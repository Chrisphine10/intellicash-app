import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Money in the box is a physical cash count: what came in, less what left.
/// Welfare paid to a member left the box too, and used to be forgotten.
void main() {
  late Directory tempDir;
  late AppDatabase db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_cash_box');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
  });

  tearDown(() async {
    await db.close();
    AppDatabase.overrideFactory = null;
    AppDatabase.overridePath = null;
    await tempDir.delete(recursive: true);
  });

  test('welfare paid out comes off the cash box', () async {
    final group = await GroupRepository(db).createGroup(
      name: 'Box Group',
      cycleNumber: 1,
      savingsMode: SavingsMode.fixed,
      shareValue: 100,
      maxSharesPerMeeting: 10,
      socialFundAmount: 50,
      interestRate: 10,
      interestType: InterestType.flat,
      loanMultiplier: 3,
      defaultLoanTermMonths: 1,
      meetingFrequency: MeetingFrequency.weekly,
      meetingDays: const [DateTime.monday],
      memberNames: const ['Akinyi'],
    );
    final member = (await MemberRepository(db).membersForGroup(group.id)).single;
    final meetings = MeetingRepository(db);
    final meeting = await meetings.startMeeting(group);
    await meetings.recordSharePurchase(
        meeting: meeting, group: group, memberId: member.id, shares: 5); // 500 in
    expect(await meetings.cashBoxBalance(group.id), 500);

    final raw = await db.database;
    await raw.insert('welfare_expenses', {
      'id': 'w-1',
      'group_id': group.id,
      'meeting_id': meeting.id,
      'cycle_number': 1,
      'category': 'MEDICAL',
      'amount': 120.0,
      'payee_member_id': member.id,
      'created_at': DateTime.now().toIso8601String(),
    });

    expect(await meetings.cashBoxBalance(group.id), 380);
  });
}
