import 'package:hive_flutter/hive_flutter.dart';
import 'package:little_star_app/models/download_task.dart';
import 'package:little_star_app/utils/logger.dart';

/// Repository for persisting download tasks using Hive.
class DownloadRepository {
  static const String _boxName = 'download_tasks';
  final Logger _log = Logger('DownloadRepository');

  Box<DownloadTask>? _box;

  /// Initialize the repository.
  /// Must be called before using any other methods.
  Future<void> init() async {
    if (_box != null && _box!.isOpen) return;

    // Register adapters if not already registered
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(DownloadStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(DownloadTaskAdapter());
    }

    _box = await Hive.openBox<DownloadTask>(_boxName);
    _log.info('DownloadRepository initialized with ${_box!.length} tasks');
  }

  /// Get all download tasks.
  List<DownloadTask> getAllTasks() {
    _ensureInitialized();
    return _box!.values.toList();
  }

  /// Get tasks by status.
  List<DownloadTask> getTasksByStatus(DownloadStatus status) {
    _ensureInitialized();
    return _box!.values.where((task) => task.status == status).toList();
  }

  /// Get pending and paused tasks (for resuming on app start).
  List<DownloadTask> getResumableTasks() {
    _ensureInitialized();
    return _box!.values
        .where((task) =>
            task.status == DownloadStatus.pending ||
            task.status == DownloadStatus.paused ||
            task.status == DownloadStatus.downloading)
        .toList();
  }

  /// Get completed tasks.
  List<DownloadTask> getCompletedTasks() {
    return getTasksByStatus(DownloadStatus.completed);
  }

  /// Get a task by ID.
  DownloadTask? getTask(String id) {
    _ensureInitialized();
    return _box!.get(id);
  }

  /// Add or update a task.
  Future<void> saveTask(DownloadTask task) async {
    _ensureInitialized();
    await _box!.put(task.id, task);
    _log.debug('Saved task: ${task.id} (${task.status.name})');
  }

  /// Delete a task.
  Future<void> deleteTask(String id) async {
    _ensureInitialized();
    await _box!.delete(id);
    _log.debug('Deleted task: $id');
  }

  /// Delete all completed tasks.
  Future<void> clearCompletedTasks() async {
    _ensureInitialized();
    final completedIds = _box!.values
        .where((task) => task.status == DownloadStatus.completed)
        .map((task) => task.id)
        .toList();

    for (final id in completedIds) {
      await _box!.delete(id);
    }
    _log.info('Cleared ${completedIds.length} completed tasks');
  }

  /// Delete all tasks.
  Future<void> clearAllTasks() async {
    _ensureInitialized();
    await _box!.clear();
    _log.info('Cleared all tasks');
  }

  /// Check if a file is already downloaded or downloading.
  bool hasTask(String url) {
    _ensureInitialized();
    return _box!.values.any((task) => task.url == url);
  }

  /// Get task by URL.
  DownloadTask? getTaskByUrl(String url) {
    _ensureInitialized();
    try {
      return _box!.values.firstWhere((task) => task.url == url);
    } catch (_) {
      return null;
    }
  }

  /// Check if a file with the same name exists in completed downloads.
  DownloadTask? getCompletedTaskByFilename(String filename) {
    _ensureInitialized();
    try {
      return _box!.values.firstWhere(
        (task) =>
            task.filename == filename &&
            task.status == DownloadStatus.completed,
      );
    } catch (_) {
      return null;
    }
  }

  void _ensureInitialized() {
    if (_box == null || !_box!.isOpen) {
      throw StateError(
          'DownloadRepository not initialized. Call init() first.');
    }
  }

  /// Close the repository.
  Future<void> close() async {
    await _box?.close();
    _log.debug('DownloadRepository closed');
  }
}
