import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../data/services/group_restore_service.dart';
import '../../providers/app_state.dart';
import '../../providers/connection_provider.dart';
import '../../providers/locale_controller.dart';
import '../agent/agent_home_screen.dart';
import '../member/member_passbook_screen.dart';
import '../more/language_screen.dart';
import '../server/sign_in_options_screen.dart';
import '../server/registration_screen.dart';
import 'group_setup_wizard.dart';

/// What this screen offers the person looking at it.
enum WelcomeOption {
  /// Nobody is signed in: create an account, or sign in.
  createAccountOrSignIn,

  /// A signed-in agent or member goes straight to their own home.
  agentHome,
  memberHome,

  /// A signed-in group account with no local book yet: set the group up.
  setUpGroup,

  /// A signed-in account this app does not serve — a platform admin, a
  /// partner officer, a lender, or a role a newer backend has invented.
  accountNotUsedOnThisApp,
}

/// Decides what a person is offered, given only who they are.
///
/// Pure and exhaustive so every role can be checked without building a
/// widget or a provider — the same reason `rootDestinationFor` is a function
/// rather than a pile of `if`s inside a `build`.
///
/// The case this exists to get right: a signed-in account that is NOT a
/// group used to fall through to the group-setup card, which was then the
/// only thing on screen. An admin or a lender signing in on a handset was
/// therefore told, in effect, that their next step was to create a group —
/// a user account being made to create a group account before it could do
/// anything. It is not their next step, and for most of these roles it is
/// not a step at all: their workspace is the web console.
WelcomeOption welcomeOptionFor({required bool signedIn, required String? role}) {
  if (!signedIn) return WelcomeOption.createAccountOrSignIn;

  switch (role) {
    case 'VILLAGE_AGENT':
      return WelcomeOption.agentHome;
    case 'MEMBER':
      return WelcomeOption.memberHome;
    case 'GROUP_ACCOUNT':
      return WelcomeOption.setUpGroup;
    default:
      // Fail closed. An unrecognised role is never handed the group book,
      // and is never pushed into creating one either.
      return WelcomeOption.accountNotUsedOnThisApp;
  }
}

/// First screen after the splash when this phone has no group set up yet.
///
/// Everyone starts with an account: create one (as a group, member or agent)
/// or sign in. Only a signed-in GROUP account is offered the group's record
/// book on this phone — creating a group is never a precondition for using a
/// personal account. Restored sessions land agents and members straight in
/// their home screen.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final connection = context.watch<ConnectionProvider>();
    final user = connection.signedInUser;
    final signedIn = connection.hasSession && user != null;
    final option = welcomeOptionFor(signedIn: signedIn, role: user?.role);

    // Already in session: route by the backend's authoritative role.
    if (option == WelcomeOption.agentHome) return const AgentHomeScreen();
    if (option == WelcomeOption.memberHome) {
      return const MemberPassbookScreen();
    }

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
            if (option == WelcomeOption.createAccountOrSignIn) ...[
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
                          l10n.signedInAs(user?.name ?? ''),
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
              if (option == WelcomeOption.setUpGroup) ...[
                // The server already knows this account's group, so pulling
                // it down comes FIRST. Offering only 'set up' to a treasurer
                // who reinstalled the app is how one group ends up recorded
                // twice under two codes, with the savings history split
                // between them.
                if (user?.groupId != null)
                  _RestoreGroupCard(remoteGroupId: user!.groupId!),
                _OptionCard(
                  icon: Icons.menu_book_outlined,
                  title: l10n.setUpGroup,
                  subtitle: user?.groupId == null
                      ? l10n.setUpGroupSubtitle
                      : 'Start a different group on this phone.',
                  emphasized: user?.groupId == null,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GroupSetupWizard()),
                  ),
                ),
              ]
              else
                // Signed in, but this app has nothing for this role. Say so
                // plainly and leave sign-out as the way forward. Offering
                // group setup here would tell someone their personal account
                // must become a group's record book before it works, which is
                // both untrue and how a group ends up owned by the wrong
                // account.
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.desktop_windows_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Use the web console for this account',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'The phone app is for groups, members and field '
                          'agents. Your account does not need to create a '
                          'group here — sign in on the web console instead, '
                          'or sign out to use a different account.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
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

/// Pulls a group that already exists on the server onto this phone.
///
/// Stateful for one reason: the pull takes a moment over a rural link and
/// the button has to say so, or an agent taps it three times and wonders why
/// nothing happened.
class _RestoreGroupCard extends StatefulWidget {
  const _RestoreGroupCard({required this.remoteGroupId});

  final String remoteGroupId;

  @override
  State<_RestoreGroupCard> createState() => _RestoreGroupCardState();
}

class _RestoreGroupCardState extends State<_RestoreGroupCard> {
  bool _busy = false;
  String? _error;

  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<GroupRestoreService>();
    final appState = context.read<AppState>();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final result = await service.restore(widget.remoteGroupId);
      // Reload so the root router sees the group and opens the record book.
      await appState.reloadGroup();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.alreadyPresent
              ? 'This group is already on this phone.'
              : 'Loaded ${result.group?.name ?? 'your group'} with '
                  '${result.membersRestored} members.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      // Named plainly rather than swallowed: without signal there is nothing
      // to restore FROM, and the treasurer needs to know to try later rather
      // than to start creating a second group.
      setState(() => _error =
          'Could not load your group. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primaryTint,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_download_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Load your group onto this phone',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Your group is already on the server. Load it here instead of '
              'creating a new one, so your savings history stays in one '
              'record.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _busy ? null : _restore,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download, size: 18),
              label: Text(_busy ? 'Loading…' : 'Load my group'),
            ),
          ],
        ),
      ),
    );
  }
}
