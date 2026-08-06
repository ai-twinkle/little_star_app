import 'dart:async';

import 'package:little_star_app/core/engine/mlx/mlx_channel.dart';
import 'package:little_star_app/core/inference/inference_backend.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/inference/turn_marker_filter.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/utils/logger.dart';

// ─── Testable channel surface ─────────────────────────────────────────────────

/// Minimal interface over [MlxChannel] that [MlxSession] depends on.
/// Kept as a separate class so tests can inject a fake without a platform
/// channel — mirrors [LlamaFfiDriver] in llama_cpp_backend.dart.
abstract class MlxChannelDriver {
  Future<void> loadModel(String localPath);

  Stream<MlxTokenEvent> generate(
    List<MlxChatMessage> messages, {
    MlxGenerationParams? params,
  });

  Future<void> cancel();

  Future<void> dispose();
}

// Production driver — thin delegation to the real MlxChannel.
class _RealMlxChannelDriver implements MlxChannelDriver {
  final MlxChannel _channel;
  _RealMlxChannelDriver(this._channel);

  @override
  Future<void> loadModel(String localPath) => _channel.loadModel(localPath);

  @override
  Stream<MlxTokenEvent> generate(
    List<MlxChatMessage> messages, {
    MlxGenerationParams? params,
  }) =>
      _channel.generate(messages, params: params);

  @override
  Future<void> cancel() => _channel.cancel();

  @override
  Future<void> dispose() => _channel.dispose();
}

// ─── MlxSession ────────────────────────────────────────────────────────────────

class MlxSession implements InferenceSession {
  final MlxChannelDriver _driver;
  final InferenceSettings _settings;
  final String _localPath;
  final Logger _log = Logger('MlxSession');

  bool _cancelled = false;
  bool _disposed = false;
  bool _modelLoaded = false;

  /// Production constructor — used by [MlxBackend].
  ///
  /// Unlike [LlamaCppSession], model loading is not done eagerly: the real
  /// [MlxChannel] crosses a platform channel and is inherently async, while
  /// [InferenceBackend.createSession] must return synchronously. The model
  /// is loaded lazily on the first [generate] call instead.
  MlxSession(this._driver, this._settings, this._localPath);

  @override
  Stream<String> generate(List<ChatMessage> messages) {
    if (_disposed) throw StateError('MlxSession: generate called after dispose');
    _cancelled = false;
    return _runGeneration(messages);
  }

  Stream<String> _runGeneration(List<ChatMessage> messages) async* {
    if (!_modelLoaded) {
      await _driver.loadModel(_localPath);
      _modelLoaded = true;
    }
    if (_cancelled) return;

    final mlxMessages = _toMlxMessages(messages);
    final sp = _settings.samplingParams;
    final params = MlxGenerationParams(
      temperature: sp.temperature,
      topP: sp.topP,
      maxTokens: _settings.maxTokens,
      seed: sp.seed < 0 ? null : sp.seed,
    );

    final filter = TurnMarkerFilter();
    var stoppedByMarker = false;
    await for (final event in _driver.generate(mlxMessages, params: params)) {
      if (_cancelled) break;
      if (event.isDone) break;
      if (event.token.isEmpty) continue;
      final result = filter.feed(event.token);
      if (result.text.isNotEmpty) yield result.text;
      if (result.stop) {
        _log.debug('Turn-marker guard: truncated fabricated next turn');
        stoppedByMarker = true;
        break;
      }
    }
    if (!stoppedByMarker && !_cancelled) {
      final remainder = filter.flush();
      if (remainder.isNotEmpty) yield remainder;
    }
  }

  /// Converts [messages] to the wire format expected by the MLX bridge.
  ///
  /// Unlike [GemmaChatTemplate] (used to render a single prompt string for
  /// llama.cpp), the system prompt is passed as its own "system"-role
  /// message: the MLX bridge delegates template rendering to the model's
  /// real Jinja chat template (swift-transformers + swift-jinja) rather
  /// than a hardcoded formatter, and that template handles the system role
  /// natively.
  List<MlxChatMessage> _toMlxMessages(List<ChatMessage> messages) {
    final mapped = <MlxChatMessage>[];
    if (_settings.systemPrompt != null && _settings.systemPrompt!.isNotEmpty) {
      mapped.add(MlxChatMessage(role: 'system', content: _settings.systemPrompt!));
    }
    for (final m in messages) {
      mapped.add(MlxChatMessage(
        role: m.isUser ? 'user' : 'assistant',
        content: m.content,
      ));
    }
    return mapped;
  }

  @override
  void cancel() {
    _log.debug('cancel()');
    _cancelled = true;
    unawaited(_driver.cancel());
  }

  @override
  void dispose() {
    if (_disposed) return;
    _log.debug('dispose()');
    _disposed = true;
    unawaited(_driver.dispose());
  }
}

// ─── MlxBackend ────────────────────────────────────────────────────────────────

class MlxBackend implements InferenceBackend {
  final Logger _log = Logger('MlxBackend');

  /// Returns true for MLX models. Platform support (Apple Silicon only) is
  /// [BackendSelector]'s responsibility, not this backend's.
  @override
  bool canHandle(ModelProfile profile) => profile.format == ModelFormat.mlx;

  /// Creates and returns an [MlxSession] for [profile].
  ///
  /// The underlying model is not loaded until the first [InferenceSession.generate]
  /// call — see [MlxSession]. The caller is responsible for calling
  /// [InferenceSession.dispose] when the session is no longer needed.
  @override
  InferenceSession createSession(
    ModelProfile profile,
    InferenceSettings settings,
  ) {
    if (!canHandle(profile)) {
      throw UnsupportedError(
        'MlxBackend only handles MLX models; got ${profile.format}',
      );
    }

    final localPath = profile.localPath;
    if (localPath == null || localPath.isEmpty) {
      throw ArgumentError.value(
        profile,
        'profile',
        'ModelProfile.localPath must be set before creating a session',
      );
    }

    _log.debug('createSession: $localPath');

    return MlxSession(_RealMlxChannelDriver(MlxChannel()), settings, localPath);
  }
}
