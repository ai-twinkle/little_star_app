# ADR-0005: GenerationController / ViewModel Boundary

- **Status**: Accepted
- **Date**: 2026-05-21
- **Deciders**: Bobson Lin

## Context

Before v0.1, `ChatViewModel` and `CompletionViewModel` each contained the full
inference lifecycle alongside their UI state responsibilities:

- Creating and managing an `InferenceSession` (or the legacy `UnifiedLM`).
- Driving the token generation loop directly inside the ViewModel.
- Accumulating streamed tokens into the UI state.
- Implementing cancellation via an ad-hoc boolean flag.
- Computing metrics (TTFT, TPS, stop reason) inline, duplicated across both
  ViewModels.

`CompletionViewModel` had grown to **371 lines**. It was difficult to unit-test
(any test needed a live `InferenceSession` or a carefully seamed fake), and
adding new metrics or backend-specific behaviour required changes in multiple
places.

Two concrete problems triggered the refactor:

1. **Testability**: generation logic mixed with `ChangeNotifier` state made
   isolation impractical. A dedicated controller without Flutter dependencies
   can be tested with a simple `InferenceSession` stub.

2. **Metrics duplication**: TTFT and TPS calculations were copy-pasted between
   `CompletionViewModel` and `ChatViewModel` with slightly different
   implementations, making consistent metrics reporting hard to guarantee.

## Decision

We extract `GenerationController` — a plain Dart class (no Flutter, no Riverpod)
that owns generation orchestration:

| Responsibility | Lives in |
|----------------|----------|
| Driving `InferenceSession.generate` | `GenerationController` |
| Measuring TTFT and TPS | `GenerationController` |
| Defining generation metric value types | `lib/core/inference/generation_metrics.dart` |
| Cooperative cancellation (`cancel()`) | `GenerationController` |
| Emitting `Stream<GenerationEvent>` | `GenerationController` |
| UI state (messages list, `isGenerating`, error text) | ViewModel |
| Session lifecycle (create / reuse / dirty-flag) | ViewModel |
| Subscribing to events and updating UI state | ViewModel |

The two sides communicate exclusively through `Stream<GenerationEvent>`:

```
GenerationEvent
  ├── GenerationToken(String token)
  ├── GenerationDone(GenerationMetrics)   ← TTFT, TPS, stop reason, token count
  └── GenerationError(Object, StackTrace?)
```

`GenerationController.run(session, messages)` is a pure async generator; it
carries no widget or provider dependencies and can be tested with a stub
`InferenceSession` in plain `dart test`.

ViewModels hold a `GenerationController` instance and a `StreamSubscription`.
On `sendMessage` / `run`, they call `_controller.run(...)`, subscribe to the
stream, and map each event to a state mutation followed by `notifyListeners()`.

## Consequences

### Positive
- `GenerationController` has **14 dedicated unit tests** covering normal
  generation, cancellation mid-stream, error propagation, and concurrent-run
  guard. None require a Flutter test harness.
- `CompletionViewModel` shrank from **371 → 244 lines** (34% reduction),
  exceeding the >30% target set in the EP-6 plan.
- TTFT and TPS are computed in one place (`GenerationController.run`); both
  ViewModels receive `GenerationMetrics` in `GenerationDone` without any
  duplication.
- A future third ViewModel (e.g. a voice or document-mode UI) reuses
  `GenerationController` without duplicating generation logic.
- Adding a new backend does not require touching any ViewModel — it only
  requires an `InferenceSession` implementation.

### Negative
- Two objects (`GenerationController` + ViewModel) share a lifetime that must
  be coordinated. If the ViewModel is disposed while a generation is running,
  it must call `_controller.cancel()` and `_sub?.cancel()` before releasing
  the stream subscription; a missed cancel leaves the underlying
  `InferenceSession` running and consuming memory.
- `StreamSubscription` management adds boilerplate to each ViewModel's
  `sendMessage` / `dispose` path. This is a well-understood Flutter pattern
  but it is not zero-cost to implement correctly.

### Neutral
- `GenerationMetrics` carries `StopReason` (`completed | cancelled | error`),
  TTFT, TPS, and token count. ViewModels map these to their own display types
  (`MetricsData` in `CompletionViewModel`, `MessageMetrics` in `ChatViewModel`);
  the mapping is lightweight but adds one more place to update if a new field
  is added to `GenerationMetrics`.
- `GenerationController` is not a Riverpod provider — it is instantiated
  directly inside each ViewModel. This keeps the controller free of DI
  framework coupling; if a shared controller is ever needed (e.g. background
  generation visible across screens), it can be lifted into a provider at
  that point.

## Alternatives Considered

### Keep generation logic in the ViewModel

Continue the v0.0.x pattern where each ViewModel drives generation inline.

- **Pros**: fewer files; no stream subscription management.
- **Cons**: the original pain points remain — untestable in isolation, metrics
  duplicated, and each new ViewModel must re-implement the same logic.
- **Why rejected**: the testability problem alone justified the extraction;
  the metrics duplication sealed it.

### Introduce BLoC (`flutter_bloc`)

Move generation and UI state into a BLoC, with `Event` → `State` transitions
driving the stream.

- **Pros**: well-known pattern; explicit event/state graph is easy to reason
  about.
- **Cons**: adds `flutter_bloc` as a dependency alongside Riverpod, introducing
  two competing state management idioms. Riverpod already covers the DI and
  provider needs; a BLoC layer would add mental-model overhead without a
  functional gain.
- **Why rejected**: Riverpod already handles what BLoC would bring; a second
  state management library is not justified.

### Use a Riverpod `AsyncNotifier` for generation

Expose generation state as a Riverpod `AsyncNotifierProvider`, letting Riverpod
manage the async lifecycle.

- **Pros**: consistent with Riverpod idioms; widgets can `watch` generation
  state directly without a `ChangeNotifier`.
- **Cons**: `AsyncNotifier` does not cleanly model a streaming sequence with
  multiple intermediate states (each token) and a terminal state (done / error).
  Forcing a `Stream` into `AsyncNotifier` adds impedance mismatch. The existing
  `ChangeNotifier` + `Stream` pattern is simpler for this use case.
- **Why rejected**: the streaming nature of generation is a poor fit for
  `AsyncNotifier`'s single-value async contract.

## References

- `lib/ui/shared/inference/generation_controller.dart` — `GenerationController`
  and the `GenerationEvent` hierarchy.
- `lib/core/inference/generation_metrics.dart` — shared `GenerationMetrics`
  and `StopReason` value types.
- `lib/ui/completion/view_model/completion_viewmodel.dart` — ViewModel after
  extraction (244 lines); `MetricsData` mapping.
- `lib/ui/chat/view_model/chat_viewmodel.dart` — ViewModel after extraction
  (277 lines); `MessageMetrics` mapping.
- `lib/core/inference/inference_session.dart` — `InferenceSession` contract
  consumed by `GenerationController`.
- Git commit `7c60863` — simultaneous ViewModel migration and Smoking Gun fix
  (task-603 + task-604).
- `.dev/cycles/2026-05-21-v0.1-major-refactor/plan.md` — EP-6 task definitions
  and the >30% line-count reduction target.
- `.dev/cycles/2026-05-21-v0.1-major-refactor/construction.md` — task-601
  (`GenerationController` extraction) and task-603/task-604 (ViewModel migration).
- ADR-0004: ChatTemplate abstraction — the Smoking Gun fix that landed in the
  same commit as the ViewModel migration.
