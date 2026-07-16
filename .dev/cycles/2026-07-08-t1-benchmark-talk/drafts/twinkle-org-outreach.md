# B02 — 上傳到自己 HF repo + 通知 Twinkle org（2026-07-16 改案）

> 任務 task-B02 · **已改案**：不再等 Twinkle org 的 write 權限（時間不可控、卡住了 task-B03）。
> 改成上傳到自己的 HF repo `Bbson/gemma-3-4B-T1-it-MLX-4bit`，org 那邊只發一則禮貌性通知
> （不要求任何權限），維持社群能見度即可。**上傳排 talk 前幾天（約 7/21–7/23）。**

## 目標 repo

`Bbson/gemma-3-4B-T1-it-MLX-4bit` —— 你自己的 HF 帳號，不需要 org 權限，隨時可以上傳。

> ✅ 已從官方 model card 確認：來源 `twinkle-ai/gemma-3-4B-T1-it`（base `google/gemma-3-4b-pt`）；
> 授權 gemma（gated，衍生模型需沿用 Gemma Terms of Use 並標明來源）；無強制 system prompt；
> 官方 sampling temperature 0.6 / top_p 0.95。model card 已在 `drafts/model-card-zh-tw.md` 標明
> 原模型出處與致謝，符合 Gemma 授權對衍生作品的標示要求。

## 給 Twinkle org 的通知訊息草稿（禮貌性，不要求任何權限）

可貼 Discord / 私訊 org admin，純粹是社群禮貌 + 保持能見度，不卡在對方回覆與否：

---

嗨 [admin]，我是 [名字]，在做一場 7/25–26 的分享，主題是端側 LLM 推論與社群模型生態，會用 Little Star App 實測 Twinkle 的 gemma-3-4B-T1-it。

想跟你們說一聲：我把它轉了一個 **4-bit MLX 版**方便在 Apple Silicon 裝置上跑，補了一份**繁中 model card**，上傳到我自己的 HF 帳號了：`Bbson/gemma-3-4B-T1-it-MLX-4bit`。model card 裡有清楚標明原模型出處是你們的 `gemma-3-4B-T1-it`。如果你們之後想收進 org 底下或有其他想法都歡迎說，不用特別回覆也沒關係，就是想讓你們知道一下 😄

---

## 追蹤
- [x] ~~確認官方來源 repo id 與 system prompt 慣例~~ → 已從 model card 確認（見上）
- [ ] 上傳到 `Bbson/gemma-3-4B-T1-it-MLX-4bit`（日期：______）
- [ ] 通知訊息已送出（日期：______，可選——不影響上傳排程，不需等回覆）
- [ ] 排定上傳日（talk 前幾天：約 7/21–7/23）
