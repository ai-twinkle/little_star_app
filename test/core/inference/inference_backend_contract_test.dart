import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/inference/inference_backend.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/models/chat_message.dart';

// ---------------------------------------------------------------------------
// Minimal stub implementations to exercise the contract
// ---------------------------------------------------------------------------

class _FakeSession implements InferenceSession {
  final List<String> _tokens;
  StreamController<String>? _controller;
  bool disposed = false;
  bool cancelled = false;

  _FakeSession(this._tokens);

  @override
  Stream<String> generate(List<ChatMessage> messages) {
    _controller = StreamController<String>();
    for (final t in _tokens) {
      _controller!.add(t);
    }
    _controller!.close();
    return _controller!.stream;
  }

  @override
  void cancel() => cancelled = true;

  @override
  void dispose() => disposed = true;
}

class _GgufOnlyBackend implements InferenceBackend {
  @override
  bool canHandle(ModelProfile profile) => profile.format == ModelFormat.gguf;

  @override
  InferenceSession createSession(ModelProfile profile, InferenceSettings settings) {
    if (!canHandle(profile)) throw UnsupportedError('Backend does not support ${profile.format}');
    return _FakeSession(['Hello', ' world', '!']);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const ggufProfile = ModelProfile(
    id: 'test-gguf',
    displayName: 'Test GGUF',
    format: ModelFormat.gguf,
  );
  const mlxProfile = ModelProfile(
    id: 'test-mlx',
    displayName: 'Test MLX',
    format: ModelFormat.mlx,
  );

  group('InferenceBackend contract', () {
    late _GgufOnlyBackend backend;

    setUp(() => backend = _GgufOnlyBackend());

    test('canHandle returns true for supported format', () {
      expect(backend.canHandle(ggufProfile), isTrue);
    });

    test('canHandle returns false for unsupported format', () {
      expect(backend.canHandle(mlxProfile), isFalse);
    });

    test('createSession throws for unsupported profile', () {
      expect(
        () => backend.createSession(mlxProfile, const InferenceSettings()),
        throwsUnsupportedError,
      );
    });

    test('createSession returns a session for supported profile', () {
      final session = backend.createSession(ggufProfile, const InferenceSettings());
      expect(session, isA<InferenceSession>());
      session.dispose();
    });
  });

  group('InferenceSession contract', () {
    test('generate streams tokens and completes', () async {
      final session = _FakeSession(['tok1', 'tok2', 'tok3']);
      final tokens = await session.generate([]).toList();
      expect(tokens, ['tok1', 'tok2', 'tok3']);
    });

    test('cancel sets cancelled flag', () {
      final session = _FakeSession([]);
      session.cancel();
      expect(session.cancelled, isTrue);
    });

    test('dispose sets disposed flag', () {
      final session = _FakeSession([]);
      session.dispose();
      expect(session.disposed, isTrue);
    });
  });
}
