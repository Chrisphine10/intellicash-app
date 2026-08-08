import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';

/// The backend connection: base URL plus a single opaque API-key token.
///
/// The IntelliCash API authenticates mobile clients with a bearer token
/// (`Authorization: Bearer ic_sk_…`) minted from the `MOBILE_CORE` preset —
/// there is no separate secret. The token is sensitive, so it lives in the
/// platform secure store, never in plain SharedPreferences.
class ApiCredentials {
  const ApiCredentials({required this.baseUrl, required this.apiKey});

  final String baseUrl;

  /// The `ic_sk_…` bearer token.
  final String apiKey;

  bool get isConfigured => apiKey.isNotEmpty;

  ApiCredentials copyWith({String? baseUrl, String? apiKey}) {
    return ApiCredentials(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
    );
  }
}

/// Who is signed in on this phone, remembered across launches.
///
/// The token alone cannot answer "which app should this person see?", because
/// deciding that from the live session needs a network round-trip, and this
/// app is used in places with no coverage for days. Persisting the role makes
/// the answer available at cold start, offline: a member opens the app on a
/// plane-mode phone and still gets their passbook rather than the group's
/// record book.
class StoredAccount {
  const StoredAccount({
    required this.role,
    required this.name,
    required this.identifier,
  });

  /// The backend's authoritative role: GROUP_ACCOUNT | MEMBER | VILLAGE_AGENT.
  final String role;
  final String name;

  /// The phone or email typed at sign-in. Kept so the login form can be
  /// pre-filled after a sign-out.
  final String identifier;

  bool get isAgent => role == 'VILLAGE_AGENT';
  bool get isMember => role == 'MEMBER';
  bool get isGroupAccount => role == 'GROUP_ACCOUNT';
}

/// Persists [ApiCredentials] in secure storage.
class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kBaseUrl = 'api_base_url';
  static const _kKey = 'api_key';
  // Legacy key from the pre-Bearer scaffolding; cleared on save/clear.
  static const _kLegacySecret = 'api_secret';
  static const _kRole = 'account_role';
  static const _kName = 'account_name';
  static const _kIdentifier = 'account_identifier';

  /// Deliberately NOT cleared on sign-out: the next person to sign in on a
  /// group's phone is almost always the same group, and retyping a phone
  /// number on a feature-phone keyboard is the kind of friction that makes
  /// people avoid signing out at all.
  static const _kLastIdentifier = 'last_identifier';

  /// Which kind of account last signed in here. Kept alongside the identifier
  /// so the login form only pre-fills when the SAME kind is chosen again —
  /// offering a group's phone number to someone signing in as "Just Me" is
  /// worse than offering nothing.
  static const _kLastRole = 'last_role';

  final FlutterSecureStorage _storage;

  Future<ApiCredentials> load() async {
    String? baseUrl;
    String? apiKey;
    try {
      baseUrl = await _storage.read(key: _kBaseUrl);
      apiKey = await _storage.read(key: _kKey);
    } catch (_) {
      // Secure storage is unavailable (fresh test environment / missing
      // platform plugin) — fall through to the .env / platform defaults.
    }
    return ApiCredentials(
      baseUrl: (baseUrl == null || baseUrl.isEmpty)
          ? ApiConfig.defaultBaseUrl()
          : baseUrl,
      // Backend configuration lives in .env: a key bundled there connects
      // the app out of the box, without anyone typing it into the app.
      apiKey: (apiKey == null || apiKey.isEmpty)
          ? (ApiConfig.envApiKey() ?? '')
          : apiKey,
    );
  }

  Future<void> save(ApiCredentials credentials) async {
    await _storage.write(key: _kBaseUrl, value: credentials.baseUrl);
    await _storage.write(key: _kKey, value: credentials.apiKey);
    await _storage.delete(key: _kLegacySecret);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kBaseUrl);
    await _storage.delete(key: _kKey);
    await _storage.delete(key: _kLegacySecret);
  }

  Future<StoredAccount?> loadAccount() async {
    try {
      final role = await _storage.read(key: _kRole);
      if (role == null || role.isEmpty) return null;
      return StoredAccount(
        role: role,
        name: await _storage.read(key: _kName) ?? '',
        identifier: await _storage.read(key: _kIdentifier) ?? '',
      );
    } catch (_) {
      // Secure storage unavailable — treat as signed out rather than crashing
      // into a screen the person may not be entitled to see.
      return null;
    }
  }

  Future<void> saveAccount(StoredAccount account) async {
    await _storage.write(key: _kRole, value: account.role);
    await _storage.write(key: _kName, value: account.name);
    await _storage.write(key: _kIdentifier, value: account.identifier);
    if (account.identifier.isNotEmpty) {
      await _storage.write(key: _kLastIdentifier, value: account.identifier);
      await _storage.write(key: _kLastRole, value: account.role);
    }
  }

  /// Forgets who was signed in. Keeps [lastIdentifier] so the login form can
  /// be pre-filled.
  Future<void> clearAccount() async {
    await _storage.delete(key: _kRole);
    await _storage.delete(key: _kName);
    await _storage.delete(key: _kIdentifier);
  }

  Future<String?> lastIdentifier() async {
    try {
      return await _storage.read(key: _kLastIdentifier);
    } catch (_) {
      return null;
    }
  }

  Future<String?> lastRole() async {
    try {
      return await _storage.read(key: _kLastRole);
    } catch (_) {
      return null;
    }
  }
}
