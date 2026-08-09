# Gaia — Faction Design

> Read `CLAUDE.md` first for core rules, board geometry, and the energy economy.
> `Rise`, `Retribution`, and `Resist` are **shared keywords** defined there. This file
> covers Gaia's two signatures, the aura, and its cards.

**Domain:** Life, growth, nature.
**Verb:** Fuel.
**One-line identity:** *The board is the buff.*

**Status: engine built, card set not written.** Design settled 2026-08-09; full spec in
`docs/specs/2026-08-09-gaia-faction-design.md`.

Both signatures and the shared `Resist` keyword are implemented and covered by
`GaiaTest.gd` (**124 assertions, run 2026-08-09**, alongside the seven existing harnesses,
all green):

| Built | Where |
|---|---|
| `Earth` as a live board-wide aura — units and both towers, +1/+1 per point | `GameState.earth_for()` / `effective_max_hp()` / `sync_tower_aura()` |
| Aura-aware healing and downward clamping that never kills | `heal_unit()` / `clamp_to_aura()` |
| `Essence N` — prompted, pool-paid, carries Earth and attached energy | `_try_essence()` in `_kill()` |
| `Resist X`, floored at 1, ordered after Sanctuary, including on recoil | `_apply_resist()` |
| Earth derived live from attached energy | `Unit.earth()` |
| The additive rate-breaker | `earth_rate()` |
| Makeshift Tower auto-fire and +5/round growth | `resolve_auto_fire()` / `grow_auto_towers()` |

**The card set ships: 19 cards** — an energy card, **13 units in five evolution chains**,
three supports, a tower support, and a Tool. All carry generated art. Two sample decks,
`Standing Stones` and `Deep Grove`, are in the starter collection (10 decks total).

**Not built:** `AIPlayer` heuristics beyond `grow_earth_target`. It does not value the
aura when choosing targets, will not protect Earth bodies, and will not hold pool energy
for `Essence`. **AI results are not a balance reading for Gaia** until those exist — the
same caveat Heaven and Void carry.

---

## Why Gaia Exists

Gaia is the only faction whose strength is a **live sum of what it has on the table**.
Every other faction's power sits on individual cards. Gaia's sits on the board as a whole,
rising and falling as bodies arrive and die.

That single property generates the entire faction:

- **It is tanky because it must be.** Tankiness is not flavour — the aura only exists while
  its holders live, so defending the board *is* defending the buff.
- **It buffs towers because towers are the one board presence that cannot be deployed
  away.** They are the natural anchor for an aura, and the half of the board every other
  faction ignores.
- **Its counterplay needs no hate cards.** Kill the Earth units and the whole board
  deflates, towers included. A board wipe zeroes Gaia the way it zeroes Void's Gap.

**Gaia is the structural inverse of Hel.** Hel wants its units to die — `Toll` refunds
energy from a death. Every Gaia death makes everything else weaker, and its second
signature *spends* energy on a death to salvage it. Same trigger, opposite direction.

**Its arc is the inverse of Void's.** Void is strong early and its keyword expires by
design as the economy outgrows it. Gaia is weak early — one unit is +1/+1, nearly nothing —
and compounds, because Earth accumulates through card text while the aura multiplies it
across a widening board.

**The design risk, named up front:** Gaia is a tanky faction that buffs towers, and
`CLAUDE.md` names tower-stall as the game's most urgent open question. See *The Brakes*.

---

## Keywords

| Keyword | Effect |
|---|---|
| **Earth N** | *(Gaia signature)* A printed stat. Your board's Earth total grants **+1 max HP and +1 damage per point** to all your units and both your towers. |
| **Essence N** | *(Gaia signature)* When this unit dies, if you have N energy in your pool, you may pay it to transfer this unit's Earth and attached energy to the nearest living friendly unit on the same board. |

Gaia's two signature slots are **full**. Like every faction it may also print the shared
keywords from `CLAUDE.md`, chosen per card for flavour rather than as identity.

### Earth — the aura

`Earth N` is printed on a unit. The **board total** is the sum of Earth across all your
living units, and that total is an aura applying to **all your units and both your towers**
at **+1 max HP and +1 damage per point**.

**It is live, not accrued.** This is the decision that makes the mechanic safe. An earlier
draft had Earth accruing permanently into the towers each turn; that is an engine for the
tower-stall failure `CLAUDE.md` flags, and it has no counterplay — damage already banked
cannot be undone. A live aura shrinks the moment a holder dies, which means:

- Tower max HP granted by the aura can go **down**. This is the only place in the game a
  tower's max HP falls.
- The opponent's targeting decision sharpens: killing the biggest Earth body is a
  board-wide debuff, not merely a removal.

**Earth growth is card text, not keyword text.** The keyword defines the aura and nothing
else. Cards gain Earth however they print it — on attack, on being damaged, via an ability,
or derived from a live value such as attached energy. Same arrangement as Hel's `Toll`: one
printed number, wildly different cards exploiting it.

**The rate is the sanctioned rule-breaker, and it must be additive.** Cards may raise the
+1/+1 by printing *"Earth grants +2 instead of +1."* They may **never** multiply the Earth
total. The aura is linear across six things — four units, two towers — so a multiplier on
it is exponential: at 10 Earth a doubling card is worth +60 stat points across the board.

### Essence — the funeral

`Essence N` is a **death trigger with a pool cost**, prompted at the moment of death.

> When this unit dies, if you have N energy in your pool, you may pay it to transfer this
> unit's **Earth and attached energy** to the nearest living friendly unit on the same
> board.

Four rules, each load-bearing:

- **The energy must already be banked.** Gaia is the only faction with a reason to hold
  pool energy *defensively* — design principle #2 pointed at a case no other faction has.
  It also self-limits against a board wipe: several units die at once and you can only
  afford one or two funerals.
- **Per-board, and it fizzles on an empty board.** No rule in this game crosses boards, and
  crossing would make Essence best at exactly the moment it should fail.
- **Only to a survivor.** In a batched death, Essence cannot chain through units that are
  also dying in the same resolution.
- **It carries attached energy, which is the faction's biggest rule-break.** `CLAUDE.md`
  states attached energy is lost when a unit dies, and that rule is what makes charging a
  genuine risk. Essence is the exception, and it is priced: you pay pool energy, you must
  have foreseen the death, and the rescued energy lands on a body that can also die. Gaia
  has no ramp, so without this the pool cost would be unpayable in practice.

**The gradient is why it is a good keyword.** Essence is worth paying on a charged,
high-Earth body and usually not on chaff — a decision every time rather than a reflex.

---

## Interactions

### Rise

A risen unit **benefits from the aura normally** — it is a living unit, so it receives the
board's Earth bonus like anything else. Returning "at half HP" means half of its *printed*
max, with the aura's bonus on top.

**Its own Earth contribution resets to printed.** Earth grown through card text is lost,
exactly as attached energy is. Rise restores **the card, not the history** — which is what
`Unit.make_risen()` already does by rebuilding from `CardData`.

**Essence may be paid on a unit that is about to Rise.** The energy and current Earth move
to a neighbour, then the body returns next turn at printed Earth. A real reward for
building the combo, bounded because pool energy was spent and `Rise` is spent on use.

### Towers

The aura grants tower max HP and tower damage, both of which already exist on `Board` as
`tower_max_hp` and `tower_damage_bonus`. The hard line from `CLAUDE.md` is untouched:
**no Gaia card raises the rate at which a tower hits structures.** Towers reach an enemy
tower or throne only through the existing quarter-rate rule, and the aura does not lift that
quarter, waive the minimum-1 floor, or let a tower hit a structure past a living unit.

Aura-granted max HP falling when an Earth unit dies **clamps current HP downward without
killing the tower**. A tower dying because a unit died two boards away is a feel-bad with
no counterplay, and it would make Gaia's own aura a liability against its own structures.

---

## The Damage Budget

**Gaia's printed damage sits below the standard 12-per-energy curve**, in the same way
Void's does. This is not a tax — **the aura *is* damage.** Every point of Earth is +1 on
every attack from every unit and both towers, so a board at 8 Earth adds 8 to six different
sources. Printed attacks are priced knowing that, which stops Gaia's ceiling from being
absurd once the board fills.

**HP sits at the top of each stage's band** (`CLAUDE.md`: Basic 40–90, Stage 1 80–120,
Stage 2 110–175). Tanky is the identity and the aura adds max HP on top, which is why the
attacks are cheap.

**The Earth curve:** roughly **1 Earth on a Basic, 2 on a Stage 1, 3 on a Stage 2.** A full
board of four evolved units is 8–12 Earth — a **+8/+12 aura** at the printed rate. Cards
that *grow* Earth print less of it up front.

---

## The Card Set

**Five evolution chains, 13 units.** Draft and reasoning in
`docs/specs/2026-08-09-gaia-card-set-draft.md`.

| Chain | Basic | Stage 1 | Stage 2 |
|---|---|---|---|
| **Stone** — auto-fire | Makeshift Tower 50 | Bulwark of Stone 100 | The Standing Stone 150 |
| **Conduit** — energy into Earth | Living Conduit 70 | Deep Roots 110 | Heartwood Ancient 160 |
| **Grove** — Earth growth | Sapling Warden 60 | Grovekeeper 95 | Elder of the Grove 130 |
| **Stoneskin** — Retribution walls | Mossback Tortoise 90 | Granite Colossus 120 | — |
| **Bloom** — Essence | Seedbearer 55 | Vernal Rite 90 | — |

Supports: `Bedrock` (free, +2 Earth), `Deep Communion` (1, draw 2 + Earth),
`Terraform` (2, heal-all + Earth), `Cairn` (tower support, +15 max HP),
`Verdant Anchor` (Tool, Earth +2).

**`Resist` appears only on the stone chain** — 5 on Bulwark, 10 on The Standing Stone.
It is per-card flavour, not faction identity, and it pairs with auto-fire: those bodies
want to survive many small hits, which is what Resist is good against.

**Exactly one rate-breaker**, `Deep Roots`, per the open question below. Enforced by a
test that counts them.

### The three cards settled in design conversation

### Makeshift Tower — Basic

A unit that **auto-fires** at the enemy unit across from it at end of turn — free, no
energy, no queueing — and gains **+5 max HP per round** like a real tower.

It is a unit in every other respect: it shields the structures behind it, it receives the
aura, it can be retreated, and — **the entire cost of the card** — an enemy attack may name
it as a target. A real tower is only reachable once a board is cleared; this one is
killable the turn it lands.

That trade is what pays for a free repeating attacker in a game whose core rule is *energy
only buys attacks*, so its damage stays small and the Earth on it is the reason to run it.

### The attached-energy body

Its `Earth` equals its **attached energy**, live and continuous. Charging it grows the
aura; losing it costs the energy *and* the aura contribution at once. This welds Gaia onto
the pool-versus-attached decision `CLAUDE.md` calls the game's central skill expression,
and it is the prime `Essence` carrier — the card most worth paying a funeral for.

Read as **`Earth = attached energy`**, not as an attack that banks Earth permanently. The
banking version compounds without limit, because attacking does not spend attached energy —
the same 4 energy would grant +4 Earth every turn forever.

### The rate-breaker

Raises the aura to **+2/+2**, additively. The build-around.

---

## The Brakes

Gaia is tanky and buffs towers, which is the profile most likely to trigger the stall risk
`CLAUDE.md` names. Four structural guards:

- **The aura is live.** Every point of it can be removed by killing the body holding it.
  There is no permanent accrual anywhere in the faction.
- **Gaia has no ramp**, and `Essence` taxes the pool it does have. The faction cannot both
  bank for funerals and buy attacks.
- **Printed damage is below curve**, so a Gaia board that has *not* built an aura is
  strictly worse than any other faction's.
- **A board wipe zeroes it**, exactly as it zeroes Void's Gap.

This is a live risk, not a solved problem. See Open Questions.

---

## Open Questions

- **Does the aura's max-HP grant shrinking ever kill a tower?** Answered *no* above — max
  falls, current clamps, the tower survives. Recorded here because it is the kind of edge
  case that gets re-litigated once the code exists.
- **Does the aura apply to Makeshift Tower's auto-fire damage?** Intended **yes** — it is a
  unit, and the aura reads "all your units." Stated explicitly because the card is
  deliberately tower-shaped and the reader will wonder.
- **How many rate-breakers may stack?** Two copies of a +2/+2 card is +3/+3 per point,
  which at 10 Earth is +30 across six things. Additive keeps it linear, but the base set
  should hold **one** such card until playtesting says otherwise.
- **Is Gaia's early game too weak?** One Basic is +1/+1 — genuinely nothing. The faction
  must survive to the midgame to do anything, and it has no ramp. Watch especially whether
  Gaia simply loses to Void, which attacks the energy Gaia must bank for `Essence`.
- **Does Gaia worsen the tower-stall risk anyway?** The live aura is the guard, but this is
  the first thing to measure once cards exist.
- **Is `Essence` a feel-bad prompt at high frequency?** It fires on every death of an
  Essence body and interrupts damage resolution to ask. If a board wipe produces four
  consecutive prompts, the UI needs a "decline all" affordance.
- **`Sanctuary` does not currently block `Retribution` recoil, though `CLAUDE.md` says it
  should.** Found while wiring `Resist` into the damage paths (2026-08-09). The recoil site
  in `_deal_lane_damage` calls `take_damage` directly, bypassing `absorb()` — so a shielded
  unit takes full recoil. `CLAUDE.md`'s Sanctuary entry lists `Retribution` among the sources
  it blocks. **This predates Gaia and is not something Gaia changed**; `Resist` was wired into
  the recoil path deliberately, Sanctuary was left alone because changing it alters Heaven's
  behaviour. Either the rule or the code is wrong and it is a one-line fix once decided.
- **Auto-fire scaling with the aura is the biggest number in the faction, and untested.**
  `The Standing Stone` fires 20 printed, but auto-fire reads the aura like any attack — on
  a 12-Earth board that is **32 damage a turn, free, forever**, from a card that never
  spends energy. Three stones plus the aura they generate is most of a lane per turn with
  the pool untouched. It is the single most likely thing here to be wrong. Dials, cheapest
  first: cap auto-fire's share of the aura, drop the printed numbers to 8/11/15, or make
  auto-fire cost 1 attached energy that stays attached. **Do not tune on AI numbers** —
  `AIPlayer` has no Gaia heuristics and cannot play the chain properly.
- **The Earth aura feeds half-rate tower chip.** `CLAUDE.md` lets a tower reach an enemy
  tower or throne at **half** rate once the board in front of it is clear, and Gaia's aura
  raises the number that half is taken from — at 12 Earth that is +6 a turn to a throne
  from a keyword whose text never mentions the throne. The half and the "no card may raise
  the rate" rule are both intact, and no Gaia card touches either; verified by a test
  asserting a 16-damage shot chips exactly 8. What is new is that Gaia is the first faction
  whose *board* scales tower damage, so this is the first time the chip grows without a
  tower support card being played. Watch whether it matters.
- **Does the aura recalculating mid-volley cause problems?** A unit's max HP changing during
  a resolution is something the engine has never had to handle. Flagged as the fiddliest
  part of the implementation rather than a design question.
