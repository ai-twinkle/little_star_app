// Pigeon API definition for MLX inference bridge (iOS only).
//
// This file defines the type-safe interface between Dart (Flutter) and Swift (iOS).
// Bridge pattern: HostApi for commands, EventChannelApi for token streaming.
//
// Generate with:
//   dart run pigeon --input pigeons/mlx_inference.dart

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/core/engine/mlx/mlx_inference.g.dart',
  swiftOut: 'ios/Runner/MlxBridge/MlxInference.g.swift',
))

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// A single token event emitted during streaming generation.
class MlxTokenEvent {
  MlxTokenEvent({
    required this.token,
    required this.isDone,
    this.tokensPerSecond,
  });

  /// The generated token text (may be empty when isDone = true).
  String token;

  /// True when generation is complete.
  bool isDone;

  /// Current tokens/sec rate, reported with every token.
  double? tokensPerSecond;
}

/// A single chat message for the conversation context.
class MlxChatMessage {
  MlxChatMessage({required this.role, required this.content});

  /// "system" | "user" | "assistant"
  String role;
  String content;
}

/// Generation hyper-parameters.
class MlxGenerationParams {
  MlxGenerationParams({
    this.temperature = 0.6,
    this.topP = 0.9,
    this.maxTokens = 512,
    this.seed,
  });

  double temperature;
  double topP;
  int maxTokens;
  int? seed;
}

// ---------------------------------------------------------------------------
// Host API — commands from Dart → Swift
// ---------------------------------------------------------------------------

@HostApi()
abstract class MlxInferenceHostApi {
  /// Load the model from a local directory path.
  /// The model must already be downloaded to [localPath].
  @async
  void loadModel(String localPath);

  /// Start a streaming generation pass.
  /// Tokens arrive via [MlxTokenStreamApi].
  void startGeneration(
    List<MlxChatMessage> messages,
    MlxGenerationParams params,
  );

  /// Cancel an in-flight generation.
  void cancelGeneration();

  /// Release the loaded model and free memory.
  void disposeModel();

  /// Returns true if a model is currently loaded.
  bool isModelLoaded();
}

// ---------------------------------------------------------------------------
// Event Channel — token stream from Swift → Dart
// ---------------------------------------------------------------------------

@EventChannelApi()
abstract class MlxTokenStreamApi {
  /// Emits [MlxTokenEvent] for every generated token.
  /// The stream ends when [MlxTokenEvent.isDone] == true.
  MlxTokenEvent onToken();
}
