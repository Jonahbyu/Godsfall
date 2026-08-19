# Support Cards

> Read `CLAUDE.md` first for core rules, the energy economy, Retreat, and the support
> power band.

**Status: 39 of the 43 cards below are implemented** and live in `data/cards.json`. Card
behaviour is covered by `scripts/core/SupportTest.gd`. Notes on how they resolve in the
prototype:

- **`Offering` gains Hel energy**, not "any single color" — Hel is currently the only
  color, so color choice has nothing to choose between yet.
- **Search and discard effects open a modal card picker.** The AI auto-resolves its own
  choices by taking the first legal option, which is deliberately naive.
- **The four priced heals are written but not playable yet.** `Field Surgery`,
  `Closing Ranks`, `Vigil`, and `Grave Warden's Oath` carry a `cost` in `data/cards.json`,
  but the engine does not yet read it — `play_support` neither checks the pool nor spends
  from it, so they would currently resolve for free. **They are deliberately kept out of
  the four sample decks until the cost is enforced.** This follows the same
  ship-the-printed-value-early pattern retreat costs used; see `CLAUDE.md`.

**Support cards are one-shot effects.** Play, resolve, discard. Unlimited per turn, no
item/supporter split, 4-copy limit like any unit. **Usually free** — a minority cost 1–3
pool energy in exchange for sitting above the power band (see *Priced supports* in
`CLAUDE.md`).

**Tools** are the exception: a Tool attaches to a unit and stays, one per unit, and is
discarded when that unit dies or retreats. See the Tools section below.

These are the **neutral** supports — playable in any deck regardless of faction. They are
the baseline every faction's own support cards get measured against.

---

## Design Rules for Supports

**One effect per card.** Units get two lines; supports get one. A support that draws
*and* gains energy is two cards' worth of value in one draw, and that's how a support
band collapses. The exceptions below are conditional — the second half only happens if
you've paid for it in board state.

**Hand size is the cost.** With one draw per turn, every support you run is a unit you
didn't. That's the balancing pressure, not a play limit. It only works if no single
*free* support is worth more than about a turn of tempo.

**Energy is the second cost, and it's rare.** A support may charge 1–3 from the pool, and
that purchase buys roughly one band step per energy. Default to 0 — the free file is the
baseline and priced cards should read as deliberate exceptions, not as the normal way to
push a card. When a support wants to be stronger than the band allows, the first question
is whether a *condition* can pay for it (`Collapse`, `Last Breath`, `Sift the Ashes` all
do); energy is the answer only when the unconditional version is the point.

**Never sell damage cheaply.** Energy buying attacks is the game's whole identity. A
support that deals damage must charge for it in something other than energy — a discard,
a self-inflicted cost, or a board condition. Free support damage makes the energy economy
optional.

**Supports should smooth the two spend-or-save decisions, not resolve them.** A card that
gains energy is fine; a card that makes the pool immune to decay is not.

**Neutral supports are deliberately plain.** They do generic things — draw, dig, heal,
bounce. The interesting supports are the faction ones, which do generic things *plus*
something only that color could want. A neutral support should never be strictly better
than a faction support.

**Search is selection, not advantage.** A search card ends with your hand the same size —
you just chose the card. That's why search is safe at full power while raw draw is the
thing under watch.

**Randomness is the cheapest brake on search.** Three of the five search cards find a
*random* card from a restricted pool rather than a chosen one. This is better than a
board condition or an exile clause because it costs nothing to read, can't be gamed, and
turns the card into a **deckbuilding decision** — a random pull from a narrow deck is
nearly deterministic, from a wide one it's a gamble. The player tunes their own
consistency by choosing how many lines to run.

The tiering that remains: Basics can be found freely and by name, evolved units come up
random, and finding any card by name costs a full turn of delay.

**Tools do a third as much, repeatedly.** A Tool must take three to four turns to match
what the equivalent one-shot does immediately. It only earns while its unit lives, so the
board is what balances it.

**Tower support is cheap because it's self-limiting.** A tower you're investing in is a
tower you're keeping alive, and a live tower costs you a lane slot. The hard line: no
tower support may raise the **rate** at which a tower hits structures. A tower reaches a
structure only through the quarter-damage rule for an empty board (see `CLAUDE.md`), and
every buff here is quartered on the way — `Murder Holes`' +5 is +1 against a throne.

**Watch the hand limit.** With a 10-card ceiling checked at end of turn, a draw support
played into a full hand converts directly into discards. That's the intended tax on
stacking draw, but it means the draw cards get *worse* the more of them you run — which
is the self-correcting pressure that unlimited support plays needed.

---

## Card List

### Draw & Selection

**Gravekeeper's Ledger** — Support
> Draw 3 cards.

The band-defining card. Three cards for one card is a net +2, which in a one-draw-per-turn
game is three turns of draw compressed into a single play. Everything else in this file is
priced against it. If Ledger turns out to be too strong, the whole file moves down with it,
which is exactly why it should be the first card playtested.

---

**Scavenger's Instinct** — Support
> Look at the top 5 cards of your deck. Take 2 into your hand. Discard the rest.

Fewer cards than Ledger, but you choose them — and the 3 discarded cards are *live* in a
game with Hel recursion. Deliberately a downside for most decks and an upside for one, so
neutral cards can still have a home color.

---

**Second Thoughts** — Support
> Shuffle your hand into your deck, then draw that many cards plus 1.

The reset. Rescues a hand of dead cards without generating raw advantage, and gets worse
the better your hand already is. Also the only card that answers a flooded hand of
locked retreat cards — you can't play them, so shuffle them away.

---

**Last Rites** — Support
> Discard 2 cards. Draw 4.

Same net +1 as Second Thoughts, but you pick what goes and it's faster. The discards are
the price and, in a discard-caring deck, the point.

---

### Search

Search is card **selection**, not card advantage — you end with the same hand size, you
just picked the card. That's why these are safe to print at full power while `Ledger` is
the thing being watched.

The tiering below is the important part: **searching a Basic is nearly free, searching an
evolved unit costs real cards.** Basics are the least powerful things in the deck and the
thing a stalled hand most needs; Stage 2s are win conditions.

---

**Muster** — Support
> Search your deck for a **Basic** unit and put it into your hand. Shuffle your deck.

The card that fixes the worst opening hands. A hand with no Basic is a hand that cannot
develop a board at all — you can't evolve into anything, and the tower eats your throne
uncontested. Muster costs a card and gives back the least powerful card type in the game,
so its only real function is *consistency*, which is exactly what it should be.

It's also the one search that stays useful late, because a Basic is what you need after a
board wipe.

---

**Roll Call** — Support
> Search your deck for up to **2 Basic** units, reveal them, and put them into your hand.
> Shuffle your deck.

Net +1 card, all of it in the weakest card type. Rebuilds a board in one play — the
answer to `THE LAST TOLL` or any other wipe. Revealing them is a real cost in a game where
placement is targeting: your opponent gets to see the rebuild coming and position for it.

---

**Line of Succession** — Support
> Reveal a **random** Stage 1 or Stage 2 unit from your deck and put it into your hand.
> Shuffle your deck.

Finds an evolution without letting you pick which one. That's the whole design: evolution
lines need *some* consistency because energy carries up the line and a charged Basic that
never finds its Stage 1 is a wasted investment — but a deck running four lines shouldn't
get to assemble exactly the one it wants on demand.

The randomness makes it a **deckbuilding card rather than a tutor.** Run one evolution
line and it's nearly deterministic; run four and it's a lottery ticket. That's a real
build decision, and it self-balances: the decks that get the most out of it are the
narrow ones that were already the most fragile.

Note it doesn't check your board at all — it can whiff into a Stage 2 whose Stage 1 you
don't control and won't draw for five turns. Dead cards in hand are the price of not
having to meet a condition.

---

**Read the Bones** — Support
> Search your deck for any **one** card and put it on **top** of your deck. Shuffle your
> deck first.

The one true tutor in the file, and the reason it's priced this way: it finds anything,
including a Stage 2 or a key support, but you don't get it until your next draw. A full
turn of delay is what keeps an unrestricted search inside the band — the opponent gets a
turn to act before the card you found does anything.

With `Line of Succession` now random, this is the only card that reliably assembles a
specific evolution line, at the cost of a turn.

---

**Grave Market** — Support
> Put a **random** card from your discard pile into your hand.

Recursion rather than search, and random rather than chosen. That kills the loop the
chooseable version had — two copies could recur each other forever and every support in
the discard was permanently re-buyable — without needing to exile supports or restrict
what it reaches.

The randomness also gives it a natural curve. Early, your discard is small, so it's
close to a tutor. Late, your discard is thirty cards deep and it's a lucky dip. **The
card gets worse as it gets more powerful**, which is a shape the file needed given how
much else here is catch-up-flavored.

---

### Energy

**Offering** — Support
> Gain 3 energy of any single color to your pool.

Straight income, and it goes to the **pool** — so it's exposed to decay, and it does not
break the one-energy-card-per-turn rule (this is a support, not an energy card). Playing
it means committing to charge that energy the same turn or lose a fifth of it.

---

**Tithe** — Support
> Move all attached energy from one of your units to another of your units.

The neutral version of Charnel Colossus's `Consume the Fallen` — but it moves energy
without killing anything, and it costs a card instead of an attack. Rescues an
investment from a unit about to die, or consolidates two half-charged units into one
that can actually attack.

This is the card that makes charging a *wrong* unit recoverable, which matters a lot in
a game where the punishment for misreading a board is losing 6 attached energy.

---

**Sift the Ashes** — Support
> Gain 1 energy of any single color for each of your units that died this turn, to a
> maximum of 4.

Conditional income that reaches the top of the band only after a bad turn. A catch-up
card by construction: it's dead when you're ahead. Hel obviously loves it, which is
fine — it's still just energy, and Hel already had `Toll`.

---

### Retreat

**Escape Route** — Support
> Reduce the retreat cost of one of your units to 0 this turn.

The clean answer to a Stage 2 you can't afford to extract. Note what it does *not* do —
the unit's leftover attached energy still all returns to the pool, so this is the card
that lets you cash out a heavily-charged unit in full. That is the strongest thing in the
retreat suite and the reason it's a whole card rather than a rider on another one.

---

**Withdraw** — Support
> Retreat one of your units. Its retreat cost is paid from your **pool** instead of its
> attached energy.

Solves the stuck-unit problem: a unit with no attached energy can't retreat at all, and
this is the only way to move it. Pays from the pool, which is otherwise never legal for
retreat.

---

**Rally the Line** — Support
> A unit that returned to your hand this turn is no longer locked. You may play it this
> turn.

Explicitly a rule-breaker, per design principle #1. Turns retreat into a genuine reposition
— pull a unit out of a losing matchup and drop it into the other board's empty slot the
same turn. Costs a card and the retreat cost, so the tempo is paid for, just not with time.

---

**Ground Give** — Support
> Return one of your units to your hand. It is locked as normal, and its attached energy
> is **lost**.

Retreat for units that can't pay — no cost, no refund. The energy loss is the whole price,
and it's a real one. Answers a fully-uncharged unit sitting in a slot you need, or saves a
Stage 2 you're about to lose while writing off the investment.

---

### Board

**Reposition** — Support
> Move an enemy unit to another slot on its own board. It keeps all attached energy.

**Repurposed.** This printed *"swap the slots of two of your units"* until free unit
movement landed — once a player could rearrange their own board for nothing, a card doing
the same thing was worse than a free action, and the only case it still covered (exchanging
two occupied slots with no empty slot to route through) is a corner case rather than a card.

Pointed at the enemy it is a lever the player otherwise has none of. An **unnamed** attack
still hits the slot directly across, so shoving an enemy body one slot over redirects the
default target of every unnamed attack on that board at once — and it can pull a blocker
out from in front of a tower, which is the half chosen targeting can never do, since
naming a target picks *among* the wall and never past it.

It stays inside the shielding rules by construction: the unit never leaves the board it
was defending, so nothing is exposed that clearing that board would not already expose.
The destination is the leftmost empty usable slot rather than a second pick — on a 3-slot
board with a living tower there is usually exactly one empty slot, so a second prompt would
be asking a question with one answer. No card advantage at all, pure positioning, which
makes it the cheapest thing in the file to print safely.

---

### Healing

Healing is the counter-play to the tower clock, which is the one source of damage every
deck faces whether or not the opponent does anything. All healing is capped at **printed
HP** — never above — so it can't combo with an HP buff into a bigger body, and it never
moves `Toll` or `Retreat`, both of which are printed and fixed.

**The base heal is 32, and one energy buys about 48 more.** That's the whole pricing
rule for this class: `Shore Up` 32 free, `Field Surgery` 80 for 1, `Grave Warden's Oath`
120 for 3 (capped — the rate would put it at 176, above the largest printed HP).

The ladder was re-anchored x1.6 on 2026-08-17. It had been set against ~50 HP bodies and
was never re-derived when the HP curve rose to 40-175, so a "20 HP heal" quietly went from
40% of a body to 12% of one. See `CLAUDE.md`.

**No card fully heals a unit.** Every heal is a flat number — never "restore to max," and
never a fraction of printed HP. A heal that scales with its target is unboundable: the
same card is worth 25 on a Basic and 110 on the Queen, so it can't be priced against
anything, and it gets silently stronger every time a bigger body is printed. Flat numbers
mean a heal **overflows and is wasted** on a small unit, which is what makes the big ones
a real deckbuilding choice rather than a strict upgrade. This is enforced by a test, not
just convention.

Healing is deliberately a little under-costed relative to damage. Towers scale forever
(+5/turn) and units don't, so healing has a built-in expiry date: by turn 10 a tower hits
for 50 and no amount of 25-point heals matters. It's an early- and mid-game card type by
construction.

**This expiry is what the priced heals are for.** A free heal is a fixed number of points
against a threat that grows every turn, so it decays into irrelevance on a clock. The
paid ones buy their way out of that in two directions — raw size that keeps pace
(`Field Surgery`, `Grave Warden's Oath`) and a rate that scales with the tower instead of
against it (`Vigil`).

The heal ladder, free and priced together:

| Card | Cost | Heals | Against the rate |
|---|---|---|---|
| `Mend` | 0 | 10, any unit | half the baseline |
| `Shore Up` | 0 | **32**, any unit | **the baseline** |
| `Field Rites` | 0 | 10 to every unit | spread |
| `Reconsecrate` | 0 | 20 + undoes Decay | baseline + a rider |
| `Last Breath` | 0 | 50, needs half HP | +30, paid by the condition |
| `Field Surgery` | 1 | 50, any unit | 20 + 30 ✓ |
| `Closing Ranks` | 2 | 20 to every unit | spread, up to 80 |
| `Vigil` | 2 | 24 × the round number | scales |
| `Grave Warden's Oath` | 3 | 120, any unit | capped below the 175 HP ceiling |

The rule reads straight down the table: **base 20, and each energy buys about 30 more.**
`Last Breath` is the interesting row — it gets the same +30 that 1 energy buys, but pays
for it with an HP condition instead, which is the file's standing alternative to charging.

Compare against the damage curve. 1 energy on an attack buys 12 damage **every turn
thereafter**; `Field Surgery`'s 30 extra points happen once. That's why healing is allowed
to look efficient in raw points — it's one-time, capped by the body it's aimed at, and the
threat it answers keeps growing.

---

**Mend** — Support
> Heal one of your units 10 HP.

The floor. Its use is narrow and real: 10 is exactly one round of early tower fire, and
against `Decay` it's a full answer rather than an overpay.

Printed because the ladder needed a rung below the baseline — otherwise 20 reads as the
small option, and it isn't.

---

**Shore Up** — Support
> Heal one of your units 20 HP.

**The baseline the whole class is priced against.** Undoes two rounds of early tower fire,
or a little under half a fresh Basic. Every other heal in the file is quoted as some
number of energy above or below this one.

---

**Field Rites** — Support
> Heal each of your units 10 HP.

40 HP spread across a full board, versus 25 on one unit. Better in raw numbers and much
worse in practice — the board caps at 4, spread healing doesn't save the unit that's
actually dying, and it does nothing at all when you're down to one body. Same reason
concentrated damage beats spread damage, running the other direction.

Its real use is against `Decay`, which hits everything for small amounts every turn.

---

**Last Breath** — Support
> Heal one of your units **80 HP**. It must be at or below **half** its printed HP.

The conditional big heal, and the one free card that reaches the +30 that normally costs
an energy — the HP condition is what pays for it instead. Dead in hand when you're not
under pressure, which is the catch-up construction the file uses everywhere.

It used to be a *full* heal, which made it scale with the body: ~25 on a Basic and 60+ on
the Queen, off the same card. That's the shape the no-full-heals rule exists to stop, so
it's a flat 50 now. On a Basic it overflows and is wasted; on the Queen it's the best heal
you can get for free. Same role, but the number is finally something you can price.

---

**Reconsecrate** — Support
> Heal one of your units 20 HP and remove all `Decay` damage dealt to it this turn.

The narrow answer to Hel's identity keyword. Deliberately printed as neutral rather than
inside a faction, because `Decay` is free damage every turn and a deck with no answer to
a wide Decay board just loses to it. Slightly less raw healing than Shore Up in exchange
for the rider.

---

**Hold the Slot** — Support
> Until the end of the turn, one of your units cannot be reduced below 1 HP.

Survives the attack, survives the tower, keeps the slot filled for one more turn. The
band-appropriate version of protection — it buys exactly one turn and can't be stacked
into permanence.

Note the interaction: a Hel unit saved this way doesn't `Toll`, because it didn't die. As
with retreat, you're choosing the body over the refund.

---

**Field Surgery** — Support · **1 energy**
> Heal one of your units 80 HP.

The straight upgrade, and the card that sets the exchange rate for the whole priced tier:
**1 energy buys 30 more healing.** Everything else priced in this file is checked against
that line.

It's the honest version of what a priced variant should be — no new text, no new
restriction, just more of the thing. `Shore Up` heals under half a Basic; this one exactly
fills a fresh one, and on a Stage 2 it's the difference between surviving a tower hit and
not.

Both cards stay playable, which is the test a variant pair has to pass. `Shore Up` is free
on a turn where every point of pool is going into an attack, and that's most turns. Field
Surgery is for the turn you're not attacking anyway — which, notably, is the turn you're
most likely to be the one getting healed. It also overflows badly on a damaged Basic,
where `Shore Up` doesn't.

---

**Closing Ranks** — Support · **2 energy**
> Heal each of your units 20 HP.

`Field Rites` at double rate. On a full board of four it's 80 HP off one card, the largest
raw number in the file — which is exactly why it's 2 and not 1. Spread healing is worth
much less than its total, but 80 is far enough past the 50 that 1 energy buys that the
board-wide version has to cost a step more.

The card is a **catch-up** by construction, but a different flavor from `Sift the Ashes`:
it wants a wide board, not a dead one. Its ceiling arrives when you're stable and behind,
which is the position tower support decks live in.

Worthless on one unit — 32 for 2 energy against `Field Surgery`'s 80 for 1 is a bad trade
by a wide margin. The card is a board-state read, not a default, and at 2 energy it's
punishing to misread.

---

**Vigil** — Support · **2 energy**
> Heal one of your units **15 HP for each round that has passed**, counting the current
> one.

The answer to healing's expiry date, and the only heal in the file that gets *better* as
the game goes long. Round 3 heals 45, round 6 heals 90, round 10 heals 150 — which is more
than any unit's printed HP, but healing is capped at printed max, so the overflow is
wasted. That cap is the balance, and it's why Vigil doesn't violate the no-full-heals
rule: it's a **flat rate**, not a fraction of the target, so it overflows on a Basic
exactly the way `Grave Warden's Oath` does. It just happens to exceed most bodies once the
game runs long.

The 15-per-round rate is set against the tower's 5-per-round scaling, deliberately three
times it. A tower that's grown to 40 damage a turn needs a heal that grew too, and one
tower hit is what this is sized to undo.

Early, it's terrible — round 2 for 2 energy is 30 HP, worse than `Field Surgery` for
double the price. That's the intended shape. It's a late-game card that you either draw
late or hold, and holding it is a real cost against the hand limit.

---

**Grave Warden's Oath** — Support · **3 energy**
> Heal one of your units 120 HP.

The top of the ladder and the only 3-cost card printed so far. On the re-anchored rate
(base 32, +48 per energy) it would land at 176 — but that exceeds the largest printed HP
in the game, so it is **capped at 120** instead. The cap is the point rather than a
rounding: a heal that covers every body in the game is a full heal by another name, and
`CLAUDE.md` forbids those.

**It is not a full heal**, and the difference matters more than it looks. 120 is more than
most bodies can hold, so on most targets it deliberately overflows
and the excess is thrown away. That's the card's real cost: it's only efficient on the
biggest thing you own, and it's a waste on anything else. A full heal would have been the
opposite — perfectly efficient on every target, best on the biggest, and impossible to
price. This is what the no-full-heals rule buys.

Against `Last Breath`, which is free and heals 50 on a half-dead unit, the Oath buys two
things: **twice the healing, and no condition.** You can top up a Queen at 60/110 before
the hit that kills her lands, which `Last Breath` can never do.

Still the most likely mispriced card in the file. Three energy is a whole turn of midgame
income and buys a 38-damage attack instead, so the question is whether 100 HP on one body
beats removing a threat permanently. Flagged below.

---

### Damage & Removal

**Collapse** — Support
> Deal 20 damage to a unit that has no attached energy.

The conditional-damage template. 20 damage for free would be a 2-cost attack you didn't
pay for; restricting it to uncharged units means it only ever kills chaff and freshly
deployed bodies, never the unit someone invested in. It also creates a real read — deploying
a unit and charging it the same turn now has a defensive reason to it.

---

**Sever** — Support
> Destroy 2 attached energy on an enemy unit.

Attacks the investment instead of the body, which is the one thing this game's economy is
uniquely vulnerable to. Two energy is roughly a turn of income at midgame — squarely in
the band.

This is the first **anti-hoarding** card in the game, and it's neutral by necessity: the
core rules note that nothing yet punishes hoarding and that the answer belongs in Void.
Sever is the baseline that Void's version should be strictly more interesting than, not
strictly stronger.

---

**Toppling Blow** — Support
> Deal 25 damage to an enemy **tower**.

Reaches the attrition engine without spending a unit's activation. Towers are the forced
tempo of the early game, and a deck with no way to answer them just loses slowly — this is
the neutral answer, half a tower for one card.

Restricted to towers so it can't be a throne-burn plan. Throne damage must come from units,
which is what makes killing a tower meaningful.

---

### Tools

**One Tool per unit.** Free to attach, carries through evolution like attached energy,
discarded when the unit dies **or** retreats.

Tools pay out every turn, so each one is priced at roughly **a third of** what the
equivalent one-shot does — three to four turns to break even. That delay is the balance
mechanism, and the board enforces it: a Tool only earns while its unit lives, and units
die constantly. **Every Tool is a bet on a body surviving**, which makes Tools a wall's
best friend and a trap on chaff.

Tools are the one card type that rewards the thing this game otherwise punishes: keeping
a single unit alive for a long time.

---

**Bone Splint** — Tool
> Attached unit heals 5 HP at end of turn.

The break-even math, printed: 8 per turn against `Shore Up`'s 32 means four turns to match
it. Nearly worthless on chaff and quietly excellent on a Thornshade that the opponent has
decided not to attack.

---

**Weighted Chain** — Tool
> Attached unit's attacks deal 5 more damage.

The damage Tool, and the number is small on purpose. 5 per turn is under half a point of
energy's worth of damage (~12), so it never competes with actually paying for an attack —
it just makes a unit you were already attacking with slightly better. On a unit that
attacks every turn for the rest of the game it's the highest-ceiling Tool in the file,
which is the correct shape for a card that requires a body to survive indefinitely.

---

**Grave Anchor** — Tool
> Attached unit's retreat cost is reduced by 2, to a minimum of 0.

Makes a big unit genuinely extractable. Note it's a Tool, so it has to be attached
*before* you need it — you're paying a card in advance for an escape option you may never
use. And the Tool itself is discarded on the retreat it enables, so it's one use.

The answer to the open question about Stage 2s being too sticky, if that turns out to be
real.

---

**Ration Pack** — Tool
> At end of turn, move 1 energy from your pool to the attached unit.

An anti-decay engine. One energy per turn moved from the decaying pool onto a unit where
it's safe, automatically, forever. Slow — but it's the only card in the file that
addresses the pool-vs-attached tension structurally rather than once.

This is the Tool most likely to be too strong. It never stops paying, and on the Queen it
is a permanent 1-per-turn discount on the climb to 20. Flagged below.

---

**Iron Standard** — Tool
> Attached unit has `Retribution 5`.

Grants a keyword rather than a stat, and picks the one that best punishes this game's
economy — the opponent pays energy to attack and takes damage for it. Stacks with a unit's
printed Retribution, so on a Mourning Bell it's Retribution 20.

---

**Deadweight** — Tool
> Attach to an **enemy** unit. That unit's attacks cost 1 more energy.

The only Tool that attaches to something you don't control, and the file's second
anti-tempo card. Taxing an attack by 1 is small in absolute terms and large in a game
where the whole constraint is affording to act.

Because it occupies the enemy unit's Tool slot, it also blocks their own Tools — which is
a real second mode nobody will notice until it matters.

---

### Tower Support

Cards that modify a tower you control. **Permanents stack without limit** — a tower may
hold any number, repeats included, and their effects add together. One-shots attach
nothing. All permanents are lost when the tower dies. See `CLAUDE.md` for the full rules.

The hard line: **nothing here raises the rate at which a tower hits structures.** A tower
reaches its facing board's tower and throne only through the quarter-damage rule for an
empty board, and every buff on this list is quartered along with the base — no card lifts
that quarter, waives its minimum-1 floor, or reaches a structure past a living unit. A
tower hitting structures at *full* rate is what would make units irrelevant.

These are cheap because they're self-limiting — a tower you're investing in is a tower
you're keeping alive, and a live tower occupies one of your three lane slots. **Tower
support is a deck that chooses to play on 4 unit slots while the opponent moves to 6.**

---

**Reinforced Base** — Tower Support *(permanent)*
> Target tower gains **+20 max HP**.

The baseline, and deliberately max HP rather than a heal — it raises the ceiling, so it
stacks with the tower's own +5/turn growth instead of being erased by it. A 50 HP tower
that would have been dead on turn 4 now lives to turn 6, which is two more turns of it
eating a unit.

---

**Murder Holes** — Tower Support *(permanent)*
> Target tower deals **+5 damage**.

Small on purpose. Tower damage already scales +5 a round, so this is one extra round of
scaling, permanently. It matters most in the early game, when +5 on a 5-damage tower is
double, and fades to noise by turn 10 — the opposite curve from most cards here, and the
right one for a card that's free and always live.

---

**Crossfire** — Tower Support *(permanent)*
> Target tower also fires for **5 damage** at the **other** enemy board.

The reach card. Towers otherwise only ever touch the board in front of them, and
`Crossfire` is the only thing in the game that lets a structure hit across boards. It's 5
damage — chip — but it hits a board the opponent thought was safe, which changes where they
place units.

It resolves through the same chain as the tower's main shot: full damage to a living unit
there, and if that board is clear, a quarter into its tower or throne — which at 5 damage
is the minimum 1. The old text restricted it to the facing *slot* and to units only; the
quarter-rate rule replaced both, so crossfire is no longer a special case with its own
targeting.

---

**Rebuild** — Tower Support *(one-shot)*
> Heal target tower **25 HP**. It cannot be healed above its max HP.

`Shore Up` for structures, same number. Doesn't take the permanent slot, so it stacks with
`Reinforced Base` — and it's better *because* of it, since Reinforced Base raised the
ceiling this heals toward.

The cap is the important clause. Uncapped tower healing plus the tower's own growth is the
stall engine this card class has to avoid.

---

**Spite Engine** — Tower Support *(permanent)*
> When target tower **dies**, deal **20 damage** to the enemy unit in the slot facing it.

Turns a lost tower into one last swing. Tower support is otherwise all investment in
something that will eventually die anyway — this is the card that makes the investment pay
out on the way down, which is the same idea as Hel's `Toll` applied to structures.

It also plays against the tower-sacrifice line in the core rules: if you're going to give
up a tower for the slot, `Spite Engine` charges the opponent for the privilege.

---

**Open the Gate** — Tower Support *(one-shot)*
> **Destroy** your own target tower. Draw 2 cards.

The anti-stall card, and the one that keeps this whole class honest. `CLAUDE.md` says you
may strategically sacrifice your own tower for board space — this is the card that does it
on your schedule instead of waiting for the opponent to break it.

Opens the third slot on that board immediately and exposes your own throne, which is a
real price. Every permanent tower support on that tower is lost with it — and since
permanents stack, a fortified tower is an expensive thing to knock down yourself.

---

**Watchfires** — Support
> Reveal cards from the top of your deck until you reveal a **tower support** card. Put it
> into your hand and shuffle the rest back.

The tower-support tutor, and the reason the class hangs together as an archetype rather
than being six loose cards.

Digs an arbitrary distance for exactly one card type, which is only reasonable *because*
tower support is the weakest class in the file — the payoff for finding one is a +20 max HP
tower, not a win condition. In a deck with no tower support cards it whiffs entirely and
mills nothing (everything shuffles back), so it's strictly a build-around.

Note it's a plain support, not a tower support: it works with both towers dead, and it
doesn't take a tower slot.

---

## Priced Variants

**Healing is the first — and so far only — class with priced cards.** Four of them, listed
under *Healing* above: `Field Surgery` (1), `Closing Ranks` (1), `Vigil` (2), and
`Grave Warden's Oath` (3). Healing was the right class to start with because it's the one
with a built-in expiry date — a fixed heal loses to a growing tower — so it's the class
where paying for a bigger effect answers a real problem instead of just buying power.

The pattern: take a free card whose power is held down by a **restriction**, and print a
second card that is the same effect *without* it. The restriction that gets dropped sets
the price, and both cards stay playable — the free one because it's always castable, the
priced one because it's better when the pool allows.

The remaining free cards whose restrictions are the most natural things to sell:

| Free card | Its restriction | Variant sells | Likely cost |
|---|---|---|---|
| `Collapse` | target must have no attached energy | any unit | 2 |
| `Line of Succession` | the evolution found is random | chosen | 2 |
| `Grave Market` | the discard pull is random | chosen | 2–3 |
| `Read the Bones` | the card found is delayed a turn | straight to hand | 3 |
| `Muster` | Basics only | any unit | 1 |
| `Withdraw` | — pays retreat from pool | pays nothing at all | 1 |

Two are worth flagging before anyone writes them. **A chooseable `Grave Market` is the
recursion loop the random version was built to kill** — two copies fetch each other
forever — so if it gets printed, the energy cost is now the only thing throttling the loop,
and 2 is probably too cheap for that job. And **an unconditional `Collapse` is 20 free-ish
damage for 2**, which is the closest any support gets to the attack curve; it's inside the
band only because that same 2 energy buys 25 on an attack that then repeats every turn.

Not every free card wants a variant. `Offering` can't have one (energy-for-energy is
banned), `Reposition` is already the cheapest thing here, and the Tools and tower support
are off-limits by rule. **Print these sparingly** — a file where most cards have an
upgraded twin has doubled in size without adding an idea.

---

## The Support Curve

Every one-shot trades **one card** for roughly **one turn of tempo**. Tools trade one card
for a third of that, every turn, for as long as the body lives. A priced support trades a
card *and* energy, and buys about one band step per energy.

| Card | Cost | Type | What one card buys |
|---|---|---|---|
| Gravekeeper's Ledger | — | Support | +2 cards |
| Scavenger's Instinct | — | Support | +1 card, chosen from 5 |
| Last Rites | — | Support | +1 card, 2 discards |
| Second Thoughts | — | Support | +1 card, hand reset |
| Muster | — | Support | Finds a Basic |
| Roll Call | — | Support | Finds 2 Basics, revealed |
| Line of Succession | — | Support | Random Stage 1 or 2 |
| Read the Bones | — | Support | Finds anything, delayed a turn |
| Grave Market | — | Support | Random card from discard |
| Offering | — | Support | +3 pool energy |
| Sift the Ashes | — | Support | +0 to 4 energy, conditional |
| Tithe | — | Support | Relocates an investment |
| Escape Route | — | Support | Full energy recovery off one unit |
| Withdraw | — | Support | Extracts a unit with no attached energy |
| Ground Give | — | Support | Extracts a unit, energy written off |
| Rally the Line | — | Support | Removes the retreat lock |
| Reposition | — | Support | Shoves an enemy unit within its board |
| Hold the Slot | — | Support | Survives one turn |
| Mend | — | Support | +16 HP |
| Shore Up | — | Support | +32 HP — the baseline |
| Field Rites | — | Support | +16 HP to every unit |
| Last Breath | — | Support | +80 HP, needs half HP |
| Reconsecrate | — | Support | +32 HP, undoes Decay |
| **Field Surgery** | **1** | Support | +80 HP |
| **Closing Ranks** | **2** | Support | +32 HP to every unit |
| **Vigil** | **2** | Support | +24 HP per round elapsed |
| **Grave Warden's Oath** | **3** | Support | +120 HP |
| Collapse | — | Support | 20 damage to an uncharged unit |
| Sever | — | Support | −2 enemy attached energy |
| Toppling Blow | — | Support | 25 damage to a tower |
| Bone Splint | — | Tool | +8 HP per turn |
| Weighted Chain | — | Tool | +5 damage per attack |
| Grave Anchor | — | Tool | −2 retreat cost |
| Ration Pack | — | Tool | +1 pool→attached per turn |
| Iron Standard | — | Tool | Retribution 5 |
| Deadweight | — | Tool | Enemy attacks cost +1 |
| Watchfires | — | Support | Digs for a tower support card |
| Reinforced Base | — | Tower, permanent | Tower +20 max HP |
| Murder Holes | — | Tower, permanent | Tower +5 damage |
| Crossfire | — | Tower, permanent | Tower hits the other board for 5 |
| Spite Engine | — | Tower, permanent | 20 damage when the tower dies |
| Rebuild | — | Tower, one-shot | Tower +40 HP |
| Open the Gate | — | Tower, one-shot | Kill your tower, draw 2 |

**43 neutral cards** — 31 one-shot supports, 6 Tools, and 6 tower support. Grouped as
draw (4), search (5), energy (3), retreat (4), board (2), healing (9), damage (3),
tools (6), tower (6), plus `Watchfires`.

**Four cost energy, all of them heals**; the other 39 are free. Healing is now the
largest class in the file at 9 cards, which is deliberate — it's the class with the most
natural ladder, since "how much" is a number that can be moved without changing what the
card does.

Deliberately no card in this list is a build-around **except `Watchfires`**, which only
functions in a deck built around tower support. That's the one intentional exception, and
it's safe because the archetype it enables is the weakest one here.

Neutral supports are the floor; faction supports are where the deckbuilding decisions
should live.

---

## Open Questions

- **Is `Grave Warden's Oath` worth 3?** Three energy is a full turn of midgame income and
  buys a 38-damage attack instead. 100 HP on one body looks bigger, but damage removes a
  threat permanently while healing only delays one — and the Oath overflows on everything
  smaller than the Queen, so its real value is well under 100 most of the time. The file's
  first 3-cost and the most likely to be mispriced in either direction; if it's never
  played, 2 is the real ceiling for the whole tier.
- **Is 100 too close to a full heal in practice?** The no-full-heals rule is about
  *scaling*, and a flat 100 satisfies it — but the current biggest body is the Queen at
  110, so on the target it's actually aimed at, 100 is nearly a reset anyway. The rule
  earns its keep the moment a bigger unit is printed, and it already stops the card from
  growing on its own. Worth revisiting if Stage 2 HP ever climbs.
- **Does `Vigil` invert healing's expiry too hard?** Healing is supposed to be an early-
  and mid-game class that fades against tower scaling. Vigil is explicitly built to not
  fade, and at 15/round it outpaces the tower's 5/round by 3×. The printed-HP cap is the
  only brake, and past round 8 the card is simply "fully heal a unit for 2" — cheaper
  than the Oath, which is a strange result. May want to be 10/round, or capped.
- **Do the priced heals trade off with their free versions, or just outrank them?**
  `Field Surgery` vs. `Shore Up` and `Closing Ranks` vs. `Field Rites` are the file's first
  real test of the variant pattern. The intended answer is that the free one wins on any
  turn you're spending pool on attacks — that's most turns — and that the priced one
  overflows badly on a small target. If the priced card is simply better whenever it's
  affordable, the pattern has failed and the free ones are the cards to cut.
- **Is `Mend` at 10 worth a slot at all?** It exists to give the ladder a rung below the
  baseline, but a 10 HP heal in a game where towers hit for 25+ by midgame may be a card
  nobody ever runs. Being unplayed is a worse outcome than being redundant; if it doesn't
  find a home, cut it and let 20 be the floor.
- **Nine healing cards may be too many.** Healing is now the largest class in the file,
  and `CLAUDE.md` already flags that a support-heavy AI mirror runs to round 24 partly
  *because* of healing. Adding four more heals — three of them bigger than anything that
  existed — pushes directly on the game-length problem that was already open. This is the
  most likely thing in this batch to need cutting after playtesting.
- **Which other free cards should get priced variants?** Six candidates remain under
  *Priced Variants*. Healing took the first batch; the next should probably be a
  different class entirely, so the pattern doesn't read as a healing-only mechanic.
- **Is `Gravekeeper's Ledger` the right ceiling?** Draw 3 for free with no play limit is
  the most likely thing in this file to be broken. Four Ledgers in a 60-card deck plus
  unlimited plays per turn is a real engine. If it needs a nerf, draw 2 is the obvious
  step, but that makes it strictly worse than `Scavenger's Instinct` for most decks.
- **Does `Escape Route` + a heavily charged Stage 2 break the energy economy?** Charge a
  unit to 20, retreat it for free, and the whole 20 goes back to the pool where it only
  decays 20%. That's a way to move a huge investment off a threatened unit for one card.
  It may be correct — it costs the board slot and three turns of replay — but it's the
  most likely degenerate line in the file.
- **Should support cards be discarded or exiled?** Much less urgent now that `Grave
  Market` pulls at random — the deterministic recursion loop is gone, since you can't
  reliably pull back the card you want. Supports currently go to the discard and stay
  reachable. The remaining question is whether *any* support should be re-buyable at all
  in a game with no other recursion for them; leaving it as-is until a faction prints a
  chooseable discard-recursion card, which is where it'll actually bite.
- **Is `Ration Pack` too strong?** It never stops paying and it's the only card that
  structurally answers pool decay. On the Queen it's a permanent discount on the climb to
  20, and unlike every other Tool there's no point at which it stops mattering. May need
  to cap total energy moved, or be a one-shot instead.
- **Does `Muster` need to exist as a card, or should it be a rule?** A hand with no Basic
  can't develop a board at all, which is a non-game. Muster fixes that for decks that run
  it — but decks that don't still lose to it. The alternative is a mulligan rule that
  guarantees a Basic in the opening hand, which is cleaner and doesn't cost a deck slot.
  Related to the unimplemented mulligan in `CLAUDE.md`.
- **`Deadweight` occupying an enemy Tool slot is undiscovered tech.** It's a real second
  mode — attaching it to deny a Tool rather than to tax attacks — and nobody will read the
  card that way at first. Fine as a discovery, worth watching in case it's the *primary*
  use, which would mean the card is mispriced.
- **Search may make decks too consistent.** Five search cards plus four draw cards in a
  60-card deck means the same opening every game, which is the thing a 60-card deck is
  supposed to prevent. Randomizing two of the five helps, but `Muster` and `Roll Call`
  are still fully deterministic and they're the ones every deck wants.
- **Does `Line of Succession` punish multi-line decks too hard?** Running four evolution
  lines — which `hel.md` currently does — makes it a coin flip that often returns a Stage
  2 you can't use for many turns. That's the intended deckbuilding pressure, but it may
  be so unreliable in practice that nobody runs it, which makes the card pointless rather
  than interesting. Restricting the random pull to **Stage 1 only** is the obvious dial if
  so: still random, far less likely to whiff into something dead.
- **Is `Sever` in the right file?** It's the anti-hoard card, and `CLAUDE.md` says
  anti-hoard belongs in Void. It's here because every deck needs *some* answer to a
  50-energy Queen. Might be better as Void's signature and cut from neutral entirely.
- **Do faction supports need their own line rule?** Units have the two-line rule. Supports
  currently have an informal one-effect rule that isn't enforced by anything. It probably
  should be a real rule before faction supports get written.
- **The AI-vs-AI harness stalls intermittently.** `SupportTest.gd`'s mirror match hit its
  300-turn guard once in ~15 runs on 2026-08-08 and failed the "game reached a conclusion"
  assertion; every other run finished in rounds 6–18. The deck it uses contains none of
  the priced heals, so this predates them and is not caused by the heal rework. Worth
  finding before the numbers from this harness are trusted — an intermittent stall means
  there is a reachable board state neither AI can close, which is the same stall risk
  `CLAUDE.md` flags for tower support. A seeded RNG would make it reproducible.
- **Does the AI use supports well enough for playtest data to mean anything?** It plays
  draw, energy, healing, damage, Tools, and tower support on a priority list, but it
  deliberately never plays the retreat or repositioning cards — those are board reads it
  isn't equipped to make, and playing them badly would be worse than holding them. The
  support-heavy AI mirror was previously recorded here as running to about **round 24**;
  re-measured 2026-08-08 over five runs it ended on rounds **9, 9, 10, and 18**, so the
  real picture is high variance around 9–18 rather than a reliable slowdown. Measured
  against an AI that ignores a whole card class, so treat any single number as noise.
