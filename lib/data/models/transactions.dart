/// Money-movement records created inside a meeting: share purchases,
/// fines and social-fund contributions.
library;

import 'enums.dart';

class SharePurchase {
  const SharePurchase({
    required this.id,
    required this.meetingId,
    required this.memberId,
    required this.shares,
    required this.unitValue,
    required this.amount,
    this.paymentMethod = PaymentMethod.cash,
    this.paymentReference,
    required this.createdAt,
  });

  final String id;
  final String meetingId;
  final String memberId;
  final int shares;
  final double unitValue;
  final double amount;
  final PaymentMethod paymentMethod;

  /// M-Pesa code / bank slip / mobile-money reference, when the method
  /// requires one. Carried into the backend ledger `externalReference`.
  final String? paymentReference;
  final DateTime createdAt;

  factory SharePurchase.fromMap(Map<String, Object?> map) {
    return SharePurchase(
      id: map['id'] as String,
      meetingId: map['meeting_id'] as String,
      memberId: map['member_id'] as String,
      shares: map['shares'] as int,
      unitValue: (map['unit_value'] as num).toDouble(),
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: enumFromName(PaymentMethod.values,
          (map['payment_method'] ?? 'cash') as String, PaymentMethod.cash),
      paymentReference: map['payment_reference'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'meeting_id': meetingId,
      'member_id': memberId,
      'shares': shares,
      'unit_value': unitValue,
      'amount': amount,
      'payment_method': paymentMethod.name,
      'payment_reference': paymentReference,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class Fine {
  const Fine({
    required this.id,
    required this.meetingId,
    required this.memberId,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  final String id;
  final String meetingId;
  final String memberId;
  final double amount;
  final String reason;
  final DateTime createdAt;

  factory Fine.fromMap(Map<String, Object?> map) {
    return Fine(
      id: map['id'] as String,
      meetingId: map['meeting_id'] as String,
      memberId: map['member_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      reason: map['reason'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'meeting_id': meetingId,
      'member_id': memberId,
      'amount': amount,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class SocialFundEntry {
  const SocialFundEntry({
    required this.id,
    required this.meetingId,
    required this.memberId,
    required this.amount,
    required this.createdAt,
  });

  final String id;
  final String meetingId;
  final String memberId;
  final double amount;
  final DateTime createdAt;

  factory SocialFundEntry.fromMap(Map<String, Object?> map) {
    return SocialFundEntry(
      id: map['id'] as String,
      meetingId: map['meeting_id'] as String,
      memberId: map['member_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'meeting_id': meetingId,
      'member_id': memberId,
      'amount': amount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// A ledger row: a member's share purchases this meeting, aggregated, with
/// the distinct payment methods they used.
class LedgerEntry {
  const LedgerEntry({
    required this.memberId,
    required this.memberName,
    required this.shares,
    required this.amount,
    this.paymentSummary = '',
  });

  final String memberId;
  final String memberName;
  final int shares;
  final double amount;

  /// Human-readable list of methods used, e.g. "Cash" or "M-Pesa · Cash".
  final String paymentSummary;
}
