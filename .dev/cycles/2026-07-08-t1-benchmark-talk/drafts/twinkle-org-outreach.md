# B02 — Twinkle AI Org 上傳協調（本週開口）

> 任務 task-B02 · ⚠️ 時間不可控，**本週（7/8–7/11）就要提出**，上傳排 talk 前幾天。

## 要向 org 取得的東西
1. Twinkle AI HF org 的 **write 權限**（或請 org admin 代為建立 repo 並授權）
2. 確認目標 repo 命名（建議 `twinkle-ai/gemma-3-4B-T1-it-MLX-4bit` 之類）
3. 確認官方來源權重 repo id（供 B01 轉換用）

## 建議訊息草稿（可貼 Discord / 私訊 org admin）

---

嗨 [admin]，我是 [名字]，在做一場 7/25–26 的分享，主題是端側 LLM 推論與社群模型生態，會用 Little Star App 實測 Twinkle 的 gemma-3-4B-T1-it。

想請教兩件事：

1. 我打算用 `mlx_lm.convert` 出一個 **4-bit MLX 版**，方便在 Apple Silicon 裝置上跑，並補一份**繁中 model card**。想上傳到 Twinkle AI org 底下，方便社群直接取用。可以給我上傳權限，或由你們開 repo 我提 PR / 上傳嗎？

2. 官方 `gemma-3-4B-T1-it` 的來源權重 repo id 是哪個？想用官方權重直接轉，避免從 GGUF 反轉失真。model card 裡有沒有建議的 system prompt 慣例？

時間點上，我想抓在 talk 前幾天上傳（新鮮度最高），所以想先把權限/流程敲定。感謝！

---

## 追蹤
- [ ] 已送出請求（日期：______）
- [ ] 取得 write 權限 / 確認上傳流程
- [ ] 確認官方來源 repo id 與 system prompt 慣例（回填 A01/B01）
- [ ] 排定上傳日（talk 前幾天：約 7/21–7/23）
