import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/remote/member_passbook.dart';
import '../../data/models/remote/membership.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';
import '../more/language_screen.dart';
import 'join_group_screen.dart';
import '../reports/member_report_screen.dart';
import '../reports/my_savings_screen.dart';

/// A member's personal passbook: their own savings, shares, social fund,
/// fines and loans, aggregated from the ledger the backend scopes to them.
class MemberPassbookScreen extends StatefulWidget {
  const MemberPassbookScreen({super.key});

  @override
  State<MemberPassbookScreen> createState() => _MemberPassbookScreenState();
}

class _MemberPassbookScreenState extends State<MemberPassbookScreen> {
  List<Map<String, dynamic>> _entries = const [];
  bool _loading = true;
  String? _error;

  /// Totals computed by the server. Null means we fell back to adding up the
  /// ledger on the phone (older server, or a login that isn't a member).
  MemberPassbook? _passbook;

  /// Every group this person saves with. More than one is normal.
  List<Membership> _memberships = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final connection = context.read<ConnectionProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _memberships = await connection.api.memberships();
      final group = connection.selectedGroup;
      // Not in any group yet is a starting point, not a failure — the empty
      // state offers the way in.
      if (group == null) {
        if (mounted) {
          setState(() {
            _passbook = null;
            _entries = const [];
          });
        }
        return;
      }
      // The server totals a member's own passbook; fall back to summing the
      // ledger here if that endpoint isn't available.
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

  Future<void> _switchGroup(Membership membership) async {
    if (membership.isActive) return;
    final connection = context.read<ConnectionProvider>();
    setState(() => _loading = true);
    try {
      await connection.api.setActiveMembership(membership.groupId);
      // The provider still holds the roster, meetings and balances of the
      // group we just left, so refresh before reading the passbook again.
      await connection.refreshAll();
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openJoinGroup() async {
    final joined = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const JoinGroupScreen()),
    );
    // Approval is not instant, but a fresh look costs nothing and picks it up
    // if an official was quick.
    if (joined == true && mounted) await _load();
  }

  Future<void> _signOut() async {
    final l10n = L10n.of(context);
    final connection = context.read<ConnectionProvider>();
    final navigator = Navigator.of(context);
    // Confirm first — a mis-tap on a toolbar icon shouldn't end the session.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.signOut, style: const TextStyle(fontSize: 17)),
        // A member has no group record book on this phone — telling them their
        // group's meetings "stay saved here" describes someone else's app.
        content: Text(l10n.signOutMemberNote,
            style: const TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await connection.disconnect();
    // Back to "who is signing in?" — a shared phone often changes hands here.
    // The root renders that itself once the account is cleared.
    navigator.popUntil((route) => route.isFirst);
  }

  double _sum(String type) => _entries
      .where((e) => e['type'] == type)
      .fold(0.0, (s, e) => s + ((e['amountCents'] as num?) ?? 0) / 100);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final connection = context.watch<ConnectionProvider>();
    final user = connection.signedInUser;
    final group = connection.selectedGroup;

    // Server figures when we have them, otherwise the on-phone sums.
    final book = _passbook;
    final shares = book?.shares ?? _sum('SHARE_PURCHASE');
    final social = book?.social ?? _sum('SOCIAL_CONTRIBUTION');
    final fines = book?.fines ?? _sum('FINE_COLLECTION');
    final repaid = book?.loansRepaid ?? _sum('LOAN_REPAYMENT');
    final borrowed =
        book?.loansReceived ?? _sum('INTERNAL_LOAN_DISBURSEMENT');
    final totalPaidIn = book?.totalPaidIn ?? (shares + social + fines);
    final owing = book?.loanOutstanding ??
        ((borrowed - repaid) < 0 ? 0.0 : borrowed - repaid);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.memberPassbookMyPassbook),
        actions: [
          IconButton(
            icon: const Icon(Icons.translate, size: 20),
            tooltip: l10n.sectionLanguage,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LanguageScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined, size: 20),
            tooltip: l10n.memberPassbookMyReport,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MemberReportScreen(
                    // Hand over what this screen already has so the report
                    // opens instantly AND shows the same figures; let it
                    // fetch for itself otherwise.
                    entries:
                        !_loading && _error == null ? _entries : null,
                    passbook: !_loading && _error == null ? _passbook : null,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.savings_outlined, size: 20),
            tooltip: l10n.memberPassbookMySavingsAcrossAllGroups,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MySavingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_add_outlined, size: 20),
            tooltip: l10n.memberPassbookJoinAnotherGroup,
            onPressed: _openJoinGroup,
          ),
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            tooltip: l10n.signOut,
            onPressed: _signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
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
                    MemberAvatar(user?.name ?? 'Member', radius: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.name ?? 'Member',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          Text(
                            group?.name ?? 'Your group',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Every group this person saves with, always listed. This used to
            // be a popup menu that hid itself below two groups, so a member
            // could not see which groups they belong to at all — and with two
            // or more, the list was behind a tap most people never made.
            if (_memberships.isNotEmpty) ...[
              SectionLabel(
                _memberships.length == 1
                    ? 'My group'
                    : 'My groups (${_memberships.length})',
              ),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < _memberships.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                      _MembershipRow(
                        membership: _memberships[i],
                        onTap: () => _switchGroup(_memberships[i]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.error_outline,
                  title: 'Couldn\'t load',
                  message: _error!,
                ),
              )
            else if (group == null) ...[
              Padding(
                padding: EdgeInsets.only(top: 32),
                child: EmptyState(
                  icon: Icons.groups_outlined,
                  title: l10n.memberPassbookYouAreNotInA,
                  message:
                      l10n.memberPassbookAskYourGroupToAddYou,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _openJoinGroup,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.memberPassbookJoinAGroup),
              ),
            ] else ...[
              const SectionLabel('My savings'),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  child: Column(
                    children: [
                      KeyValueRow('Shares bought', Formatters.money(shares)),
                      KeyValueRow('Social fund', Formatters.money(social)),
                      if (fines > 0)
                        KeyValueRow('Fines paid', Formatters.money(fines)),
                      const Divider(height: 16),
                      KeyValueRow('Total paid in',
                          Formatters.money(totalPaidIn),
                          emphasize: true),
                    ],
                  ),
                ),
              ),
              const SectionLabel('My loans'),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                  child: Column(
                    children: [
                      KeyValueRow('Loans received', Formatters.money(borrowed)),
                      KeyValueRow('Repaid', Formatters.money(repaid)),
                      const Divider(height: 16),
                      KeyValueRow(
                        'Still owing',
                        Formatters.money(owing),
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SectionLabel('Recent transactions'),
              if (_entries.isEmpty)
                EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: l10n.memberPassbookNoTransactionsYet,
                  message: l10n.memberPassbookYourSavingsAndLoanRecords,
                ),
              for (final e in _entries.take(30)) _TxnRow(entry: e),
            ],
          ],
        ),
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  const _TxnRow({required this.entry});
  final Map<String, dynamic> entry;

  static const _labels = {
    'SHARE_PURCHASE': 'Shares',
    'SOCIAL_CONTRIBUTION': 'Social fund',
    'FINE_COLLECTION': 'Fine',
    'LOAN_REPAYMENT': 'Loan repayment',
    'INTERNAL_LOAN_DISBURSEMENT': 'Loan received',
  };

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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        title: Text(_labels[type] ?? type.replaceAll('_', ' '),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

/// One group in the member's list of groups.
///
/// Tapping a row makes that group the active one; everything the API returns
/// — passbook totals, ledger, meetings — is scoped to it, so this is how a
/// member reads their record in each group they belong to.
class _MembershipRow extends StatelessWidget {
  const _MembershipRow({required this.membership, required this.onTap});

  final Membership membership;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = membership.isActive;
    return ListTile(
      onTap: active ? null : onTap,
      leading: Icon(
        active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 20,
        color: active ? AppColors.primary : AppColors.textSecondary,
      ),
      title: Text(
        membership.groupName.isEmpty ? 'Group' : membership.groupName,
        style: TextStyle(
          fontSize: 14,
          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        active
            ? 'Showing this group below'
            : 'Tap to see your savings here',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: active
          ? null
          : Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
    );
  }
}
