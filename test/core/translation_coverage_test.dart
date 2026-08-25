import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/providers/locale_controller.dart';

/// Guards the thing that actually broke: not the language plumbing, which was
/// always sound, but the fact that almost nothing was routed through it.
///
/// The app shipped a five-language picker while 400-odd labels sat in the
/// widgets as English literals, so choosing Gikuyu changed a handful of words
/// and left the rest of the screen in English. Nothing failed, nothing warned
/// — it simply did not translate. These tests make that state fail loudly.

File _arb(String code) => File('lib/l10n/app_$code.arb');

Map<String, String> _keysOf(String code) {
  final raw = jsonDecode(_arb(code).readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final entry in raw.entries)
      if (!entry.key.startsWith('@') && entry.key != '_comment')
        entry.key: entry.value as String,
  };
}

/// Every Dart file that draws something, which is where copy leaks in.
Iterable<File> get _uiSources => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .where((f) => !f.path.replaceAll(r'\', '/').contains('/l10n/'));

void main() {
  final english = _keysOf('en');

  group('the English template', () {
    test('covers the whole app, not a corner of it', () {
      // 83 was the count when five languages were already on offer. The floor
      // is deliberately near today's number: it should only ever go up, and a
      // drop means somebody deleted keys rather than translated them.
      expect(english.length, greaterThan(300),
          reason: 'the template should hold every user-visible string');
    });

    test('has no key that nothing reads', () {
      final source = _uiSources.map((f) => f.readAsStringSync()).join('\n');
      final orphans = english.keys
          .where((key) => !RegExp('\\bl10n\\.$key\\b').hasMatch(source))
          .toList();

      expect(orphans, isEmpty,
          reason: 'unused keys ask translators to work for nothing');
    });
  });

  group('each shipped language', () {
    for (final language in AppLanguage.values) {
      test('${language.englishName} has no key the template lacks', () {
        final strays =
            _keysOf(language.code).keys.where((k) => !english.containsKey(k));
        expect(strays, isEmpty,
            reason: 'a key with no English original can never be shown');
      });

      test('${language.englishName} tells the truth about being complete', () {
        final translated = _keysOf(language.code);
        if (language.complete) {
          final missing =
              english.keys.where((k) => !translated.containsKey(k)).toList();
          expect(missing, isEmpty,
              reason: '${language.code} claims complete=true, so every string '
                  'must be translated — otherwise the picker lies and the '
                  'screen silently falls back to English');
        } else {
          // A partial language is fine; claiming otherwise is not. It must
          // still carry the note explaining that the gaps are deliberate.
          final raw = jsonDecode(_arb(language.code).readAsStringSync())
              as Map<String, dynamic>;
          final note = raw['_comment'] ?? '';
          expect('$note'.toUpperCase(), contains('PARTIAL'),
              reason: 'a partly translated file should say so in the file, '
                  'not only in the picker');
        }
      });
    }
  });

  test('screens do not go back to hard-coded English', () {
    // The literal forms the extraction pass removed. If one reappears, the
    // string is invisible to every language at once — which is exactly how
    // the app arrived at 83 translatable strings out of 400.
    final literal = RegExp(
      r"""(?:const\s+)?Text\(\s*(['"])([^'"$\\]{4,})\1""",
      multiLine: true,
    );

    final offenders = <String>[];
    for (final file in _uiSources) {
      final path = file.path.replaceAll(r'\', '/');
      // PDF builders and static catalogues have no BuildContext to read from;
      // they are localised by passing strings in, not by a lookup.
      if (path.contains('/reports/pdf_') ||
          path.contains('/reports/member_pdf') ||
          path.contains('mentorship_catalogue')) {
        continue;
      }
      for (final match in literal.allMatches(file.readAsStringSync())) {
        final text = match.group(2)!;
        // Words, not identifiers, codes or format patterns.
        if (RegExp(r'^[A-Z][a-z]').hasMatch(text) && text.contains(' ')) {
          offenders.add('$path: "$text"');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'these should read from L10n so every language gets them:\n'
            '${offenders.join('\n')}');
  });
}
