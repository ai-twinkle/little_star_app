import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/ui/benchmark/controller/benchmark_recorder.dart';
import 'package:little_star_app/core/inference/backend_selector.dart';
import 'package:little_star_app/core/inference/inference_backend.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/core/platform/battery_probe.dart';
import 'package:little_star_app/core/platform/thermal_probe.dart';
import 'package:little_star_app/core/platform/memory_probe.dart';
import 'package:little_star_app/core/platform/platform_adapter.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/ui/benchmark/view_model/benchmark_viewmodel.dart';

// ─── Fakes ────────────────────────────────────────────────────────────────────

class _FakeSession implements InferenceSession {
  final Duration perTokenDelay;
  List<ChatMessage>? lastMessages;
  _FakeSession({this.perTokenDelay = Duration.zero});

  @override
  Stream<String> generate(List<ChatMessage> messages) async* {
    lastMessages = messages;
    if (perTokenDelay > Duration.zero) await Future.delayed(perTokenDelay);
    yield 'ok';
  }

  @override
  void cancel() {}

  @override
  void dispose() {}
}

class _FakeBackend implements InferenceBackend {
  final InferenceSession session;
  _FakeBackend(this.session);

  @override
  bool canHandle(ModelProfile profile) => true;

  @override
  InferenceSession createSession(
    ModelProfile profile,
    InferenceSettings settings,
  ) => session;
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

const modelPath = '/tmp/fake-mlx-model'; // no .gguf suffix -> detected as MLX
final messages = [ChatMessage(content: 'keep going', isUser: true)];

BenchmarkViewModel _viewModelWith(InferenceSession session) =>
    BenchmarkViewModel(
      recorder: BenchmarkRecorder(
        memoryProbe: _NoopMemoryProbe(),
        thermalProbe: _NoopThermalProbe(),
        batteryProbe: _NoopBatteryProbe(),
      ),
      backendSelector: BackendSelector(
        platform: IOSPlatformAdapter(),
        mlxBackendFactory: () => _FakeBackend(session),
      ),
    );

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  test('runSustainedPrompt turns Widget text into a user message', () async {
    final session = _FakeSession();
    final viewModel = _viewModelWith(session);
    await viewModel.openSessionAndRunPrompt(modelPath, 'warm up');

    await viewModel.runSustainedPrompt('keep going', maxIterations: 1);

    expect(session.lastMessages?.single.content, 'keep going');
    expect(session.lastMessages?.single.isUser, isTrue);
  });

  test('throws StateError when no session is open', () async {
    final viewModel = _viewModelWith(_FakeSession());

    expect(
      () => viewModel.runSustained(messages: messages, maxIterations: 1),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'stops after maxIterations even though duration has not elapsed',
    () async {
      final viewModel = _viewModelWith(_FakeSession());
      await viewModel.openSessionAndRunPrompt(modelPath, 'warm up');

      await viewModel.runSustained(
        messages: messages,
        duration: const Duration(minutes: 10),
        maxIterations: 3,
      );

      // 1 from openSessionAndRunPrompt + 3 from the sustained loop.
      expect(viewModel.samples, hasLength(4));
      final sustainedLabels =
          viewModel.samples.skip(1).map((s) => s.label).toList();
      expect(sustainedLabels, everyElement(startsWith('sustained-')));
      expect(sustainedLabels[0], endsWith('-1'));
      expect(sustainedLabels[1], endsWith('-2'));
      expect(sustainedLabels[2], endsWith('-3'));
    },
  );

  test('cancel() stops the loop before maxIterations is reached', () async {
    final session = _FakeSession(
      perTokenDelay: const Duration(milliseconds: 20),
    );
    final viewModel = _viewModelWith(session);
    await viewModel.openSessionAndRunPrompt(modelPath, 'warm up');

    final future = viewModel.runSustained(
      messages: messages,
      duration: const Duration(minutes: 10),
      maxIterations: 100,
    );
    await Future.delayed(const Duration(milliseconds: 30));
    viewModel.cancelSustained();
    await future;

    // 1 cold sample + far fewer than 100 sustained iterations.
    expect(viewModel.samples.length, lessThan(20));
    expect(viewModel.samples.length, greaterThan(1));
  });
}
