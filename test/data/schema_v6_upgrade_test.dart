import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The v5 -> v6 upgrade, exercised with data already in the database.
///
/// Every other test opens a FRESH database, which runs `onCreate` and proves
/// nothing about upgrading. The path that matters is a phone that already
/// holds a group's records installing a new build: if `onUpgrade` throws, or
/// quietly drops rows, a group loses its history.
///
/// Method: create at the current version, downgrade the file to v5 (drop the
/// v6 table and reset user_version), seed it, then reopen through
/// AppDatabase so the REAL upgrade code runs.
void main() {
  late Directory tempDir;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_upgrade');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    AppDatabase.overrideFactory = null;
    AppDatabase.overridePath = null;
    await tempDir.delete(recursive: true);
  });

  Map<String, Object?> groupRow(String id, String name) {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'name': name,
      'cycle_number': 2,
      'cycle_start_date': now,
      'savings_mode': 'shares',
      'share_value': 500.0,
      'max_shares_per_meeting': 5,
      'social_fund_amount': 50.0,
      'interest_rate': 10.0,
      'interest_type': 'flat',
      'loan_multiplier': 3.0,
      'default_loan_term_months': 1,
      'meeting_frequency': 'weekly',
      'meeting_day': 1,
      'created_at': now,
      'updated_at': now,
    };
  }

  test('upgrading a populated v5 database to v6 keeps the data and adds the table',
      () async {
    // --- build, then rewind to v5 -------------------------------------------
    var db = await AppDatabase.instance.database;
    // What a freshly created database reports. Assertions below compare
    // against this rather than a literal, so the test tracks the schema
    // instead of needing an edit on every version bump.
    final currentSchemaVersion =
        (await db.rawQuery('PRAGMA user_version')).first.values.first;
    await db.insert('groups', groupRow('g1', 'Tujijenge Women'));
    await db.insert('groups', groupRow('g2', 'Umoja Savings'));

    await db.execute('DROP INDEX IF EXISTS idx_welfare_group');
    await db.execute('DROP TABLE IF EXISTS welfare_expenses');
    await db.execute('PRAGMA user_version = 5');

    final beforeVersion = (await db.rawQuery('PRAGMA user_version')).first.values.first;
    expect(beforeVersion, 5, reason: 'must actually be on v5 before upgrading');

    final beforeGroups = (await db.rawQuery('SELECT COUNT(*) c FROM groups')).first['c'];
    expect(beforeGroups, 2);

    await AppDatabase.instance.close();

    // --- reopen: the real onUpgrade runs ------------------------------------
    db = await AppDatabase.instance.database;

    // Compared against what a fresh database reports rather than a literal:
    // this test is about v5 -> current, and hardcoding a number means it
    // breaks on every future schema bump for no real reason.
    final afterVersion = (await db.rawQuery('PRAGMA user_version')).first.values.first;
    expect(afterVersion, currentSchemaVersion,
        reason: 'upgrade must advance the schema version');

    // The group's records must survive. An upgrade that loses them would be
    // worse than one that fails outright, because it fails silently.
    final afterGroups = await db.query('groups', orderBy: 'id');
    expect(afterGroups.length, 2);
    expect(afterGroups.map((r) => r['name']),
        containsAll(['Tujijenge Women', 'Umoja Savings']));
    expect(afterGroups.first['cycle_number'], 2, reason: 'column values intact');

    // And the new table must exist and be usable, not merely declared.
    await db.insert('welfare_expenses', {
      'id': 'w1',
      'group_id': 'g1',
      'cycle_number': 2,
      'category': 'MEDICAL',
      'amount': 250.0,
      'payee_name': 'Embu Clinic',
      'remote_id': 'remote-1',
      'created_at': DateTime.now().toIso8601String(),
    });

    final spent = (await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) s FROM welfare_expenses WHERE group_id = ?',
      ['g1'],
    ))
        .first['s'];
    expect(spent, 250.0);
  });

  test('the upgrade is safe to run twice', () async {
    // A build installed over itself, or an interrupted upgrade retried, must
    // not fail on "table already exists".
    var db = await AppDatabase.instance.database;
    final currentSchemaVersion =
        (await db.rawQuery('PRAGMA user_version')).first.values.first;
    await db.insert('groups', groupRow('g3', 'Repeat Group'));
    await db.execute('PRAGMA user_version = 5');
    await AppDatabase.instance.close();

    db = await AppDatabase.instance.database;
    expect((await db.rawQuery('PRAGMA user_version')).first.values.first,
        currentSchemaVersion);
    expect((await db.rawQuery('SELECT COUNT(*) c FROM groups')).first['c'], 1);
  });
}
