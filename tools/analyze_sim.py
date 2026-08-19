"""Aggregate BalanceSim CSV shards into the balance tables.

    python tools/analyze_sim.py logs/sim/main/v1_s*.csv

Reads the pipe-delimited rows BalanceSim emits and prints the tables the design
docs need: game length distribution, seat and matchup win rates, the energy
economy, and the damage-vs-HP relationship.

Deliberately stdlib-only -- this runs on whatever Python is on the machine.
"""
import sys
import glob
import statistics as st
from collections import defaultdict

COLS = ("game deck_p1 deck_p2 winner rounds stalled p0_throne p0_throne_max "
        "p1_throne p1_throne_max p0_tower0 p0_tower1 p1_tower0 p1_tower1 "
        "p0_towerfire p1_towerfire p0_dmg_unit p0_dmg_tower p0_dmg_throne "
        "p1_dmg_unit p1_dmg_tower p1_dmg_throne p0_pool_avg p1_pool_avg "
        "p0_att_avg p1_att_avg p0_units_avg p1_units_avg p0_pool_peak "
        "p1_pool_peak p0_idle p1_idle p0_queued p1_queued p0_unaff p1_unaff"
        ).split()

INT = {c for c in COLS if c not in
       ("deck_p1", "deck_p2", "p0_pool_avg", "p1_pool_avg", "p0_att_avg",
        "p1_att_avg", "p0_units_avg", "p1_units_avg")}


def load(patterns):
    rows = []
    for pat in patterns:
        for path in glob.glob(pat):
            with open(path) as f:
                header = f.readline().rstrip("\n").split("|")
                for line in f:
                    parts = line.rstrip("\n").split("|")
                    if len(parts) != len(header):
                        continue
                    r = {}
                    for k, v in zip(header, parts):
                        r[k] = int(v) if k in INT else (
                            float(v) if k not in ("deck_p1", "deck_p2") else v)
                    rows.append(r)
    return rows


def pct(n, d):
    return 100.0 * n / d if d else 0.0


def dist(vals):
    vals = sorted(vals)
    if not vals:
        return "n/a"
    def q(p):
        return vals[min(len(vals) - 1, int(p * len(vals)))]
    return (f"mean {st.mean(vals):6.2f}  med {q(.5):5.1f}  "
            f"p10 {q(.10):5.1f}  p90 {q(.90):5.1f}  "
            f"min {vals[0]:5.1f}  max {vals[-1]:5.1f}")


def main():
    pats = sys.argv[1:] or ["logs/sim/main/v1_s*.csv"]
    rows = load(pats)
    if not rows:
        print("no rows matched", pats)
        return
    done = [r for r in rows if not r["stalled"]]
    n = len(rows)

    print("=" * 78)
    print(f"GAMES: {n}   finished: {len(done)}   "
          f"stalled: {n - len(done)} ({pct(n - len(done), n):.3f}%)")
    print("=" * 78)

    print("\n-- GAME LENGTH (rounds) --")
    print("  " + dist([r["rounds"] for r in done]))
    buckets = defaultdict(int)
    for r in done:
        b = r["rounds"]
        key = ("1-4" if b <= 4 else "5-8" if b <= 8 else "9-12" if b <= 12
               else "13-20" if b <= 20 else "21-40" if b <= 40 else "41+")
        buckets[key] += 1
    for k in ("1-4", "5-8", "9-12", "13-20", "21-40", "41+"):
        if buckets[k]:
            print(f"  {k:>6}: {buckets[k]:6d}  {pct(buckets[k], len(done)):5.1f}%  "
                  + "#" * int(pct(buckets[k], len(done)) / 2))

    print("\n-- SEATING --")
    p1w = sum(1 for r in done if r["winner"] == 0)
    print(f"  P1 wins {p1w:6d} / {len(done)} = {pct(p1w, len(done)):.2f}%")
    print(f"  P2 wins {len(done)-p1w:6d} / {len(done)} = "
          f"{pct(len(done)-p1w, len(done)):.2f}%")

    print("\n-- DECK WIN RATE (seat-controlled: both seats pooled) --")
    wins, games = defaultdict(int), defaultdict(int)
    for r in done:
        games[r["deck_p1"]] += 1
        games[r["deck_p2"]] += 1
        wins[r["deck_p1" if r["winner"] == 0 else "deck_p2"]] += 1
    for d in sorted(games, key=lambda x: -pct(wins[x], games[x])):
        print(f"  {d:<18} {pct(wins[d], games[d]):5.1f}%   ({wins[d]}/{games[d]})")

    print("\n-- DECK WIN RATE BY SEAT --")
    for seat, key, wv in ((("P1"), "deck_p1", 0), ("P2", "deck_p2", 1)):
        w2, g2 = defaultdict(int), defaultdict(int)
        for r in done:
            g2[r[key]] += 1
            if r["winner"] == wv:
                w2[r[key]] += 1
        line = "  " + seat + ": " + "  ".join(
            f"{d[:11]}={pct(w2[d], g2[d]):.0f}%" for d in sorted(g2))
        print(line)

    print("\n-- MATCHUP MATRIX (row = P1 deck, cell = P1 win%) --")
    decks = sorted(games)
    short = {d: d[:9] for d in decks}
    cell = defaultdict(lambda: [0, 0])
    for r in done:
        c = cell[(r["deck_p1"], r["deck_p2"])]
        c[1] += 1
        if r["winner"] == 0:
            c[0] += 1
    print("       " + "".join(f"{short[d][:8]:>9}" for d in decks))
    for a in decks:
        row = f"{short[a][:6]:<7}"
        for b in decks:
            w, g = cell[(a, b)]
            row += f"{pct(w, g):8.0f}%" if g else "       -"
        print(row)

    print("\n-- ENERGY ECONOMY (per player-round averages) --")
    pool = [r["p0_pool_avg"] for r in done] + [r["p1_pool_avg"] for r in done]
    att = [r["p0_att_avg"] for r in done] + [r["p1_att_avg"] for r in done]
    units = [r["p0_units_avg"] for r in done] + [r["p1_units_avg"] for r in done]
    peak = [r["p0_pool_peak"] for r in done] + [r["p1_pool_peak"] for r in done]
    print(f"  pool held      {dist(pool)}")
    print(f"  attached       {dist(att)}")
    print(f"  units on board {dist(units)}")
    print(f"  pool peak      {dist(peak)}")
    tot_q = sum(r["p0_queued"] + r["p1_queued"] for r in done)
    tot_u = sum(r["p0_unaff"] + r["p1_unaff"] for r in done)
    print(f"  unit-turns WITH a queued attack : {tot_q:8d}  "
          f"({pct(tot_q, tot_q + tot_u):.1f}%)")
    print(f"  unit-turns WITHOUT              : {tot_u:8d}  "
          f"({pct(tot_u, tot_q + tot_u):.1f}%)  <- attacks unaffordable/absent")
    idle = sum(r["p0_idle"] + r["p1_idle"] for r in done)
    print(f"  rounds w/ pool>=4 and nothing queued: {idle} "
          f"({idle/max(1,len(done)):.2f} per game)")

    print("\n-- DAMAGE ROUTING (per game, both players) --")
    du = sum(r["p0_dmg_unit"] + r["p1_dmg_unit"] for r in done) / len(done)
    dt = sum(r["p0_dmg_tower"] + r["p1_dmg_tower"] for r in done) / len(done)
    dth = sum(r["p0_dmg_throne"] + r["p1_dmg_throne"] for r in done) / len(done)
    tf = sum(r["p0_towerfire"] + r["p1_towerfire"] for r in done) / len(done)
    tot = du + dt + dth
    print(f"  card dmg -> units   {du:8.1f}  ({pct(du, tot):.1f}% of card damage)")
    print(f"  card dmg -> towers  {dt:8.1f}  ({pct(dt, tot):.1f}%)")
    print(f"  card dmg -> throne  {dth:8.1f}  ({pct(dth, tot):.1f}%)")
    print(f"  tower fire (all)    {tf:8.1f}   [belongs to no card]")
    print(f"  ratio tower-fire : card-damage = {tf/max(1,tot):.2f}")

    print("\n-- STRUCTURES AT GAME END --")
    lose_throne = sum(1 for r in done
                      if (r["winner"] == 0 and r["p1_throne"] <= 0)
                      or (r["winner"] == 1 and r["p0_throne"] <= 0))
    print(f"  games ending by throne kill: {lose_throne} "
          f"({pct(lose_throne, len(done)):.1f}%)")
    print(f"  loser throne max HP  {dist([r['p1_throne_max'] if r['winner']==0 else r['p0_throne_max'] for r in done])}")
    tow = []
    for r in done:
        tow += [r["p0_tower0"], r["p0_tower1"], r["p1_tower0"], r["p1_tower1"]]
    dead = sum(1 for t in tow if t <= 0)
    print(f"  towers dead at end: {dead}/{len(tow)} ({pct(dead, len(tow)):.1f}%)")


main()
