# ADR-0002：Native Bridge 雙軌策略（FFI for llama.cpp、Pigeon for MLX）

- **狀態**: 已接受（Accepted）
- **決策日期**: 2026-05-21
- **決策者**: Bobson Lin

> 本文為 [0002-dual-native-bridge.md](./0002-dual-native-bridge.md) 的正體中文版。
> 如兩版有出入，以英文版為準。

## Context（背景與問題）

v0.1 同時出貨兩個推論後端：

| 後端 | 原生函式庫 | 語言 | 支援平台 |
|------|------------|------|----------|
| `LlamaCppBackend` | `libllama-*.a` / `llama.dll` | C / C++ | iOS、macOS、Windows |
| `MlxBackend` | `mlx-swift-lm`（SPM） | Swift | iOS、macOS（Apple Silicon 限定） |

這兩個函式庫的整合介面先天不同：

- **llama.cpp** 提供純 C API。`dart:ffi` 可以直接 binding：Dart 層呼叫 C 函式，傳遞基本型態與原始指標，同步取得回傳值。Streaming 由 Dart 驅動 `llama_decode` / sampler 迴圈實現。

- **mlx-swift-lm** 是 Swift package，沒有穩定的 C API 表面。其生成 pipeline 是 async Swift（`async`/`await`、`AsyncStream`）。從 Dart 呼叫它的唯一實用途徑是透過 platform channel。選用 Pigeon 作為型別安全的 channel 層（見 ADR-0001）。

本 ADR 要回答的問題是：既然兩個後端基於充分理由選擇了不同的 bridge 技術，應該強制統一成單一 bridge，還是接受雙軌並存？

## Decision（決策）

接受 **雙軌 native bridge**：`dart:ffi` 用於 llama.cpp，Pigeon 用於 MLX。兩條 bridge 都隱藏在 `InferenceBackend` / `InferenceSession` 抽象之後。`BackendSelector` 在 runtime 根據 `ModelProfile.format` 與平台能力選取對應實作；呼叫端從不直接接觸 bridge 層。

這道抽象邊界是刻意設計、且承重的：它意味著未來新增第三條後端（例如 Core ML、ONNX Runtime）時，不需要修改選取邏輯或 ViewModel 層。

## Consequences（後果）

### 正面影響
- 每條 bridge 使用最適合其原生函式庫的工具——沒有強迫配接的多餘層。
- llama.cpp 保留直接 FFI，主後端的零 overhead 路徑完好無缺。
- MLX 保留 Pigeon，streaming 與取消在 Swift 端保持慣用寫法，不需對抗 `@_cdecl` 限制。
- llama.cpp 的 Desktop（Windows / Linux）支援不受 bridge 策略影響：`dart:ffi` 在所有平台皆可用；沒有註冊 `MlxBackend` 的平台，Pigeon 那側根本不會被 wire。

### 負面影響
- 兩套不同的生命週期模型須在抽象層調和：
  - FFI session 持有原生記憶體，dispose 時必須呼叫 `llama_free`。
  - Pigeon session 依賴 Swift ARC；取消透過 `MlxInferenceHostApi.cancel()` 呼叫實現。
- 錯誤傳遞方式不同：FFI 以整數 return code 表示錯誤，由 `LlamaCppSession` 轉成 Dart exception；Pigeon 以 `PlatformException` 表示錯誤，由 `MlxChannel` 轉成相同的 exception 類型。隨著錯誤場景增加，這份 mapping 必須保持同步。
- `BackendSelector` 帶有平台偵測邏輯（`supportsMLX`），每新增一個平台都需要更新。

### 中性影響
- `InferenceBackend.canHandle(ModelProfile)` 封裝了格式相容性與平台可用性的檢查，使兩個後端從呼叫端角度完全可互換。
- 若 llama.cpp 未來獲得 Apple Neural Engine execution provider，其整合路徑可能需重新評估——但這是 v0.2+ 的問題。

## Alternatives Considered（備選方案）

### 統一走 FFI（兩個後端都用 `dart:ffi`）

透過 `mlx-c` 或 Swift `@_cdecl` wrapper，把 MLX 也帶上 `dart:ffi`。

- **Pros**：單一 bridge 類型；一致的 mental model。
- **Cons**：`mlx-c` 沒有 LLM pipeline 層 API；`@_cdecl` Swift wrapper 無法捕捉 closure，streaming 難以實作。兩個選項都在 ADR-0001 詳細評估後被否決。
- **否決原因**：MLX streaming 需求排除了乾淨的 FFI 實作，詳見 ADR-0001 完整分析。

### 統一走 Pigeon（兩個後端都用 Pigeon）

把 llama.cpp 的 C API 包在 Objective-C 或 Swift host plugin 裡，再透過 Pigeon 暴露給 Dart。

- **Pros**：單一 channel 類型；兩端都有型別安全的產生程式碼。
- **Cons**：llama.cpp 已有 Dart 可直接呼叫的 C API——再套一層 ObjC/Swift 包裝是無謂的間接層，沒有任何功能收益。更重要的是，Pigeon 是綁定 Flutter platform channel 機制的，限定於 iOS/macOS/Android/Windows host runner；在純 Dart 測試環境（`dart test`）中無法使用。FFI 則在所有環境都能運作，包含使用 stub native lib 的單元測試。
- **否決原因**：在 llama.cpp 側增加不必要的間接層；降低主後端的可攜性與可測試性。

## References（參考資料）

- ADR-0001：MLX 整合走 Path A——Pigeon 用於 MLX 的選擇理由。
- ADR-0003：Pigeon streaming pattern——Pigeon 側 token streaming 設計細節。
- `lib/core/inference/inference_backend.dart` — 兩個後端共同實作的抽象（`canHandle`、`createSession`）。
- `lib/core/inference/backend_selector.dart` — 執行期後端選取邏輯（`BackendSelector`、`BackendOverride`、`BackendPlatform`）。
- `lib/core/inference/llama_cpp_backend.dart` — FFI 後端（`LlamaCppBackend`、`LlamaCppSession`、`LlamaFfiDriver`）。
- `lib/core/engine/llama_cpp/llama_cpp_ffi.dart` — 原始 FFI binding。
- `lib/core/engine/mlx/mlx_channel.dart` — Pigeon 的 MLX facade。
- `.dev/cycles/2026-05-21-v0.1-major-refactor/exploration.md` — C 節「MLX 整合路徑比較」；D 節「整合藍圖」（後端抽象設計）。
