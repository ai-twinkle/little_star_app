import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/core/prompt/chat_template.dart';

class ChatTemplateResolver {
  /// Priority: [override] > [ModelProfile.chatTemplateHint] > [FallbackChatTemplate].
  static ChatTemplate resolve(ModelProfile profile, [ChatTemplate? override]) {
    if (override != null) return override;

    return switch (profile.chatTemplateHint) {
      ChatTemplateHint.gemma => const GemmaChatTemplate(),
      ChatTemplateHint.llama3 => const Llama3ChatTemplate(),
      ChatTemplateHint.qwen2 || ChatTemplateHint.qwen3 => const ChatMlChatTemplate(),
      ChatTemplateHint.unknown => const FallbackChatTemplate(),
    };
  }
}

/// Resolves the [ChatTemplate] for a given [ModelProfile].
final chatTemplateProvider =
    Provider.family<ChatTemplate, ModelProfile>(
  (ref, profile) => ChatTemplateResolver.resolve(profile),
);
