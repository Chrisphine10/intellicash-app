# Google Play listing assets

| File | Size | Notes |
|---|---|---|
| `icon-512.png` | 512 × 512 | RGBA — the only file allowed an alpha channel |
| `feature-graphic-1024x500.png` | 1024 × 500 | RGB |
| `screenshots/phone-*.png` | 1080 × 1920 | RGB, 4 screens |
| `screenshots/tablet-*.png` | 1600 × 2560 | RGB |
| `screenshots/raw/` | — | untouched captures, reference only |
| `listing-copy.md` | — | short and full store description |

Each screen comes as `-poster` (captioned) or `-plain` (bare UI). Upload one
set, not both. Play needs 2–8 phone screenshots.

**Two rules reject uploads.** Everything except the icon must be flattened —
no alpha. And aspect must sit between 16:9 and 9:16, so captures are
letterboxed onto a brand canvas rather than cropped; cropping would cut off
the app's own UI.

## Before the listing can go live

- [ ] Data safety form — the app handles member names, phone numbers and
      financial records, so this needs care
- [ ] Content rating questionnaire
- [x] Privacy policy — https://intellicash.co.ke/privacy
- [x] Store description — see `listing-copy.md`
