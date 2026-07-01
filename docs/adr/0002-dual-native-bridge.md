# ADR-0002: Dual Native Bridge (FFI for llama.cpp, Pigeon for MLX)

- **Status**: Accepted
- **Date**: 2026-05-21
- **Deciders**: Bobson Lin

## Context

v0.1 ships two inference backends:

| Backend | Native library | Language | Platform |
|---------|---------------|----------|----------|
| `LlamaCppBackend` | `libllama-*.a` / `llama.dll` | C / C++ | iOS, macOS, Windows |
| `MlxBackend` | `mlx-swift-lm` (SPM) | Swift | iOS, macOS (Apple Silicon only) |

These two libraries present fundamentally different integration interfaces:

- **llama.cpp** exposes a plain C API. `dart:ffi` can bind it directly:
  the Dart layer calls C functions, passes primitive types and raw pointers,
  and receives synchronous return values. Streaming is achieved by driving
  the `llama_decode` / sampler loop from Dart.

- **mlx-swift-lm** is a Swift package with no stable C API surface. Its
  generation pipeline is async Swift (`async`/`await`, `AsyncStream`). The
  only practical way to reach it from Dart is through a platform channel.
  Pigeon was chosen as the type-safe channel layer (see ADR-0001).

The question this ADR addresses: given that the two backends arrived at
different bridge technologies for good reasons, should the app normalise
them onto a single bridge, or accept the dual-track arrangement?

## Decision

We accept the **dual native bridge**: `dart:ffi` for llama.cpp and Pigeon
for MLX. Both bridges are hidden behind the `InferenceBackend` /
`InferenceSession` abstraction. `BackendSelector` picks the right
implementation at runtime based on `ModelProfile.format` and platform
capability; call sites never reference the bridge layer directly.

The abstraction boundary is intentional and load-bearing: it means a future
third backend (e.g. Core ML, ONNX Runtime) can be added without changing
the selection or ViewModel layers.

## Consequences

### Positive
- Each bridge uses the tool best suited to its native library —
  no forced adapter layer that weakens either side.
- llama.cpp retains direct FFI, preserving the zero-overhead path
  for the primary backend.
- MLX retains Pigeon, keeping streaming and cancellation idiomatic
  in Swift without fighting `@_cdecl` constraints.
- Desktop (Windows / Linux) support for llama.cpp requires no changes
  to the bridge strategy: `dart:ffi` works on all platforms; Pigeon
  is simply not wired on platforms where `MlxBackend` is not registered.

### Negative
- Two distinct lifecycle models must be reconciled at the abstraction layer:
  - FFI sessions own native memory and must call `llama_free` on dispose.
  - Pigeon sessions rely on Swift ARC; cancellation goes through a
    `MlxInferenceHostApi.cancel()` call.
- Error propagation differs: FFI surfaces errors as return-code integers
  that `LlamaCppSession` maps to Dart exceptions; Pigeon surfaces them
  as `PlatformException`, which `MlxChannel` maps to the same exception
  types. This mapping must be kept in sync as error cases evolve.
- `BackendSelector` carries platform-detection logic (`supportsMLX`) that
  must be updated whenever a new platform is added.

### Neutral
- `InferenceBackend.canHandle(ModelProfile)` encapsulates both
  format-compatibility and platform-availability checks, so the two
  backends remain interchangeable from the caller's perspective.
- If llama.cpp ever gains an Apple Neural Engine execution provider,
  its integration path may be re-evaluated — but that is a v0.2+ concern.

## Alternatives Considered

### Unify on FFI (dart:ffi for both backends)

Bring MLX to Dart over `dart:ffi` using either `mlx-c` or a Swift
`@_cdecl` wrapper.

- **Pros**: single bridge type; consistent mental model.
- **Cons**: `mlx-c` does not provide an LLM pipeline API; a `@_cdecl`
  Swift wrapper cannot capture closures, making streaming impractical.
  Both options were evaluated in detail in ADR-0001 and rejected.
- **Why rejected**: the MLX streaming requirement rules out a clean FFI
  implementation; see ADR-0001 for the full analysis.

### Unify on Pigeon (Pigeon for both backends)

Wrap the llama.cpp C API in an Objective-C or Swift host plugin,
then expose it to Dart via Pigeon.

- **Pros**: single channel type; type-safe generated code for both sides.
- **Cons**: llama.cpp already has a Dart-callable C API — wrapping it in
  ObjC/Swift adds a gratuitous layer with no functional benefit. More
  significantly, Pigeon is a Flutter platform-channel mechanism tied to
  iOS/macOS/Android/Windows host runners; it cannot easily support future
  non-Flutter embeddings or pure-Dart test environments. FFI works in
  every context, including `dart test` with a stub native lib.
- **Why rejected**: unnecessary indirection on the llama.cpp side; reduced
  portability and testability for the primary backend.

## References

- ADR-0001: MLX integration via Path A — rationale for choosing Pigeon
  for MLX in the first place.
- ADR-0003: Pigeon streaming pattern — details of the token-streaming
  design on the Pigeon side.
- `lib/core/inference/inference_backend.dart` — shared abstraction both
  backends implement (`canHandle`, `createSession`).
- `lib/core/inference/backend_selector.dart` — runtime backend selection
  logic (`BackendSelector`, `BackendOverride`, `BackendPlatform`).
- `lib/core/inference/llama_cpp_backend.dart` — FFI-based backend
  (`LlamaCppBackend`, `LlamaCppSession`, `LlamaFfiDriver`).
- `lib/core/engine/llama_cpp/llama_cpp_ffi.dart` — raw FFI bindings.
- `lib/core/engine/mlx/mlx_channel.dart` — Pigeon-based MLX facade.
- `.dev/cycles/2026-05-21-v0.1-major-refactor/exploration.md` — Section C
  "MLX 整合路徑比較"; Section D "整合藍圖" (backend abstraction design).
