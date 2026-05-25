import 'package:little_star_app/models/chat_message.dart';

/// The lifecycle of a single model-loaded inference context.
///
/// Typical usage:
/// ```dart
/// final session = backend.createSession(profile, settings);
/// try {
///   await for (final token in session.generate(messages)) {
///     buffer.write(token);
///   }
/// } finally {
///   session.dispose();
/// }
/// ```
abstract class InferenceSession {
  /// Streams tokens for a response to [messages].
  ///
  /// The stream completes normally when generation finishes, and completes
  /// with an error on failure. Calling [cancel] closes the stream early
  /// without an error.
  Stream<String> generate(List<ChatMessage> messages);

  /// Signals the current [generate] call to stop after the next token.
  /// No-op if no generation is in progress.
  void cancel();

  /// Releases all native resources (model context, samplers, allocations).
  /// Must be called exactly once when the session is no longer needed.
  /// After disposal, calling any other method is undefined behaviour.
  void dispose();
}
