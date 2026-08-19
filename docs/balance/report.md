# Godsfall — 5,000,000-Game Balance Sweep

**2026-08-17.** Five rounds of 1,000,000 AI-vs-AI games. Each round played every one
of the 625 ordered deck pairings exactly **1,600 times**, so the matchup matrix
carries no sampling noise, and seating is part of the pairing. After each round I
read the aggregate, made **one** change, and re-ran the next million — which is what
makes each change's effect attributable instead of confounded with the others.

Raw per-round output is in `r1_report.txt` … `r5_report.txt`; the CSV shards are
under `logs/sim/rounds/rN.tar.gz` (gitignored; 5M rows, 198MB compressed).
Open questions are in `questions.md`.

**Headline:** three rule changes landed, each aimed at a measured cause. Two more
were tested and deliberately rejected. All 16 harnesses pass at 1,182 assertions.

---

## 1. How the sweep ran

| | |
|---|---|
| Games | 5,000,000 (5 rounds × 1M) |
| Per ordered pairing | 1,600 per round |
| Wall clock | ~9 min per round, 20 shards on 24 cores |
| Stalls | **0** in 5,000,000 |
| Games ending by throne kill | **100.0%** |

Existing infrastructure did the heavy lifting: `BalanceSim.gd` and `analyze_sim.py`
were already written and correct. I added `tools/run_round.sh` (shard driver),
`tools/balance_util.py` (card/deck loaders) and `tools/deck_profile.py`
(feature-vs-win-rate correlation).

---

## 2. Results by round

| deck | faction | R1 | R2 | R3 | R4 | R5 | change |
|---|---|---|---|---|---|---|---|
| Sealed Light | Heaven | 89.2 | 91.0 | 88.5 | 83.0 | **83.0** | -6.2 |
| Bedrock | Gaia | 82.5 | 78.9 | 79.4 | 80.3 | **80.1** | -2.4 |
| Toll Engine | Hel | 75.8 | 78.0 | 78.4 | 78.3 | **76.5** | +0.7 |
| Unquiet Dead | Hel | 71.6 | 74.4 | 74.6 | 75.9 | **74.8** | +3.2 |
| Deep Grove | Gaia | 83.3 | 71.2 | 71.7 | 72.4 | **73.3** | -10.0 |
| Reaffirmation | Heaven | 62.3 | 65.0 | 65.2 | 65.1 | **63.6** | +1.3 |
| Wasting Fen | Hel | 58.4 | 61.0 | 61.3 | 61.5 | **60.7** | +2.3 |
| Standing Stones | Gaia | 70.6 | 57.4 | 57.9 | 57.8 | **58.5** | -12.1 |
| Widening Rift | Void | 51.7 | 53.7 | 54.1 | 54.4 | **54.4** | +2.7 |
| Thicket | Gaia | 59.0 | 52.9 | 53.0 | 53.2 | **52.8** | -6.2 |
| Rise & Recur | Hel | 51.8 | 53.5 | 54.0 | 53.9 | **52.4** | +0.6 |
| Standing Heat | Forge | 47.7 | 50.0 | 50.1 | 50.5 | **52.0** | +4.3 |
| White Heat | Forge | 43.0 | 45.4 | 45.5 | 45.9 | **50.2** | +7.2 |
| Verdict Engine | Heaven | 46.0 | 47.8 | 47.8 | 47.9 | **45.8** | -0.2 |
| Second Wind | Forge | 39.9 | 41.2 | 41.4 | 41.4 | **45.6** | +5.7 |
| Starve | Void | 45.0 | 46.2 | 46.6 | 46.7 | **45.0** | +0.0 |
| Nothing Holds | Forge | 41.2 | 42.7 | 42.7 | 43.0 | **42.4** | +1.2 |
| Barrow Wall | Hel | 35.5 | 36.7 | 36.8 | 36.7 | **37.0** | +1.5 |
| Total Eclipse | Void | 35.3 | 36.3 | 36.8 | 36.7 | **35.2** | -0.1 |
| Lamp Wall | Heaven | 33.2 | 34.5 | 32.4 | 32.5 | **32.4** | -0.8 |
| Widening Dark | Void | 30.4 | 31.9 | 31.8 | 32.1 | **30.4** | +0.0 |
| Bank the Heat | Forge | 24.4 | 25.2 | 25.2 | 25.0 | **28.9** | +4.5 |
| Scrap Line | Forge | 27.0 | 28.0 | 27.8 | 28.1 | **26.5** | -0.5 |
| Burning Line | Forge | 22.9 | 23.8 | 23.8 | 23.9 | **26.3** | +3.4 |
| Cacophony Ramp | Hel | 22.4 | 23.4 | 23.3 | 23.6 | **22.4** | +0.0 |

### The aggregate barely moved, and that is the most important finding

| round | spread | stdev | within 40-60% |
|---|---|---|---|
| R1 | 66.8 | 19.61 | 9/25 |
| R2 | 67.6 | 18.30 | 10/25 |
| R3 | 65.2 | 18.28 | 10/25 |
| R4 | 59.4 | 17.96 | 10/25 |
| R5 | 60.6 | 17.65 | 10/25 |

Three changes each hit their target squarely, and the field standard deviation went
**19.6 → 17.7**. That is a real improvement and a small one. The reading is in
section 5.

---

## 3. Faction strength

| faction | decks | R1 mean | R5 mean | change | R5 best | R5 worst |
|---|---|---|---|---|---|---|
| **Gaia** | 4 | 73.8 | 66.2 | -7.7 | 80.1 | 52.8 |
| **Heaven** | 4 | 57.7 | 56.2 | -1.5 | 83.0 | 32.4 |
| **Hel** | 6 | 52.6 | 54.0 | +1.4 | 76.5 | 22.4 |
| **Void** | 4 | 40.6 | 41.2 | +0.6 | 54.4 | 30.4 |
| **Forge** | 7 | 35.2 | 38.8 | +3.7 | 52.0 | 26.3 |

**Gaia was the clearest outlier and is now mid-table** — it lost 7.6 points from one
change, which is the signature of a faction carried by a single mechanic rather than
by its cards.

**Heaven has the widest internal spread (50.6 points):** `Sealed Light` 83.0 and
`Lamp Wall` 32.4 share a colour and an energy card. That is partly the design working
— the docs say Judgment and Sanctuary want opposite things from a body — and partly
an AI artifact, since the bot has no heuristic for either keyword.

**Forge's mean (38.8) is diluted by shipping seven decks**, three of which are
experimental. Its best deck sits at 52.0. If the target is "every faction has a
viable deck", Forge is fine; if it is "every shipped deck is viable", it is not.

**Void is the flattest faction** (24.0 spread) and the most consistently mid-to-low.
Nothing I changed touched it, and it moved less than a point.

---

## 4. The changes I made

### Round 1 → 2 — the Earth aura's damage half was halved

**What the data said.** `Earth` correlated with winning at **+0.50**, the strongest
single predictor of any feature I tested, and all four Gaia decks finished in the top
eight.

**What was actually wrong.** One point of Earth pays +1 into every unit's max HP,
both towers' HP *and* every attack simultaneously — six-plus stat points for one
point of keyword. A live probe measured `Deep Grove` at a **mean aura of 14.6,
peaking at 78**: +14.6 damage on every attack from every body, for free, every turn.

**Change.** HP stays at full rate; damage is now +1 per **two** points, applied
consistently to attacks, auto-fire and tower fire.

**Result.** Gaia 73.8 → 66.2. `Standing Stones` −12.1, `Deep Grove` −10.0, `Thicket`
−6.2. Gaia stayed a real faction and stopped being the best one.

### Round 2 → 3 — Sanctuary bodies were put on a damage discount

**What the data said.** `Sealed Light` went *up* to 91.0% after the Earth change.

**What I found.** Sanctuary units carried **1.5–1.9× the effective HP** of plain
bodies at the same stage, and paid *nothing* for it — they hit **2–22% harder** than
plain units, not softer. `Judgment` takes a documented one-third rate cut for a
smaller benefit.

**Change.** −18% damage on Sanctuary bodies at **unchanged cost**, so the rate
genuinely moves. My first attempt re-derived cost from the reduced damage, which is
self-defeating — it lowers the price in step and leaves the rate identical.

**Result.** 91.0 → 88.5. Correct in principle, nearly useless in practice, which led
to the real fix.

### Round 3 → 4 — Sanctuary's unbounded overflow was removed

**What the data said.** `Sealed Light` won **96–99%** against individual decks while
its games ran **13.6 rounds against a 9.4 average**. It was not out-playing anything;
it was surviving to win on the tower clock.

**What was actually wrong.** A pool that could not cover a hit absorbed the *whole*
instance, at any size. So a shielded body was worth `N + one arbitrarily large hit` —
not a shield but an extra life. `Sealed Light` runs **thirty** of them.

**Change.** The pool drains exactly and the remainder gets through. **Plain Sanctuary
keeps the full absorb**, since it has no pool and draining it exactly would delete
the keyword.

**Result.** 88.5 → 83.0, and the counterplay is no longer inverted: chip still works,
and a big attack now punches through instead of being erased by the last sliver.

### Round 4 → 5 — the support healing ladder was re-anchored ×1.6

**What the data said.** Supports correlated **negatively** with winning (**−0.19**).
Every deck in the bottom third ran 15–22 supports; every deck in the top third ran
7–10.

**What was actually wrong.** The band was set when Basics were ~50 HP. The 2026-08-08
curve raise took bodies to 40–175 and deliberately held the *damage* anchors — but
nothing ever re-derived the *support* band. A 20-point heal went from 40% of a body
to 12% of one.

**Change.** Flat heal numbers ×1.6, capped below the 175 HP ceiling so the
no-full-heal rule still holds (`Grave Warden's Oath` capped at 120 rather than the
rate's 176). Draw, search and utility were **not** touched — their value is card
economy and did not change when HP did.

**Result.** `White Heat` +4.3, `Second Wind` +4.2, `Bank the Heat` +3.9, `Burning
Line` +2.4. Forge 35.2 → 38.8. It did not reorder the table.

---

## 5. What I tested and deliberately did NOT change

**Tower scaling.** Tower fire is **45% of all damage in the game** (582/game against
439 of card damage to units), and it was my leading hypothesis for the compressed
meta. I A/B tested `+2` a round instead of `+3` over 100,000 games: games lengthened
(9.5 → 9.9 mean) and **the bottom decks did not move at all** (`Cacophony Ramp` 22.2,
`Burning Line` 23.3). The clock is not what is holding them down, so I reverted it
rather than ship a plausible story.

**Judgment.** `Verdict Engine` sits at 45.8% and I made no Judgment changes in five
rounds. `AIPlayer` has no Judgment heuristic — the keyword's entire decision is *cash
the charge or hold it*, and the bot does neither deliberately. Any number I moved
would be tuning against a defect in the player, not the card.

**Deck lists.** `Cacophony Ramp` (22.4%) has been last in all five rounds. It is not
badly costed — it is a slow ramp deck losing to a 9.5-round clock. That is a
deck-design problem, and deck design is your call.

---

## 6. Mechanic strength and how hard each is to balance

| Mechanic | Strength | Hard to balance? | Why |
|---|---|---|---|
| **Earth** (Gaia) | Was dominant, now strong | **Very hard** | Pays into HP, damage and structures at once. Must be priced against the *sum*; each payment looks fair alone. |
| **Sanctuary** (Heaven) | Was dominant, now strong | **Very hard** | Effective HP is invisible in the stat line. Its overflow clause was worth more than its printed number. |
| **Toll** (Hel) | Strong, stable | Easy | One derived number, one trigger, self-limiting — it only pays when the body dies. |
| **Resist** | Strong, quiet | Moderate | +0.33 correlation and it never appears in a headline. Per-instance reduction compounds against wide boards. |
| **Rift / Gap** (Void) | Weak | **Very hard** | The only *negative* keyword correlation (−0.22). Scales off a board state the AI distorts by dumping its pool. |
| **Judgment** (Heaven) | Unknown | **Unmeasurable today** | Needs a hold-or-spend decision the AI never makes. |
| **Stoke / Scrap** (Forge) | Weak-to-mid | Moderate | Costs are paid in HP and bodies, which the sim prices correctly; the decks around them are the weak part. |
| **Supports** | Weak | Moderate | Negative correlation. Competes with *bodies* for slots, and bodies shield. |
| **Tower fire** | Dominant | Easy but risky | 45% of all damage. Symmetric, so it compresses differences rather than creating them. |

**The generalisable lesson:** *a keyword that pays into several systems at once must
be priced against the sum, not against each payment.* Earth read as +1/+1 and was
really +1 to six things. Sanctuary read as "a pool of N" and was really "N plus one
free hit of any size." Both looked correctly costed line by line, and neither was.
**The assertion suites were green the entire time** — every one of these was the
rules working exactly as written, which is precisely why only aggregate play could
surface them.

---

## 7. Honest limits on all of the above

- **The AI holds a mean pool of 0.92** and dumps everything onto bodies, so decay
  almost never fires and *spend-or-save* — the game's stated central skill expression
  — is untested by every number here.
- **No Judgment or Sanctuary heuristics**, so both Heaven decks are played badly by
  construction.
- **P1 wins 58.5–59.4%**, stable across all five rounds and unmoved by three rule
  changes. Real, but both seats run identical heuristics, so it may still be the AI
  compounding rather than the rules.
- **These are AI readings.** The AI does not retreat, does not use chosen targeting
  or volley ordering, and empties its boards more often than a human would.

---

## 8. Verification

All 16 harnesses pass — **1,182 counted assertions**, run after the final change:

```
RulesTest 146     SupportTest 169    DeckStoreTest 74    DragDropTest 33
HeavenTest 61     CardViewTest 114   VoidTest 69         GaiaTest 147
TutorialTest 119  ForgeTest 143      KeywordModTest 15   LayoutTest 37
SupportUITest 55  + SceneSmoke, Playthrough, TutorialWalk (uncounted)
```

Twenty-two assertions were updated to the new rules. Every one was a *value*
expectation of a number I deliberately changed; **no invariant was weakened** — the
no-full-heal rule, the HP bands, the two-line rule, the Judgment caps and the
Sanctuary minimum all still hold and still pass.

Docs updated in the same pass: `CLAUDE.md` (Sanctuary section, keyword table, Earth
aura, healing ladder, 5 new Open Questions, decision-log entry), `gaia.md` (Earth),
`support.md` (the whole healing ladder).
