import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../models/remote/remote_models.dart';

enum ScheduledMeetingStatus { scheduled, started, cancelled }

/// A meeting the group has planned. Only a plan, kept to remind people: a
/// scheduled meeting never becomes a meeting in progress except by an official
/// tapping Start.
class ScheduledMeeting {
  const ScheduledMeeting({
    required this.id,
    required this.groupId,
    required this.scheduledAt,
    required this.title,
    required this.status,
    this.remoteId,
    this.meetingId,
    this.source = 'phone',
    this.cancelReason,
  });

  final String id;
  final String groupId;

  /// Local time.
  final DateTime scheduledAt;
  final String title;
  final ScheduledMeetingStatus status;

  /// The server's meeting for this plan, once known.
  final String? remoteId;

  /// The meeting an official started for this plan.
  final String? meetingId;
  final String source;
  final String? cancelReason;

  bool isOverdue(DateTime now) =>
      status == ScheduledMeetingStatus.scheduled && scheduledAt.isBefore(now);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool isToday(DateTime now) => _sameDay(scheduledAt, now);

  factory ScheduledMeeting.fromMap(Map<String, Object?> map) => ScheduledMeeting(
        id: map['id'] as String,
        groupId: map['group_id'] as String,
        remoteId: map['remote_id'] as String?,
        scheduledAt: DateTime.parse(map['scheduled_at'] as String).toLocal(),
        title: map['title'] as String,
        status: ScheduledMeetingStatus.values.firstWhere(
          (s) => s.name == map['status'],
          orElse: () => ScheduledMeetingStatus.scheduled,
        ),
        meetingId: map['meeting_id'] as String?,
        source: (map['source'] as String?) ?? 'phone',
        cancelReason: map['cancel_reason'] as String?,
      );
}

/// The phone's list of planned meetings. Nothing in here opens a meeting.
class MeetingScheduleRepository {
  MeetingScheduleRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  static String _utc(DateTime at) => at.toUtc().toIso8601String();

  /// Plans still ahead or overdue (not started, not cancelled), soonest first.
  Future<List<ScheduledMeeting>> pending(String groupId) async {
    final db = await _db.database;
    final rows = await db.query(
      'meeting_schedule',
      where: 'group_id = ? AND status = ?',
      whereArgs: [groupId, ScheduledMeetingStatus.scheduled.name],
      orderBy: 'scheduled_at ASC',
    );
    return rows.map(ScheduledMeeting.fromMap).toList();
  }

  /// Every pending plan across all groups on the phone - what the alerts need.
  Future<List<ScheduledMeeting>> allPending() async {
    final db = await _db.database;
    final rows = await db.query(
      'meeting_schedule',
      where: 'status = ?',
      whereArgs: [ScheduledMeetingStatus.scheduled.name],
      orderBy: 'scheduled_at ASC',
    );
    return rows.map(ScheduledMeeting.fromMap).toList();
  }

  /// An official plans a meeting on the phone. Sent to the server when the
  /// group is linked, so members are texted reminders too.
  Future<ScheduledMeeting> add({
    required String groupId,
    required DateTime scheduledAt,
    required String title,
  }) async {
    final db = await _db.database;
    final id = _uuid.v4();
    await db.insert('meeting_schedule', {
      'id': id,
      'group_id': groupId,
      'scheduled_at': _utc(scheduledAt),
      'title': title,
      'status': ScheduledMeetingStatus.scheduled.name,
      'source': 'phone',
      'is_dirty': 1,
      'updated_at': _utc(DateTime.now()),
    });
    return ScheduledMeeting(
      id: id,
      groupId: groupId,
      scheduledAt: scheduledAt,
      title: title,
      status: ScheduledMeetingStatus.scheduled,
    );
  }

  /// An official says a planned meeting did not (or will not) happen.
  Future<void> cancel(String id, String reason) async {
    final db = await _db.database;
    await db.update(
      'meeting_schedule',
      {
        'status': ScheduledMeetingStatus.cancelled.name,
        'cancel_reason': reason,
        'is_dirty': 1,
        'updated_at': _utc(DateTime.now()),
      },
      where: 'id = ? AND status = ?',
      whereArgs: [id, ScheduledMeetingStatus.scheduled.name],
    );
  }

  /// Links today's plan, if there is one, to a meeting an official just
  /// started - so the server's scheduled meeting is the one that becomes "in
  /// progress" rather than a second meeting appearing beside it.
  ///
  /// Only a plan for today: a meeting started on Thursday is not last
  /// Monday's missed one. Returns the plan's server id, when known.
  Future<String?> linkTodaysPlan({
    required String groupId,
    required String meetingId,
    required DateTime now,
  }) async {
    final today = (await pending(groupId)).where((p) => p.isToday(now)).toList();
    if (today.isEmpty) return null;
    final plan = today.first;
    final db = await _db.database;
    await db.update(
      'meeting_schedule',
      {
        'status': ScheduledMeetingStatus.started.name,
        'meeting_id': meetingId,
        'updated_at': _utc(now),
      },
      where: 'id = ?',
      whereArgs: [plan.id],
    );
    return plan.remoteId;
  }

  /// The server meeting planned for a local meeting, if it was started from one.
  Future<String?> remoteIdForMeeting(String meetingId) async {
    final db = await _db.database;
    final rows = await db.query(
      'meeting_schedule',
      columns: ['remote_id'],
      where: 'meeting_id = ? AND remote_id IS NOT NULL',
      whereArgs: [meetingId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['remote_id'] as String?;
  }

  /// Changes made on the phone that the server has not heard about.
  Future<List<ScheduledMeeting>> unsent(String groupId) async {
    final db = await _db.database;
    final rows = await db.query(
      'meeting_schedule',
      where: 'group_id = ? AND is_dirty = 1',
      whereArgs: [groupId],
    );
    return rows.map(ScheduledMeeting.fromMap).toList();
  }

  Future<void> markSent(String id, {String? remoteId}) async {
    final db = await _db.database;
    await db.update(
      'meeting_schedule',
      {'is_dirty': 0, if (remoteId != null) 'remote_id': remoteId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Brings in the server's plans for a group: what the console scheduled,
  /// what the planner put on the calendar, and what was cancelled there.
  ///
  /// Only plans - a server meeting that is under way or closed marks its plan
  /// "started" and is never copied into the phone's meetings. A change made on
  /// the phone and not yet sent wins over the server's copy. [ownMeetings] are
  /// server ids of meetings held on this phone, which are not plans.
  Future<int> mergeFromServer(
    String groupId,
    List<RemoteMeeting> remote, {
    required Set<String> ownMeetings,
    required DateTime now,
  }) async {
    final db = await _db.database;
    final existing = {
      for (final row in await db.query('meeting_schedule',
          where: 'group_id = ? AND remote_id IS NOT NULL', whereArgs: [groupId]))
        row['remote_id'] as String: row,
    };
    var changed = 0;
    await db.transaction((txn) async {
      for (final meeting in remote) {
        final at = meeting.scheduledAt;
        if (at == null || ownMeetings.contains(meeting.id)) continue;
        if (meeting.source == 'PHONE') continue;

        final status = meeting.isCancelled
            ? ScheduledMeetingStatus.cancelled
            : meeting.isNotStarted
                ? ScheduledMeetingStatus.scheduled
                : ScheduledMeetingStatus.started;
        final row = existing[meeting.id];

        if (row == null) {
          // New to the phone: only plans still worth reminding about.
          if (status != ScheduledMeetingStatus.scheduled) continue;
          if (at.isBefore(now.subtract(const Duration(days: 14)))) continue;
          await txn.insert(
            'meeting_schedule',
            {
              'id': _uuid.v4(),
              'group_id': groupId,
              'remote_id': meeting.id,
              'scheduled_at': _utc(at),
              'title': meeting.title,
              'status': status.name,
              'source': meeting.source == 'AUTO_SCHEDULE' ? 'auto' : 'console',
              'cancel_reason': meeting.cancelReason,
              'is_dirty': 0,
              'updated_at': _utc(now),
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          changed++;
          continue;
        }

        if ((row['is_dirty'] as int? ?? 0) == 1) continue;
        final local = row['status'] as String;
        // The phone started this plan itself; the server catching up is not news.
        if (local == ScheduledMeetingStatus.started.name) continue;
        if (local == status.name &&
            row['scheduled_at'] == _utc(at) &&
            row['title'] == meeting.title) {
          continue;
        }
        await txn.update(
          'meeting_schedule',
          {
            'status': status.name,
            'scheduled_at': _utc(at),
            'title': meeting.title,
            'cancel_reason': meeting.cancelReason,
            'updated_at': _utc(now),
          },
          where: 'id = ?',
          whereArgs: [row['id']],
        );
        changed++;
      }

      // A plan the server no longer has was withdrawn there - the planner's
      // plan for a day the group stopped meeting on. Keeping it would alert
      // people for a meeting that is not happening. Only plans that came from
      // the server and have not been touched on this phone go.
      final onServer = {for (final meeting in remote) meeting.id};
      for (final entry in existing.entries) {
        final row = entry.value;
        if (onServer.contains(entry.key)) continue;
        if ((row['is_dirty'] as int? ?? 0) == 1) continue;
        if (row['status'] != ScheduledMeetingStatus.scheduled.name) continue;
        if (row['source'] == 'phone') continue;
        if (DateTime.parse(row['scheduled_at'] as String).isBefore(now)) continue;
        await txn.delete('meeting_schedule',
            where: 'id = ?', whereArgs: [row['id']]);
        changed++;
      }
    });
    return changed;
  }
}
