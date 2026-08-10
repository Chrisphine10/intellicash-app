import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The v6 -> v7 upgrade (field visits + the outbox), and the long jump a phone
/// that skipped several releases actually performs.
///
/// Same method as the v6 test: build at the current version, rewind the file to
/// an older one, seed it, then reopen through AppDatabase so the REAL upgrade
/// code runs. A fresh database only ever exercises `onCreate` and proves
/// nothing about upgrading.
void main() {
  late Directory tempDir;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_upgrade_v7');
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

  /// Removes the v7 tables and marks the file as the given version.
  ///
  /// Returns the version the database was at beforehand — i.e. the current
  /// schema version — so assertions compare against that rather than a literal
  /// that has to be edited on every future bump.
  Future<Object?> rewindTo(int version) async {
    final db = await AppDatabase.instance.database;
    final current = (await db.rawQuery('PRAGMA user_version')).first.values.first;
    await db.execute('DROP INDEX IF EXISTS idx_visits_group');
    await db.execute('DROP INDEX IF EXISTS idx_outbox_status');
    await db.execute('DROP TABLE IF EXISTS outbox');
    await db.execute('DROP TABLE IF EXISTS group_visits');
    if (version < 6) {
      await db.execute('DROP INDEX IF EXISTS idx_welfare_group');
      await db.execute('DROP TABLE IF EXISTS welfare_expenses');
    }
    await db.execute('PRAGMA user_version = $version');
    await AppDatabase.instance.close();
    return current;
  }

  test('upgrading a populated v6 database keeps the data and adds the tables',
      () async {
    var db = await AppDatabase.instance.database;
    await db.insert('groups', groupRow('g1', 'Tujijenge Women'));
    await db.insert('groups', groupRow('g2', 'Umoja Savings'));
    final currentSchemaVersion = await rewindTo(6);

    db = await AppDatabase.instance.database;

    expect((await db.rawQuery('PRAGMA user_version')).first.values.first,
        currentSchemaVersion);

    // The group's records must survive. An upgrade that loses them is worse
    // than one that fails outright, because it fails silently.
    final groups = await db.query('groups', orderBy: 'id');
    expect(groups.length, 2);
    expect(groups.map((r) => r['name']),
        containsAll(['Tujijenge Women', 'Umoja Savings']));

    // The new tables must be usable, not merely declared.
    final now = DateTime.now().toIso8601String();
    await db.insert('group_visits', {
      'id': 'v1',
      'client_request_id': 'visit-abc',
      'remote_group_id': 'remote-g1',
      'visit_type': 'FOLLOW_UP',
      'status': 'DRAFT',
      'started_at': now,
      'created_at': now,
      'updated_at': now,
    });
    await db.insert('outbox', {
      'id': 'o1',
      'record_type': 'VISIT',
      'record_id': 'v1',
      'status': 'PENDING',
      'created_at': now,
      'updated_at': now,
    });

    expect((await db.rawQuery('SELECT COUNT(*) c FROM group_visits')).first['c'], 1);
    expect((await db.rawQuery('SELECT COUNT(*) c FROM outbox')).first['c'], 1);
  });

  test('the same visit cannot be queued twice', () async {
    // A double enqueue must be a no-op rather than a second send: the whole
    // point of the outbox is that a visit reaches the server exactly once.
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    final row = {
      'id': 'o1',
      'record_type': 'VISIT',
      'record_id': 'v1',
      'status': 'PENDING',
      'created_at': now,
      'updated_at': now,
    };
    await db.insert('outbox', row);

    await expectLater(
      db.insert('outbox', {...row, 'id': 'o2'}),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('a client request id is unique across visits', () async {
    // Idempotency depends on this: two rows sharing a request id would let the
    // same visit be pushed as two.
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    final row = {
      'id': 'v1',
      'client_request_id': 'visit-dup',
      'remote_group_id': 'remote-g1',
      'started_at': now,
      'created_at': now,
      'updated_at': now,
    };
    await db.insert('group_visits', row);

    await expectLater(
      db.insert('group_visits', {...row, 'id': 'v2'}),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('a phone that skipped releases upgrades all the way from v5', () async {
    // What a handset that has not been updated in three releases actually
    // does. Each `if (oldVersion < N)` block must run in turn.
    var db = await AppDatabase.instance.database;
    await db.insert('groups', groupRow('g5', 'Skipped Releases'));
    final currentSchemaVersion = await rewindTo(5);

    db = await AppDatabase.instance.database;

    expect((await db.rawQuery('PRAGMA user_version')).first.values.first,
        currentSchemaVersion);
    expect((await db.rawQuery('SELECT COUNT(*) c FROM groups')).first['c'], 1);
    // v6's table and v7's must both be present after the jump.
    expect(
      (await db.rawQuery('SELECT COUNT(*) c FROM welfare_expenses')).first['c'],
      0,
    );
    expect((await db.rawQuery('SELECT COUNT(*) c FROM outbox')).first['c'], 0);
  });

  test('the upgrade is safe to run twice', () async {
    // A build installed over itself, or an interrupted upgrade retried, must
    // not fail on "table already exists".
    var db = await AppDatabase.instance.database;
    await db.insert('groups', groupRow('g6', 'Repeat Group'));
    final currentSchemaVersion =
        (await db.rawQuery('PRAGMA user_version')).first.values.first;
    // Mark as v6 WITHOUT dropping the v7 tables, so the upgrade re-runs
    // against a database that already has them.
    await db.execute('PRAGMA user_version = 6');
    await AppDatabase.instance.close();

    db = await AppDatabase.instance.database;
    expect((await db.rawQuery('PRAGMA user_version')).first.values.first,
        currentSchemaVersion);
    expect((await db.rawQuery('SELECT COUNT(*) c FROM groups')).first['c'], 1);
  });
}
