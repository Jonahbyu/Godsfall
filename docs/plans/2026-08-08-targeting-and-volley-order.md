# Chosen targeting & volley ordering

Rules settled in `CLAUDE.md` this session — see *Chosen targets*, *Volley ordering*, and
the decision-log entry. This plan is the engine work only; the rules are not open here.

## What is being built

1. **Chosen targets.** A queued attack may name a living enemy unit on the board its
   attacker faces. Validated at *resolution*, not at queue time — a stale pick falls
   through the existing chain.
2. **Volley ordering.** Queued attacks resolve in a player-chosen order, defaulting to
   the current left-to-right, board-by-board scan.

Both are opt-in. A player who touches neither must see byte-identical behaviour to today,
which is the main invariant every task below is checked against.

## The one structural decision

Attack resolution currently rescans the board (`_resolve_attacks`, GameState.gd:953) and
reads `u.queued_attack` off each unit. Ordering needs a **list**, not a scan.

Add `Player.volley: Array[Unit]` — the resolution order, holding units with a queued
attack. `queue_attack` appends, `cancel_attack` removes, `_resolve_attacks` walks it.
`Unit.queued_attack` stays as-is so every existing read still works; the array is purely
the *order*, not a second source of truth about what is queued.

Why a unit array rather than a struct array: the queue already lives on the unit, and a
second record would let the two disagree. The array answers only "in what order", and any
entry whose `queued_attack` is null when resolution reaches it is skipped.

## Tasks

### 1. `Unit.queued_target` becomes a real lane target

Already exists (Unit.gd:18) but is only used for friendly picks (`devour_friendly`).
`_deal_lane_damage` never reads it. No new field needed.

- `_deal_lane_damage` (GameState.gd:1115) gains step 1: if a named target was passed, is
  a `Unit`, is alive, and is on `eb` — use it. Otherwise fall through to the existing
  slot-across → leftmost logic, unchanged.
- The `enemy.boards[bi]` membership check is what enforces per-board and no-structures at
  once: a tower, a throne, or a unit on the other board simply is not in `eb.slots`.
- `_execute_attack` already passes `u.queued_target` through `_resolve_line_effects`;
  confirm the lane-damage path forwards it (it currently drops it).
- `_deal_decay` is **not** touched. Decay stays deterministic.

**Verify:** `RulesTest` — named target is hit over the slot across; named target on the
other board is refused and falls back; named target killed earlier in the volley falls
back; a tower/throne cannot be named.

**The stale-pick test is the one that matters most.** Set up an attacker in slot 0 whose
slot-across (`A`) is alive, aim it at slot 2 (`X`), kill `X` with an earlier attack in the
volley, and assert the damage lands on **`A`, not `B`**. The natural buggy implementation
— scanning outward from the dead target — passes every other targeting test and fails only
this one. Written as an explicit assertion rather than left to the general fallback test.

### 2. `Player.volley` and ordered resolution

- `Player.volley: Array[Unit]`, cleared at end of turn alongside the existing queue reset.
- `queue_attack` appends `u` if not already present. `cancel_attack` erases it — note
  `cancel_attack` currently takes only a `Unit` (GameState.gd:214) and will need the
  player, or `Player` needs a lookup; prefer passing the player to avoid a scan.
- `GameState.reorder_volley(p, from_idx, to_idx)` — the one mutation the UI needs.
- `_resolve_attacks` walks `p.volley` instead of scanning boards. Must still tolerate a
  unit that died before its attack resolved, or whose queue was cleared.
- **Migration guard:** any unit with a `queued_attack` but missing from `volley` must
  still fire, appended in board order after the ordered entries. This is what keeps the
  harnesses that call `queue_attack` directly working, and protects against a future
  code path that sets `queued_attack` without going through `queue_attack`.

**Verify:** `RulesTest` — default order matches the old left-to-right result exactly;
reordering changes which target a later attack hits; cancelling removes from the volley;
a unit that dies mid-volley is skipped.

### 3. Attack lock interaction

`_fire_locked_attacks` (GameState.gd:1509) re-queues via `queue_attack`, so ordering comes
free — locked attacks append in `all_units()` order at the start of turn.

Open point to settle while building: a locked unit does **not** remember its target. The
lock is documented as re-queueing "the attack it used last turn", and remembering a target
means remembering a *unit reference* that may be dead, retreated, or replaced. Keep
`last_attack` as-is and let locked re-queues be untargeted. Note this in `CLAUDE.md`'s
attack-lock section if it isn't already implied.

### 4. UI — target picking and reordering (`Combat.gd`)

Smallest thing that works, in this order:

- **Targeting:** after choosing an attack, enter a target-pick mode that highlights living
  enemy units on the facing board only. A click on empty space or a "no target" affordance
  queues untargeted. There is already a support-targeting mode in `Combat.gd` to model
  this on — reuse its shape rather than inventing a second one.
- **Volley list:** a panel showing queued attacks in resolution order, each row
  `attacker → attack → target`, drag to reorder. This is the feature's whole visible
  surface; without it ordering is invisible and unusable.
- Cancelling an attack from the list must go through `cancel_attack` so `volley` stays
  consistent.

### 5. AI

`_queue_attacks` (AIPlayer.gd:293) sorts candidates by `_score` and queues — it already
has an implicit order, it just isn't recorded as one.

Deliberately minimal, per the plan's open question in `CLAUDE.md`:

- Queue in score order (already happens) so `volley` reflects it.
- **Targeting heuristic:** prefer a target this attack can kill outright; among those the
  highest-value body. Otherwise leave untargeted.
- Do **not** attempt volley search. A bad approximation is worse than the fixed scan for
  balance readings.

Flag clearly in the summary that AI numbers stay unreliable for this feature until the
heuristics are real.

### 6. Harness updates

`RulesTest`, `SupportTest`, `HeavenTest`, `PlaythroughTest` all call `queue_attack`
positionally. The signature already ends in `target = null`, so existing calls compile
unchanged — confirm rather than assume.

New assertions land in `RulesTest` (targeting + ordering) per tasks 1–2. `HeavenTest`
gains the case that motivated the whole change: **soften with one attack, execute with a
Judgment unit second, verify the execute fires** — driven through `_deal_lane_damage`, not
simulated inline, matching the existing Heaven test discipline.

## Order of work

1 → 2 → 6 (engine + tests green) → 3 → 5 → 4. UI last: it is the largest surface and the
least testable headlessly, and everything under it should be proven first.

## Invariant to check at every step

A game where no target is named and no reorder happens produces the **same result** as
before this change. `RulesTest`'s full AI-vs-AI game is the cheapest check that this
holds.
