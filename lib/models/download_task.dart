import 'package:hive/hive.dart';

part 'download_task.g.dart';

/// Status of a download task.
@HiveType(typeId: 0)
enum DownloadStatus {
  @HiveField(0)
  pending,

  @HiveField(1)
  downloading,

  @HiveField(2)
  paused,

  @HiveField(3)
  completed,

  @HiveField(4)
  failed,

  @HiveField(5)
  cancelled,
}

/// Represents a download task for a model file.
@HiveType(typeId: 1)
class DownloadTask extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String url;

  @HiveField(2)
  final String filename;

  @HiveField(3)
  final String destinationPath;

  @HiveField(4)
  final int totalBytes;

  @HiveField(5)
  int downloadedBytes;

  @HiveField(6)
  DownloadStatus status;

  @HiveField(7)
  final DateTime createdAt;

  @HiveField(8)
  DateTime? startedAt;

  @HiveField(9)
  DateTime? completedAt;

  @HiveField(10)
  String? errorMessage;

  @HiveField(11)
  final String? repoId; // Hugging Face repo ID for reference

  @HiveField(12)
  final String? quantization;

  DownloadTask({
    required this.id,
    required this.url,
    required this.filename,
    required this.destinationPath,
    required this.totalBytes,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.pending,
    DateTime? createdAt,
    this.startedAt,
    this.completedAt,
    this.errorMessage,
    this.repoId,
    this.quantization,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Progress as a value between 0.0 and 1.0.
  double get progress {
    if (totalBytes <= 0) return 0.0;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  /// Progress as a percentage string.
  String get progressPercent => '${(progress * 100).toStringAsFixed(1)}%';

  /// Formatted downloaded size.
  String get formattedDownloadedBytes => _formatBytes(downloadedBytes);

  /// Formatted total size.
  String get formattedTotalBytes => _formatBytes(totalBytes);

  /// Whether the task can be resumed.
  bool get canResume => status == DownloadStatus.paused || status == DownloadStatus.failed;

  /// Whether the task can be paused.
  bool get canPause => status == DownloadStatus.downloading;

  /// Whether the task can be cancelled.
  bool get canCancel =>
      status == DownloadStatus.pending ||
      status == DownloadStatus.downloading ||
      status == DownloadStatus.paused;

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    return '$bytes B';
  }

  DownloadTask copyWith({
    String? id,
    String? url,
    String? filename,
    String? destinationPath,
    int? totalBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? errorMessage,
    String? repoId,
    String? quantization,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      filename: filename ?? this.filename,
      destinationPath: destinationPath ?? this.destinationPath,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      repoId: repoId ?? this.repoId,
      quantization: quantization ?? this.quantization,
    );
  }
}
