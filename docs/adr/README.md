# Architecture Decision Records

This directory holds the Architecture Decision Records (ADRs) for `little_star_app`.

## What is an ADR

An ADR captures **why** a particular technical decision was made — the forces in play, the alternatives considered, and the consequences accepted. ADRs are not specifications, tutorials, or how-to guides. If you need to know *what* the code does, read the code; if you need to know *why* it looks the way it does, read the relevant ADR.

## Scope

Not every decision in this repo deserves an ADR. We record only those decisions that:

- Involve a genuine trade-off between competing alternatives, **or**
- Are technically unusual enough that future maintainers would benefit from the rationale.

Routine choices that fall out of common Flutter / Dart conventions are not recorded here.

## Format

All ADRs follow the [`_template.md`](./_template.md) structure (Status, Context, Decision, Consequences, Alternatives Considered, References). Keep them short — if an ADR grows past ~1.5 pages, it has likely turned into a design document and should be trimmed back.

## Status Lifecycle

```
Proposed ──► Accepted ──► Superseded by ADR-NNNN
```

- **Proposed** — under discussion; decision not yet final.
- **Accepted** — adopted in the codebase. The default for ADRs in this repo.
- **Superseded by ADR-NNNN** — replaced by a newer decision. The superseding ADR should link back to this one in its `References` section.

ADRs in this repo are written **after** the decision has been adopted in code, so they enter the index directly as `Accepted`. We do not retrace a `Proposed` phase retroactively.

## Numbering Convention

- Four-digit zero-padded sequence (`0001`, `0002`, …).
- Strictly incrementing; numbers are **never reused**, even if an ADR is superseded or withdrawn.
- A superseded ADR stays in the index with its original number and its status updated.

## ADR Index

| #    | Title                                                                                | 正體中文 | Status   | Date |
|------|--------------------------------------------------------------------------------------|----------|----------|------|
| 0001 | [MLX integration via Path A (mlx-swift + Pigeon)](./0001-mlx-integration-path-a.md) | [中文](./0001-mlx-integration-path-a_zh-tw.md) | Accepted | 2026-05-21 |
| 0002 | [Dual native bridge (FFI for llama.cpp + Pigeon for MLX)](./0002-dual-native-bridge.md) | [中文](./0002-dual-native-bridge_zh-tw.md) | Accepted | 2026-05-21 |
| 0003 | [Pigeon streaming pattern (Swift → Dart token stream)](./0003-pigeon-streaming-pattern.md) | [中文](./0003-pigeon-streaming-pattern_zh-tw.md) | Accepted | 2026-05-21 |
| 0004 | [ChatTemplate abstraction replaces PromptFormat](./0004-chat-template-abstraction.md) | [中文](./0004-chat-template-abstraction_zh-tw.md) | Accepted | 2026-05-21 |
| 0005 | [GenerationController / ViewModel boundary](./0005-generation-controller-boundary.md) | [中文](./0005-generation-controller-boundary_zh-tw.md) | Accepted | 2026-05-21 |

> Each ADR ships in two files: the English primary (`NNNN-title.md`) and a Traditional
> Chinese translation (`NNNN-title_zh-tw.md`). Where the two versions differ, the English
> version is authoritative. Date column is filled when each ADR is committed.

## Writing a New ADR

1. Copy [`_template.md`](./_template.md) to `NNNN-short-kebab-title.md`, using the next available number.
2. Fill in the sections. Keep `Context` focused on the problem space, `Decision` to one paragraph, and let `Consequences` carry the nuance.
3. Add a row to the index above.
4. Open a PR. Include `Related: ADR-NNNN` in the commit footer.

If your ADR supersedes an earlier one, update the older ADR's Status to `Superseded by ADR-NNNN` in the same PR.
