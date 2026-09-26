import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/loan_calculator.dart';
import '../models/enums.dart';
import '../models/remote/restore_bundle.dart';
import '../repositories/id_map_repository.dart';
import 'member_matching.dart';

/// What came across, and what did not.
class HistoryImportResult {
  const HistoryImportResult({
    this.meetings = 0,
    this.records = 0,
    this.loans = 0,
    this.shareOuts = 0,
    this.skipped = 0,
    this.hasUnmappedMemberSkipped = false,
    this.notImportedBecause,
  });

  final int meetings;

  /// Share purchases, social fund, fines and repayments placed on the phone.
  final int records;
  final int loans;
  final int shareOuts;

  /// Online records that could not be placed on the phone: not tied to a
  /// meeting, a member the phone does not have, a repayment with no loan.
  final int skipped;

  /// Set when at least one record was skipped because a member mapping was missing.
  final bool hasUnmappedMemberSkipped;

  /// Set when nothing was imported on purpose (see [GroupHistoryImporter.import]).
  final String? notImportedBecause;

  bool get imported => notImportedBecause == null;
}

/// Rebuilds a group's history on a phone from the server's restore bundle.
///
/// A treasurer who changes phone used to get the roster and the settings and
/// nothing else: zero savings, an empty loan fund, no meetings. Balances are
/// worked out from the rows on the phone, so a phone with none of the rows
/// reports a group with no money - and would work out a share-out from that.
///
/// This puts the rows back: meetings and attendance, share purchases, the social
/// fund, fines, loans with their repayments, and the past share-outs, all under
/// the cycle they belong to, with the open cycle's start restored so this
/// cycle's balances read as they did on the old phone.
///
/// Everything is written in ONE transaction, so a failure leaves the phone as it
/// was rather than half a history. Every finished meeting brought over is
/// recorded as already backed up online (it came from there), and every money
/// row as already online ([MapEntity.importedEntry]), so none is ever sent
/// back. A meeting still being held stays pending: what is added to it on this
/// phone is sent when it closes, and only that.
///
/// It refuses to run on a phone that has already recorded meetings for the
/// group: the imported meetings are numbered from one, and mixing them with
/// meetings recorded since would make two meetings with the same number.
class GroupHistoryImporter {
  GroupHistoryImporter({required AppDatabase db}) : _db = db;

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Written for a past share-out that was rebuilt from the online record.
  static const restoredShareOutMarker = 'restored-from-online';

  static String _local(DateTime moment) => moment.toLocal().toIso8601String();
  static double _kes(int cents) => cents / 100;

  Future<HistoryImportResult> import({
    required String localGroupId,
    required String remoteGroupId,
    required RestoreBundle bundle,

    /// Server member id -> this phone's member id. Pre-existing mappings
    /// (from a prior sync) are honoured; the importer fills any gaps from
    /// [bundle.members] so that entries never skip for want of a mapping.
    required Map<String, String> localMemberFor,
  }) async {
    final db = await _db.database;

    final alreadyThere = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM meetings WHERE group_id = ?', [localGroupId])) ??
        0;
    if (alreadyThere > 0) {
      return const HistoryImportResult(
        notImportedBecause:
            'This phone has already recorded meetings for the group, so the '
            'online history was not added underneath them.',
      );
    }

    final groupRows = await db.query('groups',
        columns: ['share_value'], where: 'id = ?', whereArgs: [localGroupId]);
    if (groupRows.isEmpty) {
      return const HistoryImportResult(notImportedBecause: 'The group is not on this phone.');
    }
    final shareValue = (groupRows.first['share_value'] as num).toDouble();

    final names = {
      for (final row in await db.query('members',
          columns: ['id', 'name'], where: 'group_id = ?', whereArgs: [localGroupId]))
        row['id'] as String: row['name'] as String,
    };

    // A meeting counts if anything was recorded in it. One that was only ever
    // planned is not history.
    final entriesByMeeting = <String, List<RestoreEntry>>{};
    for (final entry in bundle.entries) {
      final meetingId = entry.meetingId;
      if (meetingId != null) (entriesByMeeting[meetingId] ??= []).add(entry);
    }
    final withAttendance = {for (final a in bundle.attendance) a.meetingId};
    final meetings = [
      for (final meeting in bundle.meetings)
        if (meeting.status != 'CANCELLED' &&
            (withAttendance.contains(meeting.id) ||
                (entriesByMeeting[meeting.id]?.isNotEmpty ?? false)))
          meeting,
    ]..sort((a, b) {
        final byTime = a.scheduledAt.compareTo(b.scheduledAt);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });

    final localMeeting = {for (final meeting in meetings) meeting.id: _uuid.v4()};

    // Which imported meeting, if any, is still being held. Only one a person
    // actually started (IN_PROGRESS on the server) - never a SCHEDULED one,
    // however close its date: a schedule exists to remind people, and a
    // meeting starts only when someone starts it. SCHEDULED meetings that have
    // records were held on a phone and finished, so they come in closed. At
    // most one is open, the latest, because the phone holds one meeting at a
    // time.
    final inProgress =
        meetings.where((meeting) => meeting.status == 'IN_PROGRESS').toList();
    final openRemoteId = inProgress.isEmpty ? null : inProgress.last.id;
    final numberOf = {
      for (var i = 0; i < meetings.length; i++) meetings[i].id: i + 1,
    };

    // The cash box each meeting opened with: everything that had come in and
    // gone out at the meetings before it.
    final opening = <String, int>{};
    var running = 0;
    for (final meeting in meetings) {
      opening[meeting.id] = running;
      for (final entry in entriesByMeeting[meeting.id] ?? const <RestoreEntry>[]) {
        running += entry.isCredit ? entry.amountCents : -entry.amountCents;
      }
    }

    final loanByEntry = {
      for (final loan in bundle.loans)
        if (loan.disbursementEntryId != null) loan.disbursementEntryId!: loan,
    };
    final entries = [...bundle.entries]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final slicesFor = <String, List<RestoreAllocation>>{};
    for (final slice in bundle.allocations) {
      (slicesFor[slice.repaymentEntryId] ??= []).add(slice);
    }

    // Where this cycle's balances start. The server's own share-out counts
    // savings from the last payout, and the console's share-out does not close the
    // cycle - so a group that shared out there still has an open cycle whose money
    // has already gone home. The phone reads it the same way, or its dashboard
    // would show savings the group no longer holds.
    var balancesFrom = bundle.cycleStartedAt;
    for (final entry in bundle.entries) {
      if (entry.type != 'SHARE_OUT_PAYOUT' || entry.cycleNumber != bundle.cycleNumber) continue;
      if (balancesFrom == null || entry.createdAt.isAfter(balancesFrom)) {
        balancesFrom = entry.createdAt;
      }
    }

    // A server with no cycle on record keeps the group's whole history as one
    // cycle. Without a start from the server the restore used to leave
    // `cycle_start_date` at "now", so every imported share fell before the
    // cycle and the dashboard read nothing (or fell back to the loan fund's
    // cash). The cycle then starts just before its earliest record.
    if (balancesFrom == null) {
      final dates = <DateTime>[
        for (final entry in bundle.entries) entry.createdAt,
        for (final meeting in bundle.meetings) meeting.scheduledAt,
      ]..sort();
      if (dates.isNotEmpty) {
        balancesFrom = dates.first.subtract(const Duration(seconds: 1));
      }
    }

    var records = 0;
    var loansMade = 0;
    var skipped = 0;
    var unmappedSkipped = 0;
    var shareOuts = 0;

    await db.transaction((txn) async {
      // --- the group: this cycle's start, and the loan rules it agreed ---
      final groupUpdate = <String, Object?>{
        'cycle_number': bundle.cycleNumber,
        'updated_at': DateTime.now().toIso8601String(),
        if (balancesFrom != null) 'cycle_start_date': _local(balancesFrom),
        // Only what the group actually set. Guessing a rate would put a number
        // on every loan that nobody agreed to.
        if (bundle.policyConfigured) ...{
          'interest_rate': bundle.loanInterestRateBps / 100,
          'interest_type': (bundle.interestType == 'REDUCING'
                  ? InterestType.reducingBalance
                  : InterestType.flat)
              .name,
          'default_loan_term_months': bundle.defaultLoanTermMonths < 1
              ? 1
              : bundle.defaultLoanTermMonths,
        },
        // The rest of the group's own rules, each only if the group set it —
        // a restored phone must compute exactly what the old one did.
        if (bundle.shareValueCents != null) 'share_value': bundle.shareValueCents! / 100,
        if (bundle.maxSharesPerMeeting != null) 'max_shares_per_meeting': bundle.maxSharesPerMeeting,
        if (bundle.socialFundCents != null) 'social_fund_amount': bundle.socialFundCents! / 100,
        if (bundle.loanMultiplierBps != null) 'loan_multiplier': bundle.loanMultiplierBps! / 10000,
      };
      await txn.update('groups', groupUpdate,
          where: 'id = ?', whereArgs: [localGroupId]);

      // --- PASS 1: meetings and who was there ---
      for (final meeting in meetings) {
        final isOpen = meeting.id == openRemoteId;
        final closedAt = isOpen ? null : meeting.closedAt ?? meeting.scheduledAt;
        await txn.insert('meetings', {
          'id': localMeeting[meeting.id],
          'group_id': localGroupId,
          'number': numberOf[meeting.id],
          'date': _local(meeting.scheduledAt),
          'opening_balance': _kes(opening[meeting.id] ?? 0),
          // Preserve the server lifecycle: only the meeting someone started
          // and has not closed stays open here.
          'status': isOpen ? MeetingStatus.open.name : MeetingStatus.closed.name,
          'closed_at': closedAt == null ? null : _local(closedAt),
          'unlocked_by': null,
        });
        // A finished meeting came from the server and is backed up. The one
        // still being held is only a TWIN: what is recorded in it from now on
        // exists on this phone alone, so it must stay pending and be sent
        // when it closes. Mapping it as backed up lost those records.
        await txn.insert(
            'id_map',
            {
              'entity_type': isOpen ? MapEntity.meetingTwin : MapEntity.meeting,
              'local_id': localMeeting[meeting.id],
              'remote_id': meeting.id,
              'group_id': remoteGroupId,
              'synced_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // Every money row brought over is already online: remembered by the
      // request id a sync would send it under, so it never is.
      Future<void> imported(String prefix, String localRowId, String remoteEntryId) => txn.insert(
          'id_map',
          {
            'entity_type': MapEntity.importedEntry,
            'local_id': '$prefix-$localRowId',
            'remote_id': remoteEntryId,
            'group_id': remoteGroupId,
            'synced_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace);

      // --- PASS 2: resolve members from the bundle ---
      // Build a complete remote-member-id -> local-member-id map so that
      // Pass 3 never skips an entry for want of a mapping. Members already
      // in id_map (from a prior sync) are reused; the rest are de-duplicated
      // against existing local members by phone, then created fresh.
      final resolvedMembers = Map<String, String>.from(localMemberFor);
      for (final remoteMember in bundle.members) {
        final existingLocalId = resolvedMembers[remoteMember.id];
        if (existingLocalId != null) continue;

        // Try to match an existing local member by phone.
        final match = matchLocalMember(
          remoteMember.phone,
          [
            for (final row in await txn.query('members',
                columns: ['id', 'name', 'phone'],
                where: 'group_id = ?',
                whereArgs: [localGroupId]))
              LocalMember(
                row['id'] as String,
                row['name'] as String,
                row['phone'] as String?,
              ),
          ],
        );
        if (match != null) {
          resolvedMembers[remoteMember.id] = match;
          await txn.insert(
              'id_map',
              {
                'entity_type': MapEntity.member,
                'local_id': match,
                'remote_id': remoteMember.id,
                'group_id': remoteGroupId,
                'synced_at': DateTime.now().toIso8601String(),
              },
              conflictAlgorithm: ConflictAlgorithm.replace);
          continue;
        }

        // No match — create a local member and map it.
        final localId = _uuid.v4();
        await txn.insert('members', {
          'id': localId,
          'group_id': localGroupId,
          'name': remoteMember.fullName,
          'phone': remoteMember.phone,
          'role': MemberRole.fromAny(remoteMember.role).name,
          'is_active': 1,
          'joined_at': DateTime.now().toIso8601String(),
        });
        await txn.insert(
            'id_map',
            {
              'entity_type': MapEntity.member,
              'local_id': localId,
              'remote_id': remoteMember.id,
              'group_id': remoteGroupId,
              'synced_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
        resolvedMembers[remoteMember.id] = localId;
        names[localId] = remoteMember.fullName;
      }

      // --- PASS 2b: attendance (now all members are resolved) ---
      for (final attendance in bundle.attendance) {
        final meeting = localMeeting[attendance.meetingId];
        final member = resolvedMembers[attendance.memberId];
        if (meeting == null || member == null) continue;
        await txn.insert(
            'attendance',
            {
              'meeting_id': meeting,
              'member_id': member,
              'present': attendance.present ? 1 : 0,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore);
      }

      // --- PASS 3: loans first, so a repayment can find its loan ---
      final localLoan = <String, String>{};
      for (final entry in entries) {
        if (entry.type != 'INTERNAL_LOAN_DISBURSEMENT') continue;
        final member = resolvedMembers[entry.memberId];
        final meeting = localMeeting[entry.meetingId];
        if (member == null || meeting == null) {
          if (member == null && entry.memberId != null) unmappedSkipped++;
          skipped++;
          continue;
        }
        final loan = loanByEntry[entry.id];
        final rateBps = loan?.interestRateBps ?? bundle.loanInterestRateBps;
        final term = loan?.termMonths ?? bundle.defaultLoanTermMonths;
        // Each loan keeps the interest type it was lent under.
        final type = (loan?.interestType ?? bundle.interestType) == 'REDUCING'
            ? InterestType.reducingBalance
            : InterestType.flat;
        final disbursed = loan?.disbursedAt ?? entry.createdAt;
        final due = loan?.dueAt ??
            DateTime(disbursed.year, disbursed.month + term, disbursed.day);
        final principal = _kes(entry.amountCents);
        final id = _uuid.v4();
        await txn.insert('loans', {
          'id': id,
          'group_id': localGroupId,
          'member_id': member,
          'meeting_id': meeting,
          'principal': principal,
          'interest_rate': rateBps / 100,
          'interest_type': type.name,
          'total_due': LoanCalculator.totalDue(
            principal: principal,
            monthlyRatePercent: rateBps / 100,
            termMonths: term < 1 ? 1 : term,
            type: type,
          ),
          'disbursed_at': _local(disbursed),
          'due_date': _local(due),
          'status': switch (loan?.status) {
            'REPAID' => LoanStatus.repaid.name,
            'WRITTEN_OFF' => LoanStatus.defaulted.name,
            'CARRIED_FORWARD' => LoanStatus.carriedForward.name,
            _ => LoanStatus.active.name,
          },
          'created_at': _local(entry.createdAt),
        });
        await imported('lnd', id, entry.id);
        if (loan != null) localLoan[loan.id] = id;
        loansMade++;
      }

      // --- PASS 3b: everything else a meeting recorded ---
      for (final entry in entries) {
        final meeting = localMeeting[entry.meetingId];
        final member = resolvedMembers[entry.memberId];
        final amount = _kes(entry.amountCents);
        switch (entry.type) {
          case 'SHARE_PURCHASE':
            if (meeting == null || member == null) {
              if (member == null && entry.memberId != null) unmappedSkipped++;
              skipped++;
              break;
            }
            final shares = shareValue > 0 ? (amount / shareValue).round() : 1;
            final count = shares < 1 ? 1 : shares;
            final method = PaymentMethod.values.firstWhere(
              (m) => m != PaymentMethod.cash && entry.description.contains(m.label),
              orElse: () => PaymentMethod.cash,
            );
            final shareRowId = _uuid.v4();
            await imported('shr', shareRowId, entry.id);
            await txn.insert('share_purchases', {
              'id': shareRowId,
              'meeting_id': meeting,
              'member_id': member,
              'shares': count,
              // Whatever was really paid, exactly: never rounded to a share.
              'unit_value': amount / count,
              'amount': amount,
              'payment_method': method.name,
              'payment_reference': entry.externalReference,
              'created_at': _local(entry.createdAt),
            });
            records++;
          case 'SOCIAL_CONTRIBUTION':
            if (meeting == null || member == null) {
              if (member == null && entry.memberId != null) unmappedSkipped++;
              skipped++;
              break;
            }
            final socialRowId = _uuid.v4();
            await imported('soc', socialRowId, entry.id);
            await txn.insert('social_fund_entries', {
              'id': socialRowId,
              'meeting_id': meeting,
              'member_id': member,
              'amount': amount,
              'created_at': _local(entry.createdAt),
            });
            records++;
          case 'FINE_COLLECTION':
            if (meeting == null || member == null) {
              if (member == null && entry.memberId != null) unmappedSkipped++;
              skipped++;
              break;
            }
            final reason = entry.description.replaceFirst(RegExp(r'^Fine\s*·?\s*'), '').trim();
            final fineRowId = _uuid.v4();
            await imported('fin', fineRowId, entry.id);
            await txn.insert('fines', {
              'id': fineRowId,
              'meeting_id': meeting,
              'member_id': member,
              'amount': amount,
              'reason': reason.isEmpty ? 'Fine' : reason,
              'created_at': _local(entry.createdAt),
            });
            records++;
          case 'LOAN_REPAYMENT':
            // As the server applied it: one slice per loan it paid (a payment
            // can clear an old loan and roll onto the next). Whatever no loan
            // took stays with the loan the row points at. An older server
            // sends no slices: the row's own loan then takes all of it.
            final slices = [
              for (final slice in slicesFor[entry.id] ?? const <RestoreAllocation>[])
                if (localLoan[slice.loanId] != null) slice,
            ];
            final placed = <(String, int)>[
              for (final slice in slices) (localLoan[slice.loanId]!, slice.cents),
            ];
            final rest = entry.amountCents - slices.fold<int>(0, (sum, slice) => sum + slice.cents);
            if (rest > 0) {
              final own = localLoan[entry.loanId] ?? (placed.isEmpty ? null : placed.last.$1);
              if (own != null) placed.add((own, rest));
            }
            if (placed.isEmpty) {
              skipped++;
              break;
            }
            for (final (loanId, cents) in placed) {
              final repaymentRowId = _uuid.v4();
              await imported('rpy', repaymentRowId, entry.id);
              await txn.insert('loan_repayments', {
                'id': repaymentRowId,
                'loan_id': loanId,
                'meeting_id': meeting,
                'amount': _kes(cents),
                'paid_at': _local(entry.createdAt),
              });
            }
            records++;
        }
      }

      // --- past share-outs, from what was paid out in each closed cycle ---
      final byCycle = <int, List<RestoreEntry>>{};
      for (final entry in entries) {
        final cycle = entry.cycleNumber;
        if (cycle != null) (byCycle[cycle] ??= []).add(entry);
      }
      for (final cycle in byCycle.entries) {
        // Only cycles that are CLOSED. A payout in the open cycle is a console
        // share-out that did not close it: its balances already start after it
        // (above), and recording it as this phone's share-out for the open cycle
        // would mark that cycle as sent - so the phone's own share-out for it, when
        // the group makes one, would never be.
        if (cycle.key >= bundle.cycleNumber) continue;
        final paid = cycle.value
            .where((e) => e.type == 'SHARE_OUT_PAYOUT' || e.type == 'WELFARE_SHARE_OUT')
            .toList();
        if (paid.isEmpty) continue;

        final gross = <String, int>{};
        final welfare = <String, int>{};
        final offset = <String, int>{};
        final shares = <String, int>{};
        for (final e in cycle.value) {
          final memberId = e.memberId;
          if (memberId == null) continue;
          switch (e.type) {
            case 'SHARE_OUT_PAYOUT':
              gross[memberId] = (gross[memberId] ?? 0) + e.amountCents;
            case 'WELFARE_SHARE_OUT':
              welfare[memberId] = (welfare[memberId] ?? 0) + e.amountCents;
            case 'LOAN_REPAYMENT' when e.description.startsWith('Loan settled from share-out'):
              offset[memberId] = (offset[memberId] ?? 0) + e.amountCents;
            case 'SHARE_PURCHASE':
              shares[memberId] = (shares[memberId] ?? 0) + e.amountCents;
          }
        }
        final at = paid.map((e) => e.createdAt).reduce((a, b) => a.isAfter(b) ? a : b);
        final members = {...gross.keys, ...welfare.keys, ...offset.keys};
        var wrote = 0;
        for (final remoteMember in members) {
          final local = resolvedMembers[remoteMember];
          if (local == null) continue;
          final g = gross[remoteMember] ?? 0;
          final w = welfare[remoteMember] ?? 0;
          final o = offset[remoteMember] ?? 0;
          await txn.insert('share_out_payouts', {
            'id': _uuid.v4(),
            'group_id': localGroupId,
            'cycle_number': cycle.key,
            'member_id': local,
            'member_name': names[local] ?? 'Member',
            'share_amount': _kes(shares[remoteMember] ?? 0),
            'gross_payout': _kes(g),
            'welfare_payout': _kes(w),
            'loan_offset': _kes(o),
            'net_payout': _kes(g + w - o),
            'created_at': _local(at),
          });
          wrote++;
        }
        if (wrote == 0) continue;
        shareOuts++;
        // It came from the online record, so it is never sent back.
        await txn.insert(
            'id_map',
            {
              'entity_type': MapEntity.shareOut,
              'local_id': '$localGroupId#${cycle.key}',
              'remote_id': restoredShareOutMarker,
              'group_id': remoteGroupId,
              'synced_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    return HistoryImportResult(
      meetings: meetings.length,
      records: records,
      loans: loansMade,
      shareOuts: shareOuts,
      skipped: skipped,
      hasUnmappedMemberSkipped: unmappedSkipped > 0,
    );
  }
}
