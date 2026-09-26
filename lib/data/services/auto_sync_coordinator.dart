import '../../core/utils/app_logger.dart';
import '../models/enums.dart';
import '../models/group.dart';
import '../models/meeting.dart';
import '../models/member.dart';
import '../models/remote/remote_models.dart';
import '../repositories/id_map_repository.dart';
import '../repositories/meeting_repository.dart';
import 'meeting_schedule_sync.dart';
import 'remote_governance_api.dart';
import 'member_matching.dart';
import 'share_out_sync_service.dart';
import 'write_sync_service.dart';
import 'welfare_expense_sync.dart';

/// Pushes local writes to the backend automatically when connectivity returns.
///
/// It does not invent a new sync mechanism: it runs the same idempotent
/// per-meeting write-sync the manual "Sync" screen uses (`WriteSyncService`),
/// over every group this device has bound to a backend group. Because each
/// entry carries a `clientRequestId`, re-running a sync that already partly
/// succeeded is safe — the server ignores what it has already stored.
///
/// A group that has not been linked to the backend is skipped, not failed:
/// its data stays on the phone until someone links it, which is the correct
/// behaviour, not a lost write.
/// What the coordinator needs to link this phone's group and its members to
/// the server without anyone opening the manual Sync screen.
///
/// Functions rather than repositories so a test can drive them directly.
class GroupLinkSupport {
  const GroupLinkSupport({
    required this.currentGroup,
    required this.membersForGroup,
    required this.ownRemoteGroupId,
    required this.remoteGroup,
    required this.pushMember,
    this.editedMembersSince,
    this.roleWatermark,
    this.saveRoleWatermark,
    this.pushRole,
    this.remoteMembers,
    this.addLocalMember,
    this.remotePolicy,
    this.pushRules,
    this.applyRules,
    this.rulesWatermark,
    this.saveRulesWatermark,
    this.linkDismissed,
    this.saveLinkDismissed,
  });

  /// The group this phone keeps (a group's phone keeps one).
  final Future<Group?> Function() currentGroup;
  final Future<List<Member>> Function(String localGroupId) membersForGroup;

  /// The server group of the signed-in GROUP account, or null for any other
  /// role or when signed out. Only a group's own account may bind its phone.
  final Future<String?> Function() ownRemoteGroupId;
  final Future<RemoteGroup> Function(String remoteGroupId) remoteGroup;

  /// Sends one member up and returns their server id (retry-safe server-side).
  final Future<String> Function(String remoteGroupId, Member member) pushMember;

  /// Role changes made on this phone. Optional: without them roles set on the
  /// phone stay on the phone.
  final Future<({List<Member> members, int watermark})> Function(int after)?
  editedMembersSince;
  final Future<int> Function()? roleWatermark;
  final Future<void> Function(int watermark)? saveRoleWatermark;

  /// Sets one member's office on the server. Must treat "already holds it" as
  /// success — a retried sync meets its own earlier write.
  final Future<void> Function(
    String remoteGroupId,
    String remoteMemberId,
    MemberRole role,
  )?
  pushRole;

  /// The server's roster for a group, and a way to add one of those people to
  /// this phone's roster. Optional: without them the phone only ever sends
  /// members UP, and someone the server admitted (an approved join request, a
  /// member added on the web) never appears in the phone's list.
  final Future<List<RemoteMember>> Function(String remoteGroupId)?
  remoteMembers;
  final Future<Member> Function(String localGroupId, RemoteMember remote)?
  addLocalMember;

  /// The group's money rules on both sides, kept in step by [syncGroupRules].
  /// Optional. Without them the server prices loans by its own defaults
  /// (interest-free) while the phone charges the group's rate, and the two
  /// report different balances for the same loan.
  final Future<RemoteGroupPolicy> Function(String remoteGroupId)? remotePolicy;

  /// Sends the phone's rules; returns the policy as the server now holds it.
  final Future<RemoteGroupPolicy> Function(String remoteGroupId, GroupRulesPayload rules)? pushRules;

  /// Takes the server's rules onto this phone's book.
  final Future<void> Function(String localGroupId, RemoteGroupPolicy policy)? applyRules;

  /// When the two sides' rules were last known to agree.
  final Future<DateTime?> Function(String localGroupId)? rulesWatermark;
  final Future<void> Function(String localGroupId, DateTime at)? saveRulesWatermark;

  /// Whether the person already answered "not now" to linking this phone's book
  /// to this server group, and a way to remember that answer. Optional: without
  /// them the question is simply asked again on the next start.
  final Future<bool> Function(String localGroupId, String remoteGroupId)?
  linkDismissed;
  final Future<void> Function(String localGroupId, String remoteGroupId)?
  saveLinkDismissed;
}

/// A book on this phone that COULD belong to the signed-in group account, but
/// whose name does not say so. Linking sends the book's members and meetings
/// into that group, so it is put to the person rather than done for them.
class LinkProposal {
  const LinkProposal({
    required this.localGroupId,
    required this.localName,
    required this.remoteGroupId,
    required this.remoteName,
  });

  final String localGroupId;
  final String localName;
  final String remoteGroupId;
  final String remoteName;
}

/// What the app needs to ask the person about linking a book to a group. The
/// coordinator is the only implementation; the interface lets [AppState] hold it
/// without depending on the whole sync machinery.
abstract interface class LinkProposalSource {
  LinkProposal? get linkProposal;
  Future<bool> confirmLinkProposal();
  Future<void> dismissLinkProposal();
}

class AutoSyncCoordinator implements LinkProposalSource {
  AutoSyncCoordinator({
    required IdMapRepository idMap,
    required MeetingRepository meetings,
    required WriteSyncService writeSync,
    this.welfareSync,
    this.linkSupport,
    this.shareOutSync,
    this.scheduleSync,
  }) : _idMap = idMap,
       _meetings = meetings,
       _writeSync = writeSync;

  final IdMapRepository _idMap;
  final MeetingRepository _meetings;
  final WriteSyncService _writeSync;

  /// Optional: when present, server-recorded welfare expenses are mirrored
  /// down on each sync. Optional rather than required so existing call sites
  /// keep compiling — a phone without it simply does not learn about welfare
  /// spending, which is the behaviour before this existed.
  final WelfareExpenseSync? welfareSync;

  /// Optional, like [welfareSync]: without it, binding stays manual and members
  /// made on the phone are only matched, never sent — the old behaviour, under
  /// which a group's records could be full on the phone and empty on the server.
  final GroupLinkSupport? linkSupport;

  /// Optional, like the others: without it a share-out stays on the phone (the
  /// behaviour before share-outs could be sent), and meetings are pushed in no
  /// particular order relative to it.
  final ShareOutSyncService? shareOutSync;

  /// Optional, like the others: without it the group's meeting plans stay on
  /// the phone and members get no reminder texts for them.
  final MeetingScheduleSync? scheduleSync;

  LinkProposal? _proposal;

  /// A link waiting for the person's yes, or null. Set by
  /// [bindOwnGroupIfClear]; answered with [confirmLinkProposal] or
  /// [dismissLinkProposal].
  @override
  LinkProposal? get linkProposal => _proposal;

  /// The person said yes: link the book to the group. Returns true if it linked.
  @override
  Future<bool> confirmLinkProposal() async {
    final proposal = _proposal;
    if (proposal == null) return false;
    _proposal = null;
    await _idMap.put(
      MapEntity.group,
      proposal.localGroupId,
      proposal.remoteGroupId,
      groupId: proposal.remoteGroupId,
    );
    log.info(
      'autosync',
      'Linked "${proposal.localName}" to "${proposal.remoteName}" after the person confirmed',
    );
    return true;
  }

  /// The person said "not now". Remembered, so they are not asked every start.
  @override
  Future<void> dismissLinkProposal() async {
    final proposal = _proposal;
    if (proposal == null) return;
    _proposal = null;
    try {
      await linkSupport?.saveLinkDismissed?.call(
        proposal.localGroupId,
        proposal.remoteGroupId,
      );
    } catch (_) {
      // Asked again next time; nothing worse.
    }
  }

  /// Binds this phone's group to the signed-in group account's server group,
  /// when that is unambiguous. Returns true if a binding was made.
  ///
  /// Phones are shared and handed on, so this never attaches one group's book
  /// to another group's account on its own authority. It binds by itself only
  /// when the phone keeps exactly one group, that group is not bound yet, the
  /// server group is not already bound to a different phone group, and the
  /// NAMES MATCH.
  ///
  /// When the names differ but the server group is a fresh shell (no members,
  /// no meetings - what a group created by sign-up looks like) it may well be
  /// the same group under a slightly different name, or someone else's group
  /// entirely. The two cannot be told apart from here, and a wrong link sends
  /// one group's members and money into another's record. So it becomes a
  /// [linkProposal]: put to the person, with both names, before anything moves.
  Future<bool> bindOwnGroupIfClear() async {
    final support = linkSupport;
    _proposal = null;
    if (support == null) return false;
    try {
      final remoteGroupId = await support.ownRemoteGroupId();
      if (remoteGroupId == null) return false;

      final bound = await _idMap.mappings(MapEntity.group);
      if (bound.values.contains(remoteGroupId)) return false; // already linked
      final local = await support.currentGroup();
      if (local == null || bound.containsKey(local.id)) return false;

      final remote = await support.remoteGroup(remoteGroupId);
      final sameName = _nameKey(remote.name) == _nameKey(local.name);
      final freshShell =
          (remote.memberCount ?? 0) == 0 && (remote.meetingCount ?? 0) == 0;
      if (!sameName) {
        if (freshShell) {
          final declined =
              await support.linkDismissed?.call(local.id, remoteGroupId) ??
              false;
          if (!declined) {
            _proposal = LinkProposal(
              localGroupId: local.id,
              localName: local.name,
              remoteGroupId: remoteGroupId,
              remoteName: remote.name,
            );
          }
        }
        log.warn(
          'autosync',
          'Not binding "${local.name}" to "${remote.name}" automatically: the names differ.',
        );
        return false;
      }

      await _idMap.put(
        MapEntity.group,
        local.id,
        remoteGroupId,
        groupId: remoteGroupId,
      );
      log.info(
        'autosync',
        'Bound "${local.name}" to server group ${remote.code}',
      );
      return true;
    } catch (e) {
      log.warn('autosync', 'Automatic group binding skipped: $e');
      return false;
    }
  }

  /// Sends up every member of [localGroupId] the server does not know yet, and
  /// records their server ids. Returns how many were linked.
  Future<int> pushUnmappedMembers(
    String localGroupId,
    String remoteGroupId,
  ) async {
    final support = linkSupport;
    if (support == null) return 0;
    final mapped = await _idMap.mappings(MapEntity.member);
    var linked = 0;
    for (final member in await support.membersForGroup(localGroupId)) {
      if (mapped.containsKey(member.id)) continue;
      try {
        final remoteId = await support.pushMember(remoteGroupId, member);
        await _idMap.put(
          MapEntity.member,
          member.id,
          remoteId,
          groupId: remoteGroupId,
        );
        linked++;
      } catch (e) {
        // One member failing (no signal mid-run) must not stop the rest; the
        // next sync picks them up.
        log.warn('autosync', 'Member ${member.name} did not sync: $e');
      }
    }
    if (linked > 0) {
      log.info('autosync', 'Linked $linked member(s) to the server');
    }
    return linked;
  }

  /// Brings members the SERVER admitted down onto this phone, and records their
  /// server ids. Returns how many were added.
  ///
  /// Approving a join request, or adding a member on the web console, creates a
  /// member only on the server. Until this existed the phone's list simply
  /// never showed them — they could not be marked present or take part in a
  /// meeting — and the only remedy was to reinstall.
  ///
  /// Add-only and strict, like the restore: it never edits or removes anything
  /// on the phone. A server member is matched to a local one only by the same
  /// canonical phone number (or, for two people with no number at all, the same
  /// name); anything less would fuse two people, and an unmatched member is
  /// added rather than guessed at.
  Future<int> pullNewMembers(String localGroupId, String remoteGroupId) async {
    final support = linkSupport;
    final fetch = support?.remoteMembers;
    final add = support?.addLocalMember;
    if (support == null || fetch == null || add == null) return 0;

    final remote = (await fetch(
      remoteGroupId,
    )).where((member) => member.isActive).toList();
    final mappings = await _idMap.mappings(MapEntity.member);
    final knownRemote = mappings.values.toSet();
    final mappedLocal = mappings.keys.toSet();
    final locals = await support.membersForGroup(localGroupId);

    var pulled = 0;
    for (final person in remote) {
      if (knownRemote.contains(person.id)) continue;

      final wantedPhone = normalisePhone(person.phone);
      Member? twin;
      for (final local in locals) {
        if (mappedLocal.contains(local.id)) continue;
        final localPhone = normalisePhone(local.phone);
        final samePerson = wantedPhone.isNotEmpty
            ? localPhone == wantedPhone
            : localPhone.isEmpty &&
                  _nameKey(local.name) == _nameKey(person.fullName);
        if (samePerson) {
          twin = local;
          break;
        }
      }

      try {
        final local = twin ?? await add(localGroupId, person);
        await _idMap.put(
          MapEntity.member,
          local.id,
          person.id,
          groupId: remoteGroupId,
        );
        mappedLocal.add(local.id);
        knownRemote.add(person.id);
        if (twin == null) pulled++;
      } catch (e) {
        log.warn(
          'autosync',
          'Could not add ${person.fullName} from the server: $e',
        );
      }
    }
    if (pulled > 0) {
      log.info('autosync', 'Added $pulled member(s) from the server');
    }
    return pulled;
  }

  /// Keeps the group's money rules the same on the phone and the server:
  /// interest rate and type, loan term, share value, most shares a meeting,
  /// social fund amount and borrowing multiplier.
  ///
  /// Whichever side changed them LAST wins. Edits made on this phone (the
  /// set-up wizard, even offline) are pushed; rules changed on the web console
  /// come down to the phone. The watermark records when both sides last
  /// agreed — the later of the phone's edit and the server's save — so an
  /// unchanged rule set is never sent back and forth. Returns 'pushed',
  /// 'pulled' or null.
  Future<String?> syncGroupRules(
    String localGroupId,
    String remoteGroupId,
  ) async {
    final support = linkSupport;
    final fetch = support?.remotePolicy;
    final push = support?.pushRules;
    if (support == null || fetch == null || push == null) return null;

    final local = await support.currentGroup();
    if (local == null || local.id != localGroupId) return null;
    final mark = await support.rulesWatermark?.call(localGroupId);
    final remote = await fetch(remoteGroupId);
    final remoteAt = remote.configured ? remote.updatedAt : null;

    final localChanged = mark == null || local.updatedAt.isAfter(mark);
    final remoteChanged = remoteAt != null && (mark == null || remoteAt.isAfter(mark));
    if (!localChanged && !remoteChanged) return null;

    DateTime later(DateTime a, DateTime? b) => b != null && b.isAfter(a) ? b : a;

    final phoneWins = localChanged && (!remoteChanged || !remoteAt.isAfter(local.updatedAt));
    if (phoneWins) {
      final saved = await push(remoteGroupId, rulesOf(local));
      await support.saveRulesWatermark?.call(localGroupId, later(local.updatedAt, saved.updatedAt));
      log.info('autosync', "Gave the server this group's rules (${local.interestRate}% a month, ${local.interestType.name})");
      return 'pushed';
    }

    // The server's side is newer, so it has a save time.
    final serverAt = remoteAt!;
    final apply = support.applyRules;
    if (apply == null) return null;
    await apply(localGroupId, remote);
    final updated = await support.currentGroup();
    // A server policy saved before the share rules reached the server (only
    // rate and term) is newer but incomplete. The phone keeps its own share
    // value, social fund and multiplier for those, and gives them to the
    // server - otherwise the server would never learn them and a restored
    // phone would fall back to a default nobody chose.
    final incomplete = remote.shareValueCents == null ||
        remote.maxSharesPerMeeting == null ||
        remote.socialFundCents == null ||
        remote.loanMultiplierBps == null;
    if (incomplete && updated != null && updated.id == localGroupId) {
      final saved = await push(remoteGroupId, rulesOf(updated));
      await support.saveRulesWatermark?.call(localGroupId, later(later(updated.updatedAt, serverAt), saved.updatedAt));
      log.info('autosync', "Took the online loan rules and filled in this phone's share rules");
      return 'pulled';
    }
    await support.saveRulesWatermark?.call(localGroupId, later(updated?.updatedAt ?? serverAt, serverAt));
    log.info('autosync', 'Took the group rules set online');
    return 'pulled';
  }

  /// The phone's rules, in the server's units (cents, basis points).
  static GroupRulesPayload rulesOf(Group group) => GroupRulesPayload(
        loanInterestRateBps: (group.interestRate * 100).round(),
        defaultLoanTermMonths: group.defaultLoanTermMonths < 1 ? 1 : group.defaultLoanTermMonths,
        interestType: group.interestType == InterestType.reducingBalance ? 'REDUCING' : 'FLAT',
        shareValueCents: (group.shareValue * 100).round(),
        maxSharesPerMeeting: group.maxSharesPerMeeting < 1 ? 1 : group.maxSharesPerMeeting,
        socialFundCents: (group.socialFundAmount * 100).round(),
        loanMultiplierBps: (group.loanMultiplier * 10000).round(),
      );

  /// Sends roles changed on this phone since the last push — and only those, so
  /// an office changed on the web is not overwritten by a phone that never
  /// touched it. Advances the watermark only when every change landed; a
  /// failure is retried next time, which is safe because the server treats a
  /// repeat as "already holds it".
  Future<int> pushRoleChanges(Map<String, String> boundGroups) async {
    final support = linkSupport;
    final since = support?.editedMembersSince;
    final pushRole = support?.pushRole;
    if (support == null || since == null || pushRole == null) return 0;

    final after = await support.roleWatermark?.call() ?? 0;
    final changes = await since(after);
    if (changes.members.isEmpty) return 0;

    final memberMap = await _idMap.mappings(MapEntity.member);
    var pushed = 0;
    var allLanded = true;
    for (final member in changes.members) {
      final remoteGroupId = boundGroups[member.groupId];
      final remoteMemberId = memberMap[member.id];
      // Not linked yet: the member push sends the role with the member.
      if (remoteGroupId == null || remoteMemberId == null) continue;
      try {
        await pushRole(remoteGroupId, remoteMemberId, member.role);
        pushed++;
      } catch (e) {
        allLanded = false;
        log.warn('autosync', 'Role for ${member.name} did not sync: $e');
      }
    }
    if (allLanded) await support.saveRoleWatermark?.call(changes.watermark);
    if (pushed > 0) log.info('autosync', 'Synced $pushed role change(s)');
    return pushed;
  }

  static String _nameKey(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  /// How many closed meetings are still waiting to reach the backend, across
  /// every bound group. This is what the "waiting to back up" badge shows.
  ///
  /// A meeting is still pending when it has never been pushed (no backend
  /// mapping yet) or when its last push left conflicts. Open meetings are not
  /// counted — they are still being recorded, not waiting to sync — and an
  /// unbound group contributes nothing, because there is nowhere for its data
  /// to back up to until it is linked. So the count only ever reflects work
  /// the sync can actually do, and drops to zero once everything is through.
  Future<int> pendingMeetings() async {
    final boundGroups = await _idMap.mappings(MapEntity.group);
    if (boundGroups.isEmpty) return 0;

    var pending = 0;
    for (final localGroupId in boundGroups.keys) {
      // Welfare spending first: share-out subtracts it, so a phone that
      // pushed meetings but never learned what the group had SPENT would
      // still distribute money that is already gone.
      final remoteGroupId = boundGroups[localGroupId];
      if (welfareSync != null && remoteGroupId != null) {
        try {
          final pulled = await welfareSync!.pull(
            remoteGroupId,
            localGroupId: localGroupId,
          );
          if (pulled > 0) {
            log.info('autosync', 'Pulled $pulled welfare expense(s)');
          }
        } catch (e) {
          // Never let welfare block the meeting push it precedes.
          log.warn('autosync', 'Welfare expenses did not pull: $e');
        }
      }

      final items = await _meetings.meetingsForGroup(localGroupId);
      for (final item in items) {
        if (await _needsSync(item.meeting)) pending++;
      }
    }
    return pending;
  }

  /// Work that clearing this phone's book would destroy, counted before an
  /// account switch or sign-out. Unlike the badge count it includes a meeting
  /// still in progress (it has not been closed, so it has not been sent) and
  /// every meeting of a book not linked to the server yet: both exist nowhere
  /// but on this phone.
  ///
  /// Also counted, because a switch wipes them and nothing else would send
  /// them: a book never linked that holds a roster (a group set up on this
  /// phone and not yet online), offices changed here and not yet sent, and
  /// group rules changed here and not yet sent. Visits, photos and mentorship
  /// are counted by the caller from their own queues, as for sign-out.
  Future<int> accountSwitchPending() async {
    var pending = 0;
    final groups = await _idMap.mappings(MapEntity.group);
    for (final localGroupId in await _meetings.localGroupIds()) {
      final remoteGroupId = groups[localGroupId];
      final meetings = await _meetings.meetingsForGroup(localGroupId);
      for (final item in meetings) {
        if (item.meeting.isOpen ||
            remoteGroupId == null ||
            await _needsSync(item.meeting)) {
          pending++;
        }
      }
      if (remoteGroupId == null && meetings.isEmpty) {
        final roster = await linkSupport?.membersForGroup(localGroupId) ?? const [];
        if (roster.isNotEmpty) pending++;
      }
      if (shareOutSync != null) {
        pending += (await shareOutSync!.unsent(localGroupId)).length;
      }
    }

    final support = linkSupport;
    final since = support?.editedMembersSince;
    if (support != null && since != null) {
      final after = await support.roleWatermark?.call() ?? 0;
      final edits = await since(after);
      pending += edits.members.where((member) => groups[member.groupId] != null).length;
    }
    final current = await support?.currentGroup();
    final mark = support?.rulesWatermark;
    if (current != null && mark != null && groups[current.id] != null) {
      final at = await mark(current.id);
      if (at == null || current.updatedAt.isAfter(at)) pending++;
    }
    return pending;
  }

  /// Work a sign-out waits for: in every book LINKED to the server, a meeting
  /// still open, a closed meeting not fully sent, or a share-out not sent. A
  /// book never linked is not counted — it has nowhere to sync to, and signing
  /// out does not touch it.
  Future<int> signOutPending() async {
    var pending = 0;
    final groups = await _idMap.mappings(MapEntity.group);
    for (final localGroupId in await _meetings.localGroupIds()) {
      if (groups[localGroupId] == null) continue;
      for (final item in await _meetings.meetingsForGroup(localGroupId)) {
        if (item.meeting.isOpen || await _needsSync(item.meeting)) pending++;
      }
      if (shareOutSync != null) {
        pending += (await shareOutSync!.unsent(localGroupId)).length;
      }
    }
    return pending;
  }

  /// Syncs the closed meetings of every bound group that still need it, and
  /// returns the number of records the backend accepted.
  ///
  /// It skips meetings already fully backed up: re-pushing every closed
  /// meeting on every reconnect would be idempotent but re-upload the whole
  /// history each time — real cost on a metered connection. So it syncs
  /// exactly what the badge counts as pending, and no more.
  ///
  /// Never throws: one group or meeting failing (offline mid-run, a member not
  /// yet mapped) must not stop the others, and a background reconnect has
  /// nowhere to surface an exception anyway.
  Future<int> syncBoundGroups() async {
    await bindOwnGroupIfClear();
    final boundGroups = await _idMap.mappings(MapEntity.group);
    if (boundGroups.isEmpty) return 0;

    var records = 0;
    for (final localGroupId in boundGroups.keys) {
      try {
        // Members first: a meeting's attendance and money can only land for
        // members the server knows. Made-on-the-phone members used to be
        // dropped here as "not linked to the backend".
        final remoteGroupId = boundGroups[localGroupId];
        if (remoteGroupId != null) {
          records += await pushUnmappedMembers(localGroupId, remoteGroupId);
          // Then the other direction, so the two rosters converge. After the
          // push on purpose: a member made here is matched to the server's copy
          // of them first, and only the genuinely new arrive as additions.
          try {
            records += await pullNewMembers(localGroupId, remoteGroupId);
          } catch (e) {
            log.warn('autosync', 'Server members did not pull: $e');
          }
          // Before any loan is pushed, so the server prices it at the rate and
          // interest type the phone quoted the borrower.
          try {
            await syncGroupRules(localGroupId, remoteGroupId);
          } catch (e) {
            log.warn('autosync', 'Group rules did not sync: $e');
          }
        }
        final items = await _meetings.meetingsForGroup(localGroupId);
        // A meeting in progress on this phone: the server is told it started,
        // so the console and welfare see it as being held. Its records go up
        // when it closes, as before.
        for (final item in items) {
          if (!item.meeting.isOpen) continue;
          try {
            await _writeSync.ensureRemoteMeeting(item.meeting);
          } catch (e) {
            log.warn('autosync', 'Open meeting not reported: $e');
          }
        }
        if (remoteGroupId != null && scheduleSync != null) {
          try {
            final group = await linkSupport?.currentGroup();
            if (group != null && group.id == localGroupId) {
              records += await scheduleSync!.syncGroup(group, remoteGroupId);
            }
          } catch (e) {
            log.warn('autosync', 'Meeting plans did not sync: $e');
          }
        }
        records += await _pushMeetingsAndShareOuts(localGroupId, [
          for (final item in items) item.meeting,
        ]);
      } catch (e) {
        log.warn('autosync', 'Group $localGroupId did not sync: $e');
      }
    }
    // After every group's members are linked, so each role has a member to
    // land on. Its own try: a role that fails must not undo the rest.
    try {
      records += await pushRoleChanges(boundGroups);
    } catch (e) {
      log.warn('autosync', 'Role changes did not sync: $e');
    }
    if (records > 0) {
      log.info('autosync', 'Auto-synced $records record(s) on reconnect');
    }
    return records;
  }

  /// When a meeting happened, for ordering it against a share-out: the moment it
  /// closed, or its date if it never recorded one.
  static DateTime _timeOf(Meeting meeting) => meeting.closedAt ?? meeting.date;

  /// Pushes a group's meetings and share-outs in the order they happened.
  ///
  /// The server files every record under the cycle that is open WHEN IT ARRIVES,
  /// so a cycle's meetings must be there before its share-out (which closes it),
  /// and the next cycle's after. Otherwise the second cycle's savings would be
  /// filed under the first and the share-out could never be matched to them.
  ///
  /// A share-out that cannot be sent holds back what follows it - and a meeting
  /// that has not gone up holds back the share-out after it. Nothing is lost: it
  /// all still counts as waiting, and goes as soon as what is in front of it does.
  ///
  /// Returns how many records the backend accepted.
  Future<int> _pushMeetingsAndShareOuts(
    String localGroupId,
    List<Meeting> meetings,
  ) async {
    var records = 0;
    final ordered = [...meetings]
      ..sort((a, b) => _timeOf(a).compareTo(_timeOf(b)));
    final unsent =
        await shareOutSync?.unsent(localGroupId) ?? const <ShareOutBatch>[];
    var cursor = 0;

    /// Pushes every meeting up to [limit] (all of them when null). True when
    /// every one of those is now backed up.
    Future<bool> pushUpTo(DateTime? limit) async {
      var allBackedUp = true;
      while (cursor < ordered.length) {
        final meeting = ordered[cursor];
        if (limit != null && _timeOf(meeting).isAfter(limit)) break;
        cursor++;
        if (!await _needsSync(meeting)) continue;
        try {
          records += (await _writeSync.syncMeeting(meeting)).syncedCount;
        } catch (e) {
          log.warn('autosync', 'Meeting ${meeting.number} did not sync: $e');
        }
        if (await _needsSync(meeting)) allBackedUp = false;
      }
      return allBackedUp;
    }

    for (final batch in unsent) {
      if (!await pushUpTo(batch.createdAt)) return records;
      final result = await shareOutSync!.send(batch);
      if (!result.done) return records;
      if (result.outcome == ShareOutSendOutcome.sent) records++;
    }
    await pushUpTo(null);
    return records;
  }

  /// How many share-outs are still to be sent, across every bound group. Added
  /// to the "waiting to back up" count so "Everything is backed up" is not shown
  /// while a share-out has not reached the online record.
  Future<int> pendingShareOuts() async {
    final sync = shareOutSync;
    if (sync == null) return 0;
    var pending = 0;
    for (final localGroupId in (await _idMap.mappings(MapEntity.group)).keys) {
      pending += (await sync.unsent(localGroupId)).length;
    }
    return pending;
  }

  /// Something the person should read about the share-outs, if the server has
  /// refused one; null when there is nothing wrong.
  Future<String?> shareOutAttention() async {
    final sync = shareOutSync;
    if (sync == null) return null;
    for (final localGroupId in (await _idMap.mappings(MapEntity.group)).keys) {
      final note = await sync.attention(localGroupId);
      if (note != null) return note;

      // Not refused, but stuck behind a meeting from before it that the online
      // record did not fully accept: without saying so the person sees only a
      // count of things waiting, and cannot tell why it never goes down.
      final unsent = await sync.unsent(localGroupId);
      if (unsent.isEmpty) continue;
      final first = unsent.first;
      for (final item in await _meetings.meetingsForGroup(localGroupId)) {
        if (_timeOf(item.meeting).isAfter(first.createdAt)) continue;
        if ((await _idMap.conflictsForMeeting(item.meeting.id)).isNotEmpty) {
          return 'Meeting #${item.meeting.number} has records the online record '
              'did not accept, so the Cycle ${first.cycleNumber} share-out is '
              'waiting for it.';
        }
      }
    }
    return null;
  }

  /// Whether a meeting is still waiting to reach the backend.
  ///
  /// The single definition of "pending", so the badge count and what the sync
  /// actually pushes can never diverge. An open meeting is still being
  /// recorded; a meeting with no backend mapping was never pushed; a mapped
  /// meeting with conflicts was only partly pushed. Anything else is done.
  Future<bool> _needsSync(Meeting meeting) async {
    if (meeting.isOpen) return false;
    final mapped = await _idMap.remoteId(MapEntity.meeting, meeting.id);
    if (mapped == null) return true;
    final conflicts = await _idMap.conflictsForMeeting(meeting.id);
    return conflicts.isNotEmpty;
  }
}
