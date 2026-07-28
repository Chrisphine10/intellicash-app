# Intelli-Cash Mobile

Digital VSLA platform — paperless, transparent, connected. The group
leader's phone replaces the paper register and cash box: meetings,
share purchases, fines, social fund and loans are recorded on-device
first and sync to the cloud when connectivity returns.

## Architecture

Offline-first, feature-organized Flutter app. SQLite is the source of
truth; every write also lands in a sync queue that drains to the backend
(`POST /sync/push`, see `../docs/API_SPECIFICATION.md`).

```
lib/
├── main.dart                 # Composition root: DB, repos, providers
├── app.dart                  # MaterialApp + bootstrap routing
├── core/
│   ├── database/             # sqflite schema (10 tables, FKs, indices)
│   ├── theme/                # Design tokens + Material 3 theme
│   └── utils/                # Formatters, LoanCalculator, DomainException
├── data/
│   ├── models/               # Immutable domain models + enums
│   ├── repositories/         # Business rules + SQL (one per aggregate)
│   └── services/             # SyncService (connectivity + push)
├── providers/                # ChangeNotifier state, one per feature
├── features/
│   ├── onboarding/           # 4-step group setup wizard
│   ├── shell/                # 5-tab bottom navigation
│   ├── dashboard/            # Stats + savings trend chart
│   ├── meetings/             # List → attendance → hub → sheets → ledger
│   ├── loans/                # Portfolio, eligibility, disburse, detail
│   ├── members/              # Directory, profile, add member
│   └── more/                 # Settings, sync, about
└── shared/widgets/           # StatusChip, avatars, empty states, etc.
```

## Business rules enforced in code

- **Loan eligibility** — `available = savings × multiplier − active balance`,
  checked live on the disburse screen and re-checked inside the write.
- **Immutable meetings** — closing a meeting locks every record; the
  repository refuses writes against closed meetings.
- **Savings discipline** — share value and per-meeting share cap come from
  the group constitution; the cap is enforced across multiple purchases.
- **Interest** — flat or reducing balance, fixed at disbursement
  (`LoanCalculator`), so later rule changes never rewrite history.
- **Defaults** — active loans past their due date surface as `defaulted`
  automatically on read.
- **Offline-first** — every write enqueues a sync operation atomically;
  the queue only drains when the server accepts the batch.

## Getting started

```bash
flutter pub get
flutter run            # Android device/emulator
flutter test           # 3 suites: calculators, repositories (ffi), widget
flutter analyze
```

First run opens the group setup wizard (Basics → Savings → Loans →
Schedule). The previous prototype implementation is archived in
`legacy_code_backup.zip`.
# intellicash-app
