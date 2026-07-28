import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/data/repositories/sync_repository.dart';
import 'package:intellicash_mobile/data/services/sync_service.dart';

/// The connectivity-triggered sync used to post the offline queue to a
/// `/sync/push` endpoint that never existed on the backend, so it silently
/// never worked. It now delegates to an injected `onSync` that runs the real,
/// idempotent write-sync. These pin that delegation.
void main() {
  setUpAll(sqfliteFfiInit);

  late Directory tempDir;
  late AppDatabase db;
  late SyncService service;

  setUp(() async {
    // The fallback queue-drain path reads a base URL from prefs.
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('ic_sync_cb');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    db = AppDatabase.instance;
    service = SyncService(SyncRepository(db));
  });

  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('pushNow runs the injected sync and reports its count', () async {
    var calls = 0;
    service.onSync = () async {
      calls++;
      return 5;
    };
    expect(await service.pushNow(), 5);
    expect(calls, 1);
  });

  test('a failing sync is swallowed so a reconnect never crashes', () async {
    service.onSync = () async => throw Exception('server unreachable');
    // Local writes are untouched; the caller just sees nothing synced.
    expect(await service.pushNow(), 0);
  });

  test('overlapping pushes do not stack — the second is dropped', () async {
    var active = 0;
    var maxConcurrent = 0;
    service.onSync = () async {
      active++;
      maxConcurrent = active > maxConcurrent ? active : maxConcurrent;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      active--;
      return 1;
    };
    // Fire two at once, as a flaky signal reconnecting twice would.
    final results = await Future.wait([service.pushNow(), service.pushNow()]);
    // Exactly one ran; the other returned 0 without starting.
    expect(maxConcurrent, 1);
    expect(results.where((r) => r == 1), hasLength(1));
    expect(results.where((r) => r == 0), hasLength(1));
  });

  test('notifies listeners only when something actually synced', () async {
    var notified = 0;
    service.onQueueChanged = () => notified++;

    service.onSync = () async => 0;
    await service.pushNow();
    expect(notified, 0, reason: 'nothing synced, no reason to refresh');

    service.onSync = () async => 3;
    await service.pushNow();
    expect(notified, 1);
  });

  test('without a callback it falls back to draining the queue', () async {
    // The low-level path the repository tests still rely on: no onSync, an
    // empty queue, so nothing to send and no crash.
    expect(service.onSync, isNull);
    expect(await service.pushNow(), 0);
  });
}
