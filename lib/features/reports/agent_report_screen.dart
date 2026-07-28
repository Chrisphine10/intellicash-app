import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/remote/agent_report.dart';
import '../../data/models/remote/credit_rating.dart';
import '../../data/models/remote/remote_models.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';
import '../agent/credit_band_chip.dart';
import 'report_share.dart';

/// A Village Agent's caseload in shareable form: every group with its
/// credit band, member count and a "needs support" flag, plus a summary
/// line — ready to send to a supervisor over WhatsApp.
class AgentReportScreen extends StatefulWidget {
  const AgentReportScreen({super.key, this.ratings});

  /// Credit ratings already loaded by the agent home screen (group id →
  /// rating, null when the rating call failed). When null, this screen
  /// loads them itself.
  final Map<String, RemoteCreditRating?>? ratings;

  @override
  State<AgentReportScreen> createState() => _AgentReportScreenState();
}

class _AgentReportScreenState extends State<AgentReportScreen> {
  final Map<String, RemoteCreditRating?> _ratings = {};
  bool _loading = false;

  /// The whole caseload in one response, when the server could be reached.
  AgentReport? _report;

  @override
  void initState() {
    super.initState();
    if (widget.ratings != null) {
      _ratings.addAll(widget.ratings!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRatings());
    }
  }

  Future<void> _loadRatings() async {
    final connection = context.read<ConnectionProvider>();
    setState(() => _loading = true);

    // One request covers the whole caseload, and carries the server's own
    // judgement on which groups need a visit.
    final report = await connection.api.agentReport();
    if (report != null) {
      if (mounted) {
        setState(() {
          _report = report;
          _loading = false;
        });
      }
      return;
    }

    // Offline: fall back to one rating call per group, as before.
    for (final g in connection.groups) {
      try {
        _ratings[g.id] = await connection.api.creditRating(g.id);
      } catch (_) {
        _ratings[g.id] = null;
      }
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => _loading = false);
  }

  /// A group needs a visit when it is rated C or D, or when nobody has
  /// assessed it at all — an unrated group is precisely one an agent should
  /// look at, and the server applies the same rule.
  bool _needsSupport(RemoteCreditRating? rating) =>
      rating == null || !rating.rated || rating.band == 'C' || rating.band == 'D';

  /// The server's verdict when we have it, otherwise this phone's.
  bool _needsSupportFor(String groupId) {
    for (final row in _report?.groups ?? const <AgentReportGroup>[]) {
      if (row.id == groupId) return row.needsSupport;
    }
    return _needsSupport(_ratings[groupId]);
  }

  int _scoreFor(String groupId) {
    for (final row in _report?.groups ?? const <AgentReportGroup>[]) {
      if (row.id == groupId) return row.score;
    }
    return _ratings[groupId]?.score ?? 0;
  }

  /// The band to display: the caseload report's, else the per-group rating.
  String? _bandFor(String groupId) {
    for (final row in _report?.groups ?? const <AgentReportGroup>[]) {
      if (row.id == groupId) return row.rated ? row.band : null;
    }
    return _ratings[groupId]?.band;
  }

  String _buildReportText(String agentName, List<RemoteGroup> groups) {
    final ratedCount = _report?.ratedCount ??
        _ratings.values.whereType<RemoteCreditRating>().where((r) => r.rated).length;
    final needSupport = groups.where((g) => _needsSupportFor(g.id));

    final lines = <String>[
      'CASELOAD REPORT — $agentName',
      Formatters.fullDate(DateTime.now()),
      '${groups.length} group${groups.length == 1 ? '' : 's'} · '
          '$ratedCount rated · ${needSupport.length} need support',
      '',
    ];
    for (final g in groups) {
      final band = _bandFor(g.id) ?? 'No rating yet';
      lines
        ..add('${g.name} (${g.code})')
        ..add(reportLine('  Rating', band == 'No rating yet' ? band : 'Band $band'));
      if (g.memberCount != null) {
        lines.add(reportLine('  Members', '${g.memberCount}'));
      }
      if (_needsSupportFor(g.id)) {
        lines.add('  Needs support');
      }
      lines.add('');
    }
    if (groups.isEmpty) lines.add('No groups assigned yet.');
    lines.add('Shared from IntelliCash');
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final user = connection.signedInUser;
    final groups = connection.groups;
    final agentName = user?.name ?? 'Agent';

    final rated = _report?.ratedCount ??
        _ratings.values
            .whereType<RemoteCreditRating>()
            .where((r) => r.rated)
            .length;
    final needSupport =
        groups.where((g) => _needsSupportFor(g.id)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Caseload Report')),
      body: groups.isEmpty
          ? const EmptyState(
              icon: Icons.groups_outlined,
              title: 'No groups yet',
              message: 'When groups are assigned to you, their report '
                  'appears here.',
            )
          : RefreshIndicator(
              onRefresh: _loadRatings,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Card(
                    color: AppColors.surfaceRaised,
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
                                Text(agentName,
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                                Text(
                                  '${groups.length} group'
                                  '${groups.length == 1 ? '' : 's'} · '
                                  '$rated rated · $needSupport need support',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (_loading)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SectionLabel('Groups'),
                  for (final g in groups)
                    _ReportGroupCard(
                      group: g,
                      band: _bandFor(g.id),
                      score: _scoreFor(g.id),
                      needsSupport: _needsSupportFor(g.id),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: groups.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton.icon(
                  onPressed: () => shareReport(
                    'Caseload Report — $agentName',
                    _buildReportText(agentName, groups),
                  ),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share Report'),
                ),
              ),
            ),
    );
  }
}

class _ReportGroupCard extends StatelessWidget {
  const _ReportGroupCard({
    required this.group,
    required this.band,
    required this.score,
    required this.needsSupport,
  });

  final RemoteGroup group;
  final String? band;
  final int score;
  final bool needsSupport;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Text(group.name,
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${group.code}'
              '${group.memberCount != null ? ' · ${group.memberCount} members' : ''}',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            if (needsSupport)
              Text(
                'Needs support',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.pending,
                ),
              ),
          ],
        ),
        trailing: band != null
            ? CreditBandChip.values(band: band!, score: score, rated: true)
            : Text(
                'No rating',
                style:
                    TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
      ),
    );
  }
}
