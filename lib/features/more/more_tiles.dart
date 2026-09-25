import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/status_chip.dart';
import '../server/server_settings_screen.dart';

/// Rows shared by the More screen and the screens it opens.

const moreTileTitleStyle = TextStyle(fontSize: 14);

/// A row that opens [screen] once the phone is signed in to its group online.
///
/// Visible but locked otherwise, never absent: a feature that renders nothing
/// is indistinguishable from a feature that was never built, and officials
/// once reported the welfare module "missing" for exactly that reason.
class OnlineOnlyTile extends StatelessWidget {
  const OnlineOnlyTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.screen,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final connection = context.watch<ConnectionProvider>();
    final ready = connection.isConnected && connection.selectedGroup != null;
    final muted = Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6);

    return ListTile(
      enabled: ready,
      leading: Icon(icon, size: 20),
      title: Text(title, style: moreTileTitleStyle),
      subtitle: Text(
        ready
            ? subtitle
            : connection.isConnected
                ? l10n.moreLockedChooseGroup
                : l10n.moreLockedSignIn,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: ready ? null : muted),
      ),
      trailing: Icon(ready ? Icons.chevron_right : Icons.lock_outline, size: 20),
      onTap: ready
          ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen))
          : null,
    );
  }
}

/// A plain row that opens [screen].
class NavTile extends StatelessWidget {
  const NavTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.screen,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget screen;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: moreTileTitleStyle),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
    );
  }
}

/// The phone's cloud account: signed in or not, reachable or not.
class CloudConnectionTile extends StatelessWidget {
  const CloudConnectionTile({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final connection = context.watch<ConnectionProvider>();
    final online = context.select<AppState, bool>((s) => s.isOnline);
    final (String subtitle, Widget? trailing) = switch (connection.status) {
      // The last check succeeded, but with no network now "Connected" and a
      // green tick would be a false comfort.
      ConnectionStatus.connected when !online => (
          l10n.cloudOfflineSubtitle,
          StatusChip(
            label: l10n.moreStatusOffline,
            color: AppColors.pending,
            tint: AppColors.pendingTint,
            icon: Icons.cloud_off_outlined,
          ),
        ),
      ConnectionStatus.connected => (
          connection.selectedGroup == null
              ? l10n.moreCloudConnected
              : l10n.moreCloudConnectedMembers(connection.members.length),
          StatusChip.synced(),
        ),
      ConnectionStatus.error => (
          connection.error ?? l10n.moreCloudCouldNotConnect,
          StatusChip(
            label: l10n.moreStatusOffline,
            color: AppColors.defaulted,
            tint: AppColors.defaultedTint,
            icon: Icons.error_outline,
          ),
        ),
      ConnectionStatus.unconfigured => (l10n.moreCloudNotConnected, null),
    };
    return ListTile(
      leading: const Icon(Icons.cloud_outlined, size: 20),
      title: Text(l10n.cloudAccount, style: moreTileTitleStyle),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
      ),
    );
  }
}

/// A small count badge before a chevron.
class CountChevron extends StatelessWidget {
  const CountChevron({super.key, this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    final value = count;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value != null && value > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$value',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onPrimary),
            ),
          ),
        const Icon(Icons.chevron_right, size: 20),
      ],
    );
  }
}

/// `10` for 10, `2.5` for 2.5. Rounding to a whole number would show a group
/// that lends at 2.5% as "3%" and one that lets members borrow 1.5x as "2x".
String plainNumber(num value) {
  final text = value.toStringAsFixed(2);
  return text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
