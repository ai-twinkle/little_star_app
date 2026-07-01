# ADR-0003: Pigeon Streaming Pattern (Swift → Dart Token Stream)

- **Status**: Accepted
- **Date**: 2026-05-21
- **Deciders**: Bobson Lin

## Context

LLM generation is inherently a streaming operation: the model produces one
token at a time over hundreds of milliseconds to seconds. The UX depends on
delivering each token to the UI as soon as it is produced.

Pigeon's default contract is **request–response**: Dart calls a host method,
Swift computes a result, and replies once. This pattern does not map to a
continuous token stream. A solution is needed that:

1. Allows Swift to **push** tokens to Dart asynchronously, without Dart polling.
2. Supports **cooperative cancellation** — Dart can abort a generation in
   progress mid-stream.
3. Propagates **errors** and a **done sentinel** reliably.
4. Delivers **metrics** (tokens/sec) alongside the stream without a separate
   call.
5. Stays type-safe; avoids untyped `dynamic` channel payloads.

## Decision

We use a **split-channel pattern** with two Pigeon constructs working together:

### Host API (Dart → Swift, fire-and-forget start + cancel)

```
MlxInferenceHostApi.startGeneration(messages, params)  // kicks off generation
MlxInferenceHostApi.cancelGeneration()                  // cooperative cancel
```

`startGeneration` returns immediately (it does not `await` the full output).
Swift spawns a `Task` that drives the `mlx-swift-lm` async generation loop
internally. This keeps the Pigeon host call from blocking the platform thread.

### Event stream (Swift → Dart, push)

Pigeon's `@EventChannelApi` generates:
- A `StreamHandler` on the Swift side (`MlxTokenStreamHandler`) that receives
  a `PigeonEventSink<MlxTokenEvent>`.
- A `Stream<MlxTokenEvent>` function (`onToken()`) on the Dart side.

Swift calls `sink.success(MlxTokenEvent)` for each token. The final event
carries `isDone: true` and the final `tokensPerSecond` value.

### Token event shape

```dart
class MlxTokenEvent {
  final String token;          // text fragment (may be "" on the done sentinel)
  final bool isDone;           // true on the last event only
  final double? tokensPerSecond; // reported with every token
}
```

### Dart-side assembly (`MlxChannel.generate`)

```dart
Stream<MlxTokenEvent> generate(messages, {params}) async* {
  await _host.startGeneration(messages, effectiveParams); // fire-and-forget
  await for (final event in onToken()) {
    yield event;
    if (event.isDone) break;                             // close stream
  }
}
```

### Cancellation

Dart calls `MlxChannel.cancel()` → `_host.cancelGeneration()`. On the Swift
side this sets `Task.cancel()` on the running generation task. The Swift
`for await` loop checks `Task.isCancelled` each iteration and breaks; the
event stream ends naturally (no error event is emitted for a user-initiated
cancel).

### Error propagation

If Swift throws during `loadModel` or `startGeneration`, Pigeon surfaces it
as a `PlatformException` on the Dart side. `MlxChannel` lets these propagate
to the caller; `MlxInferenceSession` catches and converts them into
`GenerationError` events consistent with `LlamaCppSession`.

## Consequences

### Positive
- Dart receives a `Stream<MlxTokenEvent>` — the same async-iterable contract
  callers expect from `LlamaCppSession`, making the two backends interchangeable
  at the `InferenceSession` layer.
- Cancellation is clean and cooperative; no orphaned Swift tasks after cancel.
- `tokensPerSecond` is included in every token event so the UI can display a
  live TPS counter without an extra RPC.
- Pigeon's code generation ensures both ends stay in sync; adding a field to
  `MlxTokenEvent` in the Pigeon schema regenerates both Dart and Swift glue.

### Negative
- Back-pressure is not implemented: if the Dart consumer is slow (e.g. UI
  jank), token events accumulate in the platform channel buffer. In practice,
  edge-LLM token rates (< 50 tok/s) make this a non-issue for v0.1, but a
  buffer strategy may be needed at higher rates.
- The `isDone` sentinel in the token stream is an application-level convention,
  not a platform-channel primitive. Both sides must uphold the contract;
  a bug on either end (e.g. never emitting `isDone: true`) will leave the
  Dart `Stream` open indefinitely.
- Two Pigeon constructs (HostApi + EventChannelApi) must be set up and
  registered in `AppDelegate` — slightly more boilerplate than a single
  MethodChannel.

### Neutral
- The pattern is effectively an EventChannel but implemented through Pigeon's
  `@EventChannelApi`, preserving type safety while matching Flutter's
  conventional streaming idiom.
- `startGeneration` is fire-and-forget by design; the Dart side does not know
  whether generation completed successfully until it sees the `isDone` sentinel
  or a `PlatformException` from the event stream.

## Alternatives Considered

### Polling via repeated host API calls

Dart polls `MlxInferenceHostApi.nextToken()` in a tight loop after calling
`startGeneration`.

- **Pros**: no event channel needed; single HostApi construct.
- **Cons**: polling frequency determines latency floor; wastes CPU when idle;
  hard to align poll rate with actual token production rate.
- **Why rejected**: unnecessary complexity; no latency or throughput advantage
  over a push channel.

### Raw platform channel (BasicMessageChannel / EventChannel without Pigeon)

Use Flutter's `EventChannel` directly with untyped `dynamic` payloads.

- **Pros**: no Pigeon dependency; familiar Flutter primitive.
- **Cons**: payload encoding/decoding is manual and untyped; adding or renaming
  a field requires manual changes on both sides with no compile-time check;
  drift between Dart and Swift is hard to catch.
- **Why rejected**: type safety is the main reason Pigeon was introduced in the
  first place (see ADR-0001).

### Pigeon `@FlutterApi` callback (non-event-channel variant)

Register a `MlxInferenceFlutterApi` on the Dart side; Swift calls
`flutterApi.onToken(event)` directly, bypassing the event channel.

- **Pros**: slightly simpler setup than `@EventChannelApi`.
- **Cons**: `@FlutterApi` calls are fire-and-forget from Swift with no
  per-message back-channel; error propagation from the stream is less
  structured. `@EventChannelApi` produces a proper `Stream` on the Dart side
  with a built-in end-of-stream signal, which is semantically cleaner.
- **Why rejected**: `@EventChannelApi` is the more idiomatic fit for a
  continuous sequence with a terminal event.

## References

- ADR-0001: MLX integration via Path A — choice of Pigeon as the bridge layer.
- ADR-0002: Dual native bridge — context for why MLX uses Pigeon rather than FFI.
- `lib/core/engine/mlx/mlx_channel.dart` — `MlxChannel.generate` and `cancel`.
- `lib/core/engine/mlx/mlx_inference.g.dart` — Pigeon-generated `MlxTokenEvent`,
  `MlxInferenceHostApi`, and `onToken()` stream.
- `ios/Runner/MlxBridge/MlxInferenceBridge.swift` — `startGeneration` Task loop,
  `MlxTokenStreamHandler.emit`, `cancelGeneration`.
- `ios/Runner/MlxBridge/MlxInference.g.swift` — Pigeon-generated Swift glue.
- `.dev/cycles/2026-05-21-v0.1-major-refactor/exploration.md` — Section C,
  Spike #1 design notes on streaming channel pattern.
- `.dev/cycles/2026-05-21-v0.1-major-refactor/construction.md` — Spike #1
  implementation and token-stream validation.
