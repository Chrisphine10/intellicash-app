import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/domain_exception.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/meeting.dart';
import '../../data/models/remote/remote_models.dart';
import '../../data/services/module_switches.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/member_provider.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/status_chip.dart';
import '../loans/disburse_loan_screen.dart';
import '../settings/welfare_screen.dart';
import '../store/external_loans_screen.dart';
import '../store/store_screen.dart';
import '../voting/polls_screen.dart';
import 'attendance_screen.dart';
import 'buy_shares_sheet.dart';
import 'online_payments_to_add.dart';
import 'record_fine_sheet.dart';
import 'repayment_sheet.dart';
import 'shares_ledger_screen.dart';
import 'social_fund_screen.dart';

/// The in-meeting hub: every money movement happens here, and closing the
/// meeting seals its records into the audit trail.
class MeetingHubScreen extends StatefulWidget {
  const MeetingHubScreen({super.key, required this.meeting});

  final Meeting meeting;

  @override
  State<MeetingHubScreen> createState() => _MeetingHubScreenState();
}

class _MeetingHubScreenState extends State<MeetingHubScreen> {
  /// The server group this book is linked to; null while unknown or unlinked,
  /// which keeps the switchable modules hidden.
  String? _remoteGroupId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final group = context.read<AppState>().group;
      if (group != null) {
        context.read<MemberProvider>().load(group.id);
        final lookup = context.read<ModuleSwitches>().remoteIdFor;
        final remote = lookup == null ? null : await lookup(group.id);
        if (mounted && remote != _remoteGroupId) setState(() => _remoteGroupId = remote);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final provider = context.watch<MeetingProvider>();
    final meeting = provider.activeMeeting ?? widget.meeting;
    final totals = provider.totals;
    final isOpen = meeting.isOpen;
    // Intelli-Store and Voting are switched on per programme by an IWL admin.
    final GroupModules modules =
        context.watch<ModuleSwitches>().forRemoteGroup(_remoteGroupId);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMeetings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          // Wraps the status under the title on a narrow phone or with
          // large text, instead of running off the right edge.
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Meeting #${meeting.number}',
                  style: Theme.of(context).textTheme.headlineSmall),
              StatusChip.meeting(meeting.status),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${Formatters.fullDate(meeting.date)} · '
            'Opening ${Formatters.moneyCompact(meeting.openingBalance)} · '
            '${totals.presentCount} present',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (isOpen && _remoteGroupId != null)
            OnlinePaymentsToAdd(remoteGroupId: _remoteGroupId!),
          const SectionLabel('Record'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: [
              _ActionTile(
                icon: Icons.favorite_outline,
                label: l10n.meetingHubSocialFund,
                enabled: true,
                onTap: () async {
                  final meetingProvider = context.read<MeetingProvider>();
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SocialFundScreen(meeting: meeting),
                    ),
                  );
                  await meetingProvider.refreshTotals();
                },
              ),
              _ActionTile(
                icon: Icons.savings_outlined,
                label: l10n.meetingHubBuyShares,
                enabled: isOpen,
                onTap: () => _openSheet(const BuySharesSheet()),
              ),
              _ActionTile(
                icon: Icons.error_outline,
                label: l10n.meetingHubRecordFine,
                enabled: isOpen,
                onTap: () => _openSheet(const RecordFineSheet()),
              ),
              _ActionTile(
                icon: Icons.payments_outlined,
                label: l10n.meetingHubDisburseLoan,
                enabled: isOpen,
                onTap: () async {
                  final meetingProvider = context.read<MeetingProvider>();
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          DisburseLoanScreen(meetingId: meeting.id),
                    ),
                  );
                  await meetingProvider.refreshTotals();
                },
              ),
              _ActionTile(
                icon: Icons.check_circle_outline,
                label: l10n.meetingHubRepayment,
                enabled: isOpen,
                onTap: () => _openSheet(const RepaymentSheet()),
              ),
              _ActionTile(
                icon: Icons.receipt_long_outlined,
                label: l10n.meetingHubShareRecords,
                enabled: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SharesLedgerScreen(meeting: meeting),
                    ),
                  );
                },
              ),
              // Elections and decisions are taken here, in front of everyone —
              // when the group's programme has voting switched on.
              if (modules.voting)
                _ActionTile(
                  icon: Icons.how_to_vote_outlined,
                  label: l10n.meetingHubVoting,
                  enabled: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PollsScreen()),
                    );
                  },
                ),
              /*
               * Welfare sits beside Voting because it is decided the same way:
               * the group agrees a payout in the meeting, in front of everyone.
               * It used to live in the settings list, which is where a
               * treasurer goes to configure things, not to record what the
               * group just decided.
               */
              _ActionTile(
                icon: Icons.volunteer_activism_outlined,
                label: l10n.meetingHubWelfare,
                enabled: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WelfareScreen()),
                  );
                },
              ),
            ],
          ),
          if (isOpen) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AttendanceScreen(meeting: meeting),
                  ),
                );
              },
              icon: const Icon(Icons.how_to_reg_outlined, size: 18),
              label: Text(l10n.meetingHubEditAttendance),
            ),
          ],
          // Shopping and outside finance are raised and agreed here, in the
          // meeting, in front of everyone — so the group decides together.
          SectionLabel(l10n.meetingHubShopAndFinance),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: [
              // The one way into the store, and only when the group's
              // programme has Intelli-Store switched on.
              if (modules.store)
                _ActionTile(
                  icon: Icons.storefront_outlined,
                  label: l10n.intelliStores,
                  enabled: true,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StoreScreen()),
                    );
                  },
                ),
              _ActionTile(
                icon: Icons.account_balance_outlined,
                label: l10n.meetingHubExternalLoans,
                enabled: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const ExternalLoansScreen()),
                  );
                },
              ),
            ],
          ),
          const SectionLabel('This meeting'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              child: Column(
                children: [
                  KeyValueRow('Social fund', Formatters.money(totals.socialFund)),
                  KeyValueRow('Shares collected',
                      Formatters.money(totals.sharesAmount)),
                  KeyValueRow('Fines', Formatters.money(totals.fines)),
                  KeyValueRow('Loan repayments',
                      Formatters.money(totals.loanRepayments)),
                  KeyValueRow('Loans disbursed',
                      '- ${Formatters.money(totals.loanDisbursements)}'),
                  const Divider(height: 16),
                  KeyValueRow('Total in', Formatters.money(totals.totalIn),
                      emphasize: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (isOpen) ...[
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.defaulted,
                side: BorderSide(
                    color: AppColors.defaulted.withValues(alpha: 0.4)),
              ),
              onPressed: _confirmClose,
              icon: const Icon(Icons.lock_outline, size: 18),
              label: Text(l10n.meetingHubCloseLockMeeting),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.meetingHubClosingLocksAllRecordsPermanently,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ] else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline,
                        size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.meetingHubThisMeetingIsClosedItsRecords,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openSheet(Widget sheet) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => sheet,
    );
  }

  Future<void> _confirmClose() async {
    final l10n = L10n.of(context);
    final appState = context.read<AppState>();
    final provider = context.read<MeetingProvider>();
    final meeting = provider.activeMeeting ?? widget.meeting;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Close Meeting #${meeting.number}?',
            style: const TextStyle(fontSize: 17)),
        content: Text(
          l10n.meetingHubAllRecordsInThisMeetingWill,
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.meetingHubKeepOpen),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.defaulted,
              foregroundColor: const Color(0xFF3A0D09),
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.meetingHubCloseLock),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await provider.closeMeeting(meeting.groupId);
      await appState.refreshPendingSync();
      // Send it now, while there is signal, rather than waiting for the next
      // reconnect or the ten-minute timer. Safe to fire and forget: it does
      // nothing offline or when the group is not linked, and a failure leaves
      // the meeting on the "pending" badge to be retried.
      unawaited(appState.syncNow());
      if (!mounted) return;
      showAppSnack(context, 'Meeting #${meeting.number} closed and locked.');
      Navigator.of(context).pop();
    } on DomainException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    }
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            children: [
              Icon(icon,
                  size: 19,
                  color: enabled ? AppColors.primary : AppColors.textSecondary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
