"""Profile each sample deck against its measured win rate, to find which
mechanical properties predict winning."""
import sys, re
from collections import Counter
from balance_util import load_cards, load_decks, kws

WR = {}
for line in open(sys.argv[1], encoding='utf-8'):
    m = re.match(r'\s{2}(\S.*?)\s{2,}(\d+\.\d)%\s+\((\d+)/(\d+)\)', line)
    if m and m.group(1) not in WR:
        WR[m.group(1).strip()] = float(m.group(2))

cards, decks = load_cards(), load_decks()

print(f"{'deck':<18}{'win%':>6}{'hp/u':>7}{'units':>6}{'nrg':>5}{'sup':>5}"
      f"{'dmg/e':>7}{'avgdmg':>7}{'kwds'}")
print("-" * 100)
rows = []
for name, dk in decks.items():
    units = [(cards[c], n) for c, n in dk.items() if cards[c]['type'] == 'unit']
    nu = sum(n for _, n in units)
    hp = sum(c['hp'] * n for c, n in units) / max(1, nu)
    nrg = sum(n for c, n in dk.items() if cards[c]['type'] == 'energy')
    sup = sum(n for c, n in dk.items() if cards[c]['type'].endswith('support')
              or cards[c]['type'] == 'tool')
    dmgs, rates, kw = [], [], Counter()
    for c, n in units:
        for k, v in kws(c).items():
            kw[k] += n
        for a in c.get('attacks', []):
            if a.get('ability'):
                continue
            cost = sum(v for v in a.get('cost', {}).values())
            d = a.get('damage', 0)
            if d > 0:
                dmgs.append(d)
                if cost > 0:
                    rates.append(d / cost)
    rows.append((WR.get(name, 0), name, hp, nu, nrg, sup,
                 sum(rates)/max(1,len(rates)), sum(dmgs)/max(1,len(dmgs)),
                 " ".join(f"{k}:{v}" for k, v in kw.most_common(4))))

for w, name, hp, nu, nrg, sup, rate, dmg, kw in sorted(rows, reverse=True):
    print(f"{name:<18}{w:6.1f}{hp:7.1f}{nu:6d}{nrg:5d}{sup:5d}{rate:7.2f}{dmg:7.1f}  {kw}")
