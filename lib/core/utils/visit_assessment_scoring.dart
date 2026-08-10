/// Dart mirror of the server's `visit-assessment-contract.ts`.
///
/// The phone scores the assessment locally so an agent sees a band the moment
/// they finish, standing in a field with no signal. That figure is
/// **provisional**: the server re-scores on submit and its answer is the one
/// that is stored. If the two ever disagree, this file is wrong.
///
/// Keeping two implementations honest is the whole risk here, so a golden
/// fixture — `test/fixtures/visit_assessment_golden.json`, byte-identical to
/// the copy in the API repo — is asserted by both suites. Change the rules in
/// one engine and the other's tests go red.
library;

const String visitAssessmentContractVersion = '1.0.0';

/// What an agent can answer. `credit` is the fraction of a question's weight
/// earned; null means the question leaves the denominator entirely.
enum AssessmentChoice {
  yes('YES', 'Yes', 1),
  partial('PARTIAL', 'Partial', 0.5),
  no('NO', 'No', 0),
  notApplicable('NOT_APPLICABLE', 'Not applicable', null);

  const AssessmentChoice(this.key, this.label, this.credit);

  final String key;
  final String label;
  final double? credit;

  static AssessmentChoice? fromKey(String? key) {
    if (key == null) return null;
    for (final choice in AssessmentChoice.values) {
      if (choice.key == key) return choice;
    }
    return null;
  }
}

class AssessmentQuestionSnapshot {
  const AssessmentQuestionSnapshot({
    required this.key,
    required this.prompt,
    required this.weight,
    required this.position,
    this.guidance,
    this.requiresNote = false,
  });

  final String key;
  final String prompt;
  final double weight;
  final int position;
  final String? guidance;
  final bool requiresNote;

  factory AssessmentQuestionSnapshot.fromJson(Map<String, dynamic> json) {
    return AssessmentQuestionSnapshot(
      key: json['key'] as String,
      prompt: json['prompt'] as String,
      weight: (json['weight'] as num).toDouble(),
      position: (json['position'] as num).toInt(),
      guidance: json['guidance'] as String?,
      requiresNote: json['requiresNote'] as bool? ?? false,
    );
  }
}

class AssessmentSectionSnapshot {
  const AssessmentSectionSnapshot({
    required this.key,
    required this.title,
    required this.position,
    required this.questions,
    this.description,
  });

  final String key;
  final String title;
  final int position;
  final List<AssessmentQuestionSnapshot> questions;
  final String? description;

  factory AssessmentSectionSnapshot.fromJson(Map<String, dynamic> json) {
    return AssessmentSectionSnapshot(
      key: json['key'] as String,
      title: json['title'] as String,
      position: (json['position'] as num).toInt(),
      description: json['description'] as String?,
      questions: (json['questions'] as List<dynamic>)
          .map((q) => AssessmentQuestionSnapshot.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}

class AssessmentBandSnapshot {
  const AssessmentBandSnapshot({
    required this.key,
    required this.label,
    required this.minPoints,
    required this.maxPoints,
    this.guidance,
  });

  final String key;
  final String label;
  final double minPoints;
  final double maxPoints;
  final String? guidance;

  factory AssessmentBandSnapshot.fromJson(Map<String, dynamic> json) {
    return AssessmentBandSnapshot(
      key: json['key'] as String,
      label: json['label'] as String,
      minPoints: (json['minPoints'] as num).toDouble(),
      maxPoints: (json['maxPoints'] as num).toDouble(),
      guidance: json['guidance'] as String?,
    );
  }
}

/// A frozen template: everything needed to render and score, with no server
/// round-trip. Cached on the device and re-downloaded only when its checksum
/// moves.
class AssessmentTemplateSnapshot {
  const AssessmentTemplateSnapshot({
    required this.templateId,
    required this.version,
    required this.title,
    required this.sections,
    required this.bands,
    required this.maxPoints,
    required this.scoringContractVersion,
    this.description,
  });

  final String templateId;
  final int version;
  final String title;
  final List<AssessmentSectionSnapshot> sections;
  final List<AssessmentBandSnapshot> bands;
  final double maxPoints;
  final String scoringContractVersion;
  final String? description;

  factory AssessmentTemplateSnapshot.fromJson(Map<String, dynamic> json) {
    return AssessmentTemplateSnapshot(
      templateId: json['templateId'] as String,
      version: (json['version'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String?,
      maxPoints: (json['maxPoints'] as num).toDouble(),
      scoringContractVersion: json['scoringContractVersion'] as String,
      sections: (json['sections'] as List<dynamic>)
          .map((s) => AssessmentSectionSnapshot.fromJson(s as Map<String, dynamic>))
          .toList(),
      bands: (json['bands'] as List<dynamic>)
          .map((b) => AssessmentBandSnapshot.fromJson(b as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Every question across every section, in render order.
  Iterable<AssessmentQuestionSnapshot> get allQuestions sync* {
    for (final section in orderedSections) {
      yield* section.questions;
    }
  }

  List<AssessmentSectionSnapshot> get orderedSections {
    final sorted = [...sections]..sort((a, b) => a.position.compareTo(b.position));
    return sorted;
  }
}

class AssessmentAnswerInput {
  const AssessmentAnswerInput({
    required this.questionKey,
    required this.choice,
    this.note,
  });

  final String questionKey;
  final String choice;
  final String? note;

  Map<String, dynamic> toJson() => {
        'questionKey': questionKey,
        'choice': choice,
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}

class AssessmentQuestionResult {
  const AssessmentQuestionResult({
    required this.questionKey,
    required this.sectionKey,
    required this.prompt,
    required this.weight,
    required this.choice,
    required this.earnedPoints,
    required this.applicablePoints,
    required this.answered,
    required this.excluded,
    this.note,
  });

  final String questionKey;
  final String sectionKey;
  final String prompt;
  final double weight;
  final AssessmentChoice? choice;
  final double earnedPoints;
  final double applicablePoints;
  final bool answered;
  final bool excluded;
  final String? note;
}

class AssessmentSectionResult {
  const AssessmentSectionResult({
    required this.sectionKey,
    required this.title,
    required this.position,
    required this.earnedPoints,
    required this.applicablePoints,
    required this.percentage,
    required this.questions,
  });

  final String sectionKey;
  final String title;
  final int position;
  final double earnedPoints;
  final double applicablePoints;

  /// Null when every question in the section was marked not applicable.
  final double? percentage;
  final List<AssessmentQuestionResult> questions;
}

class AssessmentScore {
  const AssessmentScore({
    required this.scoringContractVersion,
    required this.templateId,
    required this.templateVersion,
    required this.earnedPoints,
    required this.applicablePoints,
    required this.maxPoints,
    required this.scaledPoints,
    required this.percentage,
    required this.bandKey,
    required this.bandLabel,
    required this.sections,
    required this.unansweredKeys,
    required this.unknownAnswerKeys,
    required this.complete,
    this.bandGuidance,
  });

  final String scoringContractVersion;
  final String templateId;
  final int templateVersion;
  final double earnedPoints;
  final double applicablePoints;
  final double maxPoints;
  final double scaledPoints;
  final double percentage;
  final String? bandKey;
  final String? bandLabel;
  final String? bandGuidance;
  final List<AssessmentSectionResult> sections;
  final List<String> unansweredKeys;
  final List<String> unknownAnswerKeys;
  final bool complete;
}

/// Scores answers against a snapshot. Total: any input, including none,
/// produces a defined score.
///
/// Two asymmetries, matching the server exactly:
///
/// - **Unanswered scores 0 but stays in the denominator.** Skipping a question
///   is not the same as it not applying, and must not quietly raise the score.
/// - **Not-applicable leaves the denominator**, and what remains is rescaled
///   onto the full range before banding, so a group with inapplicable questions
///   is still judged on the same scale as everyone else.
AssessmentScore scoreAssessment(
  AssessmentTemplateSnapshot snapshot,
  List<AssessmentAnswerInput> answers,
) {
  // Last write wins, as on the server: a resent payload may carry a correction,
  // and throwing on a duplicate would reject the whole visit.
  final byKey = <String, AssessmentAnswerInput>{};
  for (final answer in answers) {
    byKey[answer.questionKey] = answer;
  }

  final knownKeys = <String>{};
  final unansweredKeys = <String>[];
  final sectionResults = <AssessmentSectionResult>[];

  var earnedPoints = 0.0;
  var applicablePoints = 0.0;

  for (final section in snapshot.orderedSections) {
    final questions = [...section.questions]
      ..sort((a, b) => a.position.compareTo(b.position));
    final questionResults = <AssessmentQuestionResult>[];
    var sectionEarned = 0.0;
    var sectionApplicable = 0.0;

    for (final question in questions) {
      knownKeys.add(question.key);
      final answer = byKey[question.key];
      final choice = AssessmentChoice.fromKey(answer?.choice);
      final excluded = choice == AssessmentChoice.notApplicable;

      if (choice == null) unansweredKeys.add(question.key);

      final credit = choice?.credit;
      final questionApplicable = excluded ? 0.0 : question.weight;
      final questionEarned = credit == null ? 0.0 : _round2(question.weight * credit);

      sectionEarned += questionEarned;
      sectionApplicable += questionApplicable;

      questionResults.add(
        AssessmentQuestionResult(
          questionKey: question.key,
          sectionKey: section.key,
          prompt: question.prompt,
          weight: question.weight,
          choice: choice,
          earnedPoints: questionEarned,
          applicablePoints: questionApplicable,
          answered: choice != null,
          excluded: excluded,
          note: answer?.note,
        ),
      );
    }

    sectionEarned = _round2(sectionEarned);
    sectionApplicable = _round2(sectionApplicable);
    earnedPoints += sectionEarned;
    applicablePoints += sectionApplicable;

    sectionResults.add(
      AssessmentSectionResult(
        sectionKey: section.key,
        title: section.title,
        position: section.position,
        earnedPoints: sectionEarned,
        applicablePoints: sectionApplicable,
        percentage: sectionApplicable > 0
            ? _round2((sectionEarned / sectionApplicable) * 100)
            : null,
        questions: questionResults,
      ),
    );
  }

  earnedPoints = _round2(earnedPoints);
  applicablePoints = _round2(applicablePoints);

  final percentage =
      applicablePoints > 0 ? _round2((earnedPoints / applicablePoints) * 100) : 0.0;
  final scaledPoints = _round2((percentage / 100) * snapshot.maxPoints);
  final band = bandForPoints(snapshot, scaledPoints);

  final unknownAnswerKeys =
      byKey.keys.where((key) => !knownKeys.contains(key)).toList();

  return AssessmentScore(
    scoringContractVersion: visitAssessmentContractVersion,
    templateId: snapshot.templateId,
    templateVersion: snapshot.version,
    earnedPoints: earnedPoints,
    applicablePoints: applicablePoints,
    maxPoints: snapshot.maxPoints,
    scaledPoints: scaledPoints,
    percentage: percentage,
    bandKey: band?.key,
    bandLabel: band?.label,
    bandGuidance: band?.guidance,
    sections: sectionResults,
    unansweredKeys: unansweredKeys,
    unknownAnswerKeys: unknownAnswerKeys,
    complete: unansweredKeys.isEmpty,
  );
}

/// The highest band the score reaches.
///
/// Matched on `minPoints` alone. Bands carry whole-number bounds but scores are
/// routinely fractional — half credit for Partial, and division when rescaling
/// around a not-applicable question — so testing the upper bound too would
/// leave values between two bands with no band at all.
AssessmentBandSnapshot? bandForPoints(
  AssessmentTemplateSnapshot snapshot,
  double points,
) {
  AssessmentBandSnapshot? best;
  for (final band in snapshot.bands) {
    if (points >= band.minPoints && (best == null || band.minPoints > best.minPoints)) {
      best = band;
    }
  }
  return best;
}

double _round2(double value) => (value * 100).round() / 100;
