# 16 — 修正深色擂台中 overlay 控制項的可讀性

**What to build:** 玩家在辯護頁展開「裁決模型」下拉選單時，所有選項都必須清楚可讀；深色 arena theme 必須涵蓋在 `Overlay` 中開啟的 popup/menu 表面，而不只是頁面內的元件。

**Blocked by:** 13 — 修正實機遊戲文字尺寸與對比.

**Status:** ready-for-agent

- [x] 裁決模型下拉展開時，未選取與已選取項目的文字對比皆達一般文字 4.5:1；不得出現奶白字配近白底。
- [x] 修正方式為讓 popup/menu 表面取得與頁面一致的深色主題（或同等可靠的收斂做法），不得只對 `DropdownMenuItem` 逐一指定顏色。
- [x] 同一頁面若有其他在 `Overlay` 開啟的表面（dialog、menu、tooltip、`SnackBar`），一併確認不繼承錯誤的前景／背景組合。
- [x] 自動測試以玩家可觀察的渲染結果驗證下拉展開後的選項文字顏色與背景對比，不依賴私有 Widget 名稱或階層。
- [ ] 在 Pixel 8a（Android 16）與 iPhone 17 Pro（iOS 26.5.2）各確認一次展開後的實際可讀性。

## Comments

- 2026-08-11 由 ticket 12 的 Android 實機驗證發現。ticket 13 已把深色 arena theme 提升到 `Scaffold`／`Material` 邊界之上，頁面內文字全部修好，但 `DropdownButtonFormField` 展開的選單是在 `Overlay` 中建立自己的 `Material`，不在該 theme 底下，因此選項沿用全域亮色主題的表面色，配上 arena 的奶白文字色，未選取項目幾乎看不見。已選取項目因為有灰色 highlight 背景而勉強可讀。
- 根因與 ticket 13 相同（theme boundary 沒有涵蓋到所有建立預設文字樣式的位置），只是發生在 overlay 而非頁面樹，所以 ticket 13 的既有測試沒有攔截到。
- 這是玩家在送出辯護前唯一能切換模型的入口，看不清選項等於實質上無法選擇。
- 2026-08-11 implementation 完成：arena theme 改為由深色 `ColorScheme` 建構全新的 `ThemeData`，而不是 `copyWith` 亮色主題。原本 `copyWith` 保留了 Material 自行推導的 `canvasColor`（下拉選單表面即由它繪製）與 card／dialog 表面，故 overlay 內的選單維持近白底（#FEF7FF）配奶白字（#FFF3DB），實測對比 1.05:1。
- 2026-08-11 code review 追加：本頁在 `Overlay` 開啟的表面只有裁決模型選單與兩個 `AlertDialog`（無 tooltip／`SnackBar`）。兩個 dialog 原本以 `State` 的 context 呼叫 `showDialog`，而該 context 位於 arena `Theme` 之上，因此整個 dialog 沿用 app 亮色主題——雖然自身前景／背景一致而可讀，但與深色擂台不符，且使既有 dialog 測試無法攔截回歸。已收斂為單一 `_showArenaDialog` seam 重新套用 arena theme。
- 2026-08-11 測試：新增 `food_religion_overlay_readability_test.dart`，從實際算繪的畫面取像素，surface 取自字框旁而非以出現頻率猜測，驗證展開後的未選取／已選取選項與兩個 dialog 的文字皆落在深色 arena 表面上且對比 ≥ 4.5:1。移除 lib 變更後三個測試皆為紅。`contrastRatio` 已抽到 `food_religion_test_support.dart` 供兩個 readability 測試共用。397 個測試全數通過。待在 Pixel 8a 與 iPhone 17 Pro 各確認一次實機可讀性。
- 2026-08-11 Pixel 8a（Android 16, API 36）release build 實機驗證通過。裝置上有 5 個 GGUF 模型，下拉展開後五個選項皆為奶白字（#FFF3DB）配深色面板：未選取項 #122329 對比 14.71:1，已選取項 highlight #2F3E43 對比 10.10:1，皆遠高於 4.5:1（修正前為 1.05:1）。離開確認 dialog 亦為深色 arena 樣式，內文對比 13.52:1。
- 2026-08-11 實機發現並修正一個由本次 theme 變更引入的版面回歸：dialog 繼承了頁面主要操作的 `Size.fromHeight(52)`（寬度無限），導致 `AlertDialog` 的 action bar overflow、兩顆按鈕上下錯位堆疊。已在 `_showArenaDialog` 內把 dialog 的 `FilledButton` 最小尺寸改回依標籤大小，重新 build 後按鈕恢復並排。
- iOS 端待辦：iPhone 17 Pro 目前未連線（只找得到無線通道且失敗），該半驗收尚未執行。
