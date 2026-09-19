import '../../core/utils/app_logger.dart';
import '../models/group.dart';
import '../models/meeting.dart';
import '../models/member.dart';
import '../models/remote/remote_models.dart';
import '../repositories/id_map_repository.dart';
import '../repositories/meeting_repository.dart';
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
