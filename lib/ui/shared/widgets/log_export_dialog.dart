import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:little_star_app/data/services/crash_reporting_service.dart';
import 'package:little_star_app/utils/logger.dart';

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

      if (mounted) {
        setState(() {
          _logContent = content ?? '無日誌內容';
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

  Future<void> _shareLogs() async {
    try {
      final file = await CrashReportingService.instance.getLogFile();
      if (file == null || !await file.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('無日誌檔案可分享')),
          );
        }
        return;
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Little Star App 日誌',
        text: '請協助診斷應用程式問題',
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
      if (_logFiles.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('無日誌檔案可分享')),
          );
        }
        return;
      }

      final xFiles = _logFiles.map((f) => XFile(f.path)).toList();

      await Share.shareXFiles(
        xFiles,
        subject: 'Little Star App 完整日誌',
        text: '請協助診斷應用程式問題（共 ${xFiles.length} 個檔案）',
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
