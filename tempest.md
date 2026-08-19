# Tempest — Faction Design

**Status:** built 2026-08-17. **66 cards, 59 units, 20 chains** — full parity with the
other five colours. Both keywords implemented; five sample decks.
**Sentence:** *pressure builds until it breaks.*

Design spec: `docs/specs/2026-08-17-tempest-faction-design.md`.
Build plan: `docs/plans/2026-08-17-tempest-engine.md`.

---

## Why Tempest Exists (Twice)

Tempest sat in the reserve table as *storm, speed, motion — "Chain"*, and on
2026-08-16 it was **absorbed into Forge**. That reasoning was sound and still is:

> Its stated identity was cheap repeated attacks, which is the *only* mechanically
> available meaning of "aggro" in an engine where cards are free and bodies are already
> cheap — so Tempest and Forge were competing for one slot.

Forge took the multi-attack role concretely, not just in principle: the `Bellow` chain
prints `stoked_extra_attack` and the `Second Wind` sample deck is built on it.

The absorption left one door open — *"revivable later only as a genuinely different idea,
or as a subfaction"* — and this is that idea. Tempest keeps the name and the storm imagery
and abandons cheap repeated attacks entirely. **Nothing here competes with Forge's
multi-attack claim.**

---

## What Tempest Does That No Other Faction Can

**It is the only faction whose resources persist and grow across turns.**

| Resource | Stored? | Has magnitude? | Survives across turns? |
|---|---|---|---|
| Gaia `Earth` | No — a live sum | Yes | Aura dies with its holders |
| Heaven `Judgment` | Yes | **No — binary** | Yes, until spent |
| Forge `stoked` | Yes | Yes | **No — clears each turn** |
| The energy pool | Yes | Yes | Yes, but **decays 20%** |
| **Tempest `Charge`** | **Yes** | **Yes** | **Yes, and grows** |

Everything else is instant, live, binary, or decaying. Tempest banks.

| Faction | Pays with | Gets back |
|---|---|---|
| **Hel** | Bodies dying | Energy (`Toll`) — death is *income* |
| **Heaven** | Discrete charges | Time — a death postponed |
| **Void** | Fragility | The opponent's energy |
| **Gaia** | Surviving bodies | A live board-wide aura |
| **Forge** | HP, attached energy, own units | Immediate damage, at once |
| **Tempest** | **Time, and the risk the body dies holding it** | **An oversized effect at a moment you choose** |

**The distinction from Gaia is the one to hold**, because both accumulate. Gaia grows
**wide** — a board-wide aura that rewards keeping many bodies alive and shrinks the instant
one dies. Tempest grows **deep** — one number on one body, lost whole when it dies. Gaia is
a garden; Tempest is a bet.

**From Forge**: Forge spends principal for damage *now*, Tempest spends *time* for damage
later. A Forge body left alone has done nothing; a Tempest body left alone has been banking.

---

## Keywords

| Keyword | Effect |
|---|---|
| **Charge N** | *(signature)* A visible counter on this unit, starting at 0. Grows by N **each time this unit deals an instance of damage**. Persists across turns and **through evolution**. Uncapped. Lost when the unit dies. |
| **Storm N** | *(signature)* A **global** counter both players read. Every attack deals **one additional instance of N damage**. A Tempest unit's Storm instance deals **2N**. Permanent, uncapped, symmetric. |

### Charge — the primary

**The counter is the investment.** A Charge unit is worth more every turn it survives and
swings, and worth nothing the moment it dies. That is the same bargain attached energy
already makes, which is why it needs no invented counterplay rule — the board is the answer.

**Discharge** is a free, once-per-turn ability that spends the whole counter. What it buys
is **printed per card**; the baseline is *this attack deals the counter as bonus damage and
strikes a second unit on that board for the counter*.

**Growth is card text, not keyword text** — the arrangement `Toll` and `Earth` already use.

**It grows on damage DEALT only, never taken.** An earlier draft allowed both and was
dropped for three reasons: the counterplay became *"stop attacking"*, which is the weakest
kind; it collided with shared `Retribution` on a board where Gaia's `Thicket` is already
the Retribution-wall deck; and offence-only makes banking a decision rather than a
byproduct, since the unit has to spend energy and expose itself to bank.

The cost is that **Tempest has no defensive wall archetype**. That is correct — *storm as
pressure that builds by acting* beats *storm as a thing that happens to you*.

**Discharge damage never grows Charge.** A spend is a spend, or a large discharge partially
refunds itself.

### Storm — the shared weather

**A global board state, not a per-unit keyword** — the same category as `The Gap`, and it
lives in `CLAUDE.md` for the same reason. It is 0 until a Tempest card raises it and never
falls.

**One instance of N, never N instances of 1.** This is not a detail. `Resist X` reduces
each incoming *instance* to a minimum of 1 damage, so N separate ticks would pierce armour
entirely as Storm climbed — a wider anti-shield break than Forge's `stoked_unpreventable`,
printed on a global number. One instance keeps `Resist` working exactly as printed.

| Gap | Storm |
|---|---|
| **Asymmetric** — each player has their own | **Symmetric** — one shared number |
| A passive measurement of a state players create anyway | Fed **deliberately** by playing Tempest cards |
| Floors at 0 | Floors at 0 |
| Shown only in a Void matchup | Shown only in a Tempest matchup |

**Tempest units benefit twice: their Storm instance is 2N.** That asymmetry is what makes
Storm a Tempest mechanic rather than a house rule — a shared resource the faction simply
uses better — and it is **the balance dial** if Storm proves too strong.

---

## Why They Are a Pair

| Faction | Generator | Spender |
|---|---|---|
| Hel | `Toll` | `Decay` |
| Void | `Siphon` | `Void N` |
| Gaia | `Earth` | `Essence` |
| Forge | `Stoke` | `Scrap` |
| **Tempest** | **`Charge`** | **`Storm`** |

Tempest's pair runs as a **loop** rather than a line: Storm doubles Charge's growth (every
attack becomes two instances), and Charge discharges into damage on a board where Storm
makes all damage bigger.

**Charge numbers are printed assuming Storm exists.** Without it a Tempest unit banks at
half rate — playable, merely slow. A real mechanical dependency between the signatures,
not a thematic one.

---

## Numbers

| Stage | `Charge N` | With Storm, by rnd 6 | Reference |
|---|---|---|---|
| Basic | 3–5 | 30–50 | median Basic **50 HP** |
| Stage 1 | 6–8 | 60–80 | median Stage 1 **96 HP** |
| Stage 2 | 9–12 | 90–120 | median Stage 2 **149 HP**; damage ceiling **120** |

**The damage discount is 30%, and it was derived rather than picked.** The live pool
measures 7.0–8.1 damage per energy (mean 7.69). An attack grows Charge twice, so amortised
the keyword is worth **+2N damage every swing forever** — +20 at Stage 2, ~2.6 energy of
value, the largest keyword benefit in the game. Compare `Judgment` −1/3 and `Sanctuary`
−18%. **Non-Charge Tempest bodies keep the standard rate**, enforced per line by the
generator.

---

## The Card Set

Two generators: `tools/add_tempest_faction.py` (the 6 launch chains) and
`tools/add_tempest_expansion.py` (14 more, in three power tiers). **59 units, 20 chains,
6 supports, 1 energy card**, at **74% signature density** — the built colours run 73–100%,
and the ~26% that print no `Charge` are the Storm chains and the vanillas.

The launch chains, each owning one op:

| Chain | Idea | Owns |
|---|---|---|
| **Cirr**sile → gale → tempest | The baseline: bank, then hit two targets | `discharge` |
| **Nimb**whorl → squall → maelstrom | The banker: double-counter into one target; the Stage 2 reaches structures | `discharge_single`, `discharge_structures` |
| **Foehn**sile → shear → thunderhead | The weather-maker. **No Charge at all** — it exists to raise Storm | `storm_raise`, `storm_scale_damage` |
| **Sirocc**skirl → squall | The relay: moves a counter off a dying body | `charge_transfer` |
| **Bora**whorl → shear → maelstrom | The executioner: grows extra on kills, discharges as a sweep | `charge_on_kill`, `discharge_sweep` |
| **Calm**sile → gale | The support body: discharges as healing | `discharge_heal` |

**Not every Tempest unit carries Charge**, and that is deliberate. Foehn has none — a
faction where every body has the keyword is the sameness failure the bestiary waves
documented. The generator enforces the converse: a body that prints Charge must have
something that grows it *and* something that spends it, or the counter is dead data.

### Supports

Tempest-locked, following the precedent `forge.md` set: a faction support is bought with a
deckbuilding commitment, a cost the 43 neutral supports never pay. Kept few — Tempest's
identity is on its bodies, unlike Forge whose aggression lives in its support suite.

- **Weather Front** (free) — raise Storm by 2.
- **Updraft** (1) — a unit you control gains 15 Charge.
- **Earthing Rod** (Tool) — this unit grows 2 extra Charge per point of Storm.

### The sample decks

Five, each on a different way to spend a counter — which is what the expansion bought:
at 16 units there was one Tempest deck, at 59 there are five plans.

| Deck | Idea |
|---|---|
| **Gathering Weather** | The starter. Banker, baseline and weather-maker, plus the relay. |
| **Levin Line** | Aggro. Cheap Charge bodies that discharge early rather than banking. |
| **The Long Bank** | Bank as long as possible, then spend it all into one body. |
| **Broken Rank** | Sweep. Every discharge splits across the board; wants a wide enemy. |
| **Storm Front** | Barely uses Charge. Every body raises Storm or scales off it. |

---

## Interaction Notes

**Charge survives evolution; the value carries, the rate does not.** The third thing to do
so, after attached energy and Tools, and for the identical reason: without it, evolving
destroys the investment and the correct play for the one faction whose resource is time is
never to evolve. **Evolving is Tempest's rate increase** — the counter is the investment,
the stage is the interest rate.

**Lost on death** (the counterplay), **on `Rise`** (*"Rise restores the card, not the
history"*), and **on retreat** (which would otherwise launder a counter past all removal).

**`charge_on_kill` is checked after Judgment resolves.** Defensive Judgment rescues a unit
*after* damage lands, so reading `hp <= 0` any earlier pays the executioner for a body
still standing. Found by a test, not by inspection.

**Retribution fires once per attack, not per instance.** Without this a `Retribution 25`
wall recoils 50 at Storm 3, and `Thicket` and `Standing Heat` become unattackable as Storm
climbs.

**`Resist X` reduces the Storm instance normally**, so a `Resist 10` body ignores Storm
until Storm exceeds 10. Armour keeps working — the whole reason for the one-instance rule.

**Plain `Sanctuary` is spent by the Storm instance.** It absorbs "the next instance
entirely", and a Storm 3 tick is an instance. A narrow, deliberate Heaven counter.

**Storm instances obey the targeting chain independently.** If the main attack killed the
defender, the Storm instance retargets and falls through to the tower once the board is
clear — so **Storm quietly rewards clearing a board**.

**`discharge_structures` rides the ATTACK, not the ability.** `_deal_lane_damage` reads the
attack that resolves; the ability only arms the counter. On an ability it is silent dead
data, so the generator refuses it.

**Storm arms the opponent too.** A Tempest player raising it is helping both sides; the 2N
bonus is what makes it worth doing. A Tempest mirror escalates very fast.

---

## Open Questions

- **Does Storm outrun the tower clock?** Modelled, a permanent uncapped ramp adds more
  damage per round than both towers by round 9. Adopted anyway as a deliberate bet: Storm
  is *symmetric*, so it sets the pace rather than the winner — and the 5M sweep's measured
  problem is that **slow decks lose**, with tower scaling already A/B tested and
  exonerated. **The first thing to measure.** The dial is the 2N bonus, not the global
  number.
- **Is Charge's uncapped counter safe?** The tower clock is the only brake. If it outruns
  the clock, the dial is the growth number, not a retrofitted cap.
- **Does Tempest have a defensive archetype at all?** Offence-only Charge removes the wall
  build deliberately. If the faction proves one-dimensional, the answer is a *card* that
  prints "also grows when this unit takes damage" as a rule-breaker, not a keyword change.
- **AI results are worth less here than for most factions.** `AIPlayer` banks its whole
  pool onto one body every turn — `void.md` already flags this for Rift, and a faction
  built on a growing counter has the same exposure. First samples: **0–5 vs Toll Engine**
  (the ~80% outlier) and **2–5 vs Lamp Wall**, 6–15 rounds, no stalls. Both wins came in
  the games where Storm reached 8+, which is the dependency working. **Not a balance
  reading.**
- **Is the 30% discount right?** Derived from Charge being worth +2N per swing, but that
  assumes the counter is actually spent well. An AI that discharges badly makes the
  keyword look overpriced.
