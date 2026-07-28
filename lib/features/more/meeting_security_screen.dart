import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/meeting_unlock.dart';
import '../../data/models/enums.dart';
import '../../data/models/member.dart';
import '../../providers/app_state.dart';
import '../../providers/member_provider.dart';
import '../../shared/widgets/common.dart';

/// Meeting security settings: switch the 3-key unlock on or off, assign the
/// officials who hold keys, and set or reset each member's meeting PIN.
class MeetingSecurityScreen extends StatefulWidget {
  const MeetingSecurityScreen({super.key});

  @override
  State<MeetingSecurityScreen> createState() => _MeetingSecurityScreenState();
}

class _MeetingSecurityScreenState extends State<MeetingSecurityScreen> {
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
    final appState = context.watch<AppState>();
    final group = appState.group;
    final members = context.watch<MemberProvider>().members;
    if (group == null) return const SizedBox.shrink();

    final officials =
        members.where((m) => m.member.isOfficial).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Meeting Security')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Card(
            child: SwitchListTile(
              value: group.requireThreeKey,
              onChanged: (value) async {
                await appState
                    .updateGroup(group.copyWith(requireThreeKey: value));
                if (!context.mounted) return;
                showAppSnack(
                  context,
                  value
                      ? '3-key unlock is on — meetings need PINs to start.'
                      : '3-key unlock is off — meetings start without PINs.',
                );
              },
              title: const Text('3-key unlock before meetings',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(
                'A meeting only starts after ${MeetingUnlock.officialsRequired} '
                'officials — or most members — enter their secret PIN.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          if (group.requireThreeKey && officials < 3) ...[
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: AppColors.pending),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Assign a chairperson, secretary and treasurer below '
                        'so three officials can unlock meetings. Until then, '
                        'most members\' PINs are needed instead.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SectionLabel('Members, roles & PINs'),
          for (final entry in members)
            _MemberSecurityTile(member: entry.member),
        ],
      ),
    );
  }
}

class _MemberSecurityTile extends StatelessWidget {
  const _MemberSecurityTile({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.name,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    member.hasPin ? 'PIN set' : 'No PIN yet',
                    style: TextStyle(
                      fontSize: 11,
                      color: member.hasPin
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            DropdownButton<MemberRole>(
              value: member.role,
              underline: const SizedBox.shrink(),
              style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
              dropdownColor: AppColors.surfaceRaised,
              items: [
                for (final role in MemberRole.values)
                  DropdownMenuItem(value: role, child: Text(role.label)),
              ],
              onChanged: (role) async {
                if (role == null || role == member.role) return;
                await context
                    .read<MemberProvider>()
                    .updateMember(member.copyWith(role: role));
              },
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: member.hasPin ? 'Reset PIN' : 'PIN is set at unlock',
              icon: Icon(
                member.hasPin ? Icons.lock_reset : Icons.pin_outlined,
                size: 20,
                color: member.hasPin
                    ? AppColors.defaulted
                    : AppColors.textSecondary,
              ),
              onPressed: member.hasPin ? () => _resetPin(context) : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resetPin(BuildContext context) async {
    final provider = context.read<MemberProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reset ${member.name}\'s PIN?',
            style: const TextStyle(fontSize: 17)),
        content: const Text(
          'The old PIN stops working. The member chooses a new PIN the next '
          'time they turn their key at a meeting unlock.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep PIN'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await provider.clearPin(member);
    if (context.mounted) {
      showAppSnack(context, '${member.name}\'s PIN was reset.');
    }
  }
}
