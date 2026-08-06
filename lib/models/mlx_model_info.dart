/// Represents a locally downloaded MLX model — a directory of weight/config
/// files rather than a single file (see [ModelFormat.mlx]).
class MlxModelInfo {
  final String repoId;
  final String directoryPath;
  final int totalSizeBytes;

  const MlxModelInfo({
    required this.repoId,
    required this.directoryPath,
    required this.totalSizeBytes,
  });

  String get displayName => repoId.split('/').last;

  String get formattedSize {
    if (totalSizeBytes >= 1024 * 1024 * 1024) {
      return '${(totalSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else if (totalSizeBytes >= 1024 * 1024) {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else if (totalSizeBytes >= 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(2)} KB';
    }
    return '$totalSizeBytes B';
  }
}
