# 建造：T1 整合、Benchmark Harness 與 Talk 產出物

> 循環：2026-07-08-t1-benchmark-talk
> 階段：Construction
> 狀態：🔄 進行中 — A03 / B01 / B02 早期關卡啟動

---

## 進行中任務

### task-A03: Pixel 8a 可行性快篩 — [IN_PROGRESS]
- ✅ 快篩 protocol 定版 → [docs/benchmark/pixel-8a-quick-screen.md](../../../docs/benchmark/pixel-8a-quick-screen.md)
- ✅ 判定表（進矩陣 / 降 Q3 / 轉敘事）三分支皆對應 talk 素材
- ⏳ **需在裝置執行**（Windows 主機無法代跑）：拉 Q4_K_M → App/adb 佈署 → 冷載入 + 短生成 + `dumpsys meminfo`
- ⚠️ 判定要早（7/8–7/11）

### task-B01: MLX 4-bit 轉換 + 繁中 sanity check — [IN_PROGRESS]
- ✅ 轉換 + sanity check runbook 定版 → [docs/benchmark/mlx-t1-conversion-runbook.md](../../../docs/benchmark/mlx-t1-conversion-runbook.md)
- ✅ 對照用 prompt 綁定 zh-tw-prompt-set Part 1（與 GGUF 同 prompt）
- ✅ 確認 repo 內已有 `GemmaChatTemplate`（system prompt 注入第一個 user turn，符合 Gemma 慣例）
- ⏳ **需在 Apple Silicon Mac 執行**：`mlx_lm.convert -q --q-bits 4` → generate 對照 → 判定
- ⚠️ 提早做，異常留換 8-bit / 回報時間

### task-B02: Twinkle org 上傳協調 + 繁中 model card — [IN_PROGRESS]
- ✅ 繁中 model card 草稿 → [drafts/model-card-zh-tw.md](drafts/model-card-zh-tw.md)
- ✅ org 協調訊息草稿 + 追蹤清單 → [drafts/twinkle-org-outreach.md](drafts/twinkle-org-outreach.md)
- ⏳ **需用戶本人動作**：本週送出協調請求；取得 write 權限；確認官方 repo id + system prompt 慣例
- ⚠️ 本週就要開口

---

## 共用資產（一次做、多處用）

- ✅ [docs/benchmark/zh-tw-prompt-set.md](../../../docs/benchmark/zh-tw-prompt-set.md) — 繁中 prompt 集 + 標準化測試協定
  - Part 1 品質/demo prompt（A01/B01/D02）
  - Part 2 受控長度 prompt 128/512/1024/2048（C02 校準 token 數後定版）
  - Part 3 執行條件（飛航/亮度/電量/冷暖/降溫）
  - 矩陣維度圖（MLX 僅 Apple，Pixel 8a 只在 llama.cpp 欄）

---

## 待用戶回填（回來後回寫此檔 + plan.md 狀態）

| 來源 | 待回填 |
|------|--------|
| A03 | Pixel 8a 記憶體實測數字 + 去留判定 |
| A01/B02 | T1 官方來源 repo id + system prompt 慣例 |
| B01 | 4-bit vs GGUF 繁中對照結果（達標 / 換 8-bit / 回報） |
| B02 | 協調請求送出日 + 上傳排程 |

---

## 提交記錄

| 日期 | 提交 | 內容 |
|------|------|------|
| 2026-07-08 | `704f9f1` | docs(workflow): 開循環（exploration + plan） |
| 2026-07-08 | (本次) | benchmark prompt set + B01/A03 runbook + B02 drafts |
