/// Supported model file formats.
enum ModelFormat { gguf, mlx }

/// Minimal ModelProfile used by EP-2 interfaces.
/// Expanded with full metadata in task-501.
class ModelProfile {
  final String id;
  final String displayName;
  final ModelFormat format;

  /// Absolute path to the downloaded model file.
  /// Null when the model has not been downloaded yet.
  final String? localPath;

  const ModelProfile({
    required this.id,
    required this.displayName,
    required this.format,
    this.localPath,
  });
}
