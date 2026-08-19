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
              ENEMY THRONE (150 HP)
   ┌─────────────────────┐  ┌─────────────────────┐
   │  [ 1 ][ 2 ][TOWER]  │  │  [ 1 ][ 2 ][TOWER]  │   enemy boards
   └─────────────────────┘  └─────────────────────┘
   ┌─────────────────────┐  ┌─────────────────────┐
   │  [ 1 ][ 2 ][TOWER]  │  │  [ 1 ][ 2 ][TOWER]  │   your boards
   └─────────────────────┘  └─────────────────────┘
              YOUR THRONE (150 HP)
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
card is a card you drew instead of a unit, in a game where you draw two per turn. Playing
four supports in a turn means you spent two turns of draw to do it.

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
| Healing | 32 HP is the baseline; ~16 to the whole board, or 80 with a condition |
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
| `Shore Up` — heal 32 | `Field Surgery` — *heal 80*, for 1 **(built)** |
| `Field Rites` — heal 16 to all | `Closing Ranks` — *heal 32 to all*, for 2 **(built)** |
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
cards, and its ladder is the worked example the others should follow: **a 32 HP baseline,
and each energy buys about 48 more** (`Shore Up` 32 free → `Field Surgery` 80 for 1 →
`Grave Warden's Oath` 120 for 3, capped). A free card may reach the same step by taking a
condition instead of a cost, which is what `Last Breath` does.

**The ladder was re-anchored ×1.6 on 2026-08-17, and the reason is that it had never been
re-derived after the HP curve moved.** The old 20/50/100 numbers were set when Basics were
~50 HP; the 2026-08-08 raise took bodies to 40–175 and deliberately left the *damage*
anchors alone, but nothing revisited the *support* band — so a 20-point heal went from 40%
of a small body to 12% of a large one. Measured over 4M games, supports-per-deck correlated
**negatively** with win rate (−0.19): every deck in the bottom third ran 15–22 supports and
every deck in the top third ran 7–10, because a support is a card that is not a body, and
bodies are what shield. Draw, search and utility were **not** rescaled — their value is in
card economy and did not change when HP did.

**No card fully heals a unit, at any price.** Every heal is a flat number — never "restore
to max," never a percentage of printed HP. A heal that scales with its target can't be
priced: the identical card is worth 20 on a Basic and 110 on the Queen, and it silently
gets stronger every time a bigger body is printed. Flat numbers also make the big heals
**overflow and waste** on small units, which is what keeps `Grave Warden's Oath` from
being a strict upgrade over `Shore Up` rather than a different choice. Enforced by a test
in `SupportTest.gd`, not by convention.

The line that does **not** move: a priced support still may not sell damage at attack
rates. **7–9 damage per energy** is what an attack buys (by stage), and an attack's cost stays attached
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

1. Both players draw an opening hand of **8**, guaranteed to contain **two** Basic units.
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

**Consume may appear on either an attack or an ability.** On an ability it is the whole
price, which is what stops a free once-per-turn effect from being a permanent no-cost
engine: the unit has to be re-charged to keep using it. It is **one of three** non-energy
costs an ability may print — the others are Forge's `Stoke N` and `Scrap`, which spend HP
and bodies on the same principle (see *Abilities are free*).

---

## Damage Formulas

These are **working anchors for playtesting**, not final numbers.

**Cost is derived from damage, and the rate rises with stage:**

| Stage | Cost band | Damage per energy |
|---|---|---|
| **Basic** | 1–6 | ≈ 7 |
| **Stage 1** | 4–10 | ≈ 8 |
| **Stage 2** | 8–20 | ≈ 9 |
| **Consume attack** | — | ≈ 20 per energy consumed |

**Only six Basic attacks — the "openers" — sit in the round-1 window of cost 1–2.**
Every other Basic attack is priced at 4–6. This is a deliberate scarcity, not a
side effect of the curve, and the reason is that **cheap attacks fire far more
often than expensive ones**: a 2-cost attack, once paid, re-fires free every turn
from round 1, while a 9-cost fires only in the last rounds of the ~37% of games
that reach round 9. A cheap attack therefore generates roughly 3× the activations
of an expensive one, so printed parity produces a heavy cheap-attack majority in
play. Measured: 34.6% of printed attacks at cost ≤3 produced **77.8%** of attacks
actually queued. Holding the played mix near half requires printed cheap attacks
to be well under parity — currently 11.5% printed, giving **38%** queued.

`cost = round(damage ÷ rate)`, clamped into the stage's band. The rate rises with
stage so that **evolving improves how well a body converts energy** — that is what
makes a slower, more expensive Stage 2 worth reaching at all.

Linear, not superlinear. Big attacks are not more efficient per point — they're
*better because the board caps at 4 units*, so concentrated damage is worth more than
its raw total.

**A band's ceiling is reached only by attacks whose payoff is an effect, not
damage.** At 9 damage per energy a cost-20 Stage 2 attack would need 180 damage,
which exceeds the largest printed HP in the game (175) — so no *damage* attack
belongs at the top of the Stage 2 band. The two cards that sit there
(`THE LAST TOLL`, `The Long Quiet`) both print 0 damage and win through effects.
That is the band working correctly, not a gap in it. In practice damage attacks
stop around cost 13, and **no single attack exceeds 120 damage**, so removing the
biggest bodies always takes chip support or a second attacker.

Reference breakpoints, by stage:

| Stage | Cost | Damage | Meaning |
|---|---|---|---|
| Basic (opener) | 1–2 | 8–16 | Chip. The only thing playable in **round 1**. Six of these exist. |
| Basic | 4 | 30 | The common Basic swing. |
| Basic | 5–6 | 35–40 | Threatens a kill on a median Basic. |
| Stage 1 | 4–5 | 35–40 | The workhorse midgame attack. |
| Stage 1 | 6–7 | 45–55 | Kills a median Basic outright. |
| Stage 1 | 9–10 | 70–80 | Kills most Basics, threatens a Stage 1. |
| Stage 2 | 8–10 | 65–90 | Kills any Basic, threatens a Stage 1. |
| Stage 2 | 13 | 120 | The damage ceiling. Still does not one-shot a 175 HP body. |

**Round 1 gives exactly 2 energy** (one energy card at `t + 1`), which is what sets
the floor of the Basic band: a few cheap Basics must be able to attack on the
opening turn, so 1–2 cost attacks have to exist and have to be Basics.

Costs may include **colorless** requirements, payable with any color. Multi-faction
units cost more total energy but get access to **stronger effects** — never higher raw
damage. Multi-faction should be common and manageable, not strictly superior.

### The colorless split

**Most attacks print part of their cost as colorless.** The colored half is the
card's faction requirement — what stays gated once multi-color enforcement is
built — and the colorless half is payable with any energy.

| Split | Applies to |
|---|---|
| Pure colored | total cost ≤ 2 — the round-1 openers |
| `N-1` + 1 colorless | total cost 3–5 |
| Half and half | total cost 6+ |

`tools/split_colorless.py` holds the rule (`--dry-run`, then `--apply`) and
**total cost never moves when it runs**, so it changes no balance number. It
currently splits **172 of 230 lines**, leaving 58 pure: 22 cheap openers and 36
that already printed colorless. Coverage is ~90% in every faction.

**Cost is the only input, and a keyword carve-out was tried first and
abandoned.** The original rule kept any line on a card carrying a signature
keyword at a pure colored cost, reasoning that a splashable `Toll` or `Siphon`
would let any deck rent a faction's mechanic. The card pool disproved it: those
keywords are the **baseline, not a scarce identity** — Toll appears on 47 attack
lines, Earth on 46, Judgment on 30 — so the rule protected 194 of 230 lines and
left Heaven with 7 mixed costs out of 57, every `Judgment` Basic printing a pure
`{"heaven": 4}`.

The correction generalises: **a keyword on most of a faction's cards is not what
distinguishes a deck; the faction's energy is.** Identity gating therefore lives
in the *size* of the colored half — a 6-cost line still demands 3 of its own
colour — rather than in refusing to print colorless at all.

A cost that **already prints colorless** was authored deliberately and is left
alone rather than re-derived.

Re-price the whole card pool from these bands with:

```
python tools/reprice_attacks.py --dry-run    # then --apply
```

---

## Shared Keywords

These belong to the whole game. Faction files list only their signatures.

### Keyword values are modifiable

**A printed keyword value is a starting point, not a constant.** A card may raise
any keyword on any unit, and every rule that consumes that keyword reads the
modified value — so a `Toll 2` body under a "+2 Toll" effect refunds 4.

- **Modifiers stack without limit.** Two +2 effects make Toll 6. The bound on
  Tools is one-per-unit; a board-wide support has no such bound and is not given
  an artificial one.
- **They are history, not print**, so `Rise` and evolution clear them, exactly
  as they clear grown `Earth`. Rise restores the card, not the history.
- **They floor at 0 on read.** A reduction can zero a keyword but never make it
  negative, and a −5 followed by a +5 returns to the printed value rather than
  being clamped away in between.
- **The live value renders on the card.** A raised keyword shows its modified
  number, the same rule as a spent `Judgment` vanishing — state the engine tracks
  per-unit has to be *visible* per-unit, or the mechanic is correct and invisible.

Two ops carry it, and both name the keyword in the data rather than in the code,
so one op serves every keyword in the game:

```json
{"op": "buff_keyword_all", "kw": "toll",   "n": 2}   // every unit you control
{"op": "buff_keyword",     "kw": "siphon", "n": 1}   // one chosen unit
```

**This is the substrate for cross-keyword rule-breakers.** A card that makes a
death pay `Toll` *as* `Siphon` converts a refund into *attached* energy, which is
the resource `Rift` reads — Hel's trigger spending into Void's currency. Those
interactions are the point of the layer: each one is still authored deliberately
per card, but the engine no longer has to grow a new op for every keyword it
touches.

| Keyword | Effect |
|---|---|
| **Rise** | When this dies, return it to an empty slot on your side at the start of your next turn, at **half HP** and **without Rise**. Every other ability, attack, and keyword returns intact — at their **printed** values. Attached energy is not restored, and neither is any stat the card had *grown* in play (notably Gaia's `Earth`). Rise restores the card, not the history. |
| **Retribution N** | When this unit takes damage from an attack, deal N damage back to the attacker. |
| **Consume N** | This line destroys N attached energy on activation. Priced at ≈20 damage per energy consumed. May appear on an attack or an ability. |
| **Judgment N** | One charge, spent by either use. **Defensive:** when this unit would die, it instead survives at N HP. **Offensive:** when this unit attacks and leaves the defender at N HP or below, that defender is destroyed. Returns only if the card returns to hand. |
| **Sanctuary / Sanctuary N** | Plain **Sanctuary** absorbs the next instance of damage entirely, from any source, then is spent. **Sanctuary N** is a pool of N that damage depletes; a hit larger than the pool drains it and **the remainder gets through**. |
| **Windfury** | This unit may attack twice per turn. |
| **Resist X** | Reduce each incoming instance of damage by X, to a **minimum of 1 damage**. |
| **Stoke N** | *(Forge)* Free once-per-turn ability: deal N damage to this unit. It has **stoked** until end of turn, and other lines read that state. **Unpreventable** — it is a cost, not damage from a source. |
| **Scrap** | *(Forge)* An ability cost: destroy **another** unit you control. It dies normally, so `Toll`, `Rise` and `Essence` all fire. |

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

**`Storm` is the second global of this kind**, and it is deliberately unlike the Gap in one
way: it is **symmetric**. One number both players read, rather than one each. It is 0 until
a Tempest card raises it, never falls, and adds **one extra instance** of its value to every
attack in the game — doubled for a Tempest unit. See `tempest.md`.

The one-instance rule is load-bearing rather than cosmetic: `Resist X` reduces each incoming
*instance* to a minimum of 1, so N separate ticks would pierce armour entirely as Storm
climbed.

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

**N is exactly what it blocks.** Sanctuary N is a pool of N that damage depletes; when a
hit exceeds what is left, the pool absorbs everything it still holds and **the remainder
gets through**.

| Incoming | Result |
|---|---|
| 30 into Sanctuary 100 | Absorbed. Now Sanctuary 70. |
| 110 into Sanctuary 100 | 100 absorbed, **10 through**. Sanctuary gone. |
| 30 into Sanctuary 20 | 20 absorbed, **10 through**. Sanctuary gone. |
| 30 × 4 into Sanctuary 100 | 100 → 70 → 40 → 10, then the fourth hit takes the last 10 and puts **20 through**. |

**Plain `Sanctuary` is the exception and still absorbs one whole instance**, at any size.
It has no pool, so draining it exactly would make it block nothing and delete the keyword.

**Blocks all damage sources** — attacks, tower fire, `Decay`, support damage, `Retribution`.

**Why the pool form.** A boolean shield treats a free `Decay 5` tick and a 75-damage
attack identically, so the cheapest possible chip would strip a shield a 6-energy attack
had to break. Under the pool form a 5-point tick removes only 5, so Sanctuary N stays
resistant to chip — which is its identity.

**The unbounded overflow was removed on 2026-08-17, and it is the change that mattered
most.** The rule used to be that a pool which could not cover a hit absorbed the *whole*
instance regardless of size, so `N` was a floor rather than a value. That made every
shielded body worth `N + one arbitrarily large hit`, which is not a shield but an extra
life — and a deck running thirty of them is not killable. Measured over 3M games,
`Sealed Light` (30 units, every one carrying Sanctuary 60+) sat at **88–91%** while its
games ran four rounds *longer* than average: it was not out-playing anyone, it was
surviving to win on the tower clock. Draining the pool exactly removes the extra life and
keeps everything the pool form was adopted for.

**Minimum printed N is 60.** Below that the number is too small to matter against the
damage the game actually deals. Printed values are plain, 60, 80, or 100.

**The counterplay is no longer inverted.** Chip still depletes a pool efficiently, but a
single big attack now punches through the last sliver instead of being erased by it, so
both answers work and neither is degenerate.

**Sanctuary bodies buy damage at ≈ 18% below the standard curve.** Sanctuary is worth a
large amount of effective HP — measured across the card pool, a Sanctuary body carried
1.5–1.9× the effective HP of a plain one at the same stage — and it used to pay *nothing*
for it, hitting 2–22% harder than plain units rather than softer. `Judgment` takes a
documented one-third rate cut for a smaller benefit; Sanctuary now takes a smaller cut for
a larger one, applied as **less damage at the same cost** so the rate genuinely moves.

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

**An ability is free unless it prints a cost.** The costs an ability may print are the
ones that are *not* pool energy:

| Printed ability cost | What it spends |
|---|---|
| **`Consume N`** | N *attached* energy, destroyed |
| **`Stoke N`** | N of the unit's own HP |
| **`Scrap`** | Another unit you control, destroyed |

None of these is a payment into the pool, and none stays on the unit as a requirement.
Each burns something already committed — an investment, a health bar, a body.

| | Attack | Ability |
|---|---|---|
| When it resolves | End of turn | Immediately |
| Cost source | Pool → attached | Nothing, or a printed non-energy cost |
| Cost after the first use | Free — the energy stays attached | Free, unless it charges every time |
| Limit | One queued attack per unit | Once per turn, per unit |

This is why the two are worth separating at all. An attack's cost is an *annuity* — you
pay once and the attack is free every turn after. A printed ability cost is the opposite:
it charges **every single time**, which is what lets a strong ability exist without
becoming a permanent engine. A free ability is priced by the once-per-turn limit alone.

**This rule was narrower until 2026-08-16**, reading *"an ability may carry a Consume; it
may carry nothing else."* That was written when Consume was the only non-energy cost anyone
had designed, so the closed list was an accident of what existed rather than a decision.
Forge's `Stoke` and `Scrap` made it false, and the generalisation — *free by default, priced
when printed, never from the pool* — is what the original rule was actually protecting.

The distinction is enforced in the data, not by convention: a line marked `"ability": true`
has its `cost` block ignored outright, so a card cannot accidentally price an ability by
filling in the wrong field. The costs that read are `"consume": N`, `"stoke": N`, and
`"scrap": true`.

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
| **Tower** (one per board, 2 total) | 75 | +5 max HP; deals damage to the unit in front |
| **Throne** | 150 | +5 max HP |

**Growth is per round, not per turn.** Structures gain their +5 once both players have
acted, not at the end of each player's turn. This was a real bug rather than a tuning
change: growth fired inside `end_turn()`, which runs twice a round, so thrones and towers
were actually gaining **+10 a round** while every document and every balance note in this
file assumed +5. It is the single largest contributor to the throne outgrowing the damage
available — the formal stall in Open Questions — and halving it is the cheapest of the
dials named there.

- **Towers are silent for the first round.** They deal **0 damage** while round 1 is
  being played and do not grow. A tower's first shot is **5 damage from an 80 HP tower**,
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

It also makes the tower's own number legible: the first tower shot is 5 from an 80 HP
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
- **Opening hand: 8 cards. Draw 2 per turn.** Raised from 6/1 on 2026-08-15, alongside
  the 75 HP tower and 150 HP throne, to answer games ending too fast. The bigger
  structures lengthen the clock; the extra draw is what lets a player *use* the added
  time — more cards per turn means more bodies to rebuild a cleared board with, so the
  longer game is spent defending rather than waiting. Provisional — this is a
  playtesting dial, not a settled rule.
- **Maximum hand size: 10.**

### The opening hand

**Every opening hand contains at least two Basic units**, for both players. The deal is
retried up to a fixed number of shuffles; if a deck genuinely holds fewer — legal, but
barely playable — Basics are not conjured and the hand stands as dealt.

This is not a courtesy. **A hand with no Basic cannot take a single action all turn**:
units are the only free thing to play, every Stage 1 needs a Basic already on the board,
and energy without a body to charge does nothing. There is no mulligan-for-value decision
in a hand like that, only a lost turn — and losing turn 1 in a game with a scaling tower
is close to losing the game. Pokémon solves the same problem the same way, and for the
same reason.

**Two rather than one, because setup deploys Basics and nothing else.** A one-Basic opener
technically has a legal action, but it walks into round 1 holding a single body against a
board that may show two — and with shielding, the side with fewer units has its tower
exposed sooner. Guaranteeing the second Basic makes the setup phase a real placement
decision rather than a formality, which is what setup was added for.

**The guarantee is clamped to what the deck holds.** A list running one Basic gets one; the
deal does not spin through every retry chasing a card that isn't there.

**It is a deal filter, not a stacked hand.** The deck is reshuffled and re-dealt whole
rather than Basics being searched out and placed on top, so nothing about the *rest* of
the hand is biased — a three-Basic hand is still as likely as the deck makes it.

### The mulligan

**Once per game, during setup, you may mulligan your opening hand.** The whole hand
shuffles back into the deck and you draw a fresh 8, under the same guaranteed-Basics rule.

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
| **Forge** | Fire, smithing, the primal | Kill | 🔨 Built — see `forge.md`. The aggro slot, and the only warm colour |
| **Tempest** | Storm, pressure, the break | Bank | 🔨 Built — see `tempest.md`. The only faction whose resources persist and grow across turns |

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
| **Forge signature** | `Stoke`, `Scrap` | `forge.md` |
| **Tempest signature** | `Charge`, `Storm` | `tempest.md` |

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

**Forge is the fifth faction and its design is settled** — see `forge.md`. Its keywords,
costs, and brakes are decided; no cards are authored and no engine work is done.

| Candidate | Domain | Verb | Notes |
|---|---|---|---|
| ~~**Forge**~~ | Fire, smithing, the primal | Kill | **Built 2026-08-16 — no longer in reserve.** See the faction table above and `forge.md`. |
| **Wyrd** | Fate, chance, transformation | Gamble | Randomness and transformation. Fun, hard to balance. |
| **Wilds** | Flesh, beasts, raw physicality | Overwhelm | Big bodies, brute force. Distinct from Gaia's nurturing growth — this is nature as a threat, not a garden. |
| ~~**Tempest**~~ | Storm, pressure, the break | Bank | **Built 2026-08-17 — no longer in reserve.** Absorbed into Forge on 2026-08-16 and revived the next day under the clause that permitted it, as a genuinely different idea: the accumulation colour rather than the multi-attack one. See `tempest.md`. |

**Tempest was absorbed and then revived, and the absorption clause is what made it
legitimate.** The 2026-08-16 merge into Forge ended with *"revivable later only as a
genuinely different idea, or as a subfaction"*, and the revival had to clear that bar
before any card was written: the new Tempest abandons cheap repeated attacks entirely and
is built on **resources that persist and grow across turns**, which is the one axis no
built colour occupies. Everything else in the game is instant (`Stoke`), live (`Earth`),
binary (`Judgment`), or decaying (the pool).

**The anti-hoard gap this table used to name is closed.** Void was built to be Hel's
predator and is the faction that interacts with the energy economy itself; see `void.md`.
Forge is immune to it from the other direction, since a deck paying costs in HP and bodies
has less in its pool to siphon — that asymmetry is matchup texture, not a hole.

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

- **The 5M-game sweep (2026-08-17) settled the seat question and it is real: P1 wins
  58.5–59.4%.** Every ordered pairing was played in both seats, 1,600 games each, across
  five 1M-game rounds — so this is not the 8-run noise the earlier entries hedged against,
  and it did **not** move when Earth, Sanctuary and the support ladder all changed under
  it. It survives the setup phase and round-1 tower silence, which were adopted partly to
  remove it. What the sweep cannot say is whether the cause is the *rules* or the *AI*:
  both seats run identical heuristics, so P1 simply acting first compounds. The cheapest
  discriminator is an asymmetric-AI run (`ai=v1xv2`) or giving P2 a compensator and
  re-measuring.
- **The deck spread is still 83% to 22% after five rounds of tuning, and card-level
  changes are not closing it.** Three targeted fixes each did exactly what they were aimed
  at — Earth −12pt on `Standing Stones`, Sanctuary −6pt on `Sealed Light`, the support
  ladder +4 to +7pt across four Forge decks — and the field standard deviation moved only
  19.6 → 17.7. The decks at the bottom (`Cacophony Ramp` 22%, `Burning Line` 26%,
  `Scrap Line` 27%) are not badly *costed*; they are slow decks losing to a ~9.5-round
  clock. **Tower scaling was A/B tested as the suspected cause and exonerated**: at `+2`
  a round instead of `+3`, games lengthened (9.5 → 9.9 mean) and the bottom decks did not
  move at all. So the clock is not what is holding them down, and the next hypothesis
  worth testing is that the AI cannot pilot a slow deck rather than that the decks are
  weak.
- **Supports correlate NEGATIVELY with winning (−0.19), and the ×1.6 re-anchor only
  dented it.** Every deck in the bottom third runs 15–22 supports; every deck in the top
  third runs 7–10. The re-anchor bought the support-heavy Forge decks 4–7 points and did
  not reorder the table. The structural reading is that **a support is a card that is not
  a body**, and under shielding, bodies are what keep a tower alive — so a support has to
  beat a whole unit's worth of board presence to be worth its slot, which most do not.
  That is a deckbuilding-cost question the power band cannot answer on its own.
- **The AI holds a mean pool of 0.92 and dumps everything onto bodies, so "spend or save"
  — design principle #2 — is effectively untested by every number in this report.** Decay
  almost never fires. `void.md` already flags this for Rift; it is broader than Void, and
  it is the single largest caveat on the whole sweep.
- **Every one of 5,000,000 games ended by throne kill. Zero stalls, zero decking.** The
  long-running stall worry in the entries below is, on current numbers, closed — no game in
  5M reached the 300-round guard and the longest was 37 rounds. Deck-out is correspondingly
  dead as a loss condition at 60 cards and ~9.5 rounds, which is probably intended but does
  mean mill can never be a strategy.

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
- **The 2026-08-15 structure and draw raise moved the AI game to ~9 rounds, not decisively
  longer.** Measured immediately after 75 HP towers, 150 HP thrones, an 8-card opener and
  draw 2: rounds **5, 7, 8, 9, 10, 11, 11, 11** over eight random-deck runs of
  `RulesTest.gd`, mean ~9, no stalls, against the ~8.4 the re-pricing entry below
  recorded.
  That is a smaller shift than the size of the change suggests, and the likely reason is
  that **draw 2 partly cancels the HP raise**: both sides now develop faster and answer
  removal faster, so more damage lands per round against the bigger structures. Whether
  that is the intended trade is exactly what a human playtest has to say — the AI does not
  retreat, does not model shielding, and now discards more, so it is the worst case for a
  change whose point is *defensive* capacity. **Eight runs cannot separate this from noise;
  do not tune on it.**
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
- **Did the 2026-08-15 re-pricing achieve what it was for?** Partly, and the shortfall is
  worth watching. It was adopted to stop 93.9% of attacks costing 1–3 and to make a
  substantial attack sit at 5–6. Measured over 24,000 games immediately after: the 1–3 tier
  fell to **77.8%**, cost 4–5 rose from 3.6% to **19.9%**, and cost 4 now fires in 66% of
  games against 10% before. So the ladder did stretch.

  A second pass on 2026-08-15 pushed it further, to **38% of attacks queued at
  cost ≤3** (from 77.8%), by cutting the round-1 openers to six and re-pricing
  every other Basic attack to 4–6. Cost 4+ is now **62%** of attacks played.

  What did *not* move much is the clock. Games went 8.06 → **8.43 rounds** — the reasoning
  that higher costs slow the game for both sides is sound and visible (games ending by
  round 4 halved, 3.0% → 1.4%), but it is a much smaller effect than the tower's share of
  total damage. **The 8-round median is a tower problem, not a cost problem**, and the
  cheapest dial remains the structure-chip rate. See the entry below.

  The deck spread also did not improve (Toll Engine 81.7% → 79.8%, Lamp Wall 28.8% →
  21.4%), so re-pricing is not a balance fix and was not expected to be one. **Needs a
  human playtest** — every number here is an AI reading, and the AI has no Judgment or
  Sanctuary heuristics, which is most of why both Heaven decks sit at the bottom.
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

### The bestiary

**Every unit is a creature, and every evolution chain reads as one creature at
successive ages.** Landed 2026-08-15; full design in `docs/specs/bestiary.md`.

The roster went from 56 units to 234 in two waves (292 cards total). Nothing mechanical
changed in the pass — no keyword, no rule, no engine code — and **no card `id`
moved**, which is what made it cheap: ids are referenced 130+ times across 15
files (`TutorialData.gd` alone names 40), and they are internal, so `grave_whelp`
displays as *Osslit* without a line of GDScript changing.

**The naming system is per-faction, and that is the load-bearing part.** A chain
shares a stem; the suffix escalates with age; and the suffix *pools differ per
faction* so a name places its own colour. The first draft used one shared suffix
table and it was wrong for two reasons worth keeping: every faction's Basic ended
in the same syllable, so 114 cards rhymed with each other, and a shared suffix
carries zero faction information, which puts the whole burden on the stem.

| Faction | Element | Sound | Example chain |
|---|---|---|---|
| **Hel** | bone, rot, grave-cold | hard, clipped | Hollowgrub → Hollowmaw → Hollowdrung |
| **Heaven** | light, gold, judgment | open, ringing | Solemim → Solemmant → Solemtribune |
| **Void** | absence, entropy | hollow, trailing off | Vastsk → Vastebb → Vastnought |
| **Gaia** | moss, stone, root | soft, earthy | Granling → Grancrag → Granthane |

**Named legendaries are the sanctioned exception** — `Hel, Queen of the
Unclaimed` and both Nithoggs keep their proper nouns, because Nithogg is the
Norse root-gnawing serpent and that is load-bearing flavour rather than a
placeholder. Kept rare, always at the top of a chain, never a Basic.

**A chain's creatures also share a silhouette.** Each family is drawn as one
shape function called at three scales, so the Stage 2 is visibly the Basic grown
up. Drawing each stage independently is what lets a chain drift apart, which is
exactly what the evolution read cannot survive.

**The new cards are generated, not hand-authored, and the generator enforces the
rules rather than trusting them.** `tools/add_bestiary_units.py` derives every
cost from damage on the documented curve, and refuses to write if a card breaks
the two-line rule, an HP band, a Judgment cap, the Sanctuary minimum, the
no-new-round-1-openers rule, or Void's per-keyword damage budget. It also scrapes
the implemented `op` list out of the GDScript and rejects any effect the engine
does not handle — an unknown op parses fine and silently does nothing, which is
the exact shape of the dropped-`effects` bug already in this log.

That last check earned its keep immediately: two Rift 2 Stage 2s were authored at
85 and 80 damage, which `VoidTest` correctly rejected as over Void's budget. The
budget rule now lives in the generator too, so the failure surfaces at authoring
time rather than three steps later.

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
| **Regenerable** | `python tools/make_card_art.py` rebuilds all 292 from scratch |
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
| Desktop shortcut | `%LOCALAPPDATA%\Godsfall\Godsfall-crest*.ico` | The `.lnk`'s IconLocation |
| Window / taskbar | `icon_window.png` | `WindowIcon.gd` autoload |

**Both are the Crest** — the throne under a lit fracture in a broken ring, the same
mark the main menu draws. `tools/make_icon.py` is a direct port of `Crest.gd`: same
`RING_GAP`, same `CRACK_W`, same fractional offsets, colours read from the same
`Theme.gd` values, so the two can be diffed line by line when either moves. The icon
a player clicks and the emblem they land on should be the same object.

Two ways the icon differs from the menu's, both forced by having no backdrop:

- **It is transparent outside the mark**, so the desktop shows through.
- **The throne and steps are solid**, not the menu's 30% wash. The wash reads
  because the menu's dark panel sits behind it; on transparency, against a light
  wallpaper, it would be nearly invisible. The icon bakes in the colour the wash
  *resolves to* on the menu's ground, so the mark is identical where it matters.

The taskbar shows the icon of the *running process*, not the shortcut that launched it,
so the shortcut icon alone leaves Godot's default robot in the taskbar. `WindowIcon.gd`
fixes that with `DisplayServer.set_icon()`.

Two things that will silently break it if changed:

- **The call must be deferred a frame.** Setting the icon before the window exists is
  ignored without error.
- **`icon_window.png` is deliberately not a Godot-imported resource.** It has no
  `.import` file, so `load()` has no loader for it — use `Image.load_from_file()`.

Both icons are generated from one script, so they can't drift apart. To change the art,
edit and rerun `tools/make_icon.py`.

**The shortcut does not read `tools/Godsfall.ico`.** Its `IconLocation` points into
`%LOCALAPPDATA%\Godsfall\`, so regenerating the repo file changes nothing on the
desktop until it is copied there — and Windows caches shortcut icons **keyed by path**,
hard enough that `ie4uinit.exe -show` and F5 on the desktop both fail to shift it.

So the way to change it is to **write the new `.ico` under a filename Windows has never
seen** (bump the suffix) and re-save the `.lnk` to point at it. A fresh path cannot have
a stale entry, and no Explorer restart is needed. Delete the superseded files afterward.
The heavy fallback — stop `explorer.exe`, delete `iconcache*.db` and `thumbcache*.db`
from `%LOCALAPPDATA%\Microsoft\Windows\Explorer`, restart it — works, but it blanks the
desktop for a few seconds and the `.db` files are locked while Explorer runs.

This is worth the paragraph because the failure is **misattributed by default**: the
`.ico` on disk is correct and verifiable (decode it and check the dominant colours),
while the desktop shows the previous art — which reads as a broken generator rather
than as a lying cache.

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

**The project bundles two fonts, both SIL Open Font License**, in `assets/fonts/`:

| | Face | Used for |
|---|---|---|
| **Display** | Cinzel | The wordmark, screen titles, section headings |
| **UI** | Inter | Everything else — the project-wide default |

Before these, everything rendered in Godot's built-in **Open Sans SemiBold**. That
is a perfectly good typeface and also the loudest available signal that a Godot
project has not been art-directed, because it is what every unstyled Godot game
looks like.

**Inter is installed as the root theme's `default_font`** by the `Palette`
autoload, so every Control inherits it without a call site asking. That is
load-bearing for more than convenience: `LayoutTest` resolves "the theme font" by
reading it off a bare `Label`, so setting the default is what makes the glyph
check validate against the font the game actually renders with.

**Cinzel is display-only and `Palette.title()` refuses to draw it below
`TYPE_SUBHEAD`.** An inscriptional face is cut for size; at 11px it is less
legible than Inter, not more characterful.

**Both are subset** to Latin-1 plus the punctuation `GLYPH` needs — 174KB for the
pair against 1MB unsubset. Regenerate with `tools/make_fonts.py`.

**Windows' Georgia, Cambria and Bookman were the obvious candidates and are
unusable**: Microsoft- and Monotype-licensed, redistribution prohibited. The repo
is public and ships to GitHub Pages, so a license-locked font is not a risk to
manage but a thing that cannot be done. Checked before downloading rather than
after.

**The glyph rules are unchanged, and still enforced by `LayoutTest`.** The safe
set is wider now that Inter is the default, but the discipline is the same one and
for the same reason:

- **Add a symbol to `Palette.GLYPH`, never inline.** One table, one place to fix.
- **Check it with `Font.has_char()` before using it.** The failure mode is that a
  glyph looks correct in an editor, in a diff, and in review, and is a box on
  screen — so the only trustworthy check is asking the theme font.

The energy symbol is still `#` rather than `⬢`. Inter has no hexagon either, and
the *drawn* `EnergyIcon` is the real answer everywhere a cost is shown; `#` is the
fallback for the handful of places that print energy inside a string.

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
| Board layout | two boards side by side (6 slots across) | **the same — 6 slots across**, both sides visible |
| Board card | 132×196 | **78×116**, a reduced frame |
| Hand card | 168×262 | **112×175** |
| Combat | board \| action+log side by side | stacked, log becomes a drawer |
| Deck select | list \| contents in an `HSplitContainer` | list fills the column, **contents is an overlay** |
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

**The two boards stay side by side on a phone, and the board card shrinks to pay for it.**
This was tried the other way first: the boards were stacked so a card could be 150 units and
carry the full frame. It reads well card-by-card and it is the wrong trade, because it turns
the battlefield into four rows and you can no longer see both sides at once. The screen's job
is the *comparison* — which of their units is in range, what is across from what, whether a
board is clear — and a layout that shows one side at a time makes the read the whole screen
exists for into a scroll.

So the geometry is fixed at **six slots across, twelve on screen**, and the card is sized to
fit it: `6 × 78 + 5 × 4 + 2 × 10 = 508` inside 540, with each row 137 units tall. Two rows
instead of four, and the hand sits under them.

**The phone board card is therefore a reduced frame**, keeping name, HP, keyword chips and
the queued-attack marker and dropping the art, ability banner, attack rows and footer. That
is consistent with the one-layout rule rather than an exception to it: the rule exists to
stop a card **contradicting** itself in two places, and a reduced card only ever *omits*.
Tapping one opens the full frame, which is where the detail lives.

The board read this preserves is the at-a-glance one — which unit is hurt, which still holds
a charge, which attack is queued. That is what board decisions are actually made from, and it
is exactly what survives at 78 units.

**The hand row is the sanctioned exception to fitting the viewport.** It scrolls
horizontally, because six hand cards are meant to be swiped through rather than shrunk to
nothing, and the hand is where cards are actually read before being played.

**It is dragged as well as scrolled, and the two gestures are separated by axis.** A
scrollbar is a poor target for a thumb, so `DragScroll` (`scripts/ui/DragScroll.gd`) lets a
press-and-swipe move the hand. The conflict this has to resolve is that hand cards are
*themselves* draggable — dragging one onto the board is how you deploy, evolve and charge —
so Godot's built-in touch panning is unusable here: the card claims the press first, and
every swipe would pick up whichever card the finger landed on.

Direction is what separates them, and the mapping is not arbitrary:

| Movement | Reads as |
|---|---|
| **Horizontal** past 8px, and clearly more sideways than vertical | scroll the hand |
| **Vertical** — or any diagonal without a clear horizontal majority | a card being pulled out to play |
| Under 8px | a tap; the card gets it |

The hand is a horizontal strip, so sideways is the only direction it *can* scroll; and every
card destination — a board slot, a unit to charge — is above the hand, so playing a card is
always an upward pull. Neither gesture wants the other's axis. The 1.4× majority requirement
is what keeps a 45-degree pull toward the board from flipping into a scroll on noise.

**A hold-then-drag delay was the alternative and was rejected**: it taxes the common case by
making every card drag wait, and a scroll that only starts after a pause reads as broken
rather than deliberate. The claim threshold is deliberately *below* Godot's own drag
threshold, because a scroll claimed after the card drag has begun is a scroll that never
happens.

**Deck select puts its contents pane in an overlay rather than stacking it.** Stacked, the
deck list and the contents each got about half the height, which is the worst of both — too
few decks visible to choose between, and too little of the contents to read. Choosing is what
the screen is *for*, so the list takes the whole column and a button under it summons the
contents over the top. The button names the deck it will open, so what it shows is
predictable before it is tapped.

**The builder uses tabs where deck select uses an overlay**, and the difference is which half
is primary. In deck select the list is the screen and the contents are a thing you check;
in the builder both halves are equally the point — you swap between collection and deck
constantly while editing — so neither can be demoted to a summoned panel. Both halves are
also tall scrolling lists, so stacking would mean scrolling past the entire collection to
reach the deck.

**Both modals are built to one recipe**, the deck builder's card inspector: a full-rect
layer, a dimming scrim, a transparent button behind the panel catching outside taps, and
Escape handled in `_unhandled_input`. Three ways to dismiss, identical everywhere, so a modal
never needs a gesture learned per screen.

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
from `data/cards.json` (**375 cards**: 61 Hel, 59 Heaven, 66 Void, 63 Gaia, 63 Forge, 20 Tempest, 43 neutral).

**Heaven is built — two factions now exist.** 13 units, an energy card, and one Tool,
implementing the `Judgment` and `Sanctuary` keywords and the within-attack damage
resolution order. See `heaven.md`. Three things are deliberately *not* done:

- **`AIPlayer` has no Heaven heuristics.** It does not value a Judgment charge, hold a
  Sanctuary body back, or time `The Gate Opens`. Heaven games run — a Heaven-vs-Hel AI
  sample over 5 runs finished on rounds 8, 8, 10, 11, and 17 with Heaven taking 2 — but
  **AI results are not a balance reading for this faction** until those heuristics exist.
- ~~No Heaven sample deck.~~ **Done** — `Verdict Engine` and `Lamp Wall` ship alongside the
  four Hel lists, so the Hel/Heaven matchup is playable from
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

**Twenty-five sample decks ship as the starter collection** — six Hel, four Heaven, four
Void, four Gaia, seven Forge — laid down on first run by `DeckStore.sample_decks()`. Each is built around a
single idea rather than a spread of the card pool, because a deck holding one of everything
has no plan to read and plays the same whatever you draw:

| Deck | Faction | Identity | Energy |
|---|---|---|---|
| **Toll Engine** | Hel | Cheap bodies that pay out when they die; `Sift the Ashes` converts a bad combat into a turn of income. No healing — it *wants* trades — so the slots go to draw. | 16 |
| **Barrow Wall** | Hel | Retribution bodies plus the whole heal suite and tower support. Survives the tower clock and wins on attrition. | 19 |
| **Rise & Recur** | Hel | `Rise`, Bonepicker's Scavenge, and Hel Queen recycling the discard; the retreat suite as a second recursion angle. | 19 |
| **Cacophony Ramp** | Hel | Both Stage 2 lines complete, with `Offering`/`Tithe`/`Ration Pack` to reach a 14-cost attack. Does nothing early, everything late. | 22 |
| **Wasting Fen** | Hel | `Decay` on every body, and two Stage 2s with a free board-wide 15 damage. Wins without winning a fight; `Reconsecrate` is the mirror-breaker. | 18 |
| **Unquiet Dead** | Hel | Two full `Rise` chains under Stage 2s that return a unit from the discard *every turn*. Rise is one reprieve; Exhume is a repeating one. | 22 |
| **Verdict Engine** | Heaven | Every unit carries `Judgment`. Chip anything into threshold range and execute it; `Court of Bells` reloads the board's charges and `Verdict of the Throne` turns the kills into throne damage. | 15 |
| **Lamp Wall** | Heaven | Deliberately **no `Judgment` at all**, so it keeps the standard damage curve — `Pillar of Light` at 65 and `Judgment of Light` at 75. Sanctuary chaff shields the Bastion while it charges. | 19 |
| **Sealed Light** | Heaven | The 60/80/100 Sanctuary ladder at every stage, with Stage 2s that *restore their own shield* each turn. A shield that comes back is what breaks the wide-board answer to Sanctuary. | 21 |
| **Reaffirmation** | Heaven | `Judgment` released from its brake — both Stage 2s restore Judgment to every unit you control, free, once a turn. Wide rather than big, since Judgment buys damage at the reduced rate. | 17 |
| **Starve** | Void | `Siphon` denial that funds itself; the opponent never accumulates enough to act. | 18 |
| **Widening Rift** | Void | `Rift` scaling off the Gap, with the Gap built by attaching rather than spending. | 20 |
| **Total Eclipse** | Void | Siphon on nearly every body, plus Stage 2s that destroy *attached* energy and eat 20% of the pool. No safe place to keep energy. | 19 |
| **Widening Dark** | Void | Rift on **every** unit and two Rift 2 Stage 2s. The one deck that wants to bank energy onto bodies it never attacks with. | 21 |
| **Standing Stones** | Gaia | `Earth` into towers and `Makeshift Tower`'s free auto-fire. | 21 |
| **Deep Grove** | Gaia | The growth engine — Earth from attached energy, `Essence` to survive a wipe. | 21 |
| **Bedrock** | Gaia | `Earth` and `Resist` on the same bodies, topping out at two Earth 3 / Resist 10 Stage 2s at 165 and 168 HP. Best against exactly the wide chip that beats Sanctuary. | 23 |
| **Thicket** | Gaia | `Retribution` 20–25 plus `Essence`, so attacking into the board is the mistake and the units that die hand their Earth to the next one. | 23 |
| **White Heat** | Forge | `Stoke` big, then cash the flag. `Cindpyre` burns *past living units* into the tower once it has stoked 40, so it declines to clear the board it is supposed to clear. Heavy healing, because HP is the currency being spent. | 19 |
| **Scrap Line** | Forge / Hel | The board as ammunition. `Scrap` eats a Hel `Toll` body and gets **paid** for the fuel. The collection's two-colour deck. | 12 + 11 |
| **Second Wind** | Forge | One body, twice a turn. `Bellowmaul` grants the extra attack slot *and* a discount in one activation — Forge's answer to a board capped at 4 is more actions, not more bodies. Deliberately tall rather than wide. | 19 |
| **Burning Line** | Forge | `Charpyre` sweeps the whole rank, which is what makes no-overkill work *for* you: clear the front and everything behind falls through. The one Forge deck that wants a wide enemy board. | 20 |
| **Nothing Holds** | Forge | Every attacker can make its damage unpreventable — the printed answer to `Sanctuary` and `Resist`, and the reason Forge/Heaven is a real matchup rather than a keyword accident. | 18 |
| **Bank the Heat** | Forge | The economy deck, and the only Forge list that plays long. `Fluxanvil` suspends the pool's decay and draws 2, so it *keeps* energy rather than spending it on arrival. | 21 |
| **Standing Heat** | Forge | The wall that punishes being hit. `Annealanvil` is Retribution 25 / Resist 5 on 168 HP that heals back everything it stokes — the one Forge body that spends HP without running out. | 20 |

**Every sample deck is exactly 60 cards**, not merely under the cap — `DeckStoreTest`
asserts it, because a shipped deck should be battle-ready as printed rather than a
partially-built list the player has to finish.

They run 14–21 support cards, and the *mix* is part of the identity — the aggro deck
takes draw and reach, the wall takes healing and tower support, and they barely overlap.
`default_deck()` returns the first sample, so `reset_to_default()` and the harnesses keep
working unchanged.

Each deck is checked at design time for the trap that a themed list invites: an evolution
whose Basic isn't in the deck. Mourning Bell was cut from Toll Engine for exactly that —
it needs Thornshade, which that deck doesn't run, and Petriwold was cut from Bedrock for
the same reason.

The Heaven pairs are the clearest demonstration that a faction's *internal* split is
deckbuildable: Verdict Engine and Lamp Wall share a color and an energy card and have
almost no card overlap, because Judgment and Sanctuary want opposite things from a body —
and Reaffirmation and Sealed Light are the same split one power level up, each built on
the Stage 2 that *resets* its half of it.

**The eight decks added 2026-08-15 exist to make the bestiary reachable.** The roster went
to 234 units in two waves, and the ten decks in front of it used 55 of them — so 179
creatures were collection content the player would only meet by hand-building. Each new
deck is anchored on a wave-2 Stage 2 whose free ability *is* the archetype (Interment,
Exhume, Renewal, Reaffirm, Expunge, Consume Light, Upthrust, Seed the Grove), which is what
makes them read as eight plans rather than eight piles of new cards.

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
renders cards at. They are **always solid and always in the colour they require** — an
attack's cost states what it *needs*, which does not change with the board. Costs above 8
collapse to a numeric chip, because nine icons overflow the frame and a Cacophony Ramp
player counting toward a 14-cost attack wants the number anyway.

**Each faction's energy token carries a distinct drawn mark, not only a colour.** Hel is a
bone, Heaven a rayed sun, Void a hole with a hot rim, Gaia a leaf; the four reserve colours
have marks too (Forge a flame, Tempest a bolt, Wyrd a four-point star, Wilds a fang). This
is the correction `KEYWORD_COLORS` already needed: at the size a cost row renders at, Void's
slate and Wilds' brown are one grey, and to a colourblind player a four-colour system
carried by hue alone collapses entirely. A shape survives both.

The marks are **one closed figure each, never linework**, and drawn in a darkened `deep`
shade so they read as struck into the token rather than sitting on it. Below
`EnergyIcon.MARK_MIN_PX` (9) the mark is skipped, which by arithmetic means **every hand
card gets it and every board card does not** — `icon_size` is 10 in hand and 7 on the board.
That split is deliberate: the hand is where you decide *which* energy a card demands, while
the board card is a glance read where colour and count are the whole message and a figure
inside a 7px hexagon is a smudge.

**Every energy cost explains itself on hover.** An attack's icon row, an ability's Consume
tag, and a card's play-cost line all carry a tooltip stating the cost in words — the same
contract the keyword chips use, and `MOUSE_FILTER_PASS` for the same reason (the hover has
to reach the row, and PASS still lets the click fall through to the card's own button, so
reading a cost never costs you the ability to select the card).

The icons and the tooltip answer **different** questions, which is why both exist. The row
states the requirement well and has no channel left for how much of it is *already paid* —
it used to encode that as fill, and doing so cost the requirement its colour entirely. The
tooltip is where the paid/owed split, the colour breakdown, and the Consume-vs-attack
distinction get said. Three rules it follows:

- **It reads the LIVE cost, never the printed one, whenever a unit exists.** A `Deadweight`
  Tool raises what every attack on that body costs, so a tooltip quoting
  `AttackData.total_cost()` would be confidently wrong on exactly the unit whose cost is
  surprising. `Unit.attack_cost()` is the authority, and the tooltip **names the tax as its
  own line** — an unexplained gap between the icons drawn and the number charged reads as a
  bug in the card.
- **It states the colour split.** `2 Hel, 2 colorless` is a different card from `4 Hel` once
  multi-colour enforcement lands, and the data is already right, so saying so now costs
  nothing.
- **It never promises what the engine cannot do.** Colour requirements are display-only
  today — the pool is one untyped int — and the tooltip says so rather than implying an
  enforcement that does not exist. Same discipline as `Windfury`'s keyword help.

**Keywords render as chips, and the chips are live.** They are built from
`CardView._live_keyword_line()`, not from the printed card, so a spent `Judgment` or `Rise`
disappears and `Sanctuary N` shows its remaining pool. One chip per keyword, tinted by
`Palette.keyword_color()`, because *"does that body still hold its charge?"* is a lookup
rather than a sentence to read.

**Cards can be clicked or dragged.** Drag-and-drop covers deploying a Basic onto an empty
slot, dropping an evolution onto its base form, dropping an energy card onto a unit to play
it and charge that unit in one motion, and dropping a **single-target support** onto the
unit it affects. Click-then-click still works everywhere; neither style is required.

Two supports stay **click-only**, because a single drop cannot express them: **tower
support**, whose target is a structure rather than a unit, and **two-unit supports**, which
need a second pick. Both keep the board's pick mode.

**Units drag freely between slots, and across your two boards.** Moving one of your own
units to any empty usable slot is **free and unlimited**, adopted 2026-08-15. This reverses
a rule that stood from the first prototype, and the reason it could go is that its own
justification had already expired: it rested on *placement is targeting*, and chosen
targeting retired that premise — an attack may name any living enemy unit, so placement is
now the **default and the fallback** rather than the only lever.

What movement still decides is real, which is why it needs no card and no energy to be
interesting: which of your units eats the tower shot, which one shields the structures
behind it, which slot an *unnamed* enemy attack faces, and whether moving off a board
leaves it clear — which is what opens it up.

It is emphatically **not a retreat**. Nothing is paid, no death effect fires, no `Toll` and
no `Rise`, attached energy and any Tool ride along untouched, the unit is not locked, and it
never leaves the board. Gated on your own main phase: **no repositioning during setup**,
since setup deployment is meant to be committed without seeing the opponent's board.

`Reposition` was **repurposed rather than left dead** — it now moves an *enemy* unit within
its own board. See `support.md`.

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

### The visual system

**Colour is split into two namespaces, and they may never borrow from each other.**

| | Holds | Rule |
|---|---|---|
| **Chrome** | Backgrounds, borders, buttons, focus rings | Faction-**neutral** |
| **Content** | Faction energy, keyword chips, HP, structures | Where colour means something |

The split exists because three pairs had collided outright. `ACCENT` was
byte-identical to Hel's purple, so every button hover and selection ring in the
game was Hel-coloured no matter which faction was being played; `HP_GREEN`
equalled Gaia's `earth`, so a healthy unit and a Gaia keyword were the same
green; `DANGER` equalled `retribution`. The chrome accent is now a cold
starlight blue that belongs to the game rather than to any colour in it, and the
content collisions were separated **in hue rather than in brightness** — a
difference you need two swatches side by side to see is not a difference on a
7px chip.

**Each faction is a `deep` / `base` / `bright` ramp**, not a single value. A flat
fill reads as a coloured sticker; three tones read as a material with a light
source, which is most of what makes the energy hexagon look struck rather than
drawn. `FACTION_COLORS` still holds one flat value per faction for the many call
sites that want one, and it is kept in step with the ramps by hand.

**Gradient fills are unavailable, and the reason is not aesthetic.** Assigning a
`GradientTexture2D` to `StyleBoxFlat.texture` **hangs indefinitely under
`--headless`** — isolated by probe to that exact assignment, with the `Gradient`
and the `GradientTexture2D` both constructing fine on their own. Every screen
has to build headlessly for the harnesses, so a gradient fill would trade the
whole test suite for a shading effect. Light is implied with edges and shadow
instead, which on a dark ground carries most of the same information. The
`Starfield` backdrop draws its own bands in `_draw` and is unaffected, because
that never leaves the CPU until a frame is actually rasterised.

**Type and space are scales, not per-call-site choices.** The UI had fifteen
distinct font sizes with 12/13/14/15/16 all in heavy use, and twelve separation
values including 1, 2, 3 and 5. Steps that close together cannot be perceived as
different, so everything reads as one middle weight and nothing is emphasised.
`TYPE_DISPLAY` through `TYPE_MICRO` and `SPACE_XS` through `SPACE_XL` replace
them. The rule the spacing scale encodes: **space within a group is XS or SM,
space between groups is MD or larger** — when those ranges overlap, grouping
stops being readable.

**Structural labels use `Palette.heading()`** — small, dim, uppercase — rather
than accent-coloured body text. A group label is furniture; it should be findable
without competing with the thing it labels.

**Typed punctuation is never a graphic.** The board divider was a `Label` holding
forty-nine hyphens; it is now `Midline`, a drawn hairline that fades at both ends
around a centre diamond. The fade is the part that matters: a hard rule across
the full width reads as a container boundary cutting the screen into two
unrelated halves, where the two boards are meant to read as one battlefield.

### Motion

**`Motion.gd` is the one timing vocabulary**, and everything animated goes
through it. Durations are named by intent (`FAST`, `QUICK`, `NORMAL`, `SLOW`)
rather than by number, because two panels that fade at 0.15s and 0.4s read as two
different products and nobody can say why.

Everything is short on purpose. This is a turn-based game; an animation exists to
say *that* something changed and *where*, then get out of the way. Anything the
player waits on becomes an annoyance by the fiftieth turn.

**Motion is driven by diffing in the UI, never by new signals from the engine.**
Combat rebuilds its board wholesale on every state change — the node holding a
unit's old HP is freed before the new one exists — so a card cannot tween its own
value. The UI snapshots each unit's HP by instance id and compares as the new
card is built. The rules engine still emits `state_changed` and nothing else.

What is animated, and what deliberately is not:

| Event | Motion |
|---|---|
| Unit damaged | Red flash + short horizontal shake |
| Unit healed | Green flash + slight swell |
| Unit arrives | Pop |
| Card drawn | Slides in from above |
| Throne damaged | Label flashes red |
| Pool changed | Gold pop on gain, dim flash on spend |
| **Throne growth** | **Nothing** |

Throne growth is the deliberate omission. It happens to both players every single
round, and a pulse that fires unconditionally teaches the eye to ignore it —
which would cost the flash its meaning on the turn it actually matters.

Every `Motion` entry point no-ops on a freed node or one outside the tree. A node
being animated can be freed mid-tween by an unrelated refresh, which is normal
here rather than an error, and it must never raise.

### The reskin

Three passes, each benchmarked against a shipped card game, because "make it look
professional" is not actionable and "what does Arena do that we do not" is.

| Pass | Benchmark | What it bought |
|---|---|---|
| 1 | **Hearthstone** | Real type, and a menu that is a place |
| 2 | **MTG Arena** | A board that reads as a battlefield |
| 3 | **TCG Pocket** | Card finish and tactility |

**Everything is drawn in code.** No bitmaps, no shaders, no licensed art. That is
partly a constraint — this project has no artist — and partly the same call the
card art already made: drawn geometry is regenerable, cannot drift from the
palette, and adds nothing to a 39MB download. The pieces:

| File | Draws |
|---|---|
| `Starfield` | The cosmic ground under every screen |
| `Crest` | The menu mark: a throne under a lit fracture in a broken ring |
| `Midline` | The contact line between the two armies |
| `LanePanel` | A lane's surface, ownership tint, and front edge |
| `SlotSocket` | An empty lane position, as a well rather than the word "empty" |
| `TowerGlyph` | The tower, degrading visibly as it takes damage |
| `FactionSpine` | A deck's colours, down the edge of its row |
| `DeckArtTile` | A deck's hero card, as an emblem plate |
| `CompositionBar` | A deck's card-type mix, as one proportional bar |
| `EnergyIcon` | The energy hexagon, as a struck token |

Three of these encode a principle worth keeping:

- **`SlotSocket` extends `DropZone`, not `Button`.** The whole drag contract,
  click-to-deploy and the tutorial ring are inherited rather than reimplemented,
  which is what made a visual change to every empty slot pass `DragDropTest`
  untouched. A reskin that rewrites behaviour is not a reskin.
- **`TowerGlyph`'s cracks come from a fixed table, never RNG.** Combat rebuilds
  the board on every state change, so a randomly-cracked tower would re-crack
  several times a turn. Same reasoning as `Starfield`'s fixed seed.
- **`TowerGlyph` makes condition a silhouette.** Merlons break away as HP falls,
  cracks open below two-thirds, rubble gathers below a third — so *which tower is
  nearly down* is answered by shape rather than by comparing two fractions. That
  is the reason to draw a structure rather than restyle a panel.

**The board's geometry did not move.** Slot sizes, card sizes and the six-across
phone row are all unchanged, which is why `LayoutTest`'s 540-unit assertions still
pass on all four screens. The reskin is entirely in what those boxes contain.

### The deck screens

Three passes over deck select and the deck builder, benchmarked the same way the
reskin was.

| Pass | Benchmark | What it bought |
|---|---|---|
| 1 | **Hearthstone / Runeterra** | A shelf of decks instead of a table of buttons |
| 2 | **MTG Arena** | The deck grid gets the room it was wasting |
| 3 | **TCG Pocket** | A deck's *shape*, not just its counts |

**A deck row is fronted by its hero card, and the hero is the emblem, not a
shrunken card.** The first attempt scaled a whole `CardView` to 74px and it was
mush. A card frame is a *layout of nine small elements*, so scaling it down does
not simplify it — it makes all nine illegible at once. `DeckArtTile` draws the
card's emblem on a faction-tinted ground instead, which works because the emblems
were drawn at 128px specifically to be read small.

The plate carries **no caption**. It had one, and it clipped to "pyrean Senti";
the deck's own name is immediately beside it and the card's name is in the
tooltip, so the caption was redundant *and* broken.

`DeckStore.hero_card_at()` picks it: **highest stage, then cost, then name**.
Fully deterministic, because Combat and the deck list both rebuild on every state
change and a hero that varied between refreshes would make the list flicker.
Stage leads because a deck's Stage 2 is what it is *trying* to do. Energy and
supports are skipped — an energy card is the same picture in every deck of that
colour, which is the opposite of identifying one.

**Row actions live behind a `…` overflow menu.** Ten decks presented thirty
buttons, and Rename / Copy / Delete were the loudest thing on a screen whose only
job is picking a deck. `OverflowMenu` is built on `MenuButton` so keyboard
navigation, outside-click dismissal and edge-aware positioning are inherited
rather than reimplemented slightly wrong. Destructive entries get a **separator**,
not a colour: `set_item_icon_modulate` tints an item's *icon*, and these items
have none, so the obvious approach would have silently done nothing.

**The deck grid fits its columns to the pane's real width**, clamped 4–9 and
recomputed on `resized` — the split handle is draggable and the window resizes,
so the width is neither known at build time nor stable afterwards. At a hardcoded
5 the grid left ~330px of the pane empty on a 1440-wide window, which is the most
expensive unused space on the screen: the deck is the half you judge as a whole.

**The builder's detail panel sizes to its content** — about 31px idle against 133
when a card is hovered. It previously reserved 120px permanently to say "Select a
card", and that space belongs to the collection, which now shows four more rows.

**Each deck tile's footer is `− N +`.** It was `×N −`, so removing a copy was a
click on the tile while *adding* one meant scrolling the collection to find the
same card again — asymmetric halves of one decision. `+` disables at the 4-copy
limit rather than disappearing, so the control stays where the eye learned it.

**`CompositionBar` is deliberately not a mana curve.** Every deckbuilder in the
genre draws one, and it would measure nothing here: this game's costs sit on
*attacks*, not on cards, because cards are free to play. Type mix is the real
axis, and it is the worked example of why a genre convention has to be
re-derived rather than copied. It uses chrome tones rather than faction ramps,
since a deck's type mix is orthogonal to its colours — borrowing the ramps would
make a Gaia deck's support segment look like Gaia energy.

**The settings cog no longer overlaps either top bar.** It is drawn on a
`CanvasLayer` above the scene and is therefore invisible to every screen's
layout, so both screens ran controls underneath it. Screens now reserve
`Palette.COG_RESERVE`, and `SettingsButton._build` asserts the cog still fits
inside what they reserve — the constant lives on `Palette` because naming the
`Settings` autoload at a screen's class scope would break every headless
harness.

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

Verified by seventeen headless harnesses, all passing — run 2026-08-16 after the Forge
expansion, **1238 counted assertions** across the thirteen that count (`SceneSmokeTest`, `PlaythroughTest` and
`TutorialWalkTest` report pass/fail without a count and are not in that total):

| Harness | Covers |
|---|---|
| `RulesTest.gd` | 146 assertions: decay, energy scaling, Toll, attach/queue, targeting (all four steps of the chain, shielding, the per-board limit, no-overkill, and clearing a board mid-volley), tower fire (the 0/5/8/11 schedule, full to units, the half chip to tower then throne, round-1 silence, the min-1 floor, and off-slot shielding), Retribution, evolution, Rise, abilities/Consume, the attack lock, **free unit movement** (within a board, across both your boards, attached energy riding along, and the refusals: occupied slot, a living tower's slot, a same-slot no-op, a dead unit), setup (the guaranteed-Basic deal across every sample deck, the mulligan and its once/timing limits, free deployment, and both-players-ready gating), structure growth at +5 per *round*, full AI-vs-AI game |
| `SupportTest.gd` | 169 assertions: card data integrity, the 4-copy limit on supports, draw/energy/healing/damage supports, Tools, tower support, retreat and its lock, the hand limit, the **repurposed `Reposition`** (moves an enemy unit, never crosses boards, never changes owner, keeps attached energy, fizzles safely on a full board), and a random-matchup AI-vs-AI game |
| `DeckStoreTest.gd` | 74 assertions: create, select, rename/collision/truncation, duplicate, delete, per-deck validation, edit isolation, save/load round-trip, the opponent-deck choice (random legality, pinning, stale and illegal fallback), `seed_samples` on a bare store, `hero_card_at` (present for every sample, deterministic, always a unit, always the deck's highest stage, and null rather than raising on a unit-less or empty deck), and `composition_at` (totalling the deck exactly, agreeing with `energy_at`, and omitting absent types rather than reporting them as zero) |
| `DragDropTest.gd` | 33 assertions: payload resolution against a shifting hand, deploy/evolve/charge by drop, the illegal-drop guards, **drag-to-move** (a legal empty slot, relocation within and across boards, an out-of-range payload refused, and a hand payload never resolving as a unit), and leaving setup via the Ready button |
| `SceneSmokeTest.gd` | All four screens instantiate without error |
| `PlaythroughTest.gd` | Drives the real combat UI: deploy, charge, queue, end turn |
| `SupportUITest.gd` | 55 assertions driving the real combat UI: leaving setup by pressing Ready, support targeting mode, the two-unit pick, tower targeting for both owners, Tool attach by click and by drop, **support drop-targeting** (a heal drops and heals, tower support and two-unit supports still refused on a unit, an enemy-targeting support accepted on an enemy and refused on your own, and the drop path agreeing with the click path on both a legal and an illegal target), the retreat button, and the modal card picker |
| `HeavenTest.gd` | 61 assertions: Heaven card data, Sanctuary pool depletion and terminal overflow, both halves of Judgment **driven through the real damage pipeline**, the Heaven mirror ordering, the save-is-not-re-executed guard, Sanctuary preceding Judgment, both reset cards, and keyword restoration on Rise and evolution |
| `CardViewTest.gd` | 108 assertions on the card frame's *structure*: the header's HP and stage cells, the evolves-from strip (present on evolutions, absent on Basics), keyword chips including a spent `Judgment` dropping its chip, the ability banner (present with an ability, absent without), attack rows whose cost icons are **always solid and always in the required colour** (the regression that rendered every requirement in hand as an empty colourless socket), the **attached-energy badge** as the footer's first child and absent when nothing is attached, **keyword-chip tooltips** and coverage of every keyword in `Palette.KEYWORD_COLORS`, the retreat footer and its reserved weakness/resistance slots, a complete frame for all four non-unit card types, **cost tooltips** on the attack row, the ability Consume tag and the play-cost line (each hoverable, each naming the right numbers, and the attack one reporting a `Deadweight` unit's **raised** cost rather than the print), and **the faction mark** on every energy token being present, distinct from every other, and skipped at board size. Checks which nodes exist and what they say, never pixel positions — those would break on every metric tweak |
| `VoidTest.gd` | 69 assertions: Void card data and the printed damage budget, Gap direction/floor/living-units-only, Siphon moving energy on a unit vs. into the pool on a support, Void N destruction, the damage-per-voided rider, Rift scaling **through the real damage pipeline**, Rift granted by a Tool, pool destruction, Gap-to-throne damage, **Gap relevance** (false with no Void card, true from either player's deck or from hand), and Siphon obeying the shielding chain |
| `GaiaTest.gd` | 146 assertions: Gaia card data including per-colour attack costs, the Earth aura summed across both boards and excluding the dead, aura-adjusted max HP, healing that reaches the aura's ceiling, downward clamping that never kills, the aura on attack damage and on tower damage, `Resist` in both damage paths and on Retribution recoil with its minimum-1 floor, Sanctuary preceding Resist, `Essence` **through the real `_cleanup_dead`** (payment, the nearest-living heir, ties-go-left, never crossing boards, skipping a corpse in a batched death, and fizzling when unaffordable), grown Earth resetting on Rise and evolution, Earth derived live from attached energy, the additive rate-breaker, and Makeshift Tower's free auto-fire, per-round growth, and obedience to the shielding chain |
| `TutorialTest.gd` | 119 assertions: lesson content integrity (unique ids, every step carrying text, every `advance` predicate one the evaluator handles), every card id a lesson names existing, every `read_more` resolving to a real page, every lesson deck building a `GameState`, the unshuffled deal being reproducible **and the default path still shuffling**, every scripted placement landing on a real non-tower slot, the gating hooks answering permissively when inactive, all eight step predicates **driven against a real `GameState`**, progress round-tripping through a sandboxed file, and compendium coverage of every keyword in `Palette.KEYWORD_COLORS`. **Also that every lesson declares an opening hand, that the hand is fully present in its deck, and that it holds the Basics/Stage 1/support/energy its steps actually demand** |
| `TutorialWalkTest.gd` | Drives all 13 battle lessons through the **real Combat screen**, performing what each step asks via the entry points a player clicks, and fails if any step cannot be satisfied. Reports per-lesson rather than a counted total. This is the harness that checks a lesson can be **finished**, not merely that it is well formed |
| `ForgeTest.gd` | 143 assertions: `Stoke` as a cost rather than a damage event (**`Sanctuary` does not absorb it and `Resist` does not reduce it** — the two assertions the file runs first, because they are the whole reason the keyword has the shape it does), the flag as an *amount* so scaling and threshold payoffs read one field, Hold the Slot still flooring it at 1 HP, lethal Stoke firing `Toll` through the ordinary death path, the flag clearing each turn, affordability refusing a partial payment, `Scrap` (weakest-body default, an explicit target honoured, never itself, refused with no other unit and costing nothing when refused, and firing the victim's `Toll`), all **nineteen** payoff ops **driven through the real damage pipeline** (the original nine, plus the ten the 2026-08-16 expansion built — unpreventable damage, the board sweep, both-boards, the tower splash, the extra attack slot, immediate resolution, the cost discount, the decay skip, draw, and the second Stoke), every one of them **verified by putting the bug back**, `stoked_heal_back` refunding the HP while **leaving the flag set**, cleave obeying the shielding chain, the threshold gate on the shielding break, ability cost parsing for all three non-energy costs, and the roster invariants (HP bands, two-line rule, retreat formula, Stoke only on an ability and never above the body's own HP) |
| `KeywordModTest.gd` | 15 assertions on the keyword modifier layer: every previously-flat keyword (`toll`, `siphon`, `decay`, `judgment`, `essence`, `resist`) accepting a modifier, unbounded stacking, the accessors reporting the modified value rather than only the raw dictionary, the floor at 0 applying **on read** so a −5 then +5 returns to the print, and modifiers clearing on both `Rise` and evolution. Verified by reverting `toll()` to its flat form and watching two assertions fail before restoring the fix |
| `TempestTest.gd` | 56 assertions: the `Charge` counter and its spend, persistence **through evolution** with the rate changing and the value carrying, the reset on `Rise`, the global `Storm` counter, Storm's extra damage instance (one instance of N and not N of 1, doubled for a Tempest body, blunted normally by `Resist`, and inert at Storm 0), Charge growing on damage **dealt** and never taken, `charge_on_kill` **not** paying when defensive Judgment rescued the body, all four Discharge modes plus `charge_transfer` **driven through the real `use_ability` and `_deliver_attack_damage`**, `discharge_structures` reaching a tower past a wall while a plain discharge does not, `storm_scale_damage`, `Retribution` firing once per attack rather than once per instance, and both Tempest supports checked against the **shipped card data** rather than a fixture |
| `LayoutTest.gd` | 37 assertions on what the UI *draws*: every entry in `Palette.GLYPH` being renderable by the actual theme font, every double-quoted literal across the twenty-one UI source files containing no character the font lacks (comments exempt — their ASCII diagrams are never rendered), all four screens building in **both** the desktop and phone layouts, and — the assertion that matters most — **no phone layout exceeding the 540-unit phone viewport**, measured with `get_combined_minimum_size()` and ignoring content inside a horizontally scrolling container. The glyph half reads the source rather than the running scene on purpose: a label built only in a rare branch — an error state, a disabled button's tooltip — is never instantiated by a smoke test, and those are exactly the strings that ship broken. The overflow half exists because its absence is what let mobile mode ship as pure zoom: every screen *built* fine, which is all the build assertions ever checked |

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

**`SupportTest.gd` is separately flaky — one failure in ~15 runs on 2026-08-08, and again
once on 2026-08-17 during the Tempest build.** The 2026-08-17 sighting was chased rather
than re-run away: 26 subsequent random-matchup runs and **8 runs with the Tempest deck
forced into the game** all passed, so it is not the new faction. The failing assertion was
still not captured — the run that failed was inside a loop that printed only the totals,
which is the same mistake the note below warns against. Capture the output next time. The prime suspect is the support-heavy
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
immediately, is limited to once per turn per unit, and has its `cost` block ignored. The
only ability cost **implemented** is `"consume": N`, which destroys that much attached
energy; the rule itself is broader (see *Abilities are free*) and Forge's `"stoke"` and
`"scrap"` are designed but not built.
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

0. **Eyeball the board-clarity pass in a real game.** All fourteen harnesses are green at 989
   assertions, but every one of them checks *structure* — which nodes exist and what they say
   — and the whole point of this pass was legibility and feel. Six things only a human can
   answer, roughly in order of how likely they are to be wrong:
   - **Does a keyword chip's tooltip actually appear on hover, and does clicking the chip
     still select the card?** The chip had to move from `MOUSE_FILTER_IGNORE` to `PASS` to
     receive a hover at all, and mouse routing is precisely what a headless harness cannot
     exercise. This is the single most likely thing in the pass to be silently broken.
   - **Does picking a unit up fight hover-to-enlarge?** A board card raises a scaled copy on
     hover, and now the same press-and-move starts a drag. The rightmost slot already had an
     open question about where the zoom lands.
   - **Is the bottom-left attached badge readable at 132×196?** It sits at 8px against the
     footer's 7px. The footer measured 102 of 118 available px at a two-digit total, so it
     fits — fitting is not the same as reading.
   - **Do the gold card in hand and the gold rings on its targets read as one gesture?**
     And does the hint's new dim resting colour read as deliberate rather than as broken?
   - **Does the Gap row appear only in a Void matchup?** Pin a Void deck as the opponent from
     deck select to see it, then a non-Void one to confirm it stays hidden.
   - **Is ~7px board type still legible**, the question this item originally asked, now that
     the cost icons are solid rather than hollow.
1. **Read whether quarter-rate tower fire overshot.** The stall it was adopted to fix has
   not recurred, but the AI mirror fell from ~61 rounds to ~13 — back to roughly the length
   previously flagged as too short. This wants a human playtest rather than another AI
   sample, because the AI presents an empty board far more often than a human would and is
   therefore the worst case for exactly this rule.
2. **Toll Engine is beating everything** — 9-0 vs Barrow Wall, 8-1 vs Lamp Wall, 8-1 vs
   Widening Rift, 5-4 vs Verdict Engine over 9-run samples. It predates Void and is now the
   clearest balance outlier in the game. See `hel.md`.
3. ~~**Card art for Heaven and Void.**~~ **Done** — all 292 cards have emblems, both bestiary waves included.
4. **Walk the tutorial end to end as a player.** All fourteen lessons build and every step
   predicate fires against a real `GameState`, but the harness cannot read *pacing* — whether
   a step's text lands before the board changes under it, whether the coach panel is where
   the eye already is, and whether the gating ever refuses something a reasonable player
   would try at that moment. The nudge on a blocked action is the thing to watch: it is the
   one place the tutorial can feel broken rather than instructive.
5. **Human playtesting.** All four factions and eighteen sample decks now exist; every balance
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
- **Most attacks print a colorless half, and cost is the only thing that decides it.**
  A `{"hel": 4}` becoming `{"hel": 2, "colorless": 2}` means "any deck splashing 2 Hel may
  run this", which is what makes multi-faction decks buildable. **Two wrong rules were
  written before this one, and both are worth keeping.** The first protected lines whose
  *attack text* named a signature keyword, which found 7 lines where it meant 195 —
  `Toll` lives on `grave_whelp` while its attack "Gnaw" never mentions it, so the check was
  reading the wrong level of the data. The second read the card's keywords correctly and
  was still wrong, because **those keywords are the baseline rather than a scarce
  identity**: Toll is on 47 attack lines, Earth on 46, Judgment on 30, so protecting them
  left 194 of 230 lines pure and every `Judgment` Basic printing a pure `{"heaven": 4}`.
  A keyword on most of a faction's cards is not what distinguishes a deck; the faction's
  *energy* is — so identity gating lives in the **size** of the colored half, not in
  refusing to print colorless.
  **The general shape: a rule whose output preserves an invariant cannot be checked by
  testing the invariant.** Total cost never moves, so every harness passed under all three
  rules; the only thing that exposed the second one was looking at the actual cards.
- **Every keyword value is modifiable at runtime, and modifiers stack without limit.**
  The engine was inconsistent about this: `rift()` and `earth()` already accepted Tool
  grants and card effects, while `toll()`, `siphon()`, `decay()`, `judgment()`, `essence()`
  and `resist()` returned the printed value flat — so "a support that boosts Toll by 2" was
  impossible while the identical card for Rift already worked. That asymmetry was an
  accident of which keyword happened to need a Tool when it shipped, not a design decision.
  Everything now reads through `Unit.kw_value()`. The two ops carrying it name the keyword
  **in the data** (`{"op": "buff_keyword_all", "kw": "toll", "n": 2}`) rather than in the
  code, so the engine never needs a `grant_toll`, `grant_siphon`, `grant_decay` and so on —
  which is what makes cross-keyword rule-breakers authorable as cards instead of as engine
  work. Modifiers are history, so `Rise` and evolution clear them.
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
  **Superseded 2026-08-15 by 8 and 2** — see the entry below.
- **Structures grew to 75 (tower) and 150 (throne), and draw grew to 8/2 in the same
  pass.** Adopted because games were ending too fast — the AI mirror sat around 8 rounds
  against a docs note already calling round 9 too short for a deckbuilder. The two halves
  do different jobs and were deliberately taken together: bigger structures lengthen the
  clock, and the extra draw is what lets a player *use* the added time instead of waiting
  through it. A cleared board is what exposes a tower, so the deciding question late is
  whether you can rebuild one — and that is a draw problem, not an HP problem. Raising HP
  alone would have made games longer *and* more passive, which is the failure mode the
  Open Questions already name for tower stall.
- **The opening hand guarantees two Basics, not one, clamped to what the deck holds.**
  Setup deploys Basics and nothing else, so a one-Basic opener enters round 1 with a
  single body against a board that may show two — and under shielding, the side with
  fewer units loses its tower cover first. The clamp matters because the guarantee is a
  *re-deal* loop: without it, a deck running one Basic would exhaust all 20 shuffles
  chasing a second and hand back the last one anyway. Same deal-filter shape as before —
  the hand is reshuffled whole, never stacked, so nothing but the guarantee is biased.
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
  strict upgrade. Cost `Last Breath` its full heal (now a flat 80) and `Grave Warden's
  Oath` its (now a flat 120). Guarded by a test.
- **Healing is the reference ladder for priced supports: base 32, +48 per energy.**
  `Shore Up` 32 free, `Field Surgery` 80 for 1, `Grave Warden's Oath` 120 for 3 (capped
  below the 175 HP ceiling rather than the rate's 176). A free card can reach the same step
  by taking a condition instead of a cost, which is what `Last Breath` does at
  80-if-below-half. **Re-anchored x1.6 on 2026-08-17** — the ladder was set against ~50 HP
  bodies and never re-derived when the curve rose to 40-175. Healing went first because "how much" is a
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
- **Drag-and-drop was an input method until 2026-08-15, when free unit movement made it a
  rule change.** The old entry read *"never a new rule"*, and the ban on drag-to-rearrange
  was its main evidence: repositioning was `Reposition`'s printed effect, and giving it away
  would both delete the card and delete the rule that placement *is* targeting. **Both
  halves had already stopped holding.** Chosen targeting retired *placement is targeting* —
  an attack may name any living enemy unit, so placement became the default and the fallback
  rather than the only lever — and the card was **repurposed** (it now moves an *enemy* unit
  within its board) instead of being left a dead draw. What movement still costs the player
  is unchanged and is why it is not free of consequence: it decides which unit eats the tower
  shot, which one shields, what an unnamed attack faces, and whether a board is left clear.
  Dropping energy on a unit remains a shortcut for two existing legal actions rather than a
  third one, so that half of the original entry survives intact.
  **The general shape: a rule justified by another rule has to be re-examined when the rule
  underneath it changes** — this ban outlived its own premise by several months because
  nothing forced the two to be read together.
- **An attack's cost states what it REQUIRES; what a unit HOLDS moved to the bottom-left.**
  One widget had been encoding two questions: the cost icons beside each attack were filled
  left-to-right by attached energy, so the row doubled as a progress bar. That overload is
  what broke the requirement read. Encoding "held" as fill state forces an "unfilled" state,
  and `EnergyIcon`'s unfilled branch paints a black well and **returns before the faction
  colour is ever used** — so with `unit` null for every card in hand, every cost icon in
  your hand rendered as an empty colourless socket. The requirement was invisible on the
  screen where you decide what to play, and it shipped that way because the progress-bar
  behaviour was *documented as a feature* in three separate comments. Costs are now always
  solid and always in the colour they demand (colorless stays grey — *which* colour is part
  of the requirement), and attached energy is a faction symbol plus a number in the footer.
  The split serves "can this fire yet" better anyway: comparing a stated `3` against a
  stated `5` beats counting filled sockets, and a unit saving toward a 14-cost attack shows a
  number instead of a maxed-out row of eight.
  **The general shape: when one widget encodes two different questions, the second
  question's states will eventually corrupt the first one's** — and a test can enshrine the
  corruption, as one here did (`"2 attached energy fills 2 icons"` asserted the bug).
- **Single-target supports drop onto their target, and both input paths share one legality
  predicate.** Supports were click-then-click with the only feedback a hint at the top of the
  screen — furthest from the board, which is where the eye is during a pick. Dragging a card
  onto the thing it affects is the most direct statement of intent available. The pending
  card now also lifts **gold** in hand, matching the gold rings on its legal targets, so the
  card and its candidates read as one gesture; the hint's resting colour moved to dim so that
  gold could *mean* something. Tower support and two-unit supports stay click-only, since a
  tower is not a unit and one drop cannot express two picks.
  The load-bearing detail is that the drop path and the click path were made to call the
  **same** predicate rather than two that agreed at the time of writing. Making them share
  immediately exposed a live bug: the Tool drop path used `can_play_support`, whose TOOL
  branch never checked *ownership*, while the click path used `_tool_candidates`, which does
  — so `Deadweight`, the one enemy-attaching Tool, could be dropped on your own unit and
  ordinary Tools onto an enemy's. **Two code paths for one question is one path too many.**
- **Keyword chips carry their rules text as a tooltip.** The chips are the densest
  information on a card and had **no tooltip at all** — both the chip and its label were
  `MOUSE_FILTER_IGNORE`, so they could not even receive a hover. A chip is enough to
  *recognise* a keyword you already know and nothing whatever if you don't, which bites
  hardest where the rules are least guessable: `Void 2` and `Rift 2` are unreadable without
  the rules, and Rift additionally scales off a board-wide number the chip cannot show.
  `Palette.KEYWORD_HELP` is one table condensed from the Compendium's keyword pages, and
  `CardViewTest` asserts **every coloured keyword has an entry**, so a new keyword fails the
  suite until someone writes its help. `Windfury`'s entry says outright that it is not
  implemented — a tooltip must never promise what the engine cannot do.
  One trap found while wiring it: flipping the *header* row to `MOUSE_FILTER_PASS` by mistake
  (a shadowed `row` variable) pushed Combat's phone layout to **544 units**. `LayoutTest`
  caught it, which is the 540-unit assertion earning its keep on a change that had nothing to
  do with layout.
- **The Gap readout appears only when a Void card is in the game.** The Gap is a real board
  number at all times but **nothing reads it** without Void, so a permanent meter would be
  clutter in roughly three-quarters of matchups. `gap_is_relevant()` measures decks, hands,
  discards and boards rather than the board alone, so the readout does not blink in and out
  as Void units are drawn, played and killed. Both Gaps are shown, because they are **not
  symmetric** — if you hold 10 attached and they hold 4, yours is 6 and theirs is 0, and
  showing only your own would make an enemy Rift unit's damage unexplainable. Drawn in
  Rift's own purple, so the number reads as belonging to the keyword that spends it.
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
- **The card inspector is content-sized and centred, not a full-rect panel.** It was
  anchored `PRESET_FULL_RECT` with fixed 90/40 insets, so a four-line support card
  produced a 1341x907 sheet of empty panel with the card marooned in the top-left and the
  deck buttons stranded at the far bottom-right. The screen stopped reading as *a card
  being examined* and started reading as a page that had failed to load. It is now sized
  to its content inside a `CenterContainer` — 765 wide on every card, 542-689 tall
  depending on how much the card prints — with `MAX_PANEL` capping the scrolling rules
  region so a long unit still scrolls internally instead of growing off-screen, which is
  the one thing the full-rect version got right. Measured across all 292 cards: the cap
  never engages on desktop, so nothing scrolls that does not need to.
- **The inspector's rules text is grouped into boxed sections rather than run together.**
  Every line in the right-hand column was a dim label at the same size, so a card's own
  printed effect and the standing note that supports obey the 4-copy limit carried
  identical weight. A box per section (EFFECT / HOW IT PLAYS / KEYWORDS / ATTACKS /
  TOLL / RETREAT) restores the hierarchy the card itself has. Keyword names are tinted with
  `Palette.keyword_color()`, the same colour the board chips use, so a keyword is
  recognisable before it is read.
- **The evolution line sits under the card plate, in the card's own column.** It began
  filed among the rules text, which was wrong on ownership — the line is a property of the
  *card*, not a rule — and it was a horizontally scrolling strip nested inside a
  vertically scrolling column, so reaching a Stage 2 meant scrolling twice in two
  directions. Moving it to a full-width band under both columns fixed the nesting and
  overcorrected: at 749 units the strip read as the most important thing on the panel,
  when it is really wayfinding you glance at to see where a card sits in its family. Under
  the plate it gets the left column's 305 units, which three stages fit in at 290 without
  scrolling at all. **The failure mode was scale, not placement** — the same element was
  wrong at 749 and right at 305.
- **Every band on the phone layout adds to one column, so the phone cap is much tighter
  than the desktop one.** Phone stacks the plate above the rules and keeps the chain under
  the plate, so `MAX_PANEL_PHONE` is 500 tall against the desktop's 660 — at 600 the
  tallest card reached 1203 in a 1170-unit viewport. Desktop is unaffected because the
  chain shares the plate's column rather than the panel's height.
- **The scroll region's height cap must be applied deferred, and the measurement that
  would catch getting it wrong is not the one to reach for.** Read during `_build()`,
  the rules column's `get_combined_minimum_size()` is still 0 because its children have
  not laid out — which sets the scroll region's minimum to 0 and collapses the entire
  rules column, rendering the inspector as a bare card plate. The trap is that
  `get_combined_minimum_size()` on the *finished panel* still reports the correct 765,
  because the minimum is right while the drawn result is not. **A layout bug that only
  affects what is drawn cannot be caught by measuring minimums**; dumping the live node
  rects is what showed it.
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
  propagates to all 292 images in one run. They are symbolic — a shape that matches the
  *name* — because the art box is 74px and an illustration would be mud at that size.
  **The 74px read is the binding constraint, not the 128px one**: several Heaven and Void
  emblems were legible in the inspector and mush on the board, and every one of them failed
  the same way — a figure competing with its own props for the silhouette. The fix each
  time was to drop the props and let the *one* thing the card is about own the shape.
- **A card with no art falls back to its initials.** Art is optional so that adding a
  card to `data/cards.json` is never blocked on drawing one, matching the same
  ship-the-data-first pattern retreat costs used.
- **Activated abilities are free; `Consume` is the only cost one may carry.**
  *(Generalised 2026-08-16 — free by default, priced when printed, never from the pool.
  See the Forge entries at the end of this log. The reasoning below is unchanged and is
  why the generalisation kept the no-pool-energy half.)* Energy only
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
- **`Sanctuary N` is a depleting pool, and the overflow is bounded.** A boolean shield is
  popped identically by a free `Decay 5` tick and a 75-damage attack, making the cheapest
  chip the best answer to the most expensive shield, which is why the pool form was
  adopted. The pool originally ended in one *free full absorb* of any size — and that half
  was removed 2026-08-17, because it made every shielded body worth `N + an extra life`.
  Over 3M games `Sealed Light` measured 88–91% while its games ran four rounds longer than
  average, i.e. it won by being unkillable rather than by out-playing anything. The pool
  now drains exactly and the remainder lands; **plain Sanctuary keeps the full absorb**,
  since it has no pool and draining it exactly would delete the keyword. Sanctuary bodies
  also now pay ~18% of their damage for the keyword, which they previously did not — they
  hit *harder* than plain bodies while carrying 1.5–1.9× the effective HP.
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
- **The aura pays +1 HP per Earth but only +1 damage per TWO Earth, and cards may only
  break the rate additively.** The offensive half was halved on 2026-08-17: one point of
  Earth pays into every unit's max HP, both towers' HP *and* every attack, so at a flat
  +1/+1 a single point was worth six-plus stat points while costing one. Measured live,
  `Deep Grove` ran a **mean aura of 14.6, peaking at 78** — +14.6 damage on every attack
  from every body, free — and every Earth deck sat at 70–83% while the field averaged 50%.
  Halving only the damage side keeps the faction's identity (it still grows, still buffs
  towers, still raises its own ceiling) and removes the part that was doubling as an
  undercosted damage engine. Gaia's four decks fell from a 73.8% mean to 66.2%. The
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
  what does not work here.** **Updated 2026-08-14:** the project now bundles Inter and
  Cinzel, so the premise "bundles no font" no longer holds — but the conclusion does. Inter
  is a text face with no arrows, shapes or emoji either, so `GLYPH` and the mechanical check
  both stay exactly as they are. Bundling widened the floor; it did not remove the need to
  check.
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
- **It happened a fourth time, which proved the sandboxing rule cannot be the only guard.**
  The same symptom returned — a desktop window rendering the phone layout, `display.cfg`
  holding `{"layout_override":1}` — written by a throwaway screenshot script that has since
  been deleted, so nothing in the repo pointed at the cause. The rule above was already
  written down and already called unconditional; it failed anyway because it is **opt-in**,
  and an opt-in rule only binds the scripts whose authors remember it. Scratch verification
  scripts are exactly the ones that do not: they are written to be run once and thrown away,
  they never get reviewed, and they outlive their session only through the file they
  corrupted. `ViewportFit._save()` now refuses to write when `DisplayServer.get_name()` is
  `headless` unless the path is a sandbox one, which makes the unsafe case **unreachable
  instead of merely discouraged**. Verified by probe in both directions — an unsandboxed
  headless `set_override()` leaves the live file untouched with the guard, and clobbers it
  without. **The general shape: when a convention has been restated and violated three
  times, the next fix is a mechanism, not a fourth restatement of the convention.**
- **Phone Combat keeps the two boards side by side; the card shrinks to pay for it.**
  Reverses the stacking change, which was right about card legibility and wrong about what
  the screen is for. Stacked, a card gets 150 units and carries the full frame — but the
  battlefield becomes four rows and both sides are never visible at once. Combat's whole job
  is the **comparison**: what is across from what, which of their units is in range, whether
  a board is clear enough to reach the tower. A layout that shows one side at a time turns
  the read the screen exists for into a scroll. Six slots across, twelve on screen, at
  `6 × 78 + 5 × 4 + 2 × 10 = 508` inside 540 and 137 units per row — two rows instead of
  four, so the vertical `ScrollContainer` is gone too and the hand sits directly under the
  boards. **The general shape: legibility of a single element is not the same objective as
  legibility of the relationship between elements, and for a board game it is the second one
  that decides the layout.**
- **The phone board card is a reduced frame, and that is consistent with the one-layout rule
  rather than an exception to it.** 78 units admits no font size at which the full frame
  reads, so it keeps name, HP, keyword chips and the queued-attack marker and drops the art,
  ability banner, attack rows and footer. The rule those rows are protected by exists to stop
  a card **contradicting** itself in two places; a reduced card only ever *omits*, and
  tapping it opens the full frame. Uniformity was never the goal — non-contradiction was.
- **Deck select's contents pane is an overlay on a phone, not a stacked half.** Stacking gave
  the list and the contents about half the height each, which is the worst of both: too few
  decks visible to choose between, and too little of the contents to read. The list is what
  the screen is *for*, so it takes the whole column and a button summons the contents over
  the top. The builder deliberately keeps **tabs** instead, because the difference is which
  half is primary — in the builder you swap between collection and deck constantly while
  editing, so neither can be demoted to something you summon. Both modals follow the card
  inspector's recipe (scrim, outside-tap, X, Escape) so a modal never needs a gesture learned
  per screen.
- **The hand is draggable as well as scrollable, and the gestures are told apart by axis,
  not by timing.** Hand cards are already draggable — that is how you deploy, evolve and
  charge — so Godot's built-in touch panning could not be used: the card claims the press
  and every swipe would pick one up. Horizontal movement past 8px (and 1.4x more sideways
  than vertical) scrolls; anything else is left alone for the card. The mapping follows the
  geometry rather than being a convention to learn: the hand is a horizontal strip so
  sideways is the only way it can scroll, and every card destination is *above* the hand so
  playing one is always an upward pull. A hold-then-drag delay was rejected for taxing the
  common case, and the claim threshold sits below Godot's own drag threshold because a
  scroll claimed after the card drag has started never happens at all.
- **`LayoutTest`'s glyph scan lists files explicitly, so a new UI file is invisible to it
  until added.** `SettingsButton.gd` had been missing since it shipped and `DragScroll.gd`
  would have been too. Neither had a bad glyph, so nothing was broken — but a file outside
  the scan is exactly how the original glyph bug shipped, and the check is only worth what
  it covers. Both added; `EXPECTED_ASSERTIONS` moved 24 -> 26 for a known reason, which is
  the only way that guard means anything.
- **The contents label is reparented into the overlay, never duplicated.** One label means
  `_show_detail()` and every caller keep working whether the overlay is open or shut. It also
  needs a hidden owner while the overlay is closed: left parentless it is an orphan the scene
  tree never frees, which showed up immediately as leaked `RichTextLabel` RIDs in the harness
  — caught only because a clean checkout leaked zero, so the baseline was worth measuring
  before blaming the engine.
- **The project bundles Cinzel and Inter, and the licence question was settled before
  anything was downloaded.** Everything had rendered in Godot's built-in Open Sans, which
  is a good typeface and is also the loudest available signal that a Godot project has not
  been art-directed. Windows' Georgia, Cambria and Bookman were the obvious upgrades and
  are Microsoft/Monotype licensed: this repo is public and publishes to Pages, so a
  license-locked font is not a risk to manage but a thing that cannot be done. Both bundled
  faces are SIL OFL and **subset** to Latin-1 plus the `GLYPH` punctuation — 174KB for the
  pair against 1MB. Inter is installed as the root theme's `default_font`, which is what
  makes `LayoutTest`'s glyph scan validate against the font the game actually renders with,
  since it reads the font off a live `Label` rather than a path. Cinzel is display-only and
  `Palette.title()` refuses to draw it below `TYPE_SUBHEAD`, because an inscriptional face
  at 11px is less legible than the UI face rather than more characterful.
- **Bundling a font widened the safe glyph set; it did not retire the check.** Inter is a
  text face with no arrows, no geometric shapes and no emoji, exactly like the font it
  replaced. `Palette.GLYPH` and `LayoutTest`'s mechanical scan are unchanged, and the
  energy symbol is still the ASCII `#` in strings — the *drawn* `EnergyIcon` is the real
  answer wherever a cost is rendered. **The general shape: fixing the cause of a class of
  bug is not the same as removing the conditions for it**, and a check that costs nothing
  should outlive the specific font that motivated it.
- **The reskin is drawn in code, and the board's geometry did not move.** Seven new
  `_draw`-based pieces (`Crest`, `LanePanel`, `SlotSocket`, `TowerGlyph`, `FactionSpine`,
  plus the earlier `Starfield` and `Midline`) replace flat panels and captions. No bitmaps
  and no shaders: partly a constraint, since this project has no artist, and partly the
  same call the card art already made — drawn geometry is regenerable, cannot drift from
  the palette, and adds nothing to a 39MB download. Slot sizes, card sizes and the
  six-across phone row are all untouched, which is why the 540-unit assertions still pass.
- **`SlotSocket` extends `DropZone`, not `Button`, and that is what made it a reskin.** The
  whole drag contract, click-to-deploy and the tutorial ring are inherited rather than
  reimplemented, so replacing the appearance of every empty slot in the game left
  `DragDropTest` passing untouched. A visual change that rewrites behaviour is not a
  reskin, and the way to keep it visual is to extend the thing that already holds the
  behaviour.
- **The desktop and window icons are the Crest, and the icon that ships is not the
  emblem the menu draws.** Both are generated from `tools/make_icon.py`, a direct port of
  `Crest.gd` — but two things had to change, and the reason generalises. An icon has **no
  backdrop**, so the menu's 30% translucent throne (which reads only because a dark panel
  sits behind it) would be nearly invisible on transparency against a light wallpaper; the
  icon prints the colour that wash *resolves to* on the menu's ground instead. And Pillow's
  `polygon(fill=...)` **replaces** pixels rather than blending, so the first pass rendered
  every translucent shape as a flat opaque slab — translucent fills have to composite
  through a scratch layer. **A drawing ported between two renderers is not the same drawing
  until it is looked at**: both defects passed every structural check, because a shape that
  is drawn wrong is still drawn.
- **The desktop shortcut reads its icon from `%LOCALAPPDATA%`, not from the repo, and
  Windows caches it by path.** Regenerating `tools/Godsfall.ico` changes nothing on the
  desktop until the file is copied across, and `ie4uinit -show` and F5 both fail to shift
  the cache. The fix is to write the new `.ico` under a **filename Windows has never seen**
  and re-point the `.lnk`; a fresh path cannot have a stale entry. Worth logging because the
  failure is **misattributed by default** — the `.ico` on disk is correct and verifiable by
  decoding it, while the desktop shows the old art, so the obvious diagnosis is a broken
  generator rather than a lying cache. Same shape as the encoding traps already in this log:
  **the error's location is not the defect's location.**
- **`TowerGlyph` turns the tower's condition into a silhouette, and its cracks come from a
  fixed table.** Merlons break away as HP falls, cracks open below two-thirds, rubble
  gathers below a third — so *which tower is nearly down* is answered by shape rather than
  by comparing two fractions, which is the reason to draw a structure rather than restyle a
  panel. The crack positions are a constant, never RNG: Combat rebuilds the board on every
  state change, so a randomly-cracked tower would re-crack several times a turn. Same
  reasoning as `Starfield`'s fixed seed, and it is now the second time this project has
  needed it.

- **Attack costs were widened into per-stage bands: Basic 1–6, Stage 1 4–10, Stage 2
  8–20, with cost derived from damage at 7/8/9 per energy by stage.** A 100k-game sample
  found the ladder compressed at the bottom — **no Basic attack cost more than 3**, yet two
  Basics dealt 36–38, as much as a 5-cost Stage 1 — which is why 93.9% of every attack
  queued cost 1–3 and the 4+ tier was nearly dead content. The floor of the Basic band is
  set by the opening turn: **round 1 gives exactly 2 energy**, so 1–2 cost Basic attacks
  have to exist or nobody attacks on turn one.

  Two things were learned building it, both by getting them wrong first. **Rank-mapping a
  stage's attacks evenly across its band is not the same as pricing them**: spreading Stage
  2 across 8–20 by damage rank put a 42-damage attack at cost 14 (3.0/e) while the Stage 1
  under it dealt 60 for 9 — evolving would have been a strict downgrade. Deriving cost
  *from* damage at a target rate, with the band as a **clamp** rather than a target, is
  what keeps the arithmetic sane. And **a floor rate applied to a stretched band
  multiplies**: holding 9/e across an 8–20 band demanded 180 damage at the ceiling, which
  exceeds the largest printed HP in the game. That is the real constraint — above roughly
  cost 13 an attack cannot be bought with damage at all, so **the top of a band belongs to
  effect cards**, and the two that sit there already print 0 damage.

  The rate rising with stage (7 → 8 → 9) is what makes evolving worth its slower arrival.
  Stage 2 damage roughly doubled to fill the usable part of its band, capped at 120 so no
  single attack deletes a 175 HP body outright.

  **Cheap attacks fire ~3x as often as expensive ones**, because an attack's cost is
  paid once and the attack is then free every turn. So the printed mix and the played
  mix are not the same distribution, and pricing to a target *played* share means
  making cheap attacks genuinely scarce on the cards — six round-1 openers in the whole
  game, against 46 attacks at cost 4+.

  Re-pricing is **not** a balance fix and did not act as one: the deck spread was unchanged
  and the game lengthened only 8.06 → 8.43 rounds. Higher costs do slow the game for both
  sides — that reasoning is sound and short games halved — but the 8-round median is
  dominated by tower fire being 52.6% of all damage dealt, which no cost change touches.

- **UI colour is split into faction-neutral chrome and meaningful content, and the
  collisions were separated by hue.** `ACCENT` was byte-identical to Hel's purple, so
  every button hover, selection ring and focus state in the game was Hel-coloured
  whatever the player was actually playing — the UI silently declaring the whole game
  to be one faction. `HP_GREEN` equalled Gaia's `earth` and `DANGER` equalled
  `retribution`, so a healthy unit and a Gaia keyword were the same green. Fixed by
  moving hue rather than brightness: **a difference you need two swatches side by side
  to see is not a difference on a 7px chip.** Each faction also became a deep/base/bright
  ramp, because a flat fill reads as a coloured sticker and three tones read as a
  material — which is most of what makes the energy hexagon, the game's most-printed
  mark, look struck rather than drawn.
- **`GradientTexture2D` cannot be assigned to a code-built `StyleBoxFlat`, and the
  failure is a hang rather than an error.** Isolated by probe to that exact assignment;
  the `Gradient` and the `GradientTexture2D` both construct fine alone, and it is the
  binding that needs a rendering server. Every screen must build headlessly for the
  harnesses, so a gradient fill costs the entire test suite. Light is implied with edges
  and shadow instead. The general shape is one this log already carries: **a feature that
  works in the editor and hangs headless is indistinguishable from a slow test**, and the
  first LayoutTest run after adding it simply timed out at two minutes with no message.
- **Motion is diffed in the UI, never added as engine signals.** Combat rebuilds its
  board wholesale on each `state_changed`, so the node holding a unit's old HP is freed
  before the new one exists and a card cannot tween its own value. The UI snapshots HP by
  instance id and compares as the replacement card is built, which keeps the rules engine
  untouched — it still emits `state_changed` and nothing else. One shared `Motion.gd`
  owns every duration, because animations assembled per call site are what make an
  interface feel homemade: two panels fading at 0.15s and 0.4s read as two products.
- **Throne growth is deliberately not animated, and that omission is the point.** Damage
  flashes; the +5 both thrones gain every round does not. A pulse that fires
  unconditionally teaches the eye to ignore it, which would cost the flash its meaning on
  the turn it matters. **The general rule: feedback that fires on every tick is
  indistinguishable from no feedback**, and it is worse, because it also hides the signal.
- **Type and space are scales; picking a size per call site is what looked amateur.** The
  UI carried fifteen distinct font sizes with 12/13/14/15/16 all in heavy use, and twelve
  separation values including 1, 2, 3 and 5. Steps that close cannot be perceived as
  different, so the screen reads as one undifferentiated middle weight with nothing for
  the eye to land on — the problem is not that any single number is wrong, it is that
  there is no system for them to be right *within*. Also retired the board divider, a
  `Label` holding forty-nine hyphens, in favour of a drawn `Midline` that fades at both
  ends: **typed punctuation standing in for a graphic is one of the most reliable tells
  that an interface was assembled rather than designed.**

- **A deck is fronted by its hero card's emblem, never by a shrunken card.** The
  first attempt scaled a whole `CardView` to 74px and it was mush: a card frame is
  a *layout of nine small elements*, so shrinking it makes all nine illegible at
  once rather than simplifying any of them. The emblems were drawn at 128px to be
  read small, and they are what survives. The plate also lost its caption, which
  clipped to "pyrean Senti" and duplicated the deck name sitting beside it.
  **The general shape: reducing a composite element is not the same as scaling
  it**, and the phone board card had already established which one works.
- **A `…` overflow menu replaced thirty row buttons on deck select.** Rename /
  Copy / Delete on ten rows made the destructive actions the loudest thing on a
  screen whose only job is picking a deck. `OverflowMenu` extends `MenuButton` so
  keyboard nav, outside-click dismissal and edge positioning come for free —
  the same reasoning that made `SlotSocket` extend `DropZone`. Destructive items
  get a separator rather than a colour, because `set_item_icon_modulate` tints an
  *icon* and menu items here have none: the obvious call would have compiled,
  run, and done nothing.
- **The deck grid fits its column count to the pane's measured width.** Hardcoded
  at 5 it left ~330px empty on a 1440-wide window, and the deck pane is the half
  you judge as a whole. Recomputed on `resized` rather than once at build time,
  since the split handle is draggable. The builder's hover-detail panel likewise
  sizes to its content — it had reserved 120px permanently to say "Select a card".
- **`CompositionBar` shows type mix, not a mana curve, and that is the point.**
  Every deckbuilder in the genre draws a cost curve; here it would measure
  something the player never pays, because costs sit on *attacks* and cards are
  free to play. **A genre convention has to be re-derived against this game's
  rules rather than copied**, and the deck's type mix is what the equivalent
  question actually is. Drawn in chrome tones, since type mix is orthogonal to
  faction colour and the ramps would misread as energy.
- **The settings cog had been overlapping every screen's top bar.** It is drawn
  on a `CanvasLayer` above the scene, so it is invisible to each screen's layout
  and both deck screens ran controls underneath it. Screens reserve
  `Palette.COG_RESERVE` and `SettingsButton` asserts the cog still fits inside
  it, so the two cannot drift. The constant lives on `Palette` rather than on the
  `Settings` autoload because naming an autoload at a screen's class scope breaks
  every headless harness — the third time that trap has come up.
- **Every energy cost carries a hover tooltip, and each faction's token carries a
  distinct drawn mark.** Two channels were each doing only half a job. The icon row
  states a requirement precisely and has **no channel left** for how much of it is
  already paid — it used to encode that as fill, and that overload is what rendered
  every requirement in hand as an empty grey socket (logged above); so the paid/owed
  split, the colour breakdown and the Consume-vs-attack distinction now live in a
  tooltip, where they can be read one card at a time on demand. And the four factions
  differed **only by hue**, which is the same defect `KEYWORD_COLORS` was fixed for: at
  the size a cost row draws at, Void's slate and Wilds' brown are one grey, and a
  colourblind player got nothing at all from the system. Each token now carries one
  closed figure — bone, sun, hole, leaf — so the sheet is readable in greyscale.
  Three things were learned building it, all by getting them wrong first:
  **(1)** `MARK_MIN_PX` was set to 11 against a comment claiming the desktop hand row
  was 12 px. It is **10**, so the mark would have drawn *nowhere* in the entire game —
  a feature that is inert everywhere still passes every structural assertion, because
  a shape that is never drawn breaks no layout. The threshold is now derived from
  `CardView.METRICS["icon_size"]` and asserted against it, so the two cannot drift.
  **(2)** Hel's mark was a skull and read as a **blob**; Wilds' was a three-talon claw
  and read as a **crown** — the mark said "Heaven" on the brownest token in the game.
  Both failed the way the wave-2 emblems failed: a skull is identified by its eye
  sockets, which are *interior negative space*, and a single filled polygon has no
  interior. Replaced with a bone and a single fang, whose identity **is** their
  outline. Caught only by rasterising the geometry at 10px and looking at it — the
  assertions confirmed eight distinct polygons the whole time, which is true and says
  nothing about whether any of them reads as its subject.
  **(3)** `contains(str(taxed))` looked like a fine assertion for the Deadweight tax
  and **passed with the bug deliberately reintroduced**: the printed cost is 1, the
  taxed cost 2, and the tooltip's colour-split line already contains a "1". Tightened
  to match the exact sentence, then re-sabotaged to confirm it fails. **A substring
  search for a single digit inside generated prose is not a test**, and the only way
  to know is to put the bug back.

- **`ViewportFit` must measure the window, never `root.get_visible_rect()`.** The auto
  detection read the viewport — a value `_apply()` sets itself — so entering phone mode
  shrank the viewport to 540, the next read saw `540 < 820`, and a 1440-wide desktop could
  never get back out. It is a control loop reading its own output as its input, and the
  symptom was the settings panel cheerfully reporting *"Auto would pick phone for this
  window"* on a full-size desktop.

- **Every unit became a creature and the roster doubled to 114 units / 172 cards,
  without a single card id or mechanic moving.** The ids are internal and heavily
  referenced (130+ times across 15 files), so renaming only the display `name`
  bought the entire creature reskin for zero engine churn — the tutorial, all ten
  sample decks and every harness kept working untouched. **The general shape: when
  an identifier is load-bearing and a label is not, change the label.**
- **A naming system's suffix pools have to be per-faction, or the system defeats
  itself.** The first draft shared one suffix table across all four colours, which
  makes every faction's Basic end in the same syllable — 114 cards that rhyme, and
  half of every name carrying no faction information at all. Per-faction pools
  (`-drung` is Hel, `-nought` is Void, `-thane` is Gaia) mean a name places its own
  colour before you read the card. `-colossus` was retired outright: it is a
  complete English word, so it reads as a title bolted onto a stem rather than as
  one creature's name, and it had appeared in two factions at once.
- **A chain shares a silhouette as well as a stem.** Each family is one shape
  function called at three scales rather than three independently drawn emblems,
  because independent drawings drift and the evolution read is exactly what cannot
  survive that. Three emblems had to be redrawn after looking at them at *board*
  size rather than at 128px: a shroud drawn under a skull was invisible, three
  bells at equal size read as a mound, and wings behind a shield read as a flying
  saucer. All three failed the same way the Heaven and Void emblems failed once
  before — **a figure competing with its own props for the silhouette** — and the
  fix each time was to drop the props.
- **The card generator enforces the design rules instead of trusting the author.**
  `tools/add_bestiary_units.py` derives cost from damage on the documented curve
  and refuses to write when a card breaks the two-line rule, an HP band, a Judgment
  cap, the Sanctuary floor, the no-new-openers rule, or Void's damage budget — and
  it scrapes the implemented `op` list out of the GDScript so a card cannot print an
  effect the engine silently ignores. Two Rift 2 cards were authored over budget and
  the check caught them; the Void budget then moved into the generator so the same
  mistake surfaces at authoring time rather than in a harness three steps later.
  **A guard that only exists in the test suite is a guard you hit late.**
- **Census assertions and invariant assertions are different things and should be
  labelled as such.** Doubling the roster broke five `VoidTest` counts (`15 Void
  units`, `6 Basics`, …) while every invariant it checks — the two-line rule, the HP
  bands, the retreat formula, the damage budget — passed untouched. The counts exist
  to catch a card failing to load, not to freeze the roster, and they are now
  commented to say so. `CardViewTest` had the same shape in a smaller way: it
  hardcoded the literal `"Charnel Colossus"` and broke on a rename while the frame
  it was testing was perfectly correct, so it now reads the name off the card.

- **Wave 2 added 30 creatures per faction (234 units, 292 cards), pitched at three
  deliberately different power levels.** At this size a 60-card deck picks ~12 unit
  slots from ~57 candidates, so most cards are *collection* content rather than deck
  content — and writing 120 more cards all competing at the same power produces 120
  interchangeable creatures, which is the sameness failure one layer down from the
  naming one. So each faction got roughly 12 vanillas, 13 staples and 5
  build-arounds. **Uniform power is not the same thing as good balance** once a
  roster outgrows what a deck can hold.
- **A card need not touch a mechanic, but a keyword-less Basic must evolve into one
  that does.** A vanilla body is a legitimate card — cheap, clean, the bottom of a
  line — while a vanilla that goes *nowhere* is a dead draw. Enforced in the
  generator rather than by care: a Basic with no keywords fails the build unless the
  next form in its chain carries one. 42 of the 234 units are vanillas on those terms.
- **Wave 2 assigned each family a distinct drawing object up front, instead of
  varying a shared one.** Wave 1 learned this the hard way: Rime and Oss were both
  "purple skull with marks radiating out" and were indistinguishable at 78px until
  Rime was redrawn as an ice crystal. At 234 units across four colours, "another
  skull" and "another green mound" identify nothing — so Hel wave 2 is fens, shrouds,
  embers and husks (never skulls), Heaven is books, chalices, keys and candles (never
  halos), Void is spirals, wedges and lacunae (never the round hole-with-a-rim), and
  Gaia is ferns, sedge, amber and burrs (never generic mounds). **A visual grammar
  has to be partitioned before it is drawn, not deduplicated afterward.**
- **Two wave-2 emblems still had to be redrawn, and both failed the same way: not
  enough object.** `Grimkin` was a pair of scales, which at 78px is a thin cross with
  two commas; `Sevsk` was a line with two dots. Both were replaced with a single
  closed shape (a spiked collar, a chain with one severed link). The wave-1 lesson
  was *too many props*; the wave-2 lesson is the mirror of it — **a silhouette needs
  exactly one object, and thin linework is not one.**

- **Eight decks were added so the bestiary is reachable without hand-building.** Two waves
  took the roster to 234 units, and the ten shipped decks used **55 of them** — so 179
  creatures existed only as collection content, which is the deck-screen version of the bug
  where Heaven's cards loaded fine and could not be added to a deck. Each new list is
  anchored on a **wave-2 Stage 2 whose free ability is the archetype** (Interment, Exhume,
  Renewal, Reaffirm, Expunge, Consume Light, Upthrust, Seed the Grove) rather than on a pile
  of same-colour bodies, which is what makes eight new decks read as eight plans. The
  pairing rule from the original four still governs: one idea per list, and the support mix
  is part of the identity.
- **The new decks were checked for stranded evolutions before anything was run, and one was
  found.** Bedrock ran Petriwold without Petribud — the same trap that cost Toll Engine its
  Mourning Bell. Worth noting that **no harness catches this**: `errors_at()` checks size,
  energy, Basics and the copy cap, and a deck full of unplayable Stage 1s is legal by every
  one of those. It is a design-time check, so it needs a design-time pass.
- **A deck that validates is not a deck that plays, so the eight were driven through real AI
  games.** Five games each against an established foil finished 7–12 rounds with **zero
  stalls** — the point being that `DeckStoreTest` proves a list is *legal* and says nothing
  about whether it functions, which is the same distinction `TutorialWalkTest` exists for
  ("valid" vs "completable"). The win-loss spread (Sealed Light 5-0, Thicket 1-4) is **not a
  balance reading**: five games is noise, and the AI has no Judgment or Sanctuary heuristics
  and dumps its whole pool onto one body, which flatters Rift decks and wastes Heaven's.

- **Forge is the fifth faction, it absorbs Tempest, and its aggression is a *currency*
  rather than a discount.** Designed 2026-08-16; no cards, no engine work. The reasoning
  that decided the shape: **"aggro" has no obvious meaning in this engine**, because cards
  are free to play and the board caps at 4 — cheap bodies cannot be an identity when every
  faction deploys for free and Hel is already the disposable-bodies deck. The only
  structurally available meaning is *acting more often than your energy should allow*,
  which was also Tempest's entire stated identity, so the two reserve colors were competing
  for one slot and Forge takes it.
  Signatures are `Stoke N` and `Scrap`, plus the shared `Consume` printed widest.
  **Stoke went through two designs and the second is the one that works.** The first made
  it an *alternative cost* — pay 3 energy or pay 20 HP, pick one — which produces a flat
  decision: you evaluate whether HP is cheaper than energy right now and the answer is
  nearly always the same within a turn. The second makes Stoke a **free once-per-turn
  ability that sets a per-unit state**: you lose the HP, the unit "has stoked," and
  *separate lines read that flag.* That produces a sequencing decision instead, and one
  Stoke can turn on several payoffs at once, which is what makes it a build-around rather
  than a discount. `Scrap` stayed a cost, but an **ability** cost, occupying the same slot
  `Consume` does.
  **The load-bearing distinction is Forge vs. Hel, since both feed units into a grinder:
  Hel's deaths are a trigger, Forge's are a cost.** A Hel body left alone still eventually
  pays its `Toll`; a Forge body left alone has done nothing. Stated because without it
  Forge is a reskin of the faction it sits next to in the cosmology.
- **Forge's aggression lives in faction-locked supports, and that required correcting what
  the support power band is actually for.** The original request was "powerful support cards
  with no energy cost," which as stated breaks the band — but the band's real constraint is
  not *"supports must be weak,"* it is **"cards every deck can run must be weak."** All 43
  neutral supports are legal in all eighteen decks, so a strong free neutral support raises
  every deck's floor and gives Forge no identity at all. A **Forge-locked** support is
  instead bought with a deckbuilding commitment, which is a cost the neutral cards never pay
  — and faction-colored supports already exist (Void has 4, Gaia 5), so this is not a new
  card type, only the first faction whose identity is carried by its support suite.
  **One asymmetry had to be replaced explicitly.** Supports are normally kept off the damage
  curve by the fact that an attack's cost stays attached and pays out every turn while a
  support's is spent for good. **A Stoke-paid attack builds no annuity either**, so that
  brake does not exist for Forge, and the rule is restated as an absolute instead: a Forge
  support's damage per unit of cost must sit visibly below the attack curve *regardless of
  currency*. Forge supports buy reach and speed, never raw damage.
- **`Windfury` is the largest piece of engine work Forge implies, and its one hard
  constraint now has a named failure mode.** Windfury is documented and **unimplemented** —
  no card uses it — so the multi-attack faction cannot ship without a second queued attack
  slot on `Unit`. The standing rule that Windfury may never appear with `Judgment` is most
  likely to be violated through a **multi-faction Forge/Heaven card** rather than a
  mono-Forge one, which is why a board-wide *"your units gain Windfury"* effect is not
  printable in Forge at all: in a two-color deck it would grant it to Heaven bodies.
  Forge's Windfury is always on the printed card.

- **Stoke is unpreventable, and `stoked` is a state cards may want to be in.** `Sanctuary`
  does not absorb it and `Resist` does not reduce it, because a shielded body would
  otherwise stoke **for free** — the faction's central cost would be optional in exactly
  the matchups where it needs to be real. The price of that decision is that Forge/Heaven
  and Forge/Gaia lose a synergy they would have got for free from the keyword interaction,
  so those pairings now need a *printed* reason to exist.
  The second half matters more: because the flag exists independently of what it paid for,
  a card may read it with no attack involved — and *"heal this unit for the HP it stoked"*
  is therefore **not a cost eraser**, since the unit still counts as having stoked and
  every other payoff stayed on. That only works if other cards read the state, which is
  what turns Stoke from a price into a condition you may want to be in.
- **`Stoke N` varies by unit, anchored at 20 HP ≈ 1 energy of value.** Varying N is a
  balance axis (a Basic stokes 20, a Stage 2 may stoke 50), but a **binary** payoff makes
  a large N strictly worse — every deck would run the cheapest body that turns the flag on.
  Two fixes, both used: amount-scaling payoffs (*"+1 damage per 2 HP stoked"*) and
  thresholds (*"if this unit stoked 40 or more"*), with thresholds as the natural home for
  the effects that break board geometry. The anchor itself is derived rather than invented:
  attached energy is an **annuity** — pay once, fire free every turn — while HP is spent for
  good and never returns above printed max, so Stoke must buy visibly less per use than
  energy does. An earlier *1.5 damage per HP* figure was coherent for the alternative-cost
  design and is meaningless now, since Stoke no longer buys an attack.
- **The Stoke flag is per-unit, and board-wide readers must print that they read others.**
  Per-unit is the baseline because it is cheap to reason about and easy to price; a card
  that reads another unit's flag is the **rule-break**, printed deliberately and rarely.
  This is the general shape Jonah asked the game to follow — *"everything has a break,
  that's what makes each card powerful"* — applied to the faction's own build-around axis,
  the same way Gaia's additive `earth_rate` breaks the aura's linearity.
- **Ramp payoffs are the one Stoke class that needs a hard limit.** *"If this unit stoked,
  attach N energy to it"* converts HP into a **permanent, decay-immune** resource that also
  feeds Void's Gap — and one-energy-card-per-turn is the game's central pacing dial, so a
  repeatable ability that walks around it is how a faction accidentally becomes a ramp deck.
  The safer form is always the one that expires: *"this attack costs no energy"* is a
  one-turn discount, while *"attach 3"* is permanent. Excluded from the core set entirely.
- **Abilities are free unless they print a cost, and the printable costs are non-energy.**
  The rule previously read *"an ability may carry a Consume; it may carry nothing else"* —
  written when Consume was the only non-energy cost anyone had designed, so the closed list
  was an accident of what existed rather than a decision. Forge's `Stoke` and `Scrap` made
  it false. The generalisation — **free by default, priced when printed, never from the
  pool** — is what the original rule was actually protecting, since the thing that must not
  happen is an ability charging *pool energy* (energy only buys attacks). The data
  enforcement is unchanged in shape: an `"ability": true` line still ignores its `cost`
  block, and now reads `"consume"`, `"stoke"`, and `"scrap"` instead of `"consume"` alone.

- **Forge shipped: 19 cards, and `Stoke` is a state rather than a payment.** The first
  design made it an *alternative cost* — pay 3 energy or pay 20 HP, pick one — which
  produces a flat decision you re-evaluate identically every turn. What shipped is a free
  once-per-turn **ability that sets a per-unit flag**, with *separate lines reading it*.
  That produces a sequencing decision instead, and one Stoke turns on several payoffs at
  once. `Scrap` is the other signature and stayed a cost, but an **ability** cost in the
  same slot `Consume` occupies.
  **`Stoke` is deliberately not routed through `take_damage()`**, and that is the whole
  keyword: `Sanctuary` does not absorb it and `Resist` does not reduce it, because it is a
  cost the controller chooses to pay rather than damage from a source. Through the damage
  path a shielded body would stoke **for free**, and the faction's central cost would be
  optional in exactly the matchups where it has to be real. `ForgeTest` runs those two
  assertions **first** in the file for that reason.
- **The AI's "free abilities are always taken" default is actively wrong for Forge, and
  finding that took a real game rather than a harness.** Stoke costs no pool energy, so
  `_ability_worth_it()` classified it as free and the AI stoked **every turn regardless of
  whether a payoff followed** — burning its own board down for nothing. `_stoke_worth_it()`
  now requires that a line *on that same unit* actually reads the flag (it is per-unit, so
  another body's payoff is no reason to burn this one), that the unit survives the cost, and
  that it is not already too hurt; Scrap additionally refuses below three living bodies.
  **The general shape: a cost the engine does not charge in pool energy is invisible to a
  heuristic that measures pool energy**, and every existing free-ability check was written
  when "free" and "costless" were the same thing.
- **A `stoked_` payoff on a line that cannot itself Stoke is silent dead data, so the
  generator refuses it.** `Gristgnash` was authored with a Scrap ability carrying
  `stoked_bonus_damage` — but Scrap does not set the flag, only Stoke does, so the effect
  could never have fired. It would have parsed cleanly and done nothing, which is the exact
  shape of the dropped-`effects` bug already in this log twice. `tools/add_forge_faction.py`
  now rejects it at authoring time, and the check was verified by **putting the bug back and
  watching the build refuse**.
- **Three Forge emblems had to be redrawn after looking at them at 78px, and all three
  failed the way the bestiary waves already documented.** The hammer was a head and a haft
  drawn as two separate polygons with a gap, which read as two grey blobs — fixed by
  overlapping them so the silhouette closes. The crucible was drawn *tipped*, and a rotated
  quad has no distinguishing outline at 20 pixels across, so it read as a plain grey
  rectangle — redrawn upright with an exaggerated taper and a bright molten brim, which is
  what identifies the object. And the steam was three tapered spikes, which read as blades
  rather than vapour — replaced with overlapping circles. **The structural assertions were
  green throughout**: they confirm an emblem exists, never that it reads as its subject.

- **An attack's conditional rider was never drawn on the card, on 26 attack lines across
  every faction.** `_add_attack_rows` rendered cost icons, name and damage and never
  `atk.text`, so `Ember Strike` showed `28` with nothing to say that stoking adds 10 — and
  `THE LAST TOLL` had been showing `—` with nothing to say it destroys both boards **since
  Hel shipped**. Jonah found it by looking at a Forge card in the game; no harness could
  have, because `CardViewTest` asserted which nodes *exist* and never that a card states
  what it does.
  This is the same failure as the spent-`Judgment` chip and it is worth stating as the
  general rule it now clearly is: **the engine being right is not the card being readable.**
  Both bugs were correct in `GameState`, invisible on the frame, and indistinguishable from
  broken to a player.
  The fix draws only the part of the text that is *not* a restatement of the damage number
  already beside it, because a "28 damage" line next to a `28` is noise on a 132px card.
  Guarded by a regression test that was **verified by putting the bug back** — with the
  rider suppressed it fails two assertions, which is the only thing that makes a
  written-after-the-fact test worth anything.
  One trap worth keeping: the first version of `_attack_rider` used a `RegEx`, and the
  backslash escapes did not survive being written through a Python heredoc — the parser
  died on `Invalid escape in string` and the whole of `CardView` failed to load, which
  surfaced as *every* structural assertion failing at once rather than as anything to do
  with regexes. Plain string scanning replaced it.

- **Forge went to full parity (19 → 63 cards), and the expansion was engine-first because
  it had to be.** Forge's original 13 units read as five chains but only three *ideas*
  (stoke-then-hit-harder, scrap-a-body, heal-the-stoke-back), and the reason was structural:
  **nine of the eleven payoffs `forge.md` catalogues were designed and unimplemented**, so
  any new chain built on the shipped ops was forced to reprint `stoked_bonus_damage`. Adding
  cards first would have produced a wider faction that was not a deeper one. So the ten
  missing ops were built, and each of the eight new chains then got one to *own*: Bellow the
  extra attack, Char the sweep, Scoria unpreventable damage, Flux the economy, Tind the
  double-stoke engine, Drossal Scrap-plus-Consume, Anneal Retribution, Ingot the two
  geometry breaks. **The general shape: when a faction reads as repetitive, check whether
  its design doc is describing mechanics the engine does not have** — the cards can only be
  as varied as the ops underneath them.
- **`Windfury` was deliberately NOT built, and the faction is complete without it.**
  `forge.md` calls it the largest single piece of engine work Forge implies (a second queued
  attack slot on `Unit`) and simultaneously prefers `stoked_extra_attack` — a *conditional*
  grant — on the grounds that the condition sits on a Forge body and therefore cannot drift
  onto a `Judgment` card the way a granted keyword could. Building the conditional version
  gave the multi-attack identity its cards while leaving the standing Windfury/Judgment
  constraint untouched. The second attack slot exists on `Unit`, so printed Windfury is now
  a smaller job than it was, not a larger one.
- **Two geometry breaks never stack on one line.** `_deliver_attack_damage` treats
  `stoked_sweep`, `stoked_both_boards` and the shielding break as mutually exclusive rather
  than cumulative — an attack that sweeps does not also strike a second board. A card
  wanting two rule-breaks is a card that should have been cut, and making them exclusive in
  the *dispatcher* means no future card can combine them by accident.
- **`stoked_twice` refreshed its own permission, and only a sabotage pass found it.** The
  grant is consumed by the second Stoke (`Unit.spend_ability`), but the second Stoke re-runs
  the line's own riders — which re-granted it, making Stoke unlimited and turning the
  once-per-turn ability limit into a formality. The fix reads `has_used_ability` **before**
  `spend_ability` consumes the grant and passes it down as `was_repeat`. Worth logging
  because the bug is invisible in the code (both halves read correctly on their own) and was
  caught by an assertion that a *third* Stoke is refused — the case nobody writes unless
  they are deliberately probing the boundary.
- **Every new op was verified by putting the bug back, and one test was vacuous.**
  `_test_grants_expire` called `p.start_turn()`, which does not exist on `Player` — so the
  call silently no-opped and all five of its assertions passed against nothing. The sabotage
  pass caught it precisely because it was the one sabotage the suite did *not* notice.
  **A test that passes when the feature is removed is not a test**, and the only way to know
  which ones those are is to remove the feature. Nine of ten sabotages failed the suite as
  intended; the tenth is why the pass is worth running at all.
- **The rule-4 guard on Forge supports was written wrong first, and the cards disproved it.**
  `forge.md`'s binding constraint is that a Forge support may not sell damage more
  efficiently than an attack, so the generator first checked *damage per pool energy* — and
  refused `Cold Shut` at 25-for-1. But the two neutral damage supports (`Collapse` 20,
  `Toppling Blow` 25) are both **free and restricted**: the restriction is what they pay
  with, so dividing by a pool cost of 0 measures nothing. The guard is now an absolute
  ceiling set by the existing neutral maximum. **A rule expressed as a rate cannot be
  checked against cards that pay in something other than the rate's denominator.**
- **Op-reachability is a third question, distinct from "the op works" and "the AI finds
  it".** `ForgeTest` proves each op resolves when driven directly; a probe over six AI games
  showed several never firing. That is an **AI heuristics gap, not an engine defect** — the
  pre-existing `stoked_cleave` and `Scrap` never fire either — and it was confirmed by a
  separate probe that plays each card as written through `use_ability` and `queue_attack`
  and reaches every one of them. One real bug did surface from it: `_queue_attacks` skipped
  any unit with an attack already queued, so the AI could stoke, pay the HP for an extra
  attack slot, and then never use it.
- **The AI's Forge payoff check could not see payoffs on the Stoke line itself.**
  `_stoke_worth_it` scans the unit's *other* lines for a `stoked_` op, which was right when
  every payoff sat on a later attack. The expansion put draw, the decay skip, the extra
  attack slot, the second Stoke and the discount on the **ability**, which the scan
  deliberately skips — so the AI refused to use cards whose whole point is the ability.
  `stoked_heal_back` is deliberately excluded from the added list: it refunds the cost and
  pays nothing on its own, which is exactly the no-op case the check exists to catch.
- **A `git checkout` on one file destroyed uncommitted work in it, and the harnesses are
  what caught it.** Reverting `scripts/core/Player.gd` to discard a temporary sabotage also
  discarded the 8-card opener, draw 2, the 150 HP throne, the two-Basic guarantee and the
  Stoke per-turn reset — none of which was committed. `RulesTest` fell from 146 to 112 with
  eleven failures all naming a throne at 100, which is what made the cause findable at all.
  **`git checkout <file>` is not an undo for an edit made this session** when the file also
  holds work that was never committed; the safe revert is a copy taken before the edit,
  which is what the other sabotages used.

- **Tempest is revived as the accumulation colour, and the two signatures are `Charge`
  and `Storm`.** The 2026-08-16 absorption into Forge left one door open — *"revivable
  only as a genuinely different idea"* — and this clears it: nothing here competes with
  Forge's multi-attack claim, which `Bellow`/`stoked_extra_attack` and the `Second Wind`
  deck now hold concretely. **Tempest is the only faction whose resources persist and grow
  across turns**; everything else is instant (`Stoke`), live (`Earth`), binary
  (`Judgment`), or decaying (the pool). Against Gaia, the distinction is wide versus deep:
  Gaia's aura rewards keeping many bodies alive and shrinks the instant one dies, while
  Tempest's counter sits on one body and is lost whole with it.
  **Four decisions were reversed mid-design and each reversal is the useful part.**
  *(1)* `Charge` grows on damage **dealt only**, never taken — the both-ways draft made
  the counterplay *"stop attacking"*, which is the weakest kind, and it collided with
  shared `Retribution` on a board where Gaia's `Thicket` is already the Retribution-wall
  deck. *(2)* `Storm N` is **one instance of N**, not N instances of 1 — the multi-instance
  reading was accidentally a **`Resist`-piercing** mechanic, since `Resist` floors each
  instance at 1 damage, so armour would have become useless as Storm climbed. *(3)* The
  `Charge` bands were re-derived twice as the growth rules changed, which is why the
  numbers in the spec are the third table and not the first. *(4)* Two chains had their
  `Charge` **removed** rather than given a spender, because a faction where every body
  carries the keyword is the sameness failure the bestiary waves already documented.
  **Charge is the third thing to survive evolution**, after attached energy and Tools, and
  for the identical reason: without it, evolving would punish the one faction whose
  resource is time, so the correct play would be never to evolve. The value carries and
  the rate does not — **evolving is Tempest's rate increase.** It is still lost on death
  (the counterplay), on `Rise` (*"Rise restores the card, not the history"*), and on
  retreat (which would otherwise launder a counter past every piece of removal).
  **Three deliberate bets are recorded in the spec rather than designed away**, each one
  a place where a modelled concern was overruled: Storm is permanent/uncapped/symmetric,
  Charge is uncapped with the tower clock as its only brake, and every instance grows
  Charge. The case for the first is that Storm is *symmetric*, so it sets the pace rather
  than the winner — and the 5M sweep's measured problem is that **slow decks lose**, with
  tower scaling already A/B tested as the cause and exonerated.
  **Tempest's damage discount is 30%, and it was derived rather than picked.** The live
  pool measures 7.0–8.1 damage per energy (mean 7.69), and an attack grows Charge twice
  (the attack plus its Storm instance), so amortised the keyword is worth **+2N damage
  every swing forever** — +20 at Stage 2, ~2.6 energy of value, the largest keyword
  benefit in the game. Compare `Judgment` −1/3 and `Sanctuary` −18%. Non-Charge Tempest
  bodies keep the standard rate, which the generator enforces per line rather than per
  card.
  **No cards are written.** `tools/add_tempest_faction.py` holds 20 of them (16 units in
  6 chains, 3 supports, an energy card) and **refuses `--apply` while any of its 11 ops is
  unimplemented** — an unknown op parses fine and silently does nothing, which is the exact
  shape of the dropped-`effects` bug already in this log twice, so the generator makes the
  unplayable state unreachable rather than merely discouraged. Its guards were verified by
  putting six separate bugs back and confirming each is refused.

- **Tempest is built: `Charge` banks a per-unit counter, `Storm` is a shared global damage
  ramp.** The sixth colour, and the first whose resources **persist and grow across turns** —
  everything else in the game is instant (`Stoke`), live (`Earth`), binary (`Judgment`) or
  decaying (the pool). Against Gaia the split is wide versus deep: Gaia's aura rewards many
  living bodies and shrinks the instant one dies, while Tempest's counter sits on one body
  and is lost whole with it.
  **`Storm` is one instance of N, never N instances of 1, and that decision is the whole
  keyword.** `Resist X` reduces each incoming *instance* to a minimum of 1 damage, so N
  separate ticks would have made Storm a **Resist-piercing** mechanic — armour would stop
  working entirely as Storm climbed, a wider anti-shield break than Forge's
  `stoked_unpreventable` and printed on a global number that both players feed. As a single
  instance, Resist blunts it exactly as printed.
  **Charge is the third thing to survive evolution**, after attached energy and the Tool, for
  the identical reason: without it, evolving destroys the investment, so the correct play for
  the one faction whose resource is *time* would be never to evolve. The value carries and
  the rate comes from the new card — **evolving is Tempest's rate increase**.
  **Four bugs, and three of them were only findable by playing rather than by testing.**
  *(1)* `charge_on_kill` read `defender.hp <= 0` **above** the Judgment block, so a defensive
  Judgment save paid the executioner for a body still standing; the check moved below both
  halves. *(2)* Both Tempest supports were **silent dead data** — units and supports do not
  share an effect dispatcher, so `storm_raise` wired only into the unit path did nothing on a
  support, and Storm never rose above 0 in two of five AI games. Same shape as the
  dropped-`effects` bug already in this log twice. *(3)* The AI needed `_discharge_worth_it()`
  for the reason Forge's Stoke needed `_stoke_worth_it()`: **a cost the engine does not charge
  in pool energy is invisible to a heuristic that measures pool energy**, so the "free
  abilities are always taken" default cashed a counter of 3 on turn one. *(4)* A harness that
  forgot `skip_setup()` got `false` back from every ability and read as ten broken ops.
  **The damage discount is 30% and was derived, not chosen.** The live pool measures 7.0–8.1
  damage per energy; an attack grows Charge twice (itself plus its Storm instance), so
  amortised the keyword is worth **+2N damage every swing forever** — +20 at Stage 2, the
  largest keyword benefit in the game against `Judgment`'s −1/3 and `Sanctuary`'s −18%.
  **Retribution now fires once per attack rather than once per damage instance.** Forced by
  Storm's extra instance, which would otherwise double every wall's recoil and make
  `Thicket` and `Standing Heat` unattackable as Storm climbed. Inert at Storm 0, so no
  existing matchup changed.
  **Three deliberate bets are recorded in `tempest.md` rather than designed away**: Storm is
  permanent/uncapped/symmetric, Charge is uncapped with the tower clock as its only brake,
  and every instance grows Charge. The case for the first is that Storm is *symmetric*, so it
  sets the pace rather than the winner, and the 5M sweep's measured problem is that **slow
  decks lose** — with tower scaling already A/B tested as the cause and exonerated.
  **Not every Tempest body carries Charge**, and the generator enforces both halves: Foehn
  prints none (a faction where every card has the keyword is the sameness failure the
  bestiary waves documented), while a body that *does* print Charge must have something that
  grows it and something that spends it, or the counter is dead data.

- **A 5-round, 5,000,000-game balance sweep (2026-08-17) produced three rule changes, and
  the method matters as much as the changes.** Each round played 1M games — every one of
  the 625 ordered deck pairings exactly 1,600 times, so the matchup matrix carries no
  sampling noise — then one change was made and the next million re-run, which is what
  makes each change's effect *attributable* rather than confounded with the others.
  The three changes, each aimed at a measured cause rather than at a win rate:
  **(1) The Earth aura's damage half was halved.** One point of Earth paid +1 into every
  unit's max HP, both towers' HP *and* every attack, so it bought six-plus stat points for
  one. A live probe measured `Deep Grove` at a mean aura of **14.6, peaking at 78**. HP
  stays at full rate; damage is now +1 per two points. Gaia 73.8% → 66.2%.
  **(2) `Sanctuary N`'s unbounded terminal overflow was removed.** A pool that could not
  cover a hit used to absorb the *whole* instance at any size, making every shielded body
  worth `N + an extra life`; `Sealed Light` runs thirty of them and sat at 89–91% while its
  games ran **four rounds longer** than average — winning by being unkillable rather than
  by out-playing anything. The pool now drains exactly and the remainder lands. Plain
  Sanctuary keeps the full absorb, since it has no pool to drain.
  **(3) The support healing ladder was re-anchored ×1.6.** It had been set against ~50 HP
  bodies and was never re-derived when the 2026-08-08 curve raise took bodies to 40–175 —
  the damage anchors were deliberately held, and nothing revisited the *support* band. Draw
  and search were left alone; only HP-denominated numbers were rescaled.
  **Two things were tested and deliberately NOT changed.** Tower scaling was the obvious
  suspect for the ~9.5-round clock and was A/B tested at `+2` instead of `+3`: games got
  longer and the bottom decks did not move, so it was reverted rather than shipped on a
  plausible story. And Judgment was left alone despite `Verdict Engine` sitting at 46%,
  because `AIPlayer` has no Judgment heuristic — the keyword's entire decision (cash the
  charge or hold it) is not being played, so its win rate is not evidence about the keyword.
  **The general shape: a keyword that pays into several systems at once has to be priced
  against the SUM, not against each payment.** Earth read as +1/+1 and was really +1 to six
  things; Sanctuary read as "a pool of N" and was really "N plus one free hit of any size."
  Both looked correctly costed line by line and neither was, and only aggregate play
  surfaced it — the assertion suites were green throughout, because every one of these was
  the rules working exactly as written.
