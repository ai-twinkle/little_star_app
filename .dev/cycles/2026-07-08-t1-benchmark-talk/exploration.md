# 探索：T1 模型整合、Benchmark Harness 與 Talk 產出物

> 循環：2026-07-08-t1-benchmark-talk
> 模式：深度 (deep)
> 狀態：✅ 決策完成 → 進入定義期

---

## 1. 問題定義 [DONE]

### 背景
7/25–26 有一場 talk。需要在約 **12 個工作天**（今天 7/8）內，把 Twinkle AI 的 **gemma-3-4B-T1-it**
（Gemma 3 微調、繁中）整合進 Little Star，並用 App 內建的量測能力產出一組**可信、可重現的裝置端
推論 benchmark**，作為 talk 的核心素材。

專案現況（已具備的資產，非拋棄式工程的基礎）：
- 多後端推論架構已完成：`lib/core/inference/`（`inference_backend.dart`、`backend_selector.dart`、
  `llama_cpp_backend.dart`），MLX backend 由 EP-10 導入（`lib/core/engine/mlx/`、`ios/Runner/MlxBridge/`）。
- 已有 "Completion Mode" 效能測試雛形（README「⚡ Performance Testing」）→ benchmark harness 的前身。
- llama.cpp FFI（`lib/core/engine/llama_cpp/llama_cpp_ffi.dart`）+ MLX Pigeon channel 雙路徑俱在。
- ADR 0001 記錄 MLX 整合路徑。

### 核心問題
在 12 個工作天內，讓 T1 在 llama.cpp 與 MLX 兩個 backend 都跑通並輸出高品質繁中，
用一份標準化繁中 prompt 集在 iPhone 17 Pro（與 Pixel 8a，若可行）上跑出完整 benchmark 矩陣，
產出 talk 用圖表與 demo 錄影 —— 且所有產出物在 talk 後仍是 Little Star / Twinkle 的長期資產。

### 目標
- [ ] A｜T1 在 llama.cpp backend 跑通、chat template 正確、繁中品質達標
- [ ] B｜T1 MLX 4-bit 轉換 + 繁中 sanity check + 上傳 Twinkle org + 接進 MLX backend
- [ ] C｜Benchmark harness 進 App 本體（載入時間 / TTFT / decode t/s / 峰值記憶體 / thermalState / 電量），可匯出 CSV/JSON
- [ ] C｜標準化測試協定 + 持續負載（10 分鐘發熱曲線）
- [ ] D｜圖表、demo 錄影、Foundation Models 對照（timebox 1 天）

### 限制條件
- 時間：12 個工作天，硬截止 7/25（talk）。7/20–7/24 保留給圖表 / 簡報 / 講稿 / ≥2 次計時排練
- 技術：4B 權重約 2.5GB；iPhone 需 `increased-memory-limit` entitlement；Pixel 8a 8GB RAM 為風險點
- 資源：Twinkle AI org 上傳權限需協調（不可控，本週就要開口）
- 慣例：不做 live demo，用錄影

### 成功標準
- [ ] 一份繁中 prompt 集，同時跑 2 backend × 2 裝置 → 一張矩陣圖講完所有對比（資訊密度最高）
- [ ] 兩個 backend 的 chat template 處理一致（否則對比失真）
- [ ] benchmark 可重現（冷/暖啟動分開、飛航模式、固定亮度、同電量起跑、組間降溫）

---

## 2. 背景研究 [DONE]

### 現有系統分析
| 元件 | 位置 | 對本循環的意義 |
|------|------|----------------|
| 推論後端抽象 | `lib/core/inference/inference_backend.dart` | harness 量測介面掛在這層，兩 backend 共用 |
| llama.cpp backend | `lib/core/inference/llama_cpp_backend.dart` + `.../engine/llama_cpp/llama_cpp_ffi.dart` | A 線落點 |
| MLX backend | `lib/core/engine/mlx/` + `ios/Runner/MlxBridge/` | B 線落點 |
| backend 選擇器 | `lib/core/inference/backend_selector.dart` | 「一鍵切換」demo 的基礎 |
| Completion Mode | README「Performance Testing」 | harness 的前身，C 線在此擴充 |

### 技術調查（待驗證重點）
- T1 model card 的 system prompt 慣例（Gemma 3 chat template 特性）——繁中品質直接取決於此
- iPhone 17 Pro：4K vs 8K context 的 KV cache 記憶體差距（決定 benchmark context 長度）
- Pixel 8a：4B Q4_K_M 在 8GB RAM 是否可行；不行則試 Q3，或轉敘事素材
- MLX 4-bit 轉繁中品質是否劣化（sanity check 提早做，留換 8-bit / 回報社群的時間）

### 參考案例
- 相關 ADR：[docs/adr/0001-mlx-integration-path-a.md](../../../docs/adr/0001-mlx-integration-path-a.md)

---

## 3. 方案發想 [DONE] — 四條工作線

- **A｜T1 整合（llama.cpp 側）**：拉官方 GGUF Q4_K_M、驗 chat template、iPhone 記憶體驗證、Pixel 快篩
- **B｜MLX 轉換與社群貢獻**：`mlx_lm.convert` 4-bit、繁中 sanity check、上傳 Twinkle org 補繁中 model card、接進 MLX backend
- **C｜Benchmark harness（進 App 本體）**：App 內埋量測 + 標準化協定 + 持續負載測試 —— **長期資產線**
- **D｜Talk 產出物**：圖表、demo 錄影、Foundation Models 對照（timebox 1 天）

---

## 4. 方案評估 [IN_PROGRESS] — C 線範圍決策

唯一影響範圍的分岔：harness 做到「內部量測工具」就好，還是趁勢做成 v0.1 對外裝置跑分功能？

| 面向 | 方案 1：內部量測工具 | 方案 2：v0.1 對外跑分功能 |
|------|----------------------|---------------------------|
| 額外工時 | 基準 | +2~3 天 UI 工 |
| Talk 敘事 | benchmark 數據 | 多一個「發佈」時刻 |
| 長期資產 | harness 邏輯可留用 | 直接變使用者功能 + 社群回報各機型數據，掛勾 Twinkle 生態 |
| 時程風險 | 低 | 吃掉 buffer，排練時間可能被壓縮 |

**✅ 決策（2026-07-08）：方案 1「內部量測工具」**。理由：保住 7/20–7/24 排練 buffer（本次主敵是語速），
時程風險最低；harness 量測邏輯本身即長期資產，對外跑分頁 UI 留待後續循環（可站在此 harness 上再做）。

---

## 5. 原型驗證規劃 [TODO]

早期關鍵假設驗證（越早越好，判定要早做）：
- **Pixel 8a 去留判定**（7/8–7/11）：跑得動進矩陣，跑不動轉敘事素材
- **MLX 繁中 sanity check**（越早越好）：異常則換 8-bit 或回報社群
- **pilot benchmark run**（7/12–7/15）：先小跑修正方法論，再正式跑矩陣

---

## 6. 決策 [TODO]

### 最終選擇
- 探索模式：**深度 (deep)**
- C 線 harness：**內部量測工具**（對外跑分頁不進本循環）

### 決策理由
時程硬截止 7/25、buffer 要留給排練；harness 邏輯已是長期資產，UI 化留待後續循環。

### 下一步
進入定義期，把四條線拆成功能層級任務；C 線只做內部量測 + 匯出，不做對外 UI。

---

## 相關循環

- [2026-05-21-v0.1-major-refactor](../2026-05-21-v0.1-major-refactor/plan.md) — 提供多後端架構、MLX backend、Completion Mode，本循環直接站在其上
- [2026-05-25-v0.1-docs](../2026-05-25-v0.1-docs/) — v0.1 文檔線，model card / ADR 產出可對接

---

## 討論記錄

| 日期 | 重點 | 待辦 |
|------|------|------|
| 2026-07-08 | 收到四線計畫 + 時程 + 風險清單；確認站在既有多後端架構上非拋棄式 | 確認深度模式；決 harness 範圍 |
| 2026-07-08 | ✅ 確認 deep 模式；harness = 內部量測工具（對外 UI 留後續） | 進入定義期，產出 plan.md |

---

## 待釐清問題

- [x] ~~**C 線 harness 範圍**~~ → 內部量測工具（2026-07-08 決）
- [ ] benchmark context 長度：4K vs 8K（需先量 KV cache 記憶體差距）
- [ ] Twinkle org 上傳協調何時開口（建議本週）與上傳時間點（建議 talk 前幾天，新鮮度最高）
