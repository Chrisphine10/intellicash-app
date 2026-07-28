import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late AppDatabase db;
  late GroupRepository groups;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_schedule');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
    groups = GroupRepository(db);
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> makeGroup(MeetingFrequency freq, List<int> days) => groups
      .createGroup(
        name: 'Sched Group',
        cycleNumber: 1,
        savingsMode: SavingsMode.fixed,
        shareValue: 100,
        maxSharesPerMeeting: 10,
        socialFundAmount: 50,
        interestRate: 5,
        interestType: InterestType.reducingBalance,
        loanMultiplier: 2,
        defaultLoanTermMonths: 3,
        meetingFrequency: freq,
        meetingDays: days,
        memberNames: const ['A'],
      )
      .then((_) {});

  test('multiple meeting days round-trip, sorted', () async {
    await makeGroup(MeetingFrequency.weekly, [DateTime.thursday, DateTime.monday]);
    final g = await groups.currentGroup();
    expect(g!.meetingDays, [DateTime.monday, DateTime.thursday]);
    expect(g.meetingDay, DateTime.monday); // primary = first
    expect(g.meetingDaysLabel, 'Mon, Thu');
  });

  test('bi-weekly and monthly frequencies persist', () async {
    await makeGroup(MeetingFrequency.biweekly, [DateTime.friday]);
    var g = await groups.currentGroup();
    expect(g!.meetingFrequency, MeetingFrequency.biweekly);
    expect(g.meetingDaysLabel, 'Friday');

    await groups.updateGroup(g.copyWith(
      meetingFrequency: MeetingFrequency.monthly,
      meetingDays: [DateTime.wednesday, DateTime.saturday],
    ));
    g = await groups.currentGroup();
    expect(g!.meetingFrequency, MeetingFrequency.monthly);
    expect(g.meetingDays, [DateTime.wednesday, DateTime.saturday]);
  });

  test('single day still reads as a one-item list', () async {
    await makeGroup(MeetingFrequency.weekly, [DateTime.sunday]);
    final g = await groups.currentGroup();
    expect(g!.meetingDays, [DateTime.sunday]);
    expect(g.meetingDaysLabel, 'Sunday');
  });
}
