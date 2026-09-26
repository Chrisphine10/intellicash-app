import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../models/enums.dart';
import '../models/member.dart';
import 'loan_repository.dart';
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

  /// Members edited on this phone after write-log entry [afterQueueId], in the
  /// order they were last edited, with the newest entry id as the next
  /// watermark.
  ///
  /// Read from the local write log rather than a "dirty" flag: every edit is
  /// already logged there atomically with the edit itself, so nothing new has
  /// to be remembered, and only changes MADE ON THIS PHONE are sent — a role
  /// changed on the web is not overwritten by a phone that never touched it.
  Future<({List<Member> members, int watermark})> editedSince(int afterQueueId) async {
    final db = await _db.database;
    final rows = await db.query(
      'sync_queue',
      columns: ['id', 'entity_id'],
      where: "entity_type = 'member' AND operation = 'update' AND id > ?",
      whereArgs: [afterQueueId],
      orderBy: 'id ASC',
    );
    if (rows.isEmpty) return (members: const <Member>[], watermark: afterQueueId);

    final lastEdit = <String, int>{};
    for (final row in rows) {
      lastEdit[row['entity_id'] as String] = row['id'] as int;
    }
    final ordered = lastEdit.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    final members = <Member>[];
    for (final entry in ordered) {
      final found = await db.query('members', where: 'id = ?', whereArgs: [entry.key], limit: 1);
      if (found.isNotEmpty) members.add(Member.fromMap(found.first));
    }
    return (members: members, watermark: rows.last['id'] as int);
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

  /// One member's contribution totals beyond savings: social fund and fines.
  /// Backs the per-member report the group generates. With [since] (the
  /// cycle's start) they are this cycle's, the same period as the savings
  /// beside them on the report and as the server's passbook; without it,
  /// every cycle.
  Future<({double social, double fines})> contributionTotals(
      String memberId, {DateTime? since}) async {
    final db = await _db.database;
    final after = since?.toIso8601String() ?? '';
    final rows = await db.rawQuery('''
      SELECT
        (SELECT COALESCE(SUM(amount), 0) FROM social_fund_entries
          WHERE member_id = ?1 AND created_at > ?2) AS social,
        (SELECT COALESCE(SUM(amount), 0) FROM fines
          WHERE member_id = ?1 AND created_at > ?2) AS fines
    ''', [memberId, after]);
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
        COALESCE(l.defaulted_count, 0) AS defaulted_count
      FROM members m
      LEFT JOIN (
        SELECT member_id,
               SUM(amount) AS total_savings,
               SUM(shares) AS total_shares
        FROM share_purchases
        WHERE created_at > (SELECT cycle_start_date FROM groups WHERE id = ?1)
        GROUP BY member_id
      ) s ON s.member_id = m.id
      LEFT JOIN (
        SELECT ln.member_id,
               SUM(CASE WHEN ln.status = 'defaulted' THEN 1 ELSE 0 END)
                 AS defaulted_count
        FROM loans ln
        GROUP BY ln.member_id
      ) l ON l.member_id = m.id
      WHERE m.group_id = ?1 AND m.is_active = 1
      ORDER BY m.name COLLATE NOCASE ASC
    ''', [groupId]);

    // Owed today on open loans, month by month (the server's rule), per member.
    final now = DateTime.now();
    final owedCents = <String, int>{};
    for (final loan in await LoanRepository.openLoans(db, groupId)) {
      owedCents[loan.memberId] =
          (owedCents[loan.memberId] ?? 0) + loan.positionAsOf(now).outstandingCents;
    }

    return rows.map((row) {
      final member = Member.fromMap(row);
      return MemberFinancials(
        member: member,
        totalSavings: (row['total_savings'] as num).toDouble(),
        totalShares: (row['total_shares'] as num).toInt(),
        activeLoanBalance: (owedCents[member.id] ?? 0) / 100,
        hasDefaultedLoan: (row['defaulted_count'] as num) > 0,
      );
    }).toList();
  }

  /// Attendance rate, 0..1: across all meetings, or (with [since]) at the
  /// meetings held since then - the cycle, for the member's report.
  Future<double> attendanceRate(String memberId, {DateTime? since}) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS total, SUM(a.present) AS attended
      FROM attendance a JOIN meetings m ON m.id = a.meeting_id
      WHERE a.member_id = ?1 AND m.date > ?2
    ''', [memberId, since?.toIso8601String() ?? '']);
    final total = (rows.first['total'] as num?)?.toInt() ?? 0;
    if (total == 0) return 0;
    final attended = (rows.first['attended'] as num?)?.toInt() ?? 0;
    return attended / total;
  }
}
