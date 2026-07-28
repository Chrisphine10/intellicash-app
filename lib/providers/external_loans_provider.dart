import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../core/utils/app_logger.dart';
import '../data/models/remote/external_loan_models.dart';
import '../data/services/remote_external_loans_api.dart';

class ExternalLoansProvider extends ChangeNotifier {
  ExternalLoansProvider(this._api);

  final RemoteExternalLoansApi _api;

  List<ExternalLoanProduct> _products = [];
  List<ExternalLoanApplication> _myApplications = [];
  bool _loading = false;
  String? _error;
  String? _groupId;

  List<ExternalLoanProduct> get products => _products;
  List<ExternalLoanApplication> get myApplications => _myApplications;
  bool get loading => _loading;
  String? get error => _error;

  /// Loads partner loan products and the group's applications. A failure on
  /// the applications call never hides the products list.
  Future<void> load({String? groupId}) async {
    _groupId = groupId;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _products = await _api.products();
      _myApplications = await _safe(
          () => _api.applications(groupId: _groupId), _myApplications);
    } on ApiException catch (e) {
      _error = e.message;
      log.warn('externalLoans', 'load failed: ${e.message}');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Submits a loan application, then refreshes the applications list.
  /// Rethrows [ApiException] so the caller can surface the server's message
  /// (amount out of range, band below minimum, …).
  Future<void> submitApplication({
    required String productId,
    required double amountKes,
    required String purpose,
    String? groupId,
  }) async {
    await _api.apply(
      productId: productId,
      amountKes: amountKes,
      purpose: purpose,
      groupId: groupId,
    );
    if (groupId != null) _groupId = groupId;
    _myApplications = await _safe(
        () => _api.applications(groupId: _groupId), _myApplications);
    notifyListeners();
  }

  Future<T> _safe<T>(Future<T> Function() call, T fallback) async {
    try {
      return await call();
    } on ApiException {
      return fallback;
    }
  }
}
