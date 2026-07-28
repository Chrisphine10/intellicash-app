import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';
import '../../providers/locale_controller.dart';
import '../../shared/widgets/common.dart';
import '../agent/agent_home_screen.dart';
import '../member/member_passbook_screen.dart';

/// The kind of account someone said they were on the previous screen. It
/// only tailors the copy — the backend remains the authority on the real
/// role, and sign-in routes by that.
enum SignInRole {
  member('Member'),
  group('Group'),
  agent('Agent');

  const SignInRole(this.label);
  final String label;
}

/// One simple sign-in: phone number (or email) + password. The server
/// address is built into the app — nothing to configure. The backend decides
/// the account's role and the app routes to the right home screen.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.role});

  /// Copy hint from the "who is signing in?" screen.
  final SignInRole? role;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _idCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final connection = context.watch<ConnectionProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.signIn)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Image.asset('assets/branding/logo_mark.png',
                  width: 72, height: 72),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                  widget.role == null
                      ? l10n.welcomeBack
                      : switch (widget.role!) {
                          SignInRole.member => l10n.accountTypeMember,
                          SignInRole.group => l10n.accountTypeGroup,
                          SignInRole.agent => l10n.accountTypeAgent,
                        },
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                l10n.signInWithPhone,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _idCtrl,
              keyboardType: TextInputType.phone,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.phoneOrEmail,
                hintText: '07XX XXX XXX',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter your phone number or email'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: l10n.password,
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                      size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your password' : null,
            ),
            if (connection.status == ConnectionStatus.error &&
                connection.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(connection.error!,
                    style: TextStyle(
                        fontSize: 12.5, color: AppColors.defaulted)),
              ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: connection.busy ? null : _submit,
              icon: connection.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.login, size: 18),
              label: Text(connection.busy ? l10n.signingIn : l10n.signIn),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.sessionNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final connection = context.read<ConnectionProvider>();
    final localeController = context.read<LocaleController>();
    final navigator = Navigator.of(context);
    // The server address ships with the app (.env) — never typed by users.
    final ok = await connection.signInWithPassword(
      baseUrl: connection.credentials.baseUrl,
      identifier: _idCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (!ok) {
      showAppSnack(context, connection.error ?? 'Sign in failed.', error: true);
      return;
    }

    final user = connection.signedInUser;
    // A phone with no language chosen yet follows the account's preference.
    await localeController.adoptAccountPreference(user?.languagePreference);
    if (!mounted) return;
    showAppSnack(context, 'Signed in as ${user?.name ?? 'your account'}.');

    // No local group yet (signed in from the welcome screen): pop back to
    // the root — the welcome screen itself routes agents and members to
    // their home by role, so no push here.
    if (context.read<AppState>().status == AppStatus.needsSetup) {
      navigator.popUntil((route) => route.isFirst);
      return;
    }

    // Route by the backend's authoritative role, regardless of entry point.
    if (user?.isAgent ?? false) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const AgentHomeScreen()),
      );
    } else if (user?.isMember ?? false) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const MemberPassbookScreen()),
      );
    } else {
      // Group / admin / other: return to the connected app.
      navigator.pop();
    }
  }
}
