# 計畫：T1 模型整合、Benchmark Harness 與 Talk 產出物

> 循環：2026-07-08-t1-benchmark-talk
> 階段：Definition
> 狀態：🔄 待用戶確認任務清單

---

## 目標

12 個工作天內（7/8→7/25），讓 gemma-3-4B-T1-it 在 llama.cpp 與 MLX 兩 backend 都跑通並輸出高品質繁中，
用一份標準化繁中 prompt 集在 iPhone 17 Pro（＋Pixel 8a 若可行）跑出完整 benchmark 矩陣，
產出 talk 圖表與 demo 錄影 —— 所有產出在 talk 後仍是 Little Star / Twinkle 長期資產。

**範圍決策**：C 線 harness 只做**內部量測工具 + 匯出**，對外跑分頁 UI 不進本循環。

---

## 任務清單

### A 線｜T1 整合（llama.cpp 側）

#### task-A01: 拉官方 T1 GGUF + chat template 驗證
- **類型**: 🔬 研究 + ⚙️ 配置
- **狀態**: [DONE] ✅ 2026-07-10
- **描述**: 拉 gemma-3-4B-T1-it-GGUF Q4_K_M，查 model card 的 system prompt 慣例（Gemma 3 template 特性），確認在 Little Star llama.cpp backend 下 template 套用正確。
- **建議方式**: 調查 model card → 配置 → 繁中輸出驗證
- **驗收標準**:
  - [x] Q4_K_M 權重可在 llama.cpp backend 載入並 generate
  - [x] chat template 套用正確：GGUF 內嵌模板與官方 tokenizer_config 逐 byte一致；llama.cpp
        實際呼叫的 legacy `llama_chat_apply_template` 不執行完整 Jinja，改用字串偵測+寫死格式化，
        但純對話情境下語意與官方模板等價（system 併入首個 user turn、輪次標記正確）。
        工具呼叫情境有已知落差，本輪不需要，記錄供未來參考
  - [x] 繁中 prompt（Q1/Q3，透過 ADBKeyBoard 送出真實 CJK）輸出品質人工判讀達標
- **預估時間**: 1 天

#### task-A02: iPhone 17 Pro 記憶體驗證 + context 長度決定
- **類型**: 🔬 研究 + ⚙️ 配置
- **狀態**: [DONE] ✅ 2026-07-12
- **描述**: 開 `increased-memory-limit` entitlement，量 2.5GB 權重 + KV cache 峰值；量 4K vs 8K context 的 KV cache 記憶體差距，決定 benchmark 的 context 長度。
- **建議方式**: 配置 entitlement → 量測 → 決策
- **驗收標準**:
  - [x] entitlement 開啟後 T1 可穩定載入不被 OOM kill（實體 iPhone 17 Pro，2048/4096/8192 三種 nCtx 皆測過，全程無 OOM）
  - [x] 4K / 8K KV cache 峰值記憶體各有實測數字：4096 → footprint ~920–950MB／resident ~3.58GB；
        8192 → footprint ~1.45–1.47GB／resident ~4.05–4.09GB。實測差距對上 dense（非 SWA-aware）KV
        cache 公式，推翻先前 A01 對 Gemma3 SWA 記憶體優化的假設——目前綁定的 llama.cpp 版本未啟用
        `llama_kv_cache_iswa`，詳見 construction.md task-A02 段落
  - [x] benchmark context 長度拍板：**4096**（L2048 tier 功能性下限 + iPhone 記憶體無虞 + Android
        外推安全 + 8192 對現有 prompt 設計無必要），已寫入 `llama_cpp_backend.dart`
- **預估時間**: 1 天

#### task-A03: Pixel 8a 可行性快篩 + 去留判定（早做）
- **類型**: 🔬 研究
- **狀態**: [DONE] ✅ 2026-07-10 — 記憶體面向「進矩陣」，但發現一個需優先處理的 P0 crash bug（見下）
- **描述**: 4B Q4_K_M 在 8GB RAM Android 上是否跑得動。跑得動 → 進 benchmark 矩陣；跑不動 → 試 Q3，仍不行則轉敘事素材（「4B 是旗艦機特權」）。
- **建議方式**: 快篩 → 判定 → 記錄結論
- **驗收標準**:
  - [x] Pixel 8a 上 Q4_K_M 載入/生成結果有明確結論：3 次成功生成，峰值 PSS 2.81–3.14GB，系統 MemAvailable 全程 3.4+GB，無 OOM
  - [x] 「進矩陣」判定拍板並寫入循環（construction.md task-A03 段落）
  - [x] **額外發現並已修復**：`nBatch=512` 硬編碼 + 無分批/截斷邏輯，累積對話超過 512 token 曾觸發原生
        `SIGABRT` 崩潰（非 OOM）。已在 `llama_cpp_ffi.dart` 加入依 `llama_n_batch(ctx)` 的 prompt 分批
        prefill，並用同一組崩潰重現步驟在實機重建+重跑驗證不再崩潰（見 construction.md「nBatch 溢位
        崩潰修復」章節）
- **預估時間**: 0.5 天 ｜ ⚠️ **判定要早（7/8–7/11 內）**

### B 線｜MLX 轉換與社群貢獻

#### task-B01: mlx_lm.convert 4-bit + 繁中 sanity check
- **類型**: 🔬 研究 + 🔧 程式
- **狀態**: [DONE] ✅ 2026-07-09 — 4-bit 轉換完成（4.501 bits/weight），Q1–Q8 sanity check 達標，判定詳見 construction.md
- **描述**: `mlx_lm.convert` 出 4-bit 版，用與 GGUF 同一組 prompt 做繁中輸出品質對照。異常則換 8-bit 或回報社群。
- **建議方式**: 轉換 → 同 prompt 對照 → 判定
- **驗收標準**:
  - [x] 4-bit MLX 權重可載入 generate
  - [x] 繁中品質獨立判讀達標（8 題僅 Q3 有個案地名瑕疵）；**與 GGUF 版正式並排對照待 task-A01 完成後補上**
- **預估時間**: 1 天 ｜ ⚠️ **sanity check 提早做（留換方案時間）**

#### task-B02: 上傳到自己 HF repo + 繁中 model card（2026-07-16 改案）
- **類型**: ⚙️ 配置 + 📄 文檔
- **狀態**: [DONE] ✅ 2026-07-16 — 4-bit MLX 權重已上傳到 [Bbson/gemma-3-4B-T1-it-MLX-4bit](https://huggingface.co/Bbson/gemma-3-4B-T1-it-MLX-4bit)（過程中遇到一次 `hf upload` 403，fine-grained token 缺 write/LFS 權限，換 write token 後成功）
- **描述**: 原計畫與 Twinkle AI org 協調 write 權限，但協調時間不可控、卡住了 task-B03；改成直接上傳到使用者自己的 HF repo，org 那邊只發一則禮貌性通知（不要求權限），不影響上傳排程。
- **建議方式**: 上傳到 `Bbson/gemma-3-4B-T1-it-MLX-4bit` → （可選）發通知訊息 → talk 前上傳完成
- **驗收標準**:
  - [x] 4-bit MLX 權重已上傳到 `Bbson/gemma-3-4B-T1-it-MLX-4bit`
  - [x] 繁中 model card 草稿完成（repo id 已更新）
  - [x] 上傳完成日 2026-07-16，早於 talk 前幾天的目標窗口
  - [ ]（可選，不影響驗收）Twinkle org 通知訊息已送出，不需等回覆
- **預估時間**: 0.5 天（撰寫）+ 上傳本身 — 實際皆已完成

#### task-B03: 接進 MLX backend + 兩 backend template 一致性驗證 + stop-token 防護
- **類型**: 🔧 程式 (TDD)
- **狀態**: [IN_PROGRESS] — llama.cpp 側 stop-token 防護（2026-07-15）+ 最小 MlxBackend/MlxSession 骨架（2026-07-16）已完成；**B02 卡點已解除**（T1 MLX 4-bit 已上傳到 [Bbson/gemma-3-4B-T1-it-MLX-4bit](https://huggingface.co/Bbson/gemma-3-4B-T1-it-MLX-4bit)），但仍需要 MLX 多檔模型匯入 UI（目前完全沒有，是更早的 task-1001/task-1003 遺留的未完成項，不是本循環新發現）才能真正把 T1 接進 app
- **描述**: 把 T1 MLX 版接進 Little Star MLX backend，確認兩個 backend 的 chat template 處理一致（否則 benchmark 對比失真）；並修正兩 backend 皆觀察到的 stop-token/EOS 未正確終止問題。
- **建議方式**: Red-Green-Refactor（template 一致性測試）
- **驗收標準**:
  - [x] llama.cpp backend：加入文字層 turn-marker 防護（`_TurnMarkerFilter`，`llama_cpp_backend.dart`），偵測不到 EOG token 但模型幻覺出下一輪對話時仍能截斷輸出；4 個單元測試佐證，尚未上機驗證
  - [x] 建立 `MlxBackend`/`MlxSession implements InferenceBackend/InferenceSession`（`lib/core/inference/mlx_backend.dart`），接進 `BackendSelector`；17 個單元測試佐證（fake driver，不需裝置）；T1 模型本身尚未接上、未上機驗證
  - [ ] T1 可透過 MLX backend 載入並 streaming generate（B02 已解除；仍卡在 `ModelManagerViewModel` 不支援 MLX 多檔目錄匯入）
  - [ ] 同 prompt 下兩 backend 的 template 組出的實際輸入序列一致（有測試佐證）——需要在 Mac 用 Xcode 跑 Swift 層，尚未設計測試方法
  - [ ] MLX 側等價的 stop-token 防護（mlx-swift-lm 本身的 `eosTokenIds`/`extraEOSTokens` 機制理論上更完整，待 T1 接上後才能實測是否需要額外防護）
- **預估時間**: 1.5 天（stop-token 防護 + MlxBackend 骨架已完成；B02 卡點解除，剩餘的「MLX 模型匯入 UI + T1 真正接上 + 一致性測試」比原估更大）

### C 線｜Benchmark Harness（進 App 本體 · 內部量測工具）

#### task-C01: App 內埋量測 + CSV/JSON 匯出
- **類型**: 🔧 程式 (TDD)
- **狀態**: [DONE] ✅ 2026-07-19 — 單元測試驗證 + 兩平台編譯驗證；thermal/battery channel 實際讀值待 C04 才第一次上機驗證（已完成，見下）
- **描述**: 在推論後端抽象層（`lib/core/inference/`）埋量測：模型載入時間、TTFT、decode tokens/s、峰值記憶體、`ProcessInfo.thermalState`、電量取樣；結果可匯出 CSV/JSON。
- **建議方式**: Red-Green-Refactor
- **驗收標準**:
  - [x] 單次推論可記錄：載入時間 / TTFT / decode t/s / 峰值記憶體 / thermalState / 電量（`lib/core/benchmark/benchmark_recorder.dart`）
  - [x] 量測對兩 backend 皆適用（掛在 `BenchmarkRecorder`，接受任意 `InferenceSession`，不綁定特定 backend）
  - [x] 結果可匯出 CSV 與 JSON（`lib/core/benchmark/benchmark_export.dart`）
- **預估時間**: 2 天 ｜ 實際：約 1 天（延續既有 `GenerationController`/`PromptMetricsSource` 機制，未重造輪子）

#### task-C02: 標準化測試協定
- **類型**: 🔬 研究 + 🔧 程式
- **狀態**: [DONE] ✅ 2026-07-19
- **描述**: 定義繁中 prompt 集（讓數據也帶 Twinkle 色彩）、prompt 長度 128/512/1024/2048、每組多次取樣、冷/暖啟動分開、飛航模式、固定亮度、同電量起跑、組間降溫。可由 harness 依協定自動跑。
- **建議方式**: 調查 → 定協定 → 程式化執行器
- **驗收標準**:
  - [x] 繁中 prompt 集定版（涵蓋 4 種長度，`lib/core/benchmark/prompt_tiers.dart` + `docs/benchmark/zh-tw-prompt-set.md`；token 數為估計值，待實測校準，見文件註記）
  - [x] harness 能依協定批次執行並分開記錄冷/暖啟動（`BenchmarkProtocolRunner`，且擴充為三態：`app-cold`/`session-cold`/`session-warm`，見 construction.md）
  - [x] 執行前置條件（飛航/亮度/電量/降溫）以 checklist 或程式檢核落實（Benchmark 畫面 pre-flight banner：thermal/battery 程式自動讀，飛航模式/亮度兩平台皆不對第三方 App 開放，保留手動 checklist）
- **預估時間**: 1.5 天 ｜ 實際：約 0.5 天

#### task-C03: 持續負載測試（發熱曲線原料）
- **類型**: 🔧 程式
- **狀態**: [DONE] ✅ 2026-07-19 — 單元測試驗證，尚未真的跑滿 10 分鐘
- **描述**: 連續生成 10 分鐘，記 tokens/s 隨時間衰減、thermalState 變化、電量消耗 —— 「發熱曲線」圖的原料。
- **驗收標準**:
  - [x] 可執行 10 分鐘連續生成並時間序列記錄 t/s、thermalState、電量（`SustainedLoadRunner`，重複呼叫 C01 的 recorder，`BenchmarkSample.timestamp` 即時間軸，未另外設計 schema）
  - [x] 輸出可直接餵給圖表（D 線）（沿用 C01 的 CSV/JSON 匯出）
- **預估時間**: 1 天 ｜ 實際：約 0.25 天（邏輯完全重用 C01）

#### task-C04: Pilot run + 方法論修正
- **類型**: 🔬 研究
- **狀態**: [DONE] ✅ 2026-07-19 — 實機驗證（iPhone 17 Pro），過程中發現並修復一個 MLX 原生層 P0 bug
- **描述**: 用 harness 小規模先跑，檢查數據合理性與協定漏洞，修正方法論後再正式跑矩陣。
- **驗收標準**:
  - [x] 完成一次 pilot 並列出方法論修正項（`integration_test/benchmark_pilot_test.dart`，GGUF+MLX 各跑 cold+warm，見 construction.md task-C04 章節的三項發現）
  - [x] 修正回寫 task-C02 協定（`docs/benchmark/zh-tw-prompt-set.md` Part 3 新增「task-C04 pilot 上機發現」段落：cold-start 變異建議≥3次獨立取樣、MLX busy bug 修復記錄、MLX prompt-token 缺值提醒）
- **預估時間**: 1 天 ｜ 實際：約 0.5 天（含意外的 MLX bug 除錯）

#### task-C05: 正式跑完整 benchmark 矩陣
- **類型**: 🔬 研究
- **狀態**: [IN_PROGRESS] — iPhone 側已完成 2026-07-19（96 筆樣本），但組間沒降溫、數據受熱節流污染；Pixel 8a 側尚未開工
- **描述**: 同一份繁中 prompt 集，跑 2 backend × 2 裝置（Pixel 8a 視 A03 判定）完整矩陣，資料匯出備 D 線用。
- **驗收標準**:
  - [x] 完整矩陣數據產出（CSV/JSON），含冷/暖啟動（iPhone 側，`integration_test/c05_matrix_test.dart`，結果見 [docs/benchmark/2026-07-19-c05-iphone-results.md](../../../docs/benchmark/2026-07-19-c05-iphone-results.md)）；持續負載（C03）數據尚未產出，harness 已就緒
  - [ ] 資料足以支撐一張「矩陣圖講完所有對比」——**目前 iPhone 數據因組間未降溫、受熱節流污染，不建議直接用；Pixel 8a 側尚未執行**；正式素材前需重跑一次乾淨版本
- **預估時間**: 2 天 ｜ 實際：iPhone 側約 0.5 天（含意外發現的熱節流現象與 prompt tier 校準缺口）

### D 線｜Talk 產出物

#### task-D01: 圖表產出
- **類型**: 🎨 設計
- **狀態**: [TODO]
- **描述**: TTFT 對比、decode 速度、記憶體、發熱/降頻曲線、電耗；核心是一張 backend×裝置矩陣圖。
- **驗收標準**:
  - [ ] 5 類圖表（TTFT/decode/記憶體/發熱/電耗）產出
  - [ ] 一張矩陣圖涵蓋 2 backend × 2 裝置對比
- **預估時間**: 1.5 天

#### task-D02: Demo 錄影（不 live）
- **類型**: 🔬 研究 + 🎨 設計
- **狀態**: [TODO]
- **描述**: 錄 T1 回答台灣語境問題、backend 一鍵切換、benchmark 執行畫面。
- **驗收標準**:
  - [ ] 三段 footage（台灣語境問答 / backend 切換 / benchmark 執行）錄製完成
- **預估時間**: 1 天

#### task-D03: Foundation Models 對照（timebox 1 天）
- **類型**: 🔬 研究
- **狀態**: [TODO]
- **描述**: timebox 一天。做得完 → 進 Act 2 當附註；做不完 → 只留 Q&A 口袋論述。
- **驗收標準**:
  - [ ] 1 天內產出對照結果或明確「轉 Q&A 口袋論述」決定
- **預估時間**: 1 天（硬 timebox）

#### task-D04: 簡報 + 講稿 + 計時排練
- **類型**: 📄 文檔
- **狀態**: [TODO]
- **描述**: 圖表整合成簡報、寫講稿，至少兩次完整計時排練（主敵：語速）。
- **驗收標準**:
  - [ ] 簡報與講稿定稿
  - [ ] ≥2 次完整計時排練完成，時間落在目標區間
- **預估時間**: 7/20–7/24 專用區間

---

## 技術決策

- C 線 harness = 內部量測工具（對外跑分頁 UI 留後續循環）
- 量測掛在推論後端抽象層 `lib/core/inference/`，兩 backend 共用（避免對比失真）
- 全程同一份繁中 prompt 集跑 2 backend × 2 裝置 → 單一矩陣圖，資訊密度最高
- **benchmark context 長度：nCtx=4096**（task-A02 已拍板，2026-07-12）——L2048 prompt tier 的功能性
  下限、iPhone 17 Pro 實測記憶體無虞、Pixel 8a 外推安全（未實測，C01/C02 執行時建議補測）。
  llama.cpp 目前綁定版本（b7493）KV cache 為 dense（非 SWA-aware），每 1024 token context 一律
  多耗 ~136MB，與模型架構的 sliding-window 設計無關——future work：升級 llama.cpp 納入
  `llama_kv_cache_iswa` 可望大幅降低同 context 長度的記憶體成本

---

## 排程對照

| 期間 | 里程碑 | 對應任務 |
|------|--------|----------|
| 7/8–7/11 | A+B 完成；Pixel 8a 去留判定 | A01, A02, A03, B01, B02(開口，已於 7/16 改案為自建 repo), B03 |
| 7/12–7/15 | harness 可用；pilot 修方法論 | C01, C02, C03, C04 |
| 7/16–7/19 | 正式跑矩陣 + demo footage；FM 去留 | C05, D02, D03 |
| 7/20–7/24 | 圖表/簡報/講稿 + ≥2 次計時排練 | D01, D04 |

> B02 已於 7/16 完成上傳，比原排程（talk 前幾天）提早許多。
> C01–C04 已於 7/19 完成（原排程 7/12–7/15，落後約 4 天但已追上）；C05 順延至 7/16–7/19 這個
> 已經開始的區間，需要多次上機執行（每 tier ≥3 次獨立 cold session + Pixel 8a），非一次性工作。

---

## 風險與依賴

| 風險 | 影響 | 緩解措施 |
|------|------|----------|
| Pixel 8a 記憶體不足 | 少一台裝置的矩陣數據 | ~~試 Q3 量化~~ → **已解除**：A03 實測記憶體充足，進矩陣 |
| ~~llama.cpp Android backend nBatch=512 溢位崩潰~~（A03 新發現） | ~~C02/C05 的 L512+ prompt tier 在 Android 上會全數 crash~~ | **已解除**：`llama_cpp_ffi.dart` 加入 prompt 分批 prefill，實機驗證不再崩潰 |
| 兩 backend stop-token 未正確終止（B01/A03 共同觀察） | 回應尾端出現雜訊/偽造下一輪對話，demo 錄影會露餡 | **llama.cpp 側已解除**（2026-07-15 文字層 turn-marker 防護，見 construction.md）；MLX 側待 T1 接進 MLX backend 後一併評估 |
| MLX 轉換後繁中品質異常 | benchmark/demo 失真 | ~~sanity check 提早做~~ → **已解除**：B01 達標 |
| ~~Twinkle org 上傳協調時間不可控~~ | ~~「發佈」時刻落空~~ | **已解除**（2026-07-16）：B02 改案為上傳到使用者自己的 HF repo `Bbson/gemma-3-4B-T1-it-MLX-4bit`，不再需要 org write 權限；org 只發禮貌性通知，不卡排程 |
| 兩 backend template 不一致 | 對比失真 | B03 加一致性測試 |
| ~~MLX 背靠背生成被原生層誤判 busy~~（C04 pilot 新發現） | ~~C02/C03/C05 協定的 cold→warm 背靠背呼叫在 MLX 上 100% 失敗~~ | **已解除**（2026-07-19）：`MlxInferenceBridge.swift` race condition 修復，commit `6e36dc3`，pilot 重跑驗證通過 |
| cold-start TTFT 疑似與 thermalState 相關的 run-to-run 變異（C04 pilot 新發現） | 單次 cold 樣本可能不具代表性，矩陣圖失真 | C05 每 tier 跑 ≥3 次獨立 session-cold 取中位數，並落實組間降溫（見 `zh-tw-prompt-set.md` Part 3） |
| 時程壓縮吃掉排練 buffer | 語速失控（主敵） | harness 限內部範圍；D03 硬 timebox |

---

## 相關循環

- [2026-05-21-v0.1-major-refactor](../2026-05-21-v0.1-major-refactor/plan.md) — 多後端架構 / MLX backend / Completion Mode 皆源於此
- [2026-05-25-v0.1-docs](../2026-05-25-v0.1-docs/) — model card / ADR 文檔可對接（B02）

---

## 預估總時間

約 19.5 人日的任務量壓進 12 個工作天 → 需並行 A/B/C 前段，D 線集中 7/20–7/24；
Pixel 8a（A03）與 MLX sanity check（B01）為最早需拍板的關卡。
