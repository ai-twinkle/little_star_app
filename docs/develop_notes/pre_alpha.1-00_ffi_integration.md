# Llama.cpp FFI Integration for Flutter

This project demonstrates a simple Foreign Function Interface (FFI) integration with the llama.cpp library in a Flutter application.

## 🎯 What's Included

- **LlamaFFI Class** (`lib/llama_ffi.dart`) - Main FFI wrapper for llama.cpp
- **Diagnostics Tool** (`lib/llama_diagnostics.dart`) - Helps diagnose setup issues
- **Flutter Integration** (`lib/main.dart`) - Demo app showing FFI usage
- **Example Scripts** - Standalone examples for testing

## 📋 Prerequisites

### Windows (Current Setup)
1. **Visual C++ Redistributable 2022 (x64)** - **REQUIRED**
   - Download from: https://docs.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist
   - Install the x64 version

2. **Compatible llama.dll**
   - ✅ You already have: `llama.dll` (1.44MB)
   - ✅ Model file: `Llama-3.2-3B-F1-Reasoning-Instruct-Q4_K_M.gguf` (2.09GB)

## 🔧 Current Issue & Solution

**Problem:** DLL loading fails with error code 126 (module not found)

**Root Cause (via `dumpbin /dependents` analysis):**
Your `llama.dll` depends on **missing companion DLLs**:

### **Critical Missing Dependencies:**
- ❌ `ggml.dll` - Core machine learning library
- ❌ `ggml-base.dll` - Base ggml components

### **Required Runtime Dependencies:**
- ❌ `MSVCP140.dll` - Visual C++ 2015-2022 C++ Runtime
- ❌ `VCRUNTIME140.dll` - Visual C++ 2015-2022 Runtime
- ❌ `api-ms-win-crt-*.dll` - Universal C Runtime components

**Solutions:**
1. **Get complete llama.cpp package** (contains all DLLs)
2. **Install Visual C++ Redistributable 2022 x64**

```bash
# After fixing dependencies, test the integration:
dart run ./scripts/diagnostics/check_dependencies.dart
```

## 🚀 Quick Start

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Run Diagnostics
```bash
dart run ./scripts/diagnostics/diagnostics.dart
```

### 3. Test Basic Integration
```bash
dart run ./scripts/examples/example_usage.dart
```

### 4. Run Flutter App
```bash
flutter run
```

## 📁 File Structure

```
lib/
├── llama_ffi.dart          # Main FFI wrapper
├── llama_diagnostics.dart  # Diagnostics tool
└── main.dart              # Flutter app with FFI demo

# Root files
├── llama.dll              # llama.cpp library (1.44MB) ✅ PRESENT
├── ggml.dll              # Core ML library ❌ MISSING
├── ggml-base.dll         # Base ggml components ❌ MISSING
├── Llama-3.2-3B-F1-Reasoning-Instruct-Q4_K_M.gguf  # Model file (2.09GB) ✅ PRESENT
```

## 🔍 FFI Wrapper Features

### Current Implementation (Basic)
- ✅ Library loading with platform detection
- ✅ Backend initialization (`llama_backend_init`)
- ✅ Backend cleanup (`llama_backend_free`)
- ✅ Function availability checking
- ✅ Model file validation
- ✅ Comprehensive error handling

### Simplified Functions
```dart
final llamaFFI = LlamaFFI();
llamaFFI.initBackend();                    // Initialize llama backend
llamaFFI.testLibrary();                    // Test library functionality
llamaFFI.modelFileExists(modelPath);       // Check if model exists
llamaFFI.listAvailableFunctions();         // Debug helper
llamaFFI.freeBackend();                    // Cleanup
```

## 🔧 Troubleshooting

### Error Code 126 (Current Issue)
```
Failed to load dynamic library: The specified module could not be found (error code: 126)
```

**Actual Dependencies (via dumpbin analysis):**
```
llama.dll depends on:
  ❌ ggml.dll
  ❌ ggml-base.dll
  ✅ KERNEL32.dll
  ❌ MSVCP140.dll
  ❌ VCRUNTIME140.dll
  ❌ api-ms-win-crt-*.dll (Universal CRT)
```

**Solutions in order of priority:**
1. **Get complete llama.cpp package** with all companion DLLs
2. **Install Visual C++ Redistributable 2022 x64**
3. **Download from**: https://github.com/ggerganov/llama.cpp/releases

### Error Code 127
Missing function in DLL
**Solution:** Use compatible llama.cpp version

### Error Code 193
Wrong architecture (32-bit vs 64-bit)
**Solution:** Ensure 64-bit DLL for 64-bit Dart

### Dependency Analysis Commands
```bash
# Check DLL dependencies (Windows)
dumpbin.exe /dependents .\llama.dll

# Run custom dependency checker
dart run check_dependencies.dart

# List available functions in DLL
dumpbin.exe /exports .\llama.dll
```

## 🔬 Advanced Usage (Future Extensions)

The current implementation provides a foundation. You can extend it with:

### Model Loading
```dart
// Future implementation example
final model = llamaFFI.loadModel('path/to/model.gguf');
final context = llamaFFI.newContext(model);
```

### Text Generation
```dart
// Future implementation example
final response = llamaFFI.generateText(
  model, 
  context, 
  'Hello, how are you?',
  maxTokens: 100
);
```

## 📚 Resources

- **llama.cpp GitHub**: https://github.com/ggerganov/llama.cpp
- **Dart FFI Documentation**: https://dart.dev/guides/libraries/c-interop
- **GGUF Models**: https://huggingface.co/models?search=gguf
- **Visual C++ Redistributable**: https://docs.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist

## 🧪 Testing Commands

```bash
# Run dependency analysis
dart run check_dependencies.dart

# Check DLL dependencies (Windows with VS tools)
dumpbin.exe /dependents .\llama.dll

# Run Flutter app (after fixing dependencies)
flutter run

# Check what DLLs are available
Get-ChildItem *.dll

# Test FFI integration
dart run lib/llama_diagnostics.dart
```

## 🎯 Next Steps

### **Immediate (Required for basic functionality):**
1. **Get Missing DLLs**: Download complete llama.cpp package containing:
   - `ggml.dll`
   - `ggml-base.dll` 
   - Compatible `llama.dll`
2. **Install Visual C++ Redistributable 2022 x64**
3. **Verify Setup**: Run `dart run check_dependencies.dart`

### **Development (After dependencies are resolved):**
4. **Test Basic Integration**: Verify library loading and function calls
5. **Extend Functionality**: Add model loading and text generation
6. **Optimize Performance**: Implement proper memory management
7. **Add Error Handling**: Improve error messages and recovery

### **Recommended Sources for Complete Package:**
- **Official Releases**: https://github.com/ggerganov/llama.cpp/releases
- **Look for**: `llama-*-win-x64.zip` files
- **Alternative**: Build from source for guaranteed compatibility

## 📝 Notes

- The current implementation focuses on basic FFI setup and diagnostics
- Model loading and text generation require more complex struct definitions
- The simplified approach avoids Dart FFI struct annotation issues
- Platform detection supports Windows, Linux, and macOS
- Memory management is important for production use

---

## 📊 **Current Status**

✅ **Completed:**
- Basic FFI wrapper implementation
- Dependency analysis tools (`check_dependencies.dart`)
- Flutter UI integration
- Comprehensive diagnostics

⚠️ **Blocked by Missing Dependencies:**
- `ggml.dll` - Core machine learning library  
- `ggml-base.dll` - Base ggml components
- Visual C++ Runtime libraries

🎯 **Next Action Required:**
Download complete llama.cpp package from official releases

---

**Last Updated**: Based on `dumpbin /dependents` analysis revealing exact dependency requirements 