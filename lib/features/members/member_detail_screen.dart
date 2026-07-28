import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/database/app_database.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/app_settings.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/loan.dart';
import '../../data/repositories/id_map_repository.dart';
import '../../providers/connection_provider.dart';
import '../../providers/loan_provider.dart';
import '../../providers/member_provider.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/status_chip.dart';
import '../loans/loan_detail_screen.dart';
import '../reports/member_report_local_screen.dart';

/// One member's profile: savings position, attendance rate and loan history.
class MemberDetailScreen extends StatefulWidget {
  const MemberDetailScreen({super.key, required this.memberId});

  final String memberId;

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  List<Loan> _loans = const [];
  double _attendanceRate = 0;
  bool _memberAccountsEnabled = false;
  String? _remoteGroupId;
  String? _remoteMemberId;
  bool _creatingAccount = false;

  final _idMap = IdMapRepository(AppDatabase.instance);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loans =
        await context.read<LoanProvider>().loansForMember(widget.memberId);
    if (!mounted) return;
    final rate =
        await context.read<MemberProvider>().attendanceRate(widget.memberId);
    final accountsEnabled = await AppSettings.memberAccountsEnabled();
    final remoteMemberId =
        await _idMap.remoteId(MapEntity.member, widget.memberId);
    String? remoteGroupId;
    if (mounted) {
      final groupId = context
          .read<MemberProvider>()
          .members
          .where((f) => f.member.id == widget.memberId)
          .firstOrNull
          ?.member
          .groupId;
      if (groupId != null) {
        remoteGroupId = await _idMap.remoteId(MapEntity.group, groupId);
      }
    }
    if (mounted) {
      setState(() {
        _loans = loans;
        _attendanceRate = rate;
        _memberAccountsEnabled = accountsEnabled;
        _remoteMemberId = remoteMemberId;
        _remoteGroupId = remoteGroupId;
      });
    }
  }

  Future<void> _createAccount(String memberName) async {
    final connection = context.read<ConnectionProvider>();
    final password = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AccountPasswordSheet(memberName: memberName),
    );
    if (password == null || !mounted) return;
    setState(() => _creatingAccount = true);
    try {
      await connection.api.createMemberAccount(
        _remoteGroupId!,
        _remoteMemberId!,
        password: password,
      );
      if (mounted) {
        showAppSnack(context,
            '$memberName can now sign in with their phone number.');
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _creatingAccount = false);
    }
  }

  bool get _canCreateAccount =>
      context.read<ConnectionProvider>().isConnected &&
      _remoteGroupId != null &&
      _remoteMemberId != null;

  @override
  Widget build(BuildContext context) {
    final financials = context
        .watch<MemberProvider>()
        .members
        .where((f) => f.member.id == widget.memberId)
        .firstOrNull;
    final member = financials?.member;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        actions: [
          if (member != null)
            IconButton(
              tooltip: 'Member report',
              icon: const Icon(Icons.description_outlined, size: 22),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        MemberReportLocalScreen(memberId: member.id),
                  ),
                );
              },
            ),
        ],
      ),
      body: member == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Row(
                  children: [
                    MemberAvatar(member.name, radius: 26),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.name,
                              style:
                                  Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 2),
                          Text(
                            '${member.role.label}'
                            '${member.phone != null ? ' · ${member.phone}' : ''}'
                            ' · Joined ${Formatters.shortDate(member.joinedAt)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SectionLabel('Position'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 12),
                    child: Column(
                      children: [
                        KeyValueRow(
                          'Total savings',
                          Formatters.money(financials!.totalSavings),
                          emphasize: true,
                        ),
                        KeyValueRow(
                            'Shares held', '${financials.totalShares}'),
                        KeyValueRow('Active loan balance',
                            Formatters.money(financials.activeLoanBalance)),
                        KeyValueRow(
                          'Attendance rate',
                          '${(_attendanceRate * 100).round()}%',
                        ),
                      ],
                    ),
                  ),
                ),
                if (_memberAccountsEnabled) ...[
                  const SectionLabel('Sign-in account'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _canCreateAccount
                                ? 'Give ${member.name} their own sign-in so '
                                    'they can see their savings and loans on '
                                    'their own phone.'
                                : 'To create a sign-in account, first back '
                                    'this group up to the cloud (More → Sync '
                                    '& Backup) while online.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _canCreateAccount && !_creatingAccount
                                ? () => _createAccount(member.name)
                                : null,
                            icon: const Icon(Icons.person_add_alt, size: 18),
                            label: Text(_creatingAccount
                                ? 'Creating…'
                                : 'Create Sign-In Account'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SectionLabel('Loan history'),
                if (_loans.isEmpty)
                  const EmptyState(
                    icon: Icons.payments_outlined,
                    title: 'No loans taken',
                    message:
                        'Loans this member takes will be listed here with '
                        'their live status.',
                  ),
                for (final loan in _loans)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 2),
                      title: Text(
                        Formatters.money(loan.principal),
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      subtitle: Text(
                        'Disbursed ${Formatters.shortDate(loan.disbursedAt)} · '
                        'Outstanding ${Formatters.moneyCompact(loan.outstanding)}',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      trailing: StatusChip.loan(loan.status),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                LoanDetailScreen(loanId: loan.id),
                          ),
                        );
                        await _load();
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Asks the group official to choose a starting password for the member's
/// sign-in account. The member signs in with their phone number + this
/// password, and can change it later.
class _AccountPasswordSheet extends StatefulWidget {
  const _AccountPasswordSheet({required this.memberName});

  final String memberName;

  @override
  State<_AccountPasswordSheet> createState() => _AccountPasswordSheetState();
}

class _AccountPasswordSheetState extends State<_AccountPasswordSheet> {
  final _passwordCtrl = TextEditingController();
  final _repeatCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _repeatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account for ${widget.memberName}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Choose a starting password. ${widget.memberName} signs in with '
            'their phone number and this password, and should change it '
            'after the first sign-in.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordCtrl,
            autofocus: true,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Starting password',
              helperText: 'At least 6 characters.',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _repeatCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Repeat password'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              final password = _passwordCtrl.text;
              if (password.length < 6) {
                setState(() => _error = 'Use at least 6 characters.');
                return;
              }
              if (_repeatCtrl.text != password) {
                setState(() => _error = 'Passwords don\'t match.');
                return;
              }
              Navigator.of(context).pop(password);
            },
            child: const Text('Create Account'),
          ),
        ],
      ),
    );
  }
}
