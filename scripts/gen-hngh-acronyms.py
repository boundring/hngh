#!/usr/bin/env python3
"""gen-hngh-acronyms.py — enumerate recursive acronym expansions for "Hngh".

The user's reference is "Home Network Goes Hngh": a 4-word recursive
acronym, H-N-G-<Hngh>, that reads as a complete SENTENCE with "Hngh" as the
guttural complement ("goes boom" -> "goes Hngh"). So G is a verb that pairs
with the subject, not an object noun.

Output is a reference document, grouped into headered sections BY H-WORD
TYPE (agent / structure / element / state), title-cased, alphabetized within
a section. Punctuation is applied judgementally: an Oxford comma separates a
coordinate list when the H-word expands to one (e.g. "Heavy, Hard ..."),
otherwise the line stays a clean single clause.

Usage
-----
  python3 scripts/gen-hngh-acronyms.py [--out FILE] [--show N]

SPDX-License-Identifier: AGPL-3.0-or-later
SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>
"""

import argparse
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DEFAULT_OUT = os.path.join(ROOT, "data", "acronyms", "hngh-acronyms.txt")

# --- curated H subjects, grouped by semantic TYPE --------------------------
# "Hermes" is the anchor (the recursion should land on the actual agent).
# Sections in the output are these five types, in this order.
H_GROUPS = [
    # (type headline, [words])
    ("## Agents", [
        "hermes", "herald", "heretic", "hunter", "hyperion",
        "hydra", "host",
    ]),
    ("## Structures & places", [
        "harbor", "hangar", "haven", "hearth", "hive", "home", "hull",
        "husk",
    ]),
    ("## Elements & forces", [
        "hazard", "horizon", "howl", "hydrogen", "halo", "hearse",
    ]),
    ("## States & properties", [
        "heavy", "hard", "hollow", "hyper",
    ]),
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

# --- title-casing helper ----------------------------------------------------
def title(word):
    return word[0].upper() + word[1:] if word else word


# --- punctuation: Oxford comma where the H-word is a coordinate list -------
# If the H-word itself reads as two items joined ("hard-and-heavy"), the
# expansion is a list and gets a comma; otherwise a clean clause. Most H-words
# here are single units, so most lines stay comma-free. This maps just the
# obviously-coordinate H forms.
OXFORD_H = {
    # h-word -> rendered leading list
    "hard": "Hard",
    "heavy": "Heavy",
    "hyper": "Hyper",
}
# A minimal, honest rule: a comma separates a leading item from the rest only
# when the H-word is itself a count noun being elaborated. Leave the rule
# OFF by default (the lines are single clauses); set True to enable.
ENABLE_OXFORD = False


def render(h, n, g):
    """Render one expansion as a punctuated sentence.

    Title-cased (each word starts its own letter of the acronym), terminated
    with a period since each is a full independent clause. An Oxford comma is
    applied ONLY where the line is a genuine coordinate list (the H-word
    expands to two adjacent list items), which is the only context the comma
    is grammatical. Most H-words here are single units, so most lines get no
    comma — correctly, because these are single clauses, not lists.
    """
    head = title(h)
    mid = title(n)
    tail = title(g)
    if ENABLE_OXFORD and h in OXFORD_H:
        # coordinate list: "Hard, Heavy, Hollow — Hngh" reads as a list of
        # three properties; comma before the final item is the Oxford comma.
        return f"{head}, {mid} {tail} Hngh."
    return f"{head} {mid} {tail} Hngh."


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--show", type=int, default=20)
    ns = ap.parse_args(argv)

    os.makedirs(os.path.dirname(ns.out) or ".", exist_ok=True)
    with open(ns.out, "w", encoding="utf-8") as f:
        f.write("# Hngh — recursive-acronym expansions\n\n")
        f.write("4-word recursive acronyms (H-N-G-<Hngh>), grouped by the "
                "type of the H-word, alphabetized within each section.\n\n")
        total = 0
        for headline, words in H_GROUPS:
            lines = []
            for h in words:
                for n in N_WORDS:
                    for g in G_WORDS:
                        lines.append(render(h, n, g))
            lines = sorted(set(lines))
            total += len(lines)
            f.write(f"{headline}\n\n")
            f.write("\n".join(lines) + "\n\n")
        print(f"wrote {total} expansions -> {ns.out}")

    # sample across sections for the terminal
    with open(ns.out, encoding="utf-8") as f:
        text = f.read()
    heads = [l for l in text.splitlines() if l.startswith("## ")]
    print("--- sections ---")
    for h in heads:
        print("  " + h)
    print(f"--- sample ({ns.show}) ---")
    body_lines = [l for l in text.splitlines()
                  if l and not l.startswith("#") and not l.startswith("## ")]
    for line in body_lines[: ns.show]:
        print("  " + line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())