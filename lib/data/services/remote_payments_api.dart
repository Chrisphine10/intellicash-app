import '../../core/network/api_client.dart';

/// What a member will pay, before they agree to it. The member names what
/// the GROUP receives; the IWL fee and the payment charges go on top.
/// Money is integer cents on the wire.
class PaymentQuote {
  const PaymentQuote({
    required this.quoteId,
    required this.provider,
    required this.groupAmount,
    required this.platformFee,
    required this.providerFee,
    required this.total,
    this.expiresAt,
  });

  /// Signed by the server. Sent back when paying, so the member is charged
  /// exactly what this quote showed.
  final String quoteId;
  final String provider;
  final double groupAmount;
  final double platformFee;
  final double providerFee;
  final double total;
  final DateTime? expiresAt;

  bool get hasFees => platformFee > 0 || providerFee > 0;

  factory PaymentQuote.fromJson(Map<String, dynamic> j) {
    double kes(String key) => ((j[key] as num?) ?? 0) / 100.0;
    return PaymentQuote(
      quoteId: '${j['quoteId']}',
      provider: '${j['provider'] ?? ''}',
      groupAmount: kes('groupAmountCents'),
      platformFee: kes('platformFeeCents'),
      providerFee: kes('providerFeeCents'),
      total: kes('totalCents'),
      expiresAt: DateTime.tryParse('${j['expiresAt'] ?? ''}'),
    );
  }
}

/// A gateway payment into the group — an M-Pesa STK push or a Paystack
/// checkout.
class GroupPayment {
  const GroupPayment({
    required this.id,
    required this.status,
    required this.provider,
    required this.amount,
    this.state,
    this.groupAmount,
    this.platformFee = 0,
    this.providerFee = 0,
    this.memberId,
    this.purpose,
    this.ledgerEntryId,
    this.createdAt,
    this.checkoutUrl,
    this.providerTransactionId,
    this.failureReason,
  });

  final String id;
  final String status; // PENDING | COMPLETED | FAILED | CANCELLED

  /// The server's full state (INITIATED … LEDGER_POSTED, HELD, …). Older
  /// servers do not send it.
  final String? state;
  final String provider;

  /// What the member was charged.
  final double amount;

  /// What the group receives. Null from an older server (then it is [amount]).
  final double? groupAmount;
  final double platformFee;
  final double providerFee;
  final String? memberId;
  final String? purpose;

  /// The server ledger entry this payment was posted as.
  final String? ledgerEntryId;
  final DateTime? createdAt;

  /// Paystack only — the page the payer opens.
  final String? checkoutUrl;

  /// The M-Pesa receipt (or Paystack transaction id) once it settles.
  final String? providerTransactionId;
  final String? failureReason;

  double get amountToGroup => groupAmount ?? amount;

  /// Paid, but the amounts did not agree: an administrator checks it. The
  /// treasurer must not record it by hand or charge again.
  bool get isHeld => state == 'HELD';
  bool get isPending => status == 'PENDING' && !isHeld;
  bool get isComplete => status == 'COMPLETED';
  bool get isFailed => (status == 'FAILED' || status == 'CANCELLED') && !isHeld;

  /// The server has already written this payment into the group's books.
  bool get isPostedByServer => state == 'LEDGER_POSTED';

  factory GroupPayment.fromJson(Map<String, dynamic> j) {
    double? kes(String key) => j[key] == null ? null : (j[key] as num) / 100.0;
    return GroupPayment(
      id: '${j['id']}',
      status: '${j['status'] ?? 'PENDING'}',
      state: j['state'] as String?,
      provider: '${j['provider'] ?? ''}',
      amount: kes('amountCents') ?? 0,
      groupAmount: kes('groupAmountCents'),
      platformFee: kes('platformFeeCents') ?? 0,
      providerFee: kes('providerFeeCents') ?? 0,
      memberId: j['memberId'] as String?,
      purpose: j['purpose'] as String?,
      ledgerEntryId: j['ledgerEntryId'] as String?,
      createdAt: DateTime.tryParse('${j['createdAt'] ?? ''}'),
      checkoutUrl: j['checkoutUrl'] as String?,
      providerTransactionId: j['providerTransactionId'] as String?,
      failureReason: j['failureReason'] as String?,
    );
  }
}

class SelfPayOptions {
  const SelfPayOptions({
    required this.enabled,
    required this.providers,
    this.shareValue,
    this.socialFund,
    this.loanOutstanding = 0,
  });

  final bool enabled;
  final List<String> providers;
  final double? shareValue;
  final double? socialFund;

  /// What the member still owes on loans (the most a repayment may be).
  final double loanOutstanding;

  factory SelfPayOptions.fromJson(Map<String, dynamic> j) {
    double? kes(String key) => j[key] == null ? null : (j[key] as num) / 100.0;
    return SelfPayOptions(
      enabled: j['enabled'] == true,
      providers: [for (final p in (j['providers'] as List? ?? const [])) '$p'],
      shareValue: kes('shareValueCents'),
      socialFund: kes('socialFundCents'),
      loanOutstanding: kes('loanOutstandingCents') ?? 0,
    );
  }
}

class RemotePaymentsApi {
  RemotePaymentsApi(this._client);

  final ApiClient _client;

  /// The breakdown for paying [groupAmount] into the group.
  Future<PaymentQuote> quote({
    required String groupId,
    required String provider,
    required String purpose,
    required double groupAmount,
    String? memberId,
    String? meetingId,
  }) async {
    final data = await _client.postData('/groups/$groupId/payments/quote', body: {
      'provider': provider,
      'purpose': purpose,
      'groupAmountCents': (groupAmount * 100).round(),
      if (memberId != null) 'memberId': memberId,
      if (meetingId != null) 'meetingId': meetingId,
    });
    return PaymentQuote.fromJson(data as Map<String, dynamic>);
  }

  /// Starts a payment for a [quote]. For M-Pesa this sends the STK prompt to
  /// [phoneNumber]; for Paystack it returns a checkout link.
  ///
  /// [clientRequestId] makes a retry safe: replaying it returns the same
  /// in-flight payment instead of prompting the member twice.
  Future<GroupPayment> initiate({
    required String groupId,
    required PaymentQuote quote,
    required String purpose,
    String? phoneNumber,
    String? customerEmail,
    String? memberId,
    String? meetingId,
    String? clientRequestId,
  }) async {
    final data = await _client.postData('/groups/$groupId/payments', body: {
      'provider': quote.provider,
      'purpose': purpose,
      'quoteId': quote.quoteId,
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

  /// Payments the server has put in the group's books that no phone has
  /// recorded — typically one that finished after the phone stopped waiting.
  Future<List<GroupPayment>> unlinked(String groupId) async {
    final data = await _client.getData('/groups/$groupId/payments?unlinked=1');
    return [
      for (final row in (data as List? ?? const []))
        GroupPayment.fromJson(row as Map<String, dynamic>),
    ];
  }

  // --- A member paying for themselves, from the passbook. -----------------

  /// Whether the member's group lets them pay from the passbook. An older
  /// server, or any failure, reads as "not offered".
  Future<SelfPayOptions> selfOptions() async {
    try {
      final data = await _client.getData('/members/me/payments/options');
      return SelfPayOptions.fromJson(data as Map<String, dynamic>);
    } catch (_) {
      return const SelfPayOptions(enabled: false, providers: []);
    }
  }

  Future<PaymentQuote> selfQuote({
    required String provider,
    required String purpose,
    required double groupAmount,
  }) async {
    final data = await _client.postData('/members/me/payments/quote', body: {
      'provider': provider,
      'purpose': purpose,
      'groupAmountCents': (groupAmount * 100).round(),
    });
    return PaymentQuote.fromJson(data as Map<String, dynamic>);
  }

  Future<GroupPayment> selfInitiate({
    required PaymentQuote quote,
    required String purpose,
    String? phoneNumber,
    String? customerEmail,
    String? clientRequestId,
  }) async {
    final data = await _client.postData('/members/me/payments', body: {
      'provider': quote.provider,
      'purpose': purpose,
      'quoteId': quote.quoteId,
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty)
        'phoneNumber': phoneNumber.trim(),
      if (customerEmail != null && customerEmail.trim().isNotEmpty)
        'customerEmail': customerEmail.trim(),
      if (clientRequestId != null) 'clientRequestId': clientRequestId,
    });
    return GroupPayment.fromJson(data as Map<String, dynamic>);
  }

  Future<GroupPayment> selfStatus(String paymentId) async {
    final data = await _client.getData('/members/me/payments/$paymentId');
    return GroupPayment.fromJson(data as Map<String, dynamic>);
  }
}
