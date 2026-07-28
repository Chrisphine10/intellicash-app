/// The signed-in member's passbook as the server totals it (`GET /members/me`).
///
/// Money arrives as integer cents and is converted to KES here, once, so no
/// screen has to remember the divide.
class MemberPassbook {
  const MemberPassbook({
    required this.memberName,
    required this.memberRole,
    required this.groupName,
    required this.shares,
    required this.social,
    required this.fines,
    required this.totalPaidIn,
    required this.loansReceived,
    required this.loansRepaid,
    required this.loanOutstanding,
    required this.attendancePresent,
    required this.attendanceTotal,
    required this.attendanceRate,
    required this.recentEntries,
  });

  final String memberName;
  final String memberRole;
  final String? groupName;

  final double shares;
  final double social;
  final double fines;
  final double totalPaidIn;

  final double loansReceived;
  final double loansRepaid;
  final double loanOutstanding;

  final int attendancePresent;
  final int attendanceTotal;

  /// 0..1, or null when the member has never been marked at a meeting.
  final double? attendanceRate;

  /// Newest first, as returned by the server.
  final List<Map<String, dynamic>> recentEntries;

  static double _money(Object? cents) =>
      ((cents as num?) ?? 0).toDouble() / 100.0;

  factory MemberPassbook.fromJson(Map<String, dynamic> j) {
    final member = (j['member'] as Map<String, dynamic>?) ?? const {};
    final group = member['group'] as Map<String, dynamic>?;
    final summary = (j['summary'] as Map<String, dynamic>?) ?? const {};
    final attendance = (j['attendance'] as Map<String, dynamic>?) ?? const {};
    return MemberPassbook(
      memberName: '${member['fullName'] ?? ''}',
      memberRole: '${member['role'] ?? ''}',
      groupName: group?['name'] as String?,
      shares: _money(summary['sharesCents']),
      social: _money(summary['socialCents']),
      fines: _money(summary['finesCents']),
      totalPaidIn: _money(summary['totalPaidInCents']),
      loansReceived: _money(summary['loansReceivedCents']),
      loansRepaid: _money(summary['loansRepaidCents']),
      loanOutstanding: _money(summary['loanOutstandingCents']),
      attendancePresent: ((attendance['present'] as num?) ?? 0).toInt(),
      attendanceTotal: ((attendance['total'] as num?) ?? 0).toInt(),
      attendanceRate: (attendance['rate'] as num?)?.toDouble(),
      recentEntries: ((j['recentEntries'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
    );
  }
}
