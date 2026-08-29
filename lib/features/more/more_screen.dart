import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_settings.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';
import '../../providers/theme_controller.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/status_chip.dart';
import '../account/account_route.dart';
import '../members/join_requests_screen.dart';
import '../onboarding/group_setup_wizard.dart';
import '../reports/group_report_screen.dart';
import '../reports/member_reports_screen.dart';
import '../shareout/share_out_screen.dart';
import 'meeting_security_screen.dart';
import '../settings/cycles_screen.dart';
import '../settings/group_policy_screen.dart';
import '../settings/payment_providers_screen.dart';
import '../server/server_settings_screen.dart';

/// Group settings, cloud sync and app info — configuration lives here so
/// it can't be touched by accident mid-meeting.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final appState = context.watch<AppState>();
    final group = appState.group;
    if (group == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navMore)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(group.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Cycle ${group.cycleNumber} · started '
                    '${Formatters.shortDate(group.cycleStartDate)}\n'
                    'Meets ${group.meetingFrequency.label.toLowerCase()} '
                    'on ${group.meetingDaysLabel}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          SectionLabel(l10n.sectionGroup),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.tune, size: 20),
                  title: Text(l10n.groupSettings,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    l10n.groupSettingsSubtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GroupSetupWizard(existing: group),
                      ),
                    );
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.key_outlined, size: 20),
                  title: Text(l10n.meetingSecurity,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    group.requireThreeKey
                        ? '3-key unlock is on · roles and PINs'
                        : '3-key unlock is off · roles and PINs',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MeetingSecurityScreen(),
                      ),
                    );
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                const _JoinRequestsTile(),
                const Divider(indent: 16, endIndent: 16),
                const _MemberAccountsToggle(),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.rule, size: 20),
                  title: Text(l10n.groupRules,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    'KSh ${group.shareValue.toStringAsFixed(0)} per share · '
                    'up to ${group.maxSharesPerMeeting} shares a meeting\n'
                    'KSh ${group.socialFundAmount.toStringAsFixed(0)} social fund · '
                    '${group.interestRate.toStringAsFixed(0)}% interest · '
                    'borrow up to ${group.loanMultiplier.toStringAsFixed(0)}× savings',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          SectionLabel(l10n.sectionReports),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.description_outlined, size: 20),
                  title: Text(l10n.groupReport,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    l10n.groupReportSubtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const GroupReportScreen()),
                    );
                  },
                ),
                const Divider(indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.people_outline, size: 20),
                  title: Text(l10n.memberReports,
                      style: const TextStyle(fontSize: 14)),
                  subtitle: Text(
                    l10n.memberReportsSubtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const MemberReportsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          SectionLabel(l10n.sectionEndOfCycle),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined,
                  size: 20),
              title: Text(l10n.shareOut,
                  style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                l10n.shareOutSubtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ShareOutScreen()),
                );
              },
            ),
          ),
          // Server connection + sync bundled together under one heading.
          SectionLabel(l10n.sectionCloudBackup),
          Card(
            child: Column(
              children: [
                _connectionTile(context),
                _paymentProvidersTile(context),
                _governanceTile(context, 'Group Rules', Icons.rule_outlined,
                    'Loan term and where expenses come from', const GroupPolicyScreen()),
                _governanceTile(context, 'Saving Cycles', Icons.event_repeat_outlined,
                    'Close a cycle and start the next', const CyclesScreen()),
                const Divider(indent: 16, endIndent: 16),
                _syncTile(context, appState),
                if (context.watch<ConnectionProvider>().isConnected) ...[
                  const Divider(indent: 16, endIndent: 16),
                  _signOutTile(context),
                ],
              ],
            ),
          ),
          /*
           * Your account: identity, language, appearance, server and version.
           * Appearance and Language used to be two more sections here, which
           * meant a group account and an agent changed the same setting in two
           * unrelated places. They live on Account now, which every role can
           * reach.
           */
          SectionLabel('Your account'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined, size: 22),
              title: Text(l10n.accountAccount, style: TextStyle(fontSize: 14)),
              subtitle: Text(
                l10n.moreWhoIsSignedInLanguage,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AccountRoute()),
              ),
            ),
          ),
          SectionLabel(l10n.sectionAbout),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset('assets/branding/logo_mark.png',
                          width: 22, height: 22),
                      const SizedBox(width: 8),
                      Text(l10n.moreIntelliCash,
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.moreYourGroupSSavingsAndLoans,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The cloud-connection row (friendly wording; opens connection settings).
  /// Signing out ends the CLOUD session only. The group's own records live in
  /// this phone's database and stay exactly where they are — saying so plainly
  /// matters, because a treasurer will otherwise fear losing the book.
  Widget _signOutTile(BuildContext context) {
    final l10n = L10n.of(context);
    final user = context.watch<ConnectionProvider>().signedInUser;
    return ListTile(
      leading: Icon(Icons.logout, size: 20, color: AppColors.defaulted),
      title: Text(l10n.signOut,
          style: TextStyle(fontSize: 14, color: AppColors.defaulted)),
      subtitle: Text(
        user != null ? l10n.signedInAs(user.name) : l10n.signOutKeepsRecords,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () => _confirmSignOut(context),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final l10n = L10n.of(context);
    final connection = context.read<ConnectionProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.signOut, style: const TextStyle(fontSize: 17)),
        content: Text(l10n.signOutKeepsRecords,
            style: const TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.defaulted,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await connection.disconnect();
    messenger.showSnackBar(SnackBar(content: Text(l10n.signedOut)));
    // Drop every screen and let the root decide what this phone shows now.
    // Pushing a login screen on top instead — which is what this did — left
    // the whole group app alive underneath, one back-press away: member
    // balances, group settings, meeting PINs, share-out.
    navigator.popUntil((route) => route.isFirst);
  }

  /// Where members' money is received. Only meaningful once the phone is
  /// connected and a group is chosen, so it stays hidden otherwise rather than
  /// Cloud-only settings.
  ///
  /// These used to be HIDDEN until a group was chosen, and that was a mistake:
  /// a feature that renders nothing is indistinguishable from a feature that
  /// was never built. Officials on the published build reported the welfare
  /// module as "missing" when it was there all along, waiting behind a cloud
  /// connection nobody was told about. Now the row is always visible and says
  /// what to do to use it.
  Widget _governanceTile(BuildContext context, String title, IconData icon,
      String subtitle, Widget screen) {
    final connection = context.watch<ConnectionProvider>();
    final ready = connection.isConnected && connection.selectedGroup != null;
    final muted = Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6);

    return ListTile(
      enabled: ready,
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        ready
            ? subtitle
            : connection.isConnected
                ? 'Choose your group under Cloud Account to use this'
                : 'Sign in under Cloud Account to use this',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ready ? null : muted,
            ),
      ),
      trailing: Icon(ready ? Icons.chevron_right : Icons.lock_outline, size: 20),
      onTap: ready
          ? () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => screen))
          : null,
    );
  }

  Widget _paymentProvidersTile(BuildContext context) {
    // Same reasoning as _governanceTile: visible but locked, never absent.
    return _governanceTile(
      context,
      'Payment Providers',
      Icons.account_balance_wallet_outlined,
      'Where money from members is received',
      const PaymentProvidersScreen(),
    );
  }

  Widget _connectionTile(BuildContext context) {
    final l10n = L10n.of(context);
    final connection = context.watch<ConnectionProvider>();
    final (String subtitle, Widget? trailing) = switch (connection.status) {
      ConnectionStatus.connected => (
          'Connected · ${connection.members.length} members',
          StatusChip.synced(),
        ),
      ConnectionStatus.error => (
          connection.error ?? 'Couldn\'t connect. Tap to try again.',
          StatusChip(
            label: 'offline',
            color: AppColors.defaulted,
            tint: AppColors.defaultedTint,
            icon: Icons.error_outline,
          ),
        ),
      ConnectionStatus.unconfigured => (
          'Connect this phone to your group online',
          null,
        ),
    };
    return ListTile(
      leading: const Icon(Icons.cloud_outlined, size: 20),
      title: Text(l10n.cloudAccount, style: TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
        );
      },
    );
  }

  /// The sync / backup row (friendly wording; pushes queued changes).
  Widget _syncTile(BuildContext context, AppState appState) {
    final l10n = L10n.of(context);
    return ListTile(
      leading: const Icon(Icons.cloud_upload_outlined, size: 20),
      title: Text(l10n.syncBackup, style: TextStyle(fontSize: 14)),
      subtitle: Text(
        appState.pendingSync == 0
            ? 'Everything is backed up'
            : '${appState.pendingSync} '
                '${appState.pendingSync == 1 ? 'meeting' : 'meetings'} '
                'waiting to back up',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: appState.pendingSync > 0
          ? StatusChip.pendingSync(appState.pendingSync)
          : StatusChip.synced(),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        final synced = await appState.syncNow();
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              synced > 0
                  ? 'Backed up $synced record(s).'
                  : appState.pendingSync == 0
                      ? 'Everything is already backed up.'
                      : l10n.moreNoInternetYourRecordsAreSafe,
            ),
            backgroundColor: AppColors.surfaceRaised,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }
}

/// Light / Dark / System picker for [ThemeController]. Applying a change
/// re-keys the app content (see [ThemeController]'s doc comment), so this
/// screen closes and the app returns to its root screen right after.
/// Optional: let this group create sign-in accounts for its members, so each
/// member can check their own savings on their own phone.
/// The permanent way in to requests to join.
///
/// There was one already - a badge on the Members app bar - but it appeared
/// only when the pending count was above zero AND the request for it had
/// succeeded. An official who wanted to go and look, or whose phone had briefly
/// lost signal when the roster loaded, had no route to the screen at all. A
/// group leader has to be able to find this on purpose, not stumble on it.
///
/// Group accounts only: answering is theirs to do, and the API refuses anyone
/// else with a 403 that would read like a bug.
class _JoinRequestsTile extends StatefulWidget {
  const _JoinRequestsTile();

  @override
  State<_JoinRequestsTile> createState() => _JoinRequestsTileState();
}

class _JoinRequestsTileState extends State<_JoinRequestsTile> {
  int? _pending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCount());
  }

  /// The count is a courtesy. It decorates the tile and never gates it, so a
  /// failure here leaves the row exactly as usable as before.
  Future<void> _loadCount() async {
    final connection = context.read<ConnectionProvider>();
    final group = connection.selectedGroup;
    if (group == null) return;
    try {
      final requests = await connection.api.joinRequests(group.id);
      if (mounted) setState(() => _pending = requests.length);
    } catch (_) {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final connection = context.watch<ConnectionProvider>();
    // The persisted role, not the live session: this app is used where there
    // is no coverage for days, and the tile has to be right at cold start.
    if (connection.account?.isGroupAccount != true) return const SizedBox.shrink();

    final group = connection.selectedGroup;
    final pending = _pending;

    return ListTile(
      leading: const Icon(Icons.how_to_reg_outlined, size: 20),
      title: Text(l10n.joinRequestsTileTitle,
          style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        pending == null
            ? l10n.joinRequestsTileSubtitle
            : pending == 0
                ? l10n.joinRequestsNoneWaiting
                : pending == 1
                    ? l10n.joinRequestsOneWaiting
                    : l10n.joinRequestsWaitingCount(pending),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pending != null && pending > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$pending',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
      onTap: group == null
          ? null
          : () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JoinRequestsScreen(groupId: group.id),
                ),
              );
              await _loadCount();
            },
    );
  }
}

class _MemberAccountsToggle extends StatefulWidget {
  const _MemberAccountsToggle();

  @override
  State<_MemberAccountsToggle> createState() => _MemberAccountsToggleState();
}

class _MemberAccountsToggleState extends State<_MemberAccountsToggle> {
  bool _enabled = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    AppSettings.memberAccountsEnabled().then((value) {
      if (mounted) {
        setState(() {
          _enabled = value;
          _loaded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return SwitchListTile(
      secondary: const Icon(Icons.phone_android_outlined, size: 20),
      title: Text(l10n.memberAccounts, style: const TextStyle(fontSize: 14)),
      subtitle: Text(
        l10n.memberAccountsSubtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      value: _enabled,
      onChanged: !_loaded
          ? null
          : (value) async {
              await AppSettings.setMemberAccountsEnabled(value);
              if (mounted) setState(() => _enabled = value);
            },
    );
  }
}
