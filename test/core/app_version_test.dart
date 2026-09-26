import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/features/account/account_route.dart';

/// The version the Account screen shows is a constant, so support can read
/// it off a phone. It fell two builds behind once (it said 2.6.1 (24) on
/// 2.6.2+25); this keeps it equal to what pubspec.yaml ships.
void main() {
  test('the Account screen shows the version in pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)\+(\d+)\s*$', multiLine: true).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(AccountRoute.appVersion, '${match!.group(1)} (${match.group(2)})');
  });
}
