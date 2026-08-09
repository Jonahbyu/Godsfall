# Void — Faction Design

> Read `CLAUDE.md` first for core rules, board geometry, and the energy economy.
> `Consume` is a **shared keyword** defined there. This file covers Void's two
> signatures, the Gap, and its cards.

**Domain:** Absence, entropy, unmaking.
**Verb:** Deny.
**One-line identity:** *Absence is a resource.*

**Status: built.** 15 units, an energy card, 4 supports, and 1 Tool are in
`data/cards.json`. `Siphon`, `Void N`, the Gap, and `Rift N` are implemented in
`GameState`, with AI heuristics and two sample decks. Verified by `VoidTest.gd`
(61 assertions).

---

## Why Void Exists

`CLAUDE.md` named a gap in the faction set: **nothing punished hoarding.** Hel is
structurally the banking faction and had no predator.

Every other faction interacts with **bodies** — Hel converts them to energy, Heaven
refuses to let them die. Void interacts with the **energy economy itself**, which is the
one untouched axis and what makes a Void matchup feel different rather than merely
differently-statted.

**The design risk, named up front:** energy denial is famously miserable to play against.
Land destruction, mana burn, and discard win by removing the opponent's game rather than
playing your own. Void's version costs Void something too — see *The Brakes*.

---

## Keywords

| Keyword | Effect |
|---|---|
| **Siphon N** | *(Void signature)* Move up to N attached energy from a target enemy unit onto this unit. |
| **Void N** | *(Void signature)* Destroy up to N attached energy on a target enemy unit. |
| **Rift N** | Not a keyword but a printed stat. This unit's attacks deal **+N damage per point of Gap**. |

And one global state value both players can read, like the turn counter:

| Term | Meaning |
|---|---|
| **Gap** | Your total attached energy minus the opponent's, floored at 0. |

### Siphon — the primary

**Siphon takes; it does not destroy.** The energy moves onto the Void unit that used it.

- **It hits attached energy, not the pool.** Pool destruction is chip against a resource
  that decays anyway. Attached energy is *the investment* — the thing the whole game is
  about protecting — so taking it is the only denial that costs the opponent something
  they chose.
- **It uses the same targeting chain as damage**: the slot across, then the leftmost
  living unit. It never falls through to a tower or throne, because structures hold no
  attached energy. **Energy denial can never reach somewhere an attack could not.**
- **It double-moves the Gap** — −1 on their side, +1 on yours. A `Siphon 2` swings the Gap
  by 4. This is the engine that feeds Rift.
- **It is counterplayable in a way destruction is not.** Over-charging a single body is a
  *mistake the opponent made*, which is the decision the whole game already asks.

**On a support card, Siphon goes to the pool instead**, because a support has no body to
carry it. That is a real difference and it cuts both ways: pool energy is safe from unit
death but exposed to the 20% decay, and it does **not** feed the Gap. Support Siphon is
ramp; unit Siphon is ramp *and* Gap — which is what keeps the units at the centre of the
faction.

### Void N — the sharper, rarer version

Destruction, printed where theft would be wrong. It takes nothing back, which is why it is
priced *below* Siphon on a comparable body: it is the harsher effect for the opponent and
the weaker one for you.

The damage riders are what make it a card rather than a tax:

> **Unmake** — 12 damage; Void 1. Deal 15 more for each energy destroyed this way.

That rider is **conditional damage** — against an uncharged body it deals zero. This is the
self-balancing property the pool version never had: **Void is efficient against the
committed and weak against the empty board**, which is exactly the anti-hoard predator role
the core rules asked for.

### The Gap, and why it is *mine minus theirs*

The direction is not a preference — it falls out of the arithmetic, and getting it backwards
breaks the faction.

`Siphon` **moves** energy from an enemy unit onto one of yours. It lowers their total and
raises yours. So if the Gap were defined as *theirs minus mine*, every successful Siphon
would **shrink** the number its own faction's payoff cards read. Void's primary keyword
would be actively turning off Void's payoff, which is the one shape the faction must not
have. Defining it as *mine minus theirs* makes Siphon swing it by 2N in your favor, and the
two signatures compound.

**It floors at 0.** A negative Gap would make Rift units deal *less* than their printed
number, which reads as a hidden penalty on a card whose text only promises a bonus.

**It counts living units only.** Within a volley a unit marked dead stays on the board so it
can still deal `Retribution`, but its attached energy is already forfeit — counting it would
let a corpse inflate the Gap for the rest of the resolution.

### Rift — the midgame payoff

`Rift N` is printed on a unit and read **at resolution**, not when the attack is queued. The
Gap is public and both players act on it, so a number that moves between queueing and
resolving is correct rather than a gotcha.

**Rift is uncapped, and that is the point.** Reaching a large Gap means committing a large
amount of energy to bodies that can all die at once, losing every point of it. A player who
has assembled a 30+ Gap has taken that risk and survived it, and winning from there is the
mechanic paying out — not a balance failure to be designed around.

What bounds it in practice is the board, not a number: **Void carries the most vulnerable
energy in the game**, and a board wipe zeroes the Gap instantly. An AI probe showed exactly
that shape — the Gap climbing, then collapsing to 0 the moment the board was cleared.

The only structural limits are that just one card prints `Rift 2`, and that the base-damage
budget below prices the keyword's existence.

---

## The Three-Phase Arc

This is the shape of a Void game and the faction's whole identity.

| Phase | Engine | Why it works, and why it stops |
|---|---|---|
| **Early** | Siphon as **starve** | Turns 2–4, both players hold 2–6 energy total. Taking 1–2 attached is a large fraction of everything that exists. |
| **Mid** | **Rift** as payoff | The Gap is large *because* you spent the early game siphoning. Every point stolen counted twice. |
| **Late** | **Pool destruction** | `Unmaker of Thrones` is worthless early (nobody is banking) and devastating late. Anti-hoard tech lands where hoarding actually happens. |

**Siphon is deliberately outclassed by the late-game economy.** By turn 9 an energy card
alone pays 10, so siphoning 2 is noise. The keyword is never nerfed — *the economy outgrows
it*, and `t + 1` income does that for free without a line of rules text.

The phases compose rather than merely following one another: **Siphon's early work is banked
into the midgame payoff.** It stops mattering *directly*, not entirely.

---

## The Damage Budget

Void buys denial and scaling, so its raw damage sits below the standard 12-per-energy curve
— the same shape as Heaven's Judgment rate cut. Enforced by a test in `VoidTest.gd`, not by
convention.

| Line type | Budget |
|---|---|
| **Siphon** attack | `10 × cost − 5 per Siphon point` |
| **Rift** attack | `10 × cost − 8 per Rift point` |
| **Plain** attack | `12 × cost` — the standard curve |

**The Rift discount pays for the keyword existing, not for its unbounded tail.** It is
deliberately *not* priced against a large Gap. A Void player holding a 30+ Gap has staked 30
energy on bodies that all die at once — winning from there is the payoff working as designed,
not a balance failure.

**A cut to 11 was tried and reverted**, and the reasoning is worth keeping because it
generalizes: **a flat reduction to printed damage is the wrong lever for a scaling
mechanic.** At Gap 30 the cut moved `Null Adept` from 42 damage to 39 — noise. At Gap 0 it
moved 12 to 9 — a 25% cut. It taxed the early game, where Void is already weakest, and did
nothing at the Gaps that prompted it. If uncapped Rift ever does need bounding, the lever is
a printed cap on individual cards (*to a maximum of +N*), which bites where the problem is.

**Plain attacks keep the standard curve**, and `Rust Crawler` / `Hungering Maw` exist to
prove the cut is about the riders and not about the color — the same job `Warden of the Lamp`
does for Heaven.

---

## Evolution Lines

### The Thief — Siphon into the Gap
`Hollow Acolyte` → `Severance Priest` → `The Absence`

The flagship. Ends on the only card holding both signatures: Siphon feeds its own Rift, so
every point stolen is two more damage next turn.

### The Rift — pure scaling
`Null Adept` → `Entropy Warden` → `Throat of the Void`

Deliberately weak printed damage at every stage, ending in the faction's only `Rift 2`.

### The Unmaking — destruction, not theft
`Gnawing Absence` → `The Unwritten` → `Unmaker of Thrones`

The line that takes nothing back, ending in the pool-destruction rule-breaker.

### The Long Quiet — the closer
`Rust Crawler` → `Famine of Forms` → `Silence Eternal`

Starts as the faction's honest standard-curve body and ends as its win condition.

### Unlinked
`Ashen Pilgrim` — the free repeating Siphon, and the engine the aggro build is designed
around. `Sundered Wretch` → `Hungering Maw` is the wall pair.

---

## Cards

All units obey the **two-line rule**. Costs are Void energy.

### Basics

**Ashen Pilgrim** — 40 HP
◆ **Beg the Void** — *ability* — Siphon 1
▸ **Thin Blade** — 1 Void — 12 damage

> Pure ramp, and the only free repeating Siphon in the faction. A free ability every turn is
> what makes the aggressive build work; the once-per-turn limit is its whole price.

---

**Hollow Acolyte** — 45 HP
*Siphon 1*
▸ **Draw Thin** — 2 Void — 15 damage; Siphon 1

> The cheapest theft in the game, and the entry to the flagship line.

---

**Rust Crawler** — 50 HP
▸ **Corrode** — 2 Void — 24 damage

> No text, standard curve. The control card that proves Void's rate cut is about its riders,
> not its color. Also the Basic under both `Famine of Forms` and `Silence Eternal`.

---

**Null Adept** — 50 HP
*Rift 1*
▸ **Widen** — 2 Void — 12 damage

> The cheapest Rift body. At Gap 12 it is 24, exactly the standard curve for 2 energy — this
> card is the statement that Void's damage is *deferred*, not cheap. Every point of Gap past
> that is profit.

---

**Gnawing Absence** — 55 HP
▸ **Unmake** — 3 Void — 12 damage; Void 1. Deal 15 more for each energy destroyed this way.

> Zero rider against an empty body, 27 total against a charged one. Void's whole thesis on
> one card.

---

**Sundered Wretch** — 85 HP
▸ **Collapse Inward** — 3 Void — 36 damage

> An 85 HP Basic on the standard curve. Void's wall, and the safest body to leave siphoned
> energy sitting on.

### Stage 1

**The Unwritten** — 80 HP — *evolves from Gnawing Absence*
◆ **Blank the Page** — *ability, Consume 1* — Void 2 on a target enemy unit
▸ **Erasure** — 2 Void — 16 damage

> `Consume 1` is mandatory. As a free ability this is a repeating energy strip with no cost
> at all, which is the same reasoning `hel.md` gives for `Dirge`.

---

**Severance Priest** — 90 HP — *evolves from Hollow Acolyte*
*Siphon 1*
▸ **Sever** — 3 Void — 25 damage; Siphon 1

> The workhorse. Siphon 1 every turn, forever, on a body that survives a volley.

---

**Entropy Warden** — 95 HP — *evolves from Null Adept*
*Rift 1*
▸ **Erode** — 3 Void — 22 damage

> At Gap 12 this is a 34-damage attack that cost 3.

---

**Famine of Forms** — 100 HP — *evolves from Rust Crawler*
*Siphon 2*
▸ **Starve** — 4 Void — 28 damage; Siphon 2

> Siphon 2 is the ceiling — four energy of swing per turn, on a body that has to survive to
> do it.

---

**Hungering Maw** — 115 HP — *evolves from Sundered Wretch*
▸ **Devour the Light** — 5 Void — 60 damage

> No rider at all: the standard curve on Void's biggest Stage 1. The honest beater.

### Stage 2

**Unmaker of Thrones** — 120 HP — *evolves from The Unwritten*
◆ **Null the Pool** — *ability, Consume 2* — destroy 20% of the enemy **pool**, minimum 2
▸ **The Last Absence** — 6 Void — 48 damage

> The rule-breaker: the only card in the faction that reaches the pool. Percentage-based so
> it scales with what is actually there, exactly like the 20% end-of-turn decay it models —
> worthless against a spent pool, devastating against a hoarder.

---

**The Absence** — 130 HP — *evolves from Severance Priest*
*Siphon 2, Rift 1*
▸ **The Widening** — 5 Void — 34 damage; Siphon 2

> The only card holding both signatures. The Siphon resolves **before** the damage, so its
> own theft counts toward the Gap its Rift then reads — the two compound within one attack.

---

**Throat of the Void** — 145 HP — *evolves from Entropy Warden*
*Rift 2*
▸ **Swallow** — 6 Void — 44 damage

> The single `Rift 2` in the faction, deliberately — two points on a cheap body would scale
> past everything else in the game. At Gap 20 it hits for 84, still short of a fresh Stage 2
> in the 110–175 band. Past that it is genuinely unbounded, which is the intended payoff for
> having staked that much energy on bodies that can die.

---

**Silence Eternal** — 175 HP — *evolves from Famine of Forms*
▸ **The Long Quiet** — 8 Void — 10 damage to the enemy throne per point of Gap, max 100

> The win condition. It converts the Gap into throne damage, which is the one thing Rift
> cannot do — Rift only ever adds to a lane attack, and lane attacks are stopped by
> shielding.
>
> **It does not break the shielding rule.** It still routes through the ordinary targeting
> chain, so the enemy board must already be clear. What it breaks is the damage curve, and
> only in proportion to a Gap the player had to build. The 100 cap means it can never
> one-shot a throne that has been growing all game.

### Supports

| Card | Cost | Effect |
|---|---|---|
| **Draw Down** | 0 | Siphon 1 from a target enemy unit (into your pool) |
| **Exsanguinate** | 2 | Siphon 3 from a target enemy unit |
| **Unwrite** | 1 | Destroy **all** attached energy on a target enemy unit |
| **Widening Rift** | 0 | Damage to a target enemy unit equal to twice the Gap, max 30 |
| **Event Horizon** | Tool | Attach to a unit. That unit gains `Rift 1`. |

`Draw Down` / `Exsanguinate` are the free/priced pair the support rules ask for: the same
effect, the restriction traded for a cost. `Unwrite` is priced *below* `Exsanguinate`
despite destroying more, because destruction gives you nothing back.

`Event Horizon` is a bet that a body survives, which is exactly the bet a Gap deck is
already making.

---

## The Brakes

Siphon + expensive attacks + an uncapped Gap payoff is **three snowball mechanics pointing
the same direction**. Each is fine alone; together they describe a faction that either fails
to start or cannot be stopped. These are load-bearing:

- **Siphon numbers stay at 1–2.** Never 3 on a unit.
- **Siphoned energy lands on the unit that took it, not in the pool.** Void's stolen gains
  sit on a body that can die — and when it dies, everything it stole is lost. **Void carries
  the most vulnerable energy on the board.** This is the faction's self-cost and the main
  thing that makes it fair. An AI probe showed exactly this: the Gap climbs to 12–13 and
  then collapses to 0 when the board is wiped.
- **Exactly one `Rift 2`, on a Stage 2.** Enforced by a test.
- **Rift attacks pay 11 damage per Rift point off their printed base.**
- **Energy denial obeys the targeting chain**, so it can never reach past a shield.

---

## Open Questions

- **Uncapped `Rift` is a deliberate bet, not an oversight.** Settled in conversation: a 30+
  Gap means you have already staked that much energy on mortal bodies, so winning from there
  is correct. The open part is whether a *human* can actually reach a large Gap without
  simply losing the board first — every large-Gap sample so far came from the AI dumping its
  whole pool onto one unit, which is not a real line of play. If it ever does need bounding,
  the lever is a printed cap on individual cards (*to a maximum of +N*), never another cut to
  base damage — see the budget section for why that lever does not work.
- **Does the Gap floor at 0 make Void bad against decks that never charge?** A Hel aggro
  deck that dumps everything into cheap bodies and lets them die keeps its attached total
  near zero — which is *good* for Void's Gap (mine minus theirs). But a Void deck that is
  itself behind on board has no Gap at all, so Rift is dead exactly when Void is losing.
  That is intended (Void is not a comeback faction) but it may be too punishing.
- **Is `Silence Eternal` reachable?** 8 energy on a Stage 2 at the end of a four-card line,
  needing a Gap of 10 to max out. It may simply never be cast. The AI never got there in the
  sample games.
- **Void has no healing and no defensive keyword.** It holds the game's most vulnerable
  energy and has no way to protect the bodies carrying it, relying entirely on neutral
  supports. That may be correct (fragility is a stated brake) or may make the faction
  unplayable against Heaven.
- **`Beg the Void` may be too good.** A free, repeating, once-per-turn Siphon on a 40 HP
  Basic is the single most efficient card in the faction, and the aggro deck runs four.
- **Does support-Siphon-to-pool read as inconsistent?** The same keyword does two different
  things depending on whether it is printed on a unit or a card. The reasoning is sound (a
  support has no body) but it is a rules wrinkle a player has to learn.

---

## AI and Balance Notes

`AIPlayer` has Void heuristics: it targets the most-charged enemy body for theft, scores
Rift's Gap bonus and the per-energy-destroyed rider as **effective** damage rather than
printed, fires `Silence Eternal` on throne lethal, and refuses to spend a `Consume` on
denial when the enemy board holds no energy.

### AI results are worth less for Void than for any other faction

**`AIPlayer._dump_leftover_energy` banks its entire remaining pool onto its toughest unit
every single turn.** For Hel and Heaven that is a harmless hedge against decay. For Void it
is *the payoff engine*, because the Gap is exactly "my attached energy minus theirs" — so
the AI plays a maximal Rift strategy by accident, and far harder than a human would. A human
charges what they intend to spend; the AI commits everything.

Measured over 12 runs per matchup (2026-08-08), tracking the **peak** Gap reached:

| Matchup | Result | Avg peak Gap | Max |
|---|---|---|---|
| Widening Rift vs Lamp Wall | 12–0 | 31 | 83 |
| Widening Rift vs Verdict Engine | 11–1 | 34 | 91 |
| Widening Rift vs Barrow Wall | 10–2 | 56 | **231** |
| Widening Rift vs Toll Engine | 4–8 | 26 | 106 |
| Starve vs Lamp Wall | 9–3 | 43 | 82 |
| Starve vs Verdict Engine | 7–4 | 115 | **298** |

**A peak Gap of 231 is not a game state a human reaches.** It is one AI holding a couple of
hundred energy on a single body because it had nothing else to do with the pool. The win
rates above are therefore an upper bound on Void's strength, measured under conditions that
maximise its scaling mechanic — not a balance reading.

Two consequences:

- **Do not tune Void's numbers on these results.** An earlier round of tuning did exactly
  that, cutting Rift base damage on the strength of an 8–1 sample. The cut was reverted once
  the cause was traced: the deck was winning on the AI's charging behaviour, not on card
  design. At the Gap range a real game reaches (10–15), every Rift card sits *on or under*
  the standard damage curve.
- **The fix is an AI change, not a card change.** `_dump_leftover_energy` should hold back
  energy rather than commit all of it — which would make readings for every faction more
  realistic, not only Void's.

### The one result that is probably real

**Widening Rift loses to Toll Engine 4–8**, despite the AI's charging behaviour favouring
Void. Toll Engine beats everything (see `hel.md`), and it is the matchup where Void's
scaling never gets going, because Toll Engine's units die on purpose and hold no energy to
siphon. That is the intended weakness — Void preys on commitment, and a deck that commits
nothing starves it.

No stalls in any Void matchup, worth noting given the stall risk `CLAUDE.md` flags.
