import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/data/models/remote/meeting_models.dart';

void main() {
  group('RemoteMeetingDetail', () {
    final json = {
      'id': 'm1',
      'title': 'Weekly meeting',
      'status': 'IN_PROGRESS',
      'scheduledAt': '2026-07-17T09:00:00.000Z',
      'unlockStatus': 'OFFICIALS_VERIFIED',
      'steps': [
        {'step': 'OPENING_AND_3_KEY_SECURITY', 'status': 'COMPLETED'},
        {'step': 'MINUTES_REVIEW', 'status': 'ACTIVE'},
        {'step': 'SOCIAL_FUND_ROUND', 'status': 'PENDING'},
      ],
      'attendance': [
        {'memberId': 'a', 'status': 'PRESENT', 'member': {'fullName': 'Mary'}},
        {'memberId': 'b', 'status': 'ABSENT', 'member': {'fullName': 'Jane'}},
        {'memberId': 'c', 'status': 'LATE', 'member': {'fullName': 'Ann'}},
      ],
      'keySubmissions': [
        {
          'memberId': 'a',
          'credentialType': 'DEFAULT_PIN',
          'verifiedAt': '2026-07-17T09:01:00.000Z',
          'member': {'fullName': 'Mary', 'role': 'CHAIRPERSON'},
        },
      ],
    };

    test('parses status, steps and active step', () {
      final m = RemoteMeetingDetail.fromJson(json);
      expect(m.isInProgress, isTrue);
      expect(m.isScheduled, isFalse);
      expect(m.isSealed, isFalse);
      expect(m.steps, hasLength(3));
      expect(m.completedSteps, 1);
      expect(m.activeStep?.step, 'MINUTES_REVIEW');
    });

    test('present count includes PRESENT and LATE', () {
      final m = RemoteMeetingDetail.fromJson(json);
      expect(m.presentCount, 2);
    });

    test('key submission flags officials', () {
      final m = RemoteMeetingDetail.fromJson(json);
      expect(m.keySubmissions.single.isOfficial, isTrue);
      expect(m.keySubmissions.single.memberName, 'Mary');
    });

    test('falls back to full step order when steps missing', () {
      final m = RemoteMeetingDetail.fromJson({
        'id': 'm2',
        'title': 't',
        'status': 'SCHEDULED',
        'unlockStatus': 'PENDING',
      });
      expect(m.isScheduled, isTrue);
      expect(m.totalSteps, kMeetingStepOrder.length);
    });
  });

  group('MeetingUnlockResult', () {
    test('parses the evaluate-unlock envelope', () {
      final r = MeetingUnlockResult.fromJson({
        'canOpen': true,
        'unlockStatus': 'OFFICIALS_VERIFIED',
        'officialsVerified': 3,
        'membersVerified': 3,
        'requiredOfficials': 3,
        'requiredMembers': 5,
        'message': 'ok',
      });
      expect(r.canOpen, isTrue);
      expect(r.officialsVerified, 3);
      expect(r.requiredMembers, 5);
    });
  });

  group('MeetingFinancialSummary', () {
    test('aggregates ledger by type and direction', () {
      final entries = [
        RemoteLedgerEntry(
            id: '1', type: 'SHARE_PURCHASE', direction: 'CREDIT', amount: 1000),
        RemoteLedgerEntry(
            id: '2', type: 'SHARE_PURCHASE', direction: 'CREDIT', amount: 500),
        RemoteLedgerEntry(
            id: '3',
            type: 'SOCIAL_CONTRIBUTION',
            direction: 'CREDIT',
            amount: 200),
        RemoteLedgerEntry(
            id: '4', type: 'LOAN_REPAYMENT', direction: 'CREDIT', amount: 300),
        RemoteLedgerEntry(
            id: '5',
            type: 'INTERNAL_LOAN_DISBURSEMENT',
            direction: 'DEBIT',
            amount: 800),
        RemoteLedgerEntry(
            id: '6',
            type: 'FINE_COLLECTION',
            direction: 'CREDIT',
            amount: 50),
      ];
      final s = MeetingFinancialSummary.fromLedger(entries);
      expect(s.shares, 1500);
      expect(s.social, 200);
      expect(s.loanRepayments, 300);
      expect(s.fines, 50);
      expect(s.loanDisbursements, 800);
      // in = 1500 + 200 + 300 + 50 = 2050; out = 800; net = 1250
      expect(s.totalIn, 2050);
      expect(s.totalOut, 800);
      expect(s.net, 1250);
      expect(s.count, 6);
    });

    test('unknown types roll into other in/out by direction', () {
      final entries = [
        RemoteLedgerEntry(
            id: '1',
            type: 'EXTERNAL_LOAN_RECEIPT',
            direction: 'CREDIT',
            amount: 5000),
        RemoteLedgerEntry(
            id: '2',
            type: 'EXTERNAL_LOAN_REPAYMENT',
            direction: 'DEBIT',
            amount: 1000),
      ];
      final s = MeetingFinancialSummary.fromLedger(entries);
      expect(s.otherIn, 5000);
      expect(s.otherOut, 1000);
      expect(s.net, 4000);
    });

    test('ledger json maps cents to KES', () {
      final e = RemoteLedgerEntry.fromJson({
        'id': 'x',
        'type': 'SHARE_PURCHASE',
        'direction': 'CREDIT',
        'amountCents': 100000,
        'member': {'fullName': 'Mary'},
      });
      expect(e.amount, 1000.0);
      expect(e.isCredit, isTrue);
      expect(e.memberName, 'Mary');
    });
  });
}
