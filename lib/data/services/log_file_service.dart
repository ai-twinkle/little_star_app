import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:little_star_app/utils/logger.dart';

/// 本地日誌檔案服務
/// 負責將日誌寫入檔案，並管理日誌輪替
class LogFileService {
  LogFileService._();
  static final LogFileService instance = LogFileService._();

  static final _log = Logger('LogFileService');

  File? _currentLogFile;
  IOSink? _sink;
  bool _initialized = false;

  /// 日誌檔案最大大小（5MB）
  static const int maxFileSize = 5 * 1024 * 1024;

  /// 保留的日誌檔案數量
  static const int maxLogFiles = 5;

  /// 初始化日誌檔案服務
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final directory = await _getLogDirectory();
      await directory.create(recursive: true);

      _currentLogFile = await _getOrCreateLogFile(directory);
      _sink = _currentLogFile!.openWrite(mode: FileMode.append);

      _initialized = true;
      _log.info('LogFileService initialized: ${_currentLogFile!.path}');

      // 啟動時清理舊日誌
      await _cleanupOldLogs(directory);
    } catch (e, st) {
      _log.error('Failed to initialize LogFileService', error: e, st: st);
    }
  }

  /// 取得日誌目錄
  Future<Directory> _getLogDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/logs');
  }

  /// 取得或建立日誌檔案
  Future<File> _getOrCreateLogFile(Directory logDir) async {
    final today = DateTime.now();
    final fileName = 'app_${today.year}${today.month.toString().padLeft(2, '0')}${today.day.toString().padLeft(2, '0')}.log';
    return File('${logDir.path}/$fileName');
  }

  /// 寫入一行日誌
  void writeLine(String line) {
    if (!_initialized || _sink == null) return;

    try {
      _sink!.writeln(line);

      // 定期檢查檔案大小
      _checkFileSize();
    } catch (e) {
      // 寫入失敗時靜默處理，避免遞迴日誌
      debugPrintSynchronously('LogFileService write error: $e');
    }
  }

  int _writeCount = 0;

  /// 檢查檔案大小，必要時輪替
  Future<void> _checkFileSize() async {
    _writeCount++;
    if (_writeCount < 100) return; // 每 100 次寫入檢查一次
    _writeCount = 0;

    try {
      if (_currentLogFile == null) return;

      final stat = await _currentLogFile!.stat();
      if (stat.size > maxFileSize) {
        await _rotateLogFile();
      }
    } catch (_) {
      // 忽略檢查錯誤
    }
  }

  /// 輪替日誌檔案
  Future<void> _rotateLogFile() async {
    try {
      await _sink?.flush();
      await _sink?.close();

      final directory = await _getLogDirectory();
      final now = DateTime.now();
      final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final rotatedFile = File('${directory.path}/app_$timestamp.log');

      await _currentLogFile!.rename(rotatedFile.path);

      _currentLogFile = await _getOrCreateLogFile(directory);
      _sink = _currentLogFile!.openWrite(mode: FileMode.append);

      await _cleanupOldLogs(directory);
    } catch (e) {
      debugPrintSynchronously('LogFileService rotate error: $e');
    }
  }

  /// 清理舊日誌檔案
  Future<void> _cleanupOldLogs(Directory logDir) async {
    try {
      final files = await logDir
          .list()
          .where((e) => e is File && e.path.endsWith('.log'))
          .cast<File>()
          .toList();

      if (files.length <= maxLogFiles) return;

      // 按修改時間排序
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      // 刪除多餘的舊檔案
      for (var i = maxLogFiles; i < files.length; i++) {
        await files[i].delete();
        _log.debug('Deleted old log file: ${files[i].path}');
      }
    } catch (e) {
      debugPrintSynchronously('LogFileService cleanup error: $e');
    }
  }

  /// 取得當前日誌檔案
  Future<File?> getCurrentLogFile() async {
    if (_sink != null) {
      await _sink!.flush();
    }
    return _currentLogFile;
  }

  /// 取得所有日誌檔案
  Future<List<File>> getAllLogFiles() async {
    try {
      final directory = await _getLogDirectory();
      if (!await directory.exists()) return [];

      final files = await directory
          .list()
          .where((e) => e is File && e.path.endsWith('.log'))
          .cast<File>()
          .toList();

      // 按修改時間排序（最新在前）
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });

      return files;
    } catch (e) {
      _log.error('Failed to get log files', error: e);
      return [];
    }
  }

  /// 讀取日誌內容
  Future<String?> readLogs({int? maxLines}) async {
    try {
      if (_sink != null) {
        await _sink!.flush();
      }

      if (_currentLogFile == null || !await _currentLogFile!.exists()) {
        return null;
      }

      final lines = await _currentLogFile!.readAsLines();

      if (maxLines != null && lines.length > maxLines) {
        return lines.sublist(lines.length - maxLines).join('\n');
      }

      return lines.join('\n');
    } catch (e) {
      _log.error('Failed to read logs', error: e);
      return null;
    }
  }

  /// 關閉服務
  Future<void> dispose() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;
    _initialized = false;
  }
}

/// Debug 模式下的同步 print
void debugPrintSynchronously(String message) {
  // ignore: avoid_print
  print(message);
}
