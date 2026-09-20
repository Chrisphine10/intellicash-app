import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/utils/domain_exception.dart';
import '../core/utils/share_out_calculator.dart';
import '../data/models/group.dart';
import '../data/repositories/share_out_repository.dart';
import '../data/services/share_out_sync_service.dart';

/// Drives the end-of-cycle share-out screen: the live preview, the welfare
/// toggle, committing the distribution, and the history of past share-outs.
class ShareOutProvider extends ChangeNotifier {
  ShareOutProvider(
    this._repo, {
    ShareOutSyncService? sync,
    Future<int> Function()? onSendNow,
  })  : _sync = sync,
        _onSendNow = onSendNow;

  final ShareOutRepository _repo;

  /// Optional: without it the screen shows no online status and the share-out
  /// stays on the phone, which is what the tests that build one plain want.
  final ShareOutSyncService? _sync;

  /// Runs the phone's sync now (meetings, then share-outs, in order).
  final Future<int> Function()? _onSendNow;

  ShareOutResult? _preview;
  List<ShareOutRecord> _history = const [];
  Map<int, ShareOutSyncStatus> _statuses = const {};
  int? _openMeeting;
  bool _linked = false;
  bool _distributeWelfare = false;
  bool _loading = false;
  bool _busy = false;
  String? _error;

  ShareOutResult? get preview => _preview;
  List<ShareOutRecord> get history => _history;

  /// How each past share-out stands with the online record, by cycle number.
  Map<int, ShareOutSyncStatus> get statuses => _statuses;

  /// The number of a meeting still open, which blocks the share-out.
  int? get openMeeting => _openMeeting;

  /// Whether the group is linked to the online record, so a share-out will be sent.
  bool get linked => _linked;
  bool get distributeWelfare => _distributeWelfare;
  bool get loading => _loading;
  bool get busy => _busy;
  String? get error => _error;

  /// True when there is something to distribute (contributions this cycle).
  bool get canDistribute => (_preview?.shareCapitalCents ?? 0) > 0;

  Future<void> load(Group group) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _preview =
          await _repo.preview(group, distributeWelfare: _distributeWelfare);
      _history = await _repo.history(group.id);
      await _refreshOnlineState(group);
    } on Exception catch (e) {
      _error = e is DomainException ? e.message : 'Could not load share-out.';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshOnlineState(Group group) async {
    _openMeeting = await _repo.openMeetingNumber(group.id);
    final sync = _sync;
    _linked = sync != null && await sync.isLinked(group.id);
    // A group that is not linked has nowhere to send a share-out, so saying one
    // is "waiting to be sent" would promise something that cannot happen.
    _statuses = (sync != null && _linked) ? await sync.statuses(group.id) : const {};
  }

  /// Runs the sync now and reads back where each share-out stands.
  Future<void> sendNow(Group group) async {
    _busy = true;
    notifyListeners();
    try {
      await _onSendNow?.call();
      await _refreshOnlineState(group);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Sends one share-out although the online share purchases differ from the
  /// phone's. Only for a person who has been told so and chose to.
  Future<ShareOutSendResult?> sendAnyway(Group group, int cycleNumber) async {
    final sync = _sync;
    if (sync == null) return null;
    _busy = true;
    notifyListeners();
    try {
      final batches = await sync.batches(group.id);
      final batch = batches.where((b) => b.cycleNumber == cycleNumber).firstOrNull;
      if (batch == null) return null;
      final result = await sync.send(batch, force: true);
      await _refreshOnlineState(group);
      // What was held behind it can go now.
      if (result.done) unawaited(_onSendNow?.call());
      return result;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> setDistributeWelfare(Group group, bool value) async {
    if (_distributeWelfare == value) return;
    _distributeWelfare = value;
    _preview = await _repo.preview(group, distributeWelfare: value);
    notifyListeners();
  }

  /// Commits the share-out and rolls the cycle. Returns the next-cycle group,
  /// or null on failure (see [error]).
  Future<Group?> distribute(Group group) async {
    final result = _preview;
    if (result == null) return null;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final next = await _repo.commit(group, result);
      _history = await _repo.history(group.id);
      _preview = await _repo.preview(next, distributeWelfare: _distributeWelfare);
      await _refreshOnlineState(next);
      // Straight away rather than at the next reconnect or the ten-minute
      // timer: a treasurer who shares out with signal expects it to be sent.
      unawaited(_onSendNow?.call());
      return next;
    } on DomainException catch (e) {
      _error = e.message;
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
