import 'dart:io';

import 'format/prompt_format.dart';
import '../llama_ffi.dart';
import '../utils/logger.dart';

final log = Logger('UnifiedLM');


class ModelParams {
  String? modelPath;

  PromptFormat? format;

  /// Number of layers to store in VRAM
  int nGpuLayers = 99;

  ModelParams({
    this.modelPath,
  });
}

class ContextParams {
  /// Maximum number of tokens to predict/generate in response
  int nPredict = 32;

  /// Text context size. 0 = from model
  int nCtx = 512;

  /// Logical maximum batch size that can be submitted to llama_decode
  int nBatch = 512;

  /// Physical maximum batch size
  int nUbatch = 512;

  /// Max number of sequences (i.e. distinct states for recurrent models)
  int nSeqMax = 1;

  /// Number of threads to use for generation
  int nThreads = 8;

  /// Number of threads to use for batch processing
  int nThreadsBatch = 8;
}


class SamplerParams {
  // Top-K sampling
  /// @details Top-K sampling described in academic paper "The Curious Case of Neural Text Degeneration" https://arxiv.org/abs/1904.09751
  int? topK;

  // Top-P (nucleus) sampling
  /// @details Nucleus sampling described in academic paper "The Curious Case of Neural Text Degeneration" https://arxiv.org/abs/1904.09751
  double? topP;

  // Temperature
  /// @details Updates the logits l_i` = l_i/t. When t <= 0.0f, the maximum logit is kept at it's original value, the rest are set to -inf
  double? temp;

  bool get useGreedy => topK == null && topP == null && temp == null;
}

class ChatMessage {
  final String role;
  final String content;
  
  ChatMessage(this.role, this.content);

  @override
  String toString() {
    return 'ChatMessage(role: $role, content: $content)';
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }
}

class UnifiedLM {
  LlamaFFI? _llamaFFI;
  ModelParams _modelParams = ModelParams();
  ContextParams _contextParams = ContextParams();
  SamplerParams _samplerParams = SamplerParams();

  factory UnifiedLM(String modelPath, {bool verbose = false}) {
    final lm = UnifiedLM._internal();
    lm._modelParams = ModelParams(modelPath: modelPath);
    lm._contextParams = ContextParams();
    lm._samplerParams = SamplerParams();
    lm.init(verbose: verbose);
    return lm;
  }

  factory UnifiedLM.withParams(ModelParams modelParams, ContextParams contextParams, SamplerParams samplerParams, {bool verbose = false}) {
    final lm = UnifiedLM._internal();
    lm._modelParams = modelParams;
    lm._contextParams = contextParams;
    lm._samplerParams = samplerParams;
    lm.init(verbose: verbose);
    return lm;
  }

  UnifiedLM._internal();

  bool _initBackend() {
    try {
      if (Platform.isWindows) {
        _llamaFFI!.setLogCallback();
        _llamaFFI!.ggml_backend_load_all();
      } else {
        _llamaFFI!.initBackend();
      }

      return true;
    } catch (e) {
      throw Exception('Failed to initialize backend: $e');
    }
  }

  void init({bool verbose = false}) {
    _llamaFFI = LlamaFFI();
    _llamaFFI!.logVerbose = verbose;

    _initBackend();

    _llamaFFI!.loadModel(_modelParams.modelPath!);
  }

  completion(String prompt) {
    // Create context
    _llamaFFI!.createContext(
      nCtx: _contextParams.nCtx,
      nBatch: _contextParams.nBatch,
      nThreads: _contextParams.nThreads,
      nThreadsBatch: _contextParams.nThreadsBatch,
    );

    // Create sampler
    _llamaFFI!.createSampler(
      useGreedy: _samplerParams.useGreedy,
      topK: _samplerParams.topK,
      topP: _samplerParams.topP,
      temp: _samplerParams.temp,
    );

    // Tokenize prompt
    final nPrompt = _llamaFFI!.tokenizePrompt(prompt);

    // Generate response
    _llamaFFI!.generate(nPrompt, maxTokens: _contextParams.nPredict);
  }

  chat(List<ChatMessage> messages) {
    // Create context
    _llamaFFI!.createContext(
      nCtx: _contextParams.nCtx,
      nBatch: _contextParams.nBatch,
      nThreads: _contextParams.nThreads,
      nThreadsBatch: _contextParams.nThreadsBatch,
    );

    // Create sampler
    _llamaFFI!.createSampler(
      useGreedy: _samplerParams.useGreedy,
      topK: _samplerParams.topK,
      topP: _samplerParams.topP,
      temp: _samplerParams.temp,
    );

    // Apply chat template
    final prompt = _llamaFFI!.applyChatTemplate(messages.map((e) => e.toJson()).toList());

    // Tokenize prompt
    final nPrompt = _llamaFFI!.tokenizePrompt(prompt);

    // Generate response
    _llamaFFI!.generate(nPrompt, maxTokens: _contextParams.nPredict);
  }

  bool dispose() {
    _llamaFFI!.freeBackend();
    return true;
  }
}