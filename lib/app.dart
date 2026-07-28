import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/l10n/material_locale_fallback.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/welcome_screen.dart';
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

class _Bootstrapper extends StatelessWidget {
  const _Bootstrapper();

  @override
  Widget build(BuildContext context) {
    final themeReady = context.select<ThemeController, bool>((t) => t.ready);
    final localeReady = context.select<LocaleController, bool>((l) => l.ready);
    final status = context.select<AppState, AppStatus>((s) => s.status);
    final sessionReady =
        context.select<ConnectionProvider, bool>((c) => c.initialized);
    if (!themeReady || !localeReady) return const _SplashScreen();
    return switch (status) {
      AppStatus.loading => const _SplashScreen(),
      // No local group yet: wait for any stored session to restore, then let
      // the user pick how they use the app (or land them in their role home).
      AppStatus.needsSetup =>
        sessionReady ? const WelcomeScreen() : const _SplashScreen(),
      AppStatus.ready => const MainShell(),
    };
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/branding/logo_mark.png', width: 96, height: 96),
            const SizedBox(height: 16),
            const Text(
              'Intelli-Cash',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your VSLA in your pocket',
              style: TextStyle(fontSize: 13, color: Color(0xFF8C99A2)),
            ),
          ],
        ),
      ),
    );
  }
}
