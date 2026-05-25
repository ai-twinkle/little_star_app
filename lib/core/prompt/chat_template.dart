import 'package:little_star_app/models/chat_message.dart';

/// Formats a conversation into a single prompt string.
/// The result always ends with the model's opening token so inference
/// continues as the assistant.
abstract class ChatTemplate {
  String render(List<ChatMessage> messages, {String? systemPrompt});
}

/// Gemma chat template: <bos><start_of_turn>user / model
/// System prompt is prepended to the first user turn (Gemma has no system role).
class GemmaChatTemplate implements ChatTemplate {
  const GemmaChatTemplate();

  @override
  String render(List<ChatMessage> messages, {String? systemPrompt}) {
    final buf = StringBuffer('<bos>');
    bool injectSystem = systemPrompt != null && systemPrompt.isNotEmpty;

    for (final msg in messages) {
      if (msg.isUser) {
        buf.write('<start_of_turn>user\n');
        if (injectSystem) {
          buf.write('$systemPrompt\n\n');
          injectSystem = false;
        }
        buf.write('${msg.content}<end_of_turn>\n');
      } else {
        buf.write('<start_of_turn>model\n${msg.content}<end_of_turn>\n');
      }
    }
    buf.write('<start_of_turn>model\n');
    return buf.toString();
  }
}

/// Llama 3 chat template: <|begin_of_text|> + header tokens + <|eot_id|>
class Llama3ChatTemplate implements ChatTemplate {
  const Llama3ChatTemplate();

  @override
  String render(List<ChatMessage> messages, {String? systemPrompt}) {
    final buf = StringBuffer('<|begin_of_text|>');

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      buf.write('<|start_header_id|>system<|end_header_id|>\n\n'
          '$systemPrompt<|eot_id|>');
    }

    for (final msg in messages) {
      if (msg.isUser) {
        buf.write('<|start_header_id|>user<|end_header_id|>\n\n'
            '${msg.content}<|eot_id|>');
      } else {
        buf.write('<|start_header_id|>assistant<|end_header_id|>\n\n'
            '${msg.content}<|eot_id|>');
      }
    }
    buf.write('<|start_header_id|>assistant<|end_header_id|>\n\n');
    return buf.toString();
  }
}

/// ChatML template used by Qwen2 and Qwen3: <|im_start|> / <|im_end|>
class ChatMlChatTemplate implements ChatTemplate {
  const ChatMlChatTemplate();

  @override
  String render(List<ChatMessage> messages, {String? systemPrompt}) {
    final buf = StringBuffer();

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      buf.write('<|im_start|>system\n$systemPrompt<|im_end|>\n');
    }

    for (final msg in messages) {
      if (msg.isUser) {
        buf.write('<|im_start|>user\n${msg.content}<|im_end|>\n');
      } else {
        buf.write('<|im_start|>assistant\n${msg.content}<|im_end|>\n');
      }
    }
    buf.write('<|im_start|>assistant\n');
    return buf.toString();
  }
}

/// Safe fallback for unknown model families.
class FallbackChatTemplate implements ChatTemplate {
  const FallbackChatTemplate();

  @override
  String render(List<ChatMessage> messages, {String? systemPrompt}) {
    final buf = StringBuffer();

    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      buf.write('System: $systemPrompt\n\n');
    }

    for (final msg in messages) {
      buf.write(msg.isUser ? 'User: ${msg.content}\n' : 'Assistant: ${msg.content}\n');
    }
    buf.write('Assistant: ');
    return buf.toString();
  }
}
