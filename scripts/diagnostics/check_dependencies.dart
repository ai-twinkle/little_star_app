import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Windows API functions for DLL analysis
typedef GetModuleHandleW = IntPtr Function(Pointer<Utf16> lpModuleName);
typedef GetModuleHandleWDart = int Function(Pointer<Utf16> lpModuleName);

typedef LoadLibraryW = IntPtr Function(Pointer<Utf16> lpLibFileName);
typedef LoadLibraryWDart = int Function(Pointer<Utf16> lpLibFileName);

typedef GetLastError = Uint32 Function();
typedef GetLastErrorDart = int Function();

typedef FreeLibrary = Int32 Function(IntPtr hLibModule);
typedef FreeLibraryDart = int Function(int hLibModule);

void main() {
  print('=== DLL Dependency Analysis ===\n');
  
  if (!Platform.isWindows) {
    print('This script only works on Windows');
    return;
  }

  try {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    
    final loadLibraryW = kernel32
        .lookup<NativeFunction<LoadLibraryW>>('LoadLibraryW')
        .asFunction<LoadLibraryWDart>();
    
    final getLastError = kernel32
        .lookup<NativeFunction<GetLastError>>('GetLastError')
        .asFunction<GetLastErrorDart>();
    
    final freeLibrary = kernel32
        .lookup<NativeFunction<FreeLibrary>>('FreeLibrary')
        .asFunction<FreeLibraryDart>();

    // Check common dependencies that llama.cpp typically needs
    final commonDependencies = [
      'msvcr110.dll',      // Visual C++ 2012
      'msvcr120.dll',      // Visual C++ 2013
      'msvcr140.dll',      // Visual C++ 2015-2022
      'msvcp140.dll',      // Visual C++ 2015-2022 C++
      'vcruntime140.dll',  // Visual C++ 2015-2022 Runtime
      'vcruntime140_1.dll', // Visual C++ 2019-2022 Runtime
      'ucrtbase.dll',      // Universal CRT
      'kernel32.dll',      // Windows Kernel
      'user32.dll',        // Windows User
      'advapi32.dll',      // Windows Advanced API
      'ole32.dll',         // OLE
      'oleaut32.dll',      // OLE Automation
      'cudart64_11.dll',   // CUDA Runtime (if GPU version)
      'cudart64_12.dll',   // CUDA Runtime 12 (if GPU version)
      'cublas64_11.dll',   // CUDA BLAS (if GPU version)
      'cublas64_12.dll',   // CUDA BLAS 12 (if GPU version)
    ];

    print('1. Checking common Windows dependencies:');
    final missing = <String>[];
    final found = <String>[];

    for (final dll in commonDependencies) {
      final dllName = dll.toNativeUtf16();
      final handle = loadLibraryW(dllName);
      
      if (handle != 0) {
        found.add(dll);
        freeLibrary(handle);
      } else {
        final error = getLastError();
        missing.add('$dll (error: $error)');
      }
      calloc.free(dllName);
    }

    print('\n✅ Found dependencies:');
    for (final dll in found) {
      print('   ✓ $dll');
    }

    print('\n❌ Missing dependencies:');
    for (final dll in missing) {
      print('   ✗ $dll');
    }

    // Now try to load llama.dll and see what specific error we get
    print('\n2. Attempting to load llama.dll:');
    final llamaDllPath = 'llama.dll'.toNativeUtf16();
    final llamaHandle = loadLibraryW(llamaDllPath);
    
    if (llamaHandle != 0) {
      print('   ✓ llama.dll loaded successfully!');
      freeLibrary(llamaHandle);
    } else {
      final error = getLastError();
      print('   ✗ Failed to load llama.dll');
      print('   Error code: $error');
      
      // Provide specific guidance based on error code
      switch (error) {
        case 126:
          print('   Meaning: The specified module could not be found');
          print('   Likely cause: Missing dependency DLLs');
          break;
        case 127:
          print('   Meaning: The specified procedure could not be found');
          print('   Likely cause: Incompatible DLL version');
          break;
        case 193:
          print('   Meaning: Not a valid Win32 application');
          print('   Likely cause: Architecture mismatch (32-bit vs 64-bit)');
          break;
        default:
          print('   Meaning: Unknown error');
      }
    }
    calloc.free(llamaDllPath);

    print('\n3. Recommendations:');
    
    final vcRedistMissing = missing.any((dll) => 
        dll.contains('msvcr140') || 
        dll.contains('msvcp140') || 
        dll.contains('vcruntime140') ||
        dll.contains('ucrtbase'));
    
    if (vcRedistMissing) {
      print('   🎯 CRITICAL: Install Visual C++ Redistributable 2015-2022 x64');
      print('      Download: https://aka.ms/vs/17/release/vc_redist.x64.exe');
    }
    
    final cudaMissing = missing.any((dll) => dll.contains('cuda'));
    if (cudaMissing && found.any((dll) => dll.contains('cuda'))) {
      print('   💡 OPTIONAL: Your llama.dll might have GPU support');
      print('      Install CUDA Runtime if you want GPU acceleration');
    }

    print('\n4. Alternative Solutions:');
    print('   • Try different llama.cpp build (CPU-only vs GPU)');
    print('   • Use llama.cpp from official releases');
    print('   • Build llama.cpp from source with your toolchain');

  } catch (e) {
    print('Error during dependency analysis: $e');
  }
} 