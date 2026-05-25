import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/ui/completion/view_model/completion_viewmodel.dart';

// ── Fake session ──────────────────────────────────────────────────────────────

class _FakeSession implements InferenceSession {
  final List<String> tokens;
  _FakeSession([this.tokens = const []]);

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

class _ErrorSession implements InferenceSession {
  @override
  Stream<String> generate(List<ChatMessage> messages) async* {
    throw StateError('mock error');
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

// ── Helpers ───────────────────────────────────────────────────────────────────

CompletionViewModel _vm(InferenceSession session) => CompletionViewModel(
      modelPath: '/fake/model.gguf',
      sessionFactory: (_, __) => session,
    );

/// Returns a Future that completes once [vm.isRunning] is false.
Future<void> _waitIdle(CompletionViewModel vm) {
  if (!vm.isRunning) return Future.value();
  final c = Completer<void>();
  late VoidCallback cb;
  cb = () {
    if (!vm.isRunning && !c.isCompleted) {
      c.complete();
      vm.removeListener(cb);
    }
  };
  vm.addListener(cb);
  return c.future;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('CompletionViewModel — normal completion', () {
    test('startCompletion appends tokens to outputTextNotifier', () async {
      final vm = _vm(_FakeSession(['Hello', ' world']));
      addTearDown(vm.dispose);

      await vm.startCompletion('hi');
      await _waitIdle(vm);

      expect(vm.outputTextNotifier.value, 'Hello world');
    });

    test('isRunning becomes false after completion', () async {
      final vm = _vm(_FakeSession(['tok']));
      addTearDown(vm.dispose);

      await vm.startCompletion('hi');
      await _waitIdle(vm);

      expect(vm.isRunning, isFalse);
    });

    test('metricsNotifier updated with tokenCount on done', () async {
      final vm = _vm(_FakeSession(['a', 'b', 'c']));
      addTearDown(vm.dispose);

      await vm.startCompletion('hi');
      await _waitIdle(vm);

      expect(vm.metricsNotifier.value.generatedTokenCount, 3);
      expect(vm.metricsNotifier.value.stopReason, 'completed');
    });

    test('reset clears output and metrics', () async {
      final vm = _vm(_FakeSession(['x']));
      addTearDown(vm.dispose);

      await vm.startCompletion('hi');
      await _waitIdle(vm);

      vm.reset();
      expect(vm.outputTextNotifier.value, isEmpty);
      expect(vm.metricsNotifier.value.generatedTokenCount, 0);
    });
  });

  group('CompletionViewModel — cancel', () {
    test('cancel sets stopReason to cancelled', () async {
      final session = _ControllableSession();
      final vm = _vm(session);
      addTearDown(vm.dispose);

      await vm.startCompletion('hi');
      session.emit('tok');
      await Future.delayed(Duration.zero);

      await vm.cancel();

      expect(vm.metricsNotifier.value.stopReason, 'cancelled');
      expect(vm.isRunning, isFalse);
    });
  });

  group('CompletionViewModel — error', () {
    test('error sets stopReason to error and isRunning to false', () async {
      final vm = _vm(_ErrorSession());
      addTearDown(vm.dispose);

      await vm.startCompletion('hi');
      await _waitIdle(vm);

      expect(vm.isRunning, isFalse);
      expect(vm.metricsNotifier.value.stopReason, 'error');
    });
  });

  group('CompletionViewModel — settings', () {
    test('default maxTokens is 256', () {
      final vm = _vm(_FakeSession());
      addTearDown(vm.dispose);
      expect(vm.maxTokens, 256);
    });

    test('updateSettings changes individual fields', () {
      final vm = _vm(_FakeSession());
      addTearDown(vm.dispose);

      vm.updateSettings(maxTokens: 512, temperature: 0.5, systemPrompt: 'Be concise');

      expect(vm.maxTokens, 512);
      expect(vm.temperature, 0.5);
      expect(vm.systemPrompt, 'Be concise');
    });

    test('updateSettings clamps maxTokens to valid range', () {
      final vm = _vm(_FakeSession());
      addTearDown(vm.dispose);

      vm.updateSettings(maxTokens: 5);
      expect(vm.maxTokens, 16);

      vm.updateSettings(maxTokens: 9999);
      expect(vm.maxTokens, 2048);
    });

    test('resetSettings restores defaults', () {
      final vm = _vm(_FakeSession());
      addTearDown(vm.dispose);

      vm.updateSettings(maxTokens: 1000, temperature: 0.1);
      vm.resetSettings();

      expect(vm.maxTokens, 256);
      expect(vm.temperature, isCloseTo(0.8, 0.001));
    });
  });

  group('CompletionViewModel — selectModel', () {
    test('selectModel updates selectedModelName', () async {
      int callCount = 0;
      final vm = CompletionViewModel(
        modelPath: '/fake/a.gguf',
        sessionFactory: (_, __) {
          callCount++;
          return _FakeSession();
        },
      );
      addTearDown(vm.dispose);

      await vm.selectModel('/fake/b.gguf');

      expect(vm.selectedModelName, 'b.gguf');
      expect(callCount, 2); // once on construction, once on selectModel
    });

    test('old session is disposed on selectModel', () async {
      final first = _ControllableSession();
      bool usedFirst = true;
      final vm = CompletionViewModel(
        modelPath: '/fake/a.gguf',
        sessionFactory: (_, __) => usedFirst ? first : _FakeSession(),
      );
      addTearDown(vm.dispose);

      usedFirst = false;
      await vm.selectModel('/fake/b.gguf');

      expect(first.disposed, isTrue);
    });
  });
}

// Custom matcher for approximate double equality.
Matcher isCloseTo(double expected, double delta) =>
    _CloseTo(expected, delta);

class _CloseTo extends Matcher {
  final double _expected;
  final double _delta;
  const _CloseTo(this._expected, this._delta);

  @override
  bool matches(dynamic item, _) =>
      item is num && (item - _expected).abs() <= _delta;

  @override
  Description describe(Description d) =>
      d.add('a value within $_delta of $_expected');
}
