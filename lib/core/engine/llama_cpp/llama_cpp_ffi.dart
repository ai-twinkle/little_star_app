import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

import '../../../utils/logger.dart';

final log = Logger('LlamaCppFFI');

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

// used in chat template (struct llama_chat_message)
final class llama_chat_message extends ffi.Struct {
  external ffi.Pointer<ffi.Char> role;
  external ffi.Pointer<ffi.Char> content;
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

// Logging callback typedefs
typedef LlamaLogCallbackNative = ffi.Void Function(ffi.Int32 level, ffi.Pointer<ffi.Char> text, ffi.Pointer<ffi.Void> userData);
typedef LlamaLogCallback = void Function(int level, ffi.Pointer<ffi.Char> text, ffi.Pointer<ffi.Void> userData);

// Logging functions
typedef LlamaLogSetNative = ffi.Void Function(ffi.Pointer<ffi.NativeFunction<LlamaLogCallbackNative>> logCallback, ffi.Pointer<ffi.Void> userData);
typedef LlamaLogSet = void Function(ffi.Pointer<ffi.NativeFunction<LlamaLogCallbackNative>> logCallback, ffi.Pointer<ffi.Void> userData);

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

// Context getter functions
typedef LlamaNCtxNative = ffi.Uint32 Function(ffi.Pointer<llama_context> ctx);
typedef LlamaNCtx = int Function(ffi.Pointer<llama_context> ctx);

typedef LlamaNBatchNative = ffi.Uint32 Function(ffi.Pointer<llama_context> ctx);
typedef LlamaNBatch = int Function(ffi.Pointer<llama_context> ctx);

typedef LlamaNUbatchNative = ffi.Uint32 Function(ffi.Pointer<llama_context> ctx);
typedef LlamaNUbatch = int Function(ffi.Pointer<llama_context> ctx);

typedef LlamaNSeqMaxNative = ffi.Uint32 Function(ffi.Pointer<llama_context> ctx);
typedef LlamaNSeqMax = int Function(ffi.Pointer<llama_context> ctx);

typedef LlamaGetModelNative = ffi.Pointer<llama_model> Function(ffi.Pointer<llama_context> ctx);
typedef LlamaGetModel = ffi.Pointer<llama_model> Function(ffi.Pointer<llama_context> ctx);

typedef LlamaNThreadsNative = ffi.Int32 Function(ffi.Pointer<llama_context> ctx);
typedef LlamaNThreads = int Function(ffi.Pointer<llama_context> ctx);

typedef LlamaNThreadsBatchNative = ffi.Int32 Function(ffi.Pointer<llama_context> ctx);
typedef LlamaNThreadsBatch = int Function(ffi.Pointer<llama_context> ctx);

// Vocab functions
typedef LlamaVocabIsEogNative = ffi.Bool Function(ffi.Pointer<llama_vocab> vocab, ffi.Int32 token);
typedef LlamaVocabIsEog = bool Function(ffi.Pointer<llama_vocab> vocab, int token);

// Tokenization functions
typedef LlamaTokenizeNative = ffi.Int32 Function(ffi.Pointer<llama_vocab> vocab, ffi.Pointer<ffi.Char> text, ffi.Int32 textLen, ffi.Pointer<llama_token> tokens, ffi.Int32 nMaxTokens, ffi.Bool addBos, ffi.Bool special);
typedef LlamaTokenize = int Function(ffi.Pointer<llama_vocab> vocab, ffi.Pointer<ffi.Char> text, int textLen, ffi.Pointer<llama_token> tokens, int nMaxTokens, bool addBos, bool special);

typedef LlamaTokenToPieceNative = ffi.Int32 Function(ffi.Pointer<llama_vocab> vocab, ffi.Int32 token, ffi.Pointer<ffi.Char> buf, ffi.Int32 length, ffi.Int32 lstrip, ffi.Bool special);
typedef LlamaTokenToPiece = int Function(ffi.Pointer<llama_vocab> vocab, int token, ffi.Pointer<ffi.Char> buf, int length, int lstrip, bool special);

// Chat template functions
typedef LlamaModelChatTemplateNative = ffi.Pointer<ffi.Char> Function(ffi.Pointer<llama_model> model, ffi.Pointer<ffi.Char> name);
typedef LlamaModelChatTemplate = ffi.Pointer<ffi.Char> Function(ffi.Pointer<llama_model> model, ffi.Pointer<ffi.Char> name);

typedef LlamaChatApplyTemplateNative = ffi.Int32 Function(
  ffi.Pointer<ffi.Char> tmpl,
  ffi.Pointer<llama_chat_message> chat,
  ffi.Size nMsg,
  ffi.Bool addAss,
  ffi.Pointer<ffi.Char> buf,
  ffi.Int32 length
);
typedef LlamaChatApplyTemplate = int Function(
  ffi.Pointer<ffi.Char> tmpl,
  ffi.Pointer<llama_chat_message> chat,
  int nMsg,
  bool addAss,
  ffi.Pointer<ffi.Char> buf,
  int length
);

// Sampler functions
typedef LlamaSamplerChainDefaultParamsNative = llama_sampler_chain_params Function();
typedef LlamaSamplerChainDefaultParams = llama_sampler_chain_params Function();

typedef LlamaSamplerChainInitNative = ffi.Pointer<llama_sampler> Function(llama_sampler_chain_params params);
typedef LlamaSamplerChainInit = ffi.Pointer<llama_sampler> Function(llama_sampler_chain_params params);

typedef LlamaSamplerChainAddNative = ffi.Void Function(ffi.Pointer<llama_sampler> chain, ffi.Pointer<llama_sampler> sampler);
typedef LlamaSamplerChainAdd = void Function(ffi.Pointer<llama_sampler> chain, ffi.Pointer<llama_sampler> sampler);

typedef LlamaSamplerInitGreedyNative = ffi.Pointer<llama_sampler> Function();
typedef LlamaSamplerInitGreedy = ffi.Pointer<llama_sampler> Function();

typedef LlamaSamplerInitTopKNative = ffi.Pointer<llama_sampler> Function(ffi.Int32 k);
typedef LlamaSamplerInitTopK = ffi.Pointer<llama_sampler> Function(int k);

typedef LlamaSamplerInitTopPNative = ffi.Pointer<llama_sampler> Function(ffi.Float p, ffi.Size minKeep);
typedef LlamaSamplerInitTopP = ffi.Pointer<llama_sampler> Function(double p, int minKeep);

typedef LlamaSamplerInitTempNative = ffi.Pointer<llama_sampler> Function(ffi.Float t);
typedef LlamaSamplerInitTemp = ffi.Pointer<llama_sampler> Function(double t);

typedef LlamaSamplerInitDistNative = ffi.Pointer<llama_sampler> Function(ffi.Uint32 seed);
typedef LlamaSamplerInitDist = ffi.Pointer<llama_sampler> Function(int seed);

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
class LlamaCppFFI {
  late ffi.DynamicLibrary _lib;
  late ffi.DynamicLibrary _ggmlLib;

  late LlamaInitBackend llama_backend_init;
  late LlamaBackendFree llama_backend_free;
  //
  late LlamaLogSet llama_log_set;
  //
  late LlamaModelDefaultParams llama_model_default_params;
  late LlamaModelLoadFromFile llama_model_load_from_file;
  late LlamaModelGetVocab llama_model_get_vocab;
  //
  late LlamaNewContextWithModel llama_new_context_with_model;
  late LlamaContextDefaultParams llama_context_default_params;
  late LlamaInitFromModel llama_init_from_model;
  //
  late LlamaNCtx llama_n_ctx;
  late LlamaNBatch llama_n_batch;
  late LlamaNUbatch llama_n_ubatch;
  late LlamaNSeqMax llama_n_seq_max;
  late LlamaGetModel llama_get_model;
  late LlamaNThreads llama_n_threads;
  late LlamaNThreadsBatch llama_n_threads_batch;
  //
  late LlamaVocabIsEog llama_vocab_is_eog;
  //
  late LlamaTokenize llama_tokenize;
  late LlamaTokenToPiece llama_token_to_piece;
  //
  late LlamaModelChatTemplate llama_model_chat_template;
  late LlamaChatApplyTemplate llama_chat_apply_template;
  //
  late LlamaSamplerChainDefaultParams llama_sampler_chain_default_params;
  late LlamaSamplerChainInit llama_sampler_chain_init;
  late LlamaSamplerChainAdd llama_sampler_chain_add;
  late LlamaSamplerInitGreedy llama_sampler_init_greedy;
  late LlamaSamplerInitTopK llama_sampler_init_top_k;
  late LlamaSamplerInitTopP llama_sampler_init_top_p;
  late LlamaSamplerInitTemp llama_sampler_init_temp;
  late LlamaSamplerInitDist llama_sampler_init_dist;
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
  ffi.Pointer<llama_sampler>? _sampler;
  llama_batch? _batch;
  bool logVerbose = false;
  
  ffi.Pointer<llama_model>? get model => _model;
  ffi.Pointer<llama_context>? get context => _context;
  ffi.Pointer<llama_sampler>? get sampler => _sampler;
  llama_batch? get batch => _batch;
  
  // Check if model is loaded
  bool get isModelLoaded => _model != null && _model != ffi.nullptr;

  // Check if context is created
  bool get isContextCreated => _context != null && _context != ffi.nullptr;

  // Check if sampler is created
  bool get isSamplerCreated => _sampler != null && _sampler != ffi.nullptr;

  LlamaCppFFI() {
    _loadLibrary();
    _loadFunctions();
  }

  void _loadLibrary() {
    String llamaLibraryPath;
    String ggmlLibraryPath;

    if (Platform.isAndroid) {
      llamaLibraryPath = 'libllama.so';
      ggmlLibraryPath = 'libggml.so';
      log.debug('Android platform detected - using library names: $llamaLibraryPath, $ggmlLibraryPath');
    } else if (Platform.isIOS) {
      // On iOS, libraries are statically linked into the app bundle
      // Use DynamicLibrary.process() to access the current process
      try {
        _lib = ffi.DynamicLibrary.process();
        _ggmlLib = ffi.DynamicLibrary.process();
        log.debug('Successfully loaded llama.cpp libraries from iOS app bundle');
        return;
      } catch (e) {
        throw Exception('Failed to load libraries from iOS app bundle: $e');
      }
    } else if (Platform.isWindows) {
      llamaLibraryPath = path.join(Directory.current.path, 'llama.dll');
      ggmlLibraryPath = path.join(Directory.current.path, 'ggml.dll');
      log.debug('Windows platform detected - using library paths: $llamaLibraryPath, $ggmlLibraryPath');
    } else if (Platform.isLinux) {
      llamaLibraryPath = path.join(Directory.current.path, 'libllama.so');
      ggmlLibraryPath = path.join(Directory.current.path, 'libggml.so');
      log.debug('Linux platform detected - using library paths: $llamaLibraryPath, $ggmlLibraryPath');
    } else if (Platform.isMacOS) {
      llamaLibraryPath = path.join(Directory.current.path, 'libllama.dylib');
      ggmlLibraryPath = path.join(Directory.current.path, 'libggml.dylib');
      log.debug('macOS platform detected - using library paths: $llamaLibraryPath, $ggmlLibraryPath');
    } else {
      throw UnsupportedError('Platform not supported');
    }

    try {
      // Print the exact absolute paths being used
      final llamaAbsolutePath = path.absolute(llamaLibraryPath);
      final ggmlAbsolutePath = path.absolute(ggmlLibraryPath);
      
      log.trace('=== Library Loading Information ===');
      log.trace('Platform: ${Platform.operatingSystem}');
      log.trace('Current working directory: ${Directory.current.path}');
      log.trace('_lib will be loaded from: $llamaAbsolutePath');
      log.trace('_ggmlLib will be loaded from: $ggmlAbsolutePath');
      
      _lib = ffi.DynamicLibrary.open(llamaLibraryPath);
      log.trace('✅ Successfully loaded llama.cpp library: $llamaAbsolutePath');
      log.trace('  _lib handle: ${_lib.toString()}');

      _ggmlLib = ffi.DynamicLibrary.open(ggmlLibraryPath);
      log.trace('✅ Successfully loaded GGML library: $ggmlAbsolutePath');
      log.trace('  _ggmlLib handle: ${_ggmlLib.toString()}');
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

      // Load logging functions
      llama_log_set = _lib
          .lookup<ffi.NativeFunction<LlamaLogSetNative>>('llama_log_set')
          .asFunction<LlamaLogSet>();

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

      // ontext getter functions
      llama_n_ctx = _lib
          .lookup<ffi.NativeFunction<LlamaNCtxNative>>('llama_n_ctx')
          .asFunction<LlamaNCtx>();

      llama_n_batch = _lib
          .lookup<ffi.NativeFunction<LlamaNBatchNative>>('llama_n_batch')
          .asFunction<LlamaNBatch>();

      llama_n_ubatch = _lib
          .lookup<ffi.NativeFunction<LlamaNUbatchNative>>('llama_n_ubatch')
          .asFunction<LlamaNUbatch>();

      llama_n_seq_max = _lib
          .lookup<ffi.NativeFunction<LlamaNSeqMaxNative>>('llama_n_seq_max')
          .asFunction<LlamaNSeqMax>();

      llama_get_model = _lib
          .lookup<ffi.NativeFunction<LlamaGetModelNative>>('llama_get_model')
          .asFunction<LlamaGetModel>();

      llama_n_threads = _lib
          .lookup<ffi.NativeFunction<LlamaNThreadsNative>>('llama_n_threads')
          .asFunction<LlamaNThreads>();

      llama_n_threads_batch = _lib
          .lookup<ffi.NativeFunction<LlamaNThreadsBatchNative>>('llama_n_threads_batch')
          .asFunction<LlamaNThreadsBatch>();

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

      // Chat template functions
      llama_model_chat_template = _lib
          .lookup<ffi.NativeFunction<LlamaModelChatTemplateNative>>('llama_model_chat_template')
          .asFunction<LlamaModelChatTemplate>();

      llama_chat_apply_template = _lib
          .lookup<ffi.NativeFunction<LlamaChatApplyTemplateNative>>('llama_chat_apply_template')
          .asFunction<LlamaChatApplyTemplate>();

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

      llama_sampler_init_top_k = _lib
          .lookup<ffi.NativeFunction<LlamaSamplerInitTopKNative>>('llama_sampler_init_top_k')
          .asFunction<LlamaSamplerInitTopK>();

      llama_sampler_init_top_p = _lib
          .lookup<ffi.NativeFunction<LlamaSamplerInitTopPNative>>('llama_sampler_init_top_p')
          .asFunction<LlamaSamplerInitTopP>();

      llama_sampler_init_temp = _lib
          .lookup<ffi.NativeFunction<LlamaSamplerInitTempNative>>('llama_sampler_init_temp')
          .asFunction<LlamaSamplerInitTemp>();

      llama_sampler_init_dist = _lib
          .lookup<ffi.NativeFunction<LlamaSamplerInitDistNative>>('llama_sampler_init_dist')
          .asFunction<LlamaSamplerInitDist>();

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

      log.debug('Successfully loaded llama.cpp functions');
    } catch (e) {
      throw Exception('Failed to load llama.cpp functions: $e');
    }
  }

  static void llamaLogCallbackNull(int level, ffi.Pointer<ffi.Char> text, ffi.Pointer<ffi.Void> userData) {}

  void setLogCallback() {
    if (logVerbose == false) {
      final nullCallbackPointer =
          ffi.Pointer.fromFunction<LlamaLogCallbackNative>(llamaLogCallbackNull);
      llama_log_set(nullCallbackPointer, ffi.nullptr);
    }
  }

  // Initialize the llama backend
  void initBackend() {
    try {
      setLogCallback();
      llama_backend_init();
      log.debug('Llama backend initialized successfully');
    } catch (e) {
      throw Exception('Failed to initialize llama backend: $e');
    }
  }

  // Load model from file
  bool loadModel(String modelPath) {
    log.debug('\n\nloadModel(modelPath: $modelPath)');
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
        log.warn('Failed to load model from: $modelPath');
        return false;
      }

      log.info('Model loaded successfully from: $modelPath');
      return true;
    } catch (e) {
      log.error('Error loading model: $e');
      return false;
    }
  }

  int tokenizePrompt(String prompt) {
    try {
      final vocab = llama_model_get_vocab(_model!);
      // Convert prompt to UTF-8 and get proper byte length
      final promptUtf8 = prompt.toNativeUtf8();
      final promptPtr = promptUtf8.cast<ffi.Char>();
      final promptByteLength = promptUtf8.length; // This gives actual byte length
      log.debug("\n\ntokenizePrompt prompt: $prompt, promptPtr: ${promptPtr.address}, byteLength: $promptByteLength");

      // First call to get required token count (negative return value)
      final nPromptRequired = llama_tokenize(vocab, promptPtr, promptByteLength, ffi.nullptr, 0, true, true);
      if (nPromptRequired >= 0) {
        log.error("Error: unexpected positive return from tokenize call");
        malloc.free(promptUtf8);
        return 0;
      }
      int nPrompt = -nPromptRequired;
      log.debug('nPrompt: $nPrompt');

      // Allocate space for the tokens and tokenize the prompt
      final tokens = malloc<llama_token>(nPrompt);
      final tokensCount = llama_tokenize(vocab, promptPtr, promptByteLength, tokens, nPrompt, true, true);

      if (tokensCount < 0) {
        log.error("Error: failed to tokenize the prompt");
        malloc.free(promptUtf8);
        malloc.free(tokens);
        return 0;
      }
      log.debug("Prompt(tokenized): $tokensCount tokens");

      // Free the prompt memory now that we're done with it
      malloc.free(promptUtf8);

      _batch = llama_batch_get_one(tokens, nPrompt);
      return nPrompt;
    } catch (e) {
      log.error('Error tokenizing prompt: $e');
      return 0;
    }
  }

  // Create context for inference
  bool createContext({
    int? nCtx,
    int? nBatch,
    int? nThreads,
    int? nThreadsBatch,
  }) {
    log.debug('\n\ncreateContext: nCtx=$nCtx, nBatch=$nBatch, nThreads=$nThreads, nThreadsBatch=$nThreadsBatch');
    try {
      if (_model == null || _model == ffi.nullptr) {
        log.warn('No model loaded');
        return false;
      }

      if (_context != null) {
        freeContext();
      }

      // Get default context parameters and apply custom values if provided
      final contextParams = llama_context_default_params();
      
      if (nCtx != null) {
        contextParams.n_ctx = nCtx;
      }
      if (nBatch != null) {
        contextParams.n_batch = nBatch;
      }
      
      if (nThreads != null) {
        contextParams.n_threads = nThreads;
      }
      if (nThreadsBatch != null) {
        contextParams.n_threads_batch = nThreadsBatch;
      }

      _context = llama_new_context_with_model(_model!, contextParams);

      if (_context == ffi.nullptr) {
        log.warn('Failed to create context');
        return false;
      }

      return true;
    } catch (e) {
      log.error('Error creating context: $e');
      return false;
    }
  }

  bool createSampler({bool useGreedy = false, int? topK, double? topP, double? temp}) {
    log.debug('\n\ncreateSampler(useGreedy: $useGreedy, topK: $topK, topP: $topP, temp: $temp)');
    try {
      if (_context == null || _context == ffi.nullptr) {
        log.warn('Context not initialized');
        return false;
      }

      final sparams = llama_sampler_chain_default_params();
      sparams.no_perf = false;
      _sampler = llama_sampler_chain_init(sparams);

      if (_sampler == ffi.nullptr) {
        log.warn('Failed to create sampler');
        return false;
      }

      if (useGreedy) {
        llama_sampler_chain_add(_sampler!, llama_sampler_init_greedy());
      } else {
        if (topK != null && topK > 0) {
          llama_sampler_chain_add(_sampler!, llama_sampler_init_top_k(topK));
        }
        if (topP != null && topP < 1.0) {
          llama_sampler_chain_add(_sampler!, llama_sampler_init_top_p(topP, 1));
        }
        if (temp != null && temp >= 0.0) {
          llama_sampler_chain_add(_sampler!, llama_sampler_init_temp(temp));
        }
        llama_sampler_chain_add(_sampler!, llama_sampler_init_dist(0)); // 0 for random seed
      }

      return true;
    } catch (e) {
      log.error('Error creating sampler: $e');
      return false;
    }
  }

  void generate(int nPrompt, {int maxTokens = 256}) {
    log.debug('\n\ngenerate(nPrompt: $nPrompt, maxTokens: $maxTokens)');
    try {
      if (_model == null || _context == null || _model == ffi.nullptr || _context == ffi.nullptr) {
        log.warn('Model or context not initialized');
        return;
      }

      if (_batch == null || _batch == ffi.nullptr) {
        log.warn('Batch not initialized');
        return;
      }

      if (_sampler == null || _sampler == ffi.nullptr) {
        log.warn('Sampler not initialized');
        return;
      }

      if (_context == null || _context == ffi.nullptr) {
        log.warn('Context not initialized');
        return;
      }

      // Get vocabulary from model
      final vocab = llama_model_get_vocab(_model!);
      if (vocab.address == 0) {
        log.error("Error: failed to get vocabulary from model");
        return;
      }

      // Print prompt tokens
      for (int i = 0; i < nPrompt; i++) {
        final buf = malloc<ffi.Char>(128);
        int n = llama_token_to_piece(vocab, _batch!.token[i], buf, 128, 0, true);
        if (n < 0) {
          log.error("error: failed to convert token to piece");
          malloc.free(buf);
          malloc.free(_batch!.token);
          return;
        }
        String piece = utf8.decode(buf.cast<ffi.Uint8>().asTypedList(n), allowMalformed: true);
        log.trace(piece);
        malloc.free(buf);
      }

      // Main generation loop
      int newTokenId;
      final tokenPtr = malloc<llama_token>();

      for (int nPos = 0; nPos + _batch!.n_tokens < nPrompt + maxTokens;) {
        if (llama_decode(_context!, _batch!) != 0) {
          log.error("Error: failed to decode batch");
          break;
        }

        nPos += _batch!.n_tokens;

        // Sample next token
        newTokenId = llama_sampler_sample(_sampler!, _context!, -1);

        // Check if end of generation
        if (llama_vocab_is_eog(vocab, newTokenId)) {
          log.debug("End of generation reached");
          break;
        }

        // Convert token to text piece
        final buf = malloc<ffi.Char>(128);
        int n = llama_token_to_piece(vocab, newTokenId, buf, 128, 0, true);
        if (n < 0) {
          log.error("Error: failed to convert token to piece");
          malloc.free(buf);
          break;
        }

        String piece = utf8.decode(buf.cast<ffi.Uint8>().asTypedList(n), allowMalformed: true);
        stdout.write(piece);
        malloc.free(buf);

        // Prepare next batch
        tokenPtr.value = newTokenId;
        _batch = llama_batch_get_one(tokenPtr, 1);
      }

    } catch (e) {
      log.error('Error generating: $e');
    }
  }

  String applyChatTemplate(List<Map<String, dynamic>> messageMaps) {
    log.debug('\n\napplyChatTemplate(messages: $messageMaps)');
    try {
      if (_model == null || _model == ffi.nullptr) {
        log.warn('Model not initialized');
        throw Exception('Model not initialized');
      }

      final tmplPtr = llama_model_chat_template(_model!, ffi.nullptr);
      log.trace('tmplPtr: $tmplPtr');

      final messageData = malloc<llama_chat_message>(messageMaps.length);
      for (int i = 0; i < messageMaps.length; i++) {
        final m = messageMaps[i];
        final rolePtr = (m['role'] as String).toNativeUtf8().cast<ffi.Char>();
        final contentPtr = (m['content'] as String).toNativeUtf8().cast<ffi.Char>();
        messageData[i]
          ..role = rolePtr
          ..content = contentPtr;
      }

      int newLen = llama_chat_apply_template(tmplPtr, messageData, messageMaps.length, true, ffi.nullptr, 0);
      int nCtx = llama_n_ctx(_context!);
      ffi.Pointer<ffi.Char> formatted = calloc<ffi.Char>(nCtx);
      if (newLen > nCtx) {
        // Reallocate buffer if needed
        malloc.free(formatted);
        formatted = calloc<ffi.Char>(nCtx);
        newLen = llama_chat_apply_template(tmplPtr, messageData, messageMaps.length, true, formatted, nCtx);
      } else {
        newLen = llama_chat_apply_template(tmplPtr, messageData, messageMaps.length, true, formatted, nCtx);
      }
      if (newLen < 0) {
        log.error("error: failed to apply the chat template");
        malloc.free(messageData);
        throw Exception('Failed to apply the chat template');
      }
      malloc.free(messageData);

      // Extract only the new prompt (from prevLen to newLen), like C++ does
      final promptBytes = formatted.cast<ffi.Uint8>().asTypedList(newLen).sublist(0, newLen);
      final prompt = utf8.decode(promptBytes);
      return prompt;
    } catch (e) {
      log.error('Error applying chat template: $e');
      throw Exception('Failed to apply the chat template: $e');
    }
  }

  // Streaming inference function that yields tokens as they are generated
  Stream<String> performStreamingInference(String prompt, {
    int maxTokens = 512,
    double? temperature,
    int? topK,
    double? topP,
    List<String>? stopSequences,
  }) async* {
    log.debug(
        'performStreamingInference(prompt: "$prompt", maxTokens: $maxTokens, temp: $temperature, topK: $topK, topP: $topP, stop: $stopSequences)');

    try {
      if (_model == null || _context == null || _model == ffi.nullptr || _context == ffi.nullptr) {
        log.warn('Model or context not initialized');
        return;
      }

      // Get vocabulary from model
      final vocab = llama_model_get_vocab(_model!);
      if (vocab.address == 0) {
        log.error("Error: failed to get vocabulary from model");
        return;
      }

      // Convert prompt to UTF-8 and get proper byte length
      final promptUtf8 = prompt.toNativeUtf8();
      final promptPtr = promptUtf8.cast<ffi.Char>();
      final promptByteLength = promptUtf8.length;

      // First call to get required token count (negative return value)
      final nPromptRequired = llama_tokenize(vocab, promptPtr, promptByteLength, ffi.nullptr, 0, true, true);
      if (nPromptRequired >= 0) {
        log.error("Error: unexpected positive return from tokenize call");
        malloc.free(promptUtf8);
        return;
      }
      final nPrompt = -nPromptRequired;

      // Allocate space for the tokens and tokenize the prompt
      final tokens = malloc<llama_token>(nPrompt);
      final actualTokens = llama_tokenize(vocab, promptPtr, promptByteLength, tokens, nPrompt, true, true);

      if (actualTokens < 0) {
        log.error("Error: failed to tokenize the prompt");
        malloc.free(promptUtf8);
        malloc.free(tokens);
        return;
      }
      log.debug("Prompt(tokenized): $actualTokens tokens");

      // Free the prompt memory now that we're done with it
      malloc.free(promptUtf8);

      // Initialize sampler
      final sparams = llama_sampler_chain_default_params();
      sparams.no_perf = false;
      final smpl = llama_sampler_chain_init(sparams);

      // Add samplers based on parameters
      if (topK != null && topK > 0) {
        llama_sampler_chain_add(smpl, llama_sampler_init_top_k(topK));
      }
      if (topP != null && topP < 1.0) {
        llama_sampler_chain_add(smpl, llama_sampler_init_top_p(topP, 1));
      }
      if (temperature != null && temperature >= 0.0) {
        llama_sampler_chain_add(smpl, llama_sampler_init_temp(temperature));
      }
      
      // Default to greedy if no other samplers, otherwise use distribution
      if (topK == null && topP == null && temperature == null) {
        llama_sampler_chain_add(smpl, llama_sampler_init_greedy());
      } else {
        llama_sampler_chain_add(smpl, llama_sampler_init_dist(0)); // 0 for random seed
      }

      // Prepare initial batch
      var batch = llama_batch_get_one(tokens, nPrompt);

      // Buffer for accumulating bytes to handle UTF-8 properly
      final byteBuffer = <int>[];
      String fullResponse = '';
      
      // Main generation loop
      int nDecode = 0;
      int newTokenId;
      final tokenPtr = malloc<llama_token>();

      for (int nPos = 0; nPos + batch.n_tokens < nPrompt + maxTokens;) {
        // Decode the batch
        if (llama_decode(_context!, batch) != 0) {
          log.error("Error: failed to decode batch");
          break;
        }

        nPos += batch.n_tokens;

        // Sample next token
        newTokenId = llama_sampler_sample(smpl, _context!, -1);

        // Check if end of generation
        if (llama_vocab_is_eog(vocab, newTokenId)) {
          log.debug("End of generation reached");
          break;
        }

        // Convert token to text piece
        final buf = malloc<ffi.Char>(128);
        int n = llama_token_to_piece(vocab, newTokenId, buf, 128, 0, true);
        if (n < 0) {
          log.error("Error: failed to convert token to piece");
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
            fullResponse += text;
            byteBuffer.clear(); // Clear buffer after successful decode

            // Check for stop sequences
            if (stopSequences != null && stopSequences.isNotEmpty) {
              bool stopped = false;
              for (final stopSeq in stopSequences) {
                if (fullResponse.endsWith(stopSeq)) {
                  log.debug('Stop sequence "$stopSeq" detected');
                  stopped = true;
                  break;
                }
              }
              if (stopped) break;
            }
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

      log.debug("Streaming completed. Sampled(decoded): $nDecode tokens");

      // Clean up memory
      malloc.free(tokens);
      malloc.free(tokenPtr);
      llama_sampler_free(smpl);
      
    } catch (e) {
      log.error('Error during streaming inference: $e');
    }
  }

  // Free model
  void freeModel() {
    if (_model != null && _model != ffi.nullptr) {
      llama_model_free(_model!);
      _model = null;
      log.debug('Model freed');
    }
  }

  // Free context
  void freeContext() {
    if (_context != null && _context != ffi.nullptr) {
      llama_free(_context!);
      _context = null;
      log.debug('Context freed');
    }
  }

  // Free the llama backend
  void freeBackend() {
    try {
      freeContext();
      freeModel();
      llama_backend_free();
      log.debug('Llama backend freed successfully');
    } catch (e) {
      log.warn('Warning: Failed to free llama backend: $e');
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
      log.info('Llama library test successful. Current time: $time microseconds');
      return true;
    } catch (e) {
      log.error('Llama library test failed: $e');
      return false;
    }
  }

  // Simple wrapper to check if model file exists
  bool modelFileExists(String modelPath) {
    final file = File(modelPath);
    log.debug('Checking if model file exists: ${file.parent} ${file.path}');
    final exists = file.existsSync();
    log.debug('Model file $modelPath exists: $exists');
    if (exists) {
      final size = file.lengthSync();
      log.debug('Model file size: ${(size / (1024 * 1024)).toStringAsFixed(2)} MB');
    }
    return exists;
  }

  // Get list of available functions in the library (debug helper)
  void listAvailableFunctions() {
    final commonFunctions = [
      'llama_backend_init',
      'llama_backend_free',
      'llama_log_set',
      //
      'llama_model_default_params',
      'llama_model_load_from_file',
      'llama_model_get_vocab',
      //
      'llama_new_context_with_model',
      'llama_context_default_params',
      'llama_init_from_model',
      'llama_n_ctx',
      'llama_n_batch',
      'llama_n_ubatch',
      'llama_n_seq_max',
      'llama_get_model',
      'llama_n_threads',
      'llama_n_threads_batch',
      //
      'llama_vocab_is_eog',
      //
      'llama_tokenize',
      'llama_token_to_piece',
      //
      'llama_model_chat_template',
      'llama_chat_apply_template',
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

    log.debug('Checking for common llama.cpp functions:');
    for (final funcName in commonFunctions) {
      try {
        _lib.lookup(funcName);
        log.debug('✅ $funcName - available');
      } catch (e) {
        log.debug('❌ $funcName - not found');
      }
    }

    final ggmlFunctions = [
      'ggml_backend_load_all',
    ];

    log.debug('Checking for ggml backend functions:');
    for (final funcName in ggmlFunctions) {
      try {
        _ggmlLib.lookup(funcName);
        log.debug('✅ $funcName - available in GGML library');
      } catch (e) {
        log.debug('❌ $funcName - not found in GGML library');
      }
    }
  }
}