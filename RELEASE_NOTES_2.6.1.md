# Intelli-Cash 2.6.1 (build 23)

First built 19 September 2026, rebuilt the same day after a full audit (see
"Fixes from the audit") and again on the evening of 20 September once the issues
that audit left open were fixed (see "Also fixed, later that day"). Builds 21
and 22 may not have been uploaded to Play - if they were not, upload this one
instead; it contains everything in them.

**Deploy the server first.** This build sends share-outs to a new server route and
loads a group's history from another; both arrive with the server update
(below). An older server simply does not have them, and the phone carries on as
it did before.

## For the Play Store listing

> Change your password from your Account page, or reset it with a code sent to
> your phone if you have forgotten it. A share-out done on the phone now reaches
> the online record and closes the cycle there, a new phone can load a group's
> whole history, balances start again after a share-out, a field agent's visit
> scorecard reaches the office, records sync on their own when the connection
> comes back, and many small fixes to forms and messages.

## What changed

### Fixes from the audit (20 September 2026)

Found by driving the app on a phone against a test server and checking every
record afterwards. The ones that matter most:

- **After a share-out the phone carried on as if nothing had been paid out.**
  The dashboard still showed the old savings, each member still showed their
  savings, the next meeting opened with the old cycle's money "in the box", and
  the loan screens would lend - and let members borrow - against money that had
  gone home. Balances, the cash box, the loan fund and borrowing limits now
  start again from the new cycle.
- **A meeting given a server copy while open (by opening Welfare) was never
  sent once closed**, and the phone said "synced". Fixed; a meeting counts as
  backed up only after a full push, and a push that stops part-way is retried.
- **Closing a meeting now sends it straight away**, and if the server is down
  while the phone keeps its signal the phone retries after 1, 3 and 7 minutes
  (it used to wait up to ten).
- **A field agent's visit scorecard now reaches the office.** The visit arrived
  but the scorecard was refused every time and retried in silence (needs the
  matching server update, below). Phones already in the field start working as
  soon as the server is updated - no app update needed for that part.
- **A group's records stay shut to other groups' accounts.** After a group signed
  out, anyone holding the phone could create a brand new group account and be
  shown the previous group's members, savings and loans. A group account now
  opens only the book that belongs to its own group; any other group account
  sees "This phone holds another group's records" and can only sign out.
- **Choosing a digital champion no longer changes the sign-in number of the
  login the group registered with.**
- Members added on the console now reach the phone; members without a phone
  number stay possible, and a made-up number ("12345") is refused with a clear
  message; savings mean shares only everywhere; the fine of KSh 50.50 reads
  50.50 everywhere.
- Agents: caseload report no longer says "Band UNRATED - 52" for unrated groups;
  "Back Up This Group" no longer opens a black screen for an agent; signing out
  of Cloud Account takes you straight back to the sign-in choice.
- Forms: an error such as "short by KSh 500" now clears as soon as the amount is
  corrected; the group-business form no longer overlaps its labels; amounts on
  the business card and group-rules summary keep their cents and thousands
  separators.
- Setting up a group: the "Add at least one founding member" and "already on the
  list" messages now show under the member field (they appeared behind the Next
  button and could not be read), and a new group - or a member added later -
  is sent to the server at once instead of at the next reconnect.
- The share-out confirmation now says plainly what happens to the payouts (see
  the next section for the change that followed).

### Also fixed, later that day (20 September 2026, evening)

The audit left five things open. They are fixed:

- **A share-out done on the phone now reaches the online record.** Until now the
  payouts stayed on the phone: the console still said "Cycle 1", its funds still
  held the money and member statements online still showed the old savings. The
  phone now sends what was paid (each loan settled, each payout, the welfare
  split) and the server closes the cycle in the same step - all of it or none of
  it. Meetings go first, then the share-out, then the next cycle's meetings, so
  each is filed under the right cycle. If something is not right, the share-out
  screen says why in words and offers **Send now**; where the only difference is
  that the online record holds different share purchases, **Send anyway** (after
  a confirmation). If the cycle was already shared out from the console, the phone
  does **not** send its copy (that would pay members twice) and says so.
  A meeting still open now stops a share-out ("Close Meeting #N first"): its
  savings would sit on both sides of the line. Share-outs made before this build
  are kept as history and are not sent.
- **A new phone gets the group's whole history, not just its members.** "Load my
  group" now brings the meetings and attendance, every share purchase, social
  fund entry, fine, loan and repayment, and the past share-outs, under the right
  cycle, and uses the loan rules the group set online. The dashboard, cash box
  and loan fund read as they did on the old phone. If the signal drops part-way
  the group is still loaded and the history follows at the next sync. It will not
  go underneath meetings the new phone has already recorded.
- **A phone's book is no longer linked to a group just because its name is
  free.** When the group you sign in as has a different name from the book on the
  phone, the app now shows both names and asks whether to link them ("Link
  them" / "Not now") instead of doing it silently. Same name: still automatic.
- **New groups start on the platform's own loan model**: flat interest, 10 % a
  month, up to 3 times savings, for 1 month (it was reducing balance, 5 %, 2x,
  3 months, so a group that kept the defaults saw different loan totals on the
  phone and on the console). Choosing "Reducing balance" now says the online
  record will not match.
- Smaller: choosing a theme no longer throws you back to the first screen (the
  Appearance screen stays and everything repaints); Cloud Account says "No
  internet" and "offline" when the phone is offline instead of "Connected"; a
  member not marked present is tagged when buying shares; a loan's "Total due"
  now says "by <due date>" (it is the whole term's interest, not what has built up
  so far); Sync & Backup says "items", not "meetings", and names a share-out the
  server refused.

### Change password (new)

**Account → Security → Change password.** Enter the current password and the
new one twice (at least 8 characters). Any other phone signed in to the same
account is signed out; the phone you are holding stays signed in. This matters
on a group's shared phone: if someone else knew the old password, they are
locked out the moment it changes.

Forgotten the current password? The same screen has **Forgot your current
password?**, which texts a code to the account's phone and lets you set a new
one — no need to sign out first.

### The phone's records reach the console on their own

A group whose records were full on the phone could show nothing in the admin
console. Two gaps caused it, both fixed:

- **The phone's group was never linked** to the server unless someone opened
  the manual Sync screen. The app now links it automatically for the group's
  own signed-in account — only when that is unambiguous: one group on the
  phone, not already linked, and the same name as the server group. If the name
  differs but the server group is still empty, the app shows both names and asks
  you to confirm. A shared phone is never attached to a different group's book.
- **Members added on the phone were never sent up**, so every attendance mark
  and payment for them was dropped at sync. They are now sent up (phone number
  optional) before the meetings that mention them.

Sync now also runs when someone signs in and every ten minutes while signed
in, not only when the network comes back. Meetings that previously synced
with "member not linked" gaps are re-sent and fill in.

To get a phone's backlog up: update to 2.6.1, open the app with a data
connection, and stay signed in for a minute.

### Signing up a group now creates the group

Creating a **group** account used to make only the login — the account opened
onto an empty app, with no group behind it, until staff attached one by hand.
The group is now created with the account (its code, fund accounts and the
champion's number).

If the group is already registered — the same champion number, or the same
name in the same county — the app says so and offers **Sign in with a code** to
that group's number instead of creating a duplicate.

Existing group logins that had no group were repaired on the server on
19 September 2026 (8 given their own group), and any that turn up later are
linked automatically the next time they sign in.

### Clearer error messages

- A wrong password at sign-in now says so and suggests signing in with a code,
  instead of "Your session has ended".
- "Could not reach the server. Confirm the base URL…" is now "Could not reach
  IntelliCash. Check your internet connection and try again."
- Server-side problems read "Something went wrong on our side", and messages
  from the server (for example which form field is wrong) are shown as written.

### Small fixes

- The Account page showed the app version as 2.4.2; it now shows 2.6.1 (22).

## Server changes this build relies on

Not yet live at the time of writing - they are on the branch `feat/qa-full-audit-2026-09`
and deploy when it is merged to main:

- `POST /groups/:id/share-outs` records a share-out done on a phone and closes
  the cycle in one transaction; `GET /groups/:id/restore-bundle` returns a
  group's whole book for a new phone. One more migration
  (`20260920200000_cycle_closed_by_share_out`: one nullable column and a unique
  index on `Cycle`, applied to an empty database as part of the whole chain).
- The scorecard endpoint now names its snapshot and accepts the template id that
  older phones send (fixes scorecards never syncing).
- Loan position: repayments across several loans, interest stops at settlement,
  ledger pairing rules and friendly refusals for oversized amounts, meetings
  stamped with the active cycle (one migration, tested on a copy of the data).

Already live:

- Changing your own password signs out your other devices (deployed 6deb629).
- Group sign-up creates the group; unlinked group logins are linked at sign-in
  (deployed 26d37fe, 3d03dec, cd08118).
- Members sent up by the phone: `POST /groups/:id/members/sync` (93e8358).
- Sign-in codes also reach a group's recorded champion number (deployed 9377f9a).

## Translations

New strings are translated into Swahili. Gikuyu, Dholuo and Kiembu show them in
English until a speaker has reviewed them, as with the 2.6.0 strings (this build
adds 28: five from the first pass - the Online Loan Rules title, the
social-fund-is-zero message, the "nothing to back up" message and the two on the
"another group's records" screen - and 23 for share-outs, linking a book, loading
a group's history, the offline message and the wizard's loan note).

## Build

- `flutter clean`, then `flutter build appbundle --release`.
- Verified in the built bundle: version 2.6.1 (22), and the compiled Dart
  contains the new Change password screen and endpoint.
- Tests: 458 passed, 2 skipped (full suite, `dart analyze lib test` clean),
  including an end-to-end test of a group set up on the phone syncing with no
  manual linking.
- Also driven on an Android emulator (profile build, QA server) through every
  screen listed in docs/QA_REPORT_2026-09-19.md in the admin repo.
