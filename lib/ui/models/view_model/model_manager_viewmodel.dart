import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:little_star_app/data/repositories/download_repository.dart';
import 'package:little_star_app/data/services/directory_service.dart';
import 'package:little_star_app/data/services/download_service.dart';
import 'package:little_star_app/data/services/huggingface_service.dart';
import 'package:little_star_app/models/download_task.dart';
import 'package:little_star_app/models/gguf_model_info.dart';
import 'package:little_star_app/models/hf_model_info.dart';
import 'package:little_star_app/utils/logger.dart';
import 'package:path/path.dart' as path;

/// ViewModel for managing model browsing and downloading.
class ModelManagerViewModel extends ChangeNotifier {
  final HuggingFaceService _hfService;
  final DownloadService _downloadService;
  final DownloadRepository _downloadRepository;
  final DirectoryService _directoryService;
  final Logger _log = Logger('ModelManagerViewModel');

  // State
  List<HFModelInfo> _searchResults = [];
  List<HFModelFile> _selectedModelFiles = [];
  List<GGUFModelInfo> _localModels = [];
  List<DownloadTask> _activeTasks = [];

  HFModelInfo? _selectedModel;
  bool _isSearching = false;
  bool _isLoadingFiles = false;
  bool _isLoadingLocal = false;
  String? _error;
  String _searchQuery = '';

  // Progress streams
  final Map<String, StreamSubscription> _progressSubscriptions = {};
  final Map<String, DownloadProgress> _downloadProgress = {};

  ModelManagerViewModel({
    required HuggingFaceService hfService,
    required DownloadService downloadService,
    required DownloadRepository downloadRepository,
    required DirectoryService directoryService,
  })  : _hfService = hfService,
        _downloadService = downloadService,
        _downloadRepository = downloadRepository,
        _directoryService = directoryService;

  // Getters
  List<HFModelInfo> get searchResults => _searchResults;
  List<HFModelFile> get selectedModelFiles => _selectedModelFiles;
  List<GGUFModelInfo> get localModels => _localModels;
  List<DownloadTask> get activeTasks => _activeTasks;
  HFModelInfo? get selectedModel => _selectedModel;
  bool get isSearching => _isSearching;
  bool get isLoadingFiles => _isLoadingFiles;
  bool get isLoadingLocal => _isLoadingLocal;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  DownloadProgress? getProgress(String taskId) => _downloadProgress[taskId];

  /// Initialize the view model.
  Future<void> init() async {
    await _downloadRepository.init();
    await loadLocalModels();
    await loadActiveTasks();
    await searchModels(); // Load popular models
  }

  /// Search for GGUF models on Hugging Face.
  Future<void> searchModels([String? query]) async {
    _searchQuery = query ?? '';
    _isSearching = true;
    _error = null;
    notifyListeners();

    try {
      _searchResults = await _hfService.searchModels(
        query: query,
        limit: 30,
        sortBy: 'downloads',
      );
      _log.info('Search returned ${_searchResults.length} models');
    } catch (e) {
      _error = 'Search failed: $e';
      _log.error('Search failed: $e');
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Select a model to view its files.
  Future<void> selectModel(HFModelInfo model) async {
    _selectedModel = model;
    _selectedModelFiles = [];
    _isLoadingFiles = true;
    _error = null;
    notifyListeners();

    try {
      _selectedModelFiles = await _hfService.getModelFiles(model.id);
      _log.info('Loaded ${_selectedModelFiles.length} files for ${model.id}');
    } catch (e) {
      _error = 'Failed to load files: $e';
      _log.error('Failed to load files: $e');
    } finally {
      _isLoadingFiles = false;
      notifyListeners();
    }
  }

  /// Clear model selection.
  void clearSelection() {
    _selectedModel = null;
    _selectedModelFiles = [];
    notifyListeners();
  }

  /// Start downloading a model file.
  Future<void> startDownload(HFModelFile file) async {
    try {
      // Check if already downloading
      if (_downloadRepository.hasTask(file.downloadUrl)) {
        final existing = _downloadRepository.getTaskByUrl(file.downloadUrl);
        if (existing != null &&
            existing.status != DownloadStatus.failed &&
            existing.status != DownloadStatus.cancelled) {
          _log.debug('Task already exists: ${file.filename}');
          return;
        }
      }

      // Get destination path
      final modelsDir = await _directoryService.getModelsDirectory();
      final destinationPath = path.join(modelsDir.path, file.filename);

      // Create download task
      final task = DownloadTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: file.downloadUrl,
        filename: file.filename,
        destinationPath: destinationPath,
        totalBytes: file.size,
        repoId: _selectedModel?.id,
        quantization: file.quantization,
      );

      // Save task
      await _downloadRepository.saveTask(task);
      _activeTasks.add(task);
      notifyListeners();

      // Start download
      final progressStream = _downloadService.startDownload(
        task: task,
        onStatusChanged: _onTaskStatusChanged,
      );

      // Subscribe to progress
      _progressSubscriptions[task.id] = progressStream.listen(
        (progress) {
          _downloadProgress[task.id] = progress;
          notifyListeners();
        },
        onError: (e) {
          _log.error('Download error: $e');
        },
      );

      _log.info('Started download: ${file.filename}');
    } catch (e) {
      _error = 'Failed to start download: $e';
      _log.error('Failed to start download: $e');
      notifyListeners();
    }
  }

  void _onTaskStatusChanged(DownloadTask task) {
    // Update in repository
    _downloadRepository.saveTask(task);

    // Update local list
    final index = _activeTasks.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      _activeTasks[index] = task;
    }

    // If completed, refresh local models
    if (task.status == DownloadStatus.completed) {
      _progressSubscriptions[task.id]?.cancel();
      _progressSubscriptions.remove(task.id);
      _downloadProgress.remove(task.id);
      loadLocalModels();
    }

    notifyListeners();
  }

  /// Pause a download.
  void pauseDownload(String taskId) {
    _downloadService.pauseDownload(taskId);
    final task = _activeTasks.firstWhere((t) => t.id == taskId);
    task.status = DownloadStatus.paused;
    _downloadRepository.saveTask(task);
    notifyListeners();
  }

  /// Resume a paused download.
  Future<void> resumeDownload(String taskId) async {
    final task = _activeTasks.firstWhere((t) => t.id == taskId);

    final progressStream = _downloadService.startDownload(
      task: task,
      onStatusChanged: _onTaskStatusChanged,
    );

    _progressSubscriptions[task.id] = progressStream.listen(
      (progress) {
        _downloadProgress[task.id] = progress;
        notifyListeners();
      },
    );
  }

  /// Cancel a download.
  Future<void> cancelDownload(String taskId) async {
    final task = _activeTasks.firstWhere((t) => t.id == taskId);
    await _downloadService.cancelDownload(taskId, task.destinationPath);

    task.status = DownloadStatus.cancelled;
    await _downloadRepository.saveTask(task);

    _activeTasks.removeWhere((t) => t.id == taskId);
    _progressSubscriptions[taskId]?.cancel();
    _progressSubscriptions.remove(taskId);
    _downloadProgress.remove(taskId);

    notifyListeners();
  }

  /// Load local GGUF models.
  Future<void> loadLocalModels() async {
    _isLoadingLocal = true;
    notifyListeners();

    try {
      final modelsDir = await _directoryService.getModelsDirectory();
      final List<GGUFModelInfo> models = [];

      if (await modelsDir.exists()) {
        await for (final entity in modelsDir.list()) {
          if (entity is File && entity.path.toLowerCase().endsWith('.gguf')) {
            final stat = await entity.stat();
            models.add(GGUFModelInfo(
              filePath: entity.path,
              fileName: path.basename(entity.path),
              fileSize: stat.size,
            ));
          }
        }
      }

      _localModels = models;
      _log.info('Loaded ${models.length} local models');
    } catch (e) {
      _log.error('Failed to load local models: $e');
    } finally {
      _isLoadingLocal = false;
      notifyListeners();
    }
  }

  /// Load active download tasks.
  Future<void> loadActiveTasks() async {
    _activeTasks = _downloadRepository.getResumableTasks();
    notifyListeners();
  }

  /// Delete a local model.
  Future<void> deleteLocalModel(GGUFModelInfo model) async {
    try {
      final file = File(model.filePath);
      if (await file.exists()) {
        await file.delete();
        _log.info('Deleted model: ${model.fileName}');
      }
      await loadLocalModels();
    } catch (e) {
      _error = 'Failed to delete model: $e';
      _log.error('Failed to delete model: $e');
      notifyListeners();
    }
  }

  /// Check if a file is already downloaded.
  bool isDownloaded(String filename) {
    return _localModels.any((m) => m.fileName == filename);
  }

  /// Check if a file is currently downloading.
  bool isDownloading(String url) {
    return _activeTasks.any(
        (t) => t.url == url && t.status == DownloadStatus.downloading);
  }

  /// Get download status for a file.
  DownloadStatus? getDownloadStatus(String url) {
    final task = _activeTasks.where((t) => t.url == url).firstOrNull;
    return task?.status;
  }

  @override
  void dispose() {
    for (final sub in _progressSubscriptions.values) {
      sub.cancel();
    }
    _progressSubscriptions.clear();
    _downloadProgress.clear();
    super.dispose();
  }
}
