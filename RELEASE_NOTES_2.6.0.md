# Intelli-Cash 2.6.0 (build 21)

Released 16 September 2026. Previous store build: 2.5.5 (20).

## For the Play Store listing

> Sign in with a code sent to your phone — no password needed — and reset a
> forgotten password the same way. If your group already has an account, the app
> now takes you straight to it instead of asking you to sign up again.

## What changed

### Sign in with a code

The sign-in screen has **Sign in with a code**. Enter the phone number, receive a
6-digit code by SMS, and you're in. Most group accounts were set up for the group
before anyone in the field had a password, so this is now the ordinary way for a
digital champion to get into their group.

### Forgot password

**Forgot password?** sends a code to the phone, then asks for a new password
(at least 8 characters) and signs you in. Every other device signed in to that
account is signed out, which is what you want if someone else had been using it.

### No more dead end at sign-up

Signing up a group whose number already has an account used to stop with an
error and nowhere to go. The app now says the account exists and offers to sign
in with a code to that number, instead of creating a second, empty group.

## Notes for release

- **Codes only arrive once SMS is working on the server.** It needs Bonga SMS
  credentials saved under Dashboard → Integrations → Bonga SMS. Until then,
  password sign-in still works.
- Needs the backend deployed 16 September 2026 (commit 59ffbdf or later).
- The code screen says a code is on its way *if* the number has an account. That
  is deliberate: the server does not reveal which numbers have accounts.
- Sixteen new strings in English and Kiswahili. Gĩkũyũ, Dholuo and Kĩembu show
  them in English until a speaker checks them (`docs/translation/*-to-review.csv`).

## Build

- `flutter clean`, then `flutter build appbundle --release`.
- Artifact: `build/app/outputs/bundle/release/app-release.aab`, 48.8 MB.
- Checked after building: the bundle's manifest carries 2.6.0 and not 2.5.5, and
  the compiled Dart contains the new screens in English and Kiswahili and the new
  endpoints.
- `dart run tool/check_release_config.dart` passed: HTTPS backend, no bundled API
  key.
- 434 tests, `flutter analyze` clean.
