import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:little_star_app/core/benchmark/benchmark_export.dart';
import 'package:little_star_app/core/benchmark/benchmark_recorder.dart';
import 'package:little_star_app/core/benchmark/benchmark_sample.dart';
import 'package:little_star_app/core/inference/backend_selector.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/inference/mlx_backend.dart';
import 'package:little_star_app/core/inference/sampling_params.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/utils/logger.dart';

/// Official T1 model-card recommended sampling for benchmark runs — see
/// docs/benchmark/zh-tw-prompt-set.md's "官方建議 sampling" section. Kept
/// distinct from the app-wide chat default (temp 0.8) so benchmark numbers
/// are comparable to the model card and stay fixed across both backends.
const InferenceSettings kBenchmarkDefaultSettings = InferenceSettings(
  samplingParams: SamplingParams(temperature: 0.6, topP: 0.95),
  maxTokens: 512,
);

/// Drives the internal benchmark harness (task-C01): opens a session for a
/// model path, runs recorded generations against it (cold on session-open,
/// warm on repeat calls), and exports the accumulated [BenchmarkSample]s.
///
/// Deliberately mirrors [ChatViewModel]/[CompletionViewModel]'s format
/// detection (`.gguf` extension vs. MLX directory) rather than introducing a
/// third convention.
class BenchmarkViewModel extends ChangeNotifier {
  final BenchmarkRecorder _recorder;
  final BackendSelector _backendSelector;
  final InferenceSettings settings;
  final Logger _log = Logger('BenchmarkViewModel');

  InferenceSession? _session;
  ModelProfile? _profile;
  final List<BenchmarkSample> _samples = [];

  bool isRunning = false;
  String? lastError;

  BenchmarkViewModel({
    BenchmarkRecorder? recorder,
    BackendSelector? backendSelector,
    this.settings = kBenchmarkDefaultSettings,
  })  : _recorder = recorder ?? BenchmarkRecorder(),
        _backendSelector = backendSelector ?? BackendSelector(mlxBackendFactory: MlxBackend.new);

  List<BenchmarkSample> get samples => List.unmodifiable(_samples);
  bool get hasOpenSession => _session != null;
  String? get openModelId => _profile?.id;

  static ModelFormat _detectFormat(String modelPath) =>
      modelPath.toLowerCase().endsWith('.gguf') ? ModelFormat.gguf : ModelFormat.mlx;

  /// Opens a fresh session for [modelPath] and records the first ("session
  /// cold") generation on it. Closes any previously open session first —
  /// mirrors the no-leak pattern in `LlamaCppBackend`/`MlxBackend` callers.
  Future<void> openSessionAndRun(String modelPath, String prompt, {String? label}) async {
    closeSession();

    final format = _detectFormat(modelPath);
    final profile = ModelProfile(
      id: modelPath,
      displayName: modelPath,
      format: format,
      localPath: modelPath,
    );

    isRunning = true;
    lastError = null;
    notifyListeners();
    try {
      final backend = _backendSelector.select(profile);
      final result = await _recorder.runNewSession(
        backend: backend,
        format: format,
        profile: profile,
        settings: settings,
        messages: [ChatMessage(content: prompt, isUser: true)],
        label: label ?? 'session-cold',
      );
      _session = result.session;
      _profile = profile;
      _samples.add(result.sample);
    } catch (e, st) {
      _log.error('openSessionAndRun failed', error: e, st: st);
      lastError = e.toString();
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }

  /// Records another ("session warm") generation on the currently open
  /// session. No-op if no session is open.
  Future<void> runOnOpenSession(String prompt, {String? label}) async {
    final session = _session;
    final profile = _profile;
    if (session == null || profile == null) return;

    isRunning = true;
    lastError = null;
    notifyListeners();
    try {
      final sample = await _recorder.runOnExistingSession(
        session: session,
        format: profile.format,
        modelId: profile.id,
        messages: [ChatMessage(content: prompt, isUser: true)],
        label: label ?? 'session-warm',
      );
      _samples.add(sample);
    } catch (e, st) {
      _log.error('runOnOpenSession failed', error: e, st: st);
      lastError = e.toString();
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }

  void closeSession() {
    _session?.dispose();
    _session = null;
    _profile = null;
    notifyListeners();
  }

  void clearSamples() {
    _samples.clear();
    notifyListeners();
  }

  Future<File> exportCsv() => _writeExport('csv', benchmarkSamplesToCsv(_samples));

  Future<File> exportJson() => _writeExport('json', benchmarkSamplesToJson(_samples));

  Future<File> _writeExport(String extension, String content) async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp('[:.]'), '-');
    final file = File('${dir.path}/benchmark_$timestamp.$extension');
    return file.writeAsString(content);
  }

  @override
  void dispose() {
    closeSession();
    super.dispose();
  }
}
