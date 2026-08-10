import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/utils/visit_assessment_scoring.dart';

/// The phone's copy of the scoring rules.
///
/// The first group asserts the **golden fixture**, a byte-identical copy of the
/// one in the API repo (`apps/api/tests/fixtures/visit-assessment-golden.json`).
/// Both engines score the same snapshot and answers and must agree exactly.
/// That is the only thing standing between two implementations and silent
/// drift, so if this fails, do not adjust the expectation — find out which
/// engine changed. The server is authoritative.
void main() {
  group('golden fixture (shared with the API)', () {
    late AssessmentTemplateSnapshot snapshot;
    late List<AssessmentAnswerInput> answers;
    late Map<String, dynamic> expected;

    setUpAll(() {
      final raw = File('test/fixtures/visit_assessment_golden.json').readAsStringSync();
      final fixture = jsonDecode(raw) as Map<String, dynamic>;

      snapshot = AssessmentTemplateSnapshot.fromJson(
        fixture['snapshot'] as Map<String, dynamic>,
      );
      answers = (fixture['answers'] as List<dynamic>)
          .map((a) => AssessmentAnswerInput(
                questionKey: (a as Map<String, dynamic>)['questionKey'] as String,
                choice: a['choice'] as String,
              ))
          .toList();
      expected = fixture['expected'] as Map<String, dynamic>;
    });

    test('produces exactly the figures the server produced', () {
      final score = scoreAssessment(snapshot, answers);

      expect(score.scoringContractVersion, expected['scoringContractVersion']);
      expect(score.earnedPoints, (expected['earnedPoints'] as num).toDouble());
      expect(score.applicablePoints, (expected['applicablePoints'] as num).toDouble());
      expect(score.maxPoints, (expected['maxPoints'] as num).toDouble());
      expect(score.percentage, (expected['percentage'] as num).toDouble());
      expect(score.complete, expected['complete']);
      expect(score.unansweredKeys, expected['unansweredKeys']);
      expect(score.unknownAnswerKeys, expected['unknownAnswerKeys']);
    });

    test('bands the fractional rescaled score the same way', () {
      // The fixture deliberately lands on 7.78 — between the whole-number
      // bounds of two bands. Matching on both bounds left it with no band at
      // all, which is the bug this pins down.
      final score = scoreAssessment(snapshot, answers);

      expect(score.scaledPoints, (expected['scaledPoints'] as num).toDouble());
      expect(score.bandKey, expected['bandKey']);
      expect(score.bandLabel, expected['bandLabel']);
    });

    test('agrees section by section, not just on the total', () {
      final score = scoreAssessment(snapshot, answers);
      final expectedSections = expected['sections'] as List<dynamic>;

      expect(score.sections.length, expectedSections.length);
      for (var i = 0; i < expectedSections.length; i++) {
        final want = expectedSections[i] as Map<String, dynamic>;
        final got = score.sections[i];
        expect(got.sectionKey, want['sectionKey']);
        expect(got.earnedPoints, (want['earnedPoints'] as num).toDouble());
        expect(got.applicablePoints, (want['applicablePoints'] as num).toDouble());
        expect(got.percentage, (want['percentage'] as num?)?.toDouble());
      }
    });
  });

  group('scoring rules', () {
    AssessmentTemplateSnapshot buildSnapshot() {
      return AssessmentTemplateSnapshot.fromJson({
        'templateId': 't',
        'version': 1,
        'title': 'Test',
        'maxPoints': 6,
        'scoringContractVersion': visitAssessmentContractVersion,
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
          {'key': 'strong', 'label': 'Strong', 'minPoints': 5, 'maxPoints': 6},
          {'key': 'fair', 'label': 'Fair', 'minPoints': 3, 'maxPoints': 4},
          {'key': 'weak', 'label': 'Weak', 'minPoints': 0, 'maxPoints': 2},
        ],
      });
    }

    List<AssessmentAnswerInput> answersOf(Map<String, String> pairs) {
      return pairs.entries
          .map((e) => AssessmentAnswerInput(questionKey: e.key, choice: e.value))
          .toList();
    }

    test('scores Yes, Partial and No at full, half and no credit', () {
      final score = scoreAssessment(
        buildSnapshot(),
        answersOf({'q1': 'YES', 'q2': 'PARTIAL', 'q3': 'NO'}),
      );

      expect(score.earnedPoints, 3);
      expect(score.percentage, 50);
      expect(score.bandKey, 'fair');
      expect(score.complete, isTrue);
    });

    test('keeps an unanswered question in the denominator', () {
      final score = scoreAssessment(buildSnapshot(), answersOf({'q1': 'YES', 'q2': 'YES'}));

      expect(score.earnedPoints, 4);
      expect(score.applicablePoints, 6);
      expect(score.complete, isFalse);
      expect(score.unansweredKeys, ['q3']);
    });

    test('removes a not-applicable question and rescales the rest', () {
      final score = scoreAssessment(
        buildSnapshot(),
        answersOf({'q1': 'YES', 'q2': 'YES', 'q3': 'NOT_APPLICABLE'}),
      );

      expect(score.earnedPoints, 4);
      expect(score.applicablePoints, 4);
      expect(score.percentage, 100);
      expect(score.scaledPoints, 6);
      expect(score.bandKey, 'strong');
      expect(score.complete, isTrue);
    });

    test('is total: no answers still yields a defined score', () {
      final score = scoreAssessment(buildSnapshot(), []);

      expect(score.earnedPoints, 0);
      expect(score.percentage, 0);
      expect(score.bandKey, 'weak');
      expect(score.complete, isFalse);
    });

    test('does not divide by zero when everything is not applicable', () {
      final score = scoreAssessment(
        buildSnapshot(),
        answersOf({'q1': 'NOT_APPLICABLE', 'q2': 'NOT_APPLICABLE', 'q3': 'NOT_APPLICABLE'}),
      );

      expect(score.applicablePoints, 0);
      expect(score.percentage, 0);
      expect(score.scaledPoints.isNaN, isFalse);
    });

    test('ignores an answer to a question this form does not have', () {
      // A phone holding an older cached snapshot. Losing the visit over it
      // would be far worse than losing the one answer.
      final score = scoreAssessment(
        buildSnapshot(),
        answersOf({'q1': 'YES', 'gone_in_v2': 'YES'}),
      );

      expect(score.unknownAnswerKeys, ['gone_in_v2']);
      expect(score.earnedPoints, 2);
    });

    test('treats an unrecognised choice as unanswered rather than crediting it', () {
      final score = scoreAssessment(buildSnapshot(), answersOf({'q1': 'MAYBE'}));

      expect(score.earnedPoints, 0);
      expect(score.unansweredKeys, contains('q1'));
    });

    test('never leaves any score in the range unbanded', () {
      final snapshot = buildSnapshot();
      for (var tenths = 0; tenths <= 60; tenths++) {
        expect(
          bandForPoints(snapshot, tenths / 10),
          isNotNull,
          reason: 'no band for ${tenths / 10} points',
        );
      }
    });
  });
}
