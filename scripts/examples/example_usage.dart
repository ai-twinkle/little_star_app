import '../../lib/llama_ffi.dart';

void main() {
  print('=== Llama.cpp FFI Integration Example ===');
  
  try {
    // Initialize the FFI wrapper
    print('\n1. Initializing Llama FFI...');
    final llamaFFI = LlamaFFI();
    
    // Initialize the backend
    print('\n2. Initializing Llama backend...');
    llamaFFI.initBackend();
    
    // Test the library
    print('\n3. Testing library functions...');
    final testResult = llamaFFI.testLibrary();
    print('Library test result: $testResult');
    
    // Check model file
    print('\n4. Checking model file...');
    final modelPath = 'Llama-3.2-3B-F1-Reasoning-Instruct-Q4_K_M.gguf';
    final modelExists = llamaFFI.modelFileExists(modelPath);
    print('Model file exists: $modelExists');
    
    // List available functions
    print('\n5. Listing available functions...');
    llamaFFI.listAvailableFunctions();
    
    // Cleanup
    print('\n6. Cleaning up...');
    llamaFFI.freeBackend();
    
    print('\n=== FFI Integration Complete ===');
    
  } catch (e) {
    print('Error during FFI integration: $e');
    print('\nPossible issues:');
    print('- llama.dll not found in the current directory');
    print('- llama.dll is not compatible with your system');
    print('- Missing dependencies for llama.dll');
    print('- Incorrect llama.cpp version');
  }
}