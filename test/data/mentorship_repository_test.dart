import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/core/utils/action_item_state.dart';
import 'package:intellicash_mobile/data/repositories/mentorship_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Coaching, the group's score, and the work agreed for next time.
///
/// The property carrying the most weight: last visit's open items are on the
/// phone, so they are on screen when the next visit starts — in a field, with
/// no signal.
void main() {
  late Directory tempDir;
  late MentorshipRepository mentorship;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_mentorship');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    mentorship = MentorshipRepository();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    AppDatabase.overrideFactory = null;
    AppDatabase.overridePath = null;
    await tempDir.delete(recursive: true);
  });

  Future<void> seedVisit(String visitId, {String? remoteId}) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('group_visits', {
      'id': visitId,
      'client_request_id': 'visit-$visitId',
      'remote_group_id': 'remote-g1',
      'visit_type': 'FOLLOW_UP',
      'status': 'DRAFT',
      'started_at': now,
      'remote_id': remoteId,
      'created_at': now,
      'updated_at': now,
    });
  }

  group('coaching', () {
    test('records a session against its topic', () async {
      await seedVisit('v1');
      await mentorship.recordSession(
        visitId: 'v1',
        topicKey: 'record_keeping',
        topicTitle: 'Record keeping',
        notes: 'Walked the ledger.',
        durationMinutes: 25,
      );

      final sessions = await mentorship.sessionsFor('v1');
      expect(sessions, hasLength(1));
      expect(sessions.single.topicTitle, 'Record keeping');
      expect(sessions.single.durationMinutes, 25);
    });

    test('recording the same topic twice replaces rather than duplicates',
        () async {
      // Coaching one topic twice in a visit is one session with better notes.
      await seedVisit('v1');
      await mentorship.recordSession(
        visitId: 'v1',
        topicKey: 'governance',
        topicTitle: 'Governance',
        notes: 'First pass.',
      );
      await mentorship.recordSession(
        visitId: 'v1',
        topicKey: 'governance',
        topicTitle: 'Governance',
        notes: 'Elections are overdue.',
      );

      final sessions = await mentorship.sessionsFor('v1');
      expect(sessions, hasLength(1));
      expect(sessions.single.notes, 'Elections are overdue.');
    });

    test('refuses a score outside 1-5 rather than clamping it', () async {
      // A clamped 9 becomes a 5 the group never gave, which is worse than
      // losing the tap.
      await seedVisit('v1');

      expect(
        await mentorship.recordRating(visitId: 'v1', dimensionKey: 'clarity', score: 9),
        isFalse,
      );
      expect(
        await mentorship.recordRating(visitId: 'v1', dimensionKey: 'clarity', score: 0),
        isFalse,
      );
      expect(await mentorship.ratingsFor('v1'), isEmpty);

      expect(
        await mentorship.recordRating(visitId: 'v1', dimensionKey: 'clarity', score: 4),
        isTrue,
      );
      expect(await mentorship.ratingsFor('v1'), hasLength(1));
    });

    test('defaults the rating to the group representative, not the agent', () async {
      await seedVisit('v1');
      await mentorship.recordRating(visitId: 'v1', dimensionKey: 'clarity', score: 5);

      expect(await mentorship.ratingsFor('v1'), hasLength(1));
      expect((await mentorship.ratingsFor('v1')).single.ratedByRole,
          'GROUP_REPRESENTATIVE');
    });

    test('knows when there is nothing worth pushing', () async {
      await seedVisit('v1');
      expect(await mentorship.hasMentorship('v1'), isFalse);

      await mentorship.recordSession(
          visitId: 'v1', topicKey: 'governance', topicTitle: 'Governance');
      expect(await mentorship.hasMentorship('v1'), isTrue);
    });

    test('coaching is removed with the visit it belongs to', () async {
      final db = await AppDatabase.instance.database;
      await seedVisit('v1');
      await mentorship.recordSession(
          visitId: 'v1', topicKey: 'governance', topicTitle: 'Governance');
      await mentorship.recordRating(visitId: 'v1', dimensionKey: 'clarity', score: 4);

      await db.delete('group_visits', where: 'id = ?', whereArgs: ['v1']);

      expect(await mentorship.sessionsFor('v1'), isEmpty);
      expect(await mentorship.ratingsFor('v1'), isEmpty);
    });
  });

  group('the action plan', () {
    test('raises work and marks it late from the date, with no job running',
        () async {
      await seedVisit('v1');
      final item = await mentorship.raise(
        visitId: 'v1',
        remoteGroupId: 'remote-g1',
        title: 'Write up the ledger',
        owner: 'the treasurer',
        dueDate: DateTime.now().subtract(const Duration(days: 4)),
      );

      expect(item.state.state, ActionItemState.overdue);
      expect(item.state.daysOverdue, greaterThanOrEqualTo(3));
      expect(item.isDirty, isTrue);
    });

    test('shows the group what it still owes, worst first', () async {
      // This is the list an agent meets at the START of the next visit.
      await seedVisit('v1');
      await mentorship.raise(
        visitId: 'v1',
        remoteGroupId: 'remote-g1',
        title: 'Open a bank account',
        dueDate: DateTime.now().add(const Duration(days: 40)),
      );
      await mentorship.raise(
        visitId: 'v1',
        remoteGroupId: 'remote-g1',
        title: 'Write up the ledger',
        dueDate: DateTime.now().subtract(const Duration(days: 20)),
      );

      final open = await mentorship.openItemsFor('remote-g1');
      expect(open.map((i) => i.title).toList(),
          ['Write up the ledger', 'Open a bank account']);
    });

    test('a closed item leaves the queue but stays on the record', () async {
      await seedVisit('v1');
      final item = await mentorship.raise(
        visitId: 'v1',
        remoteGroupId: 'remote-g1',
        title: 'Write up the ledger',
        dueDate: DateTime.now().subtract(const Duration(days: 20)),
      );

      await mentorship.setStatus(
        id: item.id,
        status: 'DONE',
        closingNote: 'Seen, written up.',
        closedAtVisitId: 'v1',
      );

      expect(await mentorship.openItemsFor('remote-g1'), isEmpty);
      // Closed late is not outstanding.
      final all = await mentorship.itemsForVisit('v1');
      expect(all.single.state.state, ActionItemState.done);
      expect(all.single.state.daysOverdue, 0);
      expect(all.single.state.open, isFalse);
    });

    test('caches the server\'s items so they are there without signal', () async {
      final written = await mentorship.cacheFromServer(
        remoteGroupId: 'remote-g1',
        items: [
          {
            'id': 'remote-a1',
            'title': 'Elect a new treasurer',
            'status': 'OPEN',
            'dueDate': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          }
        ],
      );

      expect(written, 1);
      final open = await mentorship.openItemsFor('remote-g1');
      expect(open.single.title, 'Elect a new treasurer');
      expect(open.single.state.state, ActionItemState.overdue);
      // Came from the server, so nothing to push back.
      expect(open.single.isDirty, isFalse);
    });

    test('a server refresh never undoes an unsynced local change', () async {
      // An agent marks something done in a field and has not synced. The server
      // snapshot predates that, and must not resurrect the item.
      await seedVisit('v1');
      await mentorship.cacheFromServer(
        remoteGroupId: 'remote-g1',
        items: [
          {'id': 'remote-a1', 'title': 'Elect a new treasurer', 'status': 'OPEN'}
        ],
      );
      final cached = (await mentorship.openItemsFor('remote-g1')).single;
      await mentorship.setStatus(id: cached.id, status: 'DONE');

      await mentorship.cacheFromServer(
        remoteGroupId: 'remote-g1',
        items: [
          {'id': 'remote-a1', 'title': 'Elect a new treasurer', 'status': 'OPEN'}
        ],
      );

      expect(await mentorship.openItemsFor('remote-g1'), isEmpty);
      expect(await mentorship.pendingCount(), 1);
    });

    test('re-caching an unchanged item does not duplicate it', () async {
      for (var i = 0; i < 3; i++) {
        await mentorship.cacheFromServer(
          remoteGroupId: 'remote-g1',
          items: [
            {'id': 'remote-a1', 'title': 'Elect a new treasurer', 'status': 'OPEN'}
          ],
        );
      }

      expect(await mentorship.openItemsFor('remote-g1'), hasLength(1));
    });

    test('tracks what still needs pushing', () async {
      await seedVisit('v1');
      final item = await mentorship.raise(
        visitId: 'v1',
        remoteGroupId: 'remote-g1',
        title: 'Write up the ledger',
      );
      expect(await mentorship.pendingCount(), 1);
      expect((await mentorship.dirty()).single.id, item.id);

      await mentorship.markSynced(id: item.id, remoteId: 'remote-a9');

      expect(await mentorship.pendingCount(), 0);
      expect(await mentorship.dirty(), isEmpty);
    });

    /// An agent standing in a field agrees three things and closes one. Until
    /// `AgreedActionsCard` shipped, `raise()` had no caller anywhere in the
    /// app: every one of these steps was reachable from a test and from
    /// nothing else, so the visit produced no record of what was agreed.
    test('keeps each visit own actions, and the group list holds both',
        () async {
      await seedVisit('v1');
      await seedVisit('v2');

      await mentorship.raise(
        visitId: 'v1',
        remoteGroupId: 'remote-g1',
        title: 'Agreed at the first visit',
      );
      await mentorship.raise(
        visitId: 'v2',
        remoteGroupId: 'remote-g1',
        title: 'Agreed at the second visit',
      );

      final first = await mentorship.itemsForVisit('v1');
      final second = await mentorship.itemsForVisit('v2');

      expect(first.map((item) => item.title), ['Agreed at the first visit']);
      expect(second.map((item) => item.title), ['Agreed at the second visit']);

      // Both are still the group's outstanding work, which is what the next
      // agent meets before they begin.
      final open = await mentorship.openItemsFor('remote-g1');
      expect(open, hasLength(2));
    });

    /// The server nests the date inside `state`, because lateness is derived
    /// there on every read. The phone reads a flat `dueDate` first and falls
    /// back to the nested one -- so this pins the shape the server ACTUALLY
    /// sends, not the one the mapping happens to try first.
    test('keeps the due date when the server sends it nested in state',
        () async {
      await seedVisit('v1', remoteId: 'remote-v1');

      final written = await mentorship.cacheFromServer(
        remoteGroupId: 'remote-g1',
        items: [
          {
            'id': 'remote-a1',
            'visitId': 'remote-v1',
            'title': 'Open a group bank account',
            'owner': 'Treasurer',
            'status': 'OPEN',
            'state': {
              'state': 'OPEN',
              'label': 'Open',
              'dueDate': '2026-09-30T00:00:00.000Z',
              'daysOverdue': 0,
              'open': true,
            },
          },
        ],
      );

      expect(written, 1);
      final cached = (await mentorship.openItemsFor('remote-g1')).single;
      expect(cached.dueDate, isNotNull);
      expect(cached.dueDate!.year, 2026);
      expect(cached.dueDate!.month, 9);
      expect(cached.dueDate!.day, 30);
    });

    test('records which visit signed an item off, and clears it on reopen',
        () async {
      await seedVisit('v1');
      final item = await mentorship.raise(
        visitId: 'v1',
        remoteGroupId: 'remote-g1',
        title: 'Write up the ledger',
      );

      await mentorship.setStatus(
        id: item.id,
        status: 'DONE',
        closedAtVisitId: 'v1',
      );

      var stored = (await mentorship.itemsForVisit('v1')).single;
      expect(stored.status, 'DONE');
      // Traceable both ways: where it was agreed, and where it was closed.
      expect(stored.closedAtVisitId, 'v1');
      expect(stored.isDirty, isTrue);

      await mentorship.setStatus(id: item.id, status: 'OPEN');

      stored = (await mentorship.itemsForVisit('v1')).single;
      expect(stored.status, 'OPEN');
      // It is open again, so it belongs back on the group's outstanding list.
      expect(await mentorship.openItemsFor('remote-g1'), hasLength(1));
    });
  });
}
