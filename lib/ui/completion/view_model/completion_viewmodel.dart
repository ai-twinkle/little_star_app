import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:little_star_app/core/lm.dart';


class CompletionViewModel extends ChangeNotifier {
  UnifiedLM _lm;

  // Run state
  bool _isRunning = false;
  String _outputText = '';
  StreamSubscription<String>? _subscription;

  // Timing
  DateTime? _submittedAt;
  DateTime? _firstTokenAt;
  DateTime? _finishedAt;

  // Counters (generated token count is approximated per stream emission)
  int _promptTokenCount = 0;
  int _generatedTokenCount = 0;

  // Metrics
  Duration? _ttft; // Time-To-First-Token
  Duration? _totalDuration;
  double? _prefillTokensPerSecond; // approx: prompt_tokens / ttft
  double? _decodeTokensPerSecond;  // approx: generated_tokens / decode_duration

  // Stop information
  String? _stopReason; // length | stop_sequence | eog_or_stream_end | error | cancelled

  CompletionViewModel({
    required String modelPath,
  }) : _lm = UnifiedLM(modelPath);

  // Public getters for UI
  bool get isRunning => _isRunning;
  String get outputText => _outputText;
  int get promptTokenCount => _promptTokenCount;
  int get generatedTokenCount => _generatedTokenCount;
  Duration? get ttft => _ttft;
  Duration? get totalDuration => _totalDuration;
  double? get prefillTokensPerSecond => _prefillTokensPerSecond;
  double? get decodeTokensPerSecond => _decodeTokensPerSecond;
  String? get stopReason => _stopReason;

  Future<void> loadModel(String modelPath) async {
    _lm = UnifiedLM(modelPath);
  }

  Future<void> startCompletion(
    String prompt, {
    int? maxTokens,
    List<String>? stopSequences,
  }) async {
    // Cancel any previous run
    await _subscription?.cancel();

    _resetRunState();
    _isRunning = true;
    _submittedAt = DateTime.now();

    // Count prompt tokens upfront (needed for prefill throughput estimation)
    try {
      _promptTokenCount = _lm.countPromptTokens(prompt);
    } catch (_) {
      _promptTokenCount = 0;
    }
    notifyListeners();

    // Start streaming
    final stream = _lm.completionStream(
      prompt,
      maxTokens: maxTokens,
      stopSequences: stopSequences,
    );

    _subscription = stream.listen(
      (chunk) {
        // First token arrival
        if (_firstTokenAt == null) {
          _firstTokenAt = DateTime.now();
          _ttft = _firstTokenAt!.difference(_submittedAt!);
          _prefillTokensPerSecond = _computeThroughput(
            tokens: _promptTokenCount,
            duration: _ttft,
          );
        }

        // Append output and update generated token count (approx by emission)
        _outputText += chunk;
        _generatedTokenCount += 1;

        // Update decode throughput using elapsed since first token
        final decodeDuration = DateTime.now().difference(_firstTokenAt!);
        _decodeTokensPerSecond = _computeThroughput(
          tokens: _generatedTokenCount,
          duration: decodeDuration,
        );

        // Length-based stop (best-effort)
        if (maxTokens != null && _generatedTokenCount >= maxTokens) {
          _stopReason ??= 'length';
        }

        notifyListeners();
      },
      onDone: () {
        _finishedAt = DateTime.now();
        _totalDuration = _finishedAt!.difference(_submittedAt!);

        // Infer stop reason if not set by length
        _stopReason ??= _inferStopReason(
          output: _outputText,
          stopSequences: stopSequences,
        );

        _isRunning = false;
        notifyListeners();
      },
      onError: (error, stack) {
        _stopReason = 'error';
        _isRunning = false;
        _finishedAt = DateTime.now();
        _totalDuration = _submittedAt == null ? null : _finishedAt!.difference(_submittedAt!);
        notifyListeners();
      },
      cancelOnError: true,
    );
  }

  Future<void> cancel() async {
    if (_isRunning) {
      _stopReason = 'cancelled';
    }
    await _subscription?.cancel();
    _isRunning = false;
    _finishedAt = DateTime.now();
    _totalDuration = _submittedAt == null ? null : _finishedAt!.difference(_submittedAt!);
    notifyListeners();
  }

  void reset() {
    _resetRunState();
    notifyListeners();
  }

  Map<String, dynamic> exportMetrics() {
    final decodeDuration = _firstTokenAt == null || _finishedAt == null
        ? null
        : _finishedAt!.difference(_firstTokenAt!);

    return {
      'submitted_at': _submittedAt?.toIso8601String(),
      'first_token_at': _firstTokenAt?.toIso8601String(),
      'finished_at': _finishedAt?.toIso8601String(),
      'prompt_tokens': _promptTokenCount,
      'generated_tokens_approx': _generatedTokenCount,
      'ttft_ms': _ttft?.inMilliseconds,
      'total_time_ms': _totalDuration?.inMilliseconds,
      'prefill_tps': _prefillTokensPerSecond,
      'decode_tps': _decodeTokensPerSecond,
      'decode_time_ms': decodeDuration?.inMilliseconds,
      'stop_reason': _stopReason,
      'text_length': _outputText.length,
    };
  }

  String exportMetricsJson({bool pretty = true}) {
    final map = exportMetrics();
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(map)
        : jsonEncode(map);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // Helpers
  double? _computeThroughput({required int tokens, Duration? duration}) {
    if (duration == null) return null;
    final seconds = duration.inMilliseconds / 1000.0;
    if (seconds <= 0) return null;
    return tokens / seconds;
  }

  String _inferStopReason({required String output, List<String>? stopSequences}) {
    if (stopSequences != null && stopSequences.isNotEmpty) {
      for (final s in stopSequences) {
        if (output.endsWith(s)) {
          return 'stop_sequence';
        }
      }
    }
    return 'eog_or_stream_end';
  }

  void _resetRunState() {
    _subscription = null;
    _isRunning = false;
    _outputText = '';
    _submittedAt = null;
    _firstTokenAt = null;
    _finishedAt = null;
    _promptTokenCount = 0;
    _generatedTokenCount = 0;
    _ttft = null;
    _totalDuration = null;
    _prefillTokensPerSecond = null;
    _decodeTokensPerSecond = null;
    _stopReason = null;
  }
}