import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_settings.dart';
import '../../core/utils/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';
import '../../providers/locale_controller.dart';
import '../../providers/theme_controller.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/status_chip.dart';
import '../onboarding/group_setup_wizard.dart';
import '../reports/group_report_screen.dart';
import '../reports/member_reports_screen.dart';
import '../shareout/share_out_screen.dart';
import 'language_screen.dart';
import 'meeting_security_screen.dart';
import '../settings/cycles_screen.dart';
import '../settings/group_policy_screen.dart';
import '../settings/payment_providers_screen.dart';
import '../store/store_screen.dart';
import '../server/server_settings_screen.dart';
import '../server/sign_in_options_screen.dart';

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
          SectionLabel(l10n.sectionStore),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined, size: 20),
              title: Text(l10n.intelliStores,
                  style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                'Shop on credit — priced by your rating',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StoreScreen()),
                );
              },
            ),
          ),
          SectionLabel(l10n.sectionAppearance),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.themeLabel,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Choose how Intelli-Cash looks on this phone.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  const _AppearancePicker(),
                ],
              ),
            ),
          ),
          SectionLabel(l10n.sectionLanguage),
          Card(
            child: ListTile(
              leading: const Icon(Icons.translate, size: 20),
              title: Text(l10n.language,
                  style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                context.watch<LocaleController>().language.nativeName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LanguageScreen()),
                );
              },
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
                      const Text('Intelli-Cash',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your group\'s savings and loans, right on your phone. '
                    'Everything is saved on this phone first and backed up '
                    'online when you have internet.\n\n'
                    'Intelli-Wealth Limited · intelliwealth.org',
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
    // Offer the account chooser straight away; the group's offline book is
    // still behind this screen if they just want to keep working.
    navigator.push(
      MaterialPageRoute(builder: (_) => const SignInOptionsScreen()),
    );
  }

  /// Where members' money is received. Only meaningful once the phone is
  /// connected and a group is chosen, so it stays hidden otherwise rather than
  /// opening a screen that can only show an error.
  /// Cloud-only settings. Hidden until a group is chosen, so the screen
  /// cannot open onto an error the person cannot act on.
  Widget _governanceTile(BuildContext context, String title, IconData icon,
      String subtitle, Widget screen) {
    final connection = context.watch<ConnectionProvider>();
    if (!connection.isConnected || connection.selectedGroup == null) {
      return const SizedBox.shrink();
    }
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => screen)),
    );
  }

  Widget _paymentProvidersTile(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    if (!connection.isConnected || connection.selectedGroup == null) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: const Icon(Icons.account_balance_wallet_outlined, size: 20),
      title: const Text('Payment Providers', style: TextStyle(fontSize: 14)),
      subtitle: Text(
        'Where money from members is received',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PaymentProvidersScreen()),
        );
      },
    );
  }

  Widget _connectionTile(BuildContext context) {
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
      title: const Text('Cloud Account', style: TextStyle(fontSize: 14)),
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
    return ListTile(
      leading: const Icon(Icons.cloud_upload_outlined, size: 20),
      title: const Text('Sync & Backup', style: TextStyle(fontSize: 14)),
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
                      : 'No internet — your records are safe on this phone '
                          'and will back up later.',
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
class _AppearancePicker extends StatelessWidget {
  const _AppearancePicker();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.light,
          label: Text('Light'),
          icon: Icon(Icons.light_mode_outlined, size: 16),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          label: Text('Dark'),
          icon: Icon(Icons.dark_mode_outlined, size: 16),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          label: Text('System'),
          icon: Icon(Icons.smartphone_outlined, size: 16),
        ),
      ],
      selected: {controller.mode},
      onSelectionChanged: (selection) => controller.setMode(selection.first),
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.primaryTint,
        selectedForegroundColor: AppColors.primary,
        foregroundColor: AppColors.textSecondary,
        side: BorderSide(color: AppColors.outline),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      showSelectedIcon: false,
    );
  }
}

/// Optional: let this group create sign-in accounts for its members, so each
/// member can check their own savings on their own phone.
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
