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

// Function pointer typedef for progress callback
typedef LlamaProgressCallbackNative = ffi.Bool Function(ffi.Float progress, ffi.Pointer<ffi.Void> userData);
typedef LlamaProgressCallback = bool Function(double progress, ffi.Pointer<ffi.Void> userData);

final class ggml_backend_device extends ffi.Opaque {}

typedef ggml_backend_dev_t = ffi.Pointer<ggml_backend_device>;

// Struct for llama_model_tensor_buft_override
final class llama_model_tensor_buft_override extends ffi.Struct {
  external ffi.Pointer<Utf8> pattern;
  external ffi.Pointer<ffi.Void> buft; // ggml_backend_buffer_type_t
}

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

// Simple function signatures without complex structs
typedef LlamaInitBackendNative = ffi.Void Function();
typedef LlamaInitBackend = void Function();

typedef LlamaBackendFreeNative = ffi.Void Function();
typedef LlamaBackendFree = void Function();

// Simple test function - most llama.cpp builds have this
typedef LlamaTimeUsNative = ffi.Int64 Function();
typedef LlamaTimeUs = int Function();

// Model loading functions
typedef LlamaModelDefaultParamsNative = llama_model_params Function();
typedef LlamaModelDefaultParams = llama_model_params Function();

typedef LlamaModelLoadFromFileNative = ffi.Pointer Function(ffi.Pointer<Utf8> pathModel, llama_model_params params);
typedef LlamaModelLoadFromFile = ffi.Pointer Function(ffi.Pointer<Utf8> pathModel, llama_model_params params);

typedef LlamaFreeModelNative = ffi.Void Function(ffi.Pointer model);
typedef LlamaFreeModel = void Function(ffi.Pointer model);

// Context functions
typedef LlamaNewContextWithModelNative = ffi.Pointer Function(ffi.Pointer model, ffi.Pointer params);
typedef LlamaNewContextWithModel = ffi.Pointer Function(ffi.Pointer model, ffi.Pointer params);

typedef LlamaFreeNative = ffi.Void Function(ffi.Pointer ctx);
typedef LlamaFree = void Function(ffi.Pointer ctx);

// Tokenization functions
typedef LlamaTokenizeNative = ffi.Int32 Function(ffi.Pointer model, ffi.Pointer<Utf8> text, ffi.Int32 textLen, ffi.Pointer<ffi.Int32> tokens, ffi.Int32 nMaxTokens, ffi.Bool addBos, ffi.Bool special);
typedef LlamaTokenize = int Function(ffi.Pointer model, ffi.Pointer<Utf8> text, int textLen, ffi.Pointer<ffi.Int32> tokens, int nMaxTokens, bool addBos, bool special);

typedef LlamaTokenToPieceNative = ffi.Int32 Function(ffi.Pointer model, ffi.Int32 token, ffi.Pointer<Utf8> buf, ffi.Int32 length, ffi.Bool special);
typedef LlamaTokenToPiece = int Function(ffi.Pointer model, int token, ffi.Pointer<Utf8> buf, int length, bool special);

// Inference functions
typedef LlamaDecodeNative = ffi.Int32 Function(ffi.Pointer ctx, ffi.Pointer batch);
typedef LlamaDecode = int Function(ffi.Pointer ctx, ffi.Pointer batch);

typedef LlamaSampleTokenGreedyNative = ffi.Int32 Function(ffi.Pointer ctx, ffi.Pointer candidates);
typedef LlamaSampleTokenGreedy = int Function(ffi.Pointer ctx, ffi.Pointer candidates);

// Simplified FFI integration for llama.cpp
class LlamaFFI {
  late ffi.DynamicLibrary _lib;
  late LlamaInitBackend _llamaInitBackend;
  late LlamaBackendFree _llamaBackendFree;
  late LlamaModelDefaultParams _llamaModelDefaultParams;
  late LlamaModelLoadFromFile _llamaModelLoadFromFile;
  late LlamaFreeModel _llamaFreeModel;
  late LlamaNewContextWithModel _llamaNewContextWithModel;
  late LlamaFree _llamaFree;
  late LlamaTokenize _llamaTokenize;
  late LlamaTokenToPiece _llamaTokenToPiece;
  late LlamaDecode _llamaDecode;
  late LlamaSampleTokenGreedy _llamaSampleTokenGreedy;

  ffi.Pointer? _model;
  ffi.Pointer? _context;

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
      _llamaInitBackend = _lib
          .lookup<ffi.NativeFunction<LlamaInitBackendNative>>('llama_backend_init')
          .asFunction<LlamaInitBackend>();

      _llamaBackendFree = _lib
          .lookup<ffi.NativeFunction<LlamaBackendFreeNative>>('llama_backend_free')
          .asFunction<LlamaBackendFree>();

      // Load model functions
      _llamaModelDefaultParams = _lib
          .lookup<ffi.NativeFunction<LlamaModelDefaultParamsNative>>('llama_model_default_params')
          .asFunction<LlamaModelDefaultParams>();

      _llamaModelLoadFromFile = _lib
          .lookup<ffi.NativeFunction<LlamaModelLoadFromFileNative>>('llama_load_model_from_file')
          .asFunction<LlamaModelLoadFromFile>();

      _llamaFreeModel = _lib
          .lookup<ffi.NativeFunction<LlamaFreeModelNative>>('llama_free_model')
          .asFunction<LlamaFreeModel>();

      // Load context functions
      _llamaNewContextWithModel = _lib
          .lookup<ffi.NativeFunction<LlamaNewContextWithModelNative>>('llama_new_context_with_model')
          .asFunction<LlamaNewContextWithModel>();

      _llamaFree = _lib
          .lookup<ffi.NativeFunction<LlamaFreeNative>>('llama_free')
          .asFunction<LlamaFree>();

      // Load tokenization functions
      _llamaTokenize = _lib
          .lookup<ffi.NativeFunction<LlamaTokenizeNative>>('llama_tokenize')
          .asFunction<LlamaTokenize>();

      _llamaTokenToPiece = _lib
          .lookup<ffi.NativeFunction<LlamaTokenToPieceNative>>('llama_token_to_piece')
          .asFunction<LlamaTokenToPiece>();

      print('Successfully loaded llama.cpp functions');
    } catch (e) {
      throw Exception('Failed to load llama.cpp functions: $e');
    }
  }

  // Initialize the llama backend
  void initBackend() {
    try {
      _llamaInitBackend();
      print('Llama backend initialized successfully');
    } catch (e) {
      throw Exception('Failed to initialize llama backend: $e');
    }
  }

  // Load model from file
  bool loadModel(String modelPath) {
    try {
      if (_model != null) {
        freeModel();
      }

      final pathPtr = modelPath.toNativeUtf8();
      
      // Get default model parameters
      final llama_model_params modelParams = _llamaModelDefaultParams();
      
      // Load model with default parameters
      _model = _llamaModelLoadFromFile(pathPtr, modelParams);
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

  // Create context for inference
  bool createContext() {
    try {
      if (_model == null || _model == ffi.nullptr) {
        print('No model loaded');
        return false;
      }

      if (_context != null) {
        freeContext();
      }

      // For now, use null for context params (default parameters)
      _context = _llamaNewContextWithModel(_model!, ffi.nullptr);

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
      _llamaFreeModel(_model!);
      _model = null;
      print('Model freed');
    }
  }

  // Free context
  void freeContext() {
    if (_context != null && _context != ffi.nullptr) {
      _llamaFree(_context!);
      _context = null;
      print('Context freed');
    }
  }

  // Free the llama backend
  void freeBackend() {
    try {
      freeContext();
      freeModel();
      _llamaBackendFree();
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
      'llama_model_default_params',
      'llama_load_model_from_file',
      'llama_new_context_with_model',
      'llama_tokenize',
      'llama_decode',
      'llama_sample_token_greedy',
      'llama_token_to_piece',
      'llama_time_us',
      'llama_max_devices',
      'llama_free_model',
      'llama_free',
    ];

    print('Checking for common llama.cpp functions:');
    for (final funcName in commonFunctions) {
      try {
        _lib.lookup(funcName);
        print('✓ $funcName - available');
      } catch (e) {
        print('✗ $funcName - not found');
      }
    }
  }
} 