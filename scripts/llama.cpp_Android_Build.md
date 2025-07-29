# Building llama.cpp for Android

This guide explains how to compile llama.cpp for Android and integrate it with your Flutter app using the pre-compiled libraries approach.

## Prerequisites

1. **Android NDK**: Download and install the Android NDK
   - Via Android Studio: SDK Manager → SDK Tools → NDK (Side by side)
   - Direct download: https://developer.android.com/ndk/downloads
   - Recommended version: 25.1.8937393 or later

2. **CMake**: Required for building
   - Via Android Studio: SDK Manager → SDK Tools → CMake
   - Or install separately

3. **Git**: For cloning llama.cpp repository

## Setup

### 1. Set Environment Variable (Optional but Recommended)

#### Windows (PowerShell):
```powershell
$env:ANDROID_NDK_ROOT = "C:\Users\YourUser\AppData\Local\Android\Sdk\ndk\25.1.8937393"
```

#### Linux/macOS (Bash):
```bash
export ANDROID_NDK_ROOT="/path/to/android-sdk/ndk/25.1.8937393"
```

### 2. Verify NDK Installation

Check that your NDK contains the required files:
```
$ANDROID_NDK_ROOT/
├── build/cmake/android.toolchain.cmake
├── toolchains/llvm/prebuilt/
└── ...
```

## Building

### Option 1: Using PowerShell (Windows)

```powershell
# Navigate to project root
cd C:\path\to\your\little_star_app

# Run the build script
.\scripts\build_llama.cpp_android.ps1

# Or specify NDK path explicitly
.\scripts\build_llama.cpp_android.ps1 -AndroidNDK "C:\path\to\android-ndk"
```

### Option 2: Using Bash (Linux/macOS/WSL)

```bash
# Navigate to project root
cd /path/to/your/little_star_app

# Make script executable (if not already)
chmod +x scripts/build_llama.cpp_android.sh

# Run the build script
./scripts/build_llama.cpp_android.sh

# Or specify NDK path explicitly
./scripts/build_llama.cpp_android.sh /path/to/android-ndk
```

## What the Build Script Does

1. **Clones llama.cpp**: Downloads the latest llama.cpp source code
2. **Configures CMake**: Sets up build configuration for Android
3. **Builds for ARM64**: Compiles for 64-bit ARM devices (arm64-v8a)
4. **Builds for ARM32**: Compiles for 32-bit ARM devices (armeabi-v7a)
5. **Copies Libraries**: Places compiled `.so` files in correct Android directories

## Expected Output

After successful compilation, you should see:
```
android/app/src/main/jniLibs/
├── arm64-v8a/
│   └── libllama.so
└── armeabi-v7a/
    └── libllama.so
```

## Building and Testing Your App

After compilation:

1. **Clean Flutter build cache**:
   ```bash
   flutter clean
   ```

2. **Build Android APK**:
   ```bash
   flutter build apk --debug
   ```

3. **Install and test on device**:
   ```bash
   flutter install
   ```

## Troubleshooting

### Common Issues

1. **NDK not found**:
   - Ensure `ANDROID_NDK_ROOT` is set correctly
   - Check NDK path exists and contains required files

2. **CMake errors**:
   - Install CMake through Android Studio SDK Manager
   - Ensure CMake is in your PATH

3. **Build failures**:
   - Check you have enough disk space (build requires ~2GB)
   - Ensure internet connection for downloading dependencies
   - Try cleaning build directories: `rm -rf llama.cpp/build-android-*`

4. **Library not found in Flutter**:
   - Verify `.so` files are in correct `jniLibs` directories
   - Check file permissions
   - Ensure `flutter clean` was run after adding libraries

### Debugging Steps

1. **Verify library files**:
   ```bash
   ls -la android/app/src/main/jniLibs/*/libllama.so
   ```

2. **Check library symbols**:
   ```bash
   # On Linux/macOS with NDK
   $ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-objdump -t android/app/src/main/jniLibs/arm64-v8a/libllama.so | grep llama_backend_init
   ```

3. **Flutter app logs**:
   ```bash
   flutter logs
   ```

## File Sizes

Expected library sizes (approximate):
- ARM64: 15-25 MB
- ARM32: 12-20 MB

## Next Steps

Once libraries are built and integrated:

1. Test basic FFI functionality
2. Load and test a small GGUF model
3. Implement your AI features
4. Optimize for mobile performance

## Advanced Configuration

### Custom Build Options

You can modify the build scripts to add custom cmake flags:

```cmake
-DLLAMA_CUBLAS=ON          # Enable CUDA support (if available)
-DLLAMA_METAL=ON           # Enable Metal support (iOS/macOS)
-DLLAMA_OPENBLAS=ON        # Enable OpenBLAS
-DCMAKE_BUILD_TYPE=Debug   # Debug build for troubleshooting
```

### Reducing Library Size

To reduce binary size:
```cmake
-DLLAMA_ALL_WARNINGS=OFF
-DLLAMA_BUILD_TESTS=OFF
-DLLAMA_BUILD_EXAMPLES=OFF
-DCMAKE_BUILD_TYPE=MinSizeRel
```

## Support

If you encounter issues:
1. Check this README for common solutions
2. Review llama.cpp documentation: https://github.com/ggerganov/llama.cpp
3. Check Flutter FFI documentation: https://dart.dev/guides/libraries/c-interop 