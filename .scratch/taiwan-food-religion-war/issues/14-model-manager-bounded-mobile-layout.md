# 14 — 修正模型管理手機版無界限捲動佈局

**What to build:** 玩家從「台灣食物宗教戰爭」前往推薦模型區時，模型管理頁能在實體手機的有限高度內正常載入、捲動與返回，不觸發 viewport／RenderBox layout exception，也不破壞遊戲進度。

**Blocked by:** 08 — 提供非阻斷缺少模型提醒.

**Status:** completed

- [x] 從遊戲辯護頁前往推薦模型區時，不再出現 `Vertical viewport was given unbounded height` 或後續 `RenderBox was not laid out` 錯誤。
- [x] 模型清單的捲動區在手機高度下取得明確 constraints；不得以巢狀無界限 viewport 修補。
- [x] 模型搜尋／載入完成前後都能看見並操作必要內容，且可正常返回原遊戲。
- [x] 返回後保留飲食抉擇、抽中立場與已輸入辯護，並重新發現可用模型。
- [x] 高層 Widget flow 覆蓋從遊戲前往模型管理再返回的玩家可觀察流程，並確認沒有 layout exception；另在 iPhone 17 Pro（iOS 26.5.2）重驗。

## Comments

- 2026-08-07 Ticket 12 iPhone 17 Pro 實機驗收中，進入模型管理後日誌首先回報 `Vertical viewport was given unbounded height`，隨後連鎖出現多個 `RenderBox was not laid out`。這是原生裝置上的真實 layout failure，不是模型推論錯誤。
- 2026-08-07 已以 390 × 844 高層 Widget flow 覆蓋從辯護頁進入真實模型管理畫面、搜尋載入前後、完整清單捲動、AppBar 返回、遊戲狀態與辯護輸入保留，以及模型重新發現；完整 367 項測試通過。仍需在 iPhone 17 Pro（iOS 26.5.2）重驗後勾選最後一項。
- 2026-08-11 iPhone 17 Pro（iOS 26.5.2）release build 重驗通過：從辯護頁進入推薦模型區、搜尋、捲動完整清單、返回後遊戲狀態與辯護輸入保留，未再出現 layout exception。同時修正了 ticket 14 留下的 eager build —— `ModelSearchList` 改為 sliver，搜尋結果恢復 lazy building（commit `00b47ce`）。
