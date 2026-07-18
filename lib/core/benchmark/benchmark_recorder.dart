import 'package:little_star_app/core/benchmark/benchmark_sample.dart';
import 'package:little_star_app/core/inference/inference_backend.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/core/platform/battery_probe.dart';
import 'package:little_star_app/core/platform/memory_probe.dart';
import 'package:little_star_app/core/platform/thermal_probe.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/ui/shared/inference/generation_controller.dart';

/// A freshly created session plus the [BenchmarkSample] from its first
/// generation — see [BenchmarkRecorder.runNewSession].
class NewSessionBenchmarkResult {
  final InferenceSession session;
  final BenchmarkSample sample;
  const NewSessionBenchmarkResult(this.session, this.sample);
}

/// Wraps a single benchmark generation with load-time timing and
/// memory/thermal/battery telemetry, on top of [GenerationController]'s
/// existing TTFT/decode-tps/prefill metrics — task-C01.
///
/// Reusable across runs; does not own session lifecycle (callers create
/// and dispose sessions, same as [GenerationController]).
class BenchmarkRecorder {
  final MemoryProbe _memoryProbe;
  final ThermalProbe _thermalProbe;
  final BatteryProbe _batteryProbe;
  final GenerationController Function() _controllerFactory;

  BenchmarkRecorder({
    MemoryProbe? memoryProbe,
    ThermalProbe? thermalProbe,
    BatteryProbe? batteryProbe,
    GenerationController Function()? controllerFactory,
  })  : _memoryProbe = memoryProbe ?? DartIoMemoryProbe(),
        _thermalProbe = thermalProbe ?? PigeonThermalProbe(),
        _batteryProbe = batteryProbe ?? PluginBatteryProbe(),
        _controllerFactory = controllerFactory ?? GenerationController.new;

  /// Creates a new session via [backend].createSession, timing that call,
  /// then records one generation on it — the "session cold-start" sample.
  ///
  /// Caller owns the returned session (must call [InferenceSession.dispose]
  /// when done) so it can run further [runOnExistingSession] calls to
  /// capture the "session warm" samples the 2026-07-18 findings showed
  /// differ substantially from the first.
  Future<NewSessionBenchmarkResult> runNewSession({
    required InferenceBackend backend,
    required ModelFormat format,
    required ModelProfile profile,
    required InferenceSettings settings,
    required List<ChatMessage> messages,
    String? label,
  }) async {
    final loadStopwatch = Stopwatch()..start();
    final session = backend.createSession(profile, settings);
    loadStopwatch.stop();

    final sample = await runOnExistingSession(
      session: session,
      format: format,
      modelId: profile.id,
      messages: messages,
      label: label,
      modelLoadDuration: loadStopwatch.elapsed,
    );
    return NewSessionBenchmarkResult(session, sample);
  }

  /// Records one generation on an already-created [session] — the "session
  /// warm" sample when [session] has already generated before.
  Future<BenchmarkSample> runOnExistingSession({
    required InferenceSession session,
    required ModelFormat format,
    required String modelId,
    required List<ChatMessage> messages,
    String? label,
    Duration modelLoadDuration = Duration.zero,
  }) async {
    final thermalBefore = await _thermalProbe.currentThermalState();
    final batteryBefore = await _batteryProbe.currentBatteryLevel();

    int? peakMemory = _sampleMemory(null);

    final controller = _controllerFactory();
    final textBuffer = StringBuffer();
    GenerationMetrics? metrics;

    await for (final event in controller.run(session, messages)) {
      switch (event) {
        case GenerationToken(:final token):
          textBuffer.write(token);
          peakMemory = _sampleMemory(peakMemory);
        case GenerationDone(metrics: final m):
          metrics = m;
        case GenerationError(:final error, :final stackTrace):
          Error.throwWithStackTrace(error, stackTrace ?? StackTrace.current);
      }
    }

    peakMemory = _sampleMemory(peakMemory);
    final thermalAfter = await _thermalProbe.currentThermalState();
    final batteryAfter = await _batteryProbe.currentBatteryLevel();

    return BenchmarkSample(
      timestamp: DateTime.now(),
      format: format,
      modelId: modelId,
      label: label,
      modelLoadDuration: modelLoadDuration,
      generation: metrics!,
      generatedText: textBuffer.toString(),
      peakMemoryBytes: peakMemory,
      thermalStateBefore: thermalBefore,
      thermalStateAfter: thermalAfter,
      batteryLevelBefore: batteryBefore,
      batteryLevelAfter: batteryAfter,
    );
  }

  int? _sampleMemory(int? currentPeak) {
    final sample = _memoryProbe.currentRssBytes();
    if (currentPeak == null || sample > currentPeak) return sample;
    return currentPeak;
  }
}
