import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../repositories/attachment_repository.dart';
import '../repositories/visit_repository.dart';

/// Pushes photographs, one at a time, after their visit has landed.
///
/// Three rules shape this:
///
/// 1. **A photo failure never fails a visit.** The visit is already on the
///    server by the time any of this runs; anything that does not make it stays
///    on the device and is retried.
/// 2. **Serially, not in parallel.** Fifteen simultaneous multipart uploads
///    over a rural link is how you get fifteen timeouts. One at a time also
///    makes "3 of 14" an honest thing to display.
/// 3. **Two steps, resumable.** The bytes go first, then the binding. A phone
///    that dies between them resumes at the binding and does not re-send the
///    expensive part.
class AttachmentSyncService {
  AttachmentSyncService({
    required ApiClient client,
    AttachmentRepository? attachments,
    VisitRepository? visits,
  })  : _client = client,
        _attachments = attachments ?? AttachmentRepository(),
        _visits = visits ?? VisitRepository();

  final ApiClient _client;
  final AttachmentRepository _attachments;
  final VisitRepository _visits;

  /// Failures that will fail identically however many times they are tried.
  ///
  /// `UPLOAD_STORAGE_FULL` is deliberately absent: the server's disk being
  /// full is the textbook temporary condition, and the 503 is meant to be
  /// retried once somebody clears space.
  static const _permanent = {
    'VISIT_NOT_FOUND',
    'VALIDATION_ERROR',
    'FORBIDDEN',
    'UPLOAD_TYPE_NOT_ALLOWED',
    'ATTACHMENT_LIMIT_REACHED',
  };

  /// Reports progress so the UI can say "3 of 14" rather than spinning.
  void Function(int done, int total)? onProgress;

  /// Attempts every due photograph. Returns how many reached the server.
  Future<int> pushDue() async {
    final due = await _attachments.due();
    if (due.isEmpty) return 0;

    var done = 0;
    for (final attachment in due) {
      onProgress?.call(done, due.length);
      if (await _push(attachment)) done += 1;
    }
    onProgress?.call(done, due.length);

    // Reclaim the disk only for what is safely on the server.
    await _attachments.pruneUploadedFiles();
    return done;
  }

  Future<bool> _push(LocalAttachment attachment) async {
    final visit = await _visits.byId(attachment.visitId);
    final remoteVisitId = visit?.remoteId;
    // Cannot be addressed until the visit exists centrally. Not an error —
    // the visit is presumably still queued, and this will come round again.
    if (remoteVisitId == null) return false;

    try {
      var storagePath = attachment.storagePath;
      var sha256 = attachment.sha256;

      // Skip the expensive step if a previous attempt already got the bytes up.
      if (!attachment.needsBindingOnly) {
        final uploaded = await _client.postMultipart(
          '/uploads/visit-photo',
          field: 'file',
          filePath: attachment.localPath,
          fileName: attachment.fileName,
          contentType: attachment.mimeType,
        );
        final map = uploaded is Map<String, dynamic> ? uploaded : const <String, dynamic>{};
        storagePath = map['storagePath'] as String?;
        sha256 = map['sha256'] as String?;
        if (storagePath == null || sha256 == null) {
          await _attachments.markFailure(
            id: attachment.id,
            error: 'Upload returned no storage path.',
          );
          return false;
        }
        await _attachments.markUploaded(
          id: attachment.id,
          storagePath: storagePath,
          sha256: sha256,
        );
      }

      final bound = await _client.postData(
        '/visits/$remoteVisitId/attachments',
        body: {
          'storagePath': storagePath,
          'fileName': attachment.fileName,
          'mimeType': attachment.mimeType,
          'size': attachment.sizeBytes,
          'sha256': sha256,
          'sectionKey': attachment.sectionKey,
          if (attachment.questionKey != null) 'questionKey': attachment.questionKey,
          'capturedAt': attachment.capturedAt.toIso8601String(),
          if (attachment.caption != null) 'caption': attachment.caption,
          'clientRequestId': attachment.clientRequestId,
        },
      );

      final map = bound is Map<String, dynamic> ? bound : const <String, dynamic>{};
      final remoteId = map['id'] as String?;
      if (remoteId == null) {
        await _attachments.markFailure(
          id: attachment.id,
          error: 'Binding returned no attachment id.',
        );
        return false;
      }

      await _attachments.markBound(id: attachment.id, remoteId: remoteId);
      return true;
    } on ApiException catch (error) {
      await _attachments.markFailure(
        id: attachment.id,
        error: _permanent.contains(error.code)
            ? '${error.message} (will not retry)'
            : error.message,
      );
      return false;
    } catch (error) {
      // Network, DNS, a timeout partway through a 400 KB push. All retryable,
      // and the file is still on the device.
      await _attachments.markFailure(id: attachment.id, error: '$error');
      return false;
    }
  }

  Future<int> pendingCount() => _attachments.pendingCount();
}
