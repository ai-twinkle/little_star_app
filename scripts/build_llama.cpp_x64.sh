#!/bin/bash

# Bash script to build llama.cpp for x64
# Builds optimized llama.cpp library for desktop/server environments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Check for required tools
check_dependencies() {
    local missing_deps=()
    
    if ! command -v cmake &> /dev/null; then
        missing_deps+=("cmake")
    fi
    
    if ! command -v make &> /dev/null; then
        missing_deps+=("make")
    fi
    
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required dependencies: ${missing_deps[*]}${NC}"
        echo -e "${YELLOW}Please install the missing dependencies and try again${NC}"
        exit 1
    fi
}

# Detect number of CPU cores for parallel builds
get_cpu_cores() {
    local cores
    if command -v nproc &> /dev/null; then
        cores=$(nproc)
    elif [ -f /proc/cpuinfo ]; then
        cores=$(grep -c ^processor /proc/cpuinfo)
    elif command -v sysctl &> /dev/null; then
        cores=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
    else
        cores=4
    fi
    echo $cores
}

echo -e "${GREEN}Building llama.cpp for x64 architecture${NC}"

# Check dependencies
check_dependencies

# Set up paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LLAMA_DIR="$PROJECT_ROOT/llama.cpp"
OUTPUT_DIR="$PROJECT_ROOT/native/libs/x64"

echo -e "${CYAN}Project root: $PROJECT_ROOT${NC}"
echo -e "${CYAN}Output directory: $OUTPUT_DIR${NC}"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Clone llama.cpp if not exists
if [ ! -d "$LLAMA_DIR" ]; then
    echo -e "${YELLOW}Cloning llama.cpp...${NC}"
    cd "$PROJECT_ROOT"
    git clone https://github.com/ggerganov/llama.cpp.git
    echo -e "${GREEN}llama.cpp cloned successfully${NC}"
else
    echo -e "${GREEN}Using existing llama.cpp directory${NC}"
fi

cd "$LLAMA_DIR"

# Function to build llama.cpp
build_llamacpp() {
    echo -e "${YELLOW}Building llama.cpp for x64...${NC}"
    
    local BUILD_DIR="build-x64"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"
    
    # Get CPU cores for parallel build
    local CPU_CORES=$(get_cpu_cores)
    echo -e "${CYAN}Using $CPU_CORES CPU cores for parallel build${NC}"
    
    # Configure cmake with optimizations
    echo -e "${CYAN}Configuring cmake...${NC}"
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_EXAMPLES=OFF \
        -DLLAMA_BUILD_SERVER=OFF \
        -DLLAMA_STATIC=OFF \
        -DBUILD_SHARED_LIBS=ON \
        -DLLAMA_CURL=OFF \
        -DGGML_NO_LLAMAFILE=ON \
        -DGGML_NATIVE=ON \
        -DGGML_AVX=ON \
        -DGGML_AVX2=ON \
        -DGGML_FMA=ON \
        -DGGML_F16C=ON \
        -DCMAKE_C_FLAGS="-O3 -march=native -mtune=native" \
        -DCMAKE_CXX_FLAGS="-O3 -march=native -mtune=native"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: CMake configuration failed${NC}"
        return 1
    fi
    
    # Build
    echo -e "${CYAN}Building with make -j$CPU_CORES...${NC}"
    make -j$CPU_CORES
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Error: Build failed${NC}"
        return 1
    fi
    
    # Find and copy the library
    LIBLLAMA=$(find . -name "libllama.so" -o -name "libllama.dylib" | head -1)
    if [ -z "$LIBLLAMA" ]; then
        echo -e "${RED}Error: libllama shared library not found after build${NC}"
        return 1
    fi
    
    # Copy library to output directory
    DEST_FILE="$OUTPUT_DIR/$(basename "$LIBLLAMA")"
    echo -e "${CYAN}Copying $LIBLLAMA to $DEST_FILE${NC}"
    cp "$LIBLLAMA" "$DEST_FILE"
    
    if [ -f "$DEST_FILE" ]; then
        local SIZE=$(stat -c%s "$DEST_FILE" 2>/dev/null || stat -f%z "$DEST_FILE" 2>/dev/null || echo "unknown")
        echo -e "${GREEN}Successfully built x64 library ($SIZE bytes)${NC}"
        
        # Also copy any additional binaries that might be useful
        if [ -f "./bin/llama-cli" ]; then
            echo -e "${CYAN}Copying llama-cli binary...${NC}"
            cp "./bin/llama-cli" "$OUTPUT_DIR/"
        fi
        
        if [ -f "./bin/llama-server" ]; then
            echo -e "${CYAN}Copying llama-server binary...${NC}"
            cp "./bin/llama-server" "$OUTPUT_DIR/"
        fi
        
        return 0
    else
        echo -e "${RED}Error: Failed to copy library${NC}"
        return 1
    fi
}

# Build the library
echo -e "\n${CYAN}Starting build process...${NC}"
if build_llamacpp; then
    BUILD_RESULT="SUCCESS"
else
    BUILD_RESULT="FAILED"
fi

# Summary
echo -e "\n${CYAN}=================== BUILD SUMMARY ===================${NC}"
if [ "$BUILD_RESULT" = "SUCCESS" ]; then
    echo -e "${GREEN}✓ x64 build: SUCCESS${NC}"
    echo -e "\n${GREEN}Build completed successfully!${NC}"
    echo -e "${YELLOW}Library is ready in: $OUTPUT_DIR${NC}"
    
    # List output files
    echo -e "\n${CYAN}Generated files:${NC}"
    ls -la "$OUTPUT_DIR"
    
    echo -e "\n${CYAN}Next steps:${NC}"
    echo -e "${WHITE}1. Library can be used in your application${NC}"
    echo -e "${WHITE}2. Include the library in your project dependencies${NC}"
    echo -e "${WHITE}3. Test the library with your use case${NC}"
else
    echo -e "${RED}✗ x64 build: FAILED${NC}"
    echo -e "\n${RED}Build failed. Check the error messages above.${NC}"
    exit 1
fi

cd "$PROJECT_ROOT" 