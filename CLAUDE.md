# Project — Godsfall

A turn-based deckbuilding card game. Two players, two boards, lanes of units, towers,
and a throne. Built in **Godot 4.7**.

**The Godot project lives in this same folder.** `project.godot`, `scenes/`, `scripts/`,
and `data/` sit alongside these design docs. The `.md` files remain the source of truth
for rules; the code implements them.

Genre DNA: Pokémon TCG (energy, evolution, 60-card decks), Artifact (lanes, towers),
Clash Royale (push/telegraph pressure), Magic (deckbuilding tension).

---

## Working Practices

### Self-instructions

- **Update these docs only when a change lands and Jonah confirms it works.** Ask first;
  don't rewrite the rules silently. The exception is the standing rule in *Keeping This
  Document Current* — a rule **decided in conversation** gets written down the same turn,
  because that's the reasoning being captured, not a claim about shipped code.
- **Record what isn't derivable from the code.** Design reasoning, rules decisions,
  invariants, and gotchas belong here. File lists, function inventories, scene trees, and
  test-name tables drift the moment the code moves — grep answers those faster and is
  never out of date.
- **Say what's actually verified.** "Harness passes" means it was run this session. If it
  wasn't, say so.

### Planning

Scale the ceremony to the work — most requests need none of this.

| Situation | What to do |
|---|---|
| A bug fix, a tuning number, a card's text | Just do it. |
| A new mechanic or card that touches the rules | Settle the design in conversation first, then build. `brainstorming` if the shape is genuinely open. |
| A multi-file engine change (a new card type, a new phase in turn resolution) | `writing-plans`, then execute. |
| A whole faction (Void, Gaia, Heaven) | `brainstorming` → `writing-plans` → execute. These are big and mostly-independent. |

**Rules before code, always.** This project's `.md` files are the source of truth and the
engine implements them. A mechanic that isn't settled in `CLAUDE.md` / `hel.md` /
`support.md` isn't ready to be written in GDScript — building first means the docs get
back-filled to match whatever the code happened to do, which is backwards.

Plans and specs go in `docs/plans/` and `docs/specs/` (overriding the skills' default
`docs/superpowers/` path). Neither directory exists yet; create it when the first one
is written.

### Subagents

Subagents have their own context, so the expensive part of the session — this file, the
faction files, the rules we've reasoned through — is not consumed by their work. Use them
when a task is **self-contained and verifiable on its own**, and hand them the rules text
they need rather than assuming they know it.

Good fits here:

- **Card authoring.** "Write the 12 Void cards from this spec into `data/cards.json`" is
  one agent, one file, one spec. `dispatching-parallel-agents` when several factions or
  card batches are independent.
- **Harness runs and failure triage.** Running the eight headless harnesses and reporting
  what broke is a search-and-report task.
- **Codebase questions.** "Where is tower damage applied?" → `Explore`, which reads
  excerpts instead of dumping whole files into this session.
- **Plan execution** with `subagent-driven-development`, once a plan exists and the tasks
  are independent.

Poor fits — keep these in the main session:

- **Balance and design decisions.** Tuning is Jonah's call, and the reasoning depends on
  the whole economy at once.
- **Anything editing this file.** The rules docs are the shared context; a subagent
  rewriting them defeats the point.
- **Small edits.** A fresh agent re-deriving context costs more than making the change.

Don't spawn agents unless the work actually warrants it — a task with several parts is not
by itself a reason to delegate.

### Skills

Skills are packaged instructions invoked with the `Skill` tool. They're installed
**globally** at `~/.claude/skills/`, not in this repo, so they're available in every
session here without any project setup. Invoke them — never `Read` the skill files.

**Use one when it fits the work in front of you**, and say which one you're using and why.
The table below is the set that's relevant to Godsfall; the full roster appears in the
session's skills listing.

| Skill | Use it when |
|---|---|
| `brainstorming` | A mechanic's shape is genuinely open and needs to be talked through before anything is written |
| `writing-plans` | A multi-file engine change is agreed and needs decomposing into steps |
| `executing-plans` | Working through a written plan in a fresh session |
| `subagent-driven-development` | Executing a plan in *this* session, one subagent per task |
| `dispatching-parallel-agents` | 2+ genuinely independent tasks — separate factions, unrelated harness failures |
| `systematic-debugging` | Any bug or harness failure, **before** proposing a fix |
| `test-driven-development` | Adding an engine rule — write the harness assertion first |
| `verification-before-completion` | Before claiming anything passes, is fixed, or is done |
| `verify` | Confirming a change works by actually running the game, not just the harnesses |
| `requesting-code-review` | A large engine change landed and wants a second pass |
| `receiving-code-review` | Acting on review feedback — verify claims, don't just comply |
| `skill-reflect` | End of a substantial session, to capture what was learned |
| `writing-skills` | Creating or editing a skill |

**Not applicable here**, despite being installed — don't reach for them:

- `using-git-worktrees` and `finishing-a-development-branch` assume a git repo. **This
  project is not one.** If it's ever `git init`-ed, both become useful and this line
  should be deleted.
- `frontend-design` is for web UI. Godsfall's UI is Godot scenes and `CardView`.
- The marketing skills (`copywriting`, `seo-audit`, `ads`, and the rest of that family)
  have nothing to do with this project.
- `stop-slop` is for prose. Card flavor text is the only plausible use, and it's a stretch.

**Scale to the work.** `using-superpowers` says to invoke a skill on even a 1% chance it
applies, and `brainstorming` declares a hard gate before any creative work. Read literally
that means a design session before every tuning tweak, which is wrong for this project —
so the planning table above governs instead. That override is legitimate: the skills'
own priority order puts this file above them, and Jonah's instructions above both. When
a skill and a rule in these docs conflict, **the docs win** — the skills are general
advice, these files are the game.

---

## The Core Idea

**Cards are free to play. Energy only buys attacks.**

Deployment is unconstrained — the constraint is *acting*. A board full of units you
can't afford to activate is decoration. Every turn is a triage problem: four units,
enough energy for one or two attacks, pick.

**Units are always free. A minority of support cards charge 1–3 energy** — the one
sanctioned exception, which exists so the same effect can be printed in a free restricted
version and a priced unrestricted one. See *Priced supports*. It stays an exception
because it's capped at 3, never applies to units, and never competes with attacks on
damage per energy.

Energy lives in two places, each with its own danger:

| Location | Risk | Safe from |
|---|---|---|
| **Pool** | Decays 20% at end of turn | Unit death |
| **Attached to a unit** | Lost entirely when the unit dies | Decay |

That two-sided risk is the game's central skill expression. Committing energy to a unit
protects it from decay but stakes it on that unit's survival.

---

## Board Geometry

Each player has **2 boards**. Each board has:

- **1 lane, 3 slots wide**
- **1 tower**, which occupies one of the lane's slots until it dies

So while towers live: **2 usable unit slots per board = 4 total.**
When both towers die: **3 slots per board = 6 total.**

```
              ENEMY THRONE (100 HP)
   ┌─────────────────────┐  ┌─────────────────────┐
   │  [ 1 ][ 2 ][TOWER]  │  │  [ 1 ][ 2 ][TOWER]  │   enemy boards
   └─────────────────────┘  └─────────────────────┘
   ┌─────────────────────┐  ┌─────────────────────┐
   │  [ 1 ][ 2 ][TOWER]  │  │  [ 1 ][ 2 ][TOWER]  │   your boards
   └─────────────────────┘  └─────────────────────┘
              YOUR THRONE (100 HP)
```

### Targeting

**Units shield the structures behind them.** As long as anything is alive on a board,
attacks against that board can only hit units — never the tower, never the throne.

**Shielding is per-board, and never crosses boards.** Each board is its own lane, and an
attack resolves entirely within the board it faces. Units on your *other* board defend
nothing here: if the board being attacked has no living units, its tower is exposed no
matter how crowded the board beside it is. Two boards, two independent fights.

**An attack may name any living unit on the board it faces.** Targeting is a choice, not
a consequence of placement — see *Chosen targets* below. When no target is named, or when
the named one is already dead, the attack resolves through the fallback chain.

Resolve a lane attack against enemy board `B` in this order:

1. **The named target**, if the attacker chose one and it is still alive on `B`.
2. **The unit in the slot directly across**, if one is there and alive.
3. Otherwise, if **any** unit on `B` is alive — the **leftmost** living one.
4. Otherwise, `B`'s **tower**.
5. Otherwise, the **throne**.

- **Facing is the default, not the decision.** An attack with no named target hits the
  slot across, so placement still governs the common case and still decides what a stale
  pick falls back to. It is no longer the *only* lever.
- **Only living units may be named.** The tower and throne can never be chosen while
  anything on that board lives — choosing a target does not choose past the shield.
- The fallback is **deterministic — leftmost, always.** No choice, no prompt. Once the
  player's pick is gone, the engine doesn't ask for another.
- **Slots do not compact.** A dead unit still leaves a permanent hole, but the hole no
  longer funnels damage to the tower while the board holds anything else. What a hole
  costs you now is *concentration*: attacks that would have been spread across three
  bodies all pile onto whatever is left.
- **Clearing a board is what opens it.** A board is only reachable past its units once
  every unit on it is dead — including units that died earlier in this same resolution.
- **All lane damage follows this chain, not just attacks.** `Decay` uses it too, so a
  Decay board can't chip a throne past a wall. The one exception is a card that *prints*
  an exception — a rider like "also hits the tower" is the card explicitly breaking the
  rule, which is design principle #1 working as intended.

### No overkill

**Once a unit dies, no further attack in that resolution may hit it.** A later attack
aimed at a dead unit's slot re-resolves through the chain above from the top — so it
redirects to another living unit, and only reaches the tower once the board is clear.

Damage is never wasted on a corpse, and it's never banked either: the excess from an
overkill doesn't carry to the next target, it simply doesn't happen. The attack retargets
whole.

**This makes intra-turn ordering matter more, not less.** A kill by an early attack
changes what every later attack on that board hits. Sequencing a volley so the kills land
first is the way to reach a tower in one turn: clear the board, then everything remaining
falls through.

### Chosen targets

**When you queue an attack you may name which living enemy unit it hits.** The pick is
recorded on the queued attack and used at step 1 of the chain above.

- **Only living units on the board the attacker faces.** Never the tower, never the
  throne, never the other board. Shielding and the per-board rule are both untouched:
  choosing a target picks *among* the wall, never past it.
- **Naming a target is optional.** An attack queued without one hits the slot across, as
  it always did. Every existing card, deck, and line of play behaves identically if you
  never use the feature.
- **Legality is checked when the attack resolves, not when it is queued.** A named target
  that died earlier in the volley is simply gone, and the attack falls through to the slot
  across, then the leftmost survivor. The pick is a *preference*, not a reservation.
- **Aiming at a unit something else might kill is always safe.** The attack is never
  wasted and never fizzles — it moves on to the next target down the chain.

**The stale pick falls into the normal chain — it does not slide sideways.** This is the
one detail worth stating outright, because "moves on to the next unit" has two readings.
A dead named target reverts the attack to an ordinary untargeted one: slot across first,
then leftmost survivor. It does **not** hunt for the nearest living body to the unit you
pointed at.

```
You aim slot 0's attack at the enemy's slot 2, and slot 2 dies earlier in the volley.

  enemy board:  [ A ][ B ][ X ]        X = your named target, already dead
                  ^
                  └── the attack hits A — the slot across from the attacker,
                      NOT B, which merely happens to be next to your dead pick.
```

Sliding to the neighbour would be a second targeting rule that exists only for the stale
case, and it would quietly make a doomed pick into a soft commitment to that side of the
board. Reverting to the default keeps one chain for every attack in the game.

**Why resolution-time and not queue-time.** The whole reason to sequence a volley is that
early attacks kill things, so a pick made during the main phase is routinely stale by the
time it resolves. Validating at queue time would mean either forbidding the sequences
worth building — you could not aim attack #3 at a unit while attack #1 might kill it — or
re-prompting on every death mid-resolution, which turns one decision into a chain of
interruptions. Falling back through the existing chain costs nothing and never surprises:
the fallback is the behaviour the game already had.

**What this changes about placement.** Placement is no longer the only targeting lever. It
still sets the default, still decides what a stale pick falls back to, and still governs
which of your units eats the tower shot — so where you deploy still matters. But the
sentence "placement *is* targeting" is no longer true, and the rules that leaned on it
(notably the ban on free drag-to-rearrange) now stand on their own reasoning instead.

### Volley ordering

**You choose the order your queued attacks resolve in.** The volley is an ordered list,
not a board scan.

- The **default order is left to right, board by board** — the order attacks were always
  resolved in, so a player who never touches the ordering sees no change.
- Reordering is free and can be done any time during your main phase, up until you end
  the turn.
- Ordering is **per player, across both boards.** You may interleave the two boards
  freely; each attack still resolves only against the board its unit faces.

**This is the feature that makes `Judgment` play the way the keyword reads.** A Judgment
unit executes anything it leaves at or below N, so it wants to swing *after* something
has softened the target — and before ordering existed, whether that happened was an
accident of which slot the two units occupied. Now it is a decision: put the heavy hitter
first, the Judgment body second, and the execute is a plan rather than a coincidence.

It also gives the no-overkill rule something to bite on. Clearing a board to reach the
tower requires the kills to land first, and now you can arrange that directly instead of
deploying units in kill order several turns in advance.

### Combat

- Attacks are **one-directional**, like Pokémon. The defender does not strike back
  unless a card says so (e.g. Hel's `Retribution`).
- Units **persist between turns**. They are not exhausted by attacking.
- Dead units go to the **discard pile**, and their attached energy is lost.

---

## Retreat

**Retreat pulls a unit off the board and back into your hand.** It is not Pokémon's
switch — there is no bench, and nothing takes the retreating unit's place.

Every unit card has a printed **Retreat cost**.

### How it resolves

1. Pay the retreat cost **from the unit's own attached energy**. Retreat cannot be paid
   from the pool, and it cannot be paid by another unit.
2. The paid energy is **spent** — gone, not banked.
3. **Leftover attached energy returns to your pool.** This is the only way attached
   energy ever comes back off a unit without the unit dying.
4. The card returns to your **hand**, healed to full, and **locked for one turn** — it
   cannot be played again until your next turn.
5. The slot it left is now **empty**, and does not compact.

If a unit's attached energy is less than its retreat cost, **it cannot retreat.** An
uncharged unit is stuck on the board.

### Evolved units

A retreating Stage 1 or Stage 2 brings its **whole evolution path** back to hand — the
Basic, the Stage 1, and the Stage 2, as separate cards. All of them are locked for the
turn. You rebuild the line from the bottom, one stage at a time.

This is deliberately generous, and it's fine: **saving a unit doesn't win the game, it
removes a shield.** The board is your only defense, and retreating thins it — the
remaining units absorb everything that would have been spread across the lane, so they
die faster, and clearing that board is what exposes your tower. The rebuild also costs
you turns you weren't spending on offense. Getting the cards back is not the same as
getting the board back.

Shielding makes retreat *safer than it used to be* — a single hole no longer opens a
path to your tower — but it also makes the last unit on a board the one holding the
whole lane up. Retreating that one is what breaks it open.

It's also self-limiting against the **hand limit**: retreating a Stage 2 puts three cards
into your hand at once, none of which you may play this turn. Near the 10-card ceiling
that's a real cost, which is what stops repeated bouncing from being free.

### Retreat does not trigger death effects

A retreated unit did not die. It does not `Toll`, it does not `Rise`, and it does not
go to the discard. **Retreat is the alternative to dying** — Hel can either feed a unit
to the tower for the refund, or pull it out and keep the card. Never both.

### Retreat cost formula

**`Retreat = HP ÷ 40`, rounded down.**

| HP | Retreat |
|---|---|
| 40–79 | 1 |
| 80–119 | 2 |
| 120–159 | 3 |
| 160+ | 4 |

Big bodies are still harder to extract, but the curve is shallow enough that retreat stays
a live option at every stage. That's the point: at `÷ 25` a Stage 2 needed 4 attached
energy before it could leave at all, which made retreat a Basics-only action in practice.

Like `Toll`, this is a **design-time anchor printed on the card**. It never recalculates
in play: buffs, debuffs, and damage never move it, and a damaged 150 HP unit still costs 3
to retreat. Evolution changes it, because the evolved card prints its own number.

**Retreat and Toll deliberately use different divisors** — retreat `÷ 40`, Toll `÷ 25`.
They used to share `÷ 25` so a card carried one derived number instead of two, but the
shared value made big bodies unretreatable at exactly the moment retreat mattered most.

Splitting them is not just damage control; it creates the better decision. Because
`÷ 40 < ÷ 25`, **retreat is systematically cheaper than the Toll refund** on the same body
— a 100 HP unit is worth 4 if it dies and costs 2 to save. Saving a unit is now the
*affordable* line and feeding it to the discard is the *deliberate* one, so a Hel player
choosing the refund is making a real choice rather than discovering that extraction was
never priced for them. The card still shows both numbers side by side; they simply no
longer have to be equal.

Individual cards may still deviate a point in either direction for identity reasons — see
`hel.md` for the Retribution walls, which are priced up so they can't cheaply abandon the
lane they exist to hold.

---

## Support

**Support cards are a third card type**, alongside units and energy. They are one-shot
effects: play, resolve, discard.

- **Usually free to play**, like units. A minority cost **1–3 pool energy** — see
  *Priced supports* below.
- **No per-turn limit.** Play as many as you can afford to draw — and, for the priced
  ones, as many as the pool covers.
- **No item/supporter split.** Pokémon's distinction exists to gate the strong ones
  behind a once-per-turn clock; here the answer is simply to not print cards that need
  gating. Every support card is tuned to roughly the same power level.

The design constraint that replaces the play limit: **hand size is the cost.** A support
card is a card you drew instead of a unit, in a game where you draw one per turn. Playing
four supports in a turn means you spent four draws to do it.

### The support power band

Support cards sit at **roughly one turn of tempo** — comparable to a 2-cost attack, a
turn of energy income, or a couple of extra draws. Nothing in the band should win a game
on its own; supports smooth out the two spend-or-save decisions rather than resolve them.

Concretely, a support card may do about one of these:

| Effect class | Band |
|---|---|
| Draw | ~3 cards, or 2 with a filter |
| Search — Basic unit | 1–2, chosen |
| Search — evolved unit | 1, random from the deck |
| Search — any card | 1, chosen, delayed a turn |
| Recursion — discard | 1, random |
| Pool energy | +2 to +3, or a conditional +4 |
| Retreat modification | Reduce a retreat cost by 1–2, or refund it |
| Direct damage | ~20, or ~25 with a condition |
| Board manipulation | Move a unit, move attached energy |
| Healing | 20 HP is the baseline; ~10 to the whole board, or 50 with a condition |
| Tool (per turn) | ~1/3 of the one-shot equivalent |
| Tower support | +20 max HP, +5 tower damage, or a 25 HP repair |

Supports must **not** hand out raw damage efficiently enough to compete with attacks —
that's the one line to hold. A support that deals 25 damage for free would make the
energy economy optional, so the ones that deal damage are priced with conditions,
discards, or self-inflicted costs.

### Priced supports

**Most supports are free. Some cost energy from the pool, at most 3.**

This is a deliberate exception to *energy only buys attacks* — design principle #1 in
action — and it is bounded so that it doesn't swallow the rule it breaks:

- **The cost is paid from the pool, not from a unit.** Attached energy is a unit's
  investment; a support isn't a body and has nothing to attach to. Paying from the pool
  also means a priced support competes directly with queueing an attack that turn, which
  is the tension the cost exists to create.
- **Cost is 0–3.** Zero is the default and stays the overwhelming majority. 1 is the
  common price, 2 is notable, and **3 is reserved for the genuinely powerful** — a card
  worth about two turns of tempo instead of one.
- **A priced support may exceed the power band**, roughly one extra band step per energy.
  That's the whole point: the band exists because free cards have to be capped, and a card
  that charges has bought room above it.
- **No priced Tools or priced tower support**, for now. Both are already discounted for
  paying out over time or for being self-limiting, and pricing them stacks two balance
  mechanisms on one card. If a priced Tool ever gets printed it should be an upgraded
  variant of a free one, same as everything below.
- **If you can't pay, you can't play it.** A priced support with an unaffordable cost is
  simply illegal, like an attack you can't afford — it isn't discounted or partially paid.

**Why this earns its exception: it makes variants possible.** The reason to add cost at
all is that it's the cleanest axis for printing **two versions of the same card** —

| Free | Priced |
|---|---|
| `Shore Up` — heal 20 | `Field Surgery` — *heal 50*, for 1 **(built)** |
| `Field Rites` — heal 10 to all | `Closing Ranks` — *heal 20 to all*, for 2 **(built)** |
| `Collapse` — 20 damage to an **uncharged** unit | *20 damage to any unit*, for 2 |
| `Muster` — search a Basic | *search any unit*, for 1 |
| `Offering` — +3 pool energy | — energy-for-energy is never a variant |

The free one is a floor every deck can run; the priced one is the same effect without its
restriction, and the restriction it drops is what sets the price. That's a real
deckbuilding decision — the cheap version is always castable, the expensive one is better
when you have the pool — and it gives the file a way to grow that isn't just more effects.

Two guards on the pattern:

- **The free version is the baseline, and it must stay playable.** A priced variant that
  makes its free counterpart obsolete has failed; they should trade off, not rank.
- **Energy-for-energy is never a variant.** A support that costs 2 to gain 4 is a worse
  energy card with extra steps, and it breaks the one-energy-per-turn rule sideways.
  Priced supports buy *effects*, never pool energy.

**The healing class sets the reference rate.** Healing was the first class given priced
cards, and its ladder is the worked example the others should follow: **a 20 HP baseline,
and each energy buys about 30 more** (`Shore Up` 20 free → `Field Surgery` 50 for 1 →
`Grave Warden's Oath` 100 for 3). A free card may reach the same +30 by taking a condition
instead of a cost, which is what `Last Breath` does.

**No card fully heals a unit, at any price.** Every heal is a flat number — never "restore
to max," never a percentage of printed HP. A heal that scales with its target can't be
priced: the identical card is worth 20 on a Basic and 110 on the Queen, and it silently
gets stronger every time a bigger body is printed. Flat numbers also make the big heals
**overflow and waste** on small units, which is what keeps `Grave Warden's Oath` from
being a strict upgrade over `Shore Up` rather than a different choice. Enforced by a test
in `SupportTest.gd`, not by convention.

The line that does **not** move: a priced support still may not sell damage at attack
rates. `12 damage per energy` is what an attack buys, and an attack's cost stays attached
and pays out every turn after — a support's cost is spent for good. So a support's damage
per energy must sit visibly *below* the attack curve, and the priced damage variants above
buy the removal of a *condition*, not raw points.

### Tools

**A Tool is a support card that attaches to a unit and stays.** It's the one exception to
"play, resolve, discard" — a Tool is a permanent modification to a body.

- **One Tool per unit.** A unit already holding a Tool cannot receive another.
- Tools are **free to attach**, like everything else that isn't an attack.
- A Tool **stays through evolution**, the same way attached energy does.
- When the unit **dies, the Tool goes to the discard with it.**
- When the unit **retreats, the Tool goes to the discard.** It does not return to hand
  with the unit. Retreat saves the body, not the equipment.
- A Tool may be attached to a unit that already has energy on it, and vice versa. Tools
  and energy are tracked separately.

Tools are priced **below** one-shot supports, because they pay out every turn instead of
once. A one-shot heals 20; a Tool heals 5 per turn and eventually beats it, so the Tool
does less per instance. The rule of thumb is that a Tool should take **three to four
turns to match** what a one-shot support does immediately.

That delay is the whole balance mechanism, and it's enforced by the board: a Tool only
pays out while its unit is alive, and units die constantly. **Tools are a bet on a unit
surviving** — which makes them a natural fit for walls, and a trap on chaff.

See `support.md` for the neutral card list, including Tools.

---

## Setup

Before round 1, in order:

1. Both players draw an opening hand of **6**, guaranteed to contain a Basic unit.
2. Each player may **mulligan** once — see *The mulligan*.
3. **Both players deploy Basics.** Any number, from hand, into empty slots on either
   board. Nothing else happens: no energy, no supports, no evolution, no attacks.
4. Round 1 begins. Towers are silent through it.

**Deployment is simultaneous and hidden in principle, sequential in practice.** Neither
player's setup deployment reacts to the other's — the AI commits its board without seeing
yours. That matters because placement decides facing, and a setup phase where the second
player could counter-place would hand them the whole targeting geometry for free.

**Why setup exists.** Without it the first turn is spent doing the one thing every deck
does identically — putting a Basic down — while P1 additionally presents a board to a
tower that P2 does not yet face. It removes a turn of pure ceremony and it removes the
asymmetry, at the cost of nothing: the cards deployed are the same cards, played a turn
earlier, by both players.

**It is deployment only, and Basics only.** Allowing energy would mean the first energy
card is worth `t + 1 = 1` instead of 2, quietly changing the income curve; allowing
supports would let a draw spell run before anyone has a board to affect. Restricting to
Basics is not a special rule — Stage 1s and 2s are unplayable at setup anyway, since
nothing is on the board to evolve.

---

## Turn Structure

1. **Draw** (see Draw & Hand below)
2. **Main phase** — in any order, any number of times:
   - Play unit cards (free, no cost)
   - Evolve units
   - Play **one** energy card (see Energy)
   - Play **any number** of support cards, paying any printed energy cost from the
     pool (see Support)
   - **Charge** — move energy from pool onto a unit (free action, no limit)
   - **Retreat** a unit (see Retreat)
   - **Queue attacks** — click an attack on a unit that has the required energy attached,
     optionally naming a living enemy unit as its target
   - **Reorder the volley** — rearrange queued attacks into any resolution order
   - Activate unit **abilities** (free, immediate, once per turn each)
3. **End of turn resolution**, in this order:
   1. Queued attacks resolve **in the player's chosen order** (default: left to right,
      board by board)
   2. End-of-turn effects trigger (`Decay`, Tools, etc.)
   3. Towers fire at the opposing board — full damage to a unit, a quarter to the
      structures behind it if that board is clear. **Towers do not fire in round 1.**
   4. Towers and thrones gain **+5 max HP**, **once per round** — at the end of the
      second player's turn, when the round is complete
   5. **Pool decays 20%** (minimum 1, rounded down)
   6. **Discard down to 10 cards** if over the hand limit

Because a defender that dies leaves an empty slot, a later attack in the same resolution
retargets — onto the leftmost surviving unit on that board, or past it to the tower once
the board is clear. Volley order is therefore a real decision: which kills land first
decides what everything after them hits, and it is what lets a Judgment unit swing into a
target something else already softened.

### Attack lock

**A locked unit automatically re-queues the attack it used last turn**, at the start of
your turn, right after the draw. This is a **convenience, not a rule**: it only ever
queues an attack you could have queued by hand, it pays the same cost through the same
path, and anything it queues can still be cancelled before end of turn.

It exists because a charged unit with one good attack ends up re-clicked every turn for
the rest of the game, and that clicking is not the interesting decision. The interesting
decision is where energy goes; the lock clears the repetitive part out of the way of it.

- A **global toggle** locks every unit at once.
- **Individual units override it**, in both directions. A unit you explicitly unlock stays
  unlocked when the global lock is on, and vice versa. This is why the per-unit setting is
  three-state (*follow global* / *always* / *never*) rather than a checkbox.
- A locked unit whose attack is **no longer affordable is skipped silently**. The lock
  never spends pool energy beyond the attack's own printed cost.
- **Evolving retires the remembered attack** — it belonged to the previous printed card.
  The unit's lock *setting* is kept, since that's the player's stated preference, but
  nothing re-fires until you pick an attack on the new body.

**Abilities are never auto-used.** They resolve immediately and some destroy attached
energy, so auto-firing one could burn an investment you were holding on purpose.
Abilities stay a manual decision — which is the same reasoning that makes them free.

### Damage resolution order

Attacks resolve **in the player's chosen volley order**, defaulting to left to right,
board by board. The table below is the order *within* a single attack. **Each attack
resolves fully, start to finish, before the next begins.**

| # | Step |
|---|---|
| 1 | **Select target** — named target → slot across → leftmost living → tower → throne. Dead units are skipped, including a named one that died earlier in the volley. |
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

---

## Energy

### Income

- Energy cards are **built into the deck**. The player chooses how many.
- **One energy card may be played per turn** (barring cards that break this rule).
- An energy card played on turn `t` adds **`t + 1` energy** of its color to the pool.
  Turn 1 → 2 energy. Turn 5 → 6 energy. Turn 9 → 10 energy.
- Energy cards **do not count** toward the 4-copy limit.

The value scales with the turn, so **holding an energy card in hand makes it worth
more**. But one-per-turn means a skipped energy play can never be made up. That is the
first of the two spend-or-save decisions.

### The Pool

- The pool is **persistent** — it carries across turns, it does not refresh.
- At end of turn the pool **decays 20%, minimum 1, rounded down**.
  - 10 in pool → lose 2. 15 → lose 3. 4 → lose 1.
- Decay stabilizes the pool around `5 × (t + 1)`, so banking is possible but taxed.

### Attaching

- **Charging** moves energy from the pool onto a unit. It's a free action, unlimited
  per turn.
- Attached energy is **permanent**. It survives attacking, it survives across turns,
  and it **carries through evolution**.
- Attached energy is **immune to decay**.
- Attached energy is **lost when the unit dies**.
- Queueing an attack pulls exactly the attack's cost from the pool onto the unit —
  no overpayment, no waste. A 1-cost attack takes 1, even from a 20-energy pool.

Once a unit has enough energy attached, it can use that attack **every turn for free**.
The payment is one-time. Attached energy also **accumulates toward larger attacks** on
the same unit — this is how a 20-cost attack becomes reachable.

### Consume

Some lines require **Consume N** — they destroy N attached energy on activation
rather than merely requiring it. Consume attacks are priced on a separate, steeper
curve because they burn the investment.

Consume is a mechanic **all factions have access to**, tuned to each faction's identity.

**Consume may appear on either an attack or an ability**, and it is the *only* cost an
ability may carry (see Abilities are free). On an ability it is the whole price, which is
what stops a free once-per-turn effect from being a permanent no-cost engine: the unit has
to be re-charged to keep using it.

---

## Damage Formulas

These are **working anchors for playtesting**, not final numbers.

| Attack type | Formula | Rationale |
|---|---|---|
| **Standard attack** | `≈ 12 damage per energy` | One-time cost, pays out every turn — priced as an annuity |
| **Consume attack** | `≈ 20 damage per energy consumed` | Destroys the investment, so it pays ~1.7× up front |

Linear, not superlinear. Big attacks are not more efficient per point — they're
*better because the board caps at 4 units*, so concentrated damage is worth more than
its raw total.

Reference breakpoints against a 50 HP basic unit:

| Cost | Standard dmg | Meaning |
|---|---|---|
| 1 | 12 | Chip. 5 hits to kill. |
| 2 | 25 | Half a unit. |
| 3 | 38 | Threatens a kill with chip support. |
| 4 | 50 | **Exactly kills a fresh basic.** |
| 5 | 65 | Kills through buffs. |

Costs may include **colorless** requirements, payable with any color. Multi-faction
units cost more total energy but get access to **stronger effects** — never higher raw
damage. Multi-faction should be common and manageable, not strictly superior.

---

## Shared Keywords

These belong to the whole game. Faction files list only their signatures.

| Keyword | Effect |
|---|---|
| **Rise** | When this dies, return it to an empty slot on your side at the start of your next turn, at **half HP** and **without Rise**. Every other ability, attack, and keyword returns intact — at their **printed** values. Attached energy is not restored, and neither is any stat the card had *grown* in play (notably Gaia's `Earth`). Rise restores the card, not the history. |
| **Retribution N** | When this unit takes damage from an attack, deal N damage back to the attacker. |
| **Consume N** | This line destroys N attached energy on activation. Priced at ≈20 damage per energy consumed. May appear on an attack or an ability; on an ability it is the only cost permitted. |
| **Judgment N** | One charge, spent by either use. **Defensive:** when this unit would die, it instead survives at N HP. **Offensive:** when this unit attacks and leaves the defender at N HP or below, that defender is destroyed. Returns only if the card returns to hand. |
| **Sanctuary / Sanctuary N** | Plain **Sanctuary** absorbs the next instance of damage entirely, from any source, then is spent. **Sanctuary N** is a pool of N that damage depletes; when the pool is exhausted it becomes plain Sanctuary for one final full absorb, then is spent. |
| **Windfury** | This unit may attack twice per turn. |
| **Resist X** | Reduce each incoming instance of damage by X, to a **minimum of 1 damage**. |

### The Gap

**The Gap is a global board state, not a keyword** — a number both players can read at any
time, like the round counter. It exists because Void reads it; it is defined here because it
is a property of the *board*, not of a card.

> **Gap** = your total attached energy − the opponent's total attached energy, floored at 0.

Each player has their own Gap, and they are not symmetric: if you hold 10 attached and the
opponent holds 4, your Gap is 6 and theirs is 0.

Three rules that matter:

- **It counts attached energy only.** Pool energy is invisible to it. That is what makes the
  Gap a measure of *commitment* rather than of wealth — energy sitting safely in a pool has
  not been staked on anything.
- **It counts living units only.** Within a volley a unit marked dead remains on the board so
  it can still deal `Retribution`, but its attached energy is already forfeit — counting it
  would let a corpse inflate the Gap for the rest of the resolution.
- **It floors at 0.** Cards that read the Gap only ever promise a bonus, so a negative value
  would silently become a penalty on a card whose text never mentioned one.

See `void.md` for `Rift N`, the stat that reads it.

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
is the correct shape. Units without Judgment keep the standard curve, which is why
Heaven's biggest attacks sit on Sanctuary bodies rather than Judgment ones.

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
resistant to chip *and* resistant to burst, and neither the Hel matchup nor the big-attack
matchup has a degenerate line.

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

---

## Units

### Stats

| Stage | Base HP |
|---|---|
| Basic | **40–90** |
| Stage 1 | **80–120** |
| Stage 2 | **110–175** |

HP varies with the card's power budget. These are **bands, not targets** — a card sits
where its power budget puts it, and the extremes are deliberate (a 40 HP Basic is chaff, a
90 HP Basic like `Charnel Colossus` is paying for its size elsewhere).

**The whole curve was raised on 2026-08-08**, across every faction, from `Basic ~50 /
Stage 1 ~70 / Stage 2 ~90–110`. At the old numbers a 4-energy attack dealt 50 and a
5-energy attack dealt 65, so **two attacks killed almost anything at any stage** — the top
of an evolution line died about as fast as the Basic under it. That made evolving read as
a marginal upgrade and made every combat resolve in a single exchange. Bigger bodies mean
reaching a kill takes a real volley, so boards persist across turns and there is something
to interact with.

The bands now overlap deliberately at the edges (a 90 HP Basic and an 80 HP Stage 1). That
is fine: stage is not a power ranking on its own, and a Basic that big has paid for it in
attack cost or text.

Three consequences worth tracking rather than assuming:

- **The damage anchors did not move.** `4 energy = 50 damage` still holds, but it no
  longer exactly kills a fresh Basic — the reference breakpoint table below is now a
  statement about damage, not about lethality. Whether the anchors should rise to match is
  open.
- **Derived values moved with the HP.** `Toll` (`HP ÷ 25`) and retreat (`HP ÷ 40`) are
  computed from the stat line, so raising HP raised both. `Nithogg Ascendant` went to
  Toll 6, the largest refund in the game.
- **This may not do what it was partly intended to do.** One motivation was reining in
  Heaven, but Heaven's strength is stacked reprieves (`Judgment`, `Sanctuary`, `Rise`),
  and all three get *better* on a bigger body — a Judgment survival on a 145 HP frame is
  harder to finish off than on a 110. See Open Questions.

### The Two-Line Rule

**Every unit has at most two lines.** Either:

- **One passive ability + one attack**, or
- **Two attacks**

This is a hard structural constraint. It forces every card to commit to an identity
instead of accumulating text.

Multiple keywords on a single ability line (e.g. `Toll 2, Decay 5`) count as one line.

### Abilities vs. Attacks

- **Attacks** are queued during the main phase and resolve at end of turn. They cost
  attached energy and deal damage.
- **Abilities** are passives (auras, triggers) or activated effects usable at any time
  during your main phase. Costs that are *not* damage — sacrificing a unit, moving
  energy, drawing — belong on ability lines, not buried inside attacks.
- **Activated abilities are once per turn**, per unit. This is a global rule, not a
  per-card clause.

### Abilities are free

**An activated ability never costs pool energy.** Energy only buys attacks — that is the
core rule, and an ability is not an attack. An ability resolves the moment you use it
rather than at end of turn, and it takes nothing from the pool.

**The one exception is `Consume N`**, which destroys N *attached* energy on activation.
Consume is not a payment into the pool and not a requirement that stays on the unit: it
burns an investment already committed to that body. An ability may carry a Consume; it may
carry nothing else.

| | Attack | Ability |
|---|---|---|
| When it resolves | End of turn | Immediately |
| Cost source | Pool → attached | Nothing, or attached energy destroyed by `Consume` |
| Cost after the first use | Free — the energy stays attached | Free, unless it Consumes every time |
| Limit | One queued attack per unit | Once per turn, per unit |

This is why the two are worth separating at all. An attack's cost is an *annuity* — you
pay once and the attack is free every turn after. A Consume is the opposite: it charges
every single time, which is what lets Consume abilities be strong without becoming
permanent engines. A free ability is priced by the once-per-turn limit alone.

The distinction is enforced in the data, not by convention: a line marked `"ability": true`
has its `cost` block ignored outright, so a card cannot accidentally price an ability by
filling in the wrong field. The only cost that reads is `"consume": N`.

### Evolution

- Evolving is **free** (cards are free to play).
- Evolution **carries attached energy forward**. This is mandatory — without it, no
  Stage 2 could ever be charged.
- Evolutions should be **thematically and mechanically related** to their prior form.
- Evolution is a pure board-quality upgrade that raises your energy demands.

---

## Towers & Throne

| | HP | Per round |
|---|---|---|
| **Tower** (one per board, 2 total) | 50 | +5 max HP; deals damage to the unit in front |
| **Throne** | 100 | +5 max HP |

**Growth is per round, not per turn.** Structures gain their +5 once both players have
acted, not at the end of each player's turn. This was a real bug rather than a tuning
change: growth fired inside `end_turn()`, which runs twice a round, so thrones and towers
were actually gaining **+10 a round** while every document and every balance note in this
file assumed +5. It is the single largest contributor to the throne outgrowing the damage
available — the formal stall in Open Questions — and halving it is the cheapest of the
dials named there.

- **Towers are silent for the first round.** They deal **0 damage** while round 1 is
  being played and do not grow. A tower's first shot is **5 damage from a 55 HP tower**,
  at the end of round 2, and it climbs **+3 a round** after that.
- Towers hit **units at full damage**, and **structures at half** — see *Towers against
  an empty board* below.

| Round | 1 | 2 | 3 | 4 | 5 | 8 | 12 | 20 |
|---|---|---|---|---|---|---|---|---|
| **Tower damage** | 0 | 5 | 8 | 11 | 14 | 23 | 35 | 59 |
| **Against a structure** | 0 | 2 | 4 | 5 | 7 | 11 | 17 | 29 |

The formula is `5 + 3 × (round − 2)`, floored at 0 before round 2.

**Why +3 rather than +5.** At +5 the tower one-shot any Basic by round 8 and any Stage 2
by round 14, which made the late game a structure race the units could not participate in
— the tower stopped being pressure and became the entire board. At +3 it still outgrows
any single body eventually (that is the forced tempo the tower exists to create), but it
takes until round 20 to threaten a large Stage 2 in one shot, which leaves the midgame to
the cards.

**Why the grace round.** Both players open with an empty board and one draw. Under the
old `5 × round` schedule a tower fired at the end of the very first turn, before either
player had deployed anything and while the quarter-rate rule had a completely empty board
to chip — so the game's first action was structural chip damage nobody could answer, and
P1 in particular ate a shot with nothing on the table. A round of grace costs the tower
race almost nothing (it is 5 damage, once) and buys every deck a turn to put a body down,
which is what makes the tower an *attrition* engine rather than an opening move.

It also makes the tower's own number legible: the first tower shot is 5 from a 55 HP
tower, so the tower has visibly taken one round of growth before it does anything.
- Towers occupy a lane slot. Killing your opponent's tower opens that slot for *them*
  — but exposes their throne. **You may strategically sacrifice your own tower for
  board space.**
- Losing a tower exposes the throne on that board. **Losing the throne loses the game.**

Towers are an **attrition engine**, not a wall. Every turn you don't answer a tower, it
eats another unit. The early game is forced tempo: break through, or struggle with both
the tower and their board later.

Energy income vastly outpaces tower scaling (energy grows off a small base at 25–50%
per turn; towers grow 10% and diminishing), so the tower race is winnable by design.

### Towers against an empty board

**A tower whose facing board holds no living unit fires at that board's structures for
half of its damage**, rounded down, minimum 1.

It follows the same chain every other damage source uses — the board's tower first, the
throne only once that tower is dead:

| The board the tower faces | Tower hits | For |
|---|---|---|
| Any living unit | the leftmost living unit | **full** damage |
| No units, tower alive | that board's **tower** | **½**, floor, min 1 |
| No units, tower dead | the **throne** | **½**, floor, min 1 |

- **The half rate applies to the tower's total damage**, including `Murder Holes`
  bonuses, and it is computed after the bonus rather than before.
- **Crossfire chips too.** `Murder Holes`' crossfire follows the identical chain against
  the *other* enemy board — full to a living unit there, half to its structures if it is
  clear. This is the one place the old "crossfire is unit-only" restriction was loosened,
  and it is loosened by the same rule rather than by a special case.
- **Shielding is untouched.** A single living unit anywhere on the board absorbs the shot
  at full damage and the structures behind it take nothing. Clearing a board is still what
  exposes what is behind it.

**Why half and not full.** A tower that hit structures at full rate would be the
degenerate case the original rule was written to prevent: two structures racing each other
with no way for either player to interact. Halving keeps tower fire a *unit* weapon whose
reach past an empty board is real pressure rather than a kill — at the round-8 tower it is
11 a turn into a structure, against a throne growing +5 a round, so an abandoned board
loses ground steadily without the tower ever becoming a clock a player wins on alone.

**This was a quarter until 2026-08-09, and the raise is paired with two changes that cut
the other way.** The quarter was chosen against `5 × round` scaling and `+10`-a-round
structure growth; with tower damage now on the shallower `+3` curve and growth corrected
to `+5` a round, a quarter would have left an empty board taking almost nothing (2 a round
at round 4) while the structure behind it grew faster than the chip. Half against the
slower curve lands close to where the quarter against the fast one did in the midgame, and
is far less punishing late. The three numbers were tuned as a set and should be read as
one.

**Why it exists at all.** The throne grew +5 max HP every turn unconditionally while an
empty board was completely safe from the tower facing it, so a player with no units on a
board took *zero* pressure there. Combined with unit shielding, that is the shape of the
stall documented in Open Questions: past some round neither side could reach the other's
structures, and the throne outgrew the damage available. This makes an empty board cost
something, which is the cheapest of the three dials named there and the only one that
touches no card and no anchor.

**This is the exception to "towers cannot threaten the throne."** That line was the hard
constraint on tower *support*, and it still is — see below. What changed is that the
constraint is now about **rate**, not about reach.

### Tower Support

**Tower support cards modify a tower you control.** They are support cards — free, no
per-turn limit, 4-copy max — with one added restriction and one added payoff.

- **A tower support card must name a tower you control**, and does nothing if both your
  towers are dead.
- **Permanent tower supports stack without limit.** A tower may hold any number of
  lasting modifications, including repeated copies of the same card, and their effects
  add together — two `Reinforced Base` is +40 max HP, two `Murder Holes` is +10 damage.
  One-shot tower supports (repair, a single burst of damage) attach nothing at all.
  This is deliberately unlike Tools on units, which stay one-per-body: a Tool rides a
  unit that dies constantly, while a tower is a fixed thing you choose to invest in, and
  the interesting decision there is *how much*, not *whether*. The 4-copy deck limit is
  the only bound.
- **Tower modifications are lost when the tower dies.** They do not transfer to the other
  tower and they do not return to hand.

This is the answer to the tower-upgrade question that was open since the first draft. The
constraint that makes it work: **no tower support may raise the rate at which a tower hits
structures.** A tower reaches the throne only through the half-rate rule above, and no
card may lift that half, waive the minimum-1 floor, or let a tower hit a structure past a
living unit. Tower support buffs damage, HP, and reach — all of which flow through the
half when they land on a structure, so a `Murder Holes` stack that adds +10 adds 5 to a
throne shot, not 10.

The reasoning is unchanged even though the rate moved: a tower that could threaten the
throne at full rate would turn the game into a race between two structures neither player
can interact with, and units would stop mattering. The reduced rate is what keeps that
from happening while still making an empty board cost something.

Tower support is deliberately a **defensive and attritional** card class:

- Every deck already owns two towers, so these cards need no setup and are never dead
  early — which is why their individual effects are small.
- They reward the player who is **behind on board**, because a tower is what's left when
  your units are dead. That makes them a natural catch-up lever.
- They are the main thing keeping a tower alive past the midgame, and a live tower is a
  slot you don't get to use. **Investing in a tower means playing on 2 slots per board
  while your opponent may be on 3.** That self-limiting cost is what lets tower support be
  cheap.

The design risk is **stall**. Two players both fortifying towers is a game where nothing
dies, and the throne's +5/turn means slow games get harder to close, not easier. Tower
support is therefore capped at small numbers and there is no tower *healing* above printed
HP. See Open Questions.

---

## Deckbuilding

- **Exactly 60 cards** per deck. Not "up to" — a deck that isn't 60 cannot be taken
  into a fight. A fixed size makes draw probabilities mean the same thing in every
  matchup, so the energy count a deck runs is a real ratio decision rather than
  something a player can dodge by trimming the list.
- **Maximum 4 copies** of any card. Support cards are **not** exempt — 4 copies max, same
  as units. The 4-copy cap is what keeps a support-heavy deck from becoming a combo deck.
- **Energy cards are exempt** from the 4-copy limit. The player decides how much energy
  to run — this is a core deckbuilding dial.
  - Energy-light decks are fast but hit a ceiling.
  - Energy-heavy decks stall early and dominate late.
- Multi-faction decks should be **common and manageable**.

### Draw & Hand

- A **clean hand** — small and curated, not Pokémon's flood.
- **Opening hand: 6 cards. Draw 1 per turn.** Chosen as the midpoint of the old 5–7
  working range and implemented in the prototype. Provisional — this is a playtesting
  dial, not a settled rule.
- **Maximum hand size: 10.**

### The opening hand

**Every opening hand contains at least one Basic unit**, for both players. The deal is
retried up to a fixed number of shuffles; if a deck genuinely holds no Basic — legal, but
unplayable — a Basic is not conjured and the hand stands as dealt.

This is not a courtesy. **A hand with no Basic cannot take a single action all turn**:
units are the only free thing to play, every Stage 1 needs a Basic already on the board,
and energy without a body to charge does nothing. There is no mulligan-for-value decision
in a hand like that, only a lost turn — and losing turn 1 in a game with a scaling tower
is close to losing the game. Pokémon solves the same problem the same way, and for the
same reason.

**It is a deal filter, not a stacked hand.** The deck is reshuffled and re-dealt whole
rather than a Basic being searched out and placed on top, so nothing about the *rest* of
the hand is biased — a two-Basic hand is still as likely as the deck makes it.

### The mulligan

**Once per game, during setup, you may mulligan your opening hand.** The whole hand
shuffles back into the deck and you draw a fresh 6, under the same guaranteed-Basic rule.

- **No penalty.** The new hand is the same size. The cost is that you may not do it again
  and the second hand might be worse.
- **Setup only.** It resolves before any Basic is deployed, so the decision is made
  looking at the hand alone — which is the whole point. Once you start placing units the
  option is gone.
- **The AI mulligans too**, on the same terms, using its own read of the hand.

There is deliberately no card-loss penalty (Magic's London mulligan draws 7 and bottoms
one). This game's opening hand is already small, the guaranteed Basic removes the worst
case a penalty would be guarding against, and a 5-card opener against a tower clock is a
much steeper punishment here than in a game with no scaling structure.

### The hand limit

**You may never hold more than 10 cards.** The limit is checked at **end of turn**, after
attacks and all other end-of-turn effects resolve. If you are over, **discard down to 10**,
choosing which cards to pitch.

Checking at end of turn rather than continuously is what makes the draw supports work.
`Gravekeeper's Ledger` from a hand of 9 draws all 3 — you just have to spend or pitch the
excess before the turn ends. A continuous cap would make draw supports silently fizzle,
which is the worst version of this rule.

Why 10, given that "a clean hand" is the stated goal:

- **It is a ceiling, not a target.** Normal play sits at 4–7 cards. The limit only ever
  fires after a draw support, which is exactly the case worth taxing.
- **It puts a real cost on stacking draw.** Unlimited supports per turn plus `Ledger` at
  4 copies means a deck *can* dig hard — the hand limit is what stops digging from also
  being free storage. You either use the cards or lose them.
- **It gives retreat teeth.** A retreated Stage 2 puts three locked cards into hand at
  once. If you were already near the ceiling, retreating costs you real cards, so
  bouncing units repeatedly is self-limiting.

**Locked retreat cards may be discarded to the hand limit.** They can't be *played* the
turn they return, but they're ordinary cards otherwise. This is deliberate — otherwise a
board wipe plus retreat could lock your hand solid with cards you may neither play nor
pitch.

Energy cards count toward the limit like anything else. Holding energy makes it worth more
(`t + 1` scales with the turn), and the hand limit is the pressure that stops indefinite
holding from being free.

---

## Factions

A **faction is an energy color.** Four are being built first; more are held in reserve.

| Faction | Domain | Verb | Status |
|---|---|---|---|
| **Hel** | Death, decay, the dead | Recycle | 🔨 Toll subfaction built — see `hel.md` |
| **Void** | Absence, entropy, unmaking | Deny | 🔨 Built — see `void.md` |
| **Gaia** | Life, growth, nature | Fuel | 🔨 Built — see `gaia.md` |
| **Heaven** | Order, light, judgment | Protect | 🔨 Built — see `heaven.md` |

Each faction must answer: *what does my deck do that no other faction can?*

Units may be **multi-typed**, costing more total energy in exchange for access to
stronger effects — never higher raw damage.

### Subfactions

A faction is not one deck. It is a **shared energy color hosting several themes**, each
built around its own mechanic. Subfactions within a faction pay the same energy and mix
freely in a deck.

This is the main axis of expansion: new content ships as a new subfaction inside an
existing color, not as a new color. It keeps the color count low (good for balance and
for a 60-card deck) while giving each faction room to grow in several directions.

The first subfaction is Hel's **Toll** — every unit refunds energy when it dies. See
`hel.md`.

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
| **Shared** | `Rise`, `Retribution`, `Consume`, `Windfury`, `Sanctuary`, `Judgment`, `Resist` | This file |
| **Hel signature** | `Toll`, `Decay` | `hel.md` |
| **Void signature** | `Siphon`, `Void N` | `void.md` |
| **Gaia signature** | `Earth`, `Essence` | `gaia.md` |

This replaced the earlier arrangement where `Rise` and `Retribution` lived in `hel.md`.
Hel keeps both and no Hel card changed — they simply stopped being exclusive. Hel's two
signatures are the pair that actually encode *death is a resource*.

Why shared-by-default: a keyword pool every faction draws from means factions differ by
*combination* rather than by vocabulary, which gives each color far more design room and
makes multi-faction cards read naturally instead of as exceptions.

Heaven prints `Judgment` and `Sanctuary` most often and at the largest values, so it owns
them in practice without holding them exclusively — a future faction may still reach for
Sanctuary as a defensive primitive.

### Future Factions

Held in reserve, not yet designed. The current four are all cool and cosmic — the set
is missing anything warm or aggressive, so the aggro slot is the most urgent gap.

| Candidate | Domain | Likely verb | Notes |
|---|---|---|---|
| **Forge** | Fire, smithing, the primal | Kill | The aggro slot. Completes a Norse-flavored cosmology alongside Hel, and "fire costs fuel" is the most intuitive energy justification in the set. **Most likely fifth faction.** |
| **Tempest** | Storm, speed, motion | Chain | Cheap repeated attacks. **`Windfury` is now a shared keyword**, so Tempest's identity is *cheap, repeated, unconditional* multi-attack rather than owning the mechanic — it prints windfury widest and cheapest, where other factions get one card. |
| **Wyrd** | Fate, chance, transformation | Gamble | Randomness and transformation. Fun, hard to balance. |
| **Wilds** | Flesh, beasts, raw physicality | Overwhelm | Big bodies, brute force. Distinct from Gaia's nurturing growth — this is nature as a threat, not a garden. |

A design gap worth tracking: **nothing yet punishes hoarding.** Hel is structurally the
banking faction and currently faces no predator. Anti-hoard mechanics — energy denial,
pool destruction, punishing large pools — most naturally belong in **Void**, with
**Tempest** as a secondary home (speed beating accumulation).

---

## Design Principles

1. **Every rule has a card that breaks it.** That's what makes deckbuilding fun. The
   one-energy-per-turn rule, the two-line rule, targeting, the board cap — all of them
   are baselines to be violated by specific cards.
2. **Spend or save is the question, at two time scales.** When to play an energy card
   (it grows in hand), and when to spend the pool (it decays).
3. **Pool vs. attached is the skill gap.** Simple to state, deep to play.
4. **Concentrated damage beats spread damage** because the board caps at 4. That's what
   makes linear damage formulas work.
5. **Towers create forced tempo.** They're a scaling attrition engine that punishes
   passivity.

---

## Open Questions

- **The second player won 7 of 8 random matchups. New, unexplained, and cheap to test.**
  Measured 2026-08-09 over the first eight random-deck runs of `RulesTest.gd`, including
  **both sides of the same pairing** — Barrow Wall lost to Rise & Recur as P1 and Rise &
  Recur lost to Barrow Wall as P1. That the result flips with seating rather than with the
  deck is what makes this look like a turn-order effect rather than a deck reading.

  It is not an artifact of the harness driver: both players are AI, `take_turn()` runs for
  whoever is active, and the loop drives them identically. The mechanism guessed at here was
  that P1 spends the early game as the one presenting targets to a tower P2 does not yet
  face — and **the 2026-08-09 setup phase and round-1 tower silence were adopted partly to
  remove exactly that asymmetry**, so this wants re-measuring before anything else is tried.
  **Eight runs cannot distinguish a real first-player penalty from noise**; the next step is
  a 30-run sample counting wins by seat, ignoring decks entirely.
- **The 2026-08-09 tower rework left the AI game shorter, not longer — 4 to 10 rounds.**
  Round-1 silence, the `5`-then-`+3` curve, half-rate structure chip, and the corrected
  per-round growth landed together and push in opposite directions. Measured immediately
  after, over eight random-deck runs of `RulesTest.gd`: rounds **4, 7, 8, 8, 9, 9, 9, 10**,
  mean ~8, no stalls. For reference the quarter-rate era averaged ~13 and the pre-shielding
  baseline was 9.

  The likely driver is **halving the structure growth**, not the tower numbers: a throne
  that gains +5 a round instead of +10 is far easier to finish, and the +3 damage curve is
  strictly gentler than the +5 it replaced. So the shortening is mostly the *bug fix*
  landing, and the docs' long-running "the throne outgrows the available damage" worry
  should be re-read in that light — some of that stall pressure was never intended.

  Whether ~8 rounds is too short is the same question the quarter-rate entry below asks
  and it has the same answer: **the AI empties its boards far more often than a human
  would**, so it is the worst case for every rule that punishes an empty board. The
  numbers below are kept because they are what this has to be read against, but none of
  them describes the current game. **Needs a human playtest before any number moves.**
- **Quarter-rate tower fire against an empty board collapsed the AI mirror from ~61 rounds
  to ~13, and that may be too much.** Measured 2026-08-08 immediately after the rule
  landed, over 10 runs of the unit-only mirror in `RulesTest.gd`: rounds **6, 8, 10, 12,
  13, 14, 14, 15, 19, 19**, mean ~13, **no stalls**. A follow-up 8-run sample on 2026-08-09
  across *random* deck pairings finished on rounds **6, 6, 14, 14, 15, 15, 15, 17** — the
  same range, so the short games are not an artifact of the mirror. The rule was adopted to answer the
  stall below and it plainly does — but the pre-rule mean was ~61 and the pre-shielding
  baseline was round 9, so this has not merely trimmed the tail, it has landed the mirror
  back at roughly the length that was originally flagged as *too short for a deckbuilder*.

  Two reasons to hold before tuning it down. First, **the AI empties its boards far more
  often than a human would** — it never retreats, does not model shielding, and trades
  units freely, so it spends an unusual fraction of the game presenting exactly the empty
  board this rule punishes. That makes the AI the worst case for this specific change, not
  the average one. Second, the chip is small in absolute terms (5 a turn at the turn-4
  tower, 10 at turn 8); a mean of 13 suggests the AI's boards are empty *most turns*, which
  is a fact about the AI worth confirming before concluding it is a fact about the game.

  The dial if it has overshot is the divisor — a sixth or an eighth rather than a quarter —
  not removing structure reach, since the reach is what kills the stall. **Needs a human
  playtest before any number moves.**
- **The HP curve raise pushed the AI mirror to the edge of not terminating.** Superseded as
  the most urgent number by the entry above — the quarter-rate rule was adopted as the
  cheapest of the three dials named here, and no stall has been seen since. The measurement
  is kept because it is what the change has to be read against. Measured 2026-08-08 in two
  passes over the unit-only mirror in `RulesTest.gd`, 14 runs each:

  | Sample | Rounds | Mean | Stalls |
  |---|---|---|---|
  | After Stage 2 → 100–175 | 10, 33, 49, 50, 51, 56, 57, 57, 67, 71, 72, 112, 113 | ~65 | **1 of 14** |
  | After Stage 1 → 80–120 too | 14, 30, 34, 46, 48, 49, 59, 60, 62, 71, 71, 84, 109, 112 | ~61 | 0 of 14 |

  For reference the pre-shielding baseline was **round 9**, and post-shielding was ~47.

  The stall is the tell, not the mean. In that run both thrones were at 512 and 1600 HP:
  the throne gains +5 max HP per turn unconditionally, so past some round it grows faster
  than the damage either side can land and the game becomes *formally* unwinnable rather
  than merely slow. Raising Stage 1 did not reproduce it in 14 runs and the mean did not
  move — but 14 runs cannot distinguish "fixed" from "rarer", so treat the risk as live.
  **Two harnesses now carry this flake**: `RulesTest.gd`'s unit-only mirror (~1 run in 14)
  and `SupportTest.gd`'s support-heavy mirror (~1 run in 10, measured over 10 runs on
  2026-08-08). Both are flaky **by design** and both failures are real signals rather than
  test noise; there is a comment at each assertion saying so. That the support-heavy game
  stalls at least as often is worth noting — supports were previously the thing providing
  the reach that unit-only decks lacked, so the problem is no longer something a deck can
  build its way out of.

  Bigger bodies were the right call for combat texture, but they compound two rules already
  flagged here: unit shielding (a tower is only reachable once a board is *cleared*, and
  clearing a board of 110 HP bodies is much harder) and unconditional throne growth. The
  cheapest dials, in order: **cap or stop throne growth after round N**, let attacks past a
  board once its *tower* dies rather than requiring the board clear, or raise the damage
  anchors to match the new HP curve. Do not tune on AI numbers alone — the AI never
  retreats and does not model clearing a board across a volley — but a hard stall at 300
  rounds is not a heuristics artifact.
- **Should the damage anchors rise with the HP curve?** `12 damage per energy` was set when
  a Basic had ~50 HP, so `4 energy = 50 = exactly kills a fresh Basic` was a real
  breakpoint. With Basics at 40–90 and Stage 1 at 80–120 that relationship is gone, and
  every printed attack is now worth proportionally less. Leaving the anchors alone is the
  conservative choice and is what makes the games longer; raising them would undo much of
  the intended lengthening. Related to the stall question above — raising damage is one of
  the three dials for it.
- **Unit shielding lengthened games ~5×, and that is now the most urgent number to
  playtest.** Measured 2026-08-08, immediately after the shielding rule landed. The
  unit-only AI mirror in `RulesTest.gd` had been ending on **round 9**; over eight runs it
  now finishes on rounds **24, 38, 40, 43, 43, 46, 69, 75** — averaging ~47. The
  support-heavy mirror in `SupportTest.gd` moved much less, finishing on **8, 11, 12, 15,
  16, 19** over six runs, which suggests supports were already providing the reach that
  units-only decks now lack.

  The mechanism is not mysterious: a tower can no longer be reached by connecting into a
  gap, so **the tower race is gated behind clearing an entire board**. That was the main
  outlet for forced tempo, and removing it makes the tower an attrition engine that also
  cannot be answered quickly.

  This does not mean the rule is wrong — round 9 was flagged here as *too short* for a
  deckbuilder, so some lengthening is the fix working. The open question is whether ~47 has
  overshot, and in particular whether the throne's +5/turn makes the back half of these
  games unclosable. Dials if it has, cheapest first: let attacks past a board once its
  *tower* is dead rather than requiring the board to be clear, give some cards a printed
  "ignores shielding" rider, or reconsider throne growth. **Do not tune on the AI numbers
  alone** — the AI still never retreats, and it now has a first-order targeting heuristic
  that does not model clearing a board across a volley, so it under-uses the one line of
  play the new rule rewards.
- **Does chosen targeting shorten games back toward the pre-shielding baseline?** Focus
  fire is exactly what the ~47-round average above was missing: clearing a board is the
  gate on reaching a tower, and picking targets is the most direct way to concentrate
  damage onto the last body standing. This may be the dial that fixes the overshoot
  without touching shielding, throne growth, or any card. It needs a fresh AI mirror to
  read — **but the AI must learn to use it first**, or the comparison measures nothing.
- **Does focus fire make wide boards strictly worse than tall ones?** Spreading damage was
  never good, but the fallback chain used to enforce *some* spread. Now three attacks can
  all land on one body by choice, so a board of three 50 HP units may be meaningfully
  worse than one 110 HP unit in a way the HP-per-stage curve wasn't priced for.
  `Sanctuary` is the accidental winner here — it resists many small hits, which is now
  the easy pattern to produce. Watch whether Heaven's walls become oppressive.
- **Should the AI ever get volley ordering, or is it a human-only lever?** An AI that
  orders optimally is a search problem (permutations of the volley × target choices), and
  a bad approximation is worse than the current fixed scan for balance readings. First
  pass should be a cheap heuristic — kills first, then Judgment units — with the caveat
  that AI results stay unreliable until it exists.
- **Does the throne's +5/turn growth outpace early aggression?** In the passive
  playtest the untouched enemy throne grew 100 → 165 by round 7. **Largely answered by
  quarter-rate tower fire**, which gave towers a second route to the throne and cut the AI
  mirror to ~13 rounds — a throne is no longer safe just because its board is empty. Left
  open because the passive-playtest reading was taken before that rule and has not been
  redone, and because the growth itself is untouched.
- Whether tower damage should cap (at +5/turn it one-shots any unit by turn 10). **Now also
  a throne question**: at a quarter rate an uncapped tower chips a throne for 25 a turn by
  round 20, so the cap decision governs the late game at both ends of the chain.
- **Does a tower's slot open immediately when it dies, or next turn?** Implemented as
  *immediately* in the prototype (simplest reading of "3 slots per board when towers
  die"). Not yet confirmed as the intended rule.
- Whether towers should regenerate only when undamaged that turn
- **Is unlimited support plays per turn actually safe?** Hand size is the only limiter,
  and a draw-3 support partially refunds its own cost. A chain of draw supports could
  reach a key card far more reliably than one-per-turn would allow. The 4-copy limit and
  the tuned power band are the current answers; playtesting decides whether a soft cap
  is needed.
- **Should a retreating unit return healed?** Currently yes, which makes retreat a way to
  launder a nearly-dead unit into a fresh one at the cost of a turn. The alternative —
  returning damaged, tracking HP on a card in hand — is more punishing but adds
  bookkeeping the rest of the game doesn't have.
- **Is `Retreat = HP ÷ 40` now too cheap?** This replaced `÷ 25`, which was answered *yes,
  too sticky* — but the new divisor swung a long way. Most Basics and Stage 1s now retreat
  for **1**, so a single attached energy extracts almost any small body, and the "an
  uncharged unit is stuck on the board" rule bites far less often. Watch for retreat
  becoming a default rather than a decision; if it does, the dial is `÷ 30` rather than a
  return to `÷ 25`. It also devalues the retreat-support suite — `Withdraw` and
  `Escape Route` were priced against costs of 3–4.
- **Does the Stage 2 buff actually rein Heaven in?** It was adopted partly for that, but
  Heaven's reprieves scale with HP, so the change may help Heaven more than it hurts it.
  Needs an AI-vs-AI sample once Heaven heuristics exist — the current AI can't play the
  faction well enough for the result to mean anything.
- **Does tower support cause stall? — now the most urgent open question.** Both players
  fortifying towers is a game where nothing dies, and the throne's +5/turn means slow
  games get *harder* to close. **Removing the one-permanent-per-tower cap sharpened this
  considerably**: a tower can now hold four `Reinforced Base` for +80 max HP, and the
  guard that used to do the most work is gone. Remaining guards: small individual
  numbers, no healing above max HP, and the lane slot a live tower costs you.
  `Open the Gate` is the pressure valve. If stall shows up, the first dial is capping how
  many permanent tower supports a *deck* may run, not weakening the individual cards. The
  AI now stacks these, so a support-heavy mirror match is the cheapest way to get a first
  reading — worth running before the next round of tuning.
- **Do priced supports quietly compete with attacking, or replace it?** A 2-cost support
  spends the same pool a 2-cost attack would, but the attack's energy stays *attached* and
  fires free every turn after, while the support's is gone. That asymmetry should make
  attacks the better long-run buy on its own — but it only holds if priced supports stay
  off the damage curve. If a priced support ever reads as "a better attack," the cost
  mechanic is doing the opposite of its job.
- **Should the free/priced pair be a naming convention?** Two versions of one card is
  clearer if the cards read as a pair (`Shore Up` / `Shore Up, Greater`, or similar) rather
  than as two unrelated names. Undecided; matters more once there are several pairs.
- **Is 3 the right ceiling?** Picked so a priced support can never cost more than a
  midgame turn of income, keeping it a supplement to attacking rather than a replacement
  for it. If 3-cost supports turn out to be unplayable — because the pool is always wanted
  for attacks — the real ceiling is 2 and the tier should be cut.
- **Is `Watchfires` too good at finding one card type?** An unbounded dig is normally a
  strong effect; it's only reasonable because tower support is the weakest class in the
  file. If tower support is ever buffed, `Watchfires` needs re-examining first.
- **Is 10 the right hand limit?** Picked as a ceiling that normal play (4–7 cards) never
  touches and only draw-stacking hits. If `Gravekeeper's Ledger` gets nerfed the limit may
  be redundant; if supports get cheaper it may need to come down to 8.
- **Does Heaven stall, and is the Judgment damage rate right?** Heaven stacks three
  reprieves (`Judgment`, `Sanctuary`, `Rise`) on a board that already rewards defense, so
  it is the most likely faction to trigger the tower-support stall risk above.
  `Verdict of the Throne` is the intended pressure valve. A first AI-vs-AI sample
  (Heaven vs Hel, 5 runs, 2026-08-08) finished on rounds **8, 8, 10, 11, 17** with Heaven
  winning 2 — no stalls, and comparable to the round-9 unit-only baseline. **That is not a
  balance reading**: `AIPlayer` has no Judgment or Sanctuary heuristics, so it plays Heaven
  badly by construction. The related dial is the ≈8-damage-per-energy Judgment rate;
  `Warden of the Lamp` and `Censer Bearer` are the deliberate control pair for it. See
  `heaven.md` Open Questions.
  **Update, same day, with the two Heaven sample decks:** cross-faction results are close
  (Verdict Engine 2–3 vs Toll Engine, Lamp Wall 2–3 vs Barrow Wall) but the **Heaven mirror
  is lopsided — Verdict Engine 4–1 over Lamp Wall**, because Sanctuary blocks a damage
  *instance* and does nothing about an execute. Once a shielded body is under the threshold
  it dies regardless of how much HP the shield saved. Also one Verdict-vs-Toll game ran to
  **round 35** against a mean of 16, the first concrete stall sighting.
- **Is ~7px board type legible enough in practice?** The board card carries the full frame
  at 132×196, which puts attack names at 8px and ability text at 7px. Hover-to-enlarge is
  the intended answer and makes the card *readable on demand* — the open question is
  whether the at-a-glance read (which unit is hurt, which still holds a charge, which
  attack is queued) survives at that size *without* hovering, because that read is what
  board decisions are actually made from. **Not yet playtested by a human**; the structural
  harness confirms the nodes are present, not that they can be read. If the glance read
  fails, the dial is enlarging `BOARD_SIZE` and giving back the vertical budget from the
  hand row, not reintroducing a second board-only layout.
- **Combat's desktop layout is ~26 units taller than the 1440×900 design height, and has
  been for a long time.** Measured 2026-08-11: the left column's minimum is **926** against
  a 900-unit viewport — two board rows at 223 each, a 296 hand scroller, and ~180 of
  labels, top bar and pool bar. It is **not** a regression from the mobile work: a clean
  checkout of the *first* commit (`d33e700`) measures 918, and the commit immediately
  before the mobile changes measures the same 926, so the mobile layout moved it by zero.

  It is survivable rather than harmless: most real windows are taller than 900, the hand
  `ScrollContainer` is the flexible row and absorbs the shortfall by shrinking, and
  `ViewportFit`'s desktop clamp scales the whole viewport down when a window is smaller
  than `MIN_DESIGN` (1180×780) — so nothing is *clipped*, the hand row just gets tighter
  than intended. The case where it actually bites is **phone landscape**: 844×390 is above
  the 820 mobile threshold, so it takes the desktop layout at a 1688×780 reference and is
  146 units short.

  Two candidate dials, neither obviously right: raise `NARROW_WIDTH` so a landscape phone
  gets the phone layout (simple, but a 1688-unit-wide phone layout would be very sparse),
  or add a short-viewport branch that trims the hand row the way the phone branch trims the
  board. Wants a decision before it is coded, and it is not urgent — no one has reported it.
- **What is the weakness/resistance system?** The card frame reserves both slots and prints
  "—". Undesigned deliberately: Pokémon's version is a ×2 / −20 against a fixed type chart,
  and this game's factions are energy *colors* rather than elemental types, so a chart would
  need to say something about Hel vs. Void that the fiction does not yet say. Worth deciding
  what it is *for* first — a deckbuilding constraint that rewards color matching, or a
  combat modifier that makes some matchups swingy — because those want different shapes.
- Theme and visual direction (factions are named, but the world is not)

---

## Running the Game & the Error Log

**Launch from the `Godsfall` shortcut on the desktop.** It runs `tools/Godsfall.vbs`,
which starts `tools/launch.ps1` hidden.

**The launcher is silent.** No console window ever appears, and everything exits when you
close the game. Errors are written to the log without interrupting you — there is no
on-screen indication that anything went wrong, so the workflow is to say "check the log"
whenever the game misbehaves.

The launcher runs the Godot **console** build (`Godot*console.exe`) rather than the GUI
build, because the GUI build detaches from the console and produces no capturable
output. Despite the name it shows no window here — its output is piped to the log. The
path is pinned in `tools/godot-path.txt`; if that file is missing or stale, the launcher
searches Downloads, `%LOCALAPPDATA%\Programs`, and Program Files.

The launch chain is three files for a reason:

| File | Why it exists |
|---|---|
| `Godsfall.vbs` | `WScript.Shell.Run(..., 0, False)` is the only way to start PowerShell with **no** window flash. A `.cmd`/`.bat` shortcut always flashes one, and even `powershell -WindowStyle Hidden` briefly creates one. |
| `launch.ps1` | Runs Godot, captures both streams, writes the logs |
| `godot-path.txt` | Pins the Godot build so startup doesn't scan the disk |

The one failure that is *not* silent is a missing Godot build — the game would never
appear and a silent exit would look like a broken shortcut, so that case shows a message
box.

Because nothing is displayed, `launch.ps1` must never call `Read-Host` or `pause`: with
no console attached it would hang forever, leaving an invisible stuck process.

### Card art

Every card has a small emblem in `assets/art/<card_id>.png`, generated by
`tools/make_card_art.py` and shown in `CardView`'s art box.

They are **symbolic emblems, not illustrations** — a silhouette drawn from the
card's *name*, so a card is identifiable before you read it. Nithogg is a snake,
Mourning Bell is a bell, Reposition is a unit moving between lane slots.

**Each faction gets a recurring visual grammar**, so a card's color is readable
before its shape is. Hel is bone and skulls on the horizon line; Heaven is gold,
radially symmetric, and tends to *float* above the horizon (halos, rays, wings,
bells, scales); Void is slate and built out of what is missing — most Void
emblems punch a near-black hole in the backdrop with a bright rim of whatever it
is currently eating, which is the faction drawn as absence rather than as a
creature. The shared helpers (`halo`, `rays`, `wings`, `bell`, `scales`,
`void_eye`) exist so that grammar can't drift card to card.

The pipeline is deliberately the same shape as `make_icon.py`:

| | |
|---|---|
| **Drawn in code** | Pillow, one function per card keyed by card id, coordinates in 0–1 space |
| **Regenerable** | `python tools/make_card_art.py` rebuilds all 95 from scratch |
| **Supersampled** | Drawn at 4× and downscaled, so edges are smooth without anti-aliasing work |
| **128px source** | Above the largest size the game shows (the inspector's 1.55× scale makes the 74px box ~115px). Upscaling is what looks soft |

Colors mirror `scripts/ui/Theme.gd`, and the backdrop tint comes from the card's
own faction, so a new color slots in without touching the drawing code.

**Art is optional by design.** A card with no PNG falls back to `CardView`'s
initials placeholder, so adding a card to `data/cards.json` never blocks on
someone drawing it. `make_card_art.py` prints which ids fell back to the generic
emblem.

`CardArt.gd` (autoload) loads and caches the textures. The cache is not an
optimization detail — `CardView` rebuilds on nearly every state change (hover,
selection, damage, queueing), so uncached loads would hit the disk constantly.
**Misses are cached too**, otherwise an art-less card retries the load on every
redraw.

After regenerating, run Godot once with `--import` so the new PNGs get `.import`
files. This is the opposite of `icon_window.png`, which is deliberately *not* a
Godot resource — card art is loaded with `load()` and needs the importer.

### Icons

There are **two** icons, and they are set in different places:

| Icon | Source | Set by |
|---|---|---|
| Desktop shortcut | `tools/Godsfall.ico` | The `.lnk`'s IconLocation |
| Window / taskbar | `icon_window.png` | `WindowIcon.gd` autoload |

The taskbar shows the icon of the *running process*, not the shortcut that launched it,
so the shortcut icon alone leaves Godot's default robot in the taskbar. `WindowIcon.gd`
fixes that with `DisplayServer.set_icon()`.

Two things that will silently break it if changed:

- **The call must be deferred a frame.** Setting the icon before the window exists is
  ignored without error.
- **`icon_window.png` is deliberately not a Godot-imported resource.** It has no
  `.import` file, so `load()` has no loader for it — use `Image.load_from_file()`.

Both icons are generated from one script, so they can't drift apart. To change the art,
edit and rerun `tools/make_icon.py`, then refresh the shortcut icon (Windows caches it —
easiest is to re-run the `WScript.Shell` snippet that created the `.lnk`).

### The web build

**The game is public at <https://jonahbyu.github.io/Godsfall/>**, served by GitHub Pages
from the `gh-pages` branch of `github.com/Jonahbyu/Godsfall`.

Rebuild and publish with:

```
powershell -ExecutionPolicy Bypass -File tools\export-web.ps1
```

That exports to `build/web/` and pushes it to `gh-pages`. Add `-NoPush` to build without
publishing.

The layout is three-way separated on purpose, and each split was forced by something:

| Where | Holds | Why not together |
|---|---|---|
| `master` | Source, design docs, `docs/plans` + `docs/specs` | — |
| `gh-pages` | Only the exported build | A 39MB wasm regenerated on every export has no place in a source branch's history |
| `build/` | Local export output, gitignored | — |

**Pages cannot serve an arbitrary folder** — only a branch root or `/docs`. Since `docs/`
was already the designated home for plans and specs, serving from there would have
published them and let a stray `--export` overwrite them. A separate branch is what keeps
the two from ever sharing a file.

Five things the export depends on, each of which silently breaks it if changed:

- **`variant/thread_support=false`.** A threaded build needs COOP/COEP headers, and Pages
  cannot set headers. A threaded build deploys fine and then refuses to start.
- **`.nojekyll` on `gh-pages`.** Without it Pages runs the files through Jekyll, which drops
  paths beginning with an underscore and reports nothing.
- **`BattleLog` writes to `user://` outside the editor.** `res://` is inside the packed
  `.pck` and read-only once exported, so the balance log would silently never write. It
  still uses `res://logs/` under the editor, which is what the workflow below reads.
- **The export folder must exist before `--export-release` runs.** Godot errors with
  "Target folder does not exist" rather than creating it; the script does it first.
- **`export_presets.cfg` must be written without a BOM.** The export script rewrites
  `html/head_include` on every run (see below). PowerShell 5.1's `-Encoding utf8` always
  emits a BOM, Godot does not skip one, and the BOM lands in front of `[preset.0]` — so
  the section header stops matching and the export dies with *"Invalid export preset name:
  Web"*, an error that says nothing about encoding. The script writes through
  `System.IO.File::WriteAllText` with a BOM-less encoder for exactly this reason.

`user://` on the web is browser storage, so saved decks are per-browser and are lost if the
user clears site data. That is a real limitation of the web build, not a bug.

### Fonts and glyphs

**The project bundles no font, so every character renders in Godot's built-in Open Sans
SemiBold — which covers Latin-1 and essentially nothing else.** Arrows, geometric shapes
and emoji are all absent and render as empty boxes.

This shipped broken for a long time and was only noticed on the live web build: `←`, `→`,
`◆`, `⚠`, `⬢`, `☠`, `⚒`, `✓`, `✕`, `▸`, `▾`, `▶`, `↑`, `↩`, `⊘`, `🔒`, `🔓` and `🎲` were all
in use. The `⬢` was the worst of them — it is the **energy symbol**, printed on every attack
cost, every card frame and the pool meter, so the game's central currency was a box.

**Every symbol now lives in `Palette.GLYPH`**, and the safe set is narrow:

| | |
|---|---|
| **Renders** | ASCII, plus `·` `—` `×` `•` `−` `"` `"` |
| **Does not** | every arrow, every geometric shape, every emoji |

Two rules, both enforced by `LayoutTest.gd` rather than by discipline:

- **Add a symbol to `Palette.GLYPH`, never inline.** One table means one place to check and
  one place to fix when a glyph turns out to be unavailable.
- **Check it with `Font.has_char()` before using it.** The whole failure mode is that a
  glyph looks correct in an editor, correct in a diff, correct in review, and is a box on
  screen — so the only trustworthy check is asking the actual theme font.

Bundling a symbol font was the alternative and was rejected: megabytes onto an already 39MB
wasm download to draw about twenty characters. ASCII stand-ins cost nothing and cannot
regress.

### Mobile mode

**`ViewportFit` owns both how large the UI is drawn and whether screens use their
single-column layout**, because the two are one decision made from one measurement.

Drawing bigger costs width, and the desktop layouts are built from fixed-width columns that
cannot survive losing it — so zoom alone is useless. Raising the scale without restacking
just pushes content off the other edge. `mobile` is what tells each screen to go
single-column and give the width back.

| | Desktop | Phone |
|---|---|---|
| Reference width | the window, clamped to ≥1180 | a fixed **540** design units |
| Effective scale on a 390px phone | 0.33× (unreadable) | **0.72×** |
| Board card | 132×196 | **78×116**, and a reduced frame |
| Hand card | 168×262 | **112×175** |
| Combat | board \| action+log side by side | stacked, log becomes a drawer |
| Deck select | list \| contents in an `HSplitContainer` | stacked, actions on their own row |
| Deck builder | collection \| deck in an `HSplitContainer` | **tabs** |
| Main menu | — | unchanged; it is already one column |

**Restacking containers is not enough on its own, and shipping it that way was the first
attempt's whole failure.** Mobile mode originally set a 540-unit reference width and told the
screens to go single-column — and left every card at its desktop size. A board row is six
cards, so it still demanded ~850 units inside a 540 viewport, Combat's layout minimum came
to 931, and the result was exactly "zoomed in with everything cut off". The containers were
narrower; the things inside them were not.

So the phone sizes above are arithmetic, not taste: `6 × 78 + 5 × 4 + 2 × 10 = 508` fits
540, and the board panel's margins and lane separations were trimmed to buy the rest. **Any
fixed-size UI element needs a phone value, or it silently sets the layout's floor.**

**The phone board card is a reduced frame — the one place "one layout at two sizes" bends.**
At 78 units there is no font size at which the full Pokémon-style frame is readable, so the
phone board card carries name, HP, keyword chips and a status row (attached energy, queued
marker, dies-EOT) and drops the art-adjacent rows, the ability banner, the attack rows and
the footer. That is consistent with *why* the one-layout rule exists rather than a violation
of it: the rule guards against a card **contradicting** itself in two places, and a micro
card only ever omits — tapping it opens the full frame.

**The hand row is the sanctioned exception to fitting the viewport.** It scrolls
horizontally, because six hand cards are meant to be swiped through rather than shrunk to
nothing, and the hand is where cards are actually read before being played.

**The builder uses tabs where the others stack**, and that is the one deliberate
inconsistency: both its halves are tall scrolling lists, so stacking would mean scrolling
past the entire collection to reach the deck. Tabs also match how the screen is used — you
browse, then you review, and rarely need both at once.

Combat also moves its turn line and hint onto their own full-width rows on a phone. A
`Label` in an `HBoxContainer` has nothing bounding its width, so it never wraps — it just
grows and drags the row past the edge. Its own row gives it a bound, and then
`AUTOWRAP_WORD_SMART` does the work. That was the specific cause of "Setup — place your
Basics · Towers hold fire in round 1" running off the screen.

**Activation is automatic with a manual override.** Below 820px the layout switches on its
own; a three-way `Auto / Phone / Desktop` control forces it either way and persists to
`user://display.cfg`. The override is not a nicety — it is the only way to test the phone
layout without a phone, and it is the recourse when detection misjudges a device.

**The override lives behind a settings cog pinned to the top-right of every screen**
(`Settings`, an autoload on a `CanvasLayer` above every scene). It is deliberately *not* a
main-menu item: the override is the recovery path for a UI that has become unusable, and a
recovery control has to be reachable from wherever you are when you notice — which is
usually Combat, the screen furthest from the menu. Being a `CanvasLayer` autoload also means
it survives every scene change without being rebuilt and cannot be pushed off the edge by a
screen's own layout. The panel states what Auto currently resolves to, so the control
reports the state it is *in* rather than only the rule it follows.

**`ViewportFit.save_path` is a variable, and every harness touching it must call
`use_sandbox_path()`** — the same rule `DeckStore.save_path` follows, for the same reason.
It was a `const` at first, and a verification script wrote `Override.ON` to the real file
and failed to clean up, leaving the game stuck in phone mode on a 1440-wide desktop. That is
the third instance of this exact shape in the project.

**Crossing the threshold rebuilds the screen wholesale rather than re-parenting.** The two
shapes differ in which nodes exist at all, not merely in parentage, and every screen's real
state lives in `GameState` or `DeckStore` rather than in its nodes — so a rebuild costs a
frame and cannot leave a stale mix of the two. Each screen latches `_mobile` at build time
for the same reason: one build has to agree with itself about which shape it is.

### The page shell

**The page's mobile CSS and its fullscreen button live in `tools/web-head.html`**, which
`export-web.ps1` escapes and writes into the preset's `html/head_include` before every
export. Editing that file is how the page changes; the `.cfg` value is generated and
should never be hand-edited.

It is deliberately **not** a `custom_html_shell`. A full shell means forking Godot's boot
script — the progress bar, the missing-feature detection, the service-worker retry — and
re-merging it by hand on every engine upgrade. Everything in `web-head.html` is additive
and touches nothing Godot generates, so an upgrade cannot silently break it.

What it does, and why each part is load-bearing on a phone:

- **`height: 100dvh`, with `100vh` as the fallback.** On mobile Safari and Chrome `vh` is
  locked to the viewport with the URL bar *hidden*, so a `100vh` body is taller than the
  visible page whenever the bar is showing. That overflow is the actual cause of the game
  sitting half off-screen and scrolling under the browser chrome. `dvh` tracks the bar.
- **`touch-action: none` and `overscroll-behavior: none`.** The canvas handles its own
  input; without these the browser also pans, pinch-zooms and rubber-bands the page under
  the game.
- **A fullscreen button**, because requesting fullscreen is the only reliable way to hide
  the URL bar — the old scroll-to-hide trick needs a scrollable page, and this one
  deliberately cannot scroll. It must be triggered by a user gesture, which is why it is a
  button rather than something done on load. It is **feature-detected, not UA-sniffed**,
  and simply never appears where the Fullscreen API is unavailable (iPhone Safari): a
  button that does nothing when tapped is worse than no button. Entering fullscreen also
  requests a landscape orientation lock, which is a hint — it rejects on desktop and
  wherever the browser disallows it, and that is fine.

**Two characters to keep out of `export-web.ps1`**: an em-dash or a curly apostrophe inside
the block that writes the preset. PowerShell 5.1 reads the script as ANSI when there is no
BOM, mis-decodes the multi-byte sequence, and the parser desyncs — the symptom is a
baffling `The term 'finally' is not recognized` pointing at a `try`/`finally` a hundred
lines further down, with no output from anything above it. Plain ASCII in that file.

### What the launcher produces

| Path | Contents |
|---|---|
| `logs/errors.log` | **Outstanding problems only.** Empty means nothing is wrong. |
| `logs/history/session_<stamp>.log` | Full stdout/stderr of every run, kept forever |
| `logs/fixed-history.log` | Errors that have been fixed, with a note on the fix |

A clean run writes a session log and leaves `errors.log` untouched. Closing the window
normally is not treated as an error.

### The workflow

1. Jonah launches the game from the desktop shortcut and plays.
2. Anything that goes wrong is logged silently — nothing appears on screen.
3. Jonah says **"check the log"** whenever the game misbehaves.
4. Claude reads `logs/errors.log`, fixes the causes, then archives:

```
powershell -ExecutionPolicy Bypass -File tools\archive-errors.ps1 -Note "what was fixed"
```

That appends the errors to `logs/fixed-history.log` under a `RESOLVED` header and empties
`errors.log`, so the live log only ever holds problems that are still outstanding.

**Always archive with a `-Note` after fixing.** `fixed-history.log` is the record of past
mistakes — read it when a bug looks familiar, because the same error recurring means the
earlier fix was wrong.

### What counts as an error

`launch.ps1` extracts lines matching `SCRIPT ERROR`, `ERROR:`, `WARNING:`, parse errors,
nil-instance calls, failed loads, and any `res://…​.gd:<line>` reference — plus the `at:`
source line that follows. Godot's own `push_error()` is captured too, so deliberate
assertions in game code surface here.

---

## Status

**First prototype playable.** Godot 4.7 project, rooted in this folder.

**There is an in-game tutorial, reached from `Learn to Play` on the main menu.** It is two
halves: **fourteen scripted lesson battles** and a **browsable rules reference**. See
`docs/plans/tutorial.md` for the design and `The tutorial` below for how a lesson is built.

The lessons cover the whole rule set — board geometry, the energy economy, attacking,
shielding, chosen targets and volley ordering, towers, evolution and abilities, retreat,
supports/Tools/tower support, all four factions' keywords, and deckbuilding. Each is
**independently selectable and independently completable**; no lesson depends on state from
another, so a player who only wants the Void lesson can take it. Progress is saved to
`user://tutorial.json` — deliberately its own file, so corrupt tutorial state can never take
the deck collection with it.

Two things are deliberately *not* done:

- **No lesson teaches the attack lock or the mulligan by doing.** Both are described in the
  reference but neither has a step, because the lock is a convenience over a rule the player
  already knows by then and the mulligan only exists during setup, which only lesson 1 uses.
- **Pacing is not verified.** `TutorialWalkTest` proves every lesson can be *finished* and
  `TutorialTest` proves the content is well formed, but neither can tell you whether a step's
  text lands before the board changes under it, whether the coach panel is where the eye
  already is, or whether the gating ever refuses something a reasonable player would try.

**One bug already shipped and was fixed here**, and it is worth keeping because the shape
recurs: the `board` lesson asked the player to deploy a second Basic while dealing them one
Basic and five energy cards. See the decision log — the lesson now *declares* its hand, and
`TutorialWalkTest` exists specifically because the content harness could not have caught it.

**Public, and playable in a browser at <https://jonahbyu.github.io/Godsfall/>.** Source is
at `github.com/Jonahbyu/Godsfall`; the Web build is published to the `gh-pages` branch by
`tools/export-web.ps1`. See *The web build* above for the four settings the export depends
on. Verified in a real browser on 2026-08-09 — the engine boots, `CardDB` loads all 114
cards, deck select lists all ten samples, and combat reaches the setup phase against the AI
with no console errors.

Implemented: main menu, deck select, deck builder, combat vs. a heuristic AI, **both
factions in full** — 15 Hel units and 13 Heaven units, each with its own energy card — the
38 neutral supports, and the full turn/energy/combat rule set. Card data is data-driven
from `data/cards.json` (**114 cards**: 16 Hel, 15 Heaven, 21 Void, 19 Gaia, 43 neutral).

**Heaven is built — two factions now exist.** 13 units, an energy card, and one Tool,
implementing the `Judgment` and `Sanctuary` keywords and the within-attack damage
resolution order. See `heaven.md`. Three things are deliberately *not* done:

- **`AIPlayer` has no Heaven heuristics.** It does not value a Judgment charge, hold a
  Sanctuary body back, or time `The Gate Opens`. Heaven games run — a Heaven-vs-Hel AI
  sample over 5 runs finished on rounds 8, 8, 10, 11, and 17 with Heaven taking 2 — but
  **AI results are not a balance reading for this faction** until those heuristics exist.
- ~~No Heaven sample deck.~~ **Done** — `Verdict Engine` and `Lamp Wall` ship alongside the
  four Hel lists, so the collection is six decks and the Hel/Heaven matchup is playable from
  deck select without hand-building anything.
- ~~No Heaven card art.~~ **Done** — all 15 carry a generated emblem.

**`Windfury` is documented but unimplemented.** It is defined in the shared keyword table
so Tempest and future rule-breakers have a home; no card uses it, and implementing it
means a second queued attack slot on `Unit`.

**Every card has art.** All 95 carry a generated emblem in `assets/art/`, shown in
`CardView`'s art box in hand, on the board, and in the inspector. See Card Art below —
they are regenerated from `tools/make_card_art.py`, not stored as hand-made files. The
initials placeholder still exists and is still the right behaviour for a card added
before someone draws it; nothing currently uses it.

**Decks are a named collection.** The player keeps any number of saved decks, each with a
name, and picks one before a fight. `DeckStore` holds the collection and an active index;
`DeckStore.deck` is a property pointing at the active deck's card map, so the deck builder
and combat operate on whatever is selected without knowing the collection exists. Saved to
`user://decks.json`; an old single-deck `user://deck.json` is migrated on first run.

Every mutating call — add, remove, rename, create, duplicate, delete, select — writes the
whole collection to disk immediately, so a deck can never be lost by closing the app. The
save path is `DeckStore.save_path`, a **variable** rather than a const, and the headless
harnesses redirect it with `use_sandbox_path(tag)`. That indirection is not optional: the
tests seed and round-trip deck data, and while they shared the real path, **every test run
silently destroyed the player's saved decks.** Any new harness that touches `DeckStore`
must call `use_sandbox_path()` before it writes.

**Ten sample decks ship as the starter collection** — four Hel, two Heaven, two Void, two Gaia — laid down on
first run by `DeckStore.sample_decks()`. Each is built around a single idea rather than a
spread of the card pool, because a deck holding one of everything has no plan to read and
plays the same whatever you draw:

| Deck | Faction | Identity | Energy |
|---|---|---|---|
| **Toll Engine** | Hel | Cheap bodies that pay out when they die; `Sift the Ashes` converts a bad combat into a turn of income. No healing — it *wants* trades — so the slots go to draw. | 16 |
| **Barrow Wall** | Hel | Retribution bodies plus the whole heal suite and tower support. Survives the tower clock and wins on attrition. | 19 |
| **Rise & Recur** | Hel | `Rise`, Bonepicker's Scavenge, and Hel Queen recycling the discard; the retreat suite as a second recursion angle. | 19 |
| **Cacophony Ramp** | Hel | Both Stage 2 lines complete, with `Offering`/`Tithe`/`Ration Pack` to reach a 14-cost attack. Does nothing early, everything late. | 22 |
| **Verdict Engine** | Heaven | Every unit carries `Judgment`. Chip anything into threshold range and execute it; `Court of Bells` reloads the board's charges and `Verdict of the Throne` turns the kills into throne damage. | 15 |
| **Lamp Wall** | Heaven | Deliberately **no `Judgment` at all**, so it keeps the standard damage curve — `Pillar of Light` at 65 and `Judgment of Light` at 75. Sanctuary chaff shields the Bastion while it charges. | 19 |

**Every sample deck is exactly 60 cards**, not merely under the cap — `DeckStoreTest`
asserts it, because a shipped deck should be battle-ready as printed rather than a
partially-built list the player has to finish.

All six run 15–21 support cards, and the *mix* is part of the identity — the aggro deck
takes draw and reach, the wall takes healing and tower support, and they barely overlap.
`default_deck()` returns the first sample, so `reset_to_default()` and the harnesses keep
working unchanged.

Each deck is checked at design time for the trap that a themed list invites: an evolution
whose Basic isn't in the deck. Mourning Bell was cut from Toll Engine for exactly that —
it needs Thornshade, which that deck doesn't run.

The two Heaven decks are also the first demonstration that a faction's *internal* split is
deckbuildable: Verdict Engine and Lamp Wall share a color and an energy card and have
almost no card overlap, because Judgment and Sanctuary want opposite things from a body.

**Cards use a Pokémon-TCG-style frame.** One layout, built by `CardView`, rendered at
both sizes — hand cards at 168×262 and board cards at 132×196 — with every font size and
box height coming from a single `METRICS` table keyed by mode. Top to bottom: stage and HP
on opposite ends of a header row with the name at full width beneath it, an evolves-from
strip, art, keyword chips, an ability banner, one row per attack with its cost as inline
energy icons, and a footer holding retreat cost and the reserved weakness/resistance slots.

**The name gets its own full-width row.** A real Pokémon card puts stage, name and HP on
one line, and the first build did too — but a real card is 63mm wide and this frame is
168px. With a fixed stage cell and HP flanking it, "Thornshade" rendered as "Thorns…" and
"Hel, Queen of the Unclaimed" as "Hel, Qu…". A layout whose first casualty is the card's
own name has its priorities backwards, so the name moved to its own row and steps down a
font size before it resorts to trimming.

**The board card is deliberately small and hover-enlarges instead of simplifying.**
Packing the full frame into 196px means ~7px type, which reads well enough to scan a board
but not to study a card. Hovering a board card raises a scaled copy built at *hand*
metrics on a `CanvasLayer` above the board. The alternative — a trimmed board layout — was
rejected because a card that reads differently in two places is exactly the drift that
made the inspector reuse `CardView` rather than draw its own big card.

**Energy costs sit beside the attack they pay for**, as faction-colored hexagons drawn by
`EnergyIcon.gd` rather than as a bitmap, so they stay crisp at the four scales the game
renders cards at. Attached energy fills an attack's icons left-to-right, so the row doubles
as a progress bar toward affording it — that read was the whole job of the old
bottom-of-card pip block, and it survived the move. Costs above 8 collapse to a numeric
chip, because nine icons overflow the frame and a Cacophony Ramp player counting toward a
14-cost attack wants the number anyway.

**Keywords render as chips, and the chips are live.** They are built from
`CardView._live_keyword_line()`, not from the printed card, so a spent `Judgment` or `Rise`
disappears and `Sanctuary N` shows its remaining pool. One chip per keyword, tinted by
`Palette.keyword_color()`, because *"does that body still hold its charge?"* is a lookup
rather than a sentence to read.

**Cards can be clicked or dragged.** Drag-and-drop is an alternative input method for
actions that already exist — deploy a Basic onto an empty slot, drop an evolution onto its
base form, drop an energy card onto a unit to play it and charge that unit in one motion.
Click-then-click still works everywhere; neither style is required. There is deliberately
**no free drag-to-rearrange**: moving a unit between slots is the printed effect of the
`Reposition` support card, and giving it away for free would make that card worthless.
Placement no longer being the sole targeting lever doesn't change this — repositioning
also moves which unit eats the tower shot and which one shields, so it stays a card
effect rather than a free action.

**Clicking a card in the deck builder inspects it.** `CardInspector.gd` opens a modal
holding the card's full detail: the real in-game `CardView` frame scaled up, its keywords
expanded into rules text, attack costs and effects, the Toll/Retreat comparison, flavor,
and the whole evolution line as clickable mini cards you can walk in either direction.

Inspecting and adding are **separate gestures** — the row opens the inspector, the `+`/`−`
buttons edit the deck. Reading a card you're deciding about shouldn't be the same action
as committing to it, and the old behaviour (click = add) made it impossible to study a
card without changing your deck.

The inspector deliberately reuses `CardView` rather than drawing its own large card. A
second "big card" renderer would drift out of sync with the real one the first time either
changed, and the point of the screen is to show the card **as it appears in play**.

**The two halves of the builder are deliberately different shapes.** The collection is a
text list — a scannable index of everything available, where names and keyword lines are
what you read. The deck is a **grid of real card frames** (`CardView` again, shrunk),
because that side is judged as a whole: you want to see the shape of what you've built,
not read its names.

The grid shows **one tile per distinct card with a ×N count**, not N copies. A 60-card
deck holds only ~16 distinct cards, and 60 identical thumbnails would bury the two-of you
were looking for. Each tile's count badge and remove button sit in a strip *under* the
card rather than on top of it — overlaid, they covered the card's name, which is the one
thing a thumbnail is identified by.

**The collection has faction and card-type filters**, as two independent rows of toggles.
They became necessary the moment a second faction existed: an undifferentiated list of
every card in the game is an index of the *game*, not of what you are building, and
scrolling past one faction to reach another is the whole problem.

Two filters rather than one combined control, because *"show me Heaven"* and *"show me
Tools"* are different questions and a player usually wants one faction with all its types,
or one type across everything.

**Neutral supports stay visible whichever faction is selected.** They are legal in every
deck, so hiding them behind a colour filter would misrepresent what that colour can
actually build.

The faction row is **derived from `CardDB`, never hardcoded** — see the decision log entry
about the builder having hardcoded `"hel"` and thereby making all of Heaven invisible.

### The opponent's deck

**The AI brings a random legal deck by default, and deck select can pin a specific one.**
It no longer mirrors the player's list.

- The control is an `Opponent:` dropdown on the deck select screen. Item 0 is **Random**,
  the default; the saved decks follow. Illegal decks are **listed but disabled** rather
  than hidden, so a half-built deck doesn't silently vanish from the menu.
- The choice lives in `DeckStore.opponent_index` (`OPPONENT_RANDOM` = -1) and is
  **deliberately not persisted**. It is a per-session choice about the fight in front of
  you, not a property of the collection, and saving it would mean migrating `decks.json`
  for a preference that costs nothing to re-pick.
- `resolve_opponent_index()` rolls a fresh deck each match, drawing uniformly from the
  **legal** decks only. A same-deck pairing may come up by chance (~1 match in 8); the
  draw is uniform and forcing distinctness would bias the sample away from every pairing
  involving the player's own deck.
- A pinned deck that is later deleted or gutted **falls back to Random** rather than
  starting a fight against a list the player didn't choose.

Both AI-vs-AI harnesses draw random sample decks the same way, which is the more important
half of the change: **a mirror can never surface a matchup problem**, because it only ever
measures the AI against itself with the same list. `SupportTest.gd` gave up a hand-built
support-heavy deck to do this — safe because all eight samples run 15–21 supports, and its
"cards were spent" assertion keeps that honest.

### The tutorial

Two halves, and the split is the point:

| Half | Teaches | Form |
|---|---|---|
| **Lessons** | The ~30 mechanics you *do* | Scripted interactive battles, gated step by step |
| **Reference** | The exhaustive rules text | Browsable pages, no game running |

A scripted battle is the only thing that can teach *pool vs. attached*, because that
decision only exists when energy is actually scarce. But a battle cannot cover fifteen
keywords without becoming an hour long, and a player looking up `Sanctuary N` six weeks
later wants a page, not a replay. Each half does what the other does badly.

| File | Role |
|---|---|
| `scripts/core/TutorialData.gd` | All lesson and reference content. **Data only** — no UI, no live `GameState`. |
| `scripts/core/TutorialState.gd` | Autoload `Tutorial`. Active lesson, current step, progress. |
| `scripts/ui/Tutorial.gd` | Lesson select |
| `scripts/ui/Compendium.gd` | The reference |
| `scripts/ui/Combat.gd` | Gating, highlighting, the coach panel |

**A step is data, not code** — its text, what completes it, what is legal while it is open,
and what to highlight. The three mechanisms are *gating* (a step names which actions are
legal; everything else is inert and says so), *highlighting* (a step names a widget and it
is ringed in gold), and *scripting* (a step may force board state, so a lesson about
Sanctuary need not wait for the player to draw a Sanctuary body).

**Advance conditions are checked against the real `GameState`.** A step completes because
the rules engine agrees the thing happened, never because a click was counted — which is
what keeps a lesson honest when the engine changes underneath it. The two exceptions are a
unit *selection* and a *heal*, which leave no standing record in `GameState`; the UI reports
those two directly, and that list is deliberately kept as short as it is.

Four constraints worth keeping:

- **The tutorial never touches `DeckStore`.** Lesson decks are fixed lists passed straight
  to `GameState`. That is the data-loss shape the decision log already carries twice, and
  the tutorial is the last place that should be able to write the player's collection.
- **Every lesson DECLARES its opening hand**, as a `"hand"` list dealt exactly by
  `Player.deal_exact_hand()`. The hand a lesson's steps need is a property of the *lesson*
  and has to be stated by it — never inferred from deck order and hoped for. Cards named
  there are pulled out of the deck, so a copy cannot be both in hand and still in the deck,
  and a card not in the deck is skipped rather than conjured.
- **Lesson decks are dealt unshuffled**, via `GameState.new(p1, p2, false, hand)`. A step
  that says "play the energy card" cannot survive a hand that differs per run. The
  unshuffled path also **skips the guaranteed-Basic re-deal**, since re-dealing would
  reshuffle the very order the caller asked to preserve — the declared hand is what
  guarantees a Basic instead, and `TutorialTest` asserts it for all thirteen.
- **Every hook is inert when no lesson is running.** `Tutorial.active` is false in an
  ordinary game and every hook answers permissively, so the normal path is unchanged *by
  construction* rather than by care.

The coach panel takes the top of the right-hand column and **demotes the battle log rather
than overlaying the board** — a tutorial that hides the thing it is teaching about is
self-defeating. Every step is skippable and every lesson replayable, because a tutorial that
can trap you is worse than no tutorial.

The reference reuses **`CardView`** for its keyword examples, the same renderer the hand,
board and inspector use — the same reasoning that made `CardInspector` scale a real
`CardView` rather than draw its own.

**The known drift risk:** the reference restates rules that live in this file, and nothing
syncs them automatically. The guard is narrow but real — `TutorialTest` asserts that every
keyword in `Palette.KEYWORD_COLORS` has a page and that no page documents a keyword the game
does not have, so **a new keyword fails the suite until someone documents it**. Nothing
catches a *changed number*, so a tuning change still has to be propagated by hand.

### The battle log

**Every finished game appends a record to `logs/battles.log`** — real games from `Combat`
and AI games from both harnesses, tagged so they can be told apart. Written by
`scripts/core/BattleLog.gd`.

Each record holds the matchup, the winner and round, **both thrones and all four towers**
with current and max HP, and a **per-card damage table** split into unit / tower / throne
with a hit count. Tower fire is totalled separately, because it belongs to no card and
would otherwise dominate a table meant to rank *deck* decisions.

The point is that every balance number in these docs is currently a single sample someone
read off a console scroll. A file that accumulates turns "Toll Engine feels strong" into
something countable. It is **append-only and never rotated** — a run is a few dozen lines,
and rotation would defeat the purpose of accumulating history.

Two guards worth keeping: the writer never raises (a balance log that can fail a test suite
or break a game is worse than no log), and a stall is recorded as `NO WINNER — stalled at
round N`, since that is the single most important thing the file can capture.

Verified by fourteen headless harnesses (all passing — run 2026-08-10 after the mobile
layout and glyph work landed, **891 counted assertions**, with the long-standing
`SupportUITest` flake fixed rather than merely absent; `SceneSmokeTest`, `PlaythroughTest`
and `TutorialWalkTest` report pass/fail without a count and are not in that total):

| Harness | Covers |
|---|---|
| `RulesTest.gd` | 126 assertions: decay, energy scaling, Toll, attach/queue, targeting (all four steps of the chain, shielding, the per-board limit, no-overkill, and clearing a board mid-volley), tower fire (the 0/5/8/11 schedule, full to units, the half chip to tower then throne, round-1 silence, the min-1 floor, and off-slot shielding), Retribution, evolution, Rise, abilities/Consume, the attack lock, setup (the guaranteed-Basic deal across every sample deck, the mulligan and its once/timing limits, free deployment, and both-players-ready gating), structure growth at +5 per *round*, full AI-vs-AI game |
| `SupportTest.gd` | 158 assertions: card data integrity, the 4-copy limit on supports, draw/energy/healing/damage supports, Tools, tower support, retreat and its lock, the hand limit, and a random-matchup AI-vs-AI game |
| `DeckStoreTest.gd` | 64 assertions: create, select, rename/collision/truncation, duplicate, delete, per-deck validation, edit isolation, save/load round-trip, the opponent-deck choice (random legality, pinning, stale and illegal fallback), and `seed_samples` on a bare store |
| `DragDropTest.gd` | 27 assertions: payload resolution against a shifting hand, deploy/evolve/charge by drop, the illegal-drop guards, and leaving setup via the Ready button |
| `SceneSmokeTest.gd` | All four screens instantiate without error |
| `PlaythroughTest.gd` | Drives the real combat UI: deploy, charge, queue, end turn |
| `SupportUITest.gd` | 43 assertions driving the real combat UI: leaving setup by pressing Ready, support targeting mode, the two-unit pick, tower targeting for both owners, Tool attach by click and by drop, the retreat button, and the modal card picker |
| `HeavenTest.gd` | 61 assertions: Heaven card data, Sanctuary pool depletion and terminal overflow, both halves of Judgment **driven through the real damage pipeline**, the Heaven mirror ordering, the save-is-not-re-executed guard, Sanctuary preceding Judgment, both reset cards, and keyword restoration on Rise and evolution |
| `CardViewTest.gd` | 62 assertions on the card frame's *structure*: the header's HP and stage cells, the evolves-from strip (present on evolutions, absent on Basics), keyword chips including a spent `Judgment` dropping its chip, the ability banner (present with an ability, absent without), attack rows with the right icon count and attached-energy fill, the retreat footer and its reserved weakness/resistance slots, and a complete frame for all four non-unit card types. Checks which nodes exist and what they say, never pixel positions — those would break on every metric tweak |
| `VoidTest.gd` | 61 assertions: Void card data and the printed damage budget, Gap direction/floor/living-units-only, Siphon moving energy on a unit vs. into the pool on a support, Void N destruction, the damage-per-voided rider, Rift scaling **through the real damage pipeline**, Rift granted by a Tool, pool destruction, Gap-to-throne damage, and Siphon obeying the shielding chain |
| `GaiaTest.gd` | 146 assertions: Gaia card data including per-colour attack costs, the Earth aura summed across both boards and excluding the dead, aura-adjusted max HP, healing that reaches the aura's ceiling, downward clamping that never kills, the aura on attack damage and on tower damage, `Resist` in both damage paths and on Retribution recoil with its minimum-1 floor, Sanctuary preceding Resist, `Essence` **through the real `_cleanup_dead`** (payment, the nearest-living heir, ties-go-left, never crossing boards, skipping a corpse in a batched death, and fizzling when unaffordable), grown Earth resetting on Rise and evolution, Earth derived live from attached energy, the additive rate-breaker, and Makeshift Tower's free auto-fire, per-round growth, and obedience to the shielding chain |
| `TutorialTest.gd` | 119 assertions: lesson content integrity (unique ids, every step carrying text, every `advance` predicate one the evaluator handles), every card id a lesson names existing, every `read_more` resolving to a real page, every lesson deck building a `GameState`, the unshuffled deal being reproducible **and the default path still shuffling**, every scripted placement landing on a real non-tower slot, the gating hooks answering permissively when inactive, all eight step predicates **driven against a real `GameState`**, progress round-tripping through a sandboxed file, and compendium coverage of every keyword in `Palette.KEYWORD_COLORS`. **Also that every lesson declares an opening hand, that the hand is fully present in its deck, and that it holds the Basics/Stage 1/support/energy its steps actually demand** |
| `TutorialWalkTest.gd` | Drives all 13 battle lessons through the **real Combat screen**, performing what each step asks via the entry points a player clicks, and fails if any step cannot be satisfied. Reports per-lesson rather than a counted total. This is the harness that checks a lesson can be **finished**, not merely that it is well formed |
| `LayoutTest.gd` | 24 assertions on what the UI *draws*: every entry in `Palette.GLYPH` being renderable by the actual theme font, every double-quoted literal across the nine UI source files containing no character the font lacks (comments exempt — their ASCII diagrams are never rendered), all four screens building in **both** the desktop and phone layouts, and — the assertion that matters most — **no phone layout exceeding the 540-unit phone viewport**, measured with `get_combined_minimum_size()` and ignoring content inside a horizontally scrolling container. The glyph half reads the source rather than the running scene on purpose: a label built only in a rare branch — an error state, a disabled button's tooltip — is never instantiated by a smoke test, and those are exactly the strings that ship broken. The overflow half exists because its absence is what let mobile mode ship as pure zoom: every screen *built* fine, which is all the build assertions ever checked |

The Heaven pipeline tests deliberately call `GameState._deal_lane_damage` rather than
simulating the ordering inline — a test that reimplements the rule it is checking proves
nothing about the engine. `TutorialTest` follows the same rule: its step predicates are
checked by mutating a real `GameState` and asking the predicate, never by simulating what
the predicate would see.

**`SupportUITest.gd`'s ~1-in-8 flake is fixed.** The failing assertion was
`enemy tower damaged`: the support always resolved correctly, but the enemy tower sometimes
read 27/52 instead of 25/50 because it had taken a **+2 max HP structure growth** from a
round that elapsed in an earlier section. `_reset()` cleared *your* board and never touched
tower state or the enemy's board at all, so the fixture was dirty rather than the rules
wrong. `_reset()` now restores `tower_hp`, `tower_max_hp`, `tower_mods`,
`tower_damage_bonus` and `earth_max_hp_bonus` on **both** players' boards. Verified over 20
consecutive runs, 0 failures, against a documented ~1-in-8 rate.

The general shape is worth keeping: **a shared fixture that resets only the half a test
happens to look at will fail at whatever rate the other half changes.** The assertion was
correct and the diagnosis wasted time twice because an intermittent failure reads as
non-determinism in the engine rather than as leftover state in the harness.

**`SupportTest.gd` is separately flaky — one failure in ~15 runs on 2026-08-08, not
reproducible afterward and never captured.** The prime suspect is the support-heavy
AI-vs-AI game at the end of the file: it is the only non-deterministic assertion there
(shuffled decks, heuristic AI), and a game that happens to stall or end unusually would trip
it. Worth capturing the output next time rather than re-running until green — an
intermittent test failure is information, not noise.

Run them with:
`godot --headless --path <project> --script res://scripts/core/RulesTest.gd`

**Retreat, support, Tools, tower support, and the hand limit are now built.** All 38
neutral cards from `support.md` are in `data/cards.json`. The engine implements:

- the **retreat** action — spends the printed cost from the unit's own attached energy,
  refunds the remainder to the pool, and returns the whole evolution path to hand, healed
  and locked for one turn. It pays no `Toll` and triggers no `Rise`
- a **one-turn hand lock**, checked by `play_unit`, `evolve`, and `play_support`. Locked
  cards may still be discarded to the hand limit
- a **`support`** card type with an effect list, free and unlimited per turn
- a **`tool`** type: one per unit, carried through evolution, discarded on death **and**
  on retreat
- a **`tower_support`** type: unlimited stacking permanents per tower, all cleared when
  the tower dies.
  `Board` now carries `tower_mods` and `tower_damage_bonus`, so tower damage and max HP are
  no longer constants
- the **hand limit** as step 6 of end-of-turn resolution, with a discard prompt
- a **deck-search picker** — a modal card list driven by a `choice_required` signal, shared
  by search, "discard 2", and the hand limit. The AI and headless harnesses auto-resolve it,
  so nothing hangs without a UI attached
- **AI heuristics** for all of it (`AIPlayer._play_supports`). The AI deliberately holds
  retreat and repositioning cards rather than playing them badly

One rule had to change to make retreat work: **evolving no longer discards the base card.**
It stays under the unit as its `evolution_path` and reaches the discard only when the unit
dies. Without this a retreating Stage 2 would have nothing to return to hand.

**Abilities, `Consume`, and the attack lock are built.** Unit lines are now either
attacks or abilities: a line marked `"ability": true` in `data/cards.json` resolves
immediately, is limited to once per turn per unit, and has its `cost` block ignored — the
only cost it can carry is `"consume": N`, which destroys that much attached energy.
`GameState.use_ability()` is the entry point, and `queue_attack()` refuses abilities
outright so the two paths can't be confused.

Three Hel lines converted, which is also the first use of `Consume` in the game:

| Card | Line | Was | Now |
|---|---|---|---|
| Charnel Colossus | Consume the Fallen | attack, 1 Hel | **free ability** |
| Hel's Chorus | Dirge | attack, 2 Hel | **ability, Consume 1** |
| Hel, Queen of the Unclaimed | Claim the Fallen | attack, 5 Hel | **ability, Consume 2** |

The attack lock is implemented as `Unit.lock_mode` (three-state per unit) plus
`Player.auto_lock_attacks` (global), resolved by `GameState._fire_locked_attacks()` at the
start of each turn after the draw.

**Void is built — three factions now exist.** 15 units, an energy card, 4 supports and a
Tool, implementing `Siphon`, `Void N`, and the `Rift`/Gap pair. `AIPlayer` has Void
heuristics and two sample decks ship (**Starve**, **Widening Rift**). See `void.md`. All 21
cards now carry generated art.

**Setup, the mulligan, and the guaranteed-Basic opening hand are built.** A game opens in
`Phase.SETUP`: both players get a 6-card hand containing at least one Basic, may mulligan
once, and deploy Basics for free before round 1. `GameState.skip_setup()` exists for the
harnesses that place units directly and drive the rules API; the AI-vs-AI harnesses
deliberately do *not* use it, since setup deployment is part of what they measure. Every
main-phase entry point is gated on the phase, and the combat screen's End Turn button
reads "Ready" until both sides have committed.

**Not yet implemented:** targeted attack selection in the UI beyond the friendly
pick that `Consume the Fallen` accepts, and multi-color cost *enforcement*. On that last
point the data is now right even though the rule is not built: `AttackData` parses and
stores which color a cost was printed in, but the pool is a single untyped int so any energy
pays anything. Colorless is counted in the total.

Next steps, in order:

0. **Eyeball the new card frame in a real game.** The layout rework landed with all ten
   harnesses green and the inspector renders correctly, but the harness checks *structure* —
   which nodes exist and what they say — not legibility. The two things only a human can
   answer: whether ~7px board type supports the at-a-glance read, and whether
   hover-to-enlarge lands where you expect it to on the rightmost slot.
1. **Read whether quarter-rate tower fire overshot.** The stall it was adopted to fix has
   not recurred, but the AI mirror fell from ~61 rounds to ~13 — back to roughly the length
   previously flagged as too short. This wants a human playtest rather than another AI
   sample, because the AI presents an empty board far more often than a human would and is
   therefore the worst case for exactly this rule.
2. **Toll Engine is beating everything** — 9-0 vs Barrow Wall, 8-1 vs Lamp Wall, 8-1 vs
   Widening Rift, 5-4 vs Verdict Engine over 9-run samples. It predates Void and is now the
   clearest balance outlier in the game. See `hel.md`.
3. ~~**Card art for Heaven and Void.**~~ **Done** — all 114 cards have emblems, Gaia included.
4. **Walk the tutorial end to end as a player.** All fourteen lessons build and every step
   predicate fires against a real `GameState`, but the harness cannot read *pacing* — whether
   a step's text lands before the board changes under it, whether the coach panel is where
   the eye already is, and whether the gating ever refuses something a reasonable player
   would try at that moment. The nudge on a blocked action is the thing to watch: it is the
   one place the tutorial can feel broken rather than instructive.
5. **Human playtesting.** All four factions and ten sample decks now exist; every balance
   number in these docs is still an AI reading, and the AI does not retreat, does not model
   clearing a board across a volley, and has no Judgment or Sanctuary heuristics.
6. ~~Then **Gaia**, the last of the original four.~~ **Done** — 19 cards in five chains.

---

## For Claude — Keeping This Document Current

**This file is the source of truth for the game's rules.** It is meant to be appended to
and corrected as the design evolves. Treat it as a living document, not a spec handed
down.

### When to update

Update this file **in the same turn** the decision is made — not at the end of a
session, when the reasoning has already been lost. Specifically:

- A rule is **decided** → move it out of Open Questions into the body.
- A rule is **changed** → edit it in place. Don't leave the old version alongside the
  new one, and don't append a changelog entry that contradicts the body.
- A rule is **corrected** — the user says a mechanic works differently than written →
  fix it immediately and check whether anything downstream depended on the wrong
  version. Rules in this game interlock; a change to the energy economy ripples into
  every faction file.
- A **new question** surfaces that can't be resolved now → add it to Open Questions
  rather than picking silently.
- A **number is tuned** → update the anchor tables. Note that the formulas are working
  anchors for playtesting, so they *will* move.

### How to update

- **Record the reasoning, not just the rule.** The "why" is what makes a decision
  reviewable six weeks later. Most sections here have a short rationale — keep that
  pattern.
- **Prefer editing over appending.** A document that only grows becomes a pile of
  contradictions. If a new rule supersedes an old one, replace it.
- **Propagate to faction files.** A core-rules change usually invalidates card text.
  When the energy economy or a formula changes, check `hel.md` (and future faction
  files) for cards that relied on the old behavior.
- **Keep Open Questions honest.** Delete items that get answered. An Open Questions list
  full of resolved items is worse than no list.
- **Flag balance risks as you notice them.** If a card combination looks degenerate
  while writing it, say so in that file's Open Questions rather than quietly nerfing it.
  Tuning is the user's call.

### What belongs where

| File | Contents |
|---|---|
| `CLAUDE.md` | Core rules, economy, formulas, board geometry, turn structure, global constraints |
| `<faction>.md` | Keywords, evolution lines, cards, faction identity, faction-specific balance notes |
| `support.md` | Neutral support cards, the support power band, retreat-manipulation cards |

If a mechanic is used by more than one faction — like `Consume` — it belongs in
`CLAUDE.md`, with faction-specific tuning noted in the faction file.

### Decision log

Append here when a rule is settled after real back-and-forth, so the reasoning survives
even if the rule text later changes. Keep entries to one or two lines.

- **Cards are free to play; energy only buys attacks.** The constraint is acting, not
  deploying. This is the game's core identity.
- **Energy attaches permanently to units, and is consumed only by death or `Consume`.**
  Makes charging a durable investment and big attacks reachable by accumulation.
- **Queueing an attack pulls exactly its cost from the pool.** No overpayment, no waste
  — solves Pokémon's dead-attachment problem while letting energy values scale by turn.
- **Pool decays 20% (min 1) at end of turn; attached energy does not.** Pool is safe from
  death but bleeds; attached is safe from decay but dies with the unit. This two-sided
  risk is the intended skill gap.
- **Charging is a free action** separate from attacking, so partial accumulation toward
  expensive attacks is possible and visible to the opponent.
- **Attacks default to the slot directly across; slots do not compact.** Placement was
  originally the *whole* targeting decision. Both halves of that have since been
  superseded — see the shielding entry for the hole-funnels-to-tower half, and the chosen
  targets entry for placement-as-targeting. Facing remains the default and the fallback.
- **Living units shield their board's tower and throne; an empty slot redirects to the
  leftmost survivor.** Replaced the original "empty slot → tower → throne" fall-through,
  which let a single dead body open a lane to the structures behind it and made losing one
  unit compound into losing the tower. Shielding is per-board — the other board defends
  nothing. Reaching a tower is something you earn by *clearing a board*, not by connecting
  with one attack into a gap. **Chosen targeting did not weaken this**: a named target must
  be a living unit, so picking selects among the wall and never past it.
- **An attack may name any living unit on the board it faces, and the player orders the
  volley.** Replaced placement-as-targeting, which made `Judgment` a coincidence — whether
  a Judgment unit swung after something had softened its target depended on which slots the
  two units happened to occupy, decided turns earlier. Ordering makes the execute a plan.
  Bounded so it costs the geometry nothing: only living units may be named, never
  structures and never across boards, so shielding and the two-independent-fights rule are
  both intact. Targets are validated **at resolution, not at queue time** — early attacks
  kill things, so a queue-time check would either forbid the sequences worth building or
  re-prompt on every death; a stale pick just falls through the existing chain. Both
  features are opt-in: the default order is the old left-to-right scan and an unnamed
  target is the old slot-across, so a player who ignores them sees the previous game.
- **A dead unit cannot be hit again in the same resolution; the attack retargets whole.**
  No overkill and no carry-over — excess damage isn't banked onto the next target, the
  attack simply re-resolves through the targeting chain from the top. This is what makes
  intra-turn sequencing a real decision: land the kills early and the rest of the volley
  falls through to the tower.
- **Two-line rule on every unit** (ability + attack, or two attacks). Forces each card
  to commit to an identity instead of accumulating text.
- **Activated abilities are once per turn.**
- **`Rise` is spent on use** — the returned unit lacks the keyword, but keeps everything
  else (all other keywords, abilities, and attacks) and returns at half HP. Losing only
  Rise is what caps the loop without bookkeeping; keeping the rest is what lets a Rising
  unit pay its `Toll` twice.
- **Hel is organized into subfactions sharing one energy color.** The first is **Toll**,
  where every unit refunds energy on death. Subfactions mix freely in a deck; this is the
  unit of design going forward, not the faction as a whole.
- **Keyword values may be derived from stats rather than authored per card.** `Toll` is
  `HP ÷ 25` rounded down. Derived values are computed at *design time* and printed on the
  card — they never recalculate in play, so buffs and debuffs can't move them.
- **Every rule should have a card that breaks it.** Baselines exist to be violated by
  specific cards; that's the deckbuilding fun.
- **The game is named Godsfall.** Chosen over mechanical names (`Throne Decay`,
  `Charge & Decay`) because the factions are cosmic domains — Hel, Void, Gaia, Heaven —
  and the throne is what remains when they fall. Commits to a cosmology the world can
  be built into, rather than naming a single mechanic.
- **Opening hand 6, draw 1 per turn.** Midpoint of the prior 5–7 working range, picked
  so the prototype could be built. Explicitly a tuning dial, not a settled rule.
- **Retreat returns a unit to hand, not to a bench.** There is no bench in this game, so
  Pokémon's switch has nothing to switch to. Returning to hand makes retreat a real
  decision — you keep the card but surrender the slot.
- **Retreat is paid from the unit's own attached energy; leftover attached energy returns
  to the pool.** This is the only non-death way energy comes off a unit, and it makes a
  heavily-charged unit *cheaper* to extract in real terms even though the cost is fixed.
- **`Retreat = HP ÷ 40`; `Toll` stays `HP ÷ 25`.** They shared `÷ 25` originally, for the
  good reason that one derived number per card is easier to read than two. The reason it
  had to change: at `÷ 25` a Stage 2 needed 4 attached energy before it could leave at all,
  so retreat was priced out of existence on exactly the bodies worth retreating — and the
  Stage 2 buff to 100–175 would have pushed the worst cases to 6–7. Splitting the divisors
  also produces a better decision than the shared one did: retreat is now systematically
  *cheaper* than the Toll refund, so saving a body is the affordable line and feeding it to
  the discard is the deliberate one, rather than the two being interchangeable.
- **The whole HP curve was raised: Basic 40–90, Stage 1 80–120, Stage 2 110–175.** At the
  old numbers (~50 / ~70 / ~90–110) a 5-energy attack was most of *any* body's health, so
  two exchanges killed almost anything and evolving read as a marginal upgrade. Bigger
  bodies make a kill take a real volley, so boards persist across turns and combat has
  something to interact with. Done in two passes — Stage 2 first, then Stage 1 once the gap
  between the stages turned out to be the same problem one rung down. The damage anchors
  deliberately did *not* move, which is what makes this a lengthening rather than a wash;
  whether they should is now an open question, because `4 energy = 50` no longer exactly
  kills a fresh Basic. Adopted partly to blunt Heaven, which it may not do — Heaven's
  reprieves all scale with HP. Both logged as open questions rather than assumed.
- **HP bands overlap between stages on purpose.** A 90 HP Basic and an 80 HP Stage 1 coexist
  because stage is not a power ranking by itself: a Basic that big has paid for its size in
  attack cost or text (`Charnel Colossus`), and a small Stage 1 is buying utility instead of
  a body (`Court of Bells`, the Judgment reset engine, deliberately left at the band floor
  so the faction's build-around stays killable).
- **A retreating evolved unit brings its whole evolution path back to hand.** Generous on
  purpose: saving units doesn't win games, it only removes a shield. The thinned board and
  the rebuild turns are the real cost.
- **Retreated cards are locked in hand for one turn.** Without the lock, retreat is a free
  full-heal reset every turn; with it, retreat costs a turn of board presence.
- **Retreat does not trigger `Toll` or `Rise`.** The unit didn't die. Hel chooses between
  the refund and the card, never both.
- **A support card may cost 1–3 pool energy; most cost 0.** The sanctioned exception to
  *energy only buys attacks*, and it exists for one reason: cost is the cleanest axis for
  printing **two versions of the same card**. The free one carries a restriction, the
  priced one drops it, and which you run is a real deckbuilding decision instead of a
  power ranking. Bounded so it stays an exception — capped at 3, paid from the pool (so it
  competes with attacking that turn), never on units, never on Tools or tower support
  (already discounted for other reasons), never sold as pool energy, and never at attack
  rates for damage. A priced support may sit above the power band by roughly one step per
  energy, which is the room the cost buys.
- **No card may fully heal a unit.** Every heal is a flat number, never "restore to max"
  and never a fraction of printed HP. A heal that scales with its target is unpriceable —
  the same card is worth 20 on a Basic and 110 on the Queen, and it gets stronger for free
  every time a bigger body is printed. Flat numbers also make big heals overflow and go to
  waste on small bodies, which is what makes the expensive ones a real choice instead of a
  strict upgrade. Cost `Last Breath` its full heal (now a flat 50) and `Grave Warden's
  Oath` its (now a flat 100). Guarded by a test.
- **Healing is the reference ladder for priced supports: base 20, +30 per energy.**
  `Shore Up` 20 free, `Field Surgery` 50 for 1, `Grave Warden's Oath` 100 for 3. A free
  card can reach the same +30 by taking a condition instead of a cost, which is what
  `Last Breath` does at 50-if-below-half. Healing went first because "how much" is a
  number that moves without changing what the card does.
- **Support is a single card type with no item/supporter split and no per-turn limit.**
  Pokémon's split exists to gate overtuned cards; the alternative is to tune every support
  to the same band and let hand size be the cost. One draw per turn is the real limiter.
- **Maximum hand size 10, checked at end of turn.** End-of-turn rather than continuous, so
  a draw support from a near-full hand still draws its full amount — a continuous cap would
  make draw cards silently fizzle. The limit is a ceiling normal play never touches; its
  only job is taxing stacked draw and making repeated retreats self-limiting.
- **Permanent tower supports stack without limit on a single tower.** Replaced the original
  one-slot cap. Stacking is more expressive and makes fortification a question of *how
  much* rather than a binary, and the 4-copy deck limit still bounds it. Explicitly not
  the Tool rule: a Tool is a bet on a body that dies constantly, while a tower is fixed
  and worth deciding how far to commit to. This raises the stall risk the design docs
  already flag, and `CLAUDE.md` had already named the right dial if it shows up — a
  deck-level cap on how many permanent tower supports a list may run, not weaker cards.
- **Tower support cards modify a tower you control.** Answers the
  long-open tower-upgrade question. Hard line: **no tower support may raise the rate at
  which a tower hits structures** — a structure that could threaten the throne at full
  rate would make units irrelevant. Cheap because self-limiting: a tower you keep alive is
  a lane slot you don't get to use. Originally worded as "no tower support may let a tower
  reach the throne"; the quarter-damage rule below moved the constraint from reach to rate
  without changing what it protects.
- **The AI plays a random legal deck, never a mirror of yours; deck select can pin one.**
  Combat and both AI-vs-AI harnesses used to deal the *same list* to both sides, which
  makes every fight a test of play rather than of decks — the opposite of what a
  deckbuilder is for, and structurally incapable of surfacing a matchup problem no matter
  how many times it is run. Random is the default because a session should be a spread of
  matchups; the explicit pin exists because testing one specific pairing is exactly what
  balance work needs. Same-deck pairings are allowed to come up by chance rather than
  excluded: the draw is uniform, and forcing distinctness would bias the sample away from
  every pairing that includes the player's own deck. The setting is per-session and
  unsaved — it describes the next fight, not the collection.
- **Finished games append to `logs/battles.log`: matchup, structures, and damage by card.**
  Every balance number in these docs is a single AI sample transcribed by hand off a
  console scroll, which is why they are all hedged. An append-only file makes them
  countable instead. Damage is attributed only where a *source card* is known, and tower
  fire is totalled apart from the card table — it belongs to no card, it is large in long
  games, and letting it into the table would swamp the thing the table is for. Never
  raises on a write failure: a balance log that can break a game or fail a test suite is
  worse than no log.
- **`DeckStore.new()` returns an empty store, and `seed_samples()` is the fix.** `_ready()`
  does not run for a bare instance, so a locally constructed store has *no decks* — and it
  fails silently, with `name_at()` returning `""` and `list_at()` returning an empty list.
  The random-deck harnesses hit exactly this and produced a game between two empty-named
  decks that still passed every assertion. The general shape is the same one already
  logged for `CardDB`: **an accessor that returns empty on an unloaded object turns a
  load-order mistake into plausible-looking data**, so the load has to be an explicit call
  rather than a lifecycle hook the caller may not trigger.
- **A tower whose facing board is empty hits that board's structures for a quarter of its
  damage** (floor, min 1), following the same tower-then-throne chain as everything else.
  Replaces "towers only attack units, they cannot hit the throne." The reason that
  absolute had to go: an empty board took *zero* pressure, so combined with unit shielding
  neither side could reach the other's structures late, while the throne grew +5 max HP
  every turn unconditionally — the formal stall in Open Questions. A quarter rather than
  full because full rate is the two-structures-racing degenerate case the original rule
  existed to prevent; chip makes an empty board cost something without becoming a clock a
  player can win on without units. Crossfire follows the same chain, which is the one
  restriction the rule deliberately loosened.
- **Randomness is the preferred brake on search and recursion.** A random pull from a
  restricted pool beats a board condition or an exile clause: it costs nothing to read,
  can't be gamed, kills recursion loops on its own, and turns the card into a deckbuilding
  decision — narrow decks pull reliably, wide decks gamble. Chosen search is reserved for
  Basics (too weak to matter) and for cards that pay a full turn of delay.
- **Tools are supports that attach and persist, one per unit.** Priced below one-shot
  supports because they pay out repeatedly — a Tool should need 3–4 turns to match what a
  one-shot does immediately. They're discarded on both death and retreat, so a Tool is a
  bet that the body survives.
- **Support cards obey the 4-copy limit.** Energy is the only exempt type — exempting
  supports too would turn the deck into a combo engine.
- **Drag-and-drop is an input method, never a new rule.** Cards can be dragged from hand
  to deploy, evolve, or charge, but units cannot be freely dragged between slots — that
  would make the `Reposition` support card worthless and quietly delete the rule that
  placement *is* targeting. Dropping energy on a unit is a shortcut for two existing
  legal actions (play energy, then charge), not a third one.
- **Decks are exactly 60 cards, and an off-size deck cannot be taken into a fight.**
  Replaces the original "up to 60". A fixed size means an opening hand of 6 and one draw
  per turn represent the same fraction of the deck in every game, so the energy ratio a
  player picks is a genuine deckbuilding decision rather than something they can sidestep
  by running a 40-card list. Enforced in `DeckStore.errors_at()`, which is what the deck
  select screen's Fight button reads, so the rule is checked in one place rather than at
  each entry point. `MAX_DECK` was renamed `DECK_SIZE` because "max" no longer describes it.
- **The player keeps multiple named decks and chooses one before each fight.** Deck
  select sits between the menu and combat rather than combat reading one global deck,
  so trying a new list doesn't mean destroying the old one. `DeckStore.deck` stayed as
  the active deck's card map so the builder, combat, and the test harnesses needed no
  changes. The last deck can't be deleted — there is always something to edit.
- **Evolving does not discard the base card.** It stays under the unit as its evolution
  path and goes to the discard only when the unit dies. Forced by retreat: a Stage 2 has
  to have its Basic and Stage 1 *somewhere* to return them to hand, and the discard is the
  one place they must not be. Death behaviour is unchanged — the whole stack is discarded.
- **Effects that need a choice go through one `choice_required` signal.** Deck search,
  "discard 2", and the hand-limit prompt are all the same interaction: pick N of these
  cards. One modal picker serves all of them, and callers with no UI attached (the AI, the
  headless harnesses) auto-resolve rather than hanging, so the rules engine stays testable.
- **Card data lives in `data/cards.json`, not in GDScript or `.tres`.** Hand-editable,
  diffable, and scriptable from these design docs; keeps the rules engine free of card
  text. `CLAUDE.md` and `hel.md` remain the source of truth — the JSON follows them.
- **Inspecting a card and adding it are separate gestures.** The deck builder row opens the
  inspector; `+`/`−` edit the deck. Click-to-add meant you could not read a card without
  also committing to it, which is backwards for the screen where you are deciding.
- **The inspector shows the real `CardView`, scaled, not a bespoke large card.** One
  renderer means the card cannot read differently in the builder than it does in play — a
  second one would drift the first time either changed.
- **The deck side of the builder is a grid of card frames; the collection stays a text
  list.** They answer different questions — the collection is an index you search by name,
  the deck is a thing you judge by its shape — so they get different shapes. The grid is
  one tile per *distinct* card with a ×N count, because 60 identical thumbnails hide the
  card you were looking for.
- **The test harnesses must never write the player's save file.** `DeckStore.save_path` is a
  variable and every harness calls `use_sandbox_path()`. Found the hard way: the tests wrote
  the real `user://decks.json`, so running them wiped the saved collection and left behind
  fixture decks named "Deck A"/"Deck B". A test that shares a mutable resource with the user
  is a data-loss bug, not a test-hygiene nitpick. **Sandboxing the autoload is not enough** —
  a bare `DeckStore.new()` inside a test starts with `save_path` pointing at the real file, so
  every locally constructed store needs its own `use_sandbox_path()` too. `SupportTest` had one
  and spent a while writing its fixture — a deck named "T" holding 4 `Gravekeeper's Ledger` —
  straight over the player's collection.
- **New sample decks are backfilled onto existing saves, by name, append-only.** Samples used
  to be laid down only on *first* run, so a player with a save never received decks shipped
  later — Heaven's two lists were invisible to anyone who had already played, and the bug
  reads as "why can't I see the decks" rather than as anything to do with saving.
  `DeckStore._add_missing_samples()` appends any sample whose name is absent on load. It is
  deliberately **append-only and never reconciles contents**: a deck whose name matches a
  sample is left completely alone even if it has been gutted, because the alternative is
  overwriting a player's edits to a deck they happened to name onto a sample's name. Failing
  to deliver a new deck is a nuisance; deleting someone's deck is data loss, and the two are
  not close enough to trade off.
- **A spent one-shot keyword must visibly disappear from the board.** `Judgment`,
  `Sanctuary`, and `Rise` are charges the player spends, and the rules engine tracked all
  three correctly from the start — but `CardView` rendered `CardData.keyword_line()`, which
  reads the *printed* card and therefore never changes. A unit that had spent its Judgment
  still displayed "Judgment 30". The mechanic was correct and **invisible**, which to a
  player is indistinguishable from broken: on a keyword whose whole design is *one charge,
  decide when to cash it*, a board where you cannot see which units still hold a charge
  makes the decision impossible to make. `CardView._live_keyword_line()` now filters spent
  keywords and shows `Sanctuary N`'s *remaining* pool rather than its printed value. The
  printed card is untouched — the deck builder and inspector still show what the card says,
  which is correct for a reference view and wrong for the battlefield.
  **The general rule: state the rules engine tracks per-unit has to be visible per-unit.**
  If a keyword's value changes during play, the board must render the live value, not the
  print. Guarded by assertions in `HeavenTest.gd`.
- **UI must read the faction list from `CardDB`, never hardcode a colour.** The deck builder's
  collection pane hardcoded `"hel"` in two places, so when Heaven shipped **its cards were
  absent from the builder entirely** — they existed in `data/cards.json`, loaded fine, played
  fine in headless games, and simply could not be added to a deck by hand. Nothing failed and
  no test caught it, because every harness drives the rules engine rather than the collection
  list. The lesson is narrow and worth keeping: *content that only appears through a UI needs
  a check that the UI actually enumerates it.* The builder now derives its faction filter from
  the database, so a new colour appears the moment its cards land.
- **`CardDB` loads its data on demand, never on `_ready()` ordering.** Autoload `_ready()` order
  is not a contract callers can rely on: `DeckStore` read the card database while its own
  `_ready()` ran, got an empty `_cards`, and `_sanitize()` concluded that every card id in the
  save had been deleted from the game. That alone was survivable, but the next `add()`/`remove()`
  called `save_decks()` and wrote the emptied deck over the file — turning a load-order glitch
  into permanent data loss. Two guards now: `CardDB._ensure_loaded()` on every public accessor,
  and `_sanitize()` refusing to drop anything when the database is empty. The lesson generalizes
  — **a read path that silently discards data must never feed a write path.**
- **The starter collection is four decks with distinct identities, not one catch-all deck.**
  A list holding one of each card teaches nothing — there's no plan to read and no reason to
  prefer one line over another. Four one-idea decks (Toll Engine, Barrow Wall, Rise & Recur,
  Cacophony Ramp) are legible from the list alone and beat each other in different ways, so
  the starter collection doubles as documentation of what the faction can do. Each carries
  15–19 supports, because a unit-only deck never sees half the game's decision space.
- **Card art is generated by a script, not hand-drawn files.** `tools/make_card_art.py`
  draws one emblem per card in code, the same way `make_icon.py` draws the app icon.
  Regenerable means the art can't drift from the card list, and a palette change
  propagates to all 95 images in one run. They are symbolic — a shape that matches the
  *name* — because the art box is 74px and an illustration would be mud at that size.
  **The 74px read is the binding constraint, not the 128px one**: several Heaven and Void
  emblems were legible in the inspector and mush on the board, and every one of them failed
  the same way — a figure competing with its own props for the silhouette. The fix each
  time was to drop the props and let the *one* thing the card is about own the shape.
- **A card with no art falls back to its initials.** Art is optional so that adding a
  card to `data/cards.json` is never blocked on drawing one, matching the same
  ship-the-data-first pattern retreat costs used.
- **Activated abilities are free; `Consume` is the only cost one may carry.** Energy only
  buys attacks, and an ability is not an attack. Enforced in the data rather than by
  convention: a line marked `"ability": true` has its `cost` block ignored entirely, so a
  card cannot price an ability by filling in the wrong field. The distinction earns its
  keep because an attack's cost is an annuity — paid once, free every turn after — while a
  Consume charges every single use, which is what keeps a once-per-turn ability from
  becoming a permanent no-cost engine.
- **Dirge costs Consume 1 and Claim the Fallen costs Consume 2.** Both were attacks whose
  energy cost was their only brake, so converting them to free abilities would have been a
  large silent buff — Dirge doubles every Decay on the board *permanently*, and Claim
  refills the board every turn. Consume keeps them free of the pool while making them
  charge each time. Consume the Fallen converted to a **free** ability, which is what
  `hel.md` already wanted: sacrificing a unit is a non-damage cost and belongs on an
  ability line.
- **The attack lock is a convenience, never a rule.** It re-queues only attacks the player
  could have queued by hand, through the same code path, and what it queues can be
  cancelled. Per-unit overrides are three-state rather than a checkbox because "unlock this
  one card" has to survive the global toggle being switched on — that is the entire point
  of the individual override. Abilities are deliberately excluded from it: some destroy
  attached energy, and auto-burning an investment the player was holding is exactly the
  kind of decision a convenience must not make for them.
- **Printed values may ship ahead of the mechanic that uses them.** Retreat costs were in
  `data/cards.json` and on `CardData` for a while before the retreat *action* existed, so
  the cards read correctly and the data was already right when retreat was built — which
  it now is. While that gap was open the inspector labelled it "not yet implemented", so a
  card never promised something the engine could not do. Keep that pairing: ship the
  printed value early, and say plainly in the UI that it does nothing yet.
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
  principle #2 at a third time scale. Restored only by returning the card to hand, which
  is why `Rise` + Judgment is the faction's stacked-reprieve combo.
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
  documenting rather than building.
- **`Windfury` is shared, and may never appear on a unit holding or granting Judgment.**
  Two attacks is two execute checks, and on a reset card it collapses the execute/recharge
  rhythm into a single turn. Tempest keeps multi-attack as an identity by printing it
  widest and cheapest rather than exclusively. Documented but not yet implemented — no
  card uses it.
- **Heaven's closer breaks the shielding rule on purpose, in proportion to kills.**
  `The Gate Opens` reaches the throne past living units, which `CLAUDE.md` otherwise
  forbids — but only at 15 per enemy unit killed that turn, so it is a *reward for
  clearing* rather than a bypass. Without it Heaven is the deck that never loses and never
  wins: three stacked reprieves and no way to convert durability into throne damage.
- **Void's signatures are `Siphon` and `Void N`, and Siphon *takes* rather than destroys.**
  Void is the anti-hoard predator the faction table had no home for, and it interacts with
  the energy economy rather than with bodies — the one axis no other faction touches.
  Siphon moving energy onto the Void unit (instead of destroying it) is what makes the
  faction fund its own expensive attacks without a second ramp mechanic, and it puts the
  stolen energy on a fragile body that can die holding it, which is the self-cost that
  keeps denial from being purely subtractive. Denial hits *attached* energy, not the pool,
  because attached energy is the investment the player chose — pool destruction exists
  only as a printed rule-breaker. Full design in `void.md`; no cards authored.
- **Void's payoff is `Rift N` reading a global `Gap`, and Siphon is designed to fall off.**
  Three phases: Siphon starves early (1–2 energy is a large fraction of a turn-3 board),
  Rift pays in the midgame off the Gap that early siphoning built, and pool-destruction
  rule-breakers close late. Siphon is never nerfed — `t + 1` income outgrows it for free,
  which is the cheapest possible way for a mechanic to expire. The unresolved number is
  Rift's scaling: as a raw multiplier it reaches +60 damage at an ordinary midgame Gap, so
  either the multiplier stays at 1, or the printed number becomes the cap instead. Logged
  as the faction's first open question rather than guessed at.
- **Void shipped: 15 units, `Siphon`/`Void N`, and a deliberately uncapped `Rift`.** Rift is
  a per-card scaling multiplier (+N damage per point of Gap) with no ceiling, because
  reaching a large Gap *means* having staked that much energy on bodies that can all die at
  once — winning from there is the payout, not a failure. Rift attacks pay 8 damage per Rift
  point off their printed base, which prices the keyword existing rather than its tail, and
  only one card prints `Rift 2`.
- **A flat damage cut is the wrong lever for a scaling mechanic.** Rift base damage was cut
  (8 → 11 per point) on the strength of an AI sample, then reverted. Two reasons, both worth
  keeping: the cut landed in the wrong place — at Gap 30 it moved a card from 42 damage to
  39 (noise) while at Gap 0 it moved 12 to 9 (a 25% cut), taxing the early game where Void is
  weakest — and the sample that prompted it was an artifact. `AIPlayer` banks its entire pool
  onto one unit every turn, which for every other faction is a harmless hedge but for Void is
  *the payoff engine*, since the Gap is attached-energy-minus-theirs. The AI was playing a
  maximal Rift strategy by accident and reaching peak Gaps of 231. **AI results are worth
  less for Void than for any other faction**, and the real fix is to stop the AI dumping its
  whole pool.
- **The Gap is `mine - theirs`, and the arithmetic decided that, not taste.** `Siphon` MOVES
  energy from an enemy unit onto one of yours, lowering their total and raising yours. Under
  the opposite definition every successful Siphon would *shrink* the number Void's own payoff
  cards read — the faction's primary keyword turning off its own payoff. Floored at 0 so a
  card promising a bonus can never quietly deal less than printed.
- **Siphon on a support goes to the pool; on a unit it goes onto the body.** A support has no
  body to carry stolen energy. The split is load-bearing rather than a wrinkle: pool energy
  is safe from unit death but exposed to decay and **does not feed the Gap**, so support
  Siphon is ramp while unit Siphon is ramp *and* Gap. That is what keeps units at the centre
  of the faction instead of the support suite doing the work.
- **Energy denial obeys the same targeting chain as damage.** Siphon and Void N pick their
  victim by slot-across-then-leftmost, and never fall through to a tower or throne. Denial
  must never reach somewhere an attack could not, or shielding stops meaning anything.
- **Gaia's `Earth` is a live board-wide aura, not a permanent accrual.** The first sketch had
  Earth adding max HP and damage into the towers every turn, forever. That is an *engine* for
  the tower-stall failure this file already names as its most urgent open question, and it has
  no counterplay — damage already banked cannot be undone. Making the aura a live sum of Earth
  on living units means killing an Earth body shrinks it immediately, towers included, so the
  faction's own board is its only defence and the opponent's removal is the answer. It also
  gives the faction one idea that covers offense, defense, structures, and counterplay at once,
  which is why Gaia needs no third mechanic.
- **The aura is linear at +1/+1 per Earth, and cards may only break the rate additively.** The
  aura applies to four units and two towers, so a multiplier on the Earth *total* is
  exponential across six things — at 10 Earth a doubling card is worth +60 stat points.
  Additive rate-breakers (*"Earth grants +2 instead of +1"*) keep the same linearity the rest
  of the mechanic has, and the rate being the sanctioned rule-breaker is principle #1 pointed
  at the faction's own build-around axis.
- **Earth growth is card text, not keyword text.** The keyword defines the aura only; cards
  gain Earth however they print it — on attack, on being damaged, from an ability, or derived
  live from attached energy. Same arrangement as Hel's `Toll`: one printed number, wildly
  different cards exploiting it. Trying to fix a single universal growth trigger would have
  forced the faction into one shape.
- **`Essence N` spends *pool* energy on a death to move the dying unit's Earth and attached
  energy to the nearest friendly unit on the same board.** The structural mirror of `Toll` —
  same trigger, opposite direction — and it is why Gaia is the only faction with a reason to
  hold pool energy *defensively*. It is the deliberate exception to *attached energy is lost
  when the unit dies*, and it is priced rather than free: the energy must have been banked in
  advance, so a board wipe still lands because you can only afford one or two funerals. Gaia
  has no ramp, which is what makes carrying the energy forward necessary rather than greedy.
  Per-board and never crossing, because crossing would make Essence best at exactly the moment
  it should fail — when the board it defended has been cleared.
- **`Rise` restores the card, not the history.** Settled while working out Rise + Earth: a
  risen unit benefits from the aura like any living unit, but its own Earth resets to the
  printed value and anything it *grew* is lost, exactly as attached energy is. The alternative
  makes Rise plus an Earth-growth card an engine — die, keep the accumulation, return, grow
  further. `Unit.make_risen()` already rebuilds from `CardData`, so the rule and the engine
  agree without special-casing.
- **`Resist X` is a shared keyword, chosen per card for flavour.** Reduce each incoming
  instance by X, minimum 1 damage. The floor is not optional: without it a `Resist 5` body
  makes Hel's `Decay 5` do literally nothing forever, and *"my entire keyword does nothing"* is
  the worst outcome available. It is the deliberate inverse of `Sanctuary N` — Sanctuary is a
  depleting pool weak to chip and strong against burst; Resist is per-instance, strong against
  chip and weak to burst. Deliberately **not** part of any faction's identity, Gaia's included:
  the shared keyword list exists so any card can reach for flavour.
- **Cards are laid out like Pokémon cards, in one layout rendered at two sizes.** HP
  top-right, an explicit evolves-from strip, a banner for abilities, cost icons inline with
  each attack, retreat bottom-right. The frame follows a card game players already know how
  to read, and each position was chosen for a reason the rules supply: HP is the number
  checked most often and fastest, so it gets a fixed corner; evolves-from decides whether a
  card in hand is playable *at all*, so it stopped being a suffix on the stage badge; the
  ability banner is the visual form of a real rules distinction (abilities resolve
  immediately, once per turn, free except for `Consume`, while an attack is queued and pays
  an attached cost that is free forever after); and cost beside the attack removes the
  row-matching step the old bottom-of-card pip block forced on every two-attack unit.
- **The board card keeps its 132×196 slot and hover-enlarges rather than dropping rows.** A
  trimmed board layout was the obvious alternative and was rejected: a card that reads
  differently in hand and on the board is the drift `CardView` exists to prevent, and it is
  the same reasoning that made `CardInspector` scale a real `CardView` instead of drawing
  its own large card. Growing `BOARD_SIZE` instead would have cost ~88px of vertical budget
  across two board rows, which `Combat` spends on the throne, the pool bar and the hand.
  Small type plus hover-to-enlarge keeps one layout, one slot size, and one renderer.
- **Weakness and resistance are printed as reserved em-dashes before the system exists.**
  The footer draws both slots and the inspector says plainly that neither does anything.
  Same pattern as retreat costs, which sat on cards for a while before the retreat action
  was built: shipping the printed value early means the frame does not need re-laying-out
  when the rule lands, and saying so in the UI means a card never promises something the
  engine cannot do.
- **`CardViewTest.gd` loads `CardView` by path, not by class name.** Under `--script` the
  test compiles *before* autoloads register, and `CardView.gd` references the `Palette`
  autoload — so naming the class drags in an identifier that does not exist yet and the
  whole compile fails with `Identifier not found: Palette`. Verified by probe rather than
  assumed. The cost is that `CardView.Mode` is unreachable too, so the enum values are
  mirrored as `MODE_HAND`/`MODE_BOARD` constants behind one `make_view()` helper, which is
  where a reordered enum would break instead of in every test.
- **Towers are silent in round 1, then fire 5 and scale +3.** Under `5 × round` a tower
  fired at the end of the very first turn, into a board nobody had had a chance to deploy
  onto — so the game's opening action was structural chip damage, landing hardest on P1,
  who presents a board first. A grace round costs the tower race one 5-damage shot and
  buys every deck a turn to put a body down. The `+3` curve replaced `+5` because at `+5`
  the tower one-shot a Basic by round 8 and a Stage 2 by round 14, at which point the
  units stopped being the game; `+3` keeps the eventual forced tempo while leaving the
  midgame to the cards. The first shot is deliberately a flat 5 rather than the curve's
  value, so the tower's opening number is legible and matches the 55 HP it has grown to.
- **Structure chip went from a quarter to a half, as part of that same set.** The quarter
  was priced against fast tower scaling and against structure growth that was accidentally
  double; with both corrected, a quarter would have left an empty board taking 2 a round
  in the early midgame while the structure behind it grew +5 — chip that loses to the
  growth it is supposed to pressure. All three numbers were tuned together and should be
  read as one change, not three.
- **Structures grow +5 once per round, not once per player turn.** `grow_structures()` was
  called from `end_turn()`, which runs twice a round, so every throne and tower in every
  game had been gaining **+10 a round** while this file, every balance note, and the stall
  analysis all assumed +5. Not a tuning decision — a defect, and the largest single
  contributor to the throne outgrowing the available damage. The general shape is one this
  log already carries twice: **a per-round rule implemented in a per-turn hook is silently
  double**, and nothing catches it because both numbers look plausible in a log.
- **Both players deploy Basics before round 1, and the opening hand guarantees one.** The
  first turn was otherwise spent on the one move every deck makes identically, and P1 spent
  it presenting a board to a tower P2 did not yet face. Setup is deployment-only and
  Basics-only: energy at setup would make the first energy card worth 1 instead of 2 and
  quietly reshape the income curve, and supports would resolve before there was a board to
  affect. The guaranteed Basic is a **deal filter** — reshuffle and re-deal, never search a
  Basic to the top — so a hand with no legal first action can't happen while the rest of
  the hand stays as random as the deck makes it.
- **The mulligan is free, once per game, and resolves during setup.** No card-loss penalty
  (Magic's draw-7-bottom-1) because the opening hand is already only 6, the guaranteed
  Basic removes the disaster case a penalty guards against, and a 5-card opener against a
  scaling tower is a far steeper punishment here than in a game without one. Setup-only
  rather than first-turn, so the decision is made on the hand alone rather than after the
  board is committed.
- **Gaia shipped: 19 cards in five evolution chains, and the faction pays for its aura by
  printing below the damage curve.** ~9 damage per energy on Earth-carrying bodies against
  the standard 12, because **the aura is the damage** — every point of Earth is +1 on every
  attack from every unit *and* both towers, so a board at 8 Earth adds 8 to six sources.
  Each chain is one idea (auto-fire, energy-into-Earth, growth, Retribution walls, Essence)
  rather than a spread, the same reasoning the four Hel starter decks were built on. Two
  chains stop at Stage 1 deliberately: five distinct ideas at 13 units beats three chains of
  three with two ideas fewer.
- **Makeshift Tower is the sanctioned rule-breaker on *energy only buys attacks*.** It
  attacks free at end of turn, and it pays for that by being a **unit** — a real tower is
  unreachable until its board is cleared, while this one can be named by any attack the turn
  it lands. That trade is the whole card, and it is why the chain's damage stays low and the
  Earth on it is the reason to run it. Flagged as the faction's largest untested number:
  auto-fire reads the aura, so the Stage 2 on a 12-Earth board fires 32 a turn for free.
- **`Unit.max_hp()` stays the printed value; the Earth aura lives on `GameState`.** A
  `Unit` has no reference to its owning `Player`, and the aura is a sum over every unit that
  player controls — so giving `Unit` an owner would have forced one through every
  construction site in the game and all eight harnesses, for a reference cycle's trouble.
  `GameState.effective_max_hp(p, u)` is the aura-adjusted ceiling and callers that care use
  it. Exactly how `Rift` already works: the printed stat on the card, the board-wide term on
  `GameState`. **A tower is the exception and had to be**: tower max HP is *stored* state
  rather than computed, so `Board.earth_max_hp_bonus` tracks how much of it the aura granted
  and `sync_tower_aura()` re-applies idempotently. Compute where you can, track where you
  must.
- **Every unit silently dropped its `effects` list.** `CardData.from_dict` parsed `effects`
  inside the non-unit branch and returned before units reached it, so a unit could print any
  effect at all and the value would parse cleanly and never arrive. Found while building
  Gaia, whose `earth_from_attached`, `earth_rate`, and `auto_fire` are all unit effects —
  every one of them would have been dead on arrival. Same shape as the Heaven cost bug
  logged below: **a parser branch that serves one card type silently zeroes the others**,
  and nothing fails, because absent data reads as "the card didn't ask for it."
- **A harness that crashes mid-run reports `0 failed` and exits 0.** `GaiaTest` spent
  several rounds of this session reporting success while running 7 of its 40 assertions:
  `Player.gd` references the `CardDB` autoload, which does not exist under `--script`, so
  **any harness that annotates a variable as `: Player` fails to compile** — and compilation
  precedes `_initialize()`, so no runtime bootstrap can rescue it. `VoidTest` survives only
  because it happens to use zero such annotations. The failure is invisible because an
  assertion that never *runs* cannot fail. `GaiaTest` now pins `EXPECTED_ASSERTIONS` and
  fails when the count is short, and **all eleven harnesses now carry the same guard** — the
  bug that hid this one would hide the next, and the guard costs one constant per file.
  **The general rule: a green test suite is only evidence if you know how many assertions it
  was supposed to run.** When adding or removing assertions, update `EXPECTED_ASSERTIONS`
  deliberately — a guard you edit reflexively to match whatever ran is no guard at all.
- **Every Heaven attack had been costing 0 since Heaven shipped.** `AttackData.from_dict`
  read `cost.get("hel", 0)` while Heaven's cards printed `{"heaven": N}`. Found while adding
  Void's cost blocks. The parser now reads whichever color key is present and stores which
  one it was. The general lesson: **a data format that hard-codes one valid value silently
  zeroes every other one**, and the tests could not catch it because no assertion compared a
  card's printed cost against what the engine charged.
- **The game ships to the web from a `gh-pages` branch, never from `docs/`.** GitHub Pages
  can only serve a branch root or `/docs`, and `docs/` was already the designated home for
  plans and specs — serving from there would have published them and left the design
  documents one stray `--export` away from being overwritten by build output. A branch that
  holds nothing but the build means the two can never share a file, and it keeps a 39MB
  wasm regenerated on every export out of the source history. The repo is **public**
  because Pages cannot serve a private repo without a paid plan, which is the same reason
  Battlemage is public.
- **The web export must stay single-threaded.** `variant/thread_support=false` is not a
  performance choice: a threaded Godot build requires COOP/COEP response headers, and Pages
  serves static files with no way to set them. The failure mode is the trap — the build
  exports cleanly, deploys cleanly, and then refuses to start in the browser, so nothing
  upstream of the user ever reports a problem.
- **`res://` is read-only in an exported build, so `BattleLog` writes to `user://` outside
  the editor.** The balance log wrote to `res://logs/battles.log` via `globalize_path`,
  which is a real folder under the editor and a path inside the packed `.pck` once
  exported. Because the writer deliberately never raises — correct, and documented above —
  every web game would have silently logged nothing. **A failure path designed to stay
  quiet needs its assumptions checked whenever the platform changes**, precisely because it
  will not tell you when they stop holding.
- **The viewport is clamped to a minimum design size rather than switching stretch mode.**
  `stretch/aspect = "expand"` gives the viewport the window's real aspect at 1:1 and
  deliberately does not scale — right on a desktop, where a wider window should mean more
  room rather than bigger cards, and fatal on a phone, where it means the viewport is
  genuinely 390 units wide against a combat screen needing ~1180. Nothing was scaled down;
  the board and the log panel were simply off-screen with no way to reach them. Switching
  the project to `aspect = "keep"` would have fixed mobile and regressed the case that
  actually gets played, letterboxing a real monitor back to 1440×900. `ViewportFit`
  instead keeps `expand` and raises `content_scale_size` to whatever is needed for the
  layout to fit, so a narrow window gets a scaled-down viewport that still holds the whole
  UI while a large one keeps today's native behaviour untouched — at 1440×900 the clamp is
  inactive and the reference size is the window, which is what expand computes anyway.
- **Combat stacks its columns below 820px wide instead of shrinking them.** The battlefield
  has a hard minimum width — six 132px board slots — so side by side with the 320px
  action/log column there is nothing left to give on a phone. Stacked, the log becomes a
  drawer behind a header button: it is the one thing on that screen that is *reference*
  rather than interaction, so it is what yields the vertical budget. The action panel
  stays, because charging and queueing attacks are how the turn is played. Crossing the
  threshold (rotating a phone) rebuilds the screen wholesale rather than re-parenting —
  the two shapes differ in more than parentage, and the game lives in `gs` rather than in
  the nodes, so a rebuild costs a frame and cannot leave a stale mix of the two.
- **The web page's shell is a `head_include` file, never a `custom_html_shell`.** A full
  shell means forking Godot's boot script and re-merging it by hand on every engine
  upgrade; `tools/web-head.html` is purely additive, so an upgrade cannot break it. The
  fullscreen button earns its place because requesting fullscreen is the only reliable way
  to hide a mobile URL bar — scroll-to-hide needs a scrollable page and this one must not
  scroll — and it has to come from a user gesture, hence a button rather than an on-load
  call. Feature-detected rather than UA-sniffed, so it never appears where the API is
  missing: a button that does nothing when tapped is worse than no button.
- **Two encoding traps, both of which fail by pointing somewhere else entirely.** Writing
  `export_presets.cfg` with PowerShell 5.1's `-Encoding utf8` prepends a BOM, Godot does
  not skip it, and the export dies with *"Invalid export preset name: Web"* — an error
  about the preset name, caused by three bytes in front of `[preset.0]`. And an em-dash or
  curly apostrophe anywhere in `export-web.ps1` is mis-decoded when PS 5.1 reads the
  BOM-less script as ANSI, desyncing the parser into `The term 'finally' is not recognized`
  against a `try`/`finally` a hundred lines below, with no output from anything above it.
  Both cost real time this session; the general shape is the one this log already carries
  for `CardDB` and per-round growth — **the error's location is not the defect's
  location**, and an encoding fault in particular surfaces as a syntax or lookup failure
  far from the byte that caused it.
- **There is an in-game tutorial, and it is two halves rather than one.** Fourteen scripted
  lesson battles teach the mechanics you *do*; a browsable reference carries the exhaustive
  rules text. Neither half could do the other's job: a scripted battle is the only thing
  that can teach *pool vs. attached*, because that decision only exists when energy is
  actually scarce — but a battle cannot cover fifteen keywords without becoming an hour
  long, and a player looking up `Sanctuary N` six weeks later wants a page, not a replay.
  Lessons are independently selectable and independently completable, so nothing forces a
  player who wants the Void lesson to sit through thirteen others first.
- **A tutorial step advances because the rules engine agrees, not because a click was
  counted.** Each step's completion condition is evaluated against the real `GameState`,
  which is what keeps a lesson honest when the engine changes underneath it — the same
  reasoning that makes the Heaven and Gaia harnesses drive `_deal_lane_damage` rather than
  simulate it. The two exceptions are a unit *selection* and a *heal*, which leave no
  standing record in `GameState`; the UI reports those directly, and keeping that list to
  two is deliberate, because every entry on it is a place the tutorial could drift from the
  game.
- **Every tutorial hook is inert when no lesson is running.** `Tutorial.active` is false in
  an ordinary game and every gate answers permissively, so the ordinary path is unchanged
  *by construction* rather than by care. That mattered more than usual here: the tutorial
  touches `Combat.gd`'s input paths, and `Combat.gd` is the largest file in the project.
- **The tutorial never touches `DeckStore`, and its progress lives in its own file.** Lesson
  decks are fixed lists handed straight to `GameState`, and progress saves to
  `user://tutorial.json`. This log already carries two data-loss bugs caused by a read or
  test path sharing a write path with the player's collection; a fourteen-lesson feature
  that constructs decks is exactly where the third would come from.
- **A lesson declares its opening hand; it is never inferred from deck order.** This was
  learned the hard way — the first build ordered the deck and hoped, and shipped a `board`
  lesson whose step 4 asks for a second Basic while the player held one Basic and five
  energy cards. Two things made that worse than a normal bug: `draw()` pops from the **back**
  of the deck, so the carefully ordered front is the *last* thing a player sees, and the
  guaranteed-Basic re-deal is skipped on the unshuffled path, so the usual safety net was
  not there either. `Player.deal_exact_hand()` now deals a stated list, and the hand each
  lesson needs is written next to the steps that need it. **The general shape: if a scripted
  experience requires specific cards, the requirement belongs in the script, not in an
  ordering that something downstream is free to reinterpret.**
- **"Valid" and "completable" are different properties, and only the second one matters.**
  `TutorialTest` asserted a lesson opened with *at least one* Basic and passed 113/113 while
  the `board` lesson was unplayable at step 4. The content assertions were not wrong, they
  were answering a weaker question than the one that mattered. `TutorialWalkTest` now drives
  all 13 lessons through the real Combat screen doing what each step asks, which is the only
  thing that can catch a soft-lock. **A test that a thing is well formed is not a test that
  it can be finished** — and for anything with a required sequence, the walk is the real test.
- **The tutorial's own harness caught two real bugs on its first run, and the
  assertion-count guard caught a third.** `Player.load_deck()` shuffled unconditionally, so
  the reproducible-deal premise the whole lesson system rests on was quietly false; and a
  keyword-example assertion checked `keywords` for `Consume`, which lives on an attack line
  because *an ability may carry no other cost* — the data was right and the test was wrong.
  Separately, `EXPECTED_ASSERTIONS` was written as an estimate of 118 against a real 113,
  which is the guard working as intended: **a green suite is only evidence if you know how
  many assertions it was supposed to run.**
- **`SupportUITest`'s flake was measured against a clean checkout before being attributed.**
  It failed on the working tree during this session at the `enemy tower damaged` assertion,
  which is exactly the kind of coincidence that gets blamed on whatever landed last. Running
  a `HEAD` worktree eight times reproduced it at the same ~1-in-8 rate, so it is
  pre-existing. The mechanism is now known and recorded above (a stale tower HP across
  `_reset()`), which is the thing the docs previously asked for and could not supply — an
  intermittent failure is information, and the way to collect it is to measure the baseline
  rather than to re-run until green.
- **`SupportUITest`'s flake is fixed, and it was a dirty fixture rather than a rules bug.**
  `_reset()` cleared *your* board and never touched tower state or the enemy's board at
  all, so `enemy tower damaged` depended on no round having elapsed earlier in the file —
  when one had, the tower read 27/52 instead of 25/50 and the assertion failed. It now
  restores tower HP, max HP, mods, damage bonus and Earth bonus on **both** players'
  boards; 20 consecutive runs, 0 failures, against a documented ~1-in-8 rate. The general
  shape: **a shared fixture that resets only the half a given test looks at will fail at
  whatever rate the other half changes**, and it will read as engine non-determinism rather
  than as leftover state, which is why this one survived two separate investigations.
- **Every UI symbol lives in `Palette.GLYPH`, and the safe set is ASCII plus Latin-1
  punctuation.** The project bundles no font, so everything renders in Godot's built-in Open
  Sans SemiBold, which has no arrows, no geometric shapes and no emoji — eighteen distinct
  symbols were rendering as empty boxes, including `⬢`, the energy symbol printed on every
  card cost and the pool meter. The failure mode is what makes it dangerous: a glyph looks
  right in the editor, right in a diff, right in review, and is a box only on screen, so it
  survived every code path a human read. Bundling a symbol font was rejected as megabytes of
  wasm to draw twenty characters. `LayoutTest.gd` now asks the actual theme font
  `has_char()` for every literal in the UI sources, and it caught three more (`↑`, `↩`, `⊘`)
  the manual sweep missed — **the check has to be mechanical, because reading is exactly
  what does not work here.**
- **Mobile mode is a UI scale and a layout switch together, never one without the other.**
  Drawing bigger costs width, and the desktop screens are fixed-width columns that cannot
  survive losing it — so zooming without restacking just moves the clipping to the other
  edge. `ViewportFit` therefore owns both: on a phone it targets a fixed 540-unit design
  width (≈0.72× on a 390px screen, against the 0.33× a 1180-wide layout forces) and sets
  `mobile`, which each screen reads at build time to go single-column. The deck builder uses
  **tabs** where the others stack, deliberately: both its halves are tall scrolling lists,
  so stacking would mean scrolling past the whole collection to reach the deck.
- **Layout detection is automatic with a persisted manual override.** Auto is right almost
  always, but the override is not a nicety — it is the only way to test the phone layout
  without a phone, and the only recourse when a tablet trips the desktop threshold while
  still being a touch device. Crossing the threshold **rebuilds the screen wholesale**
  rather than re-parenting, because the two shapes differ in which nodes exist at all and
  every screen's real state lives in `GameState` or `DeckStore` rather than in its nodes.
- **A responsive layout has to resize its *contents*, not just restack its containers.** The
  first cut of mobile mode set a 540-unit reference width and made every screen
  single-column, and left `CardView` at its desktop 132×196. A board row is six cards, so it
  still demanded ~850 units inside a 540 viewport and Combat's layout minimum came to 931 —
  the game was, in Jonah's words, "just zoomed in and cuts off most of the stuff." Cards now
  have phone sizes (78×116 board, 112×175 hand) chosen by arithmetic against the viewport,
  and the board panel margins, lane separations and the two full-sentence labels in the top
  bar were all trimmed or rewrapped to fit. **Every fixed-size element needs a phone value,
  or it silently becomes the layout's floor.**
- **The phone board card is a reduced frame, and that is consistent with the one-layout rule
  rather than an exception to it.** 78 units admits no font size at which the full frame is
  readable, so the phone board card keeps name, HP, keyword chips and a status row and drops
  the ability banner, attack rows and footer. The rule those rows were protected by exists to
  stop a card **contradicting** itself in two places; a micro card only ever *omits*, and
  tapping it opens the full frame. Uniformity was never the goal — non-contradiction was.
- **`LayoutTest` asserts no phone layout exceeds the phone viewport, and that assertion is
  the whole lesson.** Every screen *built* correctly the entire time mobile mode was broken,
  which is all the existing build assertions ever checked — so the suite was green while the
  feature was visibly unusable. `get_combined_minimum_size().x` against a 540 viewport is
  the honest measure, with content inside a horizontally scrolling container exempt. Verified
  by reverting the card size and watching it fail at 812 and 602 before restoring the fix:
  **a regression test written after the fact is only worth what it catches when you put the
  bug back.**
- **`export-web.ps1` reads through `System.IO.File`, never `Get-Content`.** PowerShell 5.1's
  `Get-Content` decodes a BOM-less file as the system ANSI codepage, so reading
  `tools/web-head.html` turned every em-dash in its comments into a replacement character,
  and the script wrote that into `html/head_include`. It also made the "did anything change"
  comparison always false, so the preset was rewritten and "Updated head_include" printed on
  every run including no-op ones — which is the symptom that exposed it. The published page
  was never wrong, because Godot reads the `.cfg` rather than the `.html`, but the next real
  edit to the shell would have shipped mojibake. **This is the third distinct PowerShell 5.1
  encoding trap in this one script** (BOM on write, non-ASCII in the script body, ANSI on
  read); the rule for this file is now simply *never let PowerShell guess an encoding.*
- **The layout override lives behind a settings cog on every screen, not in the main menu.**
  It is the recovery path for a UI that has become unusable, so it has to be reachable from
  wherever the player is when they notice — and the screen most likely to need it is Combat,
  which is the furthest from the menu. Implemented as an autoload on a `CanvasLayer` above
  every scene, so it survives scene changes, cannot be covered by Combat's hover-zoom layer,
  and can never be pushed off the edge by a screen's own layout. The panel reports what Auto
  *currently resolves to*, because "Auto" alone tells you nothing when the detection is what
  went wrong.
- **`ViewportFit.save_path` must be a variable, and harnesses must sandbox it.** It shipped
  as a `const`, so no test could redirect it — and a verification script then wrote
  `Override.ON` to the live `user://display.cfg`, failed to clean up, and left the real game
  stuck in phone mode on a 1440-wide desktop. The user reported it as "it still looks like a
  zoomed in version," which is the worst possible symptom: it looks exactly like the layout
  bug that had just been fixed, so the obvious diagnosis is the wrong one. **This is the
  third time this shape has cost real time** (`DeckStore` twice, now this), and the rule is
  now unconditional: *any* file the player's install writes gets a `save_path` variable and
  a `use_sandbox_path()`, on the day it is created.
