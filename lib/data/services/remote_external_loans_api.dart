import '../../core/network/api_client.dart';
import '../models/remote/external_loan_models.dart';

/// External Loans (Credit Ventures) endpoints — loan products from external
/// lending partners, and the group's applications for them.
class RemoteExternalLoansApi {
  RemoteExternalLoansApi(this._client);

  final ApiClient _client;

  /// `GET /external-loans/products` — active loan offers from partners.
  Future<List<ExternalLoanProduct>> products() async {
    final list = await _client.getList('/external-loans/products');
    return list
        .map((e) => ExternalLoanProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `GET /external-loans/applications` — the caller's applications,
  /// optionally scoped to one group.
  Future<List<ExternalLoanApplication>> applications({String? groupId}) async {
    final list = await _client.getList('/external-loans/applications', query: {
      if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
    });
    return list
        .map((e) => ExternalLoanApplication.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /external-loans/applications` — apply for a loan. [amountKes] is
  /// converted to integer cents on the wire. The server validates the amount
  /// range and the group's credit band (AMOUNT_OUT_OF_RANGE,
  /// BAND_BELOW_MINIMUM, GROUP_REQUIRED, GROUP_NOT_FOUND).
  Future<ExternalLoanApplication> apply({
    required String productId,
    required double amountKes,
    required String purpose,
    String? groupId,
  }) async {
    final data = await _client.postData('/external-loans/applications', body: {
      'productId': productId,
      'amountCents': (amountKes * 100).round(),
      'purpose': purpose,
      if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
    });
    return ExternalLoanApplication.fromJson(data as Map<String, dynamic>);
  }
}
