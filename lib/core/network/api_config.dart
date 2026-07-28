import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Resolves the IntelliCash backend base URL per platform, never hardcoding
/// a production host.
///
/// The backend is the Node/Express API (`@intellicash/api`) which listens on
/// port 4000 and mounts every route under `/api/v1`.
///
/// - `IC_BASE_URL` from the bundled `.env` wins when set — backend
///   configuration lives in `.env`, not inside the app.
/// - Android emulator reaches the host machine at `10.0.2.2`.
/// - iOS simulator and desktop reach it at `localhost`.
/// - A physical device needs the host's LAN IP, which the user supplies in
///   Server settings; that saved override wins on every platform.
abstract final class ApiConfig {
  /// Default port for `npm run dev -w @intellicash/api`.
  static const int defaultPort = 4000;

  /// Every backend route is mounted under this prefix.
  static const String apiPrefix = '/api/v1';

  /// `IC_BASE_URL` from `.env`, when the file is bundled and sets one.
  static String? envBaseUrl() {
    if (!dotenv.isInitialized) return null;
    final url = dotenv.env['IC_BASE_URL']?.trim();
    return (url == null || url.isEmpty) ? null : normalize(url);
  }

  /// `IC_API_KEY` from `.env`, when the file is bundled and sets one.
  ///
  /// Ignored entirely in a release build. `.env` ships inside the APK, and an
  /// APK is a public artifact — anyone can unzip it and read the key, which
  /// would hand out its scopes without anyone signing in. Release builds
  /// authenticate with a password and carry a session token instead.
  static String? envApiKey() {
    if (kReleaseMode) return null;
    if (!dotenv.isInitialized) return null;
    final key = dotenv.env['IC_API_KEY']?.trim();
    return (key == null || key.isEmpty) ? null : key;
  }

  /// Whether [url] is safe to send credentials to.
  ///
  /// Plain http is fine against a development host on this machine, and
  /// nothing else: over a real network it puts members' passwords and session
  /// tokens on the wire in clear.
  static bool isSecureForRelease(String url) {
    if (url.startsWith('https://')) return true;
    final host = Uri.tryParse(url)?.host ?? '';
    return host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';
  }

  /// A release build misconfiguration worth failing loudly on, or null when
  /// the configuration is sound.
  ///
  /// Returns a message rather than throwing so the app can show it: a build
  /// that silently points at a developer's laptop looks like a broken server
  /// to whoever installed it.
  static String? releaseConfigProblem() {
    if (!kReleaseMode) return null;
    final configured = envBaseUrl();
    if (configured == null) {
      return 'This build has no IC_BASE_URL. Set it in .env before building '
          'for release.';
    }
    final host = Uri.tryParse(configured)?.host ?? '';
    if (host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2') {
      return 'This build points at a development machine ($host). Set '
          'IC_BASE_URL to the real server before building for release.';
    }
    if (!isSecureForRelease(configured)) {
      return 'This build would send passwords over plain http. Use an https '
          'address for IC_BASE_URL.';
    }
    return null;
  }

  /// Platform default when the user has not entered a custom host: the
  /// `.env` value first, then the platform loopback.
  static String defaultBaseUrl() {
    final fromEnv = envBaseUrl();
    if (fromEnv != null) return fromEnv;
    final host = _defaultHost();
    return 'http://$host:$defaultPort$apiPrefix';
  }

  static String _defaultHost() {
    if (kIsWeb) return 'localhost';
    if (Platform.isAndroid) return '10.0.2.2';
    // iOS simulator, macOS, Windows, Linux all reach the host loopback.
    return 'localhost';
  }

  /// Normalizes a user-entered base URL: adds a scheme, strips a trailing
  /// slash, and appends `/api/v1` if the user left it off.
  static String normalize(String input) {
    var url = input.trim();
    if (url.isEmpty) return defaultBaseUrl();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.endsWith(apiPrefix)) {
      url = '$url$apiPrefix';
    }
    return url;
  }
}
