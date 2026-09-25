import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/domain_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/group.dart';
import '../../data/repositories/meeting_schedule_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/meeting_schedule_provider.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/status_chip.dart';
import 'attendance_screen.dart';
import 'meeting_hub_screen.dart';
import 'three_key_unlock_screen.dart';

/// Auto-numbered meeting history plus the entry point for starting one.
///
/// Also shows the meetings that are planned. A plan is only for reminders: a
/// meeting starts when an official taps Start Meeting, never by itself.
class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final group = context.read<AppState>().group;
    if (group == null) return;
    final meetings = context.read<MeetingProvider>();
    final schedule = context.read<MeetingScheduleProvider>();
    await meetings.load(group.id);
    final last =
        meetings.meetings.isEmpty ? null : meetings.meetings.first.meeting.date;
    await schedule.load(group, lastMeetingAt: last);
  }

  Future<void> _startMeeting() async {
    final appState = context.read<AppState>();
    final provider = context.read<MeetingProvider>();
    final schedule = context.read<MeetingScheduleProvider>();
    final group = appState.group!;

    // The 3-key gate: when on (Meeting Security settings), the meeting only
    // starts after officials/members turn their PIN keys.
    List<String>? unlockedBy;
    if (group.requireThreeKey) {
      unlockedBy = await Navigator.of(context).push<List<String>>(
        MaterialPageRoute(
          builder: (_) => ThreeKeyUnlockScreen(groupId: group.id),
        ),
      );
      if (unlockedBy == null || !mounted) return; // backed out — no meeting
    }

    try {
      final meeting =
          await provider.startMeeting(group, unlockedBy: unlockedBy);
      // Today's plan, if there was one, is this meeting now - so the server's
      // scheduled meeting is the one that goes "in progress", not a second one.
      await schedule.onMeetingStarted(group, meeting.id);
      await appState.refreshPendingSync();
      // Tell the server the meeting started while there is signal.
      unawaited(appState.syncNow());
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AttendanceScreen(meeting: meeting),
        ),
      );
      await _load();
    } on DomainException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    }
  }

  /// An official plans a meeting. Only a plan: members are reminded, and it
  /// still starts only when someone taps Start Meeting on the day.
  Future<void> _scheduleMeeting(Group group) async {
    final l10n = L10n.of(context);
    final schedule = context.read<MeetingScheduleProvider>();
    final appState = context.read<AppState>();
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final parts = group.meetingTime.split(':');
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 14,
        minute: int.tryParse(parts.last) ?? 0,
      ),
    );
    if (time == null || !mounted) return;
    final at =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!at.isAfter(DateTime.now())) return;
    await schedule.schedule(group, at);
    if (!mounted) return;
    showAppSnack(context, l10n.meetingsScheduledNotice);
    unawaited(appState.syncNow());
  }

  Future<void> _cancelPlan(ScheduledMeeting plan) async {
    final l10n = L10n.of(context);
    final schedule = context.read<MeetingScheduleProvider>();
    final appState = context.read<AppState>();
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.meetingsCancelReasonTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.meetingsCancelReasonHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.length >= 3) Navigator.of(dialogContext).pop(text);
            },
            child: Text(l10n.meetingsCancelMeeting),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;
    await schedule.cancel(plan, reason);
    if (!mounted) return;
    showAppSnack(context, l10n.meetingsCancelledNotice);
    unawaited(appState.syncNow());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final appState = context.watch<AppState>();
    final provider = context.watch<MeetingProvider>();
    final schedule = context.watch<MeetingScheduleProvider>();
    final hasOpenMeeting = provider.activeMeeting?.isOpen ?? false;
    final now = DateTime.now();
    final overdue = schedule.overdue(now);
    final group = appState.group;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navMeetings),
        actions: [
          if (appState.pendingSync > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: StatusChip.pendingSync(appState.pendingSync)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            FilledButton.icon(
              onPressed: hasOpenMeeting ? null : _startMeeting,
              icon: Icon(
                  appState.group?.requireThreeKey ?? false
                      ? Icons.key_outlined
                      : Icons.add,
                  size: 18),
              label: Text(hasOpenMeeting
                  ? 'A meeting is in progress'
                  : 'Start Meeting'),
            ),
            if ((appState.group?.requireThreeKey ?? false) && !hasOpenMeeting)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.meetings3KeyUnlockIsOnOfficials,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            for (final plan in overdue)
              _DidntHappenCard(
                plan: plan,
                // Starting late is for the same day only; an older miss is
                // cancelled, not revived.
                canStart: plan.isToday(now) && !hasOpenMeeting,
                onStart: _startMeeting,
                onCancel: () => _cancelPlan(plan),
              ),
            _UpcomingCard(
              upcoming: schedule.upcoming(now),
              nextFromRule: schedule.nextFromRule,
              onSchedule: group == null ? null : () => _scheduleMeeting(group),
              onCancel: _cancelPlan,
            ),
            const SizedBox(height: 16),
            if (provider.meetings.isEmpty && !provider.loading)
              EmptyState(
                icon: Icons.event_note_outlined,
                title: l10n.meetingsNoMeetingsYet,
                message:
                    l10n.meetingsStartYourFirstMeetingToRecord,
              ),
            for (final item in provider.meetings)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  title: Text(
                    'Meeting #${item.meeting.number}',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${Formatters.fullDate(item.meeting.date)} · '
                    '${item.meeting.isOpen ? 'Opening ${Formatters.moneyCompact(item.meeting.openingBalance)}' : 'Collected ${Formatters.moneyCompact(item.collected)}'}',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: StatusChip.meeting(item.meeting.status),
                  onTap: () async {
                    final meetingProvider = context.read<MeetingProvider>();
                    await meetingProvider.openSession(item.meeting);
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            MeetingHubScreen(meeting: item.meeting),
                      ),
                    );
                    await _load();
                  },
                ),
              ),
            if (provider.meetings.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l10n.meetingsClosedMeetingsAreLockedTheirRecords,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A planned meeting whose time passed with nobody starting it. The app never
/// starts or cancels it by itself: an official starts it (only on the day) or
/// cancels it so members stop being reminded.
class _DidntHappenCard extends StatelessWidget {
  const _DidntHappenCard({
    required this.plan,
    required this.canStart,
    required this.onStart,
    required this.onCancel,
  });

  final ScheduledMeeting plan;
  final bool canStart;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_busy_outlined,
                    size: 18, color: AppColors.defaulted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(l10n.meetingsDidntHappenTitle,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Text(l10n.meetingsNotStarted,
                    style:
                        TextStyle(fontSize: 11.5, color: AppColors.defaulted)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${plan.title} · ${Formatters.fullDate(plan.scheduledAt)} '
              '${TimeOfDay.fromDateTime(plan.scheduledAt).format(context)}',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 4),
            Text(l10n.meetingsDidntHappenBody,
                style: Theme.of(context).textTheme.bodySmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (canStart)
                  TextButton(
                      onPressed: onStart, child: Text(l10n.meetingsStartNow)),
                TextButton(
                    onPressed: onCancel,
                    child: Text(l10n.meetingsCancelMeeting)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What is coming up: meetings officials planned, and the next meeting day
/// from the group's schedule. Plans only - each gets reminders, none starts.
class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.upcoming,
    required this.nextFromRule,
    required this.onSchedule,
    required this.onCancel,
  });

  final List<ScheduledMeeting> upcoming;
  final DateTime? nextFromRule;
  final VoidCallback? onSchedule;
  final void Function(ScheduledMeeting plan) onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    String when(DateTime at) =>
        '${Formatters.fullDate(at)} ${TimeOfDay.fromDateTime(at).format(context)}';
    final next = nextFromRule;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l10n.meetingsUpcomingTitle,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                TextButton.icon(
                  onPressed: onSchedule,
                  icon: const Icon(Icons.event_available_outlined, size: 18),
                  label: Text(l10n.meetingsScheduleAction),
                ),
              ],
            ),
            for (final plan in upcoming.take(5))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined, size: 20),
                title: Text(plan.title, style: const TextStyle(fontSize: 13)),
                subtitle: Text(when(plan.scheduledAt),
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                trailing: IconButton(
                  tooltip: l10n.meetingsCancelMeeting,
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => onCancel(plan),
                ),
              ),
            if (next != null)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.repeat, size: 20),
                title: Text(when(next), style: const TextStyle(fontSize: 13)),
                subtitle: Text(l10n.meetingsFromGroupSchedule,
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: Text(l10n.meetingsRemindersNote,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    );
  }
}
