# PowerShell script to check Android development setup for llama.cpp compilation

param(
    [Parameter(Mandatory=$false)]
    [string]$AndroidNDK = $env:ANDROID_NDK_ROOT
)

Write-Host "=================== Android Setup Checker ===================" -ForegroundColor Cyan
Write-Host "Checking Android development environment for llama.cpp compilation" -ForegroundColor White
Write-Host ""

$allChecks = $true

# Check 1: Android NDK
Write-Host "1. Checking Android NDK..." -ForegroundColor Yellow
if (-not $AndroidNDK) {
    Write-Host "   ✗ ANDROID_NDK_ROOT not set" -ForegroundColor Red
    Write-Host "   → Set environment variable or pass -AndroidNDK parameter" -ForegroundColor Cyan
    $allChecks = $false
} elseif (-not (Test-Path $AndroidNDK)) {
    Write-Host "   ✗ Android NDK not found at: $AndroidNDK" -ForegroundColor Red
    $allChecks = $false
} else {
    Write-Host "   ✓ Android NDK found: $AndroidNDK" -ForegroundColor Green
    
    # Check NDK components
    $toolchain = Join-Path $AndroidNDK "build\cmake\android.toolchain.cmake"
    if (Test-Path $toolchain) {
        Write-Host "   ✓ CMake toolchain found" -ForegroundColor Green
    } else {
        Write-Host "   ✗ CMake toolchain missing" -ForegroundColor Red
        $allChecks = $false
    }
    
    $prebuilt = Join-Path $AndroidNDK "toolchains\llvm\prebuilt\windows-x86_64"
    if (Test-Path $prebuilt) {
        Write-Host "   ✓ LLVM toolchain found" -ForegroundColor Green
    } else {
        Write-Host "   ✗ LLVM toolchain missing" -ForegroundColor Red
        $allChecks = $false
    }
}

# Check 2: CMake
Write-Host "`n2. Checking CMake..." -ForegroundColor Yellow
try {
    $cmakeVersion = cmake --version 2>$null | Select-Object -First 1
    if ($cmakeVersion) {
        Write-Host "   ✓ CMake found: $cmakeVersion" -ForegroundColor Green
    } else {
        Write-Host "   ✗ CMake not found in PATH" -ForegroundColor Red
        Write-Host "   → Install CMake through Android Studio or separately" -ForegroundColor Cyan
        $allChecks = $false
    }
} catch {
    Write-Host "   ✗ CMake not found in PATH" -ForegroundColor Red
    Write-Host "   → Install CMake through Android Studio or separately" -ForegroundColor Cyan
    $allChecks = $false
}

# Check 3: Git
Write-Host "`n3. Checking Git..." -ForegroundColor Yellow
try {
    $gitVersion = git --version 2>$null
    if ($gitVersion) {
        Write-Host "   ✓ Git found: $gitVersion" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Git not found in PATH" -ForegroundColor Red
        Write-Host "   → Install Git from https://git-scm.com/" -ForegroundColor Cyan
        $allChecks = $false
    }
} catch {
    Write-Host "   ✗ Git not found in PATH" -ForegroundColor Red
    Write-Host "   → Install Git from https://git-scm.com/" -ForegroundColor Cyan
    $allChecks = $false
}

# Check 4: Flutter
Write-Host "`n4. Checking Flutter..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version 2>$null | Select-Object -First 1
    if ($flutterVersion) {
        Write-Host "   ✓ Flutter found: $flutterVersion" -ForegroundColor Green
    } else {
        Write-Host "   ✗ Flutter not found in PATH" -ForegroundColor Red
        $allChecks = $false
    }
} catch {
    Write-Host "   ✗ Flutter not found in PATH" -ForegroundColor Red
    $allChecks = $false
}

# Check 5: Directory structure
Write-Host "`n5. Checking project structure..." -ForegroundColor Yellow
$projectRoot = Split-Path -Parent $PSScriptRoot
$androidDir = Join-Path $projectRoot "android"
$jniLibsDir = Join-Path $projectRoot "android\app\src\main\jniLibs"

if (Test-Path $androidDir) {
    Write-Host "   ✓ Android directory found" -ForegroundColor Green
} else {
    Write-Host "   ✗ Android directory missing" -ForegroundColor Red
    $allChecks = $false
}

if (Test-Path $jniLibsDir) {
    Write-Host "   ✓ jniLibs directory ready" -ForegroundColor Green
} else {
    Write-Host "   ℹ jniLibs directory will be created during build" -ForegroundColor Cyan
}

# Check 6: Disk space
Write-Host "`n6. Checking disk space..." -ForegroundColor Yellow
$drive = (Get-Location).Drive.Name
$freeSpace = (Get-Volume -DriveLetter $drive).SizeRemaining / 1GB
if ($freeSpace -gt 5) {
    Write-Host "   ✓ Sufficient disk space: $([math]::Round($freeSpace, 1)) GB free" -ForegroundColor Green
} else {
    Write-Host "   ⚠ Low disk space: $([math]::Round($freeSpace, 1)) GB free (recommended: 5+ GB)" -ForegroundColor Yellow
}

# Summary
Write-Host "`n=================== SUMMARY ===================" -ForegroundColor Cyan
if ($allChecks) {
    Write-Host "✓ All checks passed! Ready to build llama.cpp for Android." -ForegroundColor Green
    Write-Host "`nNext steps:" -ForegroundColor Cyan
    Write-Host "1. Run: .\scripts\build_llama.cpp_android.ps1" -ForegroundColor White
    Write-Host "2. Wait for compilation (may take 20-30 minutes)" -ForegroundColor White
    Write-Host "3. Build your Flutter app: flutter build apk --debug" -ForegroundColor White
} else {
    Write-Host "✗ Some checks failed. Please fix the issues above before building." -ForegroundColor Red
    Write-Host "`nFor detailed setup instructions, see:" -ForegroundColor Cyan
    Write-Host "- scripts/llama.cpp_Android_Build.md" -ForegroundColor White
}

Write-Host "" 