import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/database/app_database.dart';

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
  LocalDataVault(this._database);

  final AppDatabase _database;

  Future<Directory> _directory() async {
    final root = await getApplicationDocumentsDirectory();
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
    final tables = await _tables(db);
    final payload = <String, dynamic>{
      'version': 1,
      'label': label ?? 'Guest local data',
      'createdAt': DateTime.now().toIso8601String(),
      'tables': {for (final table in tables) table: await db.query(table)},
    };
    final id = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final directory = await _directory();
    final file = File('${directory.path}${Platform.pathSeparator}$id.json.gz');
    await file.writeAsBytes(gzip.encode(utf8.encode(jsonEncode(payload))));
    return LocalArchive(
      id: id,
      label: payload['label'] as String,
      createdAt: DateTime.now(),
      bytes: await file.length(),
    );
  }

  Future<void> recover(String id) async {
    final directory = await _directory();
    final file = File('${directory.path}${Platform.pathSeparator}$id.json.gz');
    if (!await file.exists()) throw StateError('Archive not found.');
    final payload = jsonDecode(
      utf8.decode(gzip.decode(await file.readAsBytes())),
    );
    if (payload is! Map || payload['tables'] is! Map) {
      throw StateError('Archive is invalid.');
    }
    final db = await _database.database;
    final tables = await _tables(db);
    await db.transaction((txn) async {
      await txn.execute('PRAGMA foreign_keys = OFF');
      for (final table in tables) {
        await txn.delete(table);
      }
      final archived = payload['tables'] as Map;
      for (final table in tables) {
        final rows = archived[table];
        if (rows is! List) continue;
        for (final row in rows) {
          if (row is Map) {
            await txn.insert(table, Map<String, Object?>.from(row));
          }
        }
      }
      await txn.execute('PRAGMA foreign_keys = ON');
    });
  }

  /// The archive's file, for exporting it off the phone (e.g. to a
  /// computer, or to IntelliCash support). It is the phone's own records, so
  /// it is only ever handed to the share sheet the person opens themselves.
  Future<File> fileFor(String id) async {
    final directory = await _directory();
    final file = File('${directory.path}${Platform.pathSeparator}$id.json.gz');
    if (!await file.exists()) throw StateError('Archive not found.');
    return file;
  }

  Future<void> delete(String id) async {
    final directory = await _directory();
    final file = File('${directory.path}${Platform.pathSeparator}$id.json.gz');
    if (await file.exists()) await file.delete();
  }

  Future<List<String>> _tables(Database db) async {
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
