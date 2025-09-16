import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';

import 'package:ffi/ffi.dart';
import '../../lib/core/engine/llama_cpp/llama_cpp_ffi.dart';
import '../../lib/core/lm.dart';
import '../../lib/utils/logger.dart';


final log = Logger('SimpleChat');

void printUsage(List<String> args) {
  print("\nexample usage:");
  print("\n    dart simple_chat.dart -m model.gguf [-c context_size] [-ngl n_gpu_layers]");
  print("");
}

void main(List<String> args) {
  // Ensure console I/O uses UTF-8 (helps on Windows terminals)
  stdout.encoding = utf8;
  stderr.encoding = utf8;

  String modelPath = "";
  int ngl = 99;
  int nCtx = 2048;

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
  
  log.debug("Chat started. Type your message and press Enter. Empty line to exit.\n");

  while (true) {
    // Get user input
    stdout.write('\n\x1b[32m> \x1b[0m'); // Green prompt
    final userInput = stdin.readLineSync(encoding: utf8);

    log.debug("userInput: $userInput\n");

    if (userInput == null || userInput.trim().isEmpty) {
      break;
    }

    // Add user message to history
    messages.add(ChatMessage("user", userInput));

    // Keep only last few messages to prevent context overflow
    while (messages.length > 6) { // Keep last 3 exchanges (6 messages)
      messages.removeAt(0);
    }
    
    model.chat(messages);
  }

  // Free resources
  model.dispose();

  log.debug("Chat ended.");
}
