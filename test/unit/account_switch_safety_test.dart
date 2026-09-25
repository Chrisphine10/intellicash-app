import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_config.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/models/remote/remote_models.dart';
import 'package:intellicash_mobile/data/services/member_matching.dart';
import 'package:intellicash_mobile/data/services/remote_api.dart';
import 'package:intellicash_mobile/providers/connection_provider.dart';

/// The phone's record book is often the only copy of a meeting: recorded
/// offline, not yet sent. These tests hold the rules that keep it:
///
///  * ending a session (a 401, or signing out) never touches the book;
///  * signing in as the same account keeps it, however the number is spelled;
///  * signing in as a different account refuses while anything is unsent, and
///    clears the book only after a copy of it has been written.
class _FakeApi extends RemoteApi {
  _FakeApi()
      : super(ApiClient(
          credentials: () => ApiCredentials(baseUrl: ApiConfig.defaultBaseUrl(), apiKey: ''),
        ));

  final List<String> logins = [];

  @override
  Future<({RemoteUser user, String token})> login(String identifier, String password) async {
    logins.add(identifier);
    return (
      user: RemoteUser(id: 'u-$identifier', name: 'User $identifier', role: 'VILLAGE_AGENT'),
      token: 'token-$identifier',
    );
  }

  @override
  Future<List<RemoteGroup>> groups() async => const [];

  @override
  Future<RemoteNotifications> notifications() async =>
      const RemoteNotifications(items: [], unreadCount: 0);

  @override
  Future<bool> logout() async => true;
}

class _Book {
  int pending = 0;
  bool archiveFails = false;
  int archives = 0;
  int clears = 0;
  int syncs = 0;

  /// What a successful sync of the old account sends (and so stops pending).
  int sentBySync = 0;
}

void main() {
  late _FakeApi api;
  late _Book book;
  late ConnectionProvider connection;

  ConnectionProvider build() => ConnectionProvider(
        store: CredentialStore(),
        api: api,
        applyCredentials: (_) {},
        pendingLocalWork: () async => book.pending,
        syncPreviousAccount: () async {
          book.syncs++;
          book.pending -= book.sentBySync;
          return book.sentBySync;
        },
        archiveLocalWorkspace: () async {
          if (book.archiveFails) throw StateError('disk full');
          book.archives++;
        },
        clearLocalWorkspace: () async => book.clears++,
      );

  Future<bool> signIn(String identifier) =>
      connection.signInWithPassword(baseUrl: ApiConfig.defaultBaseUrl(), identifier: identifier, password: 'pw');

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = _FakeApi();
    book = _Book();
    connection = build();
  });

  group('ending a session never clears the book', () {
    test('an expired session (401) leaves unsent work in place', () async {
      expect(await signIn('0712000001'), isTrue);
      book.pending = 3;

      await connection.handleSessionExpired();

      expect(book.clears, 0);
      expect(book.archives, 0);
      expect(connection.signedInUser, isNull, reason: 'the session itself is still ended');
    });

    test('signing out leaves the book in place', () async {
      expect(await signIn('0712000001'), isTrue);
      book.pending = 1;

      await connection.disconnect();

      expect(book.clears, 0);
      expect(book.archives, 0);
    });
  });

  group('signing in again', () {
    test('as the same account, spelled differently, keeps the book', () async {
      expect(await signIn('0712000001'), isTrue);
      await connection.disconnect();
      book.pending = 5;

      expect(await signIn('+254 712 000 001'), isTrue);

      expect(book.clears, 0);
      expect(api.logins, hasLength(2));
    });

    test('as the same email account, in other capitals, keeps the book', () async {
      expect(await signIn('agent@example.org'), isTrue);
      await connection.disconnect();
      book.pending = 2;

      expect(await signIn(' Agent@Example.org '), isTrue);

      expect(book.clears, 0);
    });

    test('as another account is refused while work is unsent after sign-out', () async {
      expect(await signIn('0712000001'), isTrue);
      await connection.disconnect();
      book.pending = 2; // e.g. a meeting still open

      expect(await signIn('0712000002'), isFalse);

      expect(connection.errorCode, 'LOCAL_DATA_PENDING');
      expect(book.clears, 0);
      expect(book.archives, 0);
      expect(api.logins, ['0712000001'], reason: 'the new account must not even be asked');
    });

    test('from an email account to another account is protected too', () async {
      expect(await signIn('agent@example.org'), isTrue);
      await connection.disconnect();
      book.pending = 1;

      expect(await signIn('other@example.org'), isFalse);
      expect(book.clears, 0);
    });

    test('as another account first sends the old account\'s work while it is signed in', () async {
      expect(await signIn('0712000001'), isTrue);
      book.pending = 2;
      book.sentBySync = 2;

      expect(await signIn('0712000002'), isTrue);

      expect(book.syncs, 1);
      expect(book.archives, 1);
      expect(book.clears, 1);
    });

    test('is refused, and nothing cleared, when the copy cannot be written', () async {
      expect(await signIn('0712000001'), isTrue);
      await connection.disconnect();
      book.archiveFails = true;

      expect(await signIn('0712000002'), isFalse);

      expect(connection.errorCode, 'LOCAL_ARCHIVE_FAILED');
      expect(book.clears, 0);
    });

    test('with nothing unsent, archives before clearing and then signs in', () async {
      expect(await signIn('0712000001'), isTrue);
      await connection.disconnect();

      expect(await signIn('0712000002'), isTrue);

      expect(book.archives, 1);
      expect(book.clears, 1);
      expect(connection.signedInUser?.id, 'u-0712000002');
    });
  });

  group('accountIdentityKey', () {
    test('gives every spelling of a Kenyan number one key', () {
      const spellings = ['0712000001', '+254712000001', '254 712 000 001', '712000001', '00254712000001'];
      expect(spellings.map(accountIdentityKey).toSet(), {'254712000001'});
    });

    test('compares emails as lower-case text rather than as empty phones', () {
      expect(accountIdentityKey(' Agent@Example.org '), 'agent@example.org');
      expect(accountIdentityKey('a@x.org'), isNot(accountIdentityKey('b@x.org')));
      expect(accountIdentityKey('a@x.org'), isNotEmpty);
    });

    test('is empty only for an empty identifier', () {
      expect(accountIdentityKey(null), '');
      expect(accountIdentityKey('   '), '');
    });
  });
}
