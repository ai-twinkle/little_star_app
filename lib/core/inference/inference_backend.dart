import 'package:little_star_app/core/model/model_profile.dart';
import 'inference_session.dart';
import 'inference_settings.dart';

/// Capability query and session factory for one inference backend.
///
/// Backends are stateless factories; all per-run state lives in
/// [InferenceSession]. A single backend instance may create multiple
/// concurrent sessions if the underlying library permits it.
abstract class InferenceBackend {
  /// Returns true if this backend can load and run [profile].
  ///
  /// Implementations should check format compatibility and platform
  /// availability (e.g. MLX only on Apple Silicon).
  bool canHandle(ModelProfile profile);

  /// Creates a new session for [profile] configured with [settings].
  ///
  /// Throws [UnsupportedError] if [canHandle(profile)] is false.
  /// The caller owns the returned session and must call
  /// [InferenceSession.dispose] when finished.
  InferenceSession createSession(ModelProfile profile, InferenceSettings settings);
}
