import 'dart:io';

import 'package:path/path.dart' as path;

/// Static dependency rules that protect the documented layer architecture.
class ArchitectureRules {
  final Directory repositoryRoot;

  const ArchitectureRules(this.repositoryRoot);

  List<String> coreUiDependencies() {
    final coreRoot = Directory(path.join(repositoryRoot.path, 'lib', 'core'));
    final uiRoot = path.normalize(path.join(repositoryRoot.path, 'lib', 'ui'));
    final violations = <String>[];

    for (final file in _dartFiles(coreRoot)) {
      for (final uri in _dependencyUris(file.readAsStringSync())) {
        if (_targetsUi(uri, from: file, uiRoot: uiRoot)) {
          violations.add('${path.relative(file.path)} imports $uri');
        }
      }
    }

    return violations..sort();
  }

  List<String> dataCoreDependencies() {
    final dataRoot = Directory(path.join(repositoryRoot.path, 'lib', 'data'));
    final coreRoot = path.normalize(
      path.join(repositoryRoot.path, 'lib', 'core'),
    );
    final violations = <String>[];

    for (final file in _dartFiles(dataRoot)) {
      for (final uri in _dependencyUris(file.readAsStringSync())) {
        final targetsCore =
            uri.startsWith('package:little_star_app/core/') ||
            (!uri.contains(':') &&
                path.isWithin(
                  coreRoot,
                  path.normalize(path.join(file.parent.path, uri)),
                ));
        if (targetsCore) {
          violations.add('${path.relative(file.path)} imports $uri');
        }
      }
    }

    return violations..sort();
  }

  List<String> benchmarkAndMlxWidgetDependencies() {
    const widgetPaths = [
      'lib/ui/benchmark/widgets/benchmark_screen.dart',
      'lib/ui/models/widgets/mlx_models_screen.dart',
    ];
    const forbiddenFiles = [
      'directory_service.dart',
      'local_model_catalog.dart',
      'prompt_tiers.dart',
      'protocol_runner.dart',
      'sustained_load_runner.dart',
    ];
    const forbiddenRunnerTypes = [
      'BenchmarkProtocolRunner',
      'SustainedLoadRunner',
    ];
    final violations = <String>[];

    for (final widgetPath in widgetPaths) {
      final file = File(path.join(repositoryRoot.path, widgetPath));
      if (!file.existsSync()) {
        violations.add('$widgetPath is missing from the architecture check');
        continue;
      }

      final source = file.readAsStringSync();
      for (final uri in _dependencyUris(source)) {
        final isForbidden =
            uri == 'dart:io' ||
            uri.startsWith('package:path/') ||
            uri.startsWith('package:path_provider/') ||
            forbiddenFiles.any(uri.endsWith);
        if (isForbidden) {
          violations.add('$widgetPath imports $uri');
        }
      }
      for (final type in forbiddenRunnerTypes) {
        if (source.contains(type)) {
          violations.add('$widgetPath orchestrates $type');
        }
      }
    }

    return violations..sort();
  }

  List<String> homeWidgetPlatformDependencies() {
    const widgetPath = 'lib/ui/home/widgets/home_screen.dart';
    final file = File(path.join(repositoryRoot.path, widgetPath));
    if (!file.existsSync()) {
      return ['$widgetPath is missing from the architecture check'];
    }

    final source = file.readAsStringSync();
    final violations = <String>[];
    for (final uri in _dependencyUris(source)) {
      if (uri == 'dart:io' || uri.endsWith('platform_adapter.dart')) {
        violations.add('$widgetPath imports $uri');
      }
    }
    if (source.contains('Platform.')) {
      violations.add('$widgetPath performs direct Platform capability checks');
    }
    return violations;
  }

  Iterable<File> _dartFiles(Directory root) => root
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((file) => path.extension(file.path) == '.dart');

  Iterable<String> _dependencyUris(String source) sync* {
    final directives = RegExp(
      r'^\s*(?:import|export)\s+([^;]+);',
      multiLine: true,
    );
    final quotedUri = RegExp(r'''["']([^"']+)["']''');

    for (final directive in directives.allMatches(source)) {
      final body = directive.group(1)!;
      for (final match in quotedUri.allMatches(body)) {
        yield match.group(1)!;
      }
    }
  }

  bool _targetsUi(String uri, {required File from, required String uiRoot}) {
    if (uri.startsWith('package:little_star_app/ui/')) return true;
    if (uri.contains(':')) return false;

    final resolved = path.normalize(path.join(from.parent.path, uri));
    return resolved == uiRoot || path.isWithin(uiRoot, resolved);
  }
}
