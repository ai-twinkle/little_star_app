/// Backend-neutral sampling parameters.
///
/// Intentionally decoupled from llama.cpp internals (no n_batch, mirostat,
/// repeat_penalty, etc.). Backend adapters translate these into
/// backend-specific structs as needed.
class SamplingParams {
  /// Number of top-k tokens to consider. 0 = disabled.
  final int topK;

  /// Nucleus sampling probability cutoff.
  final double topP;

  /// Softmax temperature. Lower = more deterministic.
  final double temperature;

  /// RNG seed. -1 = random.
  final int seed;

  const SamplingParams({
    this.topK = 40,
    this.topP = 0.95,
    this.temperature = 0.8,
    this.seed = -1,
  });

  SamplingParams copyWith({
    int? topK,
    double? topP,
    double? temperature,
    int? seed,
  }) {
    return SamplingParams(
      topK: topK ?? this.topK,
      topP: topP ?? this.topP,
      temperature: temperature ?? this.temperature,
      seed: seed ?? this.seed,
    );
  }

  Map<String, dynamic> toJson() => {
        'topK': topK,
        'topP': topP,
        'temperature': temperature,
        'seed': seed,
      };

  factory SamplingParams.fromJson(Map<String, dynamic> json) => SamplingParams(
        topK: (json['topK'] as num?)?.toInt() ?? 40,
        topP: (json['topP'] as num?)?.toDouble() ?? 0.95,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.8,
        seed: (json['seed'] as num?)?.toInt() ?? -1,
      );

  @override
  bool operator ==(Object other) =>
      other is SamplingParams &&
      topK == other.topK &&
      topP == other.topP &&
      temperature == other.temperature &&
      seed == other.seed;

  @override
  int get hashCode => Object.hash(topK, topP, temperature, seed);
}
