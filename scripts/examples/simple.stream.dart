import '../../lib/core/lm.dart';


Future<void> main() async {
  // final modelPath = "R:\\model_gguf\\Gemma-3-Taiwan-270M-it-F16.gguf";
  final modelPath = "R:\\model_gguf\\Llama-3.2-3B-F1-Reasoning-Instruct-Q4_K_M.gguf";
  final model = UnifiedLM(modelPath, verbose: true);

  final prompt = "你好，你是誰？";

  // Streaming completion
  final stream = model.completionStream(prompt, maxTokens: 256);
  await for (final chunk in stream) {
    // Print chunks as they arrive
    // ignore: avoid_print
    print(chunk);
  }

  model.dispose();
}