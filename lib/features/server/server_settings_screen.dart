import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';
import 'cloud_dashboard_screen.dart';
import 'group_sync_screen.dart';
import 'sign_in_options_screen.dart';

/// The cloud account: sign in, or connect with a group access key. The
/// server address is built into the app — users never type it.
class ServerSettingsScreen extends StatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  State<ServerSettingsScreen> createState() => _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends State<ServerSettingsScreen> {
  /*
   * Whether this build lets anyone type an access key.
   *
   * A release authenticates by password and carries a session token;
   * `IC_API_KEY` is ignored outright (see `ApiConfig`). So in production this
   * form cannot connect anybody and can only break a connection that already
   * works — which is the opposite of what someone opening "Cloud Account"
   * wants. Gated here rather than at the six screens that link to this one,
   * because gating call sites is how one gets missed.
   */
  static const bool _keyEntryAvailable = !kReleaseMode;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _keyCtrl;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final creds = context.read<ConnectionProvider>().credentials;
    _keyCtrl = TextEditingController(text: creds.apiKey);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final connection = context.watch<ConnectionProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.cloudAccount)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _StatusBanner(connection: connection),
            if (!connection.isConnected) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignInOptionsScreen()),
                ),
                icon: const Icon(Icons.login, size: 18),
                label: Text(l10n.signIn),
              ),
              const SizedBox(height: 10),
              if (_keyEntryAvailable) ...[
                Row(
                  children: [
                    const Expanded(child: Divider(endIndent: 10)),
                    Text(l10n.serverSettingsOrUseAGroupAccess,
                        style: Theme.of(context).textTheme.bodySmall),
                    const Expanded(child: Divider(indent: 10)),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ],
            if (_keyEntryAvailable) TextFormField(
              controller: _keyCtrl,
              autocorrect: false,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                labelText: l10n.serverSettingsAccessKey,
                hintText: 'ic_sk_…',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureKey ? Icons.visibility : Icons.visibility_off,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your access key' : null,
            ),
            const SizedBox(height: 8),
            if (_keyEntryAvailable)
              Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.serverSettingsAskYourGroupAdministratorForAn,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_keyEntryAvailable)
              OutlinedButton.icon(
                onPressed: connection.busy ? null : _connect,
              icon: connection.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link, size: 18),
                label: Text(
                    connection.busy ? 'Connecting…' : 'Connect with Key'),
              ),
            if (connection.isConnected) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CloudDashboardScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.cloud_outlined, size: 18),
                label: Text(l10n.serverSettingsViewOnlineRecords),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GroupSyncScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.sync, size: 18),
                label: Text(l10n.serverSettingsBackUpThisGroup),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.defaulted,
                  side: BorderSide(
                      color: AppColors.defaulted.withValues(alpha: 0.4)),
                ),
                onPressed: () async {
                  final l10n = L10n.of(context);
                  final connection = context.read<ConnectionProvider>();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(l10n.signOut,
                          style: const TextStyle(fontSize: 17)),
                      content: Text(l10n.signOutKeepsRecords,
                          style: const TextStyle(fontSize: 13.5)),
                      actions: [
                        TextButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.defaulted,
                            minimumSize: const Size(0, 40),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          child: Text(l10n.signOut),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await connection.disconnect();
                  if (context.mounted) {
                    _keyCtrl.clear();
                    showAppSnack(context, l10n.signedOut);
                  }
                },
                icon: const Icon(Icons.logout, size: 18),
                label: Text(L10n.of(context).signOut),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _connect() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final connection = context.read<ConnectionProvider>();
    // The server address ships with the app (.env) — never typed by users.
    final ok = await connection.saveAndConnect(
      baseUrl: connection.credentials.baseUrl,
      apiKey: _keyCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      showAppSnack(context, 'Connected.');
    } else {
      showAppSnack(context, connection.error ?? 'Couldn\'t connect.',
          error: true);
    }
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.connection});

  final ConnectionProvider connection;

  @override
  Widget build(BuildContext context) {
    final (label, color, tint, icon) = switch (connection.status) {
      ConnectionStatus.connected => (
          'Connected',
          AppColors.primary,
          AppColors.primaryTint,
          Icons.check_circle_outline,
        ),
      ConnectionStatus.error => (
          'Can\'t connect right now',
          AppColors.defaulted,
          AppColors.defaultedTint,
          Icons.error_outline,
        ),
      ConnectionStatus.unconfigured => (
          'Not connected',
          AppColors.textSecondary,
          AppColors.surfaceRaised,
          Icons.cloud_off_outlined,
        ),
    };
    return Card(
      color: tint,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  if (connection.status == ConnectionStatus.error &&
                      connection.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        connection.error!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (connection.isConnected &&
                      connection.signedInUser != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${connection.signedInUser!.name} · '
                        '${connection.signedInUser!.roleLabel}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
