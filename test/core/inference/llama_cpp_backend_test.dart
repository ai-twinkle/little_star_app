import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/inference/llama_cpp_backend.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/inference/sampling_params.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/models/chat_message.dart';

// ─── Fake driver ─────────────────────────────────────────────────────────────

class _FakeDriver implements LlamaFfiDriver {
  final List<String> tokens;

  bool createContextCalled = false;
  bool createSamplerCalled = false;
  bool freeContextCalled = false;
  bool freeModelCalled = false;
  bool useGreedyCaptured = false;
  int topKCaptured = 0;
  double topPCaptured = 0;
  double tempCaptured = 0;
  List<Map<String, dynamic>>? lastMessageMaps;

  _FakeDriver({this.tokens = const ['tok1', ' tok2', ' tok3']});

  @override
  String applyChatTemplate(List<Map<String, dynamic>> messageMaps) {
    lastMessageMaps = messageMaps;
    return messageMaps.map((m) => '${m['role']}: ${m['content']}').join('\n');
  }

  @override
  bool createContext({
    required int nCtx,
    required int nBatch,
    required int nThreads,
    required int nThreadsBatch,
  }) {
    createContextCalled = true;
    return true;
  }

  @override
  bool createSampler({
    required bool useGreedy,
    required int topK,
    required double topP,
    required double temp,
  }) {
    createSamplerCalled = true;
    useGreedyCaptured = useGreedy;
    topKCaptured = topK;
    topPCaptured = topP;
    tempCaptured = temp;
    return true;
  }

  @override
  int tokenizePrompt(String prompt) => prompt.split(' ').length;

  @override
  Stream<String> generateStream(int nPrompt, {required int maxTokens}) async* {
    for (final t in tokens) {
      yield t;
    }
  }

  @override
  void freeContext() => freeContextCalled = true;

  @override
  void freeModel() => freeModelCalled = true;
}

// Fake driver whose generateStream takes a long time — used for cancel tests
class _SlowFakeDriver extends _FakeDriver {
  _SlowFakeDriver() : super(tokens: ['a', 'b', 'c', 'd', 'e']);

  @override
  Stream<String> generateStream(int nPrompt, {required int maxTokens}) async* {
    for (final t in tokens) {
      await Future.delayed(const Duration(milliseconds: 5));
      yield t;
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

const _ggufProfile = ModelProfile(
  id: 'model-gguf',
  displayName: 'Test GGUF',
  format: ModelFormat.gguf,
  localPath: '/tmp/model.gguf',
);

const _mlxProfile = ModelProfile(
  id: 'model-mlx',
  displayName: 'Test MLX',
  format: ModelFormat.mlx,
);

final _userMsg = ChatMessage(content: 'Hello!', isUser: true);

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // --- LlamaCppBackend.canHandle -------------------------------------------
  group('LlamaCppBackend.canHandle', () {
    final backend = LlamaCppBackend();

    test('returns true for gguf', () {
      expect(backend.canHandle(_ggufProfile), isTrue);
    });

    test('returns false for mlx', () {
      expect(backend.canHandle(_mlxProfile), isFalse);
    });

    test('createSession throws UnsupportedError for mlx', () {
      expect(
        () => backend.createSession(_mlxProfile, const InferenceSettings()),
        throwsUnsupportedError,
      );
    });

    test('createSession throws ArgumentError when localPath is null', () {
      const noPath = ModelProfile(
        id: 'x',
        displayName: 'x',
        format: ModelFormat.gguf,
        // localPath intentionally omitted
      );
      expect(
        () => backend.createSession(noPath, const InferenceSettings()),
        throwsArgumentError,
      );
    });
  });

  // --- kLlamaCppVersion constant -------------------------------------------
  test('kLlamaCppVersion is b7493', () {
    expect(kLlamaCppVersion, 'b7493');
    expect(LlamaCppBackend.version, 'b7493');
  });

  // --- LlamaCppSession: generate -------------------------------------------
  group('LlamaCppSession generate', () {
    test('streams all tokens from driver', () async {
      final driver = _FakeDriver();
      final session = LlamaCppSession(driver, const InferenceSettings());

      final tokens = await session.generate([_userMsg]).toList();
      expect(tokens, ['tok1', ' tok2', ' tok3']);
      session.dispose();
    });

    test('createContext and createSampler are called', () async {
      final driver = _FakeDriver();
      final session = LlamaCppSession(driver, const InferenceSettings());

      await session.generate([_userMsg]).drain<void>();
      expect(driver.createContextCalled, isTrue);
      expect(driver.createSamplerCalled, isTrue);
      session.dispose();
    });

    test('passes SamplingParams to createSampler', () async {
      final driver = _FakeDriver();
      final settings = const InferenceSettings(
        samplingParams: SamplingParams(topK: 20, topP: 0.7, temperature: 0.3),
      );
      final session = LlamaCppSession(driver, settings);

      await session.generate([_userMsg]).drain<void>();
      expect(driver.topKCaptured, 20);
      expect(driver.topPCaptured, 0.7);
      expect(driver.tempCaptured, closeTo(0.3, 1e-6));
      session.dispose();
    });

    test('system prompt is prepended to message maps', () async {
      final driver = _FakeDriver();
      final settings = const InferenceSettings(systemPrompt: 'You are helpful.');
      final session = LlamaCppSession(driver, settings);

      await session.generate([_userMsg]).drain<void>();

      final maps = driver.lastMessageMaps!;
      expect(maps.first['role'], 'system');
      expect(maps.first['content'], 'You are helpful.');
      session.dispose();
    });

    test('no system prompt entry when systemPrompt is null', () async {
      final driver = _FakeDriver();
      final session = LlamaCppSession(driver, const InferenceSettings());

      await session.generate([_userMsg]).drain<void>();

      final maps = driver.lastMessageMaps!;
      expect(maps.any((m) => m['role'] == 'system'), isFalse);
      session.dispose();
    });

    test('maps user message role correctly', () async {
      final driver = _FakeDriver();
      final session = LlamaCppSession(driver, const InferenceSettings());

      await session
          .generate([ChatMessage(content: 'hi', isUser: true)]).drain<void>();
      expect(driver.lastMessageMaps!.last['role'], 'user');
      session.dispose();
    });

    test('maps assistant message role correctly', () async {
      final driver = _FakeDriver();
      final session = LlamaCppSession(driver, const InferenceSettings());

      await session
          .generate([ChatMessage(content: 'hi', isUser: false)]).drain<void>();
      expect(driver.lastMessageMaps!.last['role'], 'assistant');
      session.dispose();
    });
  });

  // --- LlamaCppSession: turn-marker guard -----------------------------------
  group('LlamaCppSession turn-marker guard', () {
    test('truncates output at a fabricated <start_of_turn>user marker', () async {
      final driver = _FakeDriver(tokens: [
        'Sure, here', ' is the answer.',
        '<start_of_turn>user', 'What about tomorrow?',
      ]);
      final session = LlamaCppSession(driver, const InferenceSettings());

      final tokens = await session.generate([_userMsg]).toList();
      expect(tokens.join(), 'Sure, here is the answer.');
      session.dispose();
    });

    test('truncates output at a fabricated <|assistant|> marker', () async {
      final driver = _FakeDriver(tokens: [
        'The answer is 42.', '<|assistant|>', 'Fabricated follow-up',
      ]);
      final session = LlamaCppSession(driver, const InferenceSettings());

      final tokens = await session.generate([_userMsg]).toList();
      expect(tokens.join(), 'The answer is 42.');
      session.dispose();
    });

    test('detects a marker split across multiple token chunks', () async {
      final driver = _FakeDriver(tokens: [
        'Answer text', '<start_of', '_turn>user', 'garbage',
      ]);
      final session = LlamaCppSession(driver, const InferenceSettings());

      final tokens = await session.generate([_userMsg]).toList();
      expect(tokens.join(), 'Answer text');
      session.dispose();
    });

    test('does not truncate or drop normal output with no marker', () async {
      final driver = _FakeDriver(tokens: ['tok1', ' tok2', ' tok3']);
      final session = LlamaCppSession(driver, const InferenceSettings());

      final tokens = await session.generate([_userMsg]).toList();
      expect(tokens.join(), 'tok1 tok2 tok3');
      session.dispose();
    });
  });

  // --- LlamaCppSession: cancel ---------------------------------------------
  group('LlamaCppSession cancel', () {
    test('stops generation early', () async {
      final driver = _SlowFakeDriver();
      final session = LlamaCppSession(driver, const InferenceSettings());

      final received = <String>[];
      final stream = session.generate([_userMsg]);

      await for (final token in stream) {
        received.add(token);
        if (received.length == 2) session.cancel();
      }

      expect(received.length, lessThan(driver.tokens.length));
      session.dispose();
    });

    test('second generate after cancel runs normally', () async {
      final driver = _FakeDriver();
      final session = LlamaCppSession(driver, const InferenceSettings());

      session.cancel(); // cancel before any generation
      final tokens = await session.generate([_userMsg]).toList();
      expect(tokens, ['tok1', ' tok2', ' tok3']);
      session.dispose();
    });
  });

  // --- LlamaCppSession: dispose --------------------------------------------
  group('LlamaCppSession dispose', () {
    test('calls freeContext and freeModel', () {
      final driver = _FakeDriver();
      final session = LlamaCppSession(driver, const InferenceSettings());

      session.dispose();
      expect(driver.freeContextCalled, isTrue);
      expect(driver.freeModelCalled, isTrue);
    });

    test('double dispose is safe', () {
      final driver = _FakeDriver();
      final session = LlamaCppSession(driver, const InferenceSettings());

      session.dispose();
      expect(() => session.dispose(), returnsNormally);
    });

    test('generate after dispose throws StateError', () {
      final driver = _FakeDriver();
      final session = LlamaCppSession(driver, const InferenceSettings());

      session.dispose();
      expect(
        () => session.generate([_userMsg]),
        throwsA(isA<StateError>()),
      );
    });
  });

  // --- selectModel no-leak pattern -----------------------------------------
  group('selectModel no-leak pattern', () {
    test('old session is disposed before creating new one', () {
      final driver1 = _FakeDriver();
      final session1 = LlamaCppSession(driver1, const InferenceSettings());

      // Caller disposes old session before creating new one
      session1.dispose();
      expect(driver1.freeContextCalled, isTrue);
      expect(driver1.freeModelCalled, isTrue);

      final driver2 = _FakeDriver();
      final session2 = LlamaCppSession(driver2, const InferenceSettings());
      session2.dispose();
      expect(driver2.freeContextCalled, isTrue);
    });
  });
}
