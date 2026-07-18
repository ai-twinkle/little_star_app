import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/benchmark/benchmark_recorder.dart';
import 'package:little_star_app/core/benchmark/prompt_tiers.dart';
import 'package:little_star_app/core/benchmark/protocol_runner.dart';
import 'package:little_star_app/core/inference/backend_selector.dart';
import 'package:little_star_app/core/inference/inference_backend.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/core/platform/battery_probe.dart';
import 'package:little_star_app/core/platform/memory_probe.dart';
import 'package:little_star_app/core/platform/thermal_probe.dart';
import 'package:little_star_app/models/chat_message.dart';
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

  @override
  bool canHandle(ModelProfile profile) => true;

  @override
  InferenceSession createSession(ModelProfile profile, InferenceSettings settings) {
    final session = _FakeSession();
    createdSessions.add(session);
    return session;
  }
}

class _AlwaysSupportsMlx implements BackendPlatform {
  @override
  bool get supportsMLX => true;
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
  late BenchmarkProtocolRunner runner;

  setUp(() {
    backend = _FakeBackend();
    viewModel = BenchmarkViewModel(
      recorder: BenchmarkRecorder(
        memoryProbe: _NoopMemoryProbe(),
        thermalProbe: _NoopThermalProbe(),
        batteryProbe: _NoopBatteryProbe(),
      ),
      backendSelector: BackendSelector(
        platform: _AlwaysSupportsMlx(),
        mlxBackendFactory: () => backend,
      ),
    );
    runner = BenchmarkProtocolRunner(viewModel);
  });

  const modelPath = '/tmp/fake-mlx-model'; // no .gguf suffix -> detected as MLX

  group('BenchmarkProtocolRunner.runTier', () {
    test('records one cold sample plus warmRepeats warm samples, then closes the session',
        () async {
      await runner.runTier(
        modelPath,
        PromptTier.l128,
        warmRepeats: 2,
        isFirstSessionThisLaunch: false,
      );

      expect(viewModel.samples, hasLength(3));
      expect(viewModel.samples[0].label, 'L128-session-cold');
      expect(viewModel.samples[1].label, 'L128-session-warm-1');
      expect(viewModel.samples[2].label, 'L128-session-warm-2');
      expect(viewModel.hasOpenSession, isFalse);
      expect(backend.createdSessions.single.disposeCalled, isTrue);
    });

    test('labels the cold sample app-cold when isFirstSessionThisLaunch is true', () async {
      await runner.runTier(
        modelPath,
        PromptTier.l512,
        warmRepeats: 0,
        isFirstSessionThisLaunch: true,
      );

      expect(viewModel.samples.single.label, 'L512-app-cold');
    });
  });

  group('BenchmarkProtocolRunner.runAll', () {
    test('only the first tier gets app-cold when appJustLaunched is true', () async {
      await runner.runAll(
        modelPath,
        tiers: [PromptTier.l128, PromptTier.l512],
        warmRepeats: 1,
        appJustLaunched: true,
      );

      final labels = viewModel.samples.map((s) => s.label).toList();
      expect(labels, [
        'L128-app-cold',
        'L128-session-warm-1',
        'L512-session-cold',
        'L512-session-warm-1',
      ]);
    });

    test('no tier gets app-cold when appJustLaunched is false', () async {
      await runner.runAll(
        modelPath,
        tiers: [PromptTier.l128, PromptTier.l512],
        warmRepeats: 0,
      );

      final labels = viewModel.samples.map((s) => s.label).toList();
      expect(labels, ['L128-session-cold', 'L512-session-cold']);
    });

    test('defaults to all four standard tiers', () async {
      await runner.runAll(modelPath, warmRepeats: 0);
      expect(viewModel.samples, hasLength(PromptTier.all.length));
    });
  });
}
