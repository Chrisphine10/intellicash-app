import 'package:flutter/foundation.dart';

import '../data/models/dashboard_summary.dart';
import '../data/repositories/dashboard_repository.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._repository);

  final DashboardRepository _repository;

  DashboardSummary _summary = DashboardSummary.empty;
  bool _loading = false;

  DashboardSummary get summary => _summary;
  bool get loading => _loading;

  Future<void> load(String groupId) async {
    _loading = true;
    notifyListeners();
    _summary = await _repository.summary(groupId);
    _loading = false;
    notifyListeners();
  }
}
