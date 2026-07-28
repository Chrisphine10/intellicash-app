import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/domain_exception.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_state.dart';
import '../../providers/meeting_provider.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/status_chip.dart';
import 'attendance_screen.dart';
import 'meeting_hub_screen.dart';
import 'three_key_unlock_screen.dart';

/// Auto-numbered meeting history plus the entry point for starting one.
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
    await context.read<MeetingProvider>().load(group.id);
  }

  Future<void> _startMeeting() async {
    final appState = context.read<AppState>();
    final provider = context.read<MeetingProvider>();
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
      await appState.refreshPendingSync();
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final provider = context.watch<MeetingProvider>();
    final hasOpenMeeting = provider.activeMeeting?.isOpen ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meetings'),
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
                  '3-key unlock is on: officials confirm their PINs before '
                  'the meeting opens.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 16),
            if (provider.meetings.isEmpty && !provider.loading)
              const EmptyState(
                icon: Icons.event_note_outlined,
                title: 'No meetings yet',
                message:
                    'Start your first meeting to record attendance, '
                    'savings, fines and loans.',
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
                  'Closed meetings are locked — their records form the '
                  'group\'s permanent audit trail.',
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
