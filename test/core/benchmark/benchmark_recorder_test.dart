import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/benchmark/benchmark_recorder.dart';
import 'package:little_star_app/core/inference/inference_backend.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/core/platform/battery_probe.dart';
import 'package:little_star_app/core/platform/memory_probe.dart';
import 'package:little_star_app/core/platform/thermal_probe.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/ui/shared/inference/generation_controller.dart';

// ─── Fakes ────────────────────────────────────────────────────────────────────

class _FakeSession implements InferenceSession {
  final List<String> tokens;
  final Object? errorAfter;
  bool cancelCalled = false;
  bool disposeCalled = false;

  _FakeSession({this.tokens = const ['a', 'b', 'c'], this.errorAfter});

  @override
  Stream<String> generate(List<ChatMessage> messages) async* {
    for (final t in tokens) {
      yield t;
    }
    if (errorAfter != null) throw errorAfter!;
  }

  @override
  void cancel() => cancelCalled = true;

  @override
  void dispose() => disposeCalled = true;
}

class _FakeBackend implements InferenceBackend {
  final InferenceSession session;
  ModelProfile? lastProfile;
  InferenceSettings? lastSettings;

  _FakeBackend(this.session);

  @override
  bool canHandle(ModelProfile profile) => true;

  @override
  InferenceSession createSession(ModelProfile profile, InferenceSettings settings) {
    lastProfile = profile;
    lastSettings = settings;
    return session;
  }
}

class _FakeMemoryProbe implements MemoryProbe {
  final List<int> samples;
  int _i = 0;
  _FakeMemoryProbe(this.samples);

  @override
  int currentRssBytes() {
    final v = samples[_i];
    if (_i < samples.length - 1) _i++;
    return v;
  }
}

class _FakeThermalProbe implements ThermalProbe {
  final List<ThermalStatus> readings;
  int _i = 0;
  _FakeThermalProbe(this.readings);

  @override
  Future<ThermalStatus> currentThermalState() async {
    final v = readings[_i];
    if (_i < readings.length - 1) _i++;
    return v;
  }
}

class _FakeBatteryProbe implements BatteryProbe {
  final List<int?> readings;
  int _i = 0;
  _FakeBatteryProbe(this.readings);

  @override
  Future<int?> currentBatteryLevel() async {
    final v = readings[_i];
    if (_i < readings.length - 1) _i++;
    return v;
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

const _profile = ModelProfile(
  id: 'model-1',
  displayName: 'Test',
  format: ModelFormat.gguf,
  localPath: '/tmp/model.gguf',
);

final _userMsg = ChatMessage(content: 'hi', isUser: true);

BenchmarkRecorder _recorder({
  List<int> memory = const [100],
  List<ThermalStatus> thermal = const [ThermalStatus.nominal],
  List<int?> battery = const [80],
}) =>
    BenchmarkRecorder(
      memoryProbe: _FakeMemoryProbe(memory),
      thermalProbe: _FakeThermalProbe(thermal),
      batteryProbe: _FakeBatteryProbe(battery),
    );

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('BenchmarkRecorder.runOnExistingSession', () {
    test('captures generation metrics and joined text', () async {
      final session = _FakeSession(tokens: ['Hel', 'lo']);
      final recorder = _recorder();

      final sample = await recorder.runOnExistingSession(
        session: session,
        format: ModelFormat.gguf,
        modelId: 'model-1',
        messages: [_userMsg],
      );

      expect(sample.generatedText, 'Hello');
      expect(sample.generation.tokenCount, 2);
      expect(sample.generation.stopReason, StopReason.completed);
      expect(sample.format, ModelFormat.gguf);
      expect(sample.modelId, 'model-1');
    });

    test('passes label through unchanged', () async {
      final session = _FakeSession();
      final recorder = _recorder();

      final sample = await recorder.runOnExistingSession(
        session: session,
        format: ModelFormat.mlx,
        modelId: 'model-1',
        messages: [_userMsg],
        label: 'L512-session-warm',
      );

      expect(sample.label, 'L512-session-warm');
    });

    test('records thermal/battery readings taken before and after', () async {
      final session = _FakeSession();
      final recorder = _recorder(
        thermal: [ThermalStatus.nominal, ThermalStatus.fair],
        battery: [90, 88],
      );

      final sample = await recorder.runOnExistingSession(
        session: session,
        format: ModelFormat.gguf,
        modelId: 'model-1',
        messages: [_userMsg],
      );

      expect(sample.thermalStateBefore, ThermalStatus.nominal);
      expect(sample.thermalStateAfter, ThermalStatus.fair);
      expect(sample.batteryLevelBefore, 90);
      expect(sample.batteryLevelAfter, 88);
    });

    test('peakMemoryBytes is the max sample observed during the run', () async {
      final session = _FakeSession(tokens: ['a', 'b', 'c']);
      final recorder = _recorder(memory: [100, 150, 120, 90]);

      final sample = await recorder.runOnExistingSession(
        session: session,
        format: ModelFormat.gguf,
        modelId: 'model-1',
        messages: [_userMsg],
      );

      expect(sample.peakMemoryBytes, 150);
    });

    test('default modelLoadDuration is zero when not provided', () async {
      final session = _FakeSession();
      final recorder = _recorder();

      final sample = await recorder.runOnExistingSession(
        session: session,
        format: ModelFormat.gguf,
        modelId: 'model-1',
        messages: [_userMsg],
      );

      expect(sample.modelLoadDuration, Duration.zero);
    });

    test('rethrows the generation error instead of returning a sample', () async {
      final session = _FakeSession(tokens: ['a'], errorAfter: StateError('boom'));
      final recorder = _recorder();

      expect(
        () => recorder.runOnExistingSession(
          session: session,
          format: ModelFormat.gguf,
          modelId: 'model-1',
          messages: [_userMsg],
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('BenchmarkRecorder.runNewSession', () {
    test('creates the session via the backend and times the call', () async {
      final session = _FakeSession();
      final backend = _FakeBackend(session);
      final recorder = _recorder();
      const settings = InferenceSettings();

      final result = await recorder.runNewSession(
        backend: backend,
        format: ModelFormat.gguf,
        profile: _profile,
        settings: settings,
        messages: [_userMsg],
        label: 'session-cold',
      );

      expect(identical(result.session, session), isTrue);
      expect(backend.lastProfile, _profile);
      expect(backend.lastSettings, settings);
      expect(result.sample.modelId, 'model-1');
      expect(result.sample.label, 'session-cold');
      expect(result.sample.modelLoadDuration, greaterThanOrEqualTo(Duration.zero));
    });
  });
}
