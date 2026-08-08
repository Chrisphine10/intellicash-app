import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_config.dart';
import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../data/services/member_matching.dart';
import '../../providers/connection_provider.dart';
import '../../shared/widgets/common.dart';

/// Create-account flow: pick what you are (Group / Member / Agent), then a
/// short form — name, phone and a password. That's all a field user needs;
/// the server address comes from the app's built-in configuration.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

/// Account-type copy comes from the translations, keyed by the wire value.
String _typeTitle(L10n l10n, _AccountType type) => switch (type.wire) {
      'GROUP' => l10n.accountTypeGroup,
      'MEMBER' => l10n.accountTypeMember,
      _ => l10n.accountTypeAgent,
    };

String _typeSubtitle(L10n l10n, _AccountType type) => switch (type.wire) {
      'GROUP' => l10n.accountTypeGroupSubtitle,
      'MEMBER' => l10n.accountTypeMemberSubtitle,
      _ => l10n.accountTypeAgentSubtitle,
    };

class _AccountType {
  const _AccountType(this.wire, this.icon, this.title, this.subtitle);
  final String wire;
  final IconData icon;
  final String title;
  final String subtitle;
}

const _accountTypes = [
  _AccountType('GROUP', Icons.groups_outlined, 'Our Group',
      'This phone will keep our group\'s savings, loans and meetings.'),
  _AccountType('MEMBER', Icons.person_outline, 'Just Me',
      'I want to see my own savings, shares and loans.'),
  // Village Agent, VA and CBT (Community-Based Trainer) are the same job and
  // the same backend role. Programmes use different words for it, so name all
  // of them here — someone who only knows themselves as a CBT should not have
  // to guess that "Field Agent" means them.
  _AccountType('AGENT', Icons.badge_outlined, 'Field Agent',
      'Village Agent or CBT — I support and monitor several groups.'),
];

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _countyCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _repeatCtrl = TextEditingController();
  String? _accountType;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _countyCtrl.dispose();
    _passwordCtrl.dispose();
    _repeatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final connection = context.watch<ConnectionProvider>();
    final chosen = _accountType == null
        ? null
        : _accountTypes.firstWhere((t) => t.wire == _accountType);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createAccount)),
      body: _accountType == null
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Text(l10n.whoIsThisAccountFor,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  l10n.pickOneLater,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                for (final type in _accountTypes)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() => _accountType = type.wire),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: AppColors.primaryTint,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(type.icon,
                                  color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_typeTitle(l10n, type),
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text(_typeSubtitle(l10n, type),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right,
                                color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Card(
                    color: AppColors.primaryTint,
                    child: ListTile(
                      leading: Icon(chosen!.icon,
                          color: AppColors.primary, size: 22),
                      title: Text(_typeTitle(l10n, chosen),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      trailing: TextButton(
                        onPressed: () => setState(() => _accountType = null),
                        child: Text(l10n.change),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: _accountType == 'GROUP'
                          ? l10n.groupNameLabel
                          : l10n.yourFullName,
                    ),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Enter a name'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: l10n.phoneNumber,
                      hintText: '07XX XXX XXX',
                    ),
                    // Same rule as the server, so nothing that passes here
                    // is turned away after the account is submitted.
                    validator: (v) => looksLikePhone(v)
                        ? null
                        : 'Enter a valid phone number',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: l10n.password,
                      helperText: l10n.passwordHint,
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'Use at least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _repeatCtrl,
                    obscureText: _obscure,
                    decoration:
                        InputDecoration(labelText: l10n.repeatPassword),
                    validator: (v) =>
                        v != _passwordCtrl.text ? 'Passwords don\'t match' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: l10n.emailOptional,
                    ),
                    validator: (v) => (v != null &&
                            v.trim().isNotEmpty &&
                            !v.contains('@'))
                        ? 'Enter a valid email or leave it empty'
                        : null,
                  ),
                  if (_accountType == 'AGENT') ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _countyCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                          labelText: l10n.countyOptional),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: connection.busy ? null : _submit,
                    icon: connection.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.person_add_alt, size: 18),
                    label: Text(connection.busy
                        ? l10n.creatingAccount
                        : l10n.createMyAccount),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.registerNeedsInternet,
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
    final navigator = Navigator.of(context);
    final ok = await connection.register(
      baseUrl: ApiConfig.defaultBaseUrl(),
      accountType: _accountType!,
      name: _nameCtrl.text,
      phone: _phoneCtrl.text,
      password: _passwordCtrl.text,
      email: _emailCtrl.text,
      county: _countyCtrl.text,
    );
    if (!mounted) return;
    if (!ok) {
      showAppSnack(context, connection.error ?? 'Could not create the account.',
          error: true);
      return;
    }
    showAppSnack(context,
        'Welcome, ${connection.signedInUser?.name ?? 'friend'}! Your account is ready.');
    // Back to the root — the welcome screen routes by the new account's role.
    navigator.popUntil((route) => route.isFirst);
  }
}
