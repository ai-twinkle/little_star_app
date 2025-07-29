# PowerShell script to build llama.cpp for x64 on Windows
# Builds optimized llama.cpp library for desktop/server environments

param(
    [switch]$Clean = $false,
    [string]$BuildType = "Release"
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Colors for output
$RED = "Red"
$GREEN = "Green"
$YELLOW = "Yellow"
$CYAN = "Cyan"
$WHITE = "White"

# Function to write colored output
function Write-ColoredOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Check for required tools
function Test-Dependencies {
    $missingDeps = @()
    
    try {
        Get-Command cmake -ErrorAction Stop | Out-Null
    }
    catch {
        $missingDeps += "cmake"
    }
    
    try {
        Get-Command git -ErrorAction Stop | Out-Null
    }
    catch {
        $missingDeps += "git"
    }
    
    # Check for Visual Studio Build Tools or Visual Studio
    $vsInstallPath = ""
    try {
        $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
        if (Test-Path $vswhere) {
            $vsInstallPath = & $vswhere -latest -property installationPath -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64
        }
    }
    catch {
        # Fallback check
    }
    
    if (-not $vsInstallPath -and -not (Get-Command msbuild -ErrorAction SilentlyContinue)) {
        $missingDeps += "Visual Studio Build Tools or Visual Studio (with C++ tools)"
    }
    
    if ($missingDeps.Count -gt 0) {
        Write-ColoredOutput "Error: Missing required dependencies: $($missingDeps -join ', ')" $RED
        Write-ColoredOutput "Please install the missing dependencies and try again" $YELLOW
        Write-ColoredOutput "Required:" $YELLOW
        Write-ColoredOutput "- CMake: https://cmake.org/download/" $WHITE
        Write-ColoredOutput "- Git: https://git-scm.com/download/win" $WHITE
        Write-ColoredOutput "- Visual Studio Build Tools: https://visualstudio.microsoft.com/downloads/" $WHITE
        exit 1
    }
}

# Detect number of CPU cores for parallel builds
function Get-CpuCores {
    try {
        return [Environment]::ProcessorCount
    }
    catch {
        return 4
    }
}

Write-ColoredOutput "Building llama.cpp for x64 architecture on Windows" $GREEN

# Check dependencies
Test-Dependencies

# Set up paths
$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
$LLAMA_DIR = Join-Path $PROJECT_ROOT "llama.cpp"
$OUTPUT_DIR = Join-Path $PROJECT_ROOT "native\libs\x64"

Write-ColoredOutput "Project root: $PROJECT_ROOT" $CYAN
Write-ColoredOutput "Output directory: $OUTPUT_DIR" $CYAN

# Create output directory
if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null
}

# Clone llama.cpp if not exists
if (-not (Test-Path $LLAMA_DIR)) {
    Write-ColoredOutput "Cloning llama.cpp..." $YELLOW
    Set-Location $PROJECT_ROOT
    git clone https://github.com/ggerganov/llama.cpp.git
    Write-ColoredOutput "llama.cpp cloned successfully" $GREEN
}
else {
    Write-ColoredOutput "Using existing llama.cpp directory" $GREEN
}

Set-Location $LLAMA_DIR

# Function to build llama.cpp
function Build-LlamaCpp {
    Write-ColoredOutput "Building llama.cpp for x64..." $YELLOW
    
    $BUILD_DIR = "build-x64-windows"
    
    if ($Clean -and (Test-Path $BUILD_DIR)) {
        Write-ColoredOutput "Cleaning existing build directory..." $CYAN
        Remove-Item -Recurse -Force $BUILD_DIR
    }
    
    if (-not (Test-Path $BUILD_DIR)) {
        New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null
    }
    
    Set-Location $BUILD_DIR
    
    # Get CPU cores for parallel build
    $CPU_CORES = Get-CpuCores
    Write-ColoredOutput "Using $CPU_CORES CPU cores for parallel build" $CYAN
    
    # Configure cmake with optimizations
    Write-ColoredOutput "Configuring cmake..." $CYAN
    
    $cmakeArgs = @(
        ".."
        "-DCMAKE_BUILD_TYPE=$BuildType"
        "-DLLAMA_BUILD_TESTS=OFF"
        "-DLLAMA_BUILD_EXAMPLES=ON"
        "-DLLAMA_BUILD_SERVER=OFF"
        "-DLLAMA_STATIC=OFF"
        "-DBUILD_SHARED_LIBS=ON"
        "-DLLAMA_CURL=OFF"
        "-DGGML_NO_LLAMAFILE=ON"
        "-DGGML_NATIVE=ON"
        "-DGGML_AVX=ON"
        "-DGGML_AVX2=ON"
        "-DGGML_FMA=ON"
        "-DGGML_F16C=ON"
        "-A", "x64"
    )
    
    try {
        & cmake @cmakeArgs
        if ($LASTEXITCODE -ne 0) {
            throw "CMake configuration failed"
        }
    }
    catch {
        Write-ColoredOutput "Error: CMake configuration failed - $_" $RED
        return $false
    }
    
    # Build
    Write-ColoredOutput "Building with cmake --build (using $CPU_CORES parallel jobs)..." $CYAN
    
    try {
        & cmake --build . --config $BuildType --parallel $CPU_CORES
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed"
        }
    }
    catch {
        Write-ColoredOutput "Error: Build failed - $_" $RED
        return $false
    }
    
    # Find and copy the library
    $possiblePaths = @(
        ".\$BuildType\llama.dll",
        ".\src\$BuildType\llama.dll",
        ".\$BuildType\*.dll"
    )
    
    $LIBLLAMA = $null
    foreach ($path in $possiblePaths) {
        $found = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*llama*" } | Select-Object -First 1
        if ($found) {
            $LIBLLAMA = $found.FullName
            break
        }
    }
    
    if (-not $LIBLLAMA) {
        # Fallback: search recursively
        $LIBLLAMA = Get-ChildItem -Recurse -Filter "*.dll" | Where-Object { $_.Name -like "*llama*" } | Select-Object -First 1 | ForEach-Object { $_.FullName }
    }
    
    if (-not $LIBLLAMA) {
        Write-ColoredOutput "Error: libllama.dll not found after build" $RED
        Write-ColoredOutput "Searching for any DLL files in build directory:" $YELLOW
        Get-ChildItem -Recurse -Filter "*.dll" | ForEach-Object { Write-Host "  Found: $($_.FullName)" }
        return $false
    }
    
    # Copy library to output directory
    $DEST_FILE = Join-Path $OUTPUT_DIR (Split-Path -Leaf $LIBLLAMA)
    Write-ColoredOutput "Copying $LIBLLAMA to $DEST_FILE" $CYAN
    
    try {
        Copy-Item $LIBLLAMA $DEST_FILE -Force
        
        if (Test-Path $DEST_FILE) {
            $SIZE = (Get-Item $DEST_FILE).Length
            Write-ColoredOutput "Successfully built x64 library ($SIZE bytes)" $GREEN
            
            # Also copy any additional binaries that might be useful
            $additionalBinaries = @("llama-cli.exe", "llama-server.exe", "llama-simple.exe")
            
            foreach ($binary in $additionalBinaries) {
                $binaryPaths = @(
                    ".\$BuildType\$binary",
                    ".\bin\$BuildType\$binary"
                )
                
                foreach ($binaryPath in $binaryPaths) {
                    if (Test-Path $binaryPath) {
                        Write-ColoredOutput "Copying $binary..." $CYAN
                        Copy-Item $binaryPath (Join-Path $OUTPUT_DIR $binary) -Force
                        break
                    }
                }
            }
            
            return $true
        }
        else {
            Write-ColoredOutput "Error: Failed to copy library" $RED
            return $false
        }
    }
    catch {
        Write-ColoredOutput "Error: Failed to copy library - $_" $RED
        return $false
    }
}

# Build the library
Write-ColoredOutput "`nStarting build process..." $CYAN

try {
    $buildSuccess = Build-LlamaCpp
}
catch {
    Write-ColoredOutput "Build process failed with exception: $_" $RED
    $buildSuccess = $false
}

# Summary
Write-ColoredOutput "`n=================== BUILD SUMMARY ===================" $CYAN

if ($buildSuccess) {
    Write-ColoredOutput "✓ x64 build: SUCCESS" $GREEN
    Write-ColoredOutput "`nBuild completed successfully!" $GREEN
    Write-ColoredOutput "Library is ready in: $OUTPUT_DIR" $YELLOW
    
    # List output files
    Write-ColoredOutput "`nGenerated files:" $CYAN
    if (Test-Path $OUTPUT_DIR) {
        Get-ChildItem $OUTPUT_DIR | ForEach-Object {
            $size = if ($_.PSIsContainer) { "<DIR>" } else { $_.Length }
            Write-Host "  $($_.Name) - $size bytes"
        }
    }
    
    Write-ColoredOutput "`nNext steps:" $CYAN
    Write-ColoredOutput "1. Library can be used in your application" $WHITE
    Write-ColoredOutput "2. Include the library in your project dependencies" $WHITE
    Write-ColoredOutput "3. Test the library with your use case" $WHITE
    Write-ColoredOutput "4. Make sure to distribute the DLL with your application" $WHITE
}
else {
    Write-ColoredOutput "✗ x64 build: FAILED" $RED
    Write-ColoredOutput "`nBuild failed. Check the error messages above." $RED
    exit 1
}

# Return to project root
Set-Location $PROJECT_ROOT

Write-ColoredOutput "`nBuild script completed." $GREEN 