# Balance Simulation Report — 100,800 AI games

**Run date:** 2026-08-14 · **Sample:** 100,800 completed games · **Stalls:** 0

Two independent 50,400-game samples, one per AI heuristic variant (`v1` = shipped
behaviour, `v2` = improved, see *AI heuristics* below). Every ordered deck
pairing got exactly the same number of games (100 pairings × 504 each per
variant), so every cell of the matchup matrix is equally sampled and the seating
question can be read directly off it.

**The two variants agree to within ~1 point on every conclusion below.** That is
the single most important validity check in this report: the findings are
properties of the game, not artifacts of one heuristic set.

Reproduce with:

```
godot --headless --path . --script res://scripts/core/BalanceSim.gd -- \
    games=6300 out=logs/sim/main/v2_s0.csv seed=200 ai=v2
python tools/analyze_sim.py "logs/sim/main/*.csv"
```

---

## Headline numbers

| Metric | Value |
|---|---|
| Mean game length | **8.06 rounds** (median 8, p90 12) |
| Games reaching round 12 | **10.5%** |
| Games reaching round 14 | **2.5%** |
| Stall rate | **0 in 100,800** |
| P1 win rate | **55.8%** |
| Tower fire share of all damage | **52.6%** |
| Attacks costing 1–3 energy | **93.9% of all attacks queued** |
| Observed damage per energy | **~9**, against a documented anchor of 12 |

---

## 1. Damage balance

### The anchor and the cards disagree

`CLAUDE.md` states `≈ 12 damage per energy`. The printed cards average **~9**.

| Printed cost | Cards | Mean damage | Damage/energy |
|---|---|---|---|
| 1 | 8 | 10.0 | **10.0** |
| 2 | 15 | 17.5 | **8.7** |
| 3 | 10 | 27.1 | **9.0** |
| 4 | 3 | 32.3 | **8.1** |
| 5 | 7 | 49.7 | **9.9** |
| 6 | 4 | 60.5 | **10.1** |
| 7 | 1 | 40.0 | 5.7 |
| 9 | 1 | 45.0 | 5.0 |
| 14 | 1 | 40.0 | 2.9 |

The 7/9/14 entries are single conditional or utility cards, not a curve. The real
working curve is **8.1–10.1 across costs 1–6**, which is remarkably tight — the
cards are internally consistent with each other and inconsistent with the doc.

**This matters because the HP curve was raised on 2026-08-08 and the damage
anchors deliberately were not.** The docs flag this as an open question. The data
answers it: the effective rate is not merely below 12, it is below the rate the
old HP curve was priced against too.

### What it costs to kill a body

At the observed ~9/energy:

| Body | HP | Energy to kill @9 | @12 (documented) |
|---|---|---|---|
| Basic (median) | 50 | **5.6** | 4.2 |
| Basic (max) | 90 | **10.0** | 7.5 |
| Stage 1 (median) | 95 | **10.6** | 7.9 |
| Stage 2 (median) | 145 | **16.1** | 12.1 |
| Stage 2 (max) | 175 | **19.4** | 14.6 |

The doc's reference breakpoint — *4 energy exactly kills a fresh Basic* — is
dead. At 9/energy, 4 energy deals ~33 against a 50 HP median Basic.

**Recommended range: 10–12 damage per energy for standard attacks.** Either raise
printed damage ~20% to meet the documented anchor, or lower the anchor to 9–10 to
match the cards. The first is the better fix, because the second leaves Stage 2
bodies needing 16 energy to remove.

### Recommended damage-per-energy bands

| Attack class | Current effective | Recommended |
|---|---|---|
| Standard | ~9 | **11–12** |
| Judgment-carrying | ~8 (by design, ⅓ cut) | **8–9** |
| Consume | ~20 (per energy consumed) | **18–22** — no change needed |
| Gaia (aura pays the difference) | ~9 | **9–10** — no change needed |

---

## 2. HP balance

### The printed curve

| Stage | n | Min | Median | Max | Mean |
|---|---|---|---|---|---|
| Basic | 23 | 40 | 50 | 90 | 54.3 |
| Stage 1 | 19 | 80 | 95 | 120 | 97.6 |
| Stage 2 | 14 | 120 | 145 | 175 | 144.3 |

The bands are healthy and the documented overlap (90 HP Basic vs 80 HP Stage 1)
is real and working as intended.

### But the top of the curve barely plays

Of every unit body that reached the discard across 4,000 sampled games:

| Stage | Share of unit deaths |
|---|---|
| Basic | **84.7%** |
| Stage 1 | 13.9% |
| Stage 2 | **1.4%** |

**Stage 2 bodies are 1.4% of what dies, because they are 1.4% of what ever
reaches the board.** An 8-round game does not have time to assemble a three-stage
evolution line and charge it. The Stage 2 HP band (120–175) is therefore tuned
almost entirely on paper — it is real content that the current game length does
not reach.

This interacts with the damage finding: raising damage-per-energy toward 12 makes
Stage 2 bodies *more* killable, which is fine, because at present they mostly are
not on the board to be killed at all.

**Recommended HP ranges — keep, with one adjustment:**

| Stage | Current | Recommended |
|---|---|---|
| Basic | 40–90 | **40–90** — no change, the workhorse band and correctly sized |
| Stage 1 | 80–120 | **80–120** — no change |
| Stage 2 | 120–175 | **110–160** — trim the top, since the ceiling is unreachable content |

The Stage 2 trim is a low-confidence recommendation. The better fix is
**lengthening the game** so Stage 2 is reached; see §4.

---

## 3. Energy cost balance

### The pool is not the constraint — the clock is

| Metric | v1 | v2 |
|---|---|---|
| Mean pool held per player-round | 0.99 | 2.75 |
| Mean attached energy | 6.46 | 4.46 |
| Unit-turns with a queued attack | 68.2% | **70.5%** |
| Unit-turns without | 31.8% | 29.5% |
| Rounds with pool ≥4 and nothing queued | 1.66/game | 1.98/game |

Idle energy occurs in only **11.3% of player-rounds**, so energy is *broadly*
being spent. The problem is at the top of the cost curve.

### Attack cost usage — the key table

Sampled over 6,000 games (v2), 126,187 queued attacks:

| Cost | Times queued | Share | Games where it fired at all | Avg round |
|---|---|---|---|---|
| 1 | 52,372 | **41.5%** | 95.8% | 4.1 |
| 2 | 50,933 | **40.4%** | 96.8% | 4.1 |
| 3 | 15,207 | **12.1%** | 61.9% | 4.7 |
| 4 | 1,877 | 1.5% | 10.4% | 5.4 |
| 5 | 2,604 | 2.1% | 16.3% | 5.6 |
| 6 | 1,223 | 1.0% | 14.1% | 5.5 |
| 7 | 1,782 | 1.4% | 11.2% | 6.0 |
| 8 | 50 | 0.04% | **0.5%** | 6.3 |
| 9 | 58 | 0.05% | **0.5%** | 5.9 |
| 14 | 39 | 0.03% | **0.4%** | 7.1 |
| 20 | 42 | 0.03% | **0.7%** | 8.5 |

**93.9% of all attacks cost 1–3.** Costs 8+ fire in under 1% of games.

### Why: the income curve outlives the game

Theoretical income under the documented rules (one energy card per turn worth
`t+1`, pool decaying 20% floored):

| Round | Income | Pool after decay | Cumulative |
|---|---|---|---|
| 4 | 5 | 9 | 14 |
| 6 | 7 | 16 | 27 |
| 8 | 9 | 24 | 44 |
| 10 | 11 | 32 | 65 |
| 12 | 13 | 40 | 90 |

A hoarding player can afford a 14-cost attack around round 8–9 and a 20-cost
around round 11–12. But **only 10.5% of games reach round 12, and 2.5% reach
round 14.**

The expensive attacks are not mispriced against the *economy*. They are priced
for a game that ends before they arrive. `Cacophony Ramp` — the deck built
entirely around reaching a 14-cost attack — has a **34.2% win rate**, second
worst in the collection, for exactly this reason.

**Recommended cost ranges:**

| Tier | Recommendation |
|---|---|
| **1–3** | The real game. Keep, and keep most of the card pool here. |
| **4–6** | Reachable but uncommon (10–16% of games). Healthy as an aspirational tier. |
| **7–9** | **Currently near-dead.** Only justifiable on a card that wins on resolution. |
| **10+** | **Dead content at current game length.** Either cut, or fix the clock (§4). |

Do not solve this by making expensive attacks cheaper — that collapses the whole
curve into 1–3. Solve it by lengthening the game.

---

## 4. The clock — the root cause behind most of the above

### Tower fire is the majority of all damage in the game

| Source | Damage per game (both players) |
|---|---|
| **Tower fire** | **408.7** |
| All card damage | 368.4 |
| — to units | 216.7 (58.8%) |
| — to towers | 81.4 (22.1%) |
| — to throne | 70.3 (19.1%) |

**Towers deal 52.6% of all damage dealt in the game.** Every card in the game,
across both players, contributes less than the two structures that need no
deckbuilding, no energy, and no decisions.

The loser's throne averages 135.3 max HP at game end, and 100% of games end by
throne kill. With cards routing only ~70 damage per game to thrones, the tower's
half-rate structure chip is doing the closing work.

This is the mechanism behind:
- **8-round games** — the docs note the 2026-08-09 rework left games at ~8 rounds
  and asks whether that is too short. It is, and this is why.
- **Dead high-cost attacks** — the game ends before the income curve arrives.
- **Stage 2 never reaching the board** — no time to build the line.
- **`Cacophony Ramp` at 34%** — the ramp deck cannot outrun the clock.

### Recommended dials, cheapest first

1. **Reduce the structure chip rate from ½ back toward ¼–⅓.** This is the single
   number most responsible for the short clock, it touches no card, and the docs
   already record that it was raised from ¼ as part of a three-number set. The
   raise appears to have overshot.
2. **Flatten the tower damage curve below `+3`/round**, or cap it after round ~10.
3. **Raise damage per energy to 11–12** (§1) so cards close games instead of
   towers. This is the fix that makes the card game the game.

Expect all three to lengthen games. Target: **median 11–14 rounds**, which puts
cost 4–6 in reach every game and cost 7–9 in reach sometimes.

---

## 5. Deck balance

Seat-controlled (both seats pooled), 20,160 games per deck:

| Deck | Win rate | Faction |
|---|---|---|
| **Toll Engine** | **81.7%** | Hel |
| Deep Grove | 68.5% | Gaia |
| Standing Stones | 64.5% | Gaia |
| Widening Rift | 47.0% | Void |
| Starve | 46.7% | Void |
| Barrow Wall | 45.4% | Hel |
| Rise & Recur | 42.3% | Hel |
| Verdict Engine | 41.0% | Heaven |
| Cacophony Ramp | 34.2% | Hel |
| **Lamp Wall** | **28.8%** | Heaven |

**Toll Engine's dominance is confirmed and worse than the docs record.** It beats
every deck in the collection, going 92–98% against four of them and 73–75%
against the two Gaia decks. The docs cite 9-0 and 8-1 sample results; at 20,160
games the effect is unambiguous.

The spread is **81.7% to 28.8% — a 53-point range**, far outside what a balanced
collection should show.

Both Gaia decks are strong (68.5%, 64.5%); both Heaven decks are weak (41.0%,
28.8%). The docs already note Heaven cannot be read from AI play because the AI
has no Judgment or Sanctuary heuristics — **that caveat still applies and Heaven's
numbers here should be treated as a floor, not a verdict.** Gaia and Hel have no
such caveat.

### Toll Engine — why

`Charnel Colossus` deals 109.9 damage per game it appears in, third-highest in
the game and on a **Basic** body (90 HP, the band maximum). Toll Engine plays
cheap bodies that pay energy back on death, in a game that lasts 8 rounds and
rewards exactly that. It never needs the expensive attacks that never arrive.

**Toll Engine is the deck best adapted to the broken clock.** Fixing §4 will
reduce its edge without touching a card. Re-measure before nerfing anything.

---

## 6. Seating

**P1 wins 55.8%** across 100,800 games (55.6% v1, 56.1% v2).

This **contradicts the open question in `CLAUDE.md`**, which records the second
player winning 7 of 8 early random matchups and asks for a 30-run sample. At
100,800 games the advantage is P1's, by 5.8 points, and it is consistent across
both heuristic variants and every deck:

| | P1 win% | P2 win% |
|---|---|---|
| Toll Engine | 85% | 77% |
| Deep Grove | 77% | 61% |
| Lamp Wall | 32% | 26% |

Every deck does better in seat 1. The original 8-run observation was noise.

5.8 points is a real but not alarming first-player advantage — comparable to
many card games. The 2026-08-09 setup phase and round-1 tower silence appear to
have worked; they may have slightly overcorrected.

**Recommendation: no action, but close the open question.** Re-measure after the
clock changes in §4, since a longer game dilutes opening advantage.

---

## AI heuristics

`AIPlayer` now carries two heuristic generations, selected by `set_variant()`.
`v1` is the shipped behaviour preserved byte-for-byte; `v2` adds:

**1. Energy banking (`_bank_leftover_energy_v2`).** v1 dumped the entire pool
onto the single highest-HP body every turn. That is not a neutral simplification
for measurement — it empties the pool at every decision point so no expensive
attack is ever reachable, it strands energy on bodies with nothing to spend it
on, and for Void it maximises the Gap by accident (a distortion the docs already
record as having caused a bad tuning decision). v2 charges toward the cheapest
*unfunded* attack first, keeps a 4-energy float (below the floor where 20% decay
takes the same 1 energy regardless), then banks the taxable surplus on the body
with room left before its own biggest attack.

**2. Focus fire (`_focus_target`).** v1 never used chosen targeting at all — 0%
of attacks named a target. v2 tracks projected damage per enemy unit across the
volley so attacks converge on one body instead of each independently picking the
healthiest, and stops naming targets once a board is projected clear so the
attack falls through to the tower.

### Result: v2 is a wash, and that is informative

| Measure | Result |
|---|---|
| v2 as P1 vs v1 as P2 | 55.9% |
| v2 as P2 vs v1 as P1 | 44.0% |
| **Seat-controlled** | **49.95%** — statistically identical |

Focus fire fires on 26.8% of attacks yet produces the same kills (1,713 vs 1,699)
and slightly *fewer* board clears. The reason is structural: with ~2 units per
board on average and attacks that either one-shot a Basic or fall far short, the
default slot-across target is usually already correct. **Concentration has little
room to help when boards are this thin** — which is itself a finding about the
game, not about the AI.

v2 is nonetheless the better instrument (it holds a real pool, 2.75 vs 0.99, so
expensive attacks are genuinely reachable rather than structurally excluded), and
both samples are reported so no conclusion rests on the change.

### Known gap: volley ordering is documented but not implemented

`CLAUDE.md` specifies player-chosen volley ordering at length, including that it
is *"the feature that makes `Judgment` play the way the keyword reads."*
`GameState._resolve_attacks` resolves attacks in a fixed board-by-board,
left-to-right scan with no ordering hook. Neither a player nor the AI can reorder
a volley.

This is a rules-vs-code gap, not a bug I introduced, and it is likely part of why
Heaven underperforms — Judgment wants to swing *after* something has softened the
target, and currently that is still an accident of slot placement.

---

## Files

| Path | What |
|---|---|
| `scripts/core/BalanceSim.gd` | Mass sampler → CSV. Asserts nothing, never fails. |
| `scripts/core/CostProbe.gd` | Per-attack-cost usage and stage-death sampler |
| `tools/analyze_sim.py` | Aggregates CSV shards into the tables above |
| `logs/sim/` | Output, gitignored (16MB, regenerable) |

All eight assertion harnesses pass unchanged after the AI work: RulesTest 126,
SupportTest 158, HeavenTest 61, VoidTest 61, GaiaTest 146, DeckStoreTest 70,
DragDropTest 27, TutorialTest 119.

---

## Open questions this answers

- **"The second player won 7 of 8 random matchups."** — Resolved. P1 wins 55.8%
  over 100,800 games. The 8-run result was noise.
- **"Is ~8 rounds too short?"** — Yes. It is short enough that 94% of attacks
  cost 1–3, Stage 2 is 1.4% of unit deaths, and towers out-damage every card.
- **"Should the damage anchors rise with the HP curve?"** — Yes. Printed cards
  deliver ~9/energy against a documented 12, and the gap widened when HP rose.
- **"Does the throne outgrow available damage?"** — No longer. 0 stalls in
  100,800 games. The per-round growth fix resolved it; the worry can be retired.
- **"Toll Engine is beating everything."** — Confirmed at 81.7% over 20,160
  games. Likely a symptom of the short clock rather than the cards.
