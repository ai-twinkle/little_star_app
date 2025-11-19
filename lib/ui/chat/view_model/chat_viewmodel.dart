import 'dart:async';
import 'package:flutter/material.dart';

import 'package:little_star_app/core/lm.dart' hide ChatMessage;
import 'package:little_star_app/models/chat_message.dart';

// Data class for per-message metrics
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

class ChatViewModel extends ChangeNotifier {
  UnifiedLM _lm;

  // Chat state
  final List<ChatMessage> _messages = [];
  final Map<int, MessageMetrics> _messageMetrics = {}; // Index -> Metrics

  // Streaming state
  bool _isGenerating = false;
  StreamSubscription<String>? _subscription;
  final ValueNotifier<String> streamingMessageNotifier = ValueNotifier<String>('');

  // Timing for current generation
  DateTime? _generationStartTime;
  DateTime? _firstTokenTime;
  DateTime? _generationEndTime;
  int _currentTokenCount = 0;

  // Settings
  int _maxTokens = 512;
  int _contextMessageCount = 10; // Keep last N messages for context
  List<String> _stopSequences = ['<|user|>', '<|system|>', '\n<|user|>', '\n<|system|>'];
  double _temperature = 0.8;
  int _topK = 40;
  double _topP = 0.9;
  String _systemPrompt = 'You are a helpful AI assistant.';
  String? _selectedModelPath;

  ChatViewModel({required String modelPath})
      : _lm = UnifiedLM(modelPath),
        _selectedModelPath = modelPath;

  // Getters
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  int get maxTokens => _maxTokens;
  List<String> get stopSequences => _stopSequences;
  double get temperature => _temperature;
  int get topK => _topK;
  double get topP => _topP;
  String get systemPrompt => _systemPrompt;
  String? get selectedModelPath => _selectedModelPath;
  String get selectedModelName => _selectedModelPath != null
      ? _selectedModelPath!.split('/').last
      : 'No model selected';

  MessageMetrics? getMessageMetrics(int index) => _messageMetrics[index];

  Future<void> selectModel(String modelPath) async {
    _lm = UnifiedLM(modelPath);
    _selectedModelPath = modelPath;
    notifyListeners();
  }

  Future<void> sendMessage(String userMessageText) async {
    if (userMessageText.trim().isEmpty || _isGenerating) return;

    // Cancel any ongoing generation
    await _subscription?.cancel();

    // Add user message
    final userMessage = ChatMessage(
      content: userMessageText,
      isUser: true,
      modelName: selectedModelName,
    );
    _messages.add(userMessage);
    notifyListeners();

    // Start generating AI response
    await _generateResponse();
  }

  Future<void> _generateResponse() async {
    _isGenerating = true;
    streamingMessageNotifier.value = '';
    _generationStartTime = DateTime.now();
    _firstTokenTime = null;
    _generationEndTime = null;
    _currentTokenCount = 0;
    notifyListeners();

    // Build prompt from recent messages
    final prompt = _buildPromptFromHistory();

    // Update sampler params
    _lm.updateSamplerParams(
      temperature: _temperature,
      topK: _topK,
      topP: _topP,
    );

    // Start streaming
    final stream = _lm.completionStream(
      prompt,
      maxTokens: _maxTokens,
      stopSequences: _stopSequences,
    );

    _subscription = stream.listen(
      (chunk) {
        // Track first token time
        _firstTokenTime ??= DateTime.now();

        streamingMessageNotifier.value += chunk;
        _currentTokenCount++;

        // Check for stop sequences in the accumulated text
        if (_shouldStop(streamingMessageNotifier.value)) {
          _finalizeMessage();
          _subscription?.cancel();
        }
      },
      onDone: () {
        _finalizeMessage();
      },
      onError: (error, stack) {
        debugPrint('Error during generation: $error');

        // Add error message if we got any content
        if (streamingMessageNotifier.value.isNotEmpty) {
          final aiMessage = ChatMessage(
            content: '${streamingMessageNotifier.value}\n[Error occurred]',
            isUser: false,
            modelName: selectedModelName,
          );
          _messages.add(aiMessage);
        }

        streamingMessageNotifier.value = '';
        _isGenerating = false;
        notifyListeners();
      },
      cancelOnError: true,
    );
  }

  Future<void> stopGeneration() async {
    if (!_isGenerating) return;

    await _subscription?.cancel();
    _generationEndTime = DateTime.now();

    // Save partial message if any
    if (streamingMessageNotifier.value.isNotEmpty) {
      final aiMessage = ChatMessage(
        content: '${streamingMessageNotifier.value}\n[Generation stopped]',
        isUser: false,
        modelName: selectedModelName,
      );
      _messages.add(aiMessage);
      _storeCurrentMetrics(_messages.length - 1);
    }

    streamingMessageNotifier.value = '';
    _isGenerating = false;
    notifyListeners();
  }

  void _storeCurrentMetrics(int messageIndex) {
    if (_generationStartTime == null) return;

    final ttft = _firstTokenTime?.difference(_generationStartTime!);

    final totalDuration = _generationEndTime?.difference(_generationStartTime!);

    final tps = totalDuration != null && totalDuration.inMilliseconds > 0
        ? _currentTokenCount / (totalDuration.inMilliseconds / 1000.0)
        : null;

    _messageMetrics[messageIndex] = MessageMetrics(
      ttft: ttft,
      totalDuration: totalDuration,
      tokensPerSecond: tps,
      tokenCount: _currentTokenCount,
      stopReason: _isGenerating ? 'stopped' : 'completed',
    );
  }

  String _buildPromptFromHistory() {
    // Take last N messages for context
    final contextMessages = _messages.length > _contextMessageCount
        ? _messages.sublist(_messages.length - _contextMessageCount)
        : _messages;

    // Format with system prompt
    final buffer = StringBuffer();

    if (_systemPrompt.isNotEmpty) {
      buffer.writeln('<|system|>');
      buffer.writeln(_systemPrompt);
    }

    for (final msg in contextMessages) {
      if (msg.isUser) {
        buffer.writeln('<|user|>');
        buffer.writeln(msg.content);
      } else {
        buffer.writeln('<|assistant|>');
        buffer.writeln(msg.content);
      }
    }

    buffer.writeln('<|assistant|>');
    return buffer.toString();
  }

  void _finalizeMessage() {
    // Prevent duplicate finalization
    if (!_isGenerating) return;

    _generationEndTime = DateTime.now();

    // Only create message if we have content
    if (streamingMessageNotifier.value.isNotEmpty) {
      final aiMessage = ChatMessage(
        content: streamingMessageNotifier.value,
        isUser: false,
        modelName: selectedModelName,
      );
      _messages.add(aiMessage);

      // Store metrics for this message
      _storeCurrentMetrics(_messages.length - 1);
    }

    // Reset streaming state
    streamingMessageNotifier.value = '';
    _isGenerating = false;
    notifyListeners();
  }

  bool _shouldStop(String text) {
    if (_stopSequences.isEmpty) return false;

    for (final stopSeq in _stopSequences) {
      if (text.contains(stopSeq)) {
        // Remove the stop sequence from the output
        final index = text.indexOf(stopSeq);
        streamingMessageNotifier.value = text.substring(0, index);
        return true;
      }
    }
    return false;
  }

  void clearChat() {
    _messages.clear();
    _messageMetrics.clear();
    streamingMessageNotifier.value = '';
    notifyListeners();
  }

  void updateSettings({
    int? maxTokens,
    int? contextMessageCount,
    List<String>? stopSequences,
    double? temperature,
    int? topK,
    double? topP,
    String? systemPrompt,
  }) {
    if (maxTokens != null) _maxTokens = maxTokens.clamp(16, 2048);
    if (contextMessageCount != null) _contextMessageCount = contextMessageCount.clamp(1, 50);
    if (stopSequences != null) _stopSequences = stopSequences.where((s) => s.trim().isNotEmpty).toList();
    if (temperature != null) _temperature = temperature.clamp(0.0, 2.0);
    if (topK != null) _topK = topK.clamp(1, 100);
    if (topP != null) _topP = topP.clamp(0.1, 1.0);
    if (systemPrompt != null) _systemPrompt = systemPrompt;
    notifyListeners();
  }

  void resetSettings() {
    _maxTokens = 512;
    _contextMessageCount = 10;
    _stopSequences = ['<|user|>', '<|system|>', '\n<|user|>', '\n<|system|>'];
    _temperature = 0.8;
    _topK = 40;
    _topP = 0.9;
    _systemPrompt = 'You are a helpful AI assistant.';
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    streamingMessageNotifier.dispose();
    super.dispose();
  }
}
