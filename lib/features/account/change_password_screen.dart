import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';
import '../server/code_sign_in_screen.dart';

/// Changing the password of the account that is signed in.
///
/// Asks for the current password, not just a new one: these phones are shared
/// and often left signed in, and "whoever is holding it can change the
/// password" would let anyone lock a group out of its own book. Someone who has
/// forgotten the current password is sent to the texted-code reset instead,
/// with the account's number already filled in.
///
/// The server signs every OTHER device out when the password changes and keeps
/// this one in, so the person is not bounced to the sign-in screen for doing
/// the right thing.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.phone});

  /// The account's phone, handed to the code reset if it is needed.
  final String? phone;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final l10n = L10n.of(context);
    final connection = context.read<ConnectionProvider>();
    final navigator = Navigator.of(context);

    final ended = await connection.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    if (!mounted) return;
    if (ended == null) {
      showAppSnack(context, connection.error ?? l10n.changePasswordFailed, error: true);
      return;
    }
    showAppSnack(
      context,
      ended > 0 ? l10n.passwordChangedOthersSignedOut : l10n.passwordChanged,
    );
    navigator.pop();
  }

  void _resetWithCode() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CodeSignInScreen(initialPhone: widget.phone, resetPassword: true),
      ),
    );
  }

  Widget _visibilityToggle() => IconButton(
        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off, size: 20),
        onPressed: () => setState(() => _obscure = !_obscure),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final busy = context.watch<ConnectionProvider>().busy;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePassword)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(l10n.changePasswordIntro, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            TextFormField(
              controller: _currentCtrl,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: l10n.currentPasswordLabel,
                suffixIcon: _visibilityToggle(),
              ),
              validator: (value) =>
                  (value == null || value.isEmpty) ? l10n.enterCurrentPassword : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _newCtrl,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(labelText: l10n.newPasswordLabel),
              validator: (value) {
                if (value == null || value.length < 8) return l10n.passwordTooShort;
                if (value == _currentCtrl.text) return l10n.newPasswordSameAsOld;
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(labelText: l10n.confirmNewPasswordLabel),
              validator: (value) => value != _newCtrl.text ? l10n.passwordsDoNotMatch : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: busy
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.savePassword),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: busy ? null : _resetWithCode,
              child: Text(l10n.forgotCurrentPassword, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.forgotCurrentPasswordNote,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
