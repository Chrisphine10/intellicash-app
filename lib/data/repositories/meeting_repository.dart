import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/domain_exception.dart';
import '../models/enums.dart';
import '../models/group.dart';
import '../models/meeting.dart';
import '../models/transactions.dart';
import 'sync_repository.dart';

/// A meetings-list row: the meeting plus what it collected.
class MeetingListItem {
  const MeetingListItem({required this.meeting, required this.collected});

  final Meeting meeting;
  final double collected;
}

class MeetingRepository {
  MeetingRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<MeetingListItem>> meetingsForGroup(String groupId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT m.*,
        COALESCE(sp.total, 0) + COALESCE(f.total, 0) +
        COALESCE(sf.total, 0) + COALESCE(r.total, 0) AS collected
      FROM meetings m
      LEFT JOIN (SELECT meeting_id, SUM(amount) AS total
                 FROM share_purchases GROUP BY meeting_id) sp
        ON sp.meeting_id = m.id
      LEFT JOIN (SELECT meeting_id, SUM(amount) AS total
                 FROM fines GROUP BY meeting_id) f
        ON f.meeting_id = m.id
      LEFT JOIN (SELECT meeting_id, SUM(amount) AS total
                 FROM social_fund_entries GROUP BY meeting_id) sf
        ON sf.meeting_id = m.id
      LEFT JOIN (SELECT meeting_id, SUM(amount) AS total
                 FROM loan_repayments GROUP BY meeting_id) r
        ON r.meeting_id = m.id
      WHERE m.group_id = ?
      ORDER BY m.number DESC
    ''', [groupId]);

    return rows
        .map((row) => MeetingListItem(
              meeting: Meeting.fromMap(row),
              collected: (row['collected'] as num).toDouble(),
            ))
        .toList();
  }

  Future<Meeting?> openMeeting(String groupId) async {
    final db = await _db.database;
    final rows = await db.query(
      'meetings',
      where: 'group_id = ? AND status = ?',
      whereArgs: [groupId, MeetingStatus.open.name],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Meeting.fromMap(rows.first);
  }

  /// The group's cash box: everything collected minus everything lent out.
  /// Becomes the next meeting's opening balance.
  Future<double> cashBoxBalance(String groupId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        (SELECT COALESCE(SUM(sp.amount), 0) FROM share_purchases sp
          JOIN meetings m ON m.id = sp.meeting_id WHERE m.group_id = ?1)
      + (SELECT COALESCE(SUM(f.amount), 0) FROM fines f
          JOIN meetings m ON m.id = f.meeting_id WHERE m.group_id = ?1)
      + (SELECT COALESCE(SUM(sf.amount), 0) FROM social_fund_entries sf
          JOIN meetings m ON m.id = sf.meeting_id WHERE m.group_id = ?1)
      + (SELECT COALESCE(SUM(r.amount), 0) FROM loan_repayments r
          JOIN loans l ON l.id = r.loan_id WHERE l.group_id = ?1)
      - (SELECT COALESCE(SUM(l.principal), 0) FROM loans l
          WHERE l.group_id = ?1)
      AS balance
    ''', [groupId]);
    return ((rows.first['balance'] ?? 0) as num).toDouble();
  }

  /// Starts the next meeting: sequence number auto-increments, opening
  /// balance snapshots the cash box, and an attendance row is created for
  /// every active member (absent until tapped).
  ///
  /// [unlockedBy] records which members' PINs opened the 3-key gate — part
  /// of the meeting's permanent audit trail.
  Future<Meeting> startMeeting(Group group, {List<String>? unlockedBy}) async {
    final existing = await openMeeting(group.id);
    if (existing != null) {
      throw DomainException(
          'Meeting #${existing.number} is still in progress. Close it first.');
    }

    final db = await _db.database;
    final opening = await cashBoxBalance(group.id);

    return db.transaction((txn) async {
      final numberRows = await txn.rawQuery(
        'SELECT COALESCE(MAX(number), 0) + 1 AS next FROM meetings '
        'WHERE group_id = ?',
        [group.id],
      );
      final meeting = Meeting(
        id: _uuid.v4(),
        groupId: group.id,
        number: (numberRows.first['next'] as num).toInt(),
        date: DateTime.now(),
        openingBalance: opening,
        status: MeetingStatus.open,
      );
      await txn.insert(
        'meetings',
        meeting.toMap()
          ..['unlocked_by'] =
              unlockedBy == null ? null : jsonEncode(unlockedBy),
      );

      final members = await txn.query(
        'members',
        columns: ['id'],
        where: 'group_id = ? AND is_active = 1',
        whereArgs: [group.id],
      );
      final batch = txn.batch();
      for (final member in members) {
        batch.insert('attendance', {
          'meeting_id': meeting.id,
          'member_id': member['id'],
          'present': 0,
        });
      }
      await batch.commit(noResult: true);

      await SyncRepository.enqueue(
        txn,
        entityType: 'meeting',
        entityId: meeting.id,
        operation: 'create',
        payload: meeting.toMap(),
      );
      return meeting;
    });
  }

  Future<Map<String, bool>> attendanceMap(String meetingId) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance',
      where: 'meeting_id = ?',
      whereArgs: [meetingId],
    );
    return {
      for (final row in rows)
        row['member_id'] as String: (row['present'] as int) == 1,
    };
  }

  Future<void> setAttendance({
    required Meeting meeting,
    required String memberId,
    required bool present,
  }) async {
    _requireOpen(meeting);
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert(
        'attendance',
        {
          'meeting_id': meeting.id,
          'member_id': memberId,
          'present': present ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await SyncRepository.enqueue(
        txn,
        entityType: 'attendance',
        entityId: '${meeting.id}:$memberId',
        operation: 'mark',
        payload: {
          'meeting_id': meeting.id,
          'member_id': memberId,
          'present': present,
        },
      );
    });
  }

  /// Records a share purchase, enforcing the group's savings rules.
  Future<SharePurchase> recordSharePurchase({
    required Meeting meeting,
    required Group group,
    required String memberId,
    required int shares,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    String? paymentReference,
  }) async {
    _requireOpen(meeting);
    if (shares < 1 || shares > group.maxSharesPerMeeting) {
      throw DomainException(
          'Shares must be between 1 and ${group.maxSharesPerMeeting}.');
    }

    final db = await _db.database;
    final purchased = await db.rawQuery(
      'SELECT COALESCE(SUM(shares), 0) AS bought FROM share_purchases '
      'WHERE meeting_id = ? AND member_id = ?',
      [meeting.id, memberId],
    );
    final alreadyBought = (purchased.first['bought'] as num).toInt();
    if (alreadyBought + shares > group.maxSharesPerMeeting) {
      final remaining = group.maxSharesPerMeeting - alreadyBought;
      throw DomainException(remaining <= 0
          ? 'Member already holds the maximum '
              '${group.maxSharesPerMeeting} shares this meeting.'
          : 'Only $remaining more share(s) allowed this meeting.');
    }

    final trimmedRef = paymentReference?.trim();
    final purchase = SharePurchase(
      id: _uuid.v4(),
      meetingId: meeting.id,
      memberId: memberId,
      shares: shares,
      unitValue: group.shareValue,
      amount: shares * group.shareValue,
      paymentMethod: paymentMethod,
      paymentReference:
          (trimmedRef == null || trimmedRef.isEmpty) ? null : trimmedRef,
      createdAt: DateTime.now(),
    );
    await db.transaction((txn) async {
      await txn.insert('share_purchases', purchase.toMap());
      await SyncRepository.enqueue(
        txn,
        entityType: 'share_purchase',
        entityId: purchase.id,
        operation: 'create',
        payload: purchase.toMap(),
      );
    });
    return purchase;
  }

  Future<Fine> recordFine({
    required Meeting meeting,
    required String memberId,
    required double amount,
    required String reason,
  }) async {
    _requireOpen(meeting);
    if (amount <= 0) throw const DomainException('Fine must be above zero.');

    final fine = Fine(
      id: _uuid.v4(),
      meetingId: meeting.id,
      memberId: memberId,
      amount: amount,
      reason: reason.trim(),
      createdAt: DateTime.now(),
    );
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert('fines', fine.toMap());
      await SyncRepository.enqueue(
        txn,
        entityType: 'fine',
        entityId: fine.id,
        operation: 'create',
        payload: fine.toMap(),
      );
    });
    return fine;
  }

  /// Collects the standing social-fund amount from every present member who
  /// hasn't contributed yet this meeting. Returns how many were collected.
  Future<int> collectSocialFundFromPresent({
    required Meeting meeting,
    required Group group,
  }) async {
    _requireOpen(meeting);
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT a.member_id FROM attendance a
      WHERE a.meeting_id = ?1 AND a.present = 1
        AND a.member_id NOT IN
          (SELECT member_id FROM social_fund_entries WHERE meeting_id = ?1)
    ''', [meeting.id]);
    if (rows.isEmpty) return 0;

    final now = DateTime.now();
    await db.transaction((txn) async {
      for (final row in rows) {
        final entry = SocialFundEntry(
          id: _uuid.v4(),
          meetingId: meeting.id,
          memberId: row['member_id'] as String,
          amount: group.socialFundAmount,
          createdAt: now,
        );
        await txn.insert('social_fund_entries', entry.toMap());
        await SyncRepository.enqueue(
          txn,
          entityType: 'social_fund_entry',
          entityId: entry.id,
          operation: 'create',
          payload: entry.toMap(),
        );
      }
    });
    return rows.length;
  }

  /// The set of member ids who have paid the social fund in this meeting.
  Future<Set<String>> socialFundPayers(String meetingId) async {
    final db = await _db.database;
    final rows = await db.query('social_fund_entries',
        columns: ['member_id'], where: 'meeting_id = ?', whereArgs: [meetingId]);
    return {for (final r in rows) r['member_id'] as String};
  }

  /// Toggles a single member's social-fund contribution for this meeting. The
  /// amount is the group's standing social-fund amount (the same for everyone),
  /// so the UI only needs a paid / not-paid switch.
  Future<void> setSocialFundPaid({
    required Meeting meeting,
    required Group group,
    required String memberId,
    required bool paid,
  }) async {
    _requireOpen(meeting);
    final db = await _db.database;
    if (paid) {
      final existing = await db.query('social_fund_entries',
          where: 'meeting_id = ? AND member_id = ?',
          whereArgs: [meeting.id, memberId],
          limit: 1);
      if (existing.isNotEmpty) return;
      final entry = SocialFundEntry(
        id: _uuid.v4(),
        meetingId: meeting.id,
        memberId: memberId,
        amount: group.socialFundAmount,
        createdAt: DateTime.now(),
      );
      await db.transaction((txn) async {
        await txn.insert('social_fund_entries', entry.toMap());
        await SyncRepository.enqueue(
          txn,
          entityType: 'social_fund_entry',
          entityId: entry.id,
          operation: 'create',
          payload: entry.toMap(),
        );
      });
    } else {
      await db.delete('social_fund_entries',
          where: 'meeting_id = ? AND member_id = ?',
          whereArgs: [meeting.id, memberId]);
    }
  }

  Future<MeetingTotals> totals(String meetingId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT
        (SELECT COALESCE(SUM(amount), 0) FROM share_purchases
          WHERE meeting_id = ?1) AS shares_amount,
        (SELECT COALESCE(SUM(shares), 0) FROM share_purchases
          WHERE meeting_id = ?1) AS shares_count,
        (SELECT COALESCE(SUM(amount), 0) FROM social_fund_entries
          WHERE meeting_id = ?1) AS social_fund,
        (SELECT COALESCE(SUM(amount), 0) FROM fines
          WHERE meeting_id = ?1) AS fines,
        (SELECT COALESCE(SUM(amount), 0) FROM loan_repayments
          WHERE meeting_id = ?1) AS repayments,
        (SELECT COALESCE(SUM(principal), 0) FROM loans
          WHERE meeting_id = ?1) AS disbursements,
        (SELECT COALESCE(SUM(present), 0) FROM attendance
          WHERE meeting_id = ?1) AS present_count
    ''', [meetingId]);

    final row = rows.first;
    return MeetingTotals(
      sharesAmount: (row['shares_amount'] as num).toDouble(),
      sharesCount: (row['shares_count'] as num).toInt(),
      socialFund: (row['social_fund'] as num).toDouble(),
      fines: (row['fines'] as num).toDouble(),
      loanRepayments: (row['repayments'] as num).toDouble(),
      loanDisbursements: (row['disbursements'] as num).toDouble(),
      presentCount: (row['present_count'] as num).toInt(),
    );
  }

  /// Share purchases this meeting, grouped per member, largest first.
  Future<List<LedgerEntry>> ledger(String meetingId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT sp.member_id, m.name AS member_name,
             SUM(sp.shares) AS shares, SUM(sp.amount) AS amount,
             GROUP_CONCAT(DISTINCT sp.payment_method) AS methods
      FROM share_purchases sp
      JOIN members m ON m.id = sp.member_id
      WHERE sp.meeting_id = ?
      GROUP BY sp.member_id, m.name
      ORDER BY amount DESC, member_name COLLATE NOCASE ASC
    ''', [meetingId]);

    return rows.map((row) {
      final methods = (row['methods'] as String?) ?? '';
      final labels = methods
          .split(',')
          .where((m) => m.isNotEmpty)
          .map((name) =>
              enumFromName(PaymentMethod.values, name, PaymentMethod.cash).label)
          .toSet()
          .join(' · ');
      return LedgerEntry(
        memberId: row['member_id'] as String,
        memberName: row['member_name'] as String,
        shares: (row['shares'] as num).toInt(),
        amount: (row['amount'] as num).toDouble(),
        paymentSummary: labels,
      );
    }).toList();
  }

  /// Locks the meeting. Records inside a closed meeting are immutable —
  /// this is the audit trail the platform promises.
  Future<Meeting> closeMeeting(Meeting meeting) async {
    _requireOpen(meeting);
    final closed = meeting.copyWith(
      status: MeetingStatus.closed,
      closedAt: DateTime.now(),
    );
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'meetings',
        closed.toMap(),
        where: 'id = ?',
        whereArgs: [closed.id],
      );
      await SyncRepository.enqueue(
        txn,
        entityType: 'meeting',
        entityId: closed.id,
        operation: 'close',
        payload: closed.toMap(),
      );
    });
    return closed;
  }

  void _requireOpen(Meeting meeting) {
    if (!meeting.isOpen) {
      throw DomainException(
          'Meeting #${meeting.number} is closed. Its records are locked.');
    }
  }
}
