# ADR-0006: Food Stance Selection and Defense Draw

- **Status**: Accepted
- **Date**: 2026-08-06
- **Deciders**: Product owner

## Context

The original game used two semifinals and a final. One semifinal compared
northern and southern zongzi, while the other compared extra and no cilantro.
Their winners then met in a final even though zongzi style and cilantro
preference are unrelated dimensions. Calling the result an ultimate champion
made the player's choices easy to operate but semantically incoherent.

The game should remain short, replayable, recognizably Taiwanese, and end in a
single defense judged by an installed on-device model or a disclosed fallback.

## Decision

The game uses six fixed pairs of comparable Taiwanese food stances. Each game
selects four distinct pairs in random order. The player immediately locks one
stance in each choice round, producing a four-item belief slate. After all four
rounds, the game shows the complete belief slate and waits for the player to
trigger the defense draw. The draw then selects one stance from that slate with
no reroll. This explicit pre-defense beat is required even though it adds one
tap. The player answers the drawn stance's fixed, fair opposing challenge in at
most 50 characters, and the selected local model or fallback service returns
the judgment.

The approved first stance pool is:

1. 北部粽派 / 南部粽派
2. 香菜加爆派 / 香菜退散派
3. 豆花配糖水 / 豆花配豆漿
4. 火鍋沾沙茶 / 火鍋原湯派
5. 珍奶全糖 / 珍奶微糖
6. 薯條加鹽 / 原味不加鹽

Within one app run, the defense draw avoids selecting the same stance in two
consecutive games when another drawn candidate is available. The result keeps
the drawn stance primary and shows the complete belief slate as secondary
context. It does not calculate an overall score or personality type.
Player-facing result copy uses `本次抽中；四個選擇都會保留。`; it does not use
a prohibited ranking term even to negate that interpretation.

## Consequences

### Positive
- Every choice compares stances from the same food topic.
- Four independent choices contribute visibly to the game even though only one
  becomes the defense challenge.
- Random subsets, ordering, and defense draws improve replay variety.
- Additional stance pairs can extend the pool without changing the game flow.

### Negative
- The game needs eight additional character assets and sixteen additional
  stance-specific content strings for labels and opposing challenges.
- Random selection requires deterministic seams for automated tests.
- The explicit draw beat adds one tap before the defense.
- The old semifinal, final, champion, and tournament progress implementation
  must be replaced rather than cosmetically relabeled.

### Neutral
- `VS` remains valid within a choice round but no bracket connects rounds.
- The title “台灣食物宗教戰爭” remains; its subtitle and progress language
  change to describe four choices and a defense draw.

## Alternatives Considered

### Keep the cross-topic tournament
- **Pros**: already implemented; strong conventional game progression.
- **Cons**: unrelated preferences eliminate one another and produce a
  misleading champion.
- **Why rejected**: the bracket does not model the meaning of the choices.

### Run a single-topic multi-contender tournament
- **Pros**: a champion inside one topic would be coherent.
- **Cons**: longer sessions, uneven brackets, and a much larger set of similar
  assets; it loses the variety of Taiwanese food debates.
- **Why rejected**: the desired experience is a quick slate of independent
  preferences followed by one random defense.

### Let the player choose the defense stance or reroll
- **Pros**: more player control and less chance of receiving a difficult topic.
- **Cons**: weakens the surprise and lets players optimize for the easiest
  defense instead of accepting the game challenge.
- **Why rejected**: every drawn stance was already chosen by the player, so a
  no-reroll random draw remains fair.

### Draw automatically after the fourth choice
- **Pros**: one fewer tap and a faster transition to the defense.
- **Cons**: weakens the causal link between the complete belief slate, its four
  eligible candidates, and the one drawn stance.
- **Why rejected**: the explicit slate → draw action → reveal sequence makes
  the revised mechanic understandable and preserves every choice's importance.

## References

- `CONTEXT.md` — domain glossary for the game.
- `.scratch/taiwan-food-religion-war/spec.md` — approved product decisions.
- `lib/features/food_religion_war/domain/food_religion_game_session.dart` —
  current game state implementation to be superseded.
