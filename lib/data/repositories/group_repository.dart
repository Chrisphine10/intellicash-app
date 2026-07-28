import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../models/enums.dart';
import '../models/group.dart';
import '../models/member.dart';
import 'sync_repository.dart';

class GroupRepository {
  GroupRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// The device manages one group (the group leader's phone).
  Future<Group?> currentGroup() async {
    final db = await _db.database;
    final rows = await db.query('groups', limit: 1);
    if (rows.isEmpty) return null;
    return Group.fromMap(rows.first);
  }

  /// Creates the group and its founding members in one transaction.
  Future<Group> createGroup({
    required String name,
    required int cycleNumber,
    required SavingsMode savingsMode,
    required double shareValue,
    required int maxSharesPerMeeting,
    required double socialFundAmount,
    required double interestRate,
    required InterestType interestType,
    required double loanMultiplier,
    required int defaultLoanTermMonths,
    required MeetingFrequency meetingFrequency,
    required List<int> meetingDays,
    required List<String> memberNames,
  }) async {
    final now = DateTime.now();
    final group = Group(
      id: _uuid.v4(),
      name: name.trim(),
      cycleNumber: cycleNumber,
      cycleStartDate: now,
      savingsMode: savingsMode,
      shareValue: shareValue,
      maxSharesPerMeeting: maxSharesPerMeeting,
      socialFundAmount: socialFundAmount,
      interestRate: interestRate,
      interestType: interestType,
      loanMultiplier: loanMultiplier,
      defaultLoanTermMonths: defaultLoanTermMonths,
      meetingFrequency: meetingFrequency,
      meetingDays: (meetingDays.toList()..sort()),
      createdAt: now,
      updatedAt: now,
    );

    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert('groups', group.toMap());
      await SyncRepository.enqueue(
        txn,
        entityType: 'group',
        entityId: group.id,
        operation: 'create',
        payload: group.toMap(),
      );
      for (final memberName in memberNames) {
        final trimmed = memberName.trim();
        if (trimmed.isEmpty) continue;
        final member = Member(
          id: _uuid.v4(),
          groupId: group.id,
          name: trimmed,
          joinedAt: now,
        );
        await txn.insert('members', member.toMap());
        await SyncRepository.enqueue(
          txn,
          entityType: 'member',
          entityId: member.id,
          operation: 'create',
          payload: member.toMap(),
        );
      }
    });
    return group;
  }

  Future<void> updateGroup(Group group) async {
    final updated = group.copyWith(updatedAt: DateTime.now());
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update(
        'groups',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );
      await SyncRepository.enqueue(
        txn,
        entityType: 'group',
        entityId: updated.id,
        operation: 'update',
        payload: updated.toMap(),
      );
    });
  }
}
