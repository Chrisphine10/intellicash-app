import '../../core/database/app_database.dart';
import '../models/dashboard_summary.dart';
import '../models/remote/remote_models.dart';

class DashboardRepository {
  DashboardRepository(this._db);

  final AppDatabase _db;

  /// Every money figure here belongs to the group's CURRENT cycle - anything
  /// recorded after `cycle_start_date`, the same rule the share-out uses to
  /// decide what it distributes. After a share-out the dashboard therefore
  /// starts again from nothing instead of still showing savings that were paid
  /// out to members.
  ///
  /// The phone's own book is the answer whenever it holds a meeting: it is the
  /// only copy that includes a meeting recorded offline and not yet sent. The
  /// server's figures ([remoteGroup]) fill in only while the book has no
  /// meetings at all, i.e. just after sign-in, before its history has loaded.
  Future<DashboardSummary> summary(String groupId, {RemoteGroup? remoteGroup}) async {
    final db = await _db.database;
    final statRows = await db.rawQuery('''
      SELECT
        (SELECT COALESCE(SUM(sp.amount), 0) FROM share_purchases sp
          JOIN meetings m ON m.id = sp.meeting_id
          WHERE m.group_id = ?1
            AND sp.created_at > (SELECT cycle_start_date FROM groups WHERE id = ?1))
          AS total_savings,
        (SELECT COUNT(*) FROM loans
          WHERE group_id = ?1 AND status IN ('active', 'defaulted'))
          AS active_loans,
        (SELECT COUNT(*) FROM members
          WHERE group_id = ?1 AND is_active = 1) AS member_count,
        (SELECT COUNT(*) FROM meetings
          WHERE group_id = ?1
            AND date > (SELECT cycle_start_date FROM groups WHERE id = ?1))
          AS meeting_count,
        (SELECT COALESCE(SUM(f.amount), 0) FROM fines f
          JOIN meetings m ON m.id = f.meeting_id
          WHERE m.group_id = ?1
            AND f.created_at > (SELECT cycle_start_date FROM groups WHERE id = ?1))
          AS fines_collected,
        -- The social fund as it STANDS, like the server's statement: every
        -- contribution and fine ever paid in, less welfare paid out and any
        -- welfare shared out. It is a running fund, not a cycle's takings:
        -- a float the group kept at share-out is still in it.
        (SELECT COALESCE(SUM(sf.amount), 0) FROM social_fund_entries sf
          JOIN meetings m ON m.id = sf.meeting_id
          WHERE m.group_id = ?1)
        + (SELECT COALESCE(SUM(f.amount), 0) FROM fines f
          JOIN meetings m ON m.id = f.meeting_id
          WHERE m.group_id = ?1)
        - (SELECT COALESCE(SUM(w.amount), 0) FROM welfare_expenses w
          WHERE w.group_id = ?1)
        - (SELECT COALESCE(SUM(p.welfare_payout), 0) FROM share_out_payouts p
          WHERE p.group_id = ?1)
          AS social_fund
    ''', [groupId]);

    final trendRows = await db.rawQuery('''
      SELECT m.number,
             SUM(COALESCE(sp.total, 0))
               OVER (ORDER BY m.number) AS cumulative
      FROM meetings m
      LEFT JOIN (SELECT meeting_id, SUM(amount) AS total
                 FROM share_purchases
                 WHERE created_at > (SELECT cycle_start_date FROM groups WHERE id = ?1)
                 GROUP BY meeting_id) sp
        ON sp.meeting_id = m.id
      WHERE m.group_id = ?1
        AND m.date > (SELECT cycle_start_date FROM groups WHERE id = ?1)
      ORDER BY m.number ASC
    ''', [groupId]);

    final stats = statRows.first;
    final localTotalSavings = (stats['total_savings'] as num).toDouble();
    final localActiveLoans = (stats['active_loans'] as num).toInt();
    final localMemberCount = (stats['member_count'] as num).toInt();
    final localMeetingCount = (stats['meeting_count'] as num).toInt();
    final localFinesCollected = (stats['fines_collected'] as num).toDouble();
    final localSocialFund = (stats['social_fund'] as num).toDouble();

    final bookIsEmpty = localMeetingCount == 0;
    final server = bookIsEmpty ? remoteGroup : null;
    final totalSavings = server != null
        ? (server.totalSavingsCents != null
              ? server.totalSavingsCents! / 100
              : server.savingsBalance)
        : localTotalSavings;
    final socialFund = server != null
        ? (server.totalSocialFundCents != null
              ? server.totalSocialFundCents! / 100
              : server.socialFundBalance)
        : localSocialFund;
    final memberCount = localMemberCount == 0 && (remoteGroup?.memberCount ?? 0) > 0
        ? remoteGroup!.memberCount!
        : localMemberCount;
    final meetingCount = server != null && (server.meetingCount ?? 0) > 0
        ? server.meetingCount!
        : localMeetingCount;

    return DashboardSummary(
      totalSavings: totalSavings,
      activeLoans: localActiveLoans,
      memberCount: memberCount,
      meetingCount: meetingCount,
      finesCollected: localFinesCollected,
      socialFund: socialFund,
      trend: trendRows
          .map((row) => SavingsTrendPoint(
                meetingNumber: (row['number'] as num).toInt(),
                cumulativeSavings: (row['cumulative'] as num).toDouble(),
              ))
          .toList(),
    );
  }
}
