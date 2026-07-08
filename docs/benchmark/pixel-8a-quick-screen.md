# A03 — Pixel 8a 可行性快篩 Protocol（去留判定）

> 循環：2026-07-08-t1-benchmark-talk · 任務 task-A03
> ⚠️ **判定要早（7/8–7/11 內）** —— 結果決定 Pixel 8a 是否進 benchmark 矩陣。
> 環境需求：實體 Pixel 8a（8GB RAM）。開發主機為 Windows；需接上裝置實測。

---

## 前提

- 4B Q4_K_M 權重約 2.5GB。Pixel 8a 8GB RAM，扣掉系統與 App，OOM 風險高。
- Little Star 已有 Android llama.cpp backend（`android/app/src/main/jniLibs/arm64-v8a/libllama.so`）。
- 快篩用 GGUF 版（llama.cpp），**不需** MLX（MLX 為 Apple 專屬）。

---

## 快篩步驟

1. **取得權重**：拉 gemma-3-4B-T1-it-GGUF Q4_K_M（同 task-A01）。
2. **佈署到裝置**：透過 App 的 Model Manager 下載，或 `adb push` 到 App 模型資料夾。
3. **冷載入測試**：App 內載入 T1，觀察是否被 Android low-memory killer 中止。
4. **短生成測試**：跑 zh-tw-prompt-set Part 1 的 Q1、Q3（短 prompt），確認能穩定輸出不崩。
5. **記憶體觀測**：
   ```bash
   adb shell dumpsys meminfo <package-name>   # 看 PSS / 峰值
   adb shell "cat /proc/meminfo"              # 看整機可用
   ```
6. **持續性快篩**：連跑 3–5 次生成，確認不是「第一次僥倖」。

---

## 判定表

| 觀測結果 | 判定 | 後續 |
|----------|------|------|
| Q4_K_M 可穩定載入 + 生成 | ✅ **進矩陣** | 納入 C05 完整 benchmark（llama.cpp 欄） |
| Q4_K_M 偶爾 OOM，Q3 穩定 | ⚠️ **降級量化進矩陣** | 用 Q3_K_M 跑；矩陣圖註明「Pixel 8a 需更激進量化」——本身就是好素材 |
| Q3 仍不穩 / 無法載入 | ❌ **轉敘事素材** | 不進矩陣；talk 敘事：「4B 是今天旗艦機的特權，這正是量化與模型選擇重要的原因」 |

三種結果**都是 talk 的資產**：能跑 → 對比數據；要 Q3 → 量化取捨故事；跑不動 → 模型選擇論述。

---

## 產出

- 判定結果 + 記憶體實測數字 → 回寫 `construction.md` 與 plan.md task-A03 狀態
- 若「轉敘事」→ 在 D 線講稿補一段「模型選擇 / 量化重要性」論述
