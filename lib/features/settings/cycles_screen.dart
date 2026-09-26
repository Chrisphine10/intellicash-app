import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../data/repositories/id_map_repository.dart';
import '../shareout/share_out_screen.dart';
import '../../data/services/remote_governance_api.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';
import '../../core/utils/user_message.dart';

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

  /// The group a load was last attempted for: the screen retries by itself when
  /// the group appears after it opened (signal returned), but never loops.
  String? _triedGroupId;
  bool _busy = false;

  String? get _groupId => context.read<ConnectionProvider>().selectedGroup?.id;

  /// Shares bought this cycle in this phone's own book (some may not have
  /// reached the server yet). Any at all and the cycle ends with a share-out.
  bool _phoneHasShares = false;

  Future<bool> _localSharesThisCycle(String remoteGroupId) async {
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS n FROM share_purchases sp
      JOIN meetings m ON m.id = sp.meeting_id
      JOIN groups g ON g.id = m.group_id
      JOIN id_map im ON im.entity_type = ? AND im.local_id = g.id AND im.remote_id = ?
      WHERE sp.created_at > g.cycle_start_date
    ''', [MapEntity.group, remoteGroupId]);
    return ((rows.first['n'] as num?) ?? 0) > 0;
  }

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
        _error = 'Your group has not loaded yet. It needs a connection and loads by itself when signal returns — or pull down to try again.';
      });
      return;
    }
    _triedGroupId = groupId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await context.read<RemoteGovernanceApi>().cycles(groupId);
      final phoneHasShares = await _localSharesThisCycle(groupId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _phoneHasShares = phoneHasShares;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = userMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _close() async {
    final l10n = L10n.of(context);
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
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.cyclesCloseCycle),
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
      showAppSnack(context, userMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupNow = context.watch<ConnectionProvider>().selectedGroup?.id;
    if (groupNow != null && groupNow != _triedGroupId && !_loading) {
      _triedGroupId = groupNow;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    final l10n = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.cyclesSavingCycles)),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    final l10n = L10n.of(context);
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
          Text("Could not load this group's share cycles.",
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            l10n.cyclesPullDownToTryAgainIf,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: _load, child: Text(l10n.welfareTryAgain)),
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
              l10n.cyclesClosingACycleMakesItsRecords,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (data.canManage && (data.closeNeedsShareOut || _phoneHasShares))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.cyclesShareOutFirst,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(l10n.cyclesShareOutFirstBody,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ShareOutScreen()),
                    ),
                    icon: const Icon(Icons.pie_chart_outline, size: 18),
                    label: Text(l10n.cyclesGoToShareOut),
                  ),
                ],
              ),
            ),
          )
        else if (data.canManage)
          FilledButton.icon(
            onPressed: _busy ? null : _close,
            icon: const Icon(Icons.event_available_outlined, size: 18),
            label: Text(l10n.cyclesCloseCycleAndStartThe),
          )
        else
          Text(
            l10n.cyclesYouCanSeeTheCyclesBut,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 16),
        for (final cycle in data.cycles) _cycleCard(cycle),
      ],
    );
  }

  Widget _cycleCard(RemoteCycle cycle) {
    final l10n = L10n.of(context);
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
                  l10n.cyclesReadOnlyStillVisibleIn,
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
