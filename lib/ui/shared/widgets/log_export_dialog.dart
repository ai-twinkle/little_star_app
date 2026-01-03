import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:little_star_app/data/services/app_info_service.dart';
import 'package:little_star_app/data/services/crash_reporting_service.dart';
import 'package:little_star_app/utils/logger.dart' hide kReleaseMode;

/// 日誌匯出對話框
/// 讓使用者可以檢視和分享應用程式日誌
class LogExportDialog extends StatefulWidget {
  const LogExportDialog({super.key});

  /// 顯示日誌匯出對話框
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const LogExportDialog(),
    );
  }

  @override
  State<LogExportDialog> createState() => _LogExportDialogState();
}

class _LogExportDialogState extends State<LogExportDialog> {
  static final _log = Logger('LogExportDialog');

  String? _logContent;
  List<File> _logFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    try {
      final content = await CrashReportingService.instance.exportLogs(
        maxLines: 500, // 顯示最近 500 行
      );
      final files = await CrashReportingService.instance.getAllLogFiles();

      // 過濾日誌,只在 UI 顯示 WARNING 及以上等級的訊息
      String? displayContent;
      if (content != null) {
        final lines = content.split('\n');
        final filteredLines = lines.where((line) {
          // 檢查日誌等級標記 [W] 或 [E]
          return line.contains('[W]') || line.contains('[E]');
        }).toList();

        displayContent = filteredLines.isEmpty
            ? '無警告或錯誤訊息（完整日誌請使用分享功能查看）'
            : filteredLines.join('\n');
      }

      if (mounted) {
        setState(() {
          _logContent = displayContent ?? '無日誌內容';
          _logFiles = files;
          _isLoading = false;
        });
      }
    } catch (e) {
      _log.error('Failed to load logs', error: e);
      if (mounted) {
        setState(() {
          _logContent = '載入日誌失敗: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// 過濾敏感資訊
  String _sanitizePath(String path) {
    // 移除用戶名稱,只保留相對路徑結構
    final parts = path.split('/');
    final userIndex = parts.indexOf('Users');
    if (userIndex >= 0 && userIndex + 1 < parts.length) {
      parts[userIndex + 1] = '[USER]';
    }
    return parts.join('/');
  }

  /// 生成系統診斷報告
  Future<String> _generateDiagnosticReport() async {
    final buffer = StringBuffer();
    final appInfoService = AppInfoService();

    buffer.writeln('=== Little Star App 診斷報告 ===');
    buffer.writeln('生成時間: ${DateTime.now().toIso8601String()}');
    buffer.writeln('⚠️  此報告包含設備和應用程式資訊,請謹慎分享');
    buffer.writeln();

    // App 資訊
    try {
      final packageInfo = await appInfoService.getPackageInfo();
      buffer.writeln('--- 應用程式資訊 ---');
      buffer.writeln('名稱: ${packageInfo.appName}');
      buffer.writeln('版本: ${packageInfo.version}');
      buffer.writeln('Build: ${packageInfo.buildNumber}');
      buffer.writeln('Package: ${packageInfo.packageName}');
      buffer.writeln('Build Mode: ${kReleaseMode ? "Release" : kDebugMode ? "Debug" : "Profile"}');
      buffer.writeln();
    } catch (e) {
      buffer.writeln('獲取應用程式資訊失敗: $e');
      buffer.writeln();
    }

    // 設備資訊
    try {
      final deviceInfo = await appInfoService.getDeviceInfo();
      buffer.writeln('--- 設備資訊 ---');
      deviceInfo.forEach((key, value) {
        buffer.writeln('$key: $value');
      });
      buffer.writeln();
    } catch (e) {
      buffer.writeln('獲取設備資訊失敗: $e');
      buffer.writeln();
    }

    // Flutter & Dart 版本
    buffer.writeln('--- Runtime 資訊 ---');
    buffer.writeln('Dart Version: ${Platform.version}');
    buffer.writeln();

    // 儲存路徑 (移除敏感資訊)
    try {
      final storageInfo = await appInfoService.getStorageInfo();
      buffer.writeln('--- 儲存路徑 ---');
      storageInfo.forEach((key, value) {
        buffer.writeln('$key: ${_sanitizePath(value)}');
      });
      buffer.writeln();
    } catch (e) {
      buffer.writeln('獲取儲存路徑失敗: $e');
      buffer.writeln();
    }

    // 日誌檔案列表
    buffer.writeln('--- 日誌檔案 ---');
    buffer.writeln('總數: ${_logFiles.length}');
    for (var file in _logFiles) {
      try {
        final stat = await file.stat();
        final size = (stat.size / 1024).toStringAsFixed(2);
        buffer.writeln('${file.path.split('/').last}: ${size}KB');
      } catch (e) {
        buffer.writeln('${file.path.split('/').last}: 無法讀取');
      }
    }
    buffer.writeln();

    buffer.writeln('=== 報告結束 ===');

    return buffer.toString();
  }

  /// 顯示分享確認對話框
  Future<bool> _showShareConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.privacy_tip, color: Colors.orange),
            SizedBox(width: 8),
            Text('確認分享診斷資訊'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('即將分享以下資訊:'),
            SizedBox(height: 12),
            Text('• 應用程式版本和配置'),
            Text('• 設備型號和系統版本'),
            Text('• 應用程式日誌 (包含 DEBUG 級別)'),
            Text('• 儲存路徑資訊 (已匿名化)'),
            SizedBox(height: 12),
            Text(
              '⚠️ 請確認接收方可信任',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('確認分享'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _shareLogs() async {
    try {
      // Get the position of the share button (for iOS), before any asynchronous operation
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      // 顯示確認對話框
      final confirmed = await _showShareConfirmation();
      if (!confirmed) return;

      final logFile = await CrashReportingService.instance.getLogFile();
      if (logFile == null || !await logFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('無日誌檔案可分享')),
          );
        }
        return;
      }

      // 生成診斷報告
      final diagnosticReport = await _generateDiagnosticReport();

      // 創建臨時診斷報告文件
      final tempDir = await getTemporaryDirectory();
      final reportFile = File('${tempDir.path}/diagnostic_report.txt');
      await reportFile.writeAsString(diagnosticReport);

      // 分享日誌文件和診斷報告
      await Share.shareXFiles(
        [
          XFile(reportFile.path),
          XFile(logFile.path),
        ],
        subject: 'Little Star App 診斷報告',
        text: '應用程式診斷資訊\n\n包含:\n- 系統診斷報告\n- 應用程式日誌',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      _log.error('Failed to share logs', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失敗: $e')),
        );
      }
    }
  }

  Future<void> _shareAllLogs() async {
    try {
      // 获取分享按钮的位置(用于 iPad),在异步操作前获取
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      // 顯示確認對話框
      final confirmed = await _showShareConfirmation();
      if (!confirmed) return;

      if (_logFiles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('無日誌檔案可分享')),
          );
        }
        return;
      }

      // 生成診斷報告
      final diagnosticReport = await _generateDiagnosticReport();

      // 創建臨時診斷報告文件
      final tempDir = await getTemporaryDirectory();
      final reportFile = File('${tempDir.path}/diagnostic_report.txt');
      await reportFile.writeAsString(diagnosticReport);

      // 將診斷報告添加到文件列表開頭
      final xFiles = [
        XFile(reportFile.path),
        ..._logFiles.map((f) => XFile(f.path)),
      ];

      await Share.shareXFiles(
        xFiles,
        subject: 'Little Star App 完整診斷報告',
        text: '應用程式完整診斷資訊\n\n包含:\n- 系統診斷報告\n- ${_logFiles.length} 個日誌檔案',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      _log.error('Failed to share all logs', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失敗: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.description_outlined),
          SizedBox(width: 8),
          Text('應用程式日誌'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '日誌檔案: ${_logFiles.length} 個',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: SelectableText(
                          _logContent ?? '',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('關閉'),
        ),
        if (_logFiles.length > 1)
          TextButton.icon(
            onPressed: _shareAllLogs,
            icon: const Icon(Icons.folder_shared, size: 18),
            label: const Text('分享全部'),
          ),
        FilledButton.icon(
          onPressed: _shareLogs,
          icon: const Icon(Icons.share, size: 18),
          label: const Text('分享日誌'),
        ),
      ],
    );
  }
}
