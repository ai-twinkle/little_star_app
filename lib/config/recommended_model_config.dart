import 'package:little_star_app/models/hf_model_info.dart';

/// Configuration for a recommended model with additional metadata
/// for the home screen experience.
class RecommendedModelConfig {
  /// The base HuggingFace model information
  final HFModelInfo modelInfo;

  /// The recommended quantization version to download (e.g., "Q4_K_M")
  final String recommendedQuantization;

  /// Short description for display on the card
  final String? quickDescription;

  /// Use case tags (e.g., ["Chat", "Coding", "Reasoning"])
  final List<String> useCases;

  /// Badge text to display on the card (e.g., "Recommended", "Fastest")
  final String? badge;

  const RecommendedModelConfig({
    required this.modelInfo,
    required this.recommendedQuantization,
    this.quickDescription,
    this.useCases = const [],
    this.badge,
  });

  /// Create a copy with updated values
  RecommendedModelConfig copyWith({
    HFModelInfo? modelInfo,
    String? recommendedQuantization,
    String? quickDescription,
    List<String>? useCases,
    String? badge,
  }) {
    return RecommendedModelConfig(
      modelInfo: modelInfo ?? this.modelInfo,
      recommendedQuantization: recommendedQuantization ?? this.recommendedQuantization,
      quickDescription: quickDescription ?? this.quickDescription,
      useCases: useCases ?? this.useCases,
      badge: badge ?? this.badge,
    );
  }
}
