---
license: gemma
language:
  - zh
base_model: twinkle-ai/gemma-3-4B-T1-it   # ⚠️ 待 B02 向 org 確認正確 repo id
tags:
  - mlx
  - gemma3
  - traditional-chinese
  - twinkle-ai
pipeline_tag: text-generation
---

# gemma-3-4B-T1-it — MLX 4-bit（繁體中文 Model Card）

> ⚠️ 草稿（task-B02）。上傳前需回填：正確 base_model repo id、實測數據、授權連結、system prompt 慣例。

本模型是 [Twinkle AI](https://huggingface.co/twinkle-ai) `gemma-3-4B-T1-it`（Gemma 3 繁體中文微調）的
**MLX 4-bit 量化版**，透過 [`mlx-lm`](https://github.com/ml-explore/mlx-examples) 轉換，供 Apple Silicon
裝置（iPhone / iPad / Mac）端側推論使用。

## 用途

- 端側繁體中文對話與生成，聚焦台灣語境
- 在 [Little Star App](https://github.com/ai-twinkle/little_star_app) 的 MLX backend 上離線運行

## 如何使用（mlx-lm）

```python
from mlx_lm import load, generate

model, tokenizer = load("twinkle-ai/gemma-3-4B-T1-it-MLX-4bit")
prompt = "請用三句話介紹台灣夜市文化，並推薦三樣必吃小吃。"
# 建議 system prompt（待官方 model card 確認）：
#   你是台灣的 AI 助理，請一律使用繁體中文與台灣用語回答。
print(generate(model, tokenizer, prompt=prompt, max_tokens=256))
```

## 量化細節

| 項目 | 值 |
|------|----|
| 來源 | `twinkle-ai/gemma-3-4B-T1-it`（官方權重） |
| 方法 | `mlx_lm.convert -q --q-bits 4 --q-group-size 64` |
| 位元 | 4-bit |
| 約權重大小 | ~2.5 GB（待實測回填） |

## 繁中品質對照

用固定繁中 prompt 集（Little Star `docs/benchmark/zh-tw-prompt-set.md`）與 GGUF Q4_K_M 版對照，
繁體用字與台灣語境品質 [達標 / 待回填實測]。

## 端側 Benchmark（Little Star 實測）

| 裝置 | 載入時間 | TTFT | decode t/s | 峰值記憶體 |
|------|----------|------|-----------|-----------|
| iPhone 17 Pro | 待回填 | 待回填 | 待回填 | 待回填 |

## 授權

沿用 Gemma 授權條款，並遵循 Twinkle AI 原模型授權。使用前請閱讀 Gemma Terms of Use。

## 致謝

- 原模型：Twinkle AI
- 量化與繁中 model card：[你的名字 / handle]
- 端側整合與 benchmark：Little Star App
