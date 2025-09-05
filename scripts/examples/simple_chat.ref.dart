import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:convert';

import 'package:ffi/ffi.dart';
import '../../lib/llama_ffi.dart';

void printUsage(List<String> args) {
  print("\nexample usage:");
  print("\n    dart simple_chat.dart -m model.gguf [-c context_size] [-ngl n_gpu_layers]");
  print("");
}

class ChatMessage {
  final String role;
  final String content;
  
  ChatMessage(this.role, this.content);

  @override
  String toString() {
    return "ChatMessage(role: $role, content: $content)";
  }
}

void main(List<String> args) {
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

  final LlamaFFI llamaFFI = LlamaFFI();
  if (!llamaFFI.modelFileExists(modelPath)) {
    stderr.writeln("error: model file not found");
    exit(1);
  }

  // Load dynamic backends
  print("Loading backends...");
  llamaFFI.ggml_backend_load_all();

  // Initialize the model
  final modelParams = llamaFFI.llama_model_default_params();
  modelParams.n_gpu_layers = ngl;

  final pathPtr = modelPath.toNativeUtf8().cast<ffi.Char>();
  final model = llamaFFI.llama_model_load_from_file(pathPtr, modelParams);
  malloc.free(pathPtr);

  if (model.address == 0) {
    stderr.writeln("error: unable to load model");
    exit(1);
  }

  final vocab = llamaFFI.llama_model_get_vocab(model);
  if (vocab.address == 0) {
    stderr.writeln("error: failed to get vocabulary from model");
    llamaFFI.llama_model_free(model);
    exit(1);
  }

  // Initialize the context
  final ctxParams = llamaFFI.llama_context_default_params();
  ctxParams.n_ctx = nCtx;
  ctxParams.n_batch = nCtx;

  final ctx = llamaFFI.llama_init_from_model(model, ctxParams);
  if (ctx.address == 0) {
    stderr.writeln("error: failed to create the llama_context");
    llamaFFI.llama_model_free(model);
    exit(1);
  }

  // Initialize the sampler
  final sparams = llamaFFI.llama_sampler_chain_default_params();
  final smpl = llamaFFI.llama_sampler_chain_init(sparams);
  
  // Add sampler components (simplified compared to C++ version)
  // Align behavior closer to C++ example: temperature + top-p + random dist
  llamaFFI.llama_sampler_chain_add(smpl, llamaFFI.llama_sampler_init_temp(0.8));
  llamaFFI.llama_sampler_chain_add(smpl, llamaFFI.llama_sampler_init_top_p(0.95, 1));
  llamaFFI.llama_sampler_chain_add(smpl, llamaFFI.llama_sampler_init_dist(0));

  // Helper function to generate response
  String generate(String prompt, int maxTokens) {
    final responseBytes = <int>[];
    int _lastPrintedLength = 0; // Track how much text we've already printed

    // Convert prompt to UTF-8 and tokenize
    final promptUtf8 = prompt.toNativeUtf8();
    final promptPtr = promptUtf8.cast<ffi.Char>();
    final promptByteLength = promptUtf8.length;

    // Get required token count
    final nPromptRequired = llamaFFI.llama_tokenize(vocab, promptPtr, promptByteLength, ffi.nullptr, 0, false, true);
    
    if (nPromptRequired >= 0) {
      stderr.writeln("error: unexpected positive return from tokenize call");
      malloc.free(promptUtf8);
      return "";
    }
    
    final nPrompt = -nPromptRequired;
    
    // Check if prompt is too long for context
    if (nPrompt >= nCtx - 10) { // Leave some room for generation
      stderr.writeln("error: prompt too long for context size ($nPrompt tokens >= ${nCtx - 10})");
      malloc.free(promptUtf8);
      return "";
    }
    
    // Allocate space for tokens and tokenize
    final tokens = malloc<llama_token>(nPrompt);
    final actualTokens = llamaFFI.llama_tokenize(
        vocab, promptPtr, promptByteLength, tokens, nPrompt, false, true);
        
    malloc.free(promptUtf8);
        
    if (actualTokens < 0) {
      stderr.writeln("error: failed to tokenize the prompt");
      malloc.free(tokens);
      return "";
    }

    // Prepare initial batch
    var batch = llamaFFI.llama_batch_get_one(tokens, nPrompt);
    final tokenPtr = malloc<llama_token>();
    int generatedTokens = 0;

    try {
      while (generatedTokens < maxTokens) {
        // Check if we have enough space in the context
        if (nPrompt + generatedTokens >= nCtx - 1) {
          print("\nContext limit reached");
          break;
        }

        // Decode the batch
        if (llamaFFI.llama_decode(ctx, batch) != 0) {
          print("\nDecode failed");
          break;
        }

        // Sample the next token
        final newTokenId = llamaFFI.llama_sampler_sample(smpl, ctx, -1);

        // Check if it's end of generation
        if (llamaFFI.llama_vocab_is_eog(vocab, newTokenId)) {
          break;
        }

        // Convert token to text piece
        final buf = malloc<ffi.Char>(256);
        final n = llamaFFI.llama_token_to_piece(vocab, newTokenId, buf, 256, 0, true);
        if (n < 0) {
          stderr.writeln("error: failed to convert token to piece");
          malloc.free(buf);
          break;
        }

        // Add bytes to response
        final bytes = buf.cast<ffi.Uint8>().asTypedList(n);
        responseBytes.addAll(bytes);
        
        // Try to decode and print incrementally for streaming effect
        // This handles multi-byte UTF-8 characters properly
        try {
          // Try to decode the accumulated bytes
          final text = utf8.decode(responseBytes, allowMalformed: false);
          // If successful, we can print the new part
          final currentLength = text.length;
          print("text: ${text}, _lastPrintedLength: ${_lastPrintedLength}, currentLength: ${currentLength}\n");
          if (currentLength > _lastPrintedLength) {
            final newText = text.substring(_lastPrintedLength);
            print("newText: ${newText}\n");
            stdout.write("${newText}\n");
            _lastPrintedLength = currentLength;
          }
        } catch (e) {
          // If UTF-8 decode fails, it means we have incomplete UTF-8 sequence
          // Don't print anything yet, wait for more bytes
          print("error: ${e}\n");
        }
        
        malloc.free(buf);

        // Prepare next batch with the sampled token
        tokenPtr.value = newTokenId;
        batch = llamaFFI.llama_batch_get_one(tokenPtr, 1);
        generatedTokens++;
      }
    } finally {
      malloc.free(tokens);
      malloc.free(tokenPtr);
    }

    // Print any remaining text that wasn't printed during streaming
    try {
      final finalText = utf8.decode(responseBytes, allowMalformed: true);
      print("finalText: ${finalText}, _lastPrintedLength: ${_lastPrintedLength}\n");
      if (finalText.length > _lastPrintedLength) {
        final remainingText = finalText.substring(_lastPrintedLength);
        stdout.write(remainingText);
      }
      return finalText;
    } catch (e) {
      // Fallback if UTF-8 decoding completely fails
      final fallbackText = String.fromCharCodes(responseBytes);
      print("fallbackText: ${fallbackText}, _lastPrintedLength: ${_lastPrintedLength}\n");
      if (fallbackText.length > _lastPrintedLength) {
        final remainingText = fallbackText.substring(_lastPrintedLength);
        stdout.write(remainingText);
      }
      return fallbackText;
    }
  }

  // Chat loop
  final messages = <ChatMessage>[];
  // Buffer to store formatted conversation
  var formattedSize = nCtx;
  ffi.Pointer<ffi.Char> formatted = calloc<ffi.Char>(formattedSize);
  final maxResponseTokens = 100; // Limit response length (increased for better Chinese support)
  var isFirstPrompt = true;
  int prevLen = 0; // Track previous conversation length

  print("Chat started. Type your message and press Enter. Empty line to exit.\n");
  
  while (true) {
    // Get user input
    stdout.write('\x1b[32m> \x1b[0m'); // Green prompt
    final userInput = stdin.readLineSync();

    print("userInput: ${userInput}\n");

    if (userInput == null || userInput.trim().isEmpty) {
      break;
    }

    // Try to get model-provided chat template
    final tmplPtr = llamaFFI.llama_model_chat_template(model, ffi.nullptr);
    print("tmplPtr: ${tmplPtr}\n");

    // Add user message to history
    messages.add(ChatMessage("user", userInput));

    print("messages: ${messages}\n");

    // Build native llama_chat_message array
    final messageData = malloc<llama_chat_message>(messages.length);
    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      final rolePtr = m.role.toNativeUtf8().cast<ffi.Char>();
      final contentPtr = m.content.toNativeUtf8().cast<ffi.Char>();
      messageData[i]
        ..role = rolePtr
        ..content = contentPtr;
    }

    int newLen = llamaFFI.llama_chat_apply_template(tmplPtr, messageData, messages.length, true, ffi.nullptr, 0);
    if (newLen > formattedSize) {
      // Reallocate buffer if needed
      malloc.free(formatted);
      formattedSize = newLen;
      formatted = calloc<ffi.Char>(formattedSize);
      newLen = llamaFFI.llama_chat_apply_template(tmplPtr, messageData, messages.length, true, formatted, formattedSize);
    } else {
      newLen = llamaFFI.llama_chat_apply_template(tmplPtr, messageData, messages.length, true, formatted, formattedSize);
    }
    if (newLen < 0) {
      stderr.writeln("error: failed to apply the chat template");
      malloc.free(messageData);
      exit(1);
    }

    // Extract only the new prompt (from prevLen to newLen), like C++ does
    final promptBytes = formatted.cast<ffi.Uint8>().asTypedList(newLen).sublist(prevLen, newLen);
    final prompt = utf8.decode(promptBytes);

    // Generate response
    stdout.write('\x1b[33m'); // Yellow text for assistant
    print("prompt: ${prompt}\n");
    final response = generate(prompt, maxResponseTokens);
    print("response: ${response}\n");
    stdout.write('\n\x1b[0m'); // Reset color

    // Add response to message history
    if (response.isNotEmpty) {
      messages.add(ChatMessage("assistant", response));

      print("messages: ${messages}\n");
      
      // Update prevLen after adding assistant response (like C++ does)
      // Rebuild message array to include the assistant response
      final updatedMessageData = malloc<llama_chat_message>(messages.length);
      for (int i = 0; i < messages.length; i++) {
        final m = messages[i];
        final rolePtr = m.role.toNativeUtf8().cast<ffi.Char>();
        final contentPtr = m.content.toNativeUtf8().cast<ffi.Char>();
        updatedMessageData[i]
          ..role = rolePtr
          ..content = contentPtr;
      }

      prevLen = llamaFFI.llama_chat_apply_template(tmplPtr, updatedMessageData, messages.length, false, ffi.nullptr, 0);
      if (prevLen < 0) {
        stderr.writeln("error: failed to apply the chat template for prevLen");
        malloc.free(updatedMessageData);
        exit(1);
      }

      // Free the updated message data
      for (int i = 0; i < messages.length; i++) {
        malloc.free(updatedMessageData[i].role);
        malloc.free(updatedMessageData[i].content);
      }
      malloc.free(updatedMessageData);
    }

    // Free the original message data
    for (int i = 0; i < messages.length - (response.isNotEmpty ? 1 : 0); i++) {
      malloc.free(messageData[i].role);
      malloc.free(messageData[i].content);
    }
    malloc.free(messageData);

    // After the first generation, we should not prepend <bos> again
    if (isFirstPrompt) {
      isFirstPrompt = false;
    }
  }

  // Free resources
  malloc.free(formatted);
  llamaFFI.llama_sampler_free(smpl);
  llamaFFI.llama_free(ctx);
  llamaFFI.llama_model_free(model);

  print("Chat ended.");
}
