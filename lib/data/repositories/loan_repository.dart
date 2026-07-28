import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/domain_exception.dart';
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
    return rows.map(Loan.fromMap).toList();
  }

  Future<List<Loan>> loansForMember(String memberId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      '$_loanSelect WHERE l.member_id = ? ORDER BY l.disbursed_at DESC',
      [memberId],
    );
    return rows.map(Loan.fromMap).toList();
  }

  Future<Loan?> loanById(String loanId) async {
    final db = await _db.database;
    final rows =
        await db.rawQuery('$_loanSelect WHERE l.id = ?', [loanId]);
    if (rows.isEmpty) return null;
    return Loan.fromMap(rows.first);
  }

  /// Instant eligibility check — computed from savings before the
  /// disbursement form will accept a principal.
  Future<LoanEligibility> eligibility({
    required Group group,
    required String memberId,
  }) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        (SELECT COALESCE(SUM(amount), 0) FROM share_purchases
          WHERE member_id = ?1) AS savings,
        (SELECT COALESCE(SUM(l.total_due), 0) -
                COALESCE(SUM(r.repaid), 0)
         FROM loans l
         LEFT JOIN (SELECT loan_id, SUM(amount) AS repaid
                    FROM loan_repayments GROUP BY loan_id) r
           ON r.loan_id = l.id
         WHERE l.member_id = ?1 AND l.status IN ('active', 'defaulted'))
          AS active_balance
    ''', [memberId]);

    final savings = (rows.first['savings'] as num).toDouble();
    final activeBalance =
        ((rows.first['active_balance'] ?? 0) as num).toDouble();
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

    final repayment = LoanRepayment(
      id: _uuid.v4(),
      loanId: loan.id,
      meetingId: meetingId,
      amount: amount,
      paidAt: DateTime.now(),
    );

    final fullyRepaid = loan.outstanding - amount <= 0.005;
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

    return loan.copyWith(
      status: fullyRepaid ? LoanStatus.repaid : loan.status,
      amountRepaid: loan.amountRepaid + amount,
    );
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
