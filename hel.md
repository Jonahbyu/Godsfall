# Hel — Faction Design

> Read `CLAUDE.md` first for core rules, board geometry, and the energy economy.

**Domain:** Death, decay, the dead.
**Verb:** Recycle.
**One-line identity:** *Death is a resource.*

---

## Subfactions

Hel is not one deck. It is a **shared energy color** hosting several themes, all of which
pay Hel energy and can be mixed freely in a deck.

| Subfaction | Core idea | Status |
|---|---|---|
| **Toll** | Every body refunds energy when it dies. Death is income. | 🔨 Being built now |
| *(future)* | Other Hel-energy themes that pair with Toll units | Not started |

**What's being built right now is the Toll subfaction.** Every unit in it carries `Toll`
— that universality is the point, because it's what lets a Toll deck run leaner on energy
cards than its attack costs imply. A unit in this subfaction without Toll is a hole in
the engine.

`Hel, Queen of the Unclaimed` is the deliberate exception. She carries no Toll herself —
she is the **payoff** the subfaction builds toward, and she *interacts* with Toll by
killing every Toll unit on the board at once and collecting the refunds. See her entry
below.

Future subfactions will share Hel energy and are expected to slot alongside Toll units
rather than replace them.

---

## Why Hel Works In This Engine

Deployment is free and the board caps at 4 — units are cheap and disposable by default.
Hel leans all the way in. Where Heaven protects a unit and Gaia grows one, Hel throws
bodies into the grinder and gets paid.

Three structural advantages that are unique to this faction:

**Hel profits from the tower clock.** Towers are an attrition engine that kills your
units every turn. Every other faction races that clock. Hel *feeds on it* — `Toll`
converts tower damage into energy income.

**Hel is the hoarding faction by nature.** `Decay` deals damage for free — no energy, no
attack used — so Hel applies pressure *while* banking. Combined with `Toll` refunds,
Hel can climb toward expensive attacks without going passive. This is why Hel owns the
top of the energy curve.

**Hel needs less total energy than its curve suggests.** Because `Toll` is universal in
this subfaction, *every* body on the board is stored energy, and a Toll deck can run
leaner on energy cards than the raw attack costs imply. That's a real deckbuilding
identity, not a flavor note.

**The tension:** Hel's plan requires committing energy to units, and Hel's units die
constantly. Attached energy dies with them. `Toll` softens the blow but never fully
repays it — a unit holding 6 attached energy that tolls 2 still lost you 4. Playing Hel
well means knowing which unit is worth charging and which is worth feeding to the
grinder.

---

## Keywords

| Keyword | Effect |
|---|---|
| **Toll N** | *(Hel signature)* When this unit dies, gain N Hel energy to your pool. |
| **Decay N** | *(Hel signature)* At end of turn, deal N damage to the opposing unit. Costs no energy and does not use this unit's attack. |

Hel's two **signature** keywords are above. Hel also prints three **shared** keywords,
defined in `CLAUDE.md`: `Rise`, `Retribution`, and `Consume`.

`Rise` and `Retribution` were originally Hel-exclusive and moved to the core rules when
Heaven was built. No Hel card changed — they simply stopped being exclusive. Hel keeps the
two that encode *death is a resource*, which is the faction's whole identity.

### Notes on the keywords

> Notes on `Rise` and `Retribution` below are Hel's *tuning* of shared keywords. The rules
> themselves live in `CLAUDE.md`.

**Decay is the load-bearing keyword.** Free damage every turn is what lets Hel bank
energy without ceding tempo. It's also the faction's balance risk — see Open Questions.

**Toll pays into the pool, not onto a unit.** So Toll energy is immediately exposed to
20% decay. Hel gets the refund but must re-commit it. This is deliberate — Toll softens
death, it doesn't undo it, and the pool-vs-attached decision still has to be made every
turn.

**Toll scales with HP: `Toll = HP ÷ 25, rounded down`.** The refund tracks the size of
the body you lost, so it never has to be tuned per card — it falls out of the stat line.
A 40 HP chaff unit tolls 1; a 150 HP Stage 2 tolls 6.

**Toll is printed on the card and never changes in play.** The formula is a *design-time*
tool for setting the number, not something recalculated during a game. Specifically:

- **Buffs and debuffs from other units never change Toll.** A 40 HP Grave Whelp buffed to
  60 still tolls 1. Otherwise every HP aura would silently become an energy aura, and
  pumping your own chaff before feeding it to the tower would be a degenerate income loop.
- **Damage never changes Toll.** A 115 HP unit at 5 HP still tolls 4.
- **Evolution does change it**, because the evolved unit is a different card with its own
  printed Toll. Evolving is the one legitimate way to raise a body's refund.

**Rise removes only Rise.** The returned unit comes back at half HP without the Rise
keyword — but *everything else returns intact*, including Toll, Decay, Retribution, and
both attack lines. A Rising unit with Toll therefore pays out **twice per body**: once
when it first dies, once when the returned copy dies for good. That double payout is the
engine, and dropping the keyword is what still caps the loop at two.

It comes back without its attached energy, though. A `Rise` unit returns as a body, not
as an investment — so never charge one you expect to die.

**Retribution taxes the opponent's most precious resource.** In a game where attacking
costs energy, hitting a Thornshade means paying energy *and* taking damage. It's a
uniquely good fit for this engine.

---

## Evolution Lines

### Line 1 — The Queen (chaff → harvester → sovereign)
`Grave Whelp` → `Gravebound Reaper` → `Hel, Queen of the Unclaimed`

The flagship line. Starts as the most disposable card in the faction and ends as the
game's biggest win condition. Energy carries up the line, so this is where you invest.

### Line 2 — The Devourer (Decay scaling)
`Carrion Crawler` → `Nithogg, Root-Gnawer` → `Nithogg Ascendant`

A Decay tower. Barely attacks, deals enormous free damage over time. The passive
pressure that buys the Queen time to charge.

### Line 3 — The Choir (trigger engine)
`Bonepicker` → `Hel's Chorus` → `Grand Cacophony`

The build-around. Multiplies end-of-turn triggers, which means multiplying every `Decay`
on your board. With a wide Decay board, this is the faction's damage ceiling.

### Line 4 — The Martyr (retaliation)
`Thornshade` → `Mourning Bell`

Stops at Stage 1. Defensive, punishes aggression, protects the Queen's charging window.

### Line 5 — The Drowned (Toll + Rise)
`Hollow Servant` → `Grave Tide`

The subfaction's purest expression. Both stages carry Toll *and* Rise, so each body dies
twice and pays twice. Four energy from a Basic, six from a Stage 1 — plus a tower-breaker
attack that comes back after it dies.

### Unlinked
`Barrow Knight`, `Charnel Colossus`

---

## Cards

All cards obey the **two-line rule**: one ability + one attack, or two attacks.
Damage anchors: standard ≈ `12 × cost`, Consume ≈ `20 × consumed`.

### Basics

**Grave Whelp** — 40 HP
*Toll 1*
▸ **Gnaw** — 1 Hel — 12 damage

> Deliberately fragile chaff that pays you when the tower eats it. Also the entry point
> to the Queen line — a Whelp you've been charging becomes a Reaper with energy intact.

---

**Barrow Knight** — 50 HP
*Toll 2*
▸ **Cleave** — 2 Hel — 25 damage

> Flexible early body. Gaining Toll cost it the `Grave Bargain` line — with Toll
> universal in this subfaction, the two-attack cards had to give one up. Cleave was the
> keeper; Grave Bargain's discard cost is a better fit for a future subfaction.

---

**Carrion Crawler** — 40 HP
*Toll 1, Decay 5*
▸ **Rend** — 1 Hel, 1 colorless — 15 damage

> Free chip damage from turn one. Fragile on purpose — it's a Decay engine, not a body.

---

**Bonepicker** — 50 HP
*Toll 2*
▸ **Scavenge** — 1 Hel — 10 damage; return a Hel unit from your discard to your hand

> Card advantage on a 1-cost attack. Once charged, this recurs a body every single turn.
>
> Bumped from 45 to 50 HP so its printed Toll 2 matches the `HP ÷ 25` formula. Keeping
> the formula exceptionless was worth 5 HP on a Basic.

---

**Thornshade** — 50 HP
*Toll 2, Retribution 10*
▸ **Lash** — 2 Hel — 22 damage

> A wall that taxes attackers. Buys turns for the Queen to charge.

---

**Hollow Servant** — 55 HP
*Toll 2, Rise*
▸ **Grasp** — 1 Hel — 12 damage

> The slot-holder, and the clearest demonstration of the Toll/Rise engine. It dies and
> tolls 2. It returns at 27 HP — keeping Toll and Grasp, losing only Rise — then dies
> again and tolls 2 more. **One card, 4 energy, two bodies.**
>
> Still never charge it. Attached energy doesn't survive the trip.

---

**Charnel Colossus** — 90 HP
*Toll 3*
◆ **Consume the Fallen** — *ability, free* — Destroy a friendly unit; move all of its
attached energy to this unit.
▸ **Crush** — 3 Hel — 38 damage

> The energy-transfer engine, and the reason attached energy isn't a dead end. Charge a
> cheap unit, then move the investment to something that deserves it — or rescue energy
> from a unit that's about to die. A 90 HP Basic, so it can be deployed turn one and
> charged all game.
>
> **Resolved: it is an ability again.** Consume the Fallen was briefly an attack line
> costing 1 Hel, to make room for Toll under the two-line rule. Now that abilities are a
> real, separate line type it has moved back — sacrificing a unit is a non-damage cost, and
> `CLAUDE.md` says those belong on ability lines. It is **free**, it resolves immediately
> instead of at end of turn, and it no longer competes with Crush for the turn's energy.
> Both lines survive, so the two-line rule is still satisfied.
>
> Resolving immediately is the real upgrade: the energy it moves is available to pay for
> Crush **the same turn**, which is exactly the play the card was always describing.
>
> It still *doubles* the Toll engine: destroying a friendly unit with Consume the Fallen
> triggers that unit's Toll. You get its attached energy **and** its refund, on your own
> terms, without waiting for the tower to do it.

---

### Stage 1

**Gravebound Reaper** — 90 HP — *evolves from Grave Whelp*
*Toll 2, Decay 5*
▸ **Final Verdict** — 6 Hel — 75 damage; this unit dies at end of turn

> A single expensive attack, so this is a card you evolve into a *plan*. Toll 2 refunds
> on the self-kill. Note the trap: dying loses all 6 attached energy, so Final Verdict
> is genuinely a one-shot unless you're rebuying with the Queen.

---

**Hel's Chorus** — 90 HP — *evolves from Bonepicker*
*Toll 2*
◆ **Dirge** — *ability, Consume 1* — End-of-turn effects trigger **twice** this turn

> The engine card, and the clearest example of why `Consume` exists.
>
> As a 2 Hel attack it was free forever once paid: attach 2 once, double every `Decay` on
> the board every turn for the rest of the game. As a **Consume 1 ability** it costs one
> attached energy *every time*, so the Chorus has to be fed to keep singing. That turns a
> permanent engine into an ongoing decision — which is the whole point of the pool-versus-
> attached tension — and it resolves immediately rather than at end of turn.
>
> Lost `Wail` to make room for Toll. No great loss — you never wanted to spend this
> unit's activation on 38 damage anyway, and a Chorus that dies now at least refunds.

---

**Mourning Bell** — 95 HP — *evolves from Thornshade*
*Toll 3, Retribution 15*
▸ **Toll the Bell** — 3 Hel — 38 damage; gain 2 energy if a friendly unit died this turn

> The conditional refund on Toll the Bell stays. With Toll universal it will trigger
> nearly every turn, which is the point — the Bell is the subfaction's *income* payoff,
> the card that turns a dying board into a second revenue stream on top of the Tolls
> themselves.

---

**Nithogg, Root-Gnawer** — 115 HP — *evolves from Carrion Crawler*
*Toll 3, Decay 15*
▸ **Gnaw the World** — 5 Hel — 60 damage

> Huge body, huge free damage. The 5-cost attack is a late-game option, not an early
> plan — the Decay is what you're paying for.

---

**Grave Tide** — 95 HP — *evolves from Hollow Servant*
*Toll 3, Rise*
▸ **Surge of the Drowned** — 7 Hel — 40 to the opposing unit **and** 40 to the enemy tower

> Hel's tower-breaker. Reaches past the board to answer the attrition engine directly.
>
> Toll + Rise on a Stage 1 is the subfaction's best body: it dies for 3, returns at 38 HP
> keeping Toll and Surge, and dies again for 3 more. **6 energy and two tower-breaking
> bodies from one card.** This resolves the old open question about whether Grave Tide
> earned its Rise — with Toll universal and Rise no longer stripping anything else, it
> clearly does.

---

### Stage 2

**Hel, Queen of the Unclaimed** — 175 HP — *evolves from Gravebound Reaper*
◆ **Claim the Fallen** — *ability, Consume 2* — Return up to 2 Hel units from your discard
directly to empty slots on your side.
▸ **THE LAST TOLL** — 20 Hel — Destroy every unit on both boards. For each unit
destroyed this way, deal **15 damage** to the enemy throne. **Your units' Toll triggers
as normal.**

> The faction's win condition and the game's marquee card.
>
> **She has no Toll of her own** — she is the only unit in the subfaction without it. She
> isn't a body to be spent; she's what the spent bodies *pay for*. Deliberate exception,
> and the reason the card is named after the keyword it collects rather than one it has.
>
> The two lines are two halves of one plan, and **`Consume 2` deliberately puts them in
> tension.** Claim the Fallen fills your board (and forces the opponent to respond, filling
> theirs), but every use now burns 2 of the energy she is trying to accumulate toward
> THE LAST TOLL. You no longer Claim for free while climbing — each Claim is two more turns
> of charging, so the question every turn is *board now, or the bomb sooner?*
>
> That's a real change from the card's first draft, where Claim was a 5 Hel **attack** and
> the 5 stayed attached, counting toward the 20. Claiming was strictly free progress. As an
> ability it resolves immediately — the reanimated units are on the board the moment you
> use it, not at end of turn — but the climb is now something you pay for.
>
> Then The Last Toll cashes the whole board in. A full 8-unit board is 120 damage to a
> 100 HP throne. **Lethal.** It destroys the Queen too, and all 20 of her attached energy
> with her — but every Toll unit you owned refunds on the way out. A board of four Stage 1
> Toll 3s hands back 12 energy *as the throne dies*, which is what makes a failed Last
> Toll survivable: if the enemy throne lives, you're not left at zero.
>
> The opponent sees her energy climbing the entire time. Killing her before 20 is the
> counterplay — and every point they force you to lose is a point you re-climb from the
> pool, through decay.

---

**Nithogg Ascendant** — 150 HP — *evolves from Nithogg, Root-Gnawer*
*Toll 6, Decay 25*
▸ **Endless Hunger** — 14 Hel — 40 to the opposing unit, 40 to the enemy tower; gain 5 energy

> 25 free damage per turn is a lane that cannot be held. Endless Hunger partially
> refunds, making it a hoarding *engine* rather than a terminus — chain it across turns
> at a net 9 per activation.

---

**Grand Cacophony** — 120 HP — *evolves from Hel's Chorus*
*Toll 4*
▸ **Requiem** — 9 Hel — 45 damage; end-of-turn effects trigger **three times** this turn

> The build-around payoff. With Nithogg Ascendant (Decay 25) and two Decay 5s on board,
> Requiem is 105 free damage in a single end step, every turn, forever.
>
> Dropped `Dirge` for Toll — Requiem supersedes it anyway, and keeping both would have
> broken the two-line rule.

---

## The Energy Curve

Hel has a payoff at nearly every step, not one cliff:

| Energy | Card | Effect |
|---|---|---|
| 0 | **Consume the Fallen** *(ability)* | Energy transfer — free, resolves immediately |
| 1 | Gnaw / Scavenge / Grasp | 10–12, or recursion |
| 2 | Cleave / Lash | 22–25 |
| 3 | Crush / Toll the Bell | 38 |
| 5 | Gnaw the World | 60 |
| 6 | Final Verdict | 75, self-kill |
| 7 | Surge of the Drowned | 40 + 40 to tower |
| 9 | Requiem | 45 + triple triggers |
| 14 | Endless Hunger | 80 spread, refund 5 |
| **20** | **THE LAST TOLL** | Board wipe → 15/unit to throne, **+ your Tolls refund** |

Consume abilities sit outside this curve, because their cost is charged *every use*
rather than once. They are read as a per-turn rate, not a one-time price:

| Consume | Card | Effect, per activation |
|---|---|---|
| 1 | **Dirge** | Double every end-of-turn trigger this turn |
| 2 | **Claim the Fallen** | Return up to 2 units from the discard to the board |

### The Toll floor

Universal Toll puts a **floor under the curve**. Every unit on the board is worth
`HP ÷ 25` energy the moment it dies, whether you chose that death or not. Reference
totals for a full 4-unit board:

| Board | Toll on wipe |
|---|---|
| 4 Basics (40–55 HP) | ~6 energy |
| 4 Stage 1s (80–115 HP) | ~13 energy |
| Mixed late board | 8–14 energy |

That is the real reason a Toll deck runs lean on energy cards: **the board is a battery.**
Roughly half a Last Toll's cost is sitting in your units at any given time, and the tower
clock cashes it out for you whether you like it or not.

Remember: these are **one-time payments**. A unit with 9 attached uses Requiem *every
turn* thereafter for free. The curve describes the climb, not a per-turn cost.

---

## Open Questions

- **Toll Engine beats everything, and it is now the game's clearest balance outlier.**
  Measured 2026-08-08 over 9-run AI samples while testing Void: **9-0** vs Barrow Wall,
  **8-1** vs Lamp Wall, **8-1** vs Widening Rift, **5-4** vs Verdict Engine, **8-1** vs
  Starve. It beats Hel's own wall deck without losing a game.

  The likely mechanism is that the deck's plan is immune to the two things that slow
  everything else down. Unit shielding and the raised HP curve both punish decks that need
  to *clear a board*; Toll Engine does not care whether its units die, because death is its
  income. So the rules changes that lengthened every other matchup made this deck relatively
  stronger. The 16-energy count is also low for what it does, since Toll is a second income
  stream.

  **Do not tune on this alone** — the AI plays aggro decks far better than control ones,
  because it has no retreat heuristic and no model of holding a board. But 9-0 against a
  same-faction wall is a large enough margin that the deck is worth a human game before the
  next round of tuning.

- **Did the HP curve raise silently buff Hel more than the other factions?** `Toll` is
  derived from HP, so raising every body raised Hel's income across the board with no
  design decision behind it — `Nithogg Ascendant` alone went from Toll 4 to **Toll 6**.
  Hel is the only faction whose *stat line* converts directly into resources, so a
  game-wide HP change is a game-wide Hel economy change. Two things to check: whether
  Toll 6 on a 150 HP body that also has `Decay 25` is a fair reward for losing it, and
  whether `Toll = HP ÷ 25` should have been re-divisored at the same time the retreat
  divisor moved to `÷ 40`. The counter-argument for leaving it: bigger bodies also die
  less often, so the refund fires less, and Toll energy still lands in the decaying pool.
- **Is `Decay` too strong?** Free damage every turn, no energy, no attack used, and it
  stacks across a wide board. It's Hel's identity but it may need to be rarer — maybe
  only 2–3 units in the faction get it rather than 4.
- **Is 15 per unit right on THE LAST TOLL?** A full board is 120 vs. a 100 HP throne —
  lethal. Dropping to 12 (96) makes it one short, requiring a follow-up turn. Removes
  the auto-win, keeps the drama.
- **Does Hel need a Consume *attack*?** Hel now has two Consume **abilities** — Dirge
  (Consume 1) and Claim the Fallen (Consume 2) — so the mechanic is no longer unused, but
  no Hel *attack* consumes. A Consume finisher priced on the steeper ~20-damage-per-energy
  curve may still fit the "burn the investment" theme better than Final Verdict's
  self-kill.
- **Is Consume 2 the right price on Claim the Fallen?** It was chosen to stop Claim being
  free progress toward THE LAST TOLL, since the old 5 Hel attack cost stayed attached and
  counted toward the 20. The risk is overcorrection: the Queen now pays to fill her board
  *and* pays to arm her finisher, out of the same attached pool, which may make the 20 too
  far away to ever reach. Watch whether Last Toll still resolves in practice.
- **Universal Toll cost three cards their second line.** Barrow Knight lost `Grave
  Bargain`, Hel's Chorus lost `Wail`, and Grand Cacophony lost `Dirge`. Charnel Colossus
  briefly had to demote `Consume the Fallen` to a 1-cost attack for the same reason; that
  one is now resolved, since abilities are a real line type again and it has moved back.
  Toll is cheap in power but expensive in *text space*, and the two-line rule makes that a
  real cost.
  Worth checking in playtesting whether flavorful two-attack cards should be allowed to
  skip Toll — which would mean Toll is "near-universal" rather than universal.
- **Does the Toll floor make the Queen too safe?** A failed Last Toll used to leave you at
  zero energy with an empty board — a genuine all-in. Now your own units refund 6–12 on
  the wipe, which may remove the risk that made the card dramatic.
- **Is `Toll = HP ÷ 25` the right divisor?** It reproduces the two existing printed values
  (Grave Whelp 1, Bonepicker 2) and gives a clean 1–4 range, but it means HP is doing
  double duty as both survivability and energy value. A tanky-but-harmless unit is
  automatically an income unit, which may not always be the flavor you want.

---

## Card Count

**14 cards**, all in the **Toll subfaction**. 7 Basics, 4 Stage 1, 3 Stage 2 — with the
Nithogg and Chorus lines each running Basic → Stage 1 → Stage 2, and the Queen line as
the flagship.

Every unit carries `Toll` except `Hel, Queen of the Unclaimed`, who collects it instead.

Target for a testable faction was ~10; this overshoots slightly to give all four
evolution lines a complete arc.

### Toll and Retreat by card

**Toll is `HP ÷ 25`; Retreat is `HP ÷ 40`**, both rounded down. They used to share a
divisor and print the same number — see `CLAUDE.md` for why they were split.

| Card | HP | Toll | Retreat |
|---|---|---|---|
| Grave Whelp | 40 | 1 | 1 |
| Carrion Crawler | 40 | 1 | 1 |
| Bonepicker | 50 | 2 | 1 |
| Barrow Knight | 50 | 2 | 1 |
| Thornshade | 50 | 2 | **2** |
| Hollow Servant | 55 | 2 | 1 |
| Charnel Colossus | 90 | 3 | 2 |
| Gravebound Reaper | 90 | 3 | 2 |
| Hel's Chorus | 90 | 3 | 2 |
| Mourning Bell | 95 | 3 | **3** |
| Grave Tide | 95 | 3 | 2 |
| Nithogg, Root-Gnawer | 115 | 4 | 2 |
| Grand Cacophony | 120 | 4 | 3 |
| Nithogg Ascendant | 150 | 6 | 3 |
| **Hel, Queen of the Unclaimed** | 175 | **— (none)** | 4 |

The bolded retreats are the two `Retribution` walls, still priced a point above formula so
they can't cheaply abandon the lane they exist to hold.

**Toll now exceeds Retreat on every card**, which is the intended consequence of splitting
the divisors: a body pays *more* if it dies than it costs to save. That sounds like it
should push Hel away from the grinder, but it doesn't — the refund is only worth taking
when the death was going to happen anyway, and retreat still costs a turn of board
presence and a locked card. What changed is that extraction is now genuinely available on
the big bodies, so **feeding the Queen to a tower is a choice rather than the only option**.

**The game-wide HP curve raise moved most of this table.** Toll is derived from HP, so
raising Stage 1 to 80–120 and Stage 2 to 110–175 raised Hel's refunds with it: the three
Stage 1 bodies went to Toll 3, `Nithogg, Root-Gnawer` and `Grand Cacophony` to Toll 4, and
`Nithogg Ascendant` to **Toll 6** — by far the largest refund in the game, and worth
watching. See Open Questions.

This is a real buff to the subfaction and not just a stat change: **every Hel body is
stored energy, so a bigger body is more stored energy.** A Toll deck now runs leaner on
energy cards than before, which was already the faction's deckbuilding identity and is
now more pronounced.

Two deviations, both deliberate:

- **Thornshade (3) and Mourning Bell (4)** are priced a point above their Toll. They're
  walls — a wall that can cheaply abandon its lane isn't a wall, and the Retribution line
  has to commit. This is also the only place in the faction where retreating is strictly
  worse than dying by the printed numbers, which is the intended read.
- **The Queen (4)** has no Toll at all, so hers is a pure cost with nothing on the other
  side of the comparison. She's the card you'd most want to rescue from a losing board and
  the card most likely to *have* the energy to do it: retreating her at 20 attached costs
  4 and refunds 16 to the pool. That's a genuine escape hatch from a failed Last Toll, and
  it costs her whole evolution line going back to hand.

### Retreat and Toll are exclusive

Retreat doesn't kill the unit, so it doesn't `Toll` and it doesn't `Rise`. This matters
more for Hel than any other faction: **every Toll unit is a choice between the refund and
the card.** Feeding a Grave Whelp to the tower pays 1 energy and puts it in the discard
where `Bonepicker` and `Claim the Fallen` can reach it. Retreating it pays nothing, but
you keep the body.

For most of the Toll subfaction, dying is simply better — which is correct. Retreat is a
Hel *escape hatch*, not a Hel plan:

- **`Rise` units should never retreat.** `Hollow Servant` and `Grave Tide` are worth two
  bodies each if they die and one if you pull them out.
- **The Queen should sometimes retreat.** She has no Toll to lose and a huge attached pool
  to rescue.
- **`Gravebound Reaper` retreating before Final Verdict resolves** is a way to bank a
  6-energy investment when the plan falls apart, at the cost of re-evolving from Whelp.
