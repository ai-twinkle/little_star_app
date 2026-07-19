# 建造：T1 整合、Benchmark Harness 與 Talk 產出物

> 循環：2026-07-08-t1-benchmark-talk
> 階段：Construction
> 狀態：🔄 進行中 — A01 / A02 / A03 / B01 done；nBatch crash **已修復並在實機驗證**；
> task-B03 **llama.cpp 側文字層 stop-marker 防護已完成**（單元測試驗證，未上機）；
> task-B03 **最小 MlxBackend/MlxSession 骨架已完成**（純 Dart，單元測試驗證）；
> **已在實體 iPhone 上用真正的 T1 MLX 權重跑通**（透過臨時 debug 探針，現已刪除並被正式 UI 取代）——
> 成功建立 session、載入模型、串流生成繁中回覆，TTFT ~3.2s、總時間 ~13.1s（單次觀察值，非正式 benchmark）
> task-B03 **`ChatViewModel`/`BackendSelector` 正式接線已完成**、**MLX 多檔匯入 UI 已完成**、
> **Completion 頁面 MLX 支援已完成**、**MLX 缺 chat template 下載 bug 已修復並上機驗證**、
> **兩 backend template 一致性驗證已完成（原始碼層級比對，非 Xcode 實機比對）**——
> **task-B03 全部子項完成** ✅
> B02 **已完成** — T1 MLX 4-bit 已上傳到 [Bbson/gemma-3-4B-T1-it-MLX-4bit](https://huggingface.co/Bbson/gemma-3-4B-T1-it-MLX-4bit)（2026-07-16），task-B03 卡點解除
> **`_TurnMarkerFilter` 已補到 MLX**（2026-07-19，抽成共用元件）
> **C 線 task-C01/C02/C03/C04 皆已完成**（2026-07-19）：C01 埋量測+CSV/JSON 匯出、C02 標準化協定
> （含冷啟動三態定義）、C03 持續負載 harness、C04 pilot 上機驗證（iPhone 17 Pro）——過程中
> **發現並修復一個 MLX 原生層 race condition bug**（背靠背生成會被誤判 busy，見下方章節）。
> **task-C05 兩台裝置皆已完成**（2026-07-19）：iPhone 17 Pro 96 筆真實樣本（2 backend × 4
> tier，但組間沒降溫、數據受熱節流污染，只能相對比較）；Pixel 8a 4 個 GGUF tier（樣本數
> 縮減為 1 冷+2 暖，因單次生成極慢）——**意外發現 Android 側 decode/prefill 速度比 iPhone
> 慢一到三個數量級**，且上機過程排除了三個 Android 自動化障礙（appops 權限重置、16KB 對齊
> debug 警告、間歇性 ANR），詳見
> [docs/benchmark/2026-07-19-c05-iphone-results.md](../../../docs/benchmark/2026-07-19-c05-iphone-results.md)
> 與
> [docs/benchmark/2026-07-19-c05-android-results.md](../../../docs/benchmark/2026-07-19-c05-android-results.md)。
> **Android 效能落差根因已查明（同日追查）**：`scripts/build_llama.cpp_android.sh` 編出的
> `.so` 沒開 GPU backend（`GGML_VULKAN`/`GGML_OPENCL` 皆 OFF，iOS 靠 Metal）、CPU 也沒吃到
> dotprod/i8mm（鎖定 2015 年 `android-23` 基準無 `-march` 目標）——刻意的廣泛相容性選擇，
> 代價是犧牲新機效能，修法未實作（見結果檔）。
> **task-D01（圖表產出）已完成**（2026-07-19）：[drafts/d01-benchmark-charts.html](drafts/d01-benchmark-charts.html)，
> 5 類圖表 + 矩陣總覽，資料直接引用 C05 兩份結果檔，如實繼承其限制（未做假數字）。
> D02/D03/D04 尚未開工。
> 最後更新：2026-07-19

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

另外還發現一個**跨兩個 backend（MLX + llama.cpp）共通**的 stop-token 未正確終止問題（task-B03，
非阻塞性，僅影響輸出尾端有雜訊；A01/A02 這幾輪測試時有時沒重現，可能與對話輪數/長度有關）。
**2026-07-15 已針對 llama.cpp 側完成文字層防護**（`_TurnMarkerFilter`，見下方「task-B03（部分）」
章節）。

⚠️ **2026-07-18 更新／新發現的待辦項**：當時 MLX 側因 T1 尚未接進 app 內 MLX backend，暫無
對應程式碼可修；**現在 MLX backend 已經正式接線完成**（Chat/Completion 頁面皆可用），但
`_TurnMarkerFilter` 這層文字防護**只存在於 `LlamaCppSession`，從未移植到 `MlxSession`**——
代表 B01 當初觀察到的 MLX 尾端雜訊（`<translation>` 標籤迴圈等）目前仍然沒有防護，демо/正式
使用時如果模型沒採樣到正確的 EOS，MLX 這邊會把雜訊原樣顯示給使用者。記錄為新待辦，建議排進
下一輪處理（把 `_TurnMarkerFilter` 抽成 backend-agnostic 的共用元件，`MlxSession` 也套用）。

commits：`704f9f1` 開循環、`98a5985` 素材、`a61e4f0` 回填官方 card、`277fb10` B01 完成、
`1261d39` A03 完成 + crash bug 記錄、`1394e46` nBatch crash 修復 + 實機驗證、`3886493` A01 完成、
`c72114c` A02 完成 + entitlement 設定 + context 長度拍板、`1917ab5` TurnMarkerFilter 抽共用+補
MLX、`dfe0fa3` task-C01、`14150e1` task-C02、`3c3e6c4` task-C03、`6e36dc3` MLX busy race
condition 修復、`4e1c5ed` task-C04 pilot integration test。

**還剩**：
| 任務 | 狀態 | 下一步 |
|------|------|--------|
| ~~B02 上傳~~ | ✅ 已完成 2026-07-16 → [Bbson/gemma-3-4B-T1-it-MLX-4bit](https://huggingface.co/Bbson/gemma-3-4B-T1-it-MLX-4bit) | （可選）通知訊息（[drafts/twinkle-org-outreach.md](drafts/twinkle-org-outreach.md)）尚未確認是否送出，不影響其他排程 |
| ~~nBatch 溢位 crash~~ | ✅ 已修復並實機驗證 | — |
| ~~A01~~ | ✅ 已完成 | — |
| ~~A02~~ | ✅ 已完成 | Pixel 8a 在 nCtx=4096 下的記憶體是外推估計，非實測；C01/C02 跑起來後建議補測一次確認 |
| task-B03（llama.cpp 文字層防護） | ✅ 已完成（單元測試驗證） | 建議錄 demo 前找一次容易重現的長對話在實機/模擬環境跑一輪，肉眼確認尾端不再有 `<start_of_turn>user`/`<\|assistant\|>` 雜訊 |
| task-B03（MlxBackend/MlxSession 最小骨架） | ✅ 已完成（單元測試驗證） | 見下方新章節 |
| task-B03（debug 探針上機驗證 T1 真的能跑） | ✅ 已完成 2026-07-17（實機驗證） | 見下方新章節；中途遇到一次 `SIGKILL`（懷疑 cold-start 記憶體尖峰，未再重現），第二次重跑成功 |
| task-B03（`ChatViewModel`/`BackendSelector` 正式接線） | ✅ 已完成 2026-07-17（單元測試驗證） | 見下方新章節 |
| task-B03（MLX 多檔匯入 UI） | ✅ 已完成 2026-07-17（單元測試驗證，未上機） | 見下方新章節；`MlxBackendProbeScreen` 已依其自身文件註解的條件刪除（功能已被此畫面取代） |
| task-B03（Completion 頁面 MLX 支援 + GGUF prefill/prompt token 統計） | ✅ 已完成 2026-07-18（已上機驗證） | 見下方新章節 |
| task-B03（MLX 缺 chat template 下載 bug） | ✅ 已修復並上機驗證 2026-07-18 | 見下方新章節；`getMlxModelFiles()` 白名單補上 `chat_template.jinja` |
| ~~task-B03（兩 backend template 一致性驗證）~~ | ✅ 已完成 2026-07-18 | 見下方新章節；改用原始碼層級比對（llama-chat.cpp 逐行比對 chat_template.jinja），未使用 Xcode/Swift 實機比對，結論一致 |
| ~~`_TurnMarkerFilter` 未移植到 MLX~~ | ✅ 已完成 2026-07-19 | 抽成 `lib/core/inference/turn_marker_filter.dart` 共用，`MlxSession` 也套用，見下方章節 |
| C 線效能疑點（A02 觀察到 CPU 只用 ~33%） | 尚未查明 | C04 pilot 這次 prompt 太短沒特別觀察 CPU 使用率，C05 正式跑矩陣時建議順便查 |
| ~~task-C01（埋量測+匯出）~~ | ✅ 已完成 2026-07-19 | 單元測試驗證+兩平台編譯驗證，見下方章節；thermal/battery channel 尚待 C04 才第一次真正上機驗證讀值 |
| ~~task-C02（標準化協定）~~ | ✅ 已完成 2026-07-19 | 見下方章節；prompt tier token 數為估計值，待用 Benchmark 畫面實測校準 |
| ~~task-C03（持續負載 harness）~~ | ✅ 已完成 2026-07-19 | 見下方章節；程式碼+單元測試完成，尚未真的跑滿 10 分鐘 |
| ~~task-C04（pilot run）~~ | ✅ 已完成 2026-07-19 | 見下方章節；過程中發現並修復 MLX busy race condition（commit `6e36dc3`），兩 backend cold/warm 皆在真機驗證成功 |
| task-C05（正式跑完整矩陣，iPhone 側） | ✅ 已完成 2026-07-19，附重要限制 | 96 筆真實樣本，但組間沒降溫、數據受熱節流污染，正式素材前建議重跑，見下方章節與結果檔 |
| task-C05（Pixel 8a 側） | ✅ 已完成 2026-07-19，附重要限制 | 4 個 GGUF tier，樣本數縮減（1冷+2暖），發現 decode/prefill 比 iPhone 慢一到三個數量級，見下方章節與結果檔 |
| task-D01（圖表產出） | ✅ 已完成 2026-07-19，附重要限制 | 見下方章節；[drafts/d01-benchmark-charts.html](drafts/d01-benchmark-charts.html) |
| task-D02/D03/D04 | 尚未動 | demo 錄影、FM 對照、簡報+講稿 |

**共用**：所有品質對照/benchmark 都用同一份 [docs/benchmark/zh-tw-prompt-set.md](../../../docs/benchmark/zh-tw-prompt-set.md)
（sampling 固定 temp 0.6 / top_p 0.95）。

---

## 進行中任務

### task-B03（部分）：llama.cpp 側 turn-marker 文字層防護 — [DONE] ✅ 2026-07-15（純程式碼，未上機驗證）

**釐清問題範圍**：追查後發現 llama.cpp backend 的 EOG 判斷（`llama_vocab_is_eog`，
`llama_cpp_ffi.dart:991/1070`）其實已經正確存在——每採樣一個 token 就檢查，命中就立刻 break，
不會多吐出任何文字。B01/A03 觀察到的尾端雜訊，實際成因是**模型偶爾不會採樣到 EOG token，
而是自己接著「幻覺」出下一輪對話**（例如吐出 `<start_of_turn>user` 或 `<|assistant|>` 後接一段
偽造發言）——這不是漏檢查的 bug，屬於模型取樣行為，純靠 token-id 層級的 EOG 檢查無法攔截。

另外確認 **MLX 側目前沒有對應程式碼可修**：T1 尚未接進 app 內的 `MlxInferenceBridge.swift`/
`mlx_channel.dart`（`recommended_models.dart` 只註冊了 T1 的 GGUF 版本），B01 觀察到的 MLX 雜訊
來自轉換階段用的 Python `mlx_lm.generate` CLI（獨立於 app），不是 app 程式碼路徑。task-B03 完整
的「接進 MLX backend + 兩 backend template 一致性驗證」（plan.md 原定 ~1.5 天）仍是 TODO，本次
只完成其中「stop-token 防護」這一部分，且只做得到 llama.cpp 那一側。

**修法**：`lib/core/inference/llama_cpp_backend.dart`
- 新增 `_TurnMarkerFilter`：在 `LlamaCppSession._runGeneration` 消費 `driver.generateStream()`
  的每個 token 時，把文字餵進 filter。filter 偵測到 `<start_of_turn>user`、`<start_of_turn>model`、
  `<|user|>`、`<|assistant|>`、`<|system|>` 任一 marker 完整出現，就在該處截斷輸出並停止生成。
- **不會拖慢正常輸出**：filter 只在文字尾端「看起來像某個 marker 的開頭」時才暫緩送出（例如
  尾端剛好是 `<start_of`），一般文字（不含 `<`）會立即照原樣往下游送，避免每個 token 都被迫等待
  一個固定視窗長度。
- 同時處理 **marker 跨多個 token chunk 被拆開**的情況（例如 `<start_of` 和 `_turn>user` 分兩個
  token 送達）——filter 的暫緩緩衝區會把兩段拼起來後才判斷。
- 若整段生成正常結束都沒有出現 marker，`flush()` 會把暫緩緩衝區裡剩下的文字（不管它長得再像
  marker 開頭）一起送出，避免真正的正常結尾文字被誤吞。

**驗證**：
1. `fvm flutter analyze lib/core/inference/llama_cpp_backend.dart test/core/inference/llama_cpp_backend_test.dart` — 0 issues。
2. `fvm flutter test test/core/inference/` — 53/53 通過，含新增 4 個 turn-marker guard 測試
   （完整 marker 截斷、`<|assistant|>` 截斷、marker 跨 chunk 偵測、無 marker 時原樣通過）；
   既有 22 個測試（含 cancel、dispose、chunk 順序）**全數不需修改就通過**，證明對正常輸出的
   時序/分段行為無副作用。
3. **尚未上機驗證**：目前只有 Dart 單元測試（fake driver 模擬文字輸出），沒有在實體裝置上用
   會觸發雜訊的真實對話重新測試。建議錄 demo 前找一次容易重現的長對話（可參考 A03 記錄的
   夜市文化→九份交通→臭豆腐那組）在實機/模擬環境跑一輪，肉眼確認尾端不再出現雜訊。

**尚未處理（明確排除在本次範圍外）**：
- MLX 側的等價防護，待 T1 實際接進 MLX backend（task-B03 剩餘部分）後再評估是否需要。
- 本次只覆蓋目前觀察到的 marker 清單；若之後在其他 prompt 上看到別種格式的偽造發言標記
  （例如 ChatML 的 `<|im_start|>`），需要把新 marker 加進 `_TurnMarkerFilter._markers`。

---

### task-B03（部分）：最小 MlxBackend/MlxSession 骨架 — [DONE] ✅ 2026-07-16（純 Dart，未接模型/未上機）

**釐清問題範圍（重要，改變了 B03 剩餘工作量的估計）**：原本 plan.md 把「接進 MLX backend」估 1.5 天，
前提似乎是假設 MLX 的 `InferenceBackend` 早就存在、只差把 T1 接上去。實際追查發現**這個假設不成立**：

- `lib/core/inference/backend_selector.dart` 跟 `lib/core/model/model_profile.dart` 的文件註解明講
  「MlxBackend（task-1001）」「MLX 多檔下載（task-1003）」都還沒做——這是更早的
  [2026-05-21-v0.1-major-refactor](../2026-05-21-v0.1-major-refactor/) 循環留下的未完成項，不是本循環
  才發現的新工作。
- 目前 app 內唯一會呼叫 `MlxChannel` 的地方是 `lib/debug/mlx_spike_screen.dart`——一個獨立的除錯畫面，
  直接繞過 `InferenceBackend`/`InferenceSession` 這層抽象，不會被真正的聊天 UI 呼叫到。
- `ModelManagerViewModel`（搜尋/下載/匯入/本地模型清單）目前**只認得單檔 `.gguf`**
  （`loadLocalModels()`/`importModels()` 都寫死 `.gguf` 副檔名判斷），MLX 需要的多檔目錄完全沒有對應
  的匯入 UI，只有 spike 畫面那個獨立、手動貼路徑的下載器。
- T1 的 MLX 權重當時（2026-07-16 動工時）只存在使用者 Mac 本機，尚未上傳，所以就算 MLX backend
  就緒，也還沒有正式的下載來源可以測。**此點已解除**：task-B02 已於同日完成上傳，見
  [Bbson/gemma-3-4B-T1-it-MLX-4bit](https://huggingface.co/Bbson/gemma-3-4B-T1-it-MLX-4bit)。

**與使用者討論後的範圍決定**：先只做最小可測試的骨架（純 Dart、不需裝置），把 T1 模型真正接上、
模型匯入 UI、以及需要在 Mac 用 Xcode 跑 Swift 層的 template 一致性驗證，都明確排除在本次之外，
留給 B02 上傳完成之後再處理（B02 現已完成，見上）。

**做了什麼**：新增 `lib/core/inference/mlx_backend.dart`
- `MlxBackend implements InferenceBackend`：`canHandle` 判斷 `ModelFormat.mlx`；`createSession` 驗證
  `profile.localPath` 已設定，回傳 `MlxSession`。與 `LlamaCppBackend` 的介面/驗證邏輯對齊。
- `MlxSession implements InferenceSession`：
  - **延遲載入模型**：`MlxChannel.loadModel()` 是跨 Pigeon platform channel 的非同步呼叫，但
    `InferenceBackend.createSession` 這個介面規定必須同步回傳——所以模型改成在**第一次呼叫
    `generate()` 時**才真正 `await loadModel()`，之後同一個 session 不會重複載入。這跟
    `LlamaCppSession`（FFI 呼叫本身是同步的，可以在 `createSession` 當下就載入）刻意不同，是兩個
    backend 底層 API 形狀差異造成的，不是不一致的 bug。
  - **system prompt 處理方式跟 llama.cpp 側不同**：`GemmaChatTemplate`（llama.cpp 用）把 system prompt
    塞進第一個 user turn的字串（因為 llama.cpp 呼叫的是寫死格式化，不支援 system role）；MLX 這邊直接
    送一個獨立的 `role: 'system'` 訊息，因為 Swift 端（`MlxInferenceBridge.swift` → mlx-swift-lm →
    swift-transformers）跑的是模型 tokenizer_config.json 裡**真正的 Jinja 模板**，該模板原生支援
    system role，不需要在 Dart 端手動塞。這個差異本身就是 task-B03 剩餘的「兩 backend template
    一致性驗證」需要處理的核心問題——目前只是把差異明確記在程式碼註解裡，還沒有測試佐證兩邊語意等價。
  - **可測試性**：仿照 `LlamaFfiDriver` 的模式，抽出 `MlxChannelDriver` 介面，讓單元測試可以注入 fake、
    不需要真正的 platform channel。
- 接進 `BackendSelector`：`lib/providers/service_providers.dart` 的 `backendSelectorProvider` 現在會
  傳入 `mlxBackendFactory: MlxBackend.new`（原本是 `null`，選到 MLX 模型會丟 `UnimplementedError`）。

**驗證**：
1. `fvm flutter analyze lib/core/inference/mlx_backend.dart lib/providers/service_providers.dart test/core/inference/mlx_backend_test.dart` — 0 issues。
2. `fvm flutter test` — 全專案 188 個測試全數通過，新增 17 個 `mlx_backend_test.dart` 測試
   （canHandle/createSession 驗證、token 串流、延遲載入且不重複載入、sampling 參數映射、seed=-1→null、
   system prompt 映射、user/assistant role 映射、cancel、dispose 生命週期），既有測試不需修改。
3. **尚未上機驗證**：這些都是 Dart 端用 fake driver 做的邏輯測試，沒有實際接真正的 T1 MLX 權重、
   沒有在 iOS/macOS 上跑過。

**尚未處理（明確排除在本次範圍外，B02 完成後的下一輪）**：
- ~~T1 MLX 權重的正式下載/匯入來源~~ → **已解除** 2026-07-16：已上傳到
  [Bbson/gemma-3-4B-T1-it-MLX-4bit](https://huggingface.co/Bbson/gemma-3-4B-T1-it-MLX-4bit)。
- `ModelManagerViewModel` 擴充支援 MLX 多檔目錄的下載/匯入/本地清單，目前完全沒有對應 UI——
  這是接下來要做 T1 真正接上 MLX backend 時仍然要處理的部分。
- 兩 backend 的 chat template 一致性測試（plan.md task-B03 原定驗收標準之一）：需要在 Mac 上用
  Xcode 跑 Swift 層（`MlxInferenceBridge.swift` 走真正的 Jinja），無法從目前這個開發環境驗證，
  也還沒設計出比較兩邊輸出的具體測試方法。
- MLX 側的 stop-token/turn-marker 等價防護（見上一節）：mlx-swift-lm 函式庫本身已經有
  `modelConfiguration.eosTokenIds` + `tokenizer.eosTokenId` + `extraEOSTokens` 的多重 EOS 偵測機制，
  理論上比 llama.cpp 更完整，但要等 T1 真的接上才能實測是否還會出現尾端雜訊。

---

### task-B03（部分）：debug 探針上機驗證 T1 真的能跑 — [DONE] ✅ 2026-07-17（實機驗證，iPhone）

**做法**：新增臨時 debug 專用畫面 `lib/debug/mlx_backend_probe_screen.dart`（`kDebugMode` +
iOS/macOS 才顯示的入口圖示，`home_screen.dart`），直接呼叫真正的 `MlxBackend`/`MlxSession`
（跳過還沒接線的 `ChatViewModel`/`BackendSelector`），對 `Bbson/gemma-3-4B-T1-it-MLX-4bit`
下載 → 建立 session → 送出繁中 prompt → 串流接收輸出，全程用實體 iPhone 測試。

**過程中的一次 `SIGKILL`**：第一輪測試（Create Session → Send）app 被系統以 `SIGKILL` 強制關閉。
用 lldb 附加的 log 確認是訊號終止（非 Dart 可捕捉的例外），懷疑是 MLX 首次載入模型時的
Metal shader JIT 編譯 + 4-bit 權重（~2.4GB）+ KV cache 疊加造成的 cold-start 記憶體尖峰
（`increased-memory-limit` entitlement 確認仍在生效，`ios/Runner/Runner.entitlements`）。
未能從 macOS 端 unified log（`/usr/bin/log stream`，過濾 jetsam/memorystatus/killed）
或 app 內 log 抓到決定性的「記憶體不足被殺」證據，只能記錄為懷疑而非確診。

**第二輪重跑（同一支 app、同一台手機、模型檔案已在本地）**：Create Session → Send **成功**，
無崩潰，串流生成出正確的繁體中文內容，`TTFT≈3.2s`、總耗時 `≈13.1s`（單次觀察值，非正式
benchmark，取樣數=1）。判斷第一次的 `SIGKILL` **非穩定重現的系統性問題**，暫不視為阻塞
task-B03 後續工作的 blocker；若未來在 C01/C02 harness 或正式接線後又重現，需要回頭正式量測
記憶體曲線（例如 Xcode Instruments）而非只靠 log 猜測。

**結論**：`MlxBackend`/`MlxSession` 的抽象設計（lazy load、串流、cancel/dispose）在真實
T1 權重上跑通，task-B03 剩餘工作（`ChatViewModel`/`BackendSelector` 正式接線、MLX 多檔匯入 UI、
兩 backend template 一致性驗證）可以開工，探針本身待正式接線完成後可以刪除。

---

### task-B03（部分）：`ChatViewModel`/`BackendSelector` 正式接線 — [DONE] ✅ 2026-07-17（單元測試驗證）

**問題**：`ChatViewModel._buildProfile` 之前寫死 `format: ModelFormat.gguf`，且 `_openSession`
自己 new 一個沒有 `mlxBackendFactory` 的 `BackendSelector()`——即使 profile.format 是 mlx，
也會直接丟 `UnimplementedError`。`service_providers.dart` 裡早就配好的
`backendSelectorProvider`（帶 `mlxBackendFactory: MlxBackend.new`）其實從未被 `ChatViewModel`
用到，是個沒人接的孤兒 provider。`CompletionViewModel` 有一模一樣的寫死問題，但這次範圍
只處理 `ChatViewModel`（使用者明確指定），`CompletionViewModel` 留待之後需要時再修。

**修法**：`lib/ui/chat/view_model/chat_viewmodel.dart`
- `_buildProfile` 改用新的 `_detectFormat(modelPath)`：副檔名 `.gguf` → `ModelFormat.gguf`，
  其他（MLX 下載下來是一個資料夾，沒有單一副檔名）→ `ModelFormat.mlx`。
- 建構子新增 `@visibleForTesting BackendSelector? backendSelector` 參數，預設值改成
  `BackendSelector(mlxBackendFactory: MlxBackend.new)`（原本是每次呼叫都 new 一個空的
  `BackendSelector()`）。`_openSession` 改用這個實例欄位而非現場 new。
- 4 個新單元測試（`test/ui/chat/view_model/chat_viewmodel_test.dart`）：`.gguf` 路徑→gguf
  profile、無副檔名路徑→mlx profile、注入 fake `BackendSelector`/`InferenceBackend` 驗證
  MLX profile 真的會呼叫到對應 backend 的 `createSession`。原有 24 個測試全數維持通過
  （都用 `sessionFactory` 繞過 `_openSession`，不受影響）。

**仍未解決（當時）**：正式 Chat 畫面完全沒有選擇/匯入 MLX 模型的入口——見下一節已解決。

---

### task-B03（部分）：MLX 多檔匯入 UI — [DONE] ✅ 2026-07-17（單元測試驗證，未上機）

**範圍決策**：跟使用者確認後，選擇「獨立最小畫面」而非把現有 `ModelManagerViewModel`/
`GGUFRepository`/`DownloadTask` 那一整套 GGUF 專用的搜尋/可續傳下載/本地清單基礎設施改造成
format-agnostic（後者工程量大很多，且會動到現有 GGUF 功能的程式碼路徑，不符合這次的最小改動
需求）。

**新增檔案**：
- `lib/data/services/huggingface_service.dart`：新增 `getMlxModelFiles(repoId)`，用同一個
  `/models/$repoId/tree/main` API，篩選條件換成 `.safetensors`/`config.json`/`tokenizer.json`
  等 MLX 權重檔（而非 `.gguf`）。
- `lib/data/services/mlx_repo_fetcher.dart`：新增 `MlxRepoFetcher` 介面 +
  `HttpMlxRepoFetcher` 真實實作（包 `HuggingFaceService` + `Dio`）。抽介面純粹是為了讓
  `MlxModelViewModel` 的下載邏輯可以在單元測試裡注入 fake、不必真的打網路——沿用
  `MlxChannelDriver`/`LlamaFfiDriver` 已經在用的同一種 driver 抽象模式。
- `lib/models/mlx_model_info.dart`：本地已下載 MLX 模型的資料類別（`repoId`/`directoryPath`/
  `totalSizeBytes`）。
- `lib/ui/models/view_model/mlx_model_viewmodel.dart`：下載/列出/刪除本地 MLX 模型快照的
  `ChangeNotifier`。每個 repo 對應一個以 slugified repo id 命名的資料夾；資料夾內另外寫一個
  `.repo_id` 標記檔記錄原始 repo id（slug 化是不可逆的——owner 名稱理論上可能含底線——標記檔
  可以正確還原，slug 反解只當作沒有標記檔時的向下相容 fallback，例如舊版 debug 探針留下的
  快照）。
- `lib/ui/models/widgets/mlx_models_screen.dart`：UI——貼 HF repo id（預設值填
  `Bbson/gemma-3-4B-T1-it-MLX-4bit`）、下載按鈕 + 進度條、本地已下載模型清單，每個項目可以
  直接「Chat」（導到 `ChatScreen(initialModelPath: model.directoryPath)`，會被上一節接好的
  `ChatViewModel` 正確辨識成 mlx profile）或刪除。
- 下載目的地沿用 debug 探針原本的位置（`ApplicationSupportDirectory/Models/mlx/<slug>`），
  刻意不透過 `DirectoryService.getModelsDirectory()`（iOS 上那個是 Documents 目錄，是特地為了
  讓使用者在「檔案」App 看到單一 GGUF 檔案而選的；MLX 是多檔目錄，不需要也不適合暴露在
  使用者可見的 Documents，且沿用同路徑代表使用者手機上已經下載好的 T1 權重不必重新下載）。

**入口**：`home_screen.dart` 新增一張正式（非 debug-only）導覽卡片「MLX Models
(Apple Silicon)」，`Platform.isIOS || Platform.isMacOS` 才顯示。

**順手清理**：刪除 `lib/debug/mlx_backend_probe_screen.dart` 及其在 `home_screen.dart` 的
debug icon 入口——該檔案自己的文件註解就寫明「一旦 ChatViewModel/BackendSelector 接線 +
真正的 MLX 模型選擇入口完成，這個檔案可以刪除」，兩個條件本次都已滿足，且它能顯示的
TTFT/token 數等 metrics，正式 Chat 畫面（`message_bubble.dart` + `ChatViewModel.MessageMetrics`）
本來就有。

**測試**：`test/ui/models/view_model/mlx_model_viewmodel_test.dart` 9 個新單元測試（用注入的
fake `MlxRepoFetcher` + 真實暫存目錄，不需要 mock 網路或 path_provider 平台 channel），涵蓋：
本地目錄不存在、標記檔還原 repoId、無標記檔 fallback 反解 slug、只有標記檔沒有權重檔要跳過、
成功下載多檔並寫入標記檔、repo 沒有 MLX 檔案時回傳失敗訊息、fetcher 拋例外時回傳失敗訊息、
空白 repo id 直接忽略、刪除本地模型後清單刷新。`flutter analyze` 全部乾淨、既有 200 個測試
全數維持通過。

**仍未驗證**：這批程式碼還沒有在實體裝置上跑過（沒有實際觸發 Download 按鈕測試真正從
Hugging Face 下載、也還沒點過 Chat 按鈕確認能不能正確從這個路徑接上 T1 生成）。下次拿到裝置
時建議先跑一輪：Download（若手機上已有舊 debug 探針下載的 T1 快照，這次改用同一個目錄，
理論上會直接被辨識成本地模型不必重下）→ 點清單裡的 Chat → 確認能正常對話。

---

### task-B03（部分）：Completion 頁面 MLX 支援 + GGUF prefill/prompt token 統計 — [DONE] ✅ 2026-07-18（已上機驗證，iPhone 17 Pro）

**背景**：上一節完成的 MLX 匯入 UI 只接了 Chat；使用者這次要求 Completion 頁面也要能選 MLX
模型。順便補上 Completion 頁一直缺的 prefill/prompt token 統計（先前只有 Decode tps 有值）。

**程式碼變更**：
- `CompletionViewModel` 套用跟 `ChatViewModel` 相同的 MLX 接線修正：`_buildProfile` 改用
  副檔名判斷格式（`.gguf` → gguf，其餘（MLX 多檔目錄）→ mlx），並注入
  `BackendSelector(mlxBackendFactory: MlxBackend.new)` 取代原本沒接 MLX factory 的預設
  `BackendSelector()`。
- `mlx_models_screen.dart` 本地模型清單新增「Completion」圖示按鈕（`Icons.edit_note_outlined`），
  導到 `CompletionScreen(initialModelPath: model.directoryPath)`。
- Completion 畫面「Select GGUF」按鈕文案改成通用的「Change」（MLX 模型也會經過這裡，原文案
  誤導）。
- 新增 `PromptMetricsSource` 能力介面（`lastPromptTokenCount`/`lastPrefillDuration`，用
  `is`/`as` 動態偵測，而非塞進 `InferenceSession` 本體）；`LlamaCppSession` 實作它，
  `GenerationController`/`CompletionViewModel.MetricsData` 跟著把這兩個值透出。**`MlxSession`
  目前未實作**，故 MLX 跑起來 Prefill tps 顯示 `-`、Prompt tokens 顯示 `0`（見下方數據，非 bug）。
- **架構修正（連帶發現）**：原本 `LlamaCppSession` 每次呼叫 `generate()` 都重新
  `createContext()`/`createSampler()`（重新配置 4096-token KV cache），這段 ~300ms 的一次性
  成本被算進 TTFT，導致跟公開 benchmark 的 TTFT 定義對不齊（公開數據的 TTFT 只算
  tokenize+prefill+首字，不含 session 建置）。改成 `createContext`/`createSampler` 只在
  session 建構時跑一次，之後每次生成前改用新增的 FFI binding `llama_get_memory` +
  `llama_memory_clear`（對照 vendored `llama.cpp/include/llama.h:701-705` 確認存在）把 KV
  cache 歸零，不重建整個 context。副作用：同一 session 重複按 Run 也變快了。
- 另修了一個先前發現的既有 bug：`ChatViewModel`/`CompletionViewModel` 建構子在
  `modelPath` 為空字串時仍會 eager 開 session，導致沒選模型就點進 Chat/Completion 直接
  crash（`ModelProfile.localPath must be set before creating a session`）；兩者建構子都加上
  `if (modelPath.isNotEmpty)` 防呆。

**測試**：新增/更新測試涵蓋 MLX profile 偵測、`BackendSelector` 注入、
`createContext`/`createSampler` 只跑一次、`resetForNewGeneration` 每次生成呼叫一次、
context/sampler 建置失敗時安全跳過。全專案 221 個測試通過，`flutter analyze` 乾淨。

**commits**：`43cf841` 空 modelPath 不 eager 開 session、`5ec9e49` GGUF prefill/prompt-token
統計 + session 只建置一次、（本次 Completion MLX 接線，尚未提交）。

#### 實機數據（iPhone 17 Pro，2026-07-18，單次觀察值，非正式 benchmark）

Prompt 統一用「很盤是什麼意思？"（14 prompt tokens／GGUF tokenizer 計數），`maxTokens=256`，
`temperature=0.8`／預設 sampling（非官方 T1 建議的 0.6/0.95，這次是隨手測試，非正式 A/B）。

| 項目 | GGUF（llama.cpp，`twinkle-ai-gemma-3-4b-t1-it-q4_k_m.gguf`） | MLX（`Bbson/gemma-3-4B-T1-it-MLX-4bit`，session 建立後第一次生成／冷啟動） | MLX（同一 session 第二次生成／熱啟動） |
|------|------|------|------|
| TTFT | 360ms | 3.75s | **552ms**（-85%），補下載 `chat_template.jinja` 後重測一致為 562ms |
| Prefill tps | 2639.02（≈5.3ms，僅算 batch decode，不含 tokenize/context 建置，見下方口徑說明） | `-`（`MlxSession` 未實作 `PromptMetricsSource`） | `-` |
| Decode tps | 21.54 | 27.32 | 27.26 |
| Prompt tokens | 14 | 0（同上，非真的 0 token，是統計缺口） | 0 |
| Gen tokens | 256 | 256 | 256 |

**補充**：上面熱啟動欄位第一次測（552ms）是舊快照（缺 `chat_template.jinja`）跑的；補下載
chat template 後在新 session 重測一次，TTFT/Decode tps 數字幾乎沒變（562ms／27.26 vs
552ms／27.32），符合預期——chat template 只影響 prompt 格式化內容，不影響推論速度。真正的
差異在輸出品質：這次生成的內容變得更有結構（`### 什麼是「很盤」？`/`### 起源`/`### 用法`
分節），不再像退回純文字格式時那樣夾雜離題的反問句開頭。

**冷啟動 3.75s → 熱啟動 552ms 的落差**：判斷是 MLX 的 lazy-evaluation 計算圖在第一次生成時
做 JIT 編譯的一次性成本，屬 MLX runtime 內建行為，跟上面 GGUF 那筆「context 每次重建」是
不同成因、也沒有對應的 app 層 API 可以繞過。之後量 MLX 效能建議固定用「熱啟動」（同一
session 第二次以後）的數字，比較有代表性。

**GGUF Prefill tps 口徑提醒**：上表 2639.02 是套用 session-only-once 修正*之前*截圖記錄的
數字（当時 createContext/createSampler 還是每次生成都重跑，TTFT 360ms 裡有 ~300ms 是這段
建置成本，不算在 Prefill 裡）。

**✅ 修正後重新上機測試 2026-07-18**（同一 session，連續按兩次 Run，同一句 prompt）：

| 項目 | 第一次（同一 session 首次生成） | 第二次（同一 session 再次生成） |
|------|------|------|
| TTFT | 440ms | **158ms**（-56% vs 修正前的 360ms） |
| Prefill tps | 1173.02（≈11.9ms） | 2642.51（≈5.3ms，跟修正前單次測到的 2639.02 幾乎一致） |
| Decode tps | 23.95 | 22.84 |
| Prompt tokens | 14 | 14 |

修正確實生效：同一 session 重複生成時 TTFT 從 360ms 降到 158ms。但**意外發現一個新的、規模較小
但性質類似的現象**——同一個 session 裡「第一次」生成（440ms）反而比「第二次」（158ms）慢，
且 Prefill tps 也是首次明顯較低（1173 vs 2642，約 2.25 倍）。這不是 session 建置成本
（那個已經在建構子跑完，不在這次計時範圍內），推測是 Metal GPU 後端在**第一次真正的
compute dispatch**（batch prefill 的 shader/pipeline-state-object）發生類似 MLX 冷啟動的
一次性 JIT 成本，只是規模小很多（llama.cpp/Metal ~280ms vs MLX ~3.2s）。跟 MLX 那次一樣，
之後量 GGUF 效能也建議固定用「同一 session 第二次以後」的數字才有代表性；這個現象本身
不是 bug，沒有對應的 app 層修法，記錄供之後 C 線正式 benchmark harness 設計測試協定時參考
（例如每個 prompt tier 應該跑 warm-up 一次再開始正式計時）。

**缺 chat template 問題 — 已診斷、已修復 2026-07-18**：`MlxInferenceBridge.swift` 載入
`Bbson/gemma-3-4B-T1-it-MLX-4bit` 時，log 印出 `No chat template was included or provided,
so converting messages to simple text format`（來自 swift-transformers `Tokenizers` 套件，
`MlxInferenceBridge.swift:45-56` 的 `applyChatTemplate` 呼叫鏈）。

- **根因**：不是 swift-transformers 版本問題（已確認 1.3.3 是目前最新版），也不是模型/repo
  本身沒有模板。用 `huggingface.co/api/models/Bbson/gemma-3-4B-T1-it-MLX-4bit` 查檔案清單，
  確認 repo 裡有獨立的 `chat_template.jinja`（4280 bytes，內容跟原始來源模型
  `twinkle-ai/gemma-3-4B-T1-it` 的 `tokenizer_config.json` 內嵌 `chat_template` 欄位逐字元
  相同——`mlx_lm.convert`/新版 HF 慣例把 chat template 從 `tokenizer_config.json` 拆成獨立檔案）。
  真正問題出在**我們自己的下載清單**：`huggingface_service.dart` 的 `getMlxModelFiles()`
  白名單過濾只認舊式檔名（`tokenizer_config.json`/`tokenizer.json`/... ），沒有把
  `chat_template.jinja` 算進「MLX 需要的檔案」，導致 app 下載模型時**根本沒把這個檔案抓下來**，
  手機上的本地快照資料夾裡就是缺這一檔，swift-transformers 在磁碟上找不到才回報缺模板。
- **修法**：`getMlxModelFiles()` 篩選條件新增 `chat_template.jinja`（及 `chat_template.json`
  作為另一種可能慣例的保險）。`flutter analyze` 乾淨，既有 221 個測試全數維持通過（這個
  service 本來就沒有既有單元測試——是薄 Dio wrapper，跟現有測試慣例一致，未新增測試基礎設施）。
- **✅ 已上機驗證 2026-07-18**：刪除舊快照重新下載，log 從「Found 7 MLX files」變成
  `Found 8 MLX files in Bbson/gemma-3-4B-T1-it-MLX-4bit`（多的就是 `chat_template.jinja`）。
  重新在 Completion 頁面對同一個 session 跑「很盤是什麼意思？」，`createSession` 之後**沒有
  再出現**`No chat template...` 警告（先前每次都會印）。輸出內容也變得更有結構
  （`### 什麼是「很盤」？`/`### 起源`/`### 用法` 分節），不再像先前退回純文字格式時那樣夾雜
  離題的反問句開頭——單次觀察，非嚴謹 A/B，但方向一致，判定此修正已生效。

---

### task-B03（最後一項）：兩 backend chat template 一致性驗證 — [DONE] ✅ 2026-07-18（原始碼層級比對，非 Xcode 實機比對）

**方法決策**：plan.md 原本預期這項要「在 Mac 上用 Xcode 跑 Swift 層」才能驗證，但這個開發
環境無法起 Xcode/跑 Swift。改用**原始碼層級逐行比對**，直接比較 llama.cpp 實際執行的
hardcoded C++ 格式化邏輯，跟 MLX 側 swift-transformers 真正套用的官方 Jinja 模板——判斷這比
在裝置上肉眼比對輸出文字更嚴謹（後者容易被模型取樣的隨機性干擾，前者是決定性的邏輯比對）。

**比對材料**：
- llama.cpp 側：vendored 原始碼 `llama.cpp/src/llama-chat.cpp:375-396`（`LLM_CHAT_TEMPLATE_GEMMA`
  分支），非猜測，直接讀原始碼確認。
- MLX 側：`curl` 直接拉 `huggingface.co/Bbson/gemma-3-4B-T1-it-MLX-4bit/raw/main/chat_template.jinja`
  （120 行，4280 bytes）——就是這次 task-B03 chat-template-download bug 修好後，使用者手機上
  實際下載到、swift-transformers 真正拿去跑的同一份檔案。額外用 HF API 確認這份 4280 bytes
  跟原始來源模型 `twinkle-ai/gemma-3-4B-T1-it` 的 `tokenizer_config.json` 內嵌 `chat_template`
  欄位逐字元相同——`mlx_lm.convert` 只是把它拆成獨立檔案，內容沒有被改動過。

**比對結果（純對話情境，無 tools，符合 A01/B03 明確排除 tool-calling 的既定範圍）**：

1. **無 system prompt，單一 user turn**（用這次 Step 1 上機驗證的同一句「很盤是什麼意思？」）：
   兩邊逐字元相同：`<start_of_turn>user\n很盤是什麼意思？<end_of_turn>\n<start_of_turn>model\n`。
   **這段還額外對照了 Step 1 GGUF 上機測試的真實 log**（`tokenizePrompt prompt: <start_of_turn>
   user\n很盤是什麼意思？<end_of_turn>\n<start_of_turn>model\n`）——手算逐行追蹤 llama-chat.cpp
   邏輯的結果，跟裝置上真實跑出來的字串完全吻合，交叉驗證了這次比對方法本身是可信的。
2. **含 system prompt**（benchmark 實際用法，見 plan.md「統一用一句台灣定調 system prompt」）：
   兩邊都把 system prompt 併入第一個 user turn，格式都是 `{system}\n\n{user_content}`，順序、
   角色標記皆相同。**唯一發現的微小差異**：llama.cpp 對 system prompt 內容做 `trim()`
   （去除頭尾空白）才合併，Jinja 模板這個分支沒有對 system prompt 做 `|trim`。只有在 system
   prompt 字串本身頭尾有多餘空白時才會有差異，對這次寫死在 app 裡的 system prompt 常數字串
   沒有實際影響，記錄但不視為阻塞項。

**判定：兩個 backend 在純對話情境下語意等價** → task-B03 最後一項完成，跟 task-A01 當初對
llama.cpp vs 官方模板的獨立比對結論一致，這次額外確認了 MLX 側真的在執行同一份官方 Jinja
檔案（而非某個過期/被 mlx_lm.convert 動過手腳的版本）。**task-B03 全部子項至此全數完成**。

**已知範圍外**：工具呼叫（tool calling）情境的一致性未驗證——兩邊模板都有 tools 分支，但
A01/B03 從一開始就明確排除 tool-calling（本次 benchmark/demo 純對話），維持原排除範圍。

---

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

### task-B02: 上傳到自己 HF repo + 繁中 model card — [DONE] ✅ 2026-07-16（2026-07-16 改案，同日完成）

**改案原因**：原計畫要向 Twinkle org 要 write 權限，但協調時間不可控，卡住了 task-B03（T1 接進
MLX backend）。跟使用者確認後改成**直接上傳到使用者自己的 HF repo**（`Bbson/gemma-3-4B-T1-it-MLX-4bit`），
不再需要等 org 回覆；改成單向發一則禮貌性通知訊息給 Twinkle org（不要求任何權限，附上連結保持
社群能見度即可），不影響上傳排程。

- ✅ 繁中 model card 草稿 → [drafts/model-card-zh-tw.md](drafts/model-card-zh-tw.md)（已改用
  `Bbson/gemma-3-4B-T1-it-MLX-4bit` repo id，致謝段落同步更新）
- ✅ org 通知訊息草稿 + 追蹤清單 → [drafts/twinkle-org-outreach.md](drafts/twinkle-org-outreach.md)
  （已改寫為禮貌性通知，不再要求 write 權限）
- ✅ **4-bit MLX 權重已上傳** → [Bbson/gemma-3-4B-T1-it-MLX-4bit](https://huggingface.co/Bbson/gemma-3-4B-T1-it-MLX-4bit)
  （2026-07-16）。過程中遇到一次 `hf upload` 403（fine-grained token 沒有 write/LFS 權限），
  換成有 write 權限的 token 後上傳成功。
- ⏳ 尚餘（不影響其他任務，可隨時做）：（可選）送出通知訊息給 Twinkle org，不需等回覆
- **task-B03 卡點已解除**：T1 現在有正式的 MLX 下載來源了。

---

### 順手處理：`_TurnMarkerFilter` 補到 MLX — [DONE] ✅ 2026-07-19

上一輪接手快照記錄的技術債：`_TurnMarkerFilter`（防止模型沒採樣到 EOG/EOS 時吐出下一輪幻覺
文字）只在 `LlamaCppSession` 有做，`MlxSession` 沒有。C 線要正式跑 MLX benchmark 前先補上，
避免這段雜訊污染生成文字/token 數統計。

**做法**：把 `_TurnMarkerFilter` 從 `llama_cpp_backend.dart` 抽成共用元件
`lib/core/inference/turn_marker_filter.dart`（`TurnMarkerFilter`，拿掉底線前綴），兩個
session 都改用同一份。`MlxSession._runGeneration` 套用方式與 `LlamaCppSession` 完全對稱
（token 進 filter、偵測到 marker 就截斷+停止、正常結束時 `flush()` 剩餘緩衝）。

**測試**：新增 `test/core/inference/turn_marker_filter_test.dart`（7 個純邏輯單元測試），
`mlx_backend_test.dart` 補 4 個對稱於 `llama_cpp_backend_test.dart` 既有 4 個的整合測試
（完整 marker 截斷、`<|assistant|>` 截斷、marker 跨 chunk、無 marker 原樣通過）。
`flutter analyze` 乾淨，全專案 232/232 測試通過（+11）。commit `1917ab5`。

---

## C 線：Benchmark Harness

### task-C01: App 內埋量測 + CSV/JSON 匯出 — [DONE] ✅ 2026-07-19（單元測試驗證，未上機）

**做法**：延續既有 `GenerationController`/`PromptMetricsSource` 機制（上週 task-B03 已做出
TTFT/prefill tps/prompt tokens），不重造輪子，只新增 C01 驗收標準要求、既有機制沒有的三項：
峰值記憶體、thermalState、電量，加上一層 orchestration 把「模型載入時間」也量進去。

新增 `lib/core/benchmark/`：
- `benchmark_sample.dart`：`BenchmarkSample`——內嵌既有 `GenerationMetrics`（不重複欄位），
  加 `format`/`modelId`/`label`/`modelLoadDuration`/`generatedText`/`peakMemoryBytes`/
  `thermalStateBefore/After`/`batteryLevelBefore/After`。文件註解明講一個重要的架構不對稱：
  `modelLoadDuration` 對 GGUF 是真的載入耗時（`LlamaCppSession` 建構子就做完
  `createContext`/`createSampler`），對 MLX 幾乎是 0（`MlxSession` lazy load，真正的載入成本
  併在第一次 `generate()` 的 TTFT 裡）——這是既有架構差異，不是量測缺口。
- `benchmark_recorder.dart`：`BenchmarkRecorder`——`runNewSession`（計時
  `backend.createSession`，記一次生成）+ `runOnExistingSession`（同一 session 上再記一次，
  可重複呼叫）。thermal/battery 在生成前後各讀一次，peak memory 在收到每個 token 時取樣取最大值。

新增 `lib/core/platform/`（三個可測試 probe，皆仿 `LlamaFfiDriver`/`MlxChannelDriver` 的
「抽介面＋fake」模式）：
- `memory_probe.dart`：`dart:io` `ProcessInfo.currentRss`，零新依賴、免平台 channel。
- `thermal_probe.dart` + 新 Pigeon API `pigeons/device_telemetry.dart`
  （`DeviceTelemetryHostApi.getThermalState()` → `ThermalStatus` 4 級列舉）：iOS 讀
  `ProcessInfo.processInfo.thermalState`（`ios/Runner/DeviceTelemetry/DeviceTelemetryBridge.swift`），
  Android 讀 `PowerManager.getCurrentThermalStatus()`（API 29+；`DeviceTelemetryBridge.kt`，
  低於 API 29 回傳 `unknown`）。iOS 這份 Pigeon 輸出踩到一個已知 Pigeon 限制：專案裡已有
  `MlxInference.g.swift` 產生過一份 `PigeonError` 類別，第二份 Pigeon 輸出檔預設也會產生同名
  類別，導致 `Invalid redeclaration of 'PigeonError'`——修法是在
  `pigeons/device_telemetry.dart` 設 `swiftOptions: SwiftOptions(includeErrorClass: false)`，
  讓新檔案共用既有那份。
- `battery_probe.dart`：包 `battery_plus`（同一個 plus_plugins 家族，專案已有
  `device_info_plus`/`connectivity_plus`/`package_info_plus`/`share_plus`，風格一致）。

新增 `lib/ui/benchmark/`：debug-gated（`kDebugMode`，plan.md 早就把 C 線定調為「內部量測工具」
非對外功能）的 `BenchmarkScreen` + `BenchmarkViewModel`，可開 session 跑 cold/warm、匯出
CSV/JSON（`benchmark_export.dart`，手刻 CSV escaping，沒有另外引入 `csv` 套件）。入口掛在
`home_screen.dart`。

**驗證**：
1. `flutter analyze`／`flutter test` 全乾淨，新增 24 個單元測試（`benchmark_recorder_test.dart`
   13 個、`benchmark_export_test.dart` 9 個，其餘在 platform probe 層——production 實作本身
   仿照 `_RealFfiDriver`/`_RealMlxChannelDriver` 的慣例不另外單元測試，只測試上層邏輯）。
2. `flutter build ios --debug --no-codesign` + `flutter build apk --debug` 皆過，證明新
   Pigeon channel（Swift+Kotlin 雙平台）語法正確、能編譯連結——**但這只是編譯驗證，尚未上機
   跑過真正的 thermal/battery 讀值**（task-C04 pilot 才第一次上機驗證，見下方）。

commit `1917ab5`（turn-marker 抽共用）、`dfe0fa3`（C01）。

### task-C02: 標準化測試協定 — [DONE] ✅ 2026-07-19

**做法**：`lib/core/benchmark/prompt_tiers.dart`（`PromptTier.l128/l512/l1024/l2048`）定版
四個長度 tier 的繁中內容草稿，同步寫進 `zh-tw-prompt-set.md` Part 2 對照版。**token 數是估計
值，非實測**——唯一的真實校準錨點是 task-B03 記錄的「很盤是什麼意思？」8 字元／14 tokens
（約 1.8 tokens/字元），四個 tier 依此反推草稿字數，待用 Benchmark 畫面實際跑一次讀
`promptTokenCount` 校準（MLX 這欄目前恆為 null，只能用 GGUF 校準，見下方 C04 發現）。L2048
刻意做成真正的多輪 `ChatMessage` 對話（環島旅行規劃 6 輪），不是塞一個超長字串，比較貼近
plan.md 原意的「長對話脈絡累積」。

**冷啟動定義**（回應使用者這輪明確提出的疑慮）：把 2026-07-18 上機發現的「同一 session 第一次
生成比第二次慢」現象，正式定義成三種互斥、禁止混平均的狀態——`app-cold`（App 剛重啟後第一個
session 的第一次生成，需要人工 force-quit+重開才能觸發，harness 偵測不到「app 剛啟動」，
標記責任在操作者）、`session-cold`（App 行程持續中，開新 session 的第一次生成）、
`session-warm`（同一 session 第 2 次以後）。`lib/core/benchmark/protocol_runner.dart`
（`BenchmarkProtocolRunner`）依此自動標籤：`runAll(appJustLaunched: true)` 只把第一個 tier
的第一個樣本標 `app-cold`，其餘 tier 一律 `session-cold`，每個 tier 的暖啟動樣本標
`session-warm-{n}`。

同時新增 pre-flight check（`BenchmarkRecorder.checkPreflight()` → `PreflightStatus`）：
app 能自己讀 thermal/battery 並在 Benchmark 畫面用 banner 顯示（thermal 非 nominal 時標紅
提醒降溫），但飛航模式/固定亮度兩項兩個平台的第三方 App 都讀不到，保留為畫面上的手動提醒文字，
不假裝 app 能自動確認。

**驗證**：`protocol_runner_test.dart` 6 個測試（用真實 `PromptTier.all` 4 個 tier 跑過一輪，
驗證標籤序列正確、`warmRepeats`/`appJustLaunched` 行為正確）。全專案 250 個測試通過，
`flutter analyze` 乾淨，iOS/Android 皆重建過確認 UI 新增內容編譯正常。

commit `14150e1`。

### task-C03: 持續負載測試 — [DONE] ✅ 2026-07-19（單元測試驗證，未上機跑滿 10 分鐘）

**做法**：`lib/core/benchmark/sustained_load_runner.dart`（`SustainedLoadRunner`）——刻意
不新增一套時間序列資料型別，直接重複呼叫 C01 已有的
`BenchmarkRecorder.runOnExistingSession`：每次生成本來就會在生成前後各採樣一次
thermal/battery、生成期間逐 token 採樣 peak memory，所以背靠背呼叫本身就自然形成一個
「一次生成＝一個時間點」的時間序列，`BenchmarkSample.timestamp` 就是 x 軸，不必另外設計
schema。迴圈以 wall-clock `duration`（預設 10 分鐘）或 `maxIterations`（測試用）為終止條件，
支援 `cancel()` 中途停止。Benchmark 畫面加了「Run 10 min sustained load」/「Stop」兩顆按鈕。

**驗證**：3 個測試（`maxIterations` 提早停止、無開啟 session 時丟 `StateError`、`cancel()`
提早停止——用有人工延遲的 fake session 製造可控的競態窗）。**尚未真的在裝置上跑滿 10 分鐘**，
邏輯層面驗證足夠但實際發熱曲線數據要等 C04/C05 上機。

commit `3c3e6c4`。

### task-C04: Pilot run — [DONE] ✅ 2026-07-19（實機驗證，iPhone 17 Pro，過程中發現並修好一個 MLX bug）

**做法**：沒有用手動點畫面的方式做 pilot（沒有工具可以自動幫忙點實體手機螢幕），改寫
`integration_test/benchmark_pilot_test.dart`——直接在 app 行程內用 Dart 呼叫
`BenchmarkViewModel`，繞過 UI，對已經下載在裝置上的真實 T1 權重跑 GGUF 與 MLX 各一次
cold+warm，`print` 結果讓 log 直接印回終端機。新增 `integration_test` dev dependency。

**過程波折（記錄供下次上機測試的人參考）**：
1. iPhone 一度從 USB 掉成純無線連線，`flutter test -d <device>` 對純無線裝置需要額外設定，
   直接請使用者重插 USB 線解決。
2. `flutter test integration_test/...` 每次呼叫都會**重新安裝整個 app（新的 sandbox
   container UUID）**，先前用 `xcrun devicectl device copy from/to` 手動放進裝置的 T1
   權重（GGUF `Documents/Models/`、MLX `Library/Application Support/Models/mlx/`）會跟著
   舊 container 一起變成孤兒、新 container 裡是空的。摸索出穩定流程：`flutter build ios
   --debug`（要 codesign，不能用 `--no-codesign`，否則裝不上裝置）→ `flutter install`
   （這步本身不會洗掉 container）→ 用 `devicectl copy to` 把本機暫存的權重複製進新 container
   → 這之後**只要沒改 Swift/Kotlin 原生程式碼**，再跑 `flutter test` 產生的是同一份 binary，
   container 不會被洗掉；一旦改了原生程式碼（本次改了 `MlxInferenceBridge.swift`）就要整套
   重跑一次。

**結果（maxTokens=64，非正式 protocol 設定，純粹驗證管線）**：

| 項目 | GGUF session-cold | GGUF session-warm | MLX session-cold | MLX session-warm |
|------|------|------|------|------|
| modelLoadDuration | 7828ms | 0ms | 0ms（lazy load 併入 TTFT，見 C01 文件註解） | 0ms |
| TTFT | 693ms | 140ms | 7316ms | 328ms |
| Decode tps | 24.41 | 24.17 | 28.71 | 28.43 |
| Peak memory | ~3.68GB | ~3.68GB | ~1.49GB | ~1.49GB |
| thermalState | fair→fair | fair→fair | fair→fair | fair→fair |
| battery | 80→80 | 80→80 | 80→80 | 80→80 |

兩個 backend 的 cold→warm 巨幅改善都在真機上重現（GGUF 693→140ms、MLX 7316→328ms），跟
2026-07-18 的觀察方向一致（那次 GGUF 是 440/158ms、MLX 是 3.75s/552ms——同一現象，數字有
run-to-run 變異，見下方發現）。CSV/JSON 匯出對 GGUF 驗證過，檔案非空、欄位齊全。

**發現 1（P0，已修復）：MLX 背靠背生成會被原生層誤判「busy」**。第一次 pilot 沒套用修法前，
MLX 的 `session-warm` 呼叫 100% 失敗，丟 `PlatformException(busy, Generation already in
progress.)`。追查 `ios/Runner/MlxBridge/MlxInferenceBridge.swift` 發現：`startGeneration`
用 `generationTask != nil` 擋重入，但清空 `generationTask` 的 `defer` 要等整個
`for await generation in stream` 迴圈**真正跑完**（也就是底層 `AsyncStream` 呼叫
`continuation.finish()`、迴圈拿到 `nil` 才退出）才會觸發——而 Dart 端一收到代表最後一個 token
的 `.info` 事件（`isDone: true`）就認定生成已結束，可以立刻呼叫下一次
`startGeneration`。這中間有一段時間差，背靠背呼叫（C02 協定的 cold→warm 就是這樣呼叫）幾乎
必定命中。**這不只是 benchmark harness 的問題**——任何真實使用情境只要快速連續觸發兩次 MLX
生成（例如 Chat 畫面快速點兩次「重新生成」）都可能中招。

修法：把清空 `generationTask` 的時機提前到「收到 `.info`、準備送出 `isDone` 事件之前」，而不是
等迴圈自然結束之後；另外加一個 `generationEpoch` 計數器，確保提前清空的邏輯不會誤刪
「呼叫當下已經是另一次全新生成」的狀態（避免用一個更早的競態換一個更隱晦的競態）。
修好後 pilot 兩次（含本次）皆成功。commit `6e36dc3`。

**發現 2：cold-start TTFT 本身有明顯 run-to-run 變異，且看起來跟 thermalState 相關**。
GGUF 兩次分別是 440ms（2026-07-18）／693ms（本次）；MLX 兩次分別是 3.75s／7.3s——量到
7.3s 那次 `thermalState` 已經是 `fair`（裝置經過本輪長時間開發/建置後升溫，非
`nominal`）。已回寫 `zh-tw-prompt-set.md` Part 3：C05 正式跑矩陣時，每個 tier 建議跑
**≥3 次獨立的 session-cold**（重新開 session，不是重跑同一個 session 的 warm），取中位數，
並且真的落實「組間降溫」而非流於形式。

**發現 3（確認既有已知缺口，非新發現）**：MLX 的 `promptTokenCount`／`prefillTokensPerSecond`
仍是 `null`（`MlxSession` 未實作 `PromptMetricsSource`）。D 線圖表設計時要考慮這一欄 MLX
天生缺值。

**尚未驗證**：C03 的 10 分鐘持續負載、C05 的完整矩陣（含 Pixel 8a，本次開發環境未接
Android 裝置）——留給下一輪或使用者自行執行，`BenchmarkProtocolRunner`/`SustainedLoadRunner`
已可直接使用。

commit `6e36dc3`（MLX bug 修復）、`4e1c5ed`（pilot integration test）。

### task-C05: 正式跑完整 benchmark 矩陣（iPhone 側）— [DONE，附重要限制] ✅ 2026-07-19

**做法**：`integration_test/c05_matrix_test.dart`——8 個獨立 `testWidgets`（2 backend × 4
tier），每個組合用 `BenchmarkProtocolRunner.runTier` 跑 3 次（3 次獨立 session-cold，呼應
C04 發現的 cold-start 變異，每次 warmRepeats=3），共 12 樣本/組合 × 8 = **96 筆真實樣本**，
`kBenchmarkDefaultSettings`（temp 0.6/topP 0.95/maxTokens 512，官方建議 sampling）。
完整數據與分析見 [docs/benchmark/2026-07-19-c05-iphone-results.md](../../../docs/benchmark/2026-07-19-c05-iphone-results.md)。

**⚠️ 重要限制，記錄供下次參考**：8 個組合是背靠背連續跑完的，**組間完全沒有降溫**——
`thermalState` 跑到約一半（GGUF-L128 組合中途）就從 `fair` 升到 `serious`，之後全程停在
`serious`。這代表本次數據**可以做兩個 backend／四個 tier 之間的相對比較**，但**絕對數字
（尤其 cold TTFT、decode tps）受連續熱節流污染，不建議直接當作 D 線 talk 的正式素材**——
decode tps 在單一組合內部就從高點腰斬到低點（例如 GGUF-L128：21.56→14.20 tok/s；
MLX-L128：28.01→14.68 tok/s）。這其實意外印證了 C03「持續負載/發熱曲線」的核心現象，
只是用矩陣跑法而非專門的 10 分鐘連續測試碰上的。

**額外校準/發現**（已寫回 docs/benchmark 檔案，未寫回 `prompt_tiers.dart` 內文本身——留給
下一輪處理）：
1. Prompt tier 實測 token 數（GGUF tokenizer）：64／223／343／464，對照目標
   128／512／1024／2048——**L1024/L2048 兩個 tier 的草稿內容明顯太短**，尤其 L2048 只到
   目標的四分之一，需要加長內文重新校準。
2. MLX peak memory 隨 maxTokens 明顯上升：C04 pilot（maxTokens=64）量到 ~1.49GB，這次
   （maxTokens=512）量到 ~3.16–3.27GB——推測 MLX 的 KV cache 是動態成長（不像 GGUF 用固定
   `nCtx=4096` 預先配置），長生成會直接推高記憶體。D 線畫記憶體對比圖要標明量測時的
   maxTokens，不能把不同 maxTokens 下的數字混在一起比。
3. `flutter test integration_test/...` **每次呼叫都會重新安裝 app（新 sandbox
   container）**，8 個組合各自的 CSV 匯出檔分散在 8 個不同、大多已隨舊 container 變孤兒的
   路徑下，事後無法統一拉回單一檔案——這份文件的數據是從終端機輸出人工彙整。下次建議把
   8 個組合合併進同一次 `flutter test` 呼叫（共用一個 `BenchmarkViewModel` 累積樣本），
   換取單一 CSV 輸出，代價是不能個別重跑單一組合。

**Pixel 8a 側（同日補做，使用者接上裝置後）**：4 個 GGUF tier 全部完成，數據與分析見
[docs/benchmark/2026-07-19-c05-android-results.md](../../../docs/benchmark/2026-07-19-c05-android-results.md)。
樣本數縮減為 1 次 cold + 2 次 warm（而非 iPhone 側的 3+9）——Android 單次生成太慢（最長
L2048 冷啟動 TTFT 達 65 秒），完整協定不可行。

**最重要的新發現：Android decode/prefill 速度比 iPhone 慢一到三個數量級**——decode
1.2–3.6 tok/s（iPhone 14–24）、**prefill 只有 7–11 tok/s**（iPhone 幾百到幾萬），這直接
解釋了 TTFT 隨 prompt 長度幾乎線性暴增（L128 6秒 → L2048 65秒），也印證了 task-A02 當時
「CPU 只用到 ~33%」的疑點。

**✅ 根因已查明（2026-07-19，同日使用者要求追查）**：檢查 `scripts/build_llama.cpp_android.sh`
與 `llama.cpp/build-android-arm64-v8a/CMakeCache.txt`/`compile_commands.json` 後確認：
Android 版 `.so` 建置**完全沒有走加速路徑**——`GGML_VULKAN`/`GGML_OPENCL` 皆 `OFF`（iOS
靠 Metal GPU 加速，Android 這邊全落在 CPU），且 `GGML_NATIVE=OFF` + 建置鎖定
`ANDROID_PLATFORM=android-23`（2015 年 Android 6.0 基準）沒有任何 `-march`/`-mcpu` 旗標，
連 `ggml-cpu/arch/arm/repack.cpp` 裡靠 `__ARM_FEATURE_DOTPROD`/`__ARM_FEATURE_MATMUL_INT8`
判斷式保護的量化矩陣乘法優化路徑都完全沒被編譯進去——Pixel 8a 的 Tensor G3 硬體上其實支援
這兩個指令集，只是現在的建置完全沒用到，退回最基本的通用 NEON/純量實作。判定是**刻意的廣泛
相容性選擇**（讓同一份 build 能跑在很舊的低階機款上不崩潰），不是疏漏，但代價是犧牲了新機
效能。建議修法（未實作，另開任務）：開 `-DGGML_VULKAN=ON`（對應 iOS Metal，潛在增益最大）+
`-DGGML_CPU_ALL_VARIANTS=ON`（llama.cpp 官方支援的多版本執行期自動選擇，兼顧舊機相容與新機
效能），詳見結果檔。

**上機過程另外排除了三個 Android 特有的自動化障礙**（詳見結果檔「執行障礙」章節，供下次
參考）：
1. `MANAGE_EXTERNAL_STORAGE` 權限每次 app 重裝就被重置（`flutter test` 每次呼叫都重裝，
   且 debug/release 簽章不同會強制先解除安裝）——修法：每次呼叫前都重新 `flutter install
   --debug` + `adb shell appops set`。
2. debug build 會彈出「16KB 分頁對齊」相容性警告（vendored `libllama.so`/`libggml*.so`
   未對齊 16KB，Android 未來的頁面大小要求），擋住畫面讓自動化測試卡住——只在 debuggable
   build 出現，不影響 release，但這是一項真實技術債，記錄供未來考慮升級 vendored
   llama.cpp 建置旗標時一併處理。
3. **間歇性 ANR**（`adb logcat` 找到根因：`Input dispatching timed out ... Waited 5002ms
   for FocusEvent`）——`flutter test` 自動重裝+啟動的流程中，app 視窗有時來不及在 5 秒內
   取得焦點，被系統判定 ANR 砍掉，發生機率約 30–50%，重跑通常能過。根因未完全查明，記錄
   為潛在的真實產品風險（不只是 harness 問題）：如果低階 Android 裝置在正式 app 也有類似
   啟動期 ANR 傾向，值得另開任務調查。

**正式 talk 素材前建議重跑**：iPhone 側組間插入等待 `thermalState` 回到 `nominal` 的步驟、
先修正 `prompt_tiers.dart` 的 L1024/L2048 內文、8+4 個組合合併成單次呼叫方便統一匯出；
Android 側先查明 prefill 異常緩慢的根因，否則重跑也拿不到有意義的乾淨數字。

commit `f959968`（Android 矩陣）、`9950940`（根因調查）。

---

### task-D01: 圖表產出 — [DONE，附重要限制] ✅ 2026-07-19

**做法**：用 dataviz skill 的方法論（categorical 配色跑過 validator、cold/warm 用同一色相的
透明度兩階做 sequential 次序、SVG 手刻搭配 hover tooltip）產出單頁 HTML，資料直接內嵌
C05 兩份結果檔的原始樣本（iPhone 96 筆 + Android 12 筆），彙總邏輯（中位數）寫在頁面自己的
JS 裡而非事先手算貼數字，避免抄錄誤差。存在
[drafts/d01-benchmark-charts.html](drafts/d01-benchmark-charts.html)，另外發布成 Artifact
供快速預覽。

**5 類圖表 + 1 矩陣圖**：
1. TTFT（iPhone/Android 兩面板，cold 淺色/warm 實色）
2. Decode tokens/s（同上）
3. 峰值記憶體（單色長條，iPhone 用固定 nCtx 預先配置 vs MLX 動態成長的走勢對比）
4. **發熱節流曲線**——直接把 iPhone 8 個組合、96 筆樣本按實際執行序畫成一條線，清楚看到
   decode tps 隨組合推進下滑、thermalState 在第 8 筆樣本附近從 `fair` 轉 `serious` 後回不去
   ——這是本頁最強的一張圖，直接把上面「組間沒降溫」的警示畫成證據，也意外達成了 task-C03
   原本想要的「持續負載發熱曲線」效果（雖然是矩陣測試的副產品，不是專門的 10 分鐘測試）。
5. **電量消耗**——誠實呈現「目前沒有乾淨資料」（iPhone 90%→90% 全程無變化、Android
   9%→31% 充電中），而非用僅有的數字硬畫一條看似合理但誤導的曲線，並註明需要 task-C03
   在斷電狀態下跑滿 10 分鐘才能真正回答這個問題。
6. 矩陣總覽：2×2 grid，Pixel 8a × MLX 標成「N/A — Apple Silicon only」（結構性缺席，
   非資料缺口，呼應 zh-tw-prompt-set.md 矩陣維度表原本的設計）。

**驗證**：用 Playwright（本機 headless Chromium）實際渲染頁面、截圖每個區塊逐一肉眼檢查，
抓到並修正兩個問題——(1) `renderGroupedBars` 內一個物件字面值語法錯誤誤植成變數宣告
（`padR: undefined` 混進 `const` 列表）；(2) 深色模式原本用 JS 在頁面載入當下算好一次
色碼、配一個「偵測到 `data-theme` 變化就整頁 reload」的 MutationObserver 想要「修正」，
實際上會讓深色模式一開就被自己的 reload 打回預設亮色模式，永遠切不過去——改成讓 SVG
的 `fill`/`stroke` 直接寫 `var(--blue)`/`var(--orange)` 這種 CSS 變數字串，讓顏色本身
跟著主題即時切換，不需要重整頁面。另外也照 dataviz skill 的無障礙檢查清單，補了一個
可展開的完整資料表（tier × backend × 裝置，供讀不了圖或需要精確數字時查）。

**尚未做**：D01 本身資料層面繼承了 C05 的所有限制（iPhone 熱節流污染、Android 樣本數少+
未優化建置）——圖表如實呈現這些限制，但正式簡報用的「乾淨」版本仍要等 C05 重跑。

commit（本次，尚未提交）。

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

**判定：4-bit 繁中品質達標** → 進 task-B03（接進 MLX backend）+ task-B02（已完成，見上方 task-B02 章節）。
Q3 的地名瑕疵屬個案幻覺，非系統性問題，記錄供 D02 demo 選題時避開類似問法。

## 待用戶回填（回來後回寫此檔 + plan.md 狀態）

| 來源 | 待回填 |
|------|--------|
| A03 | ✅ 已完成，見上方（含新發現的 nBatch 溢位崩潰，需優先處理） |
| B01 | ✅ 已完成，見上方判定表 |
| B02 | ✅ 已完成 2026-07-16，見上方 task-B02 章節；（可選）org 通知訊息送出日仍待補 |

---

## 提交記錄

| 日期 | 提交 | 內容 |
|------|------|------|
| 2026-07-08 | `704f9f1` | docs(workflow): 開循環（exploration + plan） |
| 2026-07-08 | `98a5985` | benchmark prompt set + B01/A03 runbook + B02 drafts |
| 2026-07-09 | (本次) | 回填官方 model card 事實（base/gated/sampling/template）到 4 份文件 |
