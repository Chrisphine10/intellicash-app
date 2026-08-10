import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

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
import 'data/repositories/member_repository.dart';
import 'data/repositories/share_out_repository.dart';
import 'data/repositories/sync_repository.dart';
import 'data/services/remote_api.dart';
import 'data/services/remote_external_loans_api.dart';
import 'data/services/remote_governance_api.dart';
import 'data/repositories/assessment_repository.dart';
import 'data/repositories/attachment_repository.dart';
import 'data/services/attachment_sync_service.dart';
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
import 'data/services/auto_sync_coordinator.dart';
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
import 'providers/share_out_provider.dart';
import 'providers/store_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/theme_controller.dart';

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
  final syncService = SyncService(SyncRepository(db));

  // The ApiClient reads the current credentials on every call, so the
  // connection provider can swap them at runtime without rebuilding it.
  ApiCredentials liveCredentials = ApiCredentials(
    baseUrl: ApiConfig.defaultBaseUrl(),
    apiKey: '',
  );
  final apiClient = ApiClient(credentials: () => liveCredentials);
  final remoteApi = RemoteApi(apiClient);

  // Write-path (Phase 2a) dependencies.
  final idMap = IdMapRepository(db);
  final writeSyncService = WriteSyncService(
    db: db,
    idMap: idMap,
    writeApi: RemoteWriteApi(apiClient),
  );

  // Automatic sync: when connectivity returns, push every bound group's
  // closed meetings through the proven idempotent write-sync — not the old
  // generic-queue endpoint, which never existed on the backend.
  final autoSync = AutoSyncCoordinator(
    idMap: idMap,
    meetings: MeetingRepository(db),
    writeSync: writeSyncService,
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
  final attachmentSync = AttachmentSyncService(client: apiClient, attachments: attachments);
  final visitSync = VisitSyncService(
    api: RemoteVisitsApi(apiClient),
    assessmentsApi: assessmentsApi,
    assessments: assessments,
  );
  syncService.onSync = () async {
    final meetings = await autoSync.syncBoundGroups();

    // Refresh the cached scorecard while there is signal. Guarded on the
    // checksum so the 46-question document is downloaded when it changes and
    // not on every reconnect — over 2G that difference is the whole user
    // experience. A failure here is silent by design: the form already on the
    // phone is still perfectly usable.
    try {
      final template = await assessmentsApi.fetchCurrent();
      if (template != null && template.checksum != await assessments.currentChecksum()) {
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

    return meetings + visits + photos;
  };
  // The badge counts real unsynced work, not the vestigial write-queue, so it
  // tracks the sync it can see and clears as meetings back up.
  syncService.pendingProbe = () async =>
      await autoSync.pendingMeetings() +
      await visitSync.pendingCount() +
      await attachmentSync.pendingCount();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppState(
            groupRepository: GroupRepository(db),
            syncService: syncService,
          )..bootstrap(),
        ),
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
          create: (_) => LoanProvider(LoanRepository(db)),
        ),
        ChangeNotifierProvider(
          create: (_) => ConnectionProvider(
            store: CredentialStore(),
            api: remoteApi,
            applyCredentials: (creds) => liveCredentials = creds,
          )..bootstrap(),
        ),
        ChangeNotifierProvider(
          create: (_) => SyncProvider(
            idMap: idMap,
            remoteApi: remoteApi,
            syncService: writeSyncService,
            memberRepository: MemberRepository(db),
            meetingRepository: MeetingRepository(db),
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
        Provider<RemoteGovernanceApi>(
          create: (_) => RemoteGovernanceApi(apiClient),
        ),
        // Field visits. The repository and the outbox-backed sync service are
        // plain Providers: the visit flow drives its own screen state and only
        // needs shared, credential-aware collaborators.
        Provider<RemoteVisitsApi>(
          create: (_) => RemoteVisitsApi(apiClient),
        ),
        Provider<VisitRepository>(
          create: (_) => VisitRepository(),
        ),
        // The SAME instance the reconnect trigger drives — two would each
        // hold their own view of the queue.
        Provider<VisitSyncService>.value(value: visitSync),
        Provider<AssessmentRepository>.value(value: assessments),
        Provider<AttachmentRepository>.value(value: attachments),
        Provider<AttachmentSyncService>.value(value: attachmentSync),
        ChangeNotifierProvider(
          create: (_) => ShareOutProvider(ShareOutRepository(db)),
        ),
        ChangeNotifierProvider(
          create: (_) => ThemeController()..bootstrap(),
        ),
        ChangeNotifierProvider(
          create: (_) => LocaleController()..bootstrap(),
        ),
      ],
      child: const IntelliCashApp(),
    ),
  );
}
