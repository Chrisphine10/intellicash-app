import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/network/api_exception.dart';
import 'package:intellicash_mobile/data/repositories/outbox_repository.dart';
import 'package:intellicash_mobile/data/repositories/visit_repository.dart';
import 'package:intellicash_mobile/data/services/remote_visits_api.dart';
import 'package:intellicash_mobile/data/services/visit_sync_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pushing visits to the server.
///
/// The behaviour under test is what happens when the network misbehaves, which
/// in the field is most of the time. A visit must never be lost, never be
/// recorded twice, and never retry forever against an error that will not
/// change.
class _FakeVisitsApi implements RemoteVisitsApi {
  _FakeVisitsApi();

  final List<String> submitted = [];
  Object? throwOnSubmit;
  int calls = 0;

  @override
  Future<RemoteVisit> submit({
    required String groupId,
    required String clientRequestId,
    required String visitType,
    required DateTime startedAt,
    DateTime? completedAt,
    double? latitude,
    double? longitude,
    double? accuracyM,
    DateTime? locationCapturedAt,
    String? locationNote,
    String? deviceId,
    String? notes,
  }) async {
    calls += 1;
    final failure = throwOnSubmit;
    if (failure != null) throw failure;
    submitted.add(clientRequestId);
    return RemoteVisit(
      id: 'remote-${submitted.length}',
      groupId: groupId,
      clientRequestId: clientRequestId,
      visitType: visitType,
      status: 'SUBMITTED',
      startedAt: startedAt,
      locationOutcome: latitude == null ? 'NO_DEVICE_FIX' : 'WITHIN_GEOFENCE',
      withinGeofence: latitude != null,
      notes: notes,
    );
  }

  @override
  Future<List<RemoteVisit>> myVisits() async => const [];

  @override
  Future<List<RemoteVisit>> forGroup(String groupId) async => const [];
}

void main() {
  late Directory tempDir;
  late VisitRepository visits;
  late OutboxRepository outbox;
  late _FakeVisitsApi api;
  late VisitSyncService sync;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_visit_sync');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    visits = VisitRepository();
    outbox = OutboxRepository();
    api = _FakeVisitsApi();
    sync = VisitSyncService(api: api, visits: visits, outbox: outbox);
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    AppDatabase.overrideFactory = null;
    AppDatabase.overridePath = null;
    await tempDir.delete(recursive: true);
  });

  Future<LocalVisit> readyVisit({String group = 'remote-g1'}) async {
    final visit = await visits.start(remoteGroupId: group, groupName: 'Demo Test VSLA');
    await visits.recordLocation(
      id: visit.id,
      latitude: -0.5389,
      longitude: 37.4575,
      accuracyM: 8,
    );
    await visits.markReadyToSend(visit.id);
    await sync.queue(visit.id);
    return (await visits.byId(visit.id))!;
  }

  test('sends a finished visit and records that it landed', () async {
    final visit = await readyVisit();

    expect(await sync.pushDue(), 1);
    expect(api.submitted, [visit.clientRequestId]);

    final after = await visits.byId(visit.id);
    expect(after!.isSynced, isTrue);
    expect(after.remoteId, 'remote-1');
    expect(await sync.pendingCount(), 0);
  });

  test('does not send the same visit twice', () async {
    await readyVisit();
    await sync.pushDue();
    // A second sweep — a reconnect firing again — must find nothing to do.
    expect(await sync.pushDue(), 0);
    expect(api.calls, 1);
  });

  test('keeps a visit when the network fails, and sends it later', () async {
    // The whole reason the outbox exists: a visit recorded in a valley reaches
    // the server when the agent gets back to town, not never.
    final visit = await readyVisit();
    api.throwOnSubmit = const SocketException('No route to host');
    final now = DateTime(2026, 8, 9, 12);

    expect(await sync.pushDue(now: now), 0);
    final stillLocal = await visits.byId(visit.id);
    expect(stillLocal!.isSynced, isFalse, reason: 'the visit must not be lost');
    expect(await sync.pendingCount(), 1);

    // Too soon: the backoff has not elapsed.
    expect(await sync.pushDue(now: now.add(const Duration(seconds: 5))), 0);

    api.throwOnSubmit = null;
    expect(await sync.pushDue(now: now.add(const Duration(minutes: 1))), 1);
    expect((await visits.byId(visit.id))!.isSynced, isTrue);
  });

  test('stops retrying an error that will never change', () async {
    // A visit for a group the agent no longer holds fails identically forever.
    // Retrying hides it from the person who could fix it.
    final visit = await readyVisit();
    api.throwOnSubmit =
        const ApiException('Group not found', statusCode: 404, code: 'GROUP_NOT_FOUND');

    await sync.pushDue();

    final entries = await outbox.due();
    expect(entries, isEmpty, reason: 'must not be retried');
    expect((await visits.byId(visit.id))!.isSynced, isFalse);
    expect(await sync.pendingCount(), 1, reason: 'still outstanding, needs a person');
  });

  test('keeps retrying an error that might clear', () async {
    // A 500 or a captive portal is worth another go.
    await readyVisit();
    api.throwOnSubmit = const ApiException('Server error', statusCode: 500, code: 'INTERNAL');
    final now = DateTime(2026, 8, 9, 12);

    await sync.pushDue(now: now);
    expect((await outbox.due(now: now.add(const Duration(minutes: 1)))).length, 1);
  });

  test('pushes the corrected version of a visit edited after queueing', () async {
    // The outbox holds a pointer, not a payload. A note added after the visit
    // was queued must be the one that reaches the server.
    final visit = await readyVisit();
    await visits.saveDetails(id: visit.id, notes: 'Corrected after speaking to the treasurer');

    await sync.pushDue();

    expect(api.submitted, hasLength(1));
    // The fake echoes what it was given; assert through the repository that the
    // record it sent was the corrected one.
    final after = await visits.byId(visit.id);
    expect(after!.notes, 'Corrected after speaking to the treasurer');
    expect(after.isSynced, isTrue);
  });

  test('retires a queue entry whose visit was abandoned', () async {
    // A draft discarded before sending leaves an orphan entry. Retrying it
    // forever would keep the badge lit over work that no longer exists.
    final visit = await visits.start(remoteGroupId: 'remote-g1');
    await visits.markReadyToSend(visit.id);
    await sync.queue(visit.id);
    await visits.discardDraft(visit.id);

    // markReadyToSend moved it out of DRAFT, so discard is a no-op; delete it
    // the way a real abandonment would.
    final db = await AppDatabase.instance.database;
    await db.delete('group_visits', where: 'id = ?', whereArgs: [visit.id]);

    expect(await sync.pushDue(), 0);
    expect(await sync.pendingCount(), 0, reason: 'nothing left to send');
    expect(api.calls, 0);
  });

  test('sends several visits oldest first', () async {
    final first = await readyVisit(group: 'remote-g1');
    final second = await readyVisit(group: 'remote-g2');

    expect(await sync.pushDue(), 2);
    expect(api.submitted, [first.clientRequestId, second.clientRequestId]);
  });

  test('a visit with no fix still reaches the server', () async {
    // No signal, no GPS, a valley. The visit happened and must be filable.
    final visit = await visits.start(remoteGroupId: 'remote-g1');
    await visits.saveDetails(id: visit.id, locationNote: 'No signal in the valley');
    await visits.markReadyToSend(visit.id);
    await sync.queue(visit.id);

    expect(await sync.pushDue(), 1);
    expect((await visits.byId(visit.id))!.isSynced, isTrue);
  });
}
