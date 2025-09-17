import 'dart:io';

import 'format/prompt_format.dart';
import 'engine/llama_cpp/llama_cpp_ffi.dart';
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
  LlamaCppFFI? _ffi;
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
        _ffi!.setLogCallback();
        _ffi!.ggml_backend_load_all();
      } else {
        _ffi!.initBackend();
      }

      return true;
    } catch (e) {
      throw Exception('Failed to initialize backend: $e');
    }
  }

  void init({bool verbose = false}) {
    _ffi = LlamaCppFFI();
    _ffi!.logVerbose = verbose;

    _initBackend();

    _ffi!.loadModel(_modelParams.modelPath!);
  }

  /// Returns the number of tokens for a given prompt using the loaded model's vocab.
  /// Note: This also prepares an internal batch in the FFI layer; use only for measurement.
  int countPromptTokens(String prompt) {
    if (_ffi == null) {
      throw StateError('FFI not initialized');
    }
    return _ffi!.tokenizePrompt(prompt);
  }

  String completion(String prompt) {
    // Create context
    _ffi!.createContext(
      nCtx: _contextParams.nCtx,
      nBatch: _contextParams.nBatch,
      nThreads: _contextParams.nThreads,
      nThreadsBatch: _contextParams.nThreadsBatch,
    );

    // Create sampler
    _ffi!.createSampler(
      useGreedy: _samplerParams.useGreedy,
      topK: _samplerParams.topK,
      topP: _samplerParams.topP,
      temp: _samplerParams.temp,
    );

    // Tokenize prompt
    final nPrompt = _ffi!.tokenizePrompt(prompt);

    // Generate response
    final result = _ffi!.generate(nPrompt, maxTokens: _contextParams.nPredict);
    return result;
  }

  /// Streaming completion that yields decoded text chunks as they are generated.
  /// Ensures the context is created before delegating to the FFI streaming generator.
  Stream<String> completionStream(
    String prompt, {
    int? maxTokens,
    List<String>? stopSequences,
  }) {
    if (_ffi == null) {
      throw StateError('FFI not initialized');
    }

    // Ensure context exists
    _ffi!.createContext(
      nCtx: _contextParams.nCtx,
      nBatch: _contextParams.nBatch,
      nThreads: _contextParams.nThreads,
      nThreadsBatch: _contextParams.nThreadsBatch,
    );

    // Create sampler per configured params
    _ffi!.createSampler(
      useGreedy: _samplerParams.useGreedy,
      topK: _samplerParams.topK,
      topP: _samplerParams.topP,
      temp: _samplerParams.temp,
    );

    // Tokenize prompt to set internal batch and get prompt token count
    final nPrompt = _ffi!.tokenizePrompt(prompt);

    // Stream using FFI generateStream
    return _ffi!.generateStream(
      nPrompt,
      maxTokens: maxTokens ?? _contextParams.nPredict,
    );
  }

  String chat(List<ChatMessage> messages) {
    // Create context
    _ffi!.createContext(
      nCtx: _contextParams.nCtx,
      nBatch: _contextParams.nBatch,
      nThreads: _contextParams.nThreads,
      nThreadsBatch: _contextParams.nThreadsBatch,
    );

    // Create sampler
    _ffi!.createSampler(
      useGreedy: _samplerParams.useGreedy,
      topK: _samplerParams.topK,
      topP: _samplerParams.topP,
      temp: _samplerParams.temp,
    );

    // Apply chat template
    final prompt = _ffi!.applyChatTemplate(messages.map((e) => e.toJson()).toList());

    // Tokenize prompt
    final nPrompt = _ffi!.tokenizePrompt(prompt);

    // Generate response
    final result = _ffi!.generate(nPrompt, maxTokens: _contextParams.nPredict);
    return result;
  }

  bool dispose() {
    _ffi!.freeBackend();
    return true;
  }
}