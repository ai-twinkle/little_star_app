import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart' as path;

class LlamaDiagnostics {
  static void runDiagnostics() {
    print('=== Llama.cpp FFI Diagnostics ===\n');
    
    _checkPlatform();
    _checkLibraryFiles();
    _checkModelFiles();
    _attemptLibraryLoad();
    _printSetupInstructions();
  }
  
  static void _checkPlatform() {
    print('1. Platform Information:');
    print('   OS: ${Platform.operatingSystem}');
    print('   Version: ${Platform.operatingSystemVersion}');
    print('   Architecture: Unknown'); // Platform.architecture not available in Dart
    print('   Current directory: ${Directory.current.path}');
    print('');
  }
  
  static void _checkLibraryFiles() {
    print('2. Library Files Check:');
    
    final expectedFiles = Platform.isWindows 
        ? ['llama.dll']
        : Platform.isLinux 
            ? ['libllama.so']
            : ['libllama.dylib'];
    
    for (final filename in expectedFiles) {
      final file = File(filename);
      if (file.existsSync()) {
        final stat = file.statSync();
        final sizeMB = (stat.size / (1024 * 1024)).toStringAsFixed(2);
        print('   ✓ $filename - Size: ${sizeMB}MB, Modified: ${stat.modified}');
      } else {
        print('   ✗ $filename - Not found');
      }
    }
    print('');
  }
  
  static void _checkModelFiles() {
    print('3. Model Files Check:');
    
    final currentDir = Directory.current;
    final ggufFiles = currentDir
        .listSync()
        .where((entity) => entity is File && entity.path.endsWith('.gguf'))
        .cast<File>()
        .toList();
    
    if (ggufFiles.isEmpty) {
      print('   ✗ No .gguf model files found');
    } else {
      for (final file in ggufFiles) {
        final stat = file.statSync();
        final sizeGB = (stat.size / (1024 * 1024 * 1024)).toStringAsFixed(2);
        print('   ✓ ${path.basename(file.path)} - Size: ${sizeGB}GB');
      }
    }
    print('');
  }
  
  static void _attemptLibraryLoad() {
    print('4. Library Loading Test:');
    
    try {
      String libraryPath;
      if (Platform.isWindows) {
        libraryPath = path.join(Directory.current.path, 'llama.dll');
      } else if (Platform.isLinux) {
        libraryPath = path.join(Directory.current.path, 'libllama.so');
      } else if (Platform.isMacOS) {
        libraryPath = path.join(Directory.current.path, 'libllama.dylib');
      } else {
        print('   ✗ Unsupported platform');
        return;
      }
      
      final file = File(libraryPath);
      if (!file.existsSync()) {
        print('   ✗ Library file not found: $libraryPath');
        return;
      }
      
      print('   Attempting to load: $libraryPath');
      final lib = DynamicLibrary.open(libraryPath);
      print('   ✓ Library loaded successfully');
      
      // Try to look up a common function
      try {
        lib.lookup('llama_backend_init');
        print('   ✓ llama_backend_init function found');
      } catch (e) {
        print('   ✗ llama_backend_init function not found: $e');
      }
      
    } catch (e) {
      print('   ✗ Failed to load library: $e');
      
      if (Platform.isWindows) {
        print('   \nWindows-specific troubleshooting:');
        print('   - Install Visual C++ Redistributable 2022 (x64)');
        print('   - Ensure CUDA runtime is installed if using GPU version');
        print('   - Try using Dependency Walker to check missing DLLs');
      }
    }
    print('');
  }
  
  static void _printSetupInstructions() {
    print('5. Setup Instructions:');
    print('');
    
    if (Platform.isWindows) {
      print('   For Windows:');
      print('   1. Download llama.cpp from: https://github.com/ggerganov/llama.cpp/releases');
      print('   2. Get the Windows binary (llama-xxx-win-x64.zip)');
      print('   3. Extract llama.dll to your project root');
      print('   4. Install Microsoft Visual C++ Redistributable 2022 x64');
      print('   5. If using GPU: Install CUDA runtime');
      print('');
      print('   Alternative - Build from source:');
      print('   1. Install Visual Studio 2022 with C++ tools');
      print('   2. Clone: git clone https://github.com/ggerganov/llama.cpp.git');
      print('   3. Build: cmake -B build && cmake --build build --config Release');
      print('   4. Copy build/Release/llama.dll to your project');
    } else if (Platform.isLinux) {
      print('   For Linux:');
      print('   1. Install dependencies: sudo apt install build-essential cmake');
      print('   2. Clone: git clone https://github.com/ggerganov/llama.cpp.git');
      print('   3. Build: cd llama.cpp && make');
      print('   4. Copy libllama.so to your project');
    } else if (Platform.isMacOS) {
      print('   For macOS:');
      print('   1. Install Xcode command line tools: xcode-select --install');
      print('   2. Clone: git clone https://github.com/ggerganov/llama.cpp.git');
      print('   3. Build: cd llama.cpp && make');
      print('   4. Copy libllama.dylib to your project');
    }
    
    print('');
    print('   Model Files:');
    print('   - Download GGUF models from Hugging Face');
    print('   - Place .gguf files in your project root');
    print('   - Popular models: llama-2-7b-chat.Q4_K_M.gguf');
    print('');
    print('   Flutter Integration:');
    print('   - Add ffi: ^2.1.0 to pubspec.yaml');
    print('   - Run: flutter pub get');
    print('   - Use the LlamaFFI class provided');
  }
} 