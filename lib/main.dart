import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/utils/app_logger.dart';
import 'core/database/app_database.dart';
import 'core/network/api_client.dart';
import 'core/network/api_config.dart';
import 'core/network/api_credentials.dart';
import 'data/repositories/dashboard_repository.dart';
import 'data/repositories/group_repository.dart';
import 'data/repositories/id_map_repository.dart';
import 'data/repositories/loan_repository.dart';
import 'data/repositories/meeting_repository.dart';
import 'data/models/enums.dart';
import 'data/repositories/member_repository.dart';
import 'data/repositories/share_out_repository.dart';
import 'data/repositories/sync_repository.dart';
import 'data/services/remote_api.dart';
import 'data/services/remote_external_loans_api.dart';
import 'data/services/remote_governance_api.dart';
import 'data/repositories/assessment_repository.dart';
import 'data/repositories/attachment_repository.dart';
import 'data/repositories/mentorship_repository.dart';
import 'data/services/attachment_sync_service.dart';
import 'data/services/mentorship_catalogue.dart';
import 'data/services/mentorship_sync_service.dart';
import 'data/services/group_restore_service.dart';
import 'data/services/remote_assessments_api.dart';
import 'data/services/remote_visits_api.dart';
import 'data/services/visit_sync_service.dart';
import 'data/repositories/visit_repository.dart';
import 'data/services/remote_payment_providers_api.dart';
import 'data/services/welfare_expense_sync.dart';
import 'data/services/remote_payments_api.dart';
import 'data/services/remote_polls_api.dart';
import 'data/services/remote_store_api.dart';
import 'data/services/remote_write_api.dart';
import 'data/services/sync_service.dart';
import 'core/network/api_exception.dart';
import 'data/services/auto_sync_coordinator.dart';
import 'data/services/group_history_importer.dart';
import 'data/services/local_data_vault.dart';
import 'data/services/module_switches.dart';
import 'data/services/share_out_sync_service.dart';
import 'data/services/write_sync_service.dart';
import 'providers/app_state.dart';
import 'providers/connection_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/loan_provider.dart';
import 'providers/external_loans_provider.dart';
import 'providers/locale_controller.dart';
import 'providers/meeting_provider.dart';
import 'providers/member_provider.dart';
import 'providers/poll_provider.dart';
import 'providers/meeting_schedule_provider.dart';
import 'core/notifications/meeting_alerts.dart';
import 'data/repositories/meeting_schedule_repository.dart';
import 'data/services/meeting_schedule_sync.dart';
import 'providers/share_out_provider.dart';
import 'providers/store_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/theme_controller.dart';

/// Bridge: holds a callback that ConnectionProvider fires after restoring a
/// group. AppState wires its reloadGroup() into this once it exists, so the
/// routing re-evaluates and the record book appears without a manual step.
class _RestoredCallback {
  void Function()? fn;
}

final _restoredCallback = _RestoredCallback();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Backend configuration (base URL + API key) ships in the bundled .env —
  // the app never hardcodes credentials. Missing file is fine: the user can
  // still connect from the Cloud Account screen.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // No .env bundled — platform defaults apply.
  }

  // `.env` ships inside the APK, so a release built on a developer's machine
  // would quietly point every phone at that laptop. Say so at startup rather
  // than letting it look like the server is down.
  final releaseProblem = ApiConfig.releaseConfigProblem();
  if (releaseProblem != null) {
    log.error('config', 'Release build misconfigured: $releaseProblem');
  }

  final db = AppDatabase.instance;
  final localDataVault = LocalDataVault(db);
  final syncService = SyncService(SyncRepository(db));

  // The ApiClient reads the current credentials on every call, so the
  // connection provider can swap them at runtime without rebuilding it.
  ApiCredentials liveCredentials = ApiCredentials(
    baseUrl: ApiConfig.defaultBaseUrl(),
    apiKey: '',
  );
  final apiClient = ApiClient(credentials: () => liveCredentials);
  // Wired below, once the ConnectionProvider that owns the session exists.
  // Without this a session the server has expired surfaces as an ordinary
  // error on whatever screen is open, and the phone goes on believing it is
  // signed in while every call fails.
  final remoteApi = RemoteApi(apiClient);

  // Write-path (Phase 2a) dependencies.
  final idMap = IdMapRepository(db);
  // Planned meetings - kept only to remind people; never started by the app.
  final meetingSchedule = MeetingScheduleRepository(db);
  final meetingAlerts = MeetingAlerts();
  MeetingScheduleProvider? scheduleRef;
  final writeSyncService = WriteSyncService(
    db: db,
    idMap: idMap,
    writeApi: RemoteWriteApi(apiClient),
    schedule: meetingSchedule,
  );

  // Automatic sync: when connectivity returns, push every bound group's
  // closed meetings through the proven idempotent write-sync — not the old
  // generic-queue endpoint, which never existed on the backend.
  // Set once the ConnectionProvider exists (below); read lazily at sync time.
  ConnectionProvider? connectionRef;
  final writeApi = RemoteWriteApi(apiClient);
  final governanceApi = RemoteGovernanceApi(apiClient);
  // Sends the share-outs this phone has made, in step with the meetings.
  final shareOutSync = ShareOutSyncService(
    db: db,
    idMap: idMap,
    writeApi: writeApi,
  );
  // Loads a group that already exists online onto this phone, history and all.
  // Shared with the sync below, which finishes a restore whose history was cut
  // short by a dropped signal.
  final groupRestore = GroupRestoreService(
    api: RemoteApiRestoreAdapter(remoteApi),
    groups: GroupRepository(db),
    members: MemberRepository(db),
    idMap: idMap,
    history: GroupHistoryImporter(db: db),
  );
  final meetingScheduleSync = MeetingScheduleSync(
    schedule: meetingSchedule,
    idMap: idMap,
    writeApi: writeApi,
    remoteMeetings: remoteApi.groupMeetings,
    remoteGroup: remoteApi.groupDetail,
    saveLocalGroup: GroupRepository(db).updateGroup,
  );
  final autoSync = AutoSyncCoordinator(
    idMap: idMap,
    meetings: MeetingRepository(db),
    writeSync: writeSyncService,
    shareOutSync: shareOutSync,
    // The group's meeting days and plans, so members are texted reminders.
    scheduleSync: meetingScheduleSync,
    // Binds a group's own phone to its server group and sends up members made
    // on the phone, so its records reach the console without anyone opening
    // the manual Sync screen.
    linkSupport: GroupLinkSupport(
      currentGroup: GroupRepository(db).currentGroup,
      membersForGroup: (localGroupId) =>
          MemberRepository(db).membersForGroup(localGroupId),
      ownRemoteGroupId: () async {
        final user = connectionRef?.signedInUser;
        return user?.role == 'GROUP_ACCOUNT' ? user?.groupId : null;
      },
      remoteGroup: remoteApi.groupDetail,
      pushMember: (remoteGroupId, member) => writeApi.syncMember(
        groupId: remoteGroupId,
        fullName: member.name,
        phone: member.phone,
        role: member.role.serverName,
      ),
      // The group's money rules, kept in step both ways (whichever side
      // changed them last wins); see AutoSyncCoordinator.syncGroupRules.
      remotePolicy: governanceApi.policy,
      pushRules: governanceApi.saveRules,
      applyRules: (localGroupId, policy) async {
        final repository = GroupRepository(db);
        final local = await repository.currentGroup();
        if (local == null || local.id != localGroupId) return;
        await repository.updateGroup(local.copyWith(
          interestRate: policy.loanInterestRateBps / 100,
          defaultLoanTermMonths: policy.defaultLoanTermMonths,
          interestType: policy.interestType == 'REDUCING'
              ? InterestType.reducingBalance
              : InterestType.flat,
          shareValue: policy.shareValueCents == null ? null : policy.shareValueCents! / 100,
          maxSharesPerMeeting: policy.maxSharesPerMeeting,
          socialFundAmount: policy.socialFundCents == null ? null : policy.socialFundCents! / 100,
          loanMultiplier: policy.loanMultiplierBps == null ? null : policy.loanMultiplierBps! / 10000,
        ));
        _restoredCallback.fn?.call();
      },
      rulesWatermark: (localGroupId) async {
        final raw = (await SharedPreferences.getInstance()).getString('group_rules_mark_$localGroupId');
        return raw == null ? null : DateTime.tryParse(raw);
      },
      saveRulesWatermark: (localGroupId, at) async =>
          (await SharedPreferences.getInstance()).setString('group_rules_mark_$localGroupId', at.toIso8601String()),
      remoteMembers: remoteApi.groupMembers,
      addLocalMember: (localGroupId, remote) => MemberRepository(db).addMember(
        groupId: localGroupId,
        name: remote.fullName,
        phone: remote.phone,
        role: MemberRole.values.firstWhere(
          (role) => role.serverName == remote.role,
          orElse: () => MemberRole.member,
        ),
      ),
      // A "not now" to linking this book to that group is remembered, so the
      // question is not asked at every start.
      linkDismissed: (localGroupId, remoteGroupId) async =>
          ((await SharedPreferences.getInstance()).getStringList(
                    'link_proposal_dismissed',
                  ) ??
                  const <String>[])
              .contains('$localGroupId|$remoteGroupId'),
      saveLinkDismissed: (localGroupId, remoteGroupId) async {
        final prefs = await SharedPreferences.getInstance();
        final asked =
            prefs.getStringList('link_proposal_dismissed') ?? <String>[];
        await prefs.setStringList('link_proposal_dismissed', [
          ...asked,
          '$localGroupId|$remoteGroupId',
        ]);
      },
      editedMembersSince: (after) => MemberRepository(db).editedSince(after),
      roleWatermark: () async =>
          (await SharedPreferences.getInstance()).getInt(
            'role_sync_watermark',
          ) ??
          0,
      saveRoleWatermark: (value) async =>
          (await SharedPreferences.getInstance()).setInt(
            'role_sync_watermark',
            value,
          ),
      pushRole: (remoteGroupId, remoteMemberId, role) async {
        try {
          await writeApi.assignRole(
            groupId: remoteGroupId,
            memberId: remoteMemberId,
            role: role.serverName,
          );
        } on ApiException catch (e) {
          // The server already has this office for this member: done.
          if (e.code != 'ALREADY_HOLDS_ROLE') rethrow;
        }
      },
    ),
    // Mirrors server-recorded welfare spending down, so share-out subtracts
    // what the group has actually spent rather than gross contributions.
    welfareSync: WelfareExpenseSync(db, apiClient),
  );
  // Visits ride the same reconnect trigger rather than getting a second
  // coordinator. An agent finishes a visit in a valley and walks back into
  // signal hours later; without this the visit would sit on the phone until
  // they happened to open the app and submit another one.
  final assessmentsApi = RemoteAssessmentsApi(apiClient);
  final assessments = AssessmentRepository();
  final attachments = AttachmentRepository();
  final attachmentSync = AttachmentSyncService(
    client: apiClient,
    attachments: attachments,
  );
  final mentorship = MentorshipRepository();
  final mentorshipSync = MentorshipSyncService(
    client: apiClient,
    mentorship: mentorship,
  );
  final mentorshipCatalogue = MentorshipCatalogueStore(client: apiClient);
  final visitSync = VisitSyncService(
    api: RemoteVisitsApi(apiClient),
    assessmentsApi: assessmentsApi,
    assessments: assessments,
  );
  // A phone with steady signal never "reconnects", so a meeting closed in the
  // middle of a session would wait for the next app start. Every ten minutes,
  // while someone is signed in, push what is waiting. pushNow() already
  // refuses to stack runs, and a quiet run sends nothing.
  Timer.periodic(const Duration(minutes: 10), (_) {
    if (connectionRef?.hasSession ?? false) unawaited(syncService.pushNow());
  });
  // And sooner than that when a run leaves something behind - a server that is
  // briefly down does not change the phone's connectivity, so nothing else
  // would prompt a retry.
  syncService.retryDelays = const [
    Duration(minutes: 1),
    Duration(minutes: 3),
    Duration(minutes: 7),
  ];

  syncService.onSync = () async {
    // A phone that started without signal has a session but no group loaded, so
    // every screen that talks to the server (welfare, voting, invitations, join
    // requests) told a signed-in treasurer to "choose your group first". A sync
    // only runs when there is signal, so this is the moment to load it.
    final connection = connectionRef;
    if (connection != null &&
        connection.credentials.isConfigured &&
        (!connection.isConnected || connection.selectedGroup == null)) {
      try {
        // The full check, not just a refresh: it also re-reads who is signed
        // in, which a phone that started offline never learnt.
        await connection.testConnection(silent: true);
      } catch (_) {
        // Still no signal to the server; the next sync tries again.
      }
    }

    // A group loaded onto this phone whose history did not arrive comes first,
    // before anything is sent: the meetings it brings are numbered from one.
    await groupRestore.completePendingHistory();
    final meetings = await autoSync.syncBoundGroups();
    // Plans may have come down from the console: show them and re-plan the
    // phone's own reminders.
    try {
      // The console changed the meeting days or time: the phone took them, so
      // the group every screen shows is reloaded.
      if (meetingScheduleSync.localGroupChanged) {
        meetingScheduleSync.localGroupChanged = false;
        _restoredCallback.fn?.call();
      }
      final group = await GroupRepository(db).currentGroup();
      if (group != null) await scheduleRef?.load(group);
    } catch (_) {
      // Reminders are a convenience; never a reason to fail a sync.
    }
    // Re-check pending history AFTER sync bound groups pulls server members down.
    await groupRestore.completePendingHistory();

    // Refresh the cached scorecard while there is signal. Guarded on the
    // checksum so the 46-question document is downloaded when it changes and
    // not on every reconnect — over 2G that difference is the whole user
    // experience. A failure here is silent by design: the form already on the
    // phone is still perfectly usable.
    try {
      final template = await assessmentsApi.fetchCurrent();
      if (template != null &&
          template.checksum != await assessments.currentChecksum()) {
        await assessments.cacheSnapshot(
          snapshotId: template.snapshotId,
          templateId: template.templateId,
          version: template.version,
          checksum: template.checksum,
          maxPoints: template.maxPoints,
          scoringContractVersion: template.scoringContractVersion,
          snapshot: template.snapshotJson,
        );
      }
    } catch (_) {
      // No form yet, or no signal. Neither is a reason to fail the sync.
    }
    // A failure pushing visits must not stop meetings syncing, or vice
    // versa: they are independent bodies of work and one being stuck is not
    // a reason to strand the other.
    var visits = 0;
    try {
      visits = await visitSync.pushDue();
    } catch (_) {
      // Already recorded against the outbox entry, which owns the retry.
    }

    // Photographs go last and separately. They are the largest and slowest
    // thing to push, and a failure here must never be able to hold back a
    // visit that has already landed.
    var photos = 0;
    try {
      photos = await attachmentSync.pushDue();
    } catch (_) {
      // Recorded against the attachment row; the file stays on the device.
    }

    // Coaching notes and the action plan. Independent of the rest for the same
    // reason: a visit that has landed must not be held back by anything that
    // hangs off it.
    var coaching = 0;
    try {
      coaching = await mentorshipSync.pushDue();
      // Refresh the topic list while there is signal, so the phone renders what
      // IWL currently asks rather than what it shipped with.
      await mentorshipCatalogue.refresh();
    } catch (_) {
      // Rows stay on the phone and are retried.
    }

    return meetings + visits + photos + coaching;
  };
  // The badge counts real unsynced work, not the vestigial write-queue, so it
  // tracks the sync it can see and clears as meetings back up.
  // Optional modules (Intelli-Store, Voting) each server group may use, as
  // the server last said; both off until it says otherwise.
  final moduleSwitches = ModuleSwitches(
    remoteIdFor: (localGroupId) => idMap.remoteId(MapEntity.group, localGroupId),
  );
  await moduleSwitches.load();

  syncService.pendingProbe = () async =>
      await autoSync.pendingMeetings() +
      await autoSync.pendingShareOuts() +
      await visitSync.pendingCount() +
      await attachmentSync.pendingCount() +
      await mentorshipSync.pendingCount();

  // What the sync screen says when the server has refused a share-out, so the
  // person can see WHY it is still waiting rather than a bare count.
  syncService.attentionProbe = autoSync.shareOutAttention;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final appState = AppState(
              groupRepository: GroupRepository(db),
              syncService: syncService,
              remoteGroupIdFor: (localGroupId) =>
                  idMap.remoteId(MapEntity.group, localGroupId),
              linkSource: autoSync,
            )..bootstrap();
            // Wire the restore callback so ConnectionProvider can trigger a
            // re-route after pulling a group's book down from the server.
            _restoredCallback.fn = appState.reloadGroup;
            return appState;
          },
        ),
        ChangeNotifierProvider<ModuleSwitches>.value(value: moduleSwitches),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(DashboardRepository(db)),
        ),
        ChangeNotifierProvider(
          create: (_) => MemberProvider(MemberRepository(db)),
        ),
        ChangeNotifierProvider(
          create: (_) => MeetingProvider(MeetingRepository(db)),
        ),
        ChangeNotifierProvider(
          create: (_) => scheduleRef =
              MeetingScheduleProvider(meetingSchedule, alerts: meetingAlerts),
        ),
        ChangeNotifierProvider(create: (_) => LoanProvider(LoanRepository(db))),
        ChangeNotifierProvider(
          create: (_) {
            final connection = ConnectionProvider(
              store: CredentialStore(),
              api: remoteApi,
              applyCredentials: (creds) => liveCredentials = creds,
              // Everything a switch would wipe: meetings and share-outs, a
              // roster not yet online, unsent offices and rules, and - as
              // for sign-out - visits, photos and mentorship.
              pendingLocalWork: () async =>
                  await autoSync.accountSwitchPending() +
                  await visitSync.pendingCount() +
                  await attachmentSync.pendingCount() +
                  await mentorshipSync.pendingCount(),
              syncPreviousAccount: syncService.pushNow,
              archiveLocalWorkspace: () async {
                await localDataVault.archive(label: 'Account switch backup');
              },
              clearLocalWorkspace: db.clearLocalWorkspace,
              groupRestore: groupRestore,
              onGroupRestored: () => _restoredCallback.fn?.call(),
              onGroupModules: moduleSwitches.remember,
              // Sign-out waits for everything a sync would send.
              pendingForSignOut: () async =>
                  await autoSync.signOutPending() +
                  await visitSync.pendingCount() +
                  await attachmentSync.pendingCount() +
                  await mentorshipSync.pendingCount(),
              syncBeforeSignOut: () async {
                await syncService.pushNow();
              },
              deviceOnline: () => syncService.online,
            );
            // A 401 on an authenticated call means this session is dead. Sign
            // out rather than leaving the phone believing otherwise.
            apiClient.onSessionExpired = connection.handleSessionExpired;
            connectionRef = connection;
            // Sync the moment someone signs in (including the silent sign-in
            // at app start), not only when the network comes back: a phone
            // that never loses signal would otherwise never push.
            var wasSignedIn = false;
            connection.addListener(() {
              final signedIn = connection.hasSession;
              if (signedIn && !wasSignedIn) unawaited(syncService.pushNow());
              wasSignedIn = signedIn;
            });
            return connection..bootstrap();
          },
        ),
        ChangeNotifierProvider(
          create: (_) => SyncProvider(
            idMap: idMap,
            remoteApi: remoteApi,
            syncService: writeSyncService,
            memberRepository: MemberRepository(db),
            meetingRepository: MeetingRepository(db),
            fullSync: autoSync.syncBoundGroups,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => StoreProvider(RemoteStoreApi(apiClient)),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              ExternalLoansProvider(RemoteExternalLoansApi(apiClient)),
        ),
        ChangeNotifierProvider(
          create: (_) => PollProvider(RemotePollsApi(apiClient)),
        ),
        // Not a ChangeNotifier — the gateway payment sheet drives its own
        // state and just needs the shared, credential-aware client.
        Provider<RemotePaymentsApi>(
          create: (_) => RemotePaymentsApi(apiClient),
        ),
        Provider<RemotePaymentProvidersApi>(
          create: (_) => RemotePaymentProvidersApi(apiClient),
        ),
        Provider<WriteSyncService>.value(value: writeSyncService),
        Provider<RemoteGovernanceApi>(
          create: (_) => RemoteGovernanceApi(apiClient),
        ),
        // Field visits. The repository and the outbox-backed sync service are
        // plain Providers: the visit flow drives its own screen state and only
        // needs shared, credential-aware collaborators.
        Provider<RemoteVisitsApi>(create: (_) => RemoteVisitsApi(apiClient)),
        Provider<VisitRepository>(create: (_) => VisitRepository()),
        // The SAME instance the reconnect trigger drives — two would each
        // hold their own view of the queue.
        Provider<VisitSyncService>.value(value: visitSync),
        // Lets a group that already exists on the server be pulled onto this
        // phone, instead of the treasurer creating a duplicate one.
        Provider<GroupRestoreService>.value(value: groupRestore),
        Provider<AssessmentRepository>.value(value: assessments),
        Provider<AttachmentRepository>.value(value: attachments),
        Provider<AttachmentSyncService>.value(value: attachmentSync),
        Provider<MentorshipRepository>.value(value: mentorship),
        Provider<MentorshipSyncService>.value(value: mentorshipSync),
        Provider<MentorshipCatalogueStore>.value(value: mentorshipCatalogue),
        // The raw client, for screens that talk to an endpoint directly rather
        // than through a repository — the group business profile is online-only
        // and has no local mirror to go through.
        Provider<ApiClient>.value(value: apiClient),
        ChangeNotifierProvider(
          create: (_) => ShareOutProvider(
            ShareOutRepository(db),
            sync: shareOutSync,
            onSendNow: syncService.pushNow,
          ),
        ),
        ChangeNotifierProvider(create: (_) => ThemeController()..bootstrap()),
        ChangeNotifierProvider(create: (_) => LocaleController()..bootstrap()),
      ],
      child: const IntelliCashApp(),
    ),
  );
}
