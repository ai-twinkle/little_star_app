/// Represents a model repository from Hugging Face.
class HFModelInfo {
  final String id; // e.g., "TheBloke/Llama-2-7B-GGUF"
  final String author; // e.g., "TheBloke"
  final String modelName; // e.g., "Llama-2-7B-GGUF"
  final int downloads;
  final int likes;
  final DateTime? lastModified;
  final List<String> tags;
  final String? description;

  HFModelInfo({
    required this.id,
    required this.author,
    required this.modelName,
    this.downloads = 0,
    this.likes = 0,
    this.lastModified,
    this.tags = const [],
    this.description,
  });

  factory HFModelInfo.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final parts = id.split('/');

    return HFModelInfo(
      id: id,
      author: parts.isNotEmpty ? parts.first : '',
      modelName: parts.length > 1 ? parts.last : id,
      downloads: json['downloads'] as int? ?? 0,
      likes: json['likes'] as int? ?? 0,
      lastModified: json['lastModified'] != null
          ? DateTime.tryParse(json['lastModified'] as String)
          : null,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'modelName': modelName,
        'downloads': downloads,
        'likes': likes,
        'lastModified': lastModified?.toIso8601String(),
        'tags': tags,
        'description': description,
      };

  String get formattedDownloads {
    if (downloads >= 1000000) {
      return '${(downloads / 1000000).toStringAsFixed(1)}M';
    } else if (downloads >= 1000) {
      return '${(downloads / 1000).toStringAsFixed(1)}K';
    }
    return downloads.toString();
  }
}

/// Represents a single GGUF file within a Hugging Face repository.
class HFModelFile {
  final String filename;
  final int size; // in bytes
  final String? quantization; // e.g., "Q4_K_M", "Q5_K_S"
  final String downloadUrl;

  HFModelFile({
    required this.filename,
    required this.size,
    this.quantization,
    required this.downloadUrl,
  });

  factory HFModelFile.fromTreeEntry(Map<String, dynamic> json, String repoId) {
    final filename = json['path'] as String? ?? '';
    final size = json['size'] as int? ?? 0;

    // Extract quantization from filename (e.g., "model-Q4_K_M.gguf" -> "Q4_K_M")
    String? quantization;
    final quantRegex = RegExp(r'[_-](Q\d+_[A-Z0-9_]+|F16|F32|BF16)', caseSensitive: false);
    final match = quantRegex.firstMatch(filename);
    if (match != null) {
      quantization = match.group(1)?.toUpperCase();
    }

    return HFModelFile(
      filename: filename,
      size: size,
      quantization: quantization,
      downloadUrl: 'https://huggingface.co/$repoId/resolve/main/$filename',
    );
  }

  String get formattedSize {
    if (size >= 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    } else if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else if (size >= 1024) {
      return '${(size / 1024).toStringAsFixed(2)} KB';
    }
    return '$size B';
  }
}
