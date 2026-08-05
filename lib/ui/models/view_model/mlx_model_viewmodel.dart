import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:little_star_app/data/services/mlx_repo_fetcher.dart';
import 'package:little_star_app/models/mlx_model_info.dart';
import 'package:little_star_app/utils/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Records which HF repo a downloaded snapshot came from — the directory
/// name alone can't reliably round-trip a repo id containing arbitrary
/// characters.
const _repoIdMarkerFile = '.repo_id';

/// Manages downloading and listing local MLX model snapshots (each a
/// directory of weight/config files) for the "MLX Models" screen.
class MlxModelViewModel extends ChangeNotifier {
  final Directory _mlxModelsDir;
  final MlxRepoFetcher _fetcher;
  final Logger _log = Logger('MlxModelViewModel');

  List<MlxModelInfo> _localModels = [];
  bool _isLoadingLocal = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String _status = '';
  String? _error;

  MlxModelViewModel({required Directory mlxModelsDir, MlxRepoFetcher? fetcher})
    : _mlxModelsDir = mlxModelsDir,
      _fetcher = fetcher ?? HttpMlxRepoFetcher();

  /// Creates the production ViewModel without exposing platform-directory
  /// resolution to the Widget. Tests may substitute the application-support
  /// directory while exercising the same public initialization path.
  static Future<MlxModelViewModel> createDefault({
    Future<Directory> Function()? applicationSupportDirectory,
    MlxRepoFetcher? fetcher,
  }) async {
    final supportDirectory =
        await (applicationSupportDirectory ?? getApplicationSupportDirectory)();
    final viewModel = MlxModelViewModel(
      mlxModelsDir: Directory(
        path.join(supportDirectory.path, 'Models', 'mlx'),
      ),
      fetcher: fetcher,
    );
    await viewModel.init();
    return viewModel;
  }

  List<MlxModelInfo> get localModels => List.unmodifiable(_localModels);
  bool get isLoadingLocal => _isLoadingLocal;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String get status => _status;
  String? get error => _error;

  Future<void> init() => loadLocalModels();

  Future<void> loadLocalModels() async {
    _isLoadingLocal = true;
    notifyListeners();

    final models = <MlxModelInfo>[];
    try {
      if (await _mlxModelsDir.exists()) {
        await for (final entity in _mlxModelsDir.list()) {
          if (entity is! Directory) continue;

          final files =
              entity
                  .listSync()
                  .whereType<File>()
                  .where((f) => path.basename(f.path) != _repoIdMarkerFile)
                  .toList();
          if (files.isEmpty) continue;

          var totalSize = 0;
          for (final f in files) {
            totalSize += await f.length();
          }

          models.add(
            MlxModelInfo(
              repoId: await _readRepoId(entity),
              directoryPath: entity.path,
              totalSizeBytes: totalSize,
            ),
          );
        }
      }
      _localModels = models;
      _log.info('Loaded ${models.length} local MLX models');
    } catch (e) {
      _log.error('Failed to load local MLX models: $e');
    } finally {
      _isLoadingLocal = false;
      notifyListeners();
    }
  }

  /// Downloads every MLX file in [repoId] into its own snapshot directory.
  /// Returns true on success.
  Future<bool> downloadModel(String repoId) async {
    final trimmed = repoId.trim();
    if (trimmed.isEmpty || _isDownloading) return false;

    _isDownloading = true;
    _downloadProgress = 0;
    _error = null;
    _status = 'Fetching file list…';
    notifyListeners();

    try {
      final files = await _fetcher.listFiles(trimmed);
      if (files.isEmpty) {
        _error = 'No MLX files found in $trimmed';
        return false;
      }

      final targetDir = Directory(
        path.join(_mlxModelsDir.path, _slugify(trimmed)),
      );
      await targetDir.create(recursive: true);

      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        _status = 'Downloading (${i + 1}/${files.length}): ${file.filename}';
        notifyListeners();

        final dest = path.join(targetDir.path, path.basename(file.filename));
        await _fetcher.download(
          file.downloadUrl,
          dest,
          onProgress: (received, total) {
            if (total <= 0) return;
            _downloadProgress = (i + received / total) / files.length;
            notifyListeners();
          },
        );
      }

      await File(
        path.join(targetDir.path, _repoIdMarkerFile),
      ).writeAsString(trimmed);

      _status = 'Download complete ✓';
      _downloadProgress = 1;
      _log.info('Downloaded ${files.length} MLX files for $trimmed');
      await loadLocalModels();
      return true;
    } catch (e) {
      _error = 'Download failed: $e';
      _log.error('MLX download failed for $trimmed: $e');
      return false;
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> deleteLocalModel(MlxModelInfo model) async {
    try {
      final dir = Directory(model.directoryPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      _log.info('Deleted MLX model: ${model.repoId}');
      await loadLocalModels();
    } catch (e) {
      _error = 'Failed to delete model: $e';
      _log.error('Failed to delete MLX model: $e');
      notifyListeners();
    }
  }

  Future<String> _readRepoId(Directory snapshotDir) async {
    final marker = File(path.join(snapshotDir.path, _repoIdMarkerFile));
    if (await marker.exists()) {
      final content = (await marker.readAsString()).trim();
      if (content.isNotEmpty) return content;
    }
    // Fallback for snapshots downloaded before this marker file existed
    // (e.g. task-B03's debug probe), which only had the slugified name.
    return _unslugify(path.basename(snapshotDir.path));
  }

  static String _slugify(String repoId) => repoId.replaceAll('/', '_');

  static String _unslugify(String slug) {
    final idx = slug.indexOf('_');
    if (idx == -1) return slug;
    return '${slug.substring(0, idx)}/${slug.substring(idx + 1)}';
  }
}
