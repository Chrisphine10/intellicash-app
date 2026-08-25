# Intelli-Cash 2.5.0 (build 15)

Released 25 August 2026. Previous store build: 2.4.2 (14).

## For the Play Store listing

> Field officers can now record every business a group runs, not just one — and
> where each one sells, who buys from it, and what it needs to grow. The app is
> also fully translated into Kiswahili, with Gĩkũyũ, Dholuo and Kĩembu still
> being checked by speakers.

## What changed

### Several businesses per group

A group running a poultry unit and a cereal store previously had to overwrite
one to record the other. Both now sit side by side, each with its own revenue,
costs, margin and history — averaging two businesses with different buyers
produced a figure that described neither.

### Where a business sells

New to the visit: how far the produce actually travels — from the farm gate up
to export — how many buyers there were last month, which channels they sell
through, and whether there is a written agreement with a buyer.

Reach is picked from a list rather than typed, so a group moving from selling
locally to selling into the county shows up as real movement instead of a
changed word. Selling months are recorded too, so a quiet off-season month is
not read back in the office as a failing business.

"Not asked" stays a separate answer from "no" throughout. A question nobody put
to the group is not the same as the group saying no.

### What a group needs

Support needs are chosen from a set list — finance, market, skills, inputs,
infrastructure, governance, technology — with the group's own ranking of how
urgent it is. Picking from a list rather than typing a sentence is what makes
"twelve groups need cold storage" a fact somebody can act on.

### Language

Kiswahili covers the whole app. Gĩkũyũ, Dholuo and Kĩembu carry every screen,
and the picker says plainly that a speaker has not checked them yet.

Forty new strings in this release are still in English in those three
languages, on purpose: several are market terms — cold chain, offtake
agreement, aggregation — where a guessed word reads as confidently as a correct
one. They are queued in `docs/translation/*-to-review.csv` with a blank column
for a speaker to fill in.

## Also in this release

- A backslash that appeared mid-sentence in fourteen translated strings is gone.
- The language picker moved somewhere a second person using the phone can find
  it.

## Notes for release

- Requires the matching backend, deployed 25 August 2026. The enterprise screen
  needs a connection; it says so rather than pretending to save.
- The Impact report in the web console is new alongside this: baselines,
  observed change, and the method attached to each figure.

## Build

- `flutter clean` first, then `flutter build appbundle --release`.
- Artifact: `build/app/outputs/bundle/release/app-release.aab`, 48.6 MB.
- Verified after building: the bundle's manifest carries 2.5.0, and the compiled
  Dart contains this release's new strings in both English and Kiswahili. An
  incremental build has silently shipped stale Dart before, so the artifact is
  checked rather than assumed.
- `dart run tool/check_release_config.dart` passed: HTTPS backend, no bundled
  API key.
- 405 tests, `flutter analyze` clean.
