# Scripts Directory

This directory contains utility scripts and examples for the Llama.cpp FFI integration project.

## 📁 Directory Structure

```
scripts/
├── diagnostics/         # Diagnostic and troubleshooting tools
│   ├── check_dependencies.dart    # DLL dependency analysis
│   └── diagnostics.dart          # General FFI diagnostics
└── examples/            # Usage examples and demos
    └── example_usage.dart        # Basic FFI integration example
```

## 🔧 Diagnostics Tools

### `diagnostics/check_dependencies.dart`
**Purpose**: Analyzes DLL dependencies and troubleshoots loading issues

**What it does**:
- Checks for common Windows runtime dependencies
- Tests loading of `llama.dll` 
- Provides specific error codes and solutions
- Identifies missing Visual C++ Redistributable components

**Usage**:
```bash
dart run scripts/diagnostics/check_dependencies.dart
```

**Sample Output**:
```
=== DLL Dependency Analysis ===

1. Checking common Windows dependencies:
✅ Found dependencies: kernel32.dll, user32.dll...
❌ Missing dependencies: msvcr140.dll, ggml.dll...

2. Attempting to load llama.dll:
✗ Failed to load llama.dll
Error code: 126 (Missing dependency DLLs)
```

### `diagnostics/diagnostics.dart`
**Purpose**: Runs comprehensive FFI setup diagnostics

**What it does**:
- Platform detection and system info
- Library file validation  
- Model file checking
- Function availability testing
- Setup instructions and troubleshooting

**Usage**:
```bash
dart run scripts/diagnostics/diagnostics.dart
```

## 📚 Examples

### `examples/example_usage.dart`
**Purpose**: Basic demonstration of FFI integration

**What it does**:
- Initializes LlamaFFI wrapper
- Tests backend initialization
- Validates model file existence
- Lists available functions
- Demonstrates proper cleanup

**Usage**:
```bash
dart run scripts/examples/example_usage.dart
```

**Sample Output**:
```
=== Llama.cpp FFI Integration Example ===

1. Initializing Llama FFI...
2. Initializing Llama backend...
3. Testing library functions...
4. Checking model file...
5. Listing available functions...
6. Cleaning up...

=== FFI Integration Complete ===
```

## 🚀 Quick Commands

```bash
# Run dependency analysis
dart run scripts/diagnostics/check_dependencies.dart

# Run general diagnostics  
dart run scripts/diagnostics/diagnostics.dart

# Test basic integration
dart run scripts/examples/example_usage.dart

# Run all diagnostic scripts
dart run scripts/diagnostics/check_dependencies.dart && dart run scripts/diagnostics/diagnostics.dart
```

## 📝 Notes

- All scripts should be run from the project root directory
- Scripts assume `llama.dll` and model files are in the project root
- Diagnostic scripts are safe to run multiple times
- Example scripts demonstrate proper resource cleanup

## 🔍 Troubleshooting

If scripts fail to run:

1. **Ensure you're in the project root**:
   ```bash
   cd path/to/little_star_app
   ```

2. **Check Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Verify file structure**:
   ```bash
   tree scripts /f  # Windows
   find scripts -type f  # Linux/macOS
   ```

4. **Run individual scripts with full path**:
   ```bash
   dart scripts/diagnostics/check_dependencies.dart
   ``` 