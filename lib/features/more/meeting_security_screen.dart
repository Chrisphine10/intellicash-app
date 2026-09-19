import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/meeting_unlock.dart';
import '../../data/models/enums.dart';
import '../../data/models/member.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';
import '../../providers/sync_provider.dart';
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
    final l10n = L10n.of(context);
    final appState = context.watch<AppState>();
    final group = appState.group;
    final members = context.watch<MemberProvider>().members;
    if (group == null) return const SizedBox.shrink();

    final officials =
        members.where((m) => m.member.isOfficial).length;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.meetingSecurity)),
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
              title: Text(l10n.meetingSecurity3KeyUnlockBeforeMeetings,
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
                        l10n.meetingSecurityAssignAChairpersonSecretaryAndTreasurer,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          SectionLabel(l10n.digitalChampion),
          _DigitalChampionCard(localGroupId: group.id),
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
    final l10n = L10n.of(context);
    final provider = context.read<MemberProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Reset ${member.name}\'s PIN?',
            style: const TextStyle(fontSize: 17)),
        content: Text(
          l10n.meetingSecurityTheOldPinStopsWorkingThe,
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.meetingSecurityKeepPin),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.meetingSecurityReset),
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

/// The group's digital champion: the member whose phone opens the group's
/// account on the server.
///
/// The champion lives on the SERVER (it decides whose number can sign in to
/// the group with a texted code), so this reads and sets it there. It needs the
/// group linked and a signal; offline it says so rather than pretending.
class _DigitalChampionCard extends StatefulWidget {
  const _DigitalChampionCard({required this.localGroupId});

  final String localGroupId;

  @override
  State<_DigitalChampionCard> createState() => _DigitalChampionCardState();
}

class _DigitalChampionCardState extends State<_DigitalChampionCard> {
  bool _loading = true;
  String? _remoteGroupId;
  String? _championName;
  String? _championPhone;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final sync = context.read<SyncProvider>();
    final connection = context.read<ConnectionProvider>();
    await sync.loadStatus(widget.localGroupId);
    final remoteId = sync.remoteGroupId;
    final remote = remoteId == null ? null : await connection.fetchGroup(remoteId);
    if (!mounted) return;
    setState(() {
      _remoteGroupId = remote == null ? null : remoteId;
      _championName = remote?.championName;
      _championPhone = remote?.championPhone;
      _loading = false;
    });
  }

  Future<void> _choose() async {
    final l10n = L10n.of(context);
    final members = context
        .read<MemberProvider>()
        .members
        .map((entry) => entry.member)
        .where((m) => (m.phone ?? '').trim().isNotEmpty)
        .toList();

    final picked = await showModalBottomSheet<Member>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(l10n.digitalChampionChoose,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(l10n.digitalChampionNeedsPhone),
            ),
            for (final member in members)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(member.name),
                subtitle: Text('${member.phone} · ${member.role.label}'),
                onTap: () => Navigator.of(sheetContext).pop(member),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(picked.name, style: const TextStyle(fontSize: 17)),
        content: Text(l10n.digitalChampionConfirm, style: const TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.digitalChampionMake),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final connection = context.read<ConnectionProvider>();
    final ok = await connection.setGroupChampion(
      remoteGroupId: _remoteGroupId!,
      name: picked.name,
      phone: picked.phone!,
    );
    if (!mounted) return;
    showAppSnack(context, ok ? l10n.digitalChampionSet : (connection.error ?? l10n.digitalChampionFailed),
        error: !ok);
    if (ok) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    if (_loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      );
    }
    if (_remoteGroupId == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.cloud_off_outlined, size: 20),
          title: Text(l10n.digitalChampion, style: const TextStyle(fontSize: 14)),
          subtitle: Text(l10n.digitalChampionOffline, style: theme.textTheme.bodySmall),
        ),
      );
    }
    return Card(
      child: ListTile(
        leading: const Icon(Icons.verified_user_outlined, size: 20),
        title: Text(_championName ?? l10n.digitalChampionNotSet, style: const TextStyle(fontSize: 14)),
        subtitle: Text(
          _championPhone == null ? l10n.digitalChampionIntro : '$_championPhone\n${l10n.digitalChampionIntro}',
          style: theme.textTheme.bodySmall,
        ),
        isThreeLine: _championPhone != null,
        trailing: TextButton(onPressed: _choose, child: Text(l10n.change)),
      ),
    );
  }
}
