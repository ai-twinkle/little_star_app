# 計畫：v0.1 架構重構與後端抽象化

> 循環：2026-05-21-v0.1-major-refactor
> 階段：Definition
> 狀態：🔄 草稿，待用戶 review

---

## 目標

把 `little_star_app` 的推論層從緊耦合 llama.cpp 重構為**可抽換、可擴展的多後端架構**，新增 MLX 支援，並讓 Desktop（Windows / macOS）能跑通最小流程。

---

## Release 節奏

**Epic-based internal build**：每完成一個 epic 即可出 internal build，不設明確發布日期。

Epic 間依賴關係：

```
EP-0 Spikes ─┬──────────────────┐
             │                  │
             ▼                  ▼
EP-1 Foundation ─────────► EP-2 Inference Backend ─────► EP-3 Prompt Layer
             │                  │                            │
             │                  ▼                            ▼
             │             EP-5 ModelProfile        EP-6 VM Slim & Migrate
             ▼                  ▲
EP-4 Platform Abstraction ──────┘
             │
             ▼
EP-7 macOS Build  ─┐
EP-8 Windows DLL   ├─► EP-9 Desktop Demo
EP-10 MLX Backend ─┘

(平行 after EP-3 + EP-5 + EP-6) EP-12 SLM 適配（Gemma 4 / Llama 3.2 / Qwen 3.5）
(平行) EP-11 Design System 調查報告
```

---

## 任務清單

### EP-0：Spikes（先期驗證）

#### task-001: MLX Hello World on iOS Spike
- **類型**: 🔬 研究 + 🔧 程式（throw-away prototype）
- **狀態**: [TODO]
- **描述**: 在獨立的 spike branch 整合 `mlx-swift-lm`（SPM），透過 Pigeon channel 從 Dart 端載入 `mlx-community/Llama-3.2-1B-Instruct-4bit`，跑出第一段 streaming 輸出。產出 bridge 介面草案。
- **建議方式**: 調查 → 原型 → 量測 → 結論
- **驗收標準**:
  - [ ] mlx-swift-lm SPM 在 iOS Runner 整合成功
  - [ ] Pigeon streaming channel pattern 跑通（Swift → Dart token-by-token）
  - [ ] 至少一個 mlx-community 模型可載入並 generate
  - [ ] 量測 token rate；與 llama.cpp 同機型比較
  - [ ] 產出 bridge interface 草案文件（用於 EP-10）
- **預估時間**: 2-3 天
- **依賴**: 無

#### task-002: macOS llama.cpp Build Spike
- **類型**: 🔬 研究 + ⚙️ 配置
- **狀態**: [TODO]
- **描述**: 用 `llama.cpp/` (b7493) 源碼編出 macOS arm64 + x86_64 universal static library，整合進 `macos/Runner`，可 `flutter run -d macos` 載入既有 GGUF 並推論。
- **建議方式**: 調查 build option → 寫 script → 整合驗證
- **驗收標準**:
  - [ ] `scripts/llama.cpp_MacOS_Build.md` 文件產出
  - [ ] `macos/Frameworks/libllama.a`（universal）build 成功
  - [ ] FFI loader 加 `Platform.isMacOS` 分支可解析 native symbols
  - [ ] 在 macOS 上完成一次 GGUF 推論（loadModel → completion）
  - [ ] code signing / entitlements 處理流程記錄
- **預估時間**: 2-3 天
- **依賴**: Apple Silicon Mac 可及性（用戶手邊有但受限）

#### task-003: Platform Adapter Skeleton Spike
- **類型**: 🔬 研究 + 🔧 程式
- **狀態**: [TODO]
- **描述**: 為 macOS / Windows 補 `DirectoryService` 實作，建立 `PlatformAdapter` 雛形。App 能在 Desktop boot、掃模型資料夾、下載模型，不需推論。
- **建議方式**: 調查既有 pattern → 補實作 → Desktop 上跑通
- **驗收標準**:
  - [ ] `MacOsDirectoryService` 與 `WindowsDirectoryService` 完成
  - [ ] `flutter run -d windows` 與 `-d macos` 能 boot、掃資料夾、下載一個模型
  - [ ] `path_provider`、`permission_handler`、`file_picker` 在 Desktop 的行為差異記錄
- **預估時間**: 2 天
- **依賴**: 無（與 task-001 平行可進）

---

### EP-1：Foundation（DI 與基礎結構）

#### task-101: 引入 Riverpod
- **類型**: 🔧 程式 (TDD) + ⚙️ 配置
- **狀態**: [TODO]
- **描述**: 加入 `flutter_riverpod` 依賴；`main.dart` 包 `ProviderScope`；建立 `lib/providers/` 目錄與基礎 provider（services、repositories）。既有 ViewModel 暫不動。
- **驗收標準**:
  - [ ] `flutter_riverpod` 加入 pubspec
  - [ ] `main.dart` 用 `ProviderScope` 包 `LittleStarApp`
  - [ ] 既有 `HuggingFaceService`、`DownloadService`、`DirectoryService`、`OnboardingService` 都有對應 provider
  - [ ] 既有功能不回歸
- **預估時間**: 1 天
- **依賴**: 無

---

### EP-2：Inference Backend 抽象

#### task-201: 定義 InferenceBackend / InferenceSession 介面
- **類型**: 🔧 程式 (TDD)
- **狀態**: [TODO]
- **描述**: 在 `lib/core/inference/` 建立 `InferenceBackend` (capability query) 與 `InferenceSession` (model+context+sampler 生命週期，含 cancel)。設計 `SamplingParams`（中立命名，非 llama.cpp 特定）。
- **驗收標準**:
  - [ ] `InferenceBackend.canHandle(ModelProfile) -> bool`
  - [ ] `InferenceBackend.createSession(ModelProfile, InferenceSettings) -> InferenceSession`
  - [ ] `InferenceSession.generate(messages) -> Stream<String>`
  - [ ] `InferenceSession.cancel()`、`InferenceSession.dispose()`
  - [ ] `SamplingParams` 與 llama.cpp 概念解耦
  - [ ] 介面 doc comment 完整
- **預估時間**: 1 天
- **依賴**: task-005（ModelProfile 雛形，可平行）

#### task-202: LlamaCppBackend 實作介面
- **類型**: 🔧 程式 (TDD)
- **狀態**: [TODO]
- **描述**: 把既有 `LlamaCppFFI` 包進 `LlamaCppBackend` 與 `LlamaCppSession`；收編 `tokenizePrompt → generate(nPrompt)` 的內部 state 洩漏；補上明確 dispose。新增 `LLAMA_CPP_VERSION = "b7493"` 常數。
- **驗收標準**:
  - [ ] `LlamaCppBackend` 通過 `InferenceBackend` 介面 unit test
  - [ ] Session 生命週期：create → generate → cancel → dispose 全鏈路測試通過
  - [ ] selectModel 不洩漏（舊 session 確保 dispose）
  - [ ] 既有 chat / completion 行為等價（end-to-end）
- **預估時間**: 2 天
- **依賴**: task-201

#### task-203: BackendSelector
- **類型**: 🔧 程式 (TDD)
- **狀態**: [TODO]
- **描述**: 依平台 + `ModelProfile.format` + 使用者偏好挑後端。預設邏輯：MLX 格式 + Apple Silicon → MlxBackend；其他 → LlamaCppBackend。提供 override API。
- **驗收標準**:
  - [ ] `BackendSelector.select(ModelProfile, [Override?]) -> InferenceBackend`
  - [ ] 至少 5 個測試情境覆蓋（gguf on android / gguf on ios / mlx on macos / mlx on windows 拒絕 / override）
- **預估時間**: 0.5 天
- **依賴**: task-201、task-202、task-501（MLX 後端不一定要有，可用 stub）

---

### EP-3：Prompt 統一層

#### task-301: ChatTemplate 抽象與實作
- **類型**: 🔧 程式 (TDD)
- **狀態**: [TODO]
- **描述**: 在 `lib/core/prompt/` 建立 `ChatTemplate` 抽象。封裝 `llama_model_chat_template` 路徑與外部覆寫機制。優先序：使用者 override > ModelProfile hint > GGUF 內建 > fallback。
- **驗收標準**:
  - [ ] `ChatTemplate.render(messages, systemPrompt) -> String`
  - [ ] 從 GGUF 內建讀取的路徑驗證（呼叫 `applyChatTemplate`）
  - [ ] 對 Gemma 3、Llama 3.2、Qwen 2.5/3 各跑一輪 unit test，輸出比對預期模板
  - [ ] 與 ViewModel 手刻 `<|user|>` 路徑的對照差異記錄
- **預估時間**: 1.5 天
- **依賴**: task-201、task-501

#### task-302: 移除 dead code `PromptFormat`
- **類型**: 🔧 程式
- **狀態**: [TODO]
- **描述**: 刪除 `lib/core/format/prompt_format.dart`（chatml/alpaca/raw enum + filter，全是 dead code）。
- **驗收標準**:
  - [ ] 檔案刪除
  - [ ] 全專案無 import
  - [ ] 編譯通過、現有測試通過
- **預估時間**: 0.25 天
- **依賴**: task-301（先建好替代品）

---

### EP-4：Platform 抽象

#### task-401: PlatformAdapter 與 NativeLibraryLoader
- **類型**: 🔧 程式 (TDD)
- **狀態**: [TODO]
- **描述**: 把現有 `Platform.isWindows` 分流邏輯（在 `lm.dart` 與 `llama_cpp_ffi.dart` 內）收編進 `lib/core/platform/`。`NativeLibraryLoader` 封裝 iOS/Android/Windows/macOS 的 lib 載入路徑差異。
- **驗收標準**:
  - [ ] `PlatformAdapter.current()` 回傳當前平台適配器
  - [ ] `NativeLibraryLoader.loadLlama()` 在四平台都能正確載入
  - [ ] FFI code 移除散落的 `Platform.is*` 分支（集中於 PlatformAdapter）
- **預估時間**: 1 天
- **依賴**: task-003（Spike）、task-202

#### task-402: DirectoryService Desktop 實作收編
- **類型**: 🔧 程式
- **狀態**: [TODO]
- **描述**: 把 task-003 Spike 產出的 Desktop 實作正式收編進 `lib/data/services/directory_service.dart`，補單元測試。
- **驗收標準**:
  - [ ] `MacOsDirectoryService` / `WindowsDirectoryService` 在 main code base
  - [ ] 四平台都能掃描、建立、回傳 model directory
  - [ ] 既有 Mobile 行為無回歸
- **預估時間**: 0.5 天
- **依賴**: task-003

---

### EP-5：ModelProfile

#### task-501: ModelProfile 型態與遷移
- **類型**: 🔧 程式 (TDD)
- **狀態**: [TODO]
- **描述**: 在 `lib/core/model/` 建立 `ModelProfile`，欄位含：id、displayName、format（`gguf | mlx`）、chatTemplate hint、ctxLen、預設 SamplingParams、backend hint、quantization 建議。`RecommendedModels` 既有 5 個模型遷移到 `ModelProfile`。新增 1 個 mlx-community 模型 profile。
- **驗收標準**:
  - [ ] `ModelProfile` 型態定義 + JSON ser/de
  - [ ] `recommended_models.dart` 改用 `ModelProfile` 列表
  - [ ] 新增 `mlx-community/Llama-3.2-1B-Instruct-4bit` profile
  - [ ] `RecommendedModelConfig` 標 deprecated（暫保留以免 UI 連鎖崩）
- **預估時間**: 1 天
- **依賴**: 無

---

### EP-6：ViewModel 瘦身與遷移

#### task-601: 抽出 GenerationController
- **類型**: 🔧 程式 (TDD)
- **狀態**: [TODO]
- **描述**: 在 `lib/ui/shared/inference/` 建立 `GenerationController`，封裝 streaming、metrics tracking（TTFT、tokens/sec、stop reason）、cancel 邏輯。
- **驗收標準**:
  - [ ] `GenerationController.run(session, prompt) -> Stream<GenerationEvent>`
  - [ ] Metrics 與目前 ChatVM / CompletionVM 行為一致
  - [ ] Unit test 覆蓋 first token、normal flow、cancel、error
- **預估時間**: 1 天
- **依賴**: task-201、task-202

#### task-602: 抽出 InferenceSettings
- **類型**: 🔧 程式 (TDD)
- **狀態**: [TODO]
- **描述**: 抽出 `InferenceSettings` data class（sampler、system prompt、maxTokens、stopSequences），跨 ChatVM / CompletionVM 共用。
- **驗收標準**:
  - [ ] `InferenceSettings` 型態完成
  - [ ] 預設值單一來源
  - [ ] `copyWith` / `updateFrom(ModelProfile)` API
- **預估時間**: 0.5 天
- **依賴**: task-501

#### task-603: CompletionViewModel 遷移到新介面
- **類型**: 🔧 程式 (TDD)
- **狀態**: [TODO]
- **描述**: 把 `CompletionViewModel` 從 `UnifiedLM` 切到 `InferenceSession` + `GenerationController` + `InferenceSettings`，改用 Riverpod provider 取得 backend。
- **驗收標準**:
  - [ ] Completion 路徑 end-to-end 行為等價
  - [ ] VM 行數減少 > 30%
  - [ ] 與 task-301 ChatTemplate 整合（無更多手刻 prompt）
- **預估時間**: 1 天
- **依賴**: task-201、task-202、task-301、task-601、task-602

#### task-604: ChatViewModel 遷移到新介面（修 Smoking Gun）
- **類型**: 🔧 程式 (TDD)
- **狀態**: [TODO]
- **描述**: ChatViewModel 改走 `ChatTemplate.render()` → `InferenceSession.generate()`，**刪除 `_buildPromptFromHistory()` 的手刻 `<|user|>` 邏輯**。對所有推薦模型驗證 chat 行為。
- **驗收標準**:
  - [ ] `_buildPromptFromHistory` 刪除
  - [ ] 對 Gemma 3 270m、Gemma 3 1B、Llama 3.2 3B、Qwen 2.5 1.5B、Qwen 3 0.6B 跑一輪人工 chat 驗證，行為合理（不再吐出 `<|user|>` 等錯誤 token）
  - [ ] Metrics 行為與舊版等價
- **預估時間**: 1.5 天
- **依賴**: task-603

#### task-605: 刪除 UnifiedLM
- **類型**: 🔧 程式
- **狀態**: [TODO]
- **描述**: 確認無人 import `lib/core/lm.dart` 後刪除整檔。
- **驗收標準**:
  - [ ] `lib/core/lm.dart` 刪除
  - [ ] 全專案編譯通過
  - [ ] iOS / Android 端到端跑通
- **預估時間**: 0.25 天
- **依賴**: task-603、task-604

---

### EP-7：macOS llama.cpp Build

#### task-701: macOS llama.cpp 正式整合
- **類型**: ⚙️ 配置
- **狀態**: [TODO]
- **描述**: 把 task-002 Spike 產出的 macOS build script 與 binary 正式整合進 repo；補進 build doc。
- **驗收標準**:
  - [ ] `macos/Frameworks/libllama.a` (universal) 入 repo（或透過 LFS）
  - [ ] `scripts/llama.cpp_MacOS_Build.md` 完整
  - [ ] CI / 開發者重 build 流程文件化
- **預估時間**: 0.5 天
- **依賴**: task-002

---

### EP-8：Windows DLL 升級

#### task-801: Windows DLL 重 build 至 b7493
- **類型**: ⚙️ 配置
- **狀態**: [TODO]
- **描述**: 用 `llama.cpp/` (b7493) 重 build Windows DLL（llama.dll / ggml*.dll），取代 2025-07-01 舊版。
- **驗收標準**:
  - [ ] `windows/libs/*.dll` 更新
  - [ ] `flutter run -d windows` 載入既有 GGUF 並推論
  - [ ] 既有 `Platform.isWindows` FFI 路徑無需改動
- **預估時間**: 0.5 天
- **依賴**: 無

---

### EP-9：Desktop Demo

#### task-901: Windows Desktop 最小可跑 demo
- **類型**: 🔧 程式
- **狀態**: [TODO]
- **描述**: 在 Windows 上跑通「下載模型 → 載入 → completion」最小 demo；UI 不打磨（沿用既有），只確保不崩。
- **驗收標準**:
  - [ ] `flutter run -d windows` 全流程跑通
  - [ ] Performance 數字記錄（tok/s）
  - [ ] 已知問題列表
- **預估時間**: 1 天
- **依賴**: task-801、task-402

#### task-902: macOS Desktop 最小可跑 demo
- **類型**: 🔧 程式
- **狀態**: [TODO]
- **描述**: macOS 上跑通同樣最小 demo（GGUF via llama.cpp）。MLX 路徑由 EP-10 處理。
- **驗收標準**:
  - [ ] `flutter run -d macos` 全流程跑通（GGUF）
  - [ ] Performance 數字記錄
  - [ ] Code signing 流程記錄（如必要）
- **預估時間**: 1 天
- **依賴**: task-701、task-402

---

### EP-10：MLX 後端

#### task-1001: MlxBackend Pigeon channel 正式設計
- **類型**: 🔧 程式 (TDD) + ⚙️ 配置
- **狀態**: [TODO]
- **描述**: 根據 task-001 Spike 結果，正式定義 Pigeon spec（Dart ↔ Swift）；Swift 端寫包 mlx-swift-lm 的 glue；Dart 端 `MlxBackend` 實作 `InferenceBackend`。
- **驗收標準**:
  - [ ] Pigeon spec 提交、codegen 跑通
  - [ ] Swift glue 寫完（load / tokenize / generate stream / cancel / dispose）
  - [ ] `MlxBackend` 通過 `InferenceBackend` 介面 unit test
  - [ ] iOS 上 mlx-community 模型 end-to-end 跑通
- **預估時間**: 3 天
- **依賴**: task-001、task-201、task-202

#### task-1002: MLX 在 macOS 整合驗證
- **類型**: 🔧 程式
- **狀態**: [TODO]
- **描述**: 在 macOS Runner 加入 mlx-swift-lm SPM；確認 `MlxBackend` 在 macOS 也跑通。
- **驗收標準**:
  - [ ] macos/Runner 加入 SPM dependency
  - [ ] macOS 端到端跑通 MLX 模型
  - [ ] 與 iOS 行為對照
- **預估時間**: 1 天
- **依賴**: task-1001、task-902

#### task-1003: 模型下載 / 管理支援 MLX 格式
- **類型**: 🔧 程式 (TDD)
- **狀態**: [TODO]
- **描述**: `HuggingFaceService` 與 `DownloadService` 支援 mlx-community 模型的 safetensors 多檔下載。`ModelProfile.format` 驅動下載策略選擇。
- **驗收標準**:
  - [ ] 從 mlx-community 下載分片 safetensors 模型
  - [ ] 本地掃描可識別 MLX 模型（不只 .gguf）
  - [ ] UI 模型列表標示 format
- **預估時間**: 2 天
- **依賴**: task-501、task-1001

---

### EP-12：SLM 適配（最新 SLM 系列）

依用戶指定優先序：**Gemma 4 → Llama 3.2 補強 → Qwen 3.5**。每個 task 只做**文字模型**，multi-modal（Gemma 4 / Llama 3.2 Vision）明確留 v0.2。

#### task-1201: Gemma 4 (E2B / E4B) 適配
- **類型**: 🔧 程式 (TDD) + 🔬 研究
- **狀態**: [TODO]
- **描述**: Gemma 4 (2026-04-02 釋出) 加入 v0.1 推薦清單。範圍：E2B（effective 2B）與 E4B（effective 4B）的 GGUF + MLX 雙軌 profile，含 `<start_of_turn>` 系列 chat template 驗證。Multi-modal 能力 **不**處理（純文字 only）。
- **驗收標準**:
  - [ ] `ModelProfile` for Gemma 4 E2B (GGUF) 與 E4B (GGUF) 加入 recommended
  - [ ] 對應 mlx-community Gemma 4 profile（若上架）一併加入
  - [ ] chat template 從 GGUF metadata 正確讀出（`<start_of_turn>user...<end_of_turn>`）
  - [ ] iOS + Android end-to-end chat 驗證通過
  - [ ] macOS via llama.cpp 驗證通過（依 task-902）
  - [ ] 若有 MLX profile，iOS / macOS MLX 路徑驗證通過（依 task-1001 / 1002）
  - [ ] 文字 only — 任何 image-related field 在 profile 內標 `unsupported`
- **預估時間**: 1.5 天
- **依賴**: task-301、task-501、task-604（必要）；task-1001 / 1002（若做 MLX，可後補）

#### task-1202: Llama 3.2 系列補強
- **類型**: 🔧 程式
- **狀態**: [TODO]
- **描述**: 既有推薦清單已含 `twinkle-ai/Llama-3.2-3B-F1-Reasoning-Instruct-GGUF`。本 task 補入 1B Instruct（GGUF + MLX 對應）作為更輕量選擇。Llama 3.2 11B Vision 明確留 v0.2。
- **驗收標準**:
  - [ ] `ModelProfile` for Llama 3.2 1B Instruct (GGUF) 加入 recommended
  - [ ] `mlx-community/Llama-3.2-1B-Instruct-4bit`（task-501 已加）profile 確認與本 task 連動
  - [ ] `<|start_header_id|>` 系列 chat template 從 GGUF metadata 正確讀出
  - [ ] iOS + Android end-to-end chat 驗證通過
- **預估時間**: 0.5 天
- **依賴**: task-301、task-501、task-604

#### task-1203: Qwen 3.5 (0.8B / 2B) 適配
- **類型**: 🔧 程式
- **狀態**: [TODO]
- **描述**: Qwen 3.5 small series (2026-03-01 釋出, 0.8B / 2B / 4B / 9B)。範圍：**0.8B 與 2B** 兩個 size 的 GGUF profile。4B / 9B 暫不納入（記憶體要求較高，留 v0.2 評估）。
- **驗收標準**:
  - [ ] `ModelProfile` for Qwen 3.5 0.8B 與 2B (GGUF) 加入 recommended
  - [ ] Qwen 系列 chat template 從 GGUF metadata 正確讀出
  - [ ] iOS + Android end-to-end chat 驗證通過
  - [ ] 對既有 Qwen 3 0.6B 的 profile 維持不動（並存）
- **預估時間**: 0.5 天
- **依賴**: task-301、task-501、task-604

---

### EP-11：Design System 調查（v0.2 預備）

#### task-1101: Flutter Design System 調查報告
- **類型**: 🔬 研究 + 📄 文檔
- **狀態**: [TODO]
- **描述**: 比較 Material 3 Expressive、Forui、shadcn-flutter、自製 design token + Cupertino 雙軌等候選方案。聚焦：暗黑模式支援、Desktop 相容、維護度、與 Flutter 生態整合度。**只調查，不實作**。
- **建議方式**: 調查 → 整理比較表 → 推薦結論
- **驗收標準**:
  - [ ] 至少 4 個候選方案 detailed comparison
  - [ ] 暗黑模式覆蓋度評估
  - [ ] 4 平台（iOS/Android/macOS/Windows）相容性
  - [ ] 推薦結論 + 推薦理由
  - [ ] 產出檔案：`docs/design_system_research.md`
- **預估時間**: 1.5 天
- **依賴**: 無（可全程獨立平行）

---

## 技術決策（鎖定，避免再次討論）

1. **MLX 整合**：Path A — `mlx-swift-lm` via Pigeon
2. **DI / state**：Riverpod
3. **VM 瘦身範圍**：抽 `GenerationController` + `InferenceSettings`
4. **資料相容性**：不保留 v0.0.x，可大膽重構
5. **遷移策略**：Parallel new modules + per-feature cutover（避免 big-bang）
6. **release 節奏**：Epic-based internal build，無硬 deadline
7. **Smoking Gun**：在 task-604 / EP-3 prompt layer 重構中順帶修正
8. **macOS 任務排程**：因 Apple Silicon Mac 取用受限，macOS 任務不為關鍵路徑

---

## 風險與依賴

| 風險 | 影響 | 緩解措施 |
|------|------|----------|
| MLX bridge 設計反覆 | 中 | task-001 Spike 先驗證；介面草案 review 後再 EP-10 |
| macOS Apple Silicon 機器取用受限 | 高 | EP-7、EP-9 macOS、EP-10 macOS 部分非關鍵路徑；plan 中可並行其他 epic |
| Windows DLL 重 build 環境 | 中 | task-801 早做，blocker 早暴露 |
| Smoking Gun 修復後模型回歸 | 中 | task-604 對 5 個推薦模型逐一驗證 |
| Riverpod 引入連鎖改動 | 低 | task-101 只動 main 與 providers；VM 改動跟著 task-603 / 604 順手 |
| llama.cpp 行為差異（雖頭檔一致） | 低 | 每平台 binary 整合後跑 testLibrary + 一次完整推論 |
| mlx-swift-lm SPM 在 Flutter iOS 整合卡關 | 中 | task-001 Spike 早暴露；如不可行，回頭重評 Path C |

---

## 相關循環

- 本循環為 v0.1 重構主循環；後續 v0.2 candidate cycle 將處理：iOS/Android Beta UX、Desktop UI 進 Alpha、Design System 實作、最新 SLM 系列適配

---

## 預估總時間

| EP | 任務數 | 累計天數 |
|----|--------|---------|
| EP-0 Spikes | 3 | 6-8 天（含等待 Mac 機） |
| EP-1 Foundation | 1 | 1 天 |
| EP-2 Inference Backend | 3 | 3.5 天 |
| EP-3 Prompt Layer | 2 | 1.75 天 |
| EP-4 Platform Abstraction | 2 | 1.5 天 |
| EP-5 ModelProfile | 1 | 1 天 |
| EP-6 VM Slim & Migrate | 5 | 4.25 天 |
| EP-7 macOS Build | 1 | 0.5 天 |
| EP-8 Windows DLL | 1 | 0.5 天 |
| EP-9 Desktop Demo | 2 | 2 天 |
| EP-10 MLX Backend | 3 | 6 天 |
| EP-11 Design System Report | 1 | 1.5 天 |
| EP-12 SLM 適配（文字 only） | 3 | 2.5 天 |
| **合計** | **28 任務** | **約 31.5-33.5 工程日**（連續推進；EP-12 可平行 EP-9 / EP-10 進行，邊際時程影響有限） |
