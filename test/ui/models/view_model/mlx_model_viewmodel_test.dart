import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/data/services/mlx_repo_fetcher.dart';
import 'package:little_star_app/models/hf_model_info.dart';
import 'package:little_star_app/ui/models/view_model/mlx_model_viewmodel.dart';

class _FakeFetcher implements MlxRepoFetcher {
  List<HFModelFile> files;
  bool throwOnListFiles = false;
  final List<String> downloadedUrls = [];

  _FakeFetcher(this.files);

  @override
  Future<List<HFModelFile>> listFiles(String repoId) async {
    if (throwOnListFiles) throw StateError('network error');
    return files;
  }

  @override
  Future<void> download(
    String url,
    String destinationPath, {
    void Function(int received, int total)? onProgress,
  }) async {
    downloadedUrls.add(url);
    onProgress?.call(50, 100);
    onProgress?.call(100, 100);
    await File(destinationPath).writeAsBytes(List.filled(10, 0));
  }
}

HFModelFile _file(String name, {int size = 10}) => HFModelFile(
      filename: name,
      size: size,
      downloadUrl: 'https://huggingface.co/fake/repo/resolve/main/$name',
    );

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mlx_model_viewmodel_test');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MlxModelViewModel — loadLocalModels', () {
    test('empty when directory does not exist', () async {
      final dir = Directory('${tempDir.path}/does-not-exist');
      final vm = MlxModelViewModel(mlxModelsDir: dir, fetcher: _FakeFetcher([]));
      addTearDown(vm.dispose);

      await vm.init();

      expect(vm.localModels, isEmpty);
      expect(vm.isLoadingLocal, isFalse);
    });

    test('reads repoId from marker file when present', () async {
      final snapshot = Directory('${tempDir.path}/some_slug')..createSync();
      File('${snapshot.path}/config.json').writeAsStringSync('{}');
      File('${snapshot.path}/.repo_id').writeAsStringSync('Real/RepoId');

      final vm = MlxModelViewModel(mlxModelsDir: tempDir, fetcher: _FakeFetcher([]));
      addTearDown(vm.dispose);
      await vm.init();

      expect(vm.localModels, hasLength(1));
      expect(vm.localModels.first.repoId, 'Real/RepoId');
      expect(vm.localModels.first.displayName, 'RepoId');
    });

    test('falls back to unslugified directory name without marker file', () async {
      final snapshot = Directory('${tempDir.path}/Bbson_gemma-3-4B-T1-it-MLX-4bit')
        ..createSync();
      File('${snapshot.path}/config.json').writeAsStringSync('{}');

      final vm = MlxModelViewModel(mlxModelsDir: tempDir, fetcher: _FakeFetcher([]));
      addTearDown(vm.dispose);
      await vm.init();

      expect(vm.localModels.first.repoId, 'Bbson/gemma-3-4B-T1-it-MLX-4bit');
    });

    test('skips a snapshot directory containing only the marker file', () async {
      final snapshot = Directory('${tempDir.path}/empty_slug')..createSync();
      File('${snapshot.path}/.repo_id').writeAsStringSync('some/repo');

      final vm = MlxModelViewModel(mlxModelsDir: tempDir, fetcher: _FakeFetcher([]));
      addTearDown(vm.dispose);
      await vm.init();

      expect(vm.localModels, isEmpty);
    });
  });

  group('MlxModelViewModel — downloadModel', () {
    test('downloads every file into a slugified snapshot directory', () async {
      final fetcher = _FakeFetcher([_file('config.json'), _file('model.safetensors')]);
      final vm = MlxModelViewModel(mlxModelsDir: tempDir, fetcher: fetcher);
      addTearDown(vm.dispose);
      await vm.init();

      final ok = await vm.downloadModel('Bbson/gemma-3-4B-T1-it-MLX-4bit');

      expect(ok, isTrue);
      expect(fetcher.downloadedUrls, hasLength(2));
      expect(vm.isDownloading, isFalse);
      expect(vm.downloadProgress, 1);
      expect(vm.error, isNull);

      final snapshotDir =
          Directory('${tempDir.path}/Bbson_gemma-3-4B-T1-it-MLX-4bit');
      expect(await snapshotDir.exists(), isTrue);
      expect(await File('${snapshotDir.path}/config.json').exists(), isTrue);
      expect(await File('${snapshotDir.path}/.repo_id').readAsString(),
          'Bbson/gemma-3-4B-T1-it-MLX-4bit');

      expect(vm.localModels, hasLength(1));
      expect(vm.localModels.first.repoId, 'Bbson/gemma-3-4B-T1-it-MLX-4bit');
    });

    test('sets error and returns false when repo has no MLX files', () async {
      final vm = MlxModelViewModel(mlxModelsDir: tempDir, fetcher: _FakeFetcher([]));
      addTearDown(vm.dispose);
      await vm.init();

      final ok = await vm.downloadModel('empty/repo');

      expect(ok, isFalse);
      expect(vm.error, contains('No MLX files found'));
      expect(vm.localModels, isEmpty);
    });

    test('sets error and returns false when fetcher throws', () async {
      final fetcher = _FakeFetcher([])..throwOnListFiles = true;
      final vm = MlxModelViewModel(mlxModelsDir: tempDir, fetcher: fetcher);
      addTearDown(vm.dispose);
      await vm.init();

      final ok = await vm.downloadModel('some/repo');

      expect(ok, isFalse);
      expect(vm.error, contains('Download failed'));
    });

    test('ignores blank repo id and does not touch isDownloading', () async {
      final vm = MlxModelViewModel(mlxModelsDir: tempDir, fetcher: _FakeFetcher([]));
      addTearDown(vm.dispose);
      await vm.init();

      final ok = await vm.downloadModel('   ');

      expect(ok, isFalse);
      expect(vm.isDownloading, isFalse);
    });
  });

  group('MlxModelViewModel — deleteLocalModel', () {
    test('removes the snapshot directory and refreshes the list', () async {
      final fetcher = _FakeFetcher([_file('config.json')]);
      final vm = MlxModelViewModel(mlxModelsDir: tempDir, fetcher: fetcher);
      addTearDown(vm.dispose);
      await vm.init();
      await vm.downloadModel('some/repo');
      expect(vm.localModels, hasLength(1));

      await vm.deleteLocalModel(vm.localModels.first);

      expect(vm.localModels, isEmpty);
      expect(await Directory('${tempDir.path}/some_repo').exists(), isFalse);
    });
  });
}
