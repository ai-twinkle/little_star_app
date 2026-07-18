import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/ui/benchmark/view_model/benchmark_viewmodel.dart';

/// Repeatedly generates on an already-open session for a fixed wall-clock
/// duration (task-C03: "發熱曲線" raw material — connect-the-dots on
/// decode tokens/s, thermalState, and battery drain over a sustained run).
///
/// Deliberately reuses [BenchmarkRecorder.runOnExistingSession] per
/// iteration rather than introducing a separate time-series data type: each
/// generation call already samples thermal/battery before and after and
/// peak memory throughout (task-C01), so back-to-back calls naturally
/// produce a time series at one-generation resolution — [BenchmarkSample
/// .timestamp] is the x-axis. Every sample from this runner is a
/// "session-warm" data point (all after the session's first, already-timed
/// separately by task-C02's protocol).
class SustainedLoadRunner {
  final BenchmarkViewModel viewModel;
  bool _cancelled = false;

  SustainedLoadRunner(this.viewModel);

  /// Runs generations back-to-back until [duration] has elapsed (or
  /// [maxIterations] is hit first, or [cancel] is called) — whichever comes
  /// first. Requires a session already opened via
  /// [BenchmarkViewModel.openSessionAndRun].
  Future<void> run({
    required List<ChatMessage> messages,
    Duration duration = const Duration(minutes: 10),
    int? maxIterations,
    String labelPrefix = 'sustained',
  }) async {
    if (!viewModel.hasOpenSession) {
      throw StateError('SustainedLoadRunner.run requires an already-open session');
    }
    _cancelled = false;
    final start = DateTime.now();
    var i = 0;
    while (!_cancelled &&
        DateTime.now().difference(start) < duration &&
        (maxIterations == null || i < maxIterations)) {
      i++;
      final elapsedMs = DateTime.now().difference(start).inMilliseconds;
      await viewModel.runOnOpenSession(messages, label: '$labelPrefix-t${elapsedMs}ms-$i');
    }
  }

  /// Stops the loop after the in-flight generation finishes.
  void cancel() => _cancelled = true;
}
