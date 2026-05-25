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

  Stream<String> generateStream(int nPrompt, {required int maxTokens});

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
  Stream<String> generateStream(int nPrompt, {required int maxTokens}) =>
      _ffi.generateStream(nPrompt, maxTokens: maxTokens);

  @override
  void freeContext() => _ffi.freeContext();

  @override
  void freeModel() => _ffi.freeModel();
}

// ─── LlamaCppSession ──────────────────────────────────────────────────────────

class LlamaCppSession implements InferenceSession {
  final LlamaFfiDriver _driver;
  final InferenceSettings _settings;
  final Logger _log = Logger('LlamaCppSession');

  bool _cancelled = false;
  bool _disposed = false;

  /// Production constructor — used by [LlamaCppBackend].
  LlamaCppSession(this._driver, this._settings);

  @override
  Stream<String> generate(List<ChatMessage> messages) {
    if (_disposed) throw StateError('LlamaCppSession: generate called after dispose');
    _cancelled = false;
    return _runGeneration(messages);
  }

  Stream<String> _runGeneration(List<ChatMessage> messages) async* {
    // Build chat template input, prepending system prompt when set.
    final maps = _toMessageMaps(messages);

    // applyChatTemplate collapses the message list into a single prompt string.
    // tokenizePrompt then tokenises it and stores the initial batch internally —
    // the two calls are always paired to avoid the orphaned-batch state leak
    // that existed in the previous UnifiedLM implementation.
    final prompt = _driver.applyChatTemplate(maps);

    final sp = _settings.samplingParams;
    _driver.createContext(
      nCtx: 2048,
      nBatch: 512,
      nThreads: 8,
      nThreadsBatch: 8,
    );
    _driver.createSampler(
      useGreedy: false,
      topK: sp.topK,
      topP: sp.topP,
      temp: sp.temperature,
    );

    final nPrompt = _driver.tokenizePrompt(prompt);
    if (nPrompt == 0) {
      _log.warn('tokenizePrompt returned 0 — aborting generation');
      return;
    }

    await for (final token in _driver.generateStream(nPrompt, maxTokens: _settings.maxTokens)) {
      if (_cancelled) break;
      yield token;
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
