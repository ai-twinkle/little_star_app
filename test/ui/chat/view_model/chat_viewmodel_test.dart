import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/inference/backend_selector.dart';
import 'package:little_star_app/core/inference/inference_backend.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/ui/chat/view_model/chat_viewmodel.dart';

// ── Fake sessions ─────────────────────────────────────────────────────────────

class _FakeSession implements InferenceSession {
  final List<String> tokens;
  _FakeSession([this.tokens = const []]);

  @override
  Stream<String> generate(List<ChatMessage> _) async* {
    for (final t in tokens) {
      yield t;
    }
  }

  @override
  void cancel() {}

  @override
  void dispose() {}
}

class _ControllableSession implements InferenceSession {
  final _ctrl = StreamController<String>();
  bool disposed = false;

  void emit(String t) => _ctrl.add(t);
  void complete() => _ctrl.close();

  @override
  Stream<String> generate(List<ChatMessage> _) => _ctrl.stream;

  @override
  void cancel() {
    if (!_ctrl.isClosed) _ctrl.close();
  }

  @override
  void dispose() {
    disposed = true;
    if (!_ctrl.isClosed) _ctrl.close();
  }
}

class _ErrorSession implements InferenceSession {
  @override
  Stream<String> generate(List<ChatMessage> _) async* {
    throw StateError('mock error');
  }

  @override
  void cancel() {}

  @override
  void dispose() {}
}

// ── Helpers ───────────────────────────────────────────────────────────────────

ChatViewModel _vm(InferenceSession session) => ChatViewModel(
      modelPath: '/fake/model.gguf',
      sessionFactory: (_, __) => session,
    );

Future<void> _waitIdle(ChatViewModel vm) {
  final c = Completer<void>();
  void check() {
    if (!vm.isGenerating) {
      c.complete();
      vm.removeListener(check);
    }
  }

  vm.addListener(check);
  if (!vm.isGenerating) c.complete();
  return c.future;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('ChatViewModel — sendMessage', () {
    test('sendMessage adds user message immediately', () async {
      final vm = _vm(_FakeSession());
      addTearDown(vm.dispose);

      await vm.sendMessage('Hello');
      expect(vm.messages.first.content, 'Hello');
      expect(vm.messages.first.isUser, isTrue);
    });

    test('assistant reply is appended after generation', () async {
      final vm = _vm(_FakeSession(['Hi', ' there']));
      addTearDown(vm.dispose);

      await vm.sendMessage('Hello');
      await _waitIdle(vm);

      expect(vm.messages.length, 2);
      expect(vm.messages.last.content, 'Hi there');
      expect(vm.messages.last.isUser, isFalse);
    });

    test('streamingMessageNotifier updated token by token', () async {
      final vm = _vm(_FakeSession(['a', 'b', 'c']));
      addTearDown(vm.dispose);

      final received = <String>[];
      vm.streamingMessageNotifier.addListener(() {
        received.add(vm.streamingMessageNotifier.value);
      });

      await vm.sendMessage('hi');
      await _waitIdle(vm);

      expect(received, contains('a'));
      expect(received, contains('ab'));
      expect(received, contains('abc'));
    });

    test('streamingMessageNotifier cleared after done', () async {
      final vm = _vm(_FakeSession(['tok']));
      addTearDown(vm.dispose);

      await vm.sendMessage('hi');
      await _waitIdle(vm);

      expect(vm.streamingMessageNotifier.value, isEmpty);
    });

    test('isGenerating is false after completion', () async {
      final vm = _vm(_FakeSession(['tok']));
      addTearDown(vm.dispose);

      await vm.sendMessage('hi');
      await _waitIdle(vm);

      expect(vm.isGenerating, isFalse);
    });

    test('getMessageMetrics returns metrics for assistant reply', () async {
      final vm = _vm(_FakeSession(['a', 'b']));
      addTearDown(vm.dispose);

      await vm.sendMessage('hi');
      await _waitIdle(vm);

      final metrics = vm.getMessageMetrics(1); // index 1 = assistant reply
      expect(metrics, isNotNull);
      expect(metrics!.tokenCount, 2);
      expect(metrics.stopReason, 'completed');
    });

    test('ignored when isGenerating is true', () async {
      final session = _ControllableSession();
      final vm = _vm(session);
      addTearDown(vm.dispose);

      await vm.sendMessage('first');
      await vm.sendMessage('second'); // should be ignored

      session.complete();
      await _waitIdle(vm);

      expect(vm.messages.where((m) => m.isUser), hasLength(1));
    });
  });

  group('ChatViewModel — stopGeneration', () {
    test('stopGeneration appends partial reply with [Generation stopped]', () async {
      final session = _ControllableSession();
      final vm = _vm(session);
      addTearDown(vm.dispose);

      await vm.sendMessage('hi');
      session.emit('partial');
      await Future.delayed(Duration.zero);

      await vm.stopGeneration();

      final last = vm.messages.last;
      expect(last.isUser, isFalse);
      expect(last.content, contains('[Generation stopped]'));
    });

    test('isGenerating is false after stopGeneration', () async {
      final session = _ControllableSession();
      final vm = _vm(session);
      addTearDown(vm.dispose);

      await vm.sendMessage('hi');
      await vm.stopGeneration();

      expect(vm.isGenerating, isFalse);
    });

    test('stopGeneration is no-op when not generating', () async {
      final vm = _vm(_FakeSession());
      addTearDown(vm.dispose);

      expect(() => vm.stopGeneration(), returnsNormally);
    });
  });

  group('ChatViewModel — error', () {
    test('immediate error with no partial content does not add assistant message', () async {
      final vm = _vm(_ErrorSession());
      addTearDown(vm.dispose);

      await vm.sendMessage('hi');
      await _waitIdle(vm);

      // Only the user message; no error reply when there was no partial output
      expect(vm.messages.length, 1);
      expect(vm.messages.last.isUser, isTrue);
    });

    test('isGenerating false after error', () async {
      final vm = _vm(_ErrorSession());
      addTearDown(vm.dispose);

      await vm.sendMessage('hi');
      await _waitIdle(vm);

      expect(vm.isGenerating, isFalse);
    });
  });

  group('ChatViewModel — clearChat', () {
    test('clearChat removes all messages', () async {
      final vm = _vm(_FakeSession(['tok']));
      addTearDown(vm.dispose);

      await vm.sendMessage('hi');
      await _waitIdle(vm);

      vm.clearChat();
      expect(vm.messages, isEmpty);
    });

    test('clearChat clears streamingMessageNotifier', () async {
      final vm = _vm(_FakeSession());
      addTearDown(vm.dispose);

      vm.clearChat();
      expect(vm.streamingMessageNotifier.value, isEmpty);
    });
  });

  group('ChatViewModel — settings', () {
    test('default systemPrompt is set', () {
      final vm = _vm(_FakeSession());
      addTearDown(vm.dispose);
      expect(vm.systemPrompt, 'You are a helpful AI assistant.');
    });

    test('default stopSequences is empty (Smoking Gun fix)', () {
      final vm = _vm(_FakeSession());
      addTearDown(vm.dispose);
      expect(vm.stopSequences, isEmpty);
    });

    test('updateSettings updates temperature', () {
      final vm = _vm(_FakeSession());
      addTearDown(vm.dispose);

      vm.updateSettings(temperature: 0.3);
      expect(vm.temperature, closeTo(0.3, 0.001));
    });

    test('resetSettings restores defaults', () {
      final vm = _vm(_FakeSession());
      addTearDown(vm.dispose);

      vm.updateSettings(maxTokens: 100, temperature: 0.1);
      vm.resetSettings();

      expect(vm.maxTokens, 512);
      expect(vm.temperature, closeTo(0.8, 0.001));
      expect(vm.systemPrompt, 'You are a helpful AI assistant.');
    });
  });

  group('ChatViewModel — selectModel', () {
    test('selectModel updates selectedModelName', () async {
      final vm = _vm(_FakeSession());
      addTearDown(vm.dispose);

      await vm.selectModel('/new/path/model.gguf');
      expect(vm.selectedModelName, 'model.gguf');
    });

    test('old session disposed on selectModel', () async {
      final first = _ControllableSession();
      bool useFirst = true;
      final vm = ChatViewModel(
        modelPath: '/fake/a.gguf',
        sessionFactory: (_, __) => useFirst ? first : _FakeSession(),
      );
      addTearDown(vm.dispose);

      useFirst = false;
      await vm.selectModel('/fake/b.gguf');
      expect(first.disposed, isTrue);
    });
  });

  group('ChatViewModel — backend/format wiring', () {
    test('.gguf path builds a gguf ModelProfile', () {
      ModelProfile? captured;
      final vm = ChatViewModel(
        modelPath: '/fake/model.gguf',
        sessionFactory: (profile, __) {
          captured = profile;
          return _FakeSession();
        },
      );
      addTearDown(vm.dispose);

      expect(captured?.format, ModelFormat.gguf);
    });

    test('extensionless (MLX snapshot directory) path builds an mlx ModelProfile', () {
      ModelProfile? captured;
      final vm = ChatViewModel(
        modelPath: '/fake/Models/mlx/some-repo',
        sessionFactory: (profile, __) {
          captured = profile;
          return _FakeSession();
        },
      );
      addTearDown(vm.dispose);

      expect(captured?.format, ModelFormat.mlx);
    });

    test('mlx profile is routed through the injected BackendSelector', () {
      final fakeBackend = _FakeMlxBackend();
      final vm = ChatViewModel(
        modelPath: '/fake/Models/mlx/some-repo',
        backendSelector: BackendSelector(mlxBackendFactory: () => fakeBackend),
      );
      addTearDown(vm.dispose);

      expect(fakeBackend.createSessionCallCount, 1);
    });

    test('empty modelPath does not eagerly open a session (regression)', () {
      // Constructing with no model selected must not throw even though a
      // real BackendSelector (with no fake session/backend injected) is used
      // — this is exactly the path chat_screen.dart takes when opened
      // without an initialModelPath.
      expect(
        () => ChatViewModel(modelPath: ''),
        returnsNormally,
      );
    });

    test('sendMessage does not crash and never starts generating when no '
        'model was ever selected', () async {
      final vm = ChatViewModel(modelPath: '');
      addTearDown(vm.dispose);

      await vm.sendMessage('hello');

      expect(vm.isGenerating, isFalse);
    });
  });
}

class _FakeMlxBackend implements InferenceBackend {
  int createSessionCallCount = 0;

  @override
  bool canHandle(ModelProfile profile) => profile.format == ModelFormat.mlx;

  @override
  InferenceSession createSession(ModelProfile profile, InferenceSettings settings) {
    createSessionCallCount++;
    return _FakeSession();
  }
}
