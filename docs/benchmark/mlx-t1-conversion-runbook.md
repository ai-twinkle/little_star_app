# B01 — MLX T1 4-bit 轉換與繁中 Sanity Check Runbook

> 循環：2026-07-08-t1-benchmark-talk · 任務 task-B01
> 環境需求：**Apple Silicon Mac**（`mlx_lm` 只跑在 Apple Silicon）。開發主機為 Windows，本步驟需在 Mac 執行。
> 目標：轉出 4-bit MLX 版 T1，並用 [zh-tw-prompt-set.md](zh-tw-prompt-set.md) Part 1 做繁中品質對照。

---

## 0. 前置

```bash
# Apple Silicon Mac
python3 -m venv .venv && source .venv/bin/activate
pip install -U mlx-lm huggingface_hub
huggingface-cli login   # 若來源 repo 需授權
```

來源模型：Twinkle AI 官方 `gemma-3-4B-T1-it`（HF repo id 待 model card 確認；優先用官方 fp16/bf16 權重轉換，而非從 GGUF 反向轉）。

---

## 1. 轉 4-bit

```bash
# 以官方 repo 為來源，輸出 4-bit MLX 權重
python -m mlx_lm.convert \
  --hf-path <twinkle-ai/gemma-3-4B-T1-it> \
  --mlx-path ./t1-mlx-4bit \
  -q --q-bits 4 --q-group-size 64
```

備援（sanity check 若不過）：改 `--q-bits 8` 出 8-bit 版對照，判斷是量化損失還是轉換問題。

---

## 2. 繁中 sanity check（與 GGUF 同 prompt 對照）

用 [zh-tw-prompt-set.md](zh-tw-prompt-set.md) **Part 1 的 Q1–Q8**，MLX 版與 llama.cpp GGUF 版跑**完全相同**的
prompt + system prompt + sampling 參數，並排比對。

```bash
python -m mlx_lm.generate \
  --model ./t1-mlx-4bit \
  --system-prompt "你是台灣的 AI 助理，請一律使用繁體中文與台灣用語回答。" \
  --prompt "請用三句話介紹台灣夜市文化，並推薦三樣必吃小吃。" \
  --max-tokens 256 --temp 0.7
```

### 判讀（對齊 prompt set 的判讀重點）
- [ ] 輸出為**繁體中文**、無簡中詞（視頻/軟件/信息/質量…）
- [ ] 台灣語境正確、無明顯幻覺
- [ ] 與 GGUF 版品質**無明顯落差**（若落差大 → 換 8-bit 或回報社群）

---

## 3. 判定與去留

| 結果 | 動作 |
|------|------|
| 4-bit 繁中品質達標 | 進 task-B03（接進 MLX backend）+ task-B02（上傳） |
| 4-bit 劣化、8-bit 達標 | 改用 8-bit；重估 iPhone 記憶體（8-bit 權重更大，回頭確認 A02） |
| 皆異常 | 回報 Twinkle 社群，talk 轉為「轉換品質問題也是社群協作素材」敘事 |

⚠️ **提早做**（本週內）：發現問題才有時間換方案（見 plan.md 風險表）。

---

## 4. 產物落點

- MLX 權重 → 供 task-B03 接進 `lib/core/engine/mlx/` backend
- sanity check 對照結果 → 回寫 `.dev/cycles/2026-07-08-t1-benchmark-talk/construction.md`
- 上傳素材 → 見 [drafts/model-card-zh-tw.md](../../.dev/cycles/2026-07-08-t1-benchmark-talk/drafts/model-card-zh-tw.md)（task-B02）
