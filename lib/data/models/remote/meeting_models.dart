/// DTOs for the backend's **meeting-centric governance** lifecycle
/// (Phase 2c): the 3-key unlock, the ordered 8-step workflow, and the
/// consolidated financial summary that closes a meeting.
///
/// These mirror the Node/Express endpoints under
/// `/groups/:id/meetings/:meetingId/*` and are kept separate from the local
/// offline meeting model — an official cloud meeting is driven entirely by
/// the backend, which owns the audit trail (spec §23, §30).
///
/// Shapes verified against `apps/api/src/routes/groups.ts` on 2026-07-17.
library;

double _centsToKes(Object? v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0) / 100;

int _toInt(Object? v) =>
    v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

DateTime? _toDate(Object? v) =>
    (v == null) ? null : DateTime.tryParse('$v')?.toLocal();

/// The ordered meeting workflow. Steps must be completed in this exact
/// sequence server-side (`assertMeetingStepOrder`) before a meeting can seal.
const List<String> kMeetingStepOrder = [
  'OPENING_AND_3_KEY_SECURITY',
  'MINUTES_REVIEW',
  'SOCIAL_FUND_ROUND',
  'LOAN_REPAYMENTS',
  'SHARE_PURCHASE',
  'LOAN_APPLICATIONS',
  'RESOLUTIONS_AND_GENERAL_VOTES',
  'CLOSING',
];

const Map<String, String> _stepLabels = {
  'OPENING_AND_3_KEY_SECURITY': 'Opening & 3-key security',
  'MINUTES_REVIEW': 'Minutes review',
  'SOCIAL_FUND_ROUND': 'Social fund round',
  'LOAN_REPAYMENTS': 'Loan repayments',
  'SHARE_PURCHASE': 'Share purchase',
  'LOAN_APPLICATIONS': 'Loan applications',
  'RESOLUTIONS_AND_GENERAL_VOTES': 'Resolutions & votes',
  'CLOSING': 'Closing',
};

String meetingStepLabel(String step) => _stepLabels[step] ?? step;

/// One workflow step record on a meeting.
class RemoteMeetingStep {
  const RemoteMeetingStep({required this.step, required this.status});

  final String step; // one of kMeetingStepOrder
  final String status; // PENDING | ACTIVE | COMPLETED

  String get label => meetingStepLabel(step);
  bool get isCompleted => status == 'COMPLETED';
  bool get isActive => status == 'ACTIVE';

  factory RemoteMeetingStep.fromJson(Map<String, dynamic> j) => RemoteMeetingStep(
        step: '${j['step'] ?? ''}',
        status: '${j['status'] ?? 'PENDING'}',
      );
}

/// One attendance record on a meeting.
class RemoteAttendance {
  const RemoteAttendance({
    required this.memberId,
    required this.memberName,
    required this.status,
  });

  final String memberId;
  final String memberName;
  final String status; // PRESENT | ABSENT | LATE | EXCUSED

  factory RemoteAttendance.fromJson(Map<String, dynamic> j) {
    final member = j['member'];
    return RemoteAttendance(
      memberId: '${j['memberId'] ?? ''}',
      memberName: member is Map ? '${member['fullName'] ?? 'Member'}' : 'Member',
      status: '${j['status'] ?? 'PRESENT'}',
    );
  }
}

/// One verified 3-key submission on a meeting.
class RemoteKeySubmission {
  const RemoteKeySubmission({
    required this.memberId,
    required this.memberName,
    required this.role,
    required this.credentialType,
    this.verifiedAt,
  });

  final String memberId;
  final String memberName;
  final String role;
  final String credentialType; // DEFAULT_PIN | CURRENT_OTP
  final DateTime? verifiedAt;

  bool get isOfficial => const {
        'CHAIRPERSON',
        'SECRETARY',
        'TREASURER',
        'MONEY_COUNTER',
        'KEY_HOLDER',
      }.contains(role);

  factory RemoteKeySubmission.fromJson(Map<String, dynamic> j) {
    final member = j['member'];
    return RemoteKeySubmission(
      memberId: '${j['memberId'] ?? ''}',
      memberName: member is Map ? '${member['fullName'] ?? 'Member'}' : 'Member',
      role: member is Map ? '${member['role'] ?? 'MEMBER'}' : 'MEMBER',
      credentialType: '${j['credentialType'] ?? 'DEFAULT_PIN'}',
      verifiedAt: _toDate(j['verifiedAt']),
    );
  }
}

/// Full meeting detail — `GET /groups/:id/meetings/:meetingId` and the
/// response of create / open / seal.
class RemoteMeetingDetail {
  const RemoteMeetingDetail({
    required this.id,
    required this.title,
    required this.status,
    this.scheduledAt,
    this.openedAt,
    this.closedAt,
    required this.unlockStatus,
    this.steps = const [],
    this.attendance = const [],
    this.keySubmissions = const [],
  });

  final String id;
  final String title;

  /// SCHEDULED | KEY_UNLOCK_PENDING | IN_PROGRESS | SEALED | SYNC_CONFLICT
  final String status;
  final DateTime? scheduledAt;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final String unlockStatus; // PENDING | OFFICIALS_VERIFIED | FIVE_MEMBERS_VERIFIED
  final List<RemoteMeetingStep> steps;
  final List<RemoteAttendance> attendance;
  final List<RemoteKeySubmission> keySubmissions;

  bool get isScheduled =>
      status == 'SCHEDULED' || status == 'KEY_UNLOCK_PENDING';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isSealed => status == 'SEALED';
  bool get hasConflict => status == 'SYNC_CONFLICT';

  int get presentCount =>
      attendance.where((a) => a.status == 'PRESENT' || a.status == 'LATE').length;
  int get completedSteps => steps.where((s) => s.isCompleted).length;
  int get totalSteps => steps.isEmpty ? kMeetingStepOrder.length : steps.length;

  /// The step the workflow is currently waiting on, or null when done.
  RemoteMeetingStep? get activeStep {
    for (final s in steps) {
      if (s.isActive) return s;
    }
    for (final s in steps) {
      if (!s.isCompleted) return s;
    }
    return null;
  }

  factory RemoteMeetingDetail.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(Object? raw, T Function(Map<String, dynamic>) f) =>
        (raw as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(f)
            .toList() ??
        <T>[];

    return RemoteMeetingDetail(
      id: '${j['id'] ?? ''}',
      title: '${j['title'] ?? 'Meeting'}',
      status: '${j['status'] ?? 'SCHEDULED'}',
      scheduledAt: _toDate(j['scheduledAt']),
      openedAt: _toDate(j['openedAt']),
      closedAt: _toDate(j['closedAt']),
      unlockStatus: '${j['unlockStatus'] ?? 'PENDING'}',
      steps: list(j['steps'], RemoteMeetingStep.fromJson),
      attendance: list(j['attendance'], RemoteAttendance.fromJson),
      keySubmissions: list(j['keySubmissions'], RemoteKeySubmission.fromJson),
    );
  }
}

/// Result of `evaluateMeetingUnlock` — returned by key-submissions and, on a
/// failed open, inside the error details.
class MeetingUnlockResult {
  const MeetingUnlockResult({
    required this.canOpen,
    required this.unlockStatus,
    required this.officialsVerified,
    required this.membersVerified,
    this.requiredOfficials = 3,
    this.requiredMembers = 5,
    this.message = '',
  });

  final bool canOpen;
  final String unlockStatus;
  final int officialsVerified;
  final int membersVerified;
  final int requiredOfficials;
  final int requiredMembers;
  final String message;

  factory MeetingUnlockResult.fromJson(Map<String, dynamic> j) =>
      MeetingUnlockResult(
        canOpen: j['canOpen'] == true,
        unlockStatus: '${j['unlockStatus'] ?? 'PENDING'}',
        officialsVerified: _toInt(j['officialsVerified']),
        membersVerified: _toInt(j['membersVerified']),
        requiredOfficials: j['requiredOfficials'] == null
            ? 3
            : _toInt(j['requiredOfficials']),
        requiredMembers:
            j['requiredMembers'] == null ? 5 : _toInt(j['requiredMembers']),
        message: '${j['message'] ?? ''}',
      );
}

/// One posted ledger entry — `GET /groups/:id/ledger?meetingId=…`.
class RemoteLedgerEntry {
  const RemoteLedgerEntry({
    required this.id,
    required this.type,
    required this.direction,
    required this.amount,
    this.memberName,
    this.description,
    this.createdAt,
  });

  final String id;
  final String type;
  final String direction; // CREDIT | DEBIT
  final double amount; // KES
  final String? memberName;
  final String? description;
  final DateTime? createdAt;

  bool get isCredit => direction == 'CREDIT';

  factory RemoteLedgerEntry.fromJson(Map<String, dynamic> j) {
    final member = j['member'];
    return RemoteLedgerEntry(
      id: '${j['id'] ?? ''}',
      type: '${j['type'] ?? ''}',
      direction: '${j['direction'] ?? 'CREDIT'}',
      amount: _centsToKes(j['amountCents']),
      memberName: member is Map ? member['fullName'] as String? : null,
      description: j['description'] as String?,
      createdAt: _toDate(j['createdAt']),
    );
  }
}

/// The consolidated meeting financial summary (spec §29), computed from the
/// meeting's ledger entries — the backend has no summary endpoint, so we
/// aggregate client-side by type/direction.
class MeetingFinancialSummary {
  const MeetingFinancialSummary({
    this.shares = 0,
    this.social = 0,
    this.loanRepayments = 0,
    this.loanDisbursements = 0,
    this.fines = 0,
    this.otherIn = 0,
    this.otherOut = 0,
    this.count = 0,
  });

  final double shares;
  final double social;
  final double loanRepayments;
  final double loanDisbursements;
  final double fines;
  final double otherIn;
  final double otherOut;
  final int count;

  double get totalIn =>
      shares + social + loanRepayments + fines + otherIn;
  double get totalOut => loanDisbursements + otherOut;
  double get net => totalIn - totalOut;

  factory MeetingFinancialSummary.fromLedger(List<RemoteLedgerEntry> entries) {
    double shares = 0,
        social = 0,
        repay = 0,
        disburse = 0,
        fines = 0,
        otherIn = 0,
        otherOut = 0;
    for (final e in entries) {
      switch (e.type) {
        case 'SHARE_PURCHASE':
          shares += e.amount;
        case 'SOCIAL_CONTRIBUTION':
          social += e.amount;
        case 'LOAN_REPAYMENT':
          repay += e.amount;
        case 'INTERNAL_LOAN_DISBURSEMENT':
          disburse += e.amount;
        case 'FINE_COLLECTION':
          fines += e.amount;
        default:
          if (e.isCredit) {
            otherIn += e.amount;
          } else {
            otherOut += e.amount;
          }
      }
    }
    return MeetingFinancialSummary(
      shares: shares,
      social: social,
      loanRepayments: repay,
      loanDisbursements: disburse,
      fines: fines,
      otherIn: otherIn,
      otherOut: otherOut,
      count: entries.length,
    );
  }
}
