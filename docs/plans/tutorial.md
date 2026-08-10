# Plan — The Tutorial

**Goal.** A new player can learn every mechanic in Godsfall without reading the design
docs. Reachable from the main menu, split into chapters, and covering the whole rule set:
the economy, board geometry, targeting, combat resolution, retreat, evolution, supports,
every shared and faction keyword, and deckbuilding.

**Status:** written 2026-08-09, before any code.

---

## Shape

Two halves, and the split is the point:

| Half | Teaches | Form |
|---|---|---|
| **Lessons** | The ~30 mechanics you *do* | Scripted interactive battles, gated step by step |
| **Compendium** | The exhaustive rules text | Browsable reference pages, no game running |

A lesson teaches by making you perform the action; the compendium is what you consult
afterwards. Lessons deep-link into compendium pages so "read more" never dead-ends.

**Why both.** A scripted battle is the only thing that teaches *pool vs. attached* — the
stated skill gap — because the decision only exists when energy is actually scarce. But a
battle cannot cover 15 keywords without becoming an hour long, and a player looking up
`Sanctuary N` six weeks later wants a page, not a replay. Each half does what the other
does badly.

## Chapters

Lessons are **independently selectable and independently completable**. No lesson depends
on state from another — each builds its own `GameState` from its own fixed deck. A player
who only wants the Void lesson can take it.

| # | Lesson | Teaches |
|---|---|---|
| 1 | **First Blood** | Board layout, setup deployment, deploy, end turn, the draw |
| 2 | **Energy** | Energy cards scaling `t+1`, the pool, decay, charging, attaching |
| 3 | **Attacking** | Queueing, cost pulled from pool, attacks resolve at end of turn, free forever after |
| 4 | **The Wall** | Shielding, per-board independence, the fallback chain, clearing a board |
| 5 | **Aim** | Chosen targets, volley ordering, no-overkill, sequencing kills |
| 6 | **Towers** | Tower fire, round-1 silence, the +3 curve, half-rate structure chip, the throne |
| 7 | **Growing** | Evolution, carrying energy forward, the two-line rule, abilities vs. attacks, `Consume` |
| 8 | **Pulling Out** | Retreat, paying from attached, the hand lock, the whole evolution path |
| 9 | **Support** | Supports, priced supports, Tools, tower support, the hand limit |
| 10 | **Death is a Resource** | Hel — `Toll`, `Decay`, `Rise`, `Retribution` |
| 11 | **Judgment & Sanctuary** | Heaven — both halves of Judgment, the Sanctuary pool, resolution order |
| 12 | **Denial** | Void — `Siphon`, `Void N`, the Gap, `Rift N` |
| 13 | **Growth** | Gaia — the `Earth` aura, `Essence`, `Resist` |
| 14 | **Building a Deck** | 60 cards, 4 copies, energy exempt, the energy ratio, evolution lines |

Chapter 14 is the one lesson that is **not** a battle — it opens the deck builder with
coaching over it, because deckbuilding is not something you can do on a battlefield.

## How a lesson runs

A lesson is a **list of steps**. Each step is data, not code:

```
{
  "text":     "Move 2 energy onto Barrow Hound. Click the unit, then Charge.",
  "advance":  "charge",              # what completes the step
  "highlight": {"kind": "unit", "board": 0, "slot": 0},
  "allow":    ["charge", "select"],  # everything else is inert
  "setup":    Callable,              # optional: force board state before the step
  "read_more": "energy"              # optional compendium page id
}
```

**Advance conditions are checked against the real `GameState`**, not simulated. The
tutorial subscribes to `state_changed` and re-evaluates its predicate. That is what makes
the lesson honest: it advances because the rules engine agrees the thing happened.

### The three mechanisms

1. **Gating.** A step names which actions are legal. `Combat` asks the tutorial before
   acting, and refuses anything not allowed, with a nudge rather than silence.
2. **Highlighting.** A step names a widget — a slot, a hand card, a button — and `Combat`
   draws an accent ring around it. Purely visual.
3. **Scripting.** A step may force board state via a `setup` callable, so a lesson about
   `Sanctuary` can put a Sanctuary body on the board without a player having to draw one.

### The opponent

Lessons use a **scripted opponent, not `AIPlayer`**. The AI is a heuristic that plays
differently every run, and a lesson whose lethal setup depends on the enemy having two
units cannot tolerate that. The scripted opponent takes a per-step declared action or
does nothing. `AIPlayer` stays untouched.

## Decisions

- **Lessons build their own decks, not sample decks.** A sample deck is 60 cards tuned for
  play; a lesson wants a deck that draws exactly what the next step needs. Lesson decks are
  fixed lists defined in `TutorialData.gd`, stacked in order, and **not shuffled** —
  reproducibility is the whole requirement.
- **`DeckStore` is never touched.** A lesson passes its card list straight to
  `GameState.new()`. This is the data-loss rule the decision log already carries twice: the
  tutorial must not be able to write the player's collection. Chapter 14 opens the deck
  builder on a **scratch deck** it creates and deletes.
- **Progress is stored, and stored separately from decks.** `user://tutorial.json`, holding
  only a set of completed lesson ids. Its own file so a corrupt tutorial state can never
  take the deck collection with it.
- **Every step is skippable and every lesson is replayable.** A tutorial that traps you is
  worse than no tutorial. `Skip step` advances without performing; `Skip lesson` exits.
- **The coach panel replaces the battle log, it does not overlay the board.** `Combat`'s
  right column already holds the action panel and log. During a lesson the log is
  demoted and the coach takes the top of that column. Nothing covers the battlefield —
  a tutorial that hides the thing it is teaching about is self-defeating.
- **The compendium reuses `CardView`.** Same reasoning as `CardInspector`: a second card
  renderer drifts. Keyword pages show a real card that carries the keyword.
- **No new rules.** The tutorial teaches the rules in `CLAUDE.md` and adds none. If a lesson
  cannot be built without an engine change, the lesson is wrong, not the engine.

## Files

| File | Role |
|---|---|
| `scripts/core/TutorialData.gd` | All lesson + compendium content. Data only, no UI. |
| `scripts/core/TutorialState.gd` | Autoload. Active lesson, current step, progress save. |
| `scripts/ui/Tutorial.gd` + `scenes/Tutorial.tscn` | Lesson select screen |
| `scripts/ui/Compendium.gd` + `scenes/Compendium.tscn` | Browsable reference |
| `scripts/ui/Combat.gd` | Gating, highlight, coach panel — additive, guarded by `TutorialState.active` |
| `scripts/ui/MainMenu.gd` | The button |
| `scripts/core/TutorialTest.gd` | Harness, with `EXPECTED_ASSERTIONS` |

## Risks

- **`Combat.gd` is 1658 lines and the tutorial touches its input paths.** Mitigation: every
  hook is a single guarded call that returns "allowed" when no lesson is active, so the
  normal game path is unchanged by construction.
- **Content drift.** The compendium restates rules that live in `CLAUDE.md`. Nothing keeps
  them in sync automatically. Mitigation: the harness asserts that every keyword in
  `Palette.KEYWORD_COLORS` has a compendium page, so a new keyword fails the suite until
  it is documented.
- **Step predicates that can never fire** would soft-lock a lesson. Mitigation: every step
  is skippable, and the harness drives all 14 lessons start to finish.
