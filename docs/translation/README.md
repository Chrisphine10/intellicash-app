# Reviewing the translations

All five languages are now at **421 of 421 strings**. Nothing falls back to
English any more.

| Language | Strings | Reviewed by a speaker? |
|---|---|---|
| English | 421 | source |
| Kiswahili | 421 | yes |
| Gĩkũyũ | 421 | **no** |
| Dholuo | 421 | **no** |
| Kĩembu | 421 | **no**, and mostly derived — see below |

## Why "complete" is not the same as "finished"

While a language was half-translated, a word nobody was sure about simply
showed in English. That was ugly but safe: the gap announced itself.

Now there are no gaps. Every screen is full of Gĩkũyũ, Dholuo or Kĩembu — and
a word that is grammatical but *wrong* looks exactly as confident as a word
that is right. In a savings ledger that matters: if "mkopo" and "akiba" get
swapped, a group can disagree about who owes what and the app will look sure
of itself the whole time.

So these three ship as **drafts**. The picker says so, each `.arb` says so in
its `_comment`, and a test fails the build if that stops being said.

**Kĩembu especially.** Most of its entries were derived from the Gĩkũyũ file
by dropping the ĩ/ũ diacritics — the register the original Kĩembu entries in
that file already used. The two languages are close, but they are not the same
language, and nobody who speaks Kĩembu has read this.

## How to review

Open the CSV for your language. One row per string:

| column | meaning |
|---|---|
| `key` | leave alone — it is how the app finds the string |
| `english` | the original |
| `kiswahili_for_reference` | a second reading, in case the English is unclear |
| `<language>_draft` | **what the app says today** |
| `<language>_corrected` | fill in only if the draft is wrong |
| `ok_as_is` | put `y` if the draft is fine |

Leave both last columns blank for anything you are unsure about and we will
come back to it. A row you correct replaces the draft; a row you mark `y` is
recorded as checked.

Things to keep exactly as they are:

- `{officials}`, `{members}`, `{paidOut}`, `{cycle}`, `{max}`, `{fields}` — the
  app puts a number or a name there. Move them within the sentence to wherever
  your language wants them, but do not rename or delete them.
- `KSh`, `M-Pesa`, `Intelli-Cash`, `Intelli-Store`, `PIN`, `SMS`, `VSLA`.
- Line breaks written as `\n`.

Keep it short. These are phone screens; a label that runs to three lines pushes
the buttons off the bottom on a small handset.

## Loading a reviewed file back in

```bash
python tool/import_translations.py docs/translation/luo-to-review.csv
flutter gen-l10n
flutter test test/core/translation_coverage_test.dart
```

Once a speaker has been through a language, change its `state` to
`TranslationState.ready` in `lib/providers/locale_controller.dart`. That is the
only thing that removes the "draft" badge, and the test suite checks that only
reviewed languages claim it.

## Words to keep consistent

| English | Kiswahili | Gĩkũyũ | Dholuo |
|---|---|---|---|
| savings | akiba | ũigi | pesa mokan |
| shares | hisa | hisa | hisa |
| loan | mkopo | mũkopo | hola |
| repayment | marejesho | irĩhi | chulo |
| member | mwanachama | mũmemba | jamembe |
| group | kikundi | gĩkundi | riwruok |
| meeting | mkutano | mũcemanio | chokruok |
| welfare fund | mfuko wa jamii | mũthithũ wa ũteithio | sanduk mar kony |
| fine | faini | faini | chudo |
| cycle | mzunguko | mũthiũrũrũko | ndalo |
| share-out | mgao | kũgayana | pogruok |
| attendance | mahudhurio | ũkinyu | bedo e chokruok |
| vote | kura | itua | yiero |
| report | ripoti | ripoti | ripot |

If a reviewer prefers a different word for any of these, change it everywhere
rather than in one screen — the same English word appearing as two different
words across the app is how a group loses trust in the book.
