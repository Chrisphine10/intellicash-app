import 'package:flutter/foundation.dart';

import '../core/notifications/meeting_alerts.dart';
import '../core/utils/meeting_schedule.dart';
import '../data/models/group.dart';
import '../data/repositories/meeting_schedule_repository.dart';

/// Upcoming and missed meeting plans for the Meetings tab, and the reminders
/// the phone shows for them.
///
/// Plans only. Nothing here starts, opens or closes a meeting: that is always
/// an official tapping Start (MeetingProvider) or Close.
class MeetingScheduleProvider extends ChangeNotifier {
  MeetingScheduleProvider(this._repository, {MeetingAlerts? alerts})
      : _alerts = alerts;

  final MeetingScheduleRepository _repository;
  final MeetingAlerts? _alerts;

  List<ScheduledMeeting> _pending = [];
  DateTime? _nextFromRule;
  Group? _group;
  DateTime? _lastMeetingAt;

  /// Planned meetings still ahead, soonest first.
  List<ScheduledMeeting> upcoming(DateTime now) =>
      _pending.where((p) => !p.scheduledAt.isBefore(now)).toList();

  /// Planned meetings whose time passed with nobody starting them. An
  /// official decides: start it (if it is today) or cancel it.
  List<ScheduledMeeting> overdue(DateTime now) =>
      _pending.where((p) => p.isOverdue(now)).toList().reversed.toList();

  /// The next meeting day from the group's schedule, when no plan covers it.
  DateTime? get nextFromRule {
    final next = _nextFromRule;
    if (next == null) return null;
    final covered = _pending.any((p) =>
        p.scheduledAt.year == next.year &&
        p.scheduledAt.month == next.month &&
        p.scheduledAt.day == next.day);
    return covered ? null : next;
  }

  Future<void> load(Group group, {DateTime? lastMeetingAt}) async {
    _group = group;
    _lastMeetingAt = lastMeetingAt;
    _pending = await _repository.pending(group.id);
    _nextFromRule = nextMeetingSlot(
      frequency: group.meetingFrequency,
      days: group.meetingDays,
      time: group.meetingTime,
      now: DateTime.now(),
      lastMeetingAt: lastMeetingAt,
    );
    notifyListeners();
    await refreshAlerts();
  }

  Future<void> schedule(Group group, DateTime at, {String? title}) async {
    await _repository.add(
      groupId: group.id,
      scheduledAt: at,
      title: title?.trim().isNotEmpty == true ? title!.trim() : 'Group meeting',
    );
    await load(group, lastMeetingAt: _lastMeetingAt);
  }

  Future<void> cancel(ScheduledMeeting plan, String reason) async {
    await _repository.cancel(plan.id, reason);
    final group = _group;
    if (group != null) await load(group, lastMeetingAt: _lastMeetingAt);
  }

  /// An official started a meeting: today's plan, if any, is now that meeting.
  Future<void> onMeetingStarted(Group group, String meetingId) async {
    await _repository.linkTodaysPlan(
      groupId: group.id,
      meetingId: meetingId,
      now: DateTime.now(),
    );
    await load(group, lastMeetingAt: DateTime.now());
  }

  bool _askedPermission = false;

  Future<void> refreshAlerts() async {
    final alerts = _alerts;
    final group = _group;
    if (alerts == null || group == null) return;
    // Asked once, the first time there is a group whose members want
    // reminders - not at install, when nobody knows what it is for.
    if (group.remindersEnabled && !_askedPermission) {
      _askedPermission = true;
      await alerts.requestPermission();
    }
    await alerts.replaceAll(planMeetingAlerts(
      group: group,
      plans: _pending,
      now: DateTime.now(),
      lastMeetingAt: _lastMeetingAt,
    ));
  }
}
