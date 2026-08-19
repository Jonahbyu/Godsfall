# Spec — The Bestiary

Turning Godsfall's units into creatures, and doubling the roster from 56 to 114.

Decided in conversation 2026-08-15. **Nothing here is built yet.** This is the
design to review before card data or art is generated.

---

## What this changes, and what it deliberately does not

| | |
|---|---|
| **Changes** | Every unit's `name` and `flavor`. 58 new unit cards. 58 new art functions. |
| **Does not change** | Card `id`s, mechanics, keywords, HP, damage, costs, the rules engine, any harness, any sample deck, any tutorial lesson. |

**Card ids stay exactly as they are.** They are referenced 130+ times across 15
files — `TutorialData.gd` alone names 40 — and they are internal. `grave_whelp`
can display as *Ossilit* without a single line of GDScript changing. Renaming
ids would mean touching the tutorial, all ten sample decks, and `GaiaTest`'s 146
assertions to buy nothing the player can see.

The one place ids leak is `assets/art/<card_id>.png` and `make_card_art.py`'s
`@art("id")` keys. Those follow the id, so they are unaffected too.

---

## The naming system

A chain must be readable as **one creature at three ages, from the names alone**.
That is the Pokémon property — Charmander/Charmeleon/Charizard share a stem, and
you can tell they are one animal without seeing the art.

Three rules produce it:

1. **A chain shares a stem.** The stem is the species. It never changes.
2. **The suffix escalates with age** — small, then working, then terminal.
3. **Suffix pools are per-faction, not global.** This is the rule that does the
   most work and the one it is most tempting to skip.

### Why the suffix pools are per-faction

The first draft of this spec used one shared suffix table for the whole game, so
`-colossus` was the Stage 2 suffix for both Hel and Gaia. That is a mistake, for
two separate reasons:

- **It makes every faction sound the same.** If `-lit` is *the* Basic suffix,
  then Hel's Basic, Void's Basic and Gaia's Basic all end in `-lit`, and the
  naming system's output is 114 cards that rhyme with each other. Systematic and
  forgettable are the same failure.
- **It destroys the faction read.** The target property is that hearing a name
  narrows it to one of two factions. A shared suffix carries zero faction
  information, so the whole burden falls on the stem — half the name doing
  nothing.

So each faction gets its **own** suffix pool, drawn from its element. The suffix
should be as diagnostic as the stem.

**`-colossus` is retired.** It is a complete English word, so it reads as a
title bolted onto a stem rather than as one creature's name, and it appeared
twice. Terminal forms use short, invented-feeling endings instead.

### Hel — bone, rot, grave-cold

Hard consonants, clipped, things that gnaw and settle. Norse-adjacent.

| Stage | Suffixes |
|---|---|
| Basic | `-lit`, `-wisp`, `-ling`, `-grub` |
| Stage 1 | `-gaunt`, `-maw`, `-mire`, `-shroud` |
| Stage 2 | `-rend`, `-thane`, `-barrow`, `-drung` |

Stems: `Oss-`, `Gnaw-`, `Mor-`, `Sepul-`, `Cairn-`, `Rime-`, `Grist-`, `Hollow-`

### Heaven — light, gold, judgment

Open vowels, ringing, Latinate. The only faction whose names are *pleasant* to
say, which is itself the tell.

| Stage | Suffixes |
|---|---|
| Basic | `-im`, `-iel`, `-kin`, `-mote` |
| Stage 1 | `-sear`, `-mant`, `-vigil`, `-choir` |
| Stage 2 | `-arch`, `-seraph`, `-aureole`, `-tribune` |

Stems: `Lume-`, `Sera-`, `Bell-`, `Aur-`, `Clar-`, `Vesper-`, `Solem-`, `Halo-`

### Void — absence, entropy, slate

Hollow and sibilant. Lots of `s`, `sh`, `u`. Names that trail off rather than
land — the faction drawn as absence should *sound* like absence.

| Stage | Suffixes |
|---|---|
| Basic | `-ith`, `-hush`, `-sk`, `-wane` |
| Stage 1 | `-sever`, `-gaunt`, `-fray`, `-ebb` |
| Stage 2 | `-reave`, `-nought`, `-sunder`, `-null` |

Stems: `Null-`, `Hush-`, `Sev-`, `Wane-`, `Umbr-`, `Fane-`, `Scour-`, `Vast-`

### Gaia — moss, stone, root, growth

Soft, rounded, botanical-Latin. Two syllables that sit on the ground.

| Stage | Suffixes |
|---|---|
| Basic | `-ling`, `-sprout`, `-bud`, `-spore` |
| Stage 1 | `-warden`, `-mant`, `-bough`, `-crag` |
| Stage 2 | `-thane`, `-heart`, `-monolith`, `-elder` |

Stems: `Bryo-`, `Thorn-`, `Petri-`, `Verd-`, `Lich-`, `Mycel-`, `Gran-`, `Root-`

### The expanded pools (wave 2, +30 per faction)

The first wave used ~5 stems and 12 suffixes per faction. Thirty more units per
colour exhausts that — `Ossmire` and `Rimemire` would collide, and a stem reused
five times stops identifying a species. So each faction gains a second bank of
stems, drawn from the same element but a different *register*, and a few more
suffixes.

The registers matter as much as the sounds. Hel's first bank is bone and burial
(`Oss-`, `Cairn-`, `Sepul-`); its second is rot and cold (`Blight-`, `Murk-`,
`Frost-`). A player should be able to feel that two Hel creatures are the same
colour without their names being interchangeable.

| Faction | Wave-2 stems | Added suffixes |
|---|---|---|
| **Hel** | `Blight-`, `Murk-`, `Char-`, `Grim-`, `Rot-`, `Tomb-`, `Ash-`, `Wither-` | `-fen`, `-husk`, `-loam`, `-knell` |
| **Heaven** | `Orat-`, `Psalm-`, `Cant-`, `Gloria-`, `Matin-`, `Lucen-`, `Sanct-`, `Empyr-` | `-ora`, `-lumen`, `-cant`, `-throne` |
| **Void** | `Ebon-`, `Lacun-`, `Cess-`, `Dross-`, `Rive-`, `Gyre-`, `Pall-`, `Stark-` | `-lack`, `-rift`, `-shear`, `-abyss` |
| **Gaia** | `Fern-`, `Cald-`, `Silt-`, `Sedge-`, `Amber-`, `Burr-`, `Loam-`, `Tuss-` | `-fen`, `-shoot`, `-bole`, `-wold` |

`-fen` intentionally appears in both Hel and Gaia: a fen is a wetland, which is
Gaia's domain, and a rotting one, which is Hel's. The stems keep them apart
(`Rotfen` vs `Sedgefen`) and the shared suffix is doing honest work rather than
being a collision.

### The overlaps are deliberate and few

`-gaunt` appears in both Hel and Void; `-thane` in both Hel and Gaia; `-mant` in
both Heaven and Gaia. Each overlapping pair is between factions whose *stems*
sound nothing alike, so `Ossigaunt` and `Sevgaunt` are never confusable. Total
separation would mean inventing twelve distinct suffix families, which starts
generating nonsense syllables — the overlap is cheaper than the alternative and
the stem carries the load.

### The named exception

**Legendary units keep their proper nouns.** `Hel, Queen of the Unclaimed` and
`Nithogg, Root-Gnawer` are characters with fiction attached — Nithogg is the
Norse serpent that gnaws the world-root, which is load-bearing flavor rather
than a placeholder name. Forcing those into a phonetic family costs more than it
buys.

This is a sanctioned exception in the same sense design principle #1 means it:
the rule is the baseline, and the cards that break it are the memorable ones.
Kept rare — a faction may hold **two or three** named units at most, always at
the top of a chain, and never a Basic.

### The named exception

**Legendary units keep their proper nouns.** `Hel, Queen of the Unclaimed` and
`Nithogg, Root-Gnawer` are characters with fiction attached — Nithogg is the
Norse serpent that gnaws the world-root, which is load-bearing flavor rather
than a placeholder name. Forcing those into a phonetic family costs more than it
buys.

This is a sanctioned exception in the same sense design principle #1 means it:
the rule is the baseline, and the cards that break it are the memorable ones. It
stays rare — **at most one named unit per faction**, always the Stage 2 at the
top of its chain.

---

## The rename table

Existing chains only. Mechanics, HP and ids are untouched — this is the `name`
field and nothing else.

### Hel — bone and rot

| id | Was | Becomes |
|---|---|---|
| `grave_whelp` | Grave Whelp | **Osslit** |
| `gravebound_reaper` | Gravebound Reaper | **Ossgaunt** |
| `hel_queen` | Hel, Queen of the Unclaimed | *(unchanged — named)* |
| `carrion_crawler` | Carrion Crawler | **Gnawgrub** |
| `nithogg_root_gnawer` | Nithogg, Root-Gnawer | *(unchanged — named)* |
| `nithogg_ascendant` | Nithogg Ascendant | *(unchanged — named)* |
| `bonepicker` | Bonepicker | **Morwisp** |
| `hels_chorus` | Hel's Chorus | **Mormire** |
| `grand_cacophony` | Grand Cacophony | **Mordrung** |
| `thornshade` | Thornshade | **Sepulling** |
| `mourning_bell` | Mourning Bell | **Sepulshroud** |
| `hollow_servant` | Hollow Servant | **Cairnlit** |
| `grave_tide` | Grave Tide | **Cairnmaw** |
| `barrow_knight` | Barrow Knight | **Rimethane** |
| `charnel_colossus` | Charnel Colossus | **Gristbarrow** |

Grave Whelp → Gravebound Reaper already shared a stem and is the model the rest
follow. Bonepicker → Hel's Chorus → Grand Cacophony was three unrelated nouns
and is the clearest case of the naming rule doing real work.

`Charnel Colossus` becomes **Gristbarrow** rather than anything in `-colossus`.
It is a standalone 90 HP Basic — the largest in the game — so it gets a terminal
suffix despite its stage, which reads correctly: it is a big thing that never
grew up.

### Heaven — light and judgment

| id | Was | Becomes |
|---|---|---|
| `lantern_acolyte` | Lantern Acolyte | **Lumemote** |
| `hand_of_the_verdict` | Hand of the Verdict | **Lumesear** |
| `throne_of_the_risen_court` | Throne of the Risen Court | **Lumearch** |
| `censer_bearer` | Censer Bearer | **Seraim** |
| `arbiter_of_the_third_seal` | Arbiter of the Third Seal | **Seravigil** |
| `seraph_of_the_final_ledger` | Seraph of the Final Ledger | **Seratribune** |
| `verdict_of_the_throne` | Verdict of the Throne | **Seraureole** |
| `warden_of_the_lamp` | Warden of the Lamp | **Aurkin** |
| `radiant_bastion` | Radiant Bastion | **Aurmant** |
| `empyrean_sentinel` | Empyrean Sentinel | **Aurseraph** |
| `bellringer_of_the_court` | Bellringer of the Court | **Belliel** |
| `court_of_bells` | Court of Bells | **Bellchoir** |
| `cherub_of_the_open_gate` | Cherub of the Open Gate | **Clarim** |

`seraph_of_the_final_ledger` and `verdict_of_the_throne` are a **branch** — both
evolve from `arbiter_of_the_third_seal`. They share the `Sera-` stem and split at
the suffix, which is exactly what a branching line should look like.

`Bellchoir` is the one name here that is two real words, and it is kept because
the card *is* a court of bells and the pun is the card's identity. Watch it — if
it reads as inconsistent next to `Seravigil`, it becomes `Bellmant`.

### Void — absence and entropy

| id | Was | Becomes |
|---|---|---|
| `hollow_acolyte` | Hollow Acolyte | **Nullith** |
| `severance_priest` | Severance Priest | **Nullfray** |
| `the_absence` | The Absence | **Nullnought** |
| `rust_crawler` | Rust Crawler | **Wanesk** |
| `famine_of_forms` | Famine of Forms | **Waneebb** |
| `silence_eternal` | Silence Eternal | **Wanesunder** |
| `ashen_pilgrim` | Ashen Pilgrim | **Umbrith** |
| `gnawing_absence` | Gnawing Absence | **Hushith** |
| `the_unwritten` | The Unwritten | **Hushfray** |
| `unmaker_of_thrones` | Unmaker of Thrones | **Hushreave** |
| `null_adept` | Null Adept | **Sevwane** |
| `entropy_warden` | Entropy Warden | **Sevgaunt** |
| `throat_of_the_void` | Throat of the Void | **Sevnull** |
| `sundered_wretch` | Sundered Wretch | **Scoursk** |
| `hungering_maw` | Hungering Maw | **Scourebb** |

Void is the faction where the sound does the most work — `Nullith`, `Hushith`
and `Umbrith` all trail off into nothing, which is the faction drawn as absence
rendered as phonetics.

### Gaia — moss and stone

| id | Was | Becomes |
|---|---|---|
| `gaia_makeshift_tower` | Makeshift Tower | **Petrisprout** |
| `gaia_bulwark_of_stone` | Bulwark of Stone | **Petricrag** |
| `gaia_the_standing_stone` | The Standing Stone | **Petrimonolith** |
| `gaia_living_conduit` | Living Conduit | **Verdling** |
| `gaia_deep_roots` | Deep Roots | **Verdbough** |
| `gaia_heartwood_ancient` | Heartwood Ancient | **Verdheart** |
| `gaia_sapling_warden` | Sapling Warden | **Bryobud** |
| `gaia_grovekeeper` | Grovekeeper | **Bryowarden** |
| `gaia_elder_of_the_grove` | Elder of the Grove | **Bryoelder** |
| `gaia_mossback_tortoise` | Mossback Tortoise | **Lichling** |
| `gaia_granite_colossus` | Granite Colossus | **Lichcrag** |
| `gaia_seedbearer` | Seedbearer | **Thornspore** |
| `gaia_vernal_rite` | Vernal Rite | **Thornmant** |

Gaia needed this most. `Makeshift Tower → Bulwark of Stone → The Standing Stone`
was a structure evolving into a bigger structure, and `Seedbearer → Vernal Rite`
was a seed becoming a *ceremony*. Both now read as one creature growing up, with
no mechanical change at all — Petrisprout still auto-fires, Thornmant still
carries Essence.

`Petrisprout` is deliberately incongruous: a stone thing with a botanical Basic
suffix, because the card is a *makeshift* tower — something improvised and alive
rather than built. It grows into `-crag` and then `-monolith` as it hardens,
which is the chain's whole arc in three suffixes.

**`Makeshift Tower`'s rule-breaker status is unaffected.** It is still the unit
that attacks free at end of turn, and `CLAUDE.md`'s reasoning for why that is
allowed — it is a *unit*, so it can be named and killed the turn it lands, unlike
a real tower — is if anything clearer now that it is visibly a creature.

---

## The 58 new creatures

Per the decision to **spread wide rather than deepen**: mostly standalone Basics
and two-card lines, with metamorphosis enforced strictly wherever a chain exists.
Roughly 14–15 per faction.

### Distribution

| | Basics | Stage 1 | Stage 2 | Total |
|---|---|---|---|---|
| **Hel** | 8 | 5 | 2 | 15 |
| **Heaven** | 8 | 4 | 2 | 14 |
| **Void** | 8 | 5 | 2 | 15 |
| **Gaia** | 8 | 4 | 2 | 14 |
| | **32** | **18** | **8** | **58** |

Weighted to Basics because spreading wide means more species to choose between,
and because the Basic band is where the roster is thinnest relative to how often
those cards are actually played.

### Pricing

Every new attack is priced by the existing tool, not by eye:

```
cost = round(damage / RATE[stage])   clamped to the band
RATE  = Basic 7, Stage 1 8, Stage 2 9
BANDS = Basic 1-6, Stage 1 4-10, Stage 2 8-20
```

Two constraints from `CLAUDE.md` that the new cards must respect:

- **No new round-1 openers.** There are exactly six attacks at cost 1–2 in the
  game and that scarcity is deliberate — cheap attacks fire ~3× as often as
  expensive ones, so printed parity produces a played-mix landslide. New Basic
  attacks price at 4–6.
- **Judgment units buy damage at ≈8/energy, not 12.** Any new Heaven creature
  carrying Judgment takes the reduced rate.

### Keyword budget

New creatures draw from the existing keyword pool only. **No new keywords** —
the roster is doubling, which is already a lot of new text for a player to
absorb, and `Windfury` is still documented-but-unimplemented from the last pass.

---

## Art

58 new `@art("id")` functions in `tools/make_card_art.py`, following the
established pattern: coordinates in 0–1 space, drawn at 4× and downscaled, built
from the shared primitives (`serpent`, `skull`, `wings`, `void_eye`, `halo`).

**The creature turn helps the art more than it costs it.** The existing emblems
are symbolic because the art box is 74px and an illustration would be mud — but
a *creature silhouette* is exactly the kind of shape that survives at 74px,
which is the constraint `CLAUDE.md` already identified as binding. A recognizable
animal outline reads better small than an abstract noun ever did.

Faction grammar is unchanged and now easier to hold: Hel is bone on the horizon,
Heaven floats and is radially symmetric, Void punches a hole with a bright rim,
Gaia sits on the ground line and grows upward.

**A chain's three creatures must share a silhouette.** Same reasoning as the
names: the Stage 2 is the Basic grown up, so it keeps the head shape and the
posture and gains mass, horns, or a second pair of limbs.

---

## Open questions

- **Does the faction read actually work?** The target is that hearing a name
  narrows it to one of two factions. Per-faction suffix pools should deliver it,
  but the test is a blind one: read *Waneebb*, *Sepulshroud*, *Bellchoir* and
  *Lichcrag* to someone who knows the four elements and see whether they can
  place them. If the stems carry it but the suffixes do not, the pools need to
  diverge further.
- **`-ith` may be overused in Void.** `Nullith`, `Hushith` and `Umbrith` are
  three of fifteen, and the trailing-off quality that makes them right for the
  faction also makes them the hardest to tell apart. Watch it as the new Void
  creatures are written; if it gets crowded, `-sk` and `-wane` absorb the excess.
- **Two-real-word names are the inconsistency to watch.** `Bellchoir`,
  `Verdheart`, `Petrimonolith` and `Gristbarrow` are compounds of real words,
  while `Seravigil` and `Nullfray` are not. The compounds are kept where the
  card's identity is the pun, but four of them across 56 cards may be enough to
  make the invented ones look like a different system.
- **Does doubling the roster dilute the sample decks?** Ten decks were built
  against 56 units. Doubling means each deck now draws from twice the pool, and
  the identities they were built around may no longer be the obvious build.
  Not addressed here; wants a pass over `DeckStore.sample_decks()` afterward.
- **Should a chain's stem ever mutate?** Pokémon lets it — *Charmander* to
  *Charizard* keeps `Char-` but drops the rest entirely. Here the stem is fixed
  across all three stages, which is more legible and less characterful. A
  mutating stem on the Stage 2 only (`Sepulling → Sepulshroud → Sepulcrine`)
  would buy some of that back at the cost of the rule being simple to state.
