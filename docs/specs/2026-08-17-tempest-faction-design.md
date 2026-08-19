# Tempest — Faction Design

**Status:** designed, not built. No cards authored, no engine work done.
**Date:** 2026-08-17
**Sentence:** *pressure builds until it breaks.*

---

## Why Tempest Exists (Again)

Tempest was in the reserve table as *storm, speed, motion — "Chain"*, and on
2026-08-16 it was **absorbed into Forge**. The reasoning in `CLAUDE.md` was sound and
still is:

> Its stated identity was cheap repeated attacks, which is the *only* mechanically
> available meaning of "aggro" in an engine where cards are free and bodies are already
> cheap — so Tempest and Forge were competing for one slot.

Forge took the multi-attack role concretely, not just in principle: the `Bellow` chain
prints `stoked_extra_attack` ("conditional Windfury") and the `Second Wind` sample deck
is built on it.

The absorption note left exactly one door open — *"Revivable later only as a genuinely
different idea, or as a subfaction."* **This is that different idea.** Tempest keeps the
name and the storm imagery and abandons "cheap repeated attacks" entirely. Nothing in
this document competes with Forge's multi-attack claim.

---

## What Tempest Does That No Other Faction Can

Tempest is the only faction whose resources **persist and grow across turns.**

| Resource | Stored? | Has magnitude? | Survives across turns? |
|---|---|---|---|
| Gaia `Earth` | No — a live sum | Yes | Aura dies with its holders |
| Heaven `Judgment` | Yes | **No — binary** | Yes, until spent |
| Forge `stoked` | Yes | Yes | **No — clears each turn** |
| The energy pool | Yes | Yes | Yes, but **decays 20%** |
| **Tempest `Charge`** | **Yes** | **Yes** | **Yes, and grows** |

Everything else in the game is instant, live, binary, or decaying. Tempest banks.

In the `forge.md` currency format:

| Faction | Pays with | Gets back |
|---|---|---|
| **Hel** | Bodies dying | Energy (`Toll`) — death is *income* |
| **Heaven** | Discrete charges | Time — a death postponed |
| **Void** | Fragility | The opponent's energy |
| **Gaia** | Surviving bodies | A live board-wide aura |
| **Forge** | HP, attached energy, own units | Immediate damage, at once |
| **Tempest** | **Time, and the risk the body dies holding it** | **An oversized effect at a moment you choose** |

**The distinction from Gaia is the one to hold**, because both accumulate. Gaia grows
**wide** — a board-wide aura that rewards keeping many bodies alive and shrinks the
instant one dies. Tempest grows **deep** — one number on one body, which rewards
protecting a single investment and is lost whole when that body dies. Gaia is a garden;
Tempest is a bet.

**The distinction from Forge:** Forge spends principal for damage *now*. Tempest spends
*time* for damage later. A Forge body left alone has done nothing; a Tempest body left
alone has been banking the whole time.

---

## Keywords

Tempest claims **two signatures**, matching every other faction's allowance.

| Keyword | Effect |
|---|---|
| **Charge N** | *(Tempest signature)* A visible counter on this unit, starting at 0. It grows by N **each time this unit deals an instance of damage.** Persists across turns and through evolution. Uncapped. **Lost when the unit dies.** |
| **Storm N** | *(Tempest signature)* A **global board counter** both players read. Every attack deals **one additional instance of N damage**. A Tempest unit's Storm instance deals **2N**. Permanent, uncapped, symmetric. |

### Charge N — the primary

**The counter is the investment.** A Charge unit is worth more every turn it survives and
swings, and worth nothing the moment it dies. That is the whole bargain, and it is the
same bargain attached energy already makes — which is why it needs no invented
counterplay rule. The board is the answer.

**Discharge** is a free, once-per-turn **ability**: spend the entire counter for an effect
**the card prints**. The counter resets to 0.

- The **baseline discharge** is *this attack deals the counter as bonus damage, and hits
  a second unit on that board for the counter.*
- Different cards do different things with a spent counter. The keyword guarantees only:
  *there is a counter, it grows, you may spend it all at once.*
- **Discharge damage never grows Charge.** A spend is a spend; without this rule a large
  discharge partially refunds itself and a Stage 2 discharges every turn without ever
  really paying.

**Growth is card text, not keyword text.** The keyword defines the counter and the spend;
each card prints its own trigger and its own discharge effect. This is the arrangement
`Toll` and `Earth` already use, and it is what stopped Gaia from collapsing into one
shape.

**Charge grows on damage DEALT only — never on damage taken.** An earlier draft allowed
both. It was dropped for three reasons:

1. **The counterplay was "stop attacking,"** which is the weakest kind. Offence-only means
   the answer is the one the game already has: kill it, or block it.
2. **It collided with shared `Retribution`.** A Tempest wall with `Retribution 20` profited
   twice from being hit, and Gaia's `Thicket` is already the Retribution-wall deck.
3. **It makes Charge a decision rather than a byproduct.** The unit must attack to bank,
   and attacking costs energy and exposes the body — *energy only buys attacks*, pointed
   at the faction's own resource.

The cost is the defensive-wall archetype, which Tempest does not get. That is correct:
*storm as pressure that builds by acting* is a better fit than *storm as a thing that
happens to you.*

### Storm N — the shared weather

**Storm is a global board state, not a per-unit keyword** — the same category as `The
Gap`, and it belongs in `CLAUDE.md` for the same stated reason:

> The Gap is a global board state, not a keyword — a number both players can read at any
> time, like the round counter. It exists because Void reads it; it is defined here
> because it is a property of the *board*, not of a card.

**Storm is 0 until a Tempest card puts it on the board.** It rises as Tempest cards are
played and never falls.

**One instance, not N instances.** Storm N adds a *single* extra instance of N damage to
every attack — not N instances of 1. This matters enormously and is not a detail:

| | N instances of 1 | **One instance of N** |
|---|---|---|
| Instances per attack | 1 + Storm | **Always 2** |
| vs `Resist 10` at Storm 3 | four 1s, each floored to 1 | 3 reduced normally, **0 through** |
| Charge growth at Storm 3 | 4 per attack | **2 per attack** |

Under the multi-instance reading, Storm was a **Resist-piercing** mechanic — armour became
useless as Storm climbed, a wider anti-shield break than Forge's `stoked_unpreventable`
and printed on a global number. One instance keeps `Resist` working exactly as printed.

**How Storm differs from the Gap:**

| Gap | Storm |
|---|---|
| **Asymmetric** — each player has their own | **Symmetric** — one number, shared |
| A passive *measurement* of a state players create for other reasons | Fed **deliberately** by playing Tempest cards |
| Floors at 0 | Floors at 0 (same rule, same reason) |
| Readout shown only in a Void matchup | Readout shown only in a Tempest matchup |

**Tempest units benefit twice: their Storm instance deals 2N.** This is the asymmetry that
makes Storm a Tempest mechanic rather than a house rule — it is a shared resource that
Tempest simply *uses better*, which is more interesting than a bonus only one player can
access. It is also the correct **balance dial**: if Storm proves too strong, this is the
number to cut, not the global one.

---

## Why They Are a Pair

Every faction's signature set is a generator and a spender that relate to each other:

| Faction | Generator | Spender |
|---|---|---|
| Hel | `Toll` (death into energy) | `Decay` (free chip that causes deaths) |
| Void | `Siphon` (take energy) | `Void N` (the sharper, rarer version) |
| Gaia | `Earth` (grows an aura) | `Essence` (saves it from the death that would end it) |
| Forge | `Stoke` (sets a state) | `Scrap` (the sharper, rarer version) |
| **Tempest** | **`Charge`** (banks a counter) | **`Storm`** (the shared weather that fills it) |

Tempest's pair runs as a **loop** rather than a line: Storm doubles Charge's growth
(every attack becomes two instances), and Charge discharges into damage on a board where
Storm makes all damage bigger.

**Tempest's Charge numbers are printed assuming Storm exists.** Without Storm on the
board a Tempest unit banks at half rate. That is a genuine mechanical dependency between
the two signatures rather than a thematic one — and it is not punishing, since half rate
is playable, merely slow.

---

## Numbers

**Charge N by stage**, tracking the HP curve so the tower clock stays the brake:

| Stage | `Charge N` | With Storm, by rnd 6 | Reference |
|---|---|---|---|
| Basic | **3-5** | 30-50 | median Basic **50 HP** |
| Stage 1 | **6-8** | 60-80 | median Stage 1 **96 HP** |
| Stage 2 | **9-12** | 90-120 | median Stage 2 **149 HP**; damage ceiling **120** |

Measured against the live card pool: 282 units, median Basic 50 HP, Stage 1 96, Stage 2
149; 276 attack lines, median damage 35, max 105.

A Charge unit's counter threatens the stage below it, and a Stage 2 approaches the game's
120 damage ceiling around the round games actually end (~9.5 mean).

**Storm pace:** roughly +1 per Tempest card played, so ~1.5/round in a mono-Tempest deck —
Storm ~3 by round 3, ~8 by round 6, ~12 by round 9.

---

## The Deliberate Bets

Three choices where the design was challenged, the challenge was overruled, and the
override is defensible. Recorded as bets so playtesting knows where to look first.

### 1. Storm is permanent, uncapped, and symmetric

**The concern:** modelled at ~1.5 Tempest cards/round and ~3 attacks/player/round, Storm
adds more damage per round than both towers combined from round 3 onward. That is a third
clock in a game whose most urgent open questions are already about clocks and stall.

**The case for it:** Storm is **symmetric**, so it does not decide *who* wins — it decides
*how fast*. And `CLAUDE.md`'s measured problem is that **slow decks lose**: the bottom
three decks in the 5M-game sweep (`Cacophony Ramp` 22%, `Burning Line` 26%, `Scrap Line`
27%) are all slow, and **tower scaling was A/B tested as the suspected cause and
exonerated** — at +2/round instead of +3, games lengthened and the bottom decks did not
move. A shared damage ramp is a plausible answer to the thing tower tuning could not fix.

**Dial if wrong:** the Tempest **2N** bonus, not the global number.

### 2. Charge is uncapped; the tower clock is the brake

**The concern:** Charge is the first resource in the game that only goes up for as long as
its holder lives. `Stoke` clears each turn, `Judgment` is binary, `Sanctuary` only falls,
`Earth` dies with its holders.

**The case for it:** the numbers are set so Charge tracks the HP curve, and a deck banking
past round 9 is exactly the slow deck the ~9.5-round clock already beats. Charge is also
**offensive**, so unlike the `Sanctuary` failure it must *land* — the opponent's board is
between the counter and anything that matters.

**Dial if wrong:** the growth number, not a retrofitted cap.

### 3. Every instance dealt grows Charge

So Storm doubles Charge growth. Bounded at exactly 2x per attack (never compounding)
because Storm is one instance regardless of size.

**Dial if wrong:** make it once per attack.

---

## Interaction Notes

Decided up front, because each would otherwise be discovered mid-build.

**Charge survives evolution. The value carries; the rate does not.** A Basic with
`Charge 3` that banked 21 evolves into a Stage 1 with `Charge 8` and continues from 21,
growing 8 at a time.

This makes Charge the **third** thing to survive evolution, alongside attached energy and
Tools, and it has the same justification attached energy does: *without it, no Stage 2
could ever be charged.* Every other per-unit value resets in `Unit.evolve_into()`
(`hp_grown`, `earth_grown`, `kw_mods`, `judgment_spent`, the Sanctuary pool) under the
principle *new printed card, new everything*. Charge is the exception because resetting
it would make **evolving a punishment for the one faction whose resource is time** — the
correct play would be never to evolve, which breaks evolution for the whole colour.

The pleasing consequence: **evolving is Tempest's rate increase.** The counter is the
investment, the stage is the interest rate.

**Charge is lost on `Rise`.** *"Rise restores the card, not the history"* — identical to
grown `Earth`. Rise already returns a unit at half HP without its keyword; refunding a
full counter on top would make death nearly free for the one faction whose counterplay
*is* death.

**Charge is lost on retreat.** Retreat returns the card to hand healed to full, and
accumulated state does not survive that. Otherwise bank, retreat, redeploy launders a
counter past every piece of removal in the game.

**Retribution fires once per attack, not once per instance.** The printed wording is
*"when this unit takes damage from an attack"*, singular. Without this rule a
`Retribution 25` wall at Storm 3 recoils for 50 instead of 25, and `Thicket` and
`Standing Heat` become unattackable as Storm climbs.

**`Resist X` reduces the Storm instance normally.** Because Storm is one instance, a
`Resist 10` body simply ignores Storm until Storm exceeds 10. Armour keeps working, which
is the whole reason for the one-instance rule.

**Plain `Sanctuary` is spent by the Storm instance.** It absorbs "the next instance of
damage entirely," and the Storm instance is an instance — so a Storm 3 tick can eat a
whole plain Sanctuary. This is a narrow, deliberate Heaven counter rather than an
escalating one, and plain Sanctuary is already the documented exception case.
`Sanctuary N` depletes by the Storm instance's value, as with any damage.

**Storm instances obey the targeting chain independently.** Every damage source does. The
consequence is good: if the main attack kills the defender, the Storm instance retargets
to the next living unit, and once a board is clear it falls through to the tower. **Storm
quietly rewards clearing a board**, reinforcing design principle #4.

**Discharge reaches structures only on a card that prints it.** The base keyword is
units-only, matching Forge's sweep — which is explicitly forbidden from touching
structures because *"letting it fall through to a tower on an empty board would make it a
second shielding break rather than a wide one."* Cards may print the break individually,
per design principle #1, and it should sit on a Stage 2 or behind a threshold.

**Storm is symmetric, so it helps the opponent too.** A Tempest player raising Storm is
arming both sides. The 2N bonus is what makes it worth doing, and a Tempest mirror
escalates very fast — worth watching.

---

## Open Questions

- **Does Storm outrun the tower clock in practice?** Bet #1. The first thing to measure,
  and the cheapest read is an AI mirror with one Tempest deck against the existing field.
- **Is the 2N Tempest bonus the right size?** It is the intended balance dial for Storm,
  so it should be tuned before the global number is touched.
- **Does Tempest have a defensive archetype at all?** Offence-only Charge removes the wall
  build deliberately. If the faction proves one-dimensional, the answer is a *card* that
  prints "also grows when this unit takes damage" as a rule-breaker, not a keyword change.
- **What is Tempest's damage discount?** Every faction pays for its keywords below the
  curve — `Judgment` -1/3, `Sanctuary` -18%, Gaia ~9/energy against the standard. Tempest
  holds two compounding mechanics and almost certainly owes the steepest discount in the
  game. **Not yet derived; this must be settled before any card is authored.**
- **Does Storm make the AI's readings meaningless?** `AIPlayer` banks its whole pool onto
  one body every turn, which `void.md` already flags as making AI results worth less for
  Void than any other faction. A faction built on a growing counter has the same exposure.
- **Should Storm decay?** Rejected in favour of permanence as a deliberate bet. If bet #1
  fails, pool-style decay (20%/round) is the first alternative — it makes Storm a resource
  Tempest *maintains* rather than a clock that runs on its own, and "a storm passes" is
  thematically exact.

---

## Not Yet Designed

- **The discharge effect list.** What individual cards do with a spent counter. The
  baseline (bonus damage plus a second target) is defined; the rest is the next
  conversation.
- **The damage curve discount.** See Open Questions. Blocking for card authoring.
- **The card set.** No chains, no names, no cards.
- **Tempest energy.** Colour, art grammar, and the energy token's drawn mark. The mark
  must be **one closed figure** and distinct in greyscale from the eight that exist — the
  reserve table pencils Tempest as a bolt, which is a good closed shape.

---

## Engine Cost

Not a plan, just the shape of the work, so it is not discovered late.

| Piece | Where | Notes |
|---|---|---|
| `Storm` global counter | `GameState` | New board state beside the Gap. Needs a `storm_is_relevant()` twin of `gap_is_relevant()`. |
| The extra damage instance | `GameState._deal_lane_damage` | Every damage source already funnels through here, and `stoked_sweep` already makes multiple calls to it. Tractable. |
| `charge` per-unit counter | `Unit` | Same shape as `sanctuary_pool` — a depleting int already rendered live by `CardView._live_keyword_line()`, run the other direction. |
| Carry through evolution | `Unit.evolve_into()` | The one place it must **not** be reset. |
| Discharge as an ability | `GameState.use_ability` | Free, once per turn — the existing ability path. |
| Live counter on the card | `CardView._live_keyword_line()` | Required by the standing rule that *state the engine tracks per-unit has to be visible per-unit.* |
| Retribution once per attack | `GameState` | Must be confirmed against current behaviour before Storm ships. |
