import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:little_star_app/core/benchmark/benchmark_export.dart';
import 'package:little_star_app/core/benchmark/benchmark_sample.dart';
import 'package:little_star_app/core/benchmark/prompt_tiers.dart';
import 'package:little_star_app/core/inference/backend_selector.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/inference/sampling_params.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/data/services/local_model_catalog.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/ui/benchmark/controller/benchmark_recorder.dart';
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
/// Uses [ModelProfile.fromLocalPath], the same local-path policy shared by
/// [ChatViewModel] and [CompletionViewModel].
class BenchmarkViewModel extends ChangeNotifier {
  final BenchmarkRecorder _recorder;
  final BackendSelector _backendSelector;
  final LocalModelCatalog _localModelCatalog;
  final InferenceSettings settings;
  final Logger _log = Logger('BenchmarkViewModel');

  InferenceSession? _session;
  ModelProfile? _profile;
  final List<BenchmarkSample> _samples = [];
  List<LocalModelEntry> _availableModels = [];
  PreflightStatus? _preflight;

  bool isRunning = false;
  bool isSustainedRunning = false;
  String? lastError;
  bool _appJustLaunched = false;
  bool _sustainedCancelled = false;

  BenchmarkViewModel({
    BenchmarkRecorder? recorder,
    BackendSelector? backendSelector,
    LocalModelCatalog? localModelCatalog,
    this.settings = kBenchmarkDefaultSettings,
  }) : _recorder = recorder ?? BenchmarkRecorder(),
       _backendSelector = backendSelector ?? BackendSelector(),
       _localModelCatalog = localModelCatalog ?? LocalModelCatalog();

  List<BenchmarkSample> get samples => List.unmodifiable(_samples);
  List<LocalModelEntry> get availableModels =>
      List.unmodifiable(_availableModels);
  bool get hasOpenSession => _session != null;
  String? get openModelId => _profile?.id;
  bool get appJustLaunched => _appJustLaunched;
  PreflightStatus? get preflight => _preflight;

  void setAppJustLaunched(bool value) {
    if (_appJustLaunched == value) return;
    _appJustLaunched = value;
    notifyListeners();
  }

  Future<void> refreshLocalModels() async {
    _availableModels = await _localModelCatalog.discover();
    notifyListeners();
  }

  Future<void> refreshPreflight() async {
    _preflight = await _recorder.checkPreflight();
    notifyListeners();
  }

  /// Opens a fresh session for [modelPath] and records the first ("session
  /// cold") generation on it. Closes any previously open session first —
  /// mirrors the no-leak pattern in `LlamaCppBackend`/`MlxBackend` callers.
  Future<void> openSessionAndRun(
    String modelPath,
    List<ChatMessage> messages, {
    String? label,
  }) async {
    closeSession();

    final profile = ModelProfile.fromLocalPath(modelPath);

    isRunning = true;
    lastError = null;
    notifyListeners();
    try {
      final backend = _backendSelector.select(profile);
      final result = await _recorder.runNewSession(
        backend: backend,
        profile: profile,
        settings: settings,
        messages: messages,
        label: label ?? 'session-cold',
      );
      _session = result.session;
      _profile = profile;
      _samples.add(result.sample);
      await _checkpointCsv();
    } catch (e, st) {
      _log.error('openSessionAndRun failed', error: e, st: st);
      lastError = e.toString();
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }

  /// Convenience for [openSessionAndRun] with a single user turn.
  Future<void> openSessionAndRunPrompt(
    String modelPath,
    String prompt, {
    String? label,
  }) => openSessionAndRun(modelPath, [
    ChatMessage(content: prompt, isUser: true),
  ], label: label);

  /// Records another ("session warm") generation on the currently open
  /// session. No-op if no session is open.
  Future<void> runOnOpenSession(
    List<ChatMessage> messages, {
    String? label,
  }) async {
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
        messages: messages,
        label: label ?? 'session-warm',
      );
      _samples.add(sample);
      await _checkpointCsv();
    } catch (e, st) {
      _log.error('runOnOpenSession failed', error: e, st: st);
      lastError = e.toString();
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }

  /// Convenience for [runOnOpenSession] with a single user turn.
  Future<void> runOnOpenSessionPrompt(String prompt, {String? label}) =>
      runOnOpenSession([
        ChatMessage(content: prompt, isUser: true),
      ], label: label);

  /// Runs the standardized benchmark protocol across every requested tier.
  Future<void> runProtocol(
    String modelPath, {
    List<PromptTier>? tiers,
    int warmRepeats = 2,
  }) async {
    final labelFirstTierAppCold = _appJustLaunched;
    if (_appJustLaunched) {
      _appJustLaunched = false;
      notifyListeners();
    }
    final list = tiers ?? PromptTier.all;
    for (var i = 0; i < list.length; i++) {
      await _runProtocolTier(
        modelPath,
        list[i],
        warmRepeats: warmRepeats,
        isFirstSessionThisLaunch: labelFirstTierAppCold && i == 0,
      );
    }
  }

  Future<void> _runProtocolTier(
    String modelPath,
    PromptTier tier, {
    required int warmRepeats,
    required bool isFirstSessionThisLaunch,
  }) async {
    final coldLabel =
        isFirstSessionThisLaunch
            ? '${tier.label}-app-cold'
            : '${tier.label}-session-cold';
    await openSessionAndRun(modelPath, tier.toMessages(), label: coldLabel);

    for (var i = 1; i <= warmRepeats; i++) {
      await runOnOpenSession(
        tier.toMessages(),
        label: '${tier.label}-session-warm-$i',
      );
    }
    closeSession();
  }

  /// Convenience for sustained generation from Widget-owned prompt text.
  Future<void> runSustainedPrompt(
    String prompt, {
    Duration duration = const Duration(minutes: 10),
    int? maxIterations,
    String labelPrefix = 'sustained',
  }) => runSustained(
    messages: [ChatMessage(content: prompt, isUser: true)],
    duration: duration,
    maxIterations: maxIterations,
    labelPrefix: labelPrefix,
  );

  /// Repeatedly generates on the open session for a fixed wall-clock period.
  Future<void> runSustained({
    required List<ChatMessage> messages,
    Duration duration = const Duration(minutes: 10),
    int? maxIterations,
    String labelPrefix = 'sustained',
  }) async {
    if (!hasOpenSession) {
      throw StateError('runSustained requires an already-open session');
    }

    _sustainedCancelled = false;
    isSustainedRunning = true;
    notifyListeners();
    final start = DateTime.now();
    var i = 0;
    try {
      while (!_sustainedCancelled &&
          DateTime.now().difference(start) < duration &&
          (maxIterations == null || i < maxIterations)) {
        i++;
        final elapsedMs = DateTime.now().difference(start).inMilliseconds;
        await runOnOpenSession(
          messages,
          label: '$labelPrefix-t${elapsedMs}ms-$i',
        );
      }
    } finally {
      isSustainedRunning = false;
      notifyListeners();
    }
  }

  /// Stops sustained mode after the in-flight generation completes.
  void cancelSustained() => _sustainedCancelled = true;

  /// Current thermal/battery reading — task-C02 pre-flight check, shown in
  /// the UI before a protocol run so the tester can confirm the manual
  /// checklist items (airplane mode, fixed brightness) alongside it.
  Future<PreflightStatus> checkPreflight() => _recorder.checkPreflight();

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

  Future<File> exportCsv() =>
      _writeExport('csv', benchmarkSamplesToCsv(_samples));

  Future<File> exportJson() =>
      _writeExport('json', benchmarkSamplesToJson(_samples));

  /// Writes into Documents (not a temp dir) so the export survives an app
  /// restart and shows up in the Files app under "On My iPhone" — the app
  /// already ships `UIFileSharingEnabled`/`LSSupportsOpeningDocumentsInPlace`,
  /// which only exposes Documents, not tmp.
  Future<File> _writeExport(String extension, String content) async {
    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp('[:.]'),
      '-',
    );
    final file = File('${dir.path}/benchmark_$timestamp.$extension');
    return file.writeAsString(content);
  }

  /// Overwrites a fixed-name checkpoint CSV in Documents after every sample
  /// — so a mid-run crash (or a broken share sheet — see task-C03 2026-07-21
  /// incident, `sharePositionOrigin` PlatformException dropped a full run)
  /// still leaves completed samples recoverable via the Files app or
  /// `devicectl device copy from`, without needing the user to tap anything.
  Future<void> _checkpointCsv() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/benchmark_live.csv');
      await file.writeAsString(benchmarkSamplesToCsv(_samples));
    } catch (e, st) {
      _log.error('checkpoint write failed', error: e, st: st);
    }
  }

  @override
  void dispose() {
    closeSession();
    super.dispose();
  }
}
