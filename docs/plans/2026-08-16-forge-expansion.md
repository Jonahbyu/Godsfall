# Forge Expansion — to full faction parity

> Forge shipped at 19 cards against 59–66 for the other four colours. This brings it
> to ~60, and the constraint Jonah set is that **each card line takes a unique stab at
> a different part of how the faction operates** — not more bodies printing
> `stoked_bonus_damage`.

**Decisions taken up front:** full parity (~60 cards), and **no `Windfury`** — the
multi-attack identity stays a *conditional* Stoke payoff (`stoked_extra_attack`),
which forge.md already prefers on the grounds that it sidesteps the Judgment
constraint by sitting on a Forge body.

---

## The problem this has to solve

Forge's 13 units read as five chains but only three *ideas*: stoke-then-hit-harder,
scrap-a-body, heal-the-stoke-back. Nine of the eleven payoffs forge.md catalogues are
**designed and unimplemented**, so any new chain built on today's ops is forced to
re-use a bonus-damage rider and the faction gets wider without getting deeper.

So the expansion is engine-first: build the catalogued payoffs, then author chains
that each own one.

## Phase 1 — engine: the missing payoff ops

Nine new ops, each straight out of forge.md's catalogue. Every one is gated on
`u.has_stoked()` and honours `stoked_threshold` where present, matching the existing nine.

| Op | Class | What it does |
|---|---|---|
| `stoked_extra_attack` | Tempo | Unit may queue a second attack this turn. The conditional-Windfury slot. |
| `stoked_immediate` | Tempo | Attack resolves at queue time, not end of turn. Breaks turn structure. |
| `stoked_cost_reduction` | Economy | This unit's attacks cost N less this turn. |
| `stoked_no_decay` | Economy | Pool does not decay at end of this turn. Rule-break on the central tax. |
| `stoked_sweep` | Geometry | Attack hits every living unit on the target board. |
| `stoked_both_boards` | Geometry | Attack hits both enemy boards. Stage 2 + threshold only. |
| `stoked_also_tower` | Geometry | Splashes N to the tower behind the target without bypassing the shield. |
| `stoked_unpreventable` | Damage shape | Ignores `Sanctuary` and `Resist`. The printed answer to shield decks. |
| `stoked_draw` | Self-referential | Draw N. Forge burns hand fast. |
| `stoked_twice` | Self-referential | Unit may Stoke a second time this turn. Doubles every scaling payoff. |

`stoked_twice` and `stoked_extra_attack` are the two that need state on `Unit`
(`stoke_uses_allowed`, `extra_attack_allowed`), cleared with the flag each turn.

**Ramp payoffs stay excluded.** forge.md names *"attach N energy"* as the one class
that breaks pacing, and the generator already refuses it. Unchanged.

## Phase 2 — the new chains

Eight new chains (~26 units), each owning one mechanic above, plus wave-2-style
bodies at three power levels the way the bestiary waves were pitched.

| Chain | Owns | Shape |
|---|---|---|
| **Bellow** | `stoked_extra_attack` | Multi-attack — the Windfury slot, as a condition |
| **Char** | `stoked_sweep` | The sweeper; pairs with no-overkill to strip a board |
| **Scoria** | `stoked_unpreventable` | The anti-shield body. Forge/Heaven's printed reason to exist |
| **Flux** | `stoked_cost_reduction` / `stoked_no_decay` | The economy chain — Forge touching the energy rules |
| **Tind** | `stoked_twice` / `stoked_draw` | The engine chain; double-stoke into scaling payoffs |
| **Drossal** | `Scrap` + `Consume` | The second scrapper; Consume printed steepest |
| **Anneal** | `Retribution` + Stoke | The wall that punishes being hit while it burns |
| **Ingot** | `stoked_immediate` / `stoked_both_boards` | The closer chain: geometry breaks at Stage 2 |

Plus vanillas and staples so the roster has a floor, per the bestiary rule: **a
keyword-less Basic must evolve into one that carries something.**

## Phase 3 — supports

~8 more faction-locked supports and 2 Tools. forge.md's rule 4 is the binding one and
is enforced in the generator: **a Forge support may not sell damage more efficiently
than an attack, in any currency.** These buy reach, sustain, tempo and card flow.

At least one must supply the **printed** Forge/Heaven and Forge/Gaia reason to exist,
since making Stoke unpreventable cost those pairings their free synergy — forge.md
lists that as an open question worth answering with a card.

## Phase 4 — five sample decks

Five new decks, each anchored on one of the new chains' Stage 2 so it reads as a plan
rather than a pile of orange cards. Checked at design time for stranded evolutions —
`errors_at()` does not catch a deck full of unplayable Stage 1s.

## Phase 5 — verification

- Extend `ForgeTest.gd` with assertions per new op, **driven through the real damage
  pipeline** (`_deal_lane_damage`), never simulated inline.
- Every new op verified by putting the bug back — an op that silently does nothing
  passes every structural assertion, which is the failure shape this log already
  carries three times.
- `EXPECTED_ASSERTIONS` updated deliberately.
- Art for every new card; census counts in other harnesses updated.
- Full sixteen-harness run.
