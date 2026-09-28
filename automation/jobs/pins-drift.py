#!/usr/bin/env python3
"""pins-drift -- pins x pacman-db -> drift report. Pure comparator.

The daily check crystallized from the os-package-pairing line
(design: docs/research/2026-09-26-arc-20260925-os-package-pairing.md):
the pins file is intended state, the local pacman db is actual state;
this module diffs the two and reports. It NEVER installs, upgrades, or
removes anything -- no code path shells to pacman write operations
(auditable by grep: only -Q / -Qq appear below). Auto-update is out of
scope by definition.

Pins file: automation/config/hngh-pins.tsv. NOT hngh-packages.tsv --
that path is the 2026-09-11 collected-repositories registry with its
own schema and guard test (test-hngh-packages.py). Created on first
run with the header plus seed rows from lib/prereqs.sh's prereq_pkg
map (names only; deliberately NOT a mass `pacman -Qqe` import).

Drift kinds:
  missing  pinned package absent from the pacman db
  older    db version below the pin's min_version floor (a floor, not
           an exact pin: db newer than min_version is not drift)

CLI (exit conventions mirror scripts/report-queue: 2 on malformed
input, fail closed):
  --check  meaningful exit: 0 = ran fine (clean OR drift), 2 = input
           error (pins file unreadable, pacman missing/failing)
  --json   stdout JSON {drift:[{name,pin,db,kind}], unpinned_count, ok}
           (consumer: cadence 31-omarchy-readiness.sh greps "ok": true)
Without --json a human summary goes to stdout; db packages not pinned
are counted, never alerted individually (listing capped at 10).
"""

import json
import os
import re
import subprocess
import sys

AUTOMATION_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PINS_PATH = os.path.join(AUTOMATION_ROOT, "config", "hngh-pins.tsv")
PREREQS = os.path.join(AUTOMATION_ROOT, "lib", "prereqs.sh")
PINS_HEADER = "name\tmin_version\tnote"


class CheckError(Exception):
    """Fail-closed input error (exit 2): never reads as 'no drift'."""


def _verkey(v):
    # ponytail: naive epoch+dot-numeric compare (leading "N:" epoch,
    # then numeric dot components, pkgrel kept as a tiebreaker) --
    # enough for floor pins like "3.11"; upgrade to pyalpm.vercmp if
    # lettered pkgvers ever drift-fight here.
    epoch, sep, rest = v.partition(":")
    if not sep:
        epoch, rest = "0", v
    try:
        e = int(epoch)
    except ValueError:
        e = 0
    pkgrel = 0
    if "-" in rest:
        rest, _, rel = rest.rpartition("-")
        try:
            pkgrel = int(rel)
        except ValueError:
            pkgrel = 0
    parts = []
    for c in rest.split("."):
        try:
            parts.append((0, int(c), ""))
        except ValueError:
            parts.append((1, 0, c))
    return (e, parts, pkgrel)


_PREREQ_PKG_RE = re.compile(
    r"^\s*([A-Za-z0-9_@+.-]+)\)\s+echo\s+([A-Za-z0-9_@+.-]+)\s+;;")


def prereq_pkgs():
    """Package names from lib/prereqs.sh's prereq_pkg map (names only)."""
    try:
        with open(PREREQS, encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return []
    found = set()
    for line in text.splitlines():
        m = _PREREQ_PKG_RE.match(line)
        if m:
            found.add(m.group(2))
    return sorted(found)


def ensure_pins():
    """Create the pins file with header + prereq seed rows if absent."""
    if os.path.exists(PINS_PATH):
        return False
    os.makedirs(os.path.dirname(PINS_PATH), exist_ok=True)
    lines = [
        "# hngh pins vs pacman drift check (jobs/pins-drift.py);",
        "# min_version = floor (empty = presence only); seeded from",
        PINS_HEADER,
    ]
    lines += [n + "\t\tseeded from lib/prereqs.sh" for n in prereq_pkgs()]
    with open(PINS_PATH, "x", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    return True


def load_pins():
    """-> ([(name, min_version, note)], skipped_count). Fresh each run."""
    pins, skipped = [], 0
    with open(PINS_PATH, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            if line.strip() == PINS_HEADER:
                continue
            parts = line.split("\t")
            if len(parts) != 3 or not parts[0].strip():
                skipped += 1
                continue
            pins.append((parts[0].strip(), parts[1].strip(), parts[2].strip()))
    return pins, skipped


def read_db():
    """-> ({name: version-or-None}, names_only). Read-only, no lock."""
    try:
        p = subprocess.run(["pacman", "-Q"], capture_output=True,
                           text=True, check=False)
    except FileNotFoundError as e:
        raise CheckError("pacman not found: %s" % e)
    if p.returncode != 0:
        # fallback: names only (version floors unverifiable there)
        try:
            p = subprocess.run(["pacman", "-Qq"], capture_output=True,
                               text=True, check=False)
        except FileNotFoundError as e:
            raise CheckError("pacman not found: %s" % e)
        if p.returncode != 0:
            raise CheckError("pacman -Q failed: %s"
                             % (p.stderr or "").strip()[:200])
        return {n: None for n in p.stdout.split()}, True
    db = {}
    for line in p.stdout.splitlines():
        if not line.strip():
            continue
        name, _, ver = line.partition(" ")
        db[name] = ver.strip() or None
    return db, False


def check():
    """The pure function: pins x pacman-db -> report dict (+ context)."""
    created = ensure_pins()
    pins, skipped = load_pins()
    db, names_only = read_db()
    drift = []
    pinned = set()
    for name, minv, _note in pins:
        pinned.add(name)
        if name not in db:
            drift.append({"name": name, "pin": minv, "db": None,
                          "kind": "missing"})
        elif minv and not names_only and _verkey(db[name]) < _verkey(minv):
            drift.append({"name": name, "pin": minv, "db": db[name],
                          "kind": "older"})
    unpinned = sorted(n for n in db if n not in pinned)
    report = {"drift": drift, "unpinned_count": len(unpinned),
              "ok": not drift}
    return report, unpinned, skipped, created


def main(argv):
    for a in argv:
        if a not in ("--json", "--check"):
            sys.stderr.write("usage: pins-drift.py [--check] [--json]\n")
            return 2
    try:
        report, unpinned, skipped, created = check()
    except CheckError as e:
        sys.stderr.write(repr(e) + "\n")
        return 2
    except OSError as e:
        sys.stderr.write(repr(e) + "\n")
        return 2
    if "--json" in argv:
        print(json.dumps(report))
    else:
        if created:
            sys.stderr.write("pins-drift: created %s (seeded from %s)\n"
                             % (PINS_PATH, os.path.basename(PREREQS)))
        for r in report["drift"]:
            print("%s: %s pin=%s db=%s" % (r["kind"], r["name"],
                                           r["pin"] or "-", r["db"]))
        line = "pins-drift: %d drifted, %d unpinned" % (
            len(report["drift"]), report["unpinned_count"])
        if unpinned:
            line += " (sample: %s)" % ", ".join(unpinned[:10])
        print(line)
    if skipped:
        sys.stderr.write("pins-drift: skipped %d malformed pins row(s)\n"
                         % skipped)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
