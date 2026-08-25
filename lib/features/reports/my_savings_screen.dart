import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/remote/member_overview.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';
import 'member_pdf.dart';

/// A member's own savings across every group they belong to.
///
/// People here commonly save with more than one VSLA, and until now each
/// passbook could only be seen on its own. This is the whole picture, with
/// each group still shown separately underneath so the totals can be checked.
class MySavingsScreen extends StatefulWidget {
  const MySavingsScreen({super.key});

  @override
  State<MySavingsScreen> createState() => _MySavingsScreenState();
}

class _MySavingsScreenState extends State<MySavingsScreen> {
  MemberOverview? _overview;
  bool _loading = true;
  bool _sharing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await context.read<ConnectionProvider>().api.myOverview();
      if (mounted) {
        setState(() {
          _overview = overview;
          if (overview == null) {
            _error = 'Could not load your savings. Check your connection.';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your savings.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    final overview = _overview;
    if (overview == null) return;
    setState(() => _sharing = true);
    try {
      await shareOverviewPdf(overview);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Could not create the PDF. Try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final overview = _overview;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.mySavingsMySavings)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Couldn\'t load',
                        message: _error!,
                      ),
                    )
                  else if (overview == null || overview.groupCount == 0)
                    Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EmptyState(
                        icon: Icons.savings_outlined,
                        title: l10n.agentReportNoGroupsYet,
                        message:
                            l10n.mySavingsOnceAGroupAcceptsYou,
                      ),
                    )
                  else ...[
                    Card(
                      color: AppColors.surfaceRaised,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(overview.memberName,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                            Text(
                              overview.groupCount == 1
                                  ? 'Saving with 1 group'
                                  : 'Saving with ${overview.groupCount} groups',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SectionLabel('Everything together'),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 12),
                        child: Column(
                          children: [
                            KeyValueRow('Shares bought',
                                Formatters.money(overview.shares)),
                            KeyValueRow(
                                'Social fund', Formatters.money(overview.social)),
                            if (overview.fines > 0)
                              KeyValueRow(
                                  'Fines paid', Formatters.money(overview.fines)),
                            const Divider(height: 16),
                            KeyValueRow('Total paid in',
                                Formatters.money(overview.totalPaidIn),
                                emphasize: true),
                            const SizedBox(height: 8),
                            KeyValueRow('Loans received',
                                Formatters.money(overview.loansReceived)),
                            KeyValueRow(
                                'Repaid', Formatters.money(overview.loansRepaid)),
                            const Divider(height: 16),
                            KeyValueRow('Still owing',
                                Formatters.money(overview.loanOutstanding),
                                emphasize: true),
                          ],
                        ),
                      ),
                    ),
                    if (overview.groupCount > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline,
                                size: 15, color: AppColors.textSecondary),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                l10n.mySavingsWhatYouOweIsCountedFor,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SectionLabel('Group by group'),
                    for (final position in overview.groups)
                      _GroupCard(position: position),
                  ],
                ],
              ),
      ),
      bottomNavigationBar: overview == null || overview.groupCount == 0
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: FilledButton.icon(
                  onPressed: _sharing ? null : _download,
                  icon: _sharing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined, size: 18),
                  label: Text(_sharing ? 'Preparing...' : 'Download my report'),
                ),
              ),
            ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.position});

  final MemberGroupPosition position;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final book = position.passbook;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    position.groupName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                if (position.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      l10n.joinGroupViewing,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                  ),
              ],
            ),
            const Divider(height: 16),
            KeyValueRow('Paid in', Formatters.money(book.totalPaidIn)),
            KeyValueRow('Shares', Formatters.money(book.shares)),
            if (book.loansReceived > 0)
              KeyValueRow('Loans received', Formatters.money(book.loansReceived)),
            if (book.loanOutstanding > 0)
              KeyValueRow('Still owing', Formatters.money(book.loanOutstanding),
                  emphasize: true),
          ],
        ),
      ),
    );
  }
}
