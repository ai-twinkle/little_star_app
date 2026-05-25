# Construction Progress — v0.1 Major Refactor

Cycle: `2026-05-21-v0.1-major-refactor`

---

## EP-0 Spikes

### task-001: MLX Hello World on iOS Spike 🔬🔧
Branch: `spike/ep0-mlx-hello-world`  
Commit: `2b26f1c`

- [x] Step 1: 調查 (mlx-swift-lm v3.x API + Pigeon v22 EventChannelApi pattern)
- [x] Step 2: 原型 (Pigeon codegen → MlxInferenceBridge.swift → mlx_channel.dart)
- [ ] Step 3: 量測 — **BLOCKED: needs Mac + iPhone (iOS 16+)**
- [ ] Step 4: 結論 — depends on step 3

**Key findings:**
- mlx-swift-lm v3.x: `LLMModelFactory.shared.loadContainer` + `MLXLMCommon.generate(didGenerate:)`
- Pigeon `@EventChannelApi` generates `OnTokenStreamHandler: PigeonEventChannelWrapper<T>` → subclass + capture `PigeonEventSink`
- SPM deps needed: `MLXLLM`, `MLXLMCommon`, `MLXHuggingFace`, `HuggingFace`, `Tokenizers`

---

### task-002: macOS llama.cpp Build Spike 🔬⚙️
Branch: `spike/ep0-macos-llama-build`

- [x] Step 1: 調查 (cmake flags for static macOS build; `-force_load` requirement for debug dylib; entitlement audit)
- [x] Step 2: 寫 script (`scripts/build_llama.cpp_macos.sh` — arm64 + x86_64 universal static via lipo)
- [x] Step 3: 整合驗證 (`flutter build macos` ✅; `DynamicLibrary.process()` finds 1279 symbols; `llama_backend_init` + Metal active; `loadModel` success)
- [x] Step 4: 結論 (full `completion` run verified on macOS — gemma-3-270m-it-Q4_K_M.gguf; Prefill 6.85 tps / Decode 164.43 tps; no errors)

**Key findings:**
- Use `BUILD_SHARED_LIBS=OFF` + `GGML_METAL_EMBED_LIBRARY=ON` for self-contained static libs
- Must use `-force_load` in `OTHER_LDFLAGS`; without it, linker dead-strips unused llama symbols in Flutter debug mode
- In Flutter macOS debug, static libs land in `little_star_app.debug.dylib` (not the 57K runner binary); `DynamicLibrary.process()` searches all loaded images, so it finds them
- Metal GPU: `EMBED_LIBRARY=1` works — no separate `.metallib` needed
- Firebase is not configured for macOS — excluded `Platform.isMacOS` from `_isFirebaseSupported` in `main.dart`
- `MacOSPlatformAdapter.supportsInference` kept `false` until EP-7 (task-701)
- **Measured performance** (Apple Silicon, gemma-3-270m-it-Q4_K_M.gguf, debug mode): Prefill ~6.85 tps / Decode ~164.43 tps; no errors

**Build note:** `macos/Podfile` must set `platform :osx, '13.0'` (not 10.14) to satisfy firebase_core pod requirement. `lib/firebase_options.dart` is gitignored (contains API keys) — a stub file is needed for non-Firebase platforms (macOS build).

**Files delivered:**
- `scripts/build_llama.cpp_macos.sh` — build script (arm64 + x86_64 + universal via lipo)
- `scripts/llama.cpp_MacOS_Build.md` — build + integration + entitlements documentation
- `macos/Frameworks/libllama.a`, `libggml*.a` — 6 universal static libraries
- `macos/Runner.xcodeproj/project.pbxproj` — added `-force_load` + static lib flags + Metal/Accelerate
- `lib/core/engine/llama_cpp/llama_cpp_ffi.dart` — macOS branch → `DynamicLibrary.process()`
- `lib/main.dart` — excluded macOS from Firebase initialization

---

### task-003: Platform Adapter Skeleton Spike 🔬🔧
Branch: `spike/ep0-platform-adapter`  
Commit: `7aad50f`

- [x] Step 1: 調查 (directory paths, entitlement gaps, inline Platform.isX audit)
- [x] Step 2: 原型 (MacOsDirectoryService, WindowsDirectoryService, DirectoryServiceFactory, PlatformAdapter skeleton)
- [x] Step 3: 驗證 (`flutter analyze` — 0 new errors in changed files)
- [x] Step 4: 結論

**Key findings:**
- `DesktopDirectoryService` used `Directory.current.path` — wrong for deployed apps; demoted to Linux-only fallback
- macOS: `getApplicationSupportDirectory()/Models` — sandbox-safe
- Windows: `Documents/LittleStar/Models` — user-visible, no sandbox issues
- macOS entitlements were missing `com.apple.security.network.client` → downloads would fail in sandbox
- Platform factory pattern centralised: `DirectoryServiceFactory.create()` + `PlatformAdapterFactory.create()`
- `PlatformAdapter.supportsInference` flags Desktop as `false` until EP-1/EP-2

**Files delivered:**
- `lib/data/services/directory_service.dart` — added `MacOsDirectoryService`, `WindowsDirectoryService`, `DirectoryServiceFactory`
- `lib/core/platform/platform_adapter.dart` — new skeleton with all platform adapters
- `lib/ui/home/widgets/home_screen.dart` — replaced inline `Platform.isX` with factory
- `lib/ui/completion/widgets/model_selection_dialog.dart` — same
- `macos/Runner/DebugProfile.entitlements` + `Release.entitlements` — added `network.client`

---

## Blocked

- task-001 steps 3–4: need Mac + iPhone with iOS 16+
