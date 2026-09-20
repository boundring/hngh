"""Jcode guard rails as code: read-only swarm session checker (stdlib only).
Usage: jcode_guard.py <session.json>: exit 0 in bounds, else exit 1 + one stderr line.
"""
from __future__ import annotations

import json
import os
import sys
from collections import Counter

NODE_CAP = int(os.environ.get("HNGH_NODE_CAP", "64"))
DEPTH_CAP = int(os.environ.get("HNGH_DEPTH_CAP", "8"))


def _fail(msg: str) -> int:
    sys.stderr.write(f"jcode_guard: FAIL {msg}\n")
    return 1


def _items(doc: object) -> list | None:
    if isinstance(doc, list):
        return doc
    if isinstance(doc, dict):
        for key in ("items", "nodes"):
            v = doc[key] if key in doc else None
            if isinstance(v, list):
                return v
            if isinstance(v, dict):
                return list(v.values())
        plan = doc.get("plan")
        if isinstance(plan, dict):
            return _items(plan)
    return None


def _depth(items: list) -> int | None:
    by_id = {n.get("id"): n for n in items if isinstance(n, dict) and n.get("id")}
    if not any(isinstance(n, dict) and n.get("blocked_by") for n in items):
        return None  # no edges present: nothing to bound
    memo: dict = {}

    def dep(nid: str, seen: frozenset) -> int:
        if nid in seen:
            return 1 << 30  # cycle: unbounded, fail closed downstream
        if nid in memo:
            return memo[nid]
        node = by_id.get(nid, {})
        parents = node.get("blocked_by") or []
        d = 1 + max([dep(p, seen | {nid}) for p in parents if p in by_id] or [0])
        memo[nid] = d
        return d

    return max([dep(nid, frozenset()) for nid in by_id] or [1])


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        return _fail(f"usage: {argv[0]} <session.json>")
    try:
        with open(argv[1], encoding="utf-8") as fh:
            doc = json.load(fh)
    except (OSError, ValueError) as exc:
        return _fail(f"unreadable session JSON {argv[1]}: {exc}")
    items = _items(doc)
    if items is None:
        return _fail(f"no node list (plan.items/nodes) in {argv[1]}")
    n = len(items)
    if n > NODE_CAP:
        return _fail(f"node-cap exceeded: {n} nodes > cap {NODE_CAP}")
    depth = _depth(items)
    if depth is not None and depth > DEPTH_CAP:
        return _fail(f"depth-cap exceeded: depth {depth} > cap {DEPTH_CAP}")
    counts = Counter(n.get("status", "?") if isinstance(n, dict) else "?" for n in items)
    tally = ", ".join(f"{k}={v}" for k, v in sorted(counts.items()))
    sys.stderr.write(f"jcode_guard: ok: {n} nodes (cap {NODE_CAP}): {tally}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
