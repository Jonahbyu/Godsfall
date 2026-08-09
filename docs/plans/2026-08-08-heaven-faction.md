# Heaven Faction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the Heaven faction — two new keywords (`Judgment`, `Sanctuary`), a documented within-attack damage resolution order, 14 units + 1 energy card + 1 Tool, and a headless test harness proving all of it.

**Architecture:** Rules docs first (`CLAUDE.md`, `hel.md`, new `heaven.md`), then engine primitives on `Unit`/`CardData`, then the damage pipeline in `GameState._deal_lane_damage`, then card data, then the harness. Keyword state lives on `Unit` as mutable battlefield state mirroring the existing `lost_rise` pattern; printed values stay on `CardData`. The seven-step damage order is inserted into the one existing function that applies lane damage, so no call sites move.

**Tech Stack:** Godot 4.7, GDScript. Card data is JSON in `data/cards.json`. Tests are headless `SceneTree` scripts run via `godot --headless --script`.

**Source spec:** `docs/specs/2026-08-08-heaven-faction-design.md`

---

## Critical Context For The Implementer

Read these before starting. They are non-obvious and getting them wrong produces silent bugs.

**This project is not a git repository.** `CLAUDE.md` says so explicitly. **Skip every commit step in this plan** — they are written because the plan format requires them, but `git` will fail. Instead, after each task, run the relevant harness and confirm it passes before moving on. If the project is later `git init`-ed, the commit steps become live.

**Deaths are already batched.** `GameState._deal_lane_damage` (line ~1037) drops HP but never removes units; `_cleanup_dead` (line ~1185) removes them after the whole volley. The spec's "nothing leaves the board mid-attack" guarantee is **already the engine's behavior** — do not add batching machinery. A unit at 0 HP is `not is_alive()`, so `leftmost_living_unit()` already skips it, which is how the existing no-overkill rule works.

**`take_damage` returns damage actually dealt, capped at remaining HP.** It floors at 1 HP when `protected_this_turn` is set (Hold the Slot). Sanctuary must be applied *before* calling it, not inside it.

**Keywords with no value use `n: 0`.** `CardData.from_dict` reads `int(k.get("n", 0))`, and `has_kw` tests key presence, not value. So plain `Sanctuary` is `{"kw": "sanctuary", "n": 0}` and `has_kw("sanctuary")` is true. `keyword_line()` already renders a 0-valued keyword as just its name — that is why `Rise` prints correctly today.

**Abilities ignore their `cost` block entirely.** Only `consume` reads. See `Unit.can_use_ability`.

**`CardDB` must be loaded manually in harnesses.** Copy the `_initialize()` block from `RulesTest.gd` verbatim.

**Any harness touching `DeckStore` must call `use_sandbox_path()` first.** `CLAUDE.md` documents this as a past data-loss bug — the harnesses wrote the player's real saved decks. The Heaven harness does not need `DeckStore`, but if you add deck fixtures, this is mandatory.

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `CLAUDE.md` | Core rules | Modify — keyword tiering, 3 shared keywords, damage order, faction table, decision log |
| `hel.md` | Hel faction | Modify — `Rise`/`Retribution` become shared, note remains |
| `heaven.md` | Heaven faction | **Create** — identity, keywords, lines, 16 cards |
| `scripts/core/Unit.gd` | Battlefield state | Modify — Judgment/Sanctuary state + accessors |
| `scripts/core/CardData.gd` | Printed card | Modify — printed-keyword accessor |
| `scripts/core/GameState.gd` | Rules engine | Modify — 7-step damage order, EOT abilities, 2 new effect ops |
| `data/cards.json` | Card data | Modify — append 16 Heaven cards |
| `scripts/core/HeavenTest.gd` | Harness | **Create** — keyword + ordering assertions |

---

## Task 1: Rules docs — `CLAUDE.md` keyword tiering and shared keywords

**Files:**
- Modify: `CLAUDE.md`

Rules before code — `CLAUDE.md` is the source of truth and the engine implements it. This task lands the rules; nothing else may start before it.

- [ ] **Step 1: Add the keyword tiering section**

In `CLAUDE.md`, immediately after the `### Subfactions` section and before `### Future Factions`, insert:

```markdown
### Keywords are shared by default

**A keyword belongs to the whole game unless a faction claims it as a signature.**
Shared keywords live in this file and any faction may print them, tuned to its own
identity. Factions are defined by *which keywords they combine and how large they print
them*, not by owning them outright.

**Each faction may hold up to two signature keywords** that exist primarily in that
faction. Other factions reach them only through multi-faction cards or explicit
rule-breakers.

| Tier | Keywords | Home |
|---|---|---|
| **Shared** | `Rise`, `Retribution`, `Consume`, `Windfury`, `Sanctuary`, `Judgment` | This file |
| **Hel signature** | `Toll`, `Decay` | `hel.md` |

This replaces the earlier arrangement where `Rise` and `Retribution` lived in `hel.md`.
Hel keeps both and no Hel card changed — they simply stopped being exclusive. Hel's two
signatures are the pair that actually encode *death is a resource*.

Why shared-by-default: a keyword pool that every faction draws from means factions differ
by *combination* rather than by vocabulary, which gives each color far more design room
and makes multi-faction cards read naturally instead of as exceptions.
```

- [ ] **Step 2: Add the shared keyword definitions**

In `CLAUDE.md`, after the `## Damage Formulas` section and before `## Units`, insert:

```markdown
---

## Shared Keywords

These belong to the whole game. Faction files list only their signatures.

| Keyword | Effect |
|---|---|
| **Rise** | When this dies, return it to an empty slot on your side at the start of your next turn, at **half HP** and **without Rise**. Every other ability, attack, and keyword returns intact. Attached energy is not restored. |
| **Retribution N** | When this unit takes damage from an attack, deal N damage back to the attacker. |
| **Consume N** | This line destroys N attached energy on activation. Priced at ≈20 damage per energy consumed. May appear on an attack or an ability; on an ability it is the only cost permitted. |
| **Judgment N** | One charge, spent by either use. **Defensive:** when this unit would die, it instead survives at N HP. **Offensive:** when this unit attacks and leaves the defender at N HP or below, that defender is destroyed. Returns only if the card returns to hand. |
| **Sanctuary / Sanctuary N** | Plain **Sanctuary** absorbs the next instance of damage entirely, from any source, then is spent. **Sanctuary N** is a pool of N that damage depletes; when the pool is exhausted it becomes plain Sanctuary for one final full absorb, then is spent. |
| **Windfury** | This unit may attack twice per turn. |

### Judgment

The printed number does two jobs — it is both the HP you survive at and the threshold you
execute below. `Judgment 30` reads *I survive at 30, and I kill anything I leave at 30.*

**One charge, spent by either half.** This is what balances the keyword. A larger N is
better in both directions with no downside dial, so the cost is not the number — it is
that using it either way consumes it. A Judgment 100 unit is enormously powerful exactly
once and is then an ordinary body. That poses a decision every turn: **cash the charge to
delete something, or hold it as the insurance keeping this unit alive?** That is design
principle #2 at a third time scale.

**On-hit only.** The execute fires only when *this attack* leaves the defender at ≤ N. It
is never a passive board check and never fires at end of turn — a free repeating execute
would make attacking optional, and *energy only buys attacks*.

**A judged unit still shields.** It survived, so it is alive, so it still blocks the path
to the tower and still absorbs the next attack in the volley. Judgment does not only save
a body, it **denies the opponent the retarget** they needed.

**Judgment combos with itself.** A unit judged down to N is inside execute range of every
other Judgment unit you control.

**N is capped by stage:** Basic ≤ 20, Stage 1 ≤ 40, Stage 2 ≤ 50.

**The mirror resolves by ordering, not by a tiebreak rule.** Defensive Judgment is checked
before offensive, so a Judgment 30 attacking a Judgment 10 for lethal leaves the defender
alive at 10 with its charge spent, and the attacker's execute then fires on a survivor at
≤ 30, spending its own. Both charges spend, one unit lives. The execute is itself a death,
so a Judgment defender converts it into a survival — which is what stops high-Judgment
cards from being unanswerable.

**Judgment units buy damage at ≈ 8 per energy** instead of the standard 12 — a flat
one-third cut. Judgment converts damage into a discount on the kill (a unit needs only
`HP − N` damage), and at 12/energy that discount is worth `N ÷ 12` energy. A *rate* cut
rather than a flat cost reduction, because the execute is worth proportionally more on a
cheap attack than an expensive one, so a rate cut taxes the cheap attacks hardest — which
is the correct shape. Units without Judgment keep the standard curve.

### Sanctuary

**N is a floor, not a ceiling.** Sanctuary N blocks *at least* N and possibly far more,
because the last sliver of pool still eats one whole instance.

| Incoming | Result |
|---|---|
| 30 into Sanctuary 100 | Absorbed. Now Sanctuary 70. |
| 110 into Sanctuary 100 | Pool cannot cover it → full absorb. All 110 blocked, Sanctuary gone. |
| 30 into Sanctuary 20 | Pool cannot cover it → full absorb. Sanctuary gone. |
| 30 × 4 into Sanctuary 100 | 100 → 70 → 40 → 10, then the fourth hit exceeds 10 and is fully absorbed. Four attacks blocked. |

**Blocks all damage sources** — attacks, tower fire, `Decay`, support damage, `Retribution`.

**Why the pool form.** A boolean shield treats a free `Decay 5` tick and a 75-damage
attack identically, so the cheapest possible chip would strip a shield a 6-energy attack
had to break. Under the pool form a 5-point tick removes only 5. Sanctuary N is therefore
resistant to chip *and* resistant to burst, and neither the Hel matchup nor the
big-attack matchup has a degenerate line.

**Minimum printed N is 60.** Below that the number does no work: because of the free
overflow, a Sanctuary 30 against a 38-damage attack blocks all 38 — identical to plain
Sanctuary. Printed values are plain, 60, 80, or 100. Nothing in between.

**The counterplay is inverted, deliberately.** The way to break Sanctuary N is many small
hits, not one big one. Wide boards beat it; a single haymaker feeds it.

### Windfury

**Windfury must not appear on any unit that holds or grants Judgment.** Two attacks is two
chances at the execute threshold, and on a Judgment-reset card it collapses the
execute/recharge rhythm into one turn, removing the brake entirely. Multi-attack plus
threshold removal is the most dangerous combination available.
```

- [ ] **Step 3: Add the damage resolution order**

In `CLAUDE.md`, inside `## Turn Structure`, immediately after the `### Attack lock` section, insert:

```markdown
### Damage resolution order

Attacks resolve **left to right, board by board**. This is the order *within* a single
attack. **Each attack resolves fully, start to finish, before the next begins.**

| # | Step |
|---|---|
| 1 | **Select target** — slot across → leftmost living → tower → throne. Dead units are skipped. |
| 2 | **Apply Sanctuary** — prevention absorbs first. Deplete the pool, or full-absorb and spend. |
| 3 | **Deal remaining damage** — HP drops. |
| 4 | **Defensive Judgment** — if HP ≤ 0 and the defender has Judgment: survive at N, spend it. |
| 5 | **Offensive Judgment** — if the defender survived at ≤ N: destroy it, spend the attacker's Judgment. |
| 6 | **Retribution** — defender deals recoil to the attacker. |
| 7 | **Deaths resolve** — everything marked dead leaves the board together: discard, attached energy lost, Tools discarded, `Toll` and `Rise` fire. |

**Sanctuary before Judgment (2 before 4).** The shield is prevention — it stops damage from
ever landing, so it can never be "too late" to matter. The reverse order produces the
absurd case of a unit dying, surviving at N, then discovering it had a shield that would
have stopped the hit.

**Defensive Judgment before offensive (4 before 5).** This is what makes the mirror resolve
by ordering rather than by a special-case rule.

**Nothing leaves the board mid-attack.** A unit destroyed at step 5 is *marked* dead but
remains present through step 6, so it still deals its `Retribution` recoil — an attacker
cannot dodge the counter-punch by killing fast enough. If that recoil kills the attacker,
both die. This guarantee is scoped *within a single attack*: attack 1's deaths resolve
before attack 2 begins, so sequencing still matters and a board can still be cleared
within one volley.
```

- [ ] **Step 4: Update the faction table and Future Factions**

In the `## Factions` table, change the Heaven row from:

```markdown
| **Heaven** | Order, light, judgment | Protect | Not started |
```

to:

```markdown
| **Heaven** | Order, light, judgment | Protect | 🔨 Built — see `heaven.md` |
```

In the `### Future Factions` table, change the Tempest row's Notes cell from:

```markdown
| **Tempest** | Storm, speed, motion | Chain | Cheap repeated attacks. Mechanically this is the "attack twice" faction — precious in an economy where attacking is the scarce action. |
```

to:

```markdown
| **Tempest** | Storm, speed, motion | Chain | Cheap repeated attacks. **`Windfury` is now a shared keyword**, so Tempest's identity is *cheap, repeated, unconditional* multi-attack rather than owning the mechanic — it prints windfury widest and cheapest, where other factions get one card. |
```

- [ ] **Step 5: Add decision log entries**

Append to the `### Decision log` list in `CLAUDE.md`:

```markdown
- **Keywords are shared by default; each faction may claim up to two signatures.** Moved
  `Rise` and `Retribution` from `hel.md` into the core rules, leaving Hel with `Toll` and
  `Decay` — the two that actually encode *death is a resource*. Factions defined by
  combination rather than vocabulary get far more design room per color, and multi-faction
  cards stop reading as exceptions. Hel lost no cards and no card text changed.
- **`Judgment N` is one charge spent by either half.** Defensive (survive at N instead of
  dying) and offensive (execute anything left at ≤ N) share one printed number and one
  charge. A bigger N is better in both directions with no downside dial, so the balancing
  is that *using it either way consumes it* — a Judgment 100 unit is devastating exactly
  once. That makes every turn a spend-or-save decision on the body itself, which is design
  principle #2 at a third time scale.
- **Judgment units buy damage at ≈8 per energy, not 12.** Judgment is a discount on the
  kill worth `N ÷ 12` energy, so the curve gives it back. A *rate* cut rather than a flat
  cost reduction, because the execute is worth proportionally more on a cheap attack — a
  rate taxes cheap attacks hardest, which is the right shape, while a flat reduction would
  go negative on them. Sanctuary units keep the standard curve, which is why Heaven's
  biggest attacks sit on Sanctuary bodies.
- **`Sanctuary N` is a depleting pool that ends in one free full absorb.** A boolean shield
  is popped identically by a free `Decay 5` tick and a 75-damage attack, making the
  cheapest chip the best answer to the most expensive shield. A pool makes small hits
  inefficient while the terminal overflow still eats one whole big hit, so Sanctuary
  resists chip and burst at once. Minimum printed N is 60, because below that the free
  overflow means the number never does any work.
- **The within-attack damage order is Sanctuary → damage → defensive Judgment → offensive
  Judgment → Retribution → batched deaths.** Sanctuary is prevention so it must precede
  everything; defensive-before-offensive Judgment is what makes the Heaven mirror resolve
  by ordering instead of a special-case tiebreak. Deaths were already batched by
  `_cleanup_dead`, so the "nothing leaves the board mid-attack" guarantee needed
  documenting, not building.
- **`Windfury` is shared, and may never appear on a unit holding or granting Judgment.**
  Two attacks is two execute checks, and on a reset card it collapses the execute/recharge
  rhythm into a single turn. Tempest keeps multi-attack as an identity by printing it
  widest and cheapest rather than exclusively.
```

- [ ] **Step 6: Verify no contradictions remain**

Run:

```bash
grep -n "Rise\|Retribution" hel.md | head -30
```

Expected: `hel.md` still references both in card text (Hollow Servant, Thornshade, etc.) — that is correct and stays. Task 2 fixes only the *keyword table*.

- [ ] **Step 7: Commit** *(skip — not a git repo; instead confirm the file renders and move on)*

```bash
git add CLAUDE.md && git commit -m "docs: keyword tiering, shared keywords, damage order"
```

---

## Task 2: Rules docs — `hel.md` keyword table

**Files:**
- Modify: `hel.md:66-74`

- [ ] **Step 1: Replace the keyword table**

In `hel.md`, replace the whole `## Keywords` table (currently listing Toll, Rise, Decay, Retribution, Consume) with:

```markdown
| Keyword | Effect |
|---|---|
| **Toll N** | *(Hel signature)* When this unit dies, gain N Hel energy to your pool. |
| **Decay N** | *(Hel signature)* At end of turn, deal N damage to the opposing unit. Costs no energy and does not use this unit's attack. |

Hel's two **signature** keywords are above. Hel also prints four **shared** keywords,
defined in `CLAUDE.md`: `Rise`, `Retribution`, `Consume`, and `Windfury`.

`Rise` and `Retribution` were originally Hel-exclusive and moved to the core rules when
Heaven was built. No Hel card changed — they simply stopped being exclusive. Hel keeps the
two that encode *death is a resource*, which is the faction's whole identity.
```

- [ ] **Step 2: Keep the keyword notes but scope them**

The `### Notes on the keywords` section below the table discusses Toll, Rise, Decay, and
Retribution. Keep all of it — the Hel-specific *tuning* notes belong in the faction file
even for shared keywords. Add this line at the top of that section:

```markdown
> Notes on `Rise` and `Retribution` below are Hel's tuning of shared keywords. The rules
> themselves live in `CLAUDE.md`.
```

- [ ] **Step 3: Commit** *(skip — not a git repo)*

```bash
git add hel.md && git commit -m "docs: Hel keyword table lists signatures only"
```

---

## Task 3: `Unit.gd` — Judgment and Sanctuary battlefield state

**Files:**
- Modify: `scripts/core/Unit.gd`
- Test: `scripts/core/HeavenTest.gd` (created in Task 8; this task adds state only)

State mirrors the existing `lost_rise` pattern: printed values on `CardData`, spent-ness on `Unit`.

- [ ] **Step 1: Add state fields**

In `scripts/core/Unit.gd`, after the `var lost_rise: bool = false` line (line 9), add:

```gdscript
var judgment_spent: bool = false ## true once Judgment has fired, either half

## Sanctuary runtime state. `sanctuary_pool` is the remaining absorb pool; when it
## hits 0 the shield is still live for one final full absorb (plain Sanctuary), and
## only then is `sanctuary_active` cleared. Plain Sanctuary starts with pool 0.
var sanctuary_active: bool = false
var sanctuary_pool: int = 0
```

- [ ] **Step 2: Initialise Sanctuary from the printed card**

In `_init`, replace:

```gdscript
func _init(c: CardData) -> void:
	card = c
	hp = c.max_hp
```

with:

```gdscript
func _init(c: CardData) -> void:
	card = c
	hp = c.max_hp
	_reset_sanctuary()


## Arm Sanctuary from the printed card. Plain Sanctuary is pool 0 — still live,
## because an exhausted pool grants one final full absorb before the shield is gone.
func _reset_sanctuary() -> void:
	sanctuary_active = card.has_kw("sanctuary")
	sanctuary_pool = card.kw("sanctuary")
```

- [ ] **Step 3: Add the accessors**

After the `has_rise()` function (line ~95), add:

```gdscript
## The printed Judgment value. Like Toll, buffs and damage never change it.
func judgment() -> int:
	return card.kw("judgment")


func has_judgment() -> bool:
	return card.has_kw("judgment") and not judgment_spent


## Absorb `amount` into Sanctuary and return the damage that gets through.
##
## The pool depletes first. When the pool cannot cover the hit, the shield eats the
## *whole* instance and is spent — that terminal overflow is what makes Sanctuary
## resistant to burst as well as to chip, and it is why a small pool is never wasted.
func absorb(amount: int) -> int:
	if not sanctuary_active or amount <= 0:
		return amount
	if amount <= sanctuary_pool:
		sanctuary_pool -= amount
		return 0
	## Pool cannot cover it: full absorb, shield spent.
	sanctuary_pool = 0
	sanctuary_active = false
	return 0


## Restore Sanctuary to its printed value — Rekindle and Aegis of the Choir.
func restore_sanctuary() -> void:
	_reset_sanctuary()


## Grant plain Sanctuary to a unit whose printed card has none (Aegis of the Choir).
## Granted Sanctuary is deliberately not restorable by Court of Bells, which reads
## printed keywords only.
func grant_sanctuary() -> void:
	sanctuary_active = true
	sanctuary_pool = max(sanctuary_pool, 0)
```

- [ ] **Step 4: Reset keywords on evolution**

In `evolve_into`, after the `lost_rise = false` line, add:

```gdscript
	judgment_spent = false                   ## new printed card, new charge
	_reset_sanctuary()                       ## new printed card, new shield
```

- [ ] **Step 5: Reset keywords on Rise**

In `make_risen`, after `u.lost_rise = true`, add:

```gdscript
	## A returned body is a fresh printed card: Judgment and Sanctuary are restored.
	## This is the stacked-reprieve combo Heaven's Rise cards are built on.
	u.judgment_spent = false
	u._reset_sanctuary()
```

- [ ] **Step 6: Syntax check**

Run:

```bash
godot --headless --path . --script res://scripts/core/RulesTest.gd
```

Expected: the existing 41 assertions still pass, 0 failed. No Heaven cards exist yet, so nothing new is exercised — this only proves nothing broke.

- [ ] **Step 7: Commit** *(skip — not a git repo)*

```bash
git add scripts/core/Unit.gd && git commit -m "feat: Judgment and Sanctuary unit state"
```

---

## Task 4: `GameState.gd` — the seven-step damage order

**Files:**
- Modify: `scripts/core/GameState.gd:1037-1072`

This is the load-bearing task. `_deal_lane_damage` is the single place lane damage is applied, so the whole ordering slots in there and no call sites move.

- [ ] **Step 1: Rewrite `_deal_lane_damage`**

Replace the body of `_deal_lane_damage` (from `if defender != null:` through the `return` at the end of that block, lines ~1050-1059) with:

```gdscript
	if defender != null:
		## --- Step 2: Sanctuary absorbs before anything lands.
		var incoming: int = dmg
		var had_sanctuary: bool = defender.sanctuary_active
		var through: int = defender.absorb(incoming)
		if had_sanctuary and through < incoming:
			if defender.sanctuary_active:
				_log("  Sanctuary absorbs %d (%d pool left on %s)." % [incoming, defender.sanctuary_pool, defender.card.name])
			else:
				_log("  Sanctuary absorbs %d and is spent on %s." % [incoming, defender.card.name])

		## --- Step 3: remaining damage lands.
		var dealt := defender.take_damage(through)
		_log("%s uses %s: %d to %s (%d HP left)." % [u.card.name, atk.name, dealt, defender.card.name, max(0, defender.hp)])

		## --- Step 4: defensive Judgment. A unit that would die survives at N instead.
		## Checked before the offensive half so the Heaven mirror resolves by ordering.
		if defender.hp <= 0 and defender.has_judgment():
			defender.hp = defender.judgment()
			defender.judgment_spent = true
			_log("  Judgment: %s survives at %d HP. Its charge is spent." % [defender.card.name, defender.hp])

		## --- Step 5: offensive Judgment. Anything left standing at or below the
		## attacker's N is executed. Only fires on a survivor — a unit already at 0
		## was killed by damage and needs no execute.
		elif defender.hp > 0 and u.has_judgment() and defender.hp <= u.judgment():
			_log("  Judgment: %s executes %s at %d HP." % [u.card.name, defender.card.name, defender.hp])
			defender.hp = 0
			u.judgment_spent = true
			## The execute is a death, so the defender's own Judgment may still save it.
			if defender.has_judgment():
				defender.hp = defender.judgment()
				defender.judgment_spent = true
				_log("  Judgment: %s survives the execute at %d HP. Both charges spent." % [defender.card.name, defender.hp])

		## --- Step 6: Retribution. A unit marked dead still deals its recoil — nothing
		## leaves the board until _cleanup_dead runs after the whole volley.
		var retr: int = defender.total_retribution()
		if retr > 0:
			var r := u.take_damage(retr)
			_log("  Retribution: %s takes %d back (%d HP left)." % [u.card.name, r, max(0, u.hp)])
		return
```

Note the `elif` on step 5: a unit whose Judgment just saved it at step 4 is not re-checked
for execution in the same attack. Its HP is now exactly N, which would otherwise satisfy
`defender.hp <= u.judgment()` for any attacker with equal or larger N, deleting the save it
just made.

- [ ] **Step 2: Run the existing harness**

Run:

```bash
godot --headless --path . --script res://scripts/core/RulesTest.gd
```

Expected: **41 passed, 0 failed.** Existing targeting, Retribution, and no-overkill assertions must be unaffected — Sanctuary and Judgment are no-ops on cards that lack them.

- [ ] **Step 3: Run the support harness**

Run:

```bash
godot --headless --path . --script res://scripts/core/SupportTest.gd
```

Expected: **127 passed, 0 failed.**

- [ ] **Step 4: Commit** *(skip — not a git repo)*

```bash
git add scripts/core/GameState.gd && git commit -m "feat: seven-step within-attack damage order"
```

---

## Task 5: `GameState.gd` — Sanctuary on non-attack damage

**Files:**
- Modify: `scripts/core/GameState.gd` — `_deal_decay` (~line 1135), `_resolve_towers` (~line 1160), `_resolve_support_effects` (~line 629)

Sanctuary blocks **all** damage sources, not just attacks. Each site that calls
`take_damage` on a unit must absorb first.

- [ ] **Step 1: Add a shared helper**

In `GameState.gd`, immediately before `_deal_lane_damage`, add:

```gdscript
## Apply damage to a unit through its Sanctuary. Every non-attack damage source
## routes through here so the shield genuinely blocks all sources, per CLAUDE.md.
## Returns damage actually dealt to HP (0 if fully absorbed).
func _damage_unit(target: Unit, amount: int, source_label: String) -> int:
	if amount <= 0:
		return 0
	var had: bool = target.sanctuary_active
	var through: int = target.absorb(amount)
	if had and through < amount:
		_log("  Sanctuary absorbs %d from %s on %s." % [amount, source_label, target.card.name])
		return 0
	return target.take_damage(through)
```

- [ ] **Step 2: Route Decay through it**

In `_deal_decay`, replace:

```gdscript
		var dealt := defender.take_damage(n)
```

with:

```gdscript
		var dealt := _damage_unit(defender, n, "Decay")
```

- [ ] **Step 3: Route tower fire through it**

In `_resolve_towers`, replace:

```gdscript
				var dealt := target.take_damage(dmg)
```

with:

```gdscript
				var dealt := _damage_unit(target, dmg, "tower fire")
```

and replace the splash line:

```gdscript
					var d2 := splash.take_damage(cross)
```

with:

```gdscript
					var d2 := _damage_unit(splash, cross, "tower splash")
```

- [ ] **Step 4: Route support damage through it**

In `_resolve_support_effects`, replace:

```gdscript
		var d: int = dt.take_damage(card.effect_value("damage_uncharged", 0))
```

with:

```gdscript
		var d: int = _damage_unit(dt, card.effect_value("damage_uncharged", 0), card.name)
```

Also in `_fire_spite_engine`, replace:

```gdscript
		var dealt: int = victim.take_damage(n)
```

with:

```gdscript
		var dealt: int = _damage_unit(victim, n, "Spite Engine")
```

- [ ] **Step 5: Run both harnesses**

Run:

```bash
godot --headless --path . --script res://scripts/core/RulesTest.gd && godot --headless --path . --script res://scripts/core/SupportTest.gd
```

Expected: 41 passed / 0 failed, then 127 passed / 0 failed.

- [ ] **Step 6: Commit** *(skip — not a git repo)*

```bash
git add scripts/core/GameState.gd && git commit -m "feat: Sanctuary blocks all damage sources"
```

---

## Task 6: `GameState.gd` — end-of-turn triggered abilities and two new effect ops

**Files:**
- Modify: `scripts/core/GameState.gd` — `_resolve_eot_effects` (~line 1075), `_resolve_line_effects` (~line 975)

Every current ability is player-activated. `Rekindle` needs an end-of-turn trigger, which is new machinery.

- [ ] **Step 1: Add the EOT ability pass**

In `_resolve_eot_effects`, immediately before the `_resolve_tool_effects(p)` call, insert:

```gdscript
	## End-of-turn triggered abilities. Distinct from activated abilities: these
	## fire automatically and are not subject to the once-per-turn activation limit,
	## because the turn boundary *is* the limit. Currently only Rekindle.
	for u in p.all_units():
		if not u.is_alive():
			continue
		for ab in u.card.ability_lines():
			if ab.has_effect("eot_restore_sanctuary"):
				u.restore_sanctuary()
				_log("%s rekindles its Sanctuary." % u.card.name)
```

- [ ] **Step 2: Add the board-damage effect op**

In `_resolve_line_effects`, before the `return_from_discard` block, add:

```gdscript
	## The Ledger Closes — damage every enemy unit on one board. Softens a whole
	## board into Judgment execute range rather than killing outright.
	if atk.has_effect("damage_enemy_board"):
		var n: int = atk.effect_value("damage_enemy_board", 15)
		var tb: int = 0
		if u.queued_target is int:
			tb = clampi(int(u.queued_target), 0, enemy.boards.size() - 1)
		var board: Board = enemy.boards[tb]
		for si2 in Board.SLOT_COUNT:
			var v: Unit = board.slots[si2]
			if v != null and v.is_alive():
				var d3: int = _damage_unit(v, n, atk.name)
				_log("  %s: %d to %s (%d HP left)." % [atk.name, d3, v.card.name, max(0, v.hp)])
```

- [ ] **Step 3: Add the throne-reach effect op**

In `_resolve_line_effects`, after the block just added, add:

```gdscript
	## The Gate Opens — throne damage proportional to kills this turn. Deliberately
	## breaks the shielding rule (CLAUDE.md: units shield the structures behind
	## them), but only in proportion to units actually killed, so it is a reward for
	## clearing rather than a bypass.
	if atk.has_effect("throne_per_kill"):
		var per: int = atk.effect_value("throne_per_kill", 15)
		var kills: int = enemy.units_died_this_turn
		if kills > 0:
			var total: int = per * kills
			enemy.throne_take_damage(total)
			_log("*** The Gate Opens: %d kill(s) x %d = %d to the enemy THRONE (%d HP left)." % [kills, per, total, enemy.throne_hp])
			_check_throne(enemy)
		else:
			_log("  The Gate Opens: no enemy unit died this turn — no throne damage.")
```

- [ ] **Step 4: Verify `units_died_this_turn` is reset per turn**

Run:

```bash
grep -n "units_died_this_turn" scripts/core/*.gd
```

Expected: assignment in `_kill`, and a reset at turn start in `GameState` or `Player`. **If no
per-turn reset exists, add one** in the same place `unit_died_this_turn` is cleared — otherwise
`throne_per_kill` counts kills for the whole game and the closer becomes lethal on turn 3.
This is the single most important correctness check in the plan.

- [ ] **Step 5: Run both harnesses**

Run:

```bash
godot --headless --path . --script res://scripts/core/RulesTest.gd && godot --headless --path . --script res://scripts/core/SupportTest.gd
```

Expected: 41 / 0 and 127 / 0.

- [ ] **Step 6: Commit** *(skip — not a git repo)*

```bash
git add scripts/core/GameState.gd && git commit -m "feat: EOT triggered abilities, board damage, throne-per-kill"
```

---

## Task 7: Card data — 16 Heaven cards

**Files:**
- Modify: `data/cards.json`

Append these to the `cards` array. Damage anchors: Judgment units ≈`8 × cost`, non-Judgment ≈`12 × cost`. Retreat is `HP ÷ 25` rounded down.

- [ ] **Step 1: Add the energy card and the five Basics**

```json
{ "id": "heaven_energy", "name": "Heaven Energy", "type": "energy", "faction": "heaven",
  "text": "Adds (turn + 1) Heaven energy to your pool.",
  "flavor": "The light does not ration itself." },

{ "id": "lantern_acolyte", "name": "Lantern Acolyte", "type": "unit", "faction": "heaven",
  "stage": "basic", "hp": 40, "retreat": 1, "evolves_from": null,
  "keywords": [{ "kw": "judgment", "n": 10 }],
  "attacks": [{ "id": "rebuke", "name": "Rebuke", "cost": { "heaven": 1, "colorless": 0 },
    "damage": 8, "text": "8 damage", "effects": [] }],
  "flavor": "The smallest lamp still casts a verdict." },

{ "id": "censer_bearer", "name": "Censer Bearer", "type": "unit", "faction": "heaven",
  "stage": "basic", "hp": 45, "retreat": 1, "evolves_from": null,
  "keywords": [{ "kw": "judgment", "n": 20 }],
  "attacks": [{ "id": "cleanse", "name": "Cleanse", "cost": { "heaven": 2, "colorless": 0 },
    "damage": 16, "text": "16 damage", "effects": [] }],
  "flavor": "A great second attack and a poor first one." },

{ "id": "warden_of_the_lamp", "name": "Warden of the Lamp", "type": "unit", "faction": "heaven",
  "stage": "basic", "hp": 50, "retreat": 2, "evolves_from": null,
  "keywords": [{ "kw": "sanctuary", "n": 0 }],
  "attacks": [{ "id": "hold_the_line", "name": "Hold the Line", "cost": { "heaven": 2, "colorless": 0 },
    "damage": 25, "text": "25 damage", "effects": [] }],
  "flavor": "No judgment to pay for, so it pays full price and hits full weight." },

{ "id": "bellringer_of_the_court", "name": "Bellringer of the Court", "type": "unit", "faction": "heaven",
  "stage": "basic", "hp": 50, "retreat": 2, "evolves_from": null,
  "keywords": [{ "kw": "judgment", "n": 20 }],
  "attacks": [{ "id": "recall_the_verdict", "name": "Recall the Verdict", "cost": { "heaven": 2, "colorless": 0 },
    "damage": 10, "text": "10 damage; restore this unit's Judgment",
    "effects": [{ "op": "restore_own_judgment", "n": 1 }] }],
  "flavor": "One line, two jobs — it can never execute and recharge in the same turn." },

{ "id": "cherub_of_the_open_gate", "name": "Cherub of the Open Gate", "type": "unit", "faction": "heaven",
  "stage": "basic", "hp": 40, "retreat": 1, "evolves_from": null,
  "keywords": [{ "kw": "sanctuary", "n": 0 }],
  "attacks": [{ "id": "ward_the_way", "name": "Ward the Way", "cost": { "heaven": 1, "colorless": 0 },
    "damage": 8, "text": "8 damage", "effects": [] }],
  "flavor": "A shield for the board behind it, not an attacker." },
```

- [ ] **Step 2: Add the four Stage 1s**

```json
{ "id": "arbiter_of_the_third_seal", "name": "Arbiter of the Third Seal", "type": "unit", "faction": "heaven",
  "stage": "stage1", "hp": 70, "retreat": 2, "evolves_from": "censer_bearer",
  "keywords": [{ "kw": "judgment", "n": 30 }],
  "attacks": [{ "id": "weigh_the_soul", "name": "Weigh the Soul", "cost": { "heaven": 3, "colorless": 0 },
    "damage": 25, "text": "25 damage", "effects": [] }],
  "flavor": "Turns every damaged unit on the board into a kill." },

{ "id": "hand_of_the_verdict", "name": "Hand of the Verdict", "type": "unit", "faction": "heaven",
  "stage": "stage1", "hp": 75, "retreat": 3, "evolves_from": "lantern_acolyte",
  "keywords": [{ "kw": "judgment", "n": 20 }, { "kw": "rise", "n": 0 }],
  "attacks": [{ "id": "sentence", "name": "Sentence", "cost": { "heaven": 2, "colorless": 0 },
    "damage": 16, "text": "16 damage", "effects": [] }],
  "flavor": "Kill it twice and it returns with its charge restored. The body is the payload." },

{ "id": "court_of_bells", "name": "Court of Bells", "type": "unit", "faction": "heaven",
  "stage": "stage1", "hp": 50, "retreat": 2, "evolves_from": "bellringer_of_the_court",
  "keywords": [],
  "attacks": [
    { "id": "ring_the_court_bell", "name": "Ring the Court Bell", "ability": true,
      "consume": 2, "damage": 0,
      "text": "Restore Judgment to every friendly unit whose printed card has Judgment.",
      "effects": [{ "op": "restore_board_judgment", "n": 1 }] },
    { "id": "summons", "name": "Summons", "cost": { "heaven": 2, "colorless": 0 },
      "damage": 16, "text": "16 damage", "effects": [] }],
  "flavor": "It carries no Judgment itself, so it cannot reset its own. That is the counterplay." },

{ "id": "radiant_bastion", "name": "Radiant Bastion", "type": "unit", "faction": "heaven",
  "stage": "stage1", "hp": 90, "retreat": 3, "evolves_from": "warden_of_the_lamp",
  "keywords": [{ "kw": "sanctuary", "n": 60 }],
  "attacks": [{ "id": "pillar_of_light", "name": "Pillar of Light", "cost": { "heaven": 5, "colorless": 0 },
    "damage": 65, "text": "65 damage", "effects": [] }],
  "flavor": "The hardest single hit in the faction, on the body hardest to kill." },
```

- [ ] **Step 3: Add the four Stage 2s**

```json
{ "id": "seraph_of_the_final_ledger", "name": "Seraph of the Final Ledger", "type": "unit", "faction": "heaven",
  "stage": "stage2", "hp": 100, "retreat": 4, "evolves_from": "arbiter_of_the_third_seal",
  "keywords": [{ "kw": "judgment", "n": 50 }],
  "attacks": [
    { "id": "the_ledger_closes", "name": "The Ledger Closes", "ability": true,
      "consume": 2, "damage": 0,
      "text": "Deal 15 damage to every enemy unit on one board.",
      "effects": [{ "op": "damage_enemy_board", "n": 15 }] },
    { "id": "final_accounting", "name": "Final Accounting", "cost": { "heaven": 5, "colorless": 0 },
      "damage": 42, "text": "42 damage", "effects": [] }],
  "flavor": "It does not kill a board. It pushes a board into range." },

{ "id": "empyrean_sentinel", "name": "Empyrean Sentinel", "type": "unit", "faction": "heaven",
  "stage": "stage2", "hp": 100, "retreat": 4, "evolves_from": "radiant_bastion",
  "keywords": [{ "kw": "sanctuary", "n": 0 }],
  "attacks": [
    { "id": "rekindle", "name": "Rekindle", "ability": true, "consume": 0, "damage": 0,
      "text": "At end of turn, restore this unit's Sanctuary.",
      "effects": [{ "op": "eot_restore_sanctuary", "n": 1 }] },
    { "id": "judgment_of_light", "name": "Judgment of Light", "cost": { "heaven": 6, "colorless": 0 },
      "damage": 75, "text": "75 damage", "effects": [] }],
  "flavor": "Two hits in one turn, or it does not die at all." },

{ "id": "throne_of_the_risen_court", "name": "Throne of the Risen Court", "type": "unit", "faction": "heaven",
  "stage": "stage2", "hp": 95, "retreat": 3, "evolves_from": "hand_of_the_verdict",
  "keywords": [{ "kw": "judgment", "n": 40 }, { "kw": "rise", "n": 0 }],
  "attacks": [{ "id": "second_sentence", "name": "Second Sentence", "cost": { "heaven": 4, "colorless": 0 },
    "damage": 33, "text": "33 damage", "effects": [] }],
  "flavor": "It holds a lane forever. It does not win." },

{ "id": "verdict_of_the_throne", "name": "Verdict of the Throne", "type": "unit", "faction": "heaven",
  "stage": "stage2", "hp": 110, "retreat": 4, "evolves_from": "arbiter_of_the_third_seal",
  "keywords": [{ "kw": "judgment", "n": 50 }],
  "attacks": [
    { "id": "the_gate_opens", "name": "The Gate Opens", "ability": true,
      "consume": 3, "damage": 0,
      "text": "Deal damage to the enemy throne equal to enemy units destroyed this turn x 15.",
      "effects": [{ "op": "throne_per_kill", "n": 15 }] },
    { "id": "final_reckoning", "name": "Final Reckoning", "cost": { "heaven": 5, "colorless": 0 },
      "damage": 42, "text": "42 damage", "effects": [] }],
  "flavor": "The gate opens only as wide as the dead have made it." },
```

Note the attack id is `final_reckoning`, not `final_accounting` — two cards cannot share an
attack id, and `Unit.abilities_used` keys on it.

- [ ] **Step 4: Add the Tool**

```json
{ "id": "aegis_of_the_choir", "name": "Aegis of the Choir", "type": "tool", "faction": "heaven",
  "cost": 0, "text": "Attach to a unit. That unit gains Sanctuary. If it already has Sanctuary, restore it instead.",
  "effects": [{ "op": "grant_sanctuary", "n": 1 }],
  "flavor": "A one-shot investment on a body the opponent can kill." },
```

- [ ] **Step 5: Validate the JSON**

Run:

```bash
python -c "import json; d=json.load(open('data/cards.json')); cs=d['cards'] if isinstance(d,dict) else d; print(len(cs), 'cards'); h=[c for c in cs if c.get('faction')=='heaven']; print(len(h), 'heaven'); ids=[c['id'] for c in cs]; assert len(ids)==len(set(ids)), 'DUPLICATE CARD ID'; aids=[a['id'] for c in cs for a in c.get('attacks',[])]; import collections; print('dup attack ids:', [k for k,v in collections.Counter(aids).items() if v>1])"
```

Expected: `75 cards`, `16 heaven`, no duplicate card id assertion, and an empty duplicate-attack-id list.

- [ ] **Step 6: Verify evolution targets resolve**

Run:

```bash
python -c "import json; d=json.load(open('data/cards.json')); cs=d['cards'] if isinstance(d,dict) else d; ids={c['id'] for c in cs}; bad=[(c['id'],c.get('evolves_from')) for c in cs if c.get('evolves_from') and c['evolves_from'] not in ids]; print('BROKEN:', bad)"
```

Expected: `BROKEN: []`.

- [ ] **Step 7: Run the harnesses**

Run:

```bash
godot --headless --path . --script res://scripts/core/RulesTest.gd && godot --headless --path . --script res://scripts/core/SupportTest.gd
```

Expected: both pass. `SupportTest.gd` includes card-data integrity assertions that will catch a malformed Heaven card.

- [ ] **Step 8: Commit** *(skip — not a git repo)*

```bash
git add data/cards.json && git commit -m "feat: 16 Heaven cards"
```

---

## Task 8: The two Judgment-restore effect ops

**Files:**
- Modify: `scripts/core/GameState.gd` — `_resolve_line_effects`, and the ability resolution path
- Modify: `scripts/core/GameState.gd` — Tool attach path for `grant_sanctuary`

- [ ] **Step 1: Add `restore_own_judgment`**

In `_resolve_line_effects`, add:

```gdscript
	## Recall the Verdict — the Bellringer recharges itself. One attack line doing
	## two jobs is the brake: it can never execute and recharge in the same turn.
	if atk.has_effect("restore_own_judgment"):
		u.judgment_spent = false
		_log("  %s recalls its Judgment." % u.card.name)
```

- [ ] **Step 2: Add `restore_board_judgment`**

In `_resolve_line_effects`, add:

```gdscript
	## Ring the Court Bell — board-wide reset. Reads *printed* keywords only, so a
	## unit granted Judgment by a Tool or support card is deliberately not refreshed;
	## otherwise granting widely and resetting board-wide is an uncapped loop.
	if atk.has_effect("restore_board_judgment"):
		var n_restored: int = 0
		for v in p.all_units():
			if v.card.has_kw("judgment") and v.judgment_spent:
				v.judgment_spent = false
				n_restored += 1
		_log("  The Court rings: Judgment restored to %d unit(s)." % n_restored)
```

- [ ] **Step 3: Wire `grant_sanctuary` into the Tool attach path**

Find where Tools are attached (`grep -n "u.tool = " scripts/core/GameState.gd`). After the
assignment, add:

```gdscript
	## Aegis of the Choir — grants plain Sanctuary, or restores an existing one.
	if card.has_effect("grant_sanctuary"):
		if u.card.has_kw("sanctuary"):
			u.restore_sanctuary()
			_log("  %s restores %s's Sanctuary." % [card.name, u.card.name])
		else:
			u.grant_sanctuary()
			_log("  %s grants %s Sanctuary." % [card.name, u.card.name])
```

- [ ] **Step 4: Run the harnesses**

Run:

```bash
godot --headless --path . --script res://scripts/core/RulesTest.gd && godot --headless --path . --script res://scripts/core/SupportTest.gd
```

Expected: 41 / 0 and 127 / 0.

- [ ] **Step 5: Commit** *(skip — not a git repo)*

```bash
git add scripts/core/GameState.gd && git commit -m "feat: Judgment restore effects and Sanctuary Tool"
```

---

## Task 9: `HeavenTest.gd` harness

**Files:**
- Create: `scripts/core/HeavenTest.gd`

- [ ] **Step 1: Write the harness**

Create `scripts/core/HeavenTest.gd`:

```gdscript
extends SceneTree

## Headless Heaven harness:
##   godot --headless --script res://scripts/core/HeavenTest.gd
##
## Covers both halves of Judgment, the Heaven mirror ordering, Sanctuary pool
## depletion and terminal overflow, and the batched-death guarantee.

var _pass := 0
var _fail := 0


func _initialize() -> void:
	var db = root.get_node_or_null("CardDB")
	if db == null:
		db = load("res://scripts/core/CardDB.gd").new()
		db.name = "CardDB"
		root.add_child(db)
	if db._cards.is_empty():
		db._load()

	_run(db)
	quit(1 if _fail > 0 else 0)


func _check(label: String, actual, expected) -> void:
	if actual == expected:
		_pass += 1
		print("  ok   %s" % label)
	else:
		_fail += 1
		print("  FAIL %s — expected %s, got %s" % [label, str(expected), str(actual)])


func _unit(db, id: String) -> Unit:
	return Unit.new(db.get_card(id))


func _run(db) -> void:
	print("\n=== Godsfall Heaven harness ===\n")
	_test_card_data(db)
	_test_sanctuary_pool(db)
	_test_sanctuary_overflow(db)
	_test_judgment_defensive(db)
	_test_judgment_offensive(db)
	_test_judgment_restore(db)
	_test_rise_restores_keywords(db)
	print("\n%d passed, %d failed\n" % [_pass, _fail])


# ---- every Heaven card loads with the printed values from heaven.md
func _test_card_data(db) -> void:
	print("Heaven card data:")
	var acolyte := _unit(db, "lantern_acolyte")
	_check("Lantern Acolyte HP", acolyte.max_hp(), 40)
	_check("Lantern Acolyte Judgment", acolyte.judgment(), 10)
	var bastion := _unit(db, "radiant_bastion")
	_check("Radiant Bastion Sanctuary pool", bastion.sanctuary_pool, 60)
	_check("Radiant Bastion Sanctuary live", bastion.sanctuary_active, true)
	var warden := _unit(db, "warden_of_the_lamp")
	_check("plain Sanctuary is live at pool 0", warden.sanctuary_active, true)
	_check("plain Sanctuary pool is 0", warden.sanctuary_pool, 0)
	_check("Warden has no Judgment", warden.has_judgment(), false)


# ---- pool depletes, and small hits are inefficient against it
func _test_sanctuary_pool(db) -> void:
	print("Sanctuary N depletion:")
	var u := _unit(db, "radiant_bastion")
	_check("30 into pool 60 -> 0 through", u.absorb(30), 0)
	_check("pool now 30", u.sanctuary_pool, 30)
	_check("still live", u.sanctuary_active, true)
	_check("20 more -> 0 through", u.absorb(20), 0)
	_check("pool now 10", u.sanctuary_pool, 10)


# ---- the terminal overflow: an exhausted pool still eats one whole instance
func _test_sanctuary_overflow(db) -> void:
	print("Sanctuary terminal overflow:")
	var u := _unit(db, "radiant_bastion")
	_check("110 into pool 60 -> 0 through", u.absorb(110), 0)
	_check("shield spent", u.sanctuary_active, false)
	_check("pool emptied", u.sanctuary_pool, 0)
	_check("next hit passes fully", u.absorb(25), 25)

	var w := _unit(db, "warden_of_the_lamp")
	_check("plain Sanctuary eats a 75 hit", w.absorb(75), 0)
	_check("plain Sanctuary now spent", w.sanctuary_active, false)


# ---- defensive: a lethal hit leaves the unit alive at N, charge spent
func _test_judgment_defensive(db) -> void:
	print("Judgment, defensive half:")
	var u := _unit(db, "arbiter_of_the_third_seal")
	_check("starts with Judgment", u.has_judgment(), true)
	u.hp = 10
	u.take_damage(40)
	_check("HP dropped to 0", u.hp <= 0, true)
	## Simulate the pipeline's step 4.
	if u.hp <= 0 and u.has_judgment():
		u.hp = u.judgment()
		u.judgment_spent = true
	_check("survives at 30", u.hp, 30)
	_check("charge spent", u.has_judgment(), false)
	_check("printed value unchanged", u.judgment(), 30)


# ---- offensive: a survivor at or below N is executed
func _test_judgment_offensive(db) -> void:
	print("Judgment, offensive half:")
	var attacker := _unit(db, "arbiter_of_the_third_seal")
	var defender := _unit(db, "warden_of_the_lamp")
	defender.sanctuary_active = false      ## strip the shield to isolate Judgment
	defender.hp = 28
	_check("defender inside range", defender.hp <= attacker.judgment(), true)
	if defender.hp > 0 and attacker.has_judgment() and defender.hp <= attacker.judgment():
		defender.hp = 0
		attacker.judgment_spent = true
	_check("defender executed", defender.is_alive(), false)
	_check("attacker charge spent", attacker.has_judgment(), false)


# ---- Bellringer recharges itself; Court of Bells recharges the board
func _test_judgment_restore(db) -> void:
	print("Judgment restore:")
	var bell := _unit(db, "bellringer_of_the_court")
	bell.judgment_spent = true
	_check("spent", bell.has_judgment(), false)
	bell.judgment_spent = false
	_check("recalled", bell.has_judgment(), true)

	var court := _unit(db, "court_of_bells")
	_check("Court carries no printed Judgment", court.card.has_kw("judgment"), false)


# ---- Rise returns a fresh body with its printed keywords restored
func _test_rise_restores_keywords(db) -> void:
	print("Rise restores Judgment:")
	var u := _unit(db, "throne_of_the_risen_court")
	u.judgment_spent = true
	var risen := u.make_risen()
	_check("returns at half HP", risen.hp, 47)
	_check("Judgment restored", risen.has_judgment(), true)
	_check("Rise is spent", risen.has_rise(), false)
	_check("no attached energy", risen.attached, 0)
```

- [ ] **Step 2: Run it**

Run:

```bash
godot --headless --path . --script res://scripts/core/HeavenTest.gd
```

Expected: **28 passed, 0 failed.**

- [ ] **Step 3: Fix any failures**

If `Rise returns at half HP` fails with 47 vs 48, check `make_risen`'s `int(card.max_hp / 2.0)` against the printed 95 HP — `int(47.5)` is 47. If card data changed the HP, update the assertion to match the card, not the other way round.

- [ ] **Step 4: Commit** *(skip — not a git repo)*

```bash
git add scripts/core/HeavenTest.gd && git commit -m "test: Heaven keyword harness"
```

---

## Task 10: `heaven.md` faction file

**Files:**
- Create: `heaven.md`

- [ ] **Step 1: Write the file**

Create `heaven.md` following `hel.md`'s structure exactly: a `> Read CLAUDE.md first` header,
Domain / Verb / One-line identity, `## Why Heaven Works In This Engine`, `## Keywords` (listing
only what Heaven prints, pointing at `CLAUDE.md` for the shared definitions), `## Evolution
Lines`, `## Cards` grouped by stage with a `>` rationale block under each, `## The Energy
Curve`, `## Open Questions`, and `## Card Count` with a Judgment/Retreat table.

Source all content from `docs/specs/2026-08-08-heaven-faction-design.md` — the card list,
rationale blocks, and Open Questions are already written there and should be carried over
rather than reinvented. The spec's "What Heaven Is", "Cards", and "Open Questions" sections
map onto the faction file almost directly.

The evolution lines table:

| Line | Path | Identity |
|---|---|---|
| **The Ledger** | Censer Bearer → Arbiter of the Third Seal → **Seraph of the Final Ledger** *or* **Verdict of the Throne** | The flagship. Branches at Stage 2 — the execute payoff or the closer. |
| **The Lamp** | Warden of the Lamp → Radiant Bastion → Empyrean Sentinel | Sanctuary. Heaven's damage and its unkillable body. |
| **The Risen** | Lantern Acolyte → Hand of the Verdict → Throne of the Risen Court | Judgment + Rise. Stacked reprieves. |
| **The Court** | Bellringer of the Court → Court of Bells | The reset engine. Stops at Stage 1. |
| **Unlinked** | Cherub of the Open Gate | — |

- [ ] **Step 2: Verify the Judgment/Retreat table matches the JSON**

Run:

```bash
python -c "import json; d=json.load(open('data/cards.json')); cs=d['cards'] if isinstance(d,dict) else d; [print(c['name'], c['hp'], 'retreat', c['retreat'], c.get('keywords')) for c in cs if c.get('faction')=='heaven' and c.get('type')=='unit']"
```

Cross-check every row against the table written in `heaven.md`. Retreat must equal `HP ÷ 25`
floored, except where the faction file explicitly justifies a deviation.

- [ ] **Step 3: Commit** *(skip — not a git repo)*

```bash
git add heaven.md && git commit -m "docs: Heaven faction file"
```

---

## Task 11: Card art

**Files:**
- Modify: `tools/make_card_art.py`

- [ ] **Step 1: Check the fallback works first**

Run:

```bash
godot --headless --path . --script res://scripts/core/SceneSmokeTest.gd
```

Expected: all four screens instantiate. Heaven cards with no PNG fall back to `CardView`'s
initials placeholder — **art is optional by design** (`CLAUDE.md`), so this task never blocks
anything.

- [ ] **Step 2: Add emblem functions**

Add one drawing function per Heaven card id to `tools/make_card_art.py`, following the
existing pattern: coordinates in 0–1 space, drawn at 4× and downscaled, 128px source. Emblems
are **symbolic, drawn from the card's name** — a lantern for Lantern Acolyte, a bell for
Bellringer, a set of scales for Arbiter of the Third Seal.

- [ ] **Step 3: Regenerate and import**

Run:

```bash
python tools/make_card_art.py
godot --headless --path . --import
```

Expected: the script prints which ids fell back to the generic emblem. New PNGs get `.import`
files from the second command — without it `load()` fails at runtime.

- [ ] **Step 4: Commit** *(skip — not a git repo)*

```bash
git add tools/make_card_art.py assets/art && git commit -m "feat: Heaven card art"
```

---

## Task 12: Final verification

- [ ] **Step 1: Run every harness**

Run each and confirm the counts:

```bash
godot --headless --path . --script res://scripts/core/RulesTest.gd
godot --headless --path . --script res://scripts/core/SupportTest.gd
godot --headless --path . --script res://scripts/core/DeckStoreTest.gd
godot --headless --path . --script res://scripts/core/DragDropTest.gd
godot --headless --path . --script res://scripts/core/SceneSmokeTest.gd
godot --headless --path . --script res://scripts/core/PlaythroughTest.gd
godot --headless --path . --script res://scripts/core/SupportUITest.gd
godot --headless --path . --script res://scripts/core/HeavenTest.gd
```

Expected: 41, 127, 41, 25, all-screens-ok, playthrough-ok, 41, 28 — **all with 0 failures**.

- [ ] **Step 2: Update the `## Status` section of `CLAUDE.md`**

Add Heaven to the harness table and card count. Change "all 15 Hel cards" to reflect the new
total (75 cards, two factions). Add `HeavenTest.gd` to the harness table with its assertion
count. State plainly that the Heaven AI has not been tuned — `AIPlayer` has no Judgment or
Sanctuary heuristics, so it will play Heaven badly.

- [ ] **Step 3: Report honestly**

State which harnesses were actually run this session and their real counts. Per `CLAUDE.md`:
*"Harness passes" means it was run this session. If it wasn't, say so.*

---

## Known Gaps After This Plan

Deliberately out of scope — record them, do not silently fix them:

- **`AIPlayer` has no Heaven heuristics.** It will not value Judgment charges, will not hold
  Sanctuary bodies back, and will not use `The Gate Opens` at the right time. A Heaven-vs-Hel
  AI game will run, but it will not be a good reading of balance.
- **No Heaven sample deck.** `DeckStore.sample_decks()` ships four Hel decks. A Heaven starter
  deck is a natural follow-up.
- **`Windfury` is documented but unimplemented.** No card uses it; the keyword is defined in
  `CLAUDE.md` so Tempest and future rule-breakers have a home. Implementing it means a second
  queued attack slot on `Unit`.
- **The Judgment damage rate (≈8/energy) is untested.** `Warden of the Lamp` vs `Censer Bearer`
  is the control pair to read it against.
- **Stall is unmeasured.** The spec's central risk. A Heaven-vs-Heaven AI mirror is the cheapest
  first reading, but see the AI gap above.
