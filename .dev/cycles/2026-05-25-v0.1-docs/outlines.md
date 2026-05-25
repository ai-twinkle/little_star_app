# v0.1 文檔內容大綱

> 循環：2026-05-25-v0.1-docs
> 用途：建造期前的內容藍圖；每份文檔在開寫前先在此處對齊章節
> 狀態：🔄 草擬中（等用戶確認後鎖定）

---

## README.md（task-101）

1. **標題 + tagline + badges**
   - tagline 草案：「A Flutter app for running LLMs locally — powered by llama.cpp & MLX」
   - badges：build / license / Flutter version / supported platforms
2. **About**
   - 一段話：什麼專案、解決什麼問題、目標讀者
   - 強調「on-device / privacy-first / multi-backend」
3. **Features（v0.1）**
   - 多 backend 推論（llama.cpp / MLX）
   - 預設 Recommended Models 目錄
   - ChatTemplate 自動套用（Gemma / Llama3 / Qwen2/3）
   - 生成 metrics（TTFT / TPS）
   - 跨平台（iOS / macOS；Desktop 開發中）
4. **Supported Platforms 矩陣**

   | Platform | llama.cpp | MLX | Status |
   |----------|-----------|-----|--------|
   | iOS | ✅ | ✅ | Stable |
   | macOS | ✅ | — | Stable |
   | Windows | 🔄 | — | EP-8 in progress |
   | Linux / Web / Android | ❌ | ❌ | Not planned in v0.1 |
5. **Quick Start**
   - 三步驟（clone → fvm flutter pub get → run）
   - 連到 `docs/development/setup.md` 取完整步驟
6. **Project Structure**
   - 樹狀圖點出 `lib/core`、`lib/ui`、`lib/providers`、`ios/Runner`、`macos/Runner`、`llama.cpp/`
   - 一句話描述每個目錄
7. **Architecture**
   - 一段話 + 連到 `docs/architecture/overview.md`
8. **Roadmap**
   - v0.1（current）/ v0.2（下一站）大致勾勒
9. **Contributing**
   - 一段話 + 連到 `CONTRIBUTING.md`
10. **License + Acknowledgements**
    - License
    - 致謝：llama.cpp、mlx-swift-lm、Flutter、Riverpod、Pigeon

---

## CONTRIBUTING.md（task-102）

1. **Welcome**
   - 歡迎話 + 本文件範圍
2. **Before You Start**
   - 連到 `docs/development/setup.md`
   - 建議先讀 `docs/architecture/overview.md` 與 ADR 索引
3. **Development Workflow**
   - Fork → branch（命名 `feat/...`、`fix/...`、`chore/...`）
   - Local 驗證：`fvm flutter analyze` + `fvm flutter test`
   - PR → review → merge
4. **Commit Conventions（Conventional Commits）**
   - 格式：`type(scope): subject`
   - 常用 type：`feat / fix / refactor / docs / test / chore / build / ci`
   - body 寫「為何」、footer 放 `Related: task-xxx` 或 `Closes #n`
   - 範例（從本 repo 史抓 1-2 個）
5. **Coding Conventions**（吸收原 B3）
   - **Dart 風格**：`dart format`、避免長函式、優先 immutability
   - **Riverpod 命名**：`xxxProvider`、`Provider.family` 用法、避免在 widget 內 `read`
   - **測試策略**
     - unit：`test/core/**`，純邏輯，不碰 native
     - widget：`test/ui/**`，golden 比較需謹慎
     - integration：實機跑，CI 不跑
   - **錯誤處理**：boundary 處 catch，內部讓 exception 上拋
6. **Documentation Conventions**
   - public API 必須有 dartdoc（`///`）
   - 非對外擴充點標 `@internal`（import `package:meta/meta.dart`）
   - 新增重大決策需追加 ADR（參考 `docs/adr/README.md`）
7. **PR / Issue 模板**
   - 列出 `.github/PULL_REQUEST_TEMPLATE.md` 與 `.github/ISSUE_TEMPLATE/` 的必填欄位
8. **Asking for Help**
   - Issue / Discussion 入口

---

## CHANGELOG.md（task-103）

採 Keep a Changelog + SemVer 結構。

1. **標頭**
   - 引用 Keep a Changelog 1.1.0 與 SemVer
2. **[Unreleased]**（將成為 v0.1.0）
   - **Added**
     - InferenceBackend / InferenceSession 抽象（EP-2）
     - LlamaCppBackend 實作 + LlamaFfiDriver（可測試）
     - BackendSelector + BackendOverride（EP-2）
     - ChatTemplate 抽象與 Gemma/Llama3/ChatML 實作（EP-3）
     - ChatTemplateResolver + `chatTemplateProvider` family
     - ModelProfile 完整型態 + RecommendedModels 目錄（EP-5）
     - GenerationController + GenerationEvent stream + TTFT/TPS metrics（EP-6）
     - Riverpod 全面導入（EP-1）
     - Platform adapter skeleton + macOS/Windows DirectoryService（EP-0 spike）
     - MLX 整合骨架（mlx-swift-lm via Pigeon，EP-0 spike）
   - **Changed**
     - CompletionViewModel / ChatViewModel 改走 GenerationController + InferenceSession（EP-6）
     - CompletionViewModel 371 → 244 lines
   - **Fixed**
     - Smoking Gun：ChatViewModel `_buildPromptFromHistory` 用錯 `<|user|>` tokens（task-604）
   - **Removed**
     - `lib/core/format/prompt_format.dart` 與 `ModelParams.format`（EP-3 task-302）
3. **[0.0.4] — YYYY-MM-DD**
   - 待從 git tag / commit 史補
4. **更舊版本**：列出但允許 stub（`No detailed changelog`）

---

## docs/architecture/overview.md（task-201；A1+A3 合併）

1. **Purpose & Audience**
   - 給維護者 / 新貢獻者，不是給終端使用者
2. **High-Level Architecture（圖）**
   - ASCII 或 mermaid：UI → ViewModel → Controller → Engine → Native
3. **Layered Model**
   - **UI 層**：Flutter widgets，無狀態 / 輕狀態
   - **ViewModel 層**：Riverpod-managed，持有畫面狀態
   - **Controller 層**：`GenerationController` — 跨後端的生成編排
   - **Engine 層**：`InferenceBackend` / `InferenceSession` 抽象
   - **Native bridge 層**：FFI（llama.cpp） + Pigeon（MLX）雙軌
   - **Platform 層**：`DirectoryService`、`PlatformAdapter`
4. **Data Flow Walkthrough**
   - 一個完整 turn 的流程：使用者輸入 → ChatTemplate render → GenerationController.start → Session.generate → native token stream → GenerationEvent → ViewModel → UI
   - 在圖上標出 cancel / error / done 三條路徑
5. **Module Reference**（原 A3 子章節）
   - `lib/core/inference/` — backend、session、settings、selector
   - `lib/core/prompt/` — ChatTemplate 家族 + Resolver
   - `lib/core/model/` — ModelProfile + RecommendedModels
   - `lib/core/platform/` — DirectoryService、PlatformAdapter
   - `lib/core/engine/llama_cpp/` — FFI 包裝
   - `lib/providers/` — Riverpod providers（service / repository）
   - `lib/ui/shared/inference/` — GenerationController
   - `lib/ui/completion/` & `lib/ui/chat/` — feature 模組
6. **Cross-Cutting Concerns**
   - **DI**：Riverpod（ADR-0001 [若新增] / 但 DI 沒入選 ADR，這裡直接寫）
   - **Cancellation**：cooperative cancel pattern
   - **Error handling**：boundary catch + GenerationError event
   - **Metrics**：TTFT / TPS 收集點
7. **Extension Points**
   - 新增 backend → 實作 `InferenceBackend` + 註冊到 `BackendSelector`
   - 新增模型族 → 實作 `ChatTemplate` + 在 Resolver 加分支
   - 新增平台 → 補 `DirectoryService` 實作
8. **References**
   - 連到 5 篇 ADR

---

## docs/adr/README.md（task-300 索引）

1. **What is an ADR**
   - 一段話：捕捉「為何這樣做」的紀錄；不是規格也不是教學
2. **Scope**
   - 本 repo 的 ADR 只記真正有取捨、或技術上特殊的決策
3. **Format**
   - 連到 `_template.md`
4. **Status Lifecycle**
   - `Proposed → Accepted → Superseded by ADR-NNNN`
5. **ADR Index**

   | # | Title | Status | Date |
   |---|-------|--------|------|
   | 0001 | MLX integration via Path A (mlx-swift + Pigeon) | Accepted | 2026-MM-DD |
   | 0002 | Dual native bridge (FFI + Pigeon) | Accepted | 2026-MM-DD |
   | 0003 | Pigeon streaming pattern | Accepted | 2026-MM-DD |
   | 0004 | ChatTemplate abstraction replaces PromptFormat | Accepted | 2026-MM-DD |
   | 0005 | GenerationController / ViewModel boundary | Accepted | 2026-MM-DD |
6. **Numbering convention**
   - 四位數補零，順序遞增；不重用編號

---

## docs/adr/\_template.md（task-300）

```markdown
# ADR-NNNN: {Title}

- **Status**: Proposed | Accepted | Superseded by ADR-NNNN
- **Date**: YYYY-MM-DD
- **Deciders**: {names}

## Context
{problem space, forces, constraints}

## Decision
{the choice in one paragraph}

## Consequences
### Positive
### Negative
### Neutral

## Alternatives Considered
### {Alternative A}
- Pros / Cons / Why rejected

## References
- {link to exploration.md / construction.md / external}
```

---

## ADR-0001：MLX 整合走 Path A（task-301）

- **Status / Date**：Accepted
- **Context**
  - v0.1 要把 MLX 引入作為 iOS 上的另一條推論路徑（Apple Silicon 性能優勢）
  - 既有 Dart FFI 已用於 llama.cpp，理論上可直接套用 mlx-c
- **Decision**
  - 選 **Path A：mlx-swift-lm via Pigeon**
- **Alternatives Considered**
  - **Path B：mlx-c FFI**
    - Pros：與 llama.cpp 一致的 bridge
    - Cons：mlx-c 對 ecosystem 支援不如 mlx-swift-lm；streaming callback 透過 FFI 跨語言難寫
    - 否決原因：開發成本高、上游不穩
  - **Path C：Swift wrapper + `@_cdecl` + FFI**
    - Pros：保留 FFI 一致性
    - Cons：`@_cdecl` 對 streaming closure 限制多、Swift 物件生命週期難跨 FFI
    - 否決原因：streaming 是核心需求，無法妥協
- **Consequences**
  - Positive：mlx-swift-lm 直接吃 mlx-community 模型；Pigeon EventChannel-like pattern 對 streaming 友善
  - Negative：iOS-only（macOS 暫不適用）；引入 Swift Package 依賴
  - Neutral：與 llama.cpp 不同 bridge，雙軌共存（→ ADR-0002）
- **References**
  - `2026-05-21-v0.1-major-refactor/exploration.md` C 線（line 225+）
  - task-001 spike 結論

---

## ADR-0002：Native bridge 雙軌策略（task-302）

- **Context**
  - llama.cpp（C/C++）走 FFI；MLX（Swift）走 Pigeon
  - 為何不統一一條路？
- **Decision**
  - **接受雙軌**：FFI for llama.cpp（含 Desktop），Pigeon for MLX（iOS-only）
- **Alternatives Considered**
  - **統一走 FFI**：MLX 需走 mlx-c 或 Swift `@_cdecl`，已在 ADR-0001 否決
  - **統一走 Pigeon**：llama.cpp 端要寫 ObjC/Swift wrapper，平白增加層級且 Desktop 不支援 Pigeon
- **Consequences**
  - Positive：每邊用最舒服的方式；性能無 wrapper overhead
  - Negative：兩套 lifecycle / error 模型需在 `InferenceBackend` 抽象層調和
  - 未來收斂可能：若 llama.cpp 也想跑 Apple Neural Engine，可能重新評估
- **References**
  - 同上 + `lib/core/inference/inference_backend.dart`

---

## ADR-0003：Pigeon streaming pattern（task-303）

- **Context**
  - LLM 生成是 token-by-token；Pigeon 原生是 request-response
  - 需在 Swift 端產生 token 串並以 streaming 形式送回 Dart，且要可取消
- **Decision**
  - 採 EventChannel-like pattern：Pigeon `@FlutterApi` callback 從 Swift 主動回呼 Dart；Dart 側包成 `Stream<Token>`；以 token-id 為單位 push，最後一個 token 帶 `isDone`
  - cancel：Dart 端呼叫 host API `cancel(sessionId)`，Swift 端中斷生成迴圈
- **Consequences**
  - Positive：可取消、可拿到 metrics、自然映射 `Stream` API
  - Negative：兩端都要管 sessionId / 生命週期；錯誤傳遞需明確序列化
  - 背壓：目前依賴 Dart 端能跟上；極快速 token rate 下可能需 buffer 策略
- **Alternatives Considered**
  - Polling host API：延遲與功耗差
  - 直接走 platform channel without Pigeon：失去 type-safe 好處
- **References**
  - task-001 spike + `ios/Runner/Pigeon/*.swift`

---

## ADR-0004：ChatTemplate 抽象化（task-304）

- **Context**
  - 舊 `PromptFormat` 為扁平字串模板，無法精準對齊 GGUF 訓練時的 chat template
  - Smoking Gun：`_buildPromptFromHistory` 在 chat 路徑誤用 `<|user|>` tokens（不存在於 Gemma/Llama3）
  - 新增 Gemma / Llama3 / Qwen2 / Qwen3 等模型族時，template 規則差異大
- **Decision**
  - 引入 `ChatTemplate` 抽象 + 四個實作（Gemma / Llama3 / ChatML for Qwen / Fallback）
  - `ChatTemplateResolver.resolve(profile, [override])` 決定要套哪個
  - `chatTemplateProvider` (Provider.family) 注入到 ViewModel
- **Consequences**
  - Positive：每個模型族的精確 token string 都被測試覆蓋；Smoking Gun 修復
  - Negative：新增模型族需同步維護 ChatTemplate；override 機制需文檔說明
  - History 紀錄：ChatViewModel 不再自己組 prompt，改由 Session + applyChatTemplate
- **Alternatives Considered**
  - 保留 PromptFormat 加分支：規則糾結、易再次出 bug
  - 引入 jinja2-like template engine：依賴重、ecosystem 尚未成熟
- **References**
  - task-301 / task-302 / task-604
  - `lib/core/prompt/chat_template.dart`

---

## ADR-0005：GenerationController 與 ViewModel 邊界（task-305）

- **Context**
  - 舊 ViewModel 既管 UI 狀態又管推論流程，難測試、難加 metrics
- **Decision**
  - 抽 `GenerationController`：負責**生成編排**（start / cancel / event stream / metrics）
  - ViewModel 保留**畫面狀態**（messages、isGenerating、error）
  - 兩者透過 `Stream<GenerationEvent>` 解耦
- **Consequences**
  - Positive：Controller 可獨立 unit test（14 tests）；新 backend 不需動 VM
  - Positive：CompletionViewModel 371 → 244 lines（34% 減）
  - Negative：兩個物件的生命週期需協調（dispose 順序）
  - Neutral：metrics（TTFT/TPS）收集點明確
- **Alternatives Considered**
  - 留在 VM：原痛點
  - 引入 BLoC：增加 mental model 負擔，且 Riverpod 已涵蓋多數需求
- **References**
  - task-601 / task-603 / task-604
  - `lib/ui/shared/inference/generation_controller.dart`

---

## docs/development/setup.md（task-401）

1. **Prerequisites**
   - macOS 版本最低需求 / Xcode 版本
   - fvm（為何用 fvm、安裝法）
   - Flutter 版本（從 `.fvmrc` 抓）
   - CocoaPods、Ruby
   - Pigeon CLI 版本（^22.7.2）
2. **Clone & Install**
   - `git clone ...`
   - `fvm install` / `fvm flutter pub get`
   - `cd ios && pod install`、`cd macos && pod install`
3. **llama.cpp Build**
   - 連到 `scripts/llama.cpp_MacOS_Build.md`
   - 摘要步驟：clone submodule（或 pinned copy at b7493）→ build → 產出 `macos/Frameworks/libllama-*.a` 與 `libggml-*.a`
   - iOS 端對應步驟（若有差異）
4. **Pigeon Code Generation**
   - 何時需要重跑 `fvm dart run pigeon ...`
   - 產出檔位置
5. **iOS-Specific**
   - Signing & Capabilities
   - mlx-swift-lm SPM 整合驗證
   - Simulator vs 實機差異
6. **macOS-Specific**
   - Entitlements（network、file access）
   - Framework 連結
7. **Run Dev Build**
   - `fvm flutter run -d ios`
   - `fvm flutter run -d macos`
   - 預期啟動畫面與 Recommended Models
8. **Model Download & Placement**
   - app 內下載流程
   - 手動放置位置（dev 階段）
9. **Troubleshooting**
   - `pigeon ^22.7.2` 與 `flutter_riverpod` 版本衝突（鎖 2.6.1）
   - libllama symbol 找不到：lib 是否在 Frameworks/、Run Phase 是否包含
   - MLX 載入失敗：SPM resolution、模型路徑、權限
10. **Next Steps**
    - 連到 `docs/architecture/overview.md` 與 `CONTRIBUTING.md`

---

## 開放問題

- [ ] DI 選 Riverpod 沒進 ADR，要在 overview.md 直接記，還是補一個 ADR-0006？
- [ ] llama.cpp vendoring（submodule vs copy-with-pin）沒入選 ADR，但這實際上是 v0.1 已決策；放 setup.md 一段話即可？
- [ ] README 的 badges 要不要本輪一起建（需要 CI workflow 跑得起來）？還是先 stub？
- [ ] ADR Status 一律寫 `Accepted` 還是要回溯 Proposed 過程？建議：v0.1 一律 Accepted（因為決策已經發生過）
