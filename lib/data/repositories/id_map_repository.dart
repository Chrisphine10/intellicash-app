import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';

/// Entity kinds tracked in the local↔remote id map.
abstract final class MapEntity {
  static const group = 'group';
  static const member = 'member';
  static const meeting = 'meeting';
}

/// A conflict the backend reported for a synced record.
class SyncConflict {
  const SyncConflict({
    required this.meetingId,
    required this.kind,
    this.clientRequestId,
    required this.code,
    required this.message,
    required this.createdAt,
  });

  final String meetingId;
  final String kind;
  final String? clientRequestId;
  final String code;
  final String message;
  final DateTime createdAt;

  factory SyncConflict.fromMap(Map<String, Object?> m) => SyncConflict(
        meetingId: m['meeting_id'] as String,
        kind: m['kind'] as String,
        clientRequestId: m['client_request_id'] as String?,
        code: m['code'] as String,
        message: m['message'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// Owns the `id_map` and `sync_conflicts` tables: the binding between local
/// UUIDs and backend CUIDs, and the conflicts surfaced for review.
class IdMapRepository {
  IdMapRepository(this._db);

  final AppDatabase _db;

  Future<void> put(
    String entityType,
    String localId,
    String remoteId, {
    String? groupId,
  }) async {
    final db = await _db.database;
    await db.insert(
      'id_map',
      {
        'entity_type': entityType,
        'local_id': localId,
        'remote_id': remoteId,
        'group_id': groupId,
        'synced_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> remoteId(String entityType, String localId) async {
    final db = await _db.database;
    final rows = await db.query(
      'id_map',
      columns: ['remote_id'],
      where: 'entity_type = ? AND local_id = ?',
      whereArgs: [entityType, localId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['remote_id'] as String;
  }

  /// All local→remote mappings of a kind.
  Future<Map<String, String>> mappings(String entityType) async {
    final db = await _db.database;
    final rows = await db.query(
      'id_map',
      columns: ['local_id', 'remote_id'],
      where: 'entity_type = ?',
      whereArgs: [entityType],
    );
    return {
      for (final r in rows) r['local_id'] as String: r['remote_id'] as String,
    };
  }

  Future<int> countMapped(String entityType) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM id_map WHERE entity_type = ?',
      [entityType],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> removeMeetingMappings() async {
    final db = await _db.database;
    await db.delete('id_map', where: 'entity_type = ?',
        whereArgs: [MapEntity.meeting]);
  }

  Future<void> clearAll() async {
    final db = await _db.database;
    await db.delete('id_map');
    await db.delete('sync_conflicts');
  }

  // --- conflicts ---

  /// Replaces the stored conflicts for a meeting with the latest set.
  Future<void> replaceConflicts(
      String meetingId, List<SyncConflict> conflicts) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('sync_conflicts',
          where: 'meeting_id = ?', whereArgs: [meetingId]);
      for (final c in conflicts) {
        await txn.insert('sync_conflicts', {
          'meeting_id': c.meetingId,
          'kind': c.kind,
          'client_request_id': c.clientRequestId,
          'code': c.code,
          'message': c.message,
          'created_at': c.createdAt.toIso8601String(),
        });
      }
    });
  }

  Future<List<SyncConflict>> conflictsForMeeting(String meetingId) async {
    final db = await _db.database;
    final rows = await db.query('sync_conflicts',
        where: 'meeting_id = ?', whereArgs: [meetingId], orderBy: 'id ASC');
    return rows.map(SyncConflict.fromMap).toList();
  }

  Future<int> totalConflicts() async {
    final db = await _db.database;
    final rows =
        await db.rawQuery('SELECT COUNT(*) AS c FROM sync_conflicts');
    return (rows.first['c'] as int?) ?? 0;
  }
}
