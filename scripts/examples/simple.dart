import '../../lib/core/lm.dart';


void main() {
  // final modelPath = "R:\\model_gguf\\Gemma-3-Taiwan-270M-it-F16.gguf";
  final modelPath = "R:\\model_gguf\\Llama-3.2-3B-F1-Reasoning-Instruct-Q4_K_M.gguf";
  final model = UnifiedLM(modelPath);
  model.completion("你好，你是誰？");
  model.dispose();
}