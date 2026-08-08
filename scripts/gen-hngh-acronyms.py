#!/usr/bin/env python3
"""gen-hngh-acronyms.py — enumerate recursive acronym expansions for "Hngh".

The user's reference is "Home Network Goes Hngh": a 4-word recursive
acronym, H-N-G-<Hngh>, that reads as a complete SENTENCE with "Hngh" as the
guttural complement ("goes boom" -> "goes Hngh"). So G is a verb that pairs
with the subject, not an object noun.

Register: guttural megastructure (BLAME!/Nihei), the words the owner likes.

Usage
-----
  python3 scripts/gen-hngh-acronyms.py [--out FILE] [--show N]

SPDX-License-Identifier: AGPL-3.0-or-later
SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>
"""

import argparse
import os
import random

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DEFAULT_OUT = os.path.join(ROOT, "data", "acronyms", "hngh-acronyms.txt")

# --- curated H subjects -----------------------------------------------
# nouns/adjectives a guttural system/place can be. "Hermes" is the anchor
# (the recursion should land on the actual agent); hyper/hive/etc are the
# register. "Hermes next go Hngh" is the reference sentence.
H_WORDS = [
    "hermes", "hyperion", "hyper", "hive", "host", "heavy", "hard",
    "hollow", "husk", "hull", "horizon", "hazard", "howl", "hearse",
    "hearth", "hydrogen", "hunter", "helios", "harbor", "halo",
    "hangar", "haven", "herald", "heretic", "hydra", "home",
]

# --- curated N connectors ----------------------------------------------
# network (user-approved) + next (from "Hermes next go Hngh") + negations
N_WORDS = [
    "network", "networks", "next", "never", "not", "now", "nor",
]

# --- curated G verbs (pairing-verb + "Hngh" complement) ----------------
G_WORDS = [
    "goes", "go", "grows", "grinds", "grind", "gives", "give", "gets",
    "get", "gains", "gain", "grunts", "grunt", "generates", "generate",
    "greets", "greet", "gardens", "garden",
]


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--show", type=int, default=30)
    ns = ap.parse_args(argv)

    lines = set()
    for h in H_WORDS:
        for n in N_WORDS:
            for g in G_WORDS:
                lines.add(f"{h} {n} {g} Hngh")
    lines = list(lines)
    random.Random(0).shuffle(lines)

    os.makedirs(os.path.dirname(ns.out) or ".", exist_ok=True)
    with open(ns.out, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {len(lines)} sentence-grammar expansions -> {ns.out}")
    print("--- sample ---")
    for line in lines[: ns.show]:
        print("  " + line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())