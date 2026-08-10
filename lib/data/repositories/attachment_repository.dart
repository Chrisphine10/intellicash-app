import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';

/// Where a queued photograph has got to.
enum AttachmentStatus { pending, uploaded, bound, failed }

String _statusName(AttachmentStatus status) => switch (status) {
      AttachmentStatus.pending => 'PENDING',
      AttachmentStatus.uploaded => 'UPLOADED',
      AttachmentStatus.bound => 'BOUND',
      AttachmentStatus.failed => 'FAILED',
    };

AttachmentStatus _statusFrom(String? raw) => switch (raw) {
      'UPLOADED' => AttachmentStatus.uploaded,
      'BOUND' => AttachmentStatus.bound,
      'FAILED' => AttachmentStatus.failed,
      _ => AttachmentStatus.pending,
    };

class LocalAttachment {
  const LocalAttachment({
    required this.id,
    required this.visitId,
    required this.sectionKey,
    required this.clientRequestId,
    required this.localPath,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.capturedAt,
    required this.status,
    required this.attempts,
    this.questionKey,
    this.caption,
    this.sha256,
    this.storagePath,
    this.remoteId,
    this.lastError,
  });

  final String id;
  final String visitId;
  final String sectionKey;
  final String? questionKey;
  final String clientRequestId;

  /// The file on this device. The source of truth until [remoteId] is set —
  /// deleting it earlier would lose the evidence if the upload failed.
  final String localPath;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String? caption;
  final DateTime capturedAt;
  final AttachmentStatus status;
  final int attempts;

  /// Set once the bytes are on the server, before the binding step.
  final String? sha256;
  final String? storagePath;

  /// Set once the attachment row exists on the server. Only then is the local
  /// file redundant.
  final String? remoteId;
  final String? lastError;

  bool get isSynced => remoteId != null;

  /// The bytes are up but the binding step has not completed. Resuming from
  /// here skips the expensive part.
  bool get needsBindingOnly => storagePath != null && sha256 != null && remoteId == null;

  factory LocalAttachment.fromRow(Map<String, Object?> row) {
    return LocalAttachment(
      id: row['id'] as String,
      visitId: row['visit_id'] as String,
      sectionKey: row['section_key'] as String,
      questionKey: row['question_key'] as String?,
      clientRequestId: row['client_request_id'] as String,
      localPath: row['local_path'] as String,
      fileName: row['file_name'] as String,
      mimeType: row['mime_type'] as String,
      sizeBytes: (row['size_bytes'] as num).toInt(),
      caption: row['caption'] as String?,
      capturedAt: DateTime.parse(row['captured_at'] as String),
      status: _statusFrom(row['status'] as String?),
      attempts: (row['attempts'] as num?)?.toInt() ?? 0,
      sha256: row['sha256'] as String?,
      storagePath: row['storage_path'] as String?,
      remoteId: row['remote_id'] as String?,
      lastError: row['last_error'] as String?,
    );
  }
}

/// The queue of photographs waiting to reach the server.
///
/// A photo failure must never fail its visit. The visit syncs on its own path;
/// these are pushed one at a time afterwards, and anything that does not make
/// it stays on the device to be retried.
class AttachmentRepository {
  AttachmentRepository({AppDatabase? database, Uuid? uuid})
      : _database = database ?? AppDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  /// The server refuses beyond this, so there is no point queueing more.
  static const int maxPerVisit = 20;

  Future<Database> get _db async => _database.database;

  /// Records a captured photo against the question it is evidence for.
  ///
  /// Returns null when the visit already holds the maximum — the caller shows
  /// that as a message rather than silently dropping the picture.
  Future<LocalAttachment?> enqueue({
    required String visitId,
    required String sectionKey,
    required String localPath,
    required String fileName,
    required String mimeType,
    required int sizeBytes,
    String? questionKey,
    String? caption,
    DateTime? capturedAt,
  }) async {
    final db = await _db;
    if (await countFor(visitId) >= maxPerVisit) return null;

    final id = _uuid.v4();
    final row = {
      'id': id,
      'visit_id': visitId,
      'section_key': sectionKey,
      'question_key': questionKey,
      // Minted once, here, and never regenerated — not on retry, not on
      // resume. It is what makes the binding step idempotent.
      'client_request_id': 'att-$id',
      'local_path': localPath,
      'file_name': fileName,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'caption': caption,
      'captured_at': (capturedAt ?? DateTime.now()).toIso8601String(),
      'status': _statusName(AttachmentStatus.pending),
      'attempts': 0,
      'created_at': DateTime.now().toIso8601String(),
    };
    await db.insert('visit_attachments', row);
    return LocalAttachment.fromRow(row);
  }

  Future<int> countFor(String visitId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) c FROM visit_attachments WHERE visit_id = ?',
      [visitId],
    );
    return (rows.first['c'] as num).toInt();
  }

  Future<List<LocalAttachment>> forVisit(String visitId) async {
    final db = await _db;
    final rows = await db.query(
      'visit_attachments',
      where: 'visit_id = ?',
      whereArgs: [visitId],
      orderBy: 'created_at ASC',
    );
    return rows.map(LocalAttachment.fromRow).toList();
  }

  Future<List<LocalAttachment>> forQuestion({
    required String visitId,
    required String questionKey,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'visit_attachments',
      where: 'visit_id = ? AND question_key = ?',
      whereArgs: [visitId, questionKey],
      orderBy: 'created_at ASC',
    );
    return rows.map(LocalAttachment.fromRow).toList();
  }

  /// Photos waiting to be pushed, for visits already on the server.
  ///
  /// Joined on the visit's remote id because an attachment cannot be addressed
  /// before the visit it belongs to exists centrally.
  Future<List<LocalAttachment>> due() async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT a.* FROM visit_attachments a
      JOIN group_visits v ON v.id = a.visit_id
      WHERE a.remote_id IS NULL
        AND v.remote_id IS NOT NULL
      ORDER BY a.created_at ASC
    ''');
    return rows.map(LocalAttachment.fromRow).toList();
  }

  Future<int> pendingCount() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) c FROM visit_attachments WHERE remote_id IS NULL',
    );
    return (rows.first['c'] as num).toInt();
  }

  /// The bytes are on the server. Recorded separately from binding so a phone
  /// that dies between the two steps does not re-send the photograph.
  Future<void> markUploaded({
    required String id,
    required String storagePath,
    required String sha256,
  }) async {
    final db = await _db;
    await db.update(
      'visit_attachments',
      {
        'storage_path': storagePath,
        'sha256': sha256,
        'status': _statusName(AttachmentStatus.uploaded),
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Bound on the server. Only now is the local file redundant.
  Future<void> markBound({required String id, required String remoteId}) async {
    final db = await _db;
    await db.update(
      'visit_attachments',
      {
        'remote_id': remoteId,
        'status': _statusName(AttachmentStatus.bound),
        'uploaded_at': DateTime.now().toIso8601String(),
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailure({required String id, required String error}) async {
    final db = await _db;
    await db.rawUpdate(
      'UPDATE visit_attachments SET attempts = attempts + 1, last_error = ?, status = ? WHERE id = ?',
      [error, _statusName(AttachmentStatus.failed), id],
    );
  }

  /// Removes a photo the agent decided against, and its file.
  Future<void> discard(String id) async {
    final db = await _db;
    final rows = await db.query(
      'visit_attachments',
      where: 'id = ? AND remote_id IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return;

    await db.delete('visit_attachments', where: 'id = ?', whereArgs: [id]);
    await _deleteFile(rows.first['local_path'] as String);
  }

  /// Frees the disk once a photograph is safely on the server.
  ///
  /// Deliberately only for rows that have a remote id: a file removed while its
  /// upload is still outstanding is evidence destroyed, and by then the group
  /// has gone home.
  Future<int> pruneUploadedFiles() async {
    final db = await _db;
    final rows = await db.query(
      'visit_attachments',
      where: 'remote_id IS NOT NULL AND local_path IS NOT NULL',
    );

    var removed = 0;
    for (final row in rows) {
      final path = row['local_path'] as String?;
      if (path == null || path.isEmpty) continue;
      if (await _deleteFile(path)) {
        await db.update(
          'visit_attachments',
          {'local_path': ''},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        removed += 1;
      }
    }
    return removed;
  }

  Future<bool> _deleteFile(String path) async {
    if (path.isEmpty) return false;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {
      // A file we cannot delete is a wasted megabyte, not a failure worth
      // surfacing to an agent standing in a field.
    }
    return false;
  }
}
