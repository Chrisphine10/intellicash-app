import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/network/api_config.dart';

/// The release APK bundles `.env`, so whatever is on the build machine ships
/// to every phone. These pin the rules that stop a development configuration
/// — or a plaintext one — reaching members.
void main() {
  group('isSecureForRelease', () {
    test('accepts https anywhere', () {
      expect(ApiConfig.isSecureForRelease('https://api.intellicash.co.ke/api/v1'), isTrue);
    });

    test('accepts plain http only against this machine', () {
      // These are the development hosts: the emulator's loopback and the
      // desktop's own. Nothing leaves the device.
      for (final url in [
        'http://localhost:4000/api/v1',
        'http://127.0.0.1:4000/api/v1',
        'http://10.0.2.2:4000/api/v1',
      ]) {
        expect(ApiConfig.isSecureForRelease(url), isTrue, reason: url);
      }
    });

    test('refuses plain http to a real host', () {
      // A member's password and session token would go out in clear.
      for (final url in [
        'http://api.intellicash.co.ke/api/v1',
        'http://192.168.1.50:4000/api/v1',
        'http://41.90.64.10/api/v1',
      ]) {
        expect(ApiConfig.isSecureForRelease(url), isFalse, reason: url);
      }
    });
  });

  group('normalize', () {
    test('keeps https rather than downgrading it', () {
      expect(
        ApiConfig.normalize('https://api.intellicash.co.ke'),
        'https://api.intellicash.co.ke/api/v1',
      );
    });

    test('adds the api prefix once, not twice', () {
      expect(
        ApiConfig.normalize('https://api.intellicash.co.ke/api/v1'),
        'https://api.intellicash.co.ke/api/v1',
      );
      expect(
        ApiConfig.normalize('https://api.intellicash.co.ke/api/v1/'),
        'https://api.intellicash.co.ke/api/v1',
      );
    });
  });

  group('release safeguards in a debug test run', () {
    test('reports no problem outside release mode', () {
      // The checks only bite in a release build; a test run must not trip on
      // its own development configuration.
      expect(ApiConfig.releaseConfigProblem(), isNull);
    });

    test('a bundled key is still available to development builds', () {
      // Only release ignores it — dev convenience is preserved.
      expect(() => ApiConfig.envApiKey(), returnsNormally);
    });
  });
}
