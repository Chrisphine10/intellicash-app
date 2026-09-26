# Intelli-Cash 2.6.4 (build 27)

Built 26 September 2026 from a clean tree (`flutter clean`, then
`flutter build appbundle --release`). It uses the production `.env`
(`https://intellicash.co.ke/api/v1`) and bundles no API key.

- File: `build/app/outputs/bundle/release/app-release.aab`. A copy is at
  `Downloads/IntelliCash-2.6.4-build27.aab`.
- SHA-256: `c3b87dcafda8788b33d637f356231ec50fdbec8b17732c4b43c891ce396062c5`

It needs the admin release of 26 September 2026, second part (commit
`163df8f`, notes in `intellicash_admin/docs/RELEASE_2026-09-26-permissions.md`).
Deploy the server first, then upload this build.

## For the Play Store listing

> Your group's shares are shown as shares everywhere, and the dashboard
> shows them even before this phone has held a meeting. Officials come back
> as officials after a restore. A meeting closed on the phone now shows as
> properly closed online. A cycle with shares ends with its share-out.

## What changed

### Shares
- **"Savings" now reads "shares"** wherever it meant shares: dashboard,
  passbook, reports, set-up and sign-out messages.
- **Total shares on a phone with no meetings yet.**
  - Just after sign-in, the dashboard shows the group's shares from the
    online record.
  - Once the phone holds meetings, it shows its own figure.
  - When the two differ, a note gives the online figure and why they can
    differ.

### Meetings and officials
- **Closing a meeting reports it fully online.** The close sends which
  members' PINs opened the meeting. The console then shows it closed and
  unlocked, not "waiting for keys". A close the server refuses stays waiting
  and is retried.
- **Officials survive a restore.**
  - The group's chairperson, secretary and treasurer come back as officials.
    Before, a restore stored the server's role name, which matched nothing,
    so every official came back as an ordinary member and no meeting could
    open with three keys.
  - The phone also pulls office changes made online.
- **A restored group's cycle starts at its first record.** Before, it started
  "now", which hid every imported share.

### Cycles
- **A cycle with shares ends with its share-out.** "Close cycle" now explains
  this and leads to Share-Out. The server enforces the same rule.

### External loans
- **Only the group's own account can apply.** A member or field agent signed
  in on a phone is told, in their language, to ask the group's officials. The
  server refuses those applications. The store is switched off everywhere
  today.
- **Needs a native speaker's check:** the Kikuyu, Embu and Luo wording of
  this one message was written from the app's existing vocabulary.

## Verification
- `flutter analyze`: no issues.
- `flutter test`: 610 passed, 3 skipped, 0 failed. This includes the
  translation-coverage tests: every shipped language has every string.
- Version 2.6.4 (27) in `pubspec.yaml` and on the Account page (a test keeps
  them equal).
