import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The v7 -> v8 upgrade: the cached assessment form and the answers to it.
///
/// Same method as the earlier upgrade tests — build at the current version,
/// rewind the file, seed it, reopen through AppDatabase so the real upgrade
/// code runs. A fresh database only exercises `onCreate` and proves nothing.
///
/// The case that matters most here is a phone caught mid-visit by an update: it
/// has a draft visit and possibly an outbox entry, and must come out the other
/// side with both intact and somewhere to record answers.
void main() {
  late Directory tempDir;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_upgrade_v8');
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

  Map<String, Object?> visitRow(String id, String requestId) {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'client_request_id': requestId,
      'remote_group_id': 'remote-g1',
      'visit_type': 'FOLLOW_UP',
      'status': 'DRAFT',
      'started_at': now,
      'created_at': now,
      'updated_at': now,
    };
  }

  /// Drops the v8 tables and marks the file as [version]. Returns the version
  /// it was at beforehand, so assertions never hard-code a number.
  Future<Object?> rewindTo(int version) async {
    final db = await AppDatabase.instance.database;
    final current = (await db.rawQuery('PRAGMA user_version')).first.values.first;
    await db.execute('DROP INDEX IF EXISTS idx_answers_visit');
    await db.execute('DROP INDEX IF EXISTS idx_snapshots_current');
    await db.execute('DROP TABLE IF EXISTS visit_answers');
    await db.execute('DROP TABLE IF EXISTS visit_assessments');
    await db.execute('DROP TABLE IF EXISTS assessment_snapshots');
    await db.execute('PRAGMA user_version = $version');
    await AppDatabase.instance.close();
    return current;
  }

  test('a phone mid-visit keeps its draft and gains somewhere to answer',
      () async {
    var db = await AppDatabase.instance.database;
    await db.insert('groups', groupRow('g1', 'Tujijenge Women'));
    await db.insert('group_visits', visitRow('v1', 'visit-in-progress'));
    final now = DateTime.now().toIso8601String();
    await db.insert('outbox', {
      'id': 'o1',
      'record_type': 'VISIT',
      'record_id': 'v1',
      'status': 'PENDING',
      'created_at': now,
      'updated_at': now,
    });
    final currentSchemaVersion = await rewindTo(7);

    db = await AppDatabase.instance.database;

    expect((await db.rawQuery('PRAGMA user_version')).first.values.first,
        currentSchemaVersion);

    // The in-flight work must survive. An upgrade that silently drops a visit
    // the agent has already collected is worse than one that fails outright.
    expect((await db.rawQuery('SELECT COUNT(*) c FROM group_visits')).first['c'], 1);
    expect((await db.rawQuery('SELECT COUNT(*) c FROM outbox')).first['c'], 1);
    expect((await db.rawQuery('SELECT COUNT(*) c FROM groups')).first['c'], 1);

    // And the new tables must be usable, not merely declared.
    await db.insert('assessment_snapshots', {
      'id': 's1',
      'template_id': 't1',
      'version': 1,
      'checksum': 'abc',
      'max_points': 92.0,
      'scoring_contract_version': '1.0.0',
      'snapshot_json': '{}',
      'is_current': 1,
      'fetched_at': now,
    });
    await db.insert('visit_answers', {
      'id': 'a1',
      'visit_id': 'v1',
      'section_key': 'governance',
      'question_key': 'constitution_written',
      'choice': 'YES',
      'answered_at': now,
    });

    expect(
      (await db.rawQuery('SELECT COUNT(*) c FROM assessment_snapshots')).first['c'],
      1,
    );
    expect((await db.rawQuery('SELECT COUNT(*) c FROM visit_answers')).first['c'], 1);
  });

  test('re-answering a question overwrites rather than appending', () async {
    // An agent correcting themselves must not leave two answers to one
    // question — the server would then score whichever arrived last, and the
    // phone's local total would disagree with it.
    final db = await AppDatabase.instance.database;
    await db.insert('groups', groupRow('g1', 'Tujijenge Women'));
    await db.insert('group_visits', visitRow('v1', 'visit-answers'));
    final now = DateTime.now().toIso8601String();

    Future<void> answer(String choice) => db.insert(
          'visit_answers',
          {
            'id': 'a-$choice',
            'visit_id': 'v1',
            'section_key': 'governance',
            'question_key': 'constitution_written',
            'choice': choice,
            'answered_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

    await answer('YES');
    await answer('NO');

    final rows = await db.query('visit_answers', where: 'visit_id = ?', whereArgs: ['v1']);
    expect(rows.length, 1);
    expect(rows.first['choice'], 'NO');
  });

  test('answers are removed with the visit they belong to', () async {
    // Left behind, they would be scored against a visit that no longer exists.
    final db = await AppDatabase.instance.database;
    await db.insert('groups', groupRow('g1', 'Tujijenge Women'));
    await db.insert('group_visits', visitRow('v1', 'visit-cascade'));
    final now = DateTime.now().toIso8601String();
    await db.insert('visit_answers', {
      'id': 'a1',
      'visit_id': 'v1',
      'section_key': 'governance',
      'question_key': 'constitution_written',
      'choice': 'YES',
      'answered_at': now,
    });

    await db.delete('group_visits', where: 'id = ?', whereArgs: ['v1']);

    expect((await db.rawQuery('SELECT COUNT(*) c FROM visit_answers')).first['c'], 0);
  });

  test('a phone that skipped several releases upgrades all the way from v5',
      () async {
    // What a handset that has not been updated in months actually does: every
    // `if (oldVersion < N)` block runs in turn.
    var db = await AppDatabase.instance.database;
    await db.insert('groups', groupRow('g5', 'Skipped Releases'));
    await db.execute('DROP INDEX IF EXISTS idx_visits_group');
    await db.execute('DROP INDEX IF EXISTS idx_outbox_status');
    await db.execute('DROP TABLE IF EXISTS outbox');
    await db.execute('DROP TABLE IF EXISTS group_visits');
    await db.execute('DROP INDEX IF EXISTS idx_welfare_group');
    await db.execute('DROP TABLE IF EXISTS welfare_expenses');
    final currentSchemaVersion = await rewindTo(5);

    db = await AppDatabase.instance.database;

    expect((await db.rawQuery('PRAGMA user_version')).first.values.first,
        currentSchemaVersion);
    expect((await db.rawQuery('SELECT COUNT(*) c FROM groups')).first['c'], 1);
    // Every version's tables must be present after the long jump, not just the
    // newest one's.
    expect((await db.rawQuery('SELECT COUNT(*) c FROM welfare_expenses')).first['c'], 0);
    expect((await db.rawQuery('SELECT COUNT(*) c FROM outbox')).first['c'], 0);
    expect(
      (await db.rawQuery('SELECT COUNT(*) c FROM assessment_snapshots')).first['c'],
      0,
    );
    expect((await db.rawQuery('SELECT COUNT(*) c FROM visit_answers')).first['c'], 0);
  });

  test('the upgrade is safe to run twice', () async {
    // A build installed over itself, or an interrupted upgrade retried, must
    // not fail on "table already exists".
    var db = await AppDatabase.instance.database;
    await db.insert('groups', groupRow('g6', 'Repeat Group'));
    final currentSchemaVersion =
        (await db.rawQuery('PRAGMA user_version')).first.values.first;
    // Mark as v7 WITHOUT dropping the v8 tables, so the upgrade re-runs against
    // a database that already has them.
    await db.execute('PRAGMA user_version = 7');
    await AppDatabase.instance.close();

    db = await AppDatabase.instance.database;
    expect((await db.rawQuery('PRAGMA user_version')).first.values.first,
        currentSchemaVersion);
    expect((await db.rawQuery('SELECT COUNT(*) c FROM groups')).first['c'], 1);
  });
}
