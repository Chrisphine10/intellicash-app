# Intelli-Cash 2.6.1 (build 22)

First built 19 September 2026 and rebuilt 20 September 2026 after a full audit
(see "Fixes from the audit"). Previous build: 2.6.0 (21), which was built but may
not yet have been uploaded to Play — if it was not, upload this one instead; it
contains everything in 2.6.0.

## For the Play Store listing

> Change your password from your Account page, or reset it with a code sent to
> your phone if you have forgotten it. Balances now start again after a
> share-out, a field agent's visit scorecard reaches the office, records sync
> on their own when the connection comes back, and many small fixes to forms
> and messages.

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
- The share-out confirmation now says plainly that payouts are recorded on this
  phone and are not sent to the online record.

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
  phone, not already linked, and either the same name as the server group or a
  server group that has no records yet. A shared phone is never attached to a
  different group's book.
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
adds three: the Online Loan Rules title, the social-fund-is-zero message and the
"nothing to back up" message; "Try again" reuses each language's existing word).

## Build

- `flutter clean`, then `flutter build appbundle --release`.
- Verified in the built bundle: version 2.6.1 (22), and the compiled Dart
  contains the new Change password screen and endpoint.
- Tests: 440 passed (full suite), including an end-to-end test of a group set
  up on the phone syncing with no manual linking.
