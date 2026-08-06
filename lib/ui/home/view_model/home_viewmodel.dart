import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import 'package:little_star_app/config/recommended_model_config.dart';
import 'package:little_star_app/config/recommended_models.dart';
import 'package:little_star_app/core/platform/platform_adapter.dart';
import 'package:little_star_app/data/repositories/download_repository.dart';
import 'package:little_star_app/data/services/directory_service.dart';
import 'package:little_star_app/data/services/download_service.dart';
import 'package:little_star_app/data/services/huggingface_service.dart';
import 'package:little_star_app/data/services/onboarding_service.dart';
import 'package:little_star_app/models/download_task.dart';
import 'package:little_star_app/models/gguf_model_info.dart';
import 'package:little_star_app/models/hf_model_info.dart';
import 'package:little_star_app/utils/logger.dart';

/// State for a single recommended model
class RecommendedModelState {
  final RecommendedModelConfig config;
  final bool isDownloaded;
  final bool isDownloading;
  final DownloadTask? activeTask;
  final HFModelFile? recommendedFile;
  final bool isLoadingFileInfo;
  final String? error;
  final DownloadProgress? progress;

  const RecommendedModelState({
    required this.config,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.activeTask,
    this.recommendedFile,
    this.isLoadingFileInfo = false,
    this.error,
    this.progress,
  });

  RecommendedModelState copyWith({
    RecommendedModelConfig? config,
    bool? isDownloaded,
    bool? isDownloading,
    DownloadTask? activeTask,
    HFModelFile? recommendedFile,
    bool? isLoadingFileInfo,
    String? error,
    DownloadProgress? progress,
    bool clearActiveTask = false,
    bool clearError = false,
    bool clearProgress = false,
  }) {
    return RecommendedModelState(
      config: config ?? this.config,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isDownloading: isDownloading ?? this.isDownloading,
      activeTask: clearActiveTask ? null : (activeTask ?? this.activeTask),
      recommendedFile: recommendedFile ?? this.recommendedFile,
      isLoadingFileInfo: isLoadingFileInfo ?? this.isLoadingFileInfo,
      error: clearError ? null : (error ?? this.error),
      progress: clearProgress ? null : (progress ?? this.progress),
    );
  }
}

/// ViewModel for the Home Screen
class HomeViewModel extends ChangeNotifier {
  final HuggingFaceService _hfService;
  final DownloadService _downloadService;
  final DownloadRepository _downloadRepository;
  final DirectoryService _directoryService;
  final OnboardingService _onboardingService;
  final PlatformAdapter _platformAdapter;

  final Logger _log = Logger('HomeViewModel');

  // State
  List<RecommendedModelState> _recommendedModels = [];
  List<GGUFModelInfo> _localModels = [];
  List<DownloadTask> _activeTasks = [];
  bool _isLoadingLocal = true;
  bool _isInitialized = false;
  bool _hasCompletedOnboarding = false;
  int _currentOnboardingStep = 0;

  // Progress subscriptions
  final Map<String, StreamSubscription> _progressSubscriptions = {};
  final Map<String, DownloadProgress> _downloadProgress = {};

  // Getters
  List<RecommendedModelState> get recommendedModels => _recommendedModels;
  List<GGUFModelInfo> get localModels => _localModels;
  List<DownloadTask> get activeTasks => _activeTasks;
  bool get isLoadingLocal => _isLoadingLocal;
  bool get isInitialized => _isInitialized;
  bool get hasCompletedOnboarding => _hasCompletedOnboarding;
  int get currentOnboardingStep => _currentOnboardingStep;
  bool get supportsMlx => _platformAdapter.supportsMlx;

  HomeViewModel({
    required HuggingFaceService hfService,
    required DownloadService downloadService,
    required DownloadRepository downloadRepository,
    required DirectoryService directoryService,
    required OnboardingService onboardingService,
    PlatformAdapter? platformAdapter,
  }) : _hfService = hfService,
       _downloadService = downloadService,
       _downloadRepository = downloadRepository,
       _directoryService = directoryService,
       _onboardingService = onboardingService,
       _platformAdapter = platformAdapter ?? PlatformAdapter.current();

  /// Initialize the ViewModel
  Future<void> init() async {
    if (_isInitialized) return;

    _log.info('Initializing HomeViewModel');

    // Initialize recommended models
    _recommendedModels =
        RecommendedModels.models
            .map((config) => RecommendedModelState(config: config))
            .toList();

    // Load in parallel
    await Future.wait([
      _loadOnboardingState(),
      loadLocalModels(),
      _loadActiveTasks(),
    ]);

    // Load recommended file info
    await loadRecommendedModelFiles();

    _isInitialized = true;
    notifyListeners();
  }

  /// Load onboarding state
  Future<void> _loadOnboardingState() async {
    try {
      _hasCompletedOnboarding = await _onboardingService.hasCompleted();
      _currentOnboardingStep = await _onboardingService.getCurrentStep();
      _log.info(
        'Onboarding state: completed=$_hasCompletedOnboarding, step=$_currentOnboardingStep',
      );
    } catch (e) {
      _log.error('Failed to load onboarding state: $e');
    }
  }

  /// Load local models
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
            models.add(
              GGUFModelInfo(
                filePath: entity.path,
                fileName: entity.path.split('/').last,
                fileSize: stat.size,
              ),
            );
          }
        }
      }

      _localModels = models;
      _updateDownloadedStates();
      _log.info('Loaded ${models.length} local models');
    } catch (e) {
      _log.error('Failed to load local models: $e');
    } finally {
      _isLoadingLocal = false;
      notifyListeners();
    }
  }

  /// Load active download tasks
  Future<void> _loadActiveTasks() async {
    try {
      await _downloadRepository.init();
      _activeTasks = _downloadRepository.getResumableTasks();
      _updateDownloadingStates();
      _log.info('Loaded ${_activeTasks.length} active tasks');
    } catch (e) {
      _log.error('Failed to load active tasks: $e');
    }
  }

  /// Load file information for recommended models
  Future<void> loadRecommendedModelFiles() async {
    _log.info(
      'Loading file info for ${_recommendedModels.length} recommended models',
    );

    // Mark all as loading
    _recommendedModels =
        _recommendedModels
            .map((m) => m.copyWith(isLoadingFileInfo: true, clearError: true))
            .toList();
    notifyListeners();

    // Load all in parallel
    await Future.wait(
      _recommendedModels.map((modelState) async {
        final index = _recommendedModels.indexOf(modelState);
        try {
          final files = await _hfService.getModelFiles(
            modelState.config.modelInfo.id,
          );
          final recommendedFile = _findRecommendedFile(
            files,
            modelState.config.recommendedQuantization,
          );

          _recommendedModels[index] = modelState.copyWith(
            recommendedFile: recommendedFile,
            isLoadingFileInfo: false,
            clearError: true,
          );

          _log.info(
            'Loaded file for ${modelState.config.modelInfo.modelName}: ${recommendedFile?.filename}',
          );
        } catch (e) {
          _log.error(
            'Failed to load files for ${modelState.config.modelInfo.id}: $e',
          );
          _recommendedModels[index] = modelState.copyWith(
            isLoadingFileInfo: false,
            error: 'Failed to load file info',
          );
        }
      }),
    );

    _updateDownloadedStates();
    _updateDownloadingStates();
    notifyListeners();
  }

  /// Find the recommended file from a list of files
  HFModelFile? _findRecommendedFile(List<HFModelFile> files, String preferred) {
    if (files.isEmpty) return null;

    // Try exact match
    var file = files.cast<HFModelFile?>().firstWhere(
      (f) => f?.quantization == preferred,
      orElse: () => null,
    );
    if (file != null) return file;

    // Try same Q level (e.g., Q4_K_M -> Q4_*)
    final qLevel = preferred.length >= 2 ? preferred.substring(0, 2) : null;
    if (qLevel != null) {
      file = files.cast<HFModelFile?>().firstWhere(
        (f) => f?.quantization?.startsWith(qLevel) ?? false,
        orElse: () => null,
      );
      if (file != null) return file;
    }

    // Fallback to smallest file
    return files.reduce((a, b) => a.size < b.size ? a : b);
  }

  /// Start one-click download for a recommended model.
  /// [requestPermission] is a callback to request storage permission from UI.
  /// Returns true if permission was granted, false otherwise.
  Future<void> startOneClickDownload(
    RecommendedModelState modelState, {
    required Future<bool> Function() requestPermission,
  }) async {
    try {
      _log.info(
        'Starting one-click download for ${modelState.config.modelInfo.modelName}',
      );

      // Check if already downloading
      if (modelState.isDownloading) {
        _log.warn('Model is already downloading');
        return;
      }

      // Check if already downloaded
      if (modelState.isDownloaded) {
        _log.warn('Model is already downloaded');
        return;
      }

      // Request storage permission before downloading (Android only)
      if (Platform.isAndroid) {
        final hasPermission = await requestPermission();
        if (!hasPermission) {
          _log.warn('Storage permission denied, cannot download');
          throw Exception('Storage permission is required to download models');
        }
      }

      // Ensure we have file info
      if (modelState.recommendedFile == null) {
        _log.warn('No recommended file available, loading now...');
        await loadRecommendedModelFiles();

        // Get updated state
        final updatedState = _recommendedModels.firstWhere(
          (m) => m.config.modelInfo.id == modelState.config.modelInfo.id,
        );

        if (updatedState.recommendedFile == null) {
          throw Exception('No files available for this model');
        }

        return startOneClickDownload(
          updatedState,
          requestPermission: requestPermission,
        );
      }

      final file = modelState.recommendedFile!;
      final modelsDir = await _directoryService.getModelsDirectory();
      final destinationPath = path.join(modelsDir.path, file.filename);

      // Create download task
      final task = DownloadTask(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        url: file.downloadUrl,
        filename: file.filename,
        destinationPath: destinationPath,
        totalBytes: file.size,
        downloadedBytes: 0,
        status: DownloadStatus.pending,
        createdAt: DateTime.now(),
        repoId: modelState.config.modelInfo.id,
        quantization: file.quantization,
      );

      // Save task
      await _downloadRepository.saveTask(task);
      _activeTasks.add(task);

      // Update state
      final index = _recommendedModels.indexOf(modelState);
      _recommendedModels[index] = modelState.copyWith(
        isDownloading: true,
        activeTask: task,
        clearError: true,
      );
      notifyListeners();

      // Start download
      final progressStream = _downloadService.startDownload(
        task: task,
        onStatusChanged: _onDownloadStatusChanged,
      );

      // Subscribe to progress
      _progressSubscriptions[task.id] = progressStream.listen(
        (progress) {
          _downloadProgress[task.id] = progress;
          _updateProgressForModel(task.id, progress);
          notifyListeners();
        },
        onError: (e) {
          _log.error('Download stream error: $e');
        },
        onDone: () {
          _log.info('Download stream closed for ${task.id}');
        },
      );

      _log.info('Started download: ${file.filename}');
    } catch (e) {
      _log.error('Failed to start download: $e');
      final index = _recommendedModels.indexOf(modelState);
      _recommendedModels[index] = modelState.copyWith(
        error: 'Failed to start download: $e',
        isDownloading: false,
        clearActiveTask: true,
      );
      notifyListeners();
    }
  }

  /// Handle download status change
  void _onDownloadStatusChanged(DownloadTask task) {
    _log.info('Download status changed: ${task.filename} -> ${task.status}');

    if (task.status == DownloadStatus.completed) {
      // Clean up
      _progressSubscriptions[task.id]?.cancel();
      _progressSubscriptions.remove(task.id);
      _downloadProgress.remove(task.id);

      // Update recommended model state
      final index = _recommendedModels.indexWhere(
        (m) => m.activeTask?.id == task.id,
      );
      if (index >= 0) {
        _recommendedModels[index] = _recommendedModels[index].copyWith(
          isDownloaded: true,
          isDownloading: false,
          clearActiveTask: true,
          clearProgress: true,
        );
      }

      // Reload local models
      loadLocalModels();
    } else if (task.status == DownloadStatus.failed ||
        task.status == DownloadStatus.cancelled) {
      // Handle error
      final index = _recommendedModels.indexWhere(
        (m) => m.activeTask?.id == task.id,
      );
      if (index >= 0) {
        _recommendedModels[index] = _recommendedModels[index].copyWith(
          isDownloading: false,
          error: task.errorMessage ?? 'Download failed',
          clearActiveTask: true,
          clearProgress: true,
        );
      }

      _progressSubscriptions[task.id]?.cancel();
      _progressSubscriptions.remove(task.id);
      _downloadProgress.remove(task.id);
    }

    notifyListeners();
  }

  /// Update progress for a specific model
  void _updateProgressForModel(String taskId, DownloadProgress progress) {
    final index = _recommendedModels.indexWhere(
      (m) => m.activeTask?.id == taskId,
    );
    if (index >= 0) {
      _recommendedModels[index] = _recommendedModels[index].copyWith(
        progress: progress,
      );
    }
  }

  /// Update downloaded states based on local models
  void _updateDownloadedStates() {
    for (var i = 0; i < _recommendedModels.length; i++) {
      final modelState = _recommendedModels[i];
      final recommendedFilename = modelState.recommendedFile?.filename;
      if (recommendedFilename != null) {
        final isDownloaded = _localModels.any(
          (m) => m.fileName == recommendedFilename,
        );
        _recommendedModels[i] = modelState.copyWith(isDownloaded: isDownloaded);
      }
    }
  }

  /// Update downloading states based on active tasks
  void _updateDownloadingStates() {
    for (var i = 0; i < _recommendedModels.length; i++) {
      final modelState = _recommendedModels[i];
      final recommendedFilename = modelState.recommendedFile?.filename;
      if (recommendedFilename != null) {
        final activeTask = _activeTasks.cast<DownloadTask?>().firstWhere(
          (t) =>
              t?.filename == recommendedFilename &&
              t?.status == DownloadStatus.downloading,
          orElse: () => null,
        );
        if (activeTask != null) {
          _recommendedModels[i] = modelState.copyWith(
            isDownloading: true,
            activeTask: activeTask,
          );
        }
      }
    }
  }

  /// Complete onboarding step
  Future<void> completeOnboardingStep(int step) async {
    await _onboardingService.setStepCompleted(step);
    _currentOnboardingStep = step + 1;
    _hasCompletedOnboarding = await _onboardingService.hasCompleted();
    notifyListeners();
  }

  /// Skip onboarding
  Future<void> skipOnboarding() async {
    await _onboardingService.skip();
    _hasCompletedOnboarding = true;
    notifyListeners();
  }

  @override
  void dispose() {
    // Cancel all progress subscriptions
    for (final subscription in _progressSubscriptions.values) {
      subscription.cancel();
    }
    _progressSubscriptions.clear();
    _downloadProgress.clear();
    super.dispose();
  }
}
