import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/status_chip.dart';
import '../account/account_route.dart';
import '../account/sign_out_flow.dart';
import '../reports/group_report_screen.dart';
import '../reports/member_reports_screen.dart';
import '../shareout/share_out_screen.dart';
import 'advanced_settings_screen.dart';
import 'group_settings_screen.dart';
import 'invite_and_requests_screen.dart';
import 'more_tiles.dart';

/// The group's menu, in three short sections: the group, its reports and
/// share-out, and this phone's account and sync.
///
/// Configuration still lives here so it cannot be touched by accident
/// mid-meeting — but grouped, so a treasurer scans three headings instead of
/// sixteen rows. The detailed settings open one level down (Group settings,
/// Cloud & advanced); sign-out stays on this screen where people look for it.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final appState = context.watch<AppState>();
    final group = appState.group;
    if (group == null) return const SizedBox.shrink();
    final isGroupAccount = context.watch<ConnectionProvider>().account?.isGroupAccount == true;

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
                  Text(group.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    l10n.moreCycleStarted(group.cycleNumber, Formatters.shortDate(group.cycleStartDate)),
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
                NavTile(
                  title: l10n.groupSettings,
                  subtitle: l10n.moreGroupSettingsHubSubtitle,
                  icon: Icons.tune,
                  screen: const GroupSettingsScreen(),
                ),
                if (isGroupAccount) ...[
                  const Divider(indent: 16, endIndent: 16),
                  const _InviteAndRequestsTile(),
                ],
              ],
            ),
          ),
          SectionLabel(l10n.moreSectionReportsShareOut),
          Card(
            child: Column(
              children: [
                NavTile(
                  title: l10n.groupReport,
                  subtitle: l10n.groupReportSubtitle,
                  icon: Icons.description_outlined,
                  screen: const GroupReportScreen(),
                ),
                const Divider(indent: 16, endIndent: 16),
                NavTile(
                  title: l10n.memberReports,
                  subtitle: l10n.memberReportsSubtitle,
                  icon: Icons.people_outline,
                  screen: const MemberReportsScreen(),
                ),
                const Divider(indent: 16, endIndent: 16),
                NavTile(
                  title: l10n.shareOut,
                  subtitle: l10n.shareOutSubtitle,
                  icon: Icons.account_balance_wallet_outlined,
                  screen: const ShareOutScreen(),
                ),
              ],
            ),
          ),
          SectionLabel(l10n.moreSectionAccountSync),
          Card(
            child: Column(
              children: [
                _SyncTile(appState: appState),
                const Divider(indent: 16, endIndent: 16),
                NavTile(
                  title: l10n.accountAccount,
                  subtitle: l10n.moreWhoIsSignedInLanguage,
                  icon: Icons.account_circle_outlined,
                  screen: const AccountRoute(),
                ),
                const Divider(indent: 16, endIndent: 16),
                NavTile(
                  title: l10n.moreCloudAndAdvanced,
                  subtitle: l10n.moreCloudAndAdvancedSubtitle,
                  icon: Icons.cloud_outlined,
                  screen: const AdvancedSettingsScreen(),
                ),
                if (context.watch<ConnectionProvider>().signedInUser != null ||
                    context.watch<ConnectionProvider>().account != null) ...[
                  const Divider(indent: 16, endIndent: 16),
                  const _SignOutTile(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sign-out, always on More for a signed-in phone. It sends this phone's
/// records first and refuses, saying why, when it cannot; the group's book
/// itself stays on the phone either way.
class _SignOutTile extends StatelessWidget {
  const _SignOutTile();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final user = context.watch<ConnectionProvider>().signedInUser;
    return ListTile(
      leading: Icon(Icons.logout, size: 20, color: AppColors.defaulted),
      title: Text(l10n.signOut, style: TextStyle(fontSize: 14, color: AppColors.defaulted)),
      subtitle: Text(
        user != null ? l10n.signedInAs(user.name) : l10n.signOutKeepsRecords,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: () => confirmAndSignOut(context),
    );
  }
}

/// The sync / backup row: shows what is waiting and pushes it on tap.
class _SyncTile extends StatelessWidget {
  const _SyncTile({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final pending = appState.pendingSync;
    return ListTile(
      leading: const Icon(Icons.cloud_upload_outlined, size: 20),
      title: Text(l10n.syncBackup, style: moreTileTitleStyle),
      subtitle: Text(
        // A refused share-out is said in words: a bare "1 waiting" would leave
        // the treasurer to guess that money paid out is not on the online record.
        appState.syncAttention ??
            (pending == 0 ? l10n.moreEverythingBackedUp : l10n.moreItemsWaiting(pending)),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: appState.syncAttention == null ? null : AppColors.defaulted,
            ),
      ),
      trailing: pending > 0 ? StatusChip.pendingSync(pending) : StatusChip.synced(),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        final synced = await appState.syncNow();
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              synced > 0
                  ? l10n.moreBackedUpCount(synced)
                  : appState.pendingSync == 0
                      ? l10n.moreAlreadyBackedUp
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

/// One row for inviting people and answering their requests, with a badge
/// when someone is waiting.
class _InviteAndRequestsTile extends StatefulWidget {
  const _InviteAndRequestsTile();

  @override
  State<_InviteAndRequestsTile> createState() => _InviteAndRequestsTileState();
}

class _InviteAndRequestsTileState extends State<_InviteAndRequestsTile> {
  int? _pending;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCount());
  }

  Future<void> _loadCount() async {
    final count = await pendingJoinRequests(context.read<ConnectionProvider>());
    if (mounted) setState(() => _pending = count);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return ListTile(
      leading: const Icon(Icons.group_add_outlined, size: 20),
      title: Text(l10n.moreInviteAndRequests, style: moreTileTitleStyle),
      subtitle: Text(joinRequestsSummary(l10n, _pending), style: Theme.of(context).textTheme.bodySmall),
      trailing: CountChevron(count: _pending),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InviteAndRequestsScreen()),
        );
        await _loadCount();
      },
    );
  }
}
