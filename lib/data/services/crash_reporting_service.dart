import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:little_star_app/utils/logger.dart';
import 'package:little_star_app/data/services/log_file_service.dart';

/// 統一的錯誤回報服務
/// 整合 Firebase Crashlytics 與本地日誌
class CrashReportingService {
  CrashReportingService._();
  static final CrashReportingService instance = CrashReportingService._();

  static final _log = Logger('CrashReporting');

  bool _initialized = false;
  LogFileService? _logFileService;

  /// 檢查是否支援 Crashlytics（僅 Android/iOS/macOS）
  static bool get _isCrashlyticsSupported =>
      Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// 是否應該使用 Crashlytics
  bool get _shouldUseCrashlytics =>
      !kDebugMode && _isCrashlyticsSupported;

  /// 初始化錯誤回報服務
  /// 必須在 Firebase.initializeApp() 之後呼叫
  Future<void> initialize({LogFileService? logFileService}) async {
    if (_initialized) return;

    _logFileService = logFileService;

    // 設定 Logger 的 sink 以寫入檔案
    if (_logFileService != null) {
      Logger.sink = (line) {
        _logFileService?.writeLine(line);
      };
    }

    // 設定 Flutter framework 錯誤處理
    FlutterError.onError = _handleFlutterError;

    // 設定 Dart 層未捕獲的非同步錯誤
    PlatformDispatcher.instance.onError = _handlePlatformError;

    _initialized = true;
    _log.info('CrashReportingService initialized');
  }

  /// 處理 Flutter framework 錯誤
  void _handleFlutterError(FlutterErrorDetails details) {
    _log.error(
      'Flutter Error: ${details.exceptionAsString()}',
      error: details.exception,
      st: details.stack,
    );

    // 傳送到 Crashlytics（僅支援 Android/iOS/macOS）
    if (_shouldUseCrashlytics) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(details);
    }
  }

  /// 處理平台層未捕獲錯誤
  bool _handlePlatformError(Object error, StackTrace stack) {
    _log.error('Uncaught Platform Error', error: error, st: stack);

    // 傳送到 Crashlytics（僅支援 Android/iOS/macOS）
    if (_shouldUseCrashlytics) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    }

    return true; // 表示錯誤已處理
  }

  /// 手動記錄非致命錯誤
  void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) {
    _log.error(reason ?? 'Recorded error', error: error, st: stack);

    if (_shouldUseCrashlytics) {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack ?? StackTrace.current,
        reason: reason,
        fatal: fatal,
      );
    }
  }

  /// 記錄自訂訊息（breadcrumb）
  void log(String message) {
    _log.info(message);

    if (_shouldUseCrashlytics) {
      FirebaseCrashlytics.instance.log(message);
    }
  }

  /// 設定使用者識別（匿名）
  Future<void> setUserIdentifier(String identifier) async {
    if (_shouldUseCrashlytics) {
      await FirebaseCrashlytics.instance.setUserIdentifier(identifier);
    }
  }

  /// 設定自訂 key-value
  Future<void> setCustomKey(String key, Object value) async {
    if (_shouldUseCrashlytics) {
      await FirebaseCrashlytics.instance.setCustomKey(key, value);
    }
  }

  /// 取得本地日誌檔案路徑（供使用者分享）
  Future<File?> getLogFile() async {
    return _logFileService?.getCurrentLogFile();
  }

  /// 取得所有日誌檔案
  Future<List<File>> getAllLogFiles() async {
    return _logFileService?.getAllLogFiles() ?? [];
  }

  /// 匯出日誌內容
  Future<String?> exportLogs({int? maxLines}) async {
    return _logFileService?.readLogs(maxLines: maxLines);
  }
}
