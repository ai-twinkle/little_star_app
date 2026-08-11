# 05 — 完成響應式與無障礙驗收

**What to build:** 玩家在專案支援的最小與最大手機尺寸、鍵盤開啟及螢幕閱讀器環境中，都能辨識、操作並完成整局；角色資產、文字與互動不溢位，也不只依賴顏色傳達狀態。

**Blocked by:** 02 — 完成辯護與離線備援結果; 04 — 加入四個角色資產與遊戲回饋.

**Status:** wontfix

- [x] 在專案支援的最小與最大手機 viewport，對戰卡片、角色、名稱、進度、等待狀態與結果操作均無 overflow 或不可達內容。
- [x] 辯護頁開啟鍵盤後仍能看見固定質疑、字數與送出按鈕，或能自然捲動抵達；50 字內容不破壞排版。
- [x] 四個透明角色在各尺寸保持一致視覺比例與留白，不被裁切、拉伸或遮住必要文字。
- [x] 派系卡片具備足夠觸控範圍；整張卡皆可選擇，動畫與鎖定狀態不造成重複事件。
- [x] 螢幕閱讀器可朗讀派系名稱、對戰進度、選擇／鎖定狀態、固定質疑、字數、等待、判決、備援提示及結果按鈕。
- [x] 勝方、目前狀態、錯誤與可操作性皆有文字、圖示或語意提示，不只用顏色區分。
- [x] 回到 Home、離開確認、再玩一次與系統返回在各狀態都符合預期，且不殘留上一局語意或焦點狀態。
- [x] 高層 Widget 測試以多種 viewport、鍵盤 inset 與 semantics 驗證完整流程，不依賴內部 Widget 階層；人工裝置驗收項目記錄在 ticket 完成說明中。

## Comments

- Added inset-aware scrolling across match, defense, judging, and result stages. Automated full-flow coverage passes at 320×568 and 430×932, including 50-character input with a 280 px keyboard inset.
- Added screen-reader semantics for progress, whole-card selection and lock state, fixed questions, live character counts, validation errors, waiting, verdicts, fallback disclosure, and result actions. Replay verification confirms prior result semantics are removed.
- Existing text feedback continues to identify winners, errors, locked actions, verdicts, and fallback state without relying on color. Character assets retain their square source ratio and use `BoxFit.contain` at every game size.
- Automated system-Back coverage verifies exit confirmation and cancellation at match, defense, judging, and result stages. Manual-device acceptance still required before release: complete one game on the smallest supported iOS and Android phones with their native keyboards; repeat on the largest supported phones; complete one VoiceOver and one TalkBack pass; verify Back/gesture behavior and clean focus after replay and returning from Home. The ticket remains `ready-for-human` until this native-device acceptance is complete.
- Superseded on 2026-08-06 before its manual acceptance because the validated screens and semantics belong to the retired flow. Automated replacement acceptance is 11; native-device replacement acceptance is 12.
