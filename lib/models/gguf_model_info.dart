/// Represents a GGUF model file with metadata
class GGUFModelInfo {
  final String filePath;
  final String fileName;
  final int fileSize;

  const GGUFModelInfo({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
  });

  String get formattedSize {
    if (fileSize < 1024) return '${fileSize}B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }
}
