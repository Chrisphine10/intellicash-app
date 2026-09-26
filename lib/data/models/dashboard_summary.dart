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
    this.sharesFromServer = false,
    this.serverTotalShares,
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

  /// True when [totalSavings] is the server's figure (the phone holds no
  /// meetings for this group yet), false when it is this phone's own book.
  final bool sharesFromServer;

  /// The server's total shares this cycle, when known and the phone's figure
  /// is shown. Screens show it beside the phone's so a difference is visible
  /// and explained, never blended.
  final double? serverTotalShares;

  /// Cumulative shares after each meeting, oldest first.
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
