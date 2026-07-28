import 'dart:collection';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warn, error }

/// One captured log line.
class LogRecord {
  LogRecord({
    required this.level,
    required this.tag,
    required this.message,
    required this.time,
    this.error,
  });

  final LogLevel level;
  final String tag;
  final String message;
  final DateTime time;
  final Object? error;

  String get levelLabel => switch (level) {
        LogLevel.debug => 'DEBUG',
        LogLevel.info => 'INFO',
        LogLevel.warn => 'WARN',
        LogLevel.error => 'ERROR',
      };
}

/// App-wide leveled logger.
///
/// Prints through `dart:developer` in debug builds and keeps the last
/// [_maxRecords] entries in memory so a diagnostics screen can show recent
/// activity and errors without a third-party dependency. Cheap enough to
/// call on every network request.
class AppLogger {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const int _maxRecords = 300;
  final ListQueue<LogRecord> _records = ListQueue<LogRecord>();
  final List<void Function(LogRecord)> _listeners = [];

  /// Minimum level actually recorded/printed. Quieter in release.
  LogLevel minLevel = kReleaseMode ? LogLevel.info : LogLevel.debug;

  List<LogRecord> get records => List.unmodifiable(_records);

  List<LogRecord> get errors =>
      _records.where((r) => r.level == LogLevel.error).toList();

  void addListener(void Function(LogRecord) listener) =>
      _listeners.add(listener);
  void removeListener(void Function(LogRecord) listener) =>
      _listeners.remove(listener);

  void debug(String tag, String message) => _log(LogLevel.debug, tag, message);
  void info(String tag, String message) => _log(LogLevel.info, tag, message);
  void warn(String tag, String message, [Object? error]) =>
      _log(LogLevel.warn, tag, message, error);
  void error(String tag, String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.error, tag, message, error, stack);

  void _log(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (level.index < minLevel.index) return;
    final record = LogRecord(
      level: level,
      tag: tag,
      message: message,
      time: DateTime.now(),
      error: error,
    );
    _records.addLast(record);
    while (_records.length > _maxRecords) {
      _records.removeFirst();
    }
    for (final listener in List.of(_listeners)) {
      listener(record);
    }

    if (kDebugMode) {
      developer.log(
        message,
        name: 'IC/$tag',
        level: switch (level) {
          LogLevel.debug => 500,
          LogLevel.info => 800,
          LogLevel.warn => 900,
          LogLevel.error => 1000,
        },
        error: error,
        stackTrace: stack,
      );
    }
  }

  void clear() => _records.clear();
}

/// Short global handle: `log.info('tag', 'message')`.
final AppLogger log = AppLogger.instance;
