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
    // The server's own figure, interest included, when it sends one. Borrowed
    // minus repaid ignores interest, so it under-reads what a member owes -
    // and disagreed with the member's own passbook.
    final serverOwes = json['loanOutstandingCents'];
    return ReportMemberRow(
      name: '${json['fullName'] ?? 'Member'}',
      // Their savings are their shares, as on the Members tab. The social fund
      // is not savings — it is paid out as welfare, not shared back.
      savings: cents('sharesCents'),
      // Overpayment must never read as a negative debt.
      owes: serverOwes is num
          ? serverOwes / 100
          : (borrowed - repaid < 0 ? 0 : borrowed - repaid),
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
    this.groupValue,
    this.interestEarned,
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

  /// What a share-out would split today: the loan fund's cash plus what
  /// borrowers still owe. Null from an older server.
  final double? groupValue;

  /// Interest the group has earned on its loans this cycle.
  final double? interestEarned;

  factory GroupReport.fromJson(Map<String, dynamic> json) {
    final statement = json['statement'];
    if (statement is Map<String, dynamic> && statement['loanFund'] is Map) {
      return GroupReport._fromStatement(json, statement);
    }
    return GroupReport._fromLedger(json);
  }

  /// The server's statement: this cycle, signed by direction, debts with
  /// interest - the same figures the group's web statement and the partner
  /// portfolio show. Nothing is added up on the phone.
  factory GroupReport._fromStatement(
      Map<String, dynamic> json, Map<String, dynamic> statement) {
    double kes(Object? map, String key) =>
        map is Map ? ((map[key] as num?) ?? 0) / 100 : 0;
    final loanFund = statement['loanFund'];
    final socialFund = statement['socialFund'];
    final loans = statement['loans'];
    final meetings = statement['meetings'];
    final equity = statement['equity'];
    final attendance =
        meetings is Map ? (meetings['attendanceRate'] as num?)?.toDouble() : null;
    return GroupReport(
      generatedAt: DateTime.tryParse('${json['generatedAt']}'),
      totalSavings: kes(loanFund, 'sharesCents'),
      socialFund: kes(socialFund, 'contributionsCents'),
      fines: kes(socialFund, 'finesCents'),
      loansGivenOut: kes(loanFund, 'disbursedCents'),
      loansRepaid: kes(loanFund, 'repaymentsCents'),
      loansStillOwed: kes(loans, 'outstandingCents'),
      members: ((json['members'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReportMemberRow.fromJson)
          .toList(),
      meetingCount:
          meetings is Map ? ((meetings['held'] as num?) ?? 0).toInt() : 0,
      // The statement gives a percentage; this model has always held 0..1.
      attendanceRate: attendance == null ? null : attendance / 100,
      groupValue: equity is Map ? kes(equity, 'totalCents') : null,
      interestEarned: loans is Map ? kes(loans, 'interestCollectedCents') : null,
    );
  }

  /// An older server with no statement: its ledger breakdown, as before.
  factory GroupReport._fromLedger(Map<String, dynamic> json) {
    final ledger = (json['ledger'] as List?) ?? const [];

    // The ledger breakdown is grouped by type AND direction, so a type can
    // appear more than once. A DEBIT row against a type takes away - adding
    // every row regardless of direction inflated the total.
    double totalFor(String type) {
      var cents = 0.0;
      for (final row in ledger) {
        if (row is Map && row['type'] == type) {
          final amount = ((row['totalCents'] as num?) ?? 0).toDouble();
          cents += row['direction'] == 'DEBIT' ? -amount : amount;
        }
      }
      return cents.abs() / 100;
    }

    final borrowed = totalFor('INTERNAL_LOAN_DISBURSEMENT');
    final repaid = totalFor('LOAN_REPAYMENT');
    final shares = totalFor('SHARE_PURCHASE');
    final social = totalFor('SOCIAL_CONTRIBUTION');

    final group = json['group'];
    final meetings = json['meetings'];

    return GroupReport(
      generatedAt: DateTime.tryParse('${json['generatedAt']}'),
      // Shares only — the same meaning as the dashboard, the member list and
      // the offline version of this very screen. It was shares PLUS the social
      // fund, so the report said 2,700 online and 2,500 offline, and listed the
      // social fund again on the next line as though it were extra.
      totalSavings: shares,
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
