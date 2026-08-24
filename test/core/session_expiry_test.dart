import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/core/network/api_exception.dart';

/// A session the server has ended must end on the phone too.
///
/// `ApiException.isUnauthorized` existed and was read by nobody, so a 401
/// surfaced as an ordinary error on whatever screen was open: the phone kept
/// believing it was signed in, every later call failed the same way, and there
/// was no route back to signing in. These assert the hook fires when it should
/// and — just as important — stays quiet when it should not.
void main() {
  ApiClient clientReturning(int status, {String body = '{"error":{"code":"X"}}'}) {
    return ApiClient(
      credentials: () => ApiCredentials(baseUrl: 'https://example.test/api/v1', apiKey: ''),
      httpClient: MockClient((_) async => http.Response(body, status)),
    );
  }

  test('fires when an authenticated call is rejected', () async {
    var expired = 0;
    final client = clientReturning(401)..onSessionExpired = () => expired += 1;

    await expectLater(client.getData('/groups'), throwsA(isA<ApiException>()));
    expect(expired, 1);
  });

  test('stays quiet for every other failure', () async {
    // A 403 is "not allowed", a 404 is "not there", a 500 is the server's
    // problem. None of them mean the session is gone, and signing someone out
    // over one would lose whatever they were doing.
    for (final status in [400, 403, 404, 429, 500]) {
      var expired = 0;
      final client = clientReturning(status)..onSessionExpired = () => expired += 1;
      await expectLater(client.getData('/groups'), throwsA(isA<ApiException>()));
      expect(expired, 0, reason: 'status $status must not end the session');
    }
  });

  test('does not fire when a sign-in is refused', () async {
    // A wrong password is not an expired session. Treating it as one would
    // clear the stored account of whoever was signed in before.
    var expired = 0;
    final client = clientReturning(401, body: jsonEncode({'error': {'code': 'INVALID_CREDENTIALS'}}))
      ..onSessionExpired = () => expired += 1;

    await expectLater(
      client.login(identifier: 'someone@example.test', password: 'wrong'),
      throwsA(isA<ApiException>()),
    );
    expect(expired, 0);
  });

  test('a 401 still reaches the caller as an error', () async {
    // Signing out must not swallow the failure: the screen that made the call
    // still needs to stop what it was doing.
    final client = clientReturning(401)..onSessionExpired = () {};
    await expectLater(
      client.getData('/groups'),
      throwsA(predicate((e) => e is ApiException && e.isUnauthorized)),
    );
  });
}
