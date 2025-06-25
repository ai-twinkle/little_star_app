# Wrapping Llama.cpp Functions in Flutter FFI

This guide explains how to add new llama.cpp functions to the LlamaFFI class in `lib/llama_ffi.dart`.

## Overview

The LlamaFFI class provides a Flutter-friendly wrapper around the native llama.cpp library. To add new functionality, you need to follow a consistent pattern for each function you want to expose.

## Step-by-Step Process

### 1. Define Function Signatures

For each native function, you need to define two typedef signatures:
- `*Native`: The exact C function signature
- `*Dart`: The Dart-compatible function signature

```dart
// Example: Model loading function
typedef LlamaModelLoadFromFileNative = Pointer Function(Pointer<Utf8> pathModel, Pointer params);
typedef LlamaModelLoadFromFile = Pointer Function(Pointer<Utf8> pathModel, Pointer params);

// Example: Simple function returning default parameters
typedef LlamaModelDefaultParamsNative = Pointer Function();
typedef LlamaModelDefaultParams = Pointer Function();

// Example: Function with multiple parameters
typedef LlamaTokenizeNative = Int32 Function(Pointer model, Pointer<Utf8> text, Int32 textLen, Pointer<Int32> tokens, Int32 nMaxTokens, Bool addBos, Bool special);
typedef LlamaTokenize = int Function(Pointer model, Pointer<Utf8> text, int textLen, Pointer<Int32> tokens, int nMaxTokens, bool addBos, bool special);
```

### 2. Add Class Members

Declare a late-initialized member variable for each function:

```dart
class LlamaFFI {
  // ... existing members ...
  
  late LlamaModelDefaultParams _llamaModelDefaultParams;
  late LlamaModelLoadFromFile _llamaModelLoadFromFile;
  late LlamaFreeModel _llamaFreeModel;
  late LlamaTokenize _llamaTokenize;
  
  // ... rest of class ...
}
```

### 3. Load Functions in `_loadFunctions()`

In the `_loadFunctions()` method, lookup and bind each function:

```dart
void _loadFunctions() {
  try {
    // ... existing function loading ...
    
    // Load model functions
    _llamaModelDefaultParams = _lib
        .lookup<NativeFunction<LlamaModelDefaultParamsNative>>('llama_model_default_params')
        .asFunction<LlamaModelDefaultParams>();

    _llamaModelLoadFromFile = _lib
        .lookup<NativeFunction<LlamaModelLoadFromFileNative>>('llama_load_model_from_file')
        .asFunction<LlamaModelLoadFromFile>();

    _llamaTokenize = _lib
        .lookup<NativeFunction<LlamaTokenizeNative>>('llama_tokenize')
        .asFunction<LlamaTokenize>();

    print('Successfully loaded llama.cpp functions');
  } catch (e) {
    throw Exception('Failed to load llama.cpp functions: $e');
  }
}
```

### 4. Implement Wrapper Methods

Create high-level Dart methods that use the FFI functions:

```dart
// Example: Simple wrapper that calls native function directly
bool loadModel(String modelPath) {
  try {
    if (_model != null) {
      freeModel();
    }

    final pathPtr = modelPath.toNativeUtf8();
    
    // Get default model parameters
    final modelParams = _llamaModelDefaultParams();
    
    // Load model with default parameters
    _model = _llamaModelLoadFromFile(pathPtr, modelParams);
    malloc.free(pathPtr);

    if (_model == nullptr) {
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

// Example: More complex wrapper with state management
String? performInference(String prompt, {int maxTokens = 50}) {
  try {
    if (_model == null || _context == null || _model == nullptr || _context == nullptr) {
      print('Model or context not initialized');
      return null;
    }

    print('Performing inference with prompt: $prompt');
    
    // In a real implementation, you would:
    // 1. Tokenize the prompt using _llamaTokenize
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
```

### 5. Add to Function Availability Check

Update the `listAvailableFunctions()` method to include your new functions:

```dart
void listAvailableFunctions() {
  final commonFunctions = [
    'llama_backend_init',
    'llama_backend_free',
    'llama_model_default_params',        // ← Add new functions here
    'llama_load_model_from_file',        // ← Add new functions here
    'llama_tokenize',                    // ← Add new functions here
    // ... other functions ...
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
```

## Best Practices

### Memory Management

Always handle memory allocation and deallocation properly:

```dart
// Free native UTF8 strings
final pathPtr = modelPath.toNativeUtf8();
// ... use pathPtr ...
malloc.free(pathPtr);

// Track and free model/context pointers
void freeModel() {
  if (_model != null && _model != nullptr) {
    _llamaFreeModel(_model!);
    _model = null;
    print('Model freed');
  }
}
```

### Error Handling

Wrap FFI calls in try-catch blocks and provide meaningful error messages:

```dart
bool loadModel(String modelPath) {
  try {
    // ... FFI operations ...
    return true;
  } catch (e) {
    print('Error loading model: $e');
    return false;
  }
}
```

### State Tracking

Add getter methods to check object states:

```dart
bool get isModelLoaded => _model != null && _model != nullptr;
bool get isContextCreated => _context != null && _context != nullptr;
```

### Function Name Mapping

Note that llama.cpp function names may vary between versions. Common patterns:

| C Function | Dart Method |
|------------|-------------|
| `llama_model_default_params` | `_llamaModelDefaultParams` |
| `llama_load_model_from_file` | `_llamaModelLoadFromFile` |
| `llama_new_context_with_model` | `_llamaNewContextWithModel` |
| `llama_backend_init` | `_llamaInitBackend` |

## Complete Example: Adding a New Function

Here's a complete example of adding the `llama_get_model_size` function:

```dart
// 1. Define signatures
typedef LlamaGetModelSizeNative = Int64 Function(Pointer model);
typedef LlamaGetModelSize = int Function(Pointer model);

// 2. Add class member
late LlamaGetModelSize _llamaGetModelSize;

// 3. Load in _loadFunctions()
_llamaGetModelSize = _lib
    .lookup<NativeFunction<LlamaGetModelSizeNative>>('llama_get_model_size')
    .asFunction<LlamaGetModelSize>();

// 4. Implement wrapper method
int? getModelSize() {
  try {
    if (_model == null || _model == nullptr) {
      print('No model loaded');
      return null;
    }
    
    final size = _llamaGetModelSize(_model!);
    print('Model size: $size bytes');
    return size;
  } catch (e) {
    print('Error getting model size: $e');
    return null;
  }
}

// 5. Add to function list
'llama_get_model_size',
```

## Current Implementation Status

The LlamaFFI class currently includes:

### Core Functions
- ✅ `llama_backend_init` - Initialize backend
- ✅ `llama_backend_free` - Free backend
- ✅ `llama_time_us` - Get timestamp (for testing)

### Model Functions
- ✅ `llama_model_default_params` - Get default model parameters
- ✅ `llama_load_model_from_file` - Load model from file
- ✅ `llama_free_model` - Free model memory

### Context Functions
- ✅ `llama_new_context_with_model` - Create inference context
- ✅ `llama_free` - Free context memory

### Inference Functions (Placeholder)
- 🚧 `llama_tokenize` - Convert text to tokens
- 🚧 `llama_token_to_piece` - Convert tokens to text
- 🚧 `llama_decode` - Process tokens through model
- 🚧 `llama_sample_token_greedy` - Sample next token

### High-Level Methods
- ✅ `loadModel()` - Load and initialize model
- ✅ `createContext()` - Create inference context
- 🚧 `performInference()` - Generate text (currently returns placeholder)
- ✅ `isModelLoaded` - Check model status
- ✅ `isContextCreated` - Check context status

## Next Steps

To implement full inference capability, you would need to add:

1. **Batch Management**: `llama_batch_init`, `llama_batch_free`
2. **Token Sampling**: `llama_sample_token_mirostat`, `llama_sample_token_top_k`
3. **Model Information**: `llama_model_meta_val_str`, `llama_model_meta_count`
4. **Advanced Context**: `llama_context_default_params`

Each function should follow the same pattern outlined in this guide. 