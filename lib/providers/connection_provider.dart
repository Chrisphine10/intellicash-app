import 'package:flutter/foundation.dart';

import '../core/network/api_config.dart';
import '../core/network/api_credentials.dart';
import '../core/network/api_exception.dart';
import '../data/models/remote/remote_models.dart';
import '../data/services/remote_api.dart';

enum ConnectionStatus { unconfigured, connected, error }

/// Owns the backend connection: the stored API key, live connection state,
/// and the read-only data pulled from the IntelliCash server (groups, and the
/// selected group's members, meetings and fund balances, plus notifications).
class ConnectionProvider extends ChangeNotifier {
  ConnectionProvider({
    required CredentialStore store,
    required RemoteApi api,
    required void Function(ApiCredentials) applyCredentials,
  })  : _store = store,
        _api = api,
        _applyCredentials = applyCredentials;

  final CredentialStore _store;
  final RemoteApi _api;

  /// Pushes freshly loaded/saved credentials into the shared ApiClient.
  final void Function(ApiCredentials) _applyCredentials;

  ApiCredentials _credentials = ApiCredentials(
    baseUrl: ApiConfig.defaultBaseUrl(),
    apiKey: '',
  );
  ConnectionStatus _status = ConnectionStatus.unconfigured;
  String? _error;
  bool _busy = false;
  bool _initialized = false;

  // Live server data
  List<RemoteGroup> _groups = [];
  RemoteGroup? _selectedGroup;
  List<RemoteMember> _members = [];
  List<RemoteMeeting> _meetings = [];
  RemoteNotifications _notifications =
      const RemoteNotifications(items: [], unreadCount: 0);
  RemoteUser? _signedInUser;
  StoredAccount? _account;
  String? _lastIdentifier;
  String? _lastRole;

  ApiCredentials get credentials => _credentials;
  ConnectionStatus get status => _status;
  String? get error => _error;
  bool get busy => _busy;
  bool get isConnected => _status == ConnectionStatus.connected;

  /// True once [bootstrap] has restored (or failed to restore) any stored
  /// session — the splash waits on this so a signed-in agent or member lands
  /// straight in their home screen instead of flashing the welcome screen.
  bool get initialized => _initialized;

  /// A live signed-in session (restored or fresh).
  bool get hasSession => isConnected && _signedInUser != null;

  /// Who this phone belongs to, from secure storage.
  ///
  /// Use this — not [hasSession] — to decide which app a person sees.
  /// [hasSession] is false whenever the phone is offline, because restoring a
  /// session re-validates it over the network; routing on it would lock a
  /// group out of its own record book the moment it lost signal.
  StoredAccount? get account => _account;

  /// Signed out, or never signed in on this phone.
  bool get isSignedOut => _account == null;

  /// The phone/email last used to sign in, for pre-filling the login form.
  String? get lastIdentifier => _lastIdentifier;

  /// Which kind of account last signed in here, so the form only pre-fills
  /// when the same kind is chosen again.
  String? get lastRole => _lastRole;

  /// This phone has been signed into before. Distinguishes "signed out" from
  /// "brand new phone": the first should be asked which account is signing
  /// in, the second should be offered account creation.
  bool get hasSignedInBefore =>
      _lastIdentifier != null && _lastIdentifier!.isNotEmpty;

  List<RemoteGroup> get groups => _groups;
  RemoteGroup? get selectedGroup => _selectedGroup;
  List<RemoteMember> get members => _members;
  List<RemoteMeeting> get meetings => _meetings;

  /// The server's currently-open meeting for the selected group, if any.
  ///
  /// Needed whenever something has to be recorded against a sitting on the
  /// backend: locally-created meetings carry a client-side UUID, which the
  /// server does not know, so the remote meeting is the only id it accepts.
  RemoteMeeting? get openRemoteMeeting {
    for (final meeting in _meetings) {
      if (meeting.status == 'OPEN' && !meeting.isClosed) return meeting;
    }
    return null;
  }
  RemoteNotifications get notifications => _notifications;
  int get unreadNotifications => _notifications.unreadCount;
  RemoteUser? get signedInUser => _signedInUser;

  Future<void> bootstrap() async {
    try {
      _credentials = await _store.load();
      _applyCredentials(_credentials);
      // Read who this phone belongs to BEFORE any network call, so routing
      // works on a phone with no signal.
      _account = await _store.loadAccount();
      _lastIdentifier = await _store.lastIdentifier();
      _lastRole = await _store.lastRole();
      if (_credentials.isConfigured) {
        await testConnection(silent: true);
      }
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  /// Persists a new connection (API-key mode) and verifies it.
  Future<bool> saveAndConnect({
    required String baseUrl,
    required String apiKey,
  }) async {
    _credentials = ApiCredentials(
      baseUrl: ApiConfig.normalize(baseUrl),
      apiKey: apiKey.trim(),
    );
    _applyCredentials(_credentials);
    await _store.save(_credentials);
    return testConnection();
  }

  /// Signs in with phone/email + password. The returned session token becomes
  /// the bearer credential (the backend accepts it as a Bearer), so the rest
  /// of the app uses the same authenticated client.
  Future<bool> signInWithPassword({
    required String baseUrl,
    required String identifier,
    required String password,
  }) async {
    _credentials =
        ApiCredentials(baseUrl: ApiConfig.normalize(baseUrl), apiKey: '');
    _applyCredentials(_credentials);
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.login(identifier, password);
      _credentials = _credentials.copyWith(apiKey: result.token);
      _applyCredentials(_credentials);
      await _store.save(_credentials);
      _signedInUser = result.user;
      await _rememberAccount(result.user, identifier);
      _groups = await _api.groups();
      await _selectGroup(_groups.isNotEmpty ? _groups.first : null);
      _notifications = await _safe(
        () => _api.notifications(),
        const RemoteNotifications(items: [], unreadCount: 0),
      );
      _status = ConnectionStatus.connected;
      _error = null;
      return true;
    } on ApiException catch (e) {
      _status = ConnectionStatus.error;
      _error = e.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Creates a new account (Group / Member / Agent) and signs straight in —
  /// the register response carries a session like a login.
  Future<bool> register({
    required String baseUrl,
    required String accountType,
    required String name,
    required String phone,
    required String password,
    String? email,
    String? county,
  }) async {
    _credentials =
        ApiCredentials(baseUrl: ApiConfig.normalize(baseUrl), apiKey: '');
    _applyCredentials(_credentials);
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _api.register(
        accountType: accountType,
        name: name,
        phone: phone,
        password: password,
        email: email,
        county: county,
      );
      _credentials = _credentials.copyWith(apiKey: result.token);
      _applyCredentials(_credentials);
      await _store.save(_credentials);
      _signedInUser = result.user;
      await _rememberAccount(result.user, phone);
      _groups = await _safe(() => _api.groups(), const []);
      await _selectGroup(_groups.isNotEmpty ? _groups.first : null);
      _status = ConnectionStatus.connected;
      _error = null;
      return true;
    } on ApiException catch (e) {
      _status = ConnectionStatus.error;
      _error = e.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Probes `/health`, then validates the key by listing groups (requires
  /// the `groups:read` scope that MOBILE_CORE keys carry) and loads the
  /// first group's detail.
  Future<bool> testConnection({bool silent = false}) async {
    if (!_credentials.isConfigured) {
      _status = ConnectionStatus.unconfigured;
      _error = 'Enter an API key to connect.';
      if (!silent) notifyListeners();
      return false;
    }
    _busy = true;
    _error = null;
    if (!silent) notifyListeners();
    try {
      await _api.health();
      _groups = await _api.groups();
      await _selectGroup(_groups.isNotEmpty ? _groups.first : null);
      _notifications = await _safe(
        () => _api.notifications(),
        const RemoteNotifications(items: [], unreadCount: 0),
      );
      _signedInUser = await _safe(() => _api.me(), _signedInUser);
      // Phones upgrading from a build that stored only the token have a live
      // session but no remembered role. Adopt it here rather than making
      // everyone sign in again on update; the identifier is unknown, and the
      // login form falls back to whatever it already had.
      final user = _signedInUser;
      if (_account == null && user != null) {
        await _rememberAccount(user, _lastIdentifier ?? '');
      }
      _status = ConnectionStatus.connected;
      _error = null;
      return true;
    } on ApiException catch (e) {
      _status = ConnectionStatus.error;
      _error = e.message;
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Re-pulls groups and the selected group's data.
  Future<void> refreshAll() async {
    if (!_credentials.isConfigured) return;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _groups = await _api.groups();
      final keepId = _selectedGroup?.id;
      final next = _groups.where((g) => g.id == keepId).firstOrNull ??
          (_groups.isNotEmpty ? _groups.first : null);
      await _selectGroup(next);
      _notifications = await _safe(
        () => _api.notifications(),
        _notifications,
      );
      _status = ConnectionStatus.connected;
    } on ApiException catch (e) {
      _status = ConnectionStatus.error;
      _error = e.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Switches the active group and loads its detail, members and meetings.
  Future<void> selectGroup(String groupId) async {
    final group = _groups.where((g) => g.id == groupId).firstOrNull;
    if (group == null) return;
    _busy = true;
    notifyListeners();
    try {
      await _selectGroup(group);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _selectGroup(RemoteGroup? group) async {
    if (group == null) {
      _selectedGroup = null;
      _members = [];
      _meetings = [];
      return;
    }
    // Detail carries fund balances, credit score and counts.
    _selectedGroup = await _safe(() => _api.groupDetail(group.id), group);
    _members = await _safe(() => _api.groupMembers(group.id), const []);
    _meetings = await _safe(() => _api.groupMeetings(group.id), const []);
  }

  Future<T> _safe<T>(Future<T> Function() call, T fallback) async {
    try {
      return await call();
    } on ApiException {
      return fallback;
    }
  }

  /// Clears the session because the SERVER rejected it, not because the person
  /// asked to leave.
  ///
  /// Skips the logout call: the credential is already dead, so telling the
  /// server to revoke it would just fail and delay the sign-out. Everything
  /// else matches [disconnect], so the phone lands on the sign-in screen the
  /// same way rather than sitting on a screen that can no longer load.
  ///
  /// Idempotent — several in-flight requests can each come back 401, and only
  /// the first should do any work.
  Future<void> handleSessionExpired() async {
    if (_status == ConnectionStatus.unconfigured && _signedInUser == null) return;
    await _clearSessionState();
    notifyListeners();
  }

  /// Signs out. Returns false when the server could not be told — the local
  /// session is cleared regardless, so the phone is safe to hand over, but the
  /// caller may want to say the session will end when signal returns.
  Future<bool> disconnect() async {
    // Revoke on the server FIRST, while the credential still works. Clearing
    // locally only would leave a live session behind on a shared handset.
    final revoked = await _api.logout();
    await _clearSessionState();
    notifyListeners();
    return revoked;
  }

  /// Everything that must be true once no one is signed in.
  ///
  /// Shared by [disconnect] and [handleSessionExpired] so the two cannot drift:
  /// a session ended by the server has to leave the phone in exactly the state
  /// a deliberate sign-out does, or the next person picks up a half-signed-in
  /// handset.
  Future<void> _clearSessionState() async {
    await _store.clear();
    _credentials = ApiCredentials(
      baseUrl: ApiConfig.defaultBaseUrl(),
      apiKey: '',
    );
    _applyCredentials(_credentials);
    _status = ConnectionStatus.unconfigured;
    _groups = [];
    _selectedGroup = null;
    _members = [];
    _meetings = [];
    _notifications = const RemoteNotifications(items: [], unreadCount: 0);
    _signedInUser = null;
    // Forget the role too, or the root would keep showing this account's app
    // to whoever picks the phone up next. The identifier survives so the login
    // form can be pre-filled.
    await _store.clearAccount();
    _account = null;
    _error = null;
  }

  /// Remembers the role so the next cold start can route without a network
  /// call. Never fatal: a phone whose secure storage refuses to write should
  /// still complete the sign-in it just did.
  Future<void> _rememberAccount(RemoteUser user, String identifier) async {
    final account = StoredAccount(
      role: user.role,
      name: user.name,
      identifier: identifier.trim(),
    );
    try {
      await _store.saveAccount(account);
    } catch (_) {
      // Ignored on purpose — see above.
    }
    _account = account;
    if (account.identifier.isNotEmpty) {
      _lastIdentifier = account.identifier;
      _lastRole = account.role;
    }
  }

  RemoteApi get api => _api;
}
