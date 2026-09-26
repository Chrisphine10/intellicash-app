import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/dashboard_summary.dart';
import '../../data/models/remote/remote_models.dart';
import '../../data/repositories/id_map_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/status_chip.dart';
import 'widgets/link_proposal_card.dart';
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
  // -1 so the first build loads; after that, each finished sync reloads.
  int _loadedRevision = -1;

  Future<void> _load() async {
    final appState = context.read<AppState>();
    final group = appState.group;
    if (group == null) return;
    final connection = context.read<ConnectionProvider>();
    final dashboardProvider = context.read<DashboardProvider>();
    // Server figures only for THIS book's own server group. A book not linked
    // yet gets none: the group selected online may be a different group (an
    // agent's caseload), and its money must never appear on this dashboard.
    RemoteGroup? remoteGroup;
    try {
      final remoteGroupId =
          await IdMapRepository(AppDatabase.instance).remoteId(MapEntity.group, group.id);
      if (remoteGroupId != null) {
        final selected = connection.selectedGroup;
        if (selected?.id == remoteGroupId) {
          remoteGroup = selected;
        } else if (connection.isConnected) {
          remoteGroup = await connection.api.groupDetail(remoteGroupId);
        }
      }
    } catch (_) {
      // Offline or refused: the dashboard shows the phone's own book.
    }
    await dashboardProvider.load(group.id, remoteGroup: remoteGroup);
    if (mounted) {
      await appState.refreshPendingSync();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final appState = context.watch<AppState>();
    final provider = context.watch<DashboardProvider>();
    // Reload after each sync — including the one that runs at sign-in — so the
    // figures shown are the ones the phone now holds.
    if (appState.syncRevision != _loadedRevision) {
      _loadedRevision = appState.syncRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
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
            // Only when the phone's book might belong to the group signed in as;
            // asked, never assumed.
            const LinkProposalCard(),
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
            _SharesSourceNote(summary: summary),
            const SectionLabel('Shares trend'),
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


/// Where the "Total shares" figure came from. The phone's own book is shown
/// whenever it holds meetings; the online record's figure is shown beside it
/// when the two differ, so a gap is explained rather than hidden or blended.
class _SharesSourceNote extends StatelessWidget {
  const _SharesSourceNote({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final online = summary.serverTotalShares;
    final String? text;
    if (summary.sharesFromServer) {
      text = l10n.dashboardSharesFromServer;
    } else if (online != null && (online - summary.totalSavings).abs() >= 1) {
      text = l10n.dashboardSharesOnlineDiffers(Formatters.money(online));
    } else {
      text = null;
    }
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
