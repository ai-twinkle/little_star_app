# ADR-0003：Pigeon Streaming Pattern（Swift → Dart Token Stream）

- **狀態**: 已接受（Accepted）
- **決策日期**: 2026-05-21
- **決策者**: Bobson Lin

> 本文為 [0003-pigeon-streaming-pattern.md](./0003-pigeon-streaming-pattern.md) 的正體中文版。
> 如兩版有出入，以英文版為準。

## Context（背景與問題）

LLM 生成本質上是 streaming 操作：模型每次產生一個 token，耗時從數百毫秒到數秒不等。使用者體驗仰賴每個 token 一產出就立即送到 UI。

Pigeon 的預設合約是 **request–response**：Dart 呼叫 host method，Swift 計算結果後回覆一次。這個模式無法映射到持續的 token stream。需要一個解法能夠：

1. 讓 Swift **主動推送** token 給 Dart，不需要 Dart 輪詢。
2. 支援**協同式取消（cooperative cancellation）**——Dart 可在串流進行中中止生成。
3. 可靠地傳遞**錯誤**與**完成訊號（done sentinel）**。
4. 在串流中一併傳遞**指標（tokens/sec）**，不需額外呼叫。
5. 保持型別安全；避免非型別的 `dynamic` channel payload。

## Decision（決策）

採用**分離 channel pattern**，兩個 Pigeon 構件協同運作：

### Host API（Dart → Swift，fire-and-forget 啟動 + 取消）

```
MlxInferenceHostApi.startGeneration(messages, params)  // 啟動生成
MlxInferenceHostApi.cancelGeneration()                  // 協同式取消
```

`startGeneration` 立即回傳（不等待完整輸出）。Swift 建立一個 `Task` 在內部驅動 `mlx-swift-lm` 的 async 生成迴圈。這讓 Pigeon host call 不會阻塞 platform thread。

### Event stream（Swift → Dart，推送）

Pigeon 的 `@EventChannelApi` 產生：
- Swift 端的 `StreamHandler`（`MlxTokenStreamHandler`），接收 `PigeonEventSink<MlxTokenEvent>`。
- Dart 端的 `Stream<MlxTokenEvent>` 函式（`onToken()`）。

Swift 對每個 token 呼叫 `sink.success(MlxTokenEvent)`。最後一個 event 攜帶 `isDone: true` 與最終的 `tokensPerSecond` 數值。

### Token event 結構

```dart
class MlxTokenEvent {
  final String token;            // 文字片段（done sentinel 時可能為 ""）
  final bool isDone;             // 僅最後一個 event 為 true
  final double? tokensPerSecond; // 每個 token 都附帶
}
```

### Dart 端組裝（`MlxChannel.generate`）

```dart
Stream<MlxTokenEvent> generate(messages, {params}) async* {
  await _host.startGeneration(messages, effectiveParams); // fire-and-forget
  await for (final event in onToken()) {
    yield event;
    if (event.isDone) break;  // 關閉 stream
  }
}
```

### 取消機制

Dart 呼叫 `MlxChannel.cancel()` → `_host.cancelGeneration()`。Swift 端對執行中的生成 task 執行 `Task.cancel()`。Swift 的 `for await` 迴圈在每次迭代檢查 `Task.isCancelled` 並 break；event stream 自然結束（使用者主動取消不會發出錯誤 event）。

### 錯誤傳遞

若 Swift 在 `loadModel` 或 `startGeneration` 拋出例外，Pigeon 會在 Dart 端以 `PlatformException` 呈現。`MlxChannel` 讓這些例外往上傳；`MlxInferenceSession` 捕捉後轉換成 `GenerationError` event，與 `LlamaCppSession` 的行為一致。

## Consequences（後果）

### 正面影響
- Dart 接收到 `Stream<MlxTokenEvent>`——與呼叫端對 `LlamaCppSession` 的期待合約相同，使兩個後端在 `InferenceSession` 層完全可互換。
- 取消機制乾淨且協同；取消後不留殘存的 Swift task。
- `tokensPerSecond` 隨每個 token event 一起傳遞，UI 無需額外 RPC 即可顯示即時 TPS 數字。
- Pigeon 的程式碼生成確保兩端保持同步；在 Pigeon schema 的 `MlxTokenEvent` 加欄位，Dart 與 Swift glue 同步重新產生。

### 負面影響
- **未實作背壓（back-pressure）**：若 Dart 消費端速度較慢（例如 UI jank），token event 會在 platform channel buffer 累積。以目前 edge LLM 的 token rate（< 50 tok/s）來說，v0.1 不成問題，但在更高 rate 下可能需要 buffer 策略。
- `isDone` sentinel 是應用層面的慣例，不是 platform channel 的原生機制。兩端都必須遵守這份合約；任何一端有 bug（例如從未發出 `isDone: true`）將使 Dart `Stream` 永遠不關閉。
- 需要同時設定兩個 Pigeon 構件（HostApi + EventChannelApi）並在 `AppDelegate` 中註冊——比單一 MethodChannel 多一些 boilerplate。

### 中性影響
- 這個 pattern 本質上是 EventChannel，但透過 Pigeon 的 `@EventChannelApi` 實現，在保留型別安全的同時符合 Flutter 的慣用 streaming 風格。
- `startGeneration` 是 fire-and-forget 設計；Dart 端要到收到 `isDone` sentinel 或 event stream 的 `PlatformException` 才知道生成是否順利完成。

## Alternatives Considered（備選方案）

### 輪詢方式（重複呼叫 host API）

Dart 在呼叫 `startGeneration` 後，用緊密迴圈輪詢 `MlxInferenceHostApi.nextToken()`。

- **Pros**：不需要 event channel；只需單一 HostApi 構件。
- **Cons**：輪詢頻率決定延遲下限；閒置時浪費 CPU；輪詢速率難以對齊實際 token 產出速率。
- **否決原因**：不必要的複雜度；對比 push channel 沒有延遲或吞吐量優勢。

### 原始 platform channel（不透過 Pigeon 的 EventChannel）

直接使用 Flutter 的 `EventChannel`，payload 為非型別的 `dynamic`。

- **Pros**：不需要 Pigeon 依賴；使用熟悉的 Flutter 原語。
- **Cons**：payload 的編解碼是手動且非型別的；新增或重命名欄位需要兩端手動修改，沒有編譯期檢查；兩端漂移難以察覺。
- **否決原因**：型別安全正是當初引入 Pigeon 的主要原因（見 ADR-0001）。

### Pigeon `@FlutterApi` callback（非 event channel 版本）

在 Dart 端註冊 `MlxInferenceFlutterApi`；Swift 直接呼叫 `flutterApi.onToken(event)`，不經過 event channel。

- **Pros**：設定比 `@EventChannelApi` 略簡單。
- **Cons**：`@FlutterApi` 從 Swift 呼叫是 fire-and-forget，沒有 per-message 的反向通道；從串流傳遞錯誤的結構較不清晰。`@EventChannelApi` 在 Dart 側產生有內建 end-of-stream 訊號的 `Stream`，語意更乾淨。
- **否決原因**：對於有終止 event 的連續序列，`@EventChannelApi` 是更符合慣用的選擇。

## References（參考資料）

- ADR-0001：MLX 整合走 Path A——選用 Pigeon 作為 bridge 層的理由。
- ADR-0002：Native Bridge 雙軌策略——MLX 為何使用 Pigeon 而非 FFI 的背景。
- `lib/core/engine/mlx/mlx_channel.dart` — `MlxChannel.generate` 與 `cancel`。
- `lib/core/engine/mlx/mlx_inference.g.dart` — Pigeon 產生的 `MlxTokenEvent`、`MlxInferenceHostApi`、`onToken()` stream。
- `ios/Runner/MlxBridge/MlxInferenceBridge.swift` — `startGeneration` Task 迴圈、`MlxTokenStreamHandler.emit`、`cancelGeneration`。
- `ios/Runner/MlxBridge/MlxInference.g.swift` — Pigeon 產生的 Swift glue。
- `.dev/cycles/2026-05-21-v0.1-major-refactor/exploration.md` — C 節，Spike #1 streaming channel pattern 設計筆記。
- `.dev/cycles/2026-05-21-v0.1-major-refactor/construction.md` — Spike #1 實作與 token stream 驗證。
