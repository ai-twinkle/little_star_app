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
    all_checks=false
elif [ ! -d "$ANDROID_NDK" ]; then
    echo -e "   ${RED}✗ Android NDK not found at: $ANDROID_NDK${NC}"
    all_checks=false
else
    echo -e "   ${GREEN}✓ Android NDK found: $ANDROID_NDK${NC}"
    
    # Check NDK components
    toolchain="$ANDROID_NDK/build/cmake/android.toolchain.cmake"
    if [ -f "$toolchain" ]; then
        echo -e "   ${GREEN}✓ CMake toolchain found${NC}"
    else
        echo -e "   ${RED}✗ CMake toolchain missing${NC}"
        all_checks=false
    fi
    
    prebuilt="$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64"
    if [ -d "$prebuilt" ]; then
        echo -e "   ${GREEN}✓ LLVM toolchain found${NC}"
    else
        echo -e "   ${RED}✗ LLVM toolchain missing${NC}"
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
    echo -e "   ${CYAN}→ Install CMake through Android Studio or package manager${NC}"
    all_checks=false
fi

# Check 3: Git
echo -e "\n${YELLOW}3. Checking Git...${NC}"
if command -v git >/dev/null 2>&1; then
    git_version=$(git --version 2>/dev/null)
    echo -e "   ${GREEN}✓ Git found: $git_version${NC}"
else
    echo -e "   ${RED}✗ Git not found in PATH${NC}"
    echo -e "   ${CYAN}→ Install Git using your package manager (apt, yum, etc.)${NC}"
    all_checks=false
fi

# Check 4: Flutter
echo -e "\n${YELLOW}4. Checking Flutter...${NC}"
if command -v flutter >/dev/null 2>&1; then
    flutter_version=$(flutter --version 2>/dev/null | head -n1)
    echo -e "   ${GREEN}✓ Flutter found: $flutter_version${NC}"
else
    echo -e "   ${RED}✗ Flutter not found in PATH${NC}"
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