# Release Notes

Newest first. Each entry covers one production artifact.

---

## 2.2.0 (build 10) — 8 August 2026

**Artifact:** `app-release.aab`, 47.5 MB, signed with the release keystore
**Contains:** `ebe7ff1`, `2ef3925` (everything in 2.1.0 build 9, plus the fix below)

### What's new — store listing

> Fixed a problem where the Payment Providers screen opened blank.
>
> It now shows M-Pesa (Daraja) and Paystack for your group: whether each one
> collects into your group's own account or into the platform account, and
> what is still missing before a setup is finished.

*(438 characters, within the Play Store's 500-character limit.)*

### The change

**Payment Providers opened to an empty screen.** Tapping *More → Payment
Providers* showed the title bar and nothing else. The group's providers were
loaded correctly and no error was shown or logged — the screen simply painted
nothing, which reads to the person holding the phone as "this feature is
missing" rather than "something failed".

The cause was a layout fault. The app theme gives filled and outlined buttons
an infinite minimum width, which is what makes them stretch to fill their
parent. That is safe wherever the parent bounds the width, but a `Row` does
not: nothing clamped the infinity, the button asked to be infinitely wide, and
layout stopped there — silently taking the rest of the screen with it. This
screen was the only one in the app that placed those buttons directly in a
`Row`, which is why it was the only blank one.

Both buttons are now width-bounded, and the trap is documented in the theme so
the next row of buttons does not rediscover it.

Also in this build: the M-Pesa environment field showed its raw key
(`MPESA_ENVIRONMENT`) instead of a readable label.

### Who is affected

Anyone on **2.1.0 (build 9)**, which was the build that shipped the blank
screen. Group accounts and platform admins are the ones who reach this screen;
ordinary members never see it. Everyone on build 9 should update.

No data migration, no server change, no re-authentication. Existing
credentials, groups and offline records are untouched.

### Verification

- Full flow exercised on emulator from a clean install against production
  (`https://intellicash.co.ke/api/v1`): sign in → group setup → More →
  Payment Providers. Both provider cards render; the credential sheet opens
  with secrets masked as "Saved — type to replace".
- The shipped bundle was checked for the new code rather than assumed: the
  strings introduced by this fix are present, the debug instrumentation used
  while diagnosing it is absent, and a control string confirms the check
  itself was working.
- `versionCode` read back out of the bundle's manifest as `10`;
  `versionName` as `2.2.0`, with no trace of the previous version.
- Release config guard passed — https backend, no API key bundled.

**Not verified:** the AAB itself was not installed and run. The fix was
confirmed on a debug build of the same commit, and the bundle is verified to
contain that code. To close that gap, generate the universal APK from this
bundle with bundletool and re-run the flow.

### Rollback

Halt the staged rollout in the Play Console. There is nothing to undo
server-side. Reverting to build 9 restores the blank screen, so prefer
rolling forward.
