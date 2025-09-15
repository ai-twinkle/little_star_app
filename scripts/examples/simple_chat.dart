import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';

import 'package:ffi/ffi.dart';
import '../../lib/llama_ffi.dart';
import '../../lib/plugins/lm.dart';

void printUsage(List<String> args) {
  print("\nexample usage:");
  print("\n    dart simple_chat.dart -m model.gguf [-c context_size] [-ngl n_gpu_layers]");
  print("");
}

class ChatMessage {
  final String role;
  final String content;
  
  ChatMessage(this.role, this.content);
}

// Special chat tokens commonly used by Gemma chat templates
const String _tokBos = "<bos>";
const String _tokStartOfTurn = "<start_of_turn>";
const String _tokEndOfTurn = "<end_of_turn>";

void main(List<String> args) {
  String modelPath = "";
  int ngl = 99;
  int nCtx = 2048;

  // Ensure console I/O uses UTF-8 (helps on Windows terminals)
  stdout.encoding = utf8;
  stderr.encoding = utf8;

  // Parse command line arguments
  for (int i = 0; i < args.length; i++) {
    try {
      switch (args[i]) {
        case "-m":
          if (i + 1 < args.length) {
            modelPath = args[++i];
          } else {
            printUsage(args);
            exit(1);
          }
          break;
        case "-c":
          if (i + 1 < args.length) {
            nCtx = int.parse(args[++i]);
          } else {
            printUsage(args);
            exit(1);
          }
          break;
        case "-ngl":
          if (i + 1 < args.length) {
            ngl = int.parse(args[++i]);
          } else {
            printUsage(args);
            exit(1);
          }
          break;
        default:
          printUsage(args);
          exit(1);
      }
    } catch (e) {
      stderr.writeln("error: $e");
      printUsage(args);
      exit(1);
    }
  }

  if (modelPath.isEmpty) {
    printUsage(args);
    exit(1);
  }

  final model = UnifiedLM(modelPath);
  // Chat loop
  final messages = <ChatMessage>[];
  var isFirstPrompt = true;
  
  print("Chat started. Type your message and press Enter. Empty line to exit.\n");
  
  while (true) {
    // Get user input
    stdout.write('\x1b[32m> \x1b[0m'); // Green prompt
    final userInput = stdin.readLineSync(encoding: utf8);
    
    if (userInput == null || userInput.trim().isEmpty) {
      break;
    }

    // Add user message to history
    messages.add(ChatMessage("user", userInput));

    // Keep only last few messages to prevent context overflow
    while (messages.length > 6) { // Keep last 3 exchanges (6 messages)
      messages.removeAt(0);
    }
    
    // If we removed messages, we need to clear KV cache for a fresh start
    // Note: This is a simplified approach. In a full implementation, 
    // we would properly manage the KV cache to maintain context.

    // Build prompt using Gemma-style chat turn tokens to match C++ example behavior
    final promptBuffer = StringBuffer();
    if (isFirstPrompt) {
      promptBuffer.write(_tokBos);
    }
    // Add conversation history (only recent messages)
    for (final message in messages) {
      if (message.role == "user") {
        promptBuffer
          ..write(_tokStartOfTurn)
          ..write("user\n")
          ..write(message.content)
          ..write("\n")
          ..write(_tokEndOfTurn)
          ..write("\n");
      } else {
        // Gemma typically uses "model" for assistant turns
        promptBuffer
          ..write(_tokStartOfTurn)
          ..write("model\n")
          ..write(message.content)
          ..write("\n")
          ..write(_tokEndOfTurn)
          ..write("\n");
      }
    }
    // Now open a new assistant/model turn for generation
    promptBuffer
      ..write(_tokStartOfTurn)
      ..write("model\n");

    final prompt = promptBuffer.toString();

    // Generate response
    stdout.write('\x1b[33m'); // Yellow text for assistant
    print("prompt: ${prompt}\n\n\n");
    model.completion(prompt);
    print('\n\x1b[0m'); // Reset color

    // After the first generation, we should not prepend <bos> again
    if (isFirstPrompt) {
      isFirstPrompt = false;
    }
  }

  // Free resources
  model.dispose();

  print("Chat ended.");
}
