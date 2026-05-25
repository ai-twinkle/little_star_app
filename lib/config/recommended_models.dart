// ignore_for_file: deprecated_member_use_from_same_package

import 'package:little_star_app/config/recommended_model_config.dart';
import 'package:little_star_app/core/inference/sampling_params.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/models/hf_model_info.dart';

/// Curated model catalogue used across the app.
class RecommendedModels {
  // ── Primary: ModelProfile list ────────────────────────────────────────────

  /// Curated list of recommended models as [ModelProfile].
  /// This is the authoritative source; the legacy [models] list is derived
  /// from this for backward compatibility.
  static final List<ModelProfile> profiles = [
    const ModelProfile(
      id: 'unsloth/gemma-3-270m-it-GGUF',
      displayName: 'Gemma 3 270M',
      format: ModelFormat.gguf,
      recommendedQuantization: 'Q4_K_M',
      chatTemplateHint: ChatTemplateHint.gemma,
      ctxLen: 2048,
      defaultSamplingParams: SamplingParams(topK: 40, topP: 0.95, temperature: 0.8),
      backendHint: BackendHint.llamaCpp,
      quickDescription: 'Ultra-lightweight, perfect for mobile',
      useCases: ['Chat', 'Quick Tasks'],
      badge: 'Fastest',
    ),
    const ModelProfile(
      id: 'twinkle-ai/Llama-3.2-3B-F1-Reasoning-Instruct-GGUF',
      displayName: 'Llama 3.2 3B F1 Reasoning',
      format: ModelFormat.gguf,
      recommendedQuantization: 'Q4_K_M',
      chatTemplateHint: ChatTemplateHint.llama3,
      ctxLen: 4096,
      defaultSamplingParams: SamplingParams(topK: 40, topP: 0.95, temperature: 0.7),
      backendHint: BackendHint.llamaCpp,
      quickDescription: 'Best for reasoning and problem solving',
      useCases: ['Reasoning', 'Chat', 'Analysis'],
      badge: 'Recommended',
    ),
    const ModelProfile(
      id: 'bartowski/Qwen_Qwen3-0.6B-GGUF',
      displayName: 'Qwen 3 0.6B',
      format: ModelFormat.gguf,
      recommendedQuantization: 'Q4_K_M',
      chatTemplateHint: ChatTemplateHint.qwen3,
      ctxLen: 4096,
      defaultSamplingParams: SamplingParams(topK: 40, topP: 0.95, temperature: 0.8),
      backendHint: BackendHint.llamaCpp,
      quickDescription: 'Compact with multilingual support',
      useCases: ['Chat', 'Multilingual'],
      badge: 'Efficient',
    ),
    const ModelProfile(
      id: 'unsloth/gemma-3-1b-it-GGUF',
      displayName: 'Gemma 3 1B',
      format: ModelFormat.gguf,
      recommendedQuantization: 'Q4_K_M',
      chatTemplateHint: ChatTemplateHint.gemma,
      ctxLen: 4096,
      defaultSamplingParams: SamplingParams(topK: 40, topP: 0.95, temperature: 0.8),
      backendHint: BackendHint.llamaCpp,
      quickDescription: 'Balanced performance and efficiency',
      useCases: ['Chat', 'General Tasks'],
      badge: 'Balanced',
    ),
    const ModelProfile(
      id: 'Qwen/Qwen2.5-1.5B-Instruct-GGUF',
      displayName: 'Qwen 2.5 1.5B Instruct',
      format: ModelFormat.gguf,
      recommendedQuantization: 'Q4_K_M',
      chatTemplateHint: ChatTemplateHint.qwen2,
      ctxLen: 4096,
      defaultSamplingParams: SamplingParams(topK: 40, topP: 0.95, temperature: 0.8),
      backendHint: BackendHint.llamaCpp,
      quickDescription: 'Enhanced multilingual performance',
      useCases: ['Chat', 'Multilingual', 'General Tasks'],
      badge: 'Versatile',
    ),
    // MLX — Apple Silicon only (task-1001 wires up MlxBackend)
    const ModelProfile(
      id: 'mlx-community/Llama-3.2-1B-Instruct-4bit',
      displayName: 'Llama 3.2 1B MLX (4-bit)',
      format: ModelFormat.mlx,
      recommendedQuantization: null,
      chatTemplateHint: ChatTemplateHint.llama3,
      ctxLen: 4096,
      defaultSamplingParams: SamplingParams(topK: 40, topP: 0.95, temperature: 0.8),
      backendHint: BackendHint.mlx,
      quickDescription: 'Optimised for Apple Neural Engine',
      useCases: ['Chat', 'iOS', 'macOS'],
      badge: 'MLX',
    ),
  ];

  /// Look up a profile by id.
  static ModelProfile? profileById(String id) {
    try {
      return profiles.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Legacy: kept for backward compatibility until UI migration ────────────

  /// @deprecated Use [profiles] instead.
  @Deprecated('Use RecommendedModels.profiles')
  static final List<RecommendedModelConfig> models = profiles
      .where((p) => p.format == ModelFormat.gguf)
      .map(
        (p) => RecommendedModelConfig(
          modelInfo: HFModelInfo(
            id: p.id,
            author: p.id.split('/').first,
            modelName: p.id.split('/').last,
            tags: const [],
            description: p.quickDescription,
          ),
          recommendedQuantization: p.recommendedQuantization ?? '',
          quickDescription: p.quickDescription,
          useCases: p.useCases,
          badge: p.badge,
        ),
      )
      .toList();

  /// @deprecated Use [profileById] instead.
  @Deprecated('Use RecommendedModels.profileById')
  static RecommendedModelConfig? getById(String id) {
    try {
      return models.firstWhere((m) => m.modelInfo.id == id);
    } catch (_) {
      return null;
    }
  }

  /// @deprecated Use [profiles] instead.
  @Deprecated('Use RecommendedModels.profiles')
  static List<HFModelInfo> get modelInfoList =>
      models.map((c) => c.modelInfo).toList();
}
