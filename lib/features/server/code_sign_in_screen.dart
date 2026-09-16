import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../providers/locale_controller.dart';
import '../../shared/widgets/common.dart';

/// Getting into an account that already exists, without its password.
///
/// Groups were onboarded centrally, so their accounts existed before anyone in
/// the field held a password for them. The field team's only option was the
/// sign-up form, which either refused ("this number already has an account")
/// or quietly made a second, empty group. A texted code is the way in that
/// needs nothing but the phone the champion is already holding.
///
/// [resetPassword] turns the same two steps into a password reset: code, then
/// a new password, then signed in.
class CodeSignInScreen extends StatefulWidget {
  const CodeSignInScreen({
    super.key,
    this.initialPhone,
    this.resetPassword = false,
  });

  final String? initialPhone;
  final bool resetPassword;

  @override
  State<CodeSignInScreen> createState() => _CodeSignInScreenState();
}

class _CodeSignInScreenState extends State<CodeSignInScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneCtrl;
  final _codeCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _codeSent = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _phoneCtrl = TextEditingController(text: widget.initialPhone ?? '');
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final connection = context.read<ConnectionProvider>();
    final ok = await connection.requestSignInCode(
      phone: _phoneCtrl.text,
      forPasswordReset: widget.resetPassword,
    );
    if (!mounted) return;
    if (!ok) {
      showAppSnack(context, connection.error ?? 'Could not send a code.',
          error: true);
      return;
    }
    setState(() => _codeSent = true);
  }

  Future<void> _submitCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final connection = context.read<ConnectionProvider>();
    final localeController = context.read<LocaleController>();
    final navigator = Navigator.of(context);

    final ok = await connection.signInWithCode(
      phone: _phoneCtrl.text,
      code: _codeCtrl.text,
      newPassword: widget.resetPassword ? _passwordCtrl.text : null,
    );
    if (!mounted) return;
    if (!ok) {
      showAppSnack(context, connection.error ?? 'That code did not work.',
          error: true);
      return;
    }

    await localeController
        .adoptAccountPreference(connection.signedInUser?.languagePreference);
    if (!mounted) return;
    // Back to the root, which routes by role — the same as a password sign-in,
    // so nothing downstream can tell the difference.
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final connection = context.watch<ConnectionProvider>();
    final busy = connection.busy;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.resetPassword ? l10n.resetPasswordTitle : l10n.signInWithCode),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text(
              widget.resetPassword ? l10n.resetPasswordIntro : l10n.codeSignInIntro,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _phoneCtrl,
              enabled: !_codeSent,
              keyboardType: TextInputType.phone,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l10n.phoneNumber,
                hintText: '07XX XXX XXX',
              ),
              validator: (value) => (value == null || value.trim().length < 9)
                  ? l10n.enterPhoneNumber
                  : null,
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              // Worded as a possibility: the server does not say whether the
              // number has an account, and this screen must not guess.
              Text(
                l10n.codeMaybeSent,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(labelText: l10n.smsCodeLabel),
                validator: (value) => (value == null || value.length != 6)
                    ? l10n.enterSixDigitCode
                    : null,
              ),
              if (widget.resetPassword) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: l10n.newPasswordLabel,
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscure ? Icons.visibility : Icons.visibility_off,
                          size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (value) => (value == null || value.length < 8)
                      ? l10n.passwordTooShort
                      : null,
                ),
              ],
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : (_codeSent ? _submitCode : _sendCode),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(!_codeSent
                      ? l10n.sendMeACode
                      : widget.resetPassword
                          ? l10n.setPasswordAndSignIn
                          : l10n.signIn),
            ),
            if (_codeSent)
              TextButton(
                onPressed: busy ? null : _sendCode,
                child: Text(l10n.sendCodeAgain),
              ),
          ],
        ),
      ),
    );
  }
}
