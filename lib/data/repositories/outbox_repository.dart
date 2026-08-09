import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';

/// What kind of record an outbox entry points at.
enum OutboxRecordType {
  visit;

  String get wire => switch (this) { OutboxRecordType.visit => 'VISIT' };

  static OutboxRecordType fromWire(String value) => switch (value) {
        'VISIT' => OutboxRecordType.visit,
        _ => throw ArgumentError('Unknown outbox record type: $value'),
      };
}

/// Where an entry is in its life.
enum OutboxStatus {
  /// Waiting to be sent, or waiting for [OutboxEntry.nextAttemptAt].
  pending,

  /// Sent and accepted. Kept briefly so the UI can say "synced" rather than
  /// having the row vanish mid-glance.
  synced,

  /// Gave up after repeated failures, or the server rejected it in a way that
  /// retrying cannot fix. Needs a person.
  failed;

  String get wire => switch (this) {
        OutboxStatus.pending => 'PENDING',
        OutboxStatus.synced => 'SYNCED',
        OutboxStatus.failed => 'FAILED',
      };

  static OutboxStatus fromWire(String value) => switch (value) {
        'PENDING' => OutboxStatus.pending,
        'SYNCED' => OutboxStatus.synced,
        'FAILED' => OutboxStatus.failed,
        _ => OutboxStatus.pending,
      };
}

class OutboxEntry {
  const OutboxEntry({
    required this.id,
    required this.recordType,
    required this.recordId,
    required this.status,
    required this.attempts,
    this.nextAttemptAt,
    this.lastError,
    this.lastErrorCode,
    this.dependsOnId,
  });

  final String id;
  final OutboxRecordType recordType;
  final String recordId;
  final OutboxStatus status;
  final int attempts;
  final DateTime? nextAttemptAt;
  final String? lastError;
  final String? lastErrorCode;
  final String? dependsOnId;

  static OutboxEntry fromRow(Map<String, Object?> row) => OutboxEntry(
        id: row['id']! as String,
        recordType: OutboxRecordType.fromWire(row['record_type']! as String),
        recordId: row['record_id']! as String,
        status: OutboxStatus.fromWire(row['status']! as String),
        attempts: (row['attempts'] as int?) ?? 0,
        nextAttemptAt: _parseDate(row['next_attempt_at']),
        lastError: row['last_error'] as String?,
        lastErrorCode: row['last_error_code'] as String?,
        dependsOnId: row['depends_on_id'] as String?,
      );
}

DateTime? _parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// The durable send queue for things this phone has recorded and the server has
/// not yet accepted.
///
/// It stores a POINTER — record type plus id — rather than a serialized
/// payload. A visit edited after being queued therefore pushes its corrected
/// state, where a stored payload would push what the record looked like at
/// enqueue time and silently discard the correction.
///
/// This is a separate table from the older `sync_queue`, which posts to an
/// endpoint that has never existed on the backend, has no status column, and
/// is never drained. Do not build on that one.
class OutboxRepository {
  OutboxRepository({AppDatabase? database, Uuid? uuid})
      : _database = database ?? AppDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  /// How long to wait before attempt n+1. Caps rather than growing forever: a
  /// phone that comes back into signal after a week should retry promptly, not
  /// sit on an eight-hour backoff.
  static Duration backoffFor(int attempts) {
    const schedule = [
      Duration(seconds: 30),
      Duration(minutes: 2),
      Duration(minutes: 10),
      Duration(minutes: 30),
      Duration(hours: 2),
    ];
    if (attempts <= 0) return Duration.zero;
    return schedule[attempts.clamp(1, schedule.length) - 1];
  }

  /// After this many failures an entry stops retrying and asks for a person.
  static const int maxAttempts = 8;

  /// Queues a record, or returns the existing entry if it is already queued.
  ///
  /// Idempotent by UNIQUE(record_type, record_id): enqueueing twice — which
  /// happens whenever a screen is rebuilt or a resume path re-runs — must not
  /// produce two sends.
  Future<OutboxEntry> enqueue({
    required OutboxRecordType recordType,
    required String recordId,
    String? dependsOnId,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().toIso8601String();

    final existing = await db.query(
      'outbox',
      where: 'record_type = ? AND record_id = ?',
      whereArgs: [recordType.wire, recordId],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      final entry = OutboxEntry.fromRow(existing.first);
      // A failed entry being re-enqueued is a deliberate retry by the user;
      // put it back in the queue rather than leaving it stuck.
      if (entry.status == OutboxStatus.failed) {
        await db.update(
          'outbox',
          {
            'status': OutboxStatus.pending.wire,
            'attempts': 0,
            'next_attempt_at': null,
            'last_error': null,
            'last_error_code': null,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [entry.id],
        );
        return (await byId(entry.id))!;
      }
      return entry;
    }

    final id = _uuid.v4();
    await db.insert(
      'outbox',
      {
        'id': id,
        'record_type': recordType.wire,
        'record_id': recordId,
        'status': OutboxStatus.pending.wire,
        'attempts': 0,
        'depends_on_id': dependsOnId,
        'created_at': now,
        'updated_at': now,
      },
      // Belt and braces against a race between the SELECT above and here.
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    final row = await db.query(
      'outbox',
      where: 'record_type = ? AND record_id = ?',
      whereArgs: [recordType.wire, recordId],
      limit: 1,
    );
    return OutboxEntry.fromRow(row.first);
  }

  Future<OutboxEntry?> byId(String id) async {
    final db = await _database.database;
    final rows = await db.query('outbox', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : OutboxEntry.fromRow(rows.first);
  }

  /// Entries ready to send now, oldest first.
  ///
  /// Excludes anything whose backoff has not elapsed, and anything still
  /// waiting on a dependency — which is what makes it structurally impossible
  /// to push a child before its parent has a remote id.
  Future<List<OutboxEntry>> due({DateTime? now}) async {
    final db = await _database.database;
    final at = (now ?? DateTime.now()).toIso8601String();

    final rows = await db.rawQuery(
      '''
      SELECT o.* FROM outbox o
      LEFT JOIN outbox parent ON parent.id = o.depends_on_id
      WHERE o.status = ?
        AND (o.next_attempt_at IS NULL OR o.next_attempt_at <= ?)
        AND (o.depends_on_id IS NULL OR parent.status = ?)
      ORDER BY o.created_at ASC
      ''',
      [OutboxStatus.pending.wire, at, OutboxStatus.synced.wire],
    );
    return rows.map(OutboxEntry.fromRow).toList();
  }

  /// Number of things still waiting to reach the server — the badge count.
  Future<int> pendingCount() async {
    final db = await _database.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) c FROM outbox WHERE status IN (?, ?)',
      [OutboxStatus.pending.wire, OutboxStatus.failed.wire],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<void> markSynced(String id) async {
    final db = await _database.database;
    await db.update(
      'outbox',
      {
        'status': OutboxStatus.synced.wire,
        'last_error': null,
        'last_error_code': null,
        'next_attempt_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Records a failed attempt and schedules the next one.
  ///
  /// [permanent] is for rejections retrying cannot fix — a validation error, or
  /// a group the agent no longer has access to. Retrying those forever burns
  /// battery and hides the problem from the person who could fix it.
  Future<void> markFailure(
    String id, {
    required String error,
    String? errorCode,
    bool permanent = false,
    DateTime? now,
  }) async {
    final db = await _database.database;
    final entry = await byId(id);
    if (entry == null) return;

    final attempts = entry.attempts + 1;
    final at = now ?? DateTime.now();
    final giveUp = permanent || attempts >= maxAttempts;

    await db.update(
      'outbox',
      {
        'status': giveUp ? OutboxStatus.failed.wire : OutboxStatus.pending.wire,
        'attempts': attempts,
        'next_attempt_at':
            giveUp ? null : at.add(backoffFor(attempts)).toIso8601String(),
        'last_error': error,
        'last_error_code': errorCode,
        'updated_at': at.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clears entries that have been accepted, so the table does not grow without
  /// bound. Keeps recent ones so the UI can still show "synced".
  Future<int> pruneSynced({Duration keepFor = const Duration(days: 7), DateTime? now}) async {
    final db = await _database.database;
    final cutoff = (now ?? DateTime.now()).subtract(keepFor).toIso8601String();
    return db.delete(
      'outbox',
      where: 'status = ? AND updated_at < ?',
      whereArgs: [OutboxStatus.synced.wire, cutoff],
    );
  }
}
