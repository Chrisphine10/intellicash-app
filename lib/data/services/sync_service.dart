import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/sync_repository.dart';

/// Pushes the offline queue to the Intelli-Cash backend
/// (`POST /sync/push`, see docs/API_SPECIFICATION.md) whenever
/// connectivity returns or the user taps "Sync now".
///
/// The queue survives failed pushes untouched — records are only removed
/// once the server accepts the batch.
class SyncService {
  SyncService(this._syncRepository, {http.Client? client})
      : _http = client ?? http.Client();

  static const _baseUrlPref = 'sync_base_url';
  static const defaultBaseUrl = 'https://api.intellicash.com/api/v1';

  final SyncRepository _syncRepository;
  final http.Client _http;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  void Function()? onQueueChanged;

  /// What actually pushes local writes to the backend when connectivity
  /// returns or the user taps "Sync now".
  ///
  /// The app wires this to the proven, idempotent per-meeting write-sync (see
  /// `WriteSyncService`), which posts to real endpoints and is safe to re-run.
  /// When it is null the service falls back to draining the generic queue —
  /// kept only so the low-level repository tests still exercise `drain`.
  Future<int> Function()? onSync;

  /// How many local changes are still waiting to reach the backend — the
  /// number the "waiting to back up" badge shows.
  ///
  /// Wired to the real sync model (unsynced closed meetings), so the badge
  /// tracks actual progress and clears as meetings go through. When null the
  /// service falls back to the raw queue count for the low-level tests.
  Future<int> Function()? pendingProbe;

  /// True whenever a sync is in flight, so a burst of connectivity events
  /// (a flaky signal reconnecting repeatedly) cannot stack pushes on top of
  /// each other and double-submit.
  bool _syncing = false;

  void startWatchingConnectivity() {
    if (_connectivitySub != null) return;
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen(
        (results) {
          final online = results.any((r) => r != ConnectivityResult.none);
          if (online) {
            unawaited(pushNow());
          }
        },
        // Platform channel unavailable (e.g. tests) — manual sync still works.
        onError: (Object _) {},
      );
    } catch (_) {
      _connectivitySub = null;
    }
  }

  Future<String> baseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlPref) ?? defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlPref, url.trim());
  }

  Future<int> pendingCount() async =>
      pendingProbe != null ? await pendingProbe!() : _syncRepository.pendingCount();

  /// Attempts a push. Returns the number of records synced (0 when offline,
  /// there is nothing to send, or the server is unreachable).
  ///
  /// Re-entrancy guarded: if a sync is already running (a reconnect fired
  /// while the last push was still going) this returns 0 rather than starting
  /// a second, overlapping push.
  Future<int> pushNow() async {
    if (_syncing) return 0;
    _syncing = true;
    try {
      final synced = onSync != null ? await _pushViaCallback() : await _pushViaQueue();
      if (synced > 0) onQueueChanged?.call();
      return synced;
    } finally {
      _syncing = false;
    }
  }

  Future<int> _pushViaCallback() async {
    try {
      return await onSync!();
    } catch (_) {
      // Offline or the server rejected the batch — local writes are untouched
      // and the next reconnect tries again.
      return 0;
    }
  }

  /// Fallback for the low-level tests only: drains the generic queue to a
  /// batch endpoint. The app itself wires [onSync] to the real write-sync.
  Future<int> _pushViaQueue() async {
    final url = await baseUrl();
    return _syncRepository.drain((batch) async {
      try {
        final response = await _http
            .post(
              Uri.parse('$url/sync/push'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'operations': batch}),
            )
            .timeout(const Duration(seconds: 15));
        return response.statusCode >= 200 && response.statusCode < 300;
      } catch (_) {
        return false; // offline or unreachable — keep the queue intact
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
    _http.close();
  }
}
