# Heaven — Faction Design

> Read `CLAUDE.md` first for core rules, board geometry, and the energy economy.
> `Judgment`, `Sanctuary`, `Rise`, `Retribution`, and `Consume` are **shared keywords**
> defined there. This file covers Heaven's tuning of them and its cards.

**Domain:** Order, light, judgment.
**Verb:** Protect.
**One-line identity:** *Every reprieve is finite.*

---

## Why Heaven Works In This Engine

Heaven does not reduce damage and it does not out-heal you. It **buys time in discrete,
countable units** — a shield that absorbs one blow, a reprieve that turns a death into a
survival at low HP. Each is spent when used and does not come back on its own.

That grammar is the faction. Heaven's cards carry *charges*, and playing Heaven well is
deciding when to cash them. It is the same shape as the game's central pool-versus-attached
tension, moved onto the body itself: a resource that is only valuable while unspent, where
you have to guess which use you will need more.

Three structural advantages unique to this faction:

**Heaven buys the top of the health bar, not damage.** `Judgment N` executes anything left
at or below N, so a Judgment 30 attacker only needs to deal 20 to kill a fresh 50 HP basic
(and 60 to kill a 90 HP Stage 1).
Against the standard 12-damage-per-energy curve that is a discount worth `N ÷ 12` energy —
which is exactly why Judgment units are priced at ≈8 per energy instead.

**Heaven denies the retarget.** A judged unit survived, so it is still alive, so it still
shields its board and still eats the next attack in the volley. `CLAUDE.md`'s no-overkill
rule means clearing a board is how you reach a tower — Judgment is the keyword that makes
clearing take one more attack than the opponent budgeted.

**Judgment combos with itself, for free.** A unit judged down to N is now inside execute
range of every other Judgment unit you control. No card text is spent describing this; it
falls out of the keyword.

**The tension:** Heaven's reprieves are single-use, and its damage is below curve. A Heaven
board that has spent all its charges is a board of underpowered attackers. The faction wins
by making the opponent spend more attacks than they have, and loses when it runs out of
reprieves before they run out of energy.

**Heaven and Hel define each other.** The faction that profits from death against the one
that refuses it. Both print `Rise`, and it reads as two answers to the same question — Hel
recycles because death is income, Heaven returns because judgment is deferred.

---

## Keywords

Heaven prints four shared keywords. The rules for all of them are in `CLAUDE.md`.

| Keyword | Heaven's use |
|---|---|
| **Judgment N** | The faction's identity. Printed on 7 of 13 units, capped by stage — Basic ≤ 20, Stage 1 ≤ 40, Stage 2 ≤ 50. |
| **Sanctuary / Sanctuary N** | The second pillar, on 4 units. Heaven prints the only `Sanctuary N` in the game (`Radiant Bastion`, 60) and the only self-refreshing Sanctuary (`Empyrean Sentinel`). |
| **Rise** | Two units, both paired with Judgment. Rise restores a spent charge, which is the faction's stacked-reprieve combo. |
| **Consume N** | On all three ability lines. Consume is what keeps a free once-per-turn ability from becoming a permanent engine. |

### Notes on the keywords

**Judgment is one charge, spent by either half.** A bigger N is better in both directions
with no downside dial, so the balancing is that using it *either way* consumes it. That is
why `Verdict of the Throne` at Judgment 50 is not oppressive: it deletes something huge
exactly once, and is then a 145 HP body with a 42-damage attack.

**The charge returns only when the card returns to hand.** Retreat restores it, and so does
`Rise` — a returned body is a fresh printed card. This is deliberate and it is the only
reason `Hand of the Verdict` and `Throne of the Risen Court` are worth their low damage.

**Sanctuary N's counterplay is inverted.** Many small hits beat it; one big hit feeds it,
because the last sliver of pool still absorbs a whole instance. Wide `Decay` boards are
Heaven's natural predator, which is a healthy angle for Hel to have.

**Heaven's biggest attacks sit on Sanctuary bodies, not Judgment ones.** Units without
Judgment keep the standard 12-per-energy curve, so `Radiant Bastion` (65 for 5) and
`Empyrean Sentinel` (75 for 6) hit far harder than anything with a charge. This is the
faction's internal trade: threshold removal or raw damage, never both on one card.

---

## Evolution Lines

### The Ledger — the flagship, and it branches
`Censer Bearer` → `Arbiter of the Third Seal` → **`Seraph of the Final Ledger`** *or*
**`Verdict of the Throne`**

The only branching line in the game so far. One Arbiter becomes either the execute payoff
or the closer — you cannot have both from one body, so the choice is real every game.

### The Lamp — Sanctuary and damage
`Warden of the Lamp` → `Radiant Bastion` → `Empyrean Sentinel`

No Judgment anywhere on the line, so it keeps the standard damage curve throughout. This is
where Heaven's hitting power lives, and it ends in the game's hardest body to remove.

### The Risen — stacked reprieves
`Lantern Acolyte` → `Hand of the Verdict` → `Throne of the Risen Court`

Judgment plus Rise at every stage past the first. The durability ceiling of the faction,
deliberately paired with mediocre damage.

### The Court — the reset engine
`Bellringer of the Court` → `Court of Bells`

Stops at Stage 1. The cards that make Judgment repeatable.

### Unlinked
`Cherub of the Open Gate`

---

## Cards

All cards obey the **two-line rule**. Damage anchors: Judgment units ≈`8 × cost`,
non-Judgment ≈`12 × cost`, Consume ≈`20 × consumed`.

### Basics

**Lantern Acolyte** — 40 HP
*Judgment 10*
▸ **Rebuke** — 1 Heaven — 8 damage

> The floor of the faction and the cheapest possible threshold — kills anything at 18 or
> below. Deliberately weak alone: it finishes what the tower started, and it is a body that
> survives its first death. Entry to the Risen line.

---

**Censer Bearer** — 45 HP
*Judgment 20*
▸ **Cleanse** — 2 Heaven — 16 damage

> The workhorse. 36 effective against anything in range, for 2. Reads as *a great second
> attack and a poor first one*, which is the Judgment curve working as intended.

---

**Warden of the Lamp** — 50 HP
*Sanctuary*
▸ **Hold the Line** — 2 Heaven — 25 damage

> No Judgment, so it keeps the **standard** curve — 25 for 2, the same as Hel's `Cleave`.
> This is the control card that proves the rate cut is about Judgment and not about Heaven.
> Also the cheapest Sanctuary body and a safe windfury or Tool target, since it has no
> charge to combo dangerously.

---

**Bellringer of the Court** — 50 HP
*Judgment 20*
▸ **Recall the Verdict** — 2 Heaven — 10 damage; restore this unit's Judgment

> A body that maintains its own execute: attack and execute one turn, recharge the next, so
> it kills roughly every other turn forever without help.
>
> 10 damage for 2 is deliberately poor — you are paying for the recharge, not the damage.
> **One attack line doing two jobs is the balance**: it can never execute and recharge in
> the same turn. This is the clearest case for `CLAUDE.md`'s prohibition on windfury
> anywhere near Judgment.

---

**Cherub of the Open Gate** — 40 HP
*Sanctuary*
▸ **Ward the Way** — 1 Heaven — 8 damage

> Pure utility, unlinked. 8 damage for 1 is bad on purpose: a 40 HP body that absorbs one
> full attack is a **shield for the board behind it**, not an attacker. Deploy it in front
> of a charging Bastion and the opponent must spend a whole attack removing a free card.

---

### Stage 1

**Arbiter of the Third Seal** — 90 HP — *evolves from Censer Bearer*
*Judgment 30*
▸ **Weigh the Soul** — 3 Heaven — 25 damage

> 55 effective for 3, and the card the faction is built around. It turns every damaged unit
> into a kill, and at 90 HP it survives its own death once at 30. After it judges something
> down to 30, every other Judgment unit you own is holding a loaded gun.
>
> Also the branch point: both Stage 2 payoffs evolve from here.

---

**Hand of the Verdict** — 95 HP — *evolves from Lantern Acolyte*
*Judgment 20, Rise*
▸ **Sentence** — 2 Heaven — 16 damage

> The stacked-reprieve card. It dies, returns at 37 HP with **Judgment restored**, and must
> be killed a third time. Priced low on damage because the body is the payload.

---

**Court of Bells** — 80 HP — *evolves from Bellringer of the Court*
◆ **Ring the Court Bell** — *ability, Consume 2* — Restore Judgment to every friendly unit
whose **printed** card has Judgment.
▸ **Summons** — 2 Heaven — 16 damage

> The board-wide reset and the faction's build-around payoff — three Judgment units out
> means three executes reloaded in one activation.
>
> **`Consume 2` is mandatory.** As a free ability this is a permanent engine and Judgment
> stops being a finite charge at all, which deletes the keyword's entire design. Same
> reasoning `hel.md` gives for `Dirge` and `Claim the Fallen`.
>
> **Printed Judgment only** — a unit granted Judgment by a Tool or support card is not
> refreshed. Otherwise granting widely and resetting board-wide is an uncapped loop.
>
> It carries no Judgment itself, so it cannot reset its own. An 80 HP body — the floor of
> the Stage 1 band — is the counterplay, and that is the whole reason the card is printable.

---

**Radiant Bastion** — 110 HP — *evolves from Warden of the Lamp*
*Sanctuary 60*
▸ **Pillar of Light** — 5 Heaven — 65 damage

> Heaven's damage card, and the reason Sanctuary is not merely defensive. 65 for 5 is the
> **full standard curve** — no discount, because there is no execute to pay for. The hardest
> single hit in the faction, on the body hardest to kill.
>
> 5 attached energy on a unit the opponent is forced to focus is a large investment that
> dies with it. This is the card that makes Heaven feel the pool-versus-attached decision
> the rest of the faction dodges.

---

### Stage 2

**Seraph of the Final Ledger** — 140 HP — *evolves from Arbiter of the Third Seal*
*Judgment 50*
◆ **The Ledger Closes** — *ability, Consume 2* — Deal 15 damage to every enemy unit on one
board.
▸ **Final Accounting** — 5 Heaven — 42 damage

> The Judgment payoff. The ability does not kill on its own — it pushes multiple units
> **into execute range at once**, and Final Accounting then deletes one at 92 effective
> damage. Judgment 50 on a 140 HP body is the largest number in the faction: it executes
> every Basic in the game outright and survives its own death at half HP.

---

**Empyrean Sentinel** — 150 HP — *evolves from Radiant Bastion*
*Sanctuary*
◆ **Rekindle** — *ability, free* — At end of turn, restore this unit's Sanctuary.
▸ **Judgment of Light** — 6 Heaven — 75 damage

> **The only self-refreshing card in the faction**, and the puzzle it poses is
> concentration: it can only be killed by **two damage instances in the same turn** — two
> attacks, or one attack plus tower fire at step 3 of end-of-turn resolution.
>
> **It refreshes to plain Sanctuary, never to a pool.** A Sanctuary 60 resetting every turn
> would need 60+ damage twice per turn forever, which is unkillable. Plain Sanctuary means
> the second hit always lands whatever its size, so the puzzle is *concentration*, not raw
> damage.
>
> Free rather than Consume, because that rule is already the brake. 75 for 6 is the standard
> curve. The tower is its natural counter, which is thematically right.

---

**Throne of the Risen Court** — 130 HP — *evolves from Hand of the Verdict*
*Judgment 40, Rise*
▸ **Second Sentence** — 4 Heaven — 33 damage

> The durability ceiling. Must be killed **three times**: once to strip Judgment 40, once
> for real to trigger Rise, then again after it returns at 47 HP with Judgment restored.
>
> The most stall-adjacent card in the faction, and deliberately capped there: no reach, no
> ability, and a mediocre attack. **It holds a lane forever; it does not win.**

---

**Verdict of the Throne** — 145 HP — *evolves from Arbiter of the Third Seal*
*Judgment 50*
◆ **The Gate Opens** — *ability, Consume 3* — Deal damage to the enemy throne equal to the
number of enemy units destroyed this turn × 15.
▸ **Final Reckoning** — 5 Heaven — 42 damage

> **Heaven's pressure valve** — the answer to *never loses, never wins*.
>
> **It breaks the targeting rule on purpose.** `CLAUDE.md` says units shield the structures
> behind them and nothing reaches the throne while a board holds units. This reaches anyway
> — but only in proportion to units actually killed this turn, so it is a **reward for
> clearing**, not a bypass. Design principle #1: every rule has a card that breaks it.
>
> The synergy is exact. Heaven's whole kit produces kills — Judgment executes, the Seraph
> softens a board into range, the reset cards reload the executes — and this is what those
> kills finally cash out into. A three-kill turn is 45 to the throne.
>
> **`Consume 3` is the brake**, charging every use and competing with Final Reckoning for
> the same attached energy on the same body.

---

### Tool

**Aegis of the Choir** — *Tool, free*
> Attach to a unit. That unit gains **Sanctuary**. If it already has Sanctuary, restore it
> instead.

> The restore clause is what keeps it live on the Lamp line rather than dead there. Being a
> Tool means it is a one-shot investment on a body the opponent can kill — no engine. It
> grants *non-printed* Sanctuary, which `Court of Bells` deliberately cannot refresh.

---

## The Energy Curve

| Energy | Card | Effect |
|---|---|---|
| 1 | Rebuke / Ward the Way | 8 — chip, or an execute trigger |
| 2 | Cleanse / Sentence / Summons | 16 |
| 2 | Hold the Line | 25 *(no Judgment — standard curve)* |
| 2 | Recall the Verdict | 10 + recharge |
| 3 | Weigh the Soul | 25 |
| 4 | Second Sentence | 33 |
| 5 | Final Accounting / Final Reckoning | 42 |
| 5 | Pillar of Light | 65 *(no Judgment — standard curve)* |
| 6 | Judgment of Light | 75 *(no Judgment — standard curve)* |

Consume abilities sit outside this curve, because their cost is charged *every* use:

| Consume | Card | Effect, per activation |
|---|---|---|
| 2 | **Ring the Court Bell** | Reload every printed Judgment on your board |
| 2 | **The Ledger Closes** | 15 to every enemy unit on one board |
| 3 | **The Gate Opens** | 15 × enemy units killed this turn, to the throne |

**Read the curve twice.** The Judgment columns understate their real output: a Judgment 30
unit's 25-damage attack is 55 effective against anything already in range. The Sanctuary
columns are the honest numbers, which is why they look so much better — they are.

---

## Judgment and Retreat by card

Retreat is `HP ÷ 40` floored, same as everywhere. Judgment is the printed charge.

| Card | HP | Judgment | Retreat |
|---|---|---|---|
| Lantern Acolyte | 40 | 10 | 1 |
| Cherub of the Open Gate | 40 | — | 1 |
| Censer Bearer | 45 | 20 | 1 |
| Warden of the Lamp | 50 | — | 1 |
| Bellringer of the Court | 50 | 20 | 1 |
| Court of Bells | 80 | — | 2 |
| Arbiter of the Third Seal | 90 | 30 | 2 |
| Hand of the Verdict | 95 | 20 | 2 |
| Radiant Bastion | 110 | — | 2 |
| Throne of the Risen Court | 130 | 40 | 3 |
| Seraph of the Final Ledger | 140 | 50 | 3 |
| Verdict of the Throne | 145 | 50 | 3 |
| Empyrean Sentinel | 150 | — | 3 |

**The game-wide HP curve raise landed hardest here.** Heaven's reprieves all scale with
HP — a `Judgment` survival on a 145 HP frame is much harder to finish off than on a 110,
and `Sanctuary`'s terminal full-absorb now protects a bigger body. The change was adopted
partly to rein Heaven in and may do the opposite; see `CLAUDE.md` Open Questions.

**Judgment's stage caps did not move** (Basic ≤ 20, Stage 1 ≤ 40, Stage 2 ≤ 50). That is
deliberate: the cap limits how much of a body the execute threshold covers, and on bigger
bodies the same N is proportionally *less* powerful. `Verdict of the Throne` at Judgment 50
now survives at 50 out of 145 rather than 50 out of 110, which is a real nerf to the
defensive half and no change at all to the offensive half.

**`Court of Bells` sits at the Stage 1 band floor (80) on purpose.** It is the board-wide
Judgment reset — the faction's build-around — and `Consume 2` is its stated brake, but a
fragile body is the second one. It should stay the easiest Stage 1 in the game to remove.

**Retreat is a genuine Heaven play, unlike in Hel.** Retreating restores a spent Judgment
charge, so pulling a spent unit back and replaying it is the faction's third way to reload
— slower than the Court, but it costs no Consume. The cost is the usual one: a thinner
board, and the rebuild turns.

---

## Open Questions

- **Does Heaven still stall?** The central risk. Three stacked reprieves (Judgment,
  Sanctuary, Rise) plus tower support is exactly the scenario `CLAUDE.md` flags as the most
  urgent open question. `Verdict of the Throne` is the proposed valve but is unproven. A
  Heaven-vs-Heaven AI mirror is the cheapest first reading — but see the AI note below.
- **Is ≈8 damage per energy the right Judgment rate?** Untested. `Warden of the Lamp`
  (2 energy, 25 damage, no Judgment) and `Censer Bearer` (2 energy, 16 damage, Judgment 20)
  are the deliberate control pair. If the Warden feels obviously better, the rate should
  rise to 9 or 10.
- **Is 15 per kill right on `The Gate Opens`?** Borrowed from `THE LAST TOLL` without
  independent justification. A three-kill turn is 45 to the throne, which is a two-turn
  clock once the engine is online. May want to be 10.
- **Do the Seraph and Hel's Queen read as parallel or as a reskin?** Both are Stage 2
  finishers with a Consume ability plus a big attack. Acceptable as deliberate symmetry,
  less so if Heaven's flagship feels derivative.
- **Does Sanctuary N break the tower clock?** Towers are the forced-tempo engine. A
  Sanctuary 60 body ignores several turns of early tower fire, so Heaven may not feel the
  pressure the rest of the game is built on.
- **Is `Empyrean Sentinel` too hard to kill in practice?** Two damage instances in one turn
  is easy for a wide board and near-impossible for a narrow one, so it may be a blowout card
  in both directions rather than a puzzle.
- **Judgment beats Sanctuary in the mirror, and the reason is structural.** First AI sample
  (2026-08-08, 5 runs): **Verdict Engine 4 – 1 Lamp Wall**. Sanctuary blocks a damage
  *instance*, but it does nothing about the execute — once a Lamp Wall body is under the
  threshold, a Judgment attack deletes it no matter how much HP the shield saved. So the
  faction's defensive pillar has no answer to its offensive one. That may be correct
  (Judgment is the identity, Sanctuary is the support) or it may mean Sanctuary units need
  a way to stay above thresholds. Cross-faction results were close either way — Verdict 2–3
  vs Toll Engine, Lamp Wall 2–3 vs Barrow Wall — so this is a *mirror* problem, not a power
  problem. AI heuristics are still missing, so treat it as a signal, not a reading.
- **One Verdict-vs-Toll game ran to round 35**, against a mean of 16 for that matchup and a
  round-9 baseline for unit-only decks. First concrete sign of the stall the faction was
  designed around. One run in five is not a conclusion, but it is the thing to watch.
- **Is the branching Ledger line good or confusing?** It is the first branch in the game.
  The deck builder shows evolutions per card, so it should read fine, but it is worth
  watching whether players notice the choice exists.
- **The AI does not understand Heaven.** `AIPlayer` has no Judgment or Sanctuary heuristics:
  it will not value a charge, hold a Sanctuary body back, or time `The Gate Opens`. Heaven
  games run, but AI results are not a balance reading until this is written.

---

## Card Count

**13 units + 1 energy card + 1 Tool.** 5 Basics, 4 Stage 1, 4 Stage 2 — against Hel's 14
units, so the two factions are comparable in size.

| Theme | Cards |
|---|---|
| Judgment / execute | 7 |
| Sanctuary / absorb | 4 |
| Reset engine | 2 |
| Closer | 1 |

Four evolution lines, one of which branches, plus one unlinked Basic. Every unit carries at
least one keyword except `Court of Bells`, which is the support body the reset engine is
built around — the same deliberate exception `hel.md` makes for the Queen.
