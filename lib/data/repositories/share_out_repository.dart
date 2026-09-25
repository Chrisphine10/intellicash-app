import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/domain_exception.dart';
import '../../core/utils/share_out_calculator.dart';
import '../models/enums.dart';
import '../models/group.dart';
import 'loan_repository.dart';
import 'sync_repository.dart';

/// One member's stored share-out payout.
class ShareOutPayout {
  const ShareOutPayout({
    required this.memberName,
    required this.shareAmount,
    required this.grossPayout,
    required this.welfarePayout,
    required this.loanOffset,
    required this.netPayout,
  });

  final String memberName;
  final double shareAmount;
  final double grossPayout;
  final double welfarePayout;
  final double loanOffset;
  final double netPayout;
}

/// A completed share-out event read back from history.
class ShareOutRecord {
  const ShareOutRecord({
    required this.cycleNumber,
    required this.date,
    required this.payouts,
  });

  final int cycleNumber;
  final DateTime date;
  final List<ShareOutPayout> payouts;

  double get totalNet => payouts.fold(0, (s, p) => s + p.netPayout);
}

/// Reads the data for an end-of-cycle share-out and commits it: recording the
/// payouts, settling outstanding loans (they are netted off each member's
/// payout), and rolling the group into a fresh cycle.
///
/// Every figure is scoped to the **current cycle** (activity strictly after
/// `group.cycleStartDate`), so a share-out only distributes what was
/// accumulated since the last one — matching the backend's method.
class ShareOutRepository {
  ShareOutRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  static int _cents(num kes) => (kes * 100).round();
  static double _kes(int cents) => cents / 100;

  /// Computes the share-out preview for the group's current cycle.
  Future<ShareOutResult> preview(
    Group group, {
    bool distributeWelfare = false,
  }) async {
    final db = await _db.database;
    final gid = group.id;
    final start = group.cycleStartDate.toIso8601String();

    // Per-member share contributions this cycle.
    final memberRows = await db.rawQuery('''
      SELECT m.id AS member_id, m.name AS member_name,
             COALESCE(sp.total, 0) AS shares
      FROM members m
      LEFT JOIN (
        SELECT sp.member_id, SUM(sp.amount) AS total
        FROM share_purchases sp
        JOIN meetings mt ON mt.id = sp.meeting_id
        WHERE mt.group_id = ?1 AND sp.created_at > ?2
        GROUP BY sp.member_id
      ) sp ON sp.member_id = m.id
      WHERE m.group_id = ?1 AND m.is_active = 1
      ORDER BY m.name COLLATE NOCASE
    ''', [gid, start]);

    // Fund totals used to size the distributable pool.
    final totalsRow = (await db.rawQuery('''
      SELECT
        (SELECT COALESCE(SUM(sp.amount), 0) FROM share_purchases sp
           JOIN meetings mt ON mt.id = sp.meeting_id
           WHERE mt.group_id = ?1 AND sp.created_at > ?2) AS share_capital,
        (SELECT COALESCE(SUM(r.amount), 0) FROM loan_repayments r
           JOIN loans l ON l.id = r.loan_id
           WHERE l.group_id = ?1 AND r.paid_at > ?2) AS repayments,
        (SELECT COALESCE(SUM(l.principal), 0) FROM loans l
           WHERE l.group_id = ?1 AND l.disbursed_at > ?2) AS disbursed,
        (SELECT COALESCE(SUM(f.amount), 0) FROM fines f
           JOIN meetings mt ON mt.id = f.meeting_id
           WHERE mt.group_id = ?1 AND f.created_at > ?2) AS fines,
        (SELECT COALESCE(SUM(s.amount), 0) FROM social_fund_entries s
           JOIN meetings mt ON mt.id = s.meeting_id
           WHERE mt.group_id = ?1 AND s.created_at > ?2) AS social,
        (SELECT COALESCE(SUM(w.amount), 0) FROM welfare_expenses w
           WHERE w.group_id = ?1 AND w.created_at > ?2) AS welfare_spent
    ''', [gid, start])).first;

    // What every member owes TODAY on every open loan — including one carried
    // over from an earlier cycle, which used to be left out of the netting and
    // never settled. Month by month, the same rule as the server.
    final now = DateTime.now();
    final owedCents = <String, int>{};
    for (final loan in await LoanRepository.openLoans(db, gid)) {
      owedCents[loan.memberId] =
          (owedCents[loan.memberId] ?? 0) + loan.positionAsOf(now).outstandingCents;
    }

    final members = <ShareOutMember>[];
    var totalOutstandingCents = 0;
    for (final row in memberRows) {
      final outstanding = owedCents[row['member_id'] as String] ?? 0;
      totalOutstandingCents += outstanding;
      members.add(ShareOutMember(
        memberId: row['member_id'] as String,
        memberName: row['member_name'] as String,
        shareCents: _cents((row['shares'] as num).toDouble()),
        outstandingCents: outstanding,
      ));
    }

    final shareCapitalCents = _cents((totalsRow['share_capital'] as num).toDouble());
    final repaymentsCents = _cents((totalsRow['repayments'] as num).toDouble());
    final disbursedCents = _cents((totalsRow['disbursed'] as num).toDouble());
    // What is LEFT, not what came in. Welfare is spent down during the
    // cycle; distributing gross contributions would hand out money the
    // group has already paid to a hospital or a bereaved family.
    final welfareSpentCents =
        _cents((totalsRow['welfare_spent'] as num).toDouble());
    final welfareCents = (_cents((totalsRow['fines'] as num).toDouble()) +
            _cents((totalsRow['social'] as num).toDouble())) -
        welfareSpentCents;

    // Loan-fund cash (C) = capital + repayments − disbursements.
    // Group equity / distributable pool (E) = C + outstanding receivables.
    // E resolves to: share capital + all interest charged this cycle.
    final poolCents =
        shareCapitalCents + repaymentsCents - disbursedCents + totalOutstandingCents;

    return ShareOutCalculator.compute(
      members: members,
      savingsPoolCents: poolCents < 0 ? 0 : poolCents,
      shareCapitalCents: shareCapitalCents,
      // Clamped: an overspent welfare fund is a reconciliation problem, not a
      // negative pool to divide among members.
      welfarePoolCents: welfareCents < 0 ? 0 : welfareCents,
      distributeWelfare: distributeWelfare,
    );
  }

  /// The number of a meeting that is still open in this group, or null.
  ///
  /// A share-out draws a line under the cycle. A meeting still being recorded
  /// has savings and loans on both sides of that line, so the cycle cannot be
  /// shared out until it is closed. It also keeps the records that reach the
  /// online record in order: a cycle's meetings first, then its share-out.
  Future<int?> openMeetingNumber(String groupId) async {
    final db = await _db.database;
    final rows = await db.query(
      'meetings',
      columns: ['number'],
      where: 'group_id = ? AND status = ?',
      whereArgs: [groupId, MeetingStatus.open.name],
      orderBy: 'number DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['number'] as int;
  }

  /// Commits the share-out: writes the payout records, settles the cycle's
  /// outstanding loans (netted into the payouts), and advances the group to
  /// the next cycle. Returns the group with its bumped cycle.
  Future<Group> commit(Group group, ShareOutResult result) async {
    if (result.shareCapitalCents <= 0) {
      throw const DomainException(
          'There are no share contributions in this cycle to share out.');
    }
    final openMeeting = await openMeetingNumber(group.id);
    if (openMeeting != null) {
      throw DomainException(
          'Close Meeting #$openMeeting before sharing out. Its savings and '
          'loans belong to this cycle.');
    }
    final db = await _db.database;
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    final nextGroup = group.copyWith(
      cycleNumber: group.cycleNumber + 1,
      cycleStartDate: now,
      updatedAt: now,
    );

    await db.transaction((txn) async {
      // 1. Record each member's payout.
      for (final line in result.lines) {
        final id = _uuid.v4();
        final row = {
          'id': id,
          'group_id': group.id,
          'cycle_number': group.cycleNumber,
          'member_id': line.memberId,
          'member_name': line.memberName,
          'share_amount': _kes(line.shareCents),
          'gross_payout': _kes(line.grossPayoutCents),
          'welfare_payout': _kes(line.welfareCents),
          'loan_offset': _kes(line.loanOffsetCents),
          'net_payout': _kes(line.netPayoutCents),
          'created_at': nowIso,
        };
        await txn.insert('share_out_payouts', row);
        await SyncRepository.enqueue(
          txn,
          entityType: 'share_out_payout',
          entityId: id,
          operation: 'create',
          payload: row,
        );
      }

      // 2. Settle the cycle's outstanding loans — their balance was netted off
      // each member's payout, so record a settling repayment and close them.
      // Every open loan, whichever cycle it was lent in: never carried forward.
      final settleAt = DateTime.parse(nowIso);
      for (final loan in await LoanRepository.openLoans(txn, group.id)) {
        final remainingCents = loan.positionAsOf(settleAt).outstandingCents;
        if (remainingCents > 0) {
          await txn.insert('loan_repayments', {
            'id': _uuid.v4(),
            'loan_id': loan.id,
            'meeting_id': null,
            'amount': remainingCents / 100,
            'paid_at': nowIso,
          });
        }
        await txn.update('loans', {'status': LoanStatus.repaid.name},
            where: 'id = ?', whereArgs: [loan.id]);
      }

      // 3. Roll the group into the next cycle.
      await txn.update('groups', nextGroup.toMap(),
          where: 'id = ?', whereArgs: [group.id]);
    });

    return nextGroup;
  }

  /// Past share-outs for the group, newest cycle first.
  Future<List<ShareOutRecord>> history(String groupId) async {
    final db = await _db.database;
    final rows = await db.query(
      'share_out_payouts',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'cycle_number DESC, member_name COLLATE NOCASE',
    );
    final byCycle = <int, List<Map<String, Object?>>>{};
    for (final row in rows) {
      (byCycle[row['cycle_number'] as int] ??= []).add(row);
    }
    return [
      for (final entry in byCycle.entries)
        ShareOutRecord(
          cycleNumber: entry.key,
          date: DateTime.parse(entry.value.first['created_at'] as String),
          payouts: [
            for (final r in entry.value)
              ShareOutPayout(
                memberName: r['member_name'] as String,
                shareAmount: (r['share_amount'] as num).toDouble(),
                grossPayout: (r['gross_payout'] as num).toDouble(),
                welfarePayout: (r['welfare_payout'] as num).toDouble(),
                loanOffset: (r['loan_offset'] as num).toDouble(),
                netPayout: (r['net_payout'] as num).toDouble(),
              ),
          ],
        ),
    ];
  }
}
