import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/app_state.dart';
import '../../providers/dashboard_provider.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/status_chip.dart';
import 'widgets/savings_trend_chart.dart';
import 'widgets/stat_card.dart';

/// The group's financial health in one screen: six live stats and the
/// savings growth curve.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final group = context.read<AppState>().group;
    if (group == null) return;
    await context.read<DashboardProvider>().load(group.id);
    if (mounted) {
      await context.read<AppState>().refreshPendingSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final provider = context.watch<DashboardProvider>();
    final group = appState.group;
    if (group == null) return const SizedBox.shrink();
    final summary = provider.summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: appState.pendingSync > 0
                  ? StatusChip.pendingSync(appState.pendingSync)
                  : StatusChip.synced(),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Text('Hello 👋', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 2),
            Text(
              '${group.name} · Cycle ${group.cycleNumber}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SectionLabel('Overview'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: [
                StatCard(
                  value: Formatters.moneyCompact(summary.totalSavings),
                  label: 'Total Savings',
                  icon: Icons.savings_outlined,
                ),
                StatCard(
                  value: '${summary.activeLoans}',
                  label: 'Active Loans',
                  icon: Icons.payments_outlined,
                ),
                StatCard(
                  value: '${summary.memberCount}',
                  label: 'Members',
                  icon: Icons.people_outline,
                ),
                StatCard(
                  value: '${summary.meetingCount}',
                  label: 'Meetings',
                  icon: Icons.event_note_outlined,
                ),
                StatCard(
                  value: Formatters.moneyCompact(summary.finesCollected),
                  label: 'Fines Collected',
                  icon: Icons.error_outline,
                ),
                StatCard(
                  value: Formatters.moneyCompact(summary.socialFund),
                  label: 'Social Fund',
                  icon: Icons.favorite_outline,
                ),
              ],
            ),
            const SectionLabel('Savings trend'),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
                child: summary.trend.length < 2
                    ? SizedBox(
                        height: 140,
                        child: Center(
                          child: Text(
                            'The savings curve appears after your first '
                            'two meetings.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : SavingsTrendChart(points: summary.trend),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
