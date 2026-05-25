import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:path/path.dart' as path;

// ─── Platform abstraction (for testability) ───────────────────────────────────

/// Answers platform-detection questions for [NativeLibraryLoader].
/// Decoupled from [dart:io] so unit tests can inject fakes.
abstract class NativeLibraryPlatform {
  bool get isIOS;
  bool get isAndroid;
  bool get isMacOS;
  bool get isWindows;
  bool get isLinux;
}

/// Production implementation backed by [Platform].
class SystemNativeLibraryPlatform implements NativeLibraryPlatform {
  const SystemNativeLibraryPlatform();

  @override
  bool get isIOS => Platform.isIOS;

  @override
  bool get isAndroid => Platform.isAndroid;

  @override
  bool get isMacOS => Platform.isMacOS;

  @override
  bool get isWindows => Platform.isWindows;

  @override
  bool get isLinux => Platform.isLinux;
}

// ─── Library spec ─────────────────────────────────────────────────────────────

/// Describes how to obtain the llama.cpp dynamic libraries on a given platform.
sealed class LlamaLibrarySpec {
  const LlamaLibrarySpec();
}

/// iOS / macOS: libraries are statically linked; use [DynamicLibrary.process()].
class ProcessSpec extends LlamaLibrarySpec {
  const ProcessSpec();
}

/// Android / Windows / Linux: load shared libraries by path via [DynamicLibrary.open()].
class OpenSpec extends LlamaLibrarySpec {
  final String llamaPath;
  final String ggmlPath;
  const OpenSpec({required this.llamaPath, required this.ggmlPath});
}

// ─── NativeLibraryLoader ──────────────────────────────────────────────────────

/// Centralises all platform-specific native library loading logic.
///
/// [resolveSpec] is pure and unit-testable (no native calls).
/// [loadLlama] executes the spec and returns live library handles.
class NativeLibraryLoader {
  final NativeLibraryPlatform _platform;

  NativeLibraryLoader([NativeLibraryPlatform? platform])
      : _platform = platform ?? const SystemNativeLibraryPlatform();

  /// Returns the [LlamaLibrarySpec] for the current platform.
  LlamaLibrarySpec resolveSpec() {
    if (_platform.isIOS || _platform.isMacOS) return const ProcessSpec();
    if (_platform.isAndroid) {
      return const OpenSpec(llamaPath: 'libllama.so', ggmlPath: 'libggml.so');
    }
    if (_platform.isWindows) {
      final dir = Directory.current.path;
      return OpenSpec(
        llamaPath: path.join(dir, 'llama.dll'),
        ggmlPath: path.join(dir, 'ggml.dll'),
      );
    }
    if (_platform.isLinux) {
      final dir = Directory.current.path;
      return OpenSpec(
        llamaPath: path.join(dir, 'libllama.so'),
        ggmlPath: path.join(dir, 'libggml.so'),
      );
    }
    throw UnsupportedError(
      'NativeLibraryLoader: unsupported platform. '
      'No llama.cpp library path defined.',
    );
  }

  /// Loads and returns the llama + ggml [DynamicLibrary] handles.
  /// Throws if loading fails or the platform is unsupported.
  ({ffi.DynamicLibrary llama, ffi.DynamicLibrary ggml}) loadLlama() {
    switch (resolveSpec()) {
      case ProcessSpec():
        final lib = ffi.DynamicLibrary.process();
        return (llama: lib, ggml: lib);
      case OpenSpec(:final llamaPath, :final ggmlPath):
        return (
          llama: ffi.DynamicLibrary.open(llamaPath),
          ggml: ffi.DynamicLibrary.open(ggmlPath),
        );
    }
  }

  /// True on Windows: caller must use `setLogCallback` + `ggml_backend_load_all`
  /// for backend initialisation instead of the standard `initBackend`.
  bool get needsExplicitBackendInit => _platform.isWindows;
}
