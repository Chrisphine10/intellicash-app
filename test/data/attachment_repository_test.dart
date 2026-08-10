import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intellicash_mobile/core/database/app_database.dart';
import 'package:intellicash_mobile/data/repositories/attachment_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// The photo queue.
///
/// The property that matters most here is that a file is never deleted before
/// its upload has succeeded. An agent photographs a group's cash count once; by
/// the time a failed push is noticed, everyone has gone home.
void main() {
  late Directory tempDir;
  late Directory photoDir;
  late AttachmentRepository attachments;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ic_attachments');
    photoDir = await Directory.systemTemp.createTemp('ic_photos');
    AppDatabase.overrideFactory = databaseFactoryFfi;
    AppDatabase.overridePath = tempDir.path;
    attachments = AttachmentRepository();
  });

  tearDown(() async {
    await AppDatabase.instance.close();
    AppDatabase.overrideFactory = null;
    AppDatabase.overridePath = null;
    await tempDir.delete(recursive: true);
    if (await photoDir.exists()) await photoDir.delete(recursive: true);
  });

  Future<void> seedVisit(String visitId, {String? remoteId}) async {
    final db = await AppDatabase.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('group_visits', {
      'id': visitId,
      'client_request_id': 'visit-$visitId',
      'remote_group_id': 'remote-g1',
      'visit_type': 'FOLLOW_UP',
      'status': 'DRAFT',
      'started_at': now,
      'remote_id': remoteId,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// A real file on disk, so deletion behaviour can be observed rather than
  /// assumed.
  Future<String> photoFile(String name) async {
    final file = File('${photoDir.path}/$name');
    await file.writeAsBytes(List<int>.filled(256, 7));
    return file.path;
  }

  Future<LocalAttachment?> enqueue(
    String visitId, {
    String name = 'a.jpg',
    String section = 'governance',
    String? question = 'constitution_written',
  }) async {
    return attachments.enqueue(
      visitId: visitId,
      sectionKey: section,
      questionKey: question,
      localPath: await photoFile(name),
      fileName: name,
      mimeType: 'image/jpeg',
      sizeBytes: 256,
    );
  }

  group('capturing', () {
    test('records a photo against the question it is evidence for', () async {
      await seedVisit('v1');
      final saved = await enqueue('v1');

      expect(saved, isNotNull);
      expect(saved!.sectionKey, 'governance');
      expect(saved.questionKey, 'constitution_written');
      expect(saved.status, AttachmentStatus.pending);
      // Minted once and never regenerated — it is what makes binding idempotent.
      expect(saved.clientRequestId, startsWith('att-'));
    });

    test('refuses beyond the cap the server would reject anyway', () async {
      await seedVisit('v1');
      for (var i = 0; i < AttachmentRepository.maxPerVisit; i++) {
        expect(await enqueue('v1', name: 'p$i.jpg'), isNotNull);
      }

      // Null rather than an exception: the caller shows a message, and the
      // agent is not presented with a crash for taking one photo too many.
      expect(await enqueue('v1', name: 'over.jpg'), isNull);
      expect(await attachments.countFor('v1'), AttachmentRepository.maxPerVisit);
    });

    test('lists a question\'s photos so the agent sees what they took', () async {
      await seedVisit('v1');
      await enqueue('v1', name: 'a.jpg', question: 'constitution_written');
      await enqueue('v1', name: 'b.jpg', question: 'constitution_written');
      await enqueue('v1', name: 'c.jpg', question: 'committee_complete');

      final forQuestion = await attachments.forQuestion(
        visitId: 'v1',
        questionKey: 'constitution_written',
      );
      expect(forQuestion.length, 2);
    });

    test('discarding a photo removes its file too', () async {
      await seedVisit('v1');
      final saved = await enqueue('v1');
      expect(File(saved!.localPath).existsSync(), isTrue);

      await attachments.discard(saved.id);

      expect(await attachments.countFor('v1'), 0);
      expect(File(saved.localPath).existsSync(), isFalse);
    });
  });

  group('what is due to push', () {
    test('nothing until the visit itself has reached the server', () async {
      // An attachment cannot be addressed before the visit it belongs to
      // exists centrally — the URL contains the visit's remote id.
      await seedVisit('v1');
      await enqueue('v1');

      expect(await attachments.due(), isEmpty);
    });

    test('queued once the visit has a remote id', () async {
      await seedVisit('v1', remoteId: 'remote-v1');
      await enqueue('v1');

      final due = await attachments.due();
      expect(due.length, 1);
      expect(due.first.visitId, 'v1');
    });

    test('stops being due once bound', () async {
      await seedVisit('v1', remoteId: 'remote-v1');
      final saved = await enqueue('v1');

      await attachments.markBound(id: saved!.id, remoteId: 'remote-att-1');

      expect(await attachments.due(), isEmpty);
      expect(await attachments.pendingCount(), 0);
    });
  });

  group('resuming a half-finished push', () {
    test('an uploaded-but-unbound photo skips re-sending the bytes', () async {
      // The expensive step is the multipart push. A phone that died between the
      // two steps must not repeat it over a 2G link.
      await seedVisit('v1', remoteId: 'remote-v1');
      final saved = await enqueue('v1');

      await attachments.markUploaded(
        id: saved!.id,
        storagePath: 'visit-photo/2026/08/x.jpg',
        sha256: 'a' * 64,
      );

      final due = await attachments.due();
      expect(due.first.needsBindingOnly, isTrue);
      expect(due.first.status, AttachmentStatus.uploaded);
    });

    test('a failure is counted and kept, not dropped', () async {
      await seedVisit('v1', remoteId: 'remote-v1');
      final saved = await enqueue('v1');

      await attachments.markFailure(id: saved!.id, error: 'connection reset');
      await attachments.markFailure(id: saved.id, error: 'connection reset');

      final due = await attachments.due();
      expect(due.length, 1);
      expect(due.first.attempts, 2);
      expect(due.first.lastError, 'connection reset');
      // Still on the device. The evidence outlives the failure.
      expect(File(due.first.localPath).existsSync(), isTrue);
    });
  });

  group('reclaiming disk', () {
    test('never deletes a file whose upload has not succeeded', () async {
      // The single most important rule here. A file removed while its upload is
      // outstanding is evidence destroyed, and it cannot be retaken.
      await seedVisit('v1', remoteId: 'remote-v1');
      final pending = await enqueue('v1', name: 'pending.jpg');
      final failed = await enqueue('v1', name: 'failed.jpg');
      await attachments.markFailure(id: failed!.id, error: 'timeout');

      await attachments.pruneUploadedFiles();

      expect(File(pending!.localPath).existsSync(), isTrue);
      expect(File(failed.localPath).existsSync(), isTrue);
    });

    test('deletes the file once it is safely on the server', () async {
      await seedVisit('v1', remoteId: 'remote-v1');
      final saved = await enqueue('v1');
      await attachments.markBound(id: saved!.id, remoteId: 'remote-att-1');

      final removed = await attachments.pruneUploadedFiles();

      expect(removed, 1);
      expect(File(saved.localPath).existsSync(), isFalse);
      // The row survives — it is the record that the photo exists remotely.
      expect(await attachments.countFor('v1'), 1);
    });

    test('is safe to run twice', () async {
      await seedVisit('v1', remoteId: 'remote-v1');
      final saved = await enqueue('v1');
      await attachments.markBound(id: saved!.id, remoteId: 'remote-att-1');

      expect(await attachments.pruneUploadedFiles(), 1);
      // Second pass finds nothing left to do rather than erroring on a missing
      // file — a sync that runs every reconnect must be idempotent.
      expect(await attachments.pruneUploadedFiles(), 0);
    });
  });

  test('photos are removed with the visit they belong to', () async {
    final db = await AppDatabase.instance.database;
    await seedVisit('v1');
    await enqueue('v1');

    await db.delete('group_visits', where: 'id = ?', whereArgs: ['v1']);

    expect(await attachments.countFor('v1'), 0);
  });
}
