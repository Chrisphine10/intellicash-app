/// A group's whole record book as the server holds it, for rebuilding it on a
/// new phone. Mirrors `GET /groups/:id/restore-bundle`.
///
/// Money is integer cents and every id is the server's own; the importer turns
/// them into the phone's rows and remembers which is which.
class RestoreBundle {
  const RestoreBundle({
    required this.cycleNumber,
    required this.cycleStartedAt,
    required this.policyConfigured,
    required this.loanInterestRateBps,
    required this.defaultLoanTermMonths,
    required this.meetings,
    required this.attendance,
    required this.entries,
    required this.loans,
    this.members = const [],
    this.interestType = 'FLAT',
    this.shareValueCents,
    this.maxSharesPerMeeting,
    this.socialFundCents,
    this.loanMultiplierBps,
    this.meetingFrequency,
    this.meetingDays,
    this.meetingTime,
  });

  final int cycleNumber;

  /// When the open cycle began: the line the phone draws its balances from.
  final DateTime? cycleStartedAt;

  /// Whether the group has set loan rules of its own online.
  final bool policyConfigured;
  final int loanInterestRateBps;
  final int defaultLoanTermMonths;

  /// The group's own rules as the server holds them (null = never set), so a
  /// restored phone computes what the old one did instead of using defaults.
  final String interestType;
  final int? shareValueCents;
  final int? maxSharesPerMeeting;
  final int? socialFundCents;
  final int? loanMultiplierBps;

  /// The group's schedule, as set online.
  final String? meetingFrequency;
  final String? meetingDays;
  final String? meetingTime;

  final List<RestoreMeeting> meetings;
  final List<RestoreAttendance> attendance;
  final List<RestoreEntry> entries;
  final List<RestoreLoan> loans;
  final List<RestoreMember> members;

  factory RestoreBundle.fromJson(Map<String, dynamic> json) {
    final group = json['group'] as Map<String, dynamic>;
    final policy = (json['policy'] as Map<String, dynamic>?) ?? const {};
    List<T> list<T>(String key, T Function(Map<String, dynamic>) read) => [
          for (final item in (json[key] as List? ?? const []))
            read(item as Map<String, dynamic>),
        ];
    return RestoreBundle(
      cycleNumber: (group['cycleNumber'] as num?)?.toInt() ?? 1,
      cycleStartedAt: group['cycleStartedAt'] == null
          ? null
          : DateTime.parse(group['cycleStartedAt'] as String),
      policyConfigured: policy['configured'] == true,
      loanInterestRateBps: (policy['loanInterestRateBps'] as num?)?.toInt() ?? 0,
      defaultLoanTermMonths:
          (policy['defaultLoanTermMonths'] as num?)?.toInt() ?? 1,
      meetings: list('meetings', RestoreMeeting.fromJson),
      attendance: list('attendance', RestoreAttendance.fromJson),
      entries: list('entries', RestoreEntry.fromJson),
      loans: list('loans', RestoreLoan.fromJson),
      members: list('members', RestoreMember.fromJson),
      interestType: policy['interestType'] == 'REDUCING' ? 'REDUCING' : 'FLAT',
      shareValueCents: (policy['shareValueCents'] as num?)?.toInt(),
      maxSharesPerMeeting: (policy['maxSharesPerMeeting'] as num?)?.toInt(),
      socialFundCents: (policy['socialFundCents'] as num?)?.toInt(),
      loanMultiplierBps: (policy['loanMultiplierBps'] as num?)?.toInt(),
      meetingFrequency: group['meetingFrequency'] as String?,
      meetingDays: group['meetingDays'] as String?,
      meetingTime: group['meetingTime'] as String?,
    );
  }
}

class RestoreMeeting {
  const RestoreMeeting({
    required this.id,
    required this.title,
    required this.scheduledAt,
    required this.status,
    required this.closedAt,
    required this.cycleNumber,
  });

  final String id;
  final String title;
  final DateTime scheduledAt;
  final String status;
  final DateTime? closedAt;
  final int? cycleNumber;

  factory RestoreMeeting.fromJson(Map<String, dynamic> json) => RestoreMeeting(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '',
        scheduledAt: DateTime.parse(json['scheduledAt'] as String),
        status: (json['status'] as String?) ?? '',
        closedAt: json['closedAt'] == null
            ? null
            : DateTime.parse(json['closedAt'] as String),
        cycleNumber: (json['cycleNumber'] as num?)?.toInt(),
      );
}

class RestoreAttendance {
  const RestoreAttendance({
    required this.meetingId,
    required this.memberId,
    required this.status,
  });

  final String meetingId;
  final String memberId;
  final String status;

  bool get present => status == 'PRESENT' || status == 'LATE';

  factory RestoreAttendance.fromJson(Map<String, dynamic> json) =>
      RestoreAttendance(
        meetingId: json['meetingId'] as String,
        memberId: json['memberId'] as String,
        status: (json['status'] as String?) ?? '',
      );
}

class RestoreEntry {
  const RestoreEntry({
    required this.id,
    required this.meetingId,
    required this.memberId,
    required this.loanId,
    required this.cycleNumber,
    required this.type,
    required this.direction,
    required this.amountCents,
    required this.description,
    required this.externalReference,
    required this.createdAt,
  });

  final String id;
  final String? meetingId;
  final String? memberId;

  /// The loan a repayment paid, when the server could place it.
  final String? loanId;
  final int? cycleNumber;
  final String type;
  final String direction;
  final int amountCents;
  final String description;
  final String? externalReference;
  final DateTime createdAt;

  bool get isCredit => direction == 'CREDIT';

  factory RestoreEntry.fromJson(Map<String, dynamic> json) => RestoreEntry(
        id: json['id'] as String,
        meetingId: json['meetingId'] as String?,
        memberId: json['memberId'] as String?,
        loanId: json['loanId'] as String?,
        cycleNumber: (json['cycleNumber'] as num?)?.toInt(),
        type: json['type'] as String,
        direction: json['direction'] as String,
        amountCents: (json['amountCents'] as num).toInt(),
        description: (json['description'] as String?) ?? '',
        externalReference: json['externalReference'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class RestoreLoan {
  const RestoreLoan({
    required this.id,
    required this.memberId,
    required this.cycleNumber,
    required this.principalCents,
    required this.interestRateBps,
    required this.termMonths,
    required this.disbursedAt,
    required this.dueAt,
    required this.status,
    required this.disbursementEntryId,
    this.interestType = 'FLAT',
  });

  final String id;
  final String memberId;

  /// FLAT or REDUCING, as the loan was lent.
  final String interestType;
  final int? cycleNumber;
  final int principalCents;
  final int interestRateBps;
  final int termMonths;
  final DateTime disbursedAt;
  final DateTime dueAt;

  /// ACTIVE | REPAID | CARRIED_FORWARD | WRITTEN_OFF
  final String status;
  final String? disbursementEntryId;

  factory RestoreLoan.fromJson(Map<String, dynamic> json) => RestoreLoan(
        id: json['id'] as String,
        memberId: json['memberId'] as String,
        cycleNumber: (json['cycleNumber'] as num?)?.toInt(),
        principalCents: (json['principalCents'] as num).toInt(),
        interestRateBps: (json['interestRateBps'] as num?)?.toInt() ?? 0,
        termMonths: (json['termMonths'] as num?)?.toInt() ?? 1,
        disbursedAt: DateTime.parse(json['disbursedAt'] as String),
        dueAt: DateTime.parse(json['dueAt'] as String),
        status: (json['status'] as String?) ?? 'ACTIVE',
        disbursementEntryId: json['disbursementEntryId'] as String?,
        interestType: json['interestType'] == 'REDUCING' ? 'REDUCING' : 'FLAT',
      );
}

class RestoreMember {
  const RestoreMember({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.role,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String? role;

  factory RestoreMember.fromJson(Map<String, dynamic> json) => RestoreMember(
        id: json['id'] as String,
        fullName: (json['fullName'] as String?) ?? '',
        phone: json['phone'] as String?,
        role: json['role'] as String?,
      );
}
