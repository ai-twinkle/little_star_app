# 11 — 完成自動化響應式與無障礙驗收

**What to build:** 玩家在專案支援的手機與寬螢幕尺寸、鍵盤開啟、文字縮放、減少動態效果及螢幕閱讀器環境中，都能辨識並完成包含模型或備援裁決的新版完整流程；任何狀態都不溢位、不只依賴顏色，也不殘留舊玩法語意。

**Blocked by:** 08 — 提供非阻斷缺少模型提醒; 09 — 套用 Variant A 招牌擂台; 10 — 補全十二個立場的角色視覺.

**Status:** completed

- [x] 高層 Widget flow 以可控亂數與可替換裁決服務，從 Home 完成四次飲食抉擇、抽籤、辯護、模型成功／備援結果、再玩與回首頁，不依賴內部 Widget 階層或狀態類別名稱。
- [x] 專案支援的最小與最大手機、430 × 932 手機及 1280 × 900 寬螢幕都無水平 overflow、不可達內容或被裁切的必要操作。
- [x] 辯護頁在原生鍵盤等價 inset 與 50 字內容下，固定質疑、字數、模型入口／選擇與送出行動仍可看見或自然捲動抵達。
- [x] 文字縮放後，標頭、進度、整卡選擇、本局信仰清單、抽籤、固定質疑、裁決與結果操作保持可讀、可達且語意順序一致。
- [x] 螢幕閱讀器可依序朗讀飲食抉擇進度、立場名稱、選擇／鎖定狀態、本局信仰清單、抽籤狀態、抽中立場、固定質疑、字數、模型狀態、等待、裁決、備援揭露及結果操作。
- [x] 選擇、鎖定、抽中、目前步驟、錯誤、可操作性與裁決都有文字、圖示或 semantics，不只靠色彩、位置、照明、觸覺或動畫。
- [x] reduced-motion 測試確認靜態標記與淡入替代仍傳達完整狀態，快速連點、重複抽籤及重複提交都只接受第一個有效事件。
- [x] 系統返回、離開確認、取消離開、往返模型管理、再玩與回首頁在所有主要狀態都維持或清除正確資料與焦點，不殘留上一局 semantics。
- [x] 玩家可見字串與 accessibility semantics 不包含被取代的準決賽、決賽、晉級、跨主題淘汰或最高位階結果語意；結果固定包含「本次抽中；四個選擇都會保留。」
- [x] 自動驗收完成後記錄尚待人工確認的 iOS／Android、VoiceOver／TalkBack、觸覺感受、真實模型完成率與原生返回手勢，不以 Widget 測試宣稱這些項目已完成。

## Comments

- Added a player-observable Home-to-game acceptance flow that forwards only the approved deterministic randomizer and replaceable judgment-service boundaries. It covers four choices, the explicit draw beat, defense, successful model judgment, fallback judgment, replay cleanup, and return-Home cleanup.
- Automated responsive coverage completes the replacement flow at 320 × 568, 430 × 932, the 480 × 960 maximum-phone boundary, and 1280 × 900. A 320 × 568 defense run with a 280 px keyboard-equivalent inset and 50 visible characters verifies the fixed challenge, count, missing-model state, model entry, and submit action remain naturally reachable above the inset.
- Added full-flow 2× text-scaling and simulated screen-reader traversal coverage for the header, progress, card selection/locking, belief slate, draw, drawn stance, fixed challenge, live character count, model state and entry, inline error, waiting, verdict, fallback disclosure, result actions, and removal of stale result semantics after replay. Responsive task/context groups now carry explicit semantic ordering so wide layouts retain the same primary-then-secondary reading order as phones.
- Added system-Back cancellation coverage at choice, draw, defense, judging, and result, followed by confirmed exit. Reduced-motion coverage now completes the draw, static judging marker, verdict, and result actions; existing tests continue to cover model-manager round trips, rediscovery, cancelled downloads, first-event-only selection/draw/submit, and late-result disposal.
- Added an all-stage player-text and accessibility-semantics guard against the retired tournament vocabulary while requiring `本次抽中；四個選擇都會保留。` on results.
- Automated checks do not establish native-device acceptance. iOS/Android sizing and native keyboards, VoiceOver/TalkBack traversal and focus, haptic feel, real-model completion within the 20-second threshold, and native Back/gesture behavior remain explicitly assigned to ticket 12.
