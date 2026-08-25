import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/locale_controller.dart';
import '../more/language_screen.dart';
import 'login_screen.dart';
import 'registration_screen.dart';

/// "Who is signing in?" — the three kinds of account this app serves.
///
/// The backend is still the authority on a person's role; picking here only
/// tailors the sign-in copy so a member isn't shown agent language. It is
/// also where a person lands after signing out, so the next user of a shared
/// phone starts by saying who they are.
class SignInOptionsScreen extends StatelessWidget {
  const SignInOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.signIn)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(l10n.whoIsSigningIn,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(l10n.whoIsSigningInSubtitle,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          _RoleCard(
            role: SignInRole.member,
            icon: Icons.person_outline,
            title: l10n.accountTypeMember,
            subtitle: l10n.accountTypeMemberSubtitle,
          ),
          _RoleCard(
            role: SignInRole.group,
            icon: Icons.groups_outlined,
            title: l10n.accountTypeGroup,
            subtitle: l10n.accountTypeGroupSubtitle,
          ),
          _RoleCard(
            role: SignInRole.agent,
            icon: Icons.badge_outlined,
            title: l10n.accountTypeAgent,
            subtitle: l10n.accountTypeAgentSubtitle,
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RegistrationScreen()),
              ),
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: Text(l10n.createAccount),
            ),
          ),
          // Language belongs here, not only on the welcome screen. This is
          // where a person lands after signing out, so on a shared phone it is
          // the first thing the NEXT user sees — and if the phone is set to a
          // language they cannot read, every other route out of here is
          // written in it. A first-time user reaches the welcome screen; a
          // second user of the same handset does not.
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LanguageScreen()),
              ),
              icon: const Icon(Icons.translate, size: 18),
              label: Text(
                '${l10n.language} · '
                '${context.watch<LocaleController>().language.nativeName}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final SignInRole role;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LoginScreen(role: role)),
        ),
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
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
