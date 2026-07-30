import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/network/api_client.dart';
import '../repositories/id_map_repository.dart';

/// Brings server-recorded welfare expenses down to the phone.
///
/// Why this exists: welfare money is spent OUT of the social fund, and what
/// remains at cycle end is what gets shared. The phone computes share-out from
/// its own tables, so an expense recorded on the web is invisible to it — and
/// the group would distribute money it had already paid to a hospital or a
/// bereaved family. This closes that gap.
///
/// Deliberately PULL-ONLY for now. Welfare expenses are created on the server
/// (web/API) and mirrored down. Pushing locally-created ones is a separate
/// problem: it needs conflict handling against a fund balance the phone cannot
/// authoritatively know while offline, and getting that wrong would let two
/// devices each spend the same welfare shilling.
class WelfareExpenseSync {
  WelfareExpenseSync(this._db, this._client);

  final AppDatabase _db;
  final ApiClient _client;
  static const _uuid = Uuid();

  /// Fetches this group's welfare expenses and mirrors them locally.
  ///
  /// Idempotent by `remote_id`: re-running mirrors nothing new, so a repeated
  /// sync cannot double-count spending and shrink the share-out pool twice.
  /// Returns how many rows were newly inserted.
  Future<int> pull(String remoteGroupId, {required String localGroupId}) async {
    final payload = await _client.getData('/groups/$remoteGroupId/welfare-expenses');
    final map = payload is Map<String, dynamic> ? payload : <String, dynamic>{};
    final rows = (map['expenses'] as List?) ?? const [];

    final db = await _db.database;
    var inserted = 0;

    await db.transaction((txn) async {
      for (final raw in rows) {
        final entry = Map<String, dynamic>.from(raw as Map);
        final remoteId = '${entry['id']}';
        if (remoteId.isEmpty || remoteId == 'null') continue;

        final existing = await txn.query(
          'welfare_expenses',
          columns: const ['id'],
          where: 'remote_id = ?',
          whereArgs: [remoteId],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;

        // The amount lives on the ledger entry the server attached, not on the
        // expense record — same split as the backend, where the ledger is the
        // money and the expense row is the context.
        final ledger = (entry['ledgerEntry'] as Map?) ?? const {};
        final amountCents = (ledger['amountCents'] as num?)?.toInt() ?? 0;
        if (amountCents <= 0) continue;

        // A payee that is not a known local member is stored by NAME rather
        // than dropped: welfare is often paid to a member's family or straight
        // to a hospital, and losing the record would understate spending.
        final payeeRemoteId = entry['payeeMemberId'] as String?;
        String? localMemberId;
        if (payeeRemoteId != null) {
          final match = await txn.query(
            'id_map',
            columns: const ['local_id'],
            where: 'remote_id = ? AND entity_type = ?',
            whereArgs: [payeeRemoteId, MapEntity.member],
            limit: 1,
          );
          if (match.isNotEmpty) localMemberId = match.first['local_id'] as String?;
        }

        await txn.insert('welfare_expenses', {
          'id': _uuid.v4(),
          'group_id': localGroupId,
          'meeting_id': null,
          'cycle_number': 1,
          'category': '${entry['category'] ?? 'OTHER'}',
          'amount': amountCents / 100.0,
          'payee_member_id': localMemberId,
          'payee_name': entry['payeeName'] as String? ??
              ((entry['payeeMember'] as Map?)?['fullName'] as String?),
          'note': entry['note'] as String?,
          'remote_id': remoteId,
          'created_at':
              '${(ledger['createdAt'] ?? entry['createdAt'] ?? DateTime.now().toIso8601String())}',
        });
        inserted += 1;
      }
    });

    return inserted;
  }

  /// Welfare spending this phone knows about, in shillings.
  ///
  /// Exposed so a caller can show the figure that share-out will actually
  /// subtract, rather than recomputing the rule in the UI.
  Future<double> spentFor(String localGroupId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS spent FROM welfare_expenses WHERE group_id = ?',
      [localGroupId],
    );
    return ((rows.first['spent'] ?? 0) as num).toDouble();
  }
}
