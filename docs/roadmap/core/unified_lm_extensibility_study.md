# UnifiedLM 推理引擎可擴展性研究與未來規劃

## 1. 現狀分析 (Current State)

目前的 `UnifiedLM` 設計採用了直接耦合 (Tight Coupling) 的方式與 `llama.cpp` 的 FFI 綁定層互動。

### 現有層次結構
- **UI/ViewModel**: 呼叫 `UnifiedLM` API。
- **UnifiedLM (lib/core/lm.dart)**: 封裝了模型載入、文字生成等邏輯，但直接持有 `LlamaCppFFI` 實例。
- **LlamaCppFFI (lib/core/engine/llama_cpp/)**: 直接透過 Dart FFI 呼叫 `llama.cpp` 的 C API。

### 觀察到的限制
1. **引擎固定**：架構專為 `llama.cpp` 設計，難以直接切換到其他引擎（如 LiteRT）。
2. **缺乏抽象**：推理引擎的操作（Init, Load, Predict, Free）沒有通用的介面定義。
3. **平台綁定**：FFI 邏輯中夾雜了過多的平台判斷（Windows/Android/iOS），不利於維護。

---

## 2. 目標架構：多引擎支援 (Multi-Engine Architecture)

為了支援未來底層可能的技術變革（如效能實測中觀察到的硬體加速能力差異），建議將推理層抽象化。

### 建議的抽象介面：`InferenceEngine`

```dart
abstract class InferenceEngine {
  String get name;
  List<String> get supportedFormats; // ['gguf', 'tflite', 'onnx', 'pte']

  Future<void> initialize({bool verbose = false});
  Future<void> loadModel(String modelPath, {ModelParams? params});
  
  // 文字生成核心 API
  String complete(String prompt, {int? maxTokens});
  Stream<String> completeStream(String prompt, {int? maxTokens});
  
  // 輔助功能
  int countTokens(String text);
  String applyChatTemplate(List<ChatMessage> messages);
  
  void dispose();
}
```

---

## 3. 潛在引擎整合方案

### 1. LiteRT (TF Lite)
- **目標格式**：`.tflite`
- **優勢**：Android 平台上與 Google 硬體（TPU/NPU）整合度高，輕量化。
- **適用場景**：小型 Language Models 或 Embedding 模型。

### 2. ExecuTorch (PyTorch)
- **目標格式**：`.pte` (ExecuTorch 專屬格式)
- **優勢**：Meta 官方力推，支援 PyTorch 生態系，對 Llama 系列模型有深度優化。
- **挑戰**：目前 Flutter FFI 整合尚需手動實作 C++ 橋接。

### 3. ONNX Runtime
- **目標格式**：`.onnx`
- **優勢**：跨平台相容性最強，支援量化格式豐富（如 INT8, FP16）。
- **挑戰**：模型檔案通常較大，且在移動端的硬體委派 (Delegates) 設定較複雜。

---

## 4. 實作 Roadmap

### 第一階段：解耦與重構 (Refactor)
- [ ] 定義 `InferenceEngine` 抽象類別。
- [ ] 將現有的 `llama_cpp_ffi.dart` 邏輯封裝進 `LlamaCppEngine` 類別中。
- [ ] 重構 `UnifiedLM` 使其透過依賴注入 (Dependency Injection) 接受任何實作 `InferenceEngine` 的物件。

### 第二階段：引擎工廠與自動偵測 (Selection)
- [ ] 實作 `EngineRegistry`，根據副檔名自動選擇對應引擎。
- [ ] 支援在初始化時強制指定引擎名稱。

### 第三階段：擴展支援 (Extension)
- [ ] **LiteRT (TFLite)**：優先實作，用於處理特定的小型特定任務模型。
- [ ] **ONNX Runtime**：提供通用的跨平台推理備案。
- [ ] **ExecuTorch**：跟進 PyTorch 行動端技術，作為高品質 Llama 系列推理的替代方案。

---

## 5. 性能對比與選擇策略 (Selection Strategy)

根據 `docs/LMApp_comparison.md` 的測試結果，未來應針對不同平台動態選擇引擎：
- **iOS 平台**：優先選擇支援 **Metal/Neural Engine** 的引擎（如目前已優化的 `llama.cpp`）。
- **Android 平台**：研究 **LiteRT (NNAPI)** 是否能顯著提升目前在 Pixel 系列設備上 Decode 速度偏低（8-9 t/s）的問題。

---

*本文檔由 Antigravity 整理於 2024年12月，作為 Little Star App 長期演進的技術參考。*
