# llama.cpp macOS Build Guide

**llama.cpp version**: b7493 (bundled in `llama.cpp/`)  
**Spike**: task-002 — EP-0 macOS llama.cpp Build Spike  
**Date**: 2026-05-22

---

## Overview

Builds `libllama.a` and `libggml*.a` as universal static libraries (arm64 + x86_64) for macOS,
integrates them into `macos/Runner` via `OTHER_LDFLAGS`, and exposes symbols via
`DynamicLibrary.process()` in the Dart FFI layer.

---

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Xcode | 15+ (Xcode 26.2 tested) | App Store |
| CMake | 3.28+ (4.0.2 tested) | `brew install cmake` |
| Xcode CLT | current | `xcode-select --install` |

---

## Quick Build

```bash
bash scripts/build_llama.cpp_macos.sh
```

Output: `macos/Frameworks/libllama.a`, `libggml.a`, `libggml-base.a`, `libggml-cpu.a`,
`libggml-metal.a`, `libggml-blas.a` — all universal (arm64 + x86_64).

Headers are copied to `macos/Runner/`.

---

## CMake Flags Explained

| Flag | Value | Reason |
|------|-------|--------|
| `BUILD_SHARED_LIBS` | `OFF` | Produce `.a` for static linking into Runner binary |
| `LLAMA_STATIC` | `ON` | Force static even when cmake detects shared preference |
| `GGML_METAL` | `ON` | Metal GPU acceleration (Apple Silicon + Intel) |
| `GGML_METAL_EMBED_LIBRARY` | `ON` | Embeds Metal shaders in `.a`, no external `.metallib` needed |
| `GGML_ACCELERATE` | `ON` | Apple Accelerate framework (BLAS, vDSP) |
| `GGML_BLAS` | `ON` | Enables BLAS via Accelerate |
| `GGML_NATIVE` | `OFF` | Portable binary — no host-specific CPU features |
| `GGML_OPENMP` | `OFF` | Avoid OpenMP dependency; GCD used instead on Apple |
| `LLAMA_CURL` | `OFF` | No network download code in library |
| `CMAKE_OSX_DEPLOYMENT_TARGET` | `13.0` | Matches app deployment target |

---

## Xcode Project Integration

Libraries are added via `OTHER_LDFLAGS` in `macos/Runner.xcodeproj/project.pbxproj`
for all three Runner target configurations (Debug / Release / Profile):

```
OTHER_LDFLAGS = (
    "$(inherited)",
    "-force_load", "$(PROJECT_DIR)/Frameworks/libllama.a",
    "-force_load", "$(PROJECT_DIR)/Frameworks/libggml.a",
    "-force_load", "$(PROJECT_DIR)/Frameworks/libggml-base.a",
    "-force_load", "$(PROJECT_DIR)/Frameworks/libggml-cpu.a",
    "-force_load", "$(PROJECT_DIR)/Frameworks/libggml-metal.a",
    "-force_load", "$(PROJECT_DIR)/Frameworks/libggml-blas.a",
    "-framework Metal",
    "-framework Accelerate",
    "-framework Foundation",
);
```

> **Why `-force_load`?**  
> In Flutter macOS debug mode, the static library symbols land in
> `little_star_app.debug.dylib`. Without `-force_load`, the linker dead-strips
> symbols not directly referenced by Swift/ObjC code. `-force_load` retains all
> symbols so `DynamicLibrary.process()` can find them at runtime.

---

## Dart FFI Loader

`lib/core/engine/llama_cpp/llama_cpp_ffi.dart` — `_loadLibrary()`:

```dart
} else if (Platform.isMacOS) {
  // Static libraries are linked into the app binary (same as iOS).
  // DynamicLibrary.process() resolves symbols from the current process image.
  try {
    _lib = ffi.DynamicLibrary.process();
    _ggmlLib = ffi.DynamicLibrary.process();
    log.debug('Successfully loaded llama.cpp libraries from macOS app bundle');
    return;
  } catch (e) {
    throw Exception('Failed to load libraries from macOS app bundle: $e');
  }
}
```

---

## Code Signing & Entitlements

### Debug / Profile (`Runner/DebugProfile.entitlements`)
```xml
<key>com.apple.security.app-sandbox</key>  <true/>
<key>com.apple.security.cs.allow-jit</key>  <true/>
<key>com.apple.security.network.client</key>  <true/>
<key>com.apple.security.network.server</key>  <true/>
```

### Release (`Runner/Release.entitlements`)
```xml
<key>com.apple.security.app-sandbox</key>  <true/>
<key>com.apple.security.network.client</key>  <true/>
```

**Notes**:
- Metal GPU access is allowed by default in App Sandbox since macOS 10.14 — no extra entitlement needed.
- `com.apple.security.cs.allow-jit` is present in DebugProfile for Flutter JIT compilation.
- `network.client` was added in task-003 for model downloads.
- Model files are stored in the App Sandbox container:
  `~/Library/Containers/<bundle-id>/Data/Library/Application Support/<bundle-id>/Models/`
  (returned by `getApplicationSupportDirectory()` via `path_provider`).

---

## Verified Results (2026-05-22, Apple Silicon M-series)

```
✅ flutter build macos --debug  →  build succeeded
✅ DynamicLibrary.process()     →  1279 llama/ggml symbols found in process image
✅ llama_backend_init()         →  Metal : EMBED_LIBRARY = 1 | CPU : NEON = 1 | ACCELERATE = 1
✅ llama_model_load()           →  gemma-3-270m-it-Q4_K_M.gguf loaded in ~6s
⚠️ completion                  →  loadModel verified; full completion requires UI interaction
```

**System info from runtime**:
```
Metal : EMBED_LIBRARY = 1 | CPU : NEON = 1 | ARM_FMA = 1 | FP16_VA = 1 |
DOTPROD = 1 | LLAMAFILE = 1 | ACCELERATE = 1 | REPACK = 1
```

---

## Known Issues

1. **Firebase not configured for macOS**: `DefaultFirebaseOptions.currentPlatform` throws
   for macOS if Google services aren't set up. Excluded macOS from Firebase initialization
   in `main.dart` (`_isFirebaseSupported`). Needs proper macOS `GoogleService-Info.plist` for
   production (task-TODO).

2. **`macOS deployment target` warnings from Pods**: Some CocoaPods targets use 10.11;
   these are third-party warnings and do not affect our code.

3. **`supportsInference = false`** in `MacOSPlatformAdapter`: Kept disabled until
   proper EP-7 integration (task-701). Enable temporarily for testing by setting to `true`.

---

## Next Steps (EP-7: task-701)

- [ ] Add `macos/Frameworks/libllama.a` + other `.a` files to git (or LFS)
- [ ] Run full `loadModel → completion` end-to-end test (manual UI: type prompt, run)
- [ ] Measure tok/s on Apple Silicon vs iOS
- [ ] Set `MacOSPlatformAdapter.supportsInference = true` for production
- [ ] Configure Firebase for macOS (add `GoogleService-Info.plist`)
