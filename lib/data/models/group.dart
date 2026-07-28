import 'enums.dart';

/// A VSLA group and its constitution — the rules captured once in the
/// 4-step setup wizard and enforced by every screen.
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.cycleNumber,
    required this.cycleStartDate,
    required this.savingsMode,
    required this.shareValue,
    required this.maxSharesPerMeeting,
    required this.socialFundAmount,
    required this.interestRate,
    required this.interestType,
    required this.loanMultiplier,
    required this.defaultLoanTermMonths,
    required this.meetingFrequency,
    required this.meetingDays,
    this.requireThreeKey = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int cycleNumber;
  final DateTime cycleStartDate;

  // Savings rules
  final SavingsMode savingsMode;
  final double shareValue;
  final int maxSharesPerMeeting;
  final double socialFundAmount;

  // Loan rules
  final double interestRate; // percent per month
  final InterestType interestType;
  final double loanMultiplier;
  final int defaultLoanTermMonths;

  // Schedule
  final MeetingFrequency meetingFrequency;

  /// Weekdays the group meets on (DateTime.weekday: 1 = Monday … 7 = Sunday),
  /// sorted, at least one. A group can meet on several days (e.g. Mon + Thu).
  final List<int> meetingDays;

  /// Whether a meeting can only start after the 3-key unlock: three
  /// officials — or most of the members — each confirm their secret PIN.
  /// On by default; switchable in Meeting Security settings.
  final bool requireThreeKey;

  final DateTime createdAt;
  final DateTime updatedAt;

  static const weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const weekdayShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  /// Primary meeting day — the first one, for displays/backend that expect a
  /// single day.
  int get meetingDay => meetingDays.first;
  String get meetingDayName => weekdayNames[meetingDay - 1];

  /// Human list of all meeting days, e.g. "Mon, Thu" or "Sunday".
  String get meetingDaysLabel => meetingDays.length == 1
      ? weekdayNames[meetingDays.first - 1]
      : meetingDays.map((d) => weekdayShort[d - 1]).join(', ');

  double get maxSavingsPerMeeting => shareValue * maxSharesPerMeeting;

  Group copyWith({
    String? name,
    int? cycleNumber,
    DateTime? cycleStartDate,
    SavingsMode? savingsMode,
    double? shareValue,
    int? maxSharesPerMeeting,
    double? socialFundAmount,
    double? interestRate,
    InterestType? interestType,
    double? loanMultiplier,
    int? defaultLoanTermMonths,
    MeetingFrequency? meetingFrequency,
    List<int>? meetingDays,
    bool? requireThreeKey,
    DateTime? updatedAt,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      cycleNumber: cycleNumber ?? this.cycleNumber,
      cycleStartDate: cycleStartDate ?? this.cycleStartDate,
      savingsMode: savingsMode ?? this.savingsMode,
      shareValue: shareValue ?? this.shareValue,
      maxSharesPerMeeting: maxSharesPerMeeting ?? this.maxSharesPerMeeting,
      socialFundAmount: socialFundAmount ?? this.socialFundAmount,
      interestRate: interestRate ?? this.interestRate,
      interestType: interestType ?? this.interestType,
      loanMultiplier: loanMultiplier ?? this.loanMultiplier,
      defaultLoanTermMonths:
          defaultLoanTermMonths ?? this.defaultLoanTermMonths,
      meetingFrequency: meetingFrequency ?? this.meetingFrequency,
      meetingDays: meetingDays ?? this.meetingDays,
      requireThreeKey: requireThreeKey ?? this.requireThreeKey,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  factory Group.fromMap(Map<String, Object?> map) {
    return Group(
      id: map['id'] as String,
      name: map['name'] as String,
      cycleNumber: map['cycle_number'] as int,
      cycleStartDate: DateTime.parse(map['cycle_start_date'] as String),
      savingsMode: enumFromName(
          SavingsMode.values, map['savings_mode'] as String, SavingsMode.fixed),
      shareValue: (map['share_value'] as num).toDouble(),
      maxSharesPerMeeting: map['max_shares_per_meeting'] as int,
      socialFundAmount: (map['social_fund_amount'] as num).toDouble(),
      interestRate: (map['interest_rate'] as num).toDouble(),
      interestType: enumFromName(InterestType.values,
          map['interest_type'] as String, InterestType.reducingBalance),
      loanMultiplier: (map['loan_multiplier'] as num).toDouble(),
      defaultLoanTermMonths: map['default_loan_term_months'] as int,
      meetingFrequency: enumFromName(MeetingFrequency.values,
          map['meeting_frequency'] as String, MeetingFrequency.weekly),
      meetingDays: _parseDays(map['meeting_days'], map['meeting_day']),
      requireThreeKey: ((map['require_three_key'] as int?) ?? 1) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'cycle_number': cycleNumber,
      'cycle_start_date': cycleStartDate.toIso8601String(),
      'savings_mode': savingsMode.name,
      'share_value': shareValue,
      'max_shares_per_meeting': maxSharesPerMeeting,
      'social_fund_amount': socialFundAmount,
      'interest_rate': interestRate,
      'interest_type': interestType.name,
      'loan_multiplier': loanMultiplier,
      'default_loan_term_months': defaultLoanTermMonths,
      'meeting_frequency': meetingFrequency.name,
      // Store the full set; keep the single column populated (first day) for
      // backward compatibility and single-day consumers.
      'meeting_days': meetingDays.join(','),
      'meeting_day': meetingDay,
      'require_three_key': requireThreeKey ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Reads the multi-day column, falling back to the legacy single column.
  static List<int> _parseDays(Object? days, Object? legacyDay) {
    if (days is String && days.trim().isNotEmpty) {
      final parsed = days
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .where((d) => d >= 1 && d <= 7)
          .toList()
        ..sort();
      if (parsed.isNotEmpty) return parsed;
    }
    final single = (legacyDay as num?)?.toInt() ?? DateTime.sunday;
    return [single];
  }
}
