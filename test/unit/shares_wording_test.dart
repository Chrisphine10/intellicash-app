import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// "Shares" is the standard word for what members put into the group (decided
/// 26 Sep 2026). "Savings" read as a different figure from the one the server
/// reports and was the source of "my total savings does not match". This
/// fails if the word comes back into a user-visible string.
void main() {
  // Keys where "saving" means storing data, not money.
  const allowed = {'enterpriseSaving'};

  Map<String, String> strings(String lang) {
    final raw = jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;
    return {
      for (final entry in raw.entries)
        if (!entry.key.startsWith('@') && entry.value is String) entry.key: entry.value as String,
    };
  }

  test('English strings say shares, not savings', () {
    final offenders = strings('en').entries
        .where((e) => !allowed.contains(e.key) && e.value.toLowerCase().contains('saving'))
        .map((e) => e.key)
        .toList();
    expect(offenders, isEmpty);
  });

  test('Kiswahili strings say hisa, not akiba', () {
    final offenders = strings('sw').entries
        .where((e) => e.value.toLowerCase().contains('akiba'))
        .map((e) => e.key)
        .toList();
    expect(offenders, isEmpty);
  });

  test('no screen hard-codes "savings" in a label', () {
    // A word inside a string, not an identifier such as `m.savings`.
    final pattern = RegExp(r"""['"][^'"\n]*(?<![\w.$])[Ss]avings\b[^'"\n]*['"]""");
    final offenders = <String>[];
    for (final file in Directory('lib/features').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final line in file.readAsLinesSync()) {
        final code = line.trimLeft();
        if (code.startsWith('//') || code.startsWith('///')) continue;
        if (pattern.hasMatch(line)) offenders.add('${file.path}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty);
  });
}
