#!/usr/bin/env python3
"""render-blocks feed builder — parses HNGH-RENDER side-channel capture
files (one v1 JSON envelope per line, written by automation/jcode/
worker.mjs when JCODE_WORKER_RENDER includes fd3 and JCODE_RENDER_LOG is
set) into dashboard/render-blocks.json for a dashboard consumer.

Fail-closed rules (mirror render-blocks.mjs): a line that is not valid
JSON, or an envelope without v==1, is skipped (never fatal); envelopes
with duplicate ids keep the first; blocks carry through unvalidated
beyond the v1 check — the consumer renders only what it knows.

Usage: render-blocks-feed.py [--capture FILE]... [--out FILE] [--max N]
Default capture: automation/state/render-blocks.jsonl (the documented
JCODE_RENDER_LOG target); default out: dashboard/render-blocks.json.
"""
import argparse
import json
import os
import sys
import time

DEFAULT_CAPTURE = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "state",
    "render-blocks.jsonl")
DEFAULT_OUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "dashboard",
    "render-blocks.json")


def parse_capture(path):
    """Yield (ts, envelope) for each valid v1 line; skip bad lines."""
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    env = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(env, dict) or env.get("v") != 1:
                    continue
                ts = env.get("ts") or ""
                yield ts, env
    except OSError:
        return


def build(capture_paths, max_envelopes):
    """Newest-last envelope list, deduped by id (first wins)."""
    seen = set()
    envelopes = []
    for path in capture_paths:
        if not os.path.isfile(path):
            continue
        for ts, env in parse_capture(path):
            eid = env.get("id") or (ts + ":" + str(len(envelopes)))
            if eid in seen:
                continue
            seen.add(eid)
            envelopes.append({
                "id": eid,
                "ts": ts,
                "kind": env.get("kind", "turn-render"),
                "session": env.get("session", ""),
                "blocks": env.get("blocks", []) if isinstance(
                    env.get("blocks"), list) else [],
                "tools": env.get("tools", []) if isinstance(
                    env.get("tools"), list) else [],
                "usage": env.get("usage", {}) if isinstance(
                    env.get("usage"), dict) else {},
            })
    envelopes.sort(key=lambda e: e["ts"] or "")
    envelopes = envelopes[-max_envelopes:]
    return {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ",
                                      time.gmtime()),
        "count": len(envelopes),
        "envelopes": envelopes,
    }


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--capture", action="append", default=[],
                    help="capture file (repeatable)")
    ap.add_argument("--out", default=DEFAULT_OUT)
    ap.add_argument("--max", type=int, default=50,
                    help="max envelopes kept (newest)")
    args = ap.parse_args(argv)
    captures = args.capture or [DEFAULT_CAPTURE]
    data = build(captures, max(1, args.max))
    out_dir = os.path.dirname(os.path.abspath(args.out))
    os.makedirs(out_dir, exist_ok=True)
    fd, tmp = None, None
    tmp = args.out + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1)
    os.replace(tmp, args.out)
    print(f"render-blocks feed: {data['count']} envelopes -> {args.out}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
