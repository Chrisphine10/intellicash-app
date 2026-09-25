import '../../core/network/api_exception.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/meeting_schedule.dart';
import '../models/enums.dart';
import '../models/group.dart';
import '../models/remote/remote_models.dart';
import '../repositories/id_map_repository.dart';
import '../repositories/meeting_schedule_repository.dart';
import 'remote_write_api.dart';

/// Keeps a linked group's meeting plans in step with the server, so members
/// are texted the same reminders the phone shows.
///
/// Sends the group's meeting days and time, meetings an official planned or
/// cancelled on the phone, and brings back what the console planned or
/// cancelled. Only plans move here - never a meeting in progress.
class MeetingScheduleSync {
  MeetingScheduleSync({
    required MeetingScheduleRepository schedule,
    required IdMapRepository idMap,
    required RemoteWriteApi writeApi,
    required Future<List<RemoteMeeting>> Function(String remoteGroupId)
        remoteMeetings,
    required Future<RemoteGroup> Function(String remoteGroupId) remoteGroup,
    required Future<void> Function(Group group) saveLocalGroup,
  })  : _schedule = schedule,
        _idMap = idMap,
        _writeApi = writeApi,
        _remoteMeetings = remoteMeetings,
        _remoteGroup = remoteGroup,
        _saveLocalGroup = saveLocalGroup;

  final MeetingScheduleRepository _schedule;
  final IdMapRepository _idMap;
  final RemoteWriteApi _writeApi;
  final Future<List<RemoteMeeting>> Function(String remoteGroupId)
      _remoteMeetings;
  final Future<RemoteGroup> Function(String remoteGroupId) _remoteGroup;
  final Future<void> Function(Group group) _saveLocalGroup;

  /// Set when a sync took the server's schedule into the local group, so the
  /// app can reload the group it shows.
  bool localGroupChanged = false;

  static String? remoteSignature(RemoteGroup remote) {
    final frequency = remote.meetingFrequency;
    final days = remote.meetingDays;
    final time = remote.meetingTime;
    if (frequency == null || days == null || time == null) return null;
    return [frequency, days.join(','), time, remote.remindersEnabled ? 'on' : 'off']
        .join('|');
  }

  static MeetingFrequency? _localFrequency(String server) => switch (server) {
        'WEEKLY' => MeetingFrequency.weekly,
        'BIWEEKLY' => MeetingFrequency.biweekly,
        'MONTHLY' => MeetingFrequency.monthly,
        _ => null,
      };

  static String ruleSignature(Group group) => [
        serverFrequency(group.meetingFrequency),
        group.meetingDays.join(','),
        group.meetingTime,
        group.remindersEnabled ? 'on' : 'off',
      ].join('|');

  /// Returns how many plans changed on either side. Never throws for one
  /// refused plan; a lost signal ends the pass (the next sync picks it up).
  Future<int> syncGroup(Group group, String remoteGroupId) async {
    var changed = 0;

    // The meeting days and time, both ways. The last schedule both sides agreed
    // on is remembered: whichever side has changed since then wins, and an
    // edit on the phone wins over one on the console if both changed. A phone
    // that has never agreed with the server (just linked, or loaded onto a new
    // phone) takes the server's schedule when there is one - its own is only a
    // default nobody chose, and pushing it would move every member's reminders.
    final local = ruleSignature(group);
    final agreed =
        await _idMap.remoteId(MapEntity.meetingScheduleRule, group.id);
    final remote = await _remoteGroup(remoteGroupId);
    final server = remoteSignature(remote);
    final localChanged = agreed != null && local != agreed;
    final serverChanged = server != null && server != agreed;

    if (server != null && serverChanged && !localChanged) {
      final frequency = _localFrequency(remote.meetingFrequency!);
      if (frequency != null) {
        final adopted = group.copyWith(
          meetingFrequency: frequency,
          meetingDays: remote.meetingDays,
          meetingTime: remote.meetingTime,
          remindersEnabled: remote.remindersEnabled,
        );
        await _saveLocalGroup(adopted);
        localGroupChanged = true;
        group = adopted;
        await _idMap.put(
            MapEntity.meetingScheduleRule, group.id, ruleSignature(adopted),
            groupId: remoteGroupId);
        changed++;
      }
    } else if (local != agreed || server == null) {
      if (local != server) {
        await _writeApi.putMeetingSchedule(
          groupId: remoteGroupId,
          frequency: serverFrequency(group.meetingFrequency),
          days: group.meetingDays,
          time: group.meetingTime,
          remindersEnabled: group.remindersEnabled,
        );
        changed++;
      }
      await _idMap.put(MapEntity.meetingScheduleRule, group.id, local,
          groupId: remoteGroupId);
    }

    for (final plan in await _schedule.unsent(group.id)) {
      try {
        if (plan.status == ScheduledMeetingStatus.cancelled) {
          if (plan.remoteId != null) {
            await _writeApi.cancelMeeting(
              groupId: remoteGroupId,
              meetingId: plan.remoteId!,
              reason: plan.cancelReason ?? 'Cancelled on the phone',
            );
          }
          await _schedule.markSent(plan.id);
        } else if (plan.remoteId == null) {
          final remoteId = await _writeApi.createMeeting(
            groupId: remoteGroupId,
            title: plan.title,
            scheduledAt: plan.scheduledAt,
          );
          await _schedule.markSent(plan.id, remoteId: remoteId);
        } else {
          await _schedule.markSent(plan.id);
        }
        changed++;
      } on ApiException catch (e) {
        if (e.statusCode == 0) rethrow;
        // The server refused (the meeting already has records, say). Its
        // answer stands; the next pull brings the phone into line with it.
        log.warn('schedule', 'Plan ${plan.id} not accepted: ${e.message}');
        await _schedule.markSent(plan.id);
      }
    }

    final ownMeetings = {
      ...(await _idMap.mappings(MapEntity.meeting)).values,
      ...(await _idMap.mappings(MapEntity.meetingTwin)).values,
    };
    changed += await _schedule.mergeFromServer(
      group.id,
      await _remoteMeetings(remoteGroupId),
      ownMeetings: ownMeetings,
      now: DateTime.now(),
    );
    return changed;
  }
}
