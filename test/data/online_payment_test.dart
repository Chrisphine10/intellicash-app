import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/data/services/remote_payments_api.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Online payments on the phone: the fee breakdown it shows, the states it
/// must treat differently (a HELD payment is never "failed, try again"), and
/// the v13 column that ties a share purchase to the server's payment.
void main() {
  group('payment parsing', () {
    test('a quote carries what the group receives and the charges on top', () {
      final quote = PaymentQuote.fromJson({
        'quoteId': 'abc.sig',
        'provider': 'MPESA_DARAJA',
        'groupAmountCents': 50000,
        'platformFeeCents': 500,
        'providerFeeCents': 700,
        'totalCents': 51200,
      });
      expect(quote.groupAmount, 500);
      expect(quote.platformFee, 5);
      expect(quote.providerFee, 7);
      expect(quote.total, 512);
      expect(quote.hasFees, isTrue);
      expect(quote.groupAmount + quote.platformFee + quote.providerFee, quote.total);
    });

    test('a held payment is neither pending nor failed', () {
      final held = GroupPayment.fromJson({
        'id': 'p1',
        'status': 'FAILED',
        'state': 'HELD',
        'provider': 'MPESA_DARAJA',
        'amountCents': 51200,
        'groupAmountCents': 50000,
      });
      expect(held.isHeld, isTrue);
      expect(held.isFailed, isFalse);
      expect(held.isPending, isFalse);
      expect(held.amountToGroup, 500);
    });

    test('an older server without the new fields still reads', () {
      final old = GroupPayment.fromJson({
        'id': 'p2',
        'status': 'COMPLETED',
        'provider': 'PAYSTACK',
        'amountCents': 10000,
      });
      expect(old.isComplete, isTrue);
      expect(old.amountToGroup, 100);
      expect(old.platformFee, 0);
    });

    test('self-pay options default to off', () {
      final options = SelfPayOptions.fromJson({'enabled': true, 'providers': ['MPESA_DARAJA'], 'shareValueCents': 10000});
      expect(options.enabled, isTrue);
      expect(options.shareValue, 100);
      expect(SelfPayOptions.fromJson(const {}).enabled, isFalse);
    });
  });

  group('schema v13', () {
    late Directory tempDir;

    setUpAll(sqfliteFfiInit);

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('ic_upgrade_v13');
      AppDatabase.overrideFactory = databaseFactoryFfi;
      AppDatabase.overridePath = tempDir.path;
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      AppDatabase.overrideFactory = null;
      AppDatabase.overridePath = null;
      await tempDir.delete(recursive: true);
    });

    test('a v12 book gains share_purchases.group_payment_id and keeps its rows', () async {
      // A v12 share_purchases table with one purchase in it.
      final path = p.join(tempDir.path, 'intellicash.db');
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 12,
          onCreate: (db, _) async {
            await db.execute('''
              CREATE TABLE share_purchases (
                id TEXT PRIMARY KEY,
                meeting_id TEXT NOT NULL,
                member_id TEXT NOT NULL,
                shares INTEGER NOT NULL,
                unit_value REAL NOT NULL,
                amount REAL NOT NULL,
                payment_method TEXT NOT NULL DEFAULT 'cash',
                payment_reference TEXT,
                created_at TEXT NOT NULL
              )
            ''');
            await db.execute('CREATE TABLE fines (id TEXT PRIMARY KEY, meeting_id TEXT, member_id TEXT, amount REAL, reason TEXT, created_at TEXT)');
            await db.execute('CREATE TABLE social_fund_entries (id TEXT PRIMARY KEY, meeting_id TEXT, member_id TEXT, amount REAL, created_at TEXT)');
            await db.execute('CREATE TABLE loan_repayments (id TEXT PRIMARY KEY, loan_id TEXT, meeting_id TEXT, amount REAL, paid_at TEXT)');
            await db.insert('share_purchases', {
              'id': 'sp1',
              'meeting_id': 'm1',
              'member_id': 'mem1',
              'shares': 2,
              'unit_value': 100.0,
              'amount': 200.0,
              'created_at': DateTime(2026, 9, 1).toIso8601String(),
            });
          },
        ),
      );
      await old.close();

      final db = await AppDatabase.instance.database;
      final columns = {for (final row in await db.rawQuery('PRAGMA table_info(share_purchases)')) row['name']};
      expect(columns, contains('group_payment_id'));
      for (final table in ['fines', 'social_fund_entries', 'loan_repayments']) {
        final cols = {for (final row in await db.rawQuery('PRAGMA table_info($table)')) row['name']};
        expect(cols, contains('group_payment_id'), reason: table);
      }
      final rows = await db.query('share_purchases');
      expect(rows.single['id'], 'sp1');
      expect(rows.single['group_payment_id'], isNull);
    });

    test('a pre-release v13 book (column on share_purchases only) gains it everywhere', () async {
      final path = p.join(tempDir.path, 'intellicash.db');
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 13,
          onCreate: (db, _) async {
            await db.execute('CREATE TABLE share_purchases (id TEXT PRIMARY KEY, group_payment_id TEXT)');
            await db.execute('CREATE TABLE fines (id TEXT PRIMARY KEY, amount REAL)');
            await db.execute('CREATE TABLE social_fund_entries (id TEXT PRIMARY KEY, amount REAL)');
            await db.execute('CREATE TABLE loan_repayments (id TEXT PRIMARY KEY, amount REAL)');
          },
        ),
      );
      await old.close();

      final db = await AppDatabase.instance.database;
      for (final table in ['share_purchases', 'fines', 'social_fund_entries', 'loan_repayments']) {
        final cols = {for (final row in await db.rawQuery('PRAGMA table_info($table)')) row['name']};
        expect(cols, contains('group_payment_id'), reason: table);
      }
    });

    test('a pre-release v14 book gains payment_method and payment_reference on every money table', () async {
      final path = p.join(tempDir.path, 'intellicash.db');
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 14,
          onCreate: (db, _) async {
            await db.execute("CREATE TABLE share_purchases (id TEXT PRIMARY KEY, payment_method TEXT NOT NULL DEFAULT 'cash', payment_reference TEXT, group_payment_id TEXT)");
            await db.execute('CREATE TABLE fines (id TEXT PRIMARY KEY, amount REAL, group_payment_id TEXT)');
            await db.execute('CREATE TABLE social_fund_entries (id TEXT PRIMARY KEY, amount REAL, group_payment_id TEXT)');
            await db.execute('CREATE TABLE loan_repayments (id TEXT PRIMARY KEY, amount REAL, group_payment_id TEXT)');
            await db.insert('fines', {'id': 'f1', 'amount': 100.0});
          },
        ),
      );
      await old.close();

      final db = await AppDatabase.instance.database;
      for (final table in ['share_purchases', 'fines', 'social_fund_entries', 'loan_repayments']) {
        final cols = {for (final row in await db.rawQuery('PRAGMA table_info($table)')) row['name']};
        expect(cols, containsAll(['group_payment_id', 'payment_method', 'payment_reference']), reason: table);
      }
      // An existing row reads as cash, with no code.
      final fine = (await db.query('fines')).single;
      expect(fine['payment_method'], 'cash');
      expect(fine['payment_reference'], isNull);
    });
  });
}
