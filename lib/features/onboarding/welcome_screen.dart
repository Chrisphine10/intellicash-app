import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/connection_provider.dart';
import '../../providers/locale_controller.dart';
import '../agent/agent_home_screen.dart';
import '../member/member_passbook_screen.dart';
import '../more/language_screen.dart';
import '../server/sign_in_options_screen.dart';
import '../server/registration_screen.dart';
import 'group_setup_wizard.dart';

/// First screen after the splash when this phone has no group set up yet.
///
/// Everyone starts with an account: create one (as a group, member or agent)
/// or sign in. Only a signed-in group account can set up the group's record
/// book on this phone. Restored sessions land agents and members straight in
/// their home screen.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final connection = context.watch<ConnectionProvider>();
    final user = connection.signedInUser;

    // Already in session: route by the backend's authoritative role.
    if (connection.hasSession && user != null) {
      if (user.isAgent) return const AgentHomeScreen();
      if (user.isMember) return const MemberPassbookScreen();
      // Group / admin account: continue below to set up the local group.
    }
    final signedIn = connection.hasSession && user != null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          children: [
            Center(
              child: Image.asset('assets/branding/logo_mark.png',
                  width: 72, height: 72),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(l10n.welcomeTitle,
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                signedIn
                    ? l10n.welcomeAccountReady
                    : l10n.welcomeCreateAccountPrompt,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 20),
            if (!signedIn) ...[
              _OptionCard(
                icon: Icons.person_add_alt,
                title: l10n.createAccount,
                subtitle: l10n.createAccountSubtitle,
                emphasized: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const RegistrationScreen()),
                ),
              ),
              _OptionCard(
                icon: Icons.login,
                title: l10n.signIn,
                subtitle: l10n.signInSubtitle,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SignInOptionsScreen()),
                ),
              ),
            ] else ...[
              Card(
                color: AppColors.primaryTint,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_done_outlined,
                          size: 18, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.signedInAs(user.name),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.read<ConnectionProvider>().disconnect(),
                        child: Text(l10n.signOut),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _OptionCard(
                icon: Icons.menu_book_outlined,
                title: l10n.setUpGroup,
                subtitle: l10n.setUpGroupSubtitle,
                emphasized: true,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GroupSetupWizard()),
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Language is reachable before anything else: a first-time user
            // who doesn't read English can switch before signing up.
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
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.emphasized = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: emphasized ? AppColors.primaryTint : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: emphasized
                      ? AppColors.primary.withValues(alpha: 0.18)
                      : AppColors.primaryTint,
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
