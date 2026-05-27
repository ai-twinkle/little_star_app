# 計畫：v0.1 文檔產出

> 循環：2026-05-25-v0.1-docs
> 階段：Definition
> 狀態：🔄 進行中

---

## 目標

為 v0.1 重構成果產出完整一輪 markdown 文檔（架構 + ADR + 開發/貢獻指南 + 對外入口），服務於專案維護、外部貢獻、技術社群分享。先寫初稿，v0.1.0 release 前持續補。

---

## 任務分群（Epic）

```
EP-1 對外入口層（README / CONTRIBUTING / CHANGELOG）
EP-2 架構文檔（overview 含模組參考）
EP-3 ADR 系列（5 篇 + 索引/模板）
EP-4 開發環境指南（setup）
EP-5 [SHOULD] API 註解 / 邊界（dartdoc + @internal）
```

執行順序建議：EP-3 → EP-2 → EP-4 → EP-1 → EP-5
原因：ADR 與架構是其他文檔的內容來源；README 等對外文檔最後寫，能引用前述產出。

---

## 任務清單

### EP-1：對外入口層

#### task-101: README.md 重寫
- **類型**: 📄 文檔
- **狀態**: [TODO]
- **描述**: 把 README 從 v0.0.x 的雛形升級為 v0.1 對外入口；定位「Flutter 本地 LLM App with llama.cpp + MLX」，呈現技術棧、特色、quick start。
- **建議方式**: 草稿 → 審閱 → 定稿
- **驗收標準**:
  - [ ] 涵蓋專案定位、目標讀者、技術棧（Flutter / Riverpod / llama.cpp / MLX / Pigeon / FFI）
  - [ ] 列出 v0.1 主要能力與支援平台矩陣
  - [ ] Quick start：clone → fvm flutter pub get → llama.cpp build → run（指向 setup.md）
  - [ ] 連結到 CONTRIBUTING / CHANGELOG / docs/architecture / docs/adr
  - [ ] 含 license、致謝（llama.cpp / mlx-swift-lm 等）
- **預估時間**: 0.5 天

#### task-102: CONTRIBUTING.md
- **類型**: 📄 文檔
- **狀態**: [TODO]
- **描述**: 外部貢獻入口；吸收編碼規範（B3）成為單篇。
- **建議方式**: 草稿 → 審閱 → 定稿
- **驗收標準**:
  - [ ] 開發流程：fork / branch / PR / review / merge
  - [ ] Commit 規範：Conventional Commits（type/scope/subject + body + footer）
  - [ ] 編碼規範：Dart 風格、Riverpod 命名、測試策略（unit / widget / integration 邊界）
  - [ ] PR 模板要求與 Issue 模板要求
  - [ ] 連回 setup.md 與 architecture/overview.md
- **預估時間**: 0.5 天

#### task-103: CHANGELOG.md（v0.0.4 起）
- **類型**: 📄 文檔
- **狀態**: [TODO]
- **描述**: 採傳統 Keep a Changelog 結構（Added / Changed / Fixed / Removed），起點 v0.0.4；v0.1.0 條目反映 EP1-EP6 的累積。
- **建議方式**: 蒐集 commits → 分類 → 撰寫條目 → 審閱
- **驗收標準**:
  - [ ] 文件遵循 Keep a Changelog 與 SemVer 慣例的標頭
  - [ ] v0.0.4 至 v0.1.0（unreleased）區段齊備
  - [ ] v0.1.0 區段以 Added / Changed / Fixed / Removed 分類覆蓋 EP1-EP6 重大變更
  - [ ] 涉及 breaking change 的條目明確標註
- **預估時間**: 0.5 天

---

### EP-2：架構文檔

#### task-201: docs/architecture/overview.md
- **類型**: 📄 文檔
- **狀態**: [TODO]
- **描述**: v0.1 架構總覽 + 模組參考（A1 + A3 合併）。讀者：未來維護者 / 新貢獻者。
- **建議方式**: 大綱 → 圖 → 文字 → 審閱
- **驗收標準**:
  - [ ] 分層圖：UI / ViewModel / Controller / Service / Engine（FFI + Pigeon bridge）/ Native
  - [ ] 資料流圖：使用者輸入 → ChatTemplate → GenerationController → Engine → token stream → UI
  - [ ] 列出 core 模組及其職責、入口、擴充點（engine、profile、template、platform、download 等）
  - [ ] 標明 v0.1 引入的關鍵抽象（ChatTemplate / ModelProfile / GenerationController）
  - [ ] 章節結尾連到對應 ADR
- **預估時間**: 1 天

---

### EP-3：ADR 系列

#### task-300: ADR 模板與索引
- **類型**: 📄 文檔 + ⚙️ 配置
- **狀態**: [DONE] ✅
- **描述**: 在 `docs/adr/` 建立 README（索引）與標準 ADR 模板（Context / Decision / Consequences / Status）；不引入外部工具，純 markdown。
- **建議方式**: 變更 → 驗證 → 部署
- **驗收標準**:
  - [ ] `docs/adr/README.md` 列出 ADR 索引（編號、標題、狀態）
  - [ ] 標準 ADR 章節：Status、Context、Decision、Consequences、Alternatives Considered
  - [ ] 索引能讓讀者快速找到任一 ADR
- **預估時間**: 0.5 天

#### task-301: ADR-0001 MLX 整合路徑 A
- **類型**: 📄 文檔
- **狀態**: [DONE] ✅
- **描述**: 採用 mlx-swift-lm via Pigeon（Path A）整合 MLX；vs Path B（mlx-c FFI）/ Path C（Swift wrapper + @\_cdecl + FFI）的三方比較。
- **建議方式**: 草稿 → 審閱 → 定稿
- **驗收標準**:
  - [ ] Context 說明為何 v0.1 引入 MLX
  - [ ] Decision 明確記錄選 Path A
  - [ ] Alternatives：列出 B / C，包含優劣與被否決原因
  - [ ] Consequences：streaming callback / Swift Package 依賴 / iOS-only 等後果
  - [ ] 引用素材：exploration.md C 線（line 225+）
- **預估時間**: 0.5 天

#### task-302: ADR-0002 Native bridge 雙軌策略
- **類型**: 📄 文檔
- **狀態**: [DONE] ✅
- **描述**: 為何 v0.1 同時保留 FFI（llama.cpp）與 Pigeon（MLX）兩種 native bridge，而不統一。
- **建議方式**: 草稿 → 審閱 → 定稿
- **驗收標準**:
  - [ ] Context 說明 llama.cpp 與 MLX 的整合介面差異
  - [ ] Decision 記錄雙軌並存，並界定各自適用場域
  - [ ] Consequences：複雜度 / 維護成本 / 後續是否能收斂為單軌
  - [ ] Alternatives：統一走 FFI 或統一走 Pigeon 的代價
- **預估時間**: 0.5 天

#### task-303: ADR-0003 Pigeon streaming pattern
- **類型**: 📄 文檔
- **狀態**: [DONE] ✅
- **描述**: Swift → Dart token-by-token streaming 的 Pigeon channel pattern；涵蓋 callback / EventChannel-like 模式選擇與取消機制。
- **建議方式**: 草稿 → 審閱 → 定稿
- **驗收標準**:
  - [ ] Context 說明 streaming 的特殊性（vs request-response）
  - [ ] Decision 記錄採用的 pattern（含程式示意）
  - [ ] Consequences：cancel 行為、錯誤傳遞、背壓
  - [ ] Alternatives：其他 streaming 模式被否決原因
- **預估時間**: 0.5 天

#### task-304: ADR-0004 ChatTemplate 抽象化
- **類型**: 📄 文檔
- **狀態**: [DONE] ✅
- **描述**: 以 ChatTemplate 取代舊 PromptFormat 的抽象演進；含 Smoking Gun（舊路徑 prompt 模板行為錯誤）修復脈絡。
- **建議方式**: 草稿 → 審閱 → 定稿
- **驗收標準**:
  - [ ] Context 說明舊 PromptFormat 的痛點 + Smoking Gun
  - [ ] Decision 記錄 ChatTemplate + Resolver 設計
  - [ ] Consequences：擴充新模型族的方式、向後相容性
  - [ ] Alternatives：保留 PromptFormat / 走 jinja2-like template engine 等被否決方案
- **預估時間**: 0.5 天

#### task-305: ADR-0005 GenerationController 與 ViewModel 邊界
- **類型**: 📄 文檔
- **狀態**: [DONE] ✅
- **描述**: 抽出 GenerationController 後，與 ViewModel 的責任邊界劃分。
- **建議方式**: 草稿 → 審閱 → 定稿
- **驗收標準**:
  - [ ] Context 說明 ViewModel 過胖的舊狀態
  - [ ] Decision 記錄哪些責任進 Controller（生成、metrics、cancel）、哪些留 VM（UI 狀態）
  - [ ] Consequences：可測試性、metrics 收集點、未來新增 backend 的影響
  - [ ] Alternatives：留在 VM / 引入 BLoC 等被否決
- **預估時間**: 0.5 天

---

### EP-4：開發環境指南

#### task-401: docs/development/setup.md
- **類型**: 📄 文檔
- **狀態**: [TODO]
- **描述**: 從零起步到能跑通 dev build 的完整步驟；涵蓋 macOS / iOS 兩平台與 llama.cpp build。
- **建議方式**: 依步驟跑一次新環境 → 記錄 → 審閱
- **驗收標準**:
  - [ ] 環境需求：macOS 版本、Xcode、fvm + Flutter 版本、CocoaPods、Pigeon
  - [ ] llama.cpp build：對應 `scripts/llama.cpp_MacOS_Build.md` 的步驟與產出 static lib
  - [ ] iOS / macOS 各自的 Runner 設定（framework 連結、entitlements、code signing 提示）
  - [ ] 模型下載與放置位置
  - [ ] 常見錯誤排查（依賴版本衝突如 pigeon ^22.7.2 vs riverpod 3.x）
  - [ ] 文件中所有指令可實際執行
- **預估時間**: 1 天

---

### EP-5：[SHOULD] API 註解 / 邊界

#### task-501: dartdoc 註解完整化 + @internal 邊界
- **類型**: 🔧 程式（註解）+ 📄 文檔
- **狀態**: [TODO]
- **描述**: 為 core public API 補 dartdoc 註解；非對外擴充點標 `@internal`（含 meta package import）；本地產出 dartdoc 站驗證，不部署。
- **建議方式**: 盤點 → 補註解 → 標 @internal → 本地產 dartdoc
- **驗收標準**:
  - [ ] core 模組（engine / template / profile / controller）public API 皆有 dartdoc 註解
  - [ ] 非對外擴充點 class / method 標記 `@internal`
  - [ ] `fvm dart doc` 在本地能產出 site，無 unresolved doc reference warning
  - [ ] CONTRIBUTING 補一段「如何加 @internal / 寫 dartdoc」說明
- **預估時間**: 1-1.5 天

---

## 技術決策

- 純 markdown 放 repo，不引入靜態網站
- ADR 用最簡 markdown 模板（Status / Context / Decision / Consequences / Alternatives），不引入 adr-tools
- CHANGELOG 採 Keep a Changelog + SemVer 慣例
- A3 模組參考併入 A1 overview，不獨立檔案
- 編碼規範併入 CONTRIBUTING，不獨立檔案
- dartdoc 僅本地產出驗證，不部署 GitHub Pages

---

## 風險與依賴

| 風險 | 影響 | 緩解措施 |
|------|------|----------|
| 重構 API 在文檔寫完後又改動 | 文檔過時 | 先寫 EP-3/EP-2，等 API 穩定再寫 EP-1/EP-4；初稿允許粗糙 |
| ADR 寫得太長變成 deep dive | 變調為技術文章 | 嚴守 Status/Context/Decision/Consequences 結構；超過 1.5 頁需精簡 |
| setup.md 步驟在他機未驗證 | 外部貢獻者跑不通 | 預估時間含「跑一次新環境驗證」；Release 前找一台乾淨機器跑過 |
| dartdoc 補註解工作量爆炸 | 排擠 MUST 項目 | EP-5 為 SHOULD；若超時直接砍範圍只保留 core engine |

---

## 相關循環

- [2026-05-21-v0.1-major-refactor](../2026-05-21-v0.1-major-refactor/) — 素材來源（exploration / plan / construction），EP1-EP6 已完成

---

## 預估總時間

- EP-1：1.5 天
- EP-2：1 天
- EP-3：3 天（5 篇 ADR × 0.5 + 模板/索引 0.5）
- EP-4：1 天
- EP-5：1-1.5 天

**MUST 合計：6.5 天**
**含 SHOULD：7.5-8 天**
