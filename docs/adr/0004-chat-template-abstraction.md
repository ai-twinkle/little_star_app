# ADR-0004: ChatTemplate Abstraction Replaces PromptFormat

- **Status**: Accepted
- **Date**: 2026-05-21
- **Deciders**: Bobson Lin

## Context

### The old approach: `PromptFormat`

Before v0.1, prompt formatting was handled by `lib/core/format/prompt_format.dart`
(deleted in task-302). It contained:

- `PromptFormatType` — an enum with variants like `raw`, `chatml`, `llama2`, `alpaca`.
- `PromptFormat` — an abstract class with a `format(String input)` method that
  took a **single string** and wrapped it in template tokens.
- `SequenceFilter` — a streaming stop-sequence stripper.
- `ModelParams.format` — a field that carried the `PromptFormatType` for a model.

This design had two fundamental weaknesses:

1. **Flat-string input**: `PromptFormat.format` received a single pre-assembled
   string, not a structured conversation. The caller was responsible for turning
   a list of `ChatMessage` objects into one blob before calling `format`. This
   meant the template had no visibility into turn boundaries, roles, or system
   prompt placement.

2. **Wrong token families**: `ChatViewModel._buildPromptFromHistory()` was
   hardcoded to wrap turns with `<|user|>` / `<|assistant|>` / `<|system|>`
   tokens — tokens that exist only in certain model families (e.g. Phi, some
   Mistral variants). Those tokens **do not exist** in Gemma or Llama 3 GGUF
   models, which use entirely different control sequences.

### The Smoking Gun

When the app started supporting Gemma and Llama 3 models (alongside the original
Phi-style models), `ChatViewModel._buildPromptFromHistory()` silently produced
malformed prompts for every non-Phi model — the model received tokens it was
never trained on, causing degraded or nonsensical output. The bug was not caught
by any test because the old code had no per-template unit coverage.

The exact deleted code:

```dart
// BEFORE (wrong for Gemma / Llama 3):
String _buildPromptFromHistory() {
  buffer.writeln('<|system|>');          // Phi-style token
  if (msg.isUser) {
    buffer.writeln('<|user|>');          // Phi-style token
    buffer.writeln('<|assistant|>');     // Phi-style token
  }
}
```

### What v0.1 required

Supporting Gemma 2, Llama 3.x, and Qwen 2/3 in the same app meant the prompt
assembly logic had to be **model-family-aware**, **structured** (operating on
`List<ChatMessage>`, not a pre-joined string), and **independently testable**.

## Decision

We introduce a `ChatTemplate` abstraction with four concrete implementations
and a resolver:

```
ChatTemplate (abstract)
├── GemmaChatTemplate      — <bos><start_of_turn>user / model
├── Llama3ChatTemplate     — <|begin_of_text|> + header tokens + <|eot_id|>
├── ChatMlChatTemplate     — <|im_start|> / <|im_end|>  (Qwen 2 & 3)
└── FallbackChatTemplate   — plain "User: / Assistant:" text
```

`ChatTemplate.render(List<ChatMessage> messages, {String? systemPrompt})` takes
a structured conversation and returns the fully assembled prompt string — always
ending with the model's opening token so inference continues as the assistant.

`ChatTemplateResolver.resolve(ModelProfile, [ChatTemplate? override])` selects
the right implementation by inspecting `ModelProfile.chatTemplateHint`
(`gemma | llama3 | qwen2 | qwen3 | unknown`). An explicit override takes priority,
enabling per-session customisation or testing with a fake template.

`chatTemplateProvider` (a `Provider.family<ChatTemplate, ModelProfile>`) wires
the resolver into Riverpod so ViewModels and Sessions receive the correct template
via dependency injection.

The old `PromptFormat`, `PromptFormatType`, `SequenceFilter`, and
`ModelParams.format` are deleted entirely.

## Consequences

### Positive
- Each model family's prompt is assembled by a dedicated, independently unit-tested
  class. Adding a new model family requires only a new `ChatTemplate` subclass and
  a branch in `ChatTemplateResolver`.
- The Smoking Gun is fixed: `ChatViewModel` no longer assembles prompts manually;
  `InferenceSession` (via `LlamaCppSession`) calls `applyChatTemplate` on the
  native GGUF side, which knows the exact template embedded in the model file.
  For the MLX path, `mlx-swift-lm` handles chat template application natively.
- Test coverage is precise: each template implementation has dedicated tests for
  system prompt placement, role token accuracy, and turn separator correctness.
- The `override` parameter in `ChatTemplateResolver.resolve` supports both runtime
  customisation and hermetic unit testing with a stub template.

### Negative
- Every new model family requires a new `ChatTemplate` implementation and a new
  `ChatTemplateHint` variant; there is no zero-effort path for an unknown model.
  `FallbackChatTemplate` provides a degraded-but-functional safety net, but the
  output quality will be lower than a model-specific template.
- The `override` mechanism is powerful but undocumented at the call site; callers
  must consult `CONTRIBUTING.md` (or this ADR) to understand when to use it.

### Neutral
- `LlamaCppSession` delegates final prompt rendering to llama.cpp's built-in
  `applyChatTemplate` rather than calling `ChatTemplate.render` directly. The
  `ChatTemplate` Dart abstraction is therefore primarily used by `ChatViewModel`
  for constructing the context messages passed to `InferenceSettings`, and for
  testing prompt logic in isolation.

## Alternatives Considered

### Retain `PromptFormat`, add per-family branches

Extend the existing `PromptFormat` with switch statements for each model family.

- **Pros**: minimal churn; no new abstraction.
- **Cons**: flat-string input constraint remains; the branching logic becomes a
  maintenance liability as model families grow; existing tests (if any) would be
  insufficient for per-family correctness.
- **Why rejected**: the root cause — operating on a pre-joined string with no
  turn-boundary awareness — cannot be fixed without changing the interface.

### Jinja2-style template engine (runtime templates from GGUF metadata)

Load the chat template string embedded in the GGUF file at runtime and render it
with a Jinja2-like engine (e.g. a Dart port or a WebAssembly build).

- **Pros**: templates are fully data-driven; adding a new model requires no code
  change if its GGUF has a well-formed template.
- **Cons**: no mature, dependency-free Dart Jinja2 implementation exists; a
  WebAssembly approach adds significant binary size and startup latency; edge
  cases in the Jinja2 subset used by GGUF files are difficult to test
  exhaustively.
- **Why rejected**: the dependency risk and complexity are not justified for the
  four model families targeted in v0.1. The hard-coded approach can be revisited
  in a future cycle if the model catalogue grows substantially.

## References

- `lib/core/prompt/chat_template.dart` — `ChatTemplate` abstract class and four
  concrete implementations.
- `lib/core/prompt/chat_template_resolver.dart` — `ChatTemplateResolver` and
  `chatTemplateProvider`.
- `lib/core/model/model_profile.dart` — `ChatTemplateHint` enum.
- Deleted: `lib/core/format/prompt_format.dart` (see git commit `fd70f99`).
- Git commit `4bb2e76` — ChatTemplate abstraction introduction (task-301).
- Git commit `7c60863` — Smoking Gun fix in ChatViewModel (task-604).
- `.dev/cycles/2026-05-21-v0.1-major-refactor/plan.md` — EP-3 task definitions.
- `.dev/cycles/2026-05-21-v0.1-major-refactor/construction.md` — task-301 and
  task-302 implementation notes.
