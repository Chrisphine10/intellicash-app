import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';

/// A field visit as held on this phone.
class LocalVisit {
  const LocalVisit({
    required this.id,
    required this.clientRequestId,
    required this.remoteGroupId,
    required this.visitType,
    required this.status,
    required this.startedAt,
    this.groupName,
    this.completedAt,
    this.pinVerifiedAt,
    this.latitude,
    this.longitude,
    this.accuracyM,
    this.locationCapturedAt,
    this.locationNote,
    this.notes,
    this.remoteId,
    this.syncedAt,
  });

  final String id;

  /// Minted once, when the opening PIN passes, and never regenerated — not on
  /// retry, resume, or reinstall. The server keys on it, so this is what makes
  /// a visit pushed twice get recorded once.
  final String clientRequestId;
  final String remoteGroupId;
  final String? groupName;
  final String visitType;
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? pinVerifiedAt;
  final double? latitude;
  final double? longitude;
  final double? accuracyM;
  final DateTime? locationCapturedAt;
  final String? locationNote;
  final String? notes;
  final String? remoteId;
  final DateTime? syncedAt;

  bool get isSynced => remoteId != null;
  bool get hasLocation => latitude != null && longitude != null;

  static LocalVisit fromRow(Map<String, Object?> row) => LocalVisit(
        id: row['id']! as String,
        clientRequestId: row['client_request_id']! as String,
        remoteGroupId: row['remote_group_id']! as String,
        groupName: row['group_name'] as String?,
        visitType: (row['visit_type'] as String?) ?? 'FOLLOW_UP',
        status: (row['status'] as String?) ?? 'DRAFT',
        startedAt: DateTime.parse(row['started_at']! as String),
        completedAt: _date(row['completed_at']),
        pinVerifiedAt: _date(row['pin_verified_at']),
        latitude: (row['latitude'] as num?)?.toDouble(),
        longitude: (row['longitude'] as num?)?.toDouble(),
        accuracyM: (row['accuracy_m'] as num?)?.toDouble(),
        locationCapturedAt: _date(row['location_captured_at']),
        locationNote: row['location_note'] as String?,
        notes: row['notes'] as String?,
        remoteId: row['remote_id'] as String?,
        syncedAt: _date(row['synced_at']),
      );
}

DateTime? _date(Object? value) => value is String ? DateTime.tryParse(value) : null;

/// Visits stored on the phone.
///
/// Every step of the flow writes here immediately. A visit interrupted by a
/// flat battery halfway through must be resumable, and an agent who has walked
/// away from the group cannot be asked to remember what they had typed.
class VisitRepository {
  VisitRepository({AppDatabase? database, Uuid? uuid})
      : _database = database ?? AppDatabase.instance,
        _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final Uuid _uuid;

  /// Starts a visit once the group's PIN has been accepted.
  ///
  /// The client request id is minted HERE, at the one moment that cannot
  /// repeat, and never touched again.
  Future<LocalVisit> start({
    required String remoteGroupId,
    String? groupName,
    String visitType = 'FOLLOW_UP',
    DateTime? startedAt,
    DateTime? pinVerifiedAt,
  }) async {
    final db = await _database.database;
    final now = DateTime.now();
    final id = _uuid.v4();

    await db.insert('group_visits', {
      'id': id,
      'client_request_id': 'visit-${_uuid.v4()}',
      'remote_group_id': remoteGroupId,
      'group_name': groupName,
      'visit_type': visitType,
      'status': 'DRAFT',
      'started_at': (startedAt ?? now).toIso8601String(),
      'pin_verified_at': (pinVerifiedAt ?? now).toIso8601String(),
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });

    return (await byId(id))!;
  }

  Future<LocalVisit?> byId(String id) async {
    final db = await _database.database;
    final rows = await db.query('group_visits', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : LocalVisit.fromRow(rows.first);
  }

  /// A visit still in progress for this group, if there is one.
  ///
  /// Resuming rather than starting again is what keeps one occasion from
  /// becoming two records — and stops the agent re-entering the PIN.
  Future<LocalVisit?> openDraftFor(String remoteGroupId) async {
    final db = await _database.database;
    final rows = await db.query(
      'group_visits',
      where: 'remote_group_id = ? AND status = ?',
      whereArgs: [remoteGroupId, 'DRAFT'],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : LocalVisit.fromRow(rows.first);
  }

  Future<void> recordLocation({
    required String id,
    required double latitude,
    required double longitude,
    double? accuracyM,
    DateTime? capturedAt,
  }) =>
      _patch(id, {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy_m': accuracyM,
        'location_captured_at': (capturedAt ?? DateTime.now()).toIso8601String(),
      });

  Future<void> saveDetails({
    required String id,
    String? visitType,
    String? notes,
    String? locationNote,
  }) =>
      _patch(id, {
        if (visitType != null) 'visit_type': visitType,
        if (notes != null) 'notes': notes,
        if (locationNote != null) 'location_note': locationNote,
      });

  /// Marks the visit finished on the device. It is not on the server yet —
  /// that is the outbox's job.
  Future<void> markReadyToSend(String id, {DateTime? completedAt}) => _patch(id, {
        'status': 'PENDING',
        'completed_at': (completedAt ?? DateTime.now()).toIso8601String(),
      });

  Future<void> markSynced({required String id, required String remoteId}) => _patch(id, {
        'status': 'SUBMITTED',
        'remote_id': remoteId,
        'synced_at': DateTime.now().toIso8601String(),
      });

  /// Visits that HAVE reached the server.
  ///
  /// Anything hanging off a visit — mentorship, ratings, action items — can
  /// only be addressed once the visit itself has a remote id, because that id
  /// is in the URL.
  Future<List<LocalVisit>> synced() async {
    final db = await _database.database;
    final rows = await db.query(
      'group_visits',
      where: 'remote_id IS NOT NULL',
      orderBy: 'started_at DESC',
    );
    return rows.map(LocalVisit.fromRow).toList();
  }

  /// Visits waiting to reach the server, oldest first.
  Future<List<LocalVisit>> unsynced() async {
    final db = await _database.database;
    final rows = await db.query(
      'group_visits',
      where: 'remote_id IS NULL AND status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'started_at ASC',
    );
    return rows.map(LocalVisit.fromRow).toList();
  }

  Future<List<LocalVisit>> recent({int limit = 50}) async {
    final db = await _database.database;
    final rows = await db.query('group_visits', orderBy: 'started_at DESC', limit: limit);
    return rows.map(LocalVisit.fromRow).toList();
  }

  /// Abandons a draft. Only ever a draft: a visit that has been submitted is a
  /// record of something that happened and is not the phone's to delete.
  Future<void> discardDraft(String id) async {
    final db = await _database.database;
    await db.delete(
      'group_visits',
      where: 'id = ? AND status = ? AND remote_id IS NULL',
      whereArgs: [id, 'DRAFT'],
    );
  }

  Future<void> _patch(String id, Map<String, Object?> values) async {
    if (values.isEmpty) return;
    final db = await _database.database;
    await db.update(
      'group_visits',
      {...values, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }
}
