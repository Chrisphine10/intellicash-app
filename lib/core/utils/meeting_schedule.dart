import '../../data/models/enums.dart';

/// A group's meeting schedule, and when people are reminded of a meeting.
///
/// The schedule exists for one purpose: reminding people. It never opens a
/// meeting - a meeting starts only when an official taps Start. Nothing here
/// changes a meeting's status.
///
/// Pure: the clock is passed in. The server implements the same rules
/// (apps/api/src/domain/meeting-schedule.ts); keep the two in step. Times are
/// the phone's local time, which for these groups is Nairobi time.

/// The server's name for a frequency.
String serverFrequency(MeetingFrequency frequency) => switch (frequency) {
      MeetingFrequency.weekly => 'WEEKLY',
      MeetingFrequency.biweekly => 'BIWEEKLY',
      MeetingFrequency.monthly => 'MONTHLY',
    };

/// "HH:mm" as (hour, minute); 14:00 when the text is not a time.
({int hour, int minute}) parseMeetingTime(String text) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
  if (match == null) return (hour: 14, minute: 0);
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return (hour: 14, minute: 0);
  return (hour: hour, minute: minute);
}

String formatMeetingTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

DateTime _day(DateTime at) => DateTime(at.year, at.month, at.day);

/// Monday of the week containing [day].
DateTime _weekStart(DateTime day) =>
    _day(day).subtract(Duration(days: day.weekday - 1));

/// The next meeting time the schedule gives, strictly after [now].
///
/// - weekly: every chosen weekday.
/// - biweekly: every other week, counted from the week of the last meeting
///   (any week, when the group has never met).
/// - monthly: the chosen weekdays in the first seven days of each month.
///
/// A day the group already met on ([lastMeetingAt]) is never offered again.
DateTime? nextMeetingSlot({
  required MeetingFrequency frequency,
  required List<int> days,
  required String time,
  required DateTime now,
  DateTime? lastMeetingAt,
}) {
  if (days.isEmpty) return null;
  final t = parseMeetingTime(time);
  final today = _day(now);
  final lastDay = lastMeetingAt == null ? null : _day(lastMeetingAt);

  for (var offset = 0; offset <= 62; offset++) {
    final day = DateTime(today.year, today.month, today.day + offset);
    if (!days.contains(day.weekday)) continue;
    if (lastDay != null && day == lastDay) continue;

    if (frequency == MeetingFrequency.biweekly && lastDay != null) {
      final weeks =
          (_weekStart(day).difference(_weekStart(lastDay)).inHours / (24 * 7))
              .round();
      if (weeks.isOdd) continue;
    }
    if (frequency == MeetingFrequency.monthly && day.day > 7) continue;

    final slot = DateTime(day.year, day.month, day.day, t.hour, t.minute);
    if (slot.isAfter(now)) return slot;
  }
  return null;
}

/// The two reminders for a meeting at [meetingAt]: the day before and two
/// hours before. Only those still ahead of [now] are returned; none once the
/// meeting time has come.
List<({DateTime at, bool dayBefore})> reminderTimes(
    DateTime meetingAt, DateTime now) {
  return [
    (at: meetingAt.subtract(const Duration(hours: 24)), dayBefore: true),
    (at: meetingAt.subtract(const Duration(hours: 2)), dayBefore: false),
  ].where((r) => r.at.isAfter(now)).toList();
}

/// A server meeting status in plain words.
///
/// A scheduled meeting whose time has passed is "Not started": nothing ever
/// starts it on its own, so an official has to start it late or cancel it.
String meetingStatusLabel(String status, {DateTime? scheduledAt, DateTime? now}) {
  final notStarted = status == 'SCHEDULED' || status == 'KEY_UNLOCK_PENDING';
  if (notStarted &&
      scheduledAt != null &&
      scheduledAt.isBefore(now ?? DateTime.now())) {
    return 'Not started';
  }
  return switch (status) {
    'SCHEDULED' => 'Scheduled',
    'KEY_UNLOCK_PENDING' => 'Waiting for keys',
    'IN_PROGRESS' => 'In progress',
    'SEALED' || 'CLOSED' => 'Closed',
    'SYNC_CONFLICT' => 'Needs review',
    'CANCELLED' => 'Cancelled',
    _ => status.replaceAll('_', ' ').toLowerCase(),
  };
}
