# Building llama.cpp for iOS

This guide explains how to compile llama.cpp for iOS and integrate it with your Flutter app using static libraries.

## Prerequisites

1. **Xcode**: Latest version recommended
   - Download from Mac App Store or Apple Developer portal
   - Includes iOS SDK and command line tools
   - Version 14.0 or later recommended

2. **CMake**: Required for building
   - Install via Homebrew: `brew install cmake`
   - Or download from: https://cmake.org/download/
   - Version 3.20 or later required

3. **iOS SDK**: Included with Xcode
   - Supports iOS 13.0+ (required for std::filesystem)
   - Both device and simulator targets

4. **Git**: For cloning llama.cpp repository
   - Pre-installed on macOS or via Homebrew: `brew install git`

## Setup

### 1. Verify Prerequisites

#### Check Xcode Installation:
```bash
xcode-select --print-path
# Should output: /Applications/Xcode.app/Contents/Developer
```

#### Verify iOS SDK:
```bash
xcrun --sdk iphoneos --show-sdk-path
# Should output iOS SDK path
```

#### Check CMake:
```bash
cmake --version
# Should output CMake 3.20+
```

### 2. Verify Required Tools

Check that your development environment contains:
```
/Applications/Xcode.app/Contents/Developer/
├── Platforms/iPhoneOS.platform/
├── Platforms/iPhoneSimulator.platform/
├── Toolchains/XcodeDefault.xctoolchain/
└── usr/bin/xcodebuild
```

## Building

### Using the Build Script

```bash
# Navigate to project root
cd /path/to/your/little_star_app

# Make script executable
chmod +x scripts/build_llama.cpp_ios.sh

# Run the build script
./scripts/build_llama.cpp_ios.sh
```

### Manual Build (Advanced)

If you need custom configuration:

```bash
# Clone llama.cpp
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# Configure for iOS Device (ARM64)
cmake -B build-ios-device \
  -DCMAKE_TOOLCHAIN_FILE=cmake/ios.toolchain.cmake \
  -DPLATFORM=OS64 \
  -DDEPLOYMENT_TARGET=13.0 \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLAMA_METAL=ON \
  -DLLAMA_BLAS=ON \
  -DLLAMA_BUILD_TOOLS=OFF

# Build
cmake --build build-ios-device --config Release
```

## What the Build Script Does

1. **Dependency Check**: Verifies Xcode, iOS SDK, and CMake installation
2. **Clones llama.cpp**: Downloads the latest llama.cpp source code
3. **Configures CMake**: Sets up build configuration for iOS platforms
4. **Builds for ARM64 Device**: Compiles for 64-bit ARM iOS devices
5. **Builds for x86_64 Simulator**: Compiles for Intel-based iOS Simulator
6. **Builds for ARM64 Simulator**: Compiles for Apple Silicon iOS Simulator
7. **Creates Universal Libraries**: Combines compatible architectures
8. **Copies Libraries**: Places compiled `.a` files in iOS project structure

## Expected Output

After successful compilation, you should see:

```
ios/Frameworks/
├── libllama-arm64-device.a          # iOS Device (iPhone/iPad)
├── libllama-x86_64-simulator.a      # Intel Mac Simulator
├── libllama-arm64-simulator.a       # Apple Silicon Simulator
├── libllama-universal-device-x86sim.a  # Universal (Device + Intel Simulator)
├── libggml-arm64-device.a           # GGML Core - Device
├── libggml-x86_64-simulator.a       # GGML Core - Intel Simulator
├── libggml-arm64-simulator.a        # GGML Core - Apple Silicon Simulator
├── libggml-universal-device-x86sim.a   # Universal GGML Core
├── libggml-base-arm64-device.a      # GGML Base Components
├── libggml-cpu-arm64-device.a       # CPU Acceleration
├── libggml-metal-arm64-device.a     # Metal GPU Acceleration
└── libggml-blas-arm64-device.a      # BLAS Acceleration
```

## iOS Project Integration

The build script automatically configures your Xcode project with:

### 1. Library Search Paths
```
$(PROJECT_DIR)/Frameworks
```

### 2. Linker Flags
```
-force_load $(PROJECT_DIR)/Frameworks/libllama-arm64-device.a
-force_load $(PROJECT_DIR)/Frameworks/libggml-arm64-device.a
-force_load $(PROJECT_DIR)/Frameworks/libggml-base-arm64-device.a
-force_load $(PROJECT_DIR)/Frameworks/libggml-cpu-arm64-device.a
-force_load $(PROJECT_DIR)/Frameworks/libggml-metal-arm64-device.a
-force_load $(PROJECT_DIR)/Frameworks/libggml-blas-arm64-device.a
-framework Accelerate
-framework Foundation
-framework Metal
-framework MetalKit
```

### 3. Headers
Required headers are copied to:
```
ios/Runner/
├── llama.h
├── llama-cpp.h
├── ggml.h
└── ggml-*.h (all GGML headers)
```

### 4. Bridging Header
```objc
#import "GeneratedPluginRegistrant.h"

// llama.cpp headers
#include "llama.h"
#include "ggml.h"
```

## Building and Testing Your App

After compilation:

1. **Clean Flutter build cache**:
   ```bash
   flutter clean
   ```

2. **Build iOS app**:
   ```bash
   flutter build ios --debug --no-codesign
   ```

3. **Install and test on device**:
   ```bash
   # Open in Xcode
   open ios/Runner.xcworkspace
   
   # Or install directly
   flutter install --device-id YOUR_DEVICE_ID
   ```

## Architecture Support

### iOS Device (iPhone/iPad)
- **ARM64 (arm64)**: Modern iOS devices (iPhone 5s and later)
- **Optimizations**: Metal GPU acceleration, Accelerate framework, BLAS

### iOS Simulator
- **x86_64**: Intel-based Mac development machines
- **ARM64**: Apple Silicon Mac development machines
- **Note**: Simulator builds have GPU acceleration disabled

### Universal Libraries
- **Device + Intel Simulator**: For development on Intel Macs
- **Note**: ARM64 device and ARM64 simulator cannot be combined (same architecture, different platforms)

## Troubleshooting

### Common Issues

1. **Xcode not found**:
   ```bash
   sudo xcode-select --install
   sudo xcode-select --switch /Applications/Xcode.app
   ```

2. **iOS SDK version issues**:
   - Update Xcode to latest version
   - Check deployment target compatibility (iOS 13.0+)

3. **CMake configuration errors**:
   ```bash
   # Install/update CMake
   brew install cmake
   brew upgrade cmake
   ```

4. **Build failures**:
   - Check available disk space (build requires ~3GB)
   - Ensure stable internet connection
   - Clean build directories: `rm -rf llama.cpp/build-ios-*`

5. **Library linking errors**:
   - Verify all `.a` files are present in `ios/Frameworks/`
   - Check Xcode project linker flags
   - Ensure `flutter clean` was run after library updates

6. **Symbol not found at runtime**:
   - Use `-force_load` flags (already configured)
   - Verify library architecture matches device
   - Check bridging header includes

### Debugging Steps

1. **Verify library files**:
   ```bash
   ls -la ios/Frameworks/lib*.a
   ```

2. **Check library architecture**:
   ```bash
   file ios/Frameworks/libllama-arm64-device.a
   lipo -info ios/Frameworks/libllama-universal-device-x86sim.a
   ```

3. **Inspect library symbols**:
   ```bash
   nm ios/Frameworks/libllama-arm64-device.a | grep llama_backend_init
   ```

4. **Flutter app logs**:
   ```bash
   flutter logs --device-id YOUR_DEVICE_ID
   ```

5. **Xcode build logs**:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Build and check Issue Navigator for detailed errors

## Performance Optimizations

### Device Performance Features
- **Metal GPU Acceleration**: Enabled for parallel processing
- **Accelerate Framework**: Optimized BLAS operations
- **NEON Instructions**: ARM64 SIMD optimizations
- **Memory Mapping**: Efficient model loading

### Build Optimizations
```cmake
-DCMAKE_BUILD_TYPE=Release          # Release optimization
-DLLAMA_METAL=ON                    # Metal GPU support
-DLLAMA_BLAS=ON                     # Accelerate framework
-DLLAMA_BUILD_TOOLS=OFF             # Reduce binary size
-DLLAMA_BUILD_EXAMPLES=OFF          # Reduce binary size
```

## File Sizes

Expected library sizes (approximate):
- **libllama-arm64-device.a**: 2.9 MB
- **libggml-metal-arm64-device.a**: 736 KB
- **libggml-base-arm64-device.a**: 757 KB
- **libggml-cpu-arm64-device.a**: 718 KB
- **Total**: ~6-8 MB per architecture

## Flutter FFI Integration

### Library Loading (iOS-specific)
```dart
void _loadLibrary() {
  if (Platform.isIOS) {
    // On iOS, libraries are statically linked into the app bundle
    // Use DynamicLibrary.process() to access the current process
    _lib = ffi.DynamicLibrary.process();
    _ggmlLib = ffi.DynamicLibrary.process();
  }
  // ... other platforms
}
```

### Function Access
All llama.cpp functions are available through the process-wide symbol table:
- `llama_backend_init()`
- `llama_model_load_from_file()`
- `llama_new_context_with_model()`
- And all other API functions

## Next Steps

Once libraries are built and integrated:

1. **Test FFI connectivity**: Verify `llama_backend_init()` works
2. **Load a small model**: Test with a quantized model (1-3GB)
3. **Performance testing**: Benchmark inference speed
4. **Memory optimization**: Monitor memory usage patterns
5. **Production build**: Test with release configuration

## Advanced Configuration

### Custom Build Options

Modify the build script to add custom cmake flags:

```cmake
-DLLAMA_CUBLAS=OFF         # Disable CUDA (not available on iOS)
-DLLAMA_VULKAN=OFF         # Disable Vulkan (not available on iOS)
-DLLAMA_METAL=ON           # Enable Metal (recommended for iOS)
-DLLAMA_ACCELERATE=ON      # Enable Accelerate framework
-DCMAKE_BUILD_TYPE=MinSizeRel  # Minimize binary size
```

### Deployment Target Considerations

- **iOS 13.0+**: Required for std::filesystem support
- **iOS 14.0+**: Better Metal performance
- **iOS 15.0+**: Enhanced Neural Engine access

### Memory Considerations

iOS has strict memory limits:
- **Background**: ~200MB limit
- **Foreground**: ~1.5GB on modern devices
- **Model size**: Choose quantized models (Q4_0, Q4_1, Q5_0)

## Support

If you encounter issues:
1. Check this README for common solutions
2. Review llama.cpp documentation: https://github.com/ggerganov/llama.cpp
3. Check Flutter FFI documentation: https://dart.dev/guides/libraries/c-interop
4. iOS-specific issues: Apple Developer Documentation
5. Xcode build issues: Check Issue Navigator and build logs

## License

llama.cpp is licensed under the MIT License. See the llama.cpp repository for full license terms. 