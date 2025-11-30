import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:little_star_app/models/download_task.dart';
import 'package:little_star_app/utils/logger.dart';

/// Progress information for a download.
class DownloadProgress {
  final String taskId;
  final int downloadedBytes;
  final int totalBytes;
  final double speed; // bytes per second

  DownloadProgress({
    required this.taskId,
    required this.downloadedBytes,
    required this.totalBytes,
    this.speed = 0,
  });

  double get progress => totalBytes > 0 ? downloadedBytes / totalBytes : 0;
  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';
}

/// Service for downloading files with progress tracking and resume support.
class DownloadService {
  final Dio _dio;
  final Logger _log = Logger('DownloadService');

  // Active download tokens for cancellation
  final Map<String, CancelToken> _cancelTokens = {};

  // Progress stream controllers per task
  final Map<String, StreamController<DownloadProgress>> _progressControllers =
      {};

  DownloadService()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 30),
        ));

  /// Start downloading a file.
  ///
  /// Returns a Stream of [DownloadProgress] updates.
  /// The download can be paused/cancelled using the returned task ID.
  Stream<DownloadProgress> startDownload({
    required DownloadTask task,
    required Function(DownloadTask) onStatusChanged,
  }) {
    // Create progress controller
    final controller = StreamController<DownloadProgress>.broadcast();
    _progressControllers[task.id] = controller;

    // Create cancel token
    final cancelToken = CancelToken();
    _cancelTokens[task.id] = cancelToken;

    // Start download in background
    _performDownload(
      task: task,
      cancelToken: cancelToken,
      progressController: controller,
      onStatusChanged: onStatusChanged,
    );

    return controller.stream;
  }

  Future<void> _performDownload({
    required DownloadTask task,
    required CancelToken cancelToken,
    required StreamController<DownloadProgress> progressController,
    required Function(DownloadTask) onStatusChanged,
  }) async {
    final tempFile = File('${task.destinationPath}.tmp');

    try {
      // Check for existing partial download
      int existingBytes = 0;
      if (await tempFile.exists()) {
        existingBytes = await tempFile.length();
        _log.debug('Resuming download from byte $existingBytes');
      }

      // Update task status
      task.status = DownloadStatus.downloading;
      task.startedAt = DateTime.now();
      task.downloadedBytes = existingBytes;
      onStatusChanged(task);

      // Prepare headers for resume
      final headers = <String, dynamic>{};
      if (existingBytes > 0) {
        headers['Range'] = 'bytes=$existingBytes-';
      }

      // Start download
      final response = await _dio.get<ResponseBody>(
        task.url,
        options: Options(
          responseType: ResponseType.stream,
          headers: headers,
          followRedirects: true,
          maxRedirects: 5,
        ),
        cancelToken: cancelToken,
      );

      // Get total size from content-length or content-range
      int totalBytes = task.totalBytes;
      final contentLength = response.headers.value('content-length');
      final contentRange = response.headers.value('content-range');

      if (contentRange != null) {
        // Format: bytes 0-999/1000
        final match = RegExp(r'/(\d+)').firstMatch(contentRange);
        if (match != null) {
          totalBytes = int.parse(match.group(1)!);
        }
      } else if (contentLength != null) {
        totalBytes = existingBytes + int.parse(contentLength);
      }

      // Open file for writing
      final sink = tempFile.openWrite(mode: FileMode.append);

      // Track download speed
      int bytesReceived = existingBytes;
      DateTime lastUpdate = DateTime.now();
      int lastBytes = bytesReceived;

      try {
        await for (final chunk in response.data!.stream) {
          if (cancelToken.isCancelled) break;

          sink.add(chunk);
          bytesReceived += chunk.length;

          // Calculate speed
          final now = DateTime.now();
          final elapsed = now.difference(lastUpdate).inMilliseconds;
          double speed = 0;
          if (elapsed > 500) {
            // Update every 500ms
            speed = (bytesReceived - lastBytes) / (elapsed / 1000);
            lastBytes = bytesReceived;
            lastUpdate = now;
          }

          // Update task
          task.downloadedBytes = bytesReceived;

          // Emit progress
          progressController.add(DownloadProgress(
            taskId: task.id,
            downloadedBytes: bytesReceived,
            totalBytes: totalBytes,
            speed: speed,
          ));
        }

        await sink.flush();
        await sink.close();

        if (!cancelToken.isCancelled) {
          // Rename temp file to final
          if (await tempFile.exists()) {
            await tempFile.rename(task.destinationPath);
          }

          task.status = DownloadStatus.completed;
          task.completedAt = DateTime.now();
          task.downloadedBytes = totalBytes;
          _log.info('Download completed: ${task.filename}');
        }
      } catch (e) {
        await sink.close();
        rethrow;
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        _log.debug('Download cancelled: ${task.filename}');
        // Status already set by pause/cancel method
      } else {
        _log.error('Download failed: ${e.message}');
        task.status = DownloadStatus.failed;
        task.errorMessage = e.message;
      }
    } catch (e) {
      // Only log error if not already completed (race condition with rename)
      if (task.status != DownloadStatus.completed) {
        _log.error('Download error: $e');
        task.status = DownloadStatus.failed;
        task.errorMessage = e.toString();
      }
    } finally {
      onStatusChanged(task);
      _cleanup(task.id);
    }
  }

  /// Pause an active download.
  void pauseDownload(String taskId) {
    final cancelToken = _cancelTokens[taskId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('Paused by user');
      _log.debug('Pausing download: $taskId');
    }
  }

  /// Cancel and remove a download.
  Future<void> cancelDownload(String taskId, String destinationPath) async {
    pauseDownload(taskId);

    // Delete temp file if exists
    final tempFile = File('$destinationPath.tmp');
    if (await tempFile.exists()) {
      await tempFile.delete();
      _log.debug('Deleted temp file for: $taskId');
    }

    _cleanup(taskId);
  }

  void _cleanup(String taskId) {
    _cancelTokens.remove(taskId);
    _progressControllers[taskId]?.close();
    _progressControllers.remove(taskId);
  }

  /// Check if a download is active.
  bool isDownloading(String taskId) {
    final token = _cancelTokens[taskId];
    return token != null && !token.isCancelled;
  }

  /// Get current progress for a task.
  Stream<DownloadProgress>? getProgressStream(String taskId) {
    return _progressControllers[taskId]?.stream;
  }

  /// Dispose all resources.
  void dispose() {
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) {
        token.cancel('Service disposed');
      }
    }
    for (final controller in _progressControllers.values) {
      controller.close();
    }
    _cancelTokens.clear();
    _progressControllers.clear();
  }
}
