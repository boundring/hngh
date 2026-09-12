#!/usr/bin/env python3
"""manga-metrics -- deterministic layout metrics over sampled manga pages.

The SAFE study slice (docs/research/2026-09-12-manga-collection-study.md):
pages are extracted locally to a TEMP dir, measured, and deleted. What
survives is NUMBERS: panel bands per page (horizontal gutter projection),
panels per page (band x column grid estimate), ink/tone coverage (gray
histogram), and an ink-density histogram over a 3x3 page zone grid (the
bubble/text placement proxy). No vision model, no OCR, no network; pixels
never leave the machine and are never stored.

Pure stdlib + ImageMagick (`magick ... txt:-`) -- no PIL dependency.

usage: manga-metrics.py IMG [IMG...]            -> JSON per line
       manga-metrics.py --title NAME IMG...     -> tagged JSON per line
"""
import json
import subprocess
import sys

GW, GH = 120, 170   # measurement grid (downsampled page)
INK, TONE_HI = 64, 192
MARK = 200          # any non-white mark (light scan linework included)


def _grid(path):
    """Downsampled grayscale grid via magick; returns (W, H, values[y][x])."""
    out = subprocess.run(
        ["magick", path, "-colorspace", "Gray", "-resize",
         "%dx%d!" % (GW, GH), "txt:-"],
        capture_output=True, text=True, timeout=120, check=True)
    vals = [[255] * GW for _ in range(GH)]
    for line in out.stdout.splitlines()[1:]:
        try:
            coord, rest = line.split(":", 1)
            x, y = coord.split(",")
            g = int(float(rest.split("(")[1].split(")")[0].split(",")[0]))
            vals[int(y)][int(x)] = g
        except (ValueError, IndexError):
            continue
    return GW, GH, vals


def _gutter_runs(dark_rows, band_rows):
    """Count content bands between full-width/height white gaps."""
    bands = []
    start = None
    for i, d in enumerate(dark_rows):
        if d > 0.01 and start is None:
            start = i
        elif d <= 0.02 and start is not None:
            bands.append((start, i))
            start = None
    if start is not None:
        bands.append((start, len(dark_rows)))
    return [b for b in bands if b[1] - b[0] > max(2, band_rows // 20)]


def analyze(path):
    w, h, v = _grid(path)
    ink = tone = total = 0
    zones = [[0] * 3 for _ in range(3)]  # ink count per 3x3 zone (top->bottom)
    for y in range(h):
        for x in range(w):
            g = v[y][x]
            total += 1
            if g < INK:
                ink += 1
                zones[y * 3 // h][x * 3 // w] += 1
            elif g < TONE_HI:
                tone += 1
    dark_rows = [sum(1 for x in range(w) if v[y][x] < MARK) / w
                 for y in range(h)]
    bands = _gutter_runs(dark_rows, h)
    panels = 0
    for (y0, y1) in bands:
        dark_cols = [sum(1 for y in range(y0, y1) if v[y][x] < MARK)
                     / (y1 - y0) for x in range(w)]
        cols = _gutter_runs(dark_cols, y1 - y0)
        panels += max(1, len(cols))
    ink_rows = {k: round(z / (total / 3), 4)
              for k, z in zip(["top", "mid", "bottom"],
                              [sum(zones[r]) for r in range(3)])}
    return {
        "page": path,
        "panel_bands": len(bands),
        "panels_est": panels,
        "ink_coverage": round(ink / total, 4),
        "tone_coverage": round(tone / total, 4),
        "white_coverage": round(1 - (ink + tone) / total, 4),
        "ink_rows": ink_rows,
    }


def main(argv):
    title = None
    if "--title" in argv:
        title = argv[argv.index("--title") + 1]
    skip = {"--title", title}
    args = [a for a in argv[1:] if not a.startswith("--") and a not in skip]
    if not args:
        print("usage: manga-metrics.py [--title NAME] IMG...", file=sys.stderr)
        return 1
    for p in args:
        row = analyze(p)
        if title:
            row["title"] = title
        print(json.dumps(row, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))