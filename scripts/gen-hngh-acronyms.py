#!/usr/bin/env python3
"""gen-hngh-acronyms.py — recursive-acronym expansion generator for "Hngh".

DECISION (2026-08-08): the canonical expansion is

    Hngh Network Goes Hngh.

A doubly-recursive bookend — "Hngh" is both the first and last word, the
acronym expanding into itself. Not the most efficient form; it works, and
the owner likes it, so it ships.

This script's default output is that canonical form. EVERYTHING else —
the full gated enumeration (H-N-G-<Hngh> via the grammar gate), the human
curated picks, and the owner/prompt-composed bookend family — is archived
under data/acronyms/archive/ as best efforts *toward* the winner. Nothing
else is promoted into the canonical file.

Usage
-----
  python3 scripts/gen-hngh-acronyms.py            # canonical file
  python3 scripts/gen-hngh-acronyms.py --archive  # regenerate the archive
  python3 scripts/gen-hngh-acronyms.py --flipped  # include flipped series in
                                                  # the archive (default on)

SPDX-License-Identifier: AGPL-3.0-or-later
SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>
"""

import argparse
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT_DIR = os.path.join(ROOT, "data", "acronyms")
ARCHIVE_DIR = os.path.join(OUT_DIR, "archive")
CANONICAL = os.path.join(OUT_DIR, "hngh-acronyms.txt")
ARCHIVE = os.path.join(ARCHIVE_DIR, "hngh-acronyms-candidates.txt")

WINNER = "Hngh Network Goes Hngh."

# --- curated H subjects, grouped by semantic TYPE --------------------------
H_GROUPS = [
    (("Agents"), [
        "hermes", "host",
    ]),
    (("Structures & places"), [
        "home",
    ]),
    (("Elements & forces"), [
        # culled
    ]),
    (("States & properties"), [
        "heavy",
    ]),
]

# --- curated N connectors ----------------------------------------------
N_WORDS = [
    "network", "networks", "next", "never", "not", "now", "nor",
]

# --- curated G verbs, split by form for the grammar gate ----------------
G_VERBS = [
    ("goes", "go"), ("grows", "grow"), ("grinds", "grind"),
    ("gives", "give"), ("gets", "get"), ("gains", "gain"),
    ("grunts", "grunt"), ("generates", "generate"),
    ("greets", "greet"), ("gardens", "garden"),
]
G_3P = [v3 for v3, _ in G_VERBS]
G_BARE = [vb for _, vb in G_VERBS]

# --- grammar gate: which verb form each N-connector takes -----------------
N_VERB_FORM = {
    "network": G_3P,
    "networks": G_3P,
    "never": G_3P,
    "now": G_3P,
    "next": G_BARE,
    "not": [],
    "nor": [],
}

# --- human-curated picks (all grammatical, some near-misses on meaning) --
CURATED_PICKS = [
    "Hermes Next Go Hngh.",
    "Home Next Go Hngh.",
    "Hngh Next Go Home.",
    "Home Never Goes Hngh.",
    "Host Never Goes Hngh.",
    "Heavy Never Goes Hngh.",
    "Hermes Never Goes Hngh.",
    "Home Network Goes Hngh.",
    "Home Network Grunts Hngh.",
    "Host Network Grinds Hngh.",
    "Heavy Network Grinds Hngh.",
    "Host Network Gives Hngh.",
    "Hngh Never Goes Home.",
    "Hngh Network Goes Home.",
    "Hngh Now Goes Home.",
]

# --- composed bookend family (Hngh ... Hngh) — PROMOTED to canonical. ----
# The owner's call (2026-08-08): the whole "Hngh ... Hngh" bookend group is
# good — the acronym expanding into itself on both ends. Winner first:
#   Hngh Network Goes Hngh.
# Honorable mention (user): "Hngh Network Grows Hngh." — same register, the
# network growing itself. The "Hngh ... Heavy" cost-discipline variants were
# considered and DISCARDED (they break the self-referential bookend shape).
BOOKEND_FAMILY = [
    "Hngh Network Goes Hngh.",
    "Hngh Network Grows Hngh.",
    "Hngh Network Grinds Hngh.",
    "Hngh Network Generates Hngh.",
    "Hngh Never Goes Hngh.",
    "Hngh Now Generates Hngh.",
    "Hngh Next Grinds Hngh.",
    "Hngh Next Grows Hngh.",
]


def title(word):
    return word[0].upper() + word[1:] if word else word


def render(h, n, g):
    return f"{title(h)} {title(n)} {title(g)} Hngh."


def render_flipped(n, g, h):
    return f"Hngh {title(n)} {title(g)} {title(h)}."


def section_entries(words, flipped):
    """Generate the gated (H N G Hngh) forms for one H-group.

    Flipped forms that END in "Heavy" are dropped: the owner discarded the
    "... Heavy" ending register entirely ("Hngh ... Heavy" lines) — the
    canonical bookends must end in "Hngh". Forward forms that START with
    H-word "Heavy" are fine (they end in Hngh).
    """
    lines = []
    for h in words:
        for n in N_WORDS:
            allowed = N_VERB_FORM[n]
            for g in allowed:
                lines.append(render(h, n, g))
                if flipped and h != "heavy":
                    lines.append(render_flipped(n, g, h))
    return sorted(set(lines))


def write_canonical():
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(CANONICAL, "w", encoding="utf-8") as f:
        f.write("# Hngh — recursive-acronym expansion\n\n")
        f.write("Canonical bookend family (2026-08-08) — Hngh is both the\n")
        f.write("first and the last word; the acronym expands into itself.\n")
        f.write("Winner first:\n\n")
        for line in BOOKEND_FAMILY:
            f.write(f"- {line}\n")
        f.write("\nAll other candidates are archived at\n")
        f.write("`data/acronyms/archive/` as best efforts toward this group.\n")


def write_archive(flipped):
    os.makedirs(ARCHIVE_DIR, exist_ok=True)
    with open(ARCHIVE, "w", encoding="utf-8") as f:
        f.write("# Hngh — archived alternative expansions\n\n")
        f.write("Best efforts toward the canonical bookend family\n")
        f.write("(`Hngh ... Hngh`, see `data/acronyms/hngh-acronyms.txt`).\n")
        f.write("None of these are promoted; kept for reference and possible\n")
        f.write("regional/secondary use.\n\n")
        total = 0

        f.write("## Gated enumeration (H-N-G-<Hngh>)\n\n")
        for headline, words in H_GROUPS:
            entries = section_entries(words, flipped)
            total += len(entries)
            f.write(f"### {headline}\n\n")
            if entries:
                f.write("\n".join(entries) + "\n\n")
            else:
                f.write("_(culled — no words in this type)_\n\n")

        f.write("## Human-curated picks\n\n")
        for line in CURATED_PICKS:
            f.write(line + "\n")
        f.write("\n")

        f.write("## Bookend family (canonical, reference copy)\n\n")
        for line in BOOKEND_FAMILY:
            f.write(line + "\n")
        f.write("\n")
        total += len(CURATED_PICKS) + len(BOOKEND_FAMILY)
        print(f"archive: {total} lines -> {ARCHIVE}")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--archive", action="store_true",
                    help="regenerate the candidate archive")
    ap.add_argument("--flipped", action="store_true", default=True,
                    help="include the flipped series in the archive (default)")
    ns = ap.parse_args(argv)
    if ns.archive:
        write_archive(ns.flipped)
    else:
        write_canonical()
        print(f"canonical: {WINNER} -> {CANONICAL}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())