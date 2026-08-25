import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
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
    final l10n = L10n.of(context);
    final appState = context.watch<AppState>();
    final provider = context.watch<DashboardProvider>();
    final group = appState.group;
    if (group == null) return const SizedBox.shrink();
    final summary = provider.summary;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navDashboard),
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
            Text(l10n.dashboardHello, style: Theme.of(context).textTheme.headlineSmall),
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
                  label: l10n.dashboardTotalSavings,
                  icon: Icons.savings_outlined,
                ),
                StatCard(
                  value: '${summary.activeLoans}',
                  label: l10n.dashboardActiveLoans,
                  icon: Icons.payments_outlined,
                ),
                StatCard(
                  value: '${summary.memberCount}',
                  label: l10n.navMembers,
                  icon: Icons.people_outline,
                ),
                StatCard(
                  value: '${summary.meetingCount}',
                  label: l10n.navMeetings,
                  icon: Icons.event_note_outlined,
                ),
                StatCard(
                  value: Formatters.moneyCompact(summary.finesCollected),
                  label: l10n.dashboardFinesCollected,
                  icon: Icons.error_outline,
                ),
                StatCard(
                  value: Formatters.moneyCompact(summary.socialFund),
                  label: l10n.meetingHubSocialFund,
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
                            l10n.dashboardTheSavingsCurveAppearsAfterYour,
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
