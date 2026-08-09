# Gaia — Faction Design Spec

> **Status:** Design settled in conversation 2026-08-09. No cards authored, no engine code
> written. Read `CLAUDE.md` first for core rules, board geometry, and the energy economy.
> `Resist X` was decided in the same session but is a **shared** keyword belonging to the
> whole game, so it lives in `CLAUDE.md` rather than here.

**Domain:** Life, growth, nature.
**Verb:** Fuel.
**One-line identity:** *The board is the buff.*

---

## What Gaia Is

Gaia is the only faction whose strength is a **live sum of what it has on the table**. Every
other faction's power sits on individual cards; Gaia's sits on the board as a whole, and it
rises and falls as bodies arrive and die.

That single property generates the entire faction:

- **It is tanky because it must be.** Tankiness is not a flavour choice — the aura only
  exists while its holders live, so defending the board *is* defending the buff.
- **It buffs towers because towers are the one board presence that cannot be deployed
  away.** They are the natural anchor for an aura, and they are the half of the board every
  other faction ignores.
- **Its counterplay needs no hate cards.** Kill the Earth units and the whole board
  deflates, towers included. A board wipe zeroes Gaia the way it zeroes Void's Gap.

**Gaia is the structural inverse of Hel.** Hel wants its units to die — `Toll` refunds
energy from a death. Gaia's every death makes everything else weaker, and its second
signature *spends* energy on a death to salvage it. Same trigger, opposite direction.

**Its arc is the inverse of Void's.** Void is strong early and its keyword expires by
design as the economy outgrows it. Gaia is weak early — one unit is +1/+1, nearly nothing —
and compounds, because Earth accumulates through card text while the aura multiplies it
across a widening board.

---

## Keywords

| Keyword | Effect |
|---|---|
| **Earth N** | *(Gaia signature)* A printed stat. Your board's Earth total grants **+1 max HP and +1 damage per point** to all your units and both your towers. |
| **Essence N** | *(Gaia signature)* When this unit dies, if you have N energy in your pool, you may pay it to transfer this unit's Earth and attached energy to the nearest living friendly unit on the same board. |

Gaia's two signature slots are **full**. Like every faction it may also print the shared
keywords in `CLAUDE.md`, chosen per card for flavour rather than as part of the faction's
identity.

### Earth — the aura

`Earth N` is printed on a unit. The **board total** is the sum of Earth across all your
living units, and that total is an aura applying to **all your units and both your towers**
at **+1 max HP and +1 damage per point**.

**It is live, not accrued.** This is the decision that makes the mechanic safe. An earlier
draft had Earth accruing permanently into the towers each turn; that is an engine for the
tower-stall failure `CLAUDE.md` names as its most urgent open question, and it has no
counterplay — damage already dealt cannot be undone. A live aura shrinks the moment a
holder dies, which means:

- Tower max HP granted by the aura can go **down**. This is the only place in the game a
  tower's max HP falls.
- The opponent's targeting decision gets sharper: killing the biggest Earth body is a
  board-wide debuff, not just a removal.

**Earth growth is card text, not keyword text.** The keyword defines the aura and nothing
else. Individual cards gain Earth however they print it — on attack, on being damaged, via
an ability, or derived from a live value such as attached energy. This is the same
arrangement `Toll` has in Hel: one printed number, wildly different cards exploiting it.

**The rate is the sanctioned rule-breaker, and it must be additive.** Cards may raise the
+1/+1 by printing *"Earth grants +2 instead of +1."* They may **never** multiply the Earth
total. The aura is linear across six things (four units, two towers), so a multiplier on it
is exponential — at 10 Earth a doubling card is worth +60 stat points across the board.
Additive rate changes scale with the same linearity the rest of the mechanic has.

### Essence — the funeral

`Essence N` is a **death trigger with a pool cost**, prompted at the moment of death.

> When this unit dies, if you have N energy in your pool, you may pay it to transfer this
> unit's **Earth and attached energy** to the nearest living friendly unit on the same board.

Four rules, each load-bearing:

- **The energy must already be banked.** This is the whole point of the cost. Gaia is the
  only faction with a reason to hold pool energy *defensively*, which is design principle
  #2 ("spend or save") pointed at a case no other faction has. It also self-limits against
  a board wipe: several units die at once and you can only afford one or two funerals.
- **Per-board, and it fizzles on an empty board.** No rule in this game crosses boards.
  Letting Essence cross would make it best at exactly the moment it should fail — when the
  board it was defending has been cleared.
- **Only to a survivor.** In a batched death, Essence cannot chain through units that are
  also dying in the same resolution.
- **It carries attached energy, which is the faction's biggest rule-break.** `CLAUDE.md`
  states attached energy is lost when a unit dies, and that rule is what makes charging a
  unit a genuine risk. Essence is the exception, and it is priced: you pay pool energy, you
  must have foreseen the death, and the rescued energy lands on a body that can also die.
  Gaia has no ramp, so without this the pool cost would be unpayable in practice.

**The gradient this produces is the reason it is a good keyword.** Essence is worth paying
on a charged, high-Earth body and usually not worth paying on chaff — so it is a decision
every time rather than a reflex.

---

## Interactions with existing rules

### Rise

A risen unit **benefits from the aura normally** — it is a living unit, so it receives
+1 max HP and +1 damage per point of board Earth like anything else. Returning "at half HP"
means half of its *printed* max, with the aura's bonus applying on top.

**Its own Earth contribution resets to the printed value.** Earth it had *grown* through
card text is lost, exactly as attached energy is. Rise restores **the card, not the
history** — which is what `Unit.make_risen()` already does by rebuilding from `CardData`,
so the rule and the engine agree without special-casing.

The alternative (preserving grown Earth) would make Rise plus an Earth-growth card a genuine
engine: die, keep the accumulation, return, grow further. That is the shape that ends up in
Open Questions three weeks later.

**Essence may be paid on a unit that is about to Rise**, and this is a real reward for
building the combo rather than an oversight. The energy and current Earth move to a
neighbour, then the body returns next turn at printed Earth. It is bounded because pool
energy was spent and `Rise` is spent on use.

**This requires an edit to `CLAUDE.md`'s `Rise` entry**, since Rise is a shared keyword and
the rule is not Gaia-specific.

### Towers

The aura grants tower max HP and tower damage, both of which already exist on `Board` as
`tower_max_hp` and `tower_damage_bonus`. The hard line from `CLAUDE.md` is untouched:
**no Gaia card raises the rate at which a tower hits structures.** Towers reach an enemy
tower or throne only through the existing quarter-rate rule, and the aura does not lift that
quarter, waive the minimum-1 floor, or let a tower hit a structure past a living unit.

Aura-granted max HP falling when an Earth unit dies must **clamp current HP downward
without killing the tower** — a tower cannot die from the aura shrinking. Recorded as an
open question below, with "clamp, never kill" as the recommendation.

---

## The Economy

**Damage budget: below the standard 12-per-energy curve**, in the same way Void's is. This
is not a tax — **the aura *is* damage.** Every point of Earth is +1 on every attack from
every unit and both towers, so a board at 8 Earth is adding 8 to six different sources.
Printed attacks are priced knowing that, which is what stops Gaia's ceiling from being
absurd once the board fills.

**HP: top of each stage's band** (`CLAUDE.md`: Basic 40–90, Stage 1 80–120, Stage 2
110–175). Tanky is the identity and the aura adds max HP on top, which is why the attacks
are cheap.

**The Earth curve:** roughly **1 Earth on a Basic, 2 on a Stage 1, 3 on a Stage 2.** A full
board of four evolved units is 8–12 Earth, so a **+8/+12 aura** at the printed rate. Cards
that *grow* Earth print less of it up front.

### The three named cards

| Card | Shape |
|---|---|
| **Makeshift Tower** | Basic. A unit that **auto-fires** at the enemy unit across from it at end of turn — free, no energy, no queueing. Gains **+5 max HP per round** like a real tower. |
| *(the attached-energy card)* | Its `Earth` equals its **attached energy**, live and continuous. |
| *(the rate-breaker)* | Raises the aura to **+2/+2**, additively. The build-around. |

**Makeshift Tower** is a unit in every other respect: it shields the structures behind it,
it receives the aura, it can be retreated, and — the entire cost of the card — **an enemy
attack may name it as a target.** A real tower is only reachable once a board is cleared;
this one is killable the turn it lands. That trade is what pays for a free repeating
attacker in a game whose core rule is *energy only buys attacks*, so its damage stays small
and the Earth on it is the reason to run it.

**The attached-energy card** welds Gaia onto the pool-versus-attached decision `CLAUDE.md`
calls the game's central skill expression. Charging it grows the aura; losing it costs the
energy *and* the aura contribution at once. It is the prime `Essence` carrier — the card
most worth paying a funeral for.

Read as **`Earth = attached energy`, live and continuous**, not as an attack that banks
Earth permanently. The banking version compounds without limit: attacking does not spend
attached energy, so the same 4 energy would grant +4 Earth every turn forever.

---

## Open Questions

- **Does the aura's max-HP grant shrinking ever kill a tower?** Recommendation: **no** —
  max falls, current HP clamps to it, the tower survives at 1 if need be. A tower dying
  because a unit died two boards away is a feel-bad with no counterplay, and it would make
  Gaia's own aura a liability against its own structures.
- **Does the aura apply to Makeshift Tower's auto-fire damage?** Recommendation: **yes** —
  it is a unit, and the aura reads "all your units." Worth stating explicitly because the
  card is deliberately tower-shaped and the reader will wonder.
- **How many rate-breakers may stack?** Two copies of a +2/+2 card is +3/+3 per point,
  which at 10 Earth is +30 across six things. Additive keeps it linear, but the base set
  should probably hold **one** such card and playtesting decides whether a second is safe.
- **Is Gaia's early game too weak?** One Basic is +1/+1 — genuinely nothing. The faction
  needs to survive to the midgame to do anything, and it has no ramp. Watch whether Gaia
  simply loses to Void, which attacks the energy Gaia must bank for `Essence`.
- **Does Gaia worsen the tower-stall risk anyway?** The live aura is the guard, but Gaia
  is still a tanky faction that buffs towers, and `CLAUDE.md` names stall as the game's most
  urgent open question. This is the first thing to measure once cards exist.
- **Is `Essence` a feel-bad prompt at high frequency?** It fires on every death of an
  Essence body and interrupts damage resolution to ask a question. If a Gaia board wipe
  produces four consecutive prompts, the UI needs a "decline all" affordance.

---

## What This Spec Does Not Cover

Card lists, evolution lines, the energy card, supports, sample decks, and AI heuristics.
Those come after this design is approved, in the same order Heaven and Void were built.
