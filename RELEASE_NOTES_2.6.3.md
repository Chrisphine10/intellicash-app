# Intelli-Cash 2.6.3 (build 26)

Built 26 September 2026 from a clean tree with the production `.env`
(`https://intellicash.co.ke/api/v1`, no API key in the bundle).

- File: `build/app/outputs/bundle/release/app-release.aab` (50.1 MB). A copy is
  at `Downloads/IntelliCash-2.6.3-build26.aab`.
- SHA-256: `ad1c668df2396bbb64410558f8829d76eb6313723499e993424a02a589c77c6e`

It contains everything from 2.6.2 (build 25, committed `91700e3`): meeting
schedules and reminders, module switches, group rules, and a sign-out that
never loses work. Version code 26 is used in case build 25 reached a Play
track.

**The server this build needs is not live yet.** It needs the admin release of
26 September 2026 (three migrations; see `intellicash_admin/docs/RELEASE_2026-09-26.md`).
Deploy the server first, then upload this build.

## For the Play Store listing

> Loan interest now builds month by month, the same on your phone and online,
> and a repayment clears a member's oldest loan first. The social fund shows
> what is actually left in it. Signing out or switching accounts waits until
> everything is sent, and a phone restored during a meeting sends what is
> recorded afterwards. Clearer messages when there is no signal.

## What changed

### Money
- **Interest month by month.** A loan owes interest for each 30-day month
  begun since it was given out, up to its term. Flat and reducing balance work
  the same on the phone and the server (shared worked examples prove it). It
  used to be charged in full on the day of the loan. **Existing loans will show
  less owed early in their term than before; tell the treasurers.**
- **A repayment clears the member's oldest loan first**, as the server does.
  The message says what is still owed across all their loans.
- **"Social fund" is the fund as it stands**: contributions and fines, less
  welfare paid out. The dashboard, the online report and the offline report
  now agree.
- The offline member report covers this cycle only, like the online one.
- A restored phone applies each repayment the way the server did, including
  one that cleared two loans. It uses the group's own share value, taken from
  its history, instead of a default.

### Never losing work
- **A meeting still open when the phone was restored** now sends what is
  recorded in it afterwards, and only that. Before, those entries never
  reached the server.
- **Switching accounts** waits for everything a sign-out waits for (visits,
  photos, mentorship, office and rule changes, a group not yet online) instead
  of wiping them.
- **Recovering an old local archive** works. Before, it always failed. It
  keeps a copy of the book it replaces, and refuses while anything is unsent.
- Starting a meeting while the group's history is still loading **asks first**:
  starting one would stop the history from arriving.
- When the online loan rules are newer, the phone still gives the server its
  share value, social fund and loan multiplier if the server lacks them.

### Messages
- No signal, a timeout or a server fault: every screen now says so in a
  sentence ("Could not reach IntelliCash. Check your internet connection and
  try again."), never raw technical text. "Backend" and "base URL" are gone
  from what people read.
- The Account page shows the real version (it said 2.6.1 (24)). A test now
  keeps it equal to `pubspec.yaml`.

## Verification
- `flutter analyze`: no issues.
- `flutter test`: 603 passed, 3 skipped, 0 failed. The newest tests
  (messages, archive, version) pass 9 of 9.
- On the emulator against a QA copy of this server, with a fictional group:
  - restoring brought back every meeting;
  - savings, fines, social fund, loans and welfare matched the server to the
    shilling;
  - the member's passbook and report matched.
