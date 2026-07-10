# 建造：T1 整合、Benchmark Harness 與 Talk 產出物

> 循環：2026-07-08-t1-benchmark-talk
> 階段：Construction
> 狀態：🔄 進行中 — A03 / B01 done；nBatch crash **已修復並在實機驗證**；B02 待用戶動作
> 最後更新：2026-07-10（Apple Silicon Mac + 實體 Pixel 8a 執行完畢）

---

## 🔀 接手快照（換開發環境時先讀這段）

**目前為止**：B01（MLX 4-bit 轉換 + 繁中 sanity check）與 A03（Pixel 8a 快篩）皆已在實體資源上執行完成，
判定皆為「達標 / 進矩陣」。過程中發現並**當場修復**了一個 **llama.cpp Android backend 的 P0 crash bug**：
`nBatch` 硬編碼 512、無截斷/分批邏輯，累積對話一旦超過 512 token 就會原生崩潰（`GGML_ASSERT` → `SIGABRT`）。
修復方式：prompt 改成依 `llama_n_batch(ctx)` 分批 decode，詳見下方「nBatch 溢位崩潰修復」章節。
**已用同一組會觸發舊崩潰的 3 輪對話在實機重建 + 重跑驗證，確認不再崩潰。**

另外還發現一個**跨兩個 backend（MLX + llama.cpp）共通**的 stop-token 未正確終止問題（task-B03 待修，
非阻塞性，僅影響輸出尾端有雜訊）。

commits：`704f9f1` 開循環、`98a5985` 素材、`a61e4f0` 回填官方 card、`277fb10` B01 完成、
`1261d39` A03 完成 + crash bug 記錄、（本次）nBatch crash 修復 + 實機驗證。

**還剩**：
| 任務 | 狀態 | 下一步 |
|------|------|--------|
| B02 org 協調 | 待用戶本人動作 | 本週送出 [drafts/twinkle-org-outreach.md](drafts/twinkle-org-outreach.md) 的協調訊息 |
| ~~nBatch 溢位 crash~~ | ✅ 已修復並實機驗證 | — |
| task-B03 stop-token | 尚未動 | 兩 backend 加正確 EOS/stop token 設定 |
| A01 | 尚未動 | T1 GGUF 進 llama.cpp backend 驗 template |
| A02 | 尚未動 | iPhone 記憶體/context 長度決定 |
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
