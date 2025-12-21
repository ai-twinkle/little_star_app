#!/bin/bash

# Bash script to build llama.cpp for iOS
# Requires Xcode and iOS SDK to be installed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: Xcode not found.${NC}"
    echo -e "${YELLOW}Please install Xcode and command line tools${NC}"
    echo -e "${WHITE}Run: xcode-select --install${NC}"
    exit 1
fi

# Check if we have full Xcode (not just command line tools)
DEVELOPER_DIR=$(xcode-select -p)
if [[ "$DEVELOPER_DIR" == *"CommandLineTools"* ]]; then
    echo -e "${RED}Error: Only Xcode Command Line Tools detected.${NC}"
    echo -e "${YELLOW}You need the full Xcode app for iOS development.${NC}"
    echo -e "${WHITE}Please:${NC}"
    echo -e "${WHITE}1. Install Xcode from the Mac App Store${NC}"
    echo -e "${WHITE}2. Run: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer${NC}"
    echo -e "${WHITE}3. Open Xcode and accept license agreements${NC}"
    exit 1
fi

# Check if iOS SDK is available
if ! xcodebuild -showsdks | grep -q "iOS"; then
    echo -e "${RED}Error: iOS SDK not found.${NC}"
    echo -e "${YELLOW}Please ensure Xcode is properly installed with iOS SDK${NC}"
    echo -e "${WHITE}Try opening Xcode and installing additional components if prompted${NC}"
    exit 1
fi

# Check if CMake is installed
if ! command -v cmake &> /dev/null; then
    echo -e "${RED}Error: CMake not found.${NC}"
    echo -e "${YELLOW}CMake is required to build llama.cpp${NC}"
    echo -e "${WHITE}Please install CMake:${NC}"
    echo -e "${WHITE}  Option 1: brew install cmake${NC}"
    echo -e "${WHITE}  Option 2: Download from https://cmake.org/download/${NC}"
    echo -e "${WHITE}  Option 3: Install via Xcode (if available)${NC}"
    exit 1
fi

echo -e "${GREEN}Using Xcode: $(xcode-select -p)${NC}"
echo -e "${GREEN}Using CMake: $(cmake --version | head -1)${NC}"

# Get iOS SDK version
IOS_SDK_VERSION=$(xcodebuild -showsdks | grep "iOS" | tail -1 | sed 's/.*iOS \([0-9.]*\).*/\1/')
echo -e "${GREEN}iOS SDK Version: $IOS_SDK_VERSION${NC}"

# Set up paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LLAMA_DIR="$PROJECT_ROOT/llama.cpp"
IOS_LIBS_DIR="$PROJECT_ROOT/ios/Frameworks"

# Create frameworks directory if it doesn't exist
mkdir -p "$IOS_LIBS_DIR"

# Clone llama.cpp if not exists
if [ ! -d "$LLAMA_DIR" ]; then
    echo -e "${YELLOW}Cloning llama.cpp...${NC}"
    cd "$PROJECT_ROOT"
    git clone https://github.com/ggerganov/llama.cpp.git
fi

cd "$LLAMA_DIR"

# Function to build for specific architecture and platform
build_architecture() {
    local ARCH=$1
    local PLATFORM=$2
    local SDK=$3
    local OUTPUT_DIR=$4
    
    echo -e "${YELLOW}Building for $ARCH ($PLATFORM)...${NC}"
    
    local BUILD_DIR="build-ios-$ARCH-$PLATFORM"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Set deployment target (iOS 13.0+ required for std::filesystem)
    local DEPLOYMENT_TARGET="13.0"
    
    # Configure cmake for iOS
    cmake .. \
        -DCMAKE_SYSTEM_NAME=iOS \
        -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
        -DCMAKE_OSX_SYSROOT="$SDK" \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_TOOLS=OFF \
        -DLLAMA_BUILD_EXAMPLES=OFF \
        -DLLAMA_BUILD_SERVER=OFF \
        -DLLAMA_ALL_WARNINGS=OFF \
        -DLLAMA_ALL_WARNINGS_3RD_PARTY=OFF \
        -DLLAMA_FATAL_WARNINGS=OFF \
        -DLLAMA_STATIC=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DLLAMA_CURL=OFF \
        -DGGML_NO_LLAMAFILE=ON \
        -DGGML_OPENMP=OFF \
        -DGGML_NATIVE=OFF \
        -DGGML_METAL=ON \
        -DGGML_METAL_EMBED_LIBRARY=ON \
        -DGGML_ACCELERATE=ON \
        -DCMAKE_C_FLAGS="-fPIC" \
        -DCMAKE_CXX_FLAGS="-fPIC"
    
    # Build libraries
    make -j4
    
    # Find and copy the static libraries
    LIBLLAMA=$(find . -name "libllama.a" | head -1)
    if [ -z "$LIBLLAMA" ]; then
        echo -e "${RED}Error: libllama.a not found after build for $ARCH ($PLATFORM)${NC}"
        return 1
    fi
    
    DEST_FILE="$OUTPUT_DIR/libllama-$ARCH-$PLATFORM.a"
    echo -e "${CYAN}Copying $LIBLLAMA to $DEST_FILE${NC}"
    cp "$LIBLLAMA" "$DEST_FILE"
    
    # Copy GGML libraries
    GGML_LIBS=$(find . -name "libggml*.a")
    for lib in $GGML_LIBS; do
        if [ -f "$lib" ]; then
            local lib_name=$(basename "$lib" .a)
            local dest_ggml="$OUTPUT_DIR/${lib_name}-$ARCH-$PLATFORM.a"
            echo -e "${CYAN}Copying $lib to $dest_ggml${NC}"
            cp "$lib" "$dest_ggml"
        fi
    done
    
    if [ -f "$DEST_FILE" ]; then
        local SIZE=$(stat -f%z "$DEST_FILE" 2>/dev/null || echo "unknown")
        echo -e "${GREEN}Successfully built $ARCH ($PLATFORM) library ($SIZE bytes)${NC}"
        return 0
    else
        echo -e "${RED}Error: Failed to copy library for $ARCH ($PLATFORM)${NC}"
        return 1
    fi
}

# Function to create universal library (or note why it can't be created)
create_universal_library() {
    local LIB_NAME=$1
    local OUTPUT_DIR=$2
    
    echo -e "${YELLOW}Creating universal library for $LIB_NAME...${NC}"
    
    # Find all architecture-specific libraries for this lib
    local DEVICE_LIBS=($(find "$OUTPUT_DIR" -name "${LIB_NAME}-arm64-device.a"))
    local X86_SIM_LIBS=($(find "$OUTPUT_DIR" -name "${LIB_NAME}-x86_64-simulator.a"))
    local ARM_SIM_LIBS=($(find "$OUTPUT_DIR" -name "${LIB_NAME}-arm64-simulator.a"))
    
    if [ ${#DEVICE_LIBS[@]} -eq 0 ] && [ ${#X86_SIM_LIBS[@]} -eq 0 ] && [ ${#ARM_SIM_LIBS[@]} -eq 0 ]; then
        echo -e "${RED}Error: No libraries found for $LIB_NAME${NC}"
        return 1
    fi
    
    # Create separate universal libraries to avoid arm64 conflicts
    local SUCCESS=true
    
    # Create device + x86_64 simulator universal library (if both exist)
    if [ ${#DEVICE_LIBS[@]} -gt 0 ] && [ ${#X86_SIM_LIBS[@]} -gt 0 ]; then
        local UNIVERSAL_LIB="$OUTPUT_DIR/${LIB_NAME}-universal-device-x86sim.a"
        local LIBS_TO_COMBINE=("${DEVICE_LIBS[@]}" "${X86_SIM_LIBS[@]}")
        
        echo -e "${CYAN}Creating device+x86sim universal library: $UNIVERSAL_LIB${NC}"
        if lipo -create "${LIBS_TO_COMBINE[@]}" -output "$UNIVERSAL_LIB" 2>/dev/null; then
            local SIZE=$(stat -f%z "$UNIVERSAL_LIB" 2>/dev/null || echo "unknown")
            echo -e "${GREEN}Successfully created $LIB_NAME device+x86sim library ($SIZE bytes)${NC}"
            lipo -info "$UNIVERSAL_LIB"
        else
            echo -e "${RED}Failed to create device+x86sim universal library for $LIB_NAME${NC}"
            SUCCESS=false
        fi
    fi
    
    # Note: ARM64 device and ARM64 simulator cannot be combined into one fat binary
    # They need to be handled separately or use XCFramework
    if [ ${#DEVICE_LIBS[@]} -gt 0 ] && [ ${#ARM_SIM_LIBS[@]} -gt 0 ]; then
        echo -e "${YELLOW}Note: ARM64 device and ARM64 simulator libraries exist separately${NC}"
        echo -e "${YELLOW}      Use XCFramework for proper multi-platform support, or${NC}"
        echo -e "${YELLOW}      link against specific architecture libraries in Xcode${NC}"
    fi
    
    if [ "$SUCCESS" = true ]; then
        return 0
    else
        return 1
    fi
}

# Build for all architectures and platforms
SUCCESS=true

echo -e "\n${CYAN}Building ARM64 (iOS Device)...${NC}"
if build_architecture "arm64" "device" "iphoneos" "$IOS_LIBS_DIR"; then
    ARM64_DEVICE_RESULT="SUCCESS"
else
    ARM64_DEVICE_RESULT="FAILED"
    SUCCESS=false
fi
cd "$LLAMA_DIR"

echo -e "\n${CYAN}Building x86_64 (iOS Simulator)...${NC}"
if build_architecture "x86_64" "simulator" "iphonesimulator" "$IOS_LIBS_DIR"; then
    X86_64_SIM_RESULT="SUCCESS"
else
    X86_64_SIM_RESULT="FAILED"
    SUCCESS=false
fi
cd "$LLAMA_DIR"

echo -e "\n${CYAN}Building ARM64 (iOS Simulator)...${NC}"
if build_architecture "arm64" "simulator" "iphonesimulator" "$IOS_LIBS_DIR"; then
    ARM64_SIM_RESULT="SUCCESS"
else
    ARM64_SIM_RESULT="FAILED"
    SUCCESS=false
fi
cd "$LLAMA_DIR"

# Create universal libraries if builds were successful
if [ "$SUCCESS" = true ]; then
    echo -e "\n${CYAN}Creating universal libraries...${NC}"

    # Create universal libllama
    if ! create_universal_library "libllama" "$IOS_LIBS_DIR"; then
        SUCCESS=false
    fi

    # Create universal GGML libraries
    GGML_LIB_NAMES=$(find "$IOS_LIBS_DIR" -name "libggml*-arm64-device.a" | sed 's/.*\/\(libggml[^-]*\)-.*/\1/' | sort -u)
    for lib_name in $GGML_LIB_NAMES; do
        if ! create_universal_library "$lib_name" "$IOS_LIBS_DIR"; then
            SUCCESS=false
        fi
    done

    # Copy header files to ios/Runner to keep them in sync with libraries
    echo -e "\n${CYAN}Copying header files to ios/Runner...${NC}"
    IOS_RUNNER_DIR="$PROJECT_ROOT/ios/Runner"

    # Copy llama.h
    if [ -f "$LLAMA_DIR/include/llama.h" ]; then
        cp "$LLAMA_DIR/include/llama.h" "$IOS_RUNNER_DIR/"
        echo -e "${GREEN}  ✓ Copied llama.h${NC}"
    fi

    # Copy all ggml headers (including ggml-opt.h and gguf.h which are required by llama.h)
    for header in ggml.h ggml-alloc.h ggml-backend.h ggml-metal.h ggml-cpu.h ggml-opt.h gguf.h; do
        if [ -f "$LLAMA_DIR/ggml/include/$header" ]; then
            cp "$LLAMA_DIR/ggml/include/$header" "$IOS_RUNNER_DIR/"
            echo -e "${GREEN}  ✓ Copied $header${NC}"
        fi
    done
fi

# Summary
echo -e "\n${CYAN}=================== BUILD SUMMARY ===================${NC}"
if [ "$ARM64_DEVICE_RESULT" = "SUCCESS" ]; then
    echo -e "${GREEN}✓ ARM64 (iOS Device): SUCCESS${NC}"
else
    echo -e "${RED}✗ ARM64 (iOS Device): FAILED${NC}"
fi

if [ "$X86_64_SIM_RESULT" = "SUCCESS" ]; then
    echo -e "${GREEN}✓ x86_64 (iOS Simulator): SUCCESS${NC}"
else
    echo -e "${RED}✗ x86_64 (iOS Simulator): FAILED${NC}"
fi

if [ "$ARM64_SIM_RESULT" = "SUCCESS" ]; then
    echo -e "${GREEN}✓ ARM64 (iOS Simulator): SUCCESS${NC}"
else
    echo -e "${RED}✗ ARM64 (iOS Simulator): FAILED${NC}"
fi

if [ "$SUCCESS" = true ]; then
    echo -e "\n${GREEN}All builds completed successfully!${NC}"
    echo -e "${YELLOW}Libraries are ready in: $IOS_LIBS_DIR${NC}"
    
    echo -e "\n${CYAN}Architecture-specific libraries:${NC}"
    find "$IOS_LIBS_DIR" -name "*-arm64-device.a" | while read lib; do
        echo -e "${WHITE}  $(basename "$lib") (iOS Device)${NC}"
    done
    find "$IOS_LIBS_DIR" -name "*-x86_64-simulator.a" | while read lib; do
        echo -e "${WHITE}  $(basename "$lib") (x86_64 Simulator)${NC}"
    done
    find "$IOS_LIBS_DIR" -name "*-arm64-simulator.a" | while read lib; do
        echo -e "${WHITE}  $(basename "$lib") (ARM64 Simulator)${NC}"
    done
    
    echo -e "\n${CYAN}Universal libraries (where possible):${NC}"
    find "$IOS_LIBS_DIR" -name "*-universal*.a" | while read lib; do
        echo -e "${WHITE}  $(basename "$lib")${NC}"
    done
    
    echo -e "\n${CYAN}Next steps:${NC}"
    echo -e "${WHITE}1. Add the appropriate libraries to your Xcode project:${NC}"
    echo -e "${WHITE}   - Use universal libraries for device + x86_64 simulator${NC}"
    echo -e "${WHITE}   - Use separate ARM64 simulator libraries when needed${NC}"
    echo -e "${WHITE}2. Link against the libraries in Build Phases${NC}"
    echo -e "${WHITE}3. Add Metal framework if using GGML_METAL${NC}"
    echo -e "${WHITE}4. Run: flutter clean${NC}"
    echo -e "${WHITE}5. Run: flutter build ios --debug${NC}"
    echo -e "${WHITE}6. Test the app on your iOS device or simulator${NC}"
    echo -e "\n${YELLOW}Note: For ARM64 simulator support, consider creating XCFrameworks${NC}"
    echo -e "${YELLOW}      or conditionally link libraries based on target architecture${NC}"
else
    echo -e "\n${RED}Some builds failed. Check the error messages above.${NC}"
    exit 1
fi

cd "$PROJECT_ROOT" 