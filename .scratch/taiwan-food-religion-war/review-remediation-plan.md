# Code review 修正計畫

兩軸 code review（Standards + Spec）針對 `git diff feat/v0.1-cc...HEAD` 產生，fixed point `e8b5daa`，35 commits／63 files。本檔記錄修正順序與已做的決策，供 `/clear` 後接續。

**建立日期：** 2026-08-10
**Branch：** `feat/food-religion-game` → 目標 merge 到 `feat/v0.1-cc`

## 已定案的決策

1. **Wave A 做完就 merge**，架構層面的債留給 Wave B／EP-1。不另開 fix branch —— 本 branch 尚未 merge，findings 就是它未完成的工作。
2. **ticket 12 是 merge 的最後一道把關**（目前 `ready-for-human`）。
3. **Wave B 等 merge 完另開 branch**，走 `/grill-with-docs`。
4. finding 1 的方向：**讓 model 真的產生 roast**，不是把固定文案誠實標記。
5. roast 長度上限 **1–30 個使用者可見字元**。
6. roast 驗證失敗**依性質分流**：格式失敗沿用 model verdict、只換 roast；安全失敗（deny-list）整筆退回備援。兩者都 `isFallback: true`，UI 維持單一揭露狀態。

## Wave A 進度（2026-08-10 更新）

程式碼部分全部完成，接下來只剩人工步驟。

| 項目 | 狀態 | Commit |
|---|---|---|
| ticket 07（finding 1 + 3） | 完成 | `08e6217`、`1fd021f` |
| finding 7 haptic | 完成 | `e9c9cab` |
| finding 5 字數／trim | 完成 | `a27f960` |
| finding 6 lazy 搜尋清單 | 完成 | `00b47ce` |
| finding 2 service→UI import | 完成 | `4fe8bc9` |
| 實機手動驗證 ticket 13／14 | 完成（2026-08-11，iPhone 17 Pro） | — |
| 實機手動驗證 ticket 12 | iOS 與 Pixel 8a 各一局完成；裝置矩陣的最小機型未驗 | `7b2b8b0`、`e2e5b68` |
| 輔助技術驗收（VoiceOver／TalkBack） | 拆出為 ticket 15，不擋 merge | — |
| merge 前重跑 `/code-review`（fixed point `feat/v0.1-cc`） | **待執行** | — |

實作時的三個偏離，已在各自 commit 訊息與 ticket 07 留紀錄：

1. finding 7 除了 result transition，抽籤與選擇點擊的 haptic 也一併收斂到同一個 helper —— 三處是同一個缺陷，只修一處會留下不一致。
2. finding 5 讓 `FoodReligionDefense` 存 trim 後的值後，「送給 AI 的是玩家原始辯護」這條驗證改為「保留玩家用字、只去除前後空白」，`food_religion_ai_flow_test` 與 `food_religion_ai_judgment_test` 的相關斷言已同步更新。
3. finding 2 沒有把 `GenerationController` adapt 進來，而是讓 service 宣告 `FoodReligionTextGenerator` 並預設直接跑 `InferenceSession`。這個 feature 從未使用 controller 的 metrics，此做法同樣不預判 Wave B，且 seam 仍留著讓任何 runner adapt 進來。另加了 architecture test 鎖住「`lib/features/**/services` 不得 import UI layer」。

全測試 392 項通過；`flutter analyze` 對本次動到的檔案無 issue。

## Wave A — merge 前必須完成

### 1. ticket 07（進行中）

已重開為 `ready-for-agent`，涵蓋 finding 1（假的 AI 吐槽）與 finding 3（倒向判定誤判）。完整 acceptance criteria、七類 roast 驗證失敗、兩條分流路徑、`isFallback` 語意、已知限制都寫在
`.scratch/taiwan-food-religion-war/issues/07-on-device-judgment-for-drawn-stance.md`。

執行方式：`/clear` 後 `/implement .scratch/taiwan-food-religion-war/issues/07-on-device-judgment-for-drawn-stance.md`

### 2. 剩餘四項小修

四項互相獨立、動到的檔案不重疊。建議一個 context 內以 `/tdd` 各做一個 red-green slice；若偏好 ticket 流程則補成 ticket 15–18。

| # | Finding | 位置 | 要做的事 |
|---|---|---|---|
| 2 | Service 反向 import UI layer | `lib/features/food_religion_war/services/food_religion_judgment_service.dart:15` | **最小版修法**：service 自己宣告抽象 interface（例如 `TextGenerator`），由呼叫端把 `lib/ui/shared/inference/generation_controller.dart` 的 `GenerationController` adapt 進去。此修法與 Wave B 的架構決定無關，兩種結果都成立。完整 layering 留給 Wave B。 |
| 5 | 字數顯示與 validation 不一致 | 顯示：`widgets/food_religion_game_screen.dart:247-250`／驗證：`domain/food_religion_defense.dart:38-44,51` | 顯示改用 trim 後長度，並讓 `FoodReligionDefense` 存 trim 後的值（現在存未 trim 的 `value`，prompt `:260` 會收到前後空白，`characterCount` 可能超過 `maxCharacters`）。現象：50 字 + 尾端空格顯示「51 / 50」但送得出去。spec.md:124 |
| 6 | Model search list 失去 lazy building | `lib/ui/models/widgets/model_search_list.dart:37-51`（外層 `model_manager_screen.dart:394-399`） | ticket 14 把 `ListView.builder` 換成 `Padding(child: Column(...))`，unbounded viewport 問題解掉了但變成 eager build 每個 HuggingFace 結果。改用 `SliverList` 兩者兼顧。 |
| 7 | Haptic 無條件觸發 | `widgets/food_religion_game_screen.dart:297` | result transition 的 `HapticFeedback.mediumImpact()` 要加平台與 reduced-motion 判斷。ticket 09 line 6 只把 haptics 範圍訂在選擇記錄與抽籤揭曉。 |

### 3. 實機手動驗證

**必須在 Wave A 全部落地之後**才做 —— finding 1／5／7 改的正是 tickets 12/13/14 沒勾的東西（roast 文字、字數顯示、haptic），提前驗證會失效。

tickets 12、13、14 各自保留一個 iPhone 17 Pro 手動再驗證項目。ticket 12 是 release gate。

### 4. Merge

merge 前對同一個 fixed point 再跑一次 `/code-review`，確認 Wave A 六項都關掉。

## Wave B — merge 後另開 branch

用 `/grill-with-docs`（stateful，會留 `CONTEXT.md` 與 ADR；這個決定會動到約 2000 行的位置，屬於難以反轉，必須留紙本）。

**不要用 `/wayfinder`** —— 範圍清楚的架構決定，用 wayfinder 是過度投資。

底下會自動拉進 `/codebase-design`（module shape、seam、interface depth）與 `/domain-modeling`（glossary、ADR）。

### 這些 findings 是同一個根因，不要逐個修

- `lib/features/food_religion_war/**` 整棵樹不在 `docs/architecture/overview.md` §3 的六層裡，也沒有 ADR。**注意**：Wave A 已加入 architecture test `featureServiceUiDependencies()`（`test/support/architecture_rules.dart`），它替一個文件上不存在的 layer 立了規則 —— grill 的結論必須同時處理這個測試（保留並補文件，或隨檔案搬移一起移除）
- Service 直接 `new` 而非 injected：`domain/food_religion_game_session.dart:68,82`、`widgets/food_religion_game_screen.dart:57,88-92`；整個 feature 沒碰 Riverpod，但同一個 diff 卻為 model manager 擴充了 `lib/providers/service_providers.dart`
- `domain/` 裡放 `ChangeNotifier`（`food_religion_game_session.dart:57`）並持有 timer、model discovery、service orchestration
- Glossary drift：`FoodFaith`／`finalChallenge`（`domain/food_faith.dart:1,131`，`CONTEXT.md` 明確禁止用 "final" 描述回合）、`contenders`（`food_religion_game_session.dart:108`，被淘汰的 bracket 用語）
- `FoodReligionGameRunState.shared`（`food_religion_game_session.dart:44`）global mutable state，且 `game_screen.dart:58-62` 用「有沒有注入 randomizer」決定行為；`HomeScreen.withDependencies` 同理 —— test 需求洩進 production code

### Grill 的題目

1. `lib/features/` 是新的官方 layer（補 ADR、更新 `overview.md` §3/§5），還是搬回 `lib/ui/food_religion_war/`？
2. `GenerationController` 屬於哪一層？**（2026-08-11 更新：題目變了）** Wave A 的 finding 2 已讓 judgment service 自行宣告 `FoodReligionTextGenerator` 並預設直接跑 `InferenceSession`，因此 service 不再需要 `GenerationController`，反向依賴已經消失。現在要決定的是：`GenerationController` 留在 `lib/ui/shared/inference/` 是否正確（它是 UI 專屬的產物，還是 core 的 generation boundary？），以及 `FoodReligionTextGenerator` 這個 feature-local seam 要收斂成共用抽象、還是維持各 feature 自宣告。
3. `FoodReligionGameSession` 拆成 ViewModel + 純 domain 的界線畫在哪。
4. `FoodReligionGameRunState.shared` 的正當替代。
5. Glossary 正名範圍。

### Wave A 之後才有的新事實（grill 開始前先讀）

- judgment service 不再 import UI layer；seam 是 `FoodReligionTextGenerator`（`services/food_religion_judgment_service.dart`），commit `4fe8bc9`。
- `spec.md` 的逾時門檻已改 40 秒並補上量測依據；`maxTokens` 80。這些是產品參數，不影響架構決定。
- 仍未關的四張票都**不屬於** Wave B：12／15 是人工裝置驗收，16 是 overlay theme 的小缺陷（建議在 Wave B 動檔案之前先收掉），17 是 Android 端側裁決品質的產品決定。
- Standards review（2026-08-11，merge gate）重複點出的兩項就是 Wave B 的題目 1 與題目 5：`lib/features/` 未寫入 `overview.md` §3/§5，以及 `FoodFaith.finalChallenge` 用了 `CONTEXT.md` 禁用的 "final"。

### 與既有 cycle 的關係

**Riverpod 已經導入完成**（`pubspec.yaml:66` `flutter_riverpod: ^2.6.1`，`lib/providers/service_providers.dart` 12 個 provider，v0.1-major-refactor 循環的 task-101）。六層架構也已寫進 `docs/architecture/overview.md`。

所以 Wave B **不是**規劃新的 foundation work，而是：把一個沒遵守既有慣例的 feature 拉回慣例，並決定 `lib/features/` 是否要正式成為文件化的 layer。範圍比一個 EP 小，自己一個 branch 即可，開在 `feat/v0.1-cc` 之上。

開工前確認目前哪個 cycle 是 active —— `.dev/cycles/active.txt` 於 2026-08-10 檢查時不存在，且 `.dev/cycles/` 下有三個 cycle（`2026-05-21-v0.1-major-refactor`、`2026-05-25-v0.1-docs`、`2026-07-08-t1-benchmark-talk`）。

grill 請保持在一個沒有中斷的 context window；若結論大到需要拆票，才走 `/to-spec` → `/to-tickets`，且在 `/to-tickets` 前不要 `/clear` 或 `/compact`。

## Wave C — 之後，`/improve-codebase-architecture` 範圍

- `FoodFaith.opposing` 取代手寫 switch：`services/food_religion_judgment_service.dart:333-346` 手列每個立場的對立 label，但 `FoodStancePair.stancePool`（`domain/food_faith.dart:161`）已有這份知識。若 Wave B 要動 domain type 可順手一起做。
- 1230 行的 `food_religion_game_screen.dart` 拆分：目前同時持有 palette、`ThemeData`、dialog、navigation、validation 與 12 個 private widget。
- Data Clumps：`_DefenseView`（`game_screen.dart:702-731`）13 個參數；`drawnFaith`+`beliefSlate`+`judgment` 總是一起旅行，而 `_ChoiceView:529` 直接吃整個 session，seam 不一致。
- 抽取 `_AnnouncedText`：`Semantics(liveRegion:true) → ExcludeSemantics(Text(...))` 在 `game_screen.dart:761, 768, 792, 883, 900` 重複五次。
- 12 張角色 PNG 約 12 MB 未壓縮（每張約 1 MB），會進 bundle。此項完全獨立，任何時候可做。

## Review 已驗證正確（不需重查）

四個獨立選擇流程、6 選 4 distinct + shuffle、first-input-only locking、抽籤前 explicit beat（`food_religion_game_session.dart:153-171`）、no-reroll、跨 session `avoid`（`:31-37`）、guardrail 文案、12 立場的 challenge／fallback copy／方形素材、one-shot missing-model reminder（「先玩再說」為 primary）、arena `Theme` 提到 `Scaffold` 之上且有 16/18 px 字級下限、terminal-state guard、`lib/` 內無殘留 tournament 詞彙。

## 一個歷史紀錄的問題

commit `febff8f` 訊息寫 "accept model verdicts with generated roasts"，實際行為相反 —— 它移除了 generated roasts。不改歷史，在 ticket 07 的修正 commit 訊息裡講清楚即可。
