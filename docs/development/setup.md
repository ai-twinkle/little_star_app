# Development Setup

> Audience: contributors who want to clone the repo and get a working dev build.
> This guide takes you from zero to a running app on iOS, macOS, Windows, or Android.

## 1. Overview

`little_star_app` is a Flutter app with native dependencies on llama.cpp (C/C++) and,
on Apple Silicon, mlx-swift-lm (Swift). To run a dev build you will:

1. Install host-level tools (Xcode / Visual Studio, fvm, CMake).
2. Clone the repo and fetch Flutter / Cocoapods dependencies.
3. Build llama.cpp for your target platform.
4. (Optional) Regenerate Pigeon glue if you change `pigeons/mlx_inference.dart`.
5. Run `fvm flutter run -d <platform>`.

The detailed per-platform build instructions live in `scripts/llama.cpp_*_Build.md`.
This document is the **entry point** — it tells you which guide to read and what
order to do things in.

## 2. Prerequisites

### 2.1 Host OS

| Target | Host OS | Notes |
|--------|---------|-------|
| iOS | macOS 13+ | Xcode requires macOS |
| macOS | macOS 13+ | App's minimum deployment target is macOS 13 |
| Android | macOS / Linux / Windows | NDK required |
| Windows | Windows 10+ | Visual Studio with "Desktop development with C++" |

### 2.2 Toolchains

| Tool | Version | Install | Used for |
|------|---------|---------|----------|
| **fvm** | latest | `dart pub global activate fvm` | Pins the Flutter SDK to the project's version |
| **Flutter** | via fvm | `fvm install` | Flutter SDK |
| **Xcode** | 15+ (26.2 tested) | App Store | iOS / macOS builds |
| **Xcode CLT** | current | `xcode-select --install` | Command-line build tools |
| **CocoaPods** | latest | `gem install cocoapods` | iOS / macOS plugin deps |
| **CMake** | 3.28+ (4.0.2 tested) | `brew install cmake` / `winget install Kitware.CMake` | llama.cpp build |
| **Android NDK** | 25.1.8937393+ | Android Studio → SDK Manager | Android llama.cpp build |
| **Visual Studio** | 2022 + C++ workload | [visualstudio.microsoft.com](https://visualstudio.microsoft.com/) | Windows llama.cpp build |
| **Git LFS** | latest | `brew install git-lfs` / `git lfs install` | macOS universal libs ship via LFS |
| **Pigeon CLI** | `^22.7.2` | `fvm dart pub global activate pigeon 22.7.2` *(optional)* | Regenerating MLX bridge glue |

> **Why fvm?** The Flutter SDK version is part of the project; fvm keeps your local
> SDK consistent with CI and other contributors. Running `flutter` directly may use
> a globally installed version that differs from what this project expects.

### 2.3 Verify

After installing the above, sanity-check with:

```bash
fvm flutter doctor
```

You should see green checks for at least:

- Flutter
- (Mac) Xcode
- (Mac/Win) Connected devices or simulators

Some sections (Chrome, Linux toolchain) are expected to be red on platforms you do
not target — that is fine.

## 3. Clone & Bootstrap

```bash
git clone https://github.com/<owner>/little_star_app.git
cd little_star_app

# Pull LFS-tracked artefacts (macOS universal libs).
git lfs install
git lfs pull

# Install Flutter SDK pinned to the project's version.
fvm install
fvm use

# Fetch Dart / Flutter dependencies.
fvm flutter pub get

# Install iOS / macOS plugin pods.
cd ios   && pod install && cd ..
cd macos && pod install && cd ..
```

### Verify

```bash
fvm flutter doctor
fvm flutter pub deps --no-dev | head -20
```

Both commands should complete without errors.

## 4. Build llama.cpp

llama.cpp is bundled in `llama.cpp/` at a pinned commit (currently `b9334` for
Windows, `b7493` for mobile targets). The build scripts compile the appropriate
static or dynamic library for each platform and place it where the Runner expects.

| Platform | Build script | Output |
|----------|--------------|--------|
| iOS | `scripts/build_llama.cpp_ios.sh` | `ios/Frameworks/libllama-*.a` + `libggml*.a` |
| macOS | `scripts/build_llama.cpp_macos.sh` | `macos/Frameworks/libllama.a` + `libggml*.a` (universal arm64 + x86_64) |
| Android | `scripts/build_llama.cpp_android.sh` / `.ps1` | `android/app/src/main/jniLibs/<abi>/libllama.so` |
| Windows | `scripts/build_llama.cpp_x64.ps1` | `windows/runner/llama.dll` (loaded via exe-relative path) |

Run the script for your target:

```bash
# macOS / iOS host
bash scripts/build_llama.cpp_macos.sh
bash scripts/build_llama.cpp_ios.sh

# Windows host (PowerShell)
.\scripts\build_llama.cpp_x64.ps1

# Android (cross-platform, requires ANDROID_NDK_ROOT)
bash scripts/build_llama.cpp_android.sh
```

For the full reasoning behind CMake flags, integration details, and known
issues, see the deep dives:

- [`scripts/llama.cpp_MacOS_Build.md`](../../scripts/llama.cpp_MacOS_Build.md)
- [`scripts/llama.cpp_iOS_Build.md`](../../scripts/llama.cpp_iOS_Build.md)
- [`scripts/llama.cpp_Android_Build.md`](../../scripts/llama.cpp_Android_Build.md)

### Verify

After the script finishes:

```bash
# macOS — check universal libs are present
ls -la macos/Frameworks/libllama.a
file macos/Frameworks/libllama.a  # should report: "fat file with 2 architectures"

# iOS — check device + simulator libs
ls -la ios/Frameworks/libllama-*.a

# Windows
Test-Path windows\runner\llama.dll

# Android
ls -la android/app/src/main/jniLibs/*/libllama.so
```

## 5. Pigeon Code Generation (optional)

The MLX bridge interface is defined in `pigeons/mlx_inference.dart`. If you modify
that file, regenerate the Dart and Swift glue:

```bash
fvm dart run pigeon --input pigeons/mlx_inference.dart
```

Generated outputs:
- `lib/core/engine/mlx/mlx_inference.g.dart` (Dart side)
- `ios/Runner/MlxBridge/MlxInference.g.swift` (Swift side)

**Do not edit generated files by hand** — they are overwritten on the next run.

You only need this step if you touch the Pigeon schema. For a fresh checkout,
the generated files are already committed; skip this section.

## 6. Platform-Specific Setup

### 6.1 iOS

The iOS Runner needs two things beyond the static llama.cpp libs:

1. **mlx-swift-lm Swift Package**: Should already be wired into the Xcode project
   (added via *Runner project → Package Dependencies*). Confirm `MLXLLM`,
   `MLXLMCommon`, `MLXHuggingFace`, and `Tokenizers` are listed.
2. **Code signing**: For real-device builds, set a development team in
   *Runner target → Signing & Capabilities*. Simulator builds need no signing.

**Verify**:

```bash
fvm flutter build ios --debug --no-codesign
```

Should complete without linker errors. If you see `Undefined symbols for llama_*`,
re-run `scripts/build_llama.cpp_ios.sh`.

### 6.2 macOS

The macOS Runner uses static libs linked via `-force_load` in `OTHER_LDFLAGS`
(set in `macos/Runner.xcodeproj/project.pbxproj`). Entitlements are configured
for:

- App Sandbox (always on)
- `com.apple.security.cs.allow-jit` (Debug only — Flutter JIT)
- `com.apple.security.network.client` (model downloads)

Models are stored at:

```
~/Library/Containers/<bundle-id>/Data/Library/Application Support/<bundle-id>/Models/
```

This path is returned by `getApplicationSupportDirectory()` via `path_provider`.

**Verify**:

```bash
fvm flutter build macos --debug
```

Should succeed and report `1279 llama/ggml symbols found` in the build log.

> **Firebase is intentionally disabled on macOS** in `lib/main.dart` because the
> macOS `GoogleService-Info.plist` is not yet configured. If you add Firebase support
> for macOS, remove the `_isFirebaseSupported` guard.

### 6.3 Windows

The Windows runner links `llama.dll` dynamically. The DLL is placed in
`windows/runner/` and the loader resolves it via an exe-relative path at runtime
(see `lib/core/platform/native_library_loader.dart`).

Currently `WindowsPlatformAdapter.supportsInference = false` until the EP-1
desktop integration tasks ship; the Windows build runs but the UI gates inference
features.

**Verify**:

```powershell
fvm flutter build windows --debug
```

Should complete; resulting binary at `build\windows\x64\runner\Debug\little_star_app.exe`.

### 6.4 Android

`AndroidDirectoryService` writes models to `/storage/emulated/0/Download/LittleStar/models`
so they remain user-visible. The build expects `libllama.so` per ABI in
`android/app/src/main/jniLibs/<abi>/`.

**Verify**:

```bash
fvm flutter build apk --debug
```

## 7. Run the App

Once the platform-specific build completes:

```bash
# iOS simulator or attached device
fvm flutter run -d ios

# macOS
fvm flutter run -d macos

# Windows
fvm flutter run -d windows

# Android emulator or device
fvm flutter run -d android
```

On first launch the Home screen shows the **Recommended Models** list. None are
present locally yet — tap one to download from Hugging Face, or open the Models
screen to add your own GGUF / MLX models.

### Verify

The startup logs should contain:

```
Successfully loaded llama.cpp libraries from <platform> app bundle
```

If you see "Failed to load libraries", revisit Section 4 (llama.cpp build) and
Section 6 (platform setup).

## 8. Models — Download & Placement

### 8.1 In-app download

The simplest path. Use the Models screen:

- **Recommended**: curated list from `lib/config/recommended_models.dart` —
  Gemma 3 270M, Llama 3.2 1B, Qwen 2.5 0.5B, etc.
- **Search Hugging Face**: enter a query; results filtered to GGUF (and MLX
  on Apple Silicon).

Downloaded files land in the platform-specific models directory (see Section
8.2 below) and become available in the Chat / Completion screens.

### 8.2 Manual placement (developer)

If you have a GGUF / MLX model on disk, drop it into the platform's models
directory:

| Platform | Path |
|----------|------|
| iOS (simulator) | `~/Library/Developer/CoreSimulator/Devices/<UDID>/data/Containers/Data/Application/<APP-UUID>/Documents/Models/` |
| macOS | `~/Library/Containers/<bundle-id>/Data/Library/Application Support/<bundle-id>/Models/` |
| Android | `/storage/emulated/0/Download/LittleStar/models/` |
| Windows | `%APPDATA%\<bundle-id>\Models\` |

Relaunch the app; the model appears under "Local Models".

## 9. Troubleshooting

### `pigeon ^22.7.2` blocks `flutter_riverpod` upgrade

Symptom: `fvm flutter pub upgrade` complains that `riverpod 3.x` is incompatible
with `pigeon 22.7.2`.

Cause: `pigeon 22.7.2` transitively pins an older `meta` / `analyzer` that
conflicts with `riverpod 3.x`.

Fix: keep `flutter_riverpod: ^2.6.1` until Pigeon upstream catches up.
Recorded in `pubspec.yaml`. If you bump `flutter_riverpod`, also bump `pigeon`
and regenerate the MLX glue (Section 5).

### `Undefined symbols: _llama_*` at link time

Cause: the llama.cpp static library was not rebuilt for the current target,
or the Frameworks directory is missing from `LIBRARY_SEARCH_PATHS`.

Fix:

```bash
# Mac / iOS: rebuild and clean
bash scripts/build_llama.cpp_macos.sh   # or _ios.sh
fvm flutter clean
fvm flutter pub get
fvm flutter run -d macos
```

For macOS specifically, confirm `OTHER_LDFLAGS` in `macos/Runner.xcodeproj/project.pbxproj`
contains the six `-force_load` entries listed in
[`scripts/llama.cpp_MacOS_Build.md`](../../scripts/llama.cpp_MacOS_Build.md).

### MLX model fails to load on iOS

Symptom: `loadModel` throws `PlatformException(no-model, ...)` or tokenizer
errors.

Likely causes:

1. **SPM resolution failed** — open `ios/Runner.xcodeproj` in Xcode and confirm
   `mlx-swift-lm` 3.31.3 resolved cleanly (*Package Dependencies*).
2. **Model directory layout** — `mlx-swift-lm` expects a directory containing
   `config.json`, `tokenizer.json`, `model.safetensors*`, etc. A single file
   will not work.
3. **AutoTokenizer trust** — the bridge uses `AutoTokenizerLoader` (not
   `MLXHuggingFaceMacros`) to avoid the trust requirement; if you modify
   `MlxInferenceBridge.swift`, keep this loader.

### macOS Runner crashes on launch with Firebase

Cause: `DefaultFirebaseOptions.currentPlatform` throws because no
`GoogleService-Info.plist` is configured for macOS.

Status: intentionally guarded in `lib/main.dart` via `_isFirebaseSupported`.
If a crash still happens, confirm that guard is intact.

### llama.cpp build fails with `metal.h not found` (macOS)

Cause: Xcode CLT incomplete.

Fix:

```bash
xcode-select --install
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

Re-run the build script.

## 10. Next Steps

- Read [`docs/architecture/overview.md`](../architecture/overview.md) to learn how
  the layers fit together.
- Read [`docs/adr/`](../adr/README.md) for the *why* behind specific design choices.
- Read [`CONTRIBUTING.md`](../../CONTRIBUTING.md) (coming in EP-1) for the PR /
  commit workflow.
