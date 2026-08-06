# 04 — 加入四個角色資產與遊戲回饋

**What to build:** 玩家在準決賽、決賽與結果頁看到四個一致且容易辨識的 Q 版食物角色，以及清楚但不拖慢節奏的選擇、晉級與冠軍回饋，使完整離線流程具備可展示的遊戲感。

**Blocked by:** 02 — 完成辯護與離線備援結果.

**Status:** completed

- [x] 產出北部粽、南部粽、香菜加爆、香菜退散四張 1024 × 1024 透明背景 PNG；完整角色入鏡且圖片內不含文字。
- [x] 四張圖共用相同 Q 版畫風、線條、光影、視角、比例與透明留白，只依 Spec 改變食物、表情、配色與姿勢個性。
- [x] 同一角色資產會重用於準決賽、決賽及結果頁，不引入多姿勢版本或生成完整卡面背景。
- [x] App 正確宣告並載入資產；遺漏或錯誤資產路徑會被測試發現，而不是在執行期留下空白角色。
- [x] 選擇勝方時呈現約 800 ms 的放大、跳動與光暈回饋；動畫期間輸入維持鎖定，結束後才轉場。
- [x] 決賽與結果頁使用原生 UI 呈現對戰狀態、派系名稱與適量彩帶／冠軍效果，所有必要文字皆不烘焙在圖片中。
- [x] 視覺回歸或 Widget 測試驗證四個角色對應正確，並保留一條可完整展示的 Home 到備援結果流程。

## Comments

- Added four reusable 1024×1024 RGBA character assets with consistent centered alpha bounds, plus native final/result celebration UI and 800 ms winner feedback.
- Verification: feature analysis reported no issues; all 24 food-game tests and the full 302-test Flutter suite passed. Repository-wide analysis still reports 257 pre-existing informational lints outside this ticket's feature scope.
- Code review against `a1facee`: Standards and Spec both passed with no remaining findings.
