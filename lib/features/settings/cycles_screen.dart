import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/remote_governance_api.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';

/// Saving cycles.
///
/// Closing a cycle archives a whole year of a group's records, so the wording
/// is deliberately unambiguous: read-only, NOT deleted. "Archived" is easily
/// heard as "gone", and this is the group's entire financial history.
class CyclesScreen extends StatefulWidget {
  const CyclesScreen({super.key});

  @override
  State<CyclesScreen> createState() => _CyclesScreenState();
}

class _CyclesScreenState extends State<CyclesScreen> {
  RemoteCycles? _data;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  String? get _groupId => context.read<ConnectionProvider>().selectedGroup?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final groupId = _groupId;
    if (groupId == null) {
      setState(() {
        _loading = false;
        _error = 'Choose your group under Cloud Account first.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<RemoteGovernanceApi>().cycles(groupId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '$error';
        _loading = false;
      });
    }
  }

  Future<void> _close() async {
    // Captured BEFORE the confirm dialog: the dialog is itself an async gap,
    // and reading context after it is how a popped screen throws on return.
    final api = context.read<RemoteGovernanceApi>();
    final groupId = _groupId;
    if (groupId == null) return;

    final current = _data?.cycles.where((c) => c.editable).firstOrNull;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Close cycle ${current?.number ?? ''}?'),
        content: Text(
          'Its ${current?.meetings ?? 0} meeting(s) become read-only — they stay '
          'visible in history and reports, nothing is deleted.\n\n'
          'Members, roles and balances carry over to the new cycle. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Close cycle'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final message = await api.closeCycle(groupId);
      await _load();
      if (!mounted) return;
      showAppSnack(context, message);
    } catch (error) {
      if (!mounted) return;
      showAppSnack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saving Cycles')),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [Text(_error!, style: TextStyle(color: AppColors.defaulted))],
      );
    }
    final data = _data;
    if (data == null) {
      // Never render nothing: an empty screen reads as "this feature does not
      // exist", which is exactly how the welfare module came to be reported
      // missing. Say what happened and offer the one control that recovers it.
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Could not load this group's saving cycles.",
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            'Pull down to try again. If it keeps happening, check the group is '
            'still selected under Cloud Account.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: _load, child: const Text('Try again')),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Currently on cycle ${data.currentNumber}.',
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'Closing a cycle makes its records read-only. Nothing is deleted — '
              'past meetings and money stay in history and reports.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (data.canManage)
          FilledButton.icon(
            onPressed: _busy ? null : _close,
            icon: const Icon(Icons.event_available_outlined, size: 18),
            label: const Text('Close cycle and start the next'),
          )
        else
          Text(
            'You can see the cycles but not close one. Only the group account or '
            'a platform admin can.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 16),
        for (final cycle in data.cycles) _cycleCard(cycle),
      ],
    );
  }

  Widget _cycleCard(RemoteCycle cycle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Cycle ${cycle.number}',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                Text(
                  cycle.editable ? 'Open' : 'Archived',
                  style: TextStyle(
                    fontSize: 12,
                    color: cycle.editable ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${cycle.meetings} meeting(s) · ${cycle.ledgerEntries} entries',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!cycle.editable)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Read-only — still visible in reports',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
