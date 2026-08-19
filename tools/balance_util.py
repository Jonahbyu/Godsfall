"""Shared loaders for the balance sweep. Reads data/cards.json and the sample
decks out of DeckStore.gd so every analysis script agrees on what a deck holds."""
import json, re, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def load_cards():
    d = json.load(open(os.path.join(ROOT, 'data/cards.json'), encoding='utf-8'))
    return {c['id']: c for c in d['cards']}

def kws(c):
    return {k['kw']: k.get('n', 0) for k in c.get('keywords', [])}

def load_decks():
    """Samples are {"name": X, "cards": _x()} pointing at a function whose body
    is a flat dict literal, so this resolves that indirection."""
    src = open(os.path.join(ROOT, 'scripts/core/DeckStore.gd'), encoding='utf-8').read()
    bodies = {}
    pat = re.compile(r'^func (_\w+)\(\) -> Dictionary:\n\treturn \{(.*?)^\t\}', re.S | re.M)
    for m in pat.finditer(src):
        bodies[m.group(1)] = {cid: int(n) for cid, n
                              in re.findall(r'"([a-z0-9_]+)"\s*:\s*(\d+)', m.group(2))}
    decks = {}
    ref = re.compile(r'"name"\s*:\s*"([^"]+)"\s*,\s*\n\s*"cards"\s*:\s*(\w+)\(\)')
    for m in ref.finditer(src):
        if m.group(2) in bodies:
            decks[m.group(1)] = bodies[m.group(2)]
    return decks

if __name__ == '__main__':
    c = load_cards(); d = load_decks()
    print(f"{len(c)} cards, {len(d)} decks")
    for k, v in d.items():
        print(f"  {k:<18} {sum(v.values()):3d} cards, {len(v)} distinct")
