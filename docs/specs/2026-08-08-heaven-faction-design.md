# Heaven — Faction Design Spec

> **Status:** Design settled in conversation 2026-08-08. Cards designed, not yet written to
> `data/cards.json`. No engine code written yet.
> Read `CLAUDE.md` first for core rules, board geometry, and the energy economy.

**Domain:** Order, light, judgment.
**Verb:** Protect.
**One-line identity:** *Every reprieve is finite.*

---

## What Heaven Is

Heaven does not reduce damage and it does not out-heal you. It **buys time in discrete,
countable units** — a shield that absorbs one blow, a reprieve that turns a death into a
survival at low HP. Each of those is spent when used and does not come back on its own.

That grammar is the faction: Heaven's cards carry *charges*, and playing Heaven well is
deciding when to cash them. It is the same shape as the game's central pool-versus-attached
tension, moved onto the body itself — a resource that is only valuable while unspent, where
you must guess which use you will need more.

The offensive half comes from the same idea read backwards. `Judgment` executes a unit left
below a threshold, which means Heaven is not buying damage — it is buying **the top of the
enemy's health bar**. Against the ~12-damage-per-energy curve, a Judgment 30 attacker only
has to deal 20 to a fresh 50 HP basic. The last 30 is free.

**Heaven and Hel define each other.** The faction that profits from death against the faction
that refuses it. This is the game's first real matchup and the one worth playtesting first.
Both factions printing `Rise` reads as two answers to the same question — Hel recycles because
death is income, Heaven returns because judgment is deferred.

### Why this is not the stall deck

`CLAUDE.md` names tower-support stall as the most urgent open balance question, and a
protection faction is the obvious way to make it worse. Four structural guards:

- **Every reprieve is finite and single-use.** Judgment fires once per body. Sanctuary is
  consumed. Neither regenerates without a dedicated card.
- **The cards that break that rule are fragile and can be killed.** Reset effects live on
  separate bodies or on Tools, never as untargetable auras.
- **Chip damage beats Sanctuary N.** Many small hits deplete a pool efficiently; one large
  hit is wasted on it. This is the opposite of how most defenses in this game break, and it
  gives wide boards — including Hel's `Decay` boards — a real angle.
- **`Verdict of the Throne` is the pressure valve**, converting kills into throne damage so
  the faction can actually close a game.

This is a live risk, not a solved problem. See Open Questions.

---

## Keyword Tiering — a project-wide decision

Settled this session, and it applies to the whole game rather than only to Heaven:

**Keywords are shared by default.** They live in `CLAUDE.md` and any faction may print them,
tuned to its own identity. Factions are defined by *which keywords they combine and how
large they print them*, not by owning them outright.

**Each faction may hold up to two signature keywords** that exist primarily in that faction.
Other factions reach them only through multi-faction cards or explicit rule-breakers.

| Tier | Keywords | Home |
|---|---|---|
| **Shared** | `Rise`, `Retribution`, `Consume`, `Windfury`, `Sanctuary`, `Judgment` | `CLAUDE.md` |
| **Hel signature** | `Toll`, `Decay` | `hel.md` |

**Required doc migration:** `Rise` and `Retribution` currently live in `hel.md` and must move
to `CLAUDE.md`. Hel keeps both and no Hel card changes — they simply stop being exclusive.
Hel's signatures remain `Toll` and `Decay`, which are the two that actually encode *death is
a resource*.

**Note on Heaven's signatures:** `Judgment` and `Sanctuary` are where Heaven's identity lives,
but both are shared-tier and a future faction may print them. Heaven will own them in practice
by printing them most often and at the largest values.

---

## Keywords

### Judgment N

> **Judgment N** — *One charge, spent by either use.*
> **Defensive:** when this unit would die, it instead survives at **N HP**.
> **Offensive:** when this unit attacks and leaves the defender at **N HP or below**, that
> defender is destroyed.
> Either use spends Judgment. It returns only if the card returns to hand.

The printed number does two jobs: it is both the HP you survive at and the threshold you
execute below. `Judgment 30` reads *I survive at 30, and I kill anything I leave at 30.*

**One charge, spent by either half.** This is what balances the keyword. A larger N is better
in both directions with no downside dial, so the cost is not the number — it is that using it
either way consumes it. A Judgment 100 unit is enormously powerful exactly once and is then an
ordinary body.

That poses a decision every turn: **cash the charge now to delete something, or hold it as the
insurance keeping this unit alive?** That is design principle #2 (spend or save) applied at a
third time scale the game did not previously have.

**On-hit only.** The execute fires only when *this attack* leaves the defender at ≤ N. It is
never a passive board check and never fires at end of turn. This is near-mandatory: the core
rule is *energy only buys attacks*, and a free repeating execute would make attacking optional
for Heaven.

**Judgment restores when the card returns to hand.** Retreat, `Rise`, and any bounce effect all
return a fresh body with its printed keywords intact.

**Interaction with the no-overkill rule.** A judged unit survived, so it is alive, so it still
shields its board and still absorbs the next attack in the volley. Judgment does not only save a
body — it **denies the opponent the retarget** they needed to reach the tower.

**Judgment combos with itself.** A unit judged down to N is now trivially inside execute range of
every other Judgment unit you control. Judging sets up the next execute with no extra card text.

**N is capped by stage:** Basic ≤ 20, Stage 1 ≤ 40, Stage 2 ≤ 50. A Judgment 40 Basic would
execute most of the game's Basics off a 1-energy attack.

#### The mirror

Both halves resolve, both charges spend. My Judgment 30 attacks their Judgment 10 for lethal:

1. Defensive Judgment fires first — they survive at 10 HP, **their Judgment is spent**.
2. Offensive Judgment then sees a survivor at 10, which is ≤ 30 — execute fires, **my Judgment
   is spent**.

The execute is itself a death, so a Judgment defender converts it into "they survive at N." The
big number did not kill them; it stripped their keyword and left them alive. That is what stops
high-Judgment cards from being unanswerable, and it makes Heaven-vs-Heaven a fight over who
runs out of reprieves first rather than a rules argument.

### Sanctuary / Sanctuary N

> **Sanctuary** — absorbs the next instance of damage entirely, from any source. Then spent.
> **Sanctuary N** — a pool of N. Damage depletes the pool. When the pool is exhausted, Sanctuary
> becomes plain **Sanctuary** — one final full absorb — and is then spent.

Worked examples:

| Incoming | Result |
|---|---|
| 30 into Sanctuary 100 | Absorbed. Now **Sanctuary 70**. |
| 110 into Sanctuary 100 | Pool cannot cover it → full absorb. **All 110 blocked, Sanctuary gone.** |
| 30 into Sanctuary 20 | Pool cannot cover it → full absorb. **Sanctuary gone.** |
| 30 × 4 into Sanctuary 100 | 100 → 70 → 40 → 10, then the fourth hit exceeds 10 and is fully absorbed. **Four attacks blocked.** |

**N is a floor, not a ceiling.** Sanctuary N blocks *at least* N and possibly far more, because
the last sliver of pool still eats one whole instance.

**Blocks all damage sources** — attacks, tower fire, `Decay`, support damage, `Retribution`.

**Why the pool form solves the granularity problem.** A boolean shield treats a free `Decay 5`
tick and a 75-damage `Final Verdict` identically, so the cheapest possible chip strips a shield
a 6-energy attack would otherwise have to break. Under the pool form a 5-point tick removes only
5. Sanctuary N is therefore **resistant to chip and resistant to burst at the same time**.

**Minimum printed N is 60.** Below that the number does no work: because of the free overflow, a
Sanctuary 30 against a 38-damage attack blocks all 38 — identical to plain Sanctuary. Printed
values are **plain Sanctuary, or 60 / 80 / 100**. Nothing in between.

**The counterplay is inverted, deliberately.** The way to break Sanctuary N is many small hits,
not one big one. Wide boards beat it; a single haymaker feeds it.

### Windfury

Shared keyword, lives in `CLAUDE.md`, available to every faction. Tempest's reserved identity
becomes *cheap, repeated, unconditional* multi-attack rather than owning the mechanic outright —
`CLAUDE.md`'s Future Factions table needs updating to say so.

**Windfury must not appear on any unit that holds or grants Judgment.** Two attacks is two
chances at the execute threshold, and on a reset card it collapses the execute/recharge rhythm
into a single turn, removing the entire brake. Multi-attack plus threshold removal is the single
most dangerous combination in this design.

---

## Damage Resolution Order

`CLAUDE.md` already fixes the coarse ordering — attacks resolve **left to right, board by
board**, then end-of-turn effects, then towers fire. This specifies the ordering *within a
single attack*.

**Each attack resolves fully, start to finish, before the next attack begins.**

| # | Step | Notes |
|---|---|---|
| 1 | **Select target** | Slot across → leftmost living → tower → throne. Dead units are skipped. |
| 2 | **Apply Sanctuary** | Prevention absorbs first. Deplete the pool, or full-absorb and spend. |
| 3 | **Deal remaining damage** | HP drops. |
| 4 | **Defensive Judgment** | If HP ≤ 0 and the defender has Judgment: survive at N, spend it. |
| 5 | **Offensive Judgment** | If the defender survived at ≤ N: destroy it, spend the attacker's Judgment. |
| 6 | **Retribution** | Defender deals recoil to the attacker. |
| 7 | **Deaths resolve** | Everything marked dead leaves the board together — discard, attached energy lost, Tools discarded, `Toll` and `Rise` fire. |

**Sanctuary before Judgment (2 before 4).** The shield is prevention — it stops damage from ever
landing, so it can never be "too late" to matter. The reverse order produces the absurd case of a
unit dying, surviving at N, then discovering it had a shield that would have stopped the hit.

**Defensive Judgment before offensive (4 before 5).** This is what makes the mirror resolve by
ordering rather than by a special-case tiebreak rule.

### Nothing leaves the board mid-attack

Step 7 is a single batched removal, and this is the guarantee that makes trades fair:

- A unit destroyed at step 5 is **marked** dead but remains present through step 6, so it still
  deals its `Retribution` recoil. An attacker cannot dodge the counter-punch by killing fast enough.
- If that recoil kills the attacker, **both die**. Mutual destruction resolves symmetrically.
- Both units' death triggers fire after the exchange is fully computed, so neither preempts the other.

**Scope:** this guarantee is *within a single attack*, not across the whole volley. Attack 1's
deaths resolve at its own step 7, before Attack 2 begins — so Attack 2 sees the board with that
unit already removed and retargets through the chain from the top. This preserves `CLAUDE.md`'s
existing rule that sequencing matters.

---

## The Judgment Damage Curve

**Judgment units buy damage at ≈ 8 per energy instead of the standard 12 — a flat one-third cut.**
Units without Judgment keep the standard curve, including Sanctuary units.

Judgment converts damage into a discount on the kill: a unit needs only `HP − N` damage to die.
At 12 damage per energy that discount is worth `N ÷ 12` energy, which the curve has to give back.

**Why a rate cut and not a flat cost reduction.** The execute is worth more on a *small* attack
than a large one — a 1-energy attack that executes at 30 is 42 effective damage, a 3.5× multiplier,
while a 5-energy attack doing 60 that executes at 30 is 90 effective, only 1.5×. A rate cut taxes
proportionally, so it taxes the cheap attacks hardest, which is the correct shape. A flat cost
reduction would do the opposite, and would go negative on cheap attacks.

| Cost | Standard | Judgment unit | Effective vs. a target in range (J30) |
|---|---|---|---|
| 1 | 12 | **8** | 38 |
| 2 | 25 | **16** | 46 |
| 3 | 38 | **25** | 55 |
| 4 | 50 | **33** | 63 |
| 5 | 65 | **42** | 72 |

Effective damage stays above the standard curve at every point, so Judgment is never a trap — but
the gap narrows as cost rises, so **Heaven's identity is cheap threshold kills, not big attacks**.

The table prices Judgment as though it fires every turn, which it does not — it fires once per
body. The rate cut is therefore arguably harsh on its own, and is compensated by generous N values
and by the reset cards. `Warden of the Lamp` exists as the control card to read the rate against.

---

## Cards

**14 units + 1 energy card + 1 Tool.** Damage anchors: standard ≈ `12 × cost`, Judgment ≈
`8 × cost`, Consume ≈ `20 × consumed`.

All cards obey the **two-line rule**: one ability + one attack, or two attacks.

### Theme spread

| Theme | Cards |
|---|---|
| Judgment / execute | 7 |
| Sanctuary / absorb | 4 |
| Reset / support | 2 |
| Closer / reach | 1 |

### Basics

**Lantern Acolyte** — 40 HP — *Judgment 10*
▸ **Rebuke** — 1 Heaven — 8 damage

> The floor of the faction and the cheapest possible threshold. Kills anything at 18 or below.
> Deliberately weak alone — it finishes what the tower started, and it is a body that survives
> its first death.

**Censer Bearer** — 45 HP — *Judgment 20*
▸ **Cleanse** — 2 Heaven — 16 damage

> The workhorse. 36 effective against anything in range, for 2. Reads as *a great second attack
> and a poor first one*.

**Warden of the Lamp** — 50 HP — *Sanctuary*
▸ **Hold the Line** — 2 Heaven — 25 damage

> No Judgment, so it keeps the **standard** curve — 25 for 2. The control card that proves the
> rate cut is about Judgment and not about Heaven. Also the cheapest Sanctuary body and a safe
> windfury or Tool target, since it has no Judgment to combo dangerously.

**Bellringer of the Court** — 50 HP — *Judgment 20*
▸ **Recall the Verdict** — 2 Heaven — 10 damage; restore this unit's Judgment

> A body that maintains its own execute — attack and execute one turn, recharge the next, so it
> kills roughly every other turn forever without help.
>
> 10 damage for 2 is deliberately poor: you are paying for the recharge, not the damage. **One
> attack line doing two jobs is the balance** — it can never execute and recharge in the same
> turn. This is the clearest case for the windfury prohibition.

**Cherub of the Open Gate** — 40 HP — *Sanctuary*
▸ **Ward the Way** — 1 Heaven — 8 damage

> Pure utility, unlinked. 8 damage for 1 is bad on purpose — a 40 HP body that absorbs one full
> attack is a **shield for the board behind it**, not an attacker. Deploy in front of a charging
> Bastion and the opponent must spend a whole attack to remove a free card.

### Stage 1

**Arbiter of the Third Seal** — 70 HP — *Judgment 30* — *evolves from Censer Bearer*
▸ **Weigh the Soul** — 3 Heaven — 25 damage

> 55 effective for 3, and the card the faction is built around. Turns every damaged unit into a
> kill, and at 70 HP it survives its own death once at 30. After it judges something down to 30,
> every other Judgment unit you own is holding a loaded gun.

**Hand of the Verdict** — 75 HP — *Judgment 20, Rise* — *evolves from Lantern Acolyte*
▸ **Sentence** — 2 Heaven — 16 damage

> The stacked-reprieve card. Dies, returns at 37 HP with **Judgment restored**, and must be
> killed a third time. Priced low on damage because the body is the payload.

**Court of Bells** — 50 HP — *no Judgment* — *evolves from Bellringer of the Court*
◆ **Ring the Court Bell** — *ability, Consume 2* — Restore Judgment to every friendly unit whose
**printed** card has Judgment.
▸ **Summons** — 2 Heaven — 16 damage

> The board-wide reset and the faction's build-around payoff. Three Judgment units out means
> three executes reloaded in one activation.
>
> **`Consume 2` is mandatory.** As a free ability this is a permanent engine and Judgment stops
> being a finite charge at all, deleting the keyword's design. Same reasoning `hel.md` gives for
> `Dirge` and `Claim the Fallen`.
>
> **Printed Judgment only** — a unit granted Judgment by a Tool or support card is not refreshed,
> or granting widely and resetting board-wide becomes an uncapped loop.
>
> It carries no Judgment itself, so it cannot reset its own. A 50 HP support body is the counterplay.

**Radiant Bastion** — 90 HP — *Sanctuary 60* — *evolves from Warden of the Lamp*
▸ **Pillar of Light** — 5 Heaven — 65 damage

> Heaven's damage card, and the reason Sanctuary is not merely defensive. 65 for 5 is the **full
> standard curve** — no discount, because there is no execute to pay for. The hardest single hit
> in the faction on the body hardest to kill.
>
> 5 attached energy on a unit the opponent is forced to focus is a large investment that dies with
> it. This is the card that makes Heaven feel the pool-versus-attached decision the rest of the
> faction dodges.

### Stage 2

**Seraph of the Final Ledger** — 100 HP — *Judgment 50* — *evolves from Arbiter of the Third Seal*
◆ **The Ledger Closes** — *ability, Consume 2* — Deal 15 damage to every enemy unit on one board.
▸ **Final Accounting** — 5 Heaven — 42 damage

> The Judgment payoff. The ability does not kill on its own — it pushes multiple units **into
> execute range at once**, and then Final Accounting deletes one at 92 effective damage.
>
> Judgment 50 on a 100 HP body is the largest number in the design. It executes every Basic in
> the game outright and survives its own death at half HP.

**Empyrean Sentinel** — 100 HP — *Sanctuary* — *evolves from Radiant Bastion*
◆ **Rekindle** — *ability, free* — At end of turn, restore this unit's Sanctuary.
▸ **Judgment of Light** — 6 Heaven — 75 damage

> **The only self-refreshing card in the faction**, and the puzzle it poses is concentration: it
> can only be killed by **two damage instances in the same turn** — two attacks, or one attack
> plus tower fire at step 3 of end-of-turn resolution.
>
> **It refreshes to plain Sanctuary, never to a pool.** A Sanctuary 60 resetting every turn would
> need 60+ damage twice per turn forever, which is unkillable. Plain Sanctuary means the second hit
> always lands whatever its size.
>
> Free rather than Consume because the refresh is already brake-limited by that rule. 75 for 6 is
> the standard curve. The tower is its natural counter, which is thematically right.

**Throne of the Risen Court** — 95 HP — *Judgment 40, Rise* — *evolves from Hand of the Verdict*
▸ **Second Sentence** — 4 Heaven — 33 damage

> The durability ceiling. Must be killed **three times**: once to strip Judgment 40, once for real
> to trigger Rise, then again after it returns at 47 HP with Judgment restored.
>
> The most stall-adjacent card in the design, deliberately capped there: no reach, no ability, and
> a mediocre attack. **It holds a lane forever; it does not win.**

**Verdict of the Throne** — 110 HP — *Judgment 50* — *evolves from Arbiter of the Third Seal*
◆ **The Gate Opens** — *ability, Consume 3* — Deal damage to the enemy throne equal to the number
of enemy units destroyed this turn × 15.
▸ **Final Accounting** — 5 Heaven — 42 damage

> **Heaven's pressure valve** — the answer to *never loses, never wins*.
>
> **It breaks the targeting rule on purpose.** `CLAUDE.md` says units shield the structures behind
> them and nothing reaches the throne while a board holds units. This reaches anyway — but only in
> proportion to units actually killed this turn, so it is a **reward for clearing**, not a bypass.
> Design principle #1: every rule has a card that breaks it.
>
> The synergy is exact. Heaven's whole kit produces kills — Judgment executes, the Seraph softens
> a board into range, the reset cards reload the executes — and this is what those kills cash out
> into. A three-kill turn is 45 to the throne.
>
> **`Consume 3` is the brake**, charging every use and competing with Final Accounting on the same
> body.

### Energy

**Heaven Energy** — *energy card*
> Adds `t + 1` Heaven energy to the pool when played. Identical to `hel_energy` in every respect:
> exempt from the 4-copy limit, one per turn, no per-color behavior differences.

### Tool

**Aegis of the Choir** — *Tool, free*
> Attach to a unit. That unit gains **Sanctuary**. If it already has Sanctuary, restore it instead.

> The Sanctuary support card. One Tool per unit, discarded on death and on retreat. The restore
> clause keeps it live on the Sanctuary line rather than dead there. Being a Tool means it is a
> one-shot investment on a body the opponent can kill — no engine.
>
> Note it grants *non-printed* Sanctuary, which `Court of Bells` deliberately cannot refresh.

### Evolution lines

| Line | Path | Identity |
|---|---|---|
| **The Ledger** | Censer Bearer → Arbiter of the Third Seal → **Seraph of the Final Ledger** *or* **Verdict of the Throne** | The flagship. **Branches at Stage 2** — the execute payoff or the closer. |
| **The Lamp** | Warden of the Lamp → Radiant Bastion → Empyrean Sentinel | Sanctuary. Heaven's damage and its unkillable body. |
| **The Risen** | Lantern Acolyte → Hand of the Verdict → Throne of the Risen Court | Judgment + Rise. Stacked reprieves. |
| **The Court** | Bellringer of the Court → Court of Bells | The reset engine. Stops at Stage 1. |
| **Unlinked** | Cherub of the Open Gate | — |

> **Resolved 2026-08-08: the Ledger line branches at Stage 2.** `Verdict of the Throne` was first
> written as evolving from `Seraph of the Final Ledger`, which the stage model does not support —
> there is no Stage 3. Both now evolve from `Arbiter of the Third Seal`, so the line forks and you
> choose the execute payoff or the closer. This needs no engine change (`evolves_from` already
> permits two cards naming the same parent) and it makes the choice a real one *per game* rather
> than a longer climb: with one Arbiter on board, you cannot have both.

---

## Open Questions

- **Does Heaven still stall?** The design's central risk. Three stacked reprieves (Judgment,
  Sanctuary, Rise) plus tower support is exactly the scenario `CLAUDE.md` flags. `Verdict of the
  Throne` is the proposed valve but is unproven. A Heaven-vs-Heaven AI mirror is the cheapest first
  reading.
- **Is ≈8 damage per energy the right Judgment rate?** Untested. `Warden of the Lamp` (2 energy,
  25 damage, no Judgment) and `Censer Bearer` (2 energy, 16 damage, Judgment 20) are the control
  pair — if the Warden feels obviously better, the rate should rise to 9 or 10.
- **Is 15 per kill right on `The Gate Opens`?** Borrowed from `THE LAST TOLL` without independent
  justification. May want to be 10. A three-kill turn at 45 to the throne is a two-turn clock once
  the engine is online.
- **Do Hel's Queen and `Verdict of the Throne` read as parallel or as a reskin?** Both are Stage 2
  finishers with a Consume ability plus a big attack. Acceptable as deliberate symmetry, less so if
  Heaven's flagship feels derivative.
- **Does Sanctuary N break the tower clock?** Towers are the forced-tempo engine. A Sanctuary 60
  body ignores several turns of early tower fire, so Heaven may not feel the pressure the rest of
  the game is built on.
- **Is `Empyrean Sentinel` too hard to kill in practice?** Requiring two damage instances in one
  turn is easy for a wide board and near-impossible for a narrow one, so it may be a blowout card
  in both directions.
- **Is N ≥ 60 the right Sanctuary floor?** If Sanctuary 60 plays identically to plain Sanctuary,
  the floor rises to 80 and the tier collapses to 80/100.
- **Windfury's tuning is undefined.** Confirmed shared this session, but a unit that attacks twice
  with one attack line is very different from one that may queue two different attacks.

---

## Downstream Documentation Changes

| File | Change |
|---|---|
| `CLAUDE.md` | Add the keyword-tiering rule (shared by default, two signatures per faction) |
| `CLAUDE.md` | Add `Judgment`, `Sanctuary`, `Windfury` as shared keywords |
| `CLAUDE.md` | Add the within-attack damage resolution order |
| `CLAUDE.md` | Move `Rise` and `Retribution` in from `hel.md` as shared |
| `CLAUDE.md` | Update Future Factions — Tempest no longer owns multi-attack |
| `CLAUDE.md` | Faction table — Heaven moves from "Not started" to built |
| `CLAUDE.md` | Decision log entries for the above |
| `hel.md` | Remove `Rise` and `Retribution` from the keyword table, noting they are now shared |
| `heaven.md` | New file — faction identity, keywords, evolution lines, cards |

Per `CLAUDE.md`'s standing rule, rules-doc edits land when the design is confirmed.

---

## Implementation Notes

Engine work this design requires, beyond card data:

- **`Unit.gd`** — `judgment_spent: bool`, `sanctuary_pool: int`, `sanctuary_active: bool`, plus
  accessors mirroring the existing `toll()` / `decay()` / `has_rise()` pattern.
- **Damage pipeline** — the seven-step order above, replacing whatever currently applies damage
  directly. The batched step 7 removal is the significant change: deaths must be marked and
  resolved together rather than applied inline.
- **`CardData.gd`** — `judgment` and `sanctuary` keyword parsing; `sanctuary` needs an optional
  `n` since plain Sanctuary has no number.
- **Ability hooks** — `Rekindle` needs an end-of-turn ability trigger, which does not exist yet;
  current abilities are all activated. This is new machinery.
- **`Court of Bells`** must read *printed* keywords, not effective ones — the distinction between
  printed and granted keywords is not currently modeled.
- **Harness** — a `HeavenTest.gd` mirroring `RulesTest.gd`, covering both Judgment halves, the
  mirror ordering, Sanctuary pool depletion and overflow, and the batched-death guarantee.
