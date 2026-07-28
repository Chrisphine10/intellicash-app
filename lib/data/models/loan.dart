import 'enums.dart';

class Loan {
  const Loan({
    required this.id,
    required this.groupId,
    required this.memberId,
    this.meetingId,
    required this.principal,
    required this.interestRate,
    required this.interestType,
    required this.totalDue,
    required this.disbursedAt,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    this.amountRepaid = 0,
    this.memberName = '',
  });

  final String id;
  final String groupId;
  final String memberId;

  /// Meeting in which the loan was disbursed, when done in-session.
  final String? meetingId;
  final double principal;

  /// Percent per month, copied from group rules at disbursement so a later
  /// rule change never rewrites history.
  final double interestRate;
  final InterestType interestType;

  /// Principal plus interest for the full term, fixed at disbursement.
  final double totalDue;
  final DateTime disbursedAt;
  final DateTime dueDate;
  final LoanStatus status;
  final DateTime createdAt;

  /// Joined fields (not columns on the loans table).
  final double amountRepaid;
  final String memberName;

  double get outstanding {
    final due = totalDue - amountRepaid;
    return due > 0 ? due : 0;
  }

  bool get isOverdue =>
      status == LoanStatus.active && DateTime.now().isAfter(dueDate);

  Loan copyWith({LoanStatus? status, double? amountRepaid, String? memberName}) {
    return Loan(
      id: id,
      groupId: groupId,
      memberId: memberId,
      meetingId: meetingId,
      principal: principal,
      interestRate: interestRate,
      interestType: interestType,
      totalDue: totalDue,
      disbursedAt: disbursedAt,
      dueDate: dueDate,
      status: status ?? this.status,
      createdAt: createdAt,
      amountRepaid: amountRepaid ?? this.amountRepaid,
      memberName: memberName ?? this.memberName,
    );
  }

  factory Loan.fromMap(Map<String, Object?> map) {
    return Loan(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      memberId: map['member_id'] as String,
      meetingId: map['meeting_id'] as String?,
      principal: (map['principal'] as num).toDouble(),
      interestRate: (map['interest_rate'] as num).toDouble(),
      interestType: enumFromName(InterestType.values,
          map['interest_type'] as String, InterestType.reducingBalance),
      totalDue: (map['total_due'] as num).toDouble(),
      disbursedAt: DateTime.parse(map['disbursed_at'] as String),
      dueDate: DateTime.parse(map['due_date'] as String),
      status: enumFromName(
          LoanStatus.values, map['status'] as String, LoanStatus.active),
      createdAt: DateTime.parse(map['created_at'] as String),
      amountRepaid: ((map['amount_repaid'] ?? 0) as num).toDouble(),
      memberName: (map['member_name'] ?? '') as String,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'member_id': memberId,
      'meeting_id': meetingId,
      'principal': principal,
      'interest_rate': interestRate,
      'interest_type': interestType.name,
      'total_due': totalDue,
      'disbursed_at': disbursedAt.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class LoanRepayment {
  const LoanRepayment({
    required this.id,
    required this.loanId,
    this.meetingId,
    required this.amount,
    required this.paidAt,
  });

  final String id;
  final String loanId;
  final String? meetingId;
  final double amount;
  final DateTime paidAt;

  factory LoanRepayment.fromMap(Map<String, Object?> map) {
    return LoanRepayment(
      id: map['id'] as String,
      loanId: map['loan_id'] as String,
      meetingId: map['meeting_id'] as String?,
      amount: (map['amount'] as num).toDouble(),
      paidAt: DateTime.parse(map['paid_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'loan_id': loanId,
      'meeting_id': meetingId,
      'amount': amount,
      'paid_at': paidAt.toIso8601String(),
    };
  }
}

/// What the Disburse Loan screen shows before accepting a principal.
class LoanEligibility {
  const LoanEligibility({
    required this.totalSavings,
    required this.activeLoanBalance,
    required this.maxLoan,
    required this.availableAmount,
  });

  final double totalSavings;
  final double activeLoanBalance;
  final double maxLoan;
  final double availableAmount;

  bool get canBorrow => availableAmount > 0;
}
