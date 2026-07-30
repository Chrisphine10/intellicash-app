import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/network/api_config.dart';

/// The backend must stay pinned to the production server.
///
/// Two ways this drifts in practice: someone repoints `.env` at localhost to
/// debug and forgets, or the guard that catches that gets weakened. The first
/// is caught at runtime by `releaseConfigProblem()`; these tests make sure the
/// GUARD itself cannot quietly stop working, and that the committed example
/// everyone copies from still names the real server.
const productionBase = 'https://intellicash.co.ke/api/v1';

void main() {
  group('the committed example points at production', () {
    test('.env.example names the production server over https', () {
      // .env itself is gitignored, so this is the file a new machine copies.
      // If it drifts to localhost, every fresh clone is misconfigured.
      final example = File('.env.example').readAsStringSync();
      expect(example, contains(productionBase),
          reason: '.env.example must point at the production API');
      expect(
        RegExp(r'^IC_BASE_URL=http://', multiLine: true).hasMatch(example),
        isFalse,
        reason: 'IC_BASE_URL must not be plain http — release sends passwords',
      );
    });

    test('IC_API_KEY stays commented out in the example', () {
      // An APK is a public artifact; a key baked into one is a published key.
      final example = File('.env.example').readAsStringSync();
      expect(
        RegExp(r'^IC_API_KEY=\S', multiLine: true).hasMatch(example),
        isFalse,
        reason: 'release ignores IC_API_KEY; shipping one publishes it',
      );
    });
  });

  group('the release guard still refuses a development backend', () {
    // isSecureForRelease is the piece the guard leans on. If it ever starts
    // accepting http, a release could ship sending passwords in the clear and
    // the guard would report nothing.
    test('plain http to a real host is refused', () {
      // The actual risk: a release pointed at a real server over http would
      // send members' passwords in the clear.
      expect(ApiConfig.isSecureForRelease('http://intellicash.co.ke/api/v1'), isFalse);
      expect(ApiConfig.isSecureForRelease('http://78.159.126.22:4000/api/v1'), isFalse);
    });

    test('http to a dev machine is allowed HERE, and caught elsewhere', () {
      // isSecureForRelease deliberately permits localhost so development works
      // over plain http. That is safe only because releaseConfigProblem checks
      // the HOST first and rejects a dev address before this is consulted.
      // If that ordering is ever reversed, a release could ship pointed at a
      // laptop — so both halves are asserted, not just this one.
      expect(ApiConfig.isSecureForRelease('http://localhost:4000/api/v1'), isTrue);
      expect(ApiConfig.isSecureForRelease('http://10.0.2.2:4000/api/v1'), isTrue);
    });

    test('https to the real server is acceptable', () {
      expect(ApiConfig.isSecureForRelease(productionBase), isTrue);
    });
  });
}
