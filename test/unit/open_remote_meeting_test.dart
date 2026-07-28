import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/data/models/remote/remote_models.dart';

/// Mirrors `ConnectionProvider.openRemoteMeeting`, which picks the sitting the
/// server considers open.
///
/// This matters because meetings created on the phone carry a client-side
/// UUID the backend has never seen. Anything recorded against a meeting —
/// a store purchase agreed during it, an external loan application — has to
/// use the server's id or the backend rejects it.
RemoteMeeting? openRemoteMeeting(List<RemoteMeeting> meetings) {
  for (final meeting in meetings) {
    if (meeting.status == 'OPEN' && !meeting.isClosed) return meeting;
  }
  return null;
}

RemoteMeeting _meeting(
  String id, {
  required String status,
  DateTime? closedAt,
}) =>
    RemoteMeeting(
      id: id,
      title: 'Meeting $id',
      status: status,
      closedAt: closedAt,
      unlockStatus: 'UNLOCKED',
      transactionTotal: 0,
    );

void main() {
  group('picking the meeting the server has open', () {
    test('finds the open sitting', () {
      final meetings = [
        _meeting('cmr-closed', status: 'CLOSED'),
        _meeting('cmr-open', status: 'OPEN'),
      ];
      expect(openRemoteMeeting(meetings)?.id, 'cmr-open');
    });

    test('returns nothing when the group is not sitting', () {
      final meetings = [
        _meeting('cmr-1', status: 'SCHEDULED'),
        _meeting('cmr-2', status: 'CLOSED'),
      ];
      expect(openRemoteMeeting(meetings), isNull);
    });

    test('ignores a meeting marked OPEN that already has a closing time', () {
      // A sealed meeting whose status has not caught up must not collect new
      // purchases.
      final meetings = [
        _meeting('cmr-stale', status: 'OPEN', closedAt: DateTime(2026, 7, 1)),
      ];
      expect(openRemoteMeeting(meetings), isNull);
    });

    test('an empty list is not an error', () {
      expect(openRemoteMeeting(const []), isNull);
    });
  });
}
