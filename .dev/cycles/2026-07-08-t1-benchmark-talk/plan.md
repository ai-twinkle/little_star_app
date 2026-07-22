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
- **狀態**: [DONE] ✅ 2026-07-21 — 實機跑滿 GGUF + MLX 各 10 分鐘，乾淨真實數據（拔線、單次連續、無背靠背污染）
- **描述**: 連續生成 10 分鐘，記 tokens/s 隨時間衰減、thermalState 變化、電量消耗 —— 「發熱曲線」圖的原料。
- **驗收標準**:
  - [x] 可執行 10 分鐘連續生成並時間序列記錄 t/s、thermalState、電量（`SustainedLoadRunner`，重複呼叫 C01 的 recorder，`BenchmarkSample.timestamp` 即時間軸，未另外設計 schema）
  - [x] 輸出可直接餵給圖表（D 線）（沿用 C01 的 CSV/JSON 匯出）
  - [x] 實機驗證，兩個 backend 皆完成：GGUF `docs/benchmark/2026-07-21-c03-gguf-sustained.csv`（62 筆，10:33-10:43，decodeTps 24.2→13.7 tok/s，thermalState nominal→fair→serious）、MLX `docs/benchmark/2026-07-21-c03-mlx-sustained.csv`（47 筆，11:51-12:01，decodeTps 24.7→12.5 tok/s，thermalState 同樣遞進，電量 95%→85% 真實掉電）
- **執行過程中的修復**（見 construction.md 詳細記錄）：
  - Benchmark 畫面新增模型選擇器（folder icon → bottom sheet），不用再手打 app 沙盒路徑
  - 移除未使用的 `connectivity_plus` 依賴（`GeneratedPluginRegistrant` 階段的 Swift runtime race 導致間歇性閃退的根因之一）
  - Benchmark 卡片可見性從 `kDebugMode` 改成 `!kReleaseMode`，讓 profile build（無 debug VM service 附加，繞開閃退）能看到
  - `_share()` 補上 `sharePositionOrigin`（缺這個參數會讓 `shareXFiles` 拋 `PlatformException`，分享面板不會跳出，先前一輪 20 分鐘數據因此遺失）
  - `BenchmarkViewModel` 加上逐筆自動 checkpoint（每筆樣本產生後立即覆寫 `Documents/benchmark_live.csv`），匯出目錄從 tmp 改到 Documents（Files app 可見），避免 app 中途當掉或分享失敗時整批數據遺失
- **預估時間**: 1 天 ｜ 實際：約 0.25 天邏輯 + 額外約 0.5 天上機除錯（見 construction.md）

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
- **狀態**: [DONE] ✅ 2026-07-19，附重要限制 — iPhone 側 96 筆樣本（組間沒降溫，數據受熱節流污染）；Pixel 8a 側 4 個 GGUF tier（樣本數縮減為 1冷+2暖，發現 decode/prefill 比 iPhone 慢一到三個數量級）
- **描述**: 同一份繁中 prompt 集，跑 2 backend × 2 裝置（Pixel 8a 視 A03 判定）完整矩陣，資料匯出備 D 線用。
- **驗收標準**:
  - [x] 完整矩陣數據產出（CSV/JSON），含冷/暖啟動：iPhone 側（`integration_test/c05_matrix_test.dart`，結果見 [docs/benchmark/2026-07-19-c05-iphone-results.md](../../../docs/benchmark/2026-07-19-c05-iphone-results.md)）+ Pixel 8a 側（結果見 [docs/benchmark/2026-07-19-c05-android-results.md](../../../docs/benchmark/2026-07-19-c05-android-results.md)）；2026-07-20 晚間跑過一次時間上限版重跑（`c05_timeboxed_partial_2026-07-20.csv`，L1024/L2048 各 backend），但 thermalState 全程仍是 `serious`，證實**短時間降溫窗口對這台裝置無效，跟原本那份數據是同一種污染**，非乾淨版；持續負載（C03）數據已於 2026-07-21 補齊，見上方 C03 章節
  - [x] 資料足以支撐一張「矩陣圖講完所有對比」——**兩份數據皆附重要限制說明**（iPhone：組間未降溫受熱節流污染；Android：樣本數遠少於 iPhone、低電量充電中量測、prefill 速度異常待查），正式素材前建議各重跑一次乾淨版本，但方向性的跨裝置/跨backend比較已經可用
  - **若要重跑出乾淨版本**：C03 的成功經驗（見上方）證實乾淨數據要靠「手動 UI、單次連續、無背靠背」才拿得到，不是靠縮短自動化降溫窗口就能解決——真要重跑 C05，建議比照 C03 走法：透過 Benchmark 畫面的「Run standardized protocol」逐一手動跑每個 backend、跑完等真的降回 nominal 再跑下一個 tier，而非用 `integration_test` 背靠背跑完整矩陣；工時上這需要 8 個 tier×backend 組合各自等待真實降溫，可能要拆成好幾個時段，非一次性工作
- **預估時間**: 2 天 ｜ 實際：約 1 天（iPhone 側 0.5 天 + Android 側 0.5 天，含大量 Android 自動化障礙排除：appops 權限重置、16KB 對齊警告、間歇性 ANR）

### D 線｜Talk 產出物

#### task-D01: 圖表產出
- **類型**: 🎨 設計
- **狀態**: [DONE] ✅ 2026-07-21 更新 — 見 [drafts/d01-benchmark-charts.html](drafts/d01-benchmark-charts.html)（[已發布 artifact](https://claude.ai/code/artifact/048b8980-f2b1-4eca-8bde-e9c5c5462c5f)）
- **描述**: TTFT 對比、decode 速度、記憶體、發熱/降頻曲線、電耗；核心是一張 backend×裝置矩陣圖。
- **驗收標準**:
  - [x] 5 類圖表（TTFT/decode/記憶體/發熱/電耗）產出
  - [x] ~~一張矩陣圖涵蓋 2 backend × 2 裝置對比（Pixel 8a × MLX 標示為結構性 N/A，非資料缺口）~~ → 2026-07-21 使用者決定移除 Pixel 8a，全頁改為 iPhone 17 Pro 單裝置、聚焦 backend 對比（見下一條）
  - [x] **2026-07-21 更新（C03 資料）**：發熱節流曲線（第 4 節）與電量消耗（第 5 節）換成 task-C03 真實乾淨數據——單次連續 10 分鐘、拔線，取代原本用 C05 矩陣 8 組合背靠背當替代品的做法；新增發現：MLX 進入 `fair`/`serious` 的時間點都比 GGUF 早兩分鐘以上，同一台裝置明顯更快被 MLX 推熱；電量圖也首次有真實掉電曲線（MLX 95%→85%）
  - [x] **2026-07-21 更新（移除 Pixel 8a）**：使用者判斷 Android 數據（未優化建置、樣本數少、充電中量測，一堆但書）不值得放進圖表，全頁改為 iPhone 17 Pro 單裝置版本——「矩陣總覽」改名「快照總覽」、TTFT/decode/記憶體面板從雙欄縮為單欄、資料表拿掉裝置欄位、移除 `ANDROID_COMBOS` 死程式碼。Android 原始數據與結果文件（`docs/benchmark/2026-07-19-c05-android-results.md`）保留在 repo 供查閱，只是不再出現在這份 D01 頁面裡
  - [x] **2026-07-21 更新（修正順序效應）**：原本第 4 節「MLX 比 GGUF 快兩分鐘進入 serious」的結論其實是測試順序造成的假象——使用者補跑「MLX 先跑」+「GGUF 排第二」兩組驗證，發現**不管哪個 backend，只要排第二個跑（前面隔 8-10 分鐘）都明顯更快降頻**，跟 backend 身份無關；iOS 的 thermalState 標籤回到 `nominal` 不代表裝置內部殘留熱量真的歸零
  - [x] **2026-07-22 更新（電量也對齊）**：使用者發現前一版 MLX 對照組起始電量（75%）跟 GGUF（95%）仍有落差，補跑第三輪 MLX——充到 100% 並靜置到 thermalState 確認 nominal 才開始測，起始電量甚至比 GGUF 還高（100%→95%）
  - [x] **2026-07-22 更新（誠實揭露，最終版）**：用同樣方法論（充滿+靜置）補跑第三輪 GGUF 後，結果完全打破預期——fair/serious 時間點比 GGUF 自己前兩輪慢 2 倍以上，電量首次真的掉 10%，證實**就算控制了順序與起始電量，單次量測的 run-to-run 變異依然大於 backend 之間的差異**。使用者拍板不再追「最終正確數字」，改成誠實揭露版本：D01 第 4/5 節全面重寫，6 次重跑（3 GGUF + 3 MLX）全部列表攤開，明確聲明「不主張哪個 backend 推熱較快或較省電」；唯一保留的結論是 6 次量測中唯一一致、數值範圍完全不重疊的訊號——**穩態降頻後 decode 速度 GGUF（13.6-14.5 tok/s）一致高於 MLX（12.4-13.0 tok/s），約 10-15% 差距**。C03 原始目標（乾淨發熱曲線本身）達成；跨 backend 量化比較誠實留白，需要 N≥5 輪+統計檢定才能下結論，記錄為未來待辦
- **預估時間**: 1.5 天 ｜ 實際：約 0.5 天（資料已齊備，主要工時在圖表實作與 Playwright 視覺驗證）+ 7/21 約 0.5 小時整合 C03 新資料

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
