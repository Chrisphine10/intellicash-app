import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/domain_exception.dart';
import '../../core/utils/loan_accrual.dart';
import '../../core/utils/loan_calculator.dart';
import '../models/enums.dart';
import '../models/group.dart';
import '../models/loan.dart';
import 'sync_repository.dart';

class LoanRepository {
  LoanRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  static const _loanSelect = '''
    SELECT l.*, m.name AS member_name,
           COALESCE(r.repaid, 0) AS amount_repaid
    FROM loans l
    JOIN members m ON m.id = l.member_id
    LEFT JOIN (SELECT loan_id, SUM(amount) AS repaid
               FROM loan_repayments GROUP BY loan_id) r
      ON r.loan_id = l.id
  ''';

  Future<List<Loan>> loansForGroup(String groupId,
      {bool activeOnly = false}) async {
    await _markOverdueAsDefaulted(groupId);
    final db = await _db.database;
    final where = activeOnly
        ? "WHERE l.group_id = ? AND l.status IN ('active', 'defaulted')"
        : 'WHERE l.group_id = ?';
    final rows = await db.rawQuery(
      '$_loanSelect $where ORDER BY l.disbursed_at DESC',
      [groupId],
    );
    return withRepayments(db, rows.map(Loan.fromMap).toList());
  }

  /// Every loan of [groupId] that still owes something, from ANY cycle, with
  /// its repayments. Share-out nets and settles all of them: a loan is never
  /// carried into the next cycle.
  static Future<List<Loan>> openLoans(DatabaseExecutor db, String groupId) async {
    final rows = await db.rawQuery(
      "$_loanSelect WHERE l.group_id = ? AND l.status IN ('active', 'defaulted') ORDER BY l.disbursed_at ASC",
      [groupId],
    );
    return withRepayments(db, rows.map(Loan.fromMap).toList());
  }

  /// Attaches each loan's repayments (amount and date). Balances depend on
  /// when money was repaid, so a loan is not complete without them.
  static Future<List<Loan>> withRepayments(DatabaseExecutor db, List<Loan> loans) async {
    if (loans.isEmpty) return loans;
    final ids = loans.map((loan) => loan.id).toList();
    final byLoan = <String, List<LoanMoney>>{};
    // Chunked: SQLite limits how many values one IN (...) may hold.
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
      final rows = await db.rawQuery(
        'SELECT loan_id, amount, paid_at FROM loan_repayments '
        'WHERE loan_id IN (${List.filled(chunk.length, '?').join(',')}) ORDER BY paid_at ASC',
        chunk,
      );
      for (final row in rows) {
        byLoan.putIfAbsent(row['loan_id'] as String, () => []).add(LoanMoney(
              DateTime.parse(row['paid_at'] as String),
              ((row['amount'] as num).toDouble() * 100).round(),
            ));
      }
    }
    return [for (final loan in loans) loan.copyWith(repayments: byLoan[loan.id] ?? const [])];
  }

  Future<List<Loan>> loansForMember(String memberId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '$_loanSelect WHERE l.member_id = ? ORDER BY l.disbursed_at DESC',
      [memberId],
    );
    return withRepayments(db, rows.map(Loan.fromMap).toList());
  }

  Future<Loan?> loanById(String loanId) async {
    final db = await _db.database;
    final rows =
        await db.rawQuery('$_loanSelect WHERE l.id = ?', [loanId]);
    if (rows.isEmpty) return null;
    return (await withRepayments(db, [Loan.fromMap(rows.first)])).first;
  }

  /// Instant eligibility check — computed from savings before the
  /// disbursement form will accept a principal.
  /// What the group actually has available to LEND, in shillings.
  ///
  /// Distinct from the cash box: social contributions and fines belong to the
  /// welfare fund and are not lending capital. This mirrors the backend's
  /// INTERNAL_LOAN fund exactly — SHARE_PURCHASE and LOAN_REPAYMENT credit it,
  /// INTERNAL_LOAN_DISBURSEMENT debits it — so the phone and the server agree
  /// on the same number rather than each computing its own.
  ///
  /// A member's borrowing headroom is a SEPARATE limit. Both must hold: a
  /// member with headroom still cannot be paid out of an empty fund.
  Future<double> loanFundBalance(String groupId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        (SELECT COALESCE(SUM(sp.amount), 0) FROM share_purchases sp
          JOIN meetings m ON m.id = sp.meeting_id WHERE m.group_id = ?1)
      + (SELECT COALESCE(SUM(r.amount), 0) FROM loan_repayments r
          JOIN loans l ON l.id = r.loan_id WHERE l.group_id = ?1)
      - (SELECT COALESCE(SUM(l.principal), 0) FROM loans l
          WHERE l.group_id = ?1)
      - (SELECT COALESCE(SUM(p.gross_payout), 0)
          FROM share_out_payouts p WHERE p.group_id = ?1)
      AS balance
    ''', [groupId]);
    final balance = ((rows.first['balance'] ?? 0) as num).toDouble();
    // Clamp: a negative lending fund is not a thing a treasurer can act on,
    // and it would make "short by" arithmetic read strangely.
    return balance < 0 ? 0 : balance;
  }

  Future<LoanEligibility> eligibility({
    required Group group,
    required String memberId,
  }) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS savings FROM share_purchases
        WHERE member_id = ?1 AND created_at > ?2
    ''', [memberId, group.cycleStartDate.toIso8601String()]);

    final savings = (rows.first['savings'] as num).toDouble();
    // What the member owes today on loans still open — interest so far, not
    // the full-term maximum (the same figure the server holds).
    final now = DateTime.now();
    final open = (await loansForMember(memberId))
        .where((loan) => loan.status == LoanStatus.active || loan.status == LoanStatus.defaulted);
    final activeBalance =
        open.fold<int>(0, (sum, loan) => sum + loan.positionAsOf(now).outstandingCents) / 100;
    final maxLoan = savings * group.loanMultiplier;

    return LoanEligibility(
      totalSavings: savings,
      activeLoanBalance: activeBalance,
      maxLoan: maxLoan,
      availableAmount: LoanCalculator.availableAmount(
        totalSavings: savings,
        multiplier: group.loanMultiplier,
        activeLoanBalance: activeBalance,
      ),
    );
  }

  /// Disburses after re-checking eligibility inside the write.
  Future<Loan> disburse({
    required Group group,
    required String memberId,
    required double principal,
    required DateTime dueDate,
    String? meetingId,
  }) async {
    if (principal <= 0) {
      throw const DomainException('Principal must be above zero.');
    }
    final check = await eligibility(group: group, memberId: memberId);
    if (principal > check.availableAmount) {
      throw DomainException(
          'Amount exceeds the available limit for this member.');
    }

    final now = DateTime.now();
    final termMonths = _monthsBetween(now, dueDate);
    final loan = Loan(
      id: _uuid.v4(),
      groupId: group.id,
      memberId: memberId,
      meetingId: meetingId,
      principal: principal,
      interestRate: group.interestRate,
      interestType: group.interestType,
      totalDue: LoanCalculator.totalDue(
        principal: principal,
        monthlyRatePercent: group.interestRate,
        termMonths: termMonths,
        type: group.interestType,
      ),
      disbursedAt: now,
      dueDate: dueDate,
      status: LoanStatus.active,
      createdAt: now,
    );

    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert('loans', loan.toMap());
      await SyncRepository.enqueue(
        txn,
        entityType: 'loan',
        entityId: loan.id,
        operation: 'disburse',
        payload: loan.toMap(),
      );
    });
    return loan;
  }

  /// Records a repayment; the loan flips to repaid the moment the
  /// outstanding balance reaches zero.
  Future<Loan> repay({
    required Loan loan,
    required double amount,
    String? meetingId,
  }) async {
    if (amount <= 0) {
      throw const DomainException('Repayment must be above zero.');
    }
    if (loan.status == LoanStatus.repaid) {
      throw const DomainException('This loan is already repaid.');
    }
    if (amount > loan.outstanding) {
      throw DomainException(
          'Repayment exceeds the outstanding balance of this loan.');
    }

    final paidAt = DateTime.now();
    final repayment = LoanRepayment(
      id: _uuid.v4(),
      loanId: loan.id,
      meetingId: meetingId,
      amount: amount,
      paidAt: paidAt,
    );

    final after = loan.copyWith(
      amountRepaid: loan.amountRepaid + amount,
      repayments: [...loan.repayments, LoanMoney(paidAt, (amount * 100).round())],
    );
    final fullyRepaid = after.positionAsOf(paidAt).settled;
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert('loan_repayments', repayment.toMap());
      if (fullyRepaid) {
        await txn.update(
          'loans',
          {'status': LoanStatus.repaid.name},
          where: 'id = ?',
          whereArgs: [loan.id],
        );
      }
      await SyncRepository.enqueue(
        txn,
        entityType: 'loan_repayment',
        entityId: repayment.id,
        operation: 'create',
        payload: repayment.toMap(),
      );
    });

    return after.copyWith(status: fullyRepaid ? LoanStatus.repaid : loan.status);
  }

  Future<List<LoanRepayment>> repaymentsForLoan(String loanId) async {
    final db = await _db.database;
    final rows = await db.query(
      'loan_repayments',
      where: 'loan_id = ?',
      whereArgs: [loanId],
      orderBy: 'paid_at DESC',
    );
    return rows.map(LoanRepayment.fromMap).toList();
  }

  /// Active loans past their due date become defaulted — evaluated on read
  /// so the status is always current when a screen loads.
  Future<void> _markOverdueAsDefaulted(String groupId) async {
    final db = await _db.database;
    await db.update(
      'loans',
      {'status': LoanStatus.defaulted.name},
      where: 'group_id = ? AND status = ? AND due_date < ?',
      whereArgs: [
        groupId,
        LoanStatus.active.name,
        DateTime.now().toIso8601String(),
      ],
    );
  }

  static int _monthsBetween(DateTime from, DateTime to) {
    final months =
        (to.year - from.year) * 12 + to.month - from.month + (to.day >= from.day ? 0 : -1);
    return months < 1 ? 1 : months;
  }
}
