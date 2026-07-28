/// Aggregates behind the dashboard's six stat cards and trend chart.
class DashboardSummary {
  const DashboardSummary({
    required this.totalSavings,
    required this.activeLoans,
    required this.memberCount,
    required this.meetingCount,
    required this.finesCollected,
    required this.socialFund,
    required this.trend,
  });

  static const empty = DashboardSummary(
    totalSavings: 0,
    activeLoans: 0,
    memberCount: 0,
    meetingCount: 0,
    finesCollected: 0,
    socialFund: 0,
    trend: [],
  );

  final double totalSavings;
  final int activeLoans;
  final int memberCount;
  final int meetingCount;
  final double finesCollected;
  final double socialFund;

  /// Cumulative savings after each meeting, oldest first.
  final List<SavingsTrendPoint> trend;
}

class SavingsTrendPoint {
  const SavingsTrendPoint({
    required this.meetingNumber,
    required this.cumulativeSavings,
  });

  final int meetingNumber;
  final double cumulativeSavings;
}
