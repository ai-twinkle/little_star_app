# 01 — 建立固定淘汰賽與 Home 入口

**What to build:** 玩家能從 Home 的「台灣食物宗教戰爭」卡片直接進入獨立遊戲，依序完成兩場準決賽與決賽，最後看到唯一冠軍及該信仰的固定終極質疑。這一 slice 建立可測試的單一 Session、內容目錄與遊戲導覽邊界，但不接入辯護裁決。

**Blocked by:** None — can start immediately.

**Status:** wontfix

- [x] Home 顯示遊戲卡片，點擊後直接呈現北部粽派對南部粽派，不出現教學或模型狀態頁。
- [x] 固定順序為粽子準決賽、香菜準決賽、兩名勝方決賽；每場結果正確傳入下一場。
- [x] 每場只接受第一個有效點擊，選定後兩張卡片立即鎖定，約 800 ms 的勝方回饋結束後才前進。
- [x] 四種可能冠軍都會顯示正確派系名稱與固定終極質疑。
- [x] 系統只能依合法順序轉移，不能回到上一場、跳關或在同一場產生兩名勝方。
- [x] 遊戲中的返回動作會詢問「確定離開本局？」；取消後留在原狀態，確認後清除 Session 並回 Home。
- [x] 遊戲流程與內容位於獨立 Feature 邊界，狀態不滲入 Home，並遵守既有架構依賴規則。
- [x] 以玩家可觀察的高層 Widget 測試覆蓋 Home 入口、快速連點、三場晉級、四種冠軍與離開確認，不依賴內部 Widget 階層或狀態類別名稱。

## Comments

- Implemented with a single in-memory Session and player-observable Widget flow tests.
- Verification: targeted analyze reported no issues; the full Flutter suite passed 277 tests.
- Code review against `df001d8`: Standards had no hard violations; Spec had no remaining findings.
- Superseded on 2026-08-06 by the v2 independent-choice and defense-draw specification. Historical implementation and verification are retained here; the actionable replacement is 06 — 以四次飲食抉擇完成備援流程.
