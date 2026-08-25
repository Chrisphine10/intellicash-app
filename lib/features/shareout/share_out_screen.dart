import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/share_out_calculator.dart';
import '../../data/repositories/share_out_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/share_out_provider.dart';
import '../../shared/widgets/common.dart';

/// End-of-cycle share-out: shows how the group's fund is distributed back to
/// members (pro-rata by their contributions, with loans netted off), then
/// closes the cycle.
class ShareOutScreen extends StatefulWidget {
  const ShareOutScreen({super.key});

  @override
  State<ShareOutScreen> createState() => _ShareOutScreenState();
}

class _ShareOutScreenState extends State<ShareOutScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final group = context.read<AppState>().group;
      if (group != null) context.read<ShareOutProvider>().load(group);
    });
  }

  String _money(int cents) => Formatters.money(cents / 100);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final appState = context.watch<AppState>();
    final provider = context.watch<ShareOutProvider>();
    final group = appState.group;
    final result = provider.preview;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.shareOut)),
      body: group == null
          ? const SizedBox.shrink()
          : provider.loading && result == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    Text('Cycle ${group.cycleNumber}',
                        style: Theme.of(context).textTheme.headlineSmall),
                    Text(
                      'Started ${Formatters.shortDate(group.cycleStartDate)} · '
                      'end-of-cycle distribution',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (result == null || !provider.canDistribute)
                      Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: EmptyState(
                          icon: Icons.savings_outlined,
                          title: l10n.shareOutNothingToShareOutYet,
                          message:
                              l10n.shareOutMembersHavenTBoughtSharesThis,
                        ),
                      )
                    else ...[
                      _PoolCard(result: result, money: _money),
                      _WelfareToggle(
                        result: result,
                        money: _money,
                        onChanged: (v) =>
                            provider.setDistributeWelfare(group, v),
                      ),
                      const SectionLabel('Member payouts'),
                      _PayoutTable(result: result, money: _money),
                      const SizedBox(height: 8),
                      _TotalsCard(result: result, money: _money),
                      if (result.membersOwing.isNotEmpty)
                        _OwingNotice(result: result, money: _money),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        onPressed: provider.busy
                            ? null
                            : () => _confirmDistribute(group, result),
                        icon: const Icon(Icons.account_balance_wallet_outlined,
                            size: 18),
                        label: Text(
                            'Distribute & close Cycle ${group.cycleNumber}'),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.shareOutStartsNextCycle(group.cycleNumber + 1),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (provider.history.isNotEmpty) ...[
                      const SectionLabel('Past share-outs'),
                      for (final record in provider.history)
                        _HistoryTile(record: record),
                    ],
                  ],
                ),
    );
  }

  Future<void> _confirmDistribute(group, ShareOutResult result) async {
    final l10n = L10n.of(context);
    final appState = context.read<AppState>();
    final provider = context.read<ShareOutProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Share out Cycle ${group.cycleNumber}?',
            style: const TextStyle(fontSize: 17)),
        content: Text(
          'Distribute ${_money(result.totalNetPaidCents)} to '
          '${result.lines.length} member(s)'
          '${result.totalOutstandingCents > 0 ? ', settling ${_money(result.totalOutstandingCents)} in outstanding loans' : ''}, '
          'and start Cycle ${group.cycleNumber + 1}.\n\n'
          'This is permanent.',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.shareOutDistribute),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final next = await provider.distribute(group);
    if (!mounted) return;
    if (next == null) {
      showAppSnack(context, provider.error ?? 'Could not distribute.',
          error: true);
      return;
    }
    await appState.reloadGroup();
    if (!mounted) return;
    showAppSnack(context,
        'Cycle ${group.cycleNumber} shared out. Now in Cycle ${next.cycleNumber}.');
  }
}

class _PoolCard extends StatelessWidget {
  const _PoolCard({required this.result, required this.money});
  final ShareOutResult result;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final growth = (result.growthRate * 100);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.shareOutFundToDistribute,
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 6),
            Text(money(result.savingsPoolCents),
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            const SizedBox(height: 12),
            KeyValueRow('Member contributions', money(result.shareCapitalCents)),
            KeyValueRow(
              'Interest & earnings',
              '${money(result.interestEarnedCents)}'
              '${growth > 0 ? '  (+${growth.toStringAsFixed(1)}%)' : ''}',
            ),
            if (result.welfarePoolCents > 0)
              KeyValueRow('Welfare fund', money(result.welfarePoolCents)),
          ],
        ),
      ),
    );
  }
}

class _WelfareToggle extends StatelessWidget {
  const _WelfareToggle({
    required this.result,
    required this.money,
    required this.onChanged,
  });
  final ShareOutResult result;
  final String Function(int) money;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    if (result.welfarePoolCents <= 0) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        value: result.distributeWelfare,
        onChanged: onChanged,
        title: Text(l10n.shareOutSplitWelfareFundEqually,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        subtitle: Text(
          result.distributeWelfare
              ? '${money(result.welfarePoolCents)} shared equally among members'
              : 'Welfare fund is kept for the next cycle',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _PayoutTable extends StatelessWidget {
  const _PayoutTable({required this.result, required this.money});
  final ShareOutResult result;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < result.lines.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14),
            _PayoutRow(line: result.lines[i], money: money),
          ],
        ],
      ),
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.line, required this.money});
  final ShareOutLine line;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final pct = (line.sharePercent * 100).toStringAsFixed(1);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          MemberAvatar(line.memberName, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.memberName,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Paid in ${money(line.shareCents)} · $pct%'
                  '${line.loanOffsetCents > 0 ? '  ·  loan −${money(line.loanOffsetCents)}' : ''}',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(line.netPayoutCents),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: line.owesGroup ? AppColors.defaulted : AppColors.primary,
                ),
              ),
              Text(
                line.owesGroup ? 'owes group' : 'take-home',
                style: TextStyle(
                    fontSize: 10,
                    color: line.owesGroup
                        ? AppColors.defaulted
                        : AppColors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.result, required this.money});
  final ShareOutResult result;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Column(
          children: [
            KeyValueRow('Distributed to members',
                money(result.savingsPoolCents)),
            if (result.welfareDistributedCents > 0)
              KeyValueRow('Welfare distributed',
                  money(result.welfareDistributedCents)),
            if (result.totalOutstandingCents > 0)
              KeyValueRow('Loans settled from payouts',
                  '- ${money(result.totalOutstandingCents)}'),
            const Divider(height: 16),
            KeyValueRow('Net cash paid out', money(result.totalNetPaidCents),
                emphasize: true),
          ],
        ),
      ),
    );
  }
}

class _OwingNotice extends StatelessWidget {
  const _OwingNotice({required this.result, required this.money});
  final ShareOutResult result;
  final String Function(int) money;

  @override
  Widget build(BuildContext context) {
    final owing = result.membersOwing.toList();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.defaultedTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 18, color: AppColors.defaulted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${owing.length} member(s) owe more than their payout and must '
              'settle the balance: '
              '${owing.map((l) => '${l.memberName} (${money(-l.netPayoutCents)})').join(', ')}.',
              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});
  final ShareOutRecord record;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        title: Text('Cycle ${record.cycleNumber} share-out',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${Formatters.shortDate(record.date)} · '
          '${Formatters.money(record.totalNet)} to ${record.payouts.length} member(s)',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        children: [
          for (final p in record.payouts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Member names are free text and payouts run large at
                  // share-out. The name gives way; the amount someone is
                  // about to be handed never does.
                  Flexible(
                    child: Text(p.memberName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 10),
                  Text(Formatters.money(p.netPayout),
                      style: const TextStyle(
                          fontSize: 12,
                          fontFeatures: [FontFeature.tabularFigures()])),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
