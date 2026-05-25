#!/bin/bash
# Build llama.cpp as universal static libraries for macOS (arm64 + x86_64)
# Output: macos/Frameworks/libllama.a, libggml*.a (universal)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Requirements check
for tool in cmake xcodebuild lipo libtool; do
    if ! command -v "$tool" &>/dev/null; then
        echo -e "${RED}Error: $tool not found. Install Xcode CLT and CMake.${NC}"
        exit 1
    fi
done

MACOS_DEPLOYMENT_TARGET="13.0"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LLAMA_DIR="$PROJECT_ROOT/llama.cpp"
MACOS_LIBS_DIR="$PROJECT_ROOT/macos/Frameworks"
MACOS_HEADERS_DIR="$PROJECT_ROOT/macos/Runner"

mkdir -p "$MACOS_LIBS_DIR"
cd "$LLAMA_DIR"

echo -e "${GREEN}Using Xcode: $(xcode-select -p)${NC}"
echo -e "${GREEN}Using CMake: $(cmake --version | head -1)${NC}"
echo -e "${GREEN}macOS deployment target: $MACOS_DEPLOYMENT_TARGET${NC}"

build_arch() {
    local ARCH=$1
    local BUILD_DIR="build-macos-$ARCH"

    echo -e "\n${CYAN}Building for macOS $ARCH...${NC}"
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    cmake .. \
        -DCMAKE_SYSTEM_NAME=Darwin \
        -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET" \
        -DCMAKE_OSX_SYSROOT="macosx" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DLLAMA_STATIC=ON \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_TOOLS=OFF \
        -DLLAMA_BUILD_EXAMPLES=OFF \
        -DLLAMA_BUILD_SERVER=OFF \
        -DLLAMA_ALL_WARNINGS=OFF \
        -DLLAMA_FATAL_WARNINGS=OFF \
        -DLLAMA_CURL=OFF \
        -DGGML_METAL=ON \
        -DGGML_METAL_EMBED_LIBRARY=ON \
        -DGGML_ACCELERATE=ON \
        -DGGML_BLAS=ON \
        -DGGML_NATIVE=OFF \
        -DGGML_OPENMP=OFF \
        -DGGML_NO_LLAMAFILE=ON \
        -DCMAKE_C_FLAGS="-fPIC" \
        -DCMAKE_CXX_FLAGS="-fPIC"

    make -j$(sysctl -n hw.logicalcpu)

    # Copy per-arch libs to macos/Frameworks
    for lib in $(find . -name "libllama.a" -o -name "libggml*.a"); do
        local name=$(basename "$lib" .a)
        cp "$lib" "$MACOS_LIBS_DIR/${name}-${ARCH}.a"
        echo -e "${GREEN}  Copied ${name}-${ARCH}.a${NC}"
    done

    cd "$LLAMA_DIR"
}

# Build arm64 (required). Build x86_64 only if cross-compile SDK supports it.
build_arch "arm64"

# Check if x86_64 macOS SDK is available (needed for universal; skip on arm64-only CI)
if xcodebuild -showsdks 2>/dev/null | grep -q "macosx"; then
    echo -e "\n${CYAN}Building x86_64 (Intel)...${NC}"
    build_arch "x86_64"
    HAVE_X86=true
else
    echo -e "${YELLOW}x86_64 SDK not detected — skipping Intel slice${NC}"
    HAVE_X86=false
fi

# Create universal (fat) libraries where both slices exist
echo -e "\n${CYAN}Creating universal libraries...${NC}"
UNIVERSAL_CREATED=0
for arm_lib in "$MACOS_LIBS_DIR"/lib*-arm64.a; do
    name=$(basename "$arm_lib" -arm64.a)
    x86_lib="$MACOS_LIBS_DIR/${name}-x86_64.a"
    out="$MACOS_LIBS_DIR/${name}.a"

    if [ "$HAVE_X86" = true ] && [ -f "$x86_lib" ]; then
        lipo -create "$arm_lib" "$x86_lib" -output "$out"
        echo -e "${GREEN}  Universal: ${name}.a${NC}"
        lipo -info "$out"
    else
        # Only arm64 available — use it directly as the final lib
        cp "$arm_lib" "$out"
        echo -e "${YELLOW}  arm64-only: ${name}.a (no x86_64 slice)${NC}"
    fi
    UNIVERSAL_CREATED=$((UNIVERSAL_CREATED + 1))
done

# Copy headers to macos/Runner (keep in sync with built library version)
echo -e "\n${CYAN}Copying headers to macos/Runner...${NC}"
for h in llama.h; do
    [ -f "$LLAMA_DIR/include/$h" ] && cp "$LLAMA_DIR/include/$h" "$MACOS_HEADERS_DIR/" && echo -e "${GREEN}  $h${NC}"
done
for h in ggml.h ggml-alloc.h ggml-backend.h ggml-metal.h ggml-cpu.h ggml-opt.h gguf.h; do
    [ -f "$LLAMA_DIR/ggml/include/$h" ] && cp "$LLAMA_DIR/ggml/include/$h" "$MACOS_HEADERS_DIR/" && echo -e "${GREEN}  $h${NC}"
done

echo -e "\n${GREEN}=== BUILD COMPLETE ===${NC}"
echo -e "${WHITE}$UNIVERSAL_CREATED libraries written to: $MACOS_LIBS_DIR${NC}"
ls -lh "$MACOS_LIBS_DIR"/*.a 2>/dev/null | grep -v "\-arm64\.\|x86_64\." || true

echo -e "\n${CYAN}Next steps:${NC}"
echo -e "${WHITE}1. Add macos/Frameworks/*.a to Xcode project (OTHER_LDFLAGS)${NC}"
echo -e "${WHITE}2. Add -framework Metal -framework Accelerate -framework Foundation to linker flags${NC}"
echo -e "${WHITE}3. Update llama_cpp_ffi.dart: isMacOS → DynamicLibrary.process()${NC}"
echo -e "${WHITE}4. flutter run -d macos${NC}"

cd "$PROJECT_ROOT"
