import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/domain_exception.dart';

class LocalArchive {
  const LocalArchive({
    required this.id,
    required this.label,
    required this.createdAt,
    required this.bytes,
  });

  final String id;
  final String label;
  final DateTime createdAt;
  final int bytes;
}

/// Keeps a compressed, local-only copy of an offline book before another
/// account takes over the phone. Archives never upload and can be deleted one
/// at a time by a guest.
class LocalDataVault {
  LocalDataVault(this._database, {Future<Directory> Function()? documents})
      : _documents = documents ?? getApplicationDocumentsDirectory;

  final AppDatabase _database;

  /// Where archives live: the app's documents folder (a test passes its own).
  final Future<Directory> Function() _documents;

  Future<Directory> _directory() async {
    final root = await _documents();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}archives',
    );
    await directory.create(recursive: true);
    return directory;
  }

  Future<List<LocalArchive>> list() async {
    final directory = await _directory();
    final files =
        directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json.gz'))
            .toList()
          ..sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
          );
    return [
      for (final file in files)
        LocalArchive(
          id: file.uri.pathSegments.last.replaceFirst('.json.gz', ''),
          label: _label(file),
          createdAt: file.statSync().modified,
          bytes: file.lengthSync(),
        ),
    ];
  }

  Future<LocalArchive> archive({String? label}) async {
    final db = await _database.database;
    // One read transaction: every table as it stood at one moment. Reading
    // them one after another let a sync land in between, and a meeting could
    // be archived without the money recorded in it.
    final snapshot = await db.transaction((txn) async {
      final tables = await _tables(txn);
      return {for (final table in tables) table: await txn.query(table)};
    });
    final payload = <String, dynamic>{
      'version': 1,
      'schemaVersion': await db.getVersion(),
      'label': label ?? 'Guest local data',
      'createdAt': DateTime.now().toIso8601String(),
      'tables': snapshot,
    };
    final id = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final directory = await _directory();
    final file = File('${directory.path}${Platform.pathSeparator}$id.json.gz');
    // Written beside the final name, then renamed: a phone that dies mid-write
    // leaves a stray .tmp, never a half-written archive that looks complete.
    final partial = File('${file.path}.tmp');
    await partial.writeAsBytes(gzip.encode(utf8.encode(jsonEncode(payload))), flush: true);
    await partial.rename(file.path);
    return LocalArchive(
      id: id,
      label: payload['label'] as String,
      createdAt: DateTime.now(),
      bytes: await file.length(),
    );
  }

  /// Puts an archive back as the phone's book.
  ///
  /// It replaces everything on the phone, so it refuses while anything is
  /// waiting to go online ([unsentWork] > 0) - that work would exist nowhere
  /// else - and it archives the current book first, so recovering the wrong
  /// archive can itself be undone. An archive from a NEWER version of the app
  /// is refused (its rows may not fit); an older one is filled into today's
  /// tables, column by column.
  ///
  /// Foreign keys are switched off OUTSIDE the transaction (SQLite ignores the
  /// switch inside one; with them on, tables refilled in name order failed on
  /// the first attendance row and nothing could ever be recovered), and the
  /// result is checked with `foreign_key_check` before it is committed.
  Future<void> recover(String id, {Future<int> Function()? unsentWork}) async {
    final directory = await _directory();
    final file = File('${directory.path}${Platform.pathSeparator}$id.json.gz');
    if (!await file.exists()) throw DomainException('Archive not found.');
    final payload = jsonDecode(
      utf8.decode(gzip.decode(await file.readAsBytes())),
    );
    if (payload is! Map || payload['tables'] is! Map) {
      throw DomainException('Archive is invalid.');
    }
    final db = await _database.database;
    final current = await db.getVersion();
    final archivedVersion = payload['schemaVersion'];
    if (archivedVersion is int && archivedVersion > current) {
      throw DomainException(
        'This archive was made by a newer version of the app. Update the app, then recover it.',
      );
    }

    final waiting = await unsentWork?.call() ?? 0;
    if (waiting > 0) {
      throw DomainException(
        '$waiting record(s) on this phone have not been backed up online yet. '
        'Connect and let them sync before recovering an archive.',
      );
    }

    await archive(label: 'Before recovering ${_label(file)}');

    final archived = payload['tables'] as Map;
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((txn) async {
        final tables = await _tables(txn);
        for (final table in tables) {
          await txn.delete(table);
        }
        for (final table in tables) {
          final rows = archived[table];
          if (rows is! List) continue;
          final columns = {
            for (final info in await txn.rawQuery('PRAGMA table_info("${table.replaceAll('"', '""')}")'))
              info['name'] as String,
          };
          for (final row in rows) {
            if (row is! Map) continue;
            await txn.insert(table, {
              for (final entry in row.entries)
                if (columns.contains(entry.key)) entry.key as String: entry.value,
            });
          }
        }
        final broken = await txn.rawQuery('PRAGMA foreign_key_check');
        if (broken.isNotEmpty) {
          throw DomainException(
            'The archive does not hold together (${broken.length} record(s) point at missing ones); nothing was changed.',
          );
        }
      });
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  /// The archive's file, for exporting it off the phone (e.g. to a
  /// computer, or to IntelliCash support). It is the phone's own records, so
  /// it is only ever handed to the share sheet the person opens themselves.
  Future<File> fileFor(String id) async {
    final directory = await _directory();
    final file = File('${directory.path}${Platform.pathSeparator}$id.json.gz');
    if (!await file.exists()) throw DomainException('Archive not found.');
    return file;
  }

  Future<void> delete(String id) async {
    final directory = await _directory();
    final file = File('${directory.path}${Platform.pathSeparator}$id.json.gz');
    if (await file.exists()) await file.delete();
  }

  Future<List<String>> _tables(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    return [
      for (final row in rows)
        if (row['name'] is String) row['name'] as String,
    ];
  }

  String _label(File file) {
    final name = file.uri.pathSegments.last.replaceFirst('.json.gz', '');
    return name.replaceAll('-', ':');
  }
}
