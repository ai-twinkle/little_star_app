import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/ui/benchmark/controller/benchmark_recorder.dart';
import 'package:little_star_app/core/benchmark/prompt_tiers.dart';
import 'package:little_star_app/core/inference/backend_selector.dart';
import 'package:little_star_app/core/inference/inference_backend.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/core/platform/battery_probe.dart';
import 'package:little_star_app/core/platform/memory_probe.dart';
import 'package:little_star_app/core/platform/platform_adapter.dart';
import 'package:little_star_app/core/platform/thermal_probe.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/data/services/local_model_catalog.dart';
import 'package:little_star_app/ui/benchmark/view_model/benchmark_viewmodel.dart';

// ─── Fakes ────────────────────────────────────────────────────────────────────

class _FakeSession implements InferenceSession {
  int generateCallCount = 0;
  bool disposeCalled = false;

  @override
  Stream<String> generate(List<ChatMessage> messages) async* {
    generateCallCount++;
    yield 'ok';
  }

  @override
  void cancel() {}

  @override
  void dispose() => disposeCalled = true;
}

class _FakeBackend implements InferenceBackend {
  final List<_FakeSession> createdSessions = [];
  ModelProfile? lastProfile;

  @override
  bool canHandle(ModelProfile profile) => true;

  @override
  InferenceSession createSession(
    ModelProfile profile,
    InferenceSettings settings,
  ) {
    lastProfile = profile;
    final session = _FakeSession();
    createdSessions.add(session);
    return session;
  }
}

class _NoopMemoryProbe implements MemoryProbe {
  @override
  int currentRssBytes() => 0;
}

class _NoopThermalProbe implements ThermalProbe {
  @override
  Future<ThermalStatus> currentThermalState() async => ThermalStatus.nominal;
}

class _NoopBatteryProbe implements BatteryProbe {
  @override
  Future<int?> currentBatteryLevel() async => 100;
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late _FakeBackend backend;
  late BenchmarkViewModel viewModel;

  setUp(() {
    backend = _FakeBackend();
    viewModel = BenchmarkViewModel(
      recorder: BenchmarkRecorder(
        memoryProbe: _NoopMemoryProbe(),
        thermalProbe: _NoopThermalProbe(),
        batteryProbe: _NoopBatteryProbe(),
      ),
      backendSelector: BackendSelector(
        platform: IOSPlatformAdapter(),
        mlxBackendFactory: () => backend,
      ),
    );
  });

  const modelPath = '/tmp/fake-mlx-model'; // no .gguf suffix -> detected as MLX

  group('BenchmarkViewModel.runProtocol', () {
    test(
      'records one cold sample plus warmRepeats warm samples, then closes the session',
      () async {
        await viewModel.runProtocol(
          modelPath,
          tiers: [PromptTier.l128],
          warmRepeats: 2,
        );

        expect(viewModel.samples, hasLength(3));
        expect(viewModel.samples[0].label, 'L128-session-cold');
        expect(viewModel.samples[1].label, 'L128-session-warm-1');
        expect(viewModel.samples[2].label, 'L128-session-warm-2');
        expect(viewModel.hasOpenSession, isFalse);
        expect(backend.createdSessions.single.disposeCalled, isTrue);
      },
    );

    test(
      'labels the cold sample app-cold when isFirstSessionThisLaunch is true',
      () async {
        viewModel.setAppJustLaunched(true);
        await viewModel.runProtocol(
          modelPath,
          tiers: [PromptTier.l512],
          warmRepeats: 0,
        );

        expect(viewModel.samples.single.label, 'L512-app-cold');
      },
    );
  });

  test(
    'only the first tier gets app-cold when appJustLaunched is true',
    () async {
      viewModel.setAppJustLaunched(true);
      await viewModel.runProtocol(
        modelPath,
        tiers: [PromptTier.l128, PromptTier.l512],
        warmRepeats: 1,
      );

      final labels = viewModel.samples.map((s) => s.label).toList();
      expect(labels, [
        'L128-app-cold',
        'L128-session-warm-1',
        'L512-session-cold',
        'L512-session-warm-1',
      ]);
    },
  );

  test('app-cold selection is consumed by the next protocol run', () async {
    viewModel.setAppJustLaunched(true);

    await viewModel.runProtocol(
      modelPath,
      tiers: [PromptTier.l128],
      warmRepeats: 0,
    );
    await viewModel.runProtocol(
      modelPath,
      tiers: [PromptTier.l512],
      warmRepeats: 0,
    );

    expect(viewModel.appJustLaunched, isFalse);
    expect(viewModel.samples.map((sample) => sample.label), [
      'L128-app-cold',
      'L512-session-cold',
    ]);
  });

  test('no tier gets app-cold when appJustLaunched is false', () async {
    await viewModel.runProtocol(
      modelPath,
      tiers: [PromptTier.l128, PromptTier.l512],
      warmRepeats: 0,
    );

    final labels = viewModel.samples.map((s) => s.label).toList();
    expect(labels, ['L128-session-cold', 'L512-session-cold']);
  });

  test('defaults to all four standard tiers', () async {
    await viewModel.runProtocol(modelPath, warmRepeats: 0);
    expect(viewModel.samples, hasLength(PromptTier.all.length));
  });

  test('refreshPreflight exposes the latest telemetry snapshot', () async {
    expect(viewModel.preflight, isNull);

    await viewModel.refreshPreflight();

    expect(viewModel.preflight?.thermalState, ThermalStatus.nominal);
    expect(viewModel.preflight?.batteryLevel, 100);
  });

  test('cold run uses the shared local-path profile policy', () async {
    await viewModel.openSessionAndRunPrompt('/tmp/models/example-mlx', 'hello');

    expect(backend.lastProfile?.displayName, 'example-mlx');
    expect(backend.lastProfile?.format, ModelFormat.mlx);
  });

  test('refreshLocalModels exposes models discovered by the catalog', () async {
    final root = await Directory.systemTemp.createTemp(
      'benchmark_vm_catalog_test',
    );
    addTearDown(() => root.delete(recursive: true));
    final ggufRoot = Directory('${root.path}/gguf')..createSync();
    final mlxRoot = Directory('${root.path}/mlx')..createSync();
    File('${ggufRoot.path}/local.gguf').writeAsStringSync('model');

    final vm = BenchmarkViewModel(
      recorder: BenchmarkRecorder(
        memoryProbe: _NoopMemoryProbe(),
        thermalProbe: _NoopThermalProbe(),
        batteryProbe: _NoopBatteryProbe(),
      ),
      backendSelector: BackendSelector(
        platform: IOSPlatformAdapter(),
        mlxBackendFactory: () => backend,
      ),
      localModelCatalog: LocalModelCatalog.fixed(
        ggufRoot: ggufRoot,
        mlxRoot: mlxRoot,
      ),
    );

    await vm.refreshLocalModels();

    expect(vm.availableModels.single.path, endsWith('local.gguf'));
  });
}
