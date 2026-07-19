# 繁中 Benchmark Prompt Set / 標準化測試協定

> 循環：2026-07-08-t1-benchmark-talk
> 用途：A03（Pixel 8a 快篩）、B01（MLX 繁中 sanity check）、C02/C05（benchmark 矩陣）共用同一份 prompt。
> 原則：**同一份繁中 prompt 集跑 2 backend × 2 裝置**，talk 用一張矩陣圖講完所有對比。

本檔是「資料本身也帶 Twinkle 色彩」的來源 —— prompt 全部繁體中文、聚焦台灣語境。

---

## Part 1 — 品質 / Demo prompt（繁中輸出品質判讀 + demo 錄影素材）

用於 A01/B01 的人工品質判讀，以及 D02 demo「T1 回答台灣語境問題」。
判讀重點：**是否使用繁體用字習慣**（避免「視頻/軟件/信息/質量」等簡中詞，應為「影片/軟體/資訊/品質」）、
台灣語境正確性、語氣自然度。

| ID | Prompt | 判讀重點 |
|----|--------|----------|
| Q1 | 請用三句話介紹台灣夜市文化，並推薦三樣必吃小吃。 | 小吃在地性、繁體用字 |
| Q2 | 「揪團」和「小確幸」這兩個詞是什麼意思？請各舉一個生活例子。 | 台灣流行語理解 |
| Q3 | 我要從台北車站到九份，不開車的話有哪些交通方式？請說明大致流程。 | 在地交通常識、不編造 |
| Q4 | 請解釋台灣的「統一發票」制度，以及為什麼發票會有中獎號碼。 | 制度正確性 |
| Q5 | 用台灣國中生能懂的方式，解釋什麼是「颱風假」是怎麼決定的。 | 語氣分層、在地制度 |
| Q6 | 幫我寫一段 100 字以內、給台灣朋友的中秋節祝福訊息，語氣輕鬆。 | 生成品質、繁中語感 |
| Q7 | 「這家餐廳 CP 值很高」是稱讚還是抱怨？為什麼台灣人常這樣說？ | 語用理解 |
| Q8 | 請比較繁體中文和簡體中文在用詞上的三個差異，各舉一例。 | 自我一致：務必用繁體 |

> ⚠️ system prompt 慣例（已查官方 model card, [twinkle-ai/gemma-3-4B-T1-it](https://huggingface.co/twinkle-ai/gemma-3-4B-T1-it)）：
> T1 **無強制 system prompt**，官方範例的 system 只是選用（如告知知識截止日）。chat template（含 tool-calling）已內嵌於
> `tokenizer_config` —— 這是 template 的真實來源。benchmark 為求可控，統一用一句繁中定調 system prompt
> （建議：「你是台灣的 AI 助理，請一律使用繁體中文與台灣用語回答。」），並在兩個 backend 用**完全相同**的 system prompt，
> 否則對比失真（見 plan.md task-B03）。Gemma 無獨立 system role，system 併入第一個 user turn（repo 內 `GemmaChatTemplate` 已如此處理）。

---

## Part 2 — 效能 prompt（受控輸入長度）

用於 benchmark 的 TTFT / decode t/s 量測。四個輸入長度 tier：**128 / 512 / 1024 / 2048 tokens**。

✅ **內容已定版（草稿，見下方待校準說明）**於 `lib/core/benchmark/prompt_tiers.dart`
（`PromptTier.l128/l512/l1024/l2048`）——這是 harness 實際讀取的來源，本節文字為對照/可讀版本，
兩邊需同步更新。

⚠️ **token 數為估計值，尚待用 T1 tokenizer 實測校準**：目前唯一的真實校準錨點來自
task-B03 上機記錄（construction.md，2026-07-18）：「很盤是什麼意思？」以 GGUF tokenizer 量得
**14 tokens**（8 個字元，含問號），換算約 **1.8 tokens/字元**。下表的目標字數即依此比例反推，
**非實測**——待實際跑 Benchmark 畫面（或 Completion 畫面既有的 Prompt tokens 欄位）量出真實
token 數後，回填本表與 `prompt_tiers.dart` 的 `targetTokenCount`。另外 MLX 的
`PromptMetricsSource` 尚未實作（見 construction.md task-B03「Completion 頁面...」段落），目前只能
用 GGUF/llama.cpp backend 校準；兩邊 tokenizer 詞彙表理論上共享同源（A01 已確認 GGUF 內嵌模板與
官方 tokenizer_config 逐 byte 一致），但實際 token 切分是否完全相同未驗證。

| Tier | 目標輸入長度（估計） | 內容骨架 | 草稿字數（不含追問句） | 固定生成上限 |
|------|--------------|----------|--------------|--------------|
| L128 | ~128 tokens | 單一問題，帶較多情境細節（非 Q3 原句，因 Q3 太短） | ~90 字 | 512（見 `kBenchmarkDefaultSettings`） |
| L512 | ~512 tokens | 一段台灣新聞/說明文（便利商店密度）+「請摘要成三點」 | ~370 字 | 同上 |
| L1024 | ~1024 tokens | 兩段對立觀點短文（夜市改建爭議）+「請比較兩段觀點差異」 | ~700 字 | 同上 |
| L2048 | ~2048 tokens | 6 輪環島旅行規劃對話（多輪 ChatMessage，非單一字串）+ 追問 | ~800 字（累計多輪） | 同上 |

**產出待辦（C02 校準時）**：用 Benchmark 畫面對每個 tier 各跑一次，讀 sample 的
`promptTokenCount`，跟目標值比對，字數不夠/超過就回頭調整 `prompt_tiers.dart` 內文，兩邊同步。

---

## Part 3 — 標準化測試協定（執行條件）

每次 benchmark run 必須遵守，確保可重現：

- [ ] **飛航模式**開啟（排除網路干擾）——app 無法讀取此狀態，純手動確認
- [ ] **固定螢幕亮度**（建議固定值，記錄於結果）——app 無法讀取此狀態，純手動確認
- [ ] **同電量起跑**（每組 run 從相同電量百分比開始，記錄起始/結束電量）——Benchmark 畫面
      preflight banner 會顯示目前電量，方便對照
- [ ] **三種「啟動狀態」分開記錄，絕不平均在一起**（見下方「冷啟動定義」，2026-07-18 上機時
      發現的問題：GGUF/MLX 都出現「同一 session 第一次生成」比「第二次」明顯慢，若把兩者混在
      一起取平均，數據會失真）
- [ ] **每組多次取樣**（建議 ≥3 次取中位數；harness `BenchmarkProtocolRunner` 預設每個 tier
      跑 1 次冷啟動樣本 + `warmRepeats`（預設 2，建議正式跑矩陣時調高到 ≥3）次暖啟動樣本）
- [ ] **組間降溫**（等 `thermalState` 回到 nominal 再跑下一組；Benchmark 畫面 preflight banner
      會標紅提醒）
- [ ] 固定 context 長度（依 task-A02 KV cache 實測結果拍板，`nCtx=4096`）
- [ ] 兩 backend 使用**完全相同**的 system prompt 與 sampling 參數（`kBenchmarkDefaultSettings`）

### 冷啟動定義（2026-07-18 上機發現後補寫，務必分開量測）

實機測試意外發現：**同一個 session 裡「第一次」生成，比「第二次」明顯慢**——
GGUF：440ms → 158ms TTFT；MLX 更明顯：3.75s → 552ms（詳見 construction.md task-B03「Completion
頁面...」段落）。研判是 GPU/Metal 的 kernel/pipeline JIT 在首次真正 dispatch 時的一次性成本
（llama.cpp 端規模較小、MLX 端規模大很多），兩邊都不是 bug，也都沒有對應的 app 層繞過方法。

這代表單純的「冷/暖」二分不夠精確，實際上有 **三種需要分開記錄、不能互相平均** 的狀態：

| 狀態 | 定義 | 對應 harness 標籤 |
|------|------|------|
| **app-cold** | App 剛被強制關閉並重新啟動後，開的第一個 session 的第一次生成——內含 native library 初始化（`ggml_backend_load_all`/`initBackend`）+ 模型載入 + 首次 JIT 三種成本疊加 | `{tier}-app-cold`（僅第一個 tier，且需人工在跑之前手動 force-quit + 重開 app，`BenchmarkProtocolRunner.runAll(appJustLaunched: true)` 才會標記；harness 本身無法從程式內部偵測「app 剛啟動」，這一步是操作者的責任） |
| **session-cold** | App 行程持續運行中，開一個「新」session 的第一次生成——native library 已初始化，只有模型載入 + 首次 JIT 這兩項成本 | `{tier}-session-cold` |
| **session-warm** | 同一個 session 上的第 2 次（含）以後的生成——模型已載入、JIT 已熱機 | `{tier}-session-warm-{n}` |

**執行方式**：`BenchmarkProtocolRunner.runAll` 會自動依序把每個 tier 標成上述三種狀態之一——
第一個 tier 的第一個樣本在 `appJustLaunched: true` 時標 `app-cold`，其餘 tier 的第一個樣本一律標
`session-cold`，每個 tier 後續的暖啟動樣本標 `session-warm-{n}`。**分析數據時務必依標籤分組
比較，不可對三者取聯合平均**。

**task-C04 pilot 上機發現（2026-07-19，iPhone 17 Pro，見 construction.md）**：`session-cold`
TTFT 本身也有不小的 run-to-run 變異——GGUF 兩次分別量到 440ms／693ms，MLX 兩次分別量到
3.75s／7.3s，且量到 7.3s 那次 `thermalState` 已是 `fair`（非 `nominal`，因為裝置在長時間開發/
測試後升溫）。這代表**「組間降溫」不是可有可無的細節，thermalState 看起來會直接影響
cold-start 的絕對數值**。C05 正式跑矩陣時，每個 tier 建議跑 **≥3 次獨立的 session-cold**
（每次都重新開一個新 session，而不只是重跑同一個 session 的 warm 樣本），取中位數才有代表性，
單一次 cold 樣本可能誤導。

另外 pilot 也**發現並修好一個會擋住這套協定的 MLX bug**：`MlxInferenceBridge.startGeneration`
原本要等整個 `for await` 迴圈自然跑完才清空忙碌旗標，但 Dart 端一收到 `isDone` 事件就視為
生成結束、可以馬上叫下一次——這個時間差會讓緊接著的 `session-warm` 呼叫直接被原生層以
`PlatformException(busy, ...)` 拒絕。已修正（改成收到最後一個事件時就提早清旗標，
`ios/Runner/MlxBridge/MlxInferenceBridge.swift`），修正前 100% 會擋住本協定的 warm 樣本，
修正後 pilot 兩次 MLX cold+warm 皆成功。此外 pilot 也再次確認：MLX 的 `promptTokenCount`／
`prefillTokensPerSecond` 兩欄目前仍固定是 `null`（`MlxSession` 尚未實作 `PromptMetricsSource`，
既有已知缺口，非本次新發現）——D 線圖表需要能優雅處理 MLX 那一欄缺值，不能假設兩個 backend
欄位都有值。

### 官方建議 sampling（T1 model card）
`temperature = 0.6`、`top_p = 0.95`（官方範例 max_tokens 1500）。benchmark 全程固定此組，兩 backend 一致。

### 量測欄位（對齊 C01 harness，見 `lib/core/benchmark/`）
模型載入時間、TTFT、decode tokens/s、prefill tokens/s、prompt tokens、峰值記憶體
（`dart:io` `ProcessInfo.currentRss`，跑一次生成期間逐 token 取樣後取峰值）、
thermalState（iOS `ProcessInfo.thermalState` / Android `PowerManager.getCurrentThermalStatus`，
經 `DeviceTelemetryHostApi` 統一成 4 級）、電量（`battery_plus`，前/後各一次）。
結果可經 Benchmark 畫面匯出 CSV/JSON（`benchmark_export.dart`）。

### 持續負載（C03，發熱曲線原料）
連續生成 10 分鐘，時間序列記錄 tokens/s 衰減、thermalState 變化、電量消耗。

---

## 矩陣維度（talk 一張圖的軸）

|  | llama.cpp | MLX |
|--|-----------|-----|
| **iPhone 17 Pro** | ✅ | ✅ |
| **Pixel 8a** | 視 A03 判定（MLX 為 Apple 專屬，Android 僅 llama.cpp） | ✗ |

> 註：MLX 僅 Apple 平台。Pixel 8a 只會出現在 llama.cpp 欄。矩陣圖需標清此點，避免誤讀為「MLX 在 Android 缺席」。
