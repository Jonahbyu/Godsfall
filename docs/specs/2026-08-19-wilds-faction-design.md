# Wilds — Faction Design

**Status:** built. 20 units in 8 chains, 6 faction supports/tool, 1 energy card
(27 cards total) are in `data/cards.json`; both signatures are implemented in
the engine (`Unit.gd`, `GameState.gd`), rendered live on the card
(`CardView.gd`), and documented in the Compendium. Three sample decks ship
(`Second Life`, `The Long Tally`, `Never Really Died`). Verified against all
20 headless harnesses (0 regressions) and a live AI-vs-AI probe showing both
keywords firing correctly, including the Molt-feeds-own-Ferocity interaction.
**Date:** 2026-08-19, engine work and cards landed 2026-08-20
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
| **Ferocity N** | *(Wilds signature)* This unit tracks a stack counter, starting at 0. **Whenever a friendly unit on this unit's own board dies — including a death answered by `Molt` or `Rise` — it gains N stacks.** The trigger fires at the moment of death itself, not at a later return; a unit carrying both Ferocity and Molt gains stacks from its **own** Molt-death too. Each stack held grants **+2 max HP and +1 damage on every attack**, for as long as the stacks are held. **Stacks are lost when this unit dies** — unless the death is answered by its own `Molt`, in which case the copy keeps them. |

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

**The trigger is "died," and `Molt` and `Rise` both count — settled 2026-08-20 after the
first draft was too narrow.** The original wording only fired on a unit actually reaching
the discard, which quietly excluded the two most Wilds-flavored deaths in the game: a
unit that Molts didn't "die" by that reading, and neither did one saved by `Rise`. That
made the keyword read as "watches unlucky deaths" when the fiction is closer to "watches
the board thin, however that happens." The trigger now fires at the **moment of death**
regardless of what happens next — Molt-replacement, next-turn Rise, or a true discard all
count identically, and none of them wait for a later event (a Rise-death procs Ferocity
immediately, not when the card reappears next turn, so there is exactly one trigger point
per death and nothing to track across a turn boundary).

**A unit's own Molt feeds its own stacks.** A card printing both Ferocity and Molt counts
its own Molt-death as a qualifying friendly death on its own board, gaining stacks from
surviving its own near-death the same turn it happens. This reads correctly in the
fiction — Thrash's flavor already says *"it never really died"* — and it means a
Molt+Ferocity body is stronger than either signature suggests alone: every time it would
die, it both gets a full second life **and** grows.

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

**A card printing both Molt and Ferocity sits at the bottom of its Molt band**:

| Stage | Molt HP band | Molt+Ferocity HP (bottom of band) |
|---|---|---|
| Basic | 30–60 | **30–35** |
| Stage 1 | 60–95 | **60–68** |
| Stage 2 | 90–140 | **90–100** |

**Ferocity N, by stage: 1 / 2 / 3.** Basic trackers (and disposable token-style Basics)
print N=1; Stage 1 sacrifice payoffs print N=2; N=3 is reserved for one Stage 2
build-around. See *Open Questions* for the reasoning.

---

## Open Questions

**Resolved 2026-08-20, before card authoring**, so the generator has real numbers rather
than TBDs to build against:

- **Damage discount: none.** Confirmed as the working default. HP-band (Molt) and
  death-scarcity (Ferocity) already tax both keywords; a third rate cut would be
  double-taxing in a way none of the other five factions do — each of them pays exactly
  once, in whichever currency fits the keyword.
- **Ferocity N, by stage:** N=1 on cheap/disposable Basics — they are expected to die
  often, so even 1 stack per death compounds — N=2 on Stage 1 sacrifice payoffs, N=3
  reserved for a single Stage 2 build-around. Bounded by the board (2–3 usable slots per
  side) and the ~9.5-round mean game length: a real game plausibly feeds a Ferocity
  tracker single digits to low teens of stacks, not dozens, so N above 3 is not needed
  and would make the keyword swingy rather than steady.
- **Molt+Ferocity combo carve-out: yes.** A card printing both sits at the *bottom* of the
  already-reduced Molt HP band (see Numbers), enforced by the generator rather than left
  to author discretion — it is strictly stronger than either keyword alone and should
  never also be printed at the top of its band.
- **Interaction with `Rise`: no card ever prints both.** Rather than invent a precedence
  rule for two keywords that both claim "when this unit would die," the generator refuses
  the combination outright. Cheaper than adjudicating it, and nothing about either
  keyword's identity needs the other.
- **Interaction with `Essence` / `Toll` / `Decay` / any other on-death trigger: confirmed.**
  Molt fully replaces normal death handling — no discard, no Toll, no Rise, no Essence —
  because the unit is defined to not have died. Mirrors retreat's existing suppression of
  Toll and Rise for the identical reason.
- **Token summoners — still not designed as their own sub-theme**, but the roster below
  includes disposable Basics that feed Ferocity without themselves printing Molt (a
  self-Molting token would contradict its own job of being disposable). A dedicated
  token-summoner mechanic (a unit that prints multiple bodies at once) remains unbuilt and
  is not required for the baseline set.
- **Should Molt-return be visible/telegraphed, or silent?** Deferred to engine work, not a
  design blocker — flagged in Engine Cost.

---

## Card Concepts

Six chains, one idea each — the same discipline the Tempest and Hel starter decks used.
Built in `tools/add_wilds_faction.py`; not yet applied to `data/cards.json` (see *Not Yet
Designed*). Naming follows the bestiary system: a shared stem per chain, a suffix pool
per faction (`-grub/-runt/-cub` at Basic, `-maw/-hide/-fang` at Stage 1,
`-brute/-warden/-ravager` at Stage 2), guttural and short-vowelled — nothing ringing
(Heaven) and nothing sibilant (Tempest).

**1. Grum — Molt alone, the clean teach.** No Ferocity on this chain at all, so a new
player learns what Molt does without a second mechanic muddying the read. Ordinary
damage on the reduced Molt band (Grumgrub 40 → Grummaw 78 → Grumbrute 118), plus a small
self-heal ability so the chain has *some* second line beyond the attack. *"It has died
before. It did not think it was worth mentioning."*

**2. Snarl — Ferocity alone, the clean teach.** The mirror of Grum: no Molt, so a dead
Snarl unit is actually dead and the counter's growth is the only thing to watch. Basic
through Stage 2 climb Ferocity 1 → 2 → 3 in step with the pinned per-stage values, and
each carries a passive line ("Watch the Pack" / "Circle the Kill" / "Gorge") that both
grows the stack and grants its +2 HP/+1 damage payout. *"It has learned to count the ones
that don't get back up."*

**3. Thrash — the build-around.** Both signatures on every card, at the
Molt+Ferocity-carved-out HP band (Thrashrunt 32 → Thrashfang 65 → Thrashwarden 96) — the
smallest bodies in the faction, because this chain is strictly stronger per-card than
either Grum or Snarl alone. The Stage 2's attack (`Unmake`) explicitly scales with the
held stack count, which is the payoff the other two chains only imply. *"It never really
died. That is the whole design of it."*

**4. Whelp — the fodder, now with Molt.** Two Basics, no further evolution — this is what
dies in front of Snarl and Thrash to feed their stacks. Reversed 2026-08-20: earlier
drafts withheld Molt on the reasoning that a self-Molting token contradicts being
disposable, but that logic only held while Ferocity ignored Molt-deaths. Now that a
Molt-death is a qualifying friendly death in its own right, Molt makes a Whelp *better*
fodder, not contradictory fodder — it can feed a nearby tracker on its Molt-death, keep
fighting, and feed it again on its real death, all from one card. Each also prints
`Retribution` as a real keyword rather than a rider, so killing one still costs something
even though it's meant to die. *"It was never going to be the one that lived — it just
took two tries."*

**5. Boar — vanilla into keyword.** A plain-stat Basic (no keywords at all) that evolves
into a Stage 1 carrying Ferocity 2. This is the chain that satisfies the standing rule
that a keyword-less Basic must evolve into something that isn't — and it reads as the
in-fiction moment a young animal starts noticing the bodies. *"It has started noticing
who doesn't get up."*

**6. Scarl — Molt as a moment, not just a safety net.** Same keyword as Grum, different
idea: instead of a self-heal, each stage's ability reads the *next* Molt trigger itself
("Thicken the Hide" / "Harden the Hide") and grants the returning copy temporary
`Resist`. This is the chain that argues Molt is something a card can build around, not
only insurance sitting quietly on the card. *"The scars come back with it, every time, a
little thicker."*

**Supports.** `Second Skin` (free) grants Molt to a unit that lacks it, until its next
death or evolution — a way to try the keyword on a body that doesn't print it. `Cull the
Weak` (1 energy) sacrifices a small friendly unit on demand, feeding a Ferocity tracker
without waiting for combat to produce the death. `Trophy Rack` (Tool) is the one printed
rule-break in the set — it reads *any* death on either of your boards, friendly or enemy,
not just the own-board-friendly-only trigger every unit keyword uses, which is exactly
the kind of exception design principle #1 calls for.

---

## Not Yet Designed

- ~~**The card set.**~~ **Built and shipped**, 2026-08-20 — `tools/add_wilds_faction.py`
  holds 20 units in 8 chains (Grum, Snarl, Thrash, Whelp, Boar, Scarl, Gnaw, Reave), 6
  faction supports/tool, and the energy card (27 cards total), applied to
  `data/cards.json`. Both signatures are keyword-driven rather than effect-driven — see
  *Precedent check #1* and the generator's module docstring — so no ability line is needed
  to carry either one; a card's `keywords` block is the whole mechanism, the same shape
  `Rise`, `Judgment` and `Sanctuary` already use. Three sample decks ship: `Second Life`
  (Molt-lean), `The Long Tally` (Ferocity-lean), `Never Really Died` (the Thrash combo).
  No card art yet — falls back to the initials placeholder, same as any card shipped
  before someone draws its emblem.
- **Wilds energy.** Named (`Rawhide`). The token's drawn mark (a fang) is **built** —
  see `EnergyIcon.gd`'s `wilds` case, one closed figure distinct in greyscale from every
  other faction's mark.
- **Whether Wilds has a defensive archetype at all**, or whether — like Tempest's
  offence-only Charge — that is a deliberate omission answered by a rule-breaker card
  later rather than by the keyword pair itself. The shipped roster still leans offensive;
  no Sanctuary/Resist-style wall exists yet. Still open.
- ~~**The damage discount derivation.**~~ **Resolved** — see Open Questions: no separate
  discount for either keyword.
- **The Ferocity trigger was widened after the baseline shipped, on Jonah's correction
  2026-08-20.** The first cut only fired on a unit reaching the discard, which excluded
  the two most Wilds-flavored deaths in the game — a unit's own trigger now also counts a
  `Molt`-death and a `Rise`-death, fired at the moment of death rather than at any later
  return, and a unit carrying both signatures counts its own Molt as a qualifying death on
  its own board. `Whelp` was reversed to carry Molt for exactly this reason — a Molt'd
  Whelp now feeds a nearby tracker twice per card instead of contradicting its own job of
  being disposable. See the *Ferocity N* section above and the Card Concepts entry for
  Whelp.

---

## Engine Cost — as built

Landed 2026-08-20. Kept for the record of where each piece lives, since the original
table (written before anything was built) undersold two things worth naming here: Molt
and Ferocity turned out to need **no attack/ability op at all**, and Ferocity's trigger
ended up wider than first specified (see the note above).

| Piece | Where | Notes |
|---|---|---|
| `Molt` death interception | `GameState._kill()` | Runs before Essence, Toll, Rise and the discard — all skipped when it fires, matching retreat's existing suppression. |
| Exact-copy construction, full HP/energy | `Unit.make_molted()` | Mirrors `make_risen()` in shape, inverted in every value: full HP not half, full attached energy not zero, Ferocity stacks **carried** not wiped. |
| Molt lost on use, restored on evolve | `Unit.lost_molt` / `Unit.evolve_into()` | Also `Unit.granted_molt`, for `Second Skin`'s borrowed grant — a separate field because Molt is a presence keyword (`has_kw`), not a numeric one `add_kw_mod` can raise. |
| `Ferocity` per-unit stack counter | `Unit.ferocity_stacks`, `add_ferocity()` | Same shape as `Unit.charge` (Tempest), but does **not** survive evolution — it resets like `earth_grown`/`hp_grown`, since nothing in this spec gave it a Charge-style carry-through story. |
| Ferocity's +2 HP / +1 damage payout | `Unit.max_hp()`, `GameState._deliver_attack_damage` | HP folded directly into `max_hp()` since it is pure per-unit state (no `Player` reference needed, unlike Earth's board-wide aura); damage read at resolution alongside Rift. |
| Ferocity trigger: own board, fires on Molt/Rise too | `GameState._trigger_ferocity(p, b)` | Runs at the top of `_kill()`, before anything else, so a unit's own Molt-death is still "on this board" when it fires — that ordering is what makes the self-feed work with no special case. |
| Ferocity stacks carried through Molt, wiped otherwise | `Unit.make_molted()` / `evolve_into()` / `make_risen()` | Three reset points, one deliberate exception: Molt's copy is the only place stacks survive. |
| Live stack count / spent-Molt hidden | `CardView._live_keyword_line()` | `Ferocity N (+rate)`, same convention as Charge's banked-counter display; a spent Molt disappears from the chip line, same as Rise. |
| HP band enforcement | `tools/add_wilds_faction.py` | Refuses a card outside its band (including the Molt+Ferocity carve-out) before writing, matching the bestiary/Forge/Tempest generators. |
| Six new support/Tool ops | `GameState._resolve_support_effects`, `_support_unit_candidates`, `UNIT_TARGET_OPS` | `grant_molt`, `sacrifice_small`, `self_damage_floor`, `gain_stacks_all_ferocity`, `force_molt`, `ferocity_reads_any_death` — none of these existed anywhere else in the game; each needed its own targeting filter and dispatch case. |
| Compendium coverage | `TutorialData.gd` (`_p_kw_molt`, `_p_kw_ferocity`) | Required by `TutorialTest`'s standing rule: a keyword in `Theme.KEYWORD_COLORS` with no page fails the suite. |
