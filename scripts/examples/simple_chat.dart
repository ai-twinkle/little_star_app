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

    // Incremental UTF-8 decoder for streaming output
    final stringBuffer = StringBuffer();
    final stringSink = StringConversionSink.fromStringSink(stringBuffer);
    final byteSink = utf8.decoder.startChunkedConversion(stringSink);

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
        
        // Stream UTF-8 decode safely without throwing on incomplete sequences
        byteSink.add(bytes);
        final text = stringBuffer.toString();
        final currentLength = text.length;
        if (currentLength > _lastPrintedLength) {
          final newText = text.substring(_lastPrintedLength);
          stdout.write(newText);
          _lastPrintedLength = currentLength;
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

    // Flush remaining decoded text and return
    byteSink.close();
    final finalText = stringBuffer.toString();
    if (finalText.length > _lastPrintedLength) {
      final remainingText = finalText.substring(_lastPrintedLength);
      stdout.write(remainingText);
    }
    return finalText;
  }

  // Chat loop
  final messages = <ChatMessage>[];
  final maxResponseTokens = 100; // Limit response length (increased for better Chinese support)
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
    print("prompt: ${prompt}\n");
    final response = generate(prompt, maxResponseTokens);
    print("response: ${response}\n");
    print('\n\x1b[0m'); // Reset color

    // Add response to message history
    if (response.isNotEmpty) {
      messages.add(ChatMessage("assistant", response));
    }

    // After the first generation, we should not prepend <bos> again
    if (isFirstPrompt) {
      isFirstPrompt = false;
    }
  }

  // Free resources
  llamaFFI.llama_sampler_free(smpl);
  llamaFFI.llama_free(ctx);
  llamaFFI.llama_model_free(model);

  print("Chat ended.");
}
