import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../core/utils/app_logger.dart';
import '../data/models/remote/store_models.dart';
import '../data/services/remote_store_api.dart';

class StoreProvider extends ChangeNotifier {
  StoreProvider(this._api);

  final RemoteStoreApi _api;

  List<StoreProduct> _products = [];
  List<StoreProgramme> _programmes = [];
  List<StoreCreditRequest> _myRequests = [];
  bool _loading = false;
  String? _error;

  List<StoreProduct> get products => _products;
  List<StoreProgramme> get programmes => _programmes;
  List<StoreCreditRequest> get myRequests => _myRequests;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _products = await _api.products();
      _myRequests = await _safe(() => _api.myCreditRequests(), _myRequests);
    } on ApiException catch (e) {
      _error = e.message;
      log.warn('store', 'load failed: ${e.message}');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Loads programmes lazily (only needed for the request form).
  Future<List<StoreProgramme>> ensureProgrammes() async {
    if (_programmes.isEmpty) {
      _programmes = await _safe(() => _api.programmes(), _programmes);
    }
    return _programmes;
  }

  Future<StoreCreditRequest> submitCreditRequest({
    required String productId,
    required String programmeId,
    required String customerName,
    required String customerEmail,
    required String phoneNumber,
    required int quantity,
    String? groupId,
    String? groupName,
    String? notes,
    String? meetingId,
  }) async {
    final request = await _api.createCreditRequest(
      productId: productId,
      programmeId: programmeId,
      customerName: customerName,
      customerEmail: customerEmail,
      phoneNumber: phoneNumber,
      quantity: quantity,
      groupId: groupId,
      groupName: groupName,
      notes: notes,
      meetingId: meetingId,
    );
    _myRequests = await _safe(() => _api.myCreditRequests(), _myRequests);
    notifyListeners();
    return request;
  }

  Future<T> _safe<T>(Future<T> Function() call, T fallback) async {
    try {
      return await call();
    } on ApiException {
      return fallback;
    }
  }
}
