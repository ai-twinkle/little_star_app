# ADR-0007: Night-Market Arena Presentation and Non-Blocking Model Reminder

- **Status**: Accepted
- **Date**: 2026-08-06
- **Deciders**: Product owner

## Context

The game needs a recognizable Taiwanese identity without allowing decorative
night-market scenery to compete with mascots, whole-card choices, the defense,
or the result. It also needs to make the optional on-device model discoverable
without suggesting that a download is required to start or finish a game.

A disposable prototype compared three information structures on phone and wide
screens and exercised choice, locked, draw, defense, result, and reduced-motion
states.

## Decision

Use Variant A, “招牌擂台”, as the production design basis. Phone and wide
layouts retain the same semantic order—header, progress, primary task, then
secondary context or model entry—while arranging those units vertically or
side by side. The visual system is deliberately sparse: one red game sign, two
visible bulbs, dark oilcloth or metal panels, red/cyan current-choice seats,
and amber feedback reserved for current or recorded state and primary actions.

When no usable model is installed, show a non-blocking reminder once per app
run. Its primary action is `先玩再說`; its secondary action is
`前往推薦模型`. After dismissal, the defense screen retains a smaller model
entry. Navigating to model management preserves the game and triggers model
rediscovery on return. Download failure never blocks the game.

## Consequences

### Positive
- Mascots, stance names, and whole-card choices remain the dominant elements.
- Phone and wide layouts remain one experience with a stable semantic order.
- The game reads as Taiwanese night-market themed without relying on dense
  scenery, generated signage, or culturally misleading temple architecture.
- The reminder makes on-device AI discoverable while clearly preserving the
  fallback-complete game path.

### Negative
- Sparse decoration leaves less room for atmosphere and requires careful use
  of typography, material, and feedback to retain identity.
- Once-per-app-run reminder state and game-preserving navigation add in-memory
  lifecycle behavior that needs explicit tests.

### Neutral
- Variant B remains a reference for wide-layout density, not an alternative
  production information architecture.
- Red and cyan identify the two current seats, not specific food stances.
- Reduced motion substitutes static markers and fades for movement; sound is
  not added.

## Alternatives Considered

### Variant B: denser wide composition
- **Pros**: useful wide-screen density and more visible secondary context.
- **Cons**: less direct mapping from phone's whole-card choices to the wide
  result hierarchy.
- **Why rejected**: Variant A provides the strongest semantic continuity; B is
  retained only as a density reference.

### Variant C: ledger composition
- **Pros**: orderly, compact, and easy to scan.
- **Cons**: reads like an order ledger and loses game energy.
- **Why rejected**: it weakens mascots, choice cards, and the arena metaphor.

### Make model download the primary reminder action
- **Pros**: increases model-install visibility and the chance of personalized
  judgment.
- **Cons**: implies installation is required and devalues the complete fallback
  path.
- **Why rejected**: the game must remain immediately playable and finishable
  without a model.

## References

- `CONTEXT.md` — canonical game vocabulary.
- ADR-0006 — independent food choices and the explicit defense-draw beat.
- `.scratch/taiwan-food-religion-war/spec.md` — authoritative product behavior
  and acceptance decisions.
