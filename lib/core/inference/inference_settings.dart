import 'sampling_params.dart';

/// Per-session configuration: sampler, prompt framing, and generation limits.
class InferenceSettings {
  final SamplingParams samplingParams;

  /// Optional system prompt prepended to every conversation.
  final String? systemPrompt;

  /// Maximum number of tokens to generate.
  final int maxTokens;

  /// Sequences that stop generation when encountered.
  final List<String> stopSequences;

  const InferenceSettings({
    this.samplingParams = const SamplingParams(),
    this.systemPrompt,
    this.maxTokens = 1024,
    this.stopSequences = const [],
  });

  InferenceSettings copyWith({
    SamplingParams? samplingParams,
    String? systemPrompt,
    int? maxTokens,
    List<String>? stopSequences,
    bool clearSystemPrompt = false,
  }) {
    return InferenceSettings(
      samplingParams: samplingParams ?? this.samplingParams,
      systemPrompt: clearSystemPrompt ? null : (systemPrompt ?? this.systemPrompt),
      maxTokens: maxTokens ?? this.maxTokens,
      stopSequences: stopSequences ?? this.stopSequences,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is InferenceSettings &&
      samplingParams == other.samplingParams &&
      systemPrompt == other.systemPrompt &&
      maxTokens == other.maxTokens &&
      _listEquals(stopSequences, other.stopSequences);

  @override
  int get hashCode =>
      Object.hash(samplingParams, systemPrompt, maxTokens, Object.hashAll(stopSequences));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
