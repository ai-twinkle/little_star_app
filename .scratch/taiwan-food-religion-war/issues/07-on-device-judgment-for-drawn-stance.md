# 07 — 讓抽中立場使用端側模型裁決

**What to build:** 有已安裝模型時，玩家能在辯護抽籤後選擇本次模型，讓端側 AI 依抽中立場、固定質疑與實際辯護產生經驗證的個人化裁決 —— 包含 model 自己生成的一句安全短吐槽；任何模型不可用、無效輸出或競態情況都透明回到同一條安全備援結果，而且整局只完成一次。

**Blocked by:** 06 — 以四次飲食抉擇完成備援流程.

**Status:** completed

- [x] 辯護頁列出可發現的 GGUF 與 MLX 模型；預設維持 GGUF 優先、同類穩定排序，玩家可在送出前切換。
- [x] 模型輸入使用抽中立場、該立場固定質疑、玩家原始辯護、三級裁決規則與安全護欄，不再使用舊流程的結果角色或文案。
- [x] 十二個飲食立場都能形成正確模型上下文。
- [x] 每次辯護最多啟動一次生成；送出後模型選擇、輸入與送出行動一併鎖定。
- [x] 串流內容在服務邊界內組合並驗證後一次顯示，不顯示 Markdown、前後說明或技術資訊。
- [x] 沒有模型、所選模型消失、載入或生成失敗、20 秒逾時、解析失敗、缺欄位、非法裁決或內容驗證失敗時，產生與抽中立場相符且透明揭露的備援裁決。
- [x] 成功、逾時、失敗、取消或離開接近同時發生時只接受第一個合法終態；後續事件不得覆寫結果，推論與 native 資源會正確取消及釋放。
- [x] 模型選擇只存在目前 Session；再玩時重新發現模型並套用預設，不保留上一局選擇。
- [x] 自動測試以可替換裁決服務覆蓋模型發現、切換、三種合法裁決、十二立場上下文、所有失敗分類與終態競態，不載入真實模型或呼叫網路。

## 重開範圍（2026-08-10 code review）

Model 生成吐槽與倒向誤判兩項先前被錯誤標記為完成，實際未實作。以下為本次待完成項目。

### Model 生成吐槽

- [x] Prompt 要求 model 輸出 `verdict` 與 `roast` 兩個必填字串欄位，並明訂 roast 的長度上限、單行、純文字、正體中文與安全護欄；不再要求「只能有一個欄位」。
- [x] roast 驗證條件：1–30 個使用者可見字元、單行、非空白、不含 Markdown 標記或 URL、正體中文、未逐字複製玩家辯護。
- [x] **格式驗證失敗**（超長、含 Markdown、多行、空白、語言不符、逐字複製玩家輸入）沿用 model 的合法 verdict，roast 換成該立場該 verdict 的固定文案，`isFallback` 為 `true`。
- [x] **安全驗證失敗**（roast 命中髒話、歧視、仇恨、性暗示、暴力或人身攻擊 deny-list）整筆退回 `FallbackJudgmentService.judge(stance)`，verdict 一併重抽，`isFallback` 為 `true`。
- [x] `isFallback` 語意收斂為「這句吐槽不是 model 生成的」：model 生成並通過全部驗證時為 `false` 且畫面不顯示備援揭露；任何其他來源的吐槽一律為 `true` 且畫面顯示備援揭露。固定文案不得在 `isFallback` 為 `false` 的情況下顯示。

### 倒向判定誤判

- [x] 明確倒向判定只在辯護明確倒向同題相對立場或否定抽中立場時觸發。挺立場但字面包含「不支持」「放棄」「倒戈」「我錯了」等詞的辯護不得誤判 —— 例如香菜加爆派的辯護「不支持香菜的人才奇怪」必須可判為「信仰堅定」。

### 測試

- [x] 自動測試覆蓋 roast 的全部驗證失敗類別、兩條分流路徑各自的 verdict 與 `isFallback` 結果、model 生成成功時 `isFallback` 為 `false` 且不顯示備援揭露，以及倒向誤判的迴歸案例；不載入真實模型或呼叫網路。
- [x] 移除鎖住舊行為的既有測試（`test/features/food_religion_war/food_religion_ai_judgment_test.dart` 的 "uses the approved roast when the model writes its own safe roast"）。

### 已知限制

本機只能做結構性驗證與 deny-list 比對。語意層的安全（人身攻擊、族群或文化攻擊、推測人格與智力）無法在本機驗證，僅由 prompt 的安全護欄約束，並以 deny-list 作為 backstop。此為實作可達的最佳狀態，不構成保證。

## Comments

- Completed the on-device judgment path for the four-choice defense-draw flow, including stable GGUF-first discovery, submission-time model locking, and a bounded discovery fallback.
- Added typed safe failure classifications, first-terminal-result lifecycle guards, cancellation before load, native session cleanup, and expanded explicit stance-denial validation.
- Covered all twelve drawn stances, all three legal verdicts, every fallback class, discovery races, replay reset, cancellation, and late terminal events through replaceable services without loading a real model or using the network.
- 2026-08-10 — Reopened by two-axis code review against `feat/v0.1-cc`. Two criteria were checked off without being implemented:
  - The prompt instructed the model to emit `{"verdict":...}` only, the parser discarded any model-supplied `roast`, and the service substituted `FallbackJudgmentService.approvedRoastFor()` while leaving `isFallback` at its `false` default. Fixed copy was therefore displayed as a personalised AI response with no disclosure, contradicting spec story 33 and spec.md:126.
  - `_isExplicitTurncoat` matched bare alternatives (`不支持|放棄|倒戈|我錯了`) anywhere in the defense, so pro-stance defences were forced into a false fallback. spec.md:127 scopes the rule to defences that explicitly turn.
- Decisions taken before reopening: roast bound is 1–30 user-visible characters; format failures keep the model verdict and swap the roast, safety failures discard the whole judgment. Both paths set `isFallback: true`, so the UI keeps a single disclosure state.
- 2026-08-10 — Reopened scope implemented. The prompt now requires `verdict` and `roast`; the parser keeps the model roast and validates it inside the service boundary. Format failures (over 30 visible characters, Markdown or links, multi-line, blank, non-Traditional-Chinese, verbatim copies of the defence) keep the model verdict and swap in the stance's approved copy with `isFallback: true`; deny-list hits discard the whole judgment through `FallbackJudgmentService.judge(stance)`, re-rolling the verdict, also with `isFallback: true`. A validated model roast now yields `isFallback: false` and no disclosure.
- 2026-08-10 — `_isExplicitTurncoat` no longer matches bare 「不支持」「放棄」「倒戈」「我錯了」. Every own-stance denial must name the drawn stance or the stance slot, so loyal defences such as 「不支持香菜的人才奇怪」 and 「我絕不放棄北部粽」 stay 信仰堅定. Regression cases and every roast-validation class are covered in `test/features/food_religion_war/food_religion_ai_judgment_test.dart` without loading a model or touching the network.
- 2026-08-10 — Two-axis review of the reopened work. Spec axis found the turncoat narrowing was still stance-shaped rather than general, so `_isExplicitTurncoat` was rewritten: the defence is read clause by clause, a speaker denial now needs a first-person subject before the trigger, the drawn stance right after it, and no negation or quotation marker in the four characters before it; statements about the stance itself (北部粽不好吃) still need no speaker. 「不支持北部粽的人才奇怪」「我永遠不會放棄北部粽」「沒有人不支持北部粽」「誰說我討厭北部粽，我最愛北部粽」「我才不會改支持北部粽」 are now regression cases. Out-of-scope triggers (背叛/改信/棄守/站不住) were dropped, and `_copiesDefense` no longer rejects a partial six-character quote — only a roast made entirely of the player's words.
- 2026-08-10 — Also from review: the 正體中文 check now rejects Latin runs of three or more letters (a roast answered in English previously passed), with kana and Latin regression cases added. A response missing the `roast` key keeps going down the 缺欄位 fallback path from the original acceptance criteria, which re-rolls the verdict; only a present-but-malformed roast keeps the model verdict. Standards axis: `CONTEXT.md` 備援裁決 was widened to cover a model verdict carrying approved copy, matching the reopened `isFallback` semantics.

