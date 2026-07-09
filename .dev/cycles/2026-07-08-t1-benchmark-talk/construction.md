# 建造：T1 整合、Benchmark Harness 與 Talk 產出物

> 循環：2026-07-08-t1-benchmark-talk
> 階段：Construction
> 狀態：🔄 進行中 — A03 / B01 / B02 早期關卡啟動
> 最後更新：2026-07-09（Windows 開發機；素材已備齊，等實體資源執行）

---

## 🔀 接手快照（換開發環境時先讀這段）

**目前為止**：循環已開，探索/定義完成，A03/B01/B02 的「可在無裝置環境備妥的資產」已全部產出並提交
（commits：`704f9f1` 開循環、`98a5985` 素材、`a61e4f0` 回填官方 card）。三件事都卡在**實體資源**，需在有 Mac /
Pixel 8a / HF gated 登入的環境執行。

**前置（一次性）**：到 https://huggingface.co/twinkle-ai/gemma-3-4B-T1-it 接受 gemma 授權，`huggingface-cli login`。

**三條待執行線（照文件跑，跑完回寫「待用戶回填」表 + plan.md 狀態）**：

| 任務 | 環境 | 照這份文件執行 | 回填什麼 |
|------|------|----------------|----------|
| B02 org 協調 | 任意（送訊息） | [drafts/twinkle-org-outreach.md](drafts/twinkle-org-outreach.md) | 送出日 + write 權限結果 |
| B01 MLX 轉換 | **Apple Silicon Mac** | [docs/benchmark/mlx-t1-conversion-runbook.md](../../../docs/benchmark/mlx-t1-conversion-runbook.md) | 4-bit vs GGUF 繁中對照結果 |
| A03 Pixel 快篩 | **實體 Pixel 8a** | [docs/benchmark/pixel-8a-quick-screen.md](../../../docs/benchmark/pixel-8a-quick-screen.md) | 記憶體數字 + 去留判定 |

**共用**：所有品質對照/benchmark 都用同一份 [docs/benchmark/zh-tw-prompt-set.md](../../../docs/benchmark/zh-tw-prompt-set.md)
（sampling 固定 temp 0.6 / top_p 0.95）。

**尚未動的**：A01（T1 GGUF 進 llama.cpp backend 驗 template）、A02（iPhone 記憶體/context）、C 線 harness、D 線。
下一個純軟體、不卡裝置可推進的是 **C01（harness 埋量測 TDD）**。

---

## 進行中任務

### task-A03: Pixel 8a 可行性快篩 — [IN_PROGRESS]
- ✅ 快篩 protocol 定版 → [docs/benchmark/pixel-8a-quick-screen.md](../../../docs/benchmark/pixel-8a-quick-screen.md)
- ✅ 判定表（進矩陣 / 降 Q3 / 轉敘事）三分支皆對應 talk 素材
- ⏳ **需在裝置執行**（Windows 主機無法代跑）：拉 Q4_K_M → App/adb 佈署 → 冷載入 + 短生成 + `dumpsys meminfo`
- ⚠️ 判定要早（7/8–7/11）

### task-B01: MLX 4-bit 轉換 + 繁中 sanity check — [DONE] ✅ 2026-07-09
- ✅ 轉換 + sanity check runbook 定版 → [docs/benchmark/mlx-t1-conversion-runbook.md](../../../docs/benchmark/mlx-t1-conversion-runbook.md)
- ✅ 對照用 prompt 綁定 zh-tw-prompt-set Part 1（與 GGUF 同 prompt）
- ✅ 確認 repo 內已有 `GemmaChatTemplate`（system prompt 注入第一個 user turn，符合 Gemma 慣例）
- ✅ **已在 Apple Silicon Mac 執行**：`mlx_lm.convert --hf-path twinkle-ai/gemma-3-4B-T1-it -q --q-bits 4 --q-group-size 64`
  - 量化結果：4.501 bits/weight，輸出 2.4GB（`model.safetensors`）
  - Prompt: ~50 tokens @ ~285–300 tok/s；Generation: 256 tokens @ ~51.7–52.0 tok/s（穩定，8 題皆同量級）
  - Peak memory：穩定在 **2.68 GB**（8 題皆同）
- ✅ Q1–Q8 繁中 sanity check 完成（見下方判定）
- ⚠️ **與 GGUF 版正式並排比對尚未執行**（task-A01 GGUF+llama.cpp 驗證尚未動工，見接手快照「尚未動的」）；
  本次僅完成 MLX 版獨立品質判讀，達標。待 A01 跑完後補上真正並排對照。

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

## 官方 model card 已確認事實（2026-07-09，[T1 repo](https://huggingface.co/twinkle-ai/gemma-3-4B-T1-it)）

- 來源 repo：`twinkle-ai/gemma-3-4B-T1-it`；base：`google/gemma-3-4b-pt`
- 授權：gemma，**HF gated** → 下載/轉換前需接受授權並登入（影響 A01/A03/B01）
- 語言：繁中 + 英文；聚焦台灣人文社會（法律/教育/對話）
- system prompt：**無強制**，官方範例為選用 → benchmark 統一用一句台灣定調 system prompt
- 官方 sampling：`temperature 0.6`、`top_p 0.95`（範例 max_tokens 1500）→ 已寫入 prompt set / runbook
- chat template（含 **tool-calling**）內嵌於 `tokenizer_config` = template 真實來源
- context length：card 未載明（Gemma 3 4B 通常長 context，端側需自限；待 A02 依 KV cache 拍板）

⚠️ **A01/B03 注意**：repo 內 `GemmaChatTemplate` 是「純對話」Gemma 模板；T1 官方模板含 tool-calling 結構。
本次 benchmark/demo 走純對話，純模板即可；但跨 backend 一致性測試（B03）應以 `tokenizer_config` 的官方模板為對照基準。

## B01 繁中 sanity check 判定（2026-07-09，Apple Silicon Mac）

| ID | 判讀重點 | 結果 |
|----|----------|------|
| Q1 | 小吃在地性、繁體用字 | ✅ 繁體正確，臭豆腐/蚵仔煎/珍珠奶茶在地性正確 |
| Q2 | 台灣流行語理解 | ✅ 揪團/小確幸定義與舉例正確 |
| Q3 | 在地交通常識、不編造 | ⚠️ 有瑕疵：誤將「忠孝復興站」與台北車站混為一談，且路線名稱前後不一致（1062 皇冠北海岸線 → 黃金福隆線） |
| Q4 | 制度正確性 | ✅ 統一發票制度描述正確（含對獎機制、20% 印花稅） |
| Q5 | 語氣分層、在地制度 | ✅ 颱風假標準（風力/雨量）說明正確，語氣貼近國中生 |
| Q6 | 生成品質、繁中語感 | ✅ 語感自然（達標，但受下方技術瑕疵影響最明顯） |
| Q7 | 語用理解 | ✅ 正確判讀為稱讚，CP 值解釋到位 |
| Q8 | 自我一致：務必用繁體 | ✅ 全程繁體，且正確舉出簡中對照詞（視頻/質量 → 影片/品質） |

**技術瑕疵（非模型品質問題）**：`mlx_lm.generate` 未在 `<end_of_turn>` 停止生成，導致 Q1/Q2/Q6 在正確答案後
出現重複或英文夾雜的雜訊（尤其 Q6 出現 `<translation>` 標籤迴圈）。**需在 task-B03 接進 MLX backend 時
正確設定 stop token/EOS**，否則產品端會把這段雜訊顯示給使用者。

**判定：4-bit 繁中品質達標** → 進 task-B03（接進 MLX backend）+ task-B02（上傳協調，用戶已在進行）。
Q3 的地名瑕疵屬個案幻覺，非系統性問題，記錄供 D02 demo 選題時避開類似問法。

## 待用戶回填（回來後回寫此檔 + plan.md 狀態）

| 來源 | 待回填 |
|------|--------|
| A03 | Pixel 8a 記憶體實測數字 + 去留判定（等待裝置透過 USB 連接，adb 尚未偵測到） |
| B01 | ✅ 已完成，見上方判定表 |
| B02 | write 權限取得 + 協調請求送出日 + 上傳排程 |

---

## 提交記錄

| 日期 | 提交 | 內容 |
|------|------|------|
| 2026-07-08 | `704f9f1` | docs(workflow): 開循環（exploration + plan） |
| 2026-07-08 | `98a5985` | benchmark prompt set + B01/A03 runbook + B02 drafts |
| 2026-07-09 | (本次) | 回填官方 model card 事實（base/gated/sampling/template）到 4 份文件 |
