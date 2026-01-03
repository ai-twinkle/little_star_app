import 'dart:developer' as dev show log;

/// 在所有 Dart 目標可用的 release 偵測
const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');


enum Level { trace, debug, info, warn, error }

class Logger {
  Logger(this.name);

  /// 此 logger 的名稱（模組/類別/檔名…）
  final String name;

  // ------- 全域設定（可在程式任一處修改）-------
  /// 額外輸出管道（例如寫檔、丟到 socket）
  static void Function(String line)? sink;

  /// 使用 DevTools (dart:developer.log)
  static bool useDevTools = !kReleaseMode;

  /// 由 -DLOG_LEVEL 控制最低輸出等級；預設：debug/profile=DEBUG、release=DEBUG
  /// 注意：Release 也記錄 DEBUG，但 UI 只顯示 WARN 以上
  static final String _envLevel =
      const String.fromEnvironment('LOG_LEVEL', defaultValue: '');
  static Level minLevel =
      _parseLevel(_envLevel) ?? Level.debug;

  // ------- 實例方法 -------
  void trace(Object? msg) => _log(Level.trace, msg);
  void debug(Object? msg) => _log(Level.debug, msg);
  void info(Object? msg)  => _log(Level.info,  msg);
  void warn(Object? msg, {Object? error, StackTrace? st}) =>
      _log(Level.warn, msg, error: error, st: st);
  void error(Object? msg, {Object? error, StackTrace? st}) =>
      _log(Level.error, msg, error: error, st: st);

  /// Lazy 版本：只有在等級達標時才建立訊息字串
  void tracef(String Function() build) {
    if (Level.trace.index >= minLevel.index) trace(build());
  }
  void debugf(String Function() build) {
    if (Level.debug.index >= minLevel.index) debug(build());
  }
  void warnf(String Function() build) {
    if (Level.warn.index >= minLevel.index) warn(build());
  }

  // ------- 內部 -------

  /// 過濾敏感資訊
  static String _sanitizeMessage(String message) {
    var sanitized = message;

    // 過濾常見的敏感模式
    // API tokens/keys (Bearer, token=, api_key=)
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(Bearer\s+|token[=:]\s*|api[_-]?key[=:]\s*)([A-Za-z0-9_\-\.]+)', caseSensitive: false),
      (match) => '${match[1]}[REDACTED]',
    );

    // Authorization headers
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(Authorization[=:]\s*)([^\s,]+)', caseSensitive: false),
      (match) => '${match[1]}[REDACTED]',
    );

    // 密碼
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'(password[=:]\s*)([^\s,]+)', caseSensitive: false),
      (match) => '${match[1]}[REDACTED]',
    );

    return sanitized;
  }

  void _log(Level lvl, Object? msg, {Object? error, StackTrace? st}) {
    if (lvl.index < minLevel.index) return;

    final ts = DateTime.now().toIso8601String();
    final mark = switch (lvl) {
      Level.trace => 'T',
      Level.debug => 'D',
      Level.info  => 'I',
      Level.warn  => 'W',
      Level.error => 'E',
    };

    // 過濾訊息中的敏感資訊
    final sanitizedMsg = _sanitizeMessage(msg.toString());
    final sanitizedError = error != null ? _sanitizeMessage(error.toString()) : null;

    final line = '[$ts][$mark][$name] $sanitizedMsg'
        '${sanitizedError != null ? ' | error=$sanitizedError' : ''}'
        '${st != null ? '\n$st' : ''}';

    if (sink != null) sink!(line);

    if (useDevTools) {
      dev.log(
        line,
        name: name,
        error: error,
        stackTrace: st,
        level: switch (lvl) { Level.trace => 100, Level.debug => 500, Level.info => 800, Level.warn => 900, Level.error => 1000 },
      );
    }

    if (lvl == Level.error) {
      print('\x1b[31m${lvl.name}: $line\x1b[0m');
    } else if (lvl == Level.warn) {
      print('\x1b[33m${lvl.name}: $line\x1b[0m');
    } else if (lvl == Level.info) {
      print('\x1b[36m${lvl.name}: $line\x1b[0m');
    } else if (lvl == Level.debug) {
      print('\x1b[0;90m${lvl.name}: $line\x1b[0m');
    } else if (lvl == Level.trace) {
      print('\x1b[0;95m${lvl.name}: $line\x1b[0m');
    }
  }

  static Level? _parseLevel(String s) {
    final u = s.trim().toUpperCase();
    if (u.isEmpty) return null;
    if (u == 'T' || u == 'TRACE') return Level.trace;
    if (u == 'D' || u == 'DEBUG') return Level.debug;
    if (u == 'I' || u == 'INFO')  return Level.info;
    if (u == 'W' || u == 'WARN' || u == 'WARNING') return Level.warn;
    if (u == 'E' || u == 'ERR'  || u == 'ERROR')   return Level.error;
    return null;
  }
}
