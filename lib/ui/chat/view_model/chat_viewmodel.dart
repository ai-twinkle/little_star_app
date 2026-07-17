import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:little_star_app/core/inference/backend_selector.dart';
import 'package:little_star_app/core/inference/inference_session.dart';
import 'package:little_star_app/core/inference/inference_settings.dart';
import 'package:little_star_app/core/inference/mlx_backend.dart';
import 'package:little_star_app/core/inference/sampling_params.dart';
import 'package:little_star_app/core/model/model_profile.dart';
import 'package:little_star_app/models/chat_message.dart';
import 'package:little_star_app/ui/shared/inference/generation_controller.dart';

// ── MessageMetrics ────────────────────────────────────────────────────────────

class MessageMetrics {
  final Duration? ttft;
  final Duration? totalDuration;
  final double? tokensPerSecond;
  final int? tokenCount;
  final String? stopReason;

  MessageMetrics({
    this.ttft,
    this.totalDuration,
    this.tokensPerSecond,
    this.tokenCount,
    this.stopReason,
  });
}

// ── ChatViewModel ─────────────────────────────────────────────────────────────

class ChatViewModel extends ChangeNotifier {
  // Settings — single source of truth.
  InferenceSettings _settings;
  int _contextMessageCount = 10;

  // Session lifecycle — kept alive across turns; recreated on model/settings change.
  ModelProfile? _profile;
  InferenceSession? _session;
  bool _sessionDirty = false;

  final _controller = GenerationController();
  StreamSubscription<GenerationEvent>? _sub;

  // Chat state
  final List<ChatMessage> _messages = [];
  final Map<int, MessageMetrics> _messageMetrics = {};
  bool _isGenerating = false;
  String? _selectedModelPath;

  final ValueNotifier<String> streamingMessageNotifier = ValueNotifier('');

  ChatViewModel({
    required String modelPath,
    @visibleForTesting InferenceSession Function(ModelProfile, InferenceSettings)? sessionFactory,
    @visibleForTesting BackendSelector? backendSelector,
  })  : _settings = const InferenceSettings(
          maxTokens: 512,
          systemPrompt: 'You are a helpful AI assistant.',
          samplingParams: SamplingParams(topK: 40, topP: 0.9, temperature: 0.8),
        ),
        _selectedModelPath = modelPath,
        _sessionFactory = sessionFactory,
        _backendSelector =
            backendSelector ?? BackendSelector(mlxBackendFactory: MlxBackend.new) {
    if (modelPath.isNotEmpty) {
      _profile = _buildProfile(modelPath);
      _session = _openSession();
    }
  }

  final InferenceSession Function(ModelProfile, InferenceSettings)? _sessionFactory;
  final BackendSelector _backendSelector;

  // ── Public getters ────────────────────────────────────────────────────────

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;

  int get maxTokens => _settings.maxTokens;
  List<String> get stopSequences => _settings.stopSequences;
  double get temperature => _settings.samplingParams.temperature;
  int get topK => _settings.samplingParams.topK;
  double get topP => _settings.samplingParams.topP;
  String get systemPrompt => _settings.systemPrompt ?? 'You are a helpful AI assistant.';
  String? get selectedModelPath => _selectedModelPath;
  String get selectedModelName =>
      _selectedModelPath?.split('/').last ?? 'No model selected';

  MessageMetrics? getMessageMetrics(int index) => _messageMetrics[index];

  // ── Model selection ───────────────────────────────────────────────────────

  Future<void> selectModel(String modelPath) async {
    _session?.dispose();
    _selectedModelPath = modelPath;
    _profile = _buildProfile(modelPath);
    _session = _openSession();
    _sessionDirty = false;
    notifyListeners();
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isGenerating) return;

    await _sub?.cancel();
    _messages.add(ChatMessage(
      content: text,
      isUser: true,
      modelName: selectedModelName,
    ));
    notifyListeners();

    await _generateResponse();
  }

  Future<void> stopGeneration() async {
    if (!_isGenerating) return;

    _controller.cancel();
    await _sub?.cancel();
    _sub = null;

    if (streamingMessageNotifier.value.isNotEmpty) {
      _messages.add(ChatMessage(
        content: '${streamingMessageNotifier.value}\n[Generation stopped]',
        isUser: false,
        modelName: selectedModelName,
      ));
      _messageMetrics[_messages.length - 1] =
          MessageMetrics(stopReason: StopReason.cancelled.name);
    }

    streamingMessageNotifier.value = '';
    _isGenerating = false;
    notifyListeners();
  }

  void clearChat() {
    _messages.clear();
    _messageMetrics.clear();
    streamingMessageNotifier.value = '';
    notifyListeners();
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  void updateSettings({
    int? maxTokens,
    int? contextMessageCount,
    List<String>? stopSequences,
    double? temperature,
    int? topK,
    double? topP,
    String? systemPrompt,
  }) {
    if (contextMessageCount != null) {
      _contextMessageCount = contextMessageCount.clamp(1, 50);
    }
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
    _contextMessageCount = 10;
    _settings = const InferenceSettings(
      maxTokens: 512,
      systemPrompt: 'You are a helpful AI assistant.',
      samplingParams: SamplingParams(topK: 40, topP: 0.9, temperature: 0.8),
    );
    _sessionDirty = true;
    notifyListeners();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _sub?.cancel();
    _session?.dispose();
    streamingMessageNotifier.dispose();
    super.dispose();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _generateResponse() async {
    if (_sessionDirty || _session == null) {
      _session?.dispose();
      _session = _openSession();
      _sessionDirty = false;
    }
    final session = _session;
    if (session == null) return;

    _isGenerating = true;
    streamingMessageNotifier.value = '';
    notifyListeners();

    final contextMessages = _messages.length > _contextMessageCount
        ? _messages.sublist(_messages.length - _contextMessageCount)
        : List.of(_messages);

    _sub = _controller.run(session, contextMessages).listen(_handleEvent);
  }

  void _handleEvent(GenerationEvent event) {
    switch (event) {
      case GenerationToken(:final token):
        streamingMessageNotifier.value += token;

      case GenerationDone(:final metrics):
        _finalizeMessage(metrics);

      case GenerationError():
        if (streamingMessageNotifier.value.isNotEmpty) {
          _messages.add(ChatMessage(
            content: '${streamingMessageNotifier.value}\n[Error occurred]',
            isUser: false,
            modelName: selectedModelName,
          ));
        }
        streamingMessageNotifier.value = '';
        _isGenerating = false;
        notifyListeners();
    }
  }

  void _finalizeMessage(GenerationMetrics metrics) {
    if (!_isGenerating) return;

    if (streamingMessageNotifier.value.isNotEmpty) {
      _messages.add(ChatMessage(
        content: streamingMessageNotifier.value,
        isUser: false,
        modelName: selectedModelName,
      ));
      _messageMetrics[_messages.length - 1] = MessageMetrics(
        ttft: metrics.ttft,
        tokensPerSecond: metrics.tokensPerSecond,
        tokenCount: metrics.tokenCount,
        stopReason: metrics.stopReason.name,
      );
    }

    streamingMessageNotifier.value = '';
    _isGenerating = false;
    notifyListeners();
  }

  InferenceSession? _openSession() {
    final profile = _profile;
    if (profile == null) return null;
    if (_sessionFactory != null) return _sessionFactory(profile, _settings);
    final backend = _backendSelector.select(profile);
    return backend.createSession(profile, _settings);
  }

  static ModelProfile _buildProfile(String modelPath) => ModelProfile(
        id: modelPath,
        displayName: modelPath.split('/').last,
        format: _detectFormat(modelPath),
        localPath: modelPath,
      );

  /// MLX models are downloaded as a directory of weight/config files (no
  /// single-file extension); GGUF models are always a single `.gguf` file.
  static ModelFormat _detectFormat(String modelPath) =>
      modelPath.toLowerCase().endsWith('.gguf') ? ModelFormat.gguf : ModelFormat.mlx;
}
