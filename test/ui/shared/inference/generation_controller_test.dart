import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/ui/shared/inference/generation_controller.dart';

// ── Fake sessions ────────────────────────────────────────────────────────────

/// Emits [tokens] synchronously then completes.
class _FakeSession implements InferenceSession {
  final List<String> tokens;
  _FakeSession(this.tokens);

  @override
  Stream<String> generate(List<ChatMessage> messages) async* {
    for (final t in tokens) {
      yield t;
    }
  }

  @override
  void cancel() {}

  @override
  void dispose() {}
}

/// Throws [error] as soon as generate is called.
class _ErrorSession implements InferenceSession {
  final Object error;
  _ErrorSession(this.error);

  @override
  Stream<String> generate(List<ChatMessage> messages) async* {
    throw error;
  }

  @override
  void cancel() {}

  @override
  void dispose() {}
}

/// Exposes a [StreamController] so the test can emit tokens and trigger cancel.
class _ControllableSession implements InferenceSession {
  final _ctrl = StreamController<String>();
  bool cancelled = false;

  void emit(String token) => _ctrl.add(token);
  void complete() => _ctrl.close();

  @override
  Stream<String> generate(List<ChatMessage> messages) => _ctrl.stream;

  @override
  void cancel() {
    cancelled = true;
    if (!_ctrl.isClosed) _ctrl.close();
  }

  @override
  void dispose() {
    if (!_ctrl.isClosed) _ctrl.close();
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

ChatMessage _user(String content) =>
    ChatMessage(content: content, isUser: true, timestamp: DateTime(2024));

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('GenerationController — normal flow', () {
    test('emits GenerationToken for each chunk', () async {
      final session = _FakeSession(['Hello', ' world', '!']);
      final ctrl = GenerationController();

      final events = await ctrl.run(session, [_user('Hi')]).toList();

      expect(events, hasLength(4));
      expect(events[0], isA<GenerationToken>()
          .having((e) => e.token, 'token', 'Hello'));
      expect(events[1], isA<GenerationToken>()
          .having((e) => e.token, 'token', ' world'));
      expect(events[2], isA<GenerationToken>()
          .having((e) => e.token, 'token', '!'));
      expect(events[3], isA<GenerationDone>());
    });

    test('GenerationDone has correct tokenCount', () async {
      final session = _FakeSession(['a', 'b', 'c']);
      final ctrl = GenerationController();

      final events = await ctrl.run(session, [_user('x')]).toList();
      final done = events.last as GenerationDone;

      expect(done.metrics.tokenCount, 3);
    });

    test('GenerationDone.stopReason is completed', () async {
      final session = _FakeSession(['a']);
      final ctrl = GenerationController();

      final events = await ctrl.run(session, [_user('x')]).toList();
      final done = events.last as GenerationDone;

      expect(done.metrics.stopReason, StopReason.completed);
    });

    test('ttft is non-null when tokens were emitted', () async {
      final session = _FakeSession(['tok']);
      final ctrl = GenerationController();

      final events = await ctrl.run(session, [_user('x')]).toList();
      final done = events.last as GenerationDone;

      expect(done.metrics.ttft, isNotNull);
    });

    test('ttft is null when no tokens emitted', () async {
      final session = _FakeSession([]);
      final ctrl = GenerationController();

      final events = await ctrl.run(session, [_user('x')]).toList();
      final done = events.last as GenerationDone;

      expect(done.metrics.ttft, isNull);
      expect(done.metrics.tokenCount, 0);
    });

    test('tokensPerSecond is null for zero-token run', () async {
      final session = _FakeSession([]);
      final ctrl = GenerationController();

      final events = await ctrl.run(session, [_user('x')]).toList();
      final done = events.last as GenerationDone;

      expect(done.metrics.tokensPerSecond, isNull);
    });

    test('isRunning is false before and after run', () async {
      final session = _FakeSession(['a']);
      final ctrl = GenerationController();

      expect(ctrl.isRunning, isFalse);
      await ctrl.run(session, [_user('x')]).toList();
      expect(ctrl.isRunning, isFalse);
    });
  });

  group('GenerationController — cancel', () {
    test('cancel stops generation with StopReason.cancelled', () async {
      final session = _ControllableSession();
      final ctrl = GenerationController();

      final events = <GenerationEvent>[];
      final completer = Completer<void>();

      ctrl
          .run(session, [_user('Hi')])
          .listen(events.add, onDone: completer.complete);

      // Emit one token then cancel
      session.emit('Hello');
      await Future.delayed(Duration.zero);

      ctrl.cancel();
      await completer.future;

      final tokens = events.whereType<GenerationToken>().toList();
      expect(tokens, hasLength(1));
      expect(tokens.first.token, 'Hello');

      final done = events.last as GenerationDone;
      expect(done.metrics.stopReason, StopReason.cancelled);
    });

    test('cancel calls session.cancel()', () async {
      final session = _ControllableSession();
      final ctrl = GenerationController();

      final completer = Completer<void>();
      ctrl
          .run(session, [_user('x')])
          .listen((_) {}, onDone: completer.complete);

      await Future.delayed(Duration.zero);
      ctrl.cancel();
      await completer.future;

      expect(session.cancelled, isTrue);
    });

    test('cancel is a no-op when not running', () {
      final ctrl = GenerationController();
      expect(() => ctrl.cancel(), returnsNormally);
    });

    test('cancel marks tokenCount of received tokens', () async {
      final session = _ControllableSession();
      final ctrl = GenerationController();

      final events = <GenerationEvent>[];
      final completer = Completer<void>();
      ctrl
          .run(session, [_user('x')])
          .listen(events.add, onDone: completer.complete);

      session.emit('a');
      session.emit('b');
      await Future.delayed(Duration.zero);

      ctrl.cancel();
      await completer.future;

      final done = events.last as GenerationDone;
      expect(done.metrics.tokenCount, 2);
    });
  });

  group('GenerationController — error', () {
    test('emits GenerationError when session throws', () async {
      final session = _ErrorSession(StateError('boom'));
      final ctrl = GenerationController();

      final events = await ctrl.run(session, [_user('x')]).toList();

      expect(events.last, isA<GenerationError>());
      expect((events.last as GenerationError).error, isA<StateError>());
    });

    test('no GenerationDone after GenerationError', () async {
      final session = _ErrorSession(Exception('fail'));
      final ctrl = GenerationController();

      final events = await ctrl.run(session, [_user('x')]).toList();

      expect(events.whereType<GenerationDone>(), isEmpty);
      expect(events.whereType<GenerationError>(), hasLength(1));
    });

    test('isRunning is false after error', () async {
      final session = _ErrorSession(Exception('fail'));
      final ctrl = GenerationController();

      await ctrl.run(session, [_user('x')]).toList();
      expect(ctrl.isRunning, isFalse);
    });
  });
}
