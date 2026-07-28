# Google Play listing assets

Generated 28 Jul 2026 from the shipped brand art and real screenshots of the
release build, so the listing matches what a user sees after installing.

## What Play requires

| Asset | Size | Format | Alpha | Count |
|---|---|---|---|---|
| App icon | **512 × 512** | 32-bit PNG | allowed | 1, required |
| Feature graphic | **1024 × 500** | PNG / JPEG | **not allowed** | 1, required |
| Phone screenshots | 320–3840 px per side, aspect between 16:9 and 9:16 | 24-bit PNG / JPEG | **not allowed** | **2–8, required** |
| 7-inch tablet | same rules | same | not allowed | up to 8 |
| 10-inch tablet | same rules | same | not allowed | up to 8 |

Two rules reject uploads most often:

1. **Alpha channel.** Everything except the icon must be flattened. All files
   here are written as RGB for that reason — only `icon-512.png` keeps RGBA.
2. **Aspect ratio.** Modern phones and emulators are 20:9 or taller, which is
   *more* elongated than the 9:16 limit. Raw captures are therefore
   **letterboxed onto a brand canvas, never cropped** — cropping would cut the
   app's own UI off. Phone output is exactly 1080 × 1920 (9:16); tablet output
   is 1600 × 2560.

## Files

- `icon-512.png` — 512 × 512, RGBA
- `feature-graphic-1024x500.png` — 1024 × 500, RGB, no alpha
- `screenshots/raw/` — untouched device captures, for reference
- `screenshots/phone-*-poster.png` — captioned, 1080 × 1920
- `screenshots/phone-*-plain.png` — bare UI, letterboxed, 1080 × 1920
- `screenshots/tablet-*-poster.png` / `-plain.png` — 1600 × 2560

Upload either the poster or the plain set — not both for the same screen.
Posters read better on a store listing; plain ones are honest to the UI and
are the safer choice if Play ever queries promotional text in imagery.

## Still needed before the listing can go live

These are not image problems and cannot be generated here:

- **Privacy policy URL** — https://intellicash.co.ke/privacy is live and can be used.
- **Data safety form** — must declare what the app collects. It handles member
  names, phone numbers and financial records, so this needs care.
- **Content rating questionnaire.**
- **Store description** and short description.

The app icon shipped in the APK is the same mark used here, so the listing and
the launcher agree.
