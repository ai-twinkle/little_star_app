import 'package:little_star_app/core/inference/generation_metrics.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/models/chat_message.dart';

// ── Event hierarchy ──────────────────────────────────────────────────────────

sealed class GenerationEvent {}

/// A single decoded token emitted by the model.
class GenerationToken extends GenerationEvent {
  final String token;
  GenerationToken(this.token);
}

/// Generation ended (normally, cancelled, or after an error).
/// Always the last event in the stream; never emitted after [GenerationError].
class GenerationDone extends GenerationEvent {
  final GenerationMetrics metrics;
  GenerationDone(this.metrics);
}

/// The session threw an error. This is always the last event in the stream.
class GenerationError extends GenerationEvent {
  final Object error;
  final StackTrace? stackTrace;
  GenerationError(this.error, [this.stackTrace]);
}

// ── Controller ───────────────────────────────────────────────────────────────

/// Wraps [InferenceSession.generate] with metrics (TTFT, TPS, stop reason)
/// and cooperative cancel support.
///
/// Reusable across sequential [run] calls; do not call [run] concurrently.
class GenerationController {
  bool _cancelled = false;
  bool _isRunning = false;
  InferenceSession? _activeSession;

  bool get isRunning => _isRunning;

  /// Runs [session.generate] for [messages], yielding events with live metrics.
  ///
  /// The stream always ends with either [GenerationDone] or [GenerationError].
  /// Call [cancel] to stop early; the stream will still close with [GenerationDone]
  /// carrying [StopReason.cancelled].
  Stream<GenerationEvent> run(
    InferenceSession session,
    List<ChatMessage> messages,
  ) async* {
    _cancelled = false;
    _isRunning = true;
    _activeSession = session;

    final startTime = DateTime.now();
    DateTime? firstTokenTime;
    int tokenCount = 0;

    try {
      try {
        await for (final token in session.generate(messages)) {
          firstTokenTime ??= DateTime.now();
          tokenCount++;
          yield GenerationToken(token);
        }
      } catch (e, st) {
        yield GenerationError(e, st);
        return;
      }

      final finishedTime = DateTime.now();
      final stopReason =
          _cancelled ? StopReason.cancelled : StopReason.completed;
      final ttft = firstTokenTime?.difference(startTime);
      final decodeDuration =
          firstTokenTime != null
              ? finishedTime.difference(firstTokenTime)
              : null;
      final tps =
          decodeDuration != null && decodeDuration.inMilliseconds > 0
              ? tokenCount / (decodeDuration.inMilliseconds / 1000.0)
              : null;

      int? promptTokenCount;
      double? prefillTokensPerSecond;
      final promptMetricsSource =
          session is PromptMetricsSource
              ? session as PromptMetricsSource
              : null;
      if (promptMetricsSource != null) {
        promptTokenCount = promptMetricsSource.lastPromptTokenCount;
        final prefillDuration = promptMetricsSource.lastPrefillDuration;
        if (promptTokenCount != null &&
            prefillDuration != null &&
            prefillDuration.inMicroseconds > 0) {
          prefillTokensPerSecond =
              promptTokenCount / (prefillDuration.inMicroseconds / 1000000.0);
        }
      }

      yield GenerationDone(
        GenerationMetrics(
          tokenCount: tokenCount,
          stopReason: stopReason,
          ttft: ttft,
          tokensPerSecond: tps,
          promptTokenCount: promptTokenCount,
          prefillTokensPerSecond: prefillTokensPerSecond,
        ),
      );
    } finally {
      _isRunning = false;
      _activeSession = null;
    }
  }

  /// Requests the active generation to stop.
  /// No-op if no generation is in progress.
  void cancel() {
    if (!_isRunning) return;
    _cancelled = true;
    _activeSession?.cancel();
  }
}
