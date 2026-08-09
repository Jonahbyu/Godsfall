# Gaia Card Set — Draft for Review

> **Status: proposal. Nothing here is in `data/cards.json`.** Numbers are for Jonah to
> tune before authoring. The three cards already shipped (`Makeshift Tower`,
> `Living Conduit`, `Deep Roots`) are folded in and may move.

Structure follows Void and Heaven: **15 units in 5 evolution chains**, an energy card,
4 supports and a Tool. Gaia's engine is built and all of this runs on it — no new
engine work is implied by any card below.

---

## The Budget Gaia Is Priced Against

`gaia.md` states the faction sits **below** the 12-damage-per-energy curve because
**the aura is the damage**. Every point of Earth is +1 on every attack from every unit
*and* both towers, so a board at 8 Earth adds 8 to six sources.

Working rate: **≈9 damage per energy on Earth-carrying bodies**, standard 12 on the
few that carry none. Compare Void, which pays ~12 flat, and Heaven's Judgment units
at ~8.

**HP sits at the top of each band** (Basic 40–90, Stage 1 80–120, Stage 2 110–175) —
tanky is the identity.

**The Earth curve:** ~1 on a Basic, 2 on a Stage 1, 3 on a Stage 2. A full board of
four evolved units is 8–12 Earth, a +8/+12 aura at the printed rate.

---

## Chain 1 — Makeshift Tower *(the structure that is a unit)*

| | Card | Stage | HP | Rt | Keywords | Lines |
|---|---|---|---|---|---|---|
| ✅ | **Makeshift Tower** | Basic | 50 | 1 | Earth 1 | *auto-fire 10; +5 max HP/round* |
| | **Bulwark of Stone** | Stage 1 | 100 | 2 | Earth 2, Resist 5 | *auto-fire 14; +5 max HP/round* |
| | **The Standing Stone** | Stage 2 | 150 | 3 | Earth 3, Resist 10 | *auto-fire 20; +5 max HP/round* |

The chain that makes Gaia's tower-buffing literal. Each auto-fires free at end of turn
and grows like a real tower, but is a **unit** — targetable the turn it lands, which is
the whole cost of a free repeating attacker.

`Resist` appears here and nowhere else in the faction. It is the shared keyword doing
flavour work on the cards that are *literally made of rock*, and it pairs with the
auto-fire: these bodies want to survive many small hits, which is exactly what Resist
is good against.

**Balance note:** auto-fire scales with the aura, so The Standing Stone on a 12-Earth
board fires for 32 free every turn. That is the strongest thing in the draft and the
first number to cut if it plays badly.

---

## Chain 2 — Living Conduit *(the energy body)*

| | Card | Stage | HP | Rt | Keywords | Lines |
|---|---|---|---|---|---|---|
| ✅ | **Living Conduit** | Basic | 70 | 1 | Essence 1 | *Earth = attached energy* · Swell 2/18 |
| ✅ | **Deep Roots** | Stage 1 | 110 | 2 | Earth 2, Essence 2 | *Earth grants +2 instead of +1* · Upheaval 3/26 |
| | **Heartwood Ancient** | Stage 2 | 160 | 4 | Earth 3, Essence 3 | *Earth = attached energy* · World-Root 5/45 |

The faction's build-around. `Living Conduit`'s Earth **is** its attached energy, live
and continuous — charging it grows the whole board, and losing it costs the energy and
the aura together. That welds Gaia onto the pool-versus-attached decision.

`Deep Roots` is **the only rate-breaker in the set**, per `gaia.md`'s open question
that the base set should hold exactly one until playtesting says otherwise.

`Heartwood Ancient` re-prints `earth_from_attached` on top of Earth 3, so a charged one
is enormous — the natural Essence carrier and the card most worth paying a funeral for.

---

## Chain 3 — The Grove *(going wide)*

| Card | Stage | HP | Rt | Keywords | Lines |
|---|---|---|---|---|---|
| **Sapling Warden** | Basic | 60 | 1 | Earth 1 | Root Strike 1/9 |
| **Grovekeeper** | Stage 1 | 95 | 2 | Earth 2 | *ability: +1 Earth to this unit, once/turn* · Bramble 2/18 |
| **Elder of the Grove** | Stage 2 | 130 | 3 | Earth 3 | *ability: +1 Earth to this unit, once/turn* · Overgrowth 4/36 |

The Earth **growth** chain — `gaia.md` says growth is card text rather than keyword
text, and this is the plainest version: a free once-per-turn ability that grows the
unit's own Earth permanently.

Grown Earth is lost on death, on Rise, and on evolution (all three enforced and tested),
so this is a slow investment in a body that has to survive to pay off. That is the
faction's thesis in one card.

---

## Chain 4 — Stoneskin *(the wall)*

| Card | Stage | HP | Rt | Keywords | Lines |
|---|---|---|---|---|---|
| **Mossback Tortoise** | Basic | 90 | 2 | Earth 1, Retribution 10 | Shell Slam 2/14 |
| **Granite Colossus** | Stage 1 | 120 | 3 | Earth 2, Retribution 15 | Tremor 3/24 |

A two-card chain, deliberately. `Mossback Tortoise` is a 90 HP Basic — the top of the
band, matching `Charnel Colossus` — that pays for its size with a weak attack.

Retribution rather than Resist, because a wall that punishes attackers protects the
aura by making the opponent's removal expensive. **Retreat is priced up** (2 and 3,
above the `HP ÷ 40` formula's 2 and 3 — actually on-formula here) so these hold the
lane they exist to hold.

---

## Chain 5 — The Bloom *(Essence payoff)*

| Card | Stage | HP | Rt | Keywords | Lines |
|---|---|---|---|---|---|
| **Seedbearer** | Basic | 55 | 1 | Earth 1, Essence 1 | Scatter 1/9 |
| **Vernal Rite** | Stage 1 | 90 | 2 | Earth 2, Essence 2 | *ability: move all Earth from a friendly unit to another* · Flourish 3/25 |

Cheap Essence bodies whose whole job is to die usefully. `Vernal Rite`'s ability is
Essence without the death — consolidating a board's grown Earth onto one survivor
before a wipe, which is the counterplay to Gaia's own fragility.

---

## Supports

| Card | Type | Cost | Effect |
|---|---|---|---|
| **Bedrock** | support | 0 | +2 Earth to a friendly unit, permanently |
| **Deep Communion** | support | 1 | Draw 2, then +1 Earth to a friendly unit |
| **Terraform** | support | 2 | Heal 20 to *all* your units, and +1 Earth to one of them |
| **Cairn** | tower support | 0 | Permanent: this tower gains +15 max HP |
| **Verdant Anchor** | tool | 0 | Attach: this unit has Earth +2 |

`Bedrock` is the free floor every Gaia deck runs. `Deep Communion` at 1 sits inside the
priced-support band (~draw 2 with a rider). `Terraform` at 2 is the board-wide heal —
compare `Closing Ranks`, which is 20-to-all for 2, so the +1 Earth is the premium and
may be too much.

**No priced tower support**, per `CLAUDE.md`. `Cairn` is +15 rather than `Reinforced
Base`'s +20 because Gaia's aura *already* adds tower max HP and stacking both is the
stall risk the docs flag.

---

## Open Questions For You

1. **Is auto-fire scaling with the aura too strong?** The Standing Stone at 12 Earth
   fires 32 free every turn, forever. Options: cap auto-fire's aura share, or drop the
   printed numbers to 8/11/15.
2. **Is Gaia's early game playable?** One Basic is +1/+1 — genuinely nothing — and the
   faction has no ramp while `Essence` taxes the pool. `gaia.md` already flags this;
   the draft does not solve it, and Chain 3's growth is slow by design.
3. **Two-card chains (4 and 5) — right call?** It keeps the set at 15 while giving five
   distinct ideas. The alternative is 3 chains of 3 plus 2 of 2, which is more Stage 2s
   and fewer ideas.
4. **`Vernal Rite`'s move-Earth ability** is the one genuinely new effect op in the
   draft (`move_earth`). Everything else runs on ops the engine already has. Worth it,
   or cut it for something simpler?
5. **Should any Gaia card carry `Rise`?** It is shared, it fits "life," and the engine
   already resets grown Earth on a risen body. Deliberately absent here to keep the set
   focused, but it is the most natural shared keyword for the faction after Resist.
