import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_config.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/models/remote/remote_models.dart';
import 'package:intellicash_mobile/data/services/module_switches.dart';
import 'package:intellicash_mobile/data/services/remote_api.dart';
import 'package:intellicash_mobile/providers/connection_provider.dart';

/// Sign-out waits for this phone's work to be sent. A group that signs out
/// with a meeting still on the phone strands it behind the next sign-in; the
/// rule is to sync first and refuse, saying why, when that is not possible.
class _FakeApi extends RemoteApi {
  _FakeApi({this.detail})
      : super(ApiClient(
          credentials: () => ApiCredentials(baseUrl: ApiConfig.defaultBaseUrl(), apiKey: ''),
        ));

  final RemoteGroup? detail;
  int logouts = 0;

  @override
  Future<({RemoteUser user, String token})> login(String identifier, String password) async => (
        user: const RemoteUser(id: 'u1', name: 'Umoja', role: 'GROUP_ACCOUNT', groupId: 'g1'),
        token: 't',
      );

  @override
  Future<List<RemoteGroup>> groups() async => detail == null ? const [] : [detail!];

  @override
  Future<RemoteGroup> groupDetail(String id) async => detail!;

  @override
  Future<List<RemoteMember>> groupMembers(String groupId) async => const [];

  @override
  Future<List<RemoteMeeting>> groupMeetings(String groupId) async => const [];

  @override
  Future<RemoteNotifications> notifications() async => const RemoteNotifications(items: [], unreadCount: 0);

  @override
  Future<bool> logout() async {
    logouts++;
    return true;
  }
}

RemoteGroup _group({Map<String, dynamic>? modules}) => RemoteGroup.fromJson({
      'id': 'g1',
      'name': 'Umoja',
      'code': 'IWL-KBU-0001',
      'phase': 'ACTIVE',
      'county': 'Kiambu',
      'shareValueCents': 50000,
      'maxSharesPerMemberPerMeeting': 5,
      'cycleNumber': 1,
      if (modules != null) 'modules': modules,
    });

void main() {
  late _FakeApi api;
  late int pending;
  late bool online;
  late int syncs;
  late int sentBySync;
  late bool syncThrows;

  ConnectionProvider build({Future<void> Function(String, GroupModules)? onModules}) => ConnectionProvider(
        store: CredentialStore(),
        api: api,
        applyCredentials: (_) {},
        pendingForSignOut: () async => pending,
        syncBeforeSignOut: () async {
          syncs++;
          if (syncThrows) throw StateError('server unreachable');
          pending -= sentBySync;
        },
        deviceOnline: () => online,
        onGroupModules: onModules,
      );

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    api = _FakeApi();
    pending = 0;
    online = true;
    syncs = 0;
    sentBySync = 0;
    syncThrows = false;
  });

  Future<ConnectionProvider> signedIn() async {
    final connection = build();
    expect(
      await connection.signInWithPassword(baseUrl: ApiConfig.defaultBaseUrl(), identifier: '0712000001', password: 'pw'),
      isTrue,
    );
    return connection;
  }

  group('signOut', () {
    test('with nothing waiting, signs out even with no signal', () async {
      final connection = await signedIn();
      online = false;

      final result = await connection.signOut();

      expect(result.signedOut, isTrue);
      expect(syncs, 0);
      expect(connection.signedInUser, isNull);
    });

    test('with work waiting and no signal, is refused and nothing is synced', () async {
      final connection = await signedIn();
      pending = 3;
      online = false;

      final result = await connection.signOut();

      expect(result.outcome, SignOutOutcome.pendingOffline);
      expect(result.pending, 3);
      expect(syncs, 0);
      expect(api.logouts, 0);
      expect(connection.signedInUser, isNotNull, reason: 'still signed in');
    });

    test('with work waiting and signal, syncs first and then signs out', () async {
      final connection = await signedIn();
      pending = 2;
      sentBySync = 2;

      final result = await connection.signOut();

      expect(syncs, 1);
      expect(result.signedOut, isTrue);
      expect(api.logouts, 1);
    });

    test('is refused when the sync could not send everything', () async {
      final connection = await signedIn();
      pending = 2;
      sentBySync = 1; // e.g. a meeting still open

      final result = await connection.signOut();

      expect(result.outcome, SignOutOutcome.pendingAfterSync);
      expect(result.pending, 1);
      expect(connection.signedInUser, isNotNull);
    });

    test('is refused, not crashed, when the server cannot be reached', () async {
      final connection = await signedIn();
      pending = 1;
      syncThrows = true;

      final result = await connection.signOut();

      expect(result.outcome, SignOutOutcome.pendingAfterSync);
      expect(connection.signedInUser, isNotNull);
    });

    test('disconnect() itself is not gated (wrong-book and no-book screens use it)', () async {
      final connection = await signedIn();
      pending = 5;
      online = false;

      await connection.disconnect();

      expect(connection.signedInUser, isNull);
    });
  });

  group('module switches', () {
    test('are off for a group the phone has never heard about', () {
      final switches = ModuleSwitches();
      final modules = switches.forRemoteGroup('unknown');
      expect(modules.store, isFalse);
      expect(modules.voting, isFalse);
      expect(switches.forRemoteGroup(null).voting, isFalse);
    });

    test('are learned from the group detail and survive a restart offline', () async {
      api = _FakeApi(detail: _group(modules: {'store': false, 'voting': true}));
      final switches = ModuleSwitches();
      final connection = build(onModules: switches.remember);
      await connection.signInWithPassword(baseUrl: ApiConfig.defaultBaseUrl(), identifier: '0712000001', password: 'pw');

      expect(switches.forRemoteGroup('g1').voting, isTrue);
      expect(switches.forRemoteGroup('g1').store, isFalse);

      final afterRestart = ModuleSwitches();
      await afterRestart.load();
      expect(afterRestart.forRemoteGroup('g1').voting, isTrue);
    });

    test('an older server that says nothing leaves the last answer alone', () async {
      final switches = ModuleSwitches();
      await switches.remember('g1', const GroupModules(store: true));
      api = _FakeApi(detail: _group());
      final connection = build(onModules: switches.remember);
      await connection.signInWithPassword(baseUrl: ApiConfig.defaultBaseUrl(), identifier: '0712000001', password: 'pw');

      expect(switches.forRemoteGroup('g1').store, isTrue);
    });

    test('resolve through the book\'s link to its server group', () async {
      final switches = ModuleSwitches(remoteIdFor: (local) async => local == 'book-1' ? 'g1' : null);
      await switches.remember('g1', const GroupModules(voting: true));

      expect((await switches.forLocalGroup('book-1')).voting, isTrue);
      expect((await switches.forLocalGroup('unlinked-book')).voting, isFalse);
    });
  });
}
