import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:little_star_app/core/inference/backend_selector.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/inference/sampling_params.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/ui/shared/inference/generation_controller.dart';

// ── MetricsData ───────────────────────────────────────────────────────────────
// Kept for widget compatibility — fields not available from GenerationController
// are left at their zero/null defaults.

class MetricsData {
  final int promptTokenCount;
  final int generatedTokenCount;
  final Duration? ttft;
  final Duration? totalDuration;
  final double? prefillTokensPerSecond;
  final double? decodeTokensPerSecond;
  final String? stopReason;

  MetricsData({
    this.promptTokenCount = 0,
    this.generatedTokenCount = 0,
    this.ttft,
    this.totalDuration,
    this.prefillTokensPerSecond,
    this.decodeTokensPerSecond,
    this.stopReason,
  });

  MetricsData copyWith({
    int? promptTokenCount,
    int? generatedTokenCount,
    Duration? ttft,
    Duration? totalDuration,
    double? prefillTokensPerSecond,
    double? decodeTokensPerSecond,
    String? stopReason,
  }) {
    return MetricsData(
      promptTokenCount: promptTokenCount ?? this.promptTokenCount,
      generatedTokenCount: generatedTokenCount ?? this.generatedTokenCount,
      ttft: ttft ?? this.ttft,
      totalDuration: totalDuration ?? this.totalDuration,
      prefillTokensPerSecond: prefillTokensPerSecond ?? this.prefillTokensPerSecond,
      decodeTokensPerSecond: decodeTokensPerSecond ?? this.decodeTokensPerSecond,
      stopReason: stopReason ?? this.stopReason,
    );
  }
}

// ── CompletionViewModel ───────────────────────────────────────────────────────

class CompletionViewModel extends ChangeNotifier {
  // Settings — single source of truth for sampler + inference config.
  InferenceSettings _settings;

  // Session lifecycle.  Session is kept alive across runs; recreated only when
  // model or settings change (_sessionDirty == true).
  ModelProfile? _profile;
  InferenceSession? _session;
  bool _sessionDirty = false;

  final _controller = GenerationController();
  StreamSubscription<GenerationEvent>? _sub;

  // UI state
  bool _isRunning = false;
  String? _selectedModelPath;

  // Public notifiers — same API as before for widget compat.
  final ValueNotifier<String> outputTextNotifier = ValueNotifier('');
  final ValueNotifier<MetricsData> metricsNotifier = ValueNotifier(MetricsData());

  CompletionViewModel({
    required String modelPath,
    @visibleForTesting InferenceSession Function(ModelProfile, InferenceSettings)? sessionFactory,
  })  : _settings = const InferenceSettings(maxTokens: 256),
        _selectedModelPath = modelPath,
        _sessionFactory = sessionFactory {
    _profile = _buildProfile(modelPath);
    _session = _openSession();
  }

  final InferenceSession Function(ModelProfile, InferenceSettings)? _sessionFactory;

  // ── Public getters ────────────────────────────────────────────────────────

  bool get isRunning => _isRunning;
  String? get selectedModelPath => _selectedModelPath;
  String get selectedModelName =>
      _selectedModelPath?.split('/').last ?? 'No model selected';

  int get maxTokens => _settings.maxTokens;
  List<String> get stopSequences => _settings.stopSequences;
  double get temperature => _settings.samplingParams.temperature;
  int get topK => _settings.samplingParams.topK;
  double get topP => _settings.samplingParams.topP;
  String get systemPrompt => _settings.systemPrompt ?? '';

  // ── Model selection ───────────────────────────────────────────────────────

  Future<void> selectModel(String modelPath) async {
    _session?.dispose();
    _selectedModelPath = modelPath;
    _profile = _buildProfile(modelPath);
    _session = _openSession();
    _sessionDirty = false;
    notifyListeners();
  }

  // ── Completion ────────────────────────────────────────────────────────────

  Future<void> startCompletion(String userPrompt) async {
    if (_profile == null || _isRunning) return;
    await _sub?.cancel();

    if (_sessionDirty || _session == null) {
      _session?.dispose();
      _session = _openSession();
      _sessionDirty = false;
    }
    final session = _session;
    if (session == null) return;

    _resetRunState();
    _isRunning = true;
    notifyListeners();

    final messages = [
      ChatMessage(content: userPrompt, isUser: true, timestamp: DateTime.now()),
    ];
    _sub = _controller.run(session, messages).listen(_handleEvent);
  }

  Future<void> cancel() async {
    if (!_isRunning) return;
    _controller.cancel();
    await _sub?.cancel();
    _isRunning = false;
    metricsNotifier.value = metricsNotifier.value.copyWith(stopReason: 'cancelled');
    notifyListeners();
  }

  void reset() {
    _resetRunState();
    notifyListeners();
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  void updateSettings({
    int? maxTokens,
    List<String>? stopSequences,
    double? temperature,
    int? topK,
    double? topP,
    String? systemPrompt,
  }) {
    final prev = _settings;
    _settings = InferenceSettings(
      samplingParams: SamplingParams(
        topK: (topK ?? _settings.samplingParams.topK).clamp(1, 100),
        topP: (topP ?? _settings.samplingParams.topP).clamp(0.1, 1.0),
        temperature:
            (temperature ?? _settings.samplingParams.temperature).clamp(0.0, 2.0),
      ),
      systemPrompt: systemPrompt ?? _settings.systemPrompt,
      maxTokens: (maxTokens ?? _settings.maxTokens).clamp(16, 2048),
      stopSequences: stopSequences != null
          ? stopSequences.where((s) => s.trim().isNotEmpty).toList()
          : _settings.stopSequences,
    );
    if (_settings != prev) _sessionDirty = true;
    notifyListeners();
  }

  void resetSettings() {
    _settings = const InferenceSettings(maxTokens: 256);
    _sessionDirty = true;
    notifyListeners();
  }

  // ── Metrics export ────────────────────────────────────────────────────────

  Map<String, dynamic> exportMetrics() {
    final m = metricsNotifier.value;
    return {
      'generated_tokens': m.generatedTokenCount,
      'ttft_ms': m.ttft?.inMilliseconds,
      'decode_tps': m.decodeTokensPerSecond,
      'stop_reason': m.stopReason,
    };
  }

  String exportMetricsJson({bool pretty = true}) {
    final map = exportMetrics();
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(map)
        : jsonEncode(map);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _sub?.cancel();
    _session?.dispose();
    outputTextNotifier.dispose();
    metricsNotifier.dispose();
    super.dispose();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  void _handleEvent(GenerationEvent event) {
    switch (event) {
      case GenerationToken(:final token):
        outputTextNotifier.value += token;

      case GenerationDone(:final metrics):
        _isRunning = false;
        metricsNotifier.value = MetricsData(
          generatedTokenCount: metrics.tokenCount,
          ttft: metrics.ttft,
          decodeTokensPerSecond: metrics.tokensPerSecond,
          stopReason: metrics.stopReason.name,
        );
        notifyListeners();

      case GenerationError():
        _isRunning = false;
        metricsNotifier.value = metricsNotifier.value.copyWith(stopReason: 'error');
        notifyListeners();
    }
  }

  InferenceSession? _openSession() {
    final profile = _profile;
    if (profile == null) return null;
    if (_sessionFactory != null) return _sessionFactory(profile, _settings);
    final backend = BackendSelector().select(profile);
    return backend.createSession(profile, _settings);
  }

  static ModelProfile _buildProfile(String modelPath) => ModelProfile(
        id: modelPath,
        displayName: modelPath.split('/').last,
        format: ModelFormat.gguf,
        localPath: modelPath,
      );

  void _resetRunState() {
    outputTextNotifier.value = '';
    metricsNotifier.value = MetricsData();
  }
}
