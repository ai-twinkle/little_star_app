#!/bin/bash

# Bash script to build llama.cpp for Android
# Requires Android NDK to be installed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Check if Android NDK path is provided
if [ -z "$ANDROID_NDK_ROOT" ] && [ -z "$1" ]; then
    echo -e "${RED}Error: Android NDK path not found.${NC}"
    echo -e "${YELLOW}Please set ANDROID_NDK_ROOT environment variable or pass NDK path as first argument${NC}"
    echo -e "${WHITE}Example: ./build_android.sh /path/to/android-ndk${NC}"
    exit 1
fi

ANDROID_NDK=${1:-$ANDROID_NDK_ROOT}

if [ ! -d "$ANDROID_NDK" ]; then
    echo -e "${RED}Error: Android NDK not found at: $ANDROID_NDK${NC}"
    exit 1
fi

echo -e "${GREEN}Using Android NDK: $ANDROID_NDK${NC}"

# Detect host OS
UNAME_S=$(uname -s)
case "${UNAME_S}" in
    Linux*)     HOST_TAG=linux-x86_64;;
    Darwin*)    HOST_TAG=darwin-x86_64;;
    *)          echo -e "${RED}Unsupported host OS: ${UNAME_S}${NC}"; exit 1;;
esac

# Set up paths
TOOLCHAIN="$ANDROID_NDK/toolchains/llvm/prebuilt/$HOST_TAG"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LLAMA_DIR="$PROJECT_ROOT/llama.cpp"
ANDROID_LIBS_DIR="$PROJECT_ROOT/android/app/src/main/jniLibs"

# Clone llama.cpp if not exists
if [ ! -d "$LLAMA_DIR" ]; then
    echo -e "${YELLOW}Cloning llama.cpp...${NC}"
    cd "$PROJECT_ROOT"
    git clone https://github.com/ggerganov/llama.cpp.git
fi

cd "$LLAMA_DIR"

# Function to build for specific architecture
build_architecture() {
    local ABI=$1
    local OUTPUT_DIR=$2
    
    echo -e "${YELLOW}Building for $ABI...${NC}"
    
    local BUILD_DIR="build-android-$ABI"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Configure cmake
    cmake .. \
        -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" \
        -DANDROID_ABI="$ABI" \
        -DANDROID_PLATFORM=android-23 \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_EXAMPLES=OFF \
        -DLLAMA_BUILD_SERVER=OFF \
        -DLLAMA_STATIC=OFF \
        -DBUILD_SHARED_LIBS=ON \
        -DLLAMA_CURL=OFF \
        -DGGML_NO_LLAMAFILE=ON \
        -DCMAKE_C_FLAGS="-D__ANDROID_API__=23" \
        -DCMAKE_CXX_FLAGS="-D__ANDROID_API__=23"
    
    # Build
    make -j4
    
    # Find and copy the library
    LIBLLAMA=$(find . -name "libllama.so" | head -1)
    if [ -z "$LIBLLAMA" ]; then
        echo -e "${RED}Error: libllama.so not found after build for $ABI${NC}"
        return 1
    fi
    
    DEST_FILE="$OUTPUT_DIR/libllama.so"
    echo -e "${CYAN}Copying $LIBLLAMA to $DEST_FILE${NC}"
    cp "$LIBLLAMA" "$DEST_FILE"
    
    if [ -f "$DEST_FILE" ]; then
        local SIZE=$(stat -c%s "$DEST_FILE" 2>/dev/null || stat -f%z "$DEST_FILE" 2>/dev/null || echo "unknown")
        echo -e "${GREEN}Successfully built $ABI library ($SIZE bytes)${NC}"
        return 0
    else
        echo -e "${RED}Error: Failed to copy library for $ABI${NC}"
        return 1
    fi
}

# Build for both architectures
SUCCESS=true

echo -e "\n${CYAN}Building ARM64 (arm64-v8a)...${NC}"
if build_architecture "arm64-v8a" "$ANDROID_LIBS_DIR/arm64-v8a"; then
    ARM64_RESULT="SUCCESS"
else
    ARM64_RESULT="FAILED"
    SUCCESS=false
fi
cd "$LLAMA_DIR"

echo -e "\n${CYAN}Building ARM32 (armeabi-v7a)...${NC}"
if build_architecture "armeabi-v7a" "$ANDROID_LIBS_DIR/armeabi-v7a"; then
    ARM32_RESULT="SUCCESS"
else
    ARM32_RESULT="FAILED"
    SUCCESS=false
fi
cd "$LLAMA_DIR"

# Summary
echo -e "\n${CYAN}=================== BUILD SUMMARY ===================${NC}"
if [ "$ARM64_RESULT" = "SUCCESS" ]; then
    echo -e "${GREEN}✓ ARM64 (arm64-v8a): SUCCESS${NC}"
else
    echo -e "${RED}✗ ARM64 (arm64-v8a): FAILED${NC}"
fi

if [ "$ARM32_RESULT" = "SUCCESS" ]; then
    echo -e "${GREEN}✓ ARM32 (armeabi-v7a): SUCCESS${NC}"
else
    echo -e "${RED}✗ ARM32 (armeabi-v7a): FAILED${NC}"
fi

if [ "$SUCCESS" = true ]; then
    echo -e "\n${GREEN}All builds completed successfully!${NC}"
    echo -e "${YELLOW}Libraries are ready in: $ANDROID_LIBS_DIR${NC}"
    echo -e "\n${CYAN}Next steps:${NC}"
    echo -e "${WHITE}1. Run: flutter clean${NC}"
    echo -e "${WHITE}2. Run: flutter build apk --debug${NC}"
    echo -e "${WHITE}3. Test the app on your Android device${NC}"
else
    echo -e "\n${RED}Some builds failed. Check the error messages above.${NC}"
    exit 1
fi

cd "$PROJECT_ROOT" 