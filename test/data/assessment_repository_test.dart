import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/data/repositories/assessment_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The scorecard as it behaves in the field: no signal, a phone that may die
/// mid-question, and an agent who changes their mind.
void main() {
  late Directory tempDir;
  late AssessmentRepository assessments;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_assessments');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    assessments = AssessmentRepository();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    AppDatabase.overrideFactory = null;
    AppDatabase.overridePath = null;
    await tempDir.delete(recursive: true);
  });

  Map<String, dynamic> snapshotJson({int version = 1}) => {
        'templateId': 'tmpl',
        'version': version,
        'title': 'Field assessment',
        'maxPoints': 6,
        'scoringContractVersion': '1.0.0',
        'sections': [
          {
            'key': 'governance',
            'title': 'Governance',
            'position': 0,
            'questions': [
              {'key': 'q1', 'prompt': 'One?', 'weight': 2, 'position': 0},
              {'key': 'q2', 'prompt': 'Two?', 'weight': 2, 'position': 1},
              {'key': 'q3', 'prompt': 'Three?', 'weight': 2, 'position': 2},
            ],
          },
        ],
        'bands': [
          {'key': 'weak', 'label': 'Weak', 'minPoints': 0, 'maxPoints': 2},
          {'key': 'fair', 'label': 'Fair', 'minPoints': 3, 'maxPoints': 4},
          {'key': 'strong', 'label': 'Strong', 'minPoints': 5, 'maxPoints': 6},
        ],
      };

  Future<void> cache({
    String id = 'snap1',
    int version = 1,
    String checksum = 'sum1',
  }) {
    return assessments.cacheSnapshot(
      snapshotId: id,
      templateId: 'tmpl',
      version: version,
      checksum: checksum,
      maxPoints: 6,
      scoringContractVersion: '1.0.0',
      snapshot: snapshotJson(version: version),
    );
  }

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

  Future<void> begin(String visitId) async {
    final snapshot = await assessments.currentSnapshot();
    await assessments.beginAssessment(visitId: visitId, snapshot: snapshot!);
  }

  group('the cached form', () {
    test('survives with no network, and reports its checksum', () async {
      await cache();

      expect(await assessments.currentChecksum(), 'sum1');
      final snapshot = await assessments.currentSnapshot();
      expect(snapshot!.snapshot.sections.first.questions.length, 3);
      expect(snapshot.maxPoints, 6);
    });

    test('a newer form becomes current without discarding the old one', () async {
      // A visit answered against v1 and still waiting in the outbox has to keep
      // rendering as v1, so replacing the row would lose the questions it was
      // actually answered against.
      await cache(id: 'snap1', version: 1, checksum: 'sum1');
      await cache(id: 'snap2', version: 2, checksum: 'sum2');

      expect(await assessments.currentChecksum(), 'sum2');
      expect((await assessments.snapshotById('snap1'))!.version, 1);
      expect((await assessments.currentSnapshot())!.version, 2);
    });

    test('reports no checksum before anything has been downloaded', () async {
      // A fresh install, or a deployment with no scorecard published yet.
      expect(await assessments.currentChecksum(), isNull);
      expect(await assessments.currentSnapshot(), isNull);
    });
  });

  group('answering', () {
    test('writes each answer immediately and rescores as it goes', () async {
      await cache();
      await seedVisit('v1');
      await begin('v1');

      var score = await assessments.answer(
        visitId: 'v1',
        sectionKey: 'governance',
        questionKey: 'q1',
        choice: 'YES',
      );
      expect(score!.earnedPoints, 2);
      expect(score.complete, isFalse);

      score = await assessments.answer(
        visitId: 'v1',
        sectionKey: 'governance',
        questionKey: 'q2',
        choice: 'PARTIAL',
      );
      expect(score!.earnedPoints, 3);

      score = await assessments.answer(
        visitId: 'v1',
        sectionKey: 'governance',
        questionKey: 'q3',
        choice: 'NO',
      );
      expect(score!.earnedPoints, 3);
      expect(score.complete, isTrue);
      expect(score.bandKey, 'fair');
    });

    test('an agent changing their mind overwrites rather than double-counts',
        () async {
      await cache();
      await seedVisit('v1');
      await begin('v1');

      await assessments.answer(
        visitId: 'v1',
        sectionKey: 'governance',
        questionKey: 'q1',
        choice: 'YES',
      );
      final score = await assessments.answer(
        visitId: 'v1',
        sectionKey: 'governance',
        questionKey: 'q1',
        choice: 'NO',
      );

      expect(score!.earnedPoints, 0);
      expect((await assessments.answersFor('v1')).length, 1);
      expect((await assessments.choicesFor('v1'))['q1'], 'NO');
    });

    test('a cleared answer goes back to unanswered, not to No', () async {
      // These are different facts. "No" scores zero and completes the form;
      // unanswered scores zero and leaves it incomplete.
      await cache();
      await seedVisit('v1');
      await begin('v1');

      await assessments.answer(
        visitId: 'v1',
        sectionKey: 'governance',
        questionKey: 'q1',
        choice: 'YES',
      );
      await assessments.clearAnswer(visitId: 'v1', questionKey: 'q1');

      final score = await assessments.rescore('v1');
      expect(score!.unansweredKeys, contains('q1'));
      expect(await assessments.choicesFor('v1'), isEmpty);
    });

    test('answers survive the app being killed and reopened', () async {
      await cache();
      await seedVisit('v1');
      await begin('v1');
      await assessments.answer(
        visitId: 'v1',
        sectionKey: 'governance',
        questionKey: 'q1',
        choice: 'YES',
      );

      // Simulate a cold start: close the database and build a new repository.
      await AppDatabase.instance.close();
      final reopened = AssessmentRepository();

      final score = await reopened.rescore('v1');
      expect(score!.earnedPoints, 2);
      expect((await reopened.choicesFor('v1'))['q1'], 'YES');
    });

    test('pins the form at the start, so publishing mid-visit changes nothing',
        () async {
      await cache(id: 'snap1', version: 1, checksum: 'sum1');
      await seedVisit('v1');
      await begin('v1');

      // IWL publishes v2 while the agent is halfway through.
      await cache(id: 'snap2', version: 2, checksum: 'sum2');

      final pending = await assessments.pending('v1');
      expect(pending!.snapshotId, 'snap1');
      expect(pending.checksum, 'sum1');
    });
  });

  group('pushing', () {
    test('a visit with no remote id is not yet ready to send', () async {
      await cache();
      await seedVisit('v1'); // no remote id
      await begin('v1');
      await assessments.answer(
        visitId: 'v1',
        sectionKey: 'governance',
        questionKey: 'q1',
        choice: 'YES',
      );

      // The assessment cannot be addressed before the visit exists centrally.
      expect(await assessments.visitsAwaitingAssessmentPush(), isEmpty);
    });

    test('a synced visit with answers is queued for its assessment', () async {
      await cache();
      await seedVisit('v1', remoteId: 'remote-v1');
      await begin('v1');
      await assessments.answer(
        visitId: 'v1',
        sectionKey: 'governance',
        questionKey: 'q1',
        choice: 'YES',
      );

      expect(await assessments.visitsAwaitingAssessmentPush(), ['v1']);
    });

    test('a visit where nothing was answered is not queued', () async {
      // An agent may legitimately record a visit without filling the form in.
      // Sending an empty assessment would create a zero-scored record that
      // reads as a failing group.
      await cache();
      await seedVisit('v1', remoteId: 'remote-v1');
      await begin('v1');

      expect(await assessments.visitsAwaitingAssessmentPush(), isEmpty);
    });

    test('stops being queued once the server has scored it', () async {
      await cache();
      await seedVisit('v1', remoteId: 'remote-v1');
      await begin('v1');
      await assessments.answer(
        visitId: 'v1',
        sectionKey: 'governance',
        questionKey: 'q1',
        choice: 'YES',
      );

      await assessments.markSynced(
        visitId: 'v1',
        earnedPoints: 2,
        percentage: 33.33,
        bandKey: 'weak',
        bandLabel: 'Weak',
      );

      expect(await assessments.visitsAwaitingAssessmentPush(), isEmpty);

      final db = await AppDatabase.instance.database;
      final row = (await db.query('visit_assessments',
              where: 'visit_id = ?', whereArgs: ['v1']))
          .first;
      // The server's figure replaces the phone's, and stops being provisional.
      expect(row['is_provisional'], 0);
      expect(row['percentage'], 33.33);
      expect(row['band_key'], 'weak');
    });

    test('sends the answers the agent actually gave', () async {
      await cache();
      await seedVisit('v1', remoteId: 'remote-v1');
      await begin('v1');
      await assessments.answer(
        visitId: 'v1',
        sectionKey: 'governance',
        questionKey: 'q1',
        choice: 'YES',
        note: 'Signed copy seen.',
      );
      await assessments.answer(
        visitId: 'v1',
        sectionKey: 'governance',
        questionKey: 'q2',
        choice: 'NOT_APPLICABLE',
      );

      final pending = await assessments.pending('v1');
      expect(pending!.answers.length, 2);
      final json = jsonEncode(pending.answers.map((a) => a.toJson()).toList());
      expect(json, contains('Signed copy seen.'));
      expect(json, contains('NOT_APPLICABLE'));
    });
  });
}
