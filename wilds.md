# Wilds — Faction Design

**Status:** built 2026-08-20. **27 cards, 20 units, 8 chains** — the newest of the seven
colours. Both keywords implemented; three sample decks.
**Sentence:** *the beast that keeps getting back up, and the one that gets worse the
longer you let it stand over the bodies.*

Design spec: `docs/specs/2026-08-19-wilds-faction-design.md`.

---

## Why Wilds Exists

Wilds is the last of the two remaining reserve candidates (`wyrd`, `wilds`), chosen over
Wyrd because randomness-as-identity cuts against the game's whole design language —
spend-or-save, pool-vs-attached, chosen targeting, volley ordering are all about legible
decisions over visible state, and a coin-flip faction fights that on every card.

Its stated identity in `CLAUDE.md` is **"flesh, beasts, raw physicality... nature as a
threat, not a garden"** — explicitly not Gaia. That distinction had to be earned twice
during design, not just claimed once: the first draft of each signature keyword
independently drifted into territory an existing faction already owns, and both were
corrected before landing (see *Precedent Checks* below).

---

## What Wilds Does That No Other Faction Can

Every built faction twists the **energy economy** — Hel recycles it, Void steals it, Gaia
grows an aura off it, Heaven gates it behind reprieves, Forge spends HP/bodies instead of
it, Tempest banks it over time. **Wilds does not touch energy at all.** It twists **bodies
themselves** — HP, death, and the board of corpses a fight leaves behind.

| Faction | Reads | Wilds reads instead |
|---|---|---|
| Gaia `Earth` | Attached energy, live | **Friendly deaths**, permanent |
| Tempest `Charge` | This unit's own combat | **Other units'** deaths, on this board |
| Forge `Stoke` | A per-turn flag, self-inflicted | A full-return, self-triggered by dying |
| Heaven `Rise` (shared) | — | The keyword this faction's first signature inverts |

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

| Keyword | Effect |
|---|---|
| **Molt** | *(signature)* When this unit would die, it is instead replaced — immediately, in the same slot — by an exact copy of itself at full HP, with all attached energy retained. **The copy loses Molt.** Evolving a unit that has lost Molt restores it. |
| **Ferocity N** | *(signature)* This unit tracks a stack counter, starting at 0. **Whenever a friendly unit on this unit's own board dies — including a death answered by `Molt` or `Rise` — it gains N stacks.** The trigger fires at the moment of death, not at a later return; a unit carrying both signatures gains stacks from its **own** Molt-death too. Each stack held grants **+2 max HP and +1 damage on every attack**, for as long as it is held. **Stacks are lost when this unit dies** — unless the death is answered by its own `Molt`, in which case the copy keeps them. |

### Molt — the reprieve, inverted

Every other "comes back from death" behavior in the game routes through the shared
`Rise` keyword: return next turn, to an empty slot, at **half HP**, keyword **stripped**,
attached energy **already lost** to the normal death rule. Molt inverts every axis at once:

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
earned by being **rare and one-shot** rather than a faction-wide free pass.

**The loop terminates because the keyword is spent, not because the body degrades.**
Rise's brake is that the returned unit is *worse* (half HP, no Rise), so repeated deaths
converge toward nothing. Molt's brake is different: the returned unit is **exactly as
strong**, but it cannot do this again until something restores the keyword — and the only
restoration is evolving. This is also what makes evolving mechanically necessary for a
Molt line rather than optional, the same way Tempest's evolution-carries-Charge rule made
evolving necessary there.

**Molt fully replaces normal death handling.** No discard, no Toll, no Rise, no Essence —
the unit is defined to not have died. This mirrors how retreat already suppresses Toll and
Rise for the identical reason.

### Precedent check #1 — where the first draft of Molt would have collided

The open question at the start of design was whether a body-pool resource could earn its
own colour slot rather than reading as a reskin of Tempest's `Charge` (per-unit,
persistent counter) or Forge's `Stoke` (per-unit, per-turn flag). Molt clears that bar
because it is **neither a counter nor a flag** — it is a one-shot state that, when it
fires, produces a full replacement of the unit rather than modifying a stat on it.

**Both signatures are printed as keywords, not as attack/ability effects.** Unlike
Tempest's Charge/Discharge or Forge's Stoke/Scrap, neither has an activation a player
chooses to use — Molt fires automatically on death, and Ferocity's +2 HP / +1 damage per
stack is a passive, always-on read of the counter, the same shape Rise, Judgment and
Sanctuary already use. So a card needs no dedicated ability line to carry either keyword;
`keywords: [...]` is the whole mechanism.

### Ferocity N — the payoff for a board that is dying

**Ferocity is per-unit, not a shared aura.** This was the harder of the two precedent
checks. The first framing on the table — "gain a stack whenever any friendly unit dies" —
is structurally identical to how Gaia's `Earth` reads a shared quantity, just with a
different trigger. What makes Ferocity distinct is that it is **not a live-computed,
board-wide sum every unit reads equally** — it is a private counter that one specific unit
accumulates by watching deaths happen *near it*, and different Ferocity units on the same
board can hold wildly different totals depending on what died in front of each of them.

**`N` is printed on the tracking card, not on the units that die.** `Ferocity 3` means
*this unit gains 3 stacks per friendly death on its board* — a single number, on a single
card, no second half of the keyword needed on ordinary units the way `Toll`'s refund value
is printed on the dying card itself.

**Own board only, matching every other per-board rule in the game.** Shielding, `Essence`,
and targeting are all explicitly scoped to a single board and never cross — Ferocity
follows the same discipline. `Trophy Rack` (a Tool) is the one printed exception that
reads any death on either board — design principle #1 pointed at the faction's own
build-around axis.

**The trigger counts Molt-deaths and Rise-deaths, settled after the baseline shipped.**
The first cut only fired on a unit reaching the discard, which excluded the two most
Wilds-flavored deaths in the game. It now fires at the **moment of death** regardless of
what happens next — Molt-replacement, next-turn Rise, or a true discard all count
identically, and none of them wait for a later event. A unit's own Molt feeds its own
counter, which is the deliberate combo point of the pair.

**Additive, never a true multiplier**, despite the flavor language ("multiplier") in the
original pitch. Design principle #4 states outright that concentrated damage beating
spread damage on a 4-slot board is *"what makes linear damage formulas work"* — every
scaling mechanic that exists (`Earth`, `Rift`, `Storm`, `Charge`) is additive per point,
and Earth's own history is the cautionary tale: even additive Earth at an uncorrected rate
produced a mean aura of 14.6, peaking at 78, and put every Earth deck 20+ points above the
field average. "Multiplier" survives only as card flavor text for what is mechanically a
flat per-stack bonus.

**Rate: +2 max HP / +1 damage per stack.** Set at roughly 2x Earth's post-nerf rate
(+1 HP / +0.5 damage per point), justified by scarcity: a point of Earth grows for free
off attached energy every turn a unit is charged, while a Ferocity stack costs an actual
friendly unit's death — a real, board-visible loss, not a resource reallocation.

**Stacks are permanent while the unit lives, wiped by its own death, and are the one
thing Molt is defined to save.** Every other reset mechanism in the game (`Rise`,
evolution, retreat) wipes grown history by explicit rule (*"Rise restores the card, not
the history"*); Molt is the specific, printed exception, because the fiction is that this
unit never really died at all.

### Precedent check #2 — the rejected-permanence problem

Gaia's first draft of `Earth` added max HP and damage into the towers every turn,
forever, and was rejected specifically because *"it has no counterplay — damage already
banked cannot be undone."* Ferocity is also a permanent accrual, so it has to clear that
same bar. It does, on the same terms Tempest's `Charge` already cleared it: **the
counterplay is killing the body holding it.** A Ferocity stack lives on one unit, and
removing that unit removes the stacks with it (unless Molt intervenes, which is itself a
spendable, one-shot exception rather than a second layer of permanence).

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
to die — sacrifice-fodder Basics are the natural low end of the faction, feeding Ferocity
stacks upward onto a body built to survive and cash them in.

This also gives the faction its own version of the sacrifice-engine shape Hel already
has (Toll-Decay), but inverted in what death produces: Hel converts death into **energy**;
Wilds converts death into a **stat, on a specific body, that only that body can lose.**

---

## Numbers

**Molt HP band: below the stage's normal range**, following the same house style as
Judgment (-1/3 damage rate) and Sanctuary (-18% damage) paying for their keyword in the
stat line rather than as a free addition.

| Stage | Normal HP band | Molt HP band | Molt+Ferocity HP band |
|---|---|---|---|
| Basic | 40–90 | 30–60 | **30–35** |
| Stage 1 | 80–120 | 60–95 | **60–68** |
| Stage 2 | 110–175 | 90–140 | **90–100** |

A card printing **both** signatures sits at the very bottom of its Molt band — it is
strictly stronger than either keyword alone and must never also be printed at the top.

**Ferocity N is pinned by stage, not banded: 1 (Basic) / 2 (Stage 1) / 3 (one Stage 2).**
Bounded by the board (2–3 usable slots per side) and the ~9.5-round mean game length: a
real game plausibly feeds a tracker single digits to low teens of stacks, not dozens.

**No separate damage-rate discount for either keyword.** HP-band (Molt) and
death-scarcity (Ferocity) already tax both keywords once each; a third rate cut would be
double-taxing in a way none of the other five factions do.

---

## The Card Set

One generator: `tools/add_wilds_faction.py`. **20 units, 8 chains, 6 supports/Tool, 1
energy card**, 27 cards total, applied to `data/cards.json`.

| Chain | Idea | Keywords |
|---|---|---|
| **Grum**grub → maw → brute | Molt's clean teach — ordinary damage, a self-heal | Molt |
| **Snarl**cub → hide → ravager | Ferocity's clean teach — no Molt to muddy the read | Ferocity 1/2/3 |
| **Thrash**runt → fang → warden | The combo build-around: its own Molt feeds its own Ferocity | Molt + Ferocity 1/2/3 |
| **Whelp**grub, runt | Disposable fodder that carries Molt on purpose — feeds a tracker twice per card | Molt, Retribution |
| **Boar**grub → hide | Vanilla into Ferocity, satisfying the keyword-less-Basic-must-evolve rule | — → Ferocity 2 |
| **Scarl**cub → fang | Molt as a moment to build around: its ability grants the *returning copy* temporary Retribution | Molt |
| **Gnaw**whelp → tusk | Wide Ferocity — several cheap trackers instead of one tall investment | Ferocity 1/2 |
| **Reave**grub → hide → reaver | The Stage 2 finisher; a manual "gain 2 stacks" ability for when the opponent won't trade | — → Ferocity 2/3 |

**Not every Wilds unit carries Molt or Ferocity.** Boar and Reave's Basics print neither,
by the same discipline every other faction's roster follows — a faction where every card
has the keyword is the sameness failure the bestiary waves documented.

### Supports

Wilds-locked, following the precedent `forge.md` and `tempest.md` set: a faction support
is bought with a deckbuilding commitment, a cost the 43 neutral supports never pay.

- **Second Skin** (free) — grant Molt to a unit that lacks it, until its next death or evolution.
- **Cull the Weak** (1) — destroy a friendly unit at 40 HP or less; every Ferocity tracker on its board gains stacks as if it had died there.
- **Running Wound** (free) — deal 18 to a friendly unit, floored at 1 HP for that instance only.
- **Stampede** (2) — every friendly unit with Ferocity gains 1 stack, no death required.
- **Shed the Skin** (1) — force a Molt-capable unit to use it immediately, without dying first.
- **Trophy Rack** (Tool) — this unit's Ferocity reads *any* death on either of your boards, not just its own.

### The sample decks

| Deck | Idea |
|---|---|
| **Second Life** | Molt aggro. Grum, Whelp, Scarl — trade constantly, come back exactly as strong. No Ferocity. |
| **The Long Tally** | Ferocity grind. Snarl, Gnaw, Boar, Reave — every death makes the board angrier. No Molt, no healing (wants its own units to die). |
| **Never Really Died** | The combo the faction is built around. Thrash plus Molt-carrying Whelp fodder, with Cull the Weak / Shed the Skin to manufacture the feed on demand. |

---

## Interaction Notes

**Molt's death interception runs before Essence, Toll, Rise, and the discard** in
`GameState._kill()` — none of them fire on a Molt'd death, matching retreat's existing
suppression.

**Ferocity's trigger fires at the top of `_kill()`, before the dying unit leaves its
slot.** That ordering is what makes a unit's own Molt-death still count as "on this
board" when its own Ferocity counter reads the trigger — no special case needed.

**Ferocity's HP bonus is folded directly into `Unit.max_hp()`**, unlike Earth's
board-wide aura, because it is pure per-unit state with no `Player` reference required.
Its damage bonus is read at attack resolution alongside Rift.

**Ferocity does not survive evolution** — it resets like `earth_grown`/`hp_grown`, since
nothing in the design gives it a Tempest-`Charge`-style carry-through story. Molt's
*keyword* is restored on evolve (the one place it must be granted back, mirroring the one
place Charge must **not** be reset), but any Ferocity stacks held are not.

**`grant_molt` (Second Skin) is a separate field from the printed keyword.** Molt is a
presence keyword (`card.has_kw`), not a numeric one `add_kw_mod` can raise — the same gap
that made `grant_sanctuary()` necessary for Aegis of the Choir.

**`Shed the Skin` and `Trophy Rack` reuse the exact same construction and trigger paths a
combat Molt uses** (`Unit.make_molted()`, `GameState._trigger_ferocity`), rather than
duplicating the logic — one path, not two that could quietly drift apart.

---

## Open Questions

- **Ferocity N values are a first pass, not yet checked against a large sample of real
  games.** 1/2/3 by stage was derived from board size and mean game length, not measured.
- **Does Wilds have a defensive archetype at all?** The shipped roster leans offensive —
  Snarl, Gnaw and Reave are all attackers, and Whelp/Scarl trade rather than wall. If the
  faction proves one-dimensional, the answer is a *card* that prints a Resist/Sanctuary
  rider as a rule-breaker, not a change to either signature.
- **`Trophy Rack`'s any-board read is the one printed rule-break in the set — is it too
  strong on a wide board?** It was authored as the sanctioned exception (design principle
  #1) but has not been measured in a wide-board matchup.
- **AI heuristics do not yet value Molt or Ferocity specially.** `AIPlayer` plays Wilds
  with the same generic heuristics every other faction gets — it does not know a Molt
  trade is safe, and it does not prioritize feeding a Ferocity tracker over an unrelated
  play. The live probe run during development (`Never Really Died` vs `Starve`, 25
  rounds) showed both keywords firing correctly, but that is not a balance reading.
- ~~**No card art yet.**~~ **Done, 2026-08-20** — `tools/wilds_art.py`, 8 distinct
  visual objects (torn hide, open jaw, coiled whip-tail, a single tooth, a tusk pair,
  claw marks, a gnawed bone-end, a talon), registered into `make_card_art.py`. Fixed a
  real pre-existing gap in the same pass: Tempest's cards had been falling back to plain
  teal for their backdrop tint since that faction shipped, because `FACTION` never had a
  `tempest` entry — caught and fixed alongside Wilds' own addition.
- **`wilds.md` itself is new** — unlike `forge.md` and `tempest.md`, which each went
  through a full engine-first expansion pass (Forge 19→63 cards, Tempest 20→66), Wilds
  has shipped only its baseline. Whether it gets the same expansion treatment is Jonah's
  call, not assumed here.
