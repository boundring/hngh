#!/usr/bin/env python3
# city-state.py -- static megastructure city-state export (hngh-1ut).
# Reads: bd list --json (beads), queue/roadmap Next (orient), timer states.
# Emits: one JSON city-state to stdout + one SVG district map to stderr-file.
# Usage: city-state.py [--svg PATH]  (read-only; never mutates state).
"""Static export: beads + queue + timers -> JSON city-state + SVG map."""
import json
import os
import subprocess
import sys

REPO = os.path.expanduser("~/Projects/etc/hngh")


def sh(*argv):
    try:
        r = subprocess.run(argv, capture_output=True, text=True, timeout=30,
                           cwd=REPO)
        return r.stdout.strip()
    except Exception:
        return ""


def beads():
    out = sh("bd", "list", "--json")
    try:
        data = json.loads(out)
        items = data if isinstance(data, list) else data.get("issues", [])
    except Exception:
        items = []
    if not items:  # --json lists open only; count closed separately
        closed_out = sh("bd", "list", "--status", "closed", "--json")
        try:
            cdata = json.loads(closed_out)
            closed_items = (cdata if isinstance(cdata, list)
                            else cdata.get("issues", []))
        except Exception:
            closed_items = []
        return {"open": 0, "closed": len(closed_items), "items": []}
    open_n = sum(1 for i in items if i.get("status") == "open")
    closed_out = sh("bd", "list", "--status", "closed", "--json")
    try:
        cdata = json.loads(closed_out)
        closed_items = (cdata if isinstance(cdata, list)
                        else cdata.get("issues", []))
    except Exception:
        closed_items = []
    closed_n = len(closed_items)
    return {"open": open_n, "closed": closed_n,
            "items": [{"id": i.get("id"), "title": i.get("title"),
                       "status": i.get("status"),
                       "priority": i.get("priority")} for i in items]}


def orient():
    out = sh("python3", "scripts/omp-bridge", "--orient")
    q = r = ""
    for ln in out.splitlines():
        if ln.startswith("## Queue Next"):
            q = "?"
        elif ln.startswith("## Roadmap Next"):
            r = "?"
    # next non-empty, non-header line after each marker
    section = None
    for ln in out.splitlines():
        s = ln.strip()
        if s == "## Queue Next":
            section = "q"
        elif s == "## Roadmap Next":
            section = "r"
        elif s.startswith("##"):
            section = None
        elif s and section == "q" and q == "?":
            q = s
        elif s and section == "r" and r == "?":
            r = s
    return {"queue_next": q or "?", "roadmap_next": r or "?"}


def timers():
    out = sh("systemctl", "--user", "list-timers")
    n = sum(1 for ln in out.splitlines() if "hngh" in ln)
    return {"hngh_timers": n, "beats": "held" if n == 0 else "active"}


def svg(state, path):
    n_open = state["beads"]["open"]
    n_closed = state["beads"]["closed"]
    beats = state["timers"]["beats"]
    # one block per closed bead, one scaffold per open bead (cap 40)
    blocks = []
    x = 20
    for i in range(min(n_closed, 20)):
        blocks.append(f'<rect x="{x}" y="120" width="18" height="{40 + i * 3}"'
                      f' fill="#5af78e"><title>closed {i}</title></rect>')
        x += 24
    for i in range(min(n_open, 20)):
        blocks.append(f'<rect x="{x}" y="140" width="18" height="30"'
                      f' fill="none" stroke="#e6b450"><title>open {i}</title></rect>')
        x += 24
    furnace = "#e06c6c" if beats == "active" else "#3d9c78"
    doc = (f'<svg xmlns="http://www.w3.org/2000/svg" width="800" height="240">'
           f'<rect width="800" height="240" fill="#0b0e11"/>'
           f'<text x="20" y="30" fill="#c8d0d8" font-size="14">hngh city-state'
           f' — beats {beats}, beads {n_closed} closed / {n_open} open</text>'
           f'<circle cx="740" cy="60" r="24" fill="{furnace}"/>'
           f'<text x="700" y="100" fill="#c8d0d8" font-size="10">furnace</text>'
           + "".join(blocks) + "</svg>")
    with open(path, "w") as f:
        f.write(doc)


def main():
    svg_path = None
    if "--svg" in sys.argv:
        svg_path = sys.argv[sys.argv.index("--svg") + 1]
    state = {"beads": beads(), "orient": orient(), "timers": timers()}
    print(json.dumps(state, indent=1))
    if svg_path:
        svg(state, svg_path)


if __name__ == "__main__":
    main()
