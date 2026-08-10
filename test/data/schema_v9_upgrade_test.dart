import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The v8 -> v9 upgrade: the local photo queue.
///
/// Plus the long jump a handset that has skipped several releases actually
/// performs — v6 straight to current, with every `if (oldVersion < N)` block
/// running in turn. That is the case a per-version test never covers and the
/// one real phones hit.
void main() {
  late Directory tempDir;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_upgrade_v9');
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

  Map<String, Object?> visitRow(String id) {
    final now = DateTime.now().toIso8601String();
    return {
      'id': id,
      'client_request_id': 'visit-$id',
      'remote_group_id': 'remote-g1',
      'visit_type': 'FOLLOW_UP',
      'status': 'DRAFT',
      'started_at': now,
      'created_at': now,
      'updated_at': now,
    };
  }

  /// Drops the v9 table and marks the file as [version]. Returns the version it
  /// was at beforehand, so nothing here hard-codes a number that rots on the
  /// next bump.
  Future<Object?> rewindTo(int version) async {
    final db = await AppDatabase.instance.database;
    final current = (await db.rawQuery('PRAGMA user_version')).first.values.first;
    await db.execute('DROP INDEX IF EXISTS idx_attachments_visit');
    await db.execute('DROP TABLE IF EXISTS visit_attachments');
    if (version < 8) {
      await db.execute('DROP INDEX IF EXISTS idx_answers_visit');
      await db.execute('DROP INDEX IF EXISTS idx_snapshots_current');
      await db.execute('DROP TABLE IF EXISTS visit_answers');
      await db.execute('DROP TABLE IF EXISTS visit_assessments');
      await db.execute('DROP TABLE IF EXISTS assessment_snapshots');
    }
    if (version < 7) {
      await db.execute('DROP INDEX IF EXISTS idx_visits_group');
      await db.execute('DROP INDEX IF EXISTS idx_outbox_status');
      await db.execute('DROP TABLE IF EXISTS outbox');
      await db.execute('DROP TABLE IF EXISTS group_visits');
    }
    await db.execute('PRAGMA user_version = $version');
    await AppDatabase.instance.close();
    return current;
  }

  test('a phone mid-visit keeps its work and gains a photo queue', () async {
    var db = await AppDatabase.instance.database;
    await db.insert('groups', groupRow('g1', 'Tujijenge Women'));
    await db.insert('group_visits', visitRow('v1'));
    final now = DateTime.now().toIso8601String();
    await db.insert('visit_answers', {
      'id': 'a1',
      'visit_id': 'v1',
      'section_key': 'governance',
      'question_key': 'constitution_written',
      'choice': 'YES',
      'answered_at': now,
    });
    final currentSchemaVersion = await rewindTo(8);

    db = await AppDatabase.instance.database;

    expect((await db.rawQuery('PRAGMA user_version')).first.values.first,
        currentSchemaVersion);

    // An upgrade that silently drops collected fieldwork is worse than one that
    // fails outright, because nobody notices until the report is wrong.
    expect((await db.rawQuery('SELECT COUNT(*) c FROM group_visits')).first['c'], 1);
    expect((await db.rawQuery('SELECT COUNT(*) c FROM visit_answers')).first['c'], 1);

    await db.insert('visit_attachments', {
      'id': 'att1',
      'visit_id': 'v1',
      'section_key': 'governance',
      'question_key': 'constitution_written',
      'client_request_id': 'att-1',
      'local_path': '/data/photos/a.jpg',
      'file_name': 'a.jpg',
      'mime_type': 'image/jpeg',
      'size_bytes': 4096,
      'captured_at': now,
      'status': 'PENDING',
      'created_at': now,
    });
    expect(
      (await db.rawQuery('SELECT COUNT(*) c FROM visit_attachments')).first['c'],
      1,
    );
  });

  test('the same photo cannot be queued twice', () async {
    // Idempotency depends on this: two rows sharing a request id would let one
    // photograph be bound as two attachments on the server.
    final db = await AppDatabase.instance.database;
    await db.insert('groups', groupRow('g1', 'Tujijenge Women'));
    await db.insert('group_visits', visitRow('v1'));
    final now = DateTime.now().toIso8601String();
    final row = {
      'id': 'att1',
      'visit_id': 'v1',
      'section_key': 'governance',
      'client_request_id': 'att-dup',
      'local_path': '/data/photos/a.jpg',
      'file_name': 'a.jpg',
      'mime_type': 'image/jpeg',
      'size_bytes': 4096,
      'captured_at': now,
      'status': 'PENDING',
      'created_at': now,
    };
    await db.insert('visit_attachments', row);

    await expectLater(
      db.insert('visit_attachments', {...row, 'id': 'att2'}),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('a phone that skipped three releases upgrades all the way from v6',
      () async {
    var db = await AppDatabase.instance.database;
    await db.insert('groups', groupRow('g6', 'Skipped Releases'));
    final currentSchemaVersion = await rewindTo(6);

    db = await AppDatabase.instance.database;

    expect((await db.rawQuery('PRAGMA user_version')).first.values.first,
        currentSchemaVersion);
    expect((await db.rawQuery('SELECT COUNT(*) c FROM groups')).first['c'], 1);

    // Every version's tables must exist after the jump, not only the newest.
    for (final table in [
      'welfare_expenses',
      'group_visits',
      'outbox',
      'assessment_snapshots',
      'visit_assessments',
      'visit_answers',
      'visit_attachments',
    ]) {
      expect(
        (await db.rawQuery('SELECT COUNT(*) c FROM $table')).first['c'],
        0,
        reason: '$table missing after the v6 jump',
      );
    }
  });

  test('the upgrade is safe to run twice', () async {
    var db = await AppDatabase.instance.database;
    await db.insert('groups', groupRow('g7', 'Repeat Group'));
    final currentSchemaVersion =
        (await db.rawQuery('PRAGMA user_version')).first.values.first;
    // Mark as v8 WITHOUT dropping the v9 table, so the upgrade re-runs against
    // a database that already has it.
    await db.execute('PRAGMA user_version = 8');
    await AppDatabase.instance.close();

    db = await AppDatabase.instance.database;
    expect((await db.rawQuery('PRAGMA user_version')).first.values.first,
        currentSchemaVersion);
    expect((await db.rawQuery('SELECT COUNT(*) c FROM groups')).first['c'], 1);
  });
}
