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

⚠️ 這裡的 token 數需以**模型 tokenizer 實測校準**（繁中每字元的 token 數與英文不同）。
本檔先給「內容骨架 + 目標長度」，實際字數由 C02 harness 用 T1 tokenizer 校準後定版填入。

| Tier | 目標輸入長度 | 內容骨架 | 固定生成上限 |
|------|--------------|----------|--------------|
| L128 | ~128 tokens | 單一問題（如 Q3），無額外脈絡 | 由 C02 統一設定（如 max 256） |
| L512 | ~512 tokens | 一段台灣新聞/說明文（約 300–400 繁中字）+ 「請摘要成三點」 | 同上 |
| L1024 | ~1024 tokens | 兩段長文（如一篇部落格）+ 「請比較兩段觀點差異」 | 同上 |
| L2048 | ~2048 tokens | 長對話脈絡（多輪 QA 累積）+ 追問 | 同上 |

**產出待辦（C02 校準時）**：把每個 tier 的實際繁中文本填入 `zh-tw-prompt-set.assets/`，並記錄用 T1 tokenizer 量到的實際 token 數。

---

## Part 3 — 標準化測試協定（執行條件）

每次 benchmark run 必須遵守，確保可重現：

- [ ] **飛航模式**開啟（排除網路干擾）
- [ ] **固定螢幕亮度**（建議固定值，記錄於結果）
- [ ] **同電量起跑**（每組 run 從相同電量百分比開始，記錄起始/結束電量）
- [ ] **冷啟動 / 暖啟動分開記錄**（冷=App 剛啟動首次載入；暖=模型已在記憶體）
- [ ] **每組多次取樣**（建議 ≥3 次取中位數）
- [ ] **組間降溫**（等 `thermalState` 回到 nominal 再跑下一組）
- [ ] 固定 context 長度（依 task-A02 KV cache 實測結果拍板）
- [ ] 兩 backend 使用**完全相同**的 system prompt 與 sampling 參數

### 官方建議 sampling（T1 model card）
`temperature = 0.6`、`top_p = 0.95`（官方範例 max_tokens 1500）。benchmark 全程固定此組，兩 backend 一致。

### 量測欄位（對齊 C01 harness）
模型載入時間、TTFT、decode tokens/s、峰值記憶體、`ProcessInfo.thermalState`、電量取樣。

### 持續負載（C03，發熱曲線原料）
連續生成 10 分鐘，時間序列記錄 tokens/s 衰減、thermalState 變化、電量消耗。

---

## 矩陣維度（talk 一張圖的軸）

|  | llama.cpp | MLX |
|--|-----------|-----|
| **iPhone 17 Pro** | ✅ | ✅ |
| **Pixel 8a** | 視 A03 判定（MLX 為 Apple 專屬，Android 僅 llama.cpp） | ✗ |

> 註：MLX 僅 Apple 平台。Pixel 8a 只會出現在 llama.cpp 欄。矩陣圖需標清此點，避免誤讀為「MLX 在 Android 缺席」。
