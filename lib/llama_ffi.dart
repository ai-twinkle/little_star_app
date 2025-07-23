import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

// Union for kv override values
final class LlamaModelKvOverrideValue extends ffi.Union {
  @ffi.Int64()
  external int valI64;

  @ffi.Double()
  external double valF64;

  @ffi.Bool()
  external bool valBool;

  @ffi.Array<ffi.Char>(128)
  external ffi.Array<ffi.Char> valStr;
}

// Struct for llama_model_kv_override
final class llama_model_kv_override extends ffi.Struct {
  @ffi.Int32()
  external int tag; // enum llama_model_kv_override_type

  @ffi.Array<ffi.Char>(128)
  external ffi.Array<ffi.Char> key;

  external LlamaModelKvOverrideValue value;
}

final class ggml_backend_device extends ffi.Opaque {}

typedef ggml_backend_dev_t = ffi.Pointer<ggml_backend_device>;

// Struct for llama_model_tensor_buft_override
final class llama_model_tensor_buft_override extends ffi.Struct {
  external ffi.Pointer<Utf8> pattern;
  external ffi.Pointer<ffi.Void> buft; // ggml_backend_buffer_type_t
}

final class llama_model extends ffi.Opaque {}

// Main llama_model_params struct
final class llama_model_params extends ffi.Struct {
  // NULL-terminated list of devices to use for offloading (if NULL, all available devices are used)
  external ffi.Pointer<ggml_backend_dev_t> devices;

  // NULL-terminated list of buffer types to use for tensors that match a pattern
  external ffi.Pointer<llama_model_tensor_buft_override> tensor_buft_overrides;

  @ffi.Int32()
  external int n_gpu_layers; // number of layers to store in VRAM

  @ffi.Int32()
  external int split_mode; // how to split the model across multiple GPUs (enum llama_split_mode)

  @ffi.Int32()
  external int main_gpu; // the GPU that is used for the entire model when split_mode is LLAMA_SPLIT_MODE_NONE

  // proportion of the model (layers or rows) to offload to each GPU, size: llama_max_devices()
  external ffi.Pointer<ffi.Float> tensor_split;

  // Called with a progress value between 0.0 and 1.0. Pass NULL to disable.
  // If the provided progress_callback returns true, model loading continues.
  // If it returns false, model loading is immediately aborted.
  external ffi.Pointer<ffi.NativeFunction<LlamaProgressCallbackNative>> progress_callback;

  // context pointer passed to the progress callback
  external ffi.Pointer<ffi.Void> progress_callback_user_data;

  // override key-value pairs of the model meta data
  external ffi.Pointer<llama_model_kv_override> kv_overrides;

  // Keep the booleans together to avoid misalignment during copy-by-value.
  @ffi.Bool()
  external bool vocab_only;    // only load the vocabulary, no weights

  @ffi.Bool()
  external bool use_mmap;      // use mmap if possible

  @ffi.Bool()
  external bool use_mlock;     // force system to keep model in RAM

  @ffi.Bool()
  external bool check_tensors; // validate model tensor data
}

final class llama_vocab extends ffi.Opaque {} // struct llama_vocab

final class llama_context extends ffi.Opaque {}

final class llama_context_params extends ffi.Struct {
  @ffi.Uint32()
  external int n_ctx;             // text context, 0 = from model

  @ffi.Uint32()
  external int n_batch;           // logical maximum batch size that can be submitted to llama_decode

  @ffi.Uint32()
  external int n_ubatch;          // physical maximum batch size

  @ffi.Uint32()
  external int n_seq_max;         // max number of sequences (i.e. distinct states for recurrent models)

  @ffi.Int32()
  external int n_threads;         // number of threads to use for generation

  @ffi.Int32()
  external int n_threads_batch;   // number of threads to use for batch processing

  @ffi.Int32()
  external int rope_scaling_type; // RoPE scaling type, from enum llama_rope_scaling_type

  @ffi.Int32()
  external int pooling_type;      // whether to pool (sum) embedding results by sequence id

  @ffi.Int32()
  external int attention_type;    // attention type to use for embeddings

  @ffi.Float()
  external double rope_freq_base;   // RoPE base frequency, 0 = from model

  @ffi.Float()
  external double rope_freq_scale;  // RoPE frequency scaling factor, 0 = from model

  @ffi.Float()
  external double yarn_ext_factor;  // YaRN extrapolation mix factor, negative = from model

  @ffi.Float()
  external double yarn_attn_factor; // YaRN magnitude scaling factor

  @ffi.Float()
  external double yarn_beta_fast;   // YaRN low correction dim

  @ffi.Float()
  external double yarn_beta_slow;   // YaRN high correction dim

  @ffi.Uint32()
  external int yarn_orig_ctx;       // YaRN original context size

  @ffi.Float()
  external double defrag_thold;     // defragment the KV cache if holes/size > thold, <= 0 disabled (default)

  external ffi.Pointer<ffi.Void> cb_eval;        // ggml_backend_sched_eval_callback
  external ffi.Pointer<ffi.Void> cb_eval_user_data;

  @ffi.Int32()
  external int type_k; // data type for K cache [EXPERIMENTAL] (enum ggml_type)

  @ffi.Int32()
  external int type_v; // data type for V cache [EXPERIMENTAL] (enum ggml_type)

  external ffi.Pointer<ffi.Void> abort_callback;      // ggml_abort_callback
  external ffi.Pointer<ffi.Void> abort_callback_data;

  // Keep the booleans together and at the end of the struct to avoid misalignment during copy-by-value.
  @ffi.Bool()
  external bool embeddings;  // if true, extract embeddings (together with logits)

  @ffi.Bool()
  external bool offload_kqv; // offload the KQV ops (including the KV cache) to GPU

  @ffi.Bool()
  external bool flash_attn;  // use flash attention [EXPERIMENTAL]

  @ffi.Bool()
  external bool no_perf;     // measure performance timings

  @ffi.Bool()
  external bool op_offload;  // offload host tensor operations to device

  @ffi.Bool()
  external bool swa_full;    // use full-size SWA cache
}

// Token typedefs & structs
typedef llama_token = ffi.Int32;

final class llama_token_data extends ffi.Struct {
  @llama_token()
  external int id;

  @ffi.Float()
  external double logit;

  @ffi.Float()
  external double p;
}

final class llama_token_data_array extends ffi.Struct {
  external ffi.Pointer<llama_token_data> data;

  @ffi.Size()
  external int size;

  @ffi.Int64()
  external int selected;

  @ffi.Bool()
  external bool sorted;
}

// Sampler structs & typedefs
final class llama_sampler_chain_params extends ffi.Struct {
  @ffi.Bool()
  external bool no_perf;
}

final class llama_sampler_chain extends ffi.Opaque {}

final class llama_sampler_i extends ffi.Struct {
  external ffi.Pointer<
          ffi.NativeFunction<
              ffi.Pointer<ffi.Char> Function(ffi.Pointer<llama_sampler> smpl)>>
      name;

  external ffi.Pointer<
      ffi.NativeFunction<
          ffi.Void Function(
              ffi.Pointer<llama_sampler> smpl, llama_token token)>> accept;

  external ffi.Pointer<
      ffi.NativeFunction<
          ffi.Void Function(ffi.Pointer<llama_sampler> smpl,
              ffi.Pointer<llama_token_data_array> cur_p)>> apply;

  external ffi.Pointer<
          ffi
          .NativeFunction<ffi.Void Function(ffi.Pointer<llama_sampler> smpl)>>
      reset;

  external ffi.Pointer<
      ffi.NativeFunction<
          ffi.Pointer<llama_sampler> Function(
              ffi.Pointer<llama_sampler> smpl)>> clone;

  external ffi.Pointer<
      ffi
      .NativeFunction<ffi.Void Function(ffi.Pointer<llama_sampler> smpl)>> free;
}

typedef llama_sampler_context_t = ffi.Pointer<ffi.Void>;

final class llama_sampler extends ffi.Struct {
  external ffi.Pointer<llama_sampler_i> iface;

  external llama_sampler_context_t ctx;
}

//
typedef llama_pos = ffi.Int32;
typedef llama_seq_id = ffi.Int32;

final class llama_batch extends ffi.Struct {
  @ffi.Int32()
  external int n_tokens;

  external ffi.Pointer<llama_token> token;

  external ffi.Pointer<ffi.Float> embd;

  external ffi.Pointer<llama_pos> pos;

  external ffi.Pointer<ffi.Int32> n_seq_id;

  external ffi.Pointer<ffi.Pointer<llama_seq_id>> seq_id;

  external ffi.Pointer<ffi.Int8> logits;
}

// Simple function signatures without complex structs
typedef LlamaInitBackendNative = ffi.Void Function();
typedef LlamaInitBackend = void Function();

typedef LlamaBackendFreeNative = ffi.Void Function();
typedef LlamaBackendFree = void Function();
// Function pointer typedef for progress callback
typedef LlamaProgressCallbackNative = ffi.Bool Function(ffi.Float progress, ffi.Pointer<ffi.Void> userData);
typedef LlamaProgressCallback = bool Function(double progress, ffi.Pointer<ffi.Void> userData);

// Model loading functions
typedef LlamaModelDefaultParamsNative = llama_model_params Function();
typedef LlamaModelDefaultParams = llama_model_params Function();

typedef LlamaModelLoadFromFileNative = ffi.Pointer<llama_model> Function(ffi.Pointer<ffi.Char> pathModel, llama_model_params params);
typedef LlamaModelLoadFromFile = ffi.Pointer<llama_model> Function(ffi.Pointer<ffi.Char> pathModel, llama_model_params params);

typedef LlamaModelGetVocabNative = ffi.Pointer<llama_vocab> Function(ffi.Pointer<llama_model> model);
typedef LlamaModelGetVocab = ffi.Pointer<llama_vocab> Function(ffi.Pointer<llama_model> model);

// Context functions
typedef LlamaNewContextWithModelNative = ffi.Pointer<llama_context> Function(ffi.Pointer<llama_model> model, llama_context_params params);
typedef LlamaNewContextWithModel = ffi.Pointer<llama_context> Function(ffi.Pointer<llama_model> model, llama_context_params params);

typedef LlamaContextDefaultParamsNative = llama_context_params Function();
typedef LlamaContextDefaultParams = llama_context_params Function();

typedef LlamaInitFromModelNative = ffi.Pointer<llama_context> Function(ffi.Pointer<llama_model> model, llama_context_params params);
typedef LlamaInitFromModel = ffi.Pointer<llama_context> Function(ffi.Pointer<llama_model> model, llama_context_params params);

// Vocab functions
typedef LlamaVocabIsEogNative = ffi.Bool Function(ffi.Pointer<llama_vocab> vocab, ffi.Int32 token);
typedef LlamaVocabIsEog = bool Function(ffi.Pointer<llama_vocab> vocab, int token);

// Tokenization functions
typedef LlamaTokenizeNative = ffi.Int32 Function(ffi.Pointer<llama_vocab> vocab, ffi.Pointer<ffi.Char> text, ffi.Int32 textLen, ffi.Pointer<llama_token> tokens, ffi.Int32 nMaxTokens, ffi.Bool addBos, ffi.Bool special);
typedef LlamaTokenize = int Function(ffi.Pointer<llama_vocab> vocab, ffi.Pointer<ffi.Char> text, int textLen, ffi.Pointer<llama_token> tokens, int nMaxTokens, bool addBos, bool special);

typedef LlamaTokenToPieceNative = ffi.Int32 Function(ffi.Pointer<llama_vocab> vocab, ffi.Int32 token, ffi.Pointer<ffi.Char> buf, ffi.Int32 length, ffi.Int32 lstrip, ffi.Bool special);
typedef LlamaTokenToPiece = int Function(ffi.Pointer<llama_vocab> vocab, int token, ffi.Pointer<ffi.Char> buf, int length, int lstrip, bool special);

// Sampler functions
typedef LlamaSamplerChainDefaultParamsNative = llama_sampler_chain_params Function();
typedef LlamaSamplerChainDefaultParams = llama_sampler_chain_params Function();

typedef LlamaSamplerChainInitNative = ffi.Pointer<llama_sampler> Function(llama_sampler_chain_params params);
typedef LlamaSamplerChainInit = ffi.Pointer<llama_sampler> Function(llama_sampler_chain_params params);

typedef LlamaSamplerChainAddNative = ffi.Void Function(ffi.Pointer<llama_sampler> chain, ffi.Pointer<llama_sampler> sampler);
typedef LlamaSamplerChainAdd = void Function(ffi.Pointer<llama_sampler> chain, ffi.Pointer<llama_sampler> sampler);

typedef LlamaSamplerInitGreedyNative = ffi.Pointer<llama_sampler> Function();
typedef LlamaSamplerInitGreedy = ffi.Pointer<llama_sampler> Function();

typedef LlamaSamplerSampleNative = ffi.Int32 Function(ffi.Pointer<llama_sampler> sampler, ffi.Pointer<llama_context> ctx, ffi.Int32 idx);
typedef LlamaSamplerSample = int Function(ffi.Pointer<llama_sampler> sampler, ffi.Pointer<llama_context> ctx, int idx);

// Batch functions
typedef LlamaBatchGetOneNative = llama_batch Function(ffi.Pointer<llama_token> tokens, ffi.Int32 nTokens);
typedef LlamaBatchGetOne = llama_batch Function(ffi.Pointer<llama_token> tokens, int nTokens);

// Encode Decode functions
typedef LlamaDecodeNative = ffi.Int32 Function(ffi.Pointer<llama_context> ctx, llama_batch batch);
typedef LlamaDecode = int Function(ffi.Pointer<llama_context> ctx, llama_batch batch);

// Free functions
typedef LlamaFreeNative = ffi.Void Function(ffi.Pointer ctx);
typedef LlamaFree = void Function(ffi.Pointer ctx);

typedef LlamaModelFreeNative = ffi.Void Function(ffi.Pointer model);
typedef LlamaModelFree = void Function(ffi.Pointer model);

typedef LlamaSamplerFreeNative = ffi.Void Function(ffi.Pointer<llama_sampler> sampler);
typedef LlamaSamplerFree = void Function(ffi.Pointer<llama_sampler> sampler);

// Simple test function - most llama.cpp builds have this
typedef LlamaTimeUsNative = ffi.Int64 Function();
typedef LlamaTimeUs = int Function();

typedef LlamaPerfContextPrintNative = ffi.Void Function(ffi.Pointer<llama_context> ctx);
typedef LlamaPerfContextPrint = void Function(ffi.Pointer<llama_context> ctx);

typedef LlamaPerfSamplerPrintNative = ffi.Void Function(ffi.Pointer<llama_sampler> sampler);
typedef LlamaPerfSamplerPrint = void Function(ffi.Pointer<llama_sampler> sampler);

// Backend loading functions
typedef GgmlBackendLoadAllNative = ffi.Void Function();
typedef GgmlBackendLoadAll = void Function();

// Simplified FFI integration for llama.cpp
class LlamaFFI {
  late ffi.DynamicLibrary _lib;
  late ffi.DynamicLibrary _ggmlLib;

  late LlamaInitBackend llama_backend_init;
  late LlamaBackendFree llama_backend_free;
  //
  late LlamaModelDefaultParams llama_model_default_params;
  late LlamaModelLoadFromFile llama_model_load_from_file;
  late LlamaModelGetVocab llama_model_get_vocab;
  //
  late LlamaNewContextWithModel llama_new_context_with_model;
  late LlamaContextDefaultParams llama_context_default_params;
  late LlamaInitFromModel llama_init_from_model;
  //
  late LlamaVocabIsEog llama_vocab_is_eog;
  //
  late LlamaTokenize llama_tokenize;
  late LlamaTokenToPiece llama_token_to_piece;
  //
  late LlamaSamplerChainDefaultParams llama_sampler_chain_default_params;
  late LlamaSamplerChainInit llama_sampler_chain_init;
  late LlamaSamplerChainAdd llama_sampler_chain_add;
  late LlamaSamplerInitGreedy llama_sampler_init_greedy;
  late LlamaSamplerSample llama_sampler_sample;
  //
  late LlamaBatchGetOne llama_batch_get_one;
  //
  late LlamaDecode llama_decode;
  //
  late LlamaFree llama_free;
  late LlamaModelFree llama_model_free;
  late LlamaSamplerFree llama_sampler_free;
  //
  late LlamaTimeUs llama_time_us;
  late LlamaPerfContextPrint llama_perf_context_print;
  late LlamaPerfSamplerPrint llama_perf_sampler_print;

  late GgmlBackendLoadAll ggml_backend_load_all;

  ffi.Pointer<llama_model>? _model;
  ffi.Pointer<llama_context>? _context;

  LlamaFFI() {
    _loadLibrary();
    _loadFunctions();
  }

  void _loadLibrary() {
    String llamaLibraryPath;
    String ggmlLibraryPath;

    if (Platform.isAndroid) {
      llamaLibraryPath = 'libllama.so';
      ggmlLibraryPath = 'libggml.so';
    } else if (Platform.isIOS) {
      // On iOS, libraries are statically linked into the app bundle
      // Use DynamicLibrary.process() to access the current process
      try {
        _lib = ffi.DynamicLibrary.process();
        _ggmlLib = ffi.DynamicLibrary.process();
        print('Successfully loaded llama.cpp libraries from iOS app bundle');
        return;
      } catch (e) {
        throw Exception('Failed to load libraries from iOS app bundle: $e');
      }
    } else if (Platform.isWindows) {
      llamaLibraryPath = path.join(Directory.current.path, 'llama.dll');
      ggmlLibraryPath = path.join(Directory.current.path, 'ggml.dll');
    } else if (Platform.isLinux) {
      llamaLibraryPath = path.join(Directory.current.path, 'libllama.so');
      ggmlLibraryPath = path.join(Directory.current.path, 'libggml.so');
    } else if (Platform.isMacOS) {
      llamaLibraryPath = path.join(Directory.current.path, 'libllama.dylib');
      ggmlLibraryPath = path.join(Directory.current.path, 'libggml.dylib');
    } else {
      throw UnsupportedError('Platform not supported');
    }

    try {
      _lib = ffi.DynamicLibrary.open(llamaLibraryPath);
      print('Successfully loaded llama.cpp library: $llamaLibraryPath');

      _ggmlLib = ffi.DynamicLibrary.open(ggmlLibraryPath);
      print('Successfully loaded GGML library: $ggmlLibraryPath');
    } catch (e) {
      throw Exception('Failed to load libraries: $e');
    }
  }

  void _loadFunctions() {
    try {
      // Load basic functions that should be available in most llama.cpp builds
      llama_backend_init = _lib
          .lookup<ffi.NativeFunction<LlamaInitBackendNative>>('llama_backend_init')
          .asFunction<LlamaInitBackend>();

      llama_backend_free = _lib
          .lookup<ffi.NativeFunction<LlamaBackendFreeNative>>('llama_backend_free')
          .asFunction<LlamaBackendFree>();

      // Load model functions
      llama_model_default_params = _lib
          .lookup<ffi.NativeFunction<LlamaModelDefaultParamsNative>>('llama_model_default_params')
          .asFunction<LlamaModelDefaultParams>();

      llama_model_load_from_file = _lib
          .lookup<ffi.NativeFunction<LlamaModelLoadFromFileNative>>('llama_model_load_from_file')
          .asFunction<LlamaModelLoadFromFile>();

      llama_model_get_vocab = _lib
          .lookup<ffi.NativeFunction<LlamaModelGetVocabNative>>('llama_model_get_vocab')
          .asFunction<LlamaModelGetVocab>();

      // Load context functions
      llama_new_context_with_model = _lib
          .lookup<ffi.NativeFunction<LlamaNewContextWithModelNative>>('llama_new_context_with_model')
          .asFunction<LlamaNewContextWithModel>();

      llama_context_default_params = _lib
          .lookup<ffi.NativeFunction<LlamaContextDefaultParamsNative>>('llama_context_default_params')
          .asFunction<LlamaContextDefaultParams>();

      llama_init_from_model = _lib
          .lookup<ffi.NativeFunction<LlamaInitFromModelNative>>('llama_init_from_model')
          .asFunction<LlamaInitFromModel>();

      //
      llama_vocab_is_eog = _lib
          .lookup<ffi.NativeFunction<LlamaVocabIsEogNative>>('llama_vocab_is_eog')
          .asFunction<LlamaVocabIsEog>();

      // Load tokenization functions
      llama_tokenize = _lib
          .lookup<ffi.NativeFunction<LlamaTokenizeNative>>('llama_tokenize')
          .asFunction<LlamaTokenize>();

      llama_token_to_piece = _lib
          .lookup<ffi.NativeFunction<LlamaTokenToPieceNative>>('llama_token_to_piece')
          .asFunction<LlamaTokenToPiece>();

      // Sampler functions
      llama_sampler_chain_default_params = _lib
          .lookup<ffi.NativeFunction<LlamaSamplerChainDefaultParamsNative>>('llama_sampler_chain_default_params')
          .asFunction<LlamaSamplerChainDefaultParams>();

      llama_sampler_chain_init = _lib
          .lookup<ffi.NativeFunction<LlamaSamplerChainInitNative>>('llama_sampler_chain_init')
          .asFunction<LlamaSamplerChainInit>();

      llama_sampler_chain_add = _lib
          .lookup<ffi.NativeFunction<LlamaSamplerChainAddNative>>('llama_sampler_chain_add')
          .asFunction<LlamaSamplerChainAdd>();

      llama_sampler_init_greedy = _lib
          .lookup<ffi.NativeFunction<LlamaSamplerInitGreedyNative>>('llama_sampler_init_greedy')
          .asFunction<LlamaSamplerInitGreedy>();

      llama_sampler_sample = _lib
          .lookup<ffi.NativeFunction<LlamaSamplerSampleNative>>('llama_sampler_sample')
          .asFunction<LlamaSamplerSample>();

      // Batch functions
      llama_batch_get_one = _lib
          .lookup<ffi.NativeFunction<LlamaBatchGetOneNative>>('llama_batch_get_one')
          .asFunction<LlamaBatchGetOne>();

      // Encode Decode functions
      llama_decode = _lib
          .lookup<ffi.NativeFunction<LlamaDecodeNative>>('llama_decode')
          .asFunction<LlamaDecode>();

      // Free functions
      llama_free = _lib
          .lookup<ffi.NativeFunction<LlamaFreeNative>>('llama_free')
          .asFunction<LlamaFree>();

      llama_model_free = _lib
          .lookup<ffi.NativeFunction<LlamaModelFreeNative>>('llama_model_free')
          .asFunction<LlamaModelFree>();

      llama_sampler_free = _lib
          .lookup<ffi.NativeFunction<LlamaSamplerFreeNative>>('llama_sampler_free')
          .asFunction<LlamaSamplerFree>();

      llama_time_us = _lib
          .lookup<ffi.NativeFunction<LlamaTimeUsNative>>('llama_time_us')
          .asFunction<LlamaTimeUs>();

      llama_perf_context_print = _lib
          .lookup<ffi.NativeFunction<LlamaPerfContextPrintNative>>('llama_perf_context_print')
          .asFunction<LlamaPerfContextPrint>();

      llama_perf_sampler_print = _lib
          .lookup<ffi.NativeFunction<LlamaPerfSamplerPrintNative>>('llama_perf_sampler_print')
          .asFunction<LlamaPerfSamplerPrint>();

      // GGML backend functions - try to load from main library first
      ggml_backend_load_all = _ggmlLib
          .lookup<ffi.NativeFunction<GgmlBackendLoadAllNative>>('ggml_backend_load_all')
          .asFunction<GgmlBackendLoadAll>();

      print('Successfully loaded llama.cpp functions');
    } catch (e) {
      throw Exception('Failed to load llama.cpp functions: $e');
    }
  }

  // Initialize the llama backend
  void initBackend() {
    try {
      llama_backend_init();
      print('Llama backend initialized successfully');
    } catch (e) {
      throw Exception('Failed to initialize llama backend: $e');
    }
  }

  // Load model from file
  bool loadModel(String modelPath) {
    print('loadModel(modelPath: $modelPath)');
    try {
      if (_model != null) {
        freeModel();
      }

      final pathPtr = modelPath.toNativeUtf8().cast<ffi.Char>();

      // Get default model parameters
      final llama_model_params modelParams = llama_model_default_params();

      // Load model with default parameters
      _model = llama_model_load_from_file(pathPtr, modelParams);
      malloc.free(pathPtr);

      if (_model == ffi.nullptr) {
        print('Failed to load model from: $modelPath');
        return false;
      }

      print('Model loaded successfully from: $modelPath');
      return true;
    } catch (e) {
      print('Error loading model: $e');
      return false;
    }
  }

  bool tokenizePrompt(String prompt) {
    print('tokenizePrompt(prompt: $prompt)');
    try {
      final vocab = llama_model_get_vocab(_model!);
      final promptPtr = prompt.toNativeUtf8().cast<ffi.Char>();
      final tokens = llama_tokenize(vocab, promptPtr, prompt.length, ffi.nullptr, 0, true, true);
      print('tokens: $tokens');
      return true;
    } catch (e) {
      print('Error tokenizing prompt: $e');
      return false;
    }
  }

  // Create context for inference
  bool createContext() {
    print('createContext:');
    try {
      if (_model == null || _model == ffi.nullptr) {
        print('No model loaded');
        return false;
      }

      if (_context != null) {
        freeContext();
      }

      // For now, use null for context params (default parameters)
      _context = llama_new_context_with_model(_model!, llama_context_default_params());

      if (_context == ffi.nullptr) {
        print('Failed to create context');
        return false;
      }

      print('Context created successfully');
      return true;
    } catch (e) {
      print('Error creating context: $e');
      return false;
    }
  }

  // Simple inference function
  String? performInference(String prompt, {int maxTokens = 50}) {
    print('performInference(prompt: "$prompt", maxTokens: $maxTokens)');

    try {
      if (_model == null || _context == null || _model == ffi.nullptr || _context == ffi.nullptr) {
        print('Model or context not initialized');
        return null;
      }

      // Get vocabulary from model
      final vocab = llama_model_get_vocab(_model!);
      if (vocab.address == 0) {
        print("Error: failed to get vocabulary from model");
        return null;
      }

      // Convert prompt to UTF-8 and get proper byte length
      final promptUtf8 = prompt.toNativeUtf8();
      final promptPtr = promptUtf8.cast<ffi.Char>();
      final promptByteLength = promptUtf8.length;

      // First call to get required token count (negative return value)
      final nPromptRequired = llama_tokenize(vocab, promptPtr, promptByteLength, ffi.nullptr, 0, true, true);
      if (nPromptRequired >= 0) {
        print("Error: unexpected positive return from tokenize call");
        malloc.free(promptUtf8);
        return null;
      }
      final nPrompt = -nPromptRequired;

      // Allocate space for the tokens and tokenize the prompt
      final tokens = malloc<llama_token>(nPrompt);
      final actualTokens = llama_tokenize(vocab, promptPtr, promptByteLength, tokens, nPrompt, true, true);

      if (actualTokens < 0) {
        print("Error: failed to tokenize the prompt");
        malloc.free(promptUtf8);
        malloc.free(tokens);
        return null;
      }
      print("Prompt(tokenized): $actualTokens tokens");

      // Free the prompt memory now that we're done with it
      malloc.free(promptUtf8);

      // Initialize sampler
      final sparams = llama_sampler_chain_default_params();
      sparams.no_perf = false;
      final smpl = llama_sampler_chain_init(sparams);
      llama_sampler_chain_add(smpl, llama_sampler_init_greedy());

      // Prepare initial batch
      var batch = llama_batch_get_one(tokens, nPrompt);

      // Initialize response string - collect all bytes first
      final responseBytes = <int>[];

      // Main generation loop
      int nDecode = 0;
      int newTokenId;
      final tokenPtr = malloc<llama_token>();

      for (int nPos = 0; nPos + batch.n_tokens < nPrompt + maxTokens;) {
        // Decode the batch
        if (llama_decode(_context!, batch) != 0) {
          print("Error: failed to decode batch");
          break;
        }

        nPos += batch.n_tokens;

        // Sample next token
        newTokenId = llama_sampler_sample(smpl, _context!, -1);

        // Check if end of generation
        if (llama_vocab_is_eog(vocab, newTokenId)) {
          print("End of generation reached");
          break;
        }

        // Convert token to text piece
        final buf = malloc<ffi.Char>(128);
        int n = llama_token_to_piece(vocab, newTokenId, buf, 128, 0, true);
        if (n < 0) {
          print("Error: failed to convert token to piece");
          malloc.free(buf);
          break;
        }

        // Collect bytes without decoding individual pieces
        final bytes = buf.cast<ffi.Uint8>().asTypedList(n);
        responseBytes.addAll(bytes);
        malloc.free(buf);

        // Prepare next batch with the new token
        tokenPtr.value = newTokenId;
        batch = llama_batch_get_one(tokenPtr, 1);

        nDecode++;
      }
      print("Sampled(decoded): $nDecode tokens");

      // Clean up memory
      malloc.free(tokens);
      malloc.free(tokenPtr);
      llama_sampler_free(smpl);

      // Decode all collected bytes as UTF-8 at once
      String response;
      try {
        response = utf8.decode(responseBytes);
      } catch (e) {
        print("UTF-8 decode error: $e, falling back to latin1");
        // Fallback to latin1 decoding if UTF-8 fails
        response = String.fromCharCodes(responseBytes);
      }
      
      print("Generated response: $response");
      return response;
    } catch (e) {
      print('Error during inference: $e');
      return null;
    }
  }

  // Streaming inference function that yields tokens as they are generated
  Stream<String> performStreamingInference(String prompt, {int maxTokens = 512}) async* {
    print('performStreamingInference(prompt: "$prompt", maxTokens: $maxTokens)');

    try {
      if (_model == null || _context == null || _model == ffi.nullptr || _context == ffi.nullptr) {
        print('Model or context not initialized');
        return;
      }

      // Get vocabulary from model
      final vocab = llama_model_get_vocab(_model!);
      if (vocab.address == 0) {
        print("Error: failed to get vocabulary from model");
        return;
      }

      // Convert prompt to UTF-8 and get proper byte length
      final promptUtf8 = prompt.toNativeUtf8();
      final promptPtr = promptUtf8.cast<ffi.Char>();
      final promptByteLength = promptUtf8.length;

      // First call to get required token count (negative return value)
      final nPromptRequired = llama_tokenize(vocab, promptPtr, promptByteLength, ffi.nullptr, 0, true, true);
      if (nPromptRequired >= 0) {
        print("Error: unexpected positive return from tokenize call");
        malloc.free(promptUtf8);
        return;
      }
      final nPrompt = -nPromptRequired;

      // Allocate space for the tokens and tokenize the prompt
      final tokens = malloc<llama_token>(nPrompt);
      final actualTokens = llama_tokenize(vocab, promptPtr, promptByteLength, tokens, nPrompt, true, true);

      if (actualTokens < 0) {
        print("Error: failed to tokenize the prompt");
        malloc.free(promptUtf8);
        malloc.free(tokens);
        return;
      }
      print("Prompt(tokenized): $actualTokens tokens");

      // Free the prompt memory now that we're done with it
      malloc.free(promptUtf8);

      // Initialize sampler
      final sparams = llama_sampler_chain_default_params();
      sparams.no_perf = false;
      final smpl = llama_sampler_chain_init(sparams);
      llama_sampler_chain_add(smpl, llama_sampler_init_greedy());

      // Prepare initial batch
      var batch = llama_batch_get_one(tokens, nPrompt);

      // Buffer for accumulating bytes to handle UTF-8 properly
      final byteBuffer = <int>[];
      
      // Main generation loop
      int nDecode = 0;
      int newTokenId;
      final tokenPtr = malloc<llama_token>();

      for (int nPos = 0; nPos + batch.n_tokens < nPrompt + maxTokens;) {
        // Decode the batch
        if (llama_decode(_context!, batch) != 0) {
          print("Error: failed to decode batch");
          break;
        }

        nPos += batch.n_tokens;

        // Sample next token
        newTokenId = llama_sampler_sample(smpl, _context!, -1);

        // Check if end of generation
        if (llama_vocab_is_eog(vocab, newTokenId)) {
          print("End of generation reached");
          break;
        }

        // Convert token to text piece
        final buf = malloc<ffi.Char>(128);
        int n = llama_token_to_piece(vocab, newTokenId, buf, 128, 0, true);
        if (n < 0) {
          print("Error: failed to convert token to piece");
          malloc.free(buf);
          break;
        }

        // Get bytes for this token
        final tokenBytes = buf.cast<ffi.Uint8>().asTypedList(n);
        byteBuffer.addAll(tokenBytes);
        malloc.free(buf);

        // Try to decode accumulated bytes and yield valid UTF-8 text
        try {
          final text = utf8.decode(byteBuffer);
          if (text.isNotEmpty) {
            yield text;
            byteBuffer.clear(); // Clear buffer after successful decode
          }
        } catch (e) {
          // UTF-8 decode failed, might be incomplete multi-byte sequence
          // Keep accumulating until we have valid UTF-8
          if (byteBuffer.length > 4) {
            // If buffer gets too large, try fallback decode
            final fallbackText = String.fromCharCodes(byteBuffer);
            if (fallbackText.isNotEmpty) {
              yield fallbackText;
              byteBuffer.clear();
            }
          }
        }

        // Prepare next batch with the new token
        tokenPtr.value = newTokenId;
        batch = llama_batch_get_one(tokenPtr, 1);

        nDecode++;

        // Brief yield to keep UI responsive
        await Future.delayed(Duration.zero);
      }

      // Yield any remaining content in buffer
      if (byteBuffer.isNotEmpty) {
        try {
          final remaining = utf8.decode(byteBuffer);
          if (remaining.isNotEmpty) {
            yield remaining;
          }
        } catch (e) {
          final remaining = String.fromCharCodes(byteBuffer);
          if (remaining.isNotEmpty) {
            yield remaining;
          }
        }
      }

      print("Streaming completed. Sampled(decoded): $nDecode tokens");

      // Clean up memory
      malloc.free(tokens);
      malloc.free(tokenPtr);
      llama_sampler_free(smpl);
      
    } catch (e) {
      print('Error during streaming inference: $e');
    }
  }

  // Check if model is loaded
  bool get isModelLoaded => _model != null && _model != ffi.nullptr;

  // Check if context is created
  bool get isContextCreated => _context != null && _context != ffi.nullptr;

  // Free model
  void freeModel() {
    if (_model != null && _model != ffi.nullptr) {
      llama_model_free(_model!);
      _model = null;
      print('Model freed');
    }
  }

  // Free context
  void freeContext() {
    if (_context != null && _context != ffi.nullptr) {
      llama_free(_context!);
      _context = null;
      print('Context freed');
    }
  }

  // Free the llama backend
  void freeBackend() {
    try {
      freeContext();
      freeModel();
      llama_backend_free();
      print('Llama backend freed successfully');
    } catch (e) {
      print('Warning: Failed to free llama backend: $e');
    }
  }

  // Test function to verify the library is working
  bool testLibrary() {
    try {
      // Try to get a function that should exist
      final timeFunc = _lib
          .lookup<ffi.NativeFunction<LlamaTimeUsNative>>('llama_time_us')
          .asFunction<LlamaTimeUs>();

      final time = timeFunc();
      print('Llama library test successful. Current time: $time microseconds');
      return true;
    } catch (e) {
      print('Llama library test failed: $e');
      return false;
    }
  }

  // Simple wrapper to check if model file exists
  bool modelFileExists(String modelPath) {
    final file = File(modelPath);
    print('Checking if model file exists: ${file.parent} ${file.path}');
    final exists = file.existsSync();
    print('Model file $modelPath exists: $exists');
    if (exists) {
      final size = file.lengthSync();
      print('Model file size: ${(size / (1024 * 1024)).toStringAsFixed(2)} MB');
    }
    return exists;
  }

  // Get list of available functions in the library (debug helper)
  void listAvailableFunctions() {
    final commonFunctions = [
      'llama_backend_init',
      'llama_backend_free',
      //
      'llama_model_default_params',
      'llama_model_load_from_file',
      'llama_model_get_vocab',
      //
      'llama_new_context_with_model',
      'llama_context_default_params',
      'llama_init_from_model',
      //
      'llama_vocab_is_eog',
      //
      'llama_tokenize',
      'llama_token_to_piece',
      //
      'llama_sampler_chain_default_params',
      'llama_sampler_chain_init',
      'llama_sampler_chain_add',
      'llama_sampler_init_greedy',
      'llama_sampler_sample',
      //
      'llama_batch_get_one',
      //
      'llama_decode',
      //
      'llama_free',
      'llama_model_free',
      'llama_sampler_free',
    ];

    print('Checking for common llama.cpp functions:');
    for (final funcName in commonFunctions) {
      try {
        _lib.lookup(funcName);
        print('✅ $funcName - available');
      } catch (e) {
        print('❌ $funcName - not found');
      }
    }

    final ggmlFunctions = [
      'ggml_backend_load_all',
    ];

    print('Checking for ggml backend functions:');
    for (final funcName in ggmlFunctions) {
      try {
        _ggmlLib.lookup(funcName);
        print('✅ $funcName - available in GGML library');
      } catch (e) {
        print('❌ $funcName - not found in GGML library');
      }
    }
  }
}