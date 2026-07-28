import '../../core/network/api_client.dart';

/// A gateway payment into the group — an M-Pesa STK push or a Paystack
/// checkout. Money is integer cents on the wire.
class GroupPayment {
  const GroupPayment({
    required this.id,
    required this.status,
    required this.provider,
    required this.amount,
    this.checkoutUrl,
    this.providerTransactionId,
    this.failureReason,
  });

  final String id;
  final String status; // PENDING | COMPLETED | FAILED | CANCELLED
  final String provider;
  final double amount;

  /// Paystack only — the page the payer opens.
  final String? checkoutUrl;

  /// The M-Pesa receipt (or Paystack transaction id) once it settles.
  final String? providerTransactionId;
  final String? failureReason;

  bool get isPending => status == 'PENDING';
  bool get isComplete => status == 'COMPLETED';
  bool get isFailed => status == 'FAILED' || status == 'CANCELLED';

  factory GroupPayment.fromJson(Map<String, dynamic> j) {
    return GroupPayment(
      id: '${j['id']}',
      status: '${j['status'] ?? 'PENDING'}',
      provider: '${j['provider'] ?? ''}',
      amount: ((j['amountCents'] as num?) ?? 0) / 100.0,
      checkoutUrl: j['checkoutUrl'] as String?,
      providerTransactionId: j['providerTransactionId'] as String?,
      failureReason: j['failureReason'] as String?,
    );
  }
}

class RemotePaymentsApi {
  RemotePaymentsApi(this._client);

  final ApiClient _client;

  /// Starts a payment. For M-Pesa this sends the STK prompt to [phoneNumber];
  /// for Paystack it returns a checkout link.
  ///
  /// [clientRequestId] makes a retry safe: replaying it returns the same
  /// in-flight payment instead of prompting the member twice.
  Future<GroupPayment> initiate({
    required String groupId,
    required String provider,
    required String purpose,
    required double amount,
    String? phoneNumber,
    String? customerEmail,
    String? memberId,
    String? meetingId,
    String? clientRequestId,
  }) async {
    final data = await _client.postData('/groups/$groupId/payments', body: {
      'provider': provider,
      'purpose': purpose,
      'amountCents': (amount * 100).round(),
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
        'phoneNumber': phoneNumber.trim(),
      if (customerEmail != null && customerEmail.trim().isNotEmpty)
        'customerEmail': customerEmail.trim(),
      if (memberId != null) 'memberId': memberId,
      if (meetingId != null) 'meetingId': meetingId,
      if (clientRequestId != null) 'clientRequestId': clientRequestId,
    });
    return GroupPayment.fromJson(data as Map<String, dynamic>);
  }

  /// Polled while the member approves the prompt on their handset.
  Future<GroupPayment> status(String groupId, String paymentId) async {
    final data = await _client.getData('/groups/$groupId/payments/$paymentId');
    return GroupPayment.fromJson(data as Map<String, dynamic>);
  }
}
