import 'package:flutter/foundation.dart';

import '../data/models/dashboard_summary.dart';
import '../data/models/remote/remote_models.dart';
import '../data/repositories/dashboard_repository.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._repository);

  final DashboardRepository _repository;

  DashboardSummary _summary = DashboardSummary.empty;
  bool _loading = false;

  DashboardSummary get summary => _summary;
  bool get loading => _loading;

  Future<void> load(String groupId, {RemoteGroup? remoteGroup}) async {
    _loading = true;
    notifyListeners();
    _summary = await _repository.summary(groupId, remoteGroup: remoteGroup);
    _loading = false;
    notifyListeners();
  }
}
