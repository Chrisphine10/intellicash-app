import '../../core/utils/app_logger.dart';
import '../models/enums.dart';
import '../models/group.dart';
import '../models/meeting.dart';
import '../models/member.dart';
import '../models/remote/remote_models.dart';
import '../repositories/id_map_repository.dart';
import '../repositories/meeting_repository.dart';
import 'member_matching.dart';
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
    this.policyIsConfigured,
    this.pushPolicy,
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
  final Future<({List<Member> members, int watermark})> Function(int after)? editedMembersSince;
  final Future<int> Function()? roleWatermark;
  final Future<void> Function(int watermark)? saveRoleWatermark;

  /// Sets one member's office on the server. Must treat "already holds it" as
  /// success — a retried sync meets its own earlier write.
  final Future<void> Function(String remoteGroupId, String remoteMemberId, MemberRole role)? pushRole;

  /// The server's roster for a group, and a way to add one of those people to
  /// this phone's roster. Optional: without them the phone only ever sends
  /// members UP, and someone the server admitted (an approved join request, a
  /// member added on the web) never appears in the phone's list.
  final Future<List<RemoteMember>> Function(String remoteGroupId)? remoteMembers;
  final Future<Member> Function(String localGroupId, RemoteMember remote)? addLocalMember;

  /// Whether the server group already has loan rules of its own, and a way to
  /// give it this phone's. Optional. Without them a group that never opened the
  /// server-side "Group Rules" is charged nothing on the server (the platform
  /// default is interest-free) while its phone shows 10 %, so the two report
  /// different balances for the same loan.
  final Future<bool> Function(String remoteGroupId)? policyIsConfigured;
  final Future<void> Function(String remoteGroupId, {required int rateBps, required int termMonths})? pushPolicy;
}

class AutoSyncCoordinator {
  AutoSyncCoordinator({
    required IdMapRepository idMap,
    required MeetingRepository meetings,
    required WriteSyncService writeSync,
    this.welfareSync,
    this.linkSupport,
  })  : _idMap = idMap,
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

  /// Binds this phone's group to the signed-in group account's server group,
  /// when that is unambiguous. Returns true if a binding was made.
  ///
  /// Phones are shared and handed on, so this never attaches one group's book
  /// to another group's account. It binds only when the phone keeps exactly
  /// one group, that group is not bound yet, the server group is not already
  /// bound to a different phone group, and EITHER the names match OR the
  /// server group is a fresh shell (no members, no meetings) — which is what a
  /// group created by sign-up or by the server's repair looks like.
  Future<bool> bindOwnGroupIfClear() async {
    final support = linkSupport;
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
      final freshShell = (remote.memberCount ?? 0) == 0 && (remote.meetingCount ?? 0) == 0;
      if (!sameName && !freshShell) {
        log.warn('autosync',
            'Not binding "${local.name}" to "${remote.name}" automatically: names differ and the server group already has records.');
        return false;
      }

      await _idMap.put(MapEntity.group, local.id, remoteGroupId, groupId: remoteGroupId);
      log.info('autosync', 'Bound "${local.name}" to server group ${remote.code}');
      return true;
    } catch (e) {
      log.warn('autosync', 'Automatic group binding skipped: $e');
      return false;
    }
  }

  /// Sends up every member of [localGroupId] the server does not know yet, and
  /// records their server ids. Returns how many were linked.
  Future<int> pushUnmappedMembers(String localGroupId, String remoteGroupId) async {
    final support = linkSupport;
    if (support == null) return 0;
    final mapped = await _idMap.mappings(MapEntity.member);
    var linked = 0;
    for (final member in await support.membersForGroup(localGroupId)) {
      if (mapped.containsKey(member.id)) continue;
      try {
        final remoteId = await support.pushMember(remoteGroupId, member);
        await _idMap.put(MapEntity.member, member.id, remoteId, groupId: remoteGroupId);
        linked++;
      } catch (e) {
        // One member failing (no signal mid-run) must not stop the rest; the
        // next sync picks them up.
        log.warn('autosync', 'Member ${member.name} did not sync: $e');
      }
    }
    if (linked > 0) log.info('autosync', 'Linked $linked member(s) to the server');
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

    final remote = (await fetch(remoteGroupId)).where((member) => member.isActive).toList();
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
            : localPhone.isEmpty && _nameKey(local.name) == _nameKey(person.fullName);
        if (samePerson) {
          twin = local;
          break;
        }
      }

      try {
        final local = twin ?? await add(localGroupId, person);
        await _idMap.put(MapEntity.member, local.id, person.id, groupId: remoteGroupId);
        mappedLocal.add(local.id);
        knownRemote.add(person.id);
        if (twin == null) pulled++;
      } catch (e) {
        log.warn('autosync', 'Could not add ${person.fullName} from the server: $e');
      }
    }
    if (pulled > 0) log.info('autosync', 'Added $pulled member(s) from the server');
    return pulled;
  }

  /// Gives the server the loan rules this phone already uses, but ONLY when the
  /// server has none. Returns true if it did.
  ///
  /// Never overwrites a policy the server holds — one set on the web console, or
  /// in the server-side "Group Rules", is the group's decision. Flat monthly
  /// interest is the only model the server can express, so a phone set to
  /// reducing balance sends nothing rather than a rate that means something
  /// different there.
  Future<bool> pushPolicyIfUnset(String localGroupId, String remoteGroupId) async {
    final support = linkSupport;
    final configured = support?.policyIsConfigured;
    final push = support?.pushPolicy;
    if (support == null || configured == null || push == null) return false;

    final local = await support.currentGroup();
    if (local == null || local.id != localGroupId) return false;
    if (local.interestType != InterestType.flat) return false;
    if (await configured(remoteGroupId)) return false;

    await push(
      remoteGroupId,
      rateBps: (local.interestRate * 100).round(),
      termMonths: local.defaultLoanTermMonths < 1 ? 1 : local.defaultLoanTermMonths,
    );
    log.info('autosync', "Gave the server this group's loan rules (${local.interestRate}% a month)");
    return true;
  }

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
          final pulled = await welfareSync!
              .pull(remoteGroupId, localGroupId: localGroupId);
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
          // Before any loan is pushed, so the server prices it at the rate the
          // phone quoted the borrower.
          try {
            await pushPolicyIfUnset(localGroupId, remoteGroupId);
          } catch (e) {
            log.warn('autosync', 'Loan rules did not sync: $e');
          }
        }
        final items = await _meetings.meetingsForGroup(localGroupId);
        for (final item in items) {
          if (!await _needsSync(item.meeting)) continue;
          try {
            final result = await _writeSync.syncMeeting(item.meeting);
            records += result.syncedCount;
          } catch (e) {
            log.warn('autosync',
                'Meeting ${item.meeting.number} did not sync: $e');
          }
        }
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
