import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/group.dart';
import '../../data/repositories/meeting_schedule_repository.dart';
import '../utils/app_logger.dart';
import '../utils/meeting_schedule.dart';

/// One alert the phone will show.
class PlannedAlert {
  const PlannedAlert({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });

  final int id;
  final DateTime at;
  final String title;
  final String body;
}

/// Works out the reminders for a group - pure, so it can be tested.
///
/// The meetings are the plans on the phone plus the next meeting day from the
/// group's schedule, one per day (a planned meeting that day wins). Each gets
/// the day-before and two-hours-before alerts that are still ahead.
List<PlannedAlert> planMeetingAlerts({
  required Group group,
  required List<ScheduledMeeting> plans,
  required DateTime now,
  DateTime? lastMeetingAt,
}) {
  if (!group.remindersEnabled) return const [];

  final meetings = <DateTime>[];
  final days = <String>{};
  String key(DateTime at) => '${at.year}-${at.month}-${at.day}';

  for (final plan in plans) {
    if (plan.groupId != group.id ||
        plan.status != ScheduledMeetingStatus.scheduled) {
      continue;
    }
    if (!plan.scheduledAt.isAfter(now)) continue;
    if (days.add(key(plan.scheduledAt))) meetings.add(plan.scheduledAt);
  }
  final next = nextMeetingSlot(
    frequency: group.meetingFrequency,
    days: group.meetingDays,
    time: group.meetingTime,
    now: now,
    lastMeetingAt: lastMeetingAt,
  );
  if (next != null && days.add(key(next))) meetings.add(next);
  meetings.sort();

  final alerts = <PlannedAlert>[];
  // A small, stable id space: rescheduling cancels everything first.
  var id = 7100;
  for (final meeting in meetings.take(10)) {
    final hh = meeting.hour % 12 == 0 ? 12 : meeting.hour % 12;
    final mm = meeting.minute.toString().padLeft(2, '0');
    final time = '$hh:$mm ${meeting.hour < 12 ? 'am' : 'pm'}';
    for (final reminder in reminderTimes(meeting, now)) {
      alerts.add(PlannedAlert(
        id: id++,
        at: reminder.at,
        title: reminder.dayBefore ? 'Meeting tomorrow' : 'Meeting today',
        body: reminder.dayBefore
            ? '${group.name} meets tomorrow at $time. Please attend.'
            : '${group.name} meets today at $time. Please attend.',
      ));
    }
  }
  return alerts;
}

/// Shows meeting reminders from the phone itself, so they arrive without
/// signal. A reminder never starts a meeting: tapping one just opens the app.
class MeetingAlerts {
  MeetingAlerts({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'meeting_reminders',
    'Meeting reminders',
    channelDescription: 'The day before and two hours before a group meeting.',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> _init() async {
    if (_ready || kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (_) {
      // The groups meet in Kenya; that is the right answer when unsure.
      tz.setLocalLocation(tz.getLocation('Africa/Nairobi'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  /// Asks once for permission to show notifications (Android 13+).
  Future<void> requestPermission() async {
    try {
      await _init();
      if (!_ready) return;
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      log.warn('alerts', 'Notification permission not requested: $e');
    }
  }

  /// Replaces every pending meeting alert with [alerts].
  Future<void> replaceAll(List<PlannedAlert> alerts) async {
    try {
      await _init();
      if (!_ready) return;
      await _plugin.cancelAllPendingNotifications();
      for (final alert in alerts) {
        await _plugin.zonedSchedule(
          id: alert.id,
          scheduledDate: tz.TZDateTime.from(alert.at, tz.local),
          notificationDetails: const NotificationDetails(android: _channel),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: alert.title,
          body: alert.body,
          payload: 'meetings',
        );
      }
    } catch (e) {
      // A reminder that cannot be scheduled must never break the app.
      log.warn('alerts', 'Meeting reminders not scheduled: $e');
    }
  }
}
