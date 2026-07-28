import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/remote/member_passbook.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';
import 'member_pdf.dart';
import 'report_share.dart';

/// A member's personal statement in shareable form: the same savings,
/// social-fund, fines and loan totals the passbook shows, plus a
/// "Share Report" button that turns it into WhatsApp-friendly plain text.
class MemberReportScreen extends StatefulWidget {
  const MemberReportScreen({super.key, this.entries, this.passbook});

  /// Ledger entries already loaded by the passbook, so this screen doesn't
  /// need to fetch again. When null, the screen fetches them itself.
  final List<Map<String, dynamic>>? entries;

  /// The server's totals, when the passbook already has them. Passed down so
  /// a member's report cannot show different figures from the passbook they
  /// opened it from.
  final MemberPassbook? passbook;

  @override
  State<MemberReportScreen> createState() => _MemberReportScreenState();
}

class _MemberReportScreenState extends State<MemberReportScreen> {
  List<Map<String, dynamic>> _entries = const [];
  bool _loading = true;
  String? _error;

  /// Totals from the server. Null means they were added up on this phone.
  MemberPassbook? _passbook;

  bool _downloading = false;

  Future<void> _downloadPdf() async {
    final book = _passbook;
    if (book == null) return;
    setState(() => _downloading = true);
    try {
      await sharePassbookPdf(book);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Could not create the PDF. Try again.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _passbook = widget.passbook;
    if (widget.entries != null) {
      _entries = widget.entries!;
      _loading = false;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  // Same aggregation as the passbook: the backend scopes the group ledger
  // to the signed-in member, so summing by type gives their position.
  Future<void> _load() async {
    final connection = context.read<ConnectionProvider>();
    final group = connection.selectedGroup;
    if (!connection.hasSession || group == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      // Prefer the server's totals so this report agrees with the passbook.
      final passbook = await connection.api.myPassbook();
      final entries = passbook != null
          ? passbook.recentEntries
          : await connection.api.ledger(group.id);
      if (mounted) {
        setState(() {
          _passbook = passbook;
          _entries = entries;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load your records.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _sum(String type) => _entries
      .where((e) => e['type'] == type)
      .fold(0.0, (s, e) => s + ((e['amountCents'] as num?) ?? 0) / 100);

  /// The member's position. Server figures when we have them, otherwise the
  /// sums from this phone. Computed in one place so what is shown on screen
  /// and what gets shared can never drift apart.
  _Figures get _figures {
    final book = _passbook;
    final shares = book?.shares ?? _sum('SHARE_PURCHASE');
    final social = book?.social ?? _sum('SOCIAL_CONTRIBUTION');
    final fines = book?.fines ?? _sum('FINE_COLLECTION');
    final repaid = book?.loansRepaid ?? _sum('LOAN_REPAYMENT');
    final borrowed = book?.loansReceived ?? _sum('INTERNAL_LOAN_DISBURSEMENT');
    return _Figures(
      shares: shares,
      social: social,
      fines: fines,
      repaid: repaid,
      borrowed: borrowed,
      totalPaidIn: book?.totalPaidIn ?? (shares + social + fines),
      owing: book?.loanOutstanding ??
          (borrowed - repaid).clamp(0, double.infinity).toDouble(),
      fromServer: book != null,
    );
  }

  static const _typeLabels = {
    'SHARE_PURCHASE': 'Shares',
    'SOCIAL_CONTRIBUTION': 'Social fund',
    'FINE_COLLECTION': 'Fine',
    'LOAN_REPAYMENT': 'Loan repayment',
    'INTERNAL_LOAN_DISBURSEMENT': 'Loan received',
  };

  String _buildReportText(String memberName, String groupName) {
    final f = _figures;
    final shares = f.shares;
    final social = f.social;
    final fines = f.fines;
    final repaid = f.repaid;
    final borrowed = f.borrowed;
    final owing = f.owing;

    final lines = <String>[
      'MY REPORT — $memberName',
      groupName,
      Formatters.fullDate(DateTime.now()),
      '',
      'MY SAVINGS',
      reportLine('Shares bought', Formatters.money(shares)),
      reportLine('Social fund', Formatters.money(social)),
      reportLine('Fines paid', Formatters.money(fines)),
      reportLine('Total paid in', Formatters.money(f.totalPaidIn)),
      '',
      'MY LOANS',
      reportLine('Loans received', Formatters.money(borrowed)),
      reportLine('Repaid', Formatters.money(repaid)),
      reportLine('Still owing', Formatters.money(owing)),
      '',
      f.fromServer
          ? 'Figures confirmed by the IntelliCash server.'
          : 'Figures from this phone only - records saved elsewhere may not be '
              'included yet.',
    ];

    final recent = _entries.take(10).toList();
    if (recent.isNotEmpty) {
      lines
        ..add('')
        ..add('RECENT TRANSACTIONS');
      for (final e in recent) {
        final type = '${e['type'] ?? ''}';
        final amount = ((e['amountCents'] as num?) ?? 0) / 100;
        final date = DateTime.tryParse('${e['createdAt']}')?.toLocal();
        final when = date != null ? '${Formatters.shortDate(date)} — ' : '';
        lines.add('$when${_typeLabels[type] ?? type.replaceAll('_', ' ')}: '
            '${Formatters.money(amount)}');
      }
    }
    lines
      ..add('')
      ..add('Shared from IntelliCash');
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final user = connection.signedInUser;
    final group = connection.selectedGroup;

    if (!connection.hasSession || group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Report')),
        body: const EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Not signed in',
          message: 'Sign in to your account to see and share your report.',
        ),
      );
    }

    final f = _figures;
    final shares = f.shares;
    final social = f.social;
    final fines = f.fines;
    final repaid = f.repaid;
    final borrowed = f.borrowed;
    final owing = f.owing;

    final memberName = user?.name ?? 'Member';

    return Scaffold(
      appBar: AppBar(title: const Text('My Report')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.error_outline,
                  title: 'Couldn\'t load',
                  message: _error!,
                )
              : RefreshIndicator(
                  onRefresh: _load,
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
                              MemberAvatar(memberName, radius: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(memberName,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                      '${group.name} · '
                                      '${Formatters.shortDate(DateTime.now())}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SectionLabel('My savings'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 12),
                          child: Column(
                            children: [
                              KeyValueRow(
                                  'Shares bought', Formatters.money(shares)),
                              KeyValueRow(
                                  'Social fund', Formatters.money(social)),
                              if (fines > 0)
                                KeyValueRow(
                                    'Fines paid', Formatters.money(fines)),
                              const Divider(height: 16),
                              KeyValueRow('Total paid in',
                                  Formatters.money(shares + social + fines),
                                  emphasize: true),
                            ],
                          ),
                        ),
                      ),
                      const SectionLabel('My loans'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 12),
                          child: Column(
                            children: [
                              KeyValueRow('Loans received',
                                  Formatters.money(borrowed)),
                              KeyValueRow('Repaid', Formatters.money(repaid)),
                              const Divider(height: 16),
                              KeyValueRow(
                                  'Still owing', Formatters.money(owing),
                                  emphasize: true),
                            ],
                          ),
                        ),
                      ),
                      const SectionLabel('Recent transactions'),
                      if (_entries.isEmpty)
                        const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'No transactions yet',
                          message: 'Your savings and loan records will '
                              'appear here.',
                        ),
                      for (final e in _entries.take(10)) _ReportTxnRow(entry: e),
                    ],
                  ),
                ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => shareReport(
                          'My Report — $memberName',
                          _buildReportText(memberName, group.name),
                        ),
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Share'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        // Only offered when the server's figures are in hand —
                        // a member's downloadable statement should carry the
                        // group's own numbers, not this phone's arithmetic.
                        onPressed: _passbook == null || _downloading
                            ? null
                            : _downloadPdf,
                        icon: _downloading
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download_outlined, size: 18),
                        label: Text(_downloading ? 'Preparing...' : 'Download'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _ReportTxnRow extends StatelessWidget {
  const _ReportTxnRow({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final type = '${entry['type'] ?? ''}';
    final amount = ((entry['amountCents'] as num?) ?? 0) / 100;
    final isDebit = entry['direction'] == 'DEBIT';
    final date = DateTime.tryParse('${entry['createdAt']}')?.toLocal();
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        title: Text(
          _MemberReportScreenState._typeLabels[type] ??
              type.replaceAll('_', ' '),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          date != null ? Formatters.shortDate(date) : '',
          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: Text(
          '${isDebit ? '-' : '+'} ${Formatters.money(amount)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: isDebit ? AppColors.defaulted : AppColors.primary,
          ),
        ),
      ),
    );
  }
}


/// One member's position, however it was arrived at.
class _Figures {
  const _Figures({
    required this.shares,
    required this.social,
    required this.fines,
    required this.repaid,
    required this.borrowed,
    required this.totalPaidIn,
    required this.owing,
    required this.fromServer,
  });

  final double shares;
  final double social;
  final double fines;
  final double repaid;
  final double borrowed;
  final double totalPaidIn;
  final double owing;

  /// False when these were added up on the handset.
  final bool fromServer;
}

