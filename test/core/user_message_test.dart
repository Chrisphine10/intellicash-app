import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/network/api_exception.dart';
import 'package:intellicash_mobile/core/utils/domain_exception.dart';
import 'package:intellicash_mobile/core/utils/user_message.dart';

void main() {
  test("the app's own errors keep their sentence", () {
    expect(userMessage(const ApiException('Welfare is paid out during an open meeting.')),
        'Welfare is paid out during an open meeting.');
    expect(userMessage(const DomainException('Repayment must be above zero.')), 'Repayment must be above zero.');
  });

  test('a lost connection says so in words, not as a SocketException', () {
    final message = userMessage(const SocketException('Failed host lookup'));
    expect(message, contains('Check your internet connection'));
    expect(message, isNot(contains('SocketException')));
    expect(userMessage(TimeoutException('slow')), contains('internet connection'));
  });

  test('anything else is a plain sentence, never raw exception text', () {
    final message = userMessage(const FormatException('Unexpected character (at character 1)'));
    expect(message, isNot(contains('FormatException')));
    expect(message, contains('Please try again'));
  });
}
