import 'package:flutter_test/flutter_test.dart';
import 'package:little_star_app/core/platform/native_library_loader.dart';

// ─── Fake platforms ───────────────────────────────────────────────────────────

class _FakePlatform implements NativeLibraryPlatform {
  @override
  final bool isIOS;
  @override
  final bool isAndroid;
  @override
  final bool isMacOS;
  @override
  final bool isWindows;
  @override
  final bool isLinux;

  const _FakePlatform({
    this.isIOS = false,
    this.isAndroid = false,
    this.isMacOS = false,
    this.isWindows = false,
    this.isLinux = false,
  });
}

const _ios = _FakePlatform(isIOS: true);
const _android = _FakePlatform(isAndroid: true);
const _macos = _FakePlatform(isMacOS: true);
const _windows = _FakePlatform(isWindows: true);
const _linux = _FakePlatform(isLinux: true);

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('NativeLibraryLoader.resolveSpec', () {
    test('iOS → ProcessSpec', () {
      final spec = NativeLibraryLoader(_ios).resolveSpec();
      expect(spec, isA<ProcessSpec>());
    });

    test('macOS → ProcessSpec', () {
      final spec = NativeLibraryLoader(_macos).resolveSpec();
      expect(spec, isA<ProcessSpec>());
    });

    test('Android → OpenSpec with libllama.so / libggml.so', () {
      final spec = NativeLibraryLoader(_android).resolveSpec();
      expect(spec, isA<OpenSpec>());
      final open = spec as OpenSpec;
      expect(open.llamaPath, 'libllama.so');
      expect(open.ggmlPath, 'libggml.so');
    });

    test('Windows → OpenSpec ending in llama.dll / ggml.dll', () {
      final spec = NativeLibraryLoader(_windows).resolveSpec();
      expect(spec, isA<OpenSpec>());
      final open = spec as OpenSpec;
      expect(open.llamaPath, endsWith('llama.dll'));
      expect(open.ggmlPath, endsWith('ggml.dll'));
    });

    test('Linux → OpenSpec ending in libllama.so / libggml.so', () {
      final spec = NativeLibraryLoader(_linux).resolveSpec();
      expect(spec, isA<OpenSpec>());
      final open = spec as OpenSpec;
      expect(open.llamaPath, endsWith('libllama.so'));
      expect(open.ggmlPath, endsWith('libggml.so'));
    });
  });

  group('NativeLibraryLoader.needsExplicitBackendInit', () {
    test('true only on Windows', () {
      expect(NativeLibraryLoader(_windows).needsExplicitBackendInit, isTrue);
    });

    test('false on iOS', () {
      expect(NativeLibraryLoader(_ios).needsExplicitBackendInit, isFalse);
    });

    test('false on macOS', () {
      expect(NativeLibraryLoader(_macos).needsExplicitBackendInit, isFalse);
    });

    test('false on Android', () {
      expect(NativeLibraryLoader(_android).needsExplicitBackendInit, isFalse);
    });

    test('false on Linux', () {
      expect(NativeLibraryLoader(_linux).needsExplicitBackendInit, isFalse);
    });
  });
}
