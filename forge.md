# Forge — Faction Design

> Read `CLAUDE.md` first for core rules, board geometry, and the energy economy.
> `Consume`, `Windfury`, `Retribution`, and `Rise` are **shared keywords** defined
> there. This file covers Forge's two signatures, its HP-and-bodies economy, and
> its cards.

**Domain:** Fire, smithing, the primal.
**Verb:** Kill.
**One-line identity:** *Everything is fuel.*

**Status: built, and expanded to full parity on 2026-08-16.** 63 cards in
`data/cards.json` — an energy card, 48 units in thirteen chains plus five singles, ten
supports, three Tools and a tower support. That is level with Gaia's 63 and Heaven's 59,
against the 19 Forge originally shipped with.

**Nineteen payoff ops** are implemented in `GameState` — the original nine, plus the ten
the expansion built out of this file's own catalogue (see *Stoke Payoffs*, where each is
now marked as implemented rather than designed). Seven sample decks ship (`White Heat`,
`Scrap Line`, and the expansion's `Second Wind`, `Burning Line`, `Nothing Holds`,
`Bank the Heat`, `Standing Heat`). Verified by `ForgeTest.gd` (143 assertions) alongside
the fifteen other harnesses, all green.

**The expansion's organising rule was one mechanic per chain.** Forge's first 13 units
read as five chains but only three ideas, because nine of the payoffs catalogued below
were designed-but-unimplemented — so any new chain built on the shipped ops was forced to
reprint `stoked_bonus_damage`. Building the missing ops first is what let each new chain
own something: see *The chains* at the end of this file.

**Not built:** `Windfury`, which is still documented-but-unimplemented game-wide — see
*The Windfury Constraint*. It is deliberately not required: Forge's multi-attack identity
is carried by `stoked_extra_attack`, a *conditional* grant on a Forge body, which this
file already preferred on the grounds that it sidesteps the Judgment constraint.

**No number below has been playtested by a human.**

---

## Why Forge Exists

`CLAUDE.md` named the gap: the four built colors are **all cold and cosmic**, and the
set has nothing warm or aggressive. Forge fills the aggro slot and completes a
Norse-flavored cosmology alongside Hel.

But "aggro" needs a mechanical meaning, and in this engine it is not the obvious one.

**Cards are free to play, so cheap bodies cannot be an identity.** Every faction
deploys for free and the board caps at 4 — Hel is *already* the disposable-bodies
deck. The only structurally available meaning of aggression here is **acting more
often, and sooner, than your energy should allow**.

So Forge's answer is not lower costs. It is **a different currency**.

Every other faction pays the standard price: pool energy moves onto a unit, and that
attack is free every turn afterward. That annuity is the engine's core bargain — you
buy an action once and own it forever. Forge declines the bargain. Its cards are cheap
in energy because they charge in **HP, in attached energy destroyed, and in bodies**,
none of which pay out over time. Forge spends principal where every other faction
spends interest.

That is what makes it fast and what makes it lose. A Forge deck that connects has
converted its whole board into damage; a Forge deck that stalls has nothing left to
convert.

---

## What Forge Does That No Other Faction Can

| Faction | Pays with | Gets back |
|---|---|---|
| **Hel** | Bodies dying | Energy (`Toll`) — death is *income* |
| **Heaven** | Discrete charges | Time — a death postponed |
| **Void** | Fragility | The opponent's energy |
| **Gaia** | Surviving bodies | A live board-wide aura |
| **Forge** | **HP, attached energy, and its own units** | **Immediate damage, at once** |

The distinction from Hel is the one to hold, because both factions feed units into a
grinder. **Hel's deaths are a trigger; Forge's are a cost.** Hel wants a unit to die
because dying is when it pays — the refund arrives whether the opponent kills it or you
do. Forge wants a unit to die *right now, on your terms*, because the death is the
payment for something happening this turn. Hel is paid for the past; Forge pays for the
present.

Concretely: a Hel body left alone still eventually pays its `Toll`. A Forge body left
alone has done nothing.

---

## Keywords

Forge claims **two signatures**, matching every other faction's allowance.

| Keyword | Effect |
|---|---|
| **Stoke N** | *(Forge signature)* **Ability, free, once per turn.** Deal N damage to this unit. It has **stoked** until end of turn. Other lines read that state. |
| **Scrap** | *(Forge signature)* **An ability cost.** Destroy another unit you control to activate this line. |

Neither is an alternative way to pay energy. **Stoke sets a state that other cards
read; Scrap is a cost an ability charges.** See both sections below.

Forge additionally prints the shared keywords widest in the game:

- **`Consume N`** — the third currency, and the one that already exists. Forge prints
  it on more cards than the other four factions combined, and steeper.
- **`Windfury`** — Forge is the multi-attack faction in practice. See the constraint
  below, which is not negotiable.
- **`Retribution`** — thematically apt (a hot forge burns whoever strikes it) and
  already shared.

---

### Stoke N — the primary

> **Stoke N.** *Ability, free, once per turn.* Deal N damage to this unit. It has
> **stoked** until end of turn.

Stoke is **an ability that sets a state**, not a way to pay for something. Activating it
is the whole action: you lose the HP, and the unit is now flagged as having stoked. Cards
then *read* that flag — attacks that get better, abilities that trigger, supports that
care.

That separation is the entire mechanic. The HP is spent up front, **before you know what
you will need it for**, and everything that pays you back is a separate line that has to
be on the board already.

Four rules:

- **The flag is per-unit, and it lasts until end of turn.** A payoff reads *"if this unit
  stoked this turn."* Unit A stoking does **not** turn on unit B's attack.
- **A card may read another unit's flag, but only if it prints that it does.** Board-wide
  Stoke readers are a designed rarity — the rule-break, not the baseline — and they say so
  in their own text. This is what keeps the default cheap to reason about while leaving the
  combo faction available as a deliberate card.
- **Stoke damage is unpreventable.** `Sanctuary` does not absorb it and `Resist` does not
  reduce it. It is a cost the unit pays, not damage from a source — see below.
- **Stoke may kill the unit paying it.** The HP loss is real and lethal Stoke is legal. A
  unit that stokes itself to death has still stoked, so anything that already resolved off
  the flag stands.

**Why it is an ability rather than an alternative cost.** The first draft of this faction
made Stoke a way to pay an attack's energy cost — *pay 3 energy or pay 20 HP, pick one.*
That produces a flat decision: you evaluate whether HP is cheaper than energy right now,
and the answer is nearly always the same within a given turn. As a **state** it produces a
sequencing decision instead, and one Stoke can turn on several different payoff lines,
which is what makes it a build-around rather than a discount.

**Why Stoke is unpreventable.** If Stoke ran the normal damage path, a `Sanctuary` body
would stoke **for free** once shielded and a `Resist 10` body would pay 10 less every time
— so the faction's central cost would be optional in exactly the matchups where Forge needs
its cost to be real. Making it a cost rather than damage keeps it honest in every matchup.
Cards may still print an interaction (*"prevent all Stoke damage this turn"*), which is the
rule-break working as intended rather than a hole in the keyword.

**N varies by unit, and that is a balance axis.** A Basic prints `Stoke 20`; a Stage 2 may
print `Stoke 50`. The anchor is:

> **20 HP stoked ≈ 1 energy of value.**

That rate is derived rather than invented. Attached energy is an *annuity* — pay once, fire
free every turn — while HP is spent for good and never comes back above printed max. So
Stoke has to buy visibly less per use than energy does, and 20-per-energy puts a Basic's
Stoke at roughly one energy of benefit and a big Stage 2's at three.

**Payoffs should scale with N, or the cheapest stoker wins.** If every payoff reads as a
binary *"if this unit stoked,"* then stoking 50 is strictly worse than stoking 20 and every
deck runs the smallest body that turns the flag on. Two answers, both used:

- **Amount-scaling payoffs** — *"+1 damage per 2 HP stoked this turn."*
- **Thresholds** — *"if this unit stoked 40 or more this turn, ..."* Big numbers unlock the
  payoffs that break board geometry; small ones only reach the ordinary buffs.

**Stoked is a state cards may care about directly.** Because the flag exists independently
of what it paid for, a card may read it without any attack involved — *"units that stoked
this turn have +10 damage,"* *"heal this unit for the HP it stoked."* That last one is not a
cost eraser: the unit still **counts as having stoked**, so every other payoff on it stayed
on. Stoke is therefore a condition you may *want* to be in, not only a price you pay.

**Why it self-limits with no card text.** No card in this game fully heals a unit, every
heal is a flat number, and the board caps at 4. A unit spending HP is on a clock the
opponent does not have to interact with. Because the HP curve is Basic 40–90 / Stage 1
80–120 / Stage 2 110–175, a big body carries real fuel and a small one gets two or three
uses — the cost scales itself against the body paying it.

---

### Scrap — the sharper, rarer version

> **Scrap.** *An ability cost.* Destroy another unit you control to activate this line.

Where Stoke spends a body gradually, Scrap spends one outright. It is a **cost an ability
charges** — the same slot `Consume N` occupies, and priced the same way: an ability may
carry it, and it charges every single use, which is what keeps a free once-per-turn line
from becoming a permanent engine.

- **Another unit — never itself.** A line that ate its own body would resolve and then
  have nothing to have resolved from, and it collapses into "sacrifice this for damage,"
  which is a different and worse card.
- **The scrapped unit is destroyed, not damaged.** It **dies**, so everything that reads
  a death reads it: `Toll` refunds, `Rise` returns it, `Essence` may pay for it, its
  attached energy is lost, and its Tool is discarded. Forge does not get a private kind
  of death.
- **That is the deliberate multi-faction door.** Forge/Hel is the obvious pairing — Scrap
  a `Toll` body and you are paid for the fuel — and it is *supposed* to be good. It costs
  two colors of energy in a 60-card deck, which is the price already established for
  "stronger effects, never higher raw damage."
- **Scrap is rare.** It appears on roughly a third as many lines as Stoke. Destroying a
  body is a much larger cost than a slice of HP, so the effects it buys are correspondingly
  larger, and a faction where every card eats a unit runs out of board by round 3.

**Scrap is why Forge is not just "Hel that hits harder."** Hel's bodies are *paid for* by
dying. Forge's bodies are **ammunition** — the value is in choosing the moment.

---

## Stoke Payoffs

The catalogue of what a payoff line may do. Stoke sets a state; **these are what read
it.** Each is priced by the anchor above — a `Stoke 20` body's payoff is worth ~1 energy,
a `Stoke 50` body's ~2.5.

Everything here reads *"if this unit stoked this turn"* unless it prints otherwise.

**Each row now names the op that implements it.** All nineteen are live in `GameState`
as of the 2026-08-16 expansion; the single exception is the ramp row, marked **not
printed**, which stays excluded for the reason given under *The one class that needs a
hard limit* and is refused by both generators rather than left to authorial restraint.
Every op is covered by an assertion in `ForgeTest.gd` that was **verified by putting the
bug back** — an op that silently does nothing passes every structural check, which is the
failure shape this project's decision log already carries three times.

**Economy** — the class that makes Forge more than a damage deck

| Payoff | Note |
|---|---|
| This attack costs no energy — `stoked_free_attack` | The clean one. Best on *expensive* attacks, so it pushes Forge toward big swings rather than chip. |
| Attach N energy to this unit — **not printed** | Self-ramp. Converts HP into a permanent charge — how Forge reaches a Stage 2 attack early. **The most dangerous class; see below.** |
| This unit's attacks cost 1 less this turn — `stoked_cost_reduction` | Weaker than free, but stacks across a multi-attack turn. |
| Your pool does not decay this turn — `stoked_no_decay` | A genuine rule-break on the game's central tax. |

**Tempo**

| Payoff | Note |
|---|---|
| This unit may attack twice this turn — `stoked_extra_attack` | `Windfury` as a *conditional* rather than a printed keyword — more interesting than static Windfury, and it sidesteps the Judgment constraint because the condition sits on a Forge body. |
| This attack resolves immediately instead of at end of turn — `stoked_immediate` | Breaks the turn structure. Kills a blocker *before* the rest of the volley resolves, which interacts heavily with volley ordering and no-overkill. Powerful; keep rare. |

**Reach and geometry** — where the best cards live

| Payoff | Note |
|---|---|
| This attack ignores shielding — `stoked_ignore_shield` | Straight to the tower past living units. Heaven's `The Gate Opens` already does this; it is Forge's closer. |
| This attack hits both enemy boards — `stoked_both_boards` | Breaks the per-board rule. Enormous — wants a Stage 2 and a threshold. |
| This attack hits every unit on the target board — `stoked_sweep` | Sweep. Pairs nastily with no-overkill: clear the front and everything behind is exposed to later attacks. |
| This attack also hits the tower behind its target — `stoked_also_tower` | Softer reach — splashes past the shield without bypassing it. |

**Damage shape**

| Payoff | Note |
|---|---|
| Deal the damage again — `stoked_double` | Clean, obvious arithmetic at the table. |
| +1 damage per 2 HP stoked this turn — `stoked_scale_damage` | **The amount-scaling answer.** Makes a large `Stoke N` worth printing. |
| This attack cannot be prevented — `stoked_unpreventable` | Ignores `Sanctuary` and `Resist` — the printed answer to shield decks. |

**Self-referential** — these make Stoke a build-around

| Payoff | Note |
|---|---|
| Heal this unit for the HP it stoked — `stoked_heal_back` | **Not a cost eraser.** The unit still counts as having stoked, so every other payoff stayed on. Only worth printing *because* other cards read the state. |
| Draw a card — `stoked_draw` | Forge burns through hand fast. |
| This unit may stoke twice this turn — `stoked_twice` | Breaks once-per-turn. Doubles every amount-scaling payoff. |
| Stoke damage also hits enemy units — `stoked_cleave` | **Stoke as the weapon itself** — the burn splashes outward. The most flavour-mechanic-agreeing card in the set. |

### The one class that needs a hard limit

**Ramp payoffs — *"attach N energy to this unit"* — touch the economy rather than the
board, and they are the one thing here that can break pacing.**

Attached energy is permanent, immune to decay, and feeds Void's Gap. A card that reliably
converts 20 HP into 3 attached energy *every turn* is an income source that does not obey
`t + 1` — and one-energy-card-per-turn is the game's central pacing dial. Walking around it
with a repeatable ability is how a faction accidentally becomes a ramp deck.

So ramp payoffs are **rarer and smaller than the damage payoffs**, and the safer form is
always the one that expires: *"this attack costs no energy"* is a one-turn discount that
vanishes, while *"attach 3"* is a permanent resource. Prefer the discount; print the ramp
deliberately and at most once or twice in the faction.

### Thresholds

A payoff may require a **minimum amount stoked** rather than the bare flag:

> *If this unit stoked 40 or more this turn, this attack ignores shielding and hits both
> boards.*

Thresholds are what make varying `Stoke N` sing. Small stokers turn on ordinary buffs;
only a body that commits real HP unlocks the payoffs that break board geometry. They are
also the natural home for the strongest effects, because the cost is visible in the
requirement rather than hidden in the pricing.

---

## The Support Engine

**This is where Forge's aggression actually lives, and it is the faction's most
distinctive structural feature.**

Forge prints **faction-locked supports** — Forge-colored cards, legal only in a deck
running Forge energy — that are substantially above the neutral support power band,
and pay for it in HP and bodies rather than in pool energy.

This is not a new card type. Faction-colored supports already exist (Void has 4, Gaia
has 5 including a Tool and a tower support). Forge simply leans on them hardest and is
the first faction whose *identity* is carried by its support suite rather than by its
units.

### Why the neutral band cannot do this

`CLAUDE.md`'s support band caps a free support at **roughly one turn of tempo**, and
that cap exists because **all 43 neutral supports are legal in every deck**. A powerful
free neutral support does not make one faction aggressive — it raises the floor for all
eighteen existing decks at once and gives Forge no identity whatsoever.

The band's real constraint is therefore not "supports must be weak." It is **"cards
every deck can run must be weak."** A Forge-locked support is bought with a deckbuilding
commitment — you are running Forge energy, and a 60-card deck cannot run every color —
which is a real cost the neutral cards never pay.

### The four rules Forge supports obey

1. **Faction-locked.** A Forge support requires Forge energy in the deck. It is not
   splashable, and that restriction is what it pays with.
2. **Priced in HP or bodies, not only in pool energy.** A Forge support may print
   `Stoke N` or `Scrap` as its cost, exactly as its unit lines do. This is the whole
   point of the design: the support is cheap in energy *because* it is expensive in
   flesh.
3. **A Forge support may exceed the neutral power band by roughly one step per unit of
   alternative cost paid** — the same exchange rate `CLAUDE.md` already grants priced
   supports for pool energy. The mechanism is not new; the currency is.
4. **The damage line still holds, and it holds hardest here.** A Forge support may
   **not** sell damage more efficiently than an attack does. This is the one rule the
   whole faction is most likely to break by accident, so it is stated as an absolute:
   Forge supports buy *reach, speed, and removal of conditions*, never raw
   damage-per-energy above the attack curve.

### Why rule 4 is the binding constraint

`CLAUDE.md`: *"Supports must not hand out raw damage efficiently enough to compete with
attacks — that's the one line to hold."* An attack's cost stays attached and pays out
every turn; a support's is spent for good, which is normally what keeps supports honest.

**Forge breaks that asymmetry**, because a Stoke-paid attack does *not* build an annuity
either — it charges every time. So for Forge specifically, "attacks pay out forever and
supports don't" stops being true, and the natural brake on support damage disappears.

The replacement brake is explicit: **a Forge support's damage per unit of cost must sit
visibly below the attack curve regardless of currency.** Forge supports are for
*enabling* damage — an extra attack, a body converted to reach, a condition removed —
not for dealing it directly at a better rate than swinging.

---

## Forge Energy

**Forge is its own energy color**, the fifth. It follows every existing rule: one energy
card per turn, `t + 1` energy on turn `t`, exempt from the 4-copy limit, and it decays in
the pool at 20% like anything else.

Two consequences worth stating:

- **Forge is not a low-energy deck.** Alternative costs mean Forge can *act* on a turn it
  could not otherwise afford, not that it needs less energy overall. Its Stage 2 attacks
  sit in the same 8–20 band as everyone's. A Forge deck that runs light on energy cards
  because "Forge pays in HP" has misread the faction — it will burn its board down to fire
  attacks it could have paid for.
- **The colorless split applies unchanged.** Forge attacks print a colored half and a
  colorless half by total cost, per `tools/split_colorless.py`. Nothing about Forge changes
  that rule.

**Palette:** Forge is a warm orange-red — the first warm color in the set, against Hel's
purple, Heaven's gold, Void's slate, and Gaia's green. **Both halves already exist in the
code**: `Theme.gd` carries the full `deep`/`base`/`bright` ramp (`7a3312` / `e07a3c` /
`ffb37a`) and a flat `FACTION_COLORS` entry, and `EnergyIcon.gd` draws Forge's token mark
as a leaning-teardrop **flame**. So the energy card's art and color need no new work — they
were reserved when the four reserve colors were given marks.

---

## The Damage Curve

Forge sits on the **standard** curve — 7/8/9 damage per energy by stage — for lines paid
with **energy**.

Non-energy costs are priced separately:

| Cost | Rate |
|---|---|
| **Consume N** (existing, unchanged) | ≈ 20 damage per energy consumed |
| **Stoke N** | **20 HP stoked ≈ 1 energy of value** — the payoff line is worth about `N / 20` energy |
| **Scrap** | Priced per card, not by formula |

**How to price a Stoke payoff.** Stoke does not buy damage directly — it sets a state, and
a *payoff line* reads it. So the question is always *"what is this payoff worth, and does
the Stoke that turns it on cost about that much?"*

Work it in energy. A unit with `Stoke 20` is spending ~1 energy of value, so its payoff
should be worth ~1 energy: **+7 to +9 damage** on the stage curve, or a 1-energy discount,
or a comparable effect. A `Stoke 50` body is spending ~2.5, so it may unlock something worth
2–3 energy — a doubled attack, a threshold effect, a geometry break.

**Why not price Stoke as raw damage-per-HP.** An earlier draft set Stoke at *1.5 damage per
HP paid*, which was a coherent number for the alternative-cost design it belonged to and is
meaningless now: Stoke no longer buys an attack, so there is no damage figure to divide.
Pricing through **energy** instead works because energy is the unit everything else in the
game is already priced in, including the stage damage curve.

**The rate must stay visibly worse than paying energy, and it does.** Energy attached to a
unit is an annuity — pay once, fire free every turn after. Stoke charges every single time,
and the HP never comes back above printed max. So a Forge unit that stokes every turn is
paying repeatedly for what another faction bought once, which is the aggro contract stated
in resource terms and the reason Stoke can be generous per use without being better.

**Why Scrap has no formula.** The value of a destroyed body varies enormously — a 40 HP
chaff Basic and a fully-charged Stage 2 are not the same payment, and a formula would either
overprice the chaff or make sacrificing the Stage 2 mandatory. Scrap lines are priced
individually against *what a cheap body is worth*, on the assumption that a Forge player
scraps their worst unit. A card that becomes degenerate when you scrap your best unit is
mispriced and should be cut rather than errata'd.

---

## The Brakes

Energy denial was Void's named design risk; **self-destruction is Forge's**. A faction
that kills its own board can be built into a deck that wins before the cost lands, which
is the classic aggro failure. Four brakes, three of which need no card text:

**1. Healing cannot bail it out.** No card in the game fully heals a unit — every heal is
a flat number, capped, and `Grave Warden's Oath` at 100 for 3 energy is the ceiling.
Neutral healing exists, so a Forge deck *can* run it, but flat heals on a body spending 40
HP a turn are a delay, not a solution. This is an existing rule doing free work.

**2. The board caps at 4.** Scrap eats slots, and slots are the scarcest thing in the game.
A Forge deck that scraps twice in a turn is playing on two units against an opponent's four,
and `CLAUDE.md`'s shielding rule means a thin board is a board whose tower is about to be
exposed.

**3. Forge has no recursion.** It does not get `Rise`, it does not get Hel's discard
recovery, and it prints no card that returns a scrapped unit. Once a body is spent it is
gone. Forge/Hel exists precisely so that a player who *wants* recursion pays two colors for
it.

**4. The tower clock runs against Forge too.** A Forge deck that fails to close is a deck
with a burned-down board facing a tower that grows +3 damage a round. Forge's losing
condition is real and it arrives on schedule.

**The brake Forge deliberately does NOT get:** a per-turn limit on Stoke or Scrap. A
"once per turn" clause would make the faction's central decision into a formality — you
would simply always take the one use. The tension is *how much* to spend, and that only
exists when spending is unbounded.

---

## The Windfury Constraint

`CLAUDE.md`: **`Windfury` must not appear on any unit that holds or grants `Judgment`.**

Forge is the faction that prints Windfury widest, so it is the faction most likely to
violate this — and the violation would arrive through a **multi-faction Forge/Heaven card**
rather than through a mono-Forge one. Stated explicitly so it is checked at authoring time:

> **No Forge/Heaven card may carry `Windfury` and `Judgment` on the same body, and no
> Forge card may grant `Windfury` to a unit that could be holding `Judgment`.**

A board-wide "your units gain Windfury" effect is therefore **not printable in Forge**,
because it would grant it to Heaven bodies in a two-color deck. Forge's Windfury is always
on the printed card.

Windfury is also currently **unimplemented** — it is documented in the shared keyword table
and no card uses it. Building Forge means building Windfury, which is a second queued attack
slot on `Unit`. That is the largest single piece of engine work the faction requires and
should be planned as its own task.

---

## Interaction Notes

Decided up front, because each would otherwise be discovered mid-build:

**Stoke is a cost, not an incoming damage event.** This is the single sentence the whole
keyword hangs on. `Sanctuary` does not absorb it, `Resist` does not reduce it, and
`Retribution` does not recoil — there is no attacker to recoil at. Anything phrased *"when
this unit takes damage"* does not see Stoke.

**Stoke may still kill, and the death is an ordinary one.** A unit that stokes itself below
0 dies through the normal path, so `Toll` refunds, `Rise` returns it, and `Essence` may pay
for it. Forge does not get a private kind of death. Anything that already resolved off the
flag this turn stands — the unit stoked, and dying afterward does not undo that.

**`Judgment` does not save a unit from lethal Stoke.** Judgment's defensive half reads *"when
this unit would die"* from damage; Stoke is a cost the controller chose to pay, and a
reprieve that refunds a voluntary cost is a loop. A Forge/Heaven body may still stoke — it
just cannot stoke past its own death and survive.

**Scrap and `Toll` / `Rise` / `Essence` all fire.** A scrapped unit died, so every death
trigger reads it. This is the opposite of `CLAUDE.md`'s retreat rule (*retreat does not
trigger death effects*), and the distinction is exactly right: retreat is the alternative
to dying, and Scrap **is** dying. This is what makes Forge/Hel a deliberate pairing.

**A retreating unit's Stoke flag is irrelevant.** Retreat returns the card to hand healed,
and per-turn state does not survive that — same as `Rise` and evolution. Noted only because
"stoke, then retreat to undo the HP loss" is the obvious thing a player will try, and the
answer is that it works: retreat heals the unit. The cost is a turn of board presence and
the lock, which is the price retreat already charges everyone.

---

## Open Questions

- **Is 20 HP per energy the right Stoke anchor?** It is the faction's single most important
  number: it decides whether Forge is an aggro deck or a combo deck that converts a Stage 2
  into a one-turn kill. Derived from the annuity argument rather than measured, so it wants
  a pass against the HP bands before the card set is finalised. The specific thing to watch
  is the top end — a 175 HP body holds ~8 energy of Stoke fuel, which is more than most
  decks' whole pool.
- **Does making Stoke unpreventable cost the multi-faction pairings anything?** Decided:
  Stoke ignores `Sanctuary` and `Resist`, because a shielded body would otherwise stoke for
  free and the faction's central cost would be optional in exactly the matchups where it
  needs to be real. What that gives up is a natural Forge/Heaven and Forge/Gaia synergy, so
  those pairings now need a *printed* reason to exist rather than getting one for free from
  the keyword interaction. Worth checking that at least one card supplies it.
- **Does Scrap need a floor on what may be scrapped?** As written you may scrap a 40 HP
  chaff Basic, which is the assumption the pricing rests on. If Forge ends up running four
  copies of the cheapest possible body purely as Scrap fodder, the faction has a
  "sacrifice-token" subtheme that was not designed and should be either embraced or blocked.
- **Is a faction-locked support suite a precedent worth setting?** Forge is the first
  faction whose identity is carried by supports. If it works, Hel/Heaven/Void/Gaia arguably
  all want more faction supports; if it does not, Forge is an outlier with a card class the
  others do not use. Worth watching rather than deciding now.
- **Does Forge make Toll Engine worse or better?** Toll Engine is the current balance
  outlier (9-0 vs Barrow Wall). Forge/Hel is a natural pairing that makes Toll bodies into
  ammunition, which could either be the deck that finally beats it or a straight upgrade to
  it. Flagged because it is the most likely place Forge breaks the existing meta.
- **Nothing here has been playtested, and the existing four factions have not been either.**
  Every number above is a design-time guess against an AI-validated card pool. `CLAUDE.md`
  lists human playtesting as an outstanding step for the current four.

---

## The Card Set

Five chains, one idea each — the same shape Gaia's five were built on. Generated by
`tools/add_forge_faction.py`, which **enforces the rules rather than trusting the
author**: HP bands, the two-line rule, `retreat = HP/40`, costs derived from damage on
the per-stage curve, Stoke only ever on an ability and never more than the body's own
HP, no new round-1 openers, no ramp payoffs, and only ops the engine actually
implements.

| Chain | Idea | Members |
|---|---|---|
| **Cind** | The big stoker. Stoke 20/30/50, threshold payoffs. | Cindspark → Cindbrand → Cindpyre |
| **Slag** | The cheap stoker. Stoke 10, and a free attack off the flag. | Slagash → Slagkiln |
| **Grist** | The scrapper. The Forge/Hel door. | Gristgnash → Gristforge → Gristsmith |
| **Emb** | The cleaver. Stoke splashes onto the enemy board. | Embash → Embkiln |
| **Quench** | The sustain body. Heals back what it stoked, and still counts as stoked. | Quenchwick → Quenchbrand → Quenchanvil |

**`Cindpyre` is the faction's closer**: *if this unit stoked 40 or more this turn, this
attack burns past living units and strikes the tower behind them.* A threshold plus a
shielding break — the two rule-breaks the design reserved for the top of the curve.

**`Quenchanvil` is the card the whole keyword is built around.** `The Long Temper`
stokes 50 and heals all 50 back, so the body is at full HP **and still counts as having
stoked** — every other payoff stayed on. That only works because the flag is separate
from what it paid for, which is the design's load-bearing decision.

### The expansion chains (2026-08-16)

Eight more chains, three pairs and five singles — 35 units, taking the roster to 48.
**The organising rule was one mechanic per chain**, because the first thirteen units
read as five chains but only three ideas: with nine of the catalogued payoffs still
unbuilt, every new body would have had to reprint `stoked_bonus_damage`. So the ten
missing ops were built first, and each chain then got one to own.

| Chain | Owns | Members |
|---|---|---|
| **Bellow** | `stoked_extra_attack` — conditional Windfury | Bellowwick → Bellowbrand → Bellowmaul |
| **Char** | `stoked_sweep` — the whole rank at once | Charash → Charkiln → Charpyre |
| **Scoria** | `stoked_unpreventable` — the anti-shield body | Scoriaslag → Scoriaforge → Scoriasmith |
| **Flux** | `stoked_no_decay`, `stoked_cost_reduction` — the economy | Fluxwick → Fluxbrand → Fluxanvil |
| **Tind** | `stoked_twice` + `stoked_draw` — the engine | Tindspark → Tindkiln → Tindpyre |
| **Drossal** | `Scrap` + `Consume`, printed steepest | Drossalgnash → Drossalkiln → Drossalsmith |
| **Anneal** | `Retribution` + Stoke — the wall | Annealash → Annealbrand → Annealanvil |
| **Ingot** | `stoked_immediate`, `stoked_both_boards` — the closer | Ingotspark → Ingotforge → Ingotpyre |

Plus **Cinderling** (cheap unpreventable), **Sootfall** (`stoked_also_tower`),
**Cokewright** (the discount, early), and five singles pitched below the chains so the
roster has a floor as well as eight build-arounds — uniform power across 48 units is what
makes creatures interchangeable.

**`Ingotpyre` is the new closer**, and it breaks the rule this file reserved for the very
top: at `Stoke 45` its attack strikes **both enemy boards**, which is the per-board rule —
the one that makes the two lanes independent fights — being deliberately violated. Each
board still resolves its own shielding chain, so it widens *which* board is reached and
never reaches past anyone's units.

**`Scoriasmith` is the card that answers an open question in this file.** Making Stoke
unpreventable cost Forge/Heaven and Forge/Gaia the synergy they would have got free from
the keyword interaction, and this file flagged that those pairings now need a *printed*
reason to exist. `Nothing Holds` is it: unpreventable damage plus a 15-point tower splash
on one swing, so a shielded wall neither absorbs the hit nor protects what is behind it.

**Two geometry breaks never stack on one line.** `_deliver_attack_damage` treats sweep,
both-boards and the shielding break as mutually exclusive rather than cumulative: an
attack that sweeps does not also strike a second board. Two rule-breaks on one card is a
card that should have been cut, not a stacking rule.

### The supports

Faction-locked, so they are bought with a deckbuilding commitment the neutral cards
never pay. `Bank the Coals` (heal 60 for 1) sits above the neutral healing ladder, which
is the room the lock buys — and every one of them buys **reach or sustain, never raw
damage**, because a Stoke-paid attack builds no annuity either and the usual brake on
support damage does not apply here.

### The AI

`AIPlayer._stoke_worth_it()` gates Stoke on three things, and the first is the one a
naive reading gets wrong: **Stoke pays nothing by itself**, so stoking a body with no
payoff line is pure self-harm. The default *"free abilities are always taken"* would have
burned the board down every turn. It also refuses to stoke a unit that would die to the
cost, and refuses to Scrap below three living bodies.

Measured over eight AI games immediately after: 10–28 Stokes per game in White Heat, no
stalls, 4–13 rounds. **That is not a balance reading** — the AI does not sequence
stoke-then-attack deliberately, does not aim thresholds, and has no Judgment or Sanctuary
heuristics for the decks it plays against.

**The expansion added two fixes and left one gap open deliberately.**

`_stoke_worth_it` scans a unit's *other* lines for something reading the flag, which was
right when every payoff sat on a later attack. The expansion put draw, the decay skip, the
extra attack slot, the second Stoke and the discount on the **ability itself**, which that
scan deliberately skips — so the AI refused to use cards whose whole point is the ability.
Those five ops are now checked on the ability too. `stoked_heal_back` is deliberately *not*
in that list: it refunds the cost and pays nothing on its own, which is exactly the no-op
case the check exists to catch.

`_queue_attacks` also skipped any unit that already had an attack queued, so the AI could
stoke, pay 40 HP for an extra attack slot, and then never use it. It now makes the
exception when `can_queue_extra()` is true.

**What is still open: the AI does not reach the threshold payoffs.** A probe over six AI
games found `stoked_sweep`, `stoked_both_boards` and `stoked_immediate` never firing — and
the *pre-existing* `stoked_cleave` and `Scrap` never firing either, which is what
identifies this as a heuristics gap rather than an engine defect. A separate probe that
plays each card as written, through `use_ability` and `queue_attack`, reaches **every one
of them**, so the cards are sound and the AI simply does not plan a stoke-then-threshold
turn. Balance readings for Forge are correspondingly weak, in the same way `void.md`
records that AI results are worth less for Void than for any other faction.

**Five games per deck over the expansion's five lists: 7–17 rounds, zero stalls, and every
deck won at least one.** That is a *functioning* check rather than a balance one — the same
distinction `TutorialWalkTest` draws between "valid" and "completable", since
`DeckStoreTest` proves a list is legal and says nothing about whether it plays.
