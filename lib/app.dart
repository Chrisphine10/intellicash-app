import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n/material_locale_fallback.dart';
import 'core/network/api_credentials.dart';
import 'core/theme/app_theme.dart';
import 'features/agent/agent_home_screen.dart';
import 'features/member/member_passbook_screen.dart';
import 'features/onboarding/welcome_screen.dart';
import 'features/onboarding/wrong_book_screen.dart';
import 'features/server/sign_in_options_screen.dart';
import 'features/shell/main_shell.dart';
import 'l10n/app_localizations.dart';
import 'providers/app_state.dart';
import 'providers/connection_provider.dart';
import 'providers/locale_controller.dart';
import 'providers/theme_controller.dart';

class IntelliCashApp extends StatefulWidget {
  const IntelliCashApp({super.key});

  @override
  State<IntelliCashApp> createState() => _IntelliCashAppState();
}

class _IntelliCashAppState extends State<IntelliCashApp> {
  ThemeMode? _paintedMode;

  /// Marks every widget on screen for rebuilding, keeping all of them (and so
  /// the navigation stack and anything half-typed) exactly where they are.
  void _repaintEverything() {
    void mark(Element element) {
      element.markNeedsBuild();
      element.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) {
    // AppColors is a plain static holder, not an InheritedWidget consumer, so
    // an appearance change alone won't repaint already-built screens. Every
    // screen has to build again to read the new palette. This used to be done by
    // keying the MaterialApp on the mode, which throws the whole app away and
    // starts it again - so picking a theme dropped the person back on the first
    // screen. Marking the widgets for rebuild instead repaints them where they
    // stand, so the Appearance screen is still there showing the new look.
    final mode = context.watch<ThemeController>().mode;
    final locale = context.watch<LocaleController>().locale;
    if (_paintedMode != null && _paintedMode != mode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _repaintEverything();
      });
    }
    _paintedMode = mode;
    return MaterialApp(
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

  /// A group account signed in on a phone whose book belongs to another group.
  wrongBook,
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

  /// The server group the book on this phone is linked to, when it is.
  String? boundRemoteGroupId,
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
  if (status != AppStatus.ready) return RootDestination.welcome;
  // The book belongs to the group it is linked to. A group account may open it
  // only if it is that group's account; another group's account is stopped.
  // Only a definite mismatch stops anyone: an unlinked book, or an account whose
  // group is not yet known (an older session, or offline), opens as before.
  final owner = account.groupId;
  if (owner != null &&
      owner.isNotEmpty &&
      boundRemoteGroupId != null &&
      boundRemoteGroupId.isNotEmpty &&
      owner != boundRemoteGroupId) {
    return RootDestination.wrongBook;
  }
  return RootDestination.groupShell;
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
      boundRemoteGroupId:
          context.select<AppState, String?>((s) => s.boundRemoteGroupId),
    );
    return switch (destination) {
      RootDestination.splash => const _SplashScreen(),
      RootDestination.welcome => const WelcomeScreen(),
      RootDestination.chooseAccount => const SignInOptionsScreen(),
      RootDestination.agentHome => const AgentHomeScreen(),
      RootDestination.memberPassbook => const MemberPassbookScreen(),
      RootDestination.groupShell => const MainShell(),
      RootDestination.wrongBook => const WrongBookScreen(),
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
