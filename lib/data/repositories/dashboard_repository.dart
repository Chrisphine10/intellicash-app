import '../../core/database/app_database.dart';
import '../models/dashboard_summary.dart';

class DashboardRepository {
  DashboardRepository(this._db);

  final AppDatabase _db;

  Future<DashboardSummary> summary(String groupId) async {
    final db = await _db.database;
    final statRows = await db.rawQuery('''
      SELECT
        (SELECT COALESCE(SUM(sp.amount), 0) FROM share_purchases sp
          JOIN meetings m ON m.id = sp.meeting_id
          WHERE m.group_id = ?1) AS total_savings,
        (SELECT COUNT(*) FROM loans
          WHERE group_id = ?1 AND status IN ('active', 'defaulted'))
          AS active_loans,
        (SELECT COUNT(*) FROM members
          WHERE group_id = ?1 AND is_active = 1) AS member_count,
        (SELECT COUNT(*) FROM meetings WHERE group_id = ?1) AS meeting_count,
        (SELECT COALESCE(SUM(f.amount), 0) FROM fines f
          JOIN meetings m ON m.id = f.meeting_id
          WHERE m.group_id = ?1) AS fines_collected,
        (SELECT COALESCE(SUM(sf.amount), 0) FROM social_fund_entries sf
          JOIN meetings m ON m.id = sf.meeting_id
          WHERE m.group_id = ?1) AS social_fund
    ''', [groupId]);

    final trendRows = await db.rawQuery('''
      SELECT m.number,
             SUM(COALESCE(sp.total, 0))
               OVER (ORDER BY m.number) AS cumulative
      FROM meetings m
      LEFT JOIN (SELECT meeting_id, SUM(amount) AS total
                 FROM share_purchases GROUP BY meeting_id) sp
        ON sp.meeting_id = m.id
      WHERE m.group_id = ?
      ORDER BY m.number ASC
    ''', [groupId]);

    final stats = statRows.first;
    return DashboardSummary(
      totalSavings: (stats['total_savings'] as num).toDouble(),
      activeLoans: (stats['active_loans'] as num).toInt(),
      memberCount: (stats['member_count'] as num).toInt(),
      meetingCount: (stats['meeting_count'] as num).toInt(),
      finesCollected: (stats['fines_collected'] as num).toDouble(),
      socialFund: (stats['social_fund'] as num).toDouble(),
      trend: trendRows
          .map((row) => SavingsTrendPoint(
                meetingNumber: (row['number'] as num).toInt(),
                cumulativeSavings: (row['cumulative'] as num).toDouble(),
              ))
          .toList(),
    );
  }
}
