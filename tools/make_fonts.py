"""Regenerate the bundled, subset fonts in assets/fonts/.

The project ships Cinzel (display) and Inter (UI), both SIL Open Font License,
subset to Latin-1 plus the punctuation `Palette.GLYPH` needs. Subsetting takes
the pair from ~1MB to ~174KB, which matters because the web build is already a
39MB wasm download.

    python tools/make_fonts.py

Requires `fonttools` and network access to fetch the upstream sources.

Why these two, and why not the obvious alternatives:

  * Windows' Georgia, Cambria and Bookman are Microsoft/Monotype licensed and
    may not be redistributed. This repo is public and publishes to GitHub Pages,
    so a license-locked font is not a risk to manage — it simply cannot ship.
  * Godot's built-in Open Sans is what every unstyled Godot project renders in,
    which is precisely the look the bundle exists to get away from.

If `Palette.GLYPH` ever grows a character outside UNICODES below, `LayoutTest`
fails loudly rather than shipping a box — widen the range here and rerun.
"""

import io
import os
import subprocess
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "fonts")

# ASCII + Latin-1 supplement, plus the dashes, quotes and marks GLYPH uses.
UNICODES = (
    "U+0020-007E,U+00A0-00FF,U+2010-2015,U+2018-201D,"
    "U+2022,U+2026,U+00B7,U+00D7,U+2212,U+2190-2193"
)

FONTS = [
    (
        "Cinzel.ttf",
        "https://github.com/google/fonts/raw/main/ofl/cinzel/Cinzel%5Bwght%5D.ttf",
        "https://raw.githubusercontent.com/google/fonts/main/ofl/cinzel/OFL.txt",
        "OFL-Cinzel.txt",
    ),
    (
        "Inter.ttf",
        "https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz,wght%5D.ttf",
        "https://raw.githubusercontent.com/google/fonts/main/ofl/inter/OFL.txt",
        "OFL-Inter.txt",
    ),
]


def fetch(url: str, dest: str) -> None:
    with urllib.request.urlopen(url, timeout=60) as r, open(dest, "wb") as f:
        f.write(r.read())


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    tmp = os.path.join(OUT, "_src")
    os.makedirs(tmp, exist_ok=True)

    for name, url, lic_url, lic_name in FONTS:
        raw = os.path.join(tmp, name)
        print("fetching %s" % name)
        fetch(url, raw)
        fetch(lic_url, os.path.join(OUT, lic_name))

        dst = os.path.join(OUT, name)
        r = subprocess.run(
            [
                sys.executable, "-m", "fontTools.subset", raw,
                "--unicodes=" + UNICODES,
                "--output-file=" + dst,
                "--layout-features=kern,liga,calt,tnum",
                "--drop-tables+=DSIG",
                "--recalc-bounds",
            ],
            capture_output=True, text=True,
        )
        if r.returncode != 0:
            print("  subset FAILED:\n" + r.stderr[-800:])
            return 1
        before = os.path.getsize(raw)
        after = os.path.getsize(dst)
        print("  %-12s %7d -> %6d bytes (%.0f%% smaller)"
              % (name, before, after, 100 * (1 - after / before)))

    for f in os.listdir(tmp):
        os.remove(os.path.join(tmp, f))
    os.rmdir(tmp)
    print("\nRun Godot once with --import so the new .ttf files get .import files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
