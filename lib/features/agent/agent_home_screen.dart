import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/remote/credit_rating.dart';
import '../../data/models/remote/remote_models.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';
import '../account/account_route.dart';
import '../reports/agent_report_screen.dart';
import 'agent_group_detail_screen.dart';
import 'credit_band_chip.dart';

/// Home for a Village Agent / CBT: their caseload of groups, each with its
/// credit band, so the agent can see at a glance which groups need support.
class AgentHomeScreen extends StatefulWidget {
  const AgentHomeScreen({super.key});

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen> {
  final Map<String, RemoteCreditRating?> _ratings = {};
  bool _loadingRatings = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRatings());
  }

  Future<void> _loadRatings() async {
    final connection = context.read<ConnectionProvider>();
    setState(() => _loadingRatings = true);
    for (final g in connection.groups) {
      try {
        _ratings[g.id] = await connection.api.creditRating(g.id);
      } catch (_) {
        _ratings[g.id] = null;
      }
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => _loadingRatings = false);
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final user = connection.signedInUser;
    final groups = connection.groups;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Groups'),
        /*
         * Two icons, not four. Language and sign out moved to Account, where
         * they are labelled. Three unlabelled icons in a row put a destructive
         * action a mis-tap away from a routine one.
         */
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined, size: 20),
            tooltip: 'Caseload report',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  // Hand over the ratings already loaded here so the
                  // report opens without refetching every group.
                  builder: (_) => AgentReportScreen(ratings: Map.of(_ratings)),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined, size: 22),
            tooltip: 'Account',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AccountRoute()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await connection.refreshAll();
          await _loadRatings();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Card(
              color: AppColors.surfaceRaised,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AccountRoute()),
                ),
                child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined,
                        color: AppColors.primary, size: 26),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.name ?? 'Agent',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          Text(
                            '${user?.roleLabel ?? 'Village Agent'} · '
                            '${groups.length} group${groups.length == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
              ),
              ),
            ),
            _CaseloadSummary(ratings: _ratings, total: groups.length),
            const SectionLabel('Caseload'),
            if (groups.isEmpty)
              const EmptyState(
                icon: Icons.groups_outlined,
                title: 'No groups assigned',
                message:
                    'When groups are assigned to you, they appear here with '
                    'their credit rating.',
              ),
            for (final g in groups)
              _GroupCard(
                group: g,
                rating: _ratings[g.id],
                loading: _loadingRatings && !_ratings.containsKey(g.id),
                onTap: () async {
                  await connection.selectGroup(g.id);
                  if (!context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AgentGroupDetailScreen(group: g),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _CaseloadSummary extends StatelessWidget {
  const _CaseloadSummary({required this.ratings, required this.total});

  final Map<String, RemoteCreditRating?> ratings;
  final int total;

  @override
  Widget build(BuildContext context) {
    final rated = ratings.values.whereType<RemoteCreditRating>().toList();
    final needAttention =
        rated.where((r) => r.band == 'C' || r.band == 'D' || !r.rated).length;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: _MiniStat(
              label: 'Groups',
              value: '$total',
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _MiniStat(
              label: 'Need support',
              value: '$needAttention',
              color: needAttention > 0 ? AppColors.pending : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.rating,
    required this.loading,
    required this.onTap,
  });

  final RemoteGroup group;
  final RemoteCreditRating? rating;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(group.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${group.code} · ${group.county}'
          '${group.memberCount != null ? ' · ${group.memberCount} members' : ''}',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : rating != null
                ? CreditBandChip(rating: rating!)
                : const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
