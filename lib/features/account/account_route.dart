import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../providers/locale_controller.dart';
import '../../providers/theme_controller.dart';
import '../more/language_screen.dart';
import '../server/server_settings_screen.dart';
import 'account_screen.dart';
import 'appearance_screen.dart';

/// Binds [AccountScreen] to the app's providers.
///
/// The screen itself stays pure — data in, callbacks out — so it can be
/// rendered in a test without a database or a network. Everything that has to
/// touch a provider lives here instead, which is the only reason that screen
/// could be checked at all on a machine where the emulator would not boot.
class AccountRoute extends StatelessWidget {
  const AccountRoute({super.key});

  /// Kept in step with `pubspec.yaml` by the release checklist. Reading it at
  /// runtime would mean adding `package_info_plus` for one line of text.
  static const appVersion = '2.4.0 (12)';

  @override
  Widget build(BuildContext context) {
    final connection = context.watch<ConnectionProvider>();
    final locale = context.watch<LocaleController>();
    final themeMode = context.watch<ThemeController>().mode;
    final user = connection.signedInUser;

    return AccountScreen(
      summary: AccountSummary(
        name: user?.name ?? 'This phone',
        roleLabel: user?.roleLabel ?? 'Not signed in',
        phone: user?.phone,
        email: user?.email,
        scopeLabel: _scopeLabel(connection),
        serverLabel: _host(connection.credentials.baseUrl),
        appVersion: appVersion,
        languageLabel: locale.language.nativeName,
        themeLabel: switch (themeMode) {
          ThemeMode.light => 'Always light',
          ThemeMode.dark => 'Always dark',
          ThemeMode.system => 'Follow the phone',
        },
      ),
      onLanguage: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LanguageScreen()),
      ),
      onTheme: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AppearanceScreen()),
      ),
      onServer: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
      ),
      onSignOut: () => _confirmSignOut(context),
    );
  }

  /// What this account covers, in the words that fit the role. A group account
  /// is scoped to one group; an agent holds many.
  static String? _scopeLabel(ConnectionProvider connection) {
    final user = connection.signedInUser;
    if (user == null) return null;
    if (user.isAgent) {
      final n = connection.groups.length;
      return '$n group${n == 1 ? '' : 's'} in your caseload';
    }
    if (connection.groups.length == 1) return connection.groups.first.name;
    return null;
  }

  /// Just the host. The full base URL carries `/api/v1` and a scheme, which is
  /// noise to anyone checking they are pointed at the right place.
  static String? _host(String baseUrl) {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.host.isEmpty) return baseUrl.isEmpty ? null : baseUrl;
    return uri.host;
  }

  /// Confirmation lives here rather than in the screen: what signing out costs
  /// depends on the role, and a mis-tap should not end a session.
  static Future<void> _confirmSignOut(BuildContext context) async {
    final l10n = L10n.of(context);
    final connection = context.read<ConnectionProvider>();
    final navigator = Navigator.of(context);
    final isAgent = connection.signedInUser?.isAgent ?? false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.signOut, style: const TextStyle(fontSize: 17)),
        content: Text(
          isAgent ? l10n.signOutAgentNote : l10n.signOutKeepsRecords,
          style: const TextStyle(fontSize: 13.5),
        ),
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
}
