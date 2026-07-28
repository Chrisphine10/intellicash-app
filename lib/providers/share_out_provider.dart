import 'package:flutter/foundation.dart';

import '../core/utils/domain_exception.dart';
import '../core/utils/share_out_calculator.dart';
import '../data/models/group.dart';
import '../data/repositories/share_out_repository.dart';

/// Drives the end-of-cycle share-out screen: the live preview, the welfare
/// toggle, committing the distribution, and the history of past share-outs.
class ShareOutProvider extends ChangeNotifier {
  ShareOutProvider(this._repo);

  final ShareOutRepository _repo;

  ShareOutResult? _preview;
  List<ShareOutRecord> _history = const [];
  bool _distributeWelfare = false;
  bool _loading = false;
  bool _busy = false;
  String? _error;

  ShareOutResult? get preview => _preview;
  List<ShareOutRecord> get history => _history;
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
    } on Exception catch (e) {
      _error = e is DomainException ? e.message : 'Could not load share-out.';
    } finally {
      _loading = false;
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
