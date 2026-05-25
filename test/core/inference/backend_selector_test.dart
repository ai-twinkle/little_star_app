import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/inference/backend_selector.dart';
import 'package:little_star_app/core/inference/inference_backend.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/inference/llama_cpp_backend.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/models/chat_message.dart';

// ─── Fake platform ────────────────────────────────────────────────────────────

class _FakePlatform implements BackendPlatform {
  @override
  final bool supportsMLX;
  _FakePlatform({required this.supportsMLX});
}

final _appleDevice = _FakePlatform(supportsMLX: true);
final _nonAppleDevice = _FakePlatform(supportsMLX: false);

// ─── Stub MLX backend ─────────────────────────────────────────────────────────

class _StubMlxBackend implements InferenceBackend {
  @override
  bool canHandle(ModelProfile profile) => profile.format == ModelFormat.mlx;

  @override
  InferenceSession createSession(ModelProfile profile, InferenceSettings settings) =>
      throw UnimplementedError();
}

// ─── Profiles ─────────────────────────────────────────────────────────────────

const _ggufProfile = ModelProfile(
  id: 'llama-3b',
  displayName: 'Llama 3B GGUF',
  format: ModelFormat.gguf,
  localPath: '/models/llama.gguf',
);

const _mlxProfile = ModelProfile(
  id: 'llama-mlx',
  displayName: 'Llama 1B MLX',
  format: ModelFormat.mlx,
  localPath: '/models/llama-mlx',
);

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  // Scenario 1: GGUF on Android-like platform
  test('gguf on android → LlamaCppBackend', () {
    final selector = BackendSelector(platform: _nonAppleDevice);
    final backend = selector.select(_ggufProfile);
    expect(backend, isA<LlamaCppBackend>());
  });

  // Scenario 2: GGUF on iOS-like platform
  test('gguf on ios → LlamaCppBackend', () {
    final selector = BackendSelector(platform: _appleDevice);
    final backend = selector.select(_ggufProfile);
    expect(backend, isA<LlamaCppBackend>());
  });

  // Scenario 3: GGUF on macOS-like platform
  test('gguf on macos → LlamaCppBackend', () {
    final selector = BackendSelector(platform: _appleDevice);
    final backend = selector.select(_ggufProfile);
    expect(backend, isA<LlamaCppBackend>());
  });

  // Scenario 4: MLX on macOS (Apple Silicon) → MlxBackend via factory
  test('mlx on macos (Apple Silicon) → MlxBackend from factory', () {
    final selector = BackendSelector(
      platform: _appleDevice,
      mlxBackendFactory: () => _StubMlxBackend(),
    );
    final backend = selector.select(_mlxProfile);
    expect(backend, isA<_StubMlxBackend>());
  });

  // Scenario 5: MLX on Windows → UnsupportedError
  test('mlx on windows → throws UnsupportedError', () {
    final selector = BackendSelector(
      platform: _nonAppleDevice,
      mlxBackendFactory: () => _StubMlxBackend(),
    );
    expect(
      () => selector.select(_mlxProfile),
      throwsUnsupportedError,
    );
  });

  // Scenario 6: MLX on Android → UnsupportedError
  test('mlx on android → throws UnsupportedError', () {
    final selector = BackendSelector(platform: _nonAppleDevice);
    expect(
      () => selector.select(_mlxProfile),
      throwsUnsupportedError,
    );
  });

  // Scenario 7: MLX on Apple but no factory → UnimplementedError
  test('mlx on apple without factory → throws UnimplementedError', () {
    final selector = BackendSelector(
      platform: _appleDevice,
      // mlxBackendFactory intentionally not provided
    );
    expect(
      () => selector.select(_mlxProfile),
      throwsA(isA<UnimplementedError>()),
    );
  });

  // Override scenarios
  group('BackendOverride', () {
    test('override llamaCpp with gguf profile → LlamaCppBackend', () {
      final selector = BackendSelector(platform: _appleDevice);
      final backend = selector.select(_ggufProfile, BackendOverride.llamaCpp);
      expect(backend, isA<LlamaCppBackend>());
    });

    test('override llamaCpp with mlx profile → LlamaCppBackend', () {
      final selector = BackendSelector(platform: _appleDevice);
      // Forcing llamaCpp even for an MLX-format model
      final backend = selector.select(_mlxProfile, BackendOverride.llamaCpp);
      expect(backend, isA<LlamaCppBackend>());
    });

    test('override mlx on Apple → MlxBackend from factory', () {
      final selector = BackendSelector(
        platform: _appleDevice,
        mlxBackendFactory: () => _StubMlxBackend(),
      );
      final backend = selector.select(_ggufProfile, BackendOverride.mlx);
      expect(backend, isA<_StubMlxBackend>());
    });

    test('override mlx on non-Apple → throws UnsupportedError', () {
      final selector = BackendSelector(
        platform: _nonAppleDevice,
        mlxBackendFactory: () => _StubMlxBackend(),
      );
      expect(
        () => selector.select(_ggufProfile, BackendOverride.mlx),
        throwsUnsupportedError,
      );
    });
  });

  // BackendOverride enum completeness
  test('BackendOverride has llamaCpp and mlx values', () {
    expect(BackendOverride.values, containsAll([BackendOverride.llamaCpp, BackendOverride.mlx]));
  });
}
