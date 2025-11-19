# Simple Chat - Dart Implementation

This is a Dart version of the llama.cpp simple chat example, converted from the C++ implementation.

## Features

- Interactive chat interface with conversation history
- Command-line argument parsing for model configuration
- Streaming text generation with proper UTF-8 support
- Multi-language support (English, Chinese, etc.)
- Colored terminal output
- Memory management with proper cleanup

## Usage

```bash
dart simple_chat.dart -m model.gguf [-c context_size] [-ngl n_gpu_layers]
```

### Parameters

- `-m model.gguf` - Path to the GGUF model file (required)
- `-c context_size` - Context size for the model (default: 2048)
- `-ngl n_gpu_layers` - Number of GPU layers to offload (default: 99)

### Example

```bash
# Run with a model file
dart simple_chat.dart -m Llama-3.2-3B-F1-Reasoning-Instruct-Q4_K_M.gguf

# Run with custom context size and GPU layers
dart simple_chat.dart -m model.gguf -c 4096 -ngl 32
```

## How to Use

1. Start the application with the required model parameter
2. Type your message and press Enter
3. The assistant will generate a response in yellow text
4. Continue the conversation
5. Press Enter on an empty line to exit

## Differences from C++ Version

- **Simplified Sampling**: Only greedy sampling is currently implemented (vs. min_p, temperature, and dist sampling in C++)
- **Chat Template**: Uses a simple "User: ... Assistant: ..." format instead of model-specific chat templates
- **Context Management**: Implements conversation history limiting and context overflow prevention
- **Response Length**: Limits response length to prevent context overflow
- **Streaming**: Maintains the streaming output behavior from the original

## Technical Details

- Uses the existing `llama_ffi.dart` FFI bindings
- Maintains conversation history in memory
- Proper UTF-8 handling for international text
- Terminal color codes for better UX
- Memory cleanup on exit

## Requirements

- Dart SDK
- Compiled llama.cpp libraries (llama.dll, ggml.dll on Windows)
- A compatible GGUF model file

## Context Management

The application automatically manages context size by:
- Limiting conversation history to the last 3 exchanges (6 messages)
- Restricting response length to 100 tokens by default (optimized for multi-language support)
- Checking prompt size before generation
- Providing clear error messages for context overflow
- Proper UTF-8 handling for international characters (Chinese, Japanese, etc.)

For better performance with longer conversations:
- Use larger context sizes (e.g., `-c 1024` or `-c 2048`)
- The application will automatically truncate old messages when needed

## Troubleshooting

- Ensure model file exists and is readable
- Check that llama.cpp libraries are in the correct path
- Verify sufficient memory for the model and context size
- For context overflow issues, try increasing the context size with `-c`
- If responses are cut short, the context limit may be too small
- Use at least `-c 512` for meaningful conversations 