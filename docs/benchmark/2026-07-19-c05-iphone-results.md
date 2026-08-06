# task-C05 — iPhone 17 Pro 完整矩陣結果（2026-07-19）

> 循環：[2026-07-08-t1-benchmark-talk](../../.dev/cycles/2026-07-08-t1-benchmark-talk/)
> 執行方式：`integration_test/c05_matrix_test.dart`，`BenchmarkProtocolRunner`，
> `kBenchmarkDefaultSettings`（temp 0.6 / topP 0.95 / maxTokens 512）。
> 每個 tier×backend 組合：3 次獨立 session-cold（各自開新 session）+ 每個 session 3 次
> session-warm，共 12 筆樣本 × 8 組合 = **96 筆真實樣本**。

## ⚠️ 重要限制：本次數據受連續熱節流影響，非乾淨對照數據

8 個組合是**背靠背連續執行、組間完全沒有降溫**（時間預算限制，見下方「已知限制」）。
`thermalState` 從第一個組合（GGUF-L128）跑到約一半時就從 `fair` 升到 `serious`，
之後所有組合全程停留在 `serious`，再也沒有回到 `nominal`。這代表：

- **decode tokens/s 在每個組合內部持續下滑**（例如 GGUF-L128 從 21.56 → 14.20 tok/s，
  MLX-L128 從 28.01 → 14.68 tok/s），且**組合之間也是連續劣化**而非獨立同分佈——愈晚跑的
  組合起始溫度愈高。
- **cold-start TTFT 同樣受影響**，且與 task-C04 pilot 的發現（thermalState 相關）方向一致，
  但因為全程沒回到 nominal，這批 cold TTFT 數字**不能拿來當作「乾淨」的冷啟動基準值**。
- 兩個 backend 之間、四個 tier 之間**仍然可以互相比較**（因為都在同樣連續劣化的環境下測，
  相對排序/量級有參考價值），但**絕對數字不建議直接放進 D 線 talk 簡報**——正式素材建議
  重跑一次、組間確實降溫（等 `thermalState` 回到 `nominal`）。

## 各組合摘要（cold / warm 分開，取中位數）

| 組合 | promptTokens（GGUF 實測；MLX 恆 null，已知缺口） | cold TTFT（3 樣本中位數） | cold decode tps | warm TTFT（9 樣本中位數） | warm decode tps | peak memory |
|------|------|------|------|------|------|------|
| GGUF L128 | 64 | 551ms | 14.74 | 645ms | 15.25 | ~3.65–3.80 GB |
| GGUF L512 | 223 | 1191ms | 20.66 | 1092ms | 20.44 | ~3.84–3.86 GB |
| GGUF L1024 | 343 | 1907ms | 18.59 | 2130ms | 18.13 | ~3.85–3.87 GB |
| GGUF L2048 | 464 | 2857ms | 17.84 | 3184ms | 16.25 | ~3.85–3.87 GB |
| MLX L128 | null | 4578ms | 15.62 | 597ms | 15.12 | ~3.16–3.27 GB |
| MLX L512 | null | 4964ms | 17.30 | 1211ms | 15.98 | ~3.16–3.27 GB |
| MLX L1024 | null | 5180ms | 15.59 | 1628ms | 15.32 | ~3.16–3.27 GB |
| MLX L2048 | null | 5876ms | 17.85 | 2336ms | 16.71 | ~3.17–3.21 GB |

battery 全程 90%→90%（單次矩陣跑不到 1%，符合預期，96 個樣本總耗時約 27 分鐘）。

## 三個新發現（回寫 C02 協定 / 待辦）

1. **prompt tier 字數校準結果**：draft 內容實測 token 數（GGUF tokenizer）為
   64／223／343／464，目標是 128／512／1024／2048——**L1024/L2048 兩個 tier 的草稿明顯太短**
   （L2048 甚至沒到目標的四分之一）。待辦：加長 `lib/core/benchmark/prompt_tiers.dart` 的
   `l1024`/`l2048` 內文（`l2048` 建議多加幾輪對話），重新校準。
2. **MLX peak memory 隨 maxTokens 明顯增加**：task-C04 pilot（maxTokens=64）量到 MLX peak
   ~1.49GB；這次（maxTokens=512）量到 ~3.16–3.27GB，翻了一倍以上，GGUF 反而只有小幅增加
   （因為 GGUF 用固定 `nCtx=4096` 預先配置 KV cache，maxTokens 大小不太影響峰值；MLX 看起來
   KV cache 是動態成長，長生成會直接推高記憶體）。D 線畫記憶體對比圖時要標明是在
   maxTokens=512 下量的，跟先前 maxTokens=64 的 pilot 數字不能混用。
3. **持續背靠背生成本身就是最好的「發熱曲線」原料**：這次意外用 C05 矩陣跑出了一份完整的
   thermal throttling 曲線（fair→serious，decode tps 隨之腰斬）。C03 的正式 10 分鐘持續負載
   測試可以預期會看到類似現象，且範圍可能更明顯（本次 8 個組合分散在 4 個不同 tier/背景，
   C03 是同一個 tier 連續跑好幾倍時間）。

## 已知限制

- **組間完全沒有降溫**：受限於單一連續開發階段的時間預算，沒有在組合之間插入「等待
  thermalState 回到 nominal」的步驟（實測從 `serious` 降回 `nominal` 需要的時間未知，
  但明顯超過組合之間的執行間隔）。
- **只有 iPhone 17 Pro，沒有 Pixel 8a**：本次開發環境沒有連接 Android 裝置。
- **`flutter test integration_test/...` 每次呼叫都會重新安裝 app（新 sandbox container）**，
  所以 8 個組合各自匯出的 CSV 分散在 8 個不同、且大多已經隨舊 container 變成孤兒的路徑下，
  無法事後統一拉回——本檔的數據是從執行當下的終端機輸出人工彙整，不是直接讀 CSV 檔案彙總。
  下次如果要一次拿到單一份 CSV，建議把 8 個 combo 合併進同一個 `testWidgets` 呼叫（同一個
  `BenchmarkViewModel` 累積所有樣本），犧牲「個別 combo 可獨立重跑」換取「單一檔案輸出」。

## 建議：正式 talk 素材前重跑一次

1. 每個組合跑完後，插入等待步驟直到 Benchmark 畫面 pre-flight banner 顯示 `thermalState:
   nominal` 才開始下一組（可能需要裝置閒置數分鐘，甚至更久）。
2. 先依上方發現 1 修正 `prompt_tiers.dart` 的 L1024/L2048 內文，重新校準到目標 token 數附近。
3. 把 8 個 combo 合併進一次 `flutter test` 呼叫，一次匯出一份完整 CSV，避免資料分散在多個
   孤兒 container 裡。
