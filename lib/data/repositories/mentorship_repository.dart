import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/action_item_state.dart';

class LocalMentorshipSession {
  const LocalMentorshipSession({
    required this.topicKey,
    required this.topicTitle,
    this.notes,
    this.durationMinutes,
  });

  final String topicKey;
  final String topicTitle;
  final String? notes;
  final int? durationMinutes;

  Map<String, dynamic> toJson() => {
        'topicKey': topicKey,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
      };
}

class LocalRating {
  const LocalRating({
    required this.dimensionKey,
    required this.score,
    this.ratedByRole = 'GROUP_REPRESENTATIVE',
    this.comment,
  });

  final String dimensionKey;
  final int score;
  final String ratedByRole;
  final String? comment;

  Map<String, dynamic> toJson() => {
        'dimensionKey': dimensionKey,
        'score': score,
        'ratedByRole': ratedByRole,
        if (comment != null && comment!.isNotEmpty) 'comment': comment,
      };
}

class LocalActionItem {
  const LocalActionItem({
    required this.id,
    required this.remoteGroupId,
    required this.title,
    required this.status,
    required this.isDirty,
    this.visitId,
    this.detail,
    this.owner,
    this.dueDate,
    this.closingNote,
    this.closedAtVisitId,
    this.remoteId,
  });

  final String id;
  final String? visitId;
  final String remoteGroupId;
  final String title;
  final String? detail;
  final String? owner;
  final DateTime? dueDate;
  final String status;
  final String? closingNote;

  /// The visit it was signed off at, so the loop is traceable both ways: where
  /// the work was agreed, and where it was closed.
  final String? closedAtVisitId;
  final String? remoteId;

  /// Raised or changed on this phone and not yet pushed.
  final bool isDirty;

  /// Lateness, worked out from the date rather than read from a column.
  ActionItemStatus get state =>
      actionItemStatusOf(status: status, dueDate: dueDate);

  factory LocalActionItem.fromRow(Map<String, Object?> row) {
    final due = row['due_date'] as String?;
    return LocalActionItem(
      id: row['id'] as String,
      visitId: row['visit_id'] as String?,
      remoteGroupId: row['remote_group_id'] as String,
      title: row['title'] as String,
      detail: row['detail'] as String?,
      owner: row['owner'] as String?,
      dueDate: due == null ? null : DateTime.tryParse(due),
      status: row['status'] as String? ?? 'OPEN',
      closingNote: row['closing_note'] as String?,
      closedAtVisitId: row['closed_at_visit_id'] as String?,
      remoteId: row['remote_id'] as String?,
      isDirty: (row['is_dirty'] as num?)?.toInt() == 1,
    );
  }
}

/// Coaching recorded at a visit, and the work the group agreed to.
///
/// The action items are the half that matters offline. An agent arriving for a
/// visit needs last time's commitments on screen BEFORE they start, and that
/// moment is usually in a field with no signal — so items pulled from the
/// server are cached here alongside ones raised on the phone.
class MentorshipRepository {
  MentorshipRepository({AppDatabase? database, Uuid? uuid})
      : _database = database ?? AppDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  Future<Database> get _db async => _database.database;

  // -------------------------------------------------------------------------
  // Mentorship, which belongs to its visit
  // -------------------------------------------------------------------------

  Future<void> recordSession({
    required String visitId,
    required String topicKey,
    required String topicTitle,
    String? notes,
    int? durationMinutes,
  }) async {
    final db = await _db;
    await db.insert(
      'visit_mentorship',
      {
        'id': _uuid.v4(),
        'visit_id': visitId,
        'topic_key': topicKey,
        'topic_title': topicTitle,
        'notes': notes,
        'duration_minutes': durationMinutes,
        'created_at': DateTime.now().toIso8601String(),
      },
      // UNIQUE(visit_id, topic_key): coaching the same topic twice in one visit
      // is one session with better notes, not two.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeSession({required String visitId, required String topicKey}) async {
    final db = await _db;
    await db.delete(
      'visit_mentorship',
      where: 'visit_id = ? AND topic_key = ?',
      whereArgs: [visitId, topicKey],
    );
  }

  Future<List<LocalMentorshipSession>> sessionsFor(String visitId) async {
    final db = await _db;
    final rows = await db.query(
      'visit_mentorship',
      where: 'visit_id = ?',
      whereArgs: [visitId],
      orderBy: 'created_at ASC',
    );
    return rows
        .map((row) => LocalMentorshipSession(
              topicKey: row['topic_key'] as String,
              topicTitle: row['topic_title'] as String,
              notes: row['notes'] as String?,
              durationMinutes: (row['duration_minutes'] as num?)?.toInt(),
            ))
        .toList();
  }

  /// Records the group's score on one dimension.
  ///
  /// Refuses anything outside 1-5 rather than clamping: a clamped 9 becomes a
  /// 5 the group never gave, and that is worse than losing the tap.
  Future<bool> recordRating({
    required String visitId,
    required String dimensionKey,
    required int score,
    String ratedByRole = 'GROUP_REPRESENTATIVE',
    String? comment,
  }) async {
    if (!isValidMentorshipRating(score)) return false;

    final db = await _db;
    await db.insert(
      'visit_ratings',
      {
        'id': _uuid.v4(),
        'visit_id': visitId,
        'dimension_key': dimensionKey,
        'score': score,
        'rated_by_role': ratedByRole,
        'comment': comment,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }

  Future<List<LocalRating>> ratingsFor(String visitId) async {
    final db = await _db;
    final rows = await db.query(
      'visit_ratings',
      where: 'visit_id = ?',
      whereArgs: [visitId],
    );
    return rows
        .map((row) => LocalRating(
              dimensionKey: row['dimension_key'] as String,
              score: (row['score'] as num).toInt(),
              ratedByRole: row['rated_by_role'] as String? ?? 'GROUP_REPRESENTATIVE',
              comment: row['comment'] as String?,
            ))
        .toList();
  }

  /// True when there is anything worth pushing for this visit.
  Future<bool> hasMentorship(String visitId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT
        (SELECT COUNT(*) FROM visit_mentorship WHERE visit_id = ?) +
        (SELECT COUNT(*) FROM visit_ratings WHERE visit_id = ?) AS c
      ''',
      [visitId, visitId],
    );
    return ((rows.first['c'] as num?)?.toInt() ?? 0) > 0;
  }

  // -------------------------------------------------------------------------
  // Action items, which outlive the visit
  // -------------------------------------------------------------------------

  /// Raises work agreed at this visit. Dirty until pushed.
  Future<LocalActionItem> raise({
    required String visitId,
    required String remoteGroupId,
    required String title,
    String? detail,
    String? owner,
    DateTime? dueDate,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    final row = {
      'id': _uuid.v4(),
      'visit_id': visitId,
      'remote_group_id': remoteGroupId,
      'title': title,
      'detail': detail,
      'owner': owner,
      'due_date': dueDate?.toIso8601String(),
      'status': 'OPEN',
      'is_dirty': 1,
      'created_at': now,
      'updated_at': now,
    };
    await db.insert('visit_action_items', row);
    return LocalActionItem.fromRow(row);
  }

  /// Caches what the server holds, so it is on screen at the next visit.
  ///
  /// Deliberately does NOT overwrite a locally dirty row: an agent who just
  /// marked something done in a field, and has not synced yet, must not have
  /// that undone by a server snapshot taken before they did it.
  Future<int> cacheFromServer({
    required String remoteGroupId,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await _db;
    var written = 0;

    for (final item in items) {
      final remoteId = item['id'] as String?;
      if (remoteId == null) continue;

      final existing = await db.query(
        'visit_action_items',
        where: 'remote_id = ?',
        whereArgs: [remoteId],
        limit: 1,
      );
      if (existing.isNotEmpty && (existing.first['is_dirty'] as num?)?.toInt() == 1) {
        continue;
      }

      final due = item['dueDate'] ?? (item['state'] as Map?)?['dueDate'];
      final now = DateTime.now().toIso8601String();
      final row = {
        'id': existing.isNotEmpty ? existing.first['id'] as String : _uuid.v4(),
        'visit_id': item['visitId'] as String?,
        'remote_group_id': remoteGroupId,
        'title': '${item['title']}',
        'detail': item['detail'] as String?,
        'owner': item['owner'] as String?,
        'due_date': due is String ? due : null,
        'status': '${item['status'] ?? 'OPEN'}',
        'closing_note': item['closingNote'] as String?,
        'remote_id': remoteId,
        'is_dirty': 0,
        'created_at': now,
        'updated_at': now,
      };
      await db.insert('visit_action_items', row,
          conflictAlgorithm: ConflictAlgorithm.replace);
      written += 1;
    }
    return written;
  }

  /// What the group still owes, worst first.
  ///
  /// This is what the phone shows at the START of a visit. Surfacing it before
  /// the agent begins is the difference between a follow-up and repeating last
  /// month's conversation.
  /// What the group still owes.
  ///
  /// [excludingVisitIds] leaves out work raised at a particular visit, which is
  /// what the "before you start" card needs: an item agreed ten minutes ago in
  /// the visit being recorded is not something the group owed when that visit
  /// began. Without it the same row appeared twice on one screen, once under
  /// "From the last visit" — with its own Done button beside each copy.
  ///
  /// Ids plural because a row identifies its visit by the LOCAL id while it is
  /// only on the phone, and by the server's id once a refresh has replaced it.
  /// Excluding one and not the other makes the duplicate reappear the moment
  /// the visit syncs.
  Future<List<LocalActionItem>> openItemsFor(
    String remoteGroupId, {
    Iterable<String> excludingVisitIds = const [],
  }) async {
    final db = await _db;
    final excluded = excludingVisitIds.where((id) => id.isNotEmpty).toList();
    final placeholders = List.filled(excluded.length, '?').join(', ');

    final rows = await db.query(
      'visit_action_items',
      where: [
        'remote_group_id = ?',
        'status NOT IN (?, ?)',
        // NULL never matches NOT IN, so an item with no visit at all -- one
        // raised by the office -- has to be admitted explicitly.
        if (excluded.isNotEmpty)
          '(visit_id IS NULL OR visit_id NOT IN ($placeholders))',
      ].join(' AND '),
      whereArgs: [remoteGroupId, 'DONE', 'CANCELLED', ...excluded],
    );
    final items = rows.map(LocalActionItem.fromRow).toList()
      ..sort((a, b) => byUrgency(a.state, b.state));
    return items;
  }

  Future<List<LocalActionItem>> itemsForVisit(String visitId) async {
    final db = await _db;
    final rows = await db.query(
      'visit_action_items',
      where: 'visit_id = ?',
      whereArgs: [visitId],
      orderBy: 'created_at ASC',
    );
    return rows.map(LocalActionItem.fromRow).toList();
  }

  /// Closes or reopens an item. Marked dirty so the change reaches the server.
  Future<void> setStatus({
    required String id,
    required String status,
    String? closingNote,
    String? closedAtVisitId,
  }) async {
    final db = await _db;
    await db.update(
      'visit_action_items',
      {
        'status': status,
        if (closingNote != null) 'closing_note': closingNote,
        if (closedAtVisitId != null) 'closed_at_visit_id': closedAtVisitId,
        'is_dirty': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Locally changed items waiting to reach the server.
  Future<List<LocalActionItem>> dirty() async {
    final db = await _db;
    final rows = await db.query('visit_action_items', where: 'is_dirty = 1');
    return rows.map(LocalActionItem.fromRow).toList();
  }

  Future<void> markSynced({required String id, required String remoteId}) async {
    final db = await _db;
    await db.update(
      'visit_action_items',
      {'remote_id': remoteId, 'is_dirty': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> pendingCount() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) c FROM visit_action_items WHERE is_dirty = 1',
    );
    return (rows.first['c'] as num).toInt();
  }
}
