# Godsfall

A turn-based deckbuilding card game built in **Godot 4.7**. Two players, two boards each,
lanes of units, towers, and a throne.

**▶ [Play it in your browser](https://jonahbyu.github.io/Godsfall/)**

---

## The core idea

**Cards are free to play. Energy only buys attacks.**

Deployment is unconstrained — the constraint is *acting*. A board full of units you can't
afford to activate is decoration. Every turn is a triage problem: four units, enough energy
for one or two attacks, pick.

Energy lives in two places, each with its own danger:

| Location | Risk | Safe from |
|---|---|---|
| **Pool** | Decays 20% at end of turn | Unit death |
| **Attached to a unit** | Lost entirely when the unit dies | Decay |

That two-sided risk is the game's central skill expression. Committing energy to a unit
protects it from decay but stakes it on that unit's survival.

## The board

Each player has two boards, each a three-slot lane with a tower occupying one slot until it
dies. Living units shield the structures behind them, per board — clearing a board is what
opens a path to its tower, and killing the tower exposes the throne.

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

Towers are an attrition engine, not a wall — they fire every round and scale, so passivity
loses.

## Factions

Four energy colors, each answering *what does my deck do that no other faction can?*

| Faction | Domain | Verb | Signature keywords |
|---|---|---|---|
| **Hel** | Death, decay, the dead | Recycle | `Toll`, `Decay` |
| **Void** | Absence, entropy, unmaking | Deny | `Siphon`, `Void N` |
| **Gaia** | Life, growth, nature | Fuel | `Earth`, `Essence` |
| **Heaven** | Order, light, judgment | Protect | `Judgment`, `Sanctuary` |

114 cards across the four, plus 43 neutral supports. Ten sample decks ship as the starter
collection.

## Design docs

The `.md` files are the source of truth for the rules; the code implements them.

| File | Contents |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Core rules, economy, formulas, board geometry, turn structure |
| [hel.md](hel.md) · [void.md](void.md) · [gaia.md](gaia.md) · [heaven.md](heaven.md) | Faction keywords, evolution lines, cards, balance notes |
| [support.md](support.md) | Neutral support cards and the support power band |
| [docs/plans/](docs/plans/) · [docs/specs/](docs/specs/) | Implementation plans and design specs |

Each carries a decision log recording *why* a rule is the way it is, not just what it says.

## Running it locally

Open the project folder in Godot 4.7. On Windows, `tools/Godsfall.vbs` launches it silently
and captures errors to `logs/errors.log`.

### Tests

Eleven headless harnesses, 748 assertions:

```
godot --headless --path . --script res://scripts/core/RulesTest.gd
```

Swap in `SupportTest`, `DeckStoreTest`, `HeavenTest`, `VoidTest`, `GaiaTest`,
`CardViewTest`, `DragDropTest`, `SupportUITest`, `SceneSmokeTest`, or `PlaythroughTest`.

### Web build

```
powershell -ExecutionPolicy Bypass -File tools\export-web.ps1
```

Exports to `build/web/` and publishes to the `gh-pages` branch, which is what GitHub Pages
serves. The build is deliberately not committed to `master`.

## Status

First prototype playable — full turn/energy/combat rules, deck builder, and a heuristic AI
opponent. Balance numbers in the docs are mostly AI-vs-AI samples; the AI does not retreat
and has no Judgment or Sanctuary heuristics, so it plays Heaven badly by construction.
Human playtesting is the next step.
