# Finishing the translations

The app now has **420 translatable strings**. English and Kiswahili are
complete. Gĩkũyũ, Dholuo and Kĩembu are partial, and this folder is what a
native speaker needs to finish them.

## Why they are partial

Nobody on this side speaks them well enough to write a savings ledger in them.
Guessing was the wrong call: a group reads "mkopo" and "akiba" to decide who
owes what, and a plausible-but-wrong word in that context costs somebody money.
Everything not translated falls back to English, the picker says "partly
translated", and each `.arb` carries a `_comment` saying the same. That is
honest; a confident guess would not be.

## What to do

1. Open the CSV for your language. Each row is one string:

   | column | meaning |
   |---|---|
   | `key` | leave alone — it is how the app finds the string |
   | `english` | the original |
   | `kiswahili_for_reference` | how it was rendered in Kiswahili, as a guide |
   | `<language>_translation` | **fill this in** |

2. Leave a row blank if you are not sure. Blank falls back to English, which is
   far better than a wrong word.

3. Things to keep exactly as they are:
   - `{officials}`, `{members}`, `{paidOut}`, `{cycle}`, `{max}`, `{fields}` —
     the app puts a number or a name there. Move them within the sentence to
     wherever your language wants them, but do not rename or delete them.
   - `KSh`, `M-Pesa`, `Intelli-Cash`, `Intelli-Store`, `PIN`, `SMS`.
   - Line breaks written as `\n`.

4. Keep it short. These are phone screens; a label that runs to three lines
   pushes the buttons off the bottom on a small handset.

## Loading a finished file back in

```bash
python tool/import_translations.py docs/translation/luo-to-translate.csv
flutter gen-l10n
flutter test test/core/translation_coverage_test.dart
```

When a language reaches 100%, flip `complete: true` for it in
`lib/providers/locale_controller.dart`. The test suite enforces that: a
language claiming completeness while missing strings fails the build, so the
picker can never promise more than the app delivers.

## The vocabulary already agreed

These recur throughout and should be translated the same way every time.

| English | Kiswahili |
|---|---|
| savings | akiba |
| shares | hisa |
| loan | mkopo |
| repayment | marejesho |
| member | mwanachama |
| group | kikundi |
| meeting | mkutano |
| social / welfare fund | mfuko wa jamii |
| fine | faini |
| cycle | mzunguko |
| share-out | mgao |
| attendance | mahudhurio |
| vote | kura |
| report | ripoti |
