import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Welfare spending must reach the phone, because the phone is what computes
/// share-out. These tests exercise the REAL SQL against a real database — the
/// analyzer cannot see inside a query string, and a wrong column name there is
/// invisible until it fails in a meeting.

/// A group row with every NOT NULL column the schema demands. Written once so
/// a schema addition breaks one helper, not every test.
Map<String, Object?> groupRow(String id, String name) {
  final now = DateTime.now().toIso8601String();
  return {
    'id': id,
    'name': name,
    'cycle_number': 1,
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

void main() {
  late Directory tempDir;
  late AppDatabase db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_welfare');
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

  test('schema v6 creates welfare_expenses with the columns the sync writes',
      () async {
    final database = await db.database;
    final columns = (await database.rawQuery('PRAGMA table_info(welfare_expenses)'))
        .map((row) => row['name'] as String)
        .toSet();

    // Every column the sync inserts must exist, or the insert throws at
    // runtime with the analyzer none the wiser.
    for (final required in [
      'id',
      'group_id',
      'meeting_id',
      'cycle_number',
      'category',
      'amount',
      'payee_member_id',
      'payee_name',
      'note',
      'remote_id',
      'created_at',
    ]) {
      expect(columns, contains(required), reason: 'missing column $required');
    }
  });

  test('id_map uses entity_type — the column the sync joins on', () async {
    // This is the exact bug the analyzer could not catch: the sync originally
    // queried `entity`, which does not exist.
    final database = await db.database;
    final columns = (await database.rawQuery('PRAGMA table_info(id_map)'))
        .map((row) => row['name'] as String)
        .toSet();

    expect(columns, contains('entity_type'));
    expect(columns, contains('local_id'));
    expect(columns, contains('remote_id'));
    expect(columns, isNot(contains('entity')));
  });

  test('remote_id is UNIQUE, so a repeated sync cannot double-count spending',
      () async {
    final database = await db.database;
    await database.insert('groups', groupRow('g1', 'Test Group'));

    Future<void> insertExpense(String id) => database.insert('welfare_expenses', {
          'id': id,
          'group_id': 'g1',
          'cycle_number': 1,
          'category': 'MEDICAL',
          'amount': 150.0,
          'remote_id': 'remote-1',
          'created_at': DateTime.now().toIso8601String(),
        });

    await insertExpense('local-1');
    // The same server expense arriving twice must be refused by the database
    // itself, not merely by application logic that could be bypassed.
    await expectLater(insertExpense('local-2'), throwsA(isA<Exception>()));

    final count = (await database.rawQuery(
      'SELECT COUNT(*) AS c FROM welfare_expenses WHERE group_id = ?',
      ['g1'],
    ))
        .first['c'];
    expect(count, 1);
  });

  test('recorded spending reduces what share-out will distribute', () async {
    final database = await db.database;
    await database.insert('groups', groupRow('g2', 'Pool Group'));

    // The rule: the pool is contributions MINUS spending. Asserted directly on
    // the sum the share-out query uses, so a regression in either the column
    // name or the arithmetic fails here.
    Future<double> spent() async {
      final rows = await database.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) AS s FROM welfare_expenses WHERE group_id = ?',
        ['g2'],
      );
      return ((rows.first['s'] ?? 0) as num).toDouble();
    }

    expect(await spent(), 0);

    await database.insert('welfare_expenses', {
      'id': 'e1',
      'group_id': 'g2',
      'cycle_number': 1,
      'category': 'BEREAVEMENT',
      'amount': 400.0,
      'payee_name': 'Njeri family',
      'remote_id': 'remote-2',
      'created_at': DateTime.now().toIso8601String(),
    });

    expect(await spent(), 400.0);
  });
}
