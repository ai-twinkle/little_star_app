# PowerShell script to build llama.cpp for Android
# Requires Android NDK to be installed

param(
    [Parameter(Mandatory=$false)]
    [string]$AndroidNDK = $env:ANDROID_NDK_ROOT
)

# Check if Android NDK path is provided
if (-not $AndroidNDK) {
    Write-Host "Error: Android NDK path not found. Please set ANDROID_NDK_ROOT environment variable or pass -AndroidNDK parameter" -ForegroundColor Red
    Write-Host "Example: .\scripts\build_llama.cpp_android.ps1 -AndroidNDK 'C:\Users\YourUser\AppData\Local\Android\Sdk\ndk\25.1.8937393'" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $AndroidNDK)) {
    Write-Host "Error: Android NDK not found at: $AndroidNDK" -ForegroundColor Red
    exit 1
}

Write-Host "Using Android NDK: $AndroidNDK" -ForegroundColor Green

# Set up paths
$TOOLCHAIN = Join-Path $AndroidNDK "toolchains\llvm\prebuilt\windows-x86_64"
$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
$LLAMA_DIR = Join-Path $PROJECT_ROOT "llama.cpp"
$ANDROID_LIBS_DIR = Join-Path $PROJECT_ROOT "android\app\src\main\jniLibs"

# Clone llama.cpp if not exists
if (-not (Test-Path $LLAMA_DIR)) {
    Write-Host "Cloning llama.cpp..." -ForegroundColor Yellow
    Set-Location $PROJECT_ROOT
    git clone https://github.com/ggerganov/llama.cpp.git
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to clone llama.cpp" -ForegroundColor Red
        exit 1
    }
}

Set-Location $LLAMA_DIR

# Function to build for specific architecture
function Build-Architecture {
    param(
        [string]$ABI,
        [string]$OutputDir
    )
    
    Write-Host "Building for $ABI..." -ForegroundColor Yellow
    
    $BUILD_DIR = "build-android-$ABI"
    if (Test-Path $BUILD_DIR) {
        try {
            Remove-Item -Recurse -Force $BUILD_DIR -ErrorAction Stop
        } catch {
            Write-Host "Warning: Could not remove existing build directory, trying to continue..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
        }
    }
    if (-not (Test-Path $BUILD_DIR)) {
        New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null
    }
    Set-Location $BUILD_DIR
    
    # Configure cmake with explicit generator and toolchain
    $CMAKE_ARGS = @(
        ".."
        "-G", "Unix Makefiles"
        "-DCMAKE_TOOLCHAIN_FILE=$AndroidNDK\build\cmake\android.toolchain.cmake"
        "-DANDROID_ABI=$ABI"
        "-DANDROID_PLATFORM=android-21"
        "-DCMAKE_BUILD_TYPE=Release"
        "-DLLAMA_BUILD_TESTS=OFF"
        "-DLLAMA_BUILD_EXAMPLES=OFF"
        "-DLLAMA_BUILD_SERVER=OFF"
        "-DLLAMA_STATIC=OFF"
        "-DBUILD_SHARED_LIBS=ON"
        "-DLLAMA_CURL=OFF"
        "-DLLAMA_NATIVE=OFF"
        "-DLLAMA_LTO=OFF"
        "-DGGML_LLAMAFILE=OFF"
        "-DCMAKE_MAKE_PROGRAM=$AndroidNDK\prebuilt\windows-x86_64\bin\make.exe"
    )
    
    Write-Host "Configuring CMake..." -ForegroundColor Cyan
    cmake @CMAKE_ARGS
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: CMake configuration failed for $ABI" -ForegroundColor Red
        return $false
    }
    
    # Build using make directly
    Write-Host "Building with Make..." -ForegroundColor Cyan
    & "$AndroidNDK\prebuilt\windows-x86_64\bin\make.exe" -j4
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Build failed for $ABI" -ForegroundColor Red
        return $false
    }
    
    # Find and copy the library
    $LIBLLAMA = Get-ChildItem -Path . -Name "libllama.so" -Recurse | Select-Object -First 1
    if (-not $LIBLLAMA) {
        # Check for libcommon or other library files
        $LIBLLAMA = Get-ChildItem -Path . -Name "*llama*.so" -Recurse | Select-Object -First 1
    }
    
    if (-not $LIBLLAMA) {
        Write-Host "Error: No .so library found after build for $ABI" -ForegroundColor Red
        Write-Host "Available files:" -ForegroundColor Yellow
        Get-ChildItem -Path . -Name "*.so" -Recurse | ForEach-Object { Write-Host "  $_" }
        return $false
    }
    
    $DEST_FILE = Join-Path $OutputDir "libllama.so"
    Write-Host "Copying $($LIBLLAMA.FullName) to $DEST_FILE" -ForegroundColor Cyan
    
    # Ensure output directory exists
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    Copy-Item $LIBLLAMA.FullName $DEST_FILE -Force
    
    if (Test-Path $DEST_FILE) {
        $size = (Get-Item $DEST_FILE).Length
        Write-Host "Successfully built $ABI library (${size} bytes)" -ForegroundColor Green
        return $true
    } else {
        Write-Host "Error: Failed to copy library for $ABI" -ForegroundColor Red
        return $false
    }
}

# Check if make is available
$MAKE_PATH = "$AndroidNDK\prebuilt\windows-x86_64\bin\make.exe"
if (-not (Test-Path $MAKE_PATH)) {
    Write-Host "Error: Make build tool not found at: $MAKE_PATH" -ForegroundColor Red
    Write-Host "Your NDK installation might be incomplete." -ForegroundColor Yellow
    exit 1
}

# Build for both architectures
$success = $true

Write-Host "`nBuilding ARM64 (arm64-v8a)..." -ForegroundColor Cyan
$arm64_result = Build-Architecture -ABI "arm64-v8a" -OutputDir (Join-Path $ANDROID_LIBS_DIR "arm64-v8a")
Set-Location $LLAMA_DIR
$success = $success -and $arm64_result

# Write-Host "`nBuilding ARM32 (armeabi-v7a)..." -ForegroundColor Cyan
# $arm32_result = Build-Architecture -ABI "armeabi-v7a" -OutputDir (Join-Path $ANDROID_LIBS_DIR "armeabi-v7a")
# Set-Location $LLAMA_DIR
# $success = $success -and $arm32_result

# Summary
Write-Host "`n=================== BUILD SUMMARY ===================" -ForegroundColor Cyan
if ($arm64_result) {
    Write-Host "✓ ARM64 (arm64-v8a): SUCCESS" -ForegroundColor Green
} else {
    Write-Host "✗ ARM64 (arm64-v8a): FAILED" -ForegroundColor Red
}

# if ($arm32_result) {
#     Write-Host "✓ ARM32 (armeabi-v7a): SUCCESS" -ForegroundColor Green
# } else {
#     Write-Host "✗ ARM32 (armeabi-v7a): FAILED" -ForegroundColor Red
# }

if ($success) {
    Write-Host "`nAll builds completed successfully!" -ForegroundColor Green
    Write-Host "Libraries are ready in: $ANDROID_LIBS_DIR" -ForegroundColor Yellow
    
    # Verify the libraries
    Write-Host "`nVerifying libraries:" -ForegroundColor Cyan
    $arm64lib = Join-Path $ANDROID_LIBS_DIR "arm64-v8a\libllama.so"
    # $arm32lib = Join-Path $ANDROID_LIBS_DIR "armeabi-v7a\libllama.so"
    
    if (Test-Path $arm64lib) {
        $size = (Get-Item $arm64lib).Length / 1MB
        Write-Host "  ✓ ARM64: $([math]::Round($size, 1)) MB" -ForegroundColor Green
    }
    
    # if (Test-Path $arm32lib) {
    #     $size = (Get-Item $arm32lib).Length / 1MB
    #     Write-Host "  ✓ ARM32: $([math]::Round($size, 1)) MB" -ForegroundColor Green
    # }
    
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Run: flutter clean" -ForegroundColor White
    Write-Host "2. Run: flutter build apk --debug" -ForegroundColor White
    Write-Host "3. Test the app on your Android device" -ForegroundColor White
} else {
    Write-Host "`nSome builds failed. Check the error messages above." -ForegroundColor Red
    exit 1
}

Set-Location $PROJECT_ROOT 