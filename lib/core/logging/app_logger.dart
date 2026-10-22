import 'dart:collection';

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// Lightweight structured logger with an in-memory ring buffer
/// (viewable from Settings → Diagnostics, attachable to bug reports).
class AppLogger {
  AppLogger._();
  static final _buffer = ListQueue<String>();
  static const _max = 300;

  static void log(LogLevel level, String message, [Object? error, StackTrace? stack]) {
    final line = '${DateTime.now().toIso8601String()} [${level.name.toUpperCase()}] $message'
        '${error != null ? ' — $error' : ''}';
    _buffer.addLast(line);
    while (_buffer.length > _max) {
      _buffer.removeFirst();
    }
    if (kDebugMode || level.index >= LogLevel.warning.index) {
      debugPrint(line);
      if (stack != null && kDebugMode) debugPrint(stack.toString());
    }
  }

  static void info(String m) => log(LogLevel.info, m);
  static void warn(String m, [Object? e]) => log(LogLevel.warning, m, e);
  static void error(String m, Object e, [StackTrace? s]) => log(LogLevel.error, m, e, s);

  static String dump() => _buffer.join('\n');
}
