import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/utils/visit_assessment_scoring.dart';
import 'package:intellicash_mobile/data/repositories/assessment_repository.dart';
import 'package:intellicash_mobile/features/visits/visit_assessment_screen.dart';

/// The scorecard screen as an agent meets it: a small phone, sunlight, and a
/// group waiting while they tap.
///
/// The repository is faked in memory rather than backed by sqflite. Two
/// reasons: a widget test runs in a fake-async zone where real file I/O never
/// completes (pumping does not advance it, so the screen would sit on its
/// spinner forever), and the database behaviour is already proved against real
/// sqflite in `test/data/assessment_repository_test.dart`. What is under test
/// here is the screen. The *scoring* is still the real thing — the fake calls
/// the same `scoreAssessment` the app does.
void main() {
  late _FakeAssessmentRepository repository;

  Map<String, dynamic> snapshotJson() => {
        'templateId': 'tmpl',
        'version': 1,
        'title': 'Field assessment',
        'maxPoints': 4,
        'scoringContractVersion': '1.0.0',
        'sections': [
          {
            'key': 'governance',
            'title': 'Governance',
            'position': 0,
            'questions': [
              {
                'key': 'q1',
                'prompt': 'Is there a constitution?',
                'weight': 2,
                'position': 0,
              },
            ],
          },
          {
            'key': 'records',
            'title': 'Record keeping',
            'position': 1,
            'questions': [
              {
                'key': 'q2',
                'prompt': 'Are passbooks current?',
                'weight': 2,
                'position': 0,
              },
            ],
          },
        ],
        'bands': [
          {'key': 'weak', 'label': 'Weak', 'minPoints': 0, 'maxPoints': 1},
          {'key': 'fair', 'label': 'Fair', 'minPoints': 2, 'maxPoints': 3},
          {'key': 'strong', 'label': 'Strong', 'minPoints': 4, 'maxPoints': 4},
        ],
      };

  setUp(() {
    repository = _FakeAssessmentRepository();
  });

  void giveForm() {
    repository.cached = CachedSnapshot(
      id: 'snap1',
      templateId: 'tmpl',
      version: 1,
      checksum: 'sum1',
      maxPoints: 4,
      snapshot: AssessmentTemplateSnapshot.fromJson(snapshotJson()),
    );
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VisitAssessmentScreen(
          visitId: 'v1',
          groupName: 'Tujijenge Women',
          repository: repository,
        ),
      ),
    );
    // Two pumps: one to build, one to apply the setState after _load resolves.
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows the first section and its questions', (tester) async {
    giveForm();
    await pump(tester);

    expect(find.text('Governance'), findsOneWidget);
    expect(find.text('Is there a constitution?'), findsOneWidget);
    expect(find.text('Section 1 of 2'), findsOneWidget);
    // All four answers must be reachable — "Not applicable" especially, since
    // it is what stops a group being marked down for something it cannot do.
    expect(find.text('Not applicable'), findsOneWidget);
  });

  testWidgets('scores as the agent taps, without waiting for the network',
      (tester) async {
    giveForm();
    await pump(tester);

    expect(find.textContaining('0 / 4'), findsOneWidget);

    await tester.tap(find.text('Yes'));
    await tester.pump();
    await tester.pump();

    // Half the form answered: 2 of 4 points, and a band the agent can report
    // to the group before leaving.
    expect(find.textContaining('2 / 4'), findsOneWidget);
    expect(find.textContaining('Fair'), findsOneWidget);
    expect(find.text('1 still to answer'), findsOneWidget);
  });

  testWidgets('tapping the same answer again clears it', (tester) async {
    // Unanswered and "No" are different facts, so an agent who taps by mistake
    // must be able to get back to unanswered rather than being stuck on No.
    giveForm();
    await pump(tester);

    await tester.tap(find.text('Yes'));
    await tester.pump();
    await tester.pump();
    expect(repository.answers, {'q1': 'YES'});

    await tester.tap(find.text('Yes'));
    await tester.pump();
    await tester.pump();
    expect(repository.answers, isEmpty);
  });

  testWidgets('a second section is reachable and scores into the same total',
      (tester) async {
    giveForm();
    await pump(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Record keeping'), findsOneWidget);
    expect(find.text('Are passbooks current?'), findsOneWidget);
    expect(find.text('Section 2 of 2'), findsOneWidget);

    await tester.tap(find.text('Yes'));
    await tester.pump();
    await tester.pump();

    expect(repository.answers, {'q2': 'YES'});
    expect(find.textContaining('2 / 4'), findsOneWidget);
  });

  testWidgets('shows answers already given when the screen is reopened',
      (tester) async {
    // Returning to a partly-filled form must not look empty — the answers are
    // on disk and the agent has to be able to see what is left.
    giveForm();
    repository.answers['q1'] = 'YES';

    await pump(tester);

    expect(find.textContaining('2 / 4'), findsOneWidget);
    expect(find.text('1 still to answer'), findsOneWidget);
  });

  testWidgets('says so plainly when no form has been downloaded', (tester) async {
    // A fresh install that has never had signal, or a deployment where IWL has
    // not published a scorecard yet. Neither may look like a crash.
    await pump(tester);

    expect(find.text('Form not available'), findsOneWidget);
    expect(find.textContaining('works offline'), findsOneWidget);
  });

  testWidgets('lays out on a 320x480 screen without overflowing', (tester) async {
    // The field device is a low-end handset, not the emulator's default.
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    giveForm();
    await pump(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Is there a constitution?'), findsOneWidget);
  });
}

/// An in-memory stand-in that keeps the real scoring.
class _FakeAssessmentRepository extends AssessmentRepository {
  CachedSnapshot? cached;
  final Map<String, String> answers = {};

  @override
  Future<CachedSnapshot?> currentSnapshot() async => cached;

  @override
  Future<void> beginAssessment({
    required String visitId,
    required CachedSnapshot snapshot,
  }) async {}

  @override
  Future<Map<String, String>> choicesFor(String visitId) async =>
      Map<String, String>.from(answers);

  @override
  Future<List<AssessmentAnswerInput>> answersFor(String visitId) async => answers.entries
      .map((entry) =>
          AssessmentAnswerInput(questionKey: entry.key, choice: entry.value))
      .toList();

  @override
  Future<AssessmentScore?> answer({
    required String visitId,
    required String sectionKey,
    required String questionKey,
    required String choice,
    String? note,
  }) async {
    answers[questionKey] = choice;
    return rescore(visitId);
  }

  @override
  Future<void> clearAnswer({
    required String visitId,
    required String questionKey,
  }) async {
    answers.remove(questionKey);
  }

  @override
  Future<AssessmentScore?> rescore(String visitId) async {
    final snapshot = cached;
    if (snapshot == null) return null;
    return scoreAssessment(snapshot.snapshot, await answersFor(visitId));
  }
}
