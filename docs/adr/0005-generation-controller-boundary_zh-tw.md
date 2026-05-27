# ADR-0005：GenerationController 與 ViewModel 的邊界劃分

- **狀態**: 已接受（Accepted）
- **決策日期**: 2026-05-21
- **決策者**: Bobson Lin

> 本文為 [0005-generation-controller-boundary.md](./0005-generation-controller-boundary.md) 的正體中文版。
> 如兩版有出入，以英文版為準。

## Context（背景與問題）

v0.1 以前，`ChatViewModel` 與 `CompletionViewModel` 各自在處理 UI 狀態的同時，也包辦了完整的推論生命週期：

- 建立與管理 `InferenceSession`（或舊版 `UnifiedLM`）。
- 直接在 ViewModel 內部驅動 token 生成迴圈。
- 將 streaming token 累積到 UI 狀態。
- 透過臨時的 boolean flag 實作取消機制。
- 在兩個 ViewModel 裡分別重複計算指標（TTFT、TPS、stop reason）。

`CompletionViewModel` 已成長至 **371 行**。它難以單元測試（任何測試都需要一個活的 `InferenceSession` 或精心設計的假物件），而且新增指標或後端特定行為需要在多處修改。

觸發此次重構的兩個具體問題：

1. **可測試性**：生成邏輯與 `ChangeNotifier` 狀態混雜，使得隔離測試極為困難。一個沒有 Flutter 依賴的專屬 controller 可以用簡單的 `InferenceSession` stub 進行測試。

2. **指標重複**：TTFT 和 TPS 的計算被複製貼上到 `CompletionViewModel` 和 `ChatViewModel`，且實作略有不同，使得一致的指標回報難以保證。

## Decision（決策）

抽出 `GenerationController`——一個純 Dart 類別（無 Flutter、無 Riverpod），負責生成編排：

| 責任 | 歸屬 |
|------|------|
| 驅動 `InferenceSession.generate` | `GenerationController` |
| 計算 TTFT 與 TPS | `GenerationController` |
| 協同式取消（`cancel()`） | `GenerationController` |
| 發出 `Stream<GenerationEvent>` | `GenerationController` |
| UI 狀態（訊息列表、`isGenerating`、錯誤文字） | ViewModel |
| Session 生命週期（建立 / 重用 / dirty flag） | ViewModel |
| 訂閱事件並更新 UI 狀態 | ViewModel |

兩端只透過 `Stream<GenerationEvent>` 溝通：

```
GenerationEvent
  ├── GenerationToken(String token)
  ├── GenerationDone(GenerationMetrics)   ← TTFT、TPS、stop reason、token 數
  └── GenerationError(Object, StackTrace?)
```

`GenerationController.run(session, messages)` 是純 async generator；它不帶任何 widget 或 provider 依賴，可在純 `dart test` 中搭配 stub `InferenceSession` 進行測試。

ViewModel 持有一個 `GenerationController` 實例和一個 `StreamSubscription`。在 `sendMessage` / `run` 時呼叫 `_controller.run(...)`，訂閱串流，並將每個事件映射為狀態變更後呼叫 `notifyListeners()`。

## Consequences（後果）

### 正面影響
- `GenerationController` 有 **14 個專屬單元測試**，涵蓋正常生成、串流中取消、錯誤傳遞、並發執行保護。無一需要 Flutter test harness。
- `CompletionViewModel` 從 **371 → 244 行**（減少 34%），超越 EP-6 計畫設定的 >30% 目標。
- TTFT 和 TPS 在一個地方計算（`GenerationController.run`）；兩個 ViewModel 都透過 `GenerationDone` 的 `GenerationMetrics` 接收，沒有任何重複。
- 未來的第三個 ViewModel（例如語音或文件模式 UI）可直接重用 `GenerationController`，不需要重複生成邏輯。
- 新增後端不需要修改任何 ViewModel——只需要一個 `InferenceSession` 實作。

### 負面影響
- 兩個物件（`GenerationController` + ViewModel）共享一個必須協調的生命週期。如果 ViewModel 在生成進行中被 dispose，它必須先呼叫 `_controller.cancel()` 和 `_sub?.cancel()` 再釋放串流訂閱；若遺漏取消，底層 `InferenceSession` 會繼續運行並消耗記憶體。
- `StreamSubscription` 管理在每個 ViewModel 的 `sendMessage` / `dispose` 路徑增加了 boilerplate。這是 Flutter 中廣為人知的 pattern，但正確實作並非零成本。

### 中性影響
- `GenerationMetrics` 攜帶 `StopReason`（`completed | cancelled | error`）、TTFT、TPS、token 數。ViewModel 將這些映射到自己的顯示型別（`CompletionViewModel` 的 `MetricsData`、`ChatViewModel` 的 `MessageMetrics`）；映射輕量，但若 `GenerationMetrics` 新增欄位，這裡也需要同步更新。
- `GenerationController` 不是 Riverpod provider——它在每個 ViewModel 內部直接實例化。這讓 controller 不與 DI 框架耦合；如果未來需要跨畫面共用的 controller（例如背景生成），可以在那時再提升為 provider。

## Alternatives Considered（備選方案）

### 生成邏輯留在 ViewModel

延續 v0.0.x 的做法，每個 ViewModel 直接驅動生成。

- **Pros**：檔案數量少；不需要管理串流訂閱。
- **Cons**：原本的痛點依然存在——無法隔離測試、指標重複、每個新 ViewModel 都需要重新實作同樣的邏輯。
- **否決原因**：僅可測試性問題就足以支持抽取；指標重複問題更進一步確認了這個方向。

### 引入 BLoC（`flutter_bloc`）

將生成邏輯和 UI 狀態移入 BLoC，用 `Event` → `State` 轉換驅動串流。

- **Pros**：廣為人知的 pattern；明確的事件/狀態圖易於推理。
- **Cons**：在 Riverpod 已引入的情況下再加入 `flutter_bloc`，引入了兩種競爭的狀態管理慣用法。Riverpod 已涵蓋 DI 和 provider 需求；BLoC 層不帶來任何功能增益，只增加認知負擔。
- **否決原因**：Riverpod 已提供 BLoC 帶來的功能；第二個狀態管理函式庫不合理。

### 使用 Riverpod `AsyncNotifier` 管理生成

將生成狀態暴露為 Riverpod `AsyncNotifierProvider`，由 Riverpod 管理 async 生命週期。

- **Pros**：符合 Riverpod 慣用法；widget 可直接 `watch` 生成狀態，不需要 `ChangeNotifier`。
- **Cons**：`AsyncNotifier` 不能乾淨地建模有多個中間狀態（每個 token）和終止狀態（完成/錯誤）的串流序列。把 `Stream` 強塞進 `AsyncNotifier` 會產生阻抗失配。現有的 `ChangeNotifier` + `Stream` pattern 對這個場景更簡單。
- **否決原因**：生成的 streaming 本質與 `AsyncNotifier` 的單一值 async 合約不符。

## References（參考資料）

- `lib/ui/shared/inference/generation_controller.dart` — `GenerationController`、`GenerationEvent` 階層、`GenerationMetrics`、`StopReason`。
- `lib/ui/completion/view_model/completion_viewmodel.dart` — 抽取後的 ViewModel（244 行）；`MetricsData` 映射。
- `lib/ui/chat/view_model/chat_viewmodel.dart` — 抽取後的 ViewModel（277 行）；`MessageMetrics` 映射。
- `lib/core/inference/inference_session.dart` — `GenerationController` 消費的 `InferenceSession` 合約。
- Git commit `7c60863` — ViewModel 遷移與 Smoking Gun 修復同步落地（task-603 + task-604）。
- `.dev/cycles/2026-05-21-v0.1-major-refactor/plan.md` — EP-6 任務定義與 >30% 行數減少目標。
- `.dev/cycles/2026-05-21-v0.1-major-refactor/construction.md` — task-601（`GenerationController` 抽取）與 task-603/task-604（ViewModel 遷移）。
- ADR-0004：ChatTemplate 抽象化——與 ViewModel 遷移同一個 commit 落地的 Smoking Gun 修復。
