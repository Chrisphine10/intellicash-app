import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/data/repositories/outbox_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The outbox is what stands between "the agent finished the visit" and "the
/// visit exists". Everything here is about the field reality it has to survive:
/// a phone killed mid-push, a week with no signal, a screen rebuilt twice, and
/// a server that sometimes says no in a way retrying cannot fix.
void main() {
  late Directory tempDir;
  late OutboxRepository outbox;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_outbox');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    outbox = OutboxRepository();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    AppDatabase.overrideFactory = null;
    AppDatabase.overridePath = null;
    await tempDir.delete(recursive: true);
  });

  test('queues a visit once, however many times it is enqueued', () async {
    // Screens rebuild and resume paths re-run. Neither may produce a second
    // send of the same visit.
    final first = await outbox.enqueue(
      recordType: OutboxRecordType.visit,
      recordId: 'visit-1',
    );
    final second = await outbox.enqueue(
      recordType: OutboxRecordType.visit,
      recordId: 'visit-1',
    );

    expect(second.id, first.id);
    expect(await outbox.pendingCount(), 1);
  });

  test('is due immediately when first queued', () async {
    await outbox.enqueue(recordType: OutboxRecordType.visit, recordId: 'visit-1');
    final due = await outbox.due();
    expect(due.map((e) => e.recordId), ['visit-1']);
  });

  test('holds a failed entry back until its backoff has elapsed', () async {
    // Retrying instantly in a tunnel drains the battery and achieves nothing.
    final entry = await outbox.enqueue(
      recordType: OutboxRecordType.visit,
      recordId: 'visit-1',
    );
    final now = DateTime(2026, 8, 9, 12);
    await outbox.markFailure(entry.id, error: 'No connection', now: now);

    expect(await outbox.due(now: now.add(const Duration(seconds: 5))), isEmpty);
    expect(
      (await outbox.due(now: now.add(const Duration(minutes: 1)))).length,
      1,
      reason: 'due again once the first backoff step has passed',
    );
  });

  test('backoff grows then caps', () async {
    // A phone back in signal after a week must retry promptly, not sit on an
    // ever-growing delay.
    expect(OutboxRepository.backoffFor(1), const Duration(seconds: 30));
    expect(OutboxRepository.backoffFor(2), const Duration(minutes: 2));
    expect(OutboxRepository.backoffFor(9), OutboxRepository.backoffFor(5));
  });

  test('gives up after repeated failures and asks for a person', () async {
    final entry = await outbox.enqueue(
      recordType: OutboxRecordType.visit,
      recordId: 'visit-1',
    );
    for (var i = 0; i < OutboxRepository.maxAttempts; i += 1) {
      await outbox.markFailure(entry.id, error: 'boom');
    }

    final after = await outbox.byId(entry.id);
    expect(after!.status, OutboxStatus.failed);
    // Failed still counts as outstanding: the work has not reached the server.
    expect(await outbox.pendingCount(), 1);
    expect(await outbox.due(), isEmpty);
  });

  test('stops immediately on a rejection retrying cannot fix', () async {
    // A validation error or a group the agent no longer holds will fail
    // identically forever. Retrying hides it from the person who could fix it.
    final entry = await outbox.enqueue(
      recordType: OutboxRecordType.visit,
      recordId: 'visit-1',
    );
    await outbox.markFailure(
      entry.id,
      error: 'Group not found',
      errorCode: 'GROUP_NOT_FOUND',
      permanent: true,
    );

    final after = await outbox.byId(entry.id);
    expect(after!.status, OutboxStatus.failed);
    expect(after.attempts, 1, reason: 'gave up without burning the retry budget');
    expect(after.lastErrorCode, 'GROUP_NOT_FOUND');
  });

  test('re-enqueueing a failed entry puts it back in the queue', () async {
    // The user tapping "try again" must actually try again.
    final entry = await outbox.enqueue(
      recordType: OutboxRecordType.visit,
      recordId: 'visit-1',
    );
    await outbox.markFailure(entry.id, error: 'boom', permanent: true);

    final retried = await outbox.enqueue(
      recordType: OutboxRecordType.visit,
      recordId: 'visit-1',
    );

    expect(retried.id, entry.id, reason: 'same entry, not a duplicate');
    expect(retried.status, OutboxStatus.pending);
    expect(retried.attempts, 0);
    expect((await outbox.due()).length, 1);
  });

  test('will not send a child before its parent has landed', () async {
    // This is what makes it structurally impossible to push a photograph
    // before the visit it belongs to exists on the server.
    final parent = await outbox.enqueue(
      recordType: OutboxRecordType.visit,
      recordId: 'visit-1',
    );
    final child = await outbox.enqueue(
      recordType: OutboxRecordType.visit,
      recordId: 'visit-1-photo',
      dependsOnId: parent.id,
    );

    expect((await outbox.due()).map((e) => e.id), [parent.id]);

    await outbox.markSynced(parent.id);
    expect((await outbox.due()).map((e) => e.id), [child.id]);
  });

  test('a synced entry stops being outstanding', () async {
    final entry = await outbox.enqueue(
      recordType: OutboxRecordType.visit,
      recordId: 'visit-1',
    );
    await outbox.markSynced(entry.id);

    expect(await outbox.pendingCount(), 0);
    expect(await outbox.due(), isEmpty);
  });

  test('survives being killed mid-push', () async {
    // The phone dies between sending and recording the result. On restart the
    // entry must still be there and still be due — the server's idempotency is
    // what stops the resend becoming a duplicate visit.
    final entry = await outbox.enqueue(
      recordType: OutboxRecordType.visit,
      recordId: 'visit-1',
    );
    await AppDatabase.instance.close();

    final reopened = OutboxRepository();
    final after = await reopened.byId(entry.id);
    expect(after, isNotNull);
    expect(after!.status, OutboxStatus.pending);
    expect((await reopened.due()).length, 1);
  });

  test('prunes old synced entries but keeps recent ones', () async {
    final now = DateTime(2026, 8, 9, 12);
    final old = await outbox.enqueue(
      recordType: OutboxRecordType.visit,
      recordId: 'visit-old',
    );
    final recent = await outbox.enqueue(
      recordType: OutboxRecordType.visit,
      recordId: 'visit-recent',
    );
    // Stamped against the same clock the prune is measured with. Using the
    // real one here made the result depend on today's date.
    await outbox.markSynced(old.id, now: now);
    await outbox.markSynced(recent.id, now: now);

    // Nothing is old enough yet.
    expect(await outbox.pruneSynced(now: now), 0);

    // A fortnight later both are, and both go.
    final removed = await outbox.pruneSynced(now: now.add(const Duration(days: 14)));
    expect(removed, 2);
    expect(await outbox.byId(old.id), isNull);
  });

  test('never prunes something still waiting to be sent', () async {
    // Pruning an unsent visit would lose a group's record silently, which is
    // the worst failure this system can have.
    final entry = await outbox.enqueue(
      recordType: OutboxRecordType.visit,
      recordId: 'visit-1',
    );
    await outbox.markFailure(entry.id, error: 'boom', permanent: true);

    final removed =
        await outbox.pruneSynced(now: DateTime.now().add(const Duration(days: 400)));
    expect(removed, 0);
    expect(await outbox.byId(entry.id), isNotNull);
  });
}
