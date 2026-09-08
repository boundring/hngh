#!/usr/bin/env python3
"""kb-feed — snapshot the llm-wiki sources into dashboard/kb/ for the KB tab.

Copies ~/.llm-wiki/wiki/sources/*.md into dashboard/kb/<slug>.md (sanitized
flat names) and writes dashboard/kb/index.json:

    {generated, docs: [{slug, title, size, mtime, preview}]}

  title   first '# ' heading, else the slug
  preview first 3 non-empty lines, whitespace-collapsed
  mtime   source mtime, UTC ISO

Caps: 200 files max, 200KB per file. Fail-closed per file: a file that
cannot be read/copied (or exceeds the size cap) is skipped with a stderr
note; everything else still lands. The vault changes rarely — refresh is
the refresh-dashboard.sh cadence drop-in, not a per-minute job. Display
layer only — never governance input.
"""
import os
import json
import re
import sys
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KB_DIR = os.path.join(ROOT, "dashboard", "kb")
SOURCES = os.path.join(os.path.expanduser("~"), ".llm-wiki", "wiki", "sources")

MAX_FILES = 200
MAX_BYTES = 200 * 1024


def iso(ts):
    return datetime.fromtimestamp(ts, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def slugify(stem):
    s = re.sub(r"[^A-Za-z0-9._-]+", "_", stem).strip("._") or "doc"
    return s[:100]


def first_heading(text):
    m = re.search(r"^#\s+(.+)$", text, re.M)
    return m.group(1).strip() if m else None


def preview(text):
    lines = [re.sub(r"\s+", " ", l).strip() for l in text.splitlines()]
    lines = [l for l in lines if l]
    return " ".join(lines[:3])[:300]


def main():
    os.makedirs(KB_DIR, exist_ok=True)
    try:
        names = sorted(
            n for n in os.listdir(SOURCES) if n.endswith(".md"))
    except OSError as e:
        print("kb-feed: sources unreadable: %s" % e, file=sys.stderr)
        return  # fail-closed: keep the prior snapshot untouched

    docs, taken = [], set()
    for name in names:
        if len(docs) >= MAX_FILES:
            print("kb-feed: file cap %d reached; %d sources skipped"
                  % (MAX_FILES, len(names) - MAX_FILES), file=sys.stderr)
            break
        src = os.path.join(SOURCES, name)
        try:
            if os.path.getsize(src) > MAX_BYTES:
                print("kb-feed: skip %s: over %d bytes" % (name, MAX_BYTES),
                      file=sys.stderr)
                continue
            with open(src, "r", encoding="utf-8", errors="replace") as f:
                text = f.read()
        except OSError as e:
            print("kb-feed: skip %s: %s" % (name, e), file=sys.stderr)
            continue

        slug = slugify(name[:-3])
        base, n = slug, 2
        while slug in taken:
            slug = "%s-%d" % (base, n)
            n += 1
        taken.add(slug)

        dst = os.path.join(KB_DIR, slug + ".md")
        try:
            with open(dst, "w", encoding="utf-8") as f:
                f.write(text)
        except OSError as e:
            print("kb-feed: skip %s: write failed: %s" % (name, e),
                  file=sys.stderr)
            continue
        st = os.stat(src)
        docs.append({
            "slug": slug,
            "title": first_heading(text) or slug,
            "size": len(text.encode("utf-8")),
            "mtime": iso(st.st_mtime),
            "preview": preview(text),
        })

    docs.sort(key=lambda d: d["mtime"], reverse=True)

    # drop stale copies of sources that vanished from the vault
    keep = {d["slug"] + ".md" for d in docs}
    for stale in os.listdir(KB_DIR):
        if stale.endswith(".md") and stale not in keep:
            try:
                os.unlink(os.path.join(KB_DIR, stale))
            except OSError:
                pass

    index = {"generated": iso(datetime.now(timezone.utc).timestamp()),
             "docs": docs}
    # per-PID tmp — never share a tmp across processes (see sessions-feed.py)
    tmp = os.path.join(KB_DIR, "index.json.%d.tmp" % os.getpid())
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(index, f, indent=1)
    os.replace(tmp, os.path.join(KB_DIR, "index.json"))
    print("kb-feed: %d docs -> %s" % (len(docs), KB_DIR))


if __name__ == "__main__":
    main()
