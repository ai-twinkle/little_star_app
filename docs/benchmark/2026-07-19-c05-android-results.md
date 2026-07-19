# task-C05 — Pixel 8a (Android) 完整矩陣結果（2026-07-19）

> 循環：[2026-07-08-t1-benchmark-talk](../../.dev/cycles/2026-07-08-t1-benchmark-talk/)
> 執行方式：`integration_test/c05_matrix_test.dart`（`C05 Android GGUF *` 系列 testWidgets），
> `kBenchmarkDefaultSettings`（temp 0.6 / topP 0.95 / maxTokens 512）。
> 只有 GGUF/llama.cpp backend（MLX 僅 Apple 平台）。
> 樣本數縮減：**1 次 session-cold + 2 次 session-warm**（非 iPhone 側的 3+9），
> 原因見下方「執行障礙」——Android 單次生成耗時遠超預期，全套 3+9 協定不可行。

## 摘要數據

| Tier | promptTokens | cold TTFT | cold decode tps | cold prefill tps | warm TTFT（2 樣本） | warm decode tps（2 樣本） | peak memory |
|------|------|------|------|------|------|------|------|
| L128 | 64 | 5942ms | 2.88 | 10.83 | 8554/13046ms | 1.94 / 1.52 | ~3.47–3.71 GB |
| L512 | 223 | 21918ms | 2.84 | 10.19 | 31941/29827ms | 3.62 / 1.47 | ~3.53–3.94 GB |
| L1024 | 343 | 45013ms | 2.47 | 7.63 | 50859/48250ms | 1.19 / 1.26 | ~3.76–3.94 GB |
| L2048 | 464 | 64654ms | 1.17 | 7.18 | 63692/66889ms | 1.83 / 1.38 | ~3.98 GB |

thermalState 全程停在 `fair`（從未到 `serious`，跟 iPhone 側連續劣化到 `serious` 不同——見下方
「與 iPhone 對比」）。battery 從 9%（L128 開始）漲到 31%（L2048 結束），裝置全程 AC 充電中，
純量測角度不是問題,但代表這批數據是在「低電量+充電中」狀態下量到的,非乾淨起跑點。

## 與 iPhone 17 Pro 對比（同一份 96 筆 iPhone 資料，見
[2026-07-19-c05-iphone-results.md](2026-07-19-c05-iphone-results.md)）

- **decode tokens/s 慢一個數量級**：iPhone GGUF 約 14–24 tok/s，Pixel 8a 約 1.2–3.6 tok/s。
- **prefill tokens/s 慢兩到三個數量級，且是 TTFT 隨 prompt 長度線性暴增的主因**：iPhone GGUF
  prefill 約幾百到數萬 tok/s（批次 prefill 很快），Pixel 8a 只有 **7–11 tok/s**——這代表
  Android 側的 prefill 沒有像 iPhone 一樣吃到高效的批次/SIMD 路徑,直接導致 TTFT 從 L128
  的 6 秒暴增到 L2048 的 65 秒（幾乎跟 prompt token 數成正比）。呼應 task-A02 當時的觀察
  「生成速度偏慢、CPU 只用到 ~33%」——這次矩陣數據量化坐實了這個疑點,原因待查（懷疑
  `nThreads=8` 沒有真正有效並行,或 llama.cpp Android build 沒開對 SIMD/NEON 優化路徑）。
- **thermalState 行為不同**：iPhone 連續跑 8 個組合後從 `fair` 升到 `serious` 且回不去；
  Android 全程停在 `fair`,即使跑了 4 個組合、總計約 40 分鐘高強度運算。可能是 Android 運算
  量本身遠低於 iPhone（tok/s 慢一個數量級，單位時間發熱量也低),也可能是兩邊 thermalState
  api 的分級標準本來就不同,不能直接類比嚴重程度。
- **peak memory 量級相近**：iPhone ~3.65–3.9GB、Android ~3.47–3.98GB,同一顆模型、同樣
  `nCtx=4096`,符合預期。

## 執行障礙（記錄供下次上機測試參考，這次花了不少時間排除）

1. **`MANAGE_EXTERNAL_STORAGE` 權限在每次 app 重裝後會被重置**：Android 端模型檔案放在
   `/storage/emulated/0/Download/LittleStar/models/`（共用外部儲存,不隨 app 重裝清空),但
   app 讀取它需要的 `MANAGE_EXTERNAL_STORAGE` appops 授權**是綁在特定 app 安裝實例上的**，
   `flutter test integration_test/...` 每次呼叫都會重新安裝 app（觸發原因之一：debug 與
   release 簽章不同,安裝時會強制先解除安裝再裝,清空所有 appops 授權）。修法：每次呼叫
   `flutter test` 前都先 `flutter install --debug`（確保跟 `flutter test` 用同一簽章)+
   `adb shell appops set <pkg> MANAGE_EXTERNAL_STORAGE allow`。
2. **debug build 彈出「Android 應用程式相容性」16KB 分頁對齊警告**：vendored 的
   `libllama.so`/`libggml*.so` 等原生函式庫沒有對齊到 16KB（Android 未來的頁面大小要求),
   這個對話框只在 debuggable build 出現（「因為這個可偵錯應用程式正在測試中」),**不影響
   正式 release build**,但會蓋住畫面阻擋自動化測試,需要手動點「不要再顯示」關掉。技術債
   記錄：未來若要跟上 Android 16KB 頁面要求,需要重新編譯 vendored llama.cpp 函式庫時加上
   對齊旗標,非本輪範圍。
3. **間歇性 ANR 導致 app 被系統關閉**：`adb logcat` 找到明確原因——
   `Input dispatching timed out ... Waited 5002ms for FocusEvent(hasFocus=true)`,在
   `flutter test` 自動重裝+啟動 app 的流程中,app 視窗有時無法在 5 秒內確認取得焦點,
   Android 判定 ANR 並砍掉 app 行程。**發生機率約 30–50%**,重跑通常能過（4 個 tier 中，
   L128/L2048 一次就過，L512 跑了 4 次才過，L1024 跑了 3 次才過）。根因未完全查明——曾
   懷疑跟第 2 點的相容性對話框有關,但也有一次失敗發生時螢幕上並沒有任何對話框,單純回到
   launcher,所以不是唯一成因。**這不只是 benchmark harness 的困擾,如果正式 app 在低階
   Android 裝置上也有類似的啟動期 ANR 風險,值得另開任務調查**（本輪未深入，只做到能穩定
   重跑取得資料的程度）。
4. **樣本數被迫縮減**：原訂每個 tier 3 次獨立 cold + 9 次 warm（比照 iPhone 側),但 Android
   單次生成動輒 30 秒到超過 1 分鐘（L2048 甚至接近 70 秒才出第一個 token),3+9=12 次生成
   單一 tier 可能要跑 20-30 分鐘以上,不可行,改成 1 次 cold + 2 次 warm。**這代表 Android
   側的統計把握度遠低於 iPhone 側**,數字僅供方向性參考,不建議直接用於正式對比圖表的精確
   數值。

## 建議

- Android 側 prefill 速度異常慢（7-11 tok/s）是本次最值得深入的技術疑點,建議另開任務用
  Android Studio profiler 或 `adb shell top`/`dumpsys cpuinfo` 在生成過程中即時觀察各核心
  使用率,確認是否真的是 nThreads 沒吃滿,或是其他瓶頸（記憶體頻寬、mmap I/O 等)。
- 正式 D 線圖表如果要放 Android 數據,務必**明確標註樣本數遠少於 iPhone 側**（1+2 vs 3+9),
  且註明是在低電量+持續充電狀態下量測,而非乾淨基準。
- ANR 問題如果之後要再上機測試,建議跑測試期間全程盯著螢幕（如本次後半段做法),遇到 ANR
  對話框或相容性警告立即人工處理,比純自動化重試更省時間。
