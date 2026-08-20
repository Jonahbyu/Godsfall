# Wilds — Faction Design

**Status:** designed, not built. No cards authored, no engine work done.
**Date:** 2026-08-19
**Sentence:** *the beast that keeps getting back up, and the one that gets worse the
longer you let it stand over the bodies.*

---

## Why Wilds Exists

Wilds is the last of the two remaining reserve candidates (`wyrd`, `wilds`), chosen over
Wyrd because randomness-as-identity cuts against the game's whole design language —
spend-or-save, pool-vs-attached, chosen targeting, volley ordering are all about legible
decisions over visible state, and a coin-flip faction fights that on every card.

Its stated identity in `CLAUDE.md` is **"flesh, beasts, raw physicality... nature as a
threat, not a garden"** — explicitly not Gaia. That distinction had to be earned twice
during this design, not just claimed once: the first version of each signature keyword
independently drifted into territory an existing faction already owns, and both were
corrected before landing here (see *Precedent Checks* below).

---

## What Wilds Does That No Other Faction Can

Every built faction so far twists the **energy economy** — Hel recycles it, Void steals
it, Gaia grows an aura off it, Heaven gates it behind reprieves, Forge spends HP/bodies
instead of it, Tempest banks it over time. Wilds does not touch energy at all. It twists
**bodies themselves** — HP, death, and the board of corpses a fight leaves behind.

| Faction | Reads | Wilds reads instead |
|---|---|---|
| Gaia `Earth` | Attached energy, live | **Friendly deaths**, permanent |
| Tempest `Charge` | This unit's own combat | **Other units'** deaths, on this board |
| Forge `Stoke` | A per-turn flag, self-inflicted | A full-return, self-triggered by dying |
| Heaven `Rise` (shared) | — | The keyword this faction's first signature inverts |

In the `forge.md` currency format:

| Faction | Pays with | Gets back |
|---|---|---|
| Hel | Bodies dying | Energy (`Toll`) — death is *income* |
| Heaven | Discrete charges | Time — a death postponed |
| Void | Fragility | The opponent's energy |
| Gaia | Surviving bodies | A live board-wide aura |
| Forge | HP, attached energy, own units | Immediate damage, at once |
| Tempest | Time, and the risk the body dies holding it | An oversized effect at a moment you choose |
| **Wilds** | **A body's own smaller stat line** | **A full second life, and permanent rage from every corpse nearby** |

---

## Keywords

Wilds claims **two signatures**, matching every other faction's allowance.

| Keyword | Effect |
|---|---|
| **Molt** | *(Wilds signature)* When this unit would die, it is instead replaced — immediately, in the same slot — by an exact copy of itself at full HP, with all attached energy retained. **The copy loses Molt.** Evolving a unit that has lost Molt restores it. |
| **Ferocity N** | *(Wilds signature)* This unit tracks a stack counter, starting at 0. **Whenever a friendly unit on this unit's own board dies, it gains N stacks.** Each stack held grants **+2 max HP and +1 damage on every attack**, for as long as the stacks are held. **Stacks are lost when this unit dies** — unless the death is answered by its own `Molt`, in which case the copy keeps them. |

### Molt — the reprieve, inverted

Every other "comes back from death" behavior in the game routes through the shared
`Rise` keyword: return next turn, to an empty slot, at **half HP**, keyword **stripped**,
attached energy **already lost** to the normal death rule. Molt is not a variant of that
— it inverts every axis at once:

| | `Rise` (shared) | `Molt` (Wilds) |
|---|---|---|
| Timing | Start of your **next** turn | **Immediately**, same resolution |
| Slot | Must be **empty** | **Same slot** it died in |
| HP | **Half** | **Full** |
| Attached energy | Lost (normal death rule fired first) | **Fully retained** |
| Keyword after return | **Kept** on the copy (all *other* keywords) | **Lost** — Molt itself is spent |
| Restored by | Nothing — it is what it is | **Evolution** |

Full energy retention is the loud part. `CLAUDE.md` states plainly that *"attached energy
is lost when the unit dies"* — that rule is the entire reason pool-vs-attached is a
tension at all. Molt is a printed, deliberate exception to it, in the same spirit Forge's
`stoked_unpreventable` is a printed exception to Sanctuary/Resist: absolute, not partial,
and it earns the right to be absolute by being **rare and one-shot** rather than a
faction-wide free pass.

**The loop terminates because the keyword is spent, not because the body degrades.**
Rise's brake is that the *returned unit is worse* (half HP, no Rise) so repeated deaths
converge toward nothing. Molt's brake is different: the returned unit is **exactly as
strong**, but it cannot do this again until something restores the keyword — and the
only restoration is evolving. A Basic that Molts every death it can afford is eventually
just a normal Basic, until you evolve it, at which point the whole cycle is live again on
a bigger body. This is also what makes evolving mechanically necessary for a Molt line
rather than optional, the same way Tempest's evolution-carries-Charge rule made evolving
necessary there.

### Precedent check #1 — where the first draft of Molt would have collided

The open question at the start of this brainstorm was whether a body-pool resource could
earn its own colour slot rather than reading as a reskin of Tempest's `Charge` (per-unit,
persistent counter) or Forge's `Stoke` (per-unit, per-turn flag). Molt clears that bar
because it is **neither a counter nor a flag** — it is a one-shot state that, when it
fires, produces a full replacement of the unit rather than modifying a stat on it. Nothing
else in the game does that.

### Ferocity N — the payoff for a board that is dying

**Ferocity is per-unit, not a shared aura.** This was the harder of the two precedent
checks. The first framing on the table — "gain a stack whenever any friendly unit dies" —
is structurally identical to how Gaia's `Earth` reads a shared quantity, just with a
different trigger. What makes Ferocity distinct is that it is **not a live-computed,
board-wide sum every unit reads equally** (Earth's shape) — it is a private counter that
one specific unit accumulates by watching deaths happen *near it*, and different Ferocity
units on the same board can hold wildly different totals depending on what died in front
of each of them.

**`N` is printed on the tracking card, not on the units that die.** `Ferocity 3` means
*this unit gains 3 stacks per friendly death on its board* — a single number, on a single
card, no second half of the keyword needed on ordinary units the way `Toll`'s refund value
is printed on the dying card itself. This was a real fork during design and the other
shape (N printed on the dying unit, read by every Ferocity-tracker nearby, Toll-style) was
considered and set aside for being one more moving part than the fantasy needs.

**Own board only, matching every other per-board rule in the game.** Shielding, `Essence`,
and targeting are all explicitly scoped to a single board and never cross — Ferocity
follows the same discipline rather than becoming the first board-crossing trigger.

**Additive, never a true multiplier**, despite the flavor language ("multiplier") in the
original pitch. Design principle #4 states outright that concentrated damage beating
spread damage on a 4-slot board is *"what makes linear damage formulas work"* — every
scaling mechanic that exists (`Earth`, `Rift`, `Storm`, `Charge`) is additive per point,
and Earth's own history is the cautionary tale: even *additive* Earth at an uncorrected
rate produced a mean aura of 14.6, peaking at 78, and put every Earth deck 20+ points
above the field average. A compounding multiplier would be strictly more dangerous than
the mechanic that already broke the balance sweep once. "Multiplier" survives only as card
flavor text for what is mechanically a flat per-stack bonus.

**Rate: +2 max HP / +1 damage per stack.** Set at roughly 2x Earth's post-nerf rate
(+1 HP / +0.5 damage per point), justified by scarcity rather than picked freely: a point
of Earth grows for free off attached energy every turn a unit is charged, while a Ferocity
stack costs an actual friendly unit's death — a real, board-visible loss, not a resource
reallocation. The richer rate is what makes that cost worth paying.

**Stacks are permanent while the unit lives, wiped by its own death, and are the one
thing Molt is defined to save.** This is the deliberate combo point of the two keywords:
a unit printing *both* Ferocity and Molt does not reset when it "dies" — the copy that
replaces it keeps every stack earned so far, on top of Molt's own full HP/energy
retention. Every other reset mechanism in the game (`Rise`, evolution, retreat) wipes
grown history by explicit rule (*"Rise restores the card, not the history"*); Molt is
built to be the specific, printed exception for a unit that both carries it and dies with
Ferocity stacks banked, because the fiction is that this unit never really died at all.

### Precedent check #2 — the rejected-permanence problem

Gaia's first draft of `Earth` added max HP and damage into the towers **every turn,
forever**, and was rejected specifically because *"it has no counterplay — damage already
banked cannot be undone."* Ferocity is also a permanent accrual, so it has to clear that
same bar. It does, on the same terms Tempest's `Charge` already cleared it: **the
counterplay is killing the body holding it.** A Ferocity stack is not banked into a
shared, undo-proof pool — it lives on one unit, and removing that unit removes the stacks
with it (unless Molt intervenes, which is itself a spendable, one-shot exception rather
than a second layer of permanence).

---

## Why They Are a Pair

| Faction | Generator | Spender |
|---|---|---|
| Hel | `Toll` (death into energy) | `Decay` (free chip that causes deaths) |
| Void | `Siphon` (take energy) | `Void N` (the sharper, rarer version) |
| Gaia | `Earth` (grows an aura) | `Essence` (saves it from the death that would end it) |
| Forge | `Stoke` (sets a state) | `Scrap` (the sharper, rarer version) |
| Tempest | `Charge` (banks a counter) | `Storm` (the shared weather that fills it) |
| **Wilds** | **`Ferocity`** (grows from a dying board) | **`Molt`** (the thing that refuses to let a death count) |

Unlike Tempest's loop (Storm feeds Charge, Charge spends into a board Storm makes bigger),
Wilds' pair is **defensive-into-offensive**: Molt is what keeps a Ferocity carrier alive
long enough to matter, and every death Molt *doesn't* prevent (on other units) is what
feeds the Ferocity carrier in the first place. A Wilds board wants some of its own units
to die — sacrifice-fodder token summoners are the natural low end of the faction, feeding
Ferocity stacks upward onto a body built to survive and cash them in.

This also gives the faction its own version of the sacrifice-engine shape Hel already
has (Toll-Decay), but inverted in what death produces: Hel converts death into **energy**;
Wilds converts death into a **stat, on a specific body, that only that body can lose.**

---

## Numbers

**Molt HP band: below the stage's normal range**, following the same house style as
Judgment (-1/3 damage rate) and Sanctuary (-18% damage) paying for their keyword in the
stat line rather than as a free addition. Since Molt already returns the unit at full
HP/energy — effectively a guaranteed second life — a smaller printed body keeps total
expected value in line with an ordinary card's.

| Stage | Normal HP band | Molt HP band (proposed) |
|---|---|---|
| Basic | 40–90 | **30–60** |
| Stage 1 | 80–120 | **60–95** |
| Stage 2 | 110–175 | **90–140** |

These are first-pass numbers, not yet checked against the live card pool's medians the way
Tempest's Charge table was. **Flagged as needing the same derivation pass** before any
card is authored.

**Ferocity N: printed values not yet derived.** A first instinct is N=1 on cheap
token-summoner Basics (they die often, so even 1 stack per death adds up) and N=2–3 on
scarcer, more deliberate sacrifice payoffs — but this needs to be checked against how many
friendly deaths a real game plausibly produces on one board (bounded by 2–3 slots per
board and a ~9.5-round mean game length) before it is pinned.

---

## Open Questions

- **Damage discount, unresolved.** Every faction pays for its signature keywords below the
  standard damage curve — Judgment -1/3, Sanctuary -18%, Gaia ~9/energy against the
  standard 12. Molt's cost is paid entirely in the HP band (see above), which may be
  sufficient on its own without an additional rate cut — a Molt unit's *damage* is
  otherwise ordinary, it just has a smaller body. Ferocity's cost is the steep one
  (a full friendly death per stack, far scarcer than Earth's near-free trigger), which
  argues against stacking a further discount on top of that scarcity. **Working default:
  no separate damage-rate discount for either keyword, cost paid in HP-band and
  stack-scarcity instead** — but this is exactly the kind of call the Tempest doc flagged
  as "must be settled before any card is authored" and then left open; it should not be
  left open again here. Needs explicit confirmation before card authoring starts.
- **What N should Ferocity print, by source card and by stage?** Not yet derived against
  the live card pool the way Tempest's Charge table was. See *Numbers* above.
- **Does a Molt+Ferocity unit need its own, higher HP-band carve-out?** The two keywords
  combo hard (immortal-feeling body that only gets angrier) — worth checking whether a
  card printing both should sit at the very bottom of even the Molt band, since it is
  strictly more powerful than either keyword alone.
- **Token summoners — not yet designed at all.** The pitch that started this ("big units
  that sacrifice summoning tokens that die") implies a sub-theme of cheap, disposable
  Basics whose whole job is dying in front of a Ferocity carrier. None of these are
  sketched: what they cost, how expendable they are, whether any of them print Molt
  themselves (a token that Molts is arguably a contradiction — it stops being disposable).
- **Interaction with `Rise`.** A unit cannot logically hold both `Rise` and `Molt` doing
  their stated jobs at once — both fire "when this unit would die." Needs an explicit
  precedence rule, or a decision that no card ever prints both.
- **Interaction with `Essence`.** Gaia's `Essence` moves a dying unit's Earth and attached
  energy to the nearest ally on death. If a Molt unit's death is intercepted before it
  "counts" as a death for Essence's purposes, that needs stating — likely Molt fires first
  and Essence simply never triggers, since the unit didn't end up in the discard.
- **Interaction with `Toll` / `Decay` / any other on-death trigger.** Same question as
  above, generalized: does Molt firing suppress every other on-death effect (Toll, Rise,
  Essence, Decay-adjacent triggers), or only some? **Working default: Molt fully replaces
  normal death handling — no discard, no Toll, no Rise, no Essence — since the unit is
  defined to not have died.** This mirrors how retreat already suppresses Toll and Rise
  for the identical reason ("the unit didn't die"). Needs confirmation.
- **Should Molt-return be visible/telegraphed, or silent?** The rules generally favor
  legible state (spent Judgment/Sanctuary render live on the card). A Molt trigger should
  presumably get the same treatment other death-adjacent state changes get (Motion.gd's
  pop/flash vocabulary) once this reaches engine work — flagged for that phase, not a
  design blocker now.

---

## Not Yet Designed

- **The card set.** No chains, no names, no cards, no art grammar.
- **Wilds energy.** Colour, and the energy token's drawn mark — must be one closed figure,
  distinct in greyscale from the eight that already exist (bone, sun, hole, leaf, flame,
  bolt, and Wyrd's reserved four-point star already claim four of the remaining shapes).
- **Whether Wilds has a defensive archetype at all**, or whether — like Tempest's
  offence-only Charge — that is a deliberate omission answered by a rule-breaker card
  later rather than by the keyword pair itself.
- **The damage discount derivation.** Blocking for card authoring — see Open Questions.

---

## Engine Cost

Not a plan, just the shape of the work, so it is not discovered late.

| Piece | Where | Notes |
|---|---|---|
| `Molt` death interception | `GameState._cleanup_dead` (or wherever death is finalized) | Must run **before** normal death handling — discard, Toll, Rise, Essence all need to be skipped, not merely followed by a summon. |
| Exact-copy construction, full HP/energy | `Unit` | Likely close to `Unit.make_risen()` in shape, but preserving rather than halving/stripping — closer to "rebuild from `CardData`, then reattach the current energy total" than to Rise's reset. |
| Molt lost on use, restored on evolve | `Unit.evolve_into()` | The one place it must be **granted back**, mirroring the one place Charge must **not** be reset. |
| `Ferocity` per-unit stack counter | `Unit` | Same shape as `Unit.charge` (Tempest) — an int that persists across turns, rendered live. |
| Ferocity trigger: friendly death, own board only | `GameState` death-resolution path | Needs the same per-board scoping `Essence` already uses — must not cross boards. |
| Ferocity stacks carried through Molt, wiped otherwise | `Unit.evolve_into()` / death path / Molt's copy-construction | Three separate reset points to get consistent: normal death wipes, evolution wipes (per every other per-unit value), Molt's copy explicitly does not. |
| Live stack count on the card | `CardView._live_keyword_line()` | Required by the standing rule that state the engine tracks per-unit has to be visible per-unit — same treatment Sanctuary's remaining pool and Charge's counter already get. |
| HP band enforcement | Card generator (`tools/add_*_faction.py`-style) | Once numbers are pinned, the generator should refuse a Molt card outside its band, matching how the bestiary generator already refuses HP-band, two-line, and Judgment-cap violations. |
