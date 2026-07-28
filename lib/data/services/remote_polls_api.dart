import '../../core/network/api_client.dart';
import '../models/remote/poll_models.dart';

/// Voting / Polls endpoints — the group's elections and decisions.
///
/// Needs `votes:read` to browse and `votes:write` to open a vote, cast a
/// ballot or close a vote (a MOBILE_CORE key and a GROUP_ACCOUNT session
/// carry both).
class RemotePollsApi {
  RemotePollsApi(this._client);

  final ApiClient _client;

  /// `GET /groups/:id/polls` — every vote the group has run, open ones first.
  Future<List<RemotePoll>> polls(String groupId, {String? status}) async {
    final list = await _client.getList('/groups/$groupId/polls', query: {
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return list
        .map((e) => RemotePoll.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /polls/:id` — one vote with its live tally.
  Future<RemotePoll> poll(String pollId) async {
    final data = await _client.getData('/polls/$pollId');
    return RemotePoll.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /groups/:id/polls` — open a new vote.
  ///
  /// [options] are `{label, memberId}` maps; a candidate row may give only a
  /// `memberId` and the server labels it with the member's name. An election
  /// must name [targetRole]. Needs at least two options.
  Future<RemotePoll> createPoll({
    required String groupId,
    required String type, // ROLE_ELECTION | DECISION
    required String title,
    required List<Map<String, dynamic>> options,
    String? description,
    String? targetRole,
    String? meetingId,
    bool secretBallot = false,
    DateTime? closesAt,
  }) async {
    final data = await _client.postData('/groups/$groupId/polls', body: {
      'type': type,
      'title': title,
      'options': options,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (targetRole != null && targetRole.isNotEmpty) 'targetRole': targetRole,
      if (meetingId != null && meetingId.isNotEmpty) 'meetingId': meetingId,
      'secretBallot': secretBallot,
      if (closesAt != null) 'closesAt': closesAt.toUtc().toIso8601String(),
    });
    return RemotePoll.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /polls/:id/vote` — cast one ballot.
  ///
  /// A member-role session votes as themselves; a group account records the
  /// ballot for a member present at the meeting and must pass [memberId].
  /// The server rejects a second ballot (ALREADY_VOTED) and a closed vote
  /// (POLL_CLOSED).
  Future<RemotePoll> vote(
    String pollId,
    String optionId, {
    String? memberId,
  }) async {
    final data = await _client.postData('/polls/$pollId/vote', body: {
      'optionId': optionId,
      if (memberId != null && memberId.isNotEmpty) 'memberId': memberId,
    });
    return RemotePoll.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /polls/:id/close` — freeze the vote and write its result into the
  /// group's minute book. Returns the poll with its `resultSummary` filled in.
  Future<RemotePoll> closePoll(String pollId) async {
    final data = await _client.postData('/polls/$pollId/close');
    return RemotePoll.fromJson(data as Map<String, dynamic>);
  }
}
