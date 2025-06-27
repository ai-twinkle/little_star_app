import 'dart:ffi' as ffi;
import 'dart:io';
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

// 
typedef llama_token = ffi.Int32;


// Simple function signatures without complex structs
typedef LlamaInitBackendNative = ffi.Void Function();
typedef LlamaInitBackend = void Function();

typedef LlamaBackendFreeNative = ffi.Void Function();
typedef LlamaBackendFree = void Function();
// Simple test function - most llama.cpp builds have this
typedef LlamaTimeUsNative = ffi.Int64 Function();
typedef LlamaTimeUs = int Function();

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

// Tokenization functions
typedef LlamaTokenizeNative = ffi.Int32 Function(ffi.Pointer<llama_vocab> vocab, ffi.Pointer<ffi.Char> text, ffi.Int32 textLen, ffi.Pointer<llama_token> tokens, ffi.Int32 nMaxTokens, ffi.Bool addBos, ffi.Bool special);
typedef LlamaTokenize = int Function(ffi.Pointer<llama_vocab> vocab, ffi.Pointer<ffi.Char> text, int textLen, ffi.Pointer<llama_token> tokens, int nMaxTokens, bool addBos, bool special);

typedef LlamaTokenToPieceNative = ffi.Int32 Function(ffi.Pointer model, ffi.Int32 token, ffi.Pointer<Utf8> buf, ffi.Int32 length, ffi.Bool special);
typedef LlamaTokenToPiece = int Function(ffi.Pointer model, int token, ffi.Pointer<Utf8> buf, int length, bool special);

// Free functions
typedef LlamaModelFreeNative = ffi.Void Function(ffi.Pointer model);
typedef LlamaModelFree = void Function(ffi.Pointer model);

typedef LlamaFreeNative = ffi.Void Function(ffi.Pointer ctx);
typedef LlamaFree = void Function(ffi.Pointer ctx);

// Simplified FFI integration for llama.cpp
class LlamaFFI {
  late ffi.DynamicLibrary _lib;
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
  late LlamaTokenize llama_tokenize;
  late LlamaTokenToPiece llama_token_to_piece;
  // 
  late LlamaModelFree llama_model_free;
  late LlamaFree llama_free;

  ffi.Pointer<llama_model>? _model;
  ffi.Pointer<llama_context>? _context;

  LlamaFFI() {
    _loadLibrary();
    _loadFunctions();
  }

  void _loadLibrary() {
    String libraryPath;
    if (Platform.isAndroid) {
      // For Android, we load the library by name, not path
      // The library will be bundled in the APK's lib folder
      libraryPath = 'libllama.so';
    } else if (Platform.isWindows) {
      libraryPath = path.join(Directory.current.path, 'llama.dll');
    } else if (Platform.isLinux) {
      libraryPath = path.join(Directory.current.path, 'libllama.so');
    } else if (Platform.isMacOS) {
      libraryPath = path.join(Directory.current.path, 'libllama.dylib');
    } else {
      throw UnsupportedError('Platform not supported');
    }

    try {
      if (Platform.isAndroid) {
        // On Android, DynamicLibrary.open() expects just the library name
        _lib = ffi.DynamicLibrary.open('libllama.so');
      } else {
        _lib = ffi.DynamicLibrary.open(libraryPath);
      }
      print('Successfully loaded llama.cpp library: $libraryPath');
    } catch (e) {
      throw Exception('Failed to load llama.cpp library: $e');
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

      // Load tokenization functions
      llama_tokenize = _lib
          .lookup<ffi.NativeFunction<LlamaTokenizeNative>>('llama_tokenize')
          .asFunction<LlamaTokenize>();

      llama_token_to_piece = _lib
          .lookup<ffi.NativeFunction<LlamaTokenToPieceNative>>('llama_token_to_piece')
          .asFunction<LlamaTokenToPiece>();

      // 
      llama_model_free = _lib
          .lookup<ffi.NativeFunction<LlamaModelFreeNative>>('llama_model_free')
          .asFunction<LlamaModelFree>();

      llama_free = _lib
          .lookup<ffi.NativeFunction<LlamaFreeNative>>('llama_free')
          .asFunction<LlamaFree>();

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
    try {
      if (_model == null || _context == null || _model == ffi.nullptr || _context == ffi.nullptr) {
        print('Model or context not initialized');
        return null;
      }

      // This is a simplified version - real implementation would need proper batch handling
      // For now, we'll return a placeholder response to test the UI
      print('Performing inference with prompt: $prompt');
      
      // In a real implementation, you would:
      // 1. Tokenize the prompt
      // 2. Create a batch with the tokens
      // 3. Process the batch through the model
      // 4. Sample tokens and convert back to text
      
      // For testing purposes, return a simple response
      return "This is a test response from the GGUF model. The prompt was: '$prompt'. Model inference is working!";
    } catch (e) {
      print('Error during inference: $e');
      return null;
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
      'llama_tokenize',
      'llama_token_to_piece',
      //
      'llama_free',
      'llama_model_free',
      
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
  }
} 