import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/core/prompt/chat_template.dart';
import 'package:little_star_app/core/prompt/chat_template_resolver.dart';
import 'package:little_star_app/models/chat_message.dart';

ChatMessage _user(String content) =>
    ChatMessage(content: content, isUser: true, timestamp: DateTime(2024));

ChatMessage _assistant(String content) =>
    ChatMessage(content: content, isUser: false, timestamp: DateTime(2024));

void main() {
  // ── GemmaChatTemplate ──────────────────────────────────────────────────────
  group('GemmaChatTemplate', () {
    const t = GemmaChatTemplate();

    test('single user turn, no system', () {
      expect(
        t.render([_user('Hello')]),
        '<bos><start_of_turn>user\nHello<end_of_turn>\n<start_of_turn>model\n',
      );
    });

    test('single user turn with system prompt', () {
      expect(
        t.render([_user('Hello')], systemPrompt: 'Be helpful'),
        '<bos><start_of_turn>user\nBe helpful\n\nHello<end_of_turn>\n<start_of_turn>model\n',
      );
    });

    test('multi-turn conversation', () {
      expect(
        t.render([_user('Hi'), _assistant('Hello!'), _user('How are you?')]),
        '<bos>'
        '<start_of_turn>user\nHi<end_of_turn>\n'
        '<start_of_turn>model\nHello!<end_of_turn>\n'
        '<start_of_turn>user\nHow are you?<end_of_turn>\n'
        '<start_of_turn>model\n',
      );
    });

    test('system injected only into first user turn', () {
      final result = t.render(
        [_user('First'), _assistant('A'), _user('Second')],
        systemPrompt: 'Sys',
      );
      expect(result, contains('Sys\n\nFirst'));
      expect(result, isNot(contains('Sys\n\nSecond')));
    });

    test('empty system prompt is ignored', () {
      final result = t.render([_user('Hi')], systemPrompt: '');
      expect(result, isNot(contains('system')));
    });
  });

  // ── Llama3ChatTemplate ─────────────────────────────────────────────────────
  group('Llama3ChatTemplate', () {
    const t = Llama3ChatTemplate();

    test('single user turn, no system', () {
      expect(
        t.render([_user('Hello')]),
        '<|begin_of_text|>'
        '<|start_header_id|>user<|end_header_id|>\n\n'
        'Hello<|eot_id|>'
        '<|start_header_id|>assistant<|end_header_id|>\n\n',
      );
    });

    test('single user turn with system prompt', () {
      expect(
        t.render([_user('Hello')], systemPrompt: 'Be helpful'),
        '<|begin_of_text|>'
        '<|start_header_id|>system<|end_header_id|>\n\nBe helpful<|eot_id|>'
        '<|start_header_id|>user<|end_header_id|>\n\nHello<|eot_id|>'
        '<|start_header_id|>assistant<|end_header_id|>\n\n',
      );
    });

    test('multi-turn conversation', () {
      expect(
        t.render([_user('Hi'), _assistant('Hello!'), _user('How are you?')]),
        '<|begin_of_text|>'
        '<|start_header_id|>user<|end_header_id|>\n\nHi<|eot_id|>'
        '<|start_header_id|>assistant<|end_header_id|>\n\nHello!<|eot_id|>'
        '<|start_header_id|>user<|end_header_id|>\n\nHow are you?<|eot_id|>'
        '<|start_header_id|>assistant<|end_header_id|>\n\n',
      );
    });

    test('always ends with assistant header (no eot_id)', () {
      final result = t.render([_user('Hi')]);
      expect(result, endsWith('<|start_header_id|>assistant<|end_header_id|>\n\n'));
    });
  });

  // ── ChatMlChatTemplate ─────────────────────────────────────────────────────
  group('ChatMlChatTemplate', () {
    const t = ChatMlChatTemplate();

    test('single user turn, no system', () {
      expect(
        t.render([_user('Hello')]),
        '<|im_start|>user\nHello<|im_end|>\n<|im_start|>assistant\n',
      );
    });

    test('single user turn with system prompt', () {
      expect(
        t.render([_user('Hello')], systemPrompt: 'Be helpful'),
        '<|im_start|>system\nBe helpful<|im_end|>\n'
        '<|im_start|>user\nHello<|im_end|>\n'
        '<|im_start|>assistant\n',
      );
    });

    test('multi-turn conversation', () {
      expect(
        t.render([_user('Hi'), _assistant('Hello!'), _user('How are you?')]),
        '<|im_start|>user\nHi<|im_end|>\n'
        '<|im_start|>assistant\nHello!<|im_end|>\n'
        '<|im_start|>user\nHow are you?<|im_end|>\n'
        '<|im_start|>assistant\n',
      );
    });

    test('always ends with open assistant block', () {
      expect(t.render([_user('x')]), endsWith('<|im_start|>assistant\n'));
    });
  });

  // ── FallbackChatTemplate ───────────────────────────────────────────────────
  group('FallbackChatTemplate', () {
    const t = FallbackChatTemplate();

    test('single user turn, no system', () {
      expect(t.render([_user('Hello')]), 'User: Hello\nAssistant: ');
    });

    test('single user turn with system prompt', () {
      expect(
        t.render([_user('Hello')], systemPrompt: 'Be helpful'),
        'System: Be helpful\n\nUser: Hello\nAssistant: ',
      );
    });

    test('multi-turn conversation', () {
      expect(
        t.render([_user('Hi'), _assistant('Hey'), _user('Bye')]),
        'User: Hi\nAssistant: Hey\nUser: Bye\nAssistant: ',
      );
    });
  });

  // ── ChatTemplateResolver ───────────────────────────────────────────────────
  group('ChatTemplateResolver', () {
    ModelProfile _profile(ChatTemplateHint hint) => ModelProfile(
          id: 'test/model',
          displayName: 'Test',
          format: ModelFormat.gguf,
          chatTemplateHint: hint,
        );

    test('gemma hint → GemmaChatTemplate', () {
      expect(
        ChatTemplateResolver.resolve(_profile(ChatTemplateHint.gemma)),
        isA<GemmaChatTemplate>(),
      );
    });

    test('llama3 hint → Llama3ChatTemplate', () {
      expect(
        ChatTemplateResolver.resolve(_profile(ChatTemplateHint.llama3)),
        isA<Llama3ChatTemplate>(),
      );
    });

    test('qwen2 hint → ChatMlChatTemplate', () {
      expect(
        ChatTemplateResolver.resolve(_profile(ChatTemplateHint.qwen2)),
        isA<ChatMlChatTemplate>(),
      );
    });

    test('qwen3 hint → ChatMlChatTemplate', () {
      expect(
        ChatTemplateResolver.resolve(_profile(ChatTemplateHint.qwen3)),
        isA<ChatMlChatTemplate>(),
      );
    });

    test('unknown hint → FallbackChatTemplate', () {
      expect(
        ChatTemplateResolver.resolve(_profile(ChatTemplateHint.unknown)),
        isA<FallbackChatTemplate>(),
      );
    });

    test('override takes precedence over hint', () {
      const override = ChatMlChatTemplate();
      final result = ChatTemplateResolver.resolve(
        _profile(ChatTemplateHint.gemma),
        override,
      );
      expect(result, same(override));
    });
  });

  // ── Smoking Gun ────────────────────────────────────────────────────────────
  // ChatViewModel._buildPromptFromHistory() (lines 203-229) uses:
  //   <|system|>...<|user|>...<|assistant|>
  // This is incorrect for all three model families in RecommendedModels.profiles.
  // task-604 will migrate ChatViewModel to use ChatTemplateResolver.
  group('Smoking Gun — old tokens vs correct format', () {
    test('Llama3 does not use <|user|> / <|assistant|> tokens', () {
      const t = Llama3ChatTemplate();
      final result = t.render([_user('Hello')]);
      expect(result, isNot(contains('<|user|>')));
      expect(result, isNot(contains('<|assistant|>')));
      expect(result, contains('<|start_header_id|>user<|end_header_id|>'));
    });

    test('Gemma does not use <|user|> / <|assistant|> tokens', () {
      const t = GemmaChatTemplate();
      final result = t.render([_user('Hello')]);
      expect(result, isNot(contains('<|user|>')));
      expect(result, contains('<start_of_turn>'));
    });

    test('Qwen2 does not use <|user|> / <|assistant|> tokens', () {
      const t = ChatMlChatTemplate();
      final result = t.render([_user('Hello')]);
      expect(result, isNot(contains('<|user|>')));
      expect(result, contains('<|im_start|>'));
    });
  });
}
