import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/member.dart';
import '../../data/models/remote/remote_models.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';
import '../../providers/sync_provider.dart';
import '../../shared/widgets/common.dart';
import 'server_settings_screen.dart';

/// Phase 2a write-path sync UI: link the local group to a backend group,
/// map members, and push closed meetings up to the server.
class GroupSyncScreen extends StatefulWidget {
  const GroupSyncScreen({super.key});

  @override
  State<GroupSyncScreen> createState() => _GroupSyncScreenState();
}

class _GroupSyncScreenState extends State<GroupSyncScreen> {
  String? _selectedRemoteGroupId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final group = context.read<AppState>().group;
      if (group != null) {
        context.read<SyncProvider>().loadStatus(group.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final sync = context.watch<SyncProvider>();
    final group = context.watch<AppState>().group;
    if (group == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Back Up to Cloud')),
      body: !connection.isConnected
          ? _NeedsConnection()
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text('Local group · Cycle ${group.cycleNumber}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
                if (!sync.isGroupBound)
                  _LinkSection(
                    remoteGroups: connection.groups,
                    selected: _selectedRemoteGroupId,
                    busy: sync.busy,
                    onSelect: (id) =>
                        setState(() => _selectedRemoteGroupId = id),
                    onLink: () => _link(group.id, connection.groups),
                  )
                else
                  _BoundSection(
                    sync: sync,
                    connection: connection,
                    onPush: () => _push(group.id),
                    onUnlink: () => _unlink(group.id),
                    onLinkMember: _linkMemberDialog,
                  ),
                if (sync.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(sync.error!,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.defaulted)),
                  ),
              ],
            ),
    );
  }

  Future<void> _link(String localGroupId, List<RemoteGroup> remoteGroups) async {
    final id = _selectedRemoteGroupId ??
        (remoteGroups.isNotEmpty ? remoteGroups.first.id : null);
    if (id == null) return;
    final remote = remoteGroups.firstWhere((g) => g.id == id);
    await context.read<SyncProvider>().bindGroupAndMatch(localGroupId, remote);
    if (mounted) {
      showAppSnack(context, 'Linked to ${remote.name}.');
    }
  }

  Future<void> _push(String localGroupId) async {
    final messenger = ScaffoldMessenger.of(context);
    final summary =
        await context.read<SyncProvider>().syncClosedMeetings(localGroupId);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(summary),
      backgroundColor: AppColors.surfaceRaised,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _unlink(String localGroupId) async {
    final syncProvider = context.read<SyncProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unlink group?', style: TextStyle(fontSize: 17)),
        content: const Text(
          'This clears the local↔backend mapping. Already-synced records '
          'stay on the server; nothing is deleted.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.defaulted,
                foregroundColor: const Color(0xFF3A0D09),
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 20)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await syncProvider.unlink(localGroupId);
    }
  }

  Future<void> _linkMemberDialog(Member local) async {
    final sync = context.read<SyncProvider>();
    final remoteMembers = await sync.remoteMembers();
    if (!mounted) return;
    final chosen = await showModalBottomSheet<RemoteMember>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Link "${local.name}" to…',
                  style: Theme.of(ctx).textTheme.titleMedium),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in remoteMembers)
                    ListTile(
                      leading: MemberAvatar(r.fullName),
                      title: Text(r.fullName,
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text('${r.roleLabel}${r.phone != null ? ' · ${r.phone}' : ''}',
                          style: const TextStyle(fontSize: 11.5)),
                      onTap: () => Navigator.pop(ctx, r),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen != null) {
      await sync.linkMember(local, chosen);
      if (mounted) showAppSnack(context, 'Linked ${local.name}.');
    }
  }
}

class _NeedsConnection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 14),
            Text('Not connected',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Connect to the IntelliCash backend before linking and syncing '
              'this group.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                    builder: (_) => const ServerSettingsScreen()),
              ),
              child: const Text('Open Server Connection'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkSection extends StatelessWidget {
  const _LinkSection({
    required this.remoteGroups,
    required this.selected,
    required this.busy,
    required this.onSelect,
    required this.onLink,
  });

  final List<RemoteGroup> remoteGroups;
  final String? selected;
  final bool busy;
  final ValueChanged<String?> onSelect;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Link to a backend group'),
        if (remoteGroups.isEmpty)
          const EmptyState(
            icon: Icons.groups_outlined,
            title: 'No backend groups',
            message: 'This API key cannot see any groups to link to.',
          )
        else ...[
          DropdownButtonFormField<String>(
            initialValue: selected ?? remoteGroups.first.id,
            decoration: const InputDecoration(labelText: 'Backend group'),
            dropdownColor: AppColors.surfaceRaised,
            items: [
              for (final g in remoteGroups)
                DropdownMenuItem(
                  value: g.id,
                  child: Text('${g.name} (${g.code})',
                      style: const TextStyle(fontSize: 14)),
                ),
            ],
            onChanged: onSelect,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Linking matches your local members to the backend '
                      'roster by phone, then name. Unmatched members can be '
                      'linked by hand afterwards.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : onLink,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.link, size: 18),
            label: Text(busy ? 'Linking…' : 'Link & Match Members'),
          ),
        ],
      ],
    );
  }
}

class _BoundSection extends StatelessWidget {
  const _BoundSection({
    required this.sync,
    required this.connection,
    required this.onPush,
    required this.onUnlink,
    required this.onLinkMember,
  });

  final SyncProvider sync;
  final ConnectionProvider connection;
  final VoidCallback onPush;
  final VoidCallback onUnlink;
  final Future<void> Function(Member) onLinkMember;

  @override
  Widget build(BuildContext context) {
    final remote = connection.groups
        .where((g) => g.id == sync.remoteGroupId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Linked'),
        Card(
          color: AppColors.primaryTint,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.link, size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(remote?.name ?? 'Backend group',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                      Text(
                        '${sync.mappedMembers}/${sync.localMembers} members mapped',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (sync.unmatchedMembers.isNotEmpty) ...[
          const SectionLabel('Unmatched members'),
          Text(
            'These local members have no backend match. Link them before '
            'their transactions can sync.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          for (final m in sync.unmatchedMembers)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: MemberAvatar(m.name),
                title:
                    Text(m.name, style: const TextStyle(fontSize: 13.5)),
                subtitle: Text(m.phone ?? 'No phone',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                trailing: TextButton(
                  onPressed: () => onLinkMember(m),
                  child: const Text('Link'),
                ),
              ),
            ),
        ],
        const SectionLabel('Push meetings'),
        Text(
          'Uploads attendance and ledger (shares, social fund, loans, '
          'repayments) for every closed meeting. Safe to re-run — already '
          'synced records are skipped. Fines and meeting sealing come in a '
          'later phase.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: sync.busy ? null : onPush,
          icon: sync.busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cloud_upload_outlined, size: 18),
          label: Text(sync.busy ? 'Syncing…' : 'Push Closed Meetings'),
        ),
        if (sync.lastSummary != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(sync.lastSummary!,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.defaulted,
            side: BorderSide(color: AppColors.defaulted.withValues(alpha: 0.4)),
          ),
          onPressed: onUnlink,
          icon: const Icon(Icons.link_off, size: 18),
          label: const Text('Unlink Group'),
        ),
      ],
    );
  }
}
