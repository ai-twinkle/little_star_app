import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/engine/mlx/mlx_channel.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/inference/mlx_backend.dart';
import 'package:little_star_app/core/inference/sampling_params.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/models/chat_message.dart';

// ─── Fake driver ─────────────────────────────────────────────────────────────

class _FakeDriver implements MlxChannelDriver {
  final List<String> tokens;

  bool loadModelCalled = false;
  String? loadedPath;
  bool cancelCalled = false;
  bool disposeCalled = false;
  List<MlxChatMessage>? lastMessages;
  MlxGenerationParams? lastParams;

  _FakeDriver({this.tokens = const ['tok1', ' tok2', ' tok3']});

  @override
  Future<void> loadModel(String localPath) async {
    loadModelCalled = true;
    loadedPath = localPath;
  }

  @override
  Stream<MlxTokenEvent> generate(
    List<MlxChatMessage> messages, {
    MlxGenerationParams? params,
  }) async* {
    lastMessages = messages;
    lastParams = params;
    for (final t in tokens) {
      yield MlxTokenEvent(token: t, isDone: false);
    }
    yield MlxTokenEvent(token: '', isDone: true, tokensPerSecond: 42.0);
  }

  @override
  Future<void> cancel() async => cancelCalled = true;

  @override
  Future<void> dispose() async => disposeCalled = true;
}

// Fake driver whose generate() takes a long time — used for cancel tests.
class _SlowFakeDriver extends _FakeDriver {
  _SlowFakeDriver() : super(tokens: ['a', 'b', 'c', 'd', 'e']);

  @override
  Stream<MlxTokenEvent> generate(
    List<MlxChatMessage> messages, {
    MlxGenerationParams? params,
  }) async* {
    lastMessages = messages;
    lastParams = params;
    for (final t in tokens) {
      await Future.delayed(const Duration(milliseconds: 5));
      yield MlxTokenEvent(token: t, isDone: false);
    }
    yield MlxTokenEvent(token: '', isDone: true);
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

const _mlxProfile = ModelProfile(
  id: 'model-mlx',
  displayName: 'Test MLX',
  format: ModelFormat.mlx,
  localPath: '/tmp/t1-mlx-4bit',
);

const _ggufProfile = ModelProfile(
  id: 'model-gguf',
  displayName: 'Test GGUF',
  format: ModelFormat.gguf,
  localPath: '/tmp/model.gguf',
);

final _userMsg = ChatMessage(content: 'Hello!', isUser: true);

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // --- MlxBackend.canHandle --------------------------------------------------
  group('MlxBackend.canHandle', () {
    final backend = MlxBackend();

    test('returns true for mlx', () {
      expect(backend.canHandle(_mlxProfile), isTrue);
    });

    test('returns false for gguf', () {
      expect(backend.canHandle(_ggufProfile), isFalse);
    });

    test('createSession throws UnsupportedError for gguf', () {
      expect(
        () => backend.createSession(_ggufProfile, const InferenceSettings()),
        throwsUnsupportedError,
      );
    });

    test('createSession throws ArgumentError when localPath is null', () {
      const noPath = ModelProfile(
        id: 'x',
        displayName: 'x',
        format: ModelFormat.mlx,
        // localPath intentionally omitted
      );
      expect(
        () => backend.createSession(noPath, const InferenceSettings()),
        throwsArgumentError,
      );
    });
  });

  // --- MlxSession: generate ---------------------------------------------------
  group('MlxSession generate', () {
    test('streams all tokens from driver, excluding the done sentinel', () async {
      final driver = _FakeDriver();
      final session = MlxSession(driver, const InferenceSettings(), '/tmp/model');

      final tokens = await session.generate([_userMsg]).toList();
      expect(tokens, ['tok1', ' tok2', ' tok3']);
      session.dispose();
    });

    test('loads the model from localPath on first generate', () async {
      final driver = _FakeDriver();
      final session = MlxSession(driver, const InferenceSettings(), '/tmp/t1-mlx-4bit');

      await session.generate([_userMsg]).drain<void>();
      expect(driver.loadModelCalled, isTrue);
      expect(driver.loadedPath, '/tmp/t1-mlx-4bit');
      session.dispose();
    });

    test('does not reload the model on a second generate call', () async {
      final driver = _FakeDriver();
      final session = MlxSession(driver, const InferenceSettings(), '/tmp/model');

      await session.generate([_userMsg]).drain<void>();
      driver.loadModelCalled = false;
      await session.generate([_userMsg]).drain<void>();
      expect(driver.loadModelCalled, isFalse);
      session.dispose();
    });

    test('passes SamplingParams to MlxGenerationParams', () async {
      final driver = _FakeDriver();
      final settings = const InferenceSettings(
        samplingParams: SamplingParams(topP: 0.7, temperature: 0.3, seed: 7),
        maxTokens: 256,
      );
      final session = MlxSession(driver, settings, '/tmp/model');

      await session.generate([_userMsg]).drain<void>();
      expect(driver.lastParams!.topP, 0.7);
      expect(driver.lastParams!.temperature, closeTo(0.3, 1e-6));
      expect(driver.lastParams!.maxTokens, 256);
      expect(driver.lastParams!.seed, 7);
      session.dispose();
    });

    test('seed of -1 (random) maps to null', () async {
      final driver = _FakeDriver();
      final settings = const InferenceSettings(
        samplingParams: SamplingParams(seed: -1),
      );
      final session = MlxSession(driver, settings, '/tmp/model');

      await session.generate([_userMsg]).drain<void>();
      expect(driver.lastParams!.seed, isNull);
      session.dispose();
    });

    test('system prompt is sent as its own system-role message', () async {
      final driver = _FakeDriver();
      final settings = const InferenceSettings(systemPrompt: 'You are helpful.');
      final session = MlxSession(driver, settings, '/tmp/model');

      await session.generate([_userMsg]).drain<void>();

      final messages = driver.lastMessages!;
      expect(messages.first.role, 'system');
      expect(messages.first.content, 'You are helpful.');
      session.dispose();
    });

    test('no system message when systemPrompt is null', () async {
      final driver = _FakeDriver();
      final session = MlxSession(driver, const InferenceSettings(), '/tmp/model');

      await session.generate([_userMsg]).drain<void>();

      final messages = driver.lastMessages!;
      expect(messages.any((m) => m.role == 'system'), isFalse);
      session.dispose();
    });

    test('maps user and assistant roles correctly', () async {
      final driver = _FakeDriver();
      final session = MlxSession(driver, const InferenceSettings(), '/tmp/model');

      await session.generate([
        ChatMessage(content: 'hi', isUser: true),
        ChatMessage(content: 'hello', isUser: false),
      ]).drain<void>();

      final messages = driver.lastMessages!;
      expect(messages[0].role, 'user');
      expect(messages[1].role, 'assistant');
      session.dispose();
    });
  });

  // --- MlxSession: turn-marker guard -------------------------------------------
  group('MlxSession turn-marker guard', () {
    test('truncates output at a fabricated <start_of_turn>user marker', () async {
      final driver = _FakeDriver(tokens: [
        'Sure, here', ' is the answer.',
        '<start_of_turn>user', 'What about tomorrow?',
      ]);
      final session = MlxSession(driver, const InferenceSettings(), '/tmp/model');

      final tokens = await session.generate([_userMsg]).toList();
      expect(tokens.join(), 'Sure, here is the answer.');
      session.dispose();
    });

    test('truncates output at a fabricated <|assistant|> marker', () async {
      final driver = _FakeDriver(tokens: [
        'The answer is 42.', '<|assistant|>', 'Fabricated follow-up',
      ]);
      final session = MlxSession(driver, const InferenceSettings(), '/tmp/model');

      final tokens = await session.generate([_userMsg]).toList();
      expect(tokens.join(), 'The answer is 42.');
      session.dispose();
    });

    test('detects a marker split across multiple token chunks', () async {
      final driver = _FakeDriver(tokens: [
        'Answer text', '<start_of', '_turn>user', 'garbage',
      ]);
      final session = MlxSession(driver, const InferenceSettings(), '/tmp/model');

      final tokens = await session.generate([_userMsg]).toList();
      expect(tokens.join(), 'Answer text');
      session.dispose();
    });

    test('does not truncate or drop normal output with no marker', () async {
      final driver = _FakeDriver(tokens: ['tok1', ' tok2', ' tok3']);
      final session = MlxSession(driver, const InferenceSettings(), '/tmp/model');

      final tokens = await session.generate([_userMsg]).toList();
      expect(tokens.join(), 'tok1 tok2 tok3');
      session.dispose();
    });
  });

  // --- MlxSession: cancel ------------------------------------------------------
  group('MlxSession cancel', () {
    test('stops generation early', () async {
      final driver = _SlowFakeDriver();
      final session = MlxSession(driver, const InferenceSettings(), '/tmp/model');

      final received = <String>[];
      final stream = session.generate([_userMsg]);

      await for (final token in stream) {
        received.add(token);
        if (received.length == 2) session.cancel();
      }

      expect(received.length, lessThan(driver.tokens.length));
      expect(driver.cancelCalled, isTrue);
      session.dispose();
    });

    test('second generate after cancel runs normally', () async {
      final driver = _FakeDriver();
      final session = MlxSession(driver, const InferenceSettings(), '/tmp/model');

      session.cancel(); // cancel before any generation
      final tokens = await session.generate([_userMsg]).toList();
      expect(tokens, ['tok1', ' tok2', ' tok3']);
      session.dispose();
    });
  });

  // --- MlxSession: dispose ------------------------------------------------------
  group('MlxSession dispose', () {
    test('calls driver.dispose', () {
      final driver = _FakeDriver();
      final session = MlxSession(driver, const InferenceSettings(), '/tmp/model');

      session.dispose();
      expect(driver.disposeCalled, isTrue);
    });

    test('double dispose is safe', () {
      final driver = _FakeDriver();
      final session = MlxSession(driver, const InferenceSettings(), '/tmp/model');

      session.dispose();
      expect(() => session.dispose(), returnsNormally);
    });

    test('generate after dispose throws StateError', () {
      final driver = _FakeDriver();
      final session = MlxSession(driver, const InferenceSettings(), '/tmp/model');

      session.dispose();
      expect(
        () => session.generate([_userMsg]),
        throwsA(isA<StateError>()),
      );
    });
  });
}
