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

/// Persists [ApiCredentials] in secure storage.
class CredentialStore {
  CredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const _kBaseUrl = 'api_base_url';
  static const _kKey = 'api_key';
  // Legacy key from the pre-Bearer scaffolding; cleared on save/clear.
  static const _kLegacySecret = 'api_secret';

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
}
