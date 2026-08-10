import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../repositories/mentorship_repository.dart';
import '../repositories/visit_repository.dart';

/// Pushes coaching records and action items, and pulls the group's outstanding
/// work back down.
///
/// The pull matters as much as the push. An agent arriving for a visit needs
/// last time's commitments on screen before they start, and that moment is
/// usually somewhere with no signal — so the items are fetched whenever there
/// IS signal and cached for when there is not.
class MentorshipSyncService {
  MentorshipSyncService({
    required ApiClient client,
    MentorshipRepository? mentorship,
    VisitRepository? visits,
  })  : _client = client,
        _mentorship = mentorship ?? MentorshipRepository(),
        _visits = visits ?? VisitRepository();

  final ApiClient _client;
  final MentorshipRepository _mentorship;
  final VisitRepository _visits;

  /// Pushes mentorship for visits that have reached the server.
  ///
  /// Never throws. Like photographs, coaching notes must not be able to hold
  /// back a visit that has already landed.
  Future<int> pushDue() async {
    var pushed = 0;

    for (final visit in await _visits.synced()) {
      final remoteVisitId = visit.remoteId;
      if (remoteVisitId == null) continue;

      if (await _mentorship.hasMentorship(visit.id)) {
        if (await _pushMentorship(visit.id, remoteVisitId)) pushed += 1;
      }
    }

    pushed += await _pushActionItems();
    return pushed;
  }

  Future<bool> _pushMentorship(String localVisitId, String remoteVisitId) async {
    try {
      final sessions = await _mentorship.sessionsFor(localVisitId);
      final ratings = await _mentorship.ratingsFor(localVisitId);

      await _client.putData(
        '/visits/$remoteVisitId/mentorship',
        body: {
          'sessions': sessions.map((session) => session.toJson()).toList(),
          'ratings': ratings.map((rating) => rating.toJson()).toList(),
        },
      );
      return true;
    } catch (_) {
      // Retried next reconnect. The rows stay on the phone.
      return false;
    }
  }

  Future<int> _pushActionItems() async {
    var pushed = 0;

    for (final item in await _mentorship.dirty()) {
      try {
        if (item.remoteId == null) {
          // Raised on the phone. Needs its visit to exist centrally first.
          final visit = item.visitId == null ? null : await _visits.byId(item.visitId!);
          final remoteVisitId = visit?.remoteId;
          if (remoteVisitId == null) continue;

          final created = await _client.postData(
            '/visits/$remoteVisitId/action-items',
            body: {
              'title': item.title,
              if (item.detail != null) 'detail': item.detail,
              if (item.owner != null) 'owner': item.owner,
              if (item.dueDate != null) 'dueDate': item.dueDate!.toIso8601String(),
            },
          );
          final remoteId = (created as Map<String, dynamic>?)?['id'] as String?;
          if (remoteId != null) {
            await _mentorship.markSynced(id: item.id, remoteId: remoteId);
            pushed += 1;
          }
        } else {
          // Closed or reopened here — send the status change.
          await _client.patchData(
            '/action-items/${item.remoteId}',
            body: {
              'status': item.status,
              if (item.closingNote != null) 'closingNote': item.closingNote,
            },
          );
          await _mentorship.markSynced(id: item.id, remoteId: item.remoteId!);
          pushed += 1;
        }
      } on ApiException catch (_) {
        // A rejected item stays dirty and is retried; there is no status here
        // that retrying can make worse.
        continue;
      } catch (_) {
        continue;
      }
    }

    return pushed;
  }

  /// Caches a group's outstanding work for the next visit.
  ///
  /// Returns how many items were written, or 0 when there is no signal — which
  /// is not an error, just a reason to rely on what is already cached.
  Future<int> refreshOpenItems(String remoteGroupId) async {
    try {
      final data = await _client.getData('/groups/$remoteGroupId/action-items');
      final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
      final items = (map['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      return await _mentorship.cacheFromServer(
        remoteGroupId: remoteGroupId,
        items: items,
      );
    } catch (_) {
      return 0;
    }
  }

  Future<int> pendingCount() => _mentorship.pendingCount();
}
