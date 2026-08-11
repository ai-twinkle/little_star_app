# 16 — 修正深色擂台中 overlay 控制項的可讀性

**What to build:** 玩家在辯護頁展開「裁決模型」下拉選單時，所有選項都必須清楚可讀；深色 arena theme 必須涵蓋在 `Overlay` 中開啟的 popup/menu 表面，而不只是頁面內的元件。

**Blocked by:** 13 — 修正實機遊戲文字尺寸與對比.

**Status:** ready-for-agent

- [ ] 裁決模型下拉展開時，未選取與已選取項目的文字對比皆達一般文字 4.5:1；不得出現奶白字配近白底。
- [ ] 修正方式為讓 popup/menu 表面取得與頁面一致的深色主題（或同等可靠的收斂做法），不得只對 `DropdownMenuItem` 逐一指定顏色。
- [ ] 同一頁面若有其他在 `Overlay` 開啟的表面（dialog、menu、tooltip、`SnackBar`），一併確認不繼承錯誤的前景／背景組合。
- [ ] 自動測試以玩家可觀察的渲染結果驗證下拉展開後的選項文字顏色與背景對比，不依賴私有 Widget 名稱或階層。
- [ ] 在 Pixel 8a（Android 16）與 iPhone 17 Pro（iOS 26.5.2）各確認一次展開後的實際可讀性。

## Comments

- 2026-08-11 由 ticket 12 的 Android 實機驗證發現。ticket 13 已把深色 arena theme 提升到 `Scaffold`／`Material` 邊界之上，頁面內文字全部修好，但 `DropdownButtonFormField` 展開的選單是在 `Overlay` 中建立自己的 `Material`，不在該 theme 底下，因此選項沿用全域亮色主題的表面色，配上 arena 的奶白文字色，未選取項目幾乎看不見。已選取項目因為有灰色 highlight 背景而勉強可讀。
- 根因與 ticket 13 相同（theme boundary 沒有涵蓋到所有建立預設文字樣式的位置），只是發生在 overlay 而非頁面樹，所以 ticket 13 的既有測試沒有攔截到。
- 這是玩家在送出辯護前唯一能切換模型的入口，看不清選項等於實質上無法選擇。
