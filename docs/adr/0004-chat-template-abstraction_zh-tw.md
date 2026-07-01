# ADR-0004：ChatTemplate 抽象化取代 PromptFormat

- **狀態**: 已接受（Accepted）
- **決策日期**: 2026-05-21
- **決策者**: Bobson Lin

> 本文為 [0004-chat-template-abstraction.md](./0004-chat-template-abstraction.md) 的正體中文版。
> 如兩版有出入，以英文版為準。

## Context（背景與問題）

### 舊做法：`PromptFormat`

v0.1 以前，prompt 格式化由 `lib/core/format/prompt_format.dart` 處理（已於 task-302 刪除）。它包含：

- `PromptFormatType` — 列舉，有 `raw`、`chatml`、`llama2`、`alpaca` 等變體。
- `PromptFormat` — 抽象類別，有一個 `format(String input)` 方法，接收**單一字串**後包上模板 token。
- `SequenceFilter` — streaming stop-sequence 過濾器。
- `ModelParams.format` — 攜帶模型對應 `PromptFormatType` 的欄位。

這個設計有兩個根本缺陷：

1. **扁平字串輸入**：`PromptFormat.format` 接收的是一個預先組裝好的字串，而不是結構化的對話。呼叫端必須自行把 `List<ChatMessage>` 拼成一個字串再傳進來。這讓模板完全看不到輪次邊界、角色、或系統提示的放置位置。

2. **錯誤的 token 家族**：`ChatViewModel._buildPromptFromHistory()` 被硬寫成用 `<|user|>` / `<|assistant|>` / `<|system|>` token 包裝對話輪次——這些 token 只存在於特定模型家族（例如 Phi、某些 Mistral 變體）。這些 token 在 Gemma 或 Llama 3 的 GGUF 模型中**根本不存在**，它們使用完全不同的控制序列。

### Smoking Gun（致命 Bug）

當 App 開始支援 Gemma 和 Llama 3 模型（與原先的 Phi 系模型並存）後，`ChatViewModel._buildPromptFromHistory()` 就靜默地對每個非 Phi 模型產出格式錯誤的 prompt——模型收到它從未被訓練過的 token，導致輸出退化或無意義。由於舊程式碼沒有每個模板的單元測試覆蓋，這個 bug 沒有被任何測試捕捉。

被刪除的問題程式碼：

```dart
// 舊版（對 Gemma / Llama 3 是錯的）：
String _buildPromptFromHistory() {
  buffer.writeln('<|system|>');          // Phi-style token
  if (msg.isUser) {
    buffer.writeln('<|user|>');          // Phi-style token
    buffer.writeln('<|assistant|>');     // Phi-style token
  }
}
```

### v0.1 的需求

在同一個 App 中支援 Gemma 2、Llama 3.x、Qwen 2/3，意味著 prompt 組裝邏輯必須**具備模型家族意識**、**結構化**（操作 `List<ChatMessage>` 而非預先拼接的字串），並且**可獨立測試**。

## Decision（決策）

引入 `ChatTemplate` 抽象，有四個具體實作和一個 resolver：

```
ChatTemplate（抽象）
├── GemmaChatTemplate      — <bos><start_of_turn>user / model
├── Llama3ChatTemplate     — <|begin_of_text|> + header tokens + <|eot_id|>
├── ChatMlChatTemplate     — <|im_start|> / <|im_end|>（Qwen 2 & 3）
└── FallbackChatTemplate   — 純文字「User: / Assistant:」格式
```

`ChatTemplate.render(List<ChatMessage> messages, {String? systemPrompt})` 接收結構化對話，回傳完整組裝好的 prompt 字串——結尾永遠是模型的開頭 token，使推論以 assistant 身份繼續。

`ChatTemplateResolver.resolve(ModelProfile, [ChatTemplate? override])` 透過檢查 `ModelProfile.chatTemplateHint`（`gemma | llama3 | qwen2 | qwen3 | unknown`）選取對應實作。明確的 override 優先，支援每個 session 的客製化或測試中注入假模板。

`chatTemplateProvider`（`Provider.family<ChatTemplate, ModelProfile>`）透過 Riverpod 將 resolver 注入 ViewModel 和 Session，確保正確的模板通過依賴注入傳入。

舊的 `PromptFormat`、`PromptFormatType`、`SequenceFilter`、`ModelParams.format` 全數刪除。

## Consequences（後果）

### 正面影響
- 每個模型家族的 prompt 由專屬的、可獨立單元測試的類別組裝。新增模型家族只需一個新的 `ChatTemplate` 子類別和 `ChatTemplateResolver` 裡的一個分支。
- Smoking Gun 修復：`ChatViewModel` 不再手動組裝 prompt；`InferenceSession`（透過 `LlamaCppSession`）呼叫 native GGUF 端的 `applyChatTemplate`，它知道模型檔內嵌的精確模板。MLX 路徑由 `mlx-swift-lm` 原生處理 chat template。
- 測試覆蓋精準：每個模板實作都有針對系統提示放置位置、角色 token 正確性、輪次分隔符正確性的專屬測試。
- `ChatTemplateResolver.resolve` 的 `override` 參數同時支援執行期客製化與測試中的假模板注入。

### 負面影響
- 每個新模型家族都需要一個新的 `ChatTemplate` 實作和一個新的 `ChatTemplateHint` 變體；對於未知模型沒有零成本的路徑。`FallbackChatTemplate` 提供了降級但可用的安全網，但輸出品質會低於模型專屬模板。
- `override` 機制功能強大，但在呼叫端沒有文件說明；呼叫端必須查閱 `CONTRIBUTING.md`（或本 ADR）才能了解何時使用它。

### 中性影響
- `LlamaCppSession` 將最終的 prompt 渲染委派給 llama.cpp 內建的 `applyChatTemplate`，而非直接呼叫 `ChatTemplate.render`。因此 `ChatTemplate` Dart 抽象主要用於 `ChatViewModel` 建構傳入 `InferenceSettings` 的上下文訊息，以及隔離測試 prompt 邏輯。

## Alternatives Considered（備選方案）

### 保留 `PromptFormat`，加入每個家族的 switch 分支

擴展現有 `PromptFormat`，用 switch 語句處理每個模型家族。

- **Pros**：最小改動；不需要新抽象。
- **Cons**：扁平字串輸入的根本限制依然存在；隨著模型家族增加，分支邏輯成為維護負擔；現有測試（如果有的話）對每個家族的正確性覆蓋不足。
- **否決原因**：根本問題——對預先拼接字串操作且不具輪次邊界意識——在不改變介面的情況下無法修復。

### Jinja2 風格模板引擎（從 GGUF metadata 執行期讀取模板）

在執行期載入 GGUF 檔內嵌的 chat template 字串，並用 Jinja2 風格引擎渲染（例如 Dart port 或 WebAssembly 建置）。

- **Pros**：模板完全由資料驅動；新增模型若其 GGUF 有良好格式的模板，不需要改程式碼。
- **Cons**：沒有成熟、無外部依賴的 Dart Jinja2 實作；WebAssembly 方案增加顯著的 binary 大小和啟動延遲；GGUF 檔所使用的 Jinja2 子集邊界情況難以全面測試。
- **否決原因**：v0.1 目標的四個模型家族不足以承擔依賴風險和複雜度。如果模型目錄大幅增長，未來循環可以重新評估。

## References（參考資料）

- `lib/core/prompt/chat_template.dart` — `ChatTemplate` 抽象類別與四個具體實作。
- `lib/core/prompt/chat_template_resolver.dart` — `ChatTemplateResolver` 與 `chatTemplateProvider`。
- `lib/core/model/model_profile.dart` — `ChatTemplateHint` 列舉。
- 已刪除：`lib/core/format/prompt_format.dart`（見 git commit `fd70f99`）。
- Git commit `4bb2e76` — ChatTemplate 抽象引入（task-301）。
- Git commit `7c60863` — ChatViewModel Smoking Gun 修復（task-604）。
- `.dev/cycles/2026-05-21-v0.1-major-refactor/plan.md` — EP-3 任務定義。
- `.dev/cycles/2026-05-21-v0.1-major-refactor/construction.md` — task-301 與 task-302 實作筆記。
