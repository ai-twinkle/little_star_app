# 12 — 完成原生裝置人工驗收

**What to build:** 在實際 iOS 與 Android 裝置上確認新版「台灣食物宗教戰爭」可用原生鍵盤、輔助技術、觸覺與返回手勢完整操作，並以真實端側模型確認可接受的完成率；此票只做 release acceptance，不新增或擴張產品功能。

**Blocked by:** 11 — 完成自動化響應式與無障礙驗收; 13 — 修正實機遊戲文字尺寸與對比; 14 — 修正模型管理手機版無界限捲動佈局.

**Status:** ready-for-human

- [ ] 在最小（iPhone 15）與最大支援 iOS 手機各完成一局，涵蓋原生鍵盤、50 字輸入、離開確認、再玩、回首頁及往返模型管理。
- [ ] 在最小（Google Pixel 8 或同等硬體）與最大支援 Android 手機各完成一局，涵蓋原生鍵盤、系統 Back／返回手勢、離開確認、再玩、回首頁及往返模型管理。
- [x] 在支援裝置確認選擇與抽籤的輕觸覺適量、reduced motion 生效且遊戲沒有音效或造成不必要干擾。
- [x] 使用至少一個真實已安裝模型完成裁決並記錄 20 秒門檻內的結果；另驗證沒有模型或模型失敗時能透明完成備援路徑。
- [x] 記錄所有裝置、OS、模型、結果與剩餘缺陷；只有沒有阻斷問題且所有必要修正另行追蹤後，才可將本功能視為通過 release acceptance。

## Comments

- 2026-08-07 部分實機驗收：iPhone 17 Pro（iPhone18,1），iOS 26.5.2。App 成功建置、安裝與啟動，未觀察到 crash；本次 App 啟動日誌最初發現 0 個本機模型。
- 飲食抉擇、抽籤與辯護畫面發現阻斷性可讀性缺陷：多處必要文字過小，且選項名稱、固定質疑與字數以近黑色顯示在深色背景；信仰清單則為奶白字配近白底。實機截圖像素量測對比分別只有 1.16:1、1.08:1、1.07:1。另行追蹤於 Ticket 13，本票不得標記通過，修正後必須在同一裝置重驗。
- 本輪尚未完成原生鍵盤 50 字、離開確認、再玩、回首頁、完整模型管理往返、VoiceOver、reduced motion 與觸覺感受；畫面可讀性阻斷後續可靠驗收。模型管理頁另觸發 `Vertical viewport was given unbounded height` 與後續 RenderBox layout errors，追蹤於 Ticket 14。
- 真實 GGUF `twinkle-ai-gemma-3-4b-t1-it-q4_k_m.gguf` 已在裝置完成一次生成：從 backend session 建立／模型載入開始至 generation end 約 7.4 秒（純生成約 4.6 秒），低於 20 秒門檻；仍需在可讀性修正後由人確認完整裁決確實顯示且內容可接受。
- iPhone SE（第 3 代，iPhone14,6）可被開發工具辨識但目前 unavailable；尚無 Android 實機。最小／最大 iOS 與 Android 裝置矩陣仍未完成。
- 2026-08-11 Wave A 修正後於 iPhone 17 Pro（iOS 26.5.2）以 release build 重驗，新行為全部正常：模型自己生成的吐槽通過驗證並顯示、挺立場但字面帶否定詞的辯護不再誤判、字數與 50 字上限一致、選擇／抽籤／結果三處觸覺正常且開啟「減少動態效果」後全部靜音、模型管理往返無 layout exception 且遊戲狀態保留。
- 真實已安裝模型完成裁決，體感在 20 秒門檻內（先前量測為約 7.4 秒）。備援行為確認為退回 rule-based 裁決並顯示「AI 主持人暫時離線」揭露，使用者確認此行為可接受。
- **支援裝置基準（2026-08-11 決定）**：iOS 目標為 iPhone 15 以上；Android 目標為 Google Pixel 8 以上或同等硬體規格。裝置矩陣的最小機型與 Android 實機尚未驗證。
- VoiceOver 與 TalkBack 驗證由使用者決定暫時 pending，尚未執行。
- 2026-08-11 VoiceOver 與 TalkBack 兩項移出本票，改由 `15-assistive-technology-acceptance.md` 追蹤，本票只保留裝置矩陣與紀錄。
- 2026-08-11 Android 實機驗證（Pixel 8a，Android 16 API 36，release APK 124.7 MB），以 adb 驅動 UI 逐項確認：
  - 缺少模型提醒正確顯示且「先玩再說」為主要動作；四次飲食抉擇、抽籤節拍（先顯示信仰清單再由玩家觸發）、抽中標記、備援裁決與揭露全部正常。
  - Ticket 13 的可讀性修正在 Android 同樣生效：深底白字、大字級、`Chip` 不再是奶白配白底。
  - 字數：50 個字元加尾端空白顯示「50 / 50」且可送出，中文辯護「不支持香菜的人才奇怪」顯示「10 / 50」—— finding 5 的修正在實機成立。
  - 系統 Back 與左緣返回手勢都被攔截為「確定離開本局？」，Android 16 的預測式返回沒有直接退出遊戲。
  - 模型管理往返：從辯護頁進入、捲動完整 Hugging Face 搜尋結果、返回後抽中立場與已輸入辯護都保留；logcat 對 `unbounded height` 與 `RenderBox was not laid out` 的比對為 0 次。Ticket 14 的 Android 側因此也通過。
  - **未完成**：真實模型裁決需要「所有檔案的存取權」，該權限決定留給使用者，因此模型生成吐槽、倒向判定與 20 秒門檻在 Android 上尚未驗證。觸覺強度與 reduced motion 靜音需人親自感受，無法以 adb 判定。
- 2026-08-11 Android 模型裁決驗證（Pixel 8a／Android 16／release APK，模型放在 `/storage/emulated/0/Download/LittleStar/models`）：
  - 前置：模型探索需要「所有檔案的存取權」。未授權時 App 仍能在 Downloads 建立自己的檔案（scoped storage），卻讀不到別的程序放進去的模型，因此下載成功、掃描為空。授權後 5 顆 GGUF 全部被發現。**這不是 App 的缺陷，但值得在說明或 UI 上提示。**
  - 模型選單：GGUF 優先、不分大小寫字典序，切換與送出鎖定都正確；送出後輸入與按鈕確實鎖定並顯示「AI 鄉民評審正在審判…」。
  - Prompt 內容經 logcat 驗證正確：抽中立場、該立場固定質疑、trim 後的玩家辯護、三級裁決規則與安全護欄都在，且辯護不含前後空白（finding 5 的修正在真機生效）。
  - **逾時路徑在真機完整驗到**：`generateStream` 10:41:27.223 開始 → `cancel()` 10:41:47.237（20.014 秒）→ `dispose()` → `Context freed` → `Model freed`。取消與 native 資源釋放都正確。
- 2026-08-11 **Android 阻斷性發現：20 秒預算在 Pixel 8a 上跑不完。**
  - `gemma-3-1b-it-Q4_K_M`（367 prompt tokens、`maxTokens: 128`）在 20 秒內未產出，每次都逾時退到備援。iPhone 17 Pro 的對照是約 7.4 秒。
  - `gemma-3-270m-it-Q4_K_M` 約 3 秒完成，但輸出未通過驗證，同樣退到備援。
  - 結論：目前 Pixel 8a 上**沒有任何一顆可用模型能既在時限內完成、又產出合法裁決**，Android 的模型裁決實際上總是備援。可考慮的槓桿（尚未決定）：把 `maxTokens` 從 128 降到符合「一句 30 字吐槽 + verdict」的實際需求、依平台調整 20 秒門檻、或為 Android 指定建議模型。
- 2026-08-11 其他 Android 觀察：
  - 逾時取消後 `LlamaCppFFI` 記錄 `Error generating stream: Null check operator used on a null value`。結果不受影響（第一個終態已定），但這是 teardown 的競態，會在正常逾時流程留下 error 級日誌。
  - 裁決模型下拉選單展開時，未選取項目是奶白字配近白底、幾乎看不見（證據：本次驗證截圖）。這與 ticket 13 是同一類缺陷，但發生在 popup overlay，深色 arena theme 沒有涵蓋到。
  - 一次以 `gemma-3-4b-t1-it-q4_k_m` 送出的嘗試在約 3 秒內退到備援，且 logcat 完全沒有任何推論日誌（連 llama.cpp library 載入都沒有），與 1b／270m 的行為不同。原因未查明，需要在服務層加上失敗分類的日誌才能診斷。
  - 診斷缺口：服務從不記錄模型的原始輸出，因此在真機上無法分辨備援是 parse、缺欄位、非法裁決還是 roast 驗證失敗造成的。
- 2026-08-11 `maxTokens` 128 → 80（一個 verdict 加一句 30 字吐槽的實際需求）後在 Pixel 8a 重測：
  - `gemma-3-1b-it-Q4_K_M`：一次 17.1 秒完成（未逾時），一次 20.1 秒逾時。**卡在 20 秒門檻邊緣**，不是穩定通過。
  - 服務新增失敗分類的 debug 日誌後，取得第一筆真機證據（`gemma-3-270m-it-Q4_K_M`，6.1 秒完成）：
    `rejected: parse | raw=好的，我為你準備了符合安全護欄要求的 JSON 格式…` ```json { "verdict": "信仰堅定|勉強護教|叛教邊緣", "roast": "一句吐槽" } ``` **說明:** …
  - 兩個問題同時存在：模型把 JSON 包在前言與 Markdown code fence 裡（服務對整段做嚴格 `jsonDecode`，必定 parse 失敗），而且 270m 直接照抄 prompt 的樣板佔位字串而非真的裁決。
  - 因此 Android 的備援不是單一原因：1b 是速度卡邊緣，270m 是輸出品質不足且被嚴格解析擋下。**尚待決定**：是否加入寬鬆的 JSON 擷取（從輸出中取出第一個完整 JSON object，忽略前後說明與 code fence）。這超出 Wave A 範圍，但會直接決定 Android 上模型裁決的命中率。
- 2026-08-11 逾時門檻 20 → 40 秒。依據首版 spec 的規定（「若目標裝置普遍超時，應以量測結果調整門檻，而不是移除備援」，`Twinkle_AI_Food_Religion_War_Spec_v1.0.md:236`）與使用者決定的目標裝置級距：Android 為非旗艦的中階機，較慢的裁決可接受。Pixel 8a 上 1B 模型量到 16.6／17.1／20.1 秒，原本的 20 秒等於隨機把真實裁決砍掉。權威版 `.scratch/taiwan-food-religion-war/spec.md` 的 :129 與 :144 已同步改為 40 秒並補上「逾時門檻」小節；tickets 03／07 的已勾選條件文字仍寫 20 秒，以 spec 的修訂為準。
- 2026-08-11 換上 40 秒後重測（Pixel 8a／gemma-3-1b）：生成 16.6 秒完成、未逾時，失敗原因單純是 `parse`。模型輸出：
  ```json {"verdict":"信仰堅定|勉強護教|叛教邊緣","roast":"豆花配糖水，香氣濃郁，卻總是被糖水撐場，豆花的單調感…"} ```
  **兩顆模型都把 prompt 中 `"verdict":"信仰堅定|勉強護教|叛教邊緣"` 這串豎線樣板整串抄成 verdict 值**，並包在 ```json code fence 裡。也就是說目前的輸出契約寫法本身在誘導小模型照抄，而不是讓它三選一。這是 prompt 設計問題，與「是否放寬解析」無關。

## 已知限制（2026-08-11 決定）

- **小模型會照抄輸出樣板。** `gemma-3-1b` 與 `gemma-3-270m` 都把 prompt 中 `"verdict":"信仰堅定|勉強護教|叛教邊緣"` 整串抄成 verdict 值，並把 JSON 包在 ```json code fence 裡，因此在 Pixel 8a 上一律以 `parse` 失敗退到備援。
- 兩個可能的解法都被明確否決，本輪不做：
  1. 寬鬆的 JSON 擷取（從輸出取出第一個完整 JSON object）—— 使用者決定不放寬解析。
  2. 改寫 prompt 的輸出契約（三個合法值改成規則列、範例放具體值）—— 使用者決定不動 prompt，因為 iOS 上模型生成吐槽已驗收正常，改動有回歸風險。
- 因此目前的狀態是：**iPhone 17 Pro 上模型裁決正常；Pixel 8a 上以現有小模型一律退到備援，但備援本身透明、遊戲可完成。** 備援退場行為是設計內的，不是缺陷。
- 逾時已不再是 Android 的限制因素（40 秒門檻下，1B 模型 16.6 秒完成）。
- 2026-08-11 使用者決定在本票未關閉的情況下先行 merge 進 `feat/v0.1-cc`。仍未完成的是裝置矩陣的覆蓋率（iOS 只驗 iPhone 17 Pro、缺 iPhone 15；Android 只驗 Pixel 8a），不是任何已知缺陷 —— 兩台代表機上的完整流程、備援、返回手勢、觸覺與模型管理往返都已通過。輔助技術驗收在 ticket 15、Android 端側裁決品質在 ticket 17、下拉選單可讀性在 ticket 16，三者都不擋 merge。

