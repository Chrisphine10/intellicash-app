import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';

/// Offline-first sync queue.
///
/// Every local write lands here as an operation. [pendingCount] drives the
/// amber "N pending" chip; [drain] pushes the batch to the backend's
/// `POST /sync/push` endpoint (see docs/API_SPECIFICATION.md) via an
/// injected sender so the repository stays transport-agnostic.
class SyncRepository {
  SyncRepository(this._db);

  final AppDatabase _db;

  /// Enqueue inside an open transaction so the write and its sync record
  /// commit atomically.
  static Future<void> enqueue(
    DatabaseExecutor txn, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?> payload,
  }) {
    return txn.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
    }).then((_) {});
  }

  Future<int> pendingCount() async {
    final db = await _db.database;
    final rows =
        await db.rawQuery('SELECT COUNT(*) AS count FROM sync_queue');
    return (rows.first['count'] as int?) ?? 0;
  }

  /// Sends all queued operations through [send] (oldest first) and removes
  /// the ones it accepts. Returns how many were synced.
  Future<int> drain(
    Future<bool> Function(List<Map<String, Object?>> batch) send,
  ) async {
    final db = await _db.database;
    final rows = await db.query('sync_queue', orderBy: 'id ASC');
    if (rows.isEmpty) return 0;

    final batch = rows
        .map((row) => {
              'entityType': row['entity_type'],
              'entityId': row['entity_id'],
              'operation': row['operation'],
              'payload': jsonDecode(row['payload'] as String),
              'queuedAt': row['created_at'],
            })
        .toList();

    final accepted = await send(batch);
    if (!accepted) return 0;

    final lastId = rows.last['id'] as int;
    await db.delete('sync_queue', where: 'id <= ?', whereArgs: [lastId]);
    return rows.length;
  }
}
