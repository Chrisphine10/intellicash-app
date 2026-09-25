import '../models/enums.dart';
import '../models/group.dart';
import '../models/remote/remote_models.dart';
import '../models/remote/restore_bundle.dart';
import '../repositories/group_repository.dart';
import '../repositories/id_map_repository.dart';
import '../repositories/member_repository.dart';
import 'group_history_importer.dart';
import 'remote_api.dart';

/// Brings a group that already exists on the server down onto this phone.
///
/// Without this there is no way to get an existing group onto a new handset.
/// A treasurer who reinstalls the app, or moves to a new phone, signs in, finds
/// no local record book, and is offered "Set up group" — so they create a
/// SECOND group, with a second code, and the savings history is split across
/// two records that nobody can reconcile afterwards.
///
/// Restoring is therefore the first thing offered to a group account whose
/// server profile already names a group. Creating a new one stays available,
/// but it stops being the only door.
class GroupRestoreService {
  GroupRestoreService({
    required RemoteApiLike api,
    required GroupRepository groups,
    required MemberRepository members,
    required IdMapRepository idMap,
    GroupHistoryImporter? history,
  })  : _api = api,
        _groups = groups,
        _members = members,
        _idMap = idMap,
        _history = history;

  final RemoteApiLike _api;
  final GroupRepository _groups;
  final MemberRepository _members;
  final IdMapRepository _idMap;

  /// Optional: without it a restore brings the roster and settings only, which
  /// is what it did before the history could be loaded.
  final GroupHistoryImporter? _history;

  /// Whether this remote group is already on the phone.
  ///
  /// Checked before restoring and again inside it: running restore twice must
  /// not produce two local groups for one remote one, and a reconnect can
  /// legitimately trigger it twice.
  Future<String?> localIdFor(String remoteGroupId) async {
    final mappings = await _idMap.mappings(MapEntity.group);
    for (final entry in mappings.entries) {
      if (entry.value == remoteGroupId) return entry.key;
    }
    return null;
  }

  /// Pulls the group and its members down, returning the local group.
  ///
  /// Idempotent: if the group is already mapped, the existing local group is
  /// returned untouched. It never overwrites local records — a phone that has
  /// been recording meetings offline must not have them silently replaced by a
  /// server snapshot that does not know about them.
  Future<GroupRestoreResult> restore(String remoteGroupId) async {
    final existingLocalId = await localIdFor(remoteGroupId);
    if (existingLocalId != null) {
      final existing = await _groups.currentGroup();
      return GroupRestoreResult(
        group: existing,
        alreadyPresent: true,
        membersRestored: 0,
      );
    }

    final remote = await _api.groupDetail(remoteGroupId);

    // Fields the server does not model are given the VSLA defaults rather than
    // being invented. The group edits them in settings; guessing a share value
    // or an interest rate would be worse than a default nobody believes.
    final group = await _groups.createGroup(
      name: remote.name,
      cycleNumber: remote.cycleNumber,
      savingsMode: SavingsMode.fixed,
      shareValue: remote.shareValue,
      maxSharesPerMeeting: remote.maxSharesPerMeeting,
      socialFundAmount: 0,
      interestRate: 10,
      interestType: InterestType.flat,
      loanMultiplier: 3,
      defaultLoanTermMonths: 1,
      meetingFrequency: MeetingFrequency.weekly,
      meetingDays: const [1],
      // Members come from the server below, each mapped to its remote id.
      // Seeding names here would create a second, unmapped copy of everyone.
      memberNames: const [],
    );

    await _idMap.put(
      MapEntity.group,
      group.id,
      remote.id,
      groupId: remote.id,
    );

    var membersRestored = 0;
    try {
      final remoteMembers = await _api.groupMembers(remote.id);
      for (final remoteMember in remoteMembers) {
        final local = await _members.addMember(
          groupId: group.id,
          name: remoteMember.fullName,
          phone: remoteMember.phone,
        );
        await _idMap.put(
          MapEntity.member,
          local.id,
          remoteMember.id,
          groupId: remote.id,
        );
        membersRestored += 1;
      }
    } catch (_) {
      // The group is already on the phone and mapped, which is the part that
      // matters. Members are re-fetched on the next sync; failing the whole
      // restore here would leave the treasurer back at "Set up group".
    }

    // The record book itself: meetings, savings, loans, past share-outs.
    final historyResult = _history == null
        ? null
        : await _restoreHistory(group.id, remote.id);

    return GroupRestoreResult(
      group: await _groups.currentGroup() ?? group,
      alreadyPresent: false,
      membersRestored: membersRestored,
      history: historyResult,
      historyPending: _history != null && historyResult == null,
    );
  }

  /// Restores a group, verifying that an `alreadyPresent` result actually has
  /// local data. A stale `id_map` entry (left over from a session whose
  /// workspace was cleared) would otherwise make us skip the restore and leave
  /// the dashboard empty. If the local data is missing, the stale mapping is
  /// cleared and the restore is retried.
  Future<GroupRestoreResult> restoreWithVerify(String remoteGroupId) async {
    final result = await restore(remoteGroupId);
    if (!result.alreadyPresent) return result;
    final group = await _groups.currentGroup();
    if (group == null) {
      await _idMap.removeMeetingMappings();
      final mappings = await _idMap.mappings(MapEntity.group);
      if (mappings.isNotEmpty) {
        for (final localId in mappings.keys) {
          final remoteId = mappings[localId];
          if (remoteId == remoteGroupId) {
            await _idMap.clearAll();
            break;
          }
        }
      }
      return restore(remoteGroupId);
    }
    return result;
  }

  /// Brings the group's history across, or marks it to be tried again.
  ///
  /// Null means "not yet": the signal went, or there are no members on the phone
  /// to attach the records to. Either way nothing was written, and the next sync
  /// ([completePendingHistory]) tries again. A result with `notImportedBecause`
  /// set is final - the phone already holds meetings of its own.
  Future<HistoryImportResult?> _restoreHistory(
      String localGroupId, String remoteGroupId) async {
    try {
      final bundle = await _api.restoreBundle(remoteGroupId);
      if (bundle == null) {
        // The server cannot give it (an older server, or this account may not
        // load it). Not an error, and not worth retrying.
        await _idMap.put(MapEntity.groupHistory, localGroupId, 'skipped',
            groupId: remoteGroupId);
        return const HistoryImportResult(
            notImportedBecause: 'The online record could not provide the history.');
      }
      final memberMap = await _remoteToLocalMembers();
      if (memberMap.isEmpty && bundle.entries.isNotEmpty) {
        await _idMap.put(MapEntity.groupHistory, localGroupId, 'pending',
            groupId: remoteGroupId);
        return null;
      }
      final result = await _history!.import(
        localGroupId: localGroupId,
        remoteGroupId: remoteGroupId,
        bundle: bundle,
        localMemberFor: memberMap,
      );
      final isPending = result.records == 0 && result.loans == 0 && bundle.entries.isNotEmpty;
      final status = (!result.imported)
          ? 'skipped'
          : (isPending ? 'pending' : 'done');
      await _idMap.put(MapEntity.groupHistory, localGroupId, status,
          groupId: remoteGroupId);
      return result;
    } catch (_) {
      await _idMap.put(MapEntity.groupHistory, localGroupId, 'pending',
          groupId: remoteGroupId);
      return null;
    }
  }

  Future<Map<String, String>> _remoteToLocalMembers() async {
    final mapped = await _idMap.mappings(MapEntity.member);
    return {for (final entry in mapped.entries) entry.value: entry.key};
  }

  /// Finishes any restore whose history did not come across the first time. Safe
  /// to call on every sync: it does nothing when nothing is pending. Never throws.
  Future<void> completePendingHistory() async {
    if (_history == null) return;
    try {
      final groups = await _idMap.mappings(MapEntity.groupHistory);
      for (final entry in groups.entries) {
        if (entry.value != 'pending') continue;
        final remoteGroupId = await _idMap.remoteId(MapEntity.group, entry.key);
        if (remoteGroupId == null) continue;
        await _restoreHistory(entry.key, remoteGroupId);
      }
    } catch (_) {
      // Tried again at the next sync.
    }
  }

  /// Manually re-triggers history import for a group regardless of current status.
  Future<HistoryImportResult?> reImportHistory(
      String localGroupId, String remoteGroupId) async {
    if (_history == null) return null;
    return _restoreHistory(localGroupId, remoteGroupId);
  }
}

/// The slice of the remote API this service needs, so it can be tested without
/// standing up an HTTP client.
abstract class RemoteApiLike {
  Future<RemoteGroup> groupDetail(String groupId);
  Future<List<RemoteMember>> groupMembers(String groupId);
  Future<RestoreBundle?> restoreBundle(String groupId);
}

/// Adapts the real client to the two calls this service makes, so the service
/// itself can be tested against a fake without an HTTP stack.
class RemoteApiRestoreAdapter implements RemoteApiLike {
  const RemoteApiRestoreAdapter(this._api);

  final RemoteApi _api;

  @override
  Future<RemoteGroup> groupDetail(String groupId) => _api.groupDetail(groupId);

  @override
  Future<List<RemoteMember>> groupMembers(String groupId) =>
      _api.groupMembers(groupId);

  @override
  Future<RestoreBundle?> restoreBundle(String groupId) =>
      _api.restoreBundle(groupId);
}

class GroupRestoreResult {
  const GroupRestoreResult({
    required this.group,
    required this.alreadyPresent,
    required this.membersRestored,
    this.history,
    this.historyPending = false,
  });

  /// What came across of the record book, when it did.
  final HistoryImportResult? history;

  /// The history has not come across yet (no signal); it follows at the next sync.
  final bool historyPending;

  final Group? group;

  /// True when the phone already held this group — nothing was changed.
  final bool alreadyPresent;
  final int membersRestored;
}
