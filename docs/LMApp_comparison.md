# Gemma3-1B-IT 移動端推理性能實測：Little Star vs Edge Gallery 深度對比

## 📋 測試概述

本文針對兩款熱門的移動端 AI 推理應用進行了系統性的性能測試，旨在評估同一模型（Gemma3-1B-IT）在不同應用實現和平台上的表現差異。

**測試配置**
- **模型**: Gemma3-1B-IT (1B 參數量)
   - Little Star App(768 MB): [unsloth/gemma-3-1b-it-GGUF Q4_K_M](https://huggingface.co/unsloth/gemma-3-1b-it-GGUF/blob/main/gemma-3-1b-it-Q4_K_M.gguf)
   - Edge Gallery(584 MB): [litert-community/Gemma3-1B-IT Q4_ekv4096](https://huggingface.co/litert-community/Gemma3-1B-IT/blob/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv4096.litertlm)
- **測試應用**: 
  - Little Star App (Completion 模式) Version: 0.0.3
  - Edge Gallery (Prompt Lab 模式) Version: 1.0.9 (Android) / 1.0 (iOS)
- **測試參數**:
  - Max Tokens: 1024
  - Temperature: 1.0
  - Top P: 0.95
  - Top K: 64
- **測試平台**:
  - iOS: iPhone 17 Pro (A19 Pro)
  - Android: Google Pixel 8a (Tensor G3)
- **測試案例**:
  - Test 1: 數學求解 `Solve (x+2)^2=0`
  - Test 2: 概念解釋 `What is LLM`

## 📊 性能數據總覽

### iOS (iPhone 17 Pro) 性能表現

| 應用 | 測試項目 | TTFT | Prefill (t/s) | Decode (t/s) | 總耗時 |
|------|---------|------|---------------|--------------|--------|
| **Little Star** | Solve | 96ms | 114.58 | 68.10 | **390ms** |
| **Little Star** | LLM | 185ms | 27.03 | 70.72 | **7.37s** |
| **Edge Gallery** | Solve | 450ms | 22.27 | 45.31 | **2.15s** |
| **Edge Gallery** | LLM | 450ms | 8.86 | 47.12 | **13.46s** |

### Android (Pixel 8a) 性能表現

| 應用 | 測試項目 | TTFT | Prefill (t/s) | Decode (t/s) | 總耗時 | 備註 |
|------|---------|------|---------------|--------------|--------|------|
| **Little Star** | Solve | 316ms | 34.81 | 8.98 | **11.01s** | ✅ 正常 |
| **Little Star** | LLM | 184ms | 27.17 | 8.58 | **47.38s** | ✅ 正常 |
| **Edge Gallery** | Solve | 780ms | 24.33 | 26.29 | **38.86s** | ⚠️ 輸出錯誤 |
| **Edge Gallery** | LLM | 210ms | 62.20 | 26.06 | **28.11s** | ✅ 正常 |

## 🔍 深度分析

### 1. 應用間性能對比（同平台）

#### iOS 平台：Little Star 完勝

**Solve 測試**
- Little Star 耗時僅 **390ms**，Edge Gallery 需要 **2.15s**
- 性能差距：**5.5x**
- Decode 速度：68.10 t/s vs 45.31 t/s (提升 **50%**)
- Prefill 速度：114.58 t/s vs 22.27 t/s (提升 **414%**)

**LLM 測試**
- Little Star 耗時 **7.37s**，Edge Gallery 需要 **13.46s**
- 性能差距：**1.8x**
- Decode 速度相近：70.72 t/s vs 47.12 t/s (提升 **50%**)

#### Android 平台：差距更明顯

**Solve 測試**
- Little Star: **11.01s**
- Edge Gallery: **38.86s** (且輸出錯誤)
- 性能差距：**3.5x**

**LLM 測試**
- Little Star: **47.38s**
- Edge Gallery: **28.11s** (Edge Gallery 在此項測試反而較快)
- 這是 Edge Gallery 唯一勝出的場景

### 2. 跨平台性能對比（同應用）

#### Little Star：iOS 壓倒性優勢

| 測試項目 | iOS 耗時 | Android 耗時 | 性能差距 | Decode 速度對比 |
|---------|---------|-------------|----------|----------------|
| **Solve** | 390ms | 11.01s | **27.2x** | 68.10 vs 8.98 (7.6x) |
| **LLM** | 7.37s | 47.38s | **6.4x** | 70.72 vs 8.58 (8.2x) |

**關鍵觀察**：
- iOS 版本的 Decode 速度穩定維持在 **68-70 t/s**
- Android 版本僅能達到 **8-9 t/s**
- 這種差距顯示 Little Star:
   * 在 iOS 上充分利用了硬體加速 (llama.cpp 後端預設調用 GPU)
   * 在 Android 上未能充分利用硬體加速

#### Edge Gallery：同樣 iOS 領先，但差距較小

| 測試項目 | iOS 耗時 | Android 耗時 | 性能差距 |
|---------|---------|-------------|----------|
| **Solve** | 2.15s | 38.86s | **18.1x** |
| **LLM** | 13.46s | 28.11s | **2.1x** |

**特別注意**：
- Edge Gallery 在 Android Solve 測試中出現**嚴重輸出錯誤**
- 持續輸出 `6^2=36`，未能正確求解方程式
- 這表明除了性能問題，還存在**穩定性和正確性隱患**

### 3. 優勢排名

**總體性能排名**（由快到慢）：
1. 🥇 **Little Star (iOS)** - 絕對領先
2. 🥈 **Edge Gallery (iOS)** - 中規中矩
3. 🥉 **Little Star (Android)** - 可用但較慢
4. 🤔 **Edge Gallery (Android)** - 有些問題會輸出錯誤

## 📌 結論

在 Gemma3-1B-IT 模型的移動端推理測試中，Little Star 在 iOS 平台表現最佳，充分利用了 llama.cpp 的 GPU 硬體加速，Decode 速度達到 68-70 t/s，整體性能領先 Edge Gallery 1.8~5.5 倍。
然而 Little Star 在 Android 上的 Decode 速度僅 8-9 t/s，顯示硬體加速未被充分調用，仍有優化空間。Edge Gallery 則在 Android 平台出現輸出錯誤的穩定性問題。
總結：iOS 選 Little Star 絕對領先，Android 選 Little Star 仍是較佳選擇，但需關注硬體加速優化。
