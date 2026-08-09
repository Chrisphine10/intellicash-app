import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/remote/credit_rating.dart';
import '../../data/models/remote/group_report.dart';
import '../../data/models/remote/remote_models.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';
import '../visits/record_visit_screen.dart';
import 'credit_band_chip.dart';

/// A group in the agent's caseload: its credit rating (governance + VSLA
/// compliance), members and recent meetings. Read-only — an agent supports and
/// monitors; the group's own officials move its money.
class AgentGroupDetailScreen extends StatefulWidget {
  const AgentGroupDetailScreen({super.key, required this.group});

  final RemoteGroup group;

  @override
  State<AgentGroupDetailScreen> createState() => _AgentGroupDetailScreenState();
}

class _AgentGroupDetailScreenState extends State<AgentGroupDetailScreen> {
  RemoteCreditRating? _rating;

  /// The group's money position, from the server's own totals.
  ///
  /// A credit band says a group is struggling; this says how. An agent going
  /// out to coach one needs the figures, not just the grade.
  GroupReport? _report;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final connection = context.read<ConnectionProvider>();
    setState(() => _loading = true);
    try {
      // Both come from the server; the report returning null just means we
      // show the rating alone rather than failing the whole screen.
      final results = await Future.wait([
        connection.api.creditRating(widget.group.id),
        connection.api.groupReport(widget.group.id),
      ]);
      if (mounted) {
        setState(() {
          _rating = results[0] as RemoteCreditRating?;
          _report = results[1] as GroupReport?;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load the credit rating.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final members = connection.members;
    final meetings = connection.meetings;

    return Scaffold(
      appBar: AppBar(title: Text(widget.group.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text(widget.group.name,
              style: Theme.of(context).textTheme.titleMedium),
          Text('${widget.group.code} · ${widget.group.county}',
              style: Theme.of(context).textTheme.bodySmall),

          const SizedBox(height: 14),
          // The one write an agent can make. Deliberately above the rating:
          // the reason they opened this screen standing in front of the group
          // is to record the visit, not to read a score they already saw on
          // the caseload list.
          FilledButton.icon(
            onPressed: () async {
              final recorded = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => RecordVisitScreen(
                    groupId: widget.group.id,
                    groupName: widget.group.name,
                  ),
                ),
              );
              if (recorded == true && mounted) setState(() {});
            },
            icon: const Icon(Icons.assignment_turned_in_outlined, size: 18),
            label: const Text('Record a visit'),
          ),
          const SectionLabel('Credit rating'),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_rating != null)
            _CreditRatingCard(rating: _rating!)
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error ?? 'No rating available.',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),

          if (_report != null) ...[
            const SectionLabel('Where the money stands'),
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                child: Column(
                  children: [
                    KeyValueRow('Total savings',
                        Formatters.money(_report!.totalSavings)),
                    KeyValueRow(
                        'Social fund', Formatters.money(_report!.socialFund)),
                    if (_report!.fines > 0)
                      KeyValueRow('Fines', Formatters.money(_report!.fines)),
                    const Divider(height: 16),
                    KeyValueRow('Loans given out',
                        Formatters.money(_report!.loansGivenOut)),
                    KeyValueRow(
                        'Repaid', Formatters.money(_report!.loansRepaid)),
                    KeyValueRow('Still owed',
                        Formatters.money(_report!.loansStillOwed),
                        emphasize: true),
                  ],
                ),
              ),
            ),
            // Attendance is the earliest sign a group is drifting, and it
            // moves long before the credit band does.
            if (_report!.attendanceRate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Card(
                  color: _report!.attendanceRate! < 0.6
                      ? AppColors.pendingTint
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 12),
                    child: KeyValueRow(
                      'Meeting attendance',
                      '${(_report!.attendanceRate! * 100).round()}%',
                      emphasize: true,
                    ),
                  ),
                ),
              ),
          ],

          SectionLabel('Members (${members.length})'),
          if (members.isEmpty)
            Text('No members loaded.',
                style: Theme.of(context).textTheme.bodySmall),
          for (final m in members)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                leading: MemberAvatar(m.fullName, radius: 16),
                title: Text(m.fullName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(m.roleLabel,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ),
            ),

          const SectionLabel('Recent meetings'),
          if (meetings.isEmpty)
            Text('No meetings loaded.',
                style: Theme.of(context).textTheme.bodySmall),
          for (final mt in meetings.take(8))
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                title: Text(mt.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  mt.scheduledAt != null
                      ? Formatters.shortDate(mt.scheduledAt!)
                      : 'No date',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary),
                ),
                trailing: Text(
                  mt.status.replaceAll('_', ' ').toLowerCase(),
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CreditRatingCard extends StatelessWidget {
  const _CreditRatingCard({required this.rating});

  final RemoteCreditRating rating;

  @override
  Widget build(BuildContext context) {
    final c = creditBandColor(rating.band);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: c.tint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    rating.rated ? rating.band : '—',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: c.color),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rating.rated
                            ? '${rating.score} / 100 · ${rating.bandLabel}'
                            : rating.bandLabel,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      if (rating.termsSummary.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(rating.termsSummary,
                              style: Theme.of(context).textTheme.bodySmall),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _PillarBar(
                label: 'Governance', points: rating.governance, outOf: 40),
            const SizedBox(height: 8),
            _PillarBar(
                label: 'VSLA compliance',
                points: rating.compliance,
                outOf: 60),
            if (rating.factors.isNotEmpty) ...[
              const Divider(height: 24),
              for (final f in rating.factors)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.label,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                            Text(f.evidence,
                                style: TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Text(
                        '${f.points.toStringAsFixed(f.points % 1 == 0 ? 0 : 1)}/${f.weight}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (rating.recommendations.isNotEmpty) ...[
              const Divider(height: 24),
              Text('To improve',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 6),
              for (final tip in rating.recommendations)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•  ',
                          style: TextStyle(color: AppColors.primary)),
                      Expanded(
                        child: Text(tip,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PillarBar extends StatelessWidget {
  const _PillarBar(
      {required this.label, required this.points, required this.outOf});
  final String label;
  final double points;
  final int outOf;

  @override
  Widget build(BuildContext context) {
    final ratio = (points / outOf).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // The label yields on a narrow handset; the score does not.
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            Text('${points.toStringAsFixed(points % 1 == 0 ? 0 : 1)} / $outOf',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: AppColors.outline,
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

