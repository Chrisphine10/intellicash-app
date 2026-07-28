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

  /// Signs out. Returns false when the server could not be told — the local
  /// session is cleared regardless, so the phone is safe to hand over, but the
  /// caller may want to say the session will end when signal returns.
  Future<bool> disconnect() async {
    // Revoke on the server FIRST, while the credential still works. Clearing
    // locally only would leave a live session behind on a shared handset.
    final revoked = await _api.logout();
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
    _error = null;
    notifyListeners();
    return revoked;
  }

  RemoteApi get api => _api;
}
