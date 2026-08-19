# Plan — Forge, the fifth faction

> Design is settled in `forge.md`. This plan covers **engine + cards together**, because
> a card whose op the engine does not implement parses fine and silently does nothing —
> a failure shape already in `CLAUDE.md`'s decision log twice (dropped unit `effects`,
> Heaven's zeroed costs).

**Scope:** core set, ~20 cards, matching how Gaia (19) and Void (21) shipped.

> **DONE 2026-08-16 — phases 1-4 and 6 shipped; phase 5 (Windfury) deliberately not.**
> 19 cards, nine payoff ops, AI heuristics, generated art, two sample decks, and
> `ForgeTest.gd` at 91 assertions. All sixteen harnesses green at 1124 counted
> assertions. See `forge.md` for what landed.

**Decided in conversation 2026-08-16:**

- Stoke is an **ability that sets a per-unit state**, not a way to pay energy.
- Stoke damage is **unpreventable** — `Sanctuary` and `Resist` ignore it.
- The flag is **per-unit**; board-wide readers must print that they read others.
- `Stoke N` **varies by unit**, anchored at **20 HP ≈ 1 energy of value**.
- Abilities are **free unless they print a cost**; the printable costs are `Consume`,
  `Stoke`, `Scrap` — never pool energy.

---

## What does not exist yet

Verified against the engine on 2026-08-16 by scraping `has_effect` / `effect_value`
call sites (the same scrape `tools/add_bestiary_units.py` uses): **79 ops implemented,
none Stoke-related.**

| Needed | Status |
|---|---|
| `Unit.stoked_this_turn` state | Does not exist |
| `Stoke` as an ability cost | Does not exist |
| `Scrap` as an ability cost | Does not exist |
| Payoff ops reading the flag | Do not exist |
| **`Windfury`** | **Documented, never implemented — no card uses it** |
| Forge as a 5th faction colour | **Ramp + energy token mark already exist** in `Theme.gd` / `EnergyIcon.gd` |

Windfury is the largest single piece and is **deliberately deferred** — see Phase 5.

---

## Phase 1 — Stoke state and the ability cost

**Goal:** a unit can stoke, the flag is visible, and it clears correctly.

1. **`Unit.stoked_this_turn: int = 0`** — an *amount*, not a bool, so amount-scaling
   payoffs and thresholds both read one field. Zero means "has not stoked."
   Model it on `decay_taken_this_turn`, which is the existing per-turn counter.
2. **Clear it at the same point** that existing per-turn unit state clears. Find where
   `decay_taken_this_turn` and `protected_this_turn` reset and reset alongside them —
   do not add a second clearing site.
3. **`GameState.use_ability()` accepts a `stoke` cost.** The line's `"stoke": N` deals N
   to the unit **directly**, bypassing `Sanctuary`, `Resist`, and `protect`, then adds N
   to `stoked_this_turn`.
   - It may kill the unit. Route the death through the normal `_kill` / `_cleanup_dead`
     path so `Toll`, `Rise`, and `Essence` all fire.
   - It deals no `Retribution` — there is no attacker.
4. **`"scrap": true`** — the ability requires choosing another unit you control, which is
   then destroyed through the same normal death path. Reuse the existing `choice_required`
   signal rather than adding a second picker.
5. **Rise / evolution / retreat clear the flag.** It is per-turn state, so it should never
   survive a card being rebuilt. `Unit.make_risen()` already rebuilds from `CardData`;
   confirm the new field is not carried.

**Tests (`ForgeTest.gd`, new):** stoke sets the amount; a second activation is refused by
the once-per-turn rule; `Sanctuary 100` does **not** absorb it; `Resist 10` does **not**
reduce it; lethal stoke kills and fires `Toll`; the flag clears at end of turn; scrap kills
the chosen unit and fires its death triggers.

> **Write the Sanctuary and Resist assertions first.** They are the two rules most likely
> to be got wrong by routing stoke through the ordinary damage path out of habit, and they
> are the whole reason the keyword is unpreventable.

---

## Phase 2 — Payoff ops

**Goal:** cards can read the flag. Each op is a separate `has_effect` / `effect_value`
site so the generator's scrape picks it up.

Start with the ops the core set actually needs — **do not build the whole catalogue.**
`forge.md`'s payoff tables are a design menu, not a build list.

| Op | Reads | Notes |
|---|---|---|
| `stoked_bonus_damage` | `stoked_this_turn > 0` | Flat +N on the attack |
| `stoked_scale_damage` | the *amount* | +1 per 2 HP stoked — the answer to "why stoke 50" |
| `stoked_free_attack` | flag | Attack costs no energy this turn |
| `stoked_threshold` | amount ≥ N | Gates the geometry-breaking payoffs |
| `stoked_ignore_shield` | flag or threshold | Reuses whatever `The Gate Opens` already does |
| `stoked_cleave` | flag | Stoke damage also hits enemy units |
| `stoked_heal_back` | the amount | Heals the HP stoked; **the flag stays set** |

**`stoked_heal_back` is the one to be careful with.** It must not clear
`stoked_this_turn` — the whole point is that the unit still counts as having stoked, so
other payoffs stay on. A test should assert exactly that.

**Ramp payoffs are deliberately excluded from the core set.** `forge.md` names them as
the one class that can break pacing, since attached energy is permanent, decay-immune, and
feeds Void's Gap. Ship the faction without them and add at most one later, deliberately.

---

## Phase 3 — Forge energy and the colour

1. **Forge energy card** in `data/cards.json`, `faction: "forge"`, same `t + 1` rule as
   every other colour. No engine change — the pool is one untyped int.
2. **Verify the colour renders** end to end: `Theme.gd` already holds the ramp
   (`7a3312` / `e07a3c` / `ffb37a`) and `EnergyIcon.gd` draws the flame mark. Confirm the
   deck builder's faction filter picks it up — it derives from `CardDB`, so it should,
   **but this is exactly the bug that made all of Heaven invisible in the builder.**
3. **`Palette.KEYWORD_COLORS` + `KEYWORD_HELP` entries for `stoke` and `scrap`.**
   `CardViewTest` asserts every coloured keyword has help text, so the suite fails until
   both are written. That guard is working as intended.

---

## Phase 4 — The card set (~20)

Authored **after** phases 1–3, so every op a card names already exists.

| Type | Count | Notes |
|---|---|---|
| Energy | 1 | |
| Units | 12–14 | 4–5 evolution chains, one idea each |
| Forge supports | 3–4 | Faction-locked; this is where the aggression lives |
| Tool | 1 | |
| Tower support | 0–1 | Optional |

**Chain ideas, one per chain** — following how Gaia's five chains were built:

1. **The big stoker.** High HP, large `Stoke N`, threshold payoffs. The Stage 2 is the
   geometry-breaker (*"stoked 40+: ignores shielding and hits both boards"*).
2. **The cheap stoker.** Small `Stoke 20`, cheap repeatable payoffs. The body that turns
   the flag on when you just need it on.
3. **The scrapper.** `Scrap` abilities. The Forge/Hel door.
4. **The cleaver.** Stoke damage splashes to enemy units — stoke as the weapon itself.
5. **The sustain body.** `stoked_heal_back`. Slow, expensive, and only good *because*
   other cards read the state.

**Forge supports** — the faction's distinctive class. Faction-locked, above the neutral
band, priced in HP and bodies. Candidates from the conversation:

- Prevent all Stoke damage this turn.
- Double Stoke damage taken; all Stoke payoffs also double. **Watch this one** — it is a
  multiplier on a multiplier and may want a tighter number than a clean ×2.
- A powerful heal restricted to units with **Forge energy attached** — the gate keeps it
  from being splashed as generic healing.

**Hard rule when authoring:** a Forge support may **not** sell damage more efficiently
than an attack. `forge.md` explains why the usual brake does not apply here — a
Stoke-paid attack builds no annuity either, so the asymmetry that normally keeps supports
honest is absent and the rule has to be enforced by hand.

**Extend `tools/add_bestiary_units.py`'s validators** to cover Forge before authoring:
the Stoke anchor, the no-ramp rule, the support damage line. A guard that only exists in
the test suite is a guard you hit late.

---

## Phase 5 — Windfury (separate, deferred)

**Not part of the core set.** Windfury needs a second queued attack slot on `Unit`, which
touches queueing, the attack lock, volley ordering, and the combat UI. It is a general
engine feature, not a Forge one.

Forge's multi-attack identity is served in the core set by the **conditional** form
(*"if this unit stoked, it may attack twice"*), which needs the same engine work — so
either both wait, or the second-slot work happens here and static Windfury comes free.

**Decide before building:** if the second attack slot lands in Phase 1–2, the conditional
payoff is available to the core set. If not, cut it from the card list rather than printing
a card that does nothing.

**The standing constraint holds either way:** no Forge/Heaven card may carry `Windfury`
and `Judgment` on the same body, and a board-wide *"your units gain Windfury"* is not
printable in Forge at all — in a two-colour deck it would grant it to Heaven bodies.

---

## Phase 6 — Sample decks and verification

1. **1–2 Forge sample decks**, exactly 60 cards, added to `DeckStore.sample_decks()`.
   `_add_missing_samples()` backfills them onto existing saves by name.
2. **Check for stranded evolutions by hand** — a Stage 1 whose Basic is not in the deck.
   No harness catches this; `errors_at()` checks size, energy, Basics and the copy cap,
   and a deck full of unplayable Stage 1s passes all four.
3. **Run all fifteen harnesses.** Update `EXPECTED_ASSERTIONS` in each file that gains
   assertions — deliberately, for a known reason. A guard edited reflexively to match
   whatever ran is no guard at all.
4. **Drive the new decks through real AI games** before claiming they work. `DeckStoreTest`
   proves a list is *legal*; it says nothing about whether it functions.

---

## Risks

- **AI heuristics.** `AIPlayer` will not stoke, will not sequence stoke-then-attack, and
  will not value the flag. Forge games will run and **AI results will not be a balance
  reading** — the same caveat Heaven, Void and Gaia all carry. Do not tune Forge on AI
  numbers.
- **The Stoke anchor is unmeasured.** 20 HP ≈ 1 energy is derived from the annuity
  argument, not from play. It is the faction's most important number.
- **Forge/Hel may be the strongest pairing in the game.** Scrap on a `Toll` body is paid
  fuel, and Toll Engine is already the balance outlier at 9-0 vs Barrow Wall. Watch it.
- **Nothing here has been playtested, and neither have the existing four factions.**
  `CLAUDE.md` still lists human playtesting as outstanding.
