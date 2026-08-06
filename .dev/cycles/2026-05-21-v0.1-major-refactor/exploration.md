# 探索：v0.1 架構重構與後端抽象化

> 循環：2026-05-21-v0.1-major-refactor
> 模式：深度 (deep)
> 狀態：✅ 探索期完成（1-6 全部 [DONE]）；循環已於 2026-08-05 關閉

---

## 1. 問題定義 [DONE]

### 背景

`little_star_app` 目前處於 v0.1.0，是一個 Flutter 為基礎的 Edge LLM 工具，已實作 iOS/Android 平台與 llama.cpp 的 FFI 整合（pre_alpha → alpha.2）。

使用者原始期望涵蓋五大目標（跨平台、後端、UI/UX、架構、SLM），經第一輪對齊後**收斂為**：

> **v0.1 = 架構重構 + 後端抽象化**，作為後續其他工作的基礎。
> Desktop（Windows/MacOS）、Design System、Dark Mode、最新 SLM 支援延後至 v0.2。

### 核心問題

如何把目前耦合於 llama.cpp 的推論層，重構為一個**可抽換、可擴展的後端層**，使後續加入 MLX（v0.1 內）以及 Desktop 平台、其他後端（v0.2）時，架構不需要再大改？

### 已知架構痛點（用戶確認）

1. **FFI / 推論層與上層耦合太緊** — ViewModel/Repository 直接觸碰 llama.cpp 細節，換後端會牽動上層
2. **Prompt / 模型設定難擴充** — 新增模型家族或調參數要改多處，無集中的 prompt template / model config 層

→ 此兩痛點將作為架構 Review 的主切入點，重構藍圖必須直接回應這兩個問題。

### v0.1 目標（已收斂，含 stretch）

**核心目標（必達）**：

- [ ] **架構 Review**：聚焦兩大痛點（耦合 + prompt/config），產出重構藍圖文件
- [ ] **Backend Abstraction**：定義 `InferenceBackend` 介面（載入、generation、streaming、stop、release、capability query）
- [ ] **Prompt / Model Config 層**：集中化的 prompt template 與模型參數設定層，新增模型家族只改一處
- [ ] **llama.cpp 後端**：升級至最新 upstream，重構為 `LlamaCppBackend` 實作新介面
- [ ] **MLX 後端**：在 iOS / MacOS 整合 MLX 為 `MlxBackend`（路徑待背景研究決定）
- [ ] **Runtime 後端選擇**：依平台與裝置能力自動選擇，使用者可手動覆寫
- [ ] **Platform Abstraction**：抽象化平台介面（檔案存取、權限、原生路徑、backend 載入），iOS/Android 提供實作

**Stretch goal（用戶確認納入）**：

- [ ] **Desktop 最小可跑**：Windows / MacOS 上能完成「載入模型 → 推論」最小流程（demo 等級即可，UI 不打磨）

### v0.2 候選（本循環不做）

- Design System 與暗黑模式（**本循環只產出調查報告，不實作**）
- 最新 SLM 系列適配（Gemma 3、Phi-4、Qwen 3、Llama 3.3...）
- Desktop UI 打磨進入 Alpha 階段
- iOS / Android Beta 等級的 UX 拋光

### 限制條件

- 時間：**期望內連續推進、緊湊但不定期**（無硬 deadline，但建造期需明確 step-by-step 交付里程碑）
- 團隊：**待用戶補充**（影響任務切分粒度）
- 技術：Flutter SDK ^3.7.2；既有 FFI 已建立；MLX 整合方式未定；macOS code signing 需處理
- 相容性：**不需保留 v0.0.x 資料相容**（重灌即可，重構可大膽進行）

### 成功標準

- [ ] 重構藍圖文件產出，直接回應兩大痛點，並有遷移計畫
- [ ] `InferenceBackend` 介面文件化，`LlamaCppBackend` 遷移完成且行為與原版等價
- [ ] Prompt / Model Config 層落地，至少 3 個模型家族（如 Gemma、Llama、Qwen）走新層
- [ ] MLX 後端在 iOS / MacOS 至少一台目標機型完成端到端推論
- [ ] Platform Abstraction 介面文件化；iOS/Android 仍可正常運作
- [ ] Windows / MacOS 至少能在開發機跑通「載入 → 推論」demo 流程
- [ ] 既有 Mobile 功能無回歸：下載、模型管理、Chat、Completion 全部可用
- [ ] Design System 調查報告產出，列出至少三個候選方案的比較與推薦

---

## 2. 背景研究 [IN_PROGRESS]

研究依用戶確認順序：**A（現有架構盤點）→ B（llama.cpp upstream）→ C（MLX 整合路徑）**。

---

### A. 現有架構盤點 — Quick Scan + Deep Dive [DONE 2026-05-21]

**已讀檔案**：`lib/main.dart`、`lib/core/lm.dart`、`lib/core/format/prompt_format.dart`、`lib/core/engine/llama_cpp/llama_cpp_ffi.dart`（前 120 行）、`lib/ui/chat/view_model/chat_viewmodel.dart`、`lib/ui/completion/view_model/completion_viewmodel.dart`、`lib/ui/home/view_model/home_viewmodel.dart`（前 80 行）、`lib/data/repositories/gguf_repository.dart`、`lib/data/services/directory_service.dart`、`lib/config/recommended_models.dart`、`lib/config/recommended_model_config.dart`。

#### 痛點 1：FFI / 推論層與上層耦合 — 證據

| 證據 | 位置 |
|------|------|
| `UnifiedLM` 並非抽象，直接 `new LlamaCppFFI()` 並暴露 llama.cpp 概念 | `lib/core/lm.dart:124` |
| `UnifiedLM._initBackend()` 內含 `if (Platform.isWindows)` 平台分支 | `lib/core/lm.dart:110-115` |
| `ContextParams` 直接攜帶 llama.cpp 命名：`nCtx`/`nBatch`/`nUbatch`/`nSeqMax`/`nThreads` — 對 MLX 沒有直接對應 | `lib/core/lm.dart:23-44` |
| ViewModel 4 處直接 `new UnifiedLM(modelPath)`（chat 2 處、completion 2 處） | `chat_viewmodel.dart:53,73`；`completion_viewmodel.dart:93,117` |
| `selectModel()` 直接 `_lm = UnifiedLM(...)` 取代既有實例，**無 dispose** — 舊 FFI/native memory 可能洩漏 | `chat_viewmodel.dart:73`；`completion_viewmodel.dart:117` |
| `completion()` / `chat()` / `completionStream()` 都重複呼叫 `_ffi!.createContext()` + `_ffi!.createSampler()` — 沒有 session 概念 | `lib/core/lm.dart:142-228` |

→ **`UnifiedLM` 不是抽象、只是 façade**；重構必須是「替換」而非「重命名」。

#### 痛點 2：Prompt / 模型設定難擴充 — 證據

| 證據 | 位置 |
|------|------|
| 🚨 **Smoking gun**：`ChatViewModel._buildPromptFromHistory()` 手刻 `<|user|>` / `<|assistant|>` / `<|system|>` 模板，**並餵給 `completionStream()` 而非 `chat()`**，完全繞過 llama.cpp 內建的 `apply_chat_template` | `chat_viewmodel.dart:203-229` |
| 結果：Gemma 3 / Qwen / Llama 3 等推薦模型實際上 **chat 路徑使用的是錯的 prompt 模板**（這些模型不是用 `<|user|>` 系列 token） | — |
| `PromptFormat` enum（`raw, chatml, alpaca`）+ `formatMessages()` 是**完全 dead code**，未被 chat 或 completion 路徑使用 | `lib/core/format/prompt_format.dart` 全檔 |
| `applyChatTemplate()` 雖然在 FFI 層存在且 `UnifiedLM.chat()` 會用，但**沒有 ViewModel 走這條路徑** | `llama_cpp_ffi.dart:1152`；`lib/core/lm.dart:221` |
| `RecommendedModelConfig` 缺少：prompt template metadata、backend suitability tag、context length 建議、預設 sampler 參數 | `lib/config/recommended_model_config.dart` 全檔 |
| 停止序列 `['<|user|>', '<|system|>', ...]` 寫死於 ChatViewModel，模型無關但模板特定 | `chat_viewmodel.dart:45` |
| Chat 與 Completion 兩 ViewModel 各自定義 sampler 預設值，無單一真實來源 | `chat_viewmodel.dart:46-48`；`completion_viewmodel.dart:85-87` |

→ Prompt/config 不只是「難擴充」，目前是 **行為錯誤**：推薦模型在 chat 路徑下用了錯誤模板。

#### 其他發現（非主要痛點，但值得納入決策）

- **`DirectoryService` 已有 abstract + 平台 impl 模式**（`AndroidDirectoryService` 等）— Platform abstraction 已有半成品基礎，Desktop 擴充只需新增 `WindowsDirectoryService` / `MacOsDirectoryService`
- **無 DI 容器**：services/repositories 在 ViewModel constructor 內手動串接（見 `home_viewmodel.dart:69-73`）。重構時是否引入 DI（Riverpod / get_it / Provider）需決策
- **無集中的 state management**：`ChangeNotifier` 直用，每個 ViewModel 各自封裝
- **VendorEd llama.cpp 已在 `llama.cpp/` 根目錄出現**（git status 顯示 untracked）— 推測為 v0.1 升級過程中拉下的新版上游，尚未整合
- ViewModel 過肥：`ChatViewModel` / `CompletionViewModel` 各 300+ 行，內含 metrics 計算、stream 管理、settings、prompt 組裝 — 違反單一職責，難測試

#### Deep Dive — FFI 公開 API 面積

llama.cpp FFI 對外實際暴露的方法（位置：`llama_cpp_ffi.dart`）：

| Method | 行 | 作用 |
|--------|----|------|
| `setLogCallback()` | 765 | log routing |
| `initBackend()` / `ggml_backend_load_all()` | 774 | backend 初始化（Windows 分流） |
| `loadModel(modelPath)` | 790 | 載入模型 |
| `tokenizePrompt(prompt)` → int | 819 | tokenize **且**設定 FFI 內部 batch state — 跨呼叫狀態洩漏 |
| `createContext({nCtx, nBatch, nThreads, nThreadsBatch})` | 862 | context 建立 |
| `createSampler({useGreedy, topK, topP, temp})` | 910 | sampler 建立 |
| `generate(nPrompt, {maxTokens})` → String | 949 | 同步生成（吃 tokenize 留下的內部 state） |
| `generateStream(nPrompt, {maxTokens})` → Stream<String> | — | 串流生成 |
| `applyChatTemplate(messages)` → String | 1152 | **走 `llama_model_chat_template(_model, NULL)`，從 GGUF metadata 讀取正確 template** |
| `freeModel()` / `freeContext()` / `freeBackend()` | 1202+ | 釋放 |

#### Deep Dive — Smoking Gun **確認屬實**

`applyChatTemplate` 第 1160 行明確使用 `llama_model_chat_template(_model, NULL)`，這是 llama.cpp 從 GGUF 檔內建 metadata 讀取 chat_template 的正確 API。但：

- `UnifiedLM.chat()`（lib/core/lm.dart:221）會用它
- **但兩個 ViewModel 都不呼叫 `UnifiedLM.chat()`**：
  - `ChatViewModel` 用 `_buildPromptFromHistory()` 手刻 → `completionStream()`
  - `CompletionViewModel` 直接 `completionStream()`
- 結果：Gemma 3 / Qwen / Llama 3 的 chat 路徑全跑錯模板

**修復路徑**：新 prompt layer 應該封裝 `applyChatTemplate`，ViewModel 改走 prompt layer，bug 自然消失（用戶已確認在重構中一併修正）。

#### Deep Dive — FFI 介面對抽象化的設計挑戰

從 FFI API 推導 `InferenceBackend` 介面時需處理：

1. **內部 state 洩漏**：`tokenizePrompt → generate(nPrompt)` 中間隔的 batch 狀態必須收入 `InferenceSession` 概念
2. **參數名洩漏**：`nCtx/nBatch/nUbatch/nSeqMax` 是 llama.cpp-only；MLX 等需要 `contextSize`、`batchSize` 等中立命名
3. **Sampler 差異**：llama.cpp 的 `topK/topP/temp` 不完全等於 MLX 的 sampler；需在 abstraction 上層做 `SamplingParams` 轉換或同時提供多種預設
4. **無 abort/cancel API**：目前靠 Stream subscription 取消，無 native side cancel — 重構應引入明確 `cancel()`
5. **無 concurrent session**：單一 `_model` / `_context` 全域單例 — 重構應決定 v0.1 是否支援多 session（建議：v0.1 維持單 session，但介面預留）

#### Deep Dive — Model Metadata 缺口

| 既有 | 缺口 |
|------|------|
| `HFModelInfo`：id / author / name / tags / description | ❌ 無 prompt template、context length、預設 sampler、backend suitability、quant 建議 |
| `HFModelFile`：filename / size / quantization | ❌ 無檔內 GGUF metadata 摘要（架構、context length） |
| `GGUFModelInfo`：filePath / fileName / fileSize | ❌ 完全不讀檔內 metadata，下載後變黑盒，要載入才知道內容 |
| `RecommendedModelConfig`：useCases / badge / quickDescription | ❌ 無上述任何推論層 metadata |

→ `ModelProfile` 必須是新的整合型態，跨資料來源（recommended list、HF API、GGUF 檔頭、使用者偏好）。

#### 衍生重構候選（提交方案發想階段細化）

1. **`lib/core/inference/`** — 抽象推論層
   - `InferenceBackend`（capability query、能否處理某模型）
   - `InferenceSession`（持有 model+context+sampler，收編 tokenize/generate 內部 state，含明確 cancel）
   - `LlamaCppBackend` + `LlamaCppSession`、`MlxBackend` + `MlxSession`
   - `BackendSelector`（依平台 / 模型 / 使用者偏好挑後端）
2. **`lib/core/prompt/`** — 統一 prompt 層
   - `ChatTemplate` 抽象（從 GGUF metadata → 預設模板 → 外部覆寫的優先序）
   - 收編 `applyChatTemplate` 與目前 ViewModel 手刻邏輯
3. **`lib/core/model/`**（或仍在 `models/`） — `ModelProfile` 整合型態
   - 含 template、context length、recommended sampler、backend hint、quant 建議
4. **`lib/core/platform/`** — 沿用 `DirectoryService` pattern
   - 新增 backend loader、capability detection、Desktop 實作
5. **ViewModel 瘦身** ✅ 用戶選定範圍：抽 `GenerationController` + `InferenceSettings`
   - `GenerationController`：共用 streaming + metrics + cancel 邏輯
   - `InferenceSettings`：共用 sampler/system prompt/maxTokens 結構，作為跨 `ModelProfile` + `InferenceSession` 的溝通型態
6. **DI / state management** ✅ 用戶選定：**引入 Riverpod**（取代 ChangeNotifier + 手動依賴注入）

---

### B. llama.cpp upstream 調查 [DONE 2026-05-21]

**結論**：「升級」實質已完成，剩「整合」。

#### 版本現況

- 根目錄 untracked 的 `llama.cpp/` HEAD: `9496bbb80` / tag `b7493` (commit date 2025-12-20)
- `ios/Runner/llama.h` 與 `llama.cpp/include/llama.h` **byte-identical**（1449 行 / 76729 bytes）
- 即 ABI 與 vendored header 已同步至 b7493

#### 平台二進位現況

| 平台 | 路徑 | 大小（合計） | 時間戳 | 版本 |
|------|------|-------------|--------|------|
| iOS | `ios/Frameworks/libllama-*.a` ×4 | ~18.5 MB | **2026-05-21 08:15**（今天） | b7493 |
| Android | `android/app/src/main/jniLibs/{arm64-v8a,x86_64}/libllama.so` | ~56.8 MB | 2025-12-22 | b7493 |
| Windows | `windows/libs/{llama,ggml,ggml-base,ggml-cpu}.dll` | ~2.5 MB | 2025-07-01 | **推測 b5965（舊）— 需重 build** |
| macOS | — | — | — | **❌ 不存在 — 需從零 build** |

#### Dart FFI 綁定影響

`llama_cpp_ffi.dart` 透過 `_lib.lookup<NativeFunction<...>>('symbol_name')` 顯式查找 30+ 個符號（見第 582-756 行）。因 header byte-identical，所有符號應仍可解析。實際驗證留到 construction 階段。

#### B 線剩餘工作（轉入 plan）

1. 將 `llama.cpp/` 從 untracked → 正式 vendored（submodule 或 copy-with-version-pin），決策：哪一種
2. 程式碼裡 pin `LLAMA_CPP_VERSION = "b7493"` 常數
3. Windows DLL 重 build 至 b7493
4. macOS 從零 build（與 iOS 共用 build script 應可調整）
5. （延後）盤點 b5965 → b7493 之間值得引入的新 API
   - `llama_model_chat_template` ✅ 已用
   - model-embedded sampling params (#17120)
   - kv-cache padding (#17046)
   - 注意：許多新功能是 server 端，Edge 用途不適用

### C. MLX 整合路徑比較 [DONE 2026-05-21]

#### Ecosystem 現況（2026-05）

- **MLX 已被 Apple 在 WWDC 2025 定位為 Apple Silicon LLM 推論的官方框架**（與 Foundation Models framework 並行）
- **Ollama 在 2026-03 宣告改用 MLX**（背書 MLX 為通用 Apple Silicon LLM 推論基礎）
- 上游堆疊：
  - `mlx`（C++/Python core）
  - `mlx-c`（官方 C API，現在版本 0.4.1）— mlx-swift 內部即用此包
  - `mlx-swift`（官方 Swift binding）
  - `mlx-swift-lm`（LLM/VLM Swift package；MLXChatExample 跑 iOS + macOS）
- 模型格式：`mlx-community/*` 在 HuggingFace 上以 Safetensors 為主，附 MLX 專屬量化（4-bit、8-bit）— **與 GGUF 不相容**，下載 / 模型管理需分軌

#### 三條整合路徑

**Path A — mlx-swift + Pigeon / MethodChannel**
- Flutter Dart 端透過 Pigeon 產生型別安全 channel → Swift 端寫 glue 呼叫 `mlx-swift-lm`
- ✅ 用 mlx-swift-lm 現成 LLM 邏輯（載入、tokenize、generate、template、sampling）
- ✅ 維護成本最低，上游加新模型家族跟著 Swift 升級即得
- ❌ Bridge 風格與 llama.cpp（dart:ffi）不一致，介面層需處理兩種 IPC
- ❌ Pigeon 為 async message-based，performance 略低於 FFI（streaming 大量 token 時可能感受）

**Path B — mlx-c + dart:ffi**
- Dart 端 dart:ffi 直接呼叫 mlx-c
- ✅ Bridge 風格與 llama.cpp 一致（同為 dart:ffi）
- ❌ mlx-c 是 **array-level**，不是 LLM-level — 沒有 model load from safetensors、chat template、sampling chain 等 LLM 高階 API
- ❌ 等於把 mlx-swift-lm 在 C/C++ 重寫一遍（包含 tokenizer、safetensors loader、chat template、sampler 等），工作量爆炸
- → **不建議**

**Path C — 自寫 Swift wrapper（LLM-level）+ `@_cdecl` 匯出 C-ABI + dart:ffi**
- Swift 端寫薄包裝呼叫 `mlx-swift-lm`，用 `@_cdecl` 匯出 C 函式
- Dart 端用 dart:ffi 呼叫，與 llama.cpp 同 pattern
- ✅ Bridge 一致性 ＋ 上游 LLM 邏輯免重寫
- ⚠️ `@_cdecl` 對複雜型別有限制（不能跨 ABI 傳 Swift 物件，需用 opaque pointer + handle 模式）
- ⚠️ Stream → 需用 callback (`Pointer<NativeFunction>`) 或 polling，比 Pigeon 麻煩
- ⚠️ 上游升級時 Swift wrapper 可能需追改

#### 用戶決策：✅ Path A（mlx-swift via Pigeon）

#### 推薦：Path A（mlx-swift via Pigeon）

**理由**：
1. **時間最快**：v0.1 範圍已大，盡量縮短 MLX 引入成本
2. **可維護**：mlx-swift-lm 由 Apple 維護，加新模型最快收到
3. **架構抽象在 Dart 層**：`InferenceBackend` 介面已抽象，下面的 bridge 用什麼 IPC 不影響上層；不需要為了「架構潔淨」強求 dart:ffi 對所有後端一致
4. **Pigeon perf 在 streaming 場景仍可接受**：edge LLM 的 token rate 通常 < 50 tok/s，Pigeon 的 IPC 開銷遠低於模型運算開銷

**反向考量**（若你想用 Path C）：
- 如果你重視「所有 native bridge 都走 dart:ffi」的架構一致性
- 如果你計畫未來引入更多後端（CoreML、ONNX Runtime）也走 dart:ffi
- 那麼 Path C 的初期投資長期划算，但需要花 1~2 週做 Swift wrapper + streaming callback 設計

#### 模型管理影響

無論選 A 或 C，模型管理 (`HFRepository`, `DownloadService`) 都要支援「下載 MLX 格式（safetensors 分片）」與「下載 GGUF」雙模式。`ModelProfile` 需要 `format: gguf | mlx` 欄位。

#### macOS 構建影響

選 A：mlx-swift 透過 Swift Package Manager 在 macOS Runner 加入即可，無需自建 .a。
選 C：需要自寫 Swift wrapper 並編成 static lib (.a)。

### 技術調查（後續補充）

| 主題 | 待調查內容 | 優先 |
|------|------------|------|
| llama.cpp upstream | 目前 vendored 版本 vs 最新 master；ABI 變化；新 API | 高（B 線） |
| MLX 整合路徑 A：mlx-swift | iOS/MacOS Swift bridge；維護成本與效能 | 高（C 線） |
| MLX 整合路徑 B：mlx C API | dart:ffi 直接呼叫；與現有 llama.cpp FFI 風格一致 | 高（C 線） |
| MLX 模型格式 | Safetensors vs GGUF；模型轉換流程 | 高（C 線） |
| 後端抽象介面設計參考 | llama.cpp server API、mlc-llm、Ollama 的 backend abstraction | 中 |
| DI / state management | Riverpod / get_it / Provider 選型；引入成本 | 中（A 線深 dive） |
| Design System（v0.2 預備）| M3 Expressive、Forui、shadcn-flutter；維護度、暗黑、Desktop | 低 |

### 參考案例

待補充

---

## 3. 方案發想 [DONE — 整合藍圖]

所有架構決策已在「問題定義 + 背景研究」階段逐項收斂（範圍、痛點、後端路徑、DI、VM 瘦身、MLX 路徑）。本節直接呈現整合藍圖。

### v0.1 整合藍圖

```
┌─────────────────────────────────────────────────────────────────┐
│                        UI (Flutter Widgets)                      │
└─────────────────────────────────────────────────────────────────┘
                                  ↓ (Riverpod providers)
┌─────────────────────────────────────────────────────────────────┐
│  ViewModels (瘦身後)：ChatVM / CompletionVM / HomeVM / ModelMgr  │
│   ↳ 共用 GenerationController（streaming + metrics + cancel）    │
│   ↳ 共用 InferenceSettings（sampler / system prompt / maxTokens）│
└─────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────┐
│  lib/core/inference/  ←  InferenceBackend ＋ InferenceSession    │
│      ↳ LlamaCppBackend     → dart:ffi → libllama (b7493)        │
│      ↳ MlxBackend          → Pigeon  → mlx-swift-lm (iOS/macOS) │
│      ↳ BackendSelector（platform + ModelProfile.format → 選後端）│
└─────────────────────────────────────────────────────────────────┘
                                  ↓                ↓
┌────────────────────────────────────┐  ┌──────────────────────────┐
│  lib/core/prompt/                  │  │  lib/core/model/         │
│  ChatTemplate                      │  │  ModelProfile            │
│   ↳ GGUF 內建（applyChatTemplate） │  │   ↳ id / name / format   │
│   ↳ MLX 內建（mlx-swift-lm 自帶）  │  │   ↳ chatTemplate hint    │
│   ↳ 覆寫機制（讓 user fine-tune）  │  │   ↳ ctxLen / sampler def │
│  → 修正 Smoking Gun（chat 路徑統一）│  │   ↳ backend hint         │
└────────────────────────────────────┘  └──────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────┐
│  lib/core/platform/  ←  PlatformAdapter (抽象)                   │
│      ↳ DirectoryService（已有雛形，補 macOS / Windows）          │
│      ↳ NativeLibraryLoader（封裝 ios/android/windows/macos 載入）│
│      ↳ CapabilityDetector（Apple Silicon? memory? GPU?）         │
└─────────────────────────────────────────────────────────────────┘
                                  ↓
┌─────────────────────────────────────────────────────────────────┐
│  Native：                                                        │
│   iOS    : libllama-*.a (b7493) ✅  +  mlx-swift-lm (SPM) 🆕    │
│   Android: libllama.so (b7493)  ✅                              │
│   Windows: llama.dll (重 build → b7493) 🔧                      │
│   macOS  : libllama.a (從零 build) 🆕  +  mlx-swift-lm (SPM) 🆕 │
└─────────────────────────────────────────────────────────────────┘
```

### 模組落點

| 路徑 | 檔案 / 子模組 | 狀態 |
|------|--------------|------|
| `lib/core/inference/` | `inference_backend.dart`、`inference_session.dart`、`backend_selector.dart`、`llama_cpp/`、`mlx/`、`sampling_params.dart` | 🆕 新增 |
| `lib/core/prompt/` | `chat_template.dart`、`prompt_renderer.dart` | 🆕 新增 |
| `lib/core/model/` | `model_profile.dart`（取代/延伸 `RecommendedModelConfig`） | 🆕 新增 |
| `lib/core/platform/` | `platform_adapter.dart`、`native_library_loader.dart`、`capability_detector.dart` | 🆕 新增 |
| `lib/core/engine/llama_cpp/` | 既有 `llama_cpp_ffi.dart` 包進 `LlamaCppBackend` | ♻️ 重組 |
| `lib/core/lm.dart` | 拆解、`UnifiedLM` 整類刪除 | 🗑️ 刪除 |
| `lib/core/format/prompt_format.dart` | dead code | 🗑️ 刪除 |
| `lib/ui/shared/inference/` | `generation_controller.dart`、`inference_settings.dart` | 🆕 新增 |
| `lib/ui/chat/view_model/` | 收編 stream/metrics 邏輯到 `GenerationController` | ♻️ 重構 |
| `lib/ui/completion/view_model/` | 同上 | ♻️ 重構 |
| `lib/data/services/directory_service.dart` | 補 macOS / Windows 實作 | ➕ 擴充 |
| `pubspec.yaml` | 加 `flutter_riverpod`、`pigeon`（dev_dep） | ➕ 依賴 |
| `ios/Runner/...` | 加 `mlx-swift-lm` SPM | ➕ 依賴 |
| `macos/Runner/...` | 從零 build `libllama.a`；加 `mlx-swift-lm` SPM | 🆕 從零 |
| `windows/libs/*.dll` | 重 build at b7493 | ♻️ 重 build |

### 推薦的遷移路徑（建造期會細化，這裡僅勾勒）

採用「**Parallel new modules + cutover by feature**」：
1. 新模組（`inference/` `prompt/` `model/` `platform/`）建立並通過單元測試
2. 舊 `UnifiedLM` 暫時保留以維持既有功能
3. 一個 feature 一個 feature 把 ViewModel 切換到新介面（Completion 先，Chat 後 — Chat 需要驗證 Smoking Gun 修復）
4. 全部切換後刪除 `lib/core/lm.dart` 與 `lib/core/format/prompt_format.dart`
5. macOS / Windows / MLX 由「平台適配層」啟動，可獨立進度

避免「big-bang」原因：v0.1 範圍大，big-bang 風險高且難中途回退。

---

## 4. 方案評估 [DONE — 整合藍圖通過評估]

各項決策的方案評估已在「問題定義 + 背景研究 + 個別 Q&A」中逐項進行。本節彙整風險與緩解：

| 風險 | 機率 | 影響 | 緩解 |
|------|------|------|------|
| MLX bridge 設計反覆 | 中 | 中 | 原型驗證 Spike #1 |
| macOS llama.cpp build 卡關（code signing、Apple Silicon vs Intel） | 中 | 高 | Spike #2，先驗證 build 流程 |
| Desktop platform abstraction 一次到位太理想 | 中 | 中 | Spike #3，先做 minimum viable 適配 |
| Riverpod 引入導致大量檔案改動 | 高 | 低 | 不為改而改：只把碰到的 VM 遷移，老地方暫留 ChangeNotifier |
| Smoking Gun 修復後 Gemma/Qwen/Llama 3 行為變化 | 高 | 中 | 修復後對每個推薦模型跑驗證對話 |
| llama.cpp ABI 雖頭檔一致但實作有差 | 低 | 中 | 重 build 後跑 `testLibrary()` + 一次完整推論 |
| ViewModel 瘦身過度拉長時程 | 中 | 中 | 把 VM 瘦身放在每個 feature 切換時順手做，不獨立 task |
| Pigeon 在 streaming token 量大時延遲感知 | 低 | 低 | Spike #1 順便量測 |

---

## 5. 原型驗證規劃 [DONE]

進入建造期前推薦三個 Spike，可平行進行：

### Spike #1：MLX Hello World on iOS（最重要）
**目標**：在 iOS Runner 內整合 mlx-swift-lm，跑通「載入 mlx-community/Llama-3.2-1B-Instruct-4bit → tokenize → generate → stream 第一段文字」。Pigeon channel 跑通。

**驗證**：
- mlx-swift-lm SPM 可在 Flutter Runner 整合
- Pigeon 的 streaming channel pattern 在 mlx 場景可用
- mlx-community 格式模型可下載並載入
- 量測：token rate 跟 llama.cpp 在同機器上的差距

**產出**：可丟掉的原型程式碼 + 量測報告 + bridge 介面草案

### Spike #2：macOS llama.cpp Build
**目標**：用 `llama.cpp/` 上游編出 macOS arm64 / x86_64 universal static library，整合進 macos Runner，能 `flutter run -d macos` 跑通推論。

**驗證**：
- macOS build 腳本（mirror iOS pattern）
- Code signing / entitlements 是否需特殊處理
- `Platform.isMacOS` 分支在現有 FFI loader 內可用

**產出**：build script + 一份 `scripts/llama.cpp_MacOS_Build.md` + macOS libllama.a

### Spike #3：Platform Adapter Skeleton
**目標**：為 macOS / Windows 補 `DirectoryService` 實作，並引入 `PlatformAdapter` 統合介面。Run on Windows + macOS：app 能 boot、能掃模型資料夾、能下載模型（不需推論）。

**驗證**：
- 既有 `DirectoryService` pattern 可擴充至 Desktop
- `path_provider`、`permission_handler` 等套件在 Desktop 行為
- Hive box / file picker 等周邊在 Desktop 可用

**產出**：Desktop 平台適配的最小骨架，為 Spike #2 完成後的 Desktop demo 鋪路

### Spike 執行建議

- 三個 Spike 各 1-3 天，**Spike #1 與 #3 可平行**（不同子系統）
- Spike #2 因為涉及 macOS 機器，依賴你的硬體可及性
- Spike 結束後若有 spike 證實設計需調整，回頭更新 plan.md

---

## 6. 決策 [DONE 2026-05-21]

### v0.1 最終範圍

**核心交付**：
1. **架構重構**：4 個新模組（`inference/`、`prompt/`、`model/`、`platform/`）落地
2. **後端抽象**：`InferenceBackend` 介面；`LlamaCppBackend` 遷移完成；`MlxBackend` 透過 Pigeon + mlx-swift-lm 完成
3. **Prompt 統一層**：收編 `applyChatTemplate` + ViewModel 手刻邏輯，修正 Smoking Gun
4. **ModelProfile**：擴充模型 metadata（format / chatTemplate hint / ctxLen / sampler default / backend hint）
5. **Platform 抽象**：iOS/Android 沿用、macOS/Windows 補實作
6. **ViewModel 瘦身**：`GenerationController` + `InferenceSettings` 抽出
7. **DI 引入**：Riverpod
8. **llama.cpp**：pin b7493；Windows 重 build；macOS 從零 build
9. **MLX**：iOS + macOS 透過 mlx-swift-lm（Path A）
10. **Desktop**：Windows + macOS 最小可跑 demo
11. **Design System 調查報告**（不實作）
12. **SLM 適配（文字 only）**：Gemma 4 (E2B/E4B)、Llama 3.2 1B 補強、Qwen 3.5 (0.8B/2B)

**留 v0.2**：
- iOS / Android Beta 等級 UX 打磨
- Desktop Alpha 等級 UI（含 Design System 實作 + 暗黑模式）
- **Multi-modal 模型**：Gemma 4 vision、Llama 3.2 11B Vision（含 image input pipeline / vision encoder / UI 上傳圖）
- **更大型 SLM**：Gemma 4 26B MoE / 31B Dense、Qwen 3.5 4B/9B
- 其他 SLM 系列適配：Phi-4 等
- Beta 等級的測試覆蓋與 CI

### 下一步

進入定義期（plan.md），把藍圖拆成 task list。

### 開放決策（進定義期前需確認）

- [ ] **Spike 是否要在進 plan 前先跑**？還是 plan 內排程 Spike 為早期任務？
- [ ] **是否需要為 v0.1 設明確里程碑日期**？或者每完成一個 epic 就 release internal build？
- [ ] **macOS 開發機可及性**：你手邊有 Apple Silicon Mac 可開發 + 測 MLX 嗎？

---

## 相關循環

- 過往 alpha.1 / alpha.2 開發筆記位於 `docs/develop_notes/`，含 FFI 整合、Android/iOS 整合的歷史脈絡，可作為架構 Review 的輸入

---

## 討論記錄

| 日期 | 重點 | 待辦 |
|------|------|------|
| 2026-05-21 | 啟動 v0.1 循環，五大目標列出 | 等用戶釐清範圍、時程 |
| 2026-05-21 | 範圍收斂：v0.1 = 架構重構 + 後端抽象化（llama.cpp + MLX）；Design System 僅研究、SLM 延後 v0.2；相容性可打破；MLX 路徑待研究 | 補時程、團隊、架構痛點後進入背景研究 |
| 2026-05-21 | 痛點確認：FFI 耦合 + Prompt/Config 難擴充；Platform abstraction 納入 v0.1 含 Desktop 最小 demo；時程緊湊但無 deadline | 進入背景研究：先做現有架構盤點 |
| 2026-05-21 | A 線 quick scan 完成：證實兩大痛點；發現 chat 路徑 prompt 模板可能行為錯誤；`DirectoryService` 已有平台抽象雛形；`llama.cpp/` 根目錄為 untracked（疑似預備中的新版） | 等用戶選擇 deep-dive 區域 |
| 2026-05-21 | A 線 deep dive 完成：Smoking Gun 確認屬實；FFI 公開 API 盤點完成；Model metadata 缺口識別；衍生 6 個重構候選方向（inference/prompt/model/platform 模組 + VM 瘦身 + DI 決策）；Smoking Gun 處置 = 在重構新 prompt layer 時順帶修正 | 進入 B 線：llama.cpp upstream 調查 |
| 2026-05-21 | A 線決策對齊：VM 瘦身=抽 `GenerationController` + `InferenceSettings`；DI=引入 Riverpod | 進入 B 線 |
| 2026-05-21 | B 線完成：llama.cpp 已在 b7493；iOS/Android 二進位已就位；Windows DLL 舊需重 build；macOS 無 lib 需從零 build | 進入 C 線：MLX 路徑比較 |
| 2026-05-21 | C 線完成：MLX ecosystem 確認（Apple 官方+Ollama 背書）；三條路徑（A=mlx-swift+Pigeon、B=mlx-c+ffi 不建議、C=Swift wrapper+@_cdecl+ffi）；推薦 A | 等用戶決策 A vs C，再進「方案發想」 |
| 2026-05-21 | 解釋 Path A vs C 細節（為何要 Pigeon、@_cdecl 限制、streaming callback 難點、工作量估計）；用戶確認 Path A | 整合藍圖 |
| 2026-05-21 | 探索期完成：整合藍圖、模組落點、風險矩陣、3 個 Spike 規劃、最終 v0.1 範圍確認；待用戶決策 Spike 排程後進定義期 | plan.md |
| 2026-05-21 | plan.md 草稿產出後，用戶提議納入 SLM 適配；新增 EP-12（Gemma 4 / Llama 3.2 1B / Qwen 3.5 0.8B-2B，文字 only）；multi-modal 明確留 v0.2 | 待用戶 review plan.md |

---

## 待釐清問題

- [x] ~~範圍切分~~ → v0.1 = 架構重構 + 後端抽象化（llama.cpp 升級 + MLX）
- [x] ~~時間表~~ → 緊湊但無硬 deadline；建造期需明確 step-by-step 里程碑
- [ ] **團隊**：個人開發還是團隊？是否有人協助 MLX / iOS 端？
- [x] ~~資料相容~~ → 可打破，重灌即可
- [ ] **MLX 路徑**：背景研究階段比較 mlx-swift vs mlx C API，再回來提案
- [x] ~~Design System~~ → 本循環只做調查報告，實作留 v0.2
- [x] ~~架構痛點~~ → FFI 耦合 + Prompt/Config 難擴充（Review 兩大切入點）
- [x] ~~Desktop 預留~~ → Platform abstraction 完整做完，Desktop 含最小可跑 demo
