# ADR-0001: MLX Integration via Path A (mlx-swift-lm + Pigeon)

- **Status**: Accepted
- **Date**: 2026-05-21
- **Deciders**: Bobson Lin

## Context

v0.1 introduces MLX as a second inference backend alongside llama.cpp, targeting
Apple Silicon performance on iOS (and eventually macOS). Two industry signals
confirmed the investment worthwhile:

- **Apple WWDC 2025** officially positioned MLX as the recommended LLM inference
  framework for Apple Silicon, running alongside the Foundation Models framework.
- **Ollama announced in March 2026** that it had migrated to MLX as its Apple Silicon
  inference foundation.

The MLX ecosystem is built around Swift:

| Library | Role |
|---------|------|
| `mlx-swift` | Official Swift bindings for MLX |
| `mlx-swift-lm` | High-level LLM/VLM Swift package (loading, tokenisation, generation, chat templates, sampling) |
| `mlx-c` | Official C API; used internally by `mlx-swift` |
| `mlx-community/*` (HuggingFace) | Pre-quantised models in **safetensors** format (not GGUF-compatible) |

The app already uses `dart:ffi` for llama.cpp. The question was whether to reuse FFI
for MLX or to introduce a different bridge. Three paths were evaluated:

- **Path A** — `mlx-swift-lm` called from Swift, exposed to Dart via Pigeon.
- **Path B** — `mlx-c` called directly from Dart via `dart:ffi`.
- **Path C** — Swift wrapper around `mlx-swift-lm`, exported via `@_cdecl`, called
  from Dart via `dart:ffi`.

The decision was made during the exploration phase of the `2026-05-21-v0.1-major-refactor`
cycle (see References). Key constraints weighed:

1. **Token-by-token streaming** is a hard requirement — the UX depends on it.
2. **Time budget**: v0.1 already has a large scope; MLX integration must be low-cost.
3. **Long-term maintainability**: the upstream library must keep up with new model families.

## Decision

We adopt **Path A: `mlx-swift-lm` via Pigeon**.

The Dart side calls a Pigeon-generated type-safe channel (`MlxInferenceHostApi`).
The Swift side (`MlxInferenceBridge`) is a thin wrapper around `mlx-swift-lm` 3.31.3,
importing `MLXLLM`, `MLXLMCommon`, and `MLXHuggingFace` via Swift Package Manager.
Streaming tokens are pushed back to Dart using a Pigeon `@FlutterApi` callback
(`MlxInferenceFlutterApi`), which `MlxChannel` on the Dart side wraps into a
`Stream<MlxTokenEvent>`. Cancellation is cooperative: Dart calls
`MlxInferenceHostApi.cancel()` and Swift breaks its generation loop.

## Consequences

### Positive
- `mlx-swift-lm` handles loading, tokenisation, chat templates, and sampling —
  no need to reimplement any of it.
- `mlx-community/*` models (4-bit, 8-bit quantised) work out of the box.
- Pigeon's `@FlutterApi` callback pattern maps naturally to a Dart `Stream`,
  giving the same `Stream<GenerationEvent>` contract as `LlamaCppBackend`.
- Apple and Ollama backing means the upstream library will track new model families.

### Negative
- Introduces a Swift Package Manager dependency (`mlx-swift-lm 3.31.3`,
  `swift-transformers`) on both iOS and macOS targets.
- The native bridge is now **dual-track** (FFI for llama.cpp, Pigeon for MLX) —
  two lifecycle and error models must be reconciled at the `InferenceBackend`
  abstraction layer. See ADR-0002.
- Pigeon imposes a slight IPC overhead versus direct FFI. Measured acceptable:
  edge LLM token rates are typically < 50 tok/s; Pigeon round-trip latency is
  negligible compared with per-token model computation.

### Neutral
- MLX uses **safetensors** model files (not GGUF), so model management
  (`ModelProfile`, download service) requires a `format: gguf | mlx` field —
  the two model families cannot share a single download path.
- macOS Runner also requires SPM setup; the integration is identical to iOS
  but the `MlxInferenceBridge` is compiled separately per platform target.

## Alternatives Considered

### Path B — `mlx-c` via `dart:ffi`

`mlx-c` (v0.4.1) is the official C API backing `mlx-swift`. Calling it from Dart
over FFI would keep the bridge consistent with llama.cpp.

- **Pros**: single bridge type; familiar FFI pattern.
- **Cons**: `mlx-c` exposes low-level tensor ops, not an LLM pipeline.
  Reproducing what `mlx-swift-lm` provides (safetensors loader, AutoTokenizer,
  chat templates, KV-cache management, sampling) in C or Dart would be a
  substantial rewrite. Streaming via FFI callback (`Pointer<NativeFunction>`)
  is possible but fragile with Swift object lifetimes.
- **Why rejected**: explosion of implementation work; upstream `mlx-c` does not
  commit to an LLM-level API, so the burden would fall on us permanently.

### Path C — Swift `@_cdecl` wrapper + `dart:ffi`

A thin Swift layer wraps `mlx-swift-lm` and exports C-compatible symbols via
`@_cdecl`, which Dart calls over FFI.

- **Pros**: keeps a single FFI bridge; avoids Pigeon as a dependency.
- **Cons**: `@_cdecl` functions cannot capture Swift closures or reference Swift
  objects — streaming requires either a polling model or a C function-pointer
  callback, both of which are more error-prone than Pigeon's message channel.
  Swift object lifetime across the FFI boundary is also non-trivial to manage.
- **Why rejected**: streaming is a non-negotiable core feature; the `@_cdecl`
  constraint makes a clean streaming implementation impractical.

## References

- `.dev/cycles/2026-05-21-v0.1-major-refactor/exploration.md` — Section C
  "MLX 整合路徑比較" (line 225 onwards); decision recorded in discussion log.
- `.dev/cycles/2026-05-21-v0.1-major-refactor/construction.md` — Spike #1
  (MLX Hello World on iOS) and subsequent MLX integration tasks.
- `lib/core/engine/mlx/mlx_channel.dart` — Dart facade over the Pigeon channel.
- `lib/core/engine/mlx/mlx_inference.g.dart` — Pigeon-generated host/flutter API.
- `ios/Runner/MlxBridge/MlxInferenceBridge.swift` — Swift-side bridge implementation.
- `ios/Runner/MlxBridge/MlxInference.g.swift` — Pigeon-generated Swift glue.
- `lib/core/inference/inference_backend.dart` — `InferenceBackend` abstraction both
  backends implement.
- ADR-0002: Dual native bridge (FFI + Pigeon) — rationale for keeping both bridges.
- ADR-0003: Pigeon streaming pattern — details of the token streaming design.
