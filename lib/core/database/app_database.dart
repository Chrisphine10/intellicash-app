import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the sqflite instance and schema.
///
/// The local database is the source of truth: every transaction is written
/// here first and queued in [sync_queue] for upload when connectivity
/// returns (offline-first, per the platform architecture).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const int _version = 7;
  Database? _db;

  /// Test hook: lets tests inject an in-memory/ffi database factory.
  static DatabaseFactory? overrideFactory;
  static String? overridePath;

  Future<Database> get database async {
    final open = _db;
    if (open != null && open.isOpen) return open;
    final factory = overrideFactory ?? databaseFactory;
    final dir = overridePath ?? await factory.getDatabasesPath();
    final db = await factory.openDatabase(
      p.join(dir, 'intellicash.db'),
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
        onUpgrade: _upgradeSchema,
      ),
    );
    _db = db;
    return db;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> _createSchema(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        cycle_number INTEGER NOT NULL DEFAULT 1,
        cycle_start_date TEXT NOT NULL,
        savings_mode TEXT NOT NULL,
        share_value REAL NOT NULL,
        max_shares_per_meeting INTEGER NOT NULL,
        social_fund_amount REAL NOT NULL,
        interest_rate REAL NOT NULL,
        interest_type TEXT NOT NULL,
        loan_multiplier REAL NOT NULL,
        default_loan_term_months INTEGER NOT NULL,
        meeting_frequency TEXT NOT NULL,
        meeting_day INTEGER NOT NULL,
        meeting_days TEXT,
        require_three_key INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE members (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        phone TEXT,
        role TEXT NOT NULL DEFAULT 'member',
        is_active INTEGER NOT NULL DEFAULT 1,
        pin_hash TEXT,
        joined_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE meetings (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        number INTEGER NOT NULL,
        date TEXT NOT NULL,
        opening_balance REAL NOT NULL,
        status TEXT NOT NULL,
        closed_at TEXT,
        unlocked_by TEXT,
        UNIQUE (group_id, number)
      )
    ''');
    batch.execute('''
      CREATE TABLE attendance (
        meeting_id TEXT NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
        member_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        present INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (meeting_id, member_id)
      )
    ''');
    batch.execute('''
      CREATE TABLE share_purchases (
        id TEXT PRIMARY KEY,
        meeting_id TEXT NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
        member_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        shares INTEGER NOT NULL,
        unit_value REAL NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'cash',
        payment_reference TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE fines (
        id TEXT PRIMARY KEY,
        meeting_id TEXT NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
        member_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        amount REAL NOT NULL,
        reason TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE social_fund_entries (
        id TEXT PRIMARY KEY,
        meeting_id TEXT NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
        member_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        amount REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE loans (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        member_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        meeting_id TEXT REFERENCES meetings(id) ON DELETE SET NULL,
        principal REAL NOT NULL,
        interest_rate REAL NOT NULL,
        interest_type TEXT NOT NULL,
        total_due REAL NOT NULL,
        disbursed_at TEXT NOT NULL,
        due_date TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE loan_repayments (
        id TEXT PRIMARY KEY,
        loan_id TEXT NOT NULL REFERENCES loans(id) ON DELETE CASCADE,
        meeting_id TEXT REFERENCES meetings(id) ON DELETE SET NULL,
        amount REAL NOT NULL,
        paid_at TEXT NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    for (final ddl in _v2Tables) {
      batch.execute(ddl);
    }
    batch.execute(_shareOutPayoutsTable);
    batch.execute(_welfareExpensesTable);
    batch.execute(_groupVisitsTable);
    batch.execute(_outboxTable);
    batch.execute('CREATE INDEX idx_visits_group ON group_visits(remote_group_id, started_at)');
    batch.execute('CREATE INDEX idx_outbox_status ON outbox(status, next_attempt_at)');
    batch.execute('CREATE INDEX idx_welfare_group ON welfare_expenses(group_id, cycle_number)');
    batch.execute(
        'CREATE INDEX idx_shareout_group ON share_out_payouts(group_id, cycle_number)');
    batch.execute(
        'CREATE INDEX idx_members_group ON members(group_id, is_active)');
    batch.execute(
        'CREATE INDEX idx_meetings_group ON meetings(group_id, number DESC)');
    batch.execute(
        'CREATE INDEX idx_shares_meeting ON share_purchases(meeting_id)');
    batch.execute(
        'CREATE INDEX idx_shares_member ON share_purchases(member_id)');
    batch.execute('CREATE INDEX idx_loans_member ON loans(member_id, status)');
    batch.execute(
        'CREATE INDEX idx_repayments_loan ON loan_repayments(loan_id)');
    batch.execute(
        'CREATE INDEX idx_idmap_remote ON id_map(entity_type, remote_id)');
    batch.execute(
        'CREATE INDEX idx_conflicts_meeting ON sync_conflicts(meeting_id)');
    await batch.commit(noResult: true);
  }

  /// Tables introduced in schema v2 (write-path sync + payments). Shared by
  /// [_createSchema] and [_upgradeSchema] so both paths stay identical.
  static const List<String> _v2Tables = [
    // Maps a local UUID to the backend's CUID for a bound group/member/meeting.
    '''
      CREATE TABLE id_map (
        entity_type TEXT NOT NULL,
        local_id TEXT NOT NULL,
        remote_id TEXT NOT NULL,
        group_id TEXT,
        synced_at TEXT,
        PRIMARY KEY (entity_type, local_id)
      )
    ''',
    // Non-duplicate conflicts returned by the backend on a meeting sync,
    // surfaced for human review.
    '''
      CREATE TABLE sync_conflicts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        meeting_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        client_request_id TEXT,
        code TEXT NOT NULL,
        message TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''',
  ];

  /// End-of-cycle share-out payouts (schema v4). One row per member per
  /// share-out, forming the permanent distribution record. Shared by
  /// [_createSchema] and [_upgradeSchema].

  /// Welfare spending (schema v6).
  ///
  /// Welfare money is paid OUT of the social fund during a cycle, and what
  /// remains at the end is what gets shared out. Without these rows the phone
  /// computes the share-out pool from GROSS contributions and distributes
  /// money the group has already spent.
  ///
  /// `remote_id` is how a server-recorded expense is recognised on sync, so an
  /// expense entered on the web is not duplicated here. NULL means locally
  /// created and not yet pushed.
  static const String _welfareExpensesTable = '''
      CREATE TABLE welfare_expenses (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        meeting_id TEXT REFERENCES meetings(id) ON DELETE SET NULL,
        cycle_number INTEGER NOT NULL DEFAULT 1,
        category TEXT NOT NULL,
        amount REAL NOT NULL,
        payee_member_id TEXT REFERENCES members(id) ON DELETE SET NULL,
        payee_name TEXT,
        note TEXT,
        remote_id TEXT UNIQUE,
        created_at TEXT NOT NULL
      )
    ''';

  /// A field visit as captured on the phone.
  ///
  /// `client_request_id` is minted once, when the opening PIN passes, and is
  /// never regenerated — not on retry, not on resume, not after a reinstall.
  /// It is the whole idempotency story: the server keys on it, so a visit
  /// pushed twice is recorded once.
  ///
  /// `remote_id` is NULL until the server has accepted the visit, which is how
  /// anything that depends on the visit knows whether it can be pushed yet.
  static const String _groupVisitsTable = '''
      CREATE TABLE group_visits (
        id TEXT PRIMARY KEY,
        client_request_id TEXT NOT NULL UNIQUE,
        remote_group_id TEXT NOT NULL,
        group_name TEXT,
        visit_type TEXT NOT NULL DEFAULT 'FOLLOW_UP',
        status TEXT NOT NULL DEFAULT 'DRAFT',
        started_at TEXT NOT NULL,
        completed_at TEXT,
        pin_verified_at TEXT,
        latitude REAL,
        longitude REAL,
        accuracy_m REAL,
        location_captured_at TEXT,
        location_note TEXT,
        notes TEXT,
        remote_id TEXT UNIQUE,
        synced_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''';

  /// The durable send queue.
  ///
  /// Deliberately not the older `sync_queue`, and different from it in the
  /// ways that matter:
  ///
  /// 1. It stores a POINTER (`record_type` + `record_id`), not a payload, so a
  ///    record edited after being queued pushes its corrected state rather
  ///    than a stale snapshot.
  /// 2. It has an explicit lifecycle — `status`, `attempts`, `next_attempt_at`,
  ///    `last_error` — which is exactly what a Draft / Pending / Synced /
  ///    Failed indicator reads. `sync_queue` has no status at all.
  /// 3. `depends_on_id` makes it structurally impossible to push a child
  ///    before its parent has a remote id.
  /// 4. UNIQUE(record_type, record_id) makes a double enqueue a no-op instead
  ///    of a second send.
  static const String _outboxTable = '''
      CREATE TABLE outbox (
        id TEXT PRIMARY KEY,
        record_type TEXT NOT NULL,
        record_id TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        attempts INTEGER NOT NULL DEFAULT 0,
        next_attempt_at TEXT,
        last_error TEXT,
        last_error_code TEXT,
        depends_on_id TEXT REFERENCES outbox(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        UNIQUE(record_type, record_id)
      )
    ''';

  static const String _shareOutPayoutsTable = '''
      CREATE TABLE share_out_payouts (
        id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
        cycle_number INTEGER NOT NULL,
        member_id TEXT NOT NULL REFERENCES members(id) ON DELETE CASCADE,
        member_name TEXT NOT NULL,
        share_amount REAL NOT NULL,
        gross_payout REAL NOT NULL,
        welfare_payout REAL NOT NULL,
        loan_offset REAL NOT NULL,
        net_payout REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''';

  Future<void> _upgradeSchema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE share_purchases ADD COLUMN payment_method TEXT NOT NULL DEFAULT 'cash'");
      await db.execute(
          'ALTER TABLE share_purchases ADD COLUMN payment_reference TEXT');
      for (final ddl in _v2Tables) {
        await db.execute(ddl);
      }
      await db.execute(
          'CREATE INDEX idx_idmap_remote ON id_map(entity_type, remote_id)');
      await db.execute(
          'CREATE INDEX idx_conflicts_meeting ON sync_conflicts(meeting_id)');
    }
    if (oldVersion < 3) {
      // Multi-day meeting schedule. Backfill from the single meeting_day.
      await db.execute('ALTER TABLE groups ADD COLUMN meeting_days TEXT');
      await db.execute(
          'UPDATE groups SET meeting_days = CAST(meeting_day AS TEXT) '
          'WHERE meeting_days IS NULL');
    }
    if (oldVersion < 4) {
      // End-of-cycle share-out records.
      await db.execute(_shareOutPayoutsTable);
      await db.execute(
          'CREATE INDEX idx_shareout_group ON share_out_payouts(group_id, cycle_number)');
    }
    if (oldVersion < 5) {
      // Meeting security: the 3-key unlock gate (on by default, switchable
      // in settings), member PINs, and the record of who unlocked a meeting.
      await db.execute(
          'ALTER TABLE groups ADD COLUMN require_three_key INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE members ADD COLUMN pin_hash TEXT');
      await db.execute('ALTER TABLE meetings ADD COLUMN unlocked_by TEXT');
    }
    if (oldVersion < 6) {
      // Welfare spending. Until this existed the share-out pool was
      // computed from GROSS contributions, so a group that had spent its
      // welfare would distribute money it no longer held.
      // IF NOT EXISTS: an upgrade must tolerate being re-run. A database
      // reporting v5 while already carrying the table would otherwise
      // crash on 'table already exists' and leave the install unusable.
      await db.execute(_welfareExpensesTable
          .replaceFirst('CREATE TABLE', 'CREATE TABLE IF NOT EXISTS'));
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_welfare_group ON welfare_expenses(group_id, cycle_number)');
    }
    if (oldVersion < 7) {
      // Field-agent visits, and the outbox that gets them to the server.
      //
      // Note this does NOT touch sync_queue. That table is written on every
      // local write and drained nowhere — main.dart supplies an onSync
      // callback, so SyncService never reaches the /sync/push path, and that
      // endpoint has never existed on the backend anyway. Removing it means
      // editing fifteen call sites inside the meeting and loan money paths,
      // which is its own change with its own tests. The outbox below is
      // deliberately a separate table rather than a reuse of it.
      await db.execute(_groupVisitsTable
          .replaceFirst('CREATE TABLE', 'CREATE TABLE IF NOT EXISTS'));
      await db.execute(
          _outboxTable.replaceFirst('CREATE TABLE', 'CREATE TABLE IF NOT EXISTS'));
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_visits_group ON group_visits(remote_group_id, started_at)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_outbox_status ON outbox(status, next_attempt_at)');
    }
  }
}
