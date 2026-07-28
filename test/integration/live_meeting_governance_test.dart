@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/network/api_client.dart';
import 'package:intellicash_mobile/core/network/api_credentials.dart';
import 'package:intellicash_mobile/data/services/remote_meeting_api.dart';
import 'package:intellicash_mobile/data/models/remote/meeting_models.dart';
import 'package:intellicash_mobile/data/services/remote_write_api.dart'
    show LedgerEntryInput;

/// End-to-end **3-key meeting governance** test against a RUNNING backend.
///
/// Drives the real ApiClient -> RemoteMeetingApi through the full lifecycle:
/// create -> submit 3 official PINs -> open -> attendance -> ledger ->
/// complete all 8 steps -> seal, then reads the ledger back for the summary.
///
/// Excluded from the default suite (tagged `live`). Run explicitly with the
/// backend up:
///   flutter test test/integration/live_meeting_governance_test.dart \
///     --tags live --dart-define=IC_TOKEN=ic_sk_...
void main() {
  const baseUrl = 'http://localhost:4000/api/v1';
  const token = String.fromEnvironment('IC_TOKEN');

  // Seed group IWL-KBU-0001 (Tujijenge) + its three officials with PINs.
  const groupId = 'cmrkfdvx00018v0fcpaekt1m7';
  const maryId = 'cmrkfdxie001ev0fcdg15b03l'; // CHAIRPERSON / 111111
  const faithId = 'cmrkfdxig001gv0fcbh6o2ap2'; // SECRETARY / 222222
  const agnesId = 'cmrkfdxig001iv0fc30jwb7ik'; // TREASURER / 333333

  test('runs the full 3-key meeting lifecycle end to end', () async {
    final client = ApiClient(
      credentials: () => const ApiCredentials(baseUrl: baseUrl, apiKey: token),
    );
    final api = RemoteMeetingApi(client);

    // 1. Create — seeds the 8 workflow steps.
    final created = await api.createMeeting(
      groupId: groupId,
      title: 'Dart live governance test',
      scheduledAt: DateTime.now(),
    );
    expect(created.isScheduled, isTrue);
    expect(created.steps.length, kMeetingStepOrder.length);
    final meetingId = created.id;

    // 2. Submit the three officials' PINs -> unlock ready.
    final unlock = await api.submitKeySubmissions(
      groupId: groupId,
      meetingId: meetingId,
      submissions: const [
        KeySubmissionInput(memberId: maryId, pin: '111111'),
        KeySubmissionInput(memberId: faithId, pin: '222222'),
        KeySubmissionInput(memberId: agnesId, pin: '333333'),
      ],
    );
    expect(unlock.canOpen, isTrue);
    expect(unlock.officialsVerified, greaterThanOrEqualTo(3));

    // 3. Open -> IN_PROGRESS.
    final opened =
        await api.openMeeting(groupId: groupId, meetingId: meetingId);
    expect(opened.isInProgress, isTrue);

    // 4. Attendance.
    await api.recordAttendance(
      groupId: groupId,
      meetingId: meetingId,
      memberId: maryId,
      status: 'PRESENT',
    );

    // 5. Ledger — a share purchase + a social contribution.
    await api.postLedger(
      groupId: groupId,
      meetingId: meetingId,
      entries: [
        LedgerEntryInput(
          memberId: maryId,
          type: 'SHARE_PURCHASE',
          amountCents: 100000,
          clientRequestId: 'dart-live-share-$meetingId',
        ),
        LedgerEntryInput(
          memberId: maryId,
          type: 'SOCIAL_CONTRIBUTION',
          amountCents: 20000,
          clientRequestId: 'dart-live-social-$meetingId',
        ),
      ],
    );

    // 6. Read ledger back -> financial summary.
    final ledger =
        await api.ledgerForMeeting(groupId: groupId, meetingId: meetingId);
    final summary = MeetingFinancialSummary.fromLedger(ledger);
    expect(summary.shares, 1000);
    expect(summary.social, 200);
    expect(summary.totalIn, 1200);

    // 7. Complete all steps in order.
    for (final step in kMeetingStepOrder) {
      await api.completeStep(
          groupId: groupId, meetingId: meetingId, step: step);
    }

    // 8. Seal.
    final sealed = await api.seal(
      groupId: groupId,
      meetingId: meetingId,
      minutes: 'Sealed by Dart live governance test.',
    );
    expect(sealed.isSealed, isTrue);

    client.close();
  }, skip: token.isEmpty ? 'live test: pass --dart-define=IC_TOKEN=ic_sk_…' : false);
}
