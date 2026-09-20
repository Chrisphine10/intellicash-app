import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/repositories/id_map_repository.dart';
import 'package:intellicash_mobile/data/services/remote_write_api.dart';
import 'package:intellicash_mobile/data/services/share_out_sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The v10 -> v11 upgrade: share-outs made before they could be sent online.
///
/// Such a share-out's cycle went to the server long ago, mixed in with the next
/// cycle's, so the server could never match them up. If the phone tried to send
/// it now the server would refuse it - and, worse, everything recorded after it
/// would be held back behind that refusal. The upgrade marks each one handled.
void main() {
  late Directory tempDir;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_upgrade_v11');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    AppDatabase.overrideFactory = null;
    AppDatabase.overridePath = null;
    await tempDir.delete(recursive: true);
  });

  Future<void> group(String id, int cycle) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('groups', {
      'id': id,
      'name': 'Group $id',
      'cycle_number': cycle,
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
    });
    await db.insert('members', {
      'id': 'm-$id',
      'group_id': id,
      'name': 'Member of $id',
      'joined_at': now,
    });
  }

  Future<void> payout(String id, String groupId, int cycle) async {
    final db = await AppDatabase.instance.database;
    await db.insert('share_out_payouts', {
      'id': id,
      'group_id': groupId,
      'cycle_number': cycle,
      'member_id': 'm-$groupId',
      'member_name': 'Member of $groupId',
      'share_amount': 100.0,
      'gross_payout': 110.0,
      'welfare_payout': 0.0,
      'loan_offset': 0.0,
      'net_payout': 110.0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Object?> rewindTo(int version) async {
    final db = await AppDatabase.instance.database;
    final current = (await db.rawQuery('PRAGMA user_version')).first.values.first;
    // A phone at v10 has never had a share-out marker.
    await db.delete('id_map', where: 'entity_type = ?', whereArgs: [MapEntity.shareOut]);
    await db.execute('PRAGMA user_version = $version');
    await AppDatabase.instance.close();
    return current;
  }

  test('each share-out already on a phone is marked handled, once per cycle', () async {
    await group('g1', 3);
    await group('g2', 2);
    // g1 shared out twice (two members' rows each time), g2 once.
    await payout('a', 'g1', 1);
    await payout('b', 'g1', 1);
    await payout('c', 'g1', 2);
    await payout('d', 'g2', 1);
    final current = await rewindTo(10);

    final db = await AppDatabase.instance.database;

    expect((await db.rawQuery('PRAGMA user_version')).first.values.first, current);
    final marked = await IdMapRepository(AppDatabase.instance)
        .mappings(MapEntity.shareOut);
    expect(marked.keys.toSet(), {'g1#1', 'g1#2', 'g2#1'});
    expect(marked.values.toSet(),
        {ShareOutSyncService.beforeOnlineRecordingMarker});

    // So none of them is waiting to be sent, and none holds anything up.
    final service = ShareOutSyncService(
      db: AppDatabase.instance,
      idMap: IdMapRepository(AppDatabase.instance),
      // Never called: nothing is unsent.
      writeApi: RemoteWriteApi(ApiClient(
          credentials: () => const ApiCredentials(baseUrl: '', apiKey: ''))),
    );
    expect(await service.unsent('g1'), isEmpty);
    expect((await service.statuses('g1'))[1]!.state,
        ShareOutSyncState.beforeOnlineRecording);
  });

  test('the payouts themselves are untouched', () async {
    await group('g1', 2);
    await payout('a', 'g1', 1);
    await rewindTo(10);

    final db = await AppDatabase.instance.database;
    final rows = await db.query('share_out_payouts');
    expect(rows, hasLength(1));
    expect(rows.first['net_payout'], 110.0);
  });

  test('a phone with no share-outs gains nothing', () async {
    await group('g1', 1);
    await rewindTo(10);

    final db = await AppDatabase.instance.database;
    expect((await db.rawQuery('SELECT COUNT(*) c FROM id_map')).first['c'], 0);
  });

  test('running it again does not duplicate or overwrite a real mapping', () async {
    await group('g1', 2);
    await payout('a', 'g1', 1);
    final db = await AppDatabase.instance.database;
    // The share-out was sent by a later build; the id map says so.
    await db.insert('id_map', {
      'entity_type': MapEntity.shareOut,
      'local_id': 'g1#1',
      'remote_id': 'cyc-real',
      'group_id': 'remote-g1',
      'synced_at': DateTime.now().toIso8601String(),
    });
    await db.execute('PRAGMA user_version = 10');
    await AppDatabase.instance.close();

    final reopened = await AppDatabase.instance.database;
    final rows = await reopened.query('id_map',
        where: 'entity_type = ?', whereArgs: [MapEntity.shareOut]);
    expect(rows, hasLength(1));
    expect(rows.first['remote_id'], 'cyc-real');
  });
}
