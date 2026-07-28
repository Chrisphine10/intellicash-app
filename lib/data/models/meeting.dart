import 'enums.dart';

class Meeting {
  const Meeting({
    required this.id,
    required this.groupId,
    required this.number,
    required this.date,
    required this.openingBalance,
    required this.status,
    this.closedAt,
  });

  final String id;
  final String groupId;

  /// Auto-incremented sequence within the group (Meeting #14).
  final int number;
  final DateTime date;
  final double openingBalance;
  final MeetingStatus status;
  final DateTime? closedAt;

  bool get isOpen => status == MeetingStatus.open;

  Meeting copyWith({MeetingStatus? status, DateTime? closedAt}) {
    return Meeting(
      id: id,
      groupId: groupId,
      number: number,
      date: date,
      openingBalance: openingBalance,
      status: status ?? this.status,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  factory Meeting.fromMap(Map<String, Object?> map) {
    return Meeting(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      number: map['number'] as int,
      date: DateTime.parse(map['date'] as String),
      openingBalance: (map['opening_balance'] as num).toDouble(),
      status: enumFromName(
          MeetingStatus.values, map['status'] as String, MeetingStatus.closed),
      closedAt: map['closed_at'] == null
          ? null
          : DateTime.parse(map['closed_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'number': number,
      'date': date.toIso8601String(),
      'opening_balance': openingBalance,
      'status': status.name,
      'closed_at': closedAt?.toIso8601String(),
    };
  }
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.meetingId,
    required this.memberId,
    required this.present,
  });

  final String meetingId;
  final String memberId;
  final bool present;

  factory AttendanceRecord.fromMap(Map<String, Object?> map) {
    return AttendanceRecord(
      meetingId: map['meeting_id'] as String,
      memberId: map['member_id'] as String,
      present: (map['present'] as int) == 1,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'meeting_id': meetingId,
      'member_id': memberId,
      'present': present ? 1 : 0,
    };
  }
}

/// Live totals for one meeting, aggregated from its transactions.
class MeetingTotals {
  const MeetingTotals({
    required this.sharesAmount,
    required this.sharesCount,
    required this.socialFund,
    required this.fines,
    required this.loanRepayments,
    required this.loanDisbursements,
    required this.presentCount,
  });

  static const empty = MeetingTotals(
    sharesAmount: 0,
    sharesCount: 0,
    socialFund: 0,
    fines: 0,
    loanRepayments: 0,
    loanDisbursements: 0,
    presentCount: 0,
  );

  final double sharesAmount;
  final int sharesCount;
  final double socialFund;
  final double fines;
  final double loanRepayments;
  final double loanDisbursements;
  final int presentCount;

  double get totalIn => sharesAmount + socialFund + fines + loanRepayments;
}
