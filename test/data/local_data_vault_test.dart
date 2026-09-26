import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' show Sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/data/models/enums.dart';
import 'package:intellicash_mobile/data/repositories/group_repository.dart';
import 'package:intellicash_mobile/data/repositories/meeting_repository.dart';
import 'package:intellicash_mobile/data/repositories/member_repository.dart';
import 'package:intellicash_mobile/core/utils/domain_exception.dart';
import 'package:intellicash_mobile/data/services/local_data_vault.dart';

/// The phone's own archives: a copy written before another account takes the
/// phone, and the way back. Recovery used to fail on its first attendance row
/// (foreign keys cannot be switched off inside a transaction) and, had it run,
/// would have deleted the current book with no copy and no check for unsent
/// work.
void main() {
  late Directory tempDir;
  late AppDatabase db;
  late LocalDataVault vault;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_vault');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
    vault = LocalDataVault(db, documents: () async => Directory('${tempDir.path}/docs'));
  });

  tearDown(() async {
    await db.close();
    AppDatabase.overrideFactory = null;
    AppDatabase.overridePath = null;
    await tempDir.delete(recursive: true);
  });

  /// A book with a meeting, attendance and savings: rows that point at each other.
  Future<void> recordAMeeting() async {
    final groups = GroupRepository(db);
    final group = await groups.createGroup(
      name: 'Umoja Women Group',
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
      meetingDays: const [DateTime.sunday],
      memberNames: const ['Achieng Odhiambo', 'Wanjiku Kamau'],
    );
    final meetings = MeetingRepository(db);
    final meeting = await meetings.startMeeting(group);
    final roster = await MemberRepository(db).membersForGroup(group.id);
    await meetings.recordSharePurchase(meeting: meeting, group: group, memberId: roster.first.id, shares: 3);
    await meetings.closeMeeting(meeting);
  }

  Future<int> count(String table) async =>
      Sqflite.firstIntValue(await (await db.database).rawQuery('SELECT COUNT(*) FROM $table')) ?? 0;

  test('an archive brings the book back, rows that point at each other included', () async {
    await recordAMeeting();
    final archive = await vault.archive(label: 'Before the switch');
    final shares = await count('share_purchases');
    final meetings = await count('meetings');
    expect(shares, 1);

    await db.clearLocalWorkspace();
    expect(await count('share_purchases'), 0);

    await vault.recover(archive.id, unsentWork: () async => 0);
    expect(await count('share_purchases'), shares);
    expect(await count('meetings'), meetings);
    final broken = await (await db.database).rawQuery('PRAGMA foreign_key_check');
    expect(broken, isEmpty);
  });

  test('recovering keeps a copy of what it replaces, so it can be undone', () async {
    await recordAMeeting();
    final archive = await vault.archive(label: 'Old book');
    await vault.recover(archive.id, unsentWork: () async => 0);
    final archives = await vault.list();
    expect(archives, hasLength(2), reason: 'the archive, and the book it replaced');
  });

  test('is refused while anything is waiting to go online, and nothing changes', () async {
    await recordAMeeting();
    final archive = await vault.archive();
    await db.clearLocalWorkspace();
    await expectLater(
      vault.recover(archive.id, unsentWork: () async => 2),
      throwsA(isA<DomainException>().having((e) => e.message, 'message', contains('not been backed up'))),
    );
    expect(await count('share_purchases'), 0, reason: 'refused before touching anything');
    expect(await vault.list(), hasLength(1), reason: 'and no extra copy written');
  });

  test('refuses an archive from a newer version of the app', () async {
    await recordAMeeting();
    final archive = await vault.archive();
    final file = await vault.fileFor(archive.id);
    // Rewrite the archive as if a later app (schema version 999) made it.
    final payload = String.fromCharCodes(gzip.decode(await file.readAsBytes()));
    await file.writeAsBytes(gzip.encode(payload.replaceFirst(RegExp(r'"schemaVersion":\d+'), '"schemaVersion":999').codeUnits));
    await expectLater(
      vault.recover(archive.id, unsentWork: () async => 0),
      throwsA(isA<DomainException>().having((e) => e.message, 'message', contains('newer version'))),
    );
  });

  test('an archive is written whole or not at all', () async {
    await recordAMeeting();
    await vault.archive();
    final names = Directory('${tempDir.path}/docs/archives').listSync().map((f) => f.uri.pathSegments.last);
    expect(names.where((name) => name.endsWith('.tmp')), isEmpty);
    expect(names.where((name) => name.endsWith('.json.gz')), hasLength(1));
  });
}
