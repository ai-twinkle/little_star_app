import 'dart:math' as math;

/// Detects role-turn markers (e.g. `<start_of_turn>user`, `<|assistant|>`)
/// that signal the model has stopped answering and started hallucinating a
/// new turn without ever sampling a recognized EOG/EOS token. Both backends'
/// own token-id-level stop checks (llama.cpp's `llama_vocab_is_eog`, MLX's
/// `eosTokenIds`/`extraEOSTokens`) already stop generation when the model
/// *does* sample one, so this is a text-level safety net for the cases where
/// it doesn't — observed on both backends (task-B03, 2026-07-15/18). Holds
/// back text that could still grow into a marker so a marker split across
/// multiple token chunks never leaks to the caller.
class TurnMarkerFilter {
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
