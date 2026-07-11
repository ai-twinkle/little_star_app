# 建造：T1 整合、Benchmark Harness 與 Talk 產出物

> 循環：2026-07-08-t1-benchmark-talk
> 階段：Construction
> 狀態：🔄 進行中 — A01 / A02 / A03 / B01 done；nBatch crash **已修復並在實機驗證**；B02 待用戶動作
> 最後更新：2026-07-12（Apple Silicon Mac + 實體 Pixel 8a + 實體 iPhone 17 Pro 皆執行完畢）

---

## 🔀 接手快照（換開發環境時先讀這段）

**目前為止**：A01（GGUF+template 驗證）、A02（iPhone 記憶體/context 長度決定）、
B01（MLX 4-bit 轉換 + 繁中 sanity check）、A03（Pixel 8a 快篩）皆已在實體資源上執行完成，
判定皆為「達標」。過程中發現並**當場修復**了一個 **llama.cpp Android backend 的 P0 crash bug**：
`nBatch` 硬編碼 512、無截斷/分批邏輯，累積對話一旦超過 512 token 就會原生崩潰
（`GGML_ASSERT` → `SIGABRT`）。修復方式：prompt 改成依 `llama_n_batch(ctx)` 分批 decode，詳見下方
「nBatch 溢位崩潰修復」章節。**已用同一組會觸發舊崩潰的 3 輪對話在實機重建 + 重跑驗證，確認不再崩潰。**

A01 另外釐清了一個容易誤解的細節：llama.cpp backend 實際上**不執行** GGUF 內嵌的完整 Jinja 模板，
而是用字串偵測+寫死格式化（legacy API），但純對話情境下語意與官方模板等價，已驗證無虞
（工具呼叫情境有已知落差，本輪不需要）。

**A02 推翻了 A01 的一個假設**：原本從 GGUF metadata 推導「Gemma 3 sliding-window attention 應該能省
KV cache 記憶體」，但實機測 4K vs 8K context 的記憶體差距後發現：目前綁定的 llama.cpp（b7493）**沒有**
SWA-aware KV cache 支援，記憶體吃法是 dense（全部 34 層都當全 context 算），每 1024 token 一律
多耗 ~136MB。已據此把 benchmark context 長度拍板為 **nCtx=4096**（`llama_cpp_backend.dart` 已改，
跨 iOS/Android 共用），理由詳見 construction.md task-A02 段落。iOS 側另外設好了
`increased-memory-limit` entitlement（`ios/Runner/Runner.entitlements` + pbxproj），全程測試無 OOM。

另外還發現一個**跨兩個 backend（MLX + llama.cpp）共通**的 stop-token 未正確終止問題（task-B03 待修，
非阻塞性，僅影響輸出尾端有雜訊；A01/A02 這幾輪測試時有時沒重現，可能與對話輪數/長度有關，留意但不升級
為阻塞項）。

commits：`704f9f1` 開循環、`98a5985` 素材、`a61e4f0` 回填官方 card、`277fb10` B01 完成、
`1261d39` A03 完成 + crash bug 記錄、`1394e46` nBatch crash 修復 + 實機驗證、`3886493` A01 完成、
（本次）A02 完成 + entitlement 設定 + context 長度拍板。

**還剩**：
| 任務 | 狀態 | 下一步 |
|------|------|--------|
| B02 org 協調 | 待用戶本人動作 | 本週送出 [drafts/twinkle-org-outreach.md](drafts/twinkle-org-outreach.md) 的協調訊息 |
| ~~nBatch 溢位 crash~~ | ✅ 已修復並實機驗證 | — |
| ~~A01~~ | ✅ 已完成 | — |
| ~~A02~~ | ✅ 已完成 | Pixel 8a 在 nCtx=4096 下的記憶體是外推估計，非實測；C01/C02 跑起來後建議補測一次確認 |
| task-B03 stop-token | 尚未動 | 兩 backend 加正確 EOS/stop token 設定 |
| C 線效能疑點 | 新觀察 | A02 測試時發現生成速度偏慢、CPU 只用到 ~33%，原因待查（見 task-A02 段落最後一點），建議 C01/C02 harness 順便查明 |
| C 線 harness | 尚未動 | C01 先動（不卡裝置）；C02 現在可以安全開工（crash 已解） |
| D 線 | 尚未動 | 待 A/B/C 完成 |

**共用**：所有品質對照/benchmark 都用同一份 [docs/benchmark/zh-tw-prompt-set.md](../../../docs/benchmark/zh-tw-prompt-set.md)
（sampling 固定 temp 0.6 / top_p 0.95）。

---

## 進行中任務

### task-A03: Pixel 8a 可行性快篩 — [DONE] ✅ 2026-07-10（附帶一個需優先處理的新發現）
- ✅ 快篩 protocol 定版 → [docs/benchmark/pixel-8a-quick-screen.md](../../../docs/benchmark/pixel-8a-quick-screen.md)
- ✅ 判定表（進矩陣 / 降 Q3 / 轉敘事）三分支皆對應 talk 素材
- ✅ **已在實體 Pixel 8a（Android 16, 8GB RAM）執行**：Q4_K_M 透過 `adb push` 佈署到
  `/storage/emulated/0/Download/LittleStar/models/`（app 以目錄掃描方式發現模型，任意檔名皆可，
  無需比對推薦清單），MD5 校驗與來源檔一致。
- **記憶體結果**：
  | 階段 | App PSS | App RSS | 系統 MemAvailable |
  |------|---------|---------|-------------------|
  | 冷啟動（未載模型） | ~0.16 GB | ~0.30 GB | — |
  | Run 1 冷載入 + 生成（單輪） | 峰值 2.81 GB | 2.96 GB | ~3.42 GB |
  | Run 2 續第二輪對話 | 峰值 2.85 GB | 3.00 GB | ~3.42 GB |
  | Run 4（重啟後單輪） | 峰值 3.14 GB | 3.28 GB | ~3.47 GB |

  裝置總 RAM 7.75GB，全程系統可用記憶體維持在 3.4+ GB，**無 OOM / low-memory-killer 介入**（logcat 確認）。
  純記憶體角度：✅ **進矩陣**。
- **穩定性**：3 次成功冷/暖生成（Run1/Run2/Run4），繁中/英文 prompt 皆输出連貫、有 Taiwan 語境內容
  （蚵仔煎/鹽酥雞/珍珠奶茶等在地小吃正確列出）。

- ⚠️ **新發現（P0，建議優先於 C02/C05 處理）：llama.cpp Android backend 有未防護的 context/batch 溢位崩潰**。
  Run 3（第三輪對話，累積 prompt token 數達 538）觸發原生 crash：
  `GGML_ASSERT(n_tokens_all <= cparams.n_batch)` → `ggml_abort` → `SIGABRT`，整個 App 行程被系統回收
  （非記憶體不足，是斷言失敗）。追查結果：
  - 目前分支 `lib/core/inference/llama_cpp_backend.dart:126-131` 已把 `nCtx` 由舊碼的 512 提高到 2048，
    但 **`nBatch` 仍硬編碼 512**，且 Dart FFI 層（`llama_cpp_ffi.dart`）從頭到尾**沒有任何長度檢查、截斷、
    sliding window 或分批 decode 邏輯** —— 任何單次 tokenized prompt（含累積對話歷史）超過 512 token，
    llama.cpp 原生層會直接 `abort()`，Dart 端的錯誤處理（`if (llama_decode(...) != 0)`）完全來不及攔截。
  - **這會直接命中 zh-tw-prompt-set Part 2 的 L512/L1024/L2048 tier** —— C02/C05 在 Android/llama.cpp
    backend 上跑這些 tier 幾乎必定崩潰，不是裝置差異，是全平台適用的 code 層級 bug。
  - iOS/MLX 側目前沒有等價的固定 context 硬上限（`mlx_channel.dart` 僅設 `maxTokens` 生成上限，非 KV cache
    上限），此崩潰模式初判為 **Android/llama.cpp backend 專屬**，但長對話下的記憶體/效能劣化仍可能存在，
    需 A02 一併留意。
  - **建議**：在 C02（harness）動工前，於 A01 或另立任務修正 llama.cpp FFI 層的 prompt 分批/截斷邏輯
    （或至少讓 harness 在送出前用 tokenizer 檢查長度、超過 n_batch 就攔下不送），否則效能矩陣的
    L512 以上 tier 在 Android 端會全數失敗。已回寫 plan.md 風險表。

- 另外也在 Run1/Run2 觀察到與 B01 相同的 **stop-token 未正確終止**現象（回應尾端出現
  `<|assistant|>` 加一段偽造的下一輪使用者發言），確認這是**跨兩個 backend 共通**的 template/EOS
  設定問題，非個別 backend 特有，強化 task-B03 的優先度。

- **判定：Q4_K_M 可穩定載入 + 生成 → ✅ 進矩陣**（記憶體面向），
  但矩陣執行前必須先解決 nBatch 溢位崩潰，否則長 prompt tier 無法完整跑完。

---

### 🔧 nBatch 溢位崩潰修復 — [DONE] ✅ 2026-07-10

**問題**：見上方 task-A03。`llama_batch_get_one(tokens, nPrompt)` 把整段 prompt（含累積對話歷史）
包成單一 batch 直接丟給 `llama_decode`，一旦 token 數超過 `n_batch`（硬編碼 512）就會觸發
`GGML_ASSERT(n_tokens_all <= cparams.n_batch)` → `ggml_abort` → 整個 App 行程 `SIGABRT`。

**修法**：`lib/core/engine/llama_cpp/llama_cpp_ffi.dart`
- `tokenizePrompt()` 不再把整段 prompt 立刻包成一個大 batch，改成只保留 raw token 指標
  （新欄位 `_promptTokens`）。
- 新增 `_prefillPrompt(nPrompt)`：用 `llama_n_batch(ctx)`（執行時實際的 n_batch，不寫死常數）
  把 prompt 切成多個 ≤ n_batch 的 chunk，逐一呼叫 `llama_decode`，直到整段 prompt 進完 KV cache
  才開始取樣——這是 llama.cpp 官方 prefill 慣例（prompt 分批餵、只在最後一批後取樣）。
- `generate()` / `generateStream()` 都先呼叫 `_prefillPrompt`，再進入逐 token 生成迴圈；
  逐 token 生成迴圈本身（每次 decode 1 個 token）不受影響，本來就在 n_batch 限制內。
- 初始 guard 從檢查 `_batch == null` 改成檢查 `_promptTokens == null`（因為 `tokenizePrompt`
  不再預先設定 `_batch`）。

**驗證**：
1. `fvm flutter analyze` — 0 errors（僅既有的 FFI 命名慣例 info，非本次修改引入）。
2. `fvm flutter test test/core/inference/llama_cpp_backend_test.dart` — 18/18 通過
   （這層測試 mock 掉 FFI，驗證的是 `LlamaCppSession`/`LlamaCppBackend` 的邏輯不受影響；
   實際的原生 decode 分批邏輯無法用 Dart 單元測試覆蓋，只能上機驗證）。
3. **實機重現測試**：`fvm flutter build apk --debug` 重新編譯、`adb install -r` 裝到同一台
   Pixel 8a，用**與崩潰當下完全相同**的 3 輪對話（夜市文化 → 九份交通 → 臭豆腐）重跑。
   - Turn 2 累積 269 tokens（log 實測：`nPrompt: 269`），順利生成。
   - Turn 3（原本觸發 538 token 崩潰的那輪）**未崩潰**，App 行程全程存活
     （`dumpsys meminfo` 持續回應，PSS ~3.2GB），logcat 全文搜尋 `ggml_abort`/`GGML_ASSERT`/
     `SIGABRT`/`has died` 均只出現在**舊**崩潰時間戳（23:57:42-43），新測試時間窗（00:2x起）
     完全乾淨。
   - 該輪生成最終以 `[Generation stopped]`（UI 顯示）結束，logcat 對應 `End of generation reached`
     —— 是模型自然吐出 EOG token 提早結束，非本次修法引入的新問題，屬內容面觀察，記錄供
     B03/內容品質追蹤參考。

**尚未處理（明確排除在本次修法範圍外）**：
- `tokenizePrompt` 配置的 token buffer（`_promptTokens`）在 `freeContext()`/`freeModel()` 未被
  釋放——這是修法前就存在的既有記憶體洩漏（原本包在 `_batch.token` 裡，同樣沒被釋放），
  本次沒有讓它變得更糟，但也沒有一併修掉，留待需要時另開任務處理。
- `nCtx=2048` 本身仍是硬編碼；對話總長度超過 2048 token 時 `llama_decode` 會**優雅地**回傳非 0
  （KV cache 滿），現有 Dart 錯誤處理已經接得住（`if (llama_decode(...) != 0) { ...; break; }`），
  不會崩潰，因此不在本次「修 nBatch 崩潰」的範圍內；但長 context 的使用者體驗（例如更明確的
  「對話過長」提示）仍可留給 A02/C02 一併考慮。

### task-A02: iPhone 17 Pro 記憶體驗證 + context 長度決定 — [DONE] ✅ 2026-07-12

- ✅ **entitlement 設定**：`ios/Runner/Runner.entitlements` 新增
  `com.apple.developer.kernel.increased-memory-limit = true`，並在 `ios/Runner.xcodeproj/project.pbxproj`
  的 Runner target 三組 build config（Debug/Release/Profile）加上 `CODE_SIGN_ENTITLEMENTS`。過程中卡了
  三關都是 Xcode 帳號/簽章面的一次性障礙，非技術問題：Xcode 未登入 Apple ID → 登入後帳密被拒 → 開發者帳號
  有待簽署的 Program License Agreement。用戶處理完這三關後，automatic signing 成功重新產生含
  Increased Memory Limit 能力的 provisioning profile。

- ✅ **T1 在實體 iPhone 17 Pro（iOS 26.5.1）載入 + 生成，entitlement 生效下無 OOM/jetsam kill**：
  T1 GGUF 透過 AirDrop + App 內 file-picker 匯入（`ModelManagerViewModel.importModels()`），跨多次
  重新 build（測試不同 nCtx）皆穩定載入生成，無崩潰。

- ✅ **4K / 8K context 的 KV cache 記憶體差距，實測數字**（`xcrun xctrace record --template "Activity Monitor"`
  attach 到 `Runner` process，讀 `memory-physical-footprint`（jetsam 相關指標）與 `memory-resident-size`）：

  | nCtx | Physical Footprint（穩定態） | Resident Size | 測試方式 |
  |------|------------------------------|----------------|----------|
  | 2048 | ~640–651 MiB | ~3.29–3.30 GiB | 單輪短 prompt，生成後靜置 |
  | 4096 | ~920–950 MiB | ~3.58–3.59 GiB | 雙輪對話（第二輪 prompt 543 token） |
  | 8192 | ~1.45–1.47 GiB | ~4.05–4.09 GiB | 雙輪對話（第二輪 prompt 543 token，同一組對話腳本） |

  4096→8192 的實測差距（~535MB）幾乎完全對上**無 SWA 優化的 dense KV cache 公式**：
  `34 層 × 2(K+V) × 4(kv_heads) × 256(head_dim) × 2 bytes(F16) × Δn_ctx`，
  Δ4096 tokens → 544 MiB（理論）vs ~535MB（實測）。這推翻了先前（A01 階段）從 GGUF metadata
  分析 Gemma 3 sliding-window attention（`n_swa=1024`, 5:1 pattern）推導出的「大部分層可省記憶體」
  假設——**App 目前綁定的 llama.cpp 版本（b7493）並未啟用 SWA-aware KV cache
  （`llama_kv_cache_iswa`，較新版本才有），每多 1024 token context 一律吃掉 ~136MB**，不分
  local/global 層。這是本次最重要的技術修正：**日後如果 bump llama.cpp 版本納入 SWA-aware KV cache
  支援，同樣 context 長度的記憶體成本可望大幅下降**，值得記錄成未來優化方向。

  另外意外發現一個很有意思的 iOS 記憶體會計現象：`memory-physical-footprint`（jetsam 判死依據）
  遠低於 `memory-resident-size`（~640MB vs ~3.3GB @2048）——因為 llama.cpp 用 mmap 載入 GGUF 權重，
  乾淨（clean）、可從硬碟重新讀取的檔案背頁不計入 jetsam footprint，只有 KV cache/compute
  buffer/framework overhead 等「dirty」記憶體才算數。這代表 2.5GB 級模型權重本身幾乎不佔 iOS 的
  OOM 判死額度，實際吃緊的是 KV cache 與運算暫存。

- ✅ **benchmark context 長度拍板：4096**（原計畫詢問的是 2048/4096/8192 三選一，最終選 4096，理由）：
  1. **功能性下限**：zh-tw-prompt-set.md 的 L2048 tier（~2048 input token）若配 `nCtx=2048`，扣掉
     input 後**完全沒有生成空間**（`maxTokens=512`），2048 本身已不足以支撐既定的 benchmark 設計，
     這是比記憶體更硬的約束——nCtx 至少要 ≥ 2048+512=2560。
  2. **iPhone 17 Pro 記憶體成本可接受**：4096 下 footprint ~920–950MB，resident ~3.58GB，entitlement
     生效下全程無 OOM，有餘裕。
  3. **Pixel 8a（無 entitlement）成本可控（外推，未在 Android 重測）**：以 dense KV cache 公式外推，
     4096 相對 A03 已驗證安全的 2048 基準（PSS ~2.8–3.1GB）多花 ~272MB，估計 PSS 落在 ~3.1–3.4GB，
     仍在 A03 觀測到的 3GB+ MemAvailable 安全邊際內；**此為外推估計，非實測，建議 C01/C02 harness
     跑起來後在 Pixel 8a 補一次 4096 的實測驗證**。
  4. 8192 已實測（iPhone 上安全），但目前 prompt tier 設計不需要用到超過 4096 的容量，且對 Android
     （無 entitlement 緩衝）風險/效益比不如 4096 划算，故不選。
  - 已將 `nCtx: 2048` 改為 `nCtx: 4096`（`lib/core/inference/llama_cpp_backend.dart`，跨 iOS/Android
    共用同一份程式碼，兩平台同時受益/受限於此設定）。

- **過程觀察（非本任務核心，記錄供 C 線效能量測參考）**：生成速度明顯偏慢，CPU 使用率穩定在
  ~32–34%（非 100%），512 token 生成耗時遠超預期（單輪對話有時需要數分鐘）。可能是 `nThreads=8`
  未被有效利用、Metal shader 首次編譯開銷、或 Instruments attach 本身的觀測開銷。建議 C01/C02
  harness 埋 TTFT/decode tokens-per-second 量測時順便查明原因。

### task-A01: 拉官方 T1 GGUF + chat template 驗證 — [DONE] ✅ 2026-07-10

- ✅ **權重載入/生成**：Q4_K_M 已在 llama.cpp backend（實體 Pixel 8a）反覆載入並成功生成
  （沿用 task-A03 + nBatch 修復驗證時的同一份權重與部署）。

- ✅ **chat template 套用正確性**（GGUF 內嵌 template vs 官方 template vs 實際套用邏輯）：
  1. 用 Python `gguf` 套件從 `twinkle-ai-gemma-3-4b-t1-it-q4_k_m.gguf` 抓出
     `tokenizer.chat_template` metadata，`diff` 與官方 repo 的 `tokenizer_config.json`/
     `chat_template.jinja`（B01 下載時已取得）——**逐 byte 完全一致（4280 bytes）**。
     社群 GGUF 轉換忠實保留了官方模板（含 tool-calling 結構）。
  2. **但**追查 vendored `llama.cpp/src/llama.cpp:467` 的 `llama_chat_apply_template()`
     （app 實際呼叫的 API）發現：它**不會執行**模型內嵌的完整 Jinja 模板，而是呼叫
     `llm_chat_detect_template()`（`llama-chat.cpp:88`）用字串比對偵測「模板家族」，
     偵測到含 `<start_of_turn>` 子字串就判定為 `LLM_CHAT_TEMPLATE_GEMMA`，接著用
     **寫死的 C++ 格式化邏輯**（`llama-chat.cpp:375-396`）產生輸出，完全略過真正的
     Jinja 條件邏輯。
  3. 逐行比對寫死的 GEMMA 格式化邏輯 vs 官方模板的「無 tools」分支（`gguf-chat-template.jinja`
     第 84-121 行）：**純對話情境下語意完全等價**——system prompt 併入第一個 user turn
     （`{content}\n\n`），`assistant`→`model` role 改名，`<start_of_turn>{role}\n...
     <end_of_turn>\n` 輪次標記皆正確，`add_generation_prompt`/`add_ass` 皆補上
     `<start_of_turn>model\n`。BOS token 由 `llama_tokenize(..., add_special=true)` 在
     tokenizer 層處理，非重複疊加，屬正常 llama.cpp 用法。
  4. ⚠️ **已知限制（明確排除在本次範圍外）**：若情境含 `tools`，寫死的 GEMMA 格式化器**不會**
     重現官方模板的 `<tools>`/`<tool_call>`/`<tool_response>` XML 協定，會直接把系統/工具內容當
     一般文字處理。本次 benchmark/demo 走純對話（見接手快照與官方 model card 事實段落），
     純模板已驗證正確；工具呼叫路徑若未來要用，需另外評估（可能需改用 llama.cpp 較新的
     minja-based `common_chat_templates_apply`，而非現在用的 legacy API）。

- ✅ **繁中輸出品質人工判讀**：先前 A03 因 `adb shell input text` 對 CJK 字元丟
  `NullPointerException`，只能用英文對應句測試。本次徵得用戶同意，安裝
  [senzhk/ADBKeyBoard](https://github.com/senzhk/ADBKeyBoard)（開源 ADB Unicode 輸入 IME，
  透過 `ADB_INPUT_B64` broadcast intent 送出 base64 編碼文字）解決，實際送出 zh-tw-prompt-set
  Part 1 的 Q1、Q3：
  - Q1（夜市文化+推薦小吃）：繁體用字正確、鹽酥雞/蚵仔煎/珍珠奶茶描述在地且準確，乾淨結束
    （這次**沒有**出現 B01/A03 觀察到的 stop-token 溢出雜訊）。
  - Q3（台北車站→九份交通）：**火車轉公車（台鐵台北→瑞芳 + 基隆客運1062瑞芳→九份）路線正確**，
    這次**沒有**重現 B01 MLX 版測同題時的「忠孝復興站」地名混淆——單次抽樣，非嚴謹統計比較，
    但方向上顯示 llama.cpp backend 在這題上的表現不劣於 MLX 版。
  - 小瑕疵：回應中出現 `$\rightarrow$`（LaTeX 語法字面重現，未渲染成箭頭符號）——屬 UI
    markdown 渲染細節，非模型內容問題，記錄供 D 線 demo 畫面留意。

- **判定：三項驗收標準皆達標** → A01 完成。GGUF 忠實保留官方模板，llama.cpp 實際套用邏輯在
  純對話情境下語意等價（工具呼叫情境有已知落差，本輪不需要）；繁中輸出品質經人工判讀達標。

### task-B01: MLX 4-bit 轉換 + 繁中 sanity check — [DONE] ✅ 2026-07-09
- ✅ 轉換 + sanity check runbook 定版 → [docs/benchmark/mlx-t1-conversion-runbook.md](../../../docs/benchmark/mlx-t1-conversion-runbook.md)
- ✅ 對照用 prompt 綁定 zh-tw-prompt-set Part 1（與 GGUF 同 prompt）
- ✅ 確認 repo 內已有 `GemmaChatTemplate`（system prompt 注入第一個 user turn，符合 Gemma 慣例）
- ✅ **已在 Apple Silicon Mac 執行**：`mlx_lm.convert --hf-path twinkle-ai/gemma-3-4B-T1-it -q --q-bits 4 --q-group-size 64`
  - 量化結果：4.501 bits/weight，輸出 2.4GB（`model.safetensors`）
  - Prompt: ~50 tokens @ ~285–300 tok/s；Generation: 256 tokens @ ~51.7–52.0 tok/s（穩定，8 題皆同量級）
  - Peak memory：穩定在 **2.68 GB**（8 題皆同）
- ✅ Q1–Q8 繁中 sanity check 完成（見下方判定）
- ⚠️ **與 GGUF 版正式並排比對尚未執行**（task-A01 GGUF+llama.cpp 驗證尚未動工，見接手快照「尚未動的」）；
  本次僅完成 MLX 版獨立品質判讀，達標。待 A01 跑完後補上真正並排對照。

### task-B02: Twinkle org 上傳協調 + 繁中 model card — [IN_PROGRESS]
- ✅ 繁中 model card 草稿 → [drafts/model-card-zh-tw.md](drafts/model-card-zh-tw.md)
- ✅ org 協調訊息草稿 + 追蹤清單 → [drafts/twinkle-org-outreach.md](drafts/twinkle-org-outreach.md)
- ⏳ **需用戶本人動作**：本週送出協調請求；取得 write 權限；確認官方 repo id + system prompt 慣例
- ⚠️ 本週就要開口

---

## 共用資產（一次做、多處用）

- ✅ [docs/benchmark/zh-tw-prompt-set.md](../../../docs/benchmark/zh-tw-prompt-set.md) — 繁中 prompt 集 + 標準化測試協定
  - Part 1 品質/demo prompt（A01/B01/D02）
  - Part 2 受控長度 prompt 128/512/1024/2048（C02 校準 token 數後定版）
  - Part 3 執行條件（飛航/亮度/電量/冷暖/降溫）
  - 矩陣維度圖（MLX 僅 Apple，Pixel 8a 只在 llama.cpp 欄）

---

## 官方 model card 已確認事實（2026-07-09，[T1 repo](https://huggingface.co/twinkle-ai/gemma-3-4B-T1-it)）

- 來源 repo：`twinkle-ai/gemma-3-4B-T1-it`；base：`google/gemma-3-4b-pt`
- 授權：gemma，**HF gated** → 下載/轉換前需接受授權並登入（影響 A01/A03/B01）
- 語言：繁中 + 英文；聚焦台灣人文社會（法律/教育/對話）
- system prompt：**無強制**，官方範例為選用 → benchmark 統一用一句台灣定調 system prompt
- 官方 sampling：`temperature 0.6`、`top_p 0.95`（範例 max_tokens 1500）→ 已寫入 prompt set / runbook
- chat template（含 **tool-calling**）內嵌於 `tokenizer_config` = template 真實來源
- context length：card 未載明（Gemma 3 4B 通常長 context，端側需自限；待 A02 依 KV cache 拍板）

⚠️ **A01/B03 注意**：repo 內 `GemmaChatTemplate` 是「純對話」Gemma 模板；T1 官方模板含 tool-calling 結構。
本次 benchmark/demo 走純對話，純模板即可；但跨 backend 一致性測試（B03）應以 `tokenizer_config` 的官方模板為對照基準。

## B01 繁中 sanity check 判定（2026-07-09，Apple Silicon Mac）

| ID | 判讀重點 | 結果 |
|----|----------|------|
| Q1 | 小吃在地性、繁體用字 | ✅ 繁體正確，臭豆腐/蚵仔煎/珍珠奶茶在地性正確 |
| Q2 | 台灣流行語理解 | ✅ 揪團/小確幸定義與舉例正確 |
| Q3 | 在地交通常識、不編造 | ⚠️ 有瑕疵：誤將「忠孝復興站」與台北車站混為一談，且路線名稱前後不一致（1062 皇冠北海岸線 → 黃金福隆線） |
| Q4 | 制度正確性 | ✅ 統一發票制度描述正確（含對獎機制、20% 印花稅） |
| Q5 | 語氣分層、在地制度 | ✅ 颱風假標準（風力/雨量）說明正確，語氣貼近國中生 |
| Q6 | 生成品質、繁中語感 | ✅ 語感自然（達標，但受下方技術瑕疵影響最明顯） |
| Q7 | 語用理解 | ✅ 正確判讀為稱讚，CP 值解釋到位 |
| Q8 | 自我一致：務必用繁體 | ✅ 全程繁體，且正確舉出簡中對照詞（視頻/質量 → 影片/品質） |

**技術瑕疵（非模型品質問題）**：`mlx_lm.generate` 未在 `<end_of_turn>` 停止生成，導致 Q1/Q2/Q6 在正確答案後
出現重複或英文夾雜的雜訊（尤其 Q6 出現 `<translation>` 標籤迴圈）。**需在 task-B03 接進 MLX backend 時
正確設定 stop token/EOS**，否則產品端會把這段雜訊顯示給使用者。

**判定：4-bit 繁中品質達標** → 進 task-B03（接進 MLX backend）+ task-B02（上傳協調，用戶已在進行）。
Q3 的地名瑕疵屬個案幻覺，非系統性問題，記錄供 D02 demo 選題時避開類似問法。

## 待用戶回填（回來後回寫此檔 + plan.md 狀態）

| 來源 | 待回填 |
|------|--------|
| A03 | ✅ 已完成，見上方（含新發現的 nBatch 溢位崩潰，需優先處理） |
| B01 | ✅ 已完成，見上方判定表 |
| B02 | write 權限取得 + 協調請求送出日 + 上傳排程（用戶待辦，本檔未變動） |

---

## 提交記錄

| 日期 | 提交 | 內容 |
|------|------|------|
| 2026-07-08 | `704f9f1` | docs(workflow): 開循環（exploration + plan） |
| 2026-07-08 | `98a5985` | benchmark prompt set + B01/A03 runbook + B02 drafts |
| 2026-07-09 | (本次) | 回填官方 model card 事實（base/gated/sampling/template）到 4 份文件 |
