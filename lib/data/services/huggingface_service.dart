import 'package:dio/dio.dart';
import 'package:little_star_app/models/hf_model_info.dart';
import 'package:little_star_app/utils/logger.dart';

/// Service for interacting with the Hugging Face API.
class HuggingFaceService {
  static const String _baseUrl = 'https://huggingface.co';
  static const String _apiBaseUrl = 'https://huggingface.co/api';

  final Dio _dio;
  final Logger _log = Logger('HuggingFaceService');

  HuggingFaceService({String? authToken})
      : _dio = Dio(BaseOptions(
          baseUrl: _apiBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Accept': 'application/json',
            if (authToken != null) 'Authorization': 'Bearer $authToken',
          },
        ));

  /// Search for GGUF models on Hugging Face.
  ///
  /// [query] - Search query string (optional)
  /// [limit] - Maximum number of results (default: 20)
  /// [sortBy] - Sort by: "downloads", "likes", "lastModified" (default: "downloads")
  Future<List<HFModelInfo>> searchModels({
    String? query,
    int limit = 20,
    String sortBy = 'downloads',
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'filter': 'gguf',
        'limit': limit,
        'sort': sortBy,
        'direction': -1, // Descending order
      };

      if (query != null && query.isNotEmpty) {
        queryParams['search'] = query;
      }

      _log.debug('Searching HF models with params: $queryParams');

      final response = await _dio.get('/models', queryParameters: queryParams);

      if (response.statusCode == 200 && response.data is List) {
        final models = (response.data as List)
            .map((json) => HFModelInfo.fromJson(json as Map<String, dynamic>))
            .toList();

        _log.info('Found ${models.length} GGUF models');
        return models;
      }

      return [];
    } on DioException catch (e) {
      _log.error('Failed to search models: ${e.message}');
      rethrow;
    }
  }

  /// Get list of GGUF files in a repository.
  ///
  /// [repoId] - Repository ID (e.g., "TheBloke/Llama-2-7B-GGUF")
  Future<List<HFModelFile>> getModelFiles(String repoId) async {
    try {
      _log.debug('Fetching files for repo: $repoId');

      final response = await _dio.get('/models/$repoId/tree/main');

      if (response.statusCode == 200 && response.data is List) {
        final allFiles = response.data as List;

        // Filter only .gguf files
        final ggufFiles = allFiles
            .where((file) {
              final path = file['path'] as String? ?? '';
              return path.toLowerCase().endsWith('.gguf');
            })
            .map((json) => HFModelFile.fromTreeEntry(
                json as Map<String, dynamic>, repoId))
            .toList();

        // Sort by size (smallest first for easier download)
        ggufFiles.sort((a, b) => a.size.compareTo(b.size));

        _log.info('Found ${ggufFiles.length} GGUF files in $repoId');
        return ggufFiles;
      }

      return [];
    } on DioException catch (e) {
      _log.error('Failed to get model files: ${e.message}');
      rethrow;
    }
  }

  /// Get list of MLX weight/config files in a repository (a multi-file
  /// snapshot rather than a single `.gguf` file).
  ///
  /// [repoId] - Repository ID (e.g., "Bbson/gemma-3-4B-T1-it-MLX-4bit")
  Future<List<HFModelFile>> getMlxModelFiles(String repoId) async {
    try {
      _log.debug('Fetching MLX files for repo: $repoId');

      final response = await _dio.get('/models/$repoId/tree/main');

      if (response.statusCode == 200 && response.data is List) {
        final allFiles = response.data as List;

        final mlxFiles = allFiles
            .where((file) {
              final filePath = (file['path'] as String? ?? '').toLowerCase();
              return filePath.endsWith('.safetensors') ||
                  filePath == 'config.json' ||
                  filePath == 'tokenizer.json' ||
                  filePath == 'tokenizer_config.json' ||
                  filePath == 'special_tokens_map.json' ||
                  filePath == 'generation_config.json' ||
                  filePath == 'tokenizer.model' ||
                  // Newer HF repos (incl. mlx_lm.convert output) split the
                  // chat template out of tokenizer_config.json into its own
                  // file; swift-transformers looks for it on disk, so it
                  // must be downloaded or chat formatting silently falls
                  // back to plain text.
                  filePath == 'chat_template.jinja' ||
                  filePath == 'chat_template.json';
            })
            .map((json) => HFModelFile.fromTreeEntry(
                json as Map<String, dynamic>, repoId))
            .toList();

        _log.info('Found ${mlxFiles.length} MLX files in $repoId');
        return mlxFiles;
      }

      return [];
    } on DioException catch (e) {
      _log.error('Failed to get MLX model files: ${e.message}');
      rethrow;
    }
  }

  /// Get detailed information about a specific model.
  ///
  /// [repoId] - Repository ID (e.g., "TheBloke/Llama-2-7B-GGUF")
  Future<HFModelInfo?> getModelInfo(String repoId) async {
    try {
      _log.debug('Fetching model info: $repoId');

      final response = await _dio.get('/models/$repoId');

      if (response.statusCode == 200 && response.data is Map) {
        return HFModelInfo.fromJson(response.data as Map<String, dynamic>);
      }

      return null;
    } on DioException catch (e) {
      _log.error('Failed to get model info: ${e.message}');
      rethrow;
    }
  }

  /// Get the direct download URL for a file.
  ///
  /// [repoId] - Repository ID
  /// [filename] - File name within the repository
  String getDownloadUrl(String repoId, String filename) {
    return '$_baseUrl/$repoId/resolve/main/$filename';
  }

  /// Check if a model requires authentication to access.
  Future<bool> requiresAuth(String repoId) async {
    try {
      // Try to access the model without auth
      final testDio = Dio(BaseOptions(
        baseUrl: _apiBaseUrl,
        receiveTimeout: const Duration(seconds: 10),
      ));

      final response = await testDio.get('/models/$repoId');
      return response.statusCode == 401 || response.statusCode == 403;
    } catch (e) {
      if (e is DioException) {
        return e.response?.statusCode == 401 || e.response?.statusCode == 403;
      }
      return false;
    }
  }

  /// Set or update the authentication token.
  void setAuthToken(String? token) {
    if (token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    } else {
      _dio.options.headers.remove('Authorization');
    }
  }
}
