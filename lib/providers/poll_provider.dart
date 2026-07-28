import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../core/utils/app_logger.dart';
import '../data/models/remote/poll_models.dart';
import '../data/services/remote_polls_api.dart';

/// Voting / Polls — the group's elections and decisions. A cloud-only
/// feature: every call goes to the backend, so the UI gates on the
/// connection before using it.
class PollProvider extends ChangeNotifier {
  PollProvider(this._api);

  final RemotePollsApi _api;

  List<RemotePoll> _polls = [];
  bool _loading = false;
  String? _error;
  String? _groupId;

  List<RemotePoll> get polls => _polls;
  bool get loading => _loading;
  String? get error => _error;

  /// The group whose votes are currently loaded.
  String? get groupId => _groupId;

  /// Votes still taking ballots.
  List<RemotePoll> get openPolls => _polls.where((p) => p.isOpen).toList();

  /// Loads every vote for [groupId]. A failure leaves the previous list in
  /// place and surfaces the server's message in [error].
  Future<void> load(String groupId) async {
    _groupId = groupId;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _polls = await _api.polls(groupId);
    } on ApiException catch (e) {
      _error = e.message;
      log.warn('polls', 'load failed: ${e.message}');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// The freshest copy of a poll held in memory.
  RemotePoll? byId(String pollId) =>
      _polls.where((p) => p.id == pollId).firstOrNull;

  /// Opens a new vote and puts it at the top of the list. Rethrows
  /// [ApiException] so the caller can show the server's message.
  Future<RemotePoll> createPoll({
    required String type,
    required String title,
    required List<Map<String, dynamic>> options,
    String? groupId,
    String? description,
    String? targetRole,
    String? meetingId,
    bool secretBallot = false,
    DateTime? closesAt,
  }) async {
    final target = groupId ?? _groupId;
    if (target == null) {
      throw const ApiException('Choose a group before starting a vote.');
    }
    final poll = await _api.createPoll(
      groupId: target,
      type: type,
      title: title,
      options: options,
      description: description,
      targetRole: targetRole,
      meetingId: meetingId,
      secretBallot: secretBallot,
      closesAt: closesAt,
    );
    _groupId = target;
    _polls = [poll, ..._polls];
    notifyListeners();
    return poll;
  }

  /// Casts one ballot and refreshes that poll's tally in place. Rethrows
  /// [ApiException] — ALREADY_VOTED and POLL_CLOSED both arrive this way.
  Future<RemotePoll> vote(
    String pollId,
    String optionId, {
    String? memberId,
  }) async {
    final updated = await _api.vote(pollId, optionId, memberId: memberId);
    _replace(updated);
    return updated;
  }

  /// Closes a vote, freezing its result and writing it into the minute book.
  Future<RemotePoll> close(String pollId) async {
    final updated = await _api.closePoll(pollId);
    _replace(updated);
    return updated;
  }

  /// Re-reads one poll from the server (used when a detail screen opens).
  Future<RemotePoll?> refreshPoll(String pollId) async {
    try {
      final poll = await _api.poll(pollId);
      _replace(poll);
      return poll;
    } on ApiException catch (e) {
      log.warn('polls', 'refresh failed: ${e.message}');
      return null;
    }
  }

  void _replace(RemotePoll poll) {
    final index = _polls.indexWhere((p) => p.id == poll.id);
    if (index >= 0) {
      _polls = [..._polls]..[index] = poll;
    } else {
      _polls = [poll, ..._polls];
    }
    notifyListeners();
  }
}
