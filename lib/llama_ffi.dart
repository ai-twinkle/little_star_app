import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

// Simple function signatures without complex structs
typedef LlamaInitBackendNative = Void Function();
typedef LlamaInitBackend = void Function();

typedef LlamaBackendFreeNative = Void Function();
typedef LlamaBackendFree = void Function();

// Simple test function - most llama.cpp builds have this
typedef LlamaTimeUsNative = Int64 Function();
typedef LlamaTimeUs = int Function();

// Simplified FFI integration for llama.cpp
class LlamaFFI {
  late DynamicLibrary _lib;
  late LlamaInitBackend _llamaInitBackend;
  late LlamaBackendFree _llamaBackendFree;

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
        _lib = DynamicLibrary.open('libllama.so');
      } else {
        _lib = DynamicLibrary.open(libraryPath);
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
          .lookup<NativeFunction<LlamaInitBackendNative>>('llama_backend_init')
          .asFunction<LlamaInitBackend>();

      _llamaBackendFree = _lib
          .lookup<NativeFunction<LlamaBackendFreeNative>>('llama_backend_free')
          .asFunction<LlamaBackendFree>();

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

  // Free the llama backend
  void freeBackend() {
    try {
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
          .lookup<NativeFunction<LlamaTimeUsNative>>('llama_time_us')
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
      'llama_model_load_from_file',
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