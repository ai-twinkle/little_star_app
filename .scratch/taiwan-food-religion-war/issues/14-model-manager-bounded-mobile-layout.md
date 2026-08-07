# 14 — 修正模型管理手機版無界限捲動佈局

**What to build:** 玩家從「台灣食物宗教戰爭」前往推薦模型區時，模型管理頁能在實體手機的有限高度內正常載入、捲動與返回，不觸發 viewport／RenderBox layout exception，也不破壞遊戲進度。

**Blocked by:** 08 — 提供非阻斷缺少模型提醒.

**Status:** ready-for-agent

- [ ] 從遊戲辯護頁前往推薦模型區時，不再出現 `Vertical viewport was given unbounded height` 或後續 `RenderBox was not laid out` 錯誤。
- [ ] 模型清單的捲動區在手機高度下取得明確 constraints；不得以巢狀無界限 viewport 修補。
- [ ] 模型搜尋／載入完成前後都能看見並操作必要內容，且可正常返回原遊戲。
- [ ] 返回後保留飲食抉擇、抽中立場與已輸入辯護，並重新發現可用模型。
- [ ] 高層 Widget flow 覆蓋從遊戲前往模型管理再返回的玩家可觀察流程，並確認沒有 layout exception；另在 iPhone 17 Pro（iOS 26.5.2）重驗。

## Comments

- 2026-08-07 Ticket 12 iPhone 17 Pro 實機驗收中，進入模型管理後日誌首先回報 `Vertical viewport was given unbounded height`，隨後連鎖出現多個 `RenderBox was not laid out`。這是原生裝置上的真實 layout failure，不是模型推論錯誤。
