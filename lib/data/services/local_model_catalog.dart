import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:little_star_app/data/services/directory_service.dart';

/// A locally available model that can be selected by the benchmark harness.
class LocalModelEntry {
  final String label;
  final String path;

  const LocalModelEntry({required this.label, required this.path});
}

/// Discovers GGUF files and MLX snapshot directories used by the app.
class LocalModelCatalog {
  final Future<Directory> Function() _ggufRoot;
  final Future<Directory> Function() _mlxRoot;

  LocalModelCatalog({
    Future<Directory> Function()? ggufRoot,
    Future<Directory> Function()? mlxRoot,
  }) : _ggufRoot =
           ggufRoot ??
           (() => DirectoryServiceFactory.create().getModelsDirectory()),
       _mlxRoot = mlxRoot ?? _defaultMlxRoot;

  factory LocalModelCatalog.fixed({
    required Directory ggufRoot,
    required Directory mlxRoot,
  }) => LocalModelCatalog(
    ggufRoot: () async => ggufRoot,
    mlxRoot: () async => mlxRoot,
  );

  static Future<Directory> _defaultMlxRoot() async {
    final appSupport = await getApplicationSupportDirectory();
    return Directory(path.join(appSupport.path, 'Models', 'mlx'));
  }

  /// Returns every discoverable local model. Each root is best-effort so one
  /// unavailable platform directory does not hide models from the other.
  Future<List<LocalModelEntry>> discover() async {
    final models = <LocalModelEntry>[];

    try {
      final root = await _ggufRoot();
      if (await root.exists()) {
        await for (final entity in root.list()) {
          if (entity is File &&
              path.extension(entity.path).toLowerCase() == '.gguf') {
            models.add(
              LocalModelEntry(
                label: 'GGUF · ${path.basename(entity.path)}',
                path: entity.path,
              ),
            );
          }
        }
      }
    } catch (_) {
      // Best-effort discovery; callers can still enter a path manually.
    }

    try {
      final root = await _mlxRoot();
      if (await root.exists()) {
        await for (final entity in root.list()) {
          if (entity is Directory) {
            models.add(
              LocalModelEntry(
                label: 'MLX · ${path.basename(entity.path)}',
                path: entity.path,
              ),
            );
          }
        }
      }
    } catch (_) {
      // Best-effort discovery; callers can still enter a path manually.
    }

    return models;
  }
}
