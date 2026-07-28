import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late GroupRepository groups;
  late MemberRepository members;
  late MeetingRepository meetings;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_socialfund');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
    groups = GroupRepository(db);
    members = MemberRepository(db);
    meetings = MeetingRepository(db);
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('per-member social fund toggle records the fixed amount', () async {
    final group = await groups.createGroup(
      name: 'SF Group',
      cycleNumber: 1,
      savingsMode: SavingsMode.fixed,
      shareValue: 100,
      maxSharesPerMeeting: 10,
      socialFundAmount: 50,
      interestRate: 5,
      interestType: InterestType.flat,
      loanMultiplier: 2,
      defaultLoanTermMonths: 3,
      meetingFrequency: MeetingFrequency.weekly,
      meetingDays: const [DateTime.sunday],
      memberNames: const ['Ann', 'Ben'],
    );
    final roster = await members.membersForGroup(group.id);
    final ann = roster.firstWhere((m) => m.name == 'Ann');
    final meeting = await meetings.startMeeting(group);

    // Mark Ann paid.
    await meetings.setSocialFundPaid(
        meeting: meeting, group: group, memberId: ann.id, paid: true);
    expect(await meetings.socialFundPayers(meeting.id), {ann.id});
    expect((await meetings.totals(meeting.id)).socialFund, 50);

    // Marking paid again is idempotent (still one 50).
    await meetings.setSocialFundPaid(
        meeting: meeting, group: group, memberId: ann.id, paid: true);
    expect((await meetings.totals(meeting.id)).socialFund, 50);

    // Un-toggle removes it.
    await meetings.setSocialFundPaid(
        meeting: meeting, group: group, memberId: ann.id, paid: false);
    expect(await meetings.socialFundPayers(meeting.id), isEmpty);
    expect((await meetings.totals(meeting.id)).socialFund, 0);
  });
}
