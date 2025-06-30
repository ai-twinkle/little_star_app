import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:ffi/ffi.dart';
import '../../lib/llama_ffi.dart';

void main() {
  // Initialize settings
  String modelPath = "Llama-3.2-3B-F1-Reasoning-Instruct-Q4_K_M.gguf";
  String prompt = "<start_of_turn>2 * 4 =<end_of_turn>\n<start_of_turn>model\n";
  int ngl = 99;
  int nPredict = 32;

  final LlamaFFI llamaFFI = LlamaFFI();
  if (!llamaFFI.modelFileExists(modelPath)) {
    stderr.writeln("error: model file not found");
    return;
  }

  // Try modern backend loading first, fallback to legacy method
  print("Attempting to load backends...");
  llamaFFI.ggml_backend_load_all();

  // Initialize model
  final modelParams = llamaFFI.llama_model_default_params();
  modelParams.n_gpu_layers = ngl;
  // modelParams.vocab_only = true;
  final pathPtr = modelPath.toNativeUtf8().cast<ffi.Char>();
  final model = llamaFFI.llama_model_load_from_file(pathPtr, modelParams);
  malloc.free(pathPtr);

  if (model.address == 0) {
    stderr.writeln("error: failed to load model from $modelPath");
    return;
  }

  // Get vocabulary
  final vocab = llamaFFI.llama_model_get_vocab(model);
  print("vocab: ${vocab.address}");
  
  if (vocab.address == 0) {
    stderr.writeln("error: failed to get vocabulary from model");
    llamaFFI.llama_model_free(model);
    return;
  }

  // Convert prompt to UTF-8 and get proper byte length
  final promptUtf8 = prompt.toNativeUtf8();
  final promptPtr = promptUtf8.cast<ffi.Char>();
  final promptByteLength = promptUtf8.length; // This gives actual byte length
  
  print("prompt: $prompt, promptPtr: ${promptPtr.address}, byteLength: $promptByteLength");

  // First call to get required token count (negative return value)
  final nPromptRequired = llamaFFI.llama_tokenize(vocab, promptPtr, promptByteLength, ffi.nullptr, 0, true, true);
  
  if (nPromptRequired >= 0) {
    stderr.writeln("error: unexpected positive return from tokenize call");
    malloc.free(promptUtf8);
    llamaFFI.llama_model_free(model);
    return;
  }
  
  final nPrompt = -nPromptRequired;
  print("nPrompt: $nPrompt");

  // Allocate space for the tokens and tokenize the prompt
  final tokens = malloc<llama_token>(nPrompt);
  final actualTokens = llamaFFI.llama_tokenize(
      vocab, promptPtr, promptByteLength, tokens, nPrompt, true, true);
      
  if (actualTokens < 0) {
    stderr.writeln("error: failed to tokenize the prompt");
    malloc.free(promptUtf8);
    malloc.free(tokens);
    llamaFFI.llama_model_free(model);
    return;
  }
  
  print("Successfully tokenized $actualTokens tokens");
  
  // Free the prompt memory now that we're done with it
  malloc.free(promptUtf8);

  // Initialize context
  final ctxParams = llamaFFI.llama_context_default_params();
  ctxParams.n_ctx = nPrompt + nPredict - 1;
  ctxParams.n_batch = nPrompt;
  ctxParams.no_perf = false;

  final ctx = llamaFFI.llama_init_from_model(model, ctxParams);
  if (ctx.address == 0) {
    stderr.writeln("error: failed to create context");
    malloc.free(tokens);
    llamaFFI.llama_model_free(model);
    return;
  }

  print("Successfully created context");

  // Initialize sampler
  var sparams = llamaFFI.llama_sampler_chain_default_params();
  sparams.no_perf = false;
  final smpl = llamaFFI.llama_sampler_chain_init(sparams);
  llamaFFI.llama_sampler_chain_add(smpl, llamaFFI.llama_sampler_init_greedy());

  // Print prompt tokens
  for (int i = 0; i < nPrompt; i++) {
    final buf = malloc<ffi.Char>(128);
    int n = llamaFFI.llama_token_to_piece(vocab, tokens[i], buf, 128, 0, true);
    if (n < 0) {
      stderr.writeln("error: failed to convert token to piece");
      malloc.free(buf);
      malloc.free(tokens);
      return;
    }
    String piece = String.fromCharCodes(buf.cast<ffi.Uint8>().asTypedList(n));
    stdout.write(piece);
    malloc.free(buf);
  }

    // Track timing
  final tMainStart = DateTime.now().microsecondsSinceEpoch;

  // Prepare initial batch
  var batch = llamaFFI.llama_batch_get_one(tokens, nPrompt);
  print("batch: ${batch.ref.n_tokens}");

  // Main generation loop
  int nDecode = 0;
  int newTokenId;
  final tokenPtr = malloc<llama_token>();

  for (int nPos = 0; nPos + batch.ref.n_tokens < nPrompt + nPredict;) {
    if (llamaFFI.llama_decode(ctx, batch) != 0) {
      stderr.writeln("failed to eval");
      malloc.free(tokenPtr);
      malloc.free(tokens);
      return;
    }

    nPos += batch.ref.n_tokens;

    // Sample next token
    newTokenId = llamaFFI.llama_sampler_sample(smpl, ctx, -1);

    if (llamaFFI.llama_vocab_is_eog(vocab, newTokenId)) {
      break;
    }

    final buf = malloc<ffi.Char>(128);
    int n = llamaFFI.llama_token_to_piece(vocab, newTokenId, buf, 128, 0, true);
    if (n < 0) {
      stderr.writeln("error: failed to convert token to piece");
      malloc.free(buf);
      malloc.free(tokenPtr);
      malloc.free(tokens);
      return;
    }

    String piece = String.fromCharCodes(buf.cast<ffi.Uint8>().asTypedList(n));
    stdout.write(piece);
    stdout.flush();
    malloc.free(buf);

    // Prepare next batch
    tokenPtr.value = newTokenId;
    batch = llamaFFI.llama_batch_get_one(tokenPtr, 1);

    nDecode++;
  }

  final tMainEnd = DateTime.now().microsecondsSinceEpoch;
  stdout.writeln();

  // Print performance statistics
  final decodeTime = (tMainEnd - tMainStart) / 1000000.0;
  stderr.writeln(
      "decoded $nDecode tokens in ${decodeTime.toStringAsFixed(2)} s, speed: ${(nDecode / decodeTime).toStringAsFixed(2)} t/s");
  stderr.writeln();

  // Clean up
  malloc.free(tokens);
  llamaFFI.llama_free(ctx);
  llamaFFI.llama_model_free(model);
  
  print("Cleanup completed successfully");
}