import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/visit_assessment_scoring.dart';

/// The cached scorecard and the answers an agent gives it.
///
/// Everything here works with no signal. The form is downloaded once and kept;
/// answers are written to disk as the agent taps rather than at the end, so an
/// app killed mid-visit loses at most the question in progress.
class AssessmentRepository {
  AssessmentRepository({AppDatabase? database, Uuid? uuid})
      : _database = database ?? AppDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<Database> get _db async => _database.database;

  // -------------------------------------------------------------------------
  // The cached form
  // -------------------------------------------------------------------------

  /// Stores a snapshot fetched from the server and marks it current.
  ///
  /// Older snapshots are kept, not deleted: a visit answered against v1 and
  /// still waiting in the outbox must render as v1 until it syncs.
  Future<void> cacheSnapshot({
    required String snapshotId,
    required String templateId,
    required int version,
    required String checksum,
    required double maxPoints,
    required String scoringContractVersion,
    required Map<String, dynamic> snapshot,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update('assessment_snapshots', {'is_current': 0});
      await txn.insert(
        'assessment_snapshots',
        {
          'id': snapshotId,
          'template_id': templateId,
          'version': version,
          'checksum': checksum,
          'max_points': maxPoints,
          'scoring_contract_version': scoringContractVersion,
          'snapshot_json': jsonEncode(snapshot),
          'is_current': 1,
          'fetched_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// The checksum of the cached current form, or null if there is none.
  ///
  /// The phone sends this when asking for the form so the server can answer
  /// "unchanged" — over 2G, re-downloading a 46-question document on every
  /// visit is the difference between a usable app and an unusable one.
  Future<String?> currentChecksum() async {
    final db = await _db;
    final rows = await db.query(
      'assessment_snapshots',
      columns: ['checksum'],
      where: 'is_current = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['checksum'] as String?;
  }

  Future<CachedSnapshot?> currentSnapshot() async {
    final db = await _db;
    final rows = await db.query(
      'assessment_snapshots',
      where: 'is_current = 1',
      orderBy: 'version DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CachedSnapshot.fromRow(rows.first);
  }

  Future<CachedSnapshot?> snapshotById(String snapshotId) async {
    final db = await _db;
    final rows = await db.query(
      'assessment_snapshots',
      where: 'id = ?',
      whereArgs: [snapshotId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CachedSnapshot.fromRow(rows.first);
  }

  // -------------------------------------------------------------------------
  // Answering
  // -------------------------------------------------------------------------

  /// Binds a visit to the form it is being answered against.
  ///
  /// Called once, when the agent opens the assessment. Pinning it here rather
  /// than at submit means a form published mid-visit cannot change the
  /// questions under an agent who is halfway through them.
  Future<void> beginAssessment({
    required String visitId,
    required CachedSnapshot snapshot,
  }) async {
    final db = await _db;
    final existing = await db.query(
      'visit_assessments',
      where: 'visit_id = ?',
      whereArgs: [visitId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    await db.insert('visit_assessments', {
      'visit_id': visitId,
      'snapshot_id': snapshot.id,
      'template_version': snapshot.version,
      'checksum': snapshot.checksum,
      'max_points': snapshot.maxPoints,
      'is_provisional': 1,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Records one answer and re-scores the visit.
  ///
  /// Written immediately rather than batched at the end: an agent is standing
  /// in a field with a phone that may die, and a lost afternoon of answers is
  /// not recoverable — the group has dispersed.
  Future<AssessmentScore?> answer({
    required String visitId,
    required String sectionKey,
    required String questionKey,
    required String choice,
    String? note,
  }) async {
    final db = await _db;
    await db.insert(
      'visit_answers',
      {
        'id': _uuid.v4(),
        'visit_id': visitId,
        'section_key': sectionKey,
        'question_key': questionKey,
        'choice': choice,
        'note': note,
        'answered_at': DateTime.now().toIso8601String(),
      },
      // The UNIQUE(visit_id, question_key) index turns a correction into an
      // overwrite. Two answers to one question would be scored inconsistently
      // by the phone and the server.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return rescore(visitId);
  }

  Future<void> clearAnswer({
    required String visitId,
    required String questionKey,
  }) async {
    final db = await _db;
    await db.delete(
      'visit_answers',
      where: 'visit_id = ? AND question_key = ?',
      whereArgs: [visitId, questionKey],
    );
    await rescore(visitId);
  }

  Future<List<AssessmentAnswerInput>> answersFor(String visitId) async {
    final db = await _db;
    final rows = await db.query(
      'visit_answers',
      where: 'visit_id = ?',
      whereArgs: [visitId],
    );
    return rows
        .map((row) => AssessmentAnswerInput(
              questionKey: row['question_key'] as String,
              choice: row['choice'] as String,
              note: row['note'] as String?,
            ))
        .toList();
  }

  /// The agent's current answers keyed by question, for rendering selection.
  Future<Map<String, String>> choicesFor(String visitId) async {
    final answers = await answersFor(visitId);
    return {for (final answer in answers) answer.questionKey: answer.choice};
  }

  /// Recomputes and stores the local score.
  ///
  /// **Provisional.** The server re-scores on submit and its figure is the one
  /// stored centrally; this exists so the agent sees a band while still with
  /// the group, which is when it is useful.
  Future<AssessmentScore?> rescore(String visitId) async {
    final db = await _db;
    final rows = await db.query(
      'visit_assessments',
      where: 'visit_id = ?',
      whereArgs: [visitId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final cached = await snapshotById(rows.first['snapshot_id'] as String);
    if (cached == null) return null;

    final score = scoreAssessment(cached.snapshot, await answersFor(visitId));

    await db.update(
      'visit_assessments',
      {
        'earned_points': score.earnedPoints,
        'applicable_points': score.applicablePoints,
        'max_points': score.maxPoints,
        'percentage': score.percentage,
        'band_key': score.bandKey,
        'band_label': score.bandLabel,
        'is_complete': score.complete ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'visit_id = ?',
      whereArgs: [visitId],
    );

    return score;
  }

  /// What the visit's assessment needs in order to be pushed.
  Future<PendingAssessment?> pending(String visitId) async {
    final db = await _db;
    final rows = await db.query(
      'visit_assessments',
      where: 'visit_id = ?',
      whereArgs: [visitId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    return PendingAssessment(
      visitId: visitId,
      snapshotId: rows.first['snapshot_id'] as String,
      checksum: rows.first['checksum'] as String,
      answers: await answersFor(visitId),
    );
  }

  /// Visits already on the server whose assessment has not landed yet.
  ///
  /// The two are pushed separately on purpose: a visit that reaches the server
  /// must not be held back because its assessment failed, and an assessment
  /// cannot be sent before the visit it belongs to exists. So the visit goes
  /// first, and anything left behind is swept up here on the next sync.
  Future<List<String>> visitsAwaitingAssessmentPush() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT a.visit_id AS visit_id
      FROM visit_assessments a
      JOIN group_visits v ON v.id = a.visit_id
      WHERE a.is_provisional = 1
        AND v.remote_id IS NOT NULL
        AND EXISTS (SELECT 1 FROM visit_answers w WHERE w.visit_id = a.visit_id)
    ''');
    return rows.map((row) => row['visit_id'] as String).toList();
  }

  /// Marks the server's score as the one that counts.
  Future<void> markSynced({
    required String visitId,
    required double earnedPoints,
    required double percentage,
    String? bandKey,
    String? bandLabel,
  }) async {
    final db = await _db;
    await db.update(
      'visit_assessments',
      {
        'earned_points': earnedPoints,
        'percentage': percentage,
        'band_key': bandKey,
        'band_label': bandLabel,
        // No longer provisional: this is what the server stored.
        'is_provisional': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'visit_id = ?',
      whereArgs: [visitId],
    );
  }
}

/// A snapshot as held on the device.
class CachedSnapshot {
  const CachedSnapshot({
    required this.id,
    required this.templateId,
    required this.version,
    required this.checksum,
    required this.maxPoints,
    required this.snapshot,
  });

  final String id;
  final String templateId;
  final int version;
  final String checksum;
  final double maxPoints;
  final AssessmentTemplateSnapshot snapshot;

  factory CachedSnapshot.fromRow(Map<String, Object?> row) {
    return CachedSnapshot(
      id: row['id'] as String,
      templateId: row['template_id'] as String,
      version: (row['version'] as num).toInt(),
      checksum: row['checksum'] as String,
      maxPoints: (row['max_points'] as num).toDouble(),
      snapshot: AssessmentTemplateSnapshot.fromJson(
        jsonDecode(row['snapshot_json'] as String) as Map<String, dynamic>,
      ),
    );
  }
}

class PendingAssessment {
  const PendingAssessment({
    required this.visitId,
    required this.snapshotId,
    required this.checksum,
    required this.answers,
  });

  final String visitId;
  final String snapshotId;
  final String checksum;
  final List<AssessmentAnswerInput> answers;

  bool get isEmpty => answers.isEmpty;
}
