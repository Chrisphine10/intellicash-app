import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/group.dart';
import '../../data/models/remote/group_report.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/loan_repository.dart';
import '../../data/repositories/meeting_repository.dart';
import '../../data/repositories/member_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';
import 'pdf_report.dart';
import 'report_share.dart';

/// A simple, shareable summary of the whole group: its money, its members
/// and its meetings. Reads only the local database, so it works offline —
/// officials can share it in WhatsApp straight from the field.
class GroupReportScreen extends StatefulWidget {
  const GroupReportScreen({super.key});

  @override
  State<GroupReportScreen> createState() => _GroupReportScreenState();
}

class _GroupReportScreenState extends State<GroupReportScreen> {
  // Reports read straight from the local database — same pattern as the
  // 3-key unlock screen.
  final _memberRepository = MemberRepository(AppDatabase.instance);
  final _dashboardRepository = DashboardRepository(AppDatabase.instance);
  final _meetingRepository = MeetingRepository(AppDatabase.instance);
  final _loanRepository = LoanRepository(AppDatabase.instance);

  bool _loading = true;

  // Money
  double _totalSavings = 0;
  double _socialFund = 0;
  double _fines = 0;
  double _loansGivenOut = 0;
  double _loansRepaid = 0;
  double _loansStillOwed = 0;
  double _cashBox = 0;

  // People & meetings
  List<ReportMemberRow> _members = const [];
  int _meetingsThisCycle = 0;

  /// When the server produced these figures. Null means they were added up on
  /// this phone, which a group reading the report aloud needs to know: work
  /// recorded on other phones may not be in them yet.
  DateTime? _serverGeneratedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final group = context.read<AppState>().group;
    if (group == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);

    // The server is the authority when it can be reached: it sees every
    // phone's work, not just this one's.
    final connection = context.read<ConnectionProvider>();
    final remoteGroup = connection.selectedGroup;
    final report = remoteGroup != null
        ? await connection.api.groupReport(remoteGroup.id)
        : null;
    if (report != null) {
      if (!mounted) return;
      // Money in the box is counted on this phone, so it stays local either
      // way; everything else comes from the report as one consistent set.
      final cashBoxFromPhone =
          await _meetingRepository.cashBoxBalance(group.id);
      if (!mounted) return;
      setState(() {
        _totalSavings = report.totalSavings;
        _socialFund = report.socialFund;
        _fines = report.fines;
        _loansGivenOut = report.loansGivenOut;
        _loansRepaid = report.loansRepaid;
        _loansStillOwed = report.loansStillOwed;
        _cashBox = cashBoxFromPhone;
        _members = report.members;
        _meetingsThisCycle = report.meetingCount;
        _serverGeneratedAt = report.generatedAt;
        _loading = false;
      });
      return;
    }

    final summary = await _dashboardRepository.summary(group.id);
    final members = await _memberRepository.financialsForGroup(group.id);
    final cashBox = await _meetingRepository.cashBoxBalance(group.id);
    final loans = await _loanRepository.loansForGroup(group.id);
    final meetings = await _meetingRepository.meetingsForGroup(group.id);

    double givenOut = 0, repaid = 0, stillOwed = 0;
    for (final loan in loans) {
      givenOut += loan.principal;
      repaid += loan.amountRepaid;
      stillOwed += loan.outstanding;
    }

    final meetingsThisCycle = meetings
        .where((m) => !m.meeting.date.isBefore(group.cycleStartDate))
        .length;

    if (!mounted) return;
    setState(() {
      _totalSavings = summary.totalSavings;
      _socialFund = summary.socialFund;
      _fines = summary.finesCollected;
      _loansGivenOut = givenOut;
      _loansRepaid = repaid;
      _loansStillOwed = stillOwed;
      _cashBox = cashBox;
      _members = members.map(ReportMemberRow.fromLocal).toList();
      _meetingsThisCycle = meetingsThisCycle;
      _serverGeneratedAt = null;
      _loading = false;
    });
  }

  String _buildReportText(Group group) {
    final l10n = L10n.of(context);
    final lines = <String>[
      'GROUP REPORT — ${group.name}',
      Formatters.fullDate(DateTime.now()),
      'Cycle ${group.cycleNumber} · started '
          '${Formatters.shortDate(group.cycleStartDate)}',
      reportLine('Group rules',
          '${Formatters.moneyCompact(group.shareValue)} per share, '
          'meets ${group.meetingFrequency.label.toLowerCase()} '
          'on ${group.meetingDaysLabel}'),
      '',
      'MONEY',
      reportLine('Total savings', Formatters.money(_totalSavings)),
      reportLine('Social fund', Formatters.money(_socialFund)),
      reportLine('Fines collected', Formatters.money(_fines)),
      reportLine('Loans given out', Formatters.money(_loansGivenOut)),
      reportLine('Loans repaid', Formatters.money(_loansRepaid)),
      reportLine('Loans still owed', Formatters.money(_loansStillOwed)),
      reportLine('Money in the box', Formatters.money(_cashBox)),
      '',
      'MEMBERS (${_members.length})',
    ];
    if (_members.isEmpty) {
      lines.add('No members yet.');
    }
    for (final m in _members) {
      final owes = m.owes > 0 ? ', owes ${Formatters.money(m.owes)}' : '';
      lines.add('${m.name} - saved ${Formatters.money(m.savings)}$owes');
    }
    lines
      ..add('')
      ..add(reportLine('Meetings held this cycle', '$_meetingsThisCycle'))
      ..add('')
      ..add(_serverGeneratedAt != null
          ? 'Figures confirmed by the IntelliCash server.'
          : l10n.groupReportFiguresFromThisPhoneOnlyWork)
      ..add('Shared from IntelliCash');
    return lines.join('\n');
  }

  Future<void> _share(Group group) async {
    await shareReport('Group Report — ${group.name}', _buildReportText(group));
  }

  bool _sharingPdf = false;

  Future<void> _sharePdf(Group group) async {
    setState(() => _sharingPdf = true);
    try {
      await shareGroupPdf(
        group: group,
        totalSavings: _totalSavings,
        socialFund: _socialFund,
        fines: _fines,
        loansGivenOut: _loansGivenOut,
        loansRepaid: _loansRepaid,
        loansStillOwed: _loansStillOwed,
        cashBox: _cashBox,
        members: _members,
        meetingsThisCycle: _meetingsThisCycle,
      );
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Could not create the PDF. Try again.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _sharingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final group = context.watch<AppState>().group;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupReport)),
      body: group == null
          ? EmptyState(
              icon: Icons.groups_outlined,
              title: l10n.groupReportNoGroupYet,
              message: l10n.groupReportSetUpYourGroupFirst,
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      _GroupHeaderCard(group: group),
                      _FiguresSource(generatedAt: _serverGeneratedAt),
                      const SectionLabel('Money'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 12),
                          child: Column(
                            children: [
                              KeyValueRow('Total savings',
                                  Formatters.money(_totalSavings)),
                              KeyValueRow(
                                  'Social fund', Formatters.money(_socialFund)),
                              KeyValueRow(
                                  'Fines collected', Formatters.money(_fines)),
                              KeyValueRow('Loans given out',
                                  Formatters.money(_loansGivenOut)),
                              KeyValueRow('Loans repaid',
                                  Formatters.money(_loansRepaid)),
                              KeyValueRow('Loans still owed',
                                  Formatters.money(_loansStillOwed)),
                              const Divider(height: 16),
                              KeyValueRow('Money in the box',
                                  Formatters.money(_cashBox),
                                  emphasize: true),
                            ],
                          ),
                        ),
                      ),
                      SectionLabel('Members (${_members.length})'),
                      if (_members.isEmpty)
                        EmptyState(
                          icon: Icons.person_outline,
                          title: l10n.groupReportNoMembersYet,
                          message:
                              l10n.groupReportMembersAppearHereOnceThey,
                        )
                      else
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 15, vertical: 8),
                            child: Column(
                              children: [
                                for (final m in _members) _MemberLine(m: m),
                              ],
                            ),
                          ),
                        ),
                      const SectionLabel('Meetings'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 15, vertical: 12),
                          child: KeyValueRow('Meetings held this cycle',
                              '$_meetingsThisCycle'),
                        ),
                      ),
                    ],
                  ),
                ),
      bottomNavigationBar: group == null || _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _share(group),
                        icon: const Icon(Icons.share, size: 18),
                        label: Text(l10n.shareTextButton),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            _sharingPdf ? null : () => _sharePdf(group),
                        icon: const Icon(Icons.picture_as_pdf_outlined,
                            size: 18),
                        label:
                            Text(_sharingPdf ? 'Creating…' : 'Save PDF'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _GroupHeaderCard extends StatelessWidget {
  const _GroupHeaderCard({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surfaceRaised,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.description_outlined,
                color: AppColors.primary, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  Text(
                    'Cycle ${group.cycleNumber} · '
                    '${Formatters.moneyCompact(group.shareValue)} per share · '
                    'meets ${group.meetingFrequency.label.toLowerCase()} '
                    'on ${group.meetingDaysLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Says where the numbers came from.
///
/// A group reads this report aloud and makes decisions on it, so it must be
/// obvious whether the figures are the server's — which sees every phone's
/// work — or only what this handset happens to hold.
class _FiguresSource extends StatelessWidget {
  const _FiguresSource({required this.generatedAt});

  final DateTime? generatedAt;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final confirmed = generatedAt != null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            confirmed ? Icons.cloud_done_outlined : Icons.phone_android,
            size: 15,
            color: confirmed ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              confirmed
                  ? 'Confirmed by the server on '
                      '${Formatters.shortDate(generatedAt!.toLocal())}'
                  : l10n.groupReportFromThisPhoneOnlyWorkSaved,
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberLine extends StatelessWidget {
  const _MemberLine({required this.m});

  final ReportMemberRow m;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
                if (m.owes > 0)
                  Text(
                    'Owes ${Formatters.money(m.owes)}',
                    style: TextStyle(fontSize: 11, color: AppColors.pending),
                  ),
              ],
            ),
          ),
          Text(
            Formatters.money(m.savings),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
