/// Why a generation stopped.
enum StopReason { completed, cancelled, error }

/// Backend-agnostic measurements for one generation.
class GenerationMetrics {
  /// Number of tokens emitted by the model.
  final int tokenCount;

  /// Time from generation start to the first token.
  final Duration? ttft;

  /// Approximate decode throughput (tokens / decode-phase seconds).
  final double? tokensPerSecond;

  /// Prompt token count when the backend exposes prompt metrics.
  final int? promptTokenCount;

  /// Prefill throughput when the backend exposes prompt metrics.
  final double? prefillTokensPerSecond;

  final StopReason stopReason;

  const GenerationMetrics({
    required this.tokenCount,
    required this.stopReason,
    this.ttft,
    this.tokensPerSecond,
    this.promptTokenCount,
    this.prefillTokensPerSecond,
  });
}
