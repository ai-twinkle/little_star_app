import 'package:ffi/ffi.dart';
import '../../lib/llama_ffi.dart';

void main() {
  final LlamaFFI llamaFFI = LlamaFFI();

  llamaFFI.llama_backend_init();

  final modelParams = llamaFFI.llama_model_default_params();

  final modelPath = 'Llama-3.2-3B-F1-Reasoning-Instruct-Q4_K_M.gguf';
  final pathPtr = modelPath.toNativeUtf8();

  final model = llamaFFI.llama_model_load_from_file(pathPtr, modelParams);

  final contextParams = llamaFFI.llama_context_default_params();

  final context = llamaFFI.llama_init_from_model(model, contextParams);

  llamaFFI.llama_free(context);
  llamaFFI.llama_model_free(model);
}