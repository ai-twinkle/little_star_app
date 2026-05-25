# 探索：v0.1 文檔規劃

> 循環：2026-05-25-v0.1-docs
> 模式：標準 (standard)
> 狀態：✅ 探索期完成

---

## 1. 釐清 [DONE]

### 背景

v0.1-major-refactor 循環正在執行 EP1-EP6 的大型重構，涵蓋：
- EP-1：Riverpod 全面導入
- EP-3：ChatTemplate 抽象化
- EP-5：ModelProfile 型別化與 recommended catalogue
- EP-6：GenerationController + ViewModel 遷移

重構接近完成（前述 commits 已落地），重構成果需要對應的文檔產出，避免：
- 未來維護者（包含自己）忘記決策脈絡
- 外部貢獻者難以介入
- 技術成果無法對外分享

### 核心需求

> 為 v0.1 重構成果產出完整一輪文檔（架構 + API + 使用），服務於維護延續、外部貢獻、技術社群分享。

### 限制條件

- **時間**：建造期必須等 v0.1-major-refactor 的 EP1-EP6 全數完成後才能啟動（避免文檔追逐尚未穩定的 API）
- **素材依賴**：以 `.dev/cycles/2026-05-21-v0.1-major-refactor/` 的 exploration / plan / construction 為主要素材來源
- **範圍排除**：不含終端使用者教學（App 操作說明）
- **平台特性**：Flutter + llama.cpp + MLX 的本地 LLM App，文檔需涵蓋跨平台（iOS/macOS）與原生整合面

### 成功標準

- 新維護者能在不問人的情況下理解 v0.1 架構的核心抽象與資料流
- 外部貢獻者能設定開發環境並執行 build / test
- 至少一份可發佈的技術文章草稿，能對外介紹 v0.1 的技術亮點

---

## 2. 發散 [DONE]

針對「完整一輪：架構 + API + 使用文件」的範圍，先列出候選文檔類型，後續再收斂優先級與形式：

### 維護者導向（內部）

- **A1. Architecture Overview**：系統分層、模組責任、資料流圖
- **A2. ADR 系列（Architecture Decision Records）**：把 EP1-EP6 的關鍵決策（為何選 Riverpod、為何抽象 ChatTemplate、ModelProfile 設計取捨…）逐項記錄
- **A3. Module Reference**：每個 core 模組（engine、profile、template…）的職責、入口、擴充點

### 貢獻者導向（外部）

- **B1. CONTRIBUTING.md**：流程、commit 規範、PR 規則、Issue 模板
- **B2. Development Setup Guide**：環境需求、fvm flutter、llama.cpp build、平台特定步驟（macOS framework / iOS）
- **B3. Coding Conventions**：dart 風格、Riverpod 命名、測試策略

### API 文檔

- **C1. Dartdoc 完整化**：core 模組 public API 註解補全 + dartdoc 產生靜態網站
- **C2. Public API Reference**：手寫 markdown，聚焦對外擴充點（自定義 engine、自定義 template）
- **C3. 內部 API 不文檔化**：只標記 `@internal`，僅 dartdoc 即可

### 社群 / 對外導向

- **D1. README 重寫**：v0.1 定位、特色、quick start、技術棧
- **D2. CHANGELOG.md / Release Notes v0.1.0**：對照 v0.0.x 的差異
- **D3. 技術 Blog 草稿**：例如「在 Flutter App 中跑本地 LLM：llama.cpp vs MLX 的工程取捨」
- **D4. 設計分享**：ChatTemplate 抽象的演進、Riverpod 在大型 App 的實踐

### 形式 / 載體（橫切）

- **F1. 全部 markdown 放 repo**（最簡單，git 跟得上）
- **F2. dartdoc 產 API 站 + markdown 放 `docs/`**（兩套並存）
- **F3. 引入靜態網站產生器**（Docusaurus / mkdocs，偏重 community）
- **F4. 只走 GitHub Wiki**（不建議，會脫離 repo 版本控）

---

## 3. 收斂 [DONE]

### 共識前提（來自待釐清問題的回應）

- ADR 範圍：**只記真正有取捨、或技術上特殊的決策**（不逐 EP 流水帳）
- 技術 Blog / 設計分享：**不在本循環**
- dartdoc：**不部署 GitHub Pages**，本地產出即可（或僅作為原始碼註解品質）
- CHANGELOG 起點：**從 v0.0.4 開始**
- 發佈節奏：**先寫初稿，Release 前慢慢補**（不卡 release 同步）

### 評估表

| 候選 | 必要性 | 工作量 | 對讀者價值 | 歸類 |
|------|--------|--------|------------|------|
| A1 架構總覽 | ⭐⭐⭐ | M | ⭐⭐⭐ 維護者起手式 | **MUST** |
| A2 ADR（精選） | ⭐⭐⭐ | M | ⭐⭐⭐ 留下決策脈絡 | **MUST** |
| A3 模組參考 | ⭐⭐ | M-L | ⭐⭐ 與 A1 + dartdoc 互補 | **SHOULD**（或併入 A1） |
| B1 CONTRIBUTING | ⭐⭐⭐ | S | ⭐⭐ 外部貢獻入口 | **MUST** |
| B2 環境設定指南 | ⭐⭐⭐ | M | ⭐⭐⭐ 沒這個外部跑不起來 | **MUST** |
| B3 編碼規範 | ⭐⭐ | S | ⭐⭐ 可塞進 CONTRIBUTING | **SHOULD**（併入 B1） |
| C1 dartdoc 註解完整化 | ⭐⭐ | M-L | ⭐⭐ IDE / 內部閱讀 | **SHOULD** |
| C2 手寫 API Reference | ⭐ | M | ⭐ 與 dartdoc 重疊 | **DEFER** |
| C3 @internal 標記策略 | ⭐⭐ | S | ⭐ 邊界清晰 | **SHOULD**（隨 C1 落地） |
| D1 README 重寫 | ⭐⭐⭐ | S-M | ⭐⭐⭐ 第一印象 | **MUST** |
| D2 CHANGELOG（v0.0.4→） | ⭐⭐⭐ | S | ⭐⭐⭐ 版本差異說明 | **MUST** |
| D3 技術 Blog | — | — | — | **DEFER**（另起循環） |
| D4 設計分享 | — | — | — | **DEFER**（另起循環） |

### 載體選擇

- **F1 純 markdown 放 repo**（推薦）：dartdoc 不部署，沒理由引入靜態網站；所有文檔以 `docs/` 目錄 + 根目錄 README/CONTRIBUTING/CHANGELOG 收納
- F2/F3/F4：本輪不採用

### 提議分群結果

**MUST（7 項）**
- A1 架構總覽
- A2 ADR（精選）
- B1 CONTRIBUTING（吸收 B3 編碼規範）
- B2 環境設定指南
- D1 README 重寫
- D2 CHANGELOG（v0.0.4 起）

**SHOULD（2 項）**
- A3 模組參考（或併入 A1 子章節）
- C1 dartdoc 註解完整化 + C3 @internal 邊界

**DEFER**
- C2 手寫 API Reference（與 dartdoc 重複）
- D3 / D4 對外文章與設計分享（另起循環）

### 建議的 docs 目錄結構

```
README.md              # 重寫（D1）
CONTRIBUTING.md        # 吸收編碼規範（B1+B3）
CHANGELOG.md           # 從 v0.0.4（D2）
docs/
├── architecture/
│   ├── overview.md             # A1
│   └── modules.md              # A3（SHOULD）
├── adr/
│   ├── 0001-{topic}.md         # A2 精選
│   └── ...
└── development/
    └── setup.md                # B2（macOS / iOS / llama.cpp / fvm）
```

---

## 4. 決策 [DONE]

### 最終文檔清單

**MUST**

1. **README.md（重寫）** — v0.1 定位、特色、quick start、技術棧
2. **CONTRIBUTING.md** — 流程 + commit 規範 + PR 規則 + 編碼規範（吸收 B3）
3. **CHANGELOG.md** — 從 v0.0.4 起，傳統 **Added / Changed / Fixed / Removed** 結構
4. **docs/architecture/overview.md** — 系統分層、模組責任、資料流；A3 模組參考併入此檔為子章節
5. **docs/development/setup.md** — macOS / iOS / llama.cpp build / fvm flutter / Pigeon 等環境設定
6. **docs/adr/** — 5 篇精選 ADR：
   - `0001-mlx-integration-path-a.md` — 採用 Path A（mlx-swift via Pigeon）整合 MLX
   - `0002-dual-native-bridge.md` — Native bridge 雙軌策略（FFI for llama.cpp + Pigeon for MLX 並存）
   - `0003-pigeon-streaming-pattern.md` — Pigeon streaming pattern（Swift → Dart token-by-token）
   - `0004-chat-template-abstraction.md` — ChatTemplate 抽象化取代 PromptFormat（含 Smoking Gun 修復脈絡）
   - `0005-generation-controller-boundary.md` — GenerationController 與 ViewModel 邊界劃分

**SHOULD**

7. **dartdoc 註解完整化 + @internal 邊界策略** — public API 註解補全；非對外擴充點標 `@internal`；只本地產出，不部署

**DEFER**

- 手寫 API Reference（與 dartdoc 重複）
- 技術 Blog / 設計分享（另起寫作循環）

### 文檔載體選擇

**F1：純 markdown 放 repo**（不引入靜態網站；dartdoc 僅本地產出）

### 最終目錄結構

```
README.md                  # MUST #1
CONTRIBUTING.md            # MUST #2（含編碼規範）
CHANGELOG.md               # MUST #3（v0.0.4 起；Added/Changed/Fixed/Removed）
docs/
├── architecture/
│   └── overview.md        # MUST #4（A1 + A3）
├── adr/
│   ├── 0001-mlx-integration-path-a.md
│   ├── 0002-dual-native-bridge.md
│   ├── 0003-pigeon-streaming-pattern.md
│   ├── 0004-chat-template-abstraction.md
│   └── 0005-generation-controller-boundary.md
└── development/
    └── setup.md           # MUST #5
```

### 與 v0.1-major-refactor 的銜接時點

- **建造期啟動條件**：v0.1-major-refactor 的 EP1-EP6 全數 [DONE] 後啟動本循環建造期
- **不卡 Release**：先寫初稿，v0.1.0 release 前持續補充
- 平行循環同時存在期間：本循環的探索/定義期可在 EP1-EP6 仍進行時完成，不互斥

---

## 相關循環

- [2026-05-21-v0.1-major-refactor](../2026-05-21-v0.1-major-refactor/) — 本循環的素材來源；其 EP1-EP6 構成 v0.1 主要技術內容

---

## 討論記錄

| 日期 | 重點 | 待辦 |
|------|------|------|
| 2026-05-25 | 確定模式=standard、讀者=維護者/貢獻者/社群（不含終端使用者）、範圍=完整一輪 | 進入發散，與用戶逐項討論候選文檔的去留與優先級 |
| 2026-05-25 | 5 個待釐清問題全數收斂；提出 MUST/SHOULD/DEFER 分群與 docs 目錄結構草案 | 等用戶確認分群，再進入決策子階段 |
| 2026-05-25 | A3 併入 A1；CHANGELOG 採傳統 Added/Changed/Fixed/Removed；ADR 選定 5 篇（MLX Path A、雙軌 bridge、Pigeon streaming、ChatTemplate、GenerationController 邊界） | 探索期完成；下一步進定義期切任務 |

---

## 待釐清問題

- [x] ~~ADR 範圍~~ → 只記真正有取捨、或技術上特殊的決策
- [x] ~~技術 Blog 是否屬本循環~~ → 不在本循環，另起寫作循環
- [x] ~~dartdoc 部署~~ → 不部署
- [x] ~~CHANGELOG 起點~~ → 從 v0.0.4 開始
- [x] ~~發佈節奏~~ → 先寫初稿，Release 前慢慢補
