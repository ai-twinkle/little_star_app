import 'package:little_star_app/config/recommended_model_config.dart';
import 'package:little_star_app/models/hf_model_info.dart';

/// Configuration for recommended models to show to users.
class RecommendedModels {
  /// List of recommended models for new users.
  /// These are curated based on quality, size, and performance.
  static final List<RecommendedModelConfig> models = [
    RecommendedModelConfig(
      modelInfo: HFModelInfo(
        id: 'unsloth/gemma-3-270m-it-GGUF',
        author: 'unsloth',
        modelName: 'gemma-3-270m-it-GGUF',
        downloads: 150000,
        likes: 650,
        tags: ['gemma', 'instruct', 'gguf', 'lightweight'],
        description: 'Google\'s Gemma 3 270M model. Ultra-lightweight and fast for mobile devices.',
      ),
      recommendedQuantization: 'Q4_K_M',
      quickDescription: 'Ultra-lightweight, perfect for mobile',
      useCases: ['Chat', 'Quick Tasks'],
      badge: 'Fastest',
    ),
    RecommendedModelConfig(
      modelInfo: HFModelInfo(
        id: 'twinkle-ai/Llama-3.2-3B-F1-Reasoning-Instruct-GGUF',
        author: 'twinkle-ai',
        modelName: 'Llama-3.2-3B-F1-Reasoning-Instruct-GGUF',
        downloads: 400000,
        likes: 950,
        tags: ['llama', 'instruct', 'reasoning', 'gguf'],
        description: 'Twinkle AI\'s Llama 3.2 3B F1 Reasoning Instruct model. Excellent for quick responses and low memory usage.',
      ),
      recommendedQuantization: 'Q4_K_M',
      quickDescription: 'Best for reasoning and problem solving',
      useCases: ['Reasoning', 'Chat', 'Analysis'],
      badge: 'Recommended',
    ),
    RecommendedModelConfig(
      modelInfo: HFModelInfo(
        id: 'bartowski/Qwen_Qwen3-0.6B-GGUF',
        author: 'bartowski',
        modelName: 'Qwen_Qwen3-0.6B-GGUF',
        downloads: 250000,
        likes: 720,
        tags: ['qwen', 'instruct', 'gguf', 'efficient'],
        description: 'Qwen 3 0.6B model. Compact and efficient with good multilingual support.',
      ),
      recommendedQuantization: 'Q4_K_M',
      quickDescription: 'Compact with multilingual support',
      useCases: ['Chat', 'Multilingual'],
      badge: 'Efficient',
    ),
    RecommendedModelConfig(
      modelInfo: HFModelInfo(
        id: 'unsloth/gemma-3-1b-it-GGUF',
        author: 'unsloth',
        modelName: 'gemma-3-1b-it-GGUF',
        downloads: 180000,
        likes: 700,
        tags: ['gemma', 'instruct', 'gguf', 'balanced'],
        description: 'Google\'s Gemma 3 1B model. Balanced performance and size for mobile devices.',
      ),
      recommendedQuantization: 'Q4_K_M',
      quickDescription: 'Balanced performance and efficiency',
      useCases: ['Chat', 'General Tasks'],
      badge: 'Balanced',
    ),
    RecommendedModelConfig(
      modelInfo: HFModelInfo(
        id: 'Qwen/Qwen2.5-1.5B-Instruct-GGUF',
        author: 'Qwen',
        modelName: 'Qwen2.5-1.5B-Instruct-GGUF',
        downloads: 320000,
        likes: 850,
        tags: ['qwen', 'instruct', 'gguf', 'multilingual'],
        description: 'Qwen 2.5 1.5B Instruct model. Enhanced multilingual capabilities with good performance.',
      ),
      recommendedQuantization: 'Q4_K_M',
      quickDescription: 'Enhanced multilingual performance',
      useCases: ['Chat', 'Multilingual', 'General Tasks'],
      badge: 'Versatile',
    ),
  ];

  /// Get a specific recommended model by ID.
  static RecommendedModelConfig? getById(String id) {
    try {
      return models.firstWhere((model) => model.modelInfo.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get the HFModelInfo list for backward compatibility
  static List<HFModelInfo> get modelInfoList =>
      models.map((config) => config.modelInfo).toList();
}
