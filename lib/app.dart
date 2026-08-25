import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n/material_locale_fallback.dart';
import 'core/network/api_credentials.dart';
import 'core/theme/app_theme.dart';
import 'features/agent/agent_home_screen.dart';
import 'features/member/member_passbook_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/server/sign_in_options_screen.dart';
import 'features/shell/main_shell.dart';
import 'l10n/app_localizations.dart';
import 'providers/app_state.dart';
import 'providers/connection_provider.dart';
import 'providers/locale_controller.dart';
import 'providers/theme_controller.dart';

class IntelliCashApp extends StatelessWidget {
  const IntelliCashApp({super.key});

  @override
  Widget build(BuildContext context) {
    // AppColors is a plain static holder, not an InheritedWidget consumer, so
    // an appearance change alone won't repaint already-built screens. Keying
    // on the mode forces Flutter to tear down and rebuild the whole app
    // content below MaterialApp, which is how every screen picks up the new
    // palette — see ThemeController's doc comment.
    final mode = context.watch<ThemeController>().mode;
    final locale = context.watch<LocaleController>().locale;
    return MaterialApp(
      key: ValueKey('appearance-$mode'),
      // A literal, not a lookup. This widget builds the MaterialApp that
      // *installs* the localisation delegates, so `L10n.of(context)` here
      // reads a scope that does not exist yet and throws on the first frame.
      // The window title is also the one string a user never reads in-app.
      title: 'Intelli-Cash',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themed(),
      locale: locale,
      supportedLocales: L10n.supportedLocales,
      localizationsDelegates: const [
        L10n.delegate,
        // Ours first: they claim only the locales Flutter can't serve.
        FallbackMaterialLocalizationsDelegate(),
        FallbackCupertinoLocalizationsDelegate(),
        FallbackWidgetsLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: const _Bootstrapper(),
    );
  }
}

/// Which of the app's three separate products the root should show.
///
/// Member, field agent and group account are different systems with different
/// functionality, not one app with a few tiles hidden. A member never sets up
/// a group and never sees one; an agent sees their caseload; only a group
/// account gets the record book.
enum RootDestination {
  splash,
  welcome,
  chooseAccount,
  agentHome,
  memberPassbook,
  groupShell,
}

/// The whole routing rule, as a pure function so it can be tested directly.
///
/// [status] describes only whether a group's book exists on THIS phone. It
/// says nothing about who is signed in, which is why it must never be
/// consulted before [account].
RootDestination rootDestinationFor({
  required bool themeReady,
  required bool localeReady,
  required bool sessionReady,
  required AppStatus status,
  required StoredAccount? account,
  bool hasSignedInBefore = false,
}) {
  if (!themeReady || !localeReady) return RootDestination.splash;
  if (status == AppStatus.loading || !sessionReady) {
    return RootDestination.splash;
  }
  // Signed out — including on a phone that still holds a group's book.
  //
  // A phone that has been signed into before goes to "who is signing in?",
  // not back to the account it just left. Signing out of the group account is
  // how a treasurer switches to their own member account on the same handset,
  // so the account TYPE has to be the first question asked.
  if (account == null) {
    return hasSignedInBefore
        ? RootDestination.chooseAccount
        : RootDestination.welcome;
  }
  if (account.isAgent) return RootDestination.agentHome;
  if (account.isMember) return RootDestination.memberPassbook;
  // Only a group account opens the record book. Every other role — a platform
  // admin, or one this build has never heard of — lands on the welcome screen
  // instead of falling through to a book full of other people's money. The
  // backend gains roles over time; an old app meeting a new role must fail
  // closed, not guess.
  if (!account.isGroupAccount) return RootDestination.welcome;
  return status == AppStatus.ready
      ? RootDestination.groupShell
      : RootDestination.welcome;
}

/// Decides which app this person sees.
///
/// Role comes FIRST, before the local group. It used to be the other way
/// round: any phone that had a group on it returned [MainShell] to everyone,
/// and role routing lived inside [WelcomeScreen] — which this only reached
/// when no group existed. Two things fell out of that. A member or agent who
/// signed in on a group's phone got the group's whole record book, every
/// member's savings and loans included, as soon as they relaunched the app.
/// And signing out changed nothing here, because [AppStatus] only ever
/// described whether a group existed on disk, never whether anyone was signed
/// in — so "sign out" left the group's book wide open behind a pushed login
/// screen.
///
/// The role is read from secure storage, not from the live session, because
/// the live session needs the network to validate and these phones spend days
/// without it.
class _Bootstrapper extends StatelessWidget {
  const _Bootstrapper();

  @override
  Widget build(BuildContext context) {
    final destination = rootDestinationFor(
      themeReady: context.select<ThemeController, bool>((t) => t.ready),
      localeReady: context.select<LocaleController, bool>((l) => l.ready),
      sessionReady:
          context.select<ConnectionProvider, bool>((c) => c.initialized),
      status: context.select<AppState, AppStatus>((s) => s.status),
      account: context.select<ConnectionProvider, StoredAccount?>(
        (c) => c.account,
      ),
      hasSignedInBefore:
          context.select<ConnectionProvider, bool>((c) => c.hasSignedInBefore),
    );
    return switch (destination) {
      RootDestination.splash => const _SplashScreen(),
      RootDestination.welcome => const WelcomeScreen(),
      RootDestination.chooseAccount => const SignInOptionsScreen(),
      RootDestination.agentHome => const AgentHomeScreen(),
      RootDestination.memberPassbook => const MemberPassbookScreen(),
      RootDestination.groupShell => const MainShell(),
    };
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/branding/logo_mark.png', width: 96, height: 96),
            const SizedBox(height: 16),
            Text(
              l10n.moreIntelliCash,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.appTagline,
              style: TextStyle(fontSize: 13, color: Color(0xFF8C99A2)),
            ),
          ],
        ),
      ),
    );
  }
}
