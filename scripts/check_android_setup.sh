#!/bin/bash

# Shell script to check Android development setup for llama.cpp compilation

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Parse command line arguments
ANDROID_NDK=${1:-$ANDROID_NDK_ROOT}

echo -e "${CYAN}=================== Android Setup Checker ===================${NC}"
echo -e "${WHITE}Checking Android development environment for llama.cpp compilation${NC}"
echo ""

all_checks=true

# Check 1: Android NDK
echo -e "${YELLOW}1. Checking Android NDK...${NC}"
if [ -z "$ANDROID_NDK" ]; then
    echo -e "   ${RED}✗ ANDROID_NDK_ROOT not set${NC}"
    echo -e "   ${CYAN}→ Set environment variable or pass as first argument${NC}"
    echo -e "   ${CYAN}→ Install Android NDK:${NC}"
    echo -e "     ${WHITE}Option 1: Via Android Studio (SDK Manager → SDK Tools → NDK)${NC}"
    echo -e "     ${WHITE}Option 2: Direct download:${NC}"
    echo -e "     ${WHITE}  wget https://dl.google.com/android/repository/android-ndk-r25c-linux.zip${NC}"
    echo -e "     ${WHITE}  unzip android-ndk-r25c-linux.zip${NC}"
    echo -e "     ${WHITE}  export ANDROID_NDK_ROOT=/path/to/android-ndk-r25c${NC}"
    all_checks=false
elif [ ! -d "$ANDROID_NDK" ]; then
    echo -e "   ${RED}✗ Android NDK not found at: $ANDROID_NDK${NC}"
    echo -e "   ${CYAN}→ Install Android NDK at the specified path or update ANDROID_NDK_ROOT${NC}"
    echo -e "   ${CYAN}→ Download from: https://developer.android.com/ndk/downloads${NC}"
    all_checks=false
else
    echo -e "   ${GREEN}✓ Android NDK found: $ANDROID_NDK${NC}"
    
    # Check NDK components
    toolchain="$ANDROID_NDK/build/cmake/android.toolchain.cmake"
    if [ -f "$toolchain" ]; then
        echo -e "   ${GREEN}✓ CMake toolchain found${NC}"
    else
        echo -e "   ${RED}✗ CMake toolchain missing${NC}"
        echo -e "   ${CYAN}→ Your NDK installation appears incomplete${NC}"
        echo -e "   ${CYAN}→ Reinstall NDK or download complete package from:${NC}"
        echo -e "     ${WHITE}https://developer.android.com/ndk/downloads${NC}"
        all_checks=false
    fi
    
    prebuilt="$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64"
    if [ -d "$prebuilt" ]; then
        echo -e "   ${GREEN}✓ LLVM toolchain found${NC}"
    else
        echo -e "   ${RED}✗ LLVM toolchain missing${NC}"
        echo -e "   ${CYAN}→ LLVM toolchain not found for Linux x86_64${NC}"
        echo -e "   ${CYAN}→ Ensure you downloaded the correct NDK for Linux${NC}"
        echo -e "   ${CYAN}→ Expected path: \$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64${NC}"
        all_checks=false
    fi
fi

# Check 2: CMake
echo -e "\n${YELLOW}2. Checking CMake...${NC}"
if command -v cmake >/dev/null 2>&1; then
    cmake_version=$(cmake --version 2>/dev/null | head -n1)
    echo -e "   ${GREEN}✓ CMake found: $cmake_version${NC}"
else
    echo -e "   ${RED}✗ CMake not found in PATH${NC}"
    echo -e "   ${CYAN}→ Install CMake using one of these methods:${NC}"
    echo -e "     ${WHITE}Ubuntu/Debian: sudo apt update && sudo apt install cmake${NC}"
    echo -e "     ${WHITE}CentOS/RHEL:   sudo yum install cmake${NC}"
    echo -e "     ${WHITE}Fedora:        sudo dnf install cmake${NC}"
    echo -e "     ${WHITE}Arch Linux:    sudo pacman -S cmake${NC}"
    echo -e "     ${WHITE}Snap:          sudo snap install cmake --classic${NC}"
    echo -e "     ${WHITE}Or via Android Studio: SDK Manager → SDK Tools → CMake${NC}"
    all_checks=false
fi

# Check 3: Git
echo -e "\n${YELLOW}3. Checking Git...${NC}"
if command -v git >/dev/null 2>&1; then
    git_version=$(git --version 2>/dev/null)
    echo -e "   ${GREEN}✓ Git found: $git_version${NC}"
else
    echo -e "   ${RED}✗ Git not found in PATH${NC}"
    echo -e "   ${CYAN}→ Install Git using your package manager:${NC}"
    echo -e "     ${WHITE}Ubuntu/Debian: sudo apt update && sudo apt install git${NC}"
    echo -e "     ${WHITE}CentOS/RHEL:   sudo yum install git${NC}"
    echo -e "     ${WHITE}Fedora:        sudo dnf install git${NC}"
    echo -e "     ${WHITE}Arch Linux:    sudo pacman -S git${NC}"
    echo -e "     ${WHITE}Or download from: https://git-scm.com/download/linux${NC}"
    all_checks=false
fi

# Check 4: Flutter
echo -e "\n${YELLOW}4. Checking Flutter...${NC}"
if command -v flutter >/dev/null 2>&1; then
    flutter_version=$(flutter --version 2>/dev/null | head -n1)
    echo -e "   ${GREEN}✓ Flutter found: $flutter_version${NC}"
else
    echo -e "   ${RED}✗ Flutter not found in PATH${NC}"
    echo -e "   ${CYAN}→ Install Flutter SDK:${NC}"
    echo -e "     ${WHITE}1. Download: wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.0-stable.tar.xz${NC}"
    echo -e "     ${WHITE}2. Extract:  tar xf flutter_linux_3.16.0-stable.tar.xz${NC}"
    echo -e "     ${WHITE}3. Add to PATH: echo 'export PATH=\"\$HOME/flutter/bin:\$PATH\"' >> ~/.bashrc${NC}"
    echo -e "     ${WHITE}4. Reload:   source ~/.bashrc${NC}"
    echo -e "     ${WHITE}5. Verify:   flutter doctor${NC}"
    echo -e "   ${CYAN}→ Or install via Snap: sudo snap install flutter --classic${NC}"
    all_checks=false
fi

# Check 5: Directory structure
echo -e "\n${YELLOW}5. Checking project structure...${NC}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(dirname "$script_dir")"
android_dir="$project_root/android"
jni_libs_dir="$project_root/android/app/src/main/jniLibs"

if [ -d "$android_dir" ]; then
    echo -e "   ${GREEN}✓ Android directory found${NC}"
else
    echo -e "   ${RED}✗ Android directory missing${NC}"
    echo -e "   ${CYAN}→ This should be a Flutter project with Android support${NC}"
    echo -e "   ${CYAN}→ Create Flutter project: flutter create --platforms=android .${NC}"
    echo -e "   ${CYAN}→ Or add Android support: flutter create --platforms=android .${NC}"
    all_checks=false
fi

if [ -d "$jni_libs_dir" ]; then
    echo -e "   ${GREEN}✓ jniLibs directory ready${NC}"
else
    echo -e "   ${CYAN}ℹ jniLibs directory will be created during build${NC}"
fi

# Check 6: Disk space
echo -e "\n${YELLOW}6. Checking disk space...${NC}"
free_space_kb=$(df . | tail -1 | awk '{print $4}')
free_space_gb=$((free_space_kb / 1024 / 1024))

if [ $free_space_gb -gt 5 ]; then
    echo -e "   ${GREEN}✓ Sufficient disk space: ${free_space_gb} GB free${NC}"
else
    echo -e "   ${YELLOW}⚠ Low disk space: ${free_space_gb} GB free (recommended: 5+ GB)${NC}"
fi

# Summary
echo -e "\n${CYAN}=================== SUMMARY ===================${NC}"
if [ "$all_checks" = true ]; then
    echo -e "${GREEN}✓ All checks passed! Ready to build llama.cpp for Android.${NC}"
    echo -e "\n${CYAN}Next steps:${NC}"
    echo -e "${WHITE}1. Run: ./scripts/build_llama.cpp_android.sh${NC}"
    echo -e "${WHITE}2. Wait for compilation (may take 20-30 minutes)${NC}"
    echo -e "${WHITE}3. Build your Flutter app: flutter build apk --debug${NC}"
else
    echo -e "${RED}✗ Some checks failed. Please fix the issues above before building.${NC}"
    echo -e "\n${CYAN}For detailed setup instructions, see:${NC}"
    echo -e "${WHITE}- scripts/llama.cpp_Android_Build.md${NC}"
fi

echo "" 