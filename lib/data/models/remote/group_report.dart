import '../member.dart';

/// One member's line in a group report.
///
/// Both the server's report and the on-phone one produce these, so the totals
/// and the member rows in any single report always come from the same place.
/// Mixing the two would let the lines disagree with the totals above them.
class ReportMemberRow {
  const ReportMemberRow({
    required this.name,
    required this.savings,
    required this.owes,
    this.roleLabel,
    this.shares,
  });

  final String name;
  final double savings;
  final double owes;

  /// Set only for office holders ("Chairperson"), so the report can mark who
  /// carries responsibility. Null for an ordinary member.
  final String? roleLabel;

  /// How many shares they hold. Null when the figures came from the server,
  /// which totals share value but does not count shares — a report shows a
  /// dash there rather than dividing and risking a wrong number if the share
  /// value changed mid-cycle.
  final int? shares;

  /// From the local database, used when the phone has no connection.
  factory ReportMemberRow.fromLocal(MemberFinancials m) => ReportMemberRow(
        name: m.member.name,
        savings: m.totalSavings,
        owes: m.activeLoanBalance,
        roleLabel: m.member.isOfficial ? m.member.role.label : null,
        shares: m.totalShares,
      );

  factory ReportMemberRow.fromJson(Map<String, dynamic> json) {
    double cents(String key) => ((json[key] as num?) ?? 0) / 100;
    final borrowed = cents('loanDisbursementsCents');
    final repaid = cents('loanRepaymentsCents');
    final role = '${json['role'] ?? 'MEMBER'}';
    return ReportMemberRow(
      name: '${json['fullName'] ?? 'Member'}',
      // What they have put in: shares plus the social fund.
      savings: cents('sharesCents') + cents('socialCents'),
      // Overpayment must never read as a negative debt.
      owes: borrowed - repaid < 0 ? 0 : borrowed - repaid,
      roleLabel: role == 'MEMBER' ? null : _titleCase(role),
    );
  }

  /// `VICE_CHAIRPERSON` -> `Vice chairperson`.
  static String _titleCase(String role) {
    final words = role.toLowerCase().replaceAll('_', ' ').trim();
    if (words.isEmpty) return words;
    return words[0].toUpperCase() + words.substring(1);
  }
}

/// The group's report as the server totals it (`GET /reports/group/:id`).
///
/// Money arrives in integer cents and is converted to KES once, here, so no
/// screen has to remember to divide.
class GroupReport {
  const GroupReport({
    required this.generatedAt,
    required this.totalSavings,
    required this.socialFund,
    required this.fines,
    required this.loansGivenOut,
    required this.loansRepaid,
    required this.loansStillOwed,
    required this.members,
    required this.meetingCount,
    this.attendanceRate,
  });

  final DateTime? generatedAt;
  final double totalSavings;
  final double socialFund;
  final double fines;
  final double loansGivenOut;
  final double loansRepaid;
  final double loansStillOwed;
  final List<ReportMemberRow> members;
  final int meetingCount;

  /// 0..1, or null when the group has no attendance recorded yet.
  final double? attendanceRate;

  factory GroupReport.fromJson(Map<String, dynamic> json) {
    final ledger = (json['ledger'] as List?) ?? const [];

    // The ledger breakdown is grouped by type AND direction, so a type can
    // appear more than once and the rows have to be added, not looked up.
    double totalFor(String type) {
      var cents = 0.0;
      for (final row in ledger) {
        if (row is Map && row['type'] == type) {
          cents += ((row['totalCents'] as num?) ?? 0).toDouble();
        }
      }
      return cents / 100;
    }

    final borrowed = totalFor('INTERNAL_LOAN_DISBURSEMENT');
    final repaid = totalFor('LOAN_REPAYMENT');
    final shares = totalFor('SHARE_PURCHASE');
    final social = totalFor('SOCIAL_CONTRIBUTION');

    final group = json['group'];
    final meetings = json['meetings'];

    return GroupReport(
      generatedAt: DateTime.tryParse('${json['generatedAt']}'),
      totalSavings: shares + social,
      socialFund: social,
      fines: totalFor('FINE_COLLECTION'),
      loansGivenOut: borrowed,
      loansRepaid: repaid,
      loansStillOwed: borrowed - repaid < 0 ? 0 : borrowed - repaid,
      members: ((json['members'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReportMemberRow.fromJson)
          .toList(),
      meetingCount: group is Map ? ((group['meetingCount'] as num?) ?? 0).toInt() : 0,
      attendanceRate: meetings is Map
          ? (meetings['attendanceRate'] as num?)?.toDouble()
          : null,
    );
  }
}
