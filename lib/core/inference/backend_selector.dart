import 'package:little_star_app/core/inference/inference_backend.dart';
import 'package:little_star_app/core/inference/llama_cpp_backend.dart';
import 'package:little_star_app/core/inference/mlx_backend.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/core/platform/platform_adapter.dart';

// ─── Override ─────────────────────────────────────────────────────────────────

/// Explicit backend preference that overrides the default selection logic.
enum BackendOverride {
  /// Force the llama.cpp backend regardless of model format.
  llamaCpp,

  /// Force the MLX backend. Still requires Apple Silicon; throws
  /// [UnsupportedError] on unsupported platforms.
  mlx,
}

// ─── BackendSelector ──────────────────────────────────────────────────────────

/// Picks the right [InferenceBackend] for a [ModelProfile].
///
/// Default logic:
/// - GGUF → [LlamaCppBackend] on all platforms.
/// - MLX + Apple Silicon → MlxBackend (task-1001).
/// - MLX on any other platform → [UnsupportedError].
///
/// Pass a [BackendOverride] to bypass the default logic. Tests may replace the
/// production MLX registration through [mlxBackendFactory].
class BackendSelector {
  final PlatformAdapter _platform;
  final InferenceBackend Function() _mlxBackendFactory;

  BackendSelector({
    PlatformAdapter? platform,
    InferenceBackend Function()? mlxBackendFactory,
  }) : _platform = platform ?? PlatformAdapter.current(),
       _mlxBackendFactory = mlxBackendFactory ?? MlxBackend.new;

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
    if (!_platform.supportsMlx) {
      throw UnsupportedError(
        'MLX models require Apple Silicon (iOS or macOS). '
        'Profile: ${profile.id}',
      );
    }
    return _mlxBackendFactory();
  }

  InferenceBackend _resolveOverride(
    BackendOverride override,
    ModelProfile profile,
  ) {
    return switch (override) {
      BackendOverride.llamaCpp => LlamaCppBackend(),
      BackendOverride.mlx => _selectMlx(profile),
    };
  }
}
