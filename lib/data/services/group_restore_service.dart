import '../models/enums.dart';
import '../models/group.dart';
import '../models/remote/remote_models.dart';
import '../repositories/group_repository.dart';
import '../repositories/id_map_repository.dart';
import '../repositories/member_repository.dart';
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
  })  : _api = api,
        _groups = groups,
        _members = members,
        _idMap = idMap;

  final RemoteApiLike _api;
  final GroupRepository _groups;
  final MemberRepository _members;
  final IdMapRepository _idMap;

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

    return GroupRestoreResult(
      group: group,
      alreadyPresent: false,
      membersRestored: membersRestored,
    );
  }
}

/// The slice of the remote API this service needs, so it can be tested without
/// standing up an HTTP client.
abstract class RemoteApiLike {
  Future<RemoteGroup> groupDetail(String groupId);
  Future<List<RemoteMember>> groupMembers(String groupId);
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
}

class GroupRestoreResult {
  const GroupRestoreResult({
    required this.group,
    required this.alreadyPresent,
    required this.membersRestored,
  });

  final Group? group;

  /// True when the phone already held this group — nothing was changed.
  final bool alreadyPresent;
  final int membersRestored;
}
