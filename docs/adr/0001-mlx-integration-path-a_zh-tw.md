# ADR-0001：MLX 整合走 Path A（mlx-swift-lm + Pigeon）

- **狀態**: 已接受（Accepted）
- **決策日期**: 2026-05-21
- **決策者**: Bobson Lin

> 本文為 [0001-mlx-integration-path-a.md](./0001-mlx-integration-path-a.md) 的正體中文版。
> 如兩版有出入，以英文版為準。

## Context（背景與問題）

v0.1 引入 MLX 作為第二條推論後端，與 llama.cpp 並存，目標是在 Apple Silicon（iOS，以及後續 macOS）上發揮硬體性能。兩個業界訊號確認了這個投資方向：

- **Apple WWDC 2025** 正式將 MLX 定位為 Apple Silicon 的官方 LLM 推論框架，與 Foundation Models framework 並行推進。
- **Ollama 在 2026 年 3 月宣告**已將 Apple Silicon 推論底層改為 MLX。

MLX 生態系以 Swift 為核心：

| 函式庫 | 角色 |
|--------|------|
| `mlx-swift` | MLX 的官方 Swift binding |
| `mlx-swift-lm` | 高階 LLM/VLM Swift package（載入、tokenize、生成、chat template、sampling） |
| `mlx-c` | 官方 C API；`mlx-swift` 內部即使用此包 |
| `mlx-community/*`（HuggingFace） | 預先量化模型（safetensors 格式，**與 GGUF 不相容**） |

App 既有架構已透過 `dart:ffi` 整合 llama.cpp。決策的核心問題是：MLX 要沿用 FFI，還是引入不同的 native bridge？評估了三條路徑：

- **Path A** — 在 Swift 端呼叫 `mlx-swift-lm`，透過 Pigeon 暴露給 Dart。
- **Path B** — 在 Dart 端透過 `dart:ffi` 直接呼叫 `mlx-c`。
- **Path C** — Swift 端以 `@_cdecl` 包裝 `mlx-swift-lm`，Dart 端透過 `dart:ffi` 呼叫。

決策於 `2026-05-21-v0.1-major-refactor` 循環的探索期完成（見 References）。主要考量因素：

1. **Token-by-token streaming** 是硬性需求——使用者體驗依賴它。
2. **時間預算**：v0.1 範圍已大，MLX 整合成本必須最小化。
3. **長期可維護性**：上游函式庫必須能持續跟進新模型族。

## Decision（決策）

採用 **Path A：`mlx-swift-lm` via Pigeon**。

Dart 端透過 Pigeon 產生的型別安全 channel（`MlxInferenceHostApi`）發出請求。Swift 端（`MlxInferenceBridge`）是 `mlx-swift-lm` 3.31.3 的薄包裝，透過 Swift Package Manager 引入 `MLXLLM`、`MLXLMCommon`、`MLXHuggingFace`。Streaming token 以 Pigeon `@FlutterApi` callback（`MlxInferenceFlutterApi`）主動回呼 Dart；`MlxChannel` 將其包裝成 `Stream<MlxTokenEvent>`。取消機制採協同式（cooperative cancel）：Dart 端呼叫 `MlxInferenceHostApi.cancel()`，Swift 端中斷生成迴圈。

## Consequences（後果）

### 正面影響
- `mlx-swift-lm` 包辦載入、tokenise、chat template、sampling，不需自行重寫任何一層。
- `mlx-community/*` 模型（4-bit、8-bit 量化）開箱即用。
- Pigeon 的 `@FlutterApi` callback pattern 自然映射為 Dart `Stream`，與 `LlamaCppBackend` 的 `Stream<GenerationEvent>` 合約一致。
- Apple 與 Ollama 背書，上游函式庫將持續追蹤新模型族。

### 負面影響
- 引入 Swift Package Manager 依賴（`mlx-swift-lm 3.31.3`、`swift-transformers`），iOS 與 macOS target 皆需設定。
- Native bridge **雙軌並存**（FFI 用於 llama.cpp、Pigeon 用於 MLX）——兩種生命週期與錯誤模型需在 `InferenceBackend` 抽象層調和。見 ADR-0002。
- Pigeon 相比直接 FFI 有些微 IPC 開銷。實測可接受：edge LLM token rate 通常 < 50 tok/s，Pigeon 往返延遲遠低於每個 token 的模型運算耗時。

### 中性影響
- MLX 使用 **safetensors** 模型格式（非 GGUF），模型管理（`ModelProfile`、下載服務）需要 `format: gguf | mlx` 欄位——兩種模型族無法共用同一下載路徑。
- macOS Runner 也需要 SPM 設定；整合方式與 iOS 相同，但 `MlxInferenceBridge` 分別在各 target 編譯。

## Alternatives Considered（備選方案）

### Path B — `mlx-c` via `dart:ffi`

`mlx-c`（v0.4.1）是 `mlx-swift` 背後使用的官方 C API。從 Dart 透過 FFI 呼叫，可與 llama.cpp 保持一致的 bridge 風格。

- **Pros**：單一 bridge 類型；熟悉的 FFI pattern。
- **Cons**：`mlx-c` 暴露的是低階張量操作，不是 LLM pipeline。要重現 `mlx-swift-lm` 提供的功能（safetensors loader、AutoTokenizer、chat template、KV-cache 管理、sampling），等於大型重寫。Streaming 透過 FFI callback（`Pointer<NativeFunction>`）在 Swift 物件生命週期管理上脆弱。
- **否決原因**：實作工作量爆炸；`mlx-c` 不承諾提供 LLM 層 API，長期維護負擔完全落在本 repo。

### Path C — Swift `@_cdecl` wrapper + `dart:ffi`

Swift 端以薄包裝呼叫 `mlx-swift-lm`，並以 `@_cdecl` 匯出 C 相容符號，Dart 端透過 FFI 呼叫。

- **Pros**：維持單一 FFI bridge；不需引入 Pigeon。
- **Cons**：`@_cdecl` 函式無法捕捉 Swift closure 或持有 Swift 物件——streaming 需走 polling 或 C function pointer callback，兩者都比 Pigeon 的訊息 channel 更易出錯。Swift 物件跨 FFI 邊界的生命週期管理也不容易。
- **否決原因**：streaming 是不可妥協的核心功能；`@_cdecl` 的限制使乾淨的 streaming 實作難以達成。

## References（參考資料）

- `.dev/cycles/2026-05-21-v0.1-major-refactor/exploration.md` — C 節「MLX 整合路徑比較」（line 225 起）；決策記錄於討論記錄。
- `.dev/cycles/2026-05-21-v0.1-major-refactor/construction.md` — Spike #1（MLX Hello World on iOS）與後續 MLX 整合任務。
- `lib/core/engine/mlx/mlx_channel.dart` — Pigeon channel 的 Dart facade。
- `lib/core/engine/mlx/mlx_inference.g.dart` — Pigeon 產生的 host/flutter API。
- `ios/Runner/MlxBridge/MlxInferenceBridge.swift` — Swift 端 bridge 實作。
- `ios/Runner/MlxBridge/MlxInference.g.swift` — Pigeon 產生的 Swift glue。
- `lib/core/inference/inference_backend.dart` — 兩個後端共同實作的 `InferenceBackend` 抽象。
- ADR-0002：Native bridge 雙軌策略（FFI + Pigeon）——保留雙軌的理由。
- ADR-0003：Pigeon streaming pattern——token streaming 設計細節。
