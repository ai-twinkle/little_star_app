import 'dart:math' as math;

import 'package:little_star_app/core/engine/llama_cpp/llama_cpp_ffi.dart';
import 'package:little_star_app/core/inference/inference_backend.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/core/platform/native_library_loader.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/utils/logger.dart';

/// llama.cpp build tag bundled with this app.
const String kLlamaCppVersion = 'b7493';

// ─── Testable FFI surface ─────────────────────────────────────────────────────

/// Minimal interface over [LlamaCppFFI] that [LlamaCppSession] depends on.
/// Kept as a separate class so tests can inject a fake without loading native libs.
abstract class LlamaFfiDriver {
  String applyChatTemplate(List<Map<String, dynamic>> messageMaps);

  bool createContext({
    required int nCtx,
    required int nBatch,
    required int nThreads,
    required int nThreadsBatch,
  });

  bool createSampler({
    required bool useGreedy,
    required int topK,
    required double topP,
    required double temp,
  });

  /// Tokenises [prompt] and sets the initial batch.
  /// Returns the number of prompt tokens, or 0 on failure.
  int tokenizePrompt(String prompt);

  /// Clears the context's KV cache so a fresh, independent generation can
  /// start at sequence position 0 — call before each [tokenizePrompt] on a
  /// context reused across multiple [generateStream] calls.
  void resetForNewGeneration();

  Stream<String> generateStream(int nPrompt, {required int maxTokens});

  /// Wall-clock time spent decoding the prompt (prefill) in the most recent
  /// [generateStream] call. Null until a generation has run.
  Duration? get lastPrefillDuration;

  void freeContext();
  void freeModel();
}

// Production driver — thin delegation to the real LlamaCppFFI.
class _RealFfiDriver implements LlamaFfiDriver {
  final LlamaCppFFI _ffi;
  _RealFfiDriver(this._ffi);

  @override
  String applyChatTemplate(List<Map<String, dynamic>> messageMaps) =>
      _ffi.applyChatTemplate(messageMaps);

  @override
  bool createContext({
    required int nCtx,
    required int nBatch,
    required int nThreads,
    required int nThreadsBatch,
  }) =>
      _ffi.createContext(
        nCtx: nCtx,
        nBatch: nBatch,
        nThreads: nThreads,
        nThreadsBatch: nThreadsBatch,
      );

  @override
  bool createSampler({
    required bool useGreedy,
    required int topK,
    required double topP,
    required double temp,
  }) =>
      _ffi.createSampler(
        useGreedy: useGreedy,
        topK: topK,
        topP: topP,
        temp: temp,
      );

  @override
  int tokenizePrompt(String prompt) => _ffi.tokenizePrompt(prompt);

  @override
  void resetForNewGeneration() => _ffi.clearMemory();

  @override
  Stream<String> generateStream(int nPrompt, {required int maxTokens}) =>
      _ffi.generateStream(nPrompt, maxTokens: maxTokens);

  @override
  Duration? get lastPrefillDuration => _ffi.lastPrefillDuration;

  @override
  void freeContext() => _ffi.freeContext();

  @override
  void freeModel() => _ffi.freeModel();
}

// ─── Turn-marker guard ─────────────────────────────────────────────────────────

/// Detects role-turn markers (e.g. `<start_of_turn>user`, `<|assistant|>`)
/// that signal the model has stopped answering and started hallucinating a
/// new turn without ever sampling a recognized EOG token — llama.cpp's own
/// `llama_vocab_is_eog` check (see `LlamaCppFFI.generateStream`) already
/// stops generation when the model *does* sample one, so this is a text-level
/// safety net for the cases where it doesn't. Holds back text that could
/// still grow into a marker so a marker split across multiple token chunks
/// never leaks to the caller.
class _TurnMarkerFilter {
  static const _markers = [
    '<start_of_turn>user',
    '<start_of_turn>model',
    '<|user|>',
    '<|assistant|>',
    '<|system|>',
  ];
  static final int _maxMarkerLen =
      _markers.map((m) => m.length).reduce((a, b) => a > b ? a : b);

  final _pending = StringBuffer();

  /// Feeds newly generated [text]. Returns the portion now safe to emit and
  /// whether a stop marker was found (caller should stop generation).
  ({String text, bool stop}) feed(String text) {
    _pending.write(text);
    final buffered = _pending.toString();

    var stopIndex = -1;
    for (final marker in _markers) {
      final idx = buffered.indexOf(marker);
      if (idx != -1 && (stopIndex == -1 || idx < stopIndex)) {
        stopIndex = idx;
      }
    }
    if (stopIndex != -1) {
      _pending.clear();
      return (text: buffered.substring(0, stopIndex), stop: true);
    }

    // Hold back only a tail that is itself a prefix of some marker (i.e.
    // could still grow into one on the next feed). Ordinary text containing
    // no "<" passes through immediately — the buffer isn't held hostage
    // waiting for a marker that was never starting.
    var holdBack = 0;
    final maxCheck = math.min(buffered.length, _maxMarkerLen - 1);
    for (var len = maxCheck; len > 0; len--) {
      final tail = buffered.substring(buffered.length - len);
      if (_markers.any((m) => m.startsWith(tail))) {
        holdBack = len;
        break;
      }
    }
    final safeLen = buffered.length - holdBack;
    final safe = buffered.substring(0, safeLen);
    _pending
      ..clear()
      ..write(buffered.substring(safeLen));
    return (text: safe, stop: false);
  }

  /// Returns text still held back — call once after generation ends normally
  /// (no marker ever completed) so the trailing text isn't silently dropped.
  String flush() {
    final rest = _pending.toString();
    _pending.clear();
    return rest;
  }
}

// ─── LlamaCppSession ──────────────────────────────────────────────────────────

class LlamaCppSession implements InferenceSession, PromptMetricsSource {
  final LlamaFfiDriver _driver;
  final InferenceSettings _settings;
  final Logger _log = Logger('LlamaCppSession');

  bool _cancelled = false;
  bool _disposed = false;
  bool _contextReady = false;

  int? _lastPromptTokenCount;

  /// Production constructor — used by [LlamaCppBackend].
  ///
  /// Creates the context and sampler once, up front, rather than per
  /// [generate] call — this both matches how TTFT/prefill throughput are
  /// conventionally measured elsewhere (excluding one-time session setup)
  /// and avoids paying the KV-cache allocation cost on every run. Each
  /// [generate] call instead clears the existing context's KV cache via
  /// [LlamaFfiDriver.resetForNewGeneration].
  LlamaCppSession(this._driver, this._settings) {
    _contextReady = _initContext();
  }

  bool _initContext() {
    final sp = _settings.samplingParams;
    // 4096 chosen in task-A02 (2026-07-08-t1-benchmark-talk): the benchmark's
    // own L2048 prompt tier needs 2048 input + up to 512 generated tokens
    // (2560 total), and on-device measurement showed no SWA-aware KV cache
    // savings for Gemma 3 in the bundled llama.cpp build -- every 1024 tokens
    // of context costs ~136MB uniformly across all layers, so this is the
    // smallest value that comfortably covers the benchmark's needs on both
    // the iPhone 17 Pro (increased-memory-limit entitlement) and Pixel 8a.
    if (!_driver.createContext(nCtx: 4096, nBatch: 512, nThreads: 8, nThreadsBatch: 8)) {
      _log.warn('createContext failed during session init');
      return false;
    }
    if (!_driver.createSampler(
      useGreedy: false,
      topK: sp.topK,
      topP: sp.topP,
      temp: sp.temperature,
    )) {
      _log.warn('createSampler failed during session init');
      return false;
    }
    return true;
  }

  @override
  int? get lastPromptTokenCount => _lastPromptTokenCount;

  @override
  Duration? get lastPrefillDuration => _driver.lastPrefillDuration;

  @override
  Stream<String> generate(List<ChatMessage> messages) {
    if (_disposed) throw StateError('LlamaCppSession: generate called after dispose');
    _cancelled = false;
    return _runGeneration(messages);
  }

  Stream<String> _runGeneration(List<ChatMessage> messages) async* {
    if (!_contextReady) {
      _log.warn('generate called but context/sampler failed to initialize');
      return;
    }

    // Build chat template input, prepending system prompt when set.
    final maps = _toMessageMaps(messages);

    // applyChatTemplate collapses the message list into a single prompt string.
    // tokenizePrompt then tokenises it and stores the initial batch internally —
    // the two calls are always paired to avoid the orphaned-batch state leak
    // that existed in the previous UnifiedLM implementation.
    final prompt = _driver.applyChatTemplate(maps);

    // Context and sampler are created once in the constructor; reset the KV
    // cache so this generation starts fresh instead of continuing from
    // whatever the previous run on this session left behind.
    _driver.resetForNewGeneration();

    final nPrompt = _driver.tokenizePrompt(prompt);
    if (nPrompt == 0) {
      _log.warn('tokenizePrompt returned 0 — aborting generation');
      return;
    }
    _lastPromptTokenCount = nPrompt;

    final filter = _TurnMarkerFilter();
    var stoppedByMarker = false;
    await for (final token in _driver.generateStream(nPrompt, maxTokens: _settings.maxTokens)) {
      if (_cancelled) break;
      final result = filter.feed(token);
      if (result.text.isNotEmpty) yield result.text;
      if (result.stop) {
        _log.debug('Turn-marker guard: truncated fabricated next turn');
        stoppedByMarker = true;
        break;
      }
    }
    if (!stoppedByMarker && !_cancelled) {
      final remainder = filter.flush();
      if (remainder.isNotEmpty) yield remainder;
    }
  }

  List<Map<String, dynamic>> _toMessageMaps(List<ChatMessage> messages) {
    final maps = <Map<String, dynamic>>[];
    if (_settings.systemPrompt != null && _settings.systemPrompt!.isNotEmpty) {
      maps.add({'role': 'system', 'content': _settings.systemPrompt!});
    }
    for (final m in messages) {
      maps.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.content,
      });
    }
    return maps;
  }

  @override
  void cancel() {
    _log.debug('cancel()');
    _cancelled = true;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _log.debug('dispose()');
    _disposed = true;
    _driver.freeContext();
    _driver.freeModel();
  }
}

// ─── LlamaCppBackend ──────────────────────────────────────────────────────────

class LlamaCppBackend implements InferenceBackend {
  static const String version = kLlamaCppVersion;

  final Logger _log = Logger('LlamaCppBackend');

  /// Returns true for GGUF models on any supported platform.
  @override
  bool canHandle(ModelProfile profile) => profile.format == ModelFormat.gguf;

  /// Creates and returns a [LlamaCppSession] for [profile].
  ///
  /// Loads the native library, initialises the llama backend, and loads the
  /// model. The caller is responsible for calling [InferenceSession.dispose]
  /// when the session is no longer needed — including before calling
  /// [createSession] again to avoid model memory leaks.
  @override
  InferenceSession createSession(
    ModelProfile profile,
    InferenceSettings settings,
  ) {
    if (!canHandle(profile)) {
      throw UnsupportedError(
        'LlamaCppBackend only handles GGUF models; got ${profile.format}',
      );
    }

    final localPath = profile.localPath;
    if (localPath == null || localPath.isEmpty) {
      throw ArgumentError.value(
        profile,
        'profile',
        'ModelProfile.localPath must be set before creating a session',
      );
    }

    _log.debug('createSession: $localPath');

    final ffi = LlamaCppFFI();
    final loader = NativeLibraryLoader();
    if (loader.needsExplicitBackendInit) {
      ffi.setLogCallback();
      ffi.ggml_backend_load_all();
    } else {
      ffi.initBackend();
    }

    ffi.loadModel(localPath);

    return LlamaCppSession(_RealFfiDriver(ffi), settings);
  }
}
