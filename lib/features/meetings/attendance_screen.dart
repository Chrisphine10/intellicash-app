import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/domain_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/meeting.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/member_provider.dart';
import '../../shared/widgets/common.dart';
import 'meeting_hub_screen.dart';

/// 1-tap attendance: tap a member's circle to mark them present.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.meeting});

  final Meeting meeting;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final group = context.read<AppState>().group;
      if (group != null) {
        context.read<MemberProvider>().load(group.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final meetingProvider = context.watch<MeetingProvider>();
    final members = context.watch<MemberProvider>().members;
    final attendance = meetingProvider.attendance;
    final presentCount = meetingProvider.presentCount;
    final total = members.length;
    final readOnly = !(meetingProvider.activeMeeting?.isOpen ?? false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMeetings)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              children: [
                Text(l10n.attendanceAttendance,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  'Meeting #${widget.meeting.number} · '
                  '${Formatters.fullDate(widget.meeting.date)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$presentCount of $total present',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              total == 0
                                  ? '—'
                                  : '${(presentCount / total * 100).round()}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: total == 0 ? 0 : presentCount / total,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final financials in members)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 2),
                      leading: MemberAvatar(financials.member.name),
                      title: Text(
                        financials.member.name,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                      trailing: _AttendanceTick(
                        present: attendance[financials.member.id] ?? false,
                      ),
                      onTap: readOnly
                          ? null
                          : () async {
                              try {
                                await meetingProvider
                                    .toggleAttendance(financials.member.id);
                              } on DomainException catch (e) {
                                if (context.mounted) {
                                  showAppSnack(context, e.message,
                                      error: true);
                                }
                              }
                            },
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) =>
                          MeetingHubScreen(meeting: widget.meeting),
                    ),
                  );
                },
                child: Text(l10n.attendanceContinueToMeeting),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceTick extends StatelessWidget {
  const _AttendanceTick({required this.present});

  final bool present;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: present ? AppColors.primary : Colors.transparent,
        border: present
            ? null
            : Border.all(color: AppColors.outline, width: 1.6),
      ),
      child: present
          ? Icon(Icons.check, size: 16, color: AppColors.onPrimary)
          : null,
    );
  }
}
