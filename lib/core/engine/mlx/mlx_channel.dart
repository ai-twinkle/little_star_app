import 'package:flutter/services.dart';
import 'mlx_inference.g.dart';

export 'mlx_inference.g.dart'
    show MlxChatMessage, MlxGenerationParams, MlxTokenEvent;

/// High-level Dart facade over the Pigeon-generated [MlxInferenceHostApi]
/// and [onToken] event channel.
///
/// Lifecycle: loadModel → generate (repeat) → dispose.
class MlxChannel {
  MlxChannel() : _host = MlxInferenceHostApi();

  final MlxInferenceHostApi _host;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Loads the model from [localPath] (a local snapshot directory).
  /// Throws [PlatformException] on failure.
  Future<void> loadModel(String localPath) => _host.loadModel(localPath);

  /// Starts a streaming generation pass for the given [messages].
  /// Returns a [Stream] that emits [MlxTokenEvent] per token until
  /// [MlxTokenEvent.isDone] == true.
  ///
  /// The stream automatically filters the final "done" sentinel from the
  /// token text, but the caller still receives it to read the final tps.
  Stream<MlxTokenEvent> generate(
    List<MlxChatMessage> messages, {
    MlxGenerationParams? params,
  }) async* {
    final effectiveParams = params ??
        MlxGenerationParams(temperature: 0.6, topP: 0.9, maxTokens: 512);

    // Start generation on the Swift side (fire-and-forget channel call).
    await _host.startGeneration(messages, effectiveParams);

    // Subscribe to the event channel and forward events.
    await for (final event in onToken()) {
      yield event;
      if (event.isDone) break;
    }
  }

  /// Cancels any in-flight generation.
  Future<void> cancel() => _host.cancelGeneration();

  /// Releases the loaded model and frees memory.
  Future<void> dispose() => _host.disposeModel();

  /// Returns true if a model is currently loaded.
  Future<bool> isModelLoaded() => _host.isModelLoaded();
}
