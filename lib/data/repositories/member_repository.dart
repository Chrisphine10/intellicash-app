import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../models/enums.dart';
import '../models/member.dart';
import 'sync_repository.dart';

class MemberRepository {
  MemberRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<Member>> membersForGroup(String groupId,
      {bool activeOnly = true}) async {
    final db = await _db.database;
    final rows = await db.query(
      'members',
      where: activeOnly ? 'group_id = ? AND is_active = 1' : 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(Member.fromMap).toList();
  }

  Future<Member> addMember({
    required String groupId,
    required String name,
    String? phone,
    MemberRole role = MemberRole.member,
  }) async {
    final member = Member(
      id: _uuid.v4(),
      groupId: groupId,
      name: name.trim(),
      phone: phone?.trim().isEmpty ?? true ? null : phone!.trim(),
      role: role,
      joinedAt: DateTime.now(),
    );
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert('members', member.toMap());
      await SyncRepository.enqueue(
        txn,
        entityType: 'member',
        entityId: member.id,
        operation: 'create',
        payload: member.toMap(),
      );
    });
    return member;
  }

  Future<void> updateMember(Member member) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'members',
        member.toMap(),
        where: 'id = ?',
        whereArgs: [member.id],
      );
      await SyncRepository.enqueue(
        txn,
        entityType: 'member',
        entityId: member.id,
        operation: 'update',
        payload: member.toMap(),
      );
    });
  }

  /// One member's lifetime contribution totals beyond savings: social fund
  /// and fines. Backs the per-member report the group generates.
  Future<({double social, double fines})> contributionTotals(
      String memberId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        (SELECT COALESCE(SUM(amount), 0) FROM social_fund_entries
          WHERE member_id = ?) AS social,
        (SELECT COALESCE(SUM(amount), 0) FROM fines
          WHERE member_id = ?) AS fines
    ''', [memberId, memberId]);
    final row = rows.first;
    return (
      social: ((row['social'] ?? 0) as num).toDouble(),
      fines: ((row['fines'] ?? 0) as num).toDouble(),
    );
  }

  /// Sets (or clears, with null) a member's meeting-PIN hash. The hash stays
  /// on this phone — it is deliberately never queued for cloud sync.
  Future<void> setPinHash(String memberId, String? pinHash) async {
    final db = await _db.database;
    await db.update(
      'members',
      {'pin_hash': pinHash},
      where: 'id = ?',
      whereArgs: [memberId],
    );
  }

  /// Directory view: every active member with savings and loan position.
  Future<List<MemberFinancials>> financialsForGroup(String groupId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        m.*,
        COALESCE(s.total_savings, 0)  AS total_savings,
        COALESCE(s.total_shares, 0)   AS total_shares,
        COALESCE(l.active_balance, 0) AS active_balance,
        COALESCE(l.defaulted_count, 0) AS defaulted_count
      FROM members m
      LEFT JOIN (
        SELECT member_id,
               SUM(amount) AS total_savings,
               SUM(shares) AS total_shares
        FROM share_purchases
        GROUP BY member_id
      ) s ON s.member_id = m.id
      LEFT JOIN (
        SELECT ln.member_id,
               SUM(CASE WHEN ln.status IN ('active', 'defaulted')
                   THEN ln.total_due - COALESCE(r.repaid, 0) ELSE 0 END)
                 AS active_balance,
               SUM(CASE WHEN ln.status = 'defaulted' THEN 1 ELSE 0 END)
                 AS defaulted_count
        FROM loans ln
        LEFT JOIN (
          SELECT loan_id, SUM(amount) AS repaid
          FROM loan_repayments
          GROUP BY loan_id
        ) r ON r.loan_id = ln.id
        GROUP BY ln.member_id
      ) l ON l.member_id = m.id
      WHERE m.group_id = ? AND m.is_active = 1
      ORDER BY m.name COLLATE NOCASE ASC
    ''', [groupId]);

    return rows.map((row) {
      return MemberFinancials(
        member: Member.fromMap(row),
        totalSavings: (row['total_savings'] as num).toDouble(),
        totalShares: (row['total_shares'] as num).toInt(),
        activeLoanBalance: (row['active_balance'] as num).toDouble(),
        hasDefaultedLoan: (row['defaulted_count'] as num) > 0,
      );
    }).toList();
  }

  /// Attendance rate across all meetings, 0..1, for the member detail screen.
  Future<double> attendanceRate(String memberId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS total, SUM(present) AS attended
      FROM attendance
      WHERE member_id = ?
    ''', [memberId]);
    final total = (rows.first['total'] as num?)?.toInt() ?? 0;
    if (total == 0) return 0;
    final attended = (rows.first['attended'] as num?)?.toInt() ?? 0;
    return attended / total;
  }
}
