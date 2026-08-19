# Balance Questions — from the 5-round, 5,000,000-game sweep

2026-08-17. Nothing here was asked mid-run. These are the calls that need your
judgment rather than a number I can defend from the data. Anything I could
answer from the data, I fixed — see `docs/balance/report.md`.

---

## Q1 — Is the AI's play good enough for these numbers to mean what they look like?

**This is the question the other five depend on.** The AI holds a mean pool of
**0.92** and dumps everything onto bodies every turn. So:

- **Decay almost never fires**, which means "spend or save" — design principle
  #2, which the docs call the game's central skill expression — is *not being
  tested at all* by any of the 5M games.
- `void.md` already flags this for Rift specifically ("the AI was playing a
  maximal Rift strategy by accident"). It is broader than Void.
- There are no `Judgment` or `Sanctuary` heuristics, so the two Heaven decks are
  played badly by construction.

Everything below is conditional on this. **Do you want a round of AI work before
any more balance work?** I think the answer is yes, and that further card tuning
against this AI has hit diminishing returns — see Q3.

## Q2 — P1 wins 58.5–59.4%. Rules problem or AI problem?

Now measured properly: every ordered pairing in both seats, 1,600 games each,
stable across all five rounds and unmoved by three separate rule changes. It is
real and it is not noise. It survives the setup phase and round-1 tower silence,
which were adopted partly to remove it.

But both seats run *identical* heuristics, so P1 acting first compounds
mechanically. **Do you want this fixed in the rules** (P2 compensation — an extra
card, starting pool, or a first-turn tower delay) **or diagnosed in the AI first?**
The cheap discriminator is an asymmetric run; I did not do it because it changes
what the sweep was measuring.

## Q3 — Should every deck be near 50%, or every *faction's best* deck?

The spread is 83% → 22% and card-level fixes are not closing it (stdev 19.6 →
17.7 across five rounds, with three targeted changes that each hit their mark).

Forge ships **seven** decks and Gaia four, so Forge's mean is diluted by having
more experimental lists — its best deck is 52%, which is fine. If the target is
"every faction has a viable deck," the game is much closer to balanced than the
table suggests. If it is "every shipped deck is viable," then `Cacophony Ramp`
(22%), `Burning Line` (26%) and `Scrap Line` (27%) need rebuilding as *decks*,
not rebalancing as cards — I did not touch deck lists, since that is design.

## Q4 — Supports correlate negatively with winning (−0.19). Band problem or slot problem?

Every deck in the bottom third runs 15–22 supports; every deck in the top third
runs 7–10. I re-anchored the healing ladder ×1.6 and it bought the support-heavy
Forge decks 4–7 points without reordering the table.

The structural reading is that **a support is a card that is not a body**, and
under shielding, bodies are what keep a tower alive — so a support must beat a
whole unit's board presence to earn its slot. That is not something the power
band can fix by itself. Options, in increasing order of disruption: keep buffing
supports, or reconsider whether shielding should make bodies quite this dominant.

## Q5 — Tower fire is 45% of all damage. Intended?

576 per game against 439 of card damage to units. I **A/B tested** dropping tower
scaling from `+3` to `+2` a round: games lengthened (9.5 → 9.9) and the bottom
decks did not move, so I reverted it — it is not what is compressing the meta.
But it does mean nearly half the damage in the game belongs to no card and is
identical for both players. Worth deciding whether that is the intended texture.

## Q6 — Judgment is untuned and I left it that way deliberately

`Verdict Engine` 46%, `Lamp Wall` 32%, `Reaffirmation` 64%. I made **no Judgment
changes** in five rounds, because the AI has no heuristic for it — the keyword's
whole decision is *cash the charge or hold it*, and the bot does neither
deliberately. Any number I moved here would be tuning against a bug in the
player, not the card. This needs Q1 resolved or a human playtest.

## Q7 — Deck-out is dead as a loss condition

All 5,000,000 games ended by throne kill. Zero stalls (the longest game in 5M was
37 rounds, against a 300-round guard), zero decking, at 60 cards and ~9.5 rounds.
Probably intended, but it does mean mill can never be a strategy and the
long-running stall worry in Open Questions is, on current numbers, closed.
