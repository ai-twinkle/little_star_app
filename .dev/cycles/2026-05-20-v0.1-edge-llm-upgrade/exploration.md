# v0.1 Edge LLM Upgrade and Refactor - Exploration

- **狀態**: [IN_PROGRESS]
- **建立日期**: 2026-05-20
- **探索模式**: deep [DONE] 使用者已確認
- **目前階段**: 方案評估

## 目標摘要

本循環目標是將 Little Star App 從目前 pre-alpha/alpha 狀態推進到 v0.1，重點包含：

- 更完整的 Edge LLM 工具，涵蓋 Mobile 與 Desktop。
- iOS 與 Android 平台完善至 Beta。
- Windows 與 macOS Desktop 支援至 Alpha。
- 推論後端更新與多樣化：llama.cpp 更新到最新，並支援 MLX 供 iOS/macOS 使用。
- UI/UX 美化與開發者友善度提升：研究可採用的 Design System，支援暗黑模式。
- 整體 App 架構 review，建立更彈性的架構。
- 支援最新 SLM。

## 初始專案背景

- 專案是 Flutter app，目前 `pubspec.yaml` version 為 `0.0.4`，Dart SDK `^3.7.2`。
- README 描述目前核心能力為 on-device GGUF 推論、chat、model manager、completion/performance testing，推論引擎以 `llama.cpp` + FFI 為主。
- 平台目錄已存在 `android/`、`ios/`、`macos/`、`windows/`、`linux/`、`web/`，其中 README 標示 Android/iOS/Desktop 為主要跨平台方向，Desktop 仍 WIP。
- 目前 repo 內有 `lib/core/engine/llama_cpp/llama_cpp_ffi.dart`、`lib/core/lm.dart`、chat/completion/home/models 等 UI feature 模組，以及 download、Hugging Face、directory、logging/crash reporting 等 service。
- `docs/develop_notes/` 已有 llama.cpp FFI、Android/iOS integration、UX analysis、logging/security 等開發筆記。
- `ios/Frameworks/` 已包含多組 llama/ggml static libraries，根目錄有 Windows 相關 DLL，並有未追蹤的 `llama.cpp/` vendor tree。
- 工作樹已有既有變更：Flutter generated plugin registrant 檔案被修改，`cktrace` 與 `llama.cpp/` 未追蹤。本循環文件建立不會處理或覆蓋這些變更。

## 為什麼建議 deep 模式

這次不是單一功能，而是同時牽涉 native inference backend、Apple/Android/Desktop build pipeline、模型相容性、UX design system、dark mode、app 架構與 release 定義。建議採用 deep 探索模式：

1. 問題定義
2. 背景研究
3. 方案發想
4. 方案評估
5. 原型驗證規劃
6. 決策

## 探索範圍草案

### 1. 產品與 release 分級

- 定義 v0.1 的 Beta/Alpha 門檻。
- 區分 mobile beta、desktop alpha、developer experience 與 model support 的必備項/可延後項。
- 明確列出 Android、iOS、Windows、macOS 的驗收指標。

### 2. 推論後端架構

- 將 llama.cpp 從單一 FFI 實作抽象成 backend capability model。
- 評估 MLX 在 iOS/macOS 的整合方式、限制與效能預期。
- 規劃 backend 選擇、session lifecycle、streaming、cancel、token metrics、context window、chat template 與錯誤處理。
- 保留未來擴充其他 runtime 的路徑。

### 3. llama.cpp 更新策略

- 釐清目前 vendor/import 方式：submodule、vendored source、預編 binary、平台專用 framework/DLL。
- 定義同步最新 llama.cpp 的流程、patch 管理、build script、CI 驗證與 artifact 命名。
- 評估新版本 API/ABI 對現有 FFI wrapper 的破壞性。

### 4. MLX 支援

- iOS/macOS 優先評估 Swift/Objective-C bridge、FFI 或 platform channel 的整合方式。
- 設計與 llama.cpp 共用的 Dart 層抽象，避免 UI/feature 直接依賴特定 runtime。
- 定義模型格式、下載來源、快取策略與 fallback 行為。

### 5. 最新 SLM 支援

- 建立模型 catalog/profile 概念：model family、format、quantization、backend compatibility、RAM/VRAM/ANE/GPU/CPU 建議、license。
- 針對 mobile 與 desktop 分別定義推薦模型與最低設備需求。
- 明確區分 GGUF 模型與 MLX-native 模型。

### 6. UI/UX 與 Design System

- 釐清此處的 "System Design" 是否指 UI Design System，或是 app/system architecture design。
- 研究 Flutter 可落地的 design system 選項，優先考慮 Material 3、adaptive layout、desktop controls、accessibility 與 dark mode。
- 規劃 shared theme tokens、component primitives、responsive/adaptive navigation、developer/debug surface。

### 7. App 架構 review

- Review `lib/core`、`lib/data`、`lib/ui` 的責任邊界。
- 評估是否需要建立 domain/application 層、backend registry、model repository、session state manager、feature-level view models。
- 梳理 native build scripts、platform artifacts、docs 與 CI 的 ownership。

## 待釐清問題

1. v0.1 的正式 release criteria 是什麼？例如 mobile beta 是否必須完成模型下載、聊天、completion、錯誤回報、基本 benchmark？
2. Desktop Alpha 是否只包含 Windows/macOS？目前 `linux/` 與 `web/` 要列入、保留、還是明確延後？
3. MLX 目標是「可執行推論」即可，還是要達到與 llama.cpp 同等的 chat/streaming/model manager 體驗？
4. 最新 SLM 的第一批目標模型家族與限制是什麼？例如 Llama、Qwen、Gemma、Phi、SmolLM、Mistral；是否有 license 或 Hugging Face repo 偏好？
5. Design System 方向偏向 Material 3 / Fluent / Apple-like adaptive / 自訂品牌？是否需要先保留目前 Twinkle AI 視覺語言？
6. 是否接受為 v0.1 做較大的 app 分層重構，還是希望先以 facade/adapter 漸進重構降低風險？
7. 是否需要本循環包含 CI/CD、release packaging、測試矩陣與 benchmark 報告？

## 背景研究待辦

- [DONE] 查證 2026-05-20 時點 llama.cpp 最新版本、C API/Swift/Android example、build/runtime 變動。
- [DONE] 查證 MLX/MLX Swift/MLX LM 在 iOS/macOS 的現況與限制。
- [DONE] 查證 2026 年主流 SLM family、edge/mobile 適配、格式與 license。
- [DONE] 查證 Flutter 目前 Material 3、adaptive UI、desktop app design、dark mode 最佳實務。
- [DONE] 對照現有 `docs/develop_notes/` 與 `docs/roadmap/`，整理可繼承的決策與需要更新的假設。

## 背景研究 Round 1

### 本機架構觀察

- `docs/roadmap/core/unified_lm_extensibility_study.md` 已明確指出目前 `UnifiedLM` 直接耦合 `LlamaCppFFI`，並已有 `InferenceEngine`、`EngineRegistry`、dependency injection 的初步構想。
- `lib/core/lm.dart` 目前在 `UnifiedLM.init()` 直接建立 `LlamaCppFFI()`，chat/completion view model 也直接持有 `UnifiedLM`。這表示 v0.1 要支援 MLX 時，第一個重構切點應該是建立 runtime/backend facade，而不是先在 UI 加平台分支。
- `lib/core/engine/llama_cpp/llama_cpp_ffi.dart` 註記目前對應 llama.cpp `b7493`；2026-05-20 查證最新 release 為 `b9245`，中間落差很大，需先做 C API/ABI 差異盤點。
- `lib/main.dart` 目前只設定 `theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.amber), useMaterial3: true)`，尚未有 `darkTheme`、`themeMode`、設計 token 層或 adaptive navigation shell。
- `docs/develop_notes/alpha.2-00_*ux*` 已建立首頁推薦模型、一鍵下載、badge、loading skeleton、onboarding 等 UX 決策。v0.1 不應推翻這些成果，而應把它們納入正式 design system。

### 外部技術查證

- llama.cpp: GitHub release 頁在 2026-05-20 顯示最新 release `b9245`，時間為 2026-05-20 04:13。該 release 已列出 macOS arm64、macOS x64、iOS XCFramework、Android arm64、Windows x64/arm64、CUDA/Vulkan/SYCL/HIP 等 artifacts。來源: https://github.com/ggml-org/llama.cpp/releases/
- llama.cpp README 仍強調 C/C++ local inference、Apple silicon via ARM NEON/Accelerate/Metal、x86 AVX/AMX、Vulkan/SYCL/CUDA/HIP、CPU+GPU hybrid，並列出 Qwen、Phi、Gemma、SmolLM、LFM2 等多種 text-only model family。來源: https://github.com/ggml-org/llama.cpp
- MLX core: `ml-explore/mlx` 最新 release 顯示 `v0.31.2`，日期 2026-04-22，定位為 Apple silicon array framework。來源: https://github.com/ml-explore/mlx
- MLX Swift: Swift Package Index 顯示 `mlx-swift` 最新 release `0.31.3`，相容矩陣包含 iOS、macOS、visionOS、watchOS、tvOS、Linux、Wasm、Android。來源: https://swiftpackageindex.com/ml-explore/mlx-swift/
- MLX Swift LM: 官方 repo 已把 LLM/VLM reusable libraries 移至 `mlx-swift-lm`，提供 model loading、tokenizer/downloader integration、LoRA/full fine-tuning、quantized model support、多種 LLM/VLM architecture。來源: https://github.com/ml-explore/mlx-swift-lm
- MLX Swift Examples: 官方 examples 包含 `LLMBasic`、`LLMEval`、`MLXChatExample`，可在 iOS/macOS 下載 Hugging Face LLM/tokenizer 並生成文字。來源: https://github.com/ml-explore/mlx-swift-examples
- Qwen3: 官方 Qwen blog 顯示 dense models 包含 `0.6B`、`1.7B`、`4B`、`8B`、`14B`、`32B`，Apache 2.0；`0.6B/1.7B/4B` 皆 32K context，是 v0.1 edge SLM catalog 的強候選。來源: https://qwenlm.github.io/blog/qwen3/
- Gemma 3n: Google 文件定位為適用於手機、筆電、平板等 everyday devices，支援 reduced effective parameters、audio/text/visual data。來源: https://ai.google.dev/gemma/docs/gemma-3n
- Llama 3.2: Meta 官方文章明確定位 `1B`、`3B` text-only models 可 fit edge/mobile devices。來源: https://ai.meta.com/blog/llama-3-2-connect-2024-vision-edge-mobile-devices/
- Phi-4-mini: Microsoft/Hugging Face model card 表示 Phi-4-mini-instruct 是 lightweight open model，支援 128K token context，並已有 llama.cpp/Ollama/LM Studio compatible quantization 入口。來源: https://huggingface.co/microsoft/Phi-4-mini-instruct
- SmolLM: Hugging Face repo 定位為 fully open、compact、可 on-device run 的 text/vision model family，license 為 Apache-2.0。來源: https://github.com/huggingface/smollm
- Flutter: 2026-05-20 時官方 docs 反映 Flutter `3.44.0`，Material 3 是現行設計語言；Flutter adaptive docs 建議 abstract/measure/branch，並以 `<600dp` bottom navigation、`>=600dp` navigation rail 作為 Material breakpoint 參考。來源: https://docs.flutter.dev/ui/adaptive-responsive/general
- Flutter Theme: 官方 recipe 建議透過 `MaterialApp.theme`/`ThemeData`/`ColorScheme.fromSeed` 建立 app-wide theme，並可透過 `brightness: Brightness.dark` 建立 dark scheme。來源: https://docs.flutter.dev/cookbook/design/themes
- Flutter Material 3 ColorScheme: 最新 docs 指出 `ColorScheme.fromSeed` 已採用較新的 Material color utilities 演算法，並有新的 tone-based surface/container roles。來源: https://docs.flutter.dev/release/breaking-changes/new-color-scheme-roles

## 問題定義 v1

v0.1 的核心問題不是「再接一個後端」，而是目前 app 的推論、模型、平台 artifacts、UI state 與 design tokens 都還沒有足夠穩定的擴充邊界。若直接把 MLX 或 desktop 支援塞進現有 `UnifiedLM`，會導致平台分支擴散到 UI/ViewModel、build script 與模型下載邏輯。

初步問題定義：

1. 需要建立可描述能力的 inference backend 架構：`llama.cpp` 與 `MLX` 都應是 backend implementation，而不是 UI 直接依賴的特殊分支。
2. 需要建立 model catalog/profile：同一個模型 family 可能有 GGUF、MLX、LiteRT、ONNX、原始 HF weights 等不同 runtime artifacts。
3. 需要建立平台 release matrix：Android/iOS beta 與 Windows/macOS alpha 不能用相同成熟度門檻。
4. 需要把 UI/UX 從目前單一 Material 3 seed theme 升級成可維護 design system：theme tokens、dark mode、adaptive navigation、desktop-friendly controls、developer diagnostics。
5. 需要先定義 native artifact ownership：llama.cpp latest 更新、iOS XCFramework、Android arm64、Windows DLL、macOS dylib/xcframework、MLX Swift package 都需要版本、來源、驗證流程與回滾策略。

## 初步方案方向

### A. 推論層重構優先

- 建立 `InferenceBackend` / `InferenceSession` / `BackendCapabilities` / `ModelProfile`。
- `LlamaCppBackend` 包裝現有 `LlamaCppFFI`，先保持 UI 行為不變。
- `MlxBackend` 先走 iOS/macOS native bridge prototype，不直接污染 Dart UI 層。
- `UnifiedLM` 改為 compatibility facade，避免一次改動所有 ViewModel。

### B. v0.1 release 分階段

- Mobile Beta: Android/iOS 的 GGUF llama.cpp 穩定、model manager 穩定、chat/completion streaming/cancel/error handling 可用、dark mode 可用、基本 benchmark/reporting 可用。
- Apple MLX Alpha: iOS/macOS 先證明 MLX backend 可 load/generate/stream/statistics，模型 catalog 能標示 MLX-compatible models。
- Desktop Alpha: Windows/macOS 先完成 artifact loading、model directory、chat/completion、error diagnostics、basic packaging；Linux/Web 建議列為 out-of-scope 或 experimental。

### C. Design System 採 Material 3 為基底

- 以 Material 3 + app-specific tokens 為主，不另引入大型第三方 UI framework。
- 先建立 `AppTheme`、`AppColorTokens`、`AppSpacing`、`AppTypography`、`AppBreakpoints`、`AppThemeModeController`。
- Android/iOS/mobile 使用 bottom navigation；tablet/desktop 使用 navigation rail 或 drawer；developer diagnostics 使用 desktop-friendly dense layout。
- dark mode 使用 `ColorScheme.fromSeed(... brightness: Brightness.dark)` 起步，再針對 chart/log/status/badge 補足 semantic colors。

### D. SLM catalog 第一批候選

- GGUF/llama.cpp: Qwen3 0.6B/1.7B/4B、Gemma 3 270M/1B/3n E2B/E4B、Llama 3.2 1B/3B、Phi-4-mini、SmolLM/SmolLM3。
- Apple MLX: 優先選 mlx-community 或官方 examples 能直接支援的 Qwen/Gemma/Phi/SmolLM family。
- catalog 需記錄 license、format、runtime、context length、recommended quantization、minimum RAM、intended tasks、download source。

## 下一輪需要決策

1. v0.1 是否同意採「推論層重構優先」：先把 `UnifiedLM` 解耦，再升 llama.cpp/接 MLX？
2. Desktop Alpha 是否只納入 Windows/macOS，把 Linux/Web 明確標為 experimental/out-of-scope？
3. MLX 的 v0.1 目標是 prototype alpha，還是要納入 iOS/macOS Beta 品質？
4. Design System 是否以 Material 3 + 自訂 token 為主，保留 Twinkle AI 既有品牌色與首頁成果？
5. 第一批 SLM 是否以 `Qwen3 0.6B/1.7B/4B`、`Gemma 3 270M/1B/3n`、`Llama 3.2 1B/3B` 為核心，Phi/SmolLM 作為補充？

## 決策 Round 1

| 決策 | 結論 | 影響 |
|------|------|------|
| 推論層策略 | [DONE] 先做 `UnifiedLM` 解耦，再升 llama.cpp / 接 MLX。 | v0.1 第一個技術主線是 backend abstraction，不直接在 UI/ViewModel 加 runtime 分支。 |
| Desktop 範圍 | [DONE] Desktop Alpha 限定 Windows + macOS；Linux/Web 先 out-of-scope。 | release matrix 聚焦四個目標平台：Android/iOS beta、Windows/macOS alpha。 |
| MLX 成熟度 | [DONE] MLX 在 v0.1 定位為 Apple Alpha prototype。 | MLX 驗收以 load/generate/stream/statistics 原型為主，不要求 iOS/macOS beta 品質。 |
| Design System | [DONE] 採 Material 3 + Twinkle AI 自訂 tokens。 | 保留既有品牌與首頁成果，新增 theme tokens、dark mode、adaptive navigation。 |
| 第一批 SLM | [DONE] 以 Qwen3、Gemma 3/3n、Llama 3.2 為核心；Phi/SmolLM 作為補充。 | model catalog 初版以這些 family 建 profile、runtime compatibility 與推薦量化策略。 |

## 方案發想輸入

下一輪方案發想應圍繞 5 條主線：

1. **Inference Backend Abstraction**
   - 將 `UnifiedLM` 改為 compatibility facade。
   - 新增 `InferenceBackend`、`InferenceSession`、`BackendCapabilities`、`InferenceRequest`、`InferenceResult`、`TokenStreamEvent`。
   - 第一個 concrete backend 是 `LlamaCppBackend`，包住現有 `LlamaCppFFI`。

2. **llama.cpp Upgrade Track**
   - 從目前 `b7493` 升至最新 release 線。
   - 先做 API/ABI diff、artifact inventory、build script 對齊，再動 FFI struct/function binding。
   - Android/iOS 是 beta gate，Windows/macOS 是 alpha gate。

3. **Apple MLX Alpha Prototype**
   - 使用 `mlx-swift-lm` / `mlx-swift-examples` 作為參考。
   - 先用 iOS/macOS native bridge 證明 load/generate/stream/statistics。
   - Dart 層只透過同一個 `InferenceBackend` contract 存取。

4. **Model Catalog and SLM Support**
   - 建立 `ModelProfile` / `RuntimeArtifact` / `RecommendedRuntime`。
   - 初版核心 family: Qwen3 0.6B/1.7B/4B、Gemma 3 270M/1B/3n、Llama 3.2 1B/3B。
   - Phi-4-mini、SmolLM/SmolLM3 作為補充與比較組。

5. **Material 3 Design System**
   - 新增 `AppTheme`、`AppColorTokens`、`AppSpacing`、`AppTypography`、`AppBreakpoints`。
   - 支援 `theme` / `darkTheme` / `themeMode`。
   - 將既有首頁 UX 成果納入正式 component/token 規範。
   - Mobile 使用 bottom navigation；tablet/desktop 使用 rail/drawer。

## 方案評估

### 評估準則

本輪用以下準則評估 v0.1 方案：

- **Release fit**: 能否直接支援 Android/iOS Beta、Windows/macOS Alpha 的目標。
- **Blast radius**: 是否會一次牽動過多 UI/ViewModel/native build/FFI 程式碼。
- **Runtime extensibility**: 是否能自然容納 llama.cpp、MLX 與未來 runtime。
- **Testability**: 是否能在沒有真機或大模型時做單元測試與 contract test。
- **Developer experience**: 是否能讓後續 backend、model catalog、design system 的工作可拆分、可驗證。
- **User continuity**: 是否保留既有 chat/completion/model manager/首頁體驗。

### 方案 1: Big-bang 重寫推論與 UI 架構

- **做法**: 直接替換 `UnifiedLM`、ViewModel、model manager、theme/navigation，並同步升級 llama.cpp、接 MLX。
- **優點**: 目標架構最乾淨，一次清掉歷史負債。
- **缺點**: 風險最高；chat/completion/download/theme/native artifact 同時變動，任何一處失敗都會阻塞 v0.1。
- **評估**: 不建議。這會把 Beta/Alpha release 目標綁死在大範圍重構上，驗證成本過高。

### 方案 2: Compatibility facade + backend adapter

- **做法**: 保留 `UnifiedLM` 作為 compatibility facade，新增 backend contract 與 `LlamaCppBackend` adapter；Chat/Completion ViewModel 先不大改，逐步導入 backend registry、session lifecycle、model profile。
- **優點**:
  - 可以先維持既有 UI 行為。
  - llama.cpp 升級與 MLX prototype 都能走同一個 backend contract。
  - 測試可以從 fake backend/session 開始，不必依賴大型模型與 native binary。
  - 風險可切成多個小步：contract -> llama adapter -> callsite migration -> llama upgrade -> MLX bridge。
- **缺點**:
  - 短期會同時存在 `UnifiedLM` facade 與新 backend API。
  - 需要明確定義 compatibility boundary，避免新舊 API 混用失控。
- **評估**: 推薦主方案。最符合 v0.1 的風險控制與多 runtime 目標。

### 方案 3: Runtime-specific product tracks

- **做法**: llama.cpp 繼續走現有 `UnifiedLM`，MLX 另做 Apple-only native/plugin flow，UI 依平台切換。
- **優點**: MLX prototype 可能最快看到結果。
- **缺點**: runtime 邏輯會外溢到 UI/ViewModel/model manager，後續 catalog、metrics、error handling 會重複實作。
- **評估**: 只適合作為 MLX native spike，不適合作為 app 架構方向。

### 推薦架構路線

採 **方案 2: Compatibility facade + backend adapter**，並切成四個層次：

1. **Contract 層**
   - `InferenceBackend`: 描述 backend 名稱、支援平台、支援格式與 capability。
   - `InferenceSession`: 管理單一模型載入後的 completion/chat/tokenization/metrics/cancel/dispose。
   - `InferenceRequest`: prompt/messages、sampling、max tokens、stop sequences、streaming flags。
   - `InferenceEvent`: token chunk、metrics、warning、finish、error。
   - `ModelProfile`: model family、runtime artifacts、license、recommended quantization、memory guidance。

2. **Adapter 層**
   - `LlamaCppBackend` 包裝現有 `LlamaCppFFI`。
   - `MlxBackend` 先是 Apple-only prototype adapter，底層用 platform channel 或 Flutter plugin bridge 到 Swift。
   - `FakeBackend` 用於 ViewModel 與 contract tests。

3. **Facade 層**
   - `UnifiedLM` 保留現有 public API，內部委派給 `InferenceBackend` / `InferenceSession`。
   - Chat/Completion ViewModel 初期仍使用 `UnifiedLM`，降低遷移風險。
   - 後續再讓 ViewModel 直接依賴 use case/service，而不是直接 new `UnifiedLM`。

4. **Selection 層**
   - `BackendRegistry` 根據 platform、model profile、artifact format、user preference 選 runtime。
   - v0.1 初期規則：
     - Android: llama.cpp / GGUF
     - iOS: llama.cpp / GGUF beta, MLX alpha opt-in
     - Windows: llama.cpp / GGUF alpha
     - macOS: llama.cpp / GGUF alpha, MLX alpha opt-in
     - Linux/Web: out-of-scope

### 推論層風險與處理

- **直接耦合風險**: `ChatViewModel` 與 `CompletionViewModel` 目前直接 `UnifiedLM(modelPath)`，換模型時也直接 new，沒有明確釋放舊 session。  
  **處理**: `UnifiedLM` facade 補 `dispose` 與 session ownership；後續改成注入 service/factory。

- **取消生成風險**: 目前 cancel 主要取消 Dart stream subscription，不一定會中止 native decode。  
  **處理**: backend contract 定義 `cancel()`；llama.cpp adapter 後續接 `abort_callback` 或 cooperative flag。

- **token count side effect**: 目前 `countPromptTokens()` 註解指出會準備 internal batch。  
  **處理**: contract 將 `countTokens()` 規定為 non-mutating；若 backend 做不到，需用 isolated tokenizer context 或明確記錄限制。

- **stop sequence 分散**: stop sequence 現在主要由 ViewModel 檢查，runtime 不知道停止原因。  
  **處理**: `InferenceEvent.finishReason` 統一回傳 `length` / `stop_sequence` / `eog` / `cancelled` / `error`。

### llama.cpp 升級方案評估

可選方案：

1. **只使用官方 release artifacts**
   - 優點: 快速取得 Android/iOS/macOS/Windows binary。
   - 缺點: patch、build flags、debug symbols、reproducibility 受限。

2. **完整 vendored source + 自建 artifacts**
   - 優點: 可控、可重現、方便 patch。
   - 缺點: 建置矩陣重，v0.1 初期會拖慢進度。

3. **Hybrid**
   - 優點: Alpha/prototype 可先用官方 artifacts 或現有 scripts，加速驗證；Beta gate 再建立自建與 artifact manifest。
   - 缺點: 需要管理兩種 artifact source 的規範。

推薦採 **Hybrid**：

- 先以最新 release 線做 C API/ABI diff，確認 FFI struct/function 是否仍匹配。
- 建立 `native/artifacts/manifest` 或 docs，記錄 source、version、platform、arch、checksum、build flags。
- Android/iOS Beta gate 需要可重現 build script 或至少有清楚的 artifact provenance。
- Windows/macOS Alpha 可以先接受較低成熟度，但仍需啟動 smoke test。

### Apple MLX Alpha 方案評估

可選方案：

1. **Dart FFI 直接接 MLX Swift/C++**
   - 優點: 理論上可低 overhead。
   - 缺點: MLX Swift 的 app integration 更接近 Swift package/native layer，直接 FFI 成本高。

2. **Platform channel / Flutter plugin bridge**
   - 優點: 最符合 iOS/macOS prototype；能直接使用 Swift package、async stream、Apple 平台工具鏈。
   - 缺點: streaming event 與 large tensor/model lifecycle 要設計好。

3. **獨立 native sample app 先驗證**
   - 優點: 最快排除 MLX Swift model loading/streaming/packaging 問題。
   - 缺點: 不直接接到 Flutter app。

推薦採 **2 + 3 的組合**：

- 先做最小 native spike：使用 MLX Swift LM 在 iOS/macOS 載入一個小模型並生成文字。
- 通過後建立 Flutter platform channel prototype，對齊 `InferenceBackend` contract。
- MLX Alpha 驗收只要求 load/generate/stream/basic stats/error surface，不納入 mobile beta 阻塞條件。

### Model Catalog 方案評估

目前 `RecommendedModels` 是 GGUF-centric 靜態推薦列表，適合 alpha UX，但不足以支援 v0.1 多 runtime。

推薦演進方式：

- 保留 `RecommendedModelConfig` 作為 UI compatibility layer。
- 新增 `ModelProfile` 作為 source of truth，描述 model family 與 artifact。
- `RecommendedModels` 改成從 profile 派生 mobile/desktop/MLX 推薦清單。
- 每個 artifact 至少包含：runtime、format、repo id、filename pattern、recommended quantization、size、license、minimum RAM、platform support。

首批 profile 分層：

- Core: Qwen3 0.6B/1.7B/4B、Gemma 3 270M/1B/3n、Llama 3.2 1B/3B。
- Supplemental: Phi-4-mini、SmolLM/SmolLM3。
- 每個 profile 需至少有 GGUF artifact；MLX artifact 可先標 alpha/experimental。

### Design System 方案評估

可選方案：

1. **繼續局部 ThemeData**
   - 優點: 最小改動。
   - 缺點: dark mode、desktop density、semantic colors 會散落到 widgets。

2. **Material 3 + Twinkle tokens**
   - 優點: 與 Flutter 現有 `useMaterial3` 一致；能保留品牌與首頁成果；dark mode/adaptive navigation 可漸進導入。
   - 缺點: 初期需整理 token 與 component usage。

3. **導入大型第三方 design system**
   - 優點: 某些 desktop controls 可能更完整。
   - 缺點: 依賴與視覺遷移成本高，不符合目前 v0.1 風險控制。

推薦採 **Material 3 + Twinkle tokens**：

- `AppTheme.light()` / `AppTheme.dark()` 建立正式 theme。
- `AppSpacing`、`AppBreakpoints`、`AppMotion`、`AppSemanticColors` 先服務既有首頁、模型卡、下載狀態、benchmark metrics。
- `MaterialApp` 補 `darkTheme` / `themeMode`。
- `AdaptiveShell` 在 mobile bottom nav、tablet/desktop rail/drawer 間切換。

### 推薦執行順序

1. **Phase 0: Baseline and guardrails**
   - 記錄目前工作樹與 native artifacts。
   - 建立最小 smoke tests/fake backend tests。
   - 定義 release matrix 與 out-of-scope。

2. **Phase 1: Inference contract**
   - 新增 backend/session/request/event/model profile contract。
   - 用 fake backend 做 ViewModel 不依賴 native 的測試。

3. **Phase 2: Llama adapter**
   - 以現有 `LlamaCppFFI` 包成 `LlamaCppBackend`。
   - `UnifiedLM` 改為 facade，保持 Chat/Completion 行為。

4. **Phase 3: Model catalog**
   - 導入 `ModelProfile`，保留 `RecommendedModels` compatibility。
   - 建立首批 SLM profile。

5. **Phase 4: Design system and dark mode**
   - 建立 Material 3 + Twinkle tokens。
   - 補 dark mode 與 adaptive shell。

6. **Phase 5: llama.cpp latest**
   - API/ABI diff、artifact manifest、平台 smoke test。
   - Android/iOS 作 Beta gate；Windows/macOS 作 Alpha gate。

7. **Phase 6: Apple MLX Alpha**
   - Native spike -> Flutter bridge -> backend adapter。
   - 僅作 alpha opt-in，不阻塞 mobile beta。

### 評估結論

v0.1 應採取「先穩住邊界，再更新 runtime」的路線。具體建議是：

- 主架構採 **Compatibility facade + backend adapter**。
- llama.cpp 採 **Hybrid artifact strategy**。
- MLX 採 **Apple Alpha prototype**，用 platform channel / Flutter plugin bridge。
- model catalog 從 GGUF-centric 推薦清單演進為 runtime-aware profile。
- design system 採 **Material 3 + Twinkle AI tokens**，先補 dark mode 與 adaptive navigation。

此評估可直接轉入定義期 `plan.md`，拆成研究、設計、程式、配置、驗證五類任務。

## 討論記錄

| 日期 | 重點 | 待辦 |
|------|------|------|
| 2026-05-20 | 使用者提出 v0.1 大幅升級與重構目標；已建立初始探索範圍並建議 deep 模式。 | 等待確認 deep 探索模式，並回答優先釐清問題。 |
| 2026-05-20 | 使用者確認採用 deep 探索模式。開始對照本機架構文件與外部最新技術背景。 | 進行背景研究，整理第一輪問題定義與方案方向。 |
| 2026-05-20 | 完成第一輪背景研究；確認 llama.cpp 最新 release、MLX Swift/Swift LM 可行性、edge SLM 候選與 Flutter Material 3/adaptive/dark mode 方向。 | 等待使用者對推論層重構、Desktop 範圍、MLX 成熟度、Design System 與 SLM 首批清單做決策。 |
| 2026-05-20 | 使用者確認五項核心決策：推論層重構優先、Linux/Web out-of-scope、MLX Apple Alpha prototype、Material 3 + Twinkle tokens、第一批 SLM 核心清單。 | 進入方案發想與評估，整理 v0.1 工作流與任務拆分。 |
| 2026-05-20 | 完成方案評估；推薦 Compatibility facade + backend adapter、Hybrid llama.cpp artifact strategy、MLX Apple Alpha prototype、runtime-aware model catalog、Material 3 + Twinkle tokens。 | 等待確認評估結論，下一步進入原型驗證規劃或定義期任務拆分。 |
