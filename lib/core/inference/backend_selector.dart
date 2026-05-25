import 'dart:io';

import 'package:little_star_app/core/inference/inference_backend.dart';
import 'package:little_star_app/core/inference/llama_cpp_backend.dart';
import 'package:little_star_app/core/model/model_profile.dart';

// ─── Override ─────────────────────────────────────────────────────────────────

/// Explicit backend preference that overrides the default selection logic.
enum BackendOverride {
  /// Force the llama.cpp backend regardless of model format.
  llamaCpp,

  /// Force the MLX backend. Still requires Apple Silicon; throws
  /// [UnsupportedError] on unsupported platforms.
  mlx,
}

// ─── Platform abstraction (for testability) ──────────────────────────────────

/// Answers platform questions that [BackendSelector] needs.
/// Decoupled from [dart:io] so unit tests can inject fakes.
abstract class BackendPlatform {
  /// True when the device can run MLX (iOS or macOS on Apple Silicon).
  bool get supportsMLX;
}

/// Production implementation backed by [Platform].
class SystemBackendPlatform implements BackendPlatform {
  const SystemBackendPlatform();

  @override
  bool get supportsMLX => Platform.isIOS || Platform.isMacOS;
}

// ─── BackendSelector ──────────────────────────────────────────────────────────

/// Picks the right [InferenceBackend] for a [ModelProfile].
///
/// Default logic:
/// - GGUF → [LlamaCppBackend] on all platforms.
/// - MLX + Apple Silicon → MlxBackend (task-1001).
/// - MLX on any other platform → [UnsupportedError].
///
/// Pass a [BackendOverride] to bypass the default logic.
/// Wire [mlxBackendFactory] once task-1001 is complete.
class BackendSelector {
  final BackendPlatform _platform;

  /// Factory called when an MLX backend is needed.
  /// Throws [UnimplementedError] if null (until task-1001 lands).
  final InferenceBackend Function()? mlxBackendFactory;

  BackendSelector({
    BackendPlatform? platform,
    this.mlxBackendFactory,
  }) : _platform = platform ?? const SystemBackendPlatform();

  /// Returns the [InferenceBackend] appropriate for [profile].
  ///
  /// If [override] is provided it takes precedence over the default logic,
  /// but platform constraints are still enforced (e.g. MLX on Windows still
  /// throws [UnsupportedError]).
  InferenceBackend select(ModelProfile profile, [BackendOverride? override]) {
    if (override != null) return _resolveOverride(override, profile);

    return switch (profile.format) {
      ModelFormat.gguf => LlamaCppBackend(),
      ModelFormat.mlx => _selectMlx(profile),
    };
  }

  InferenceBackend _selectMlx(ModelProfile profile) {
    if (!_platform.supportsMLX) {
      throw UnsupportedError(
        'MLX models require Apple Silicon (iOS or macOS). '
        'Profile: ${profile.id}',
      );
    }
    final factory = mlxBackendFactory;
    if (factory == null) {
      throw UnimplementedError(
        'MlxBackend is not yet wired up (task-1001). '
        'Provide mlxBackendFactory to BackendSelector.',
      );
    }
    return factory();
  }

  InferenceBackend _resolveOverride(BackendOverride override, ModelProfile profile) {
    return switch (override) {
      BackendOverride.llamaCpp => LlamaCppBackend(),
      BackendOverride.mlx => _selectMlx(profile),
    };
  }
}
