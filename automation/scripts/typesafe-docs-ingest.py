#!/usr/bin/env python3
"""typesafe-docs-ingest -- local Typesafe/Jev knowledge graph (slice 3).

Pulls the Typesafe docs index (llms.txt), caches every page as markdown
under <home>/db/typesafe-docs/, and builds/refreshes the local sqlite
knowledge base <home>/db/hngh-knowledge.db:

    nodes(id, url UNIQUE, title, blurb, path, fetched, content)
    edges(src, dst, kind)   -- markdown links between ingested pages
    nodes_fts               -- FTS5 over title/blurb/content

N-dimensional graph needs: nodes are pages, edges are cross-references;
FTS5 gives lexical recall, edges give the hop/walk axis. This DB stays
OUTSIDE the llm-wiki vault by design (25-wiki-health counts vault pages;
a machine-scraped corpus would poison its UNINDEXED budget).

Fail-closed: network failures skip the page and keep the previous row;
the script exits nonzero only when NOTHING could be ingested. The
weekly refresh drop-in treats any nonzero exit as a skip-and-report.

Usage:
  typesafe-docs-ingest.py [--llms URL] [--db PATH] [--cache DIR]
                          [--core-only] [--limit N] [--source-dir DIR]

  --core-only    skip /cookbooks/ pages (concepts/primitives/patterns
                 surface only)
  --limit N      cap pages ingested this run (smoke/partial refresh)
  --source-dir   hermetic mode: resolve every URL to a local file in
                 DIR by basename (tests; also works offline)
"""
import argparse
import datetime
import hashlib
import os
import re
import sqlite3
import sys
import urllib.request
from urllib.parse import urljoin

AUTOMATION_LIB = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              "..", "lib")
sys.path.insert(0, AUTOMATION_LIB)

DEFAULT_LLMS = "https://docs.typesafe.ai/llms.txt"
UA = {"User-Agent": "hngh-automation/0.1 (typesafe-docs-ingest)"}

SCHEMA = """
CREATE TABLE IF NOT EXISTS nodes (
  id INTEGER PRIMARY KEY,
  url TEXT UNIQUE NOT NULL,
  title TEXT NOT NULL,
  blurb TEXT DEFAULT '',
  path TEXT DEFAULT '',
  fetched TEXT NOT NULL,
  content TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS edges (
  src INTEGER NOT NULL REFERENCES nodes(id),
  dst INTEGER NOT NULL REFERENCES nodes(id),
  kind TEXT NOT NULL DEFAULT 'link',
  UNIQUE(src, dst, kind)
);
CREATE INDEX IF NOT EXISTS edges_src ON edges(src);
CREATE INDEX IF NOT EXISTS edges_dst ON edges(dst);
CREATE VIRTUAL TABLE IF NOT EXISTS nodes_fts USING fts5(
  title, blurb, content, content='nodes', content_rowid='id');
"""


def fetch(url, source_dir=None):
    """Page body as text, or None on any failure."""
    if source_dir:
        path = os.path.join(source_dir, url.rsplit("/", 1)[-1])
        try:
            with open(path, encoding="utf-8") as fh:
                return fh.read()
        except OSError:
            return None
    try:
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read().decode("utf-8", "replace")
    except (OSError, urllib.error.URLError, ValueError):
        return None


def parse_llms(text):
    """llms.txt entries: '- [Title](url.md): blurb'."""
    out = []
    for line in text.splitlines():
        m = re.match(r"^-\s+\[([^\]]+)\]\((\S+?)\)(?::\s*(.*))?$", line)
        if m:
            out.append((m.group(1).strip(), m.group(2),
                        (m.group(3) or "").strip()))
    return out


def slug(url):
    path = re.sub(r"^https?://", "", url)
    return re.sub(r"[^A-Za-z0-9._-]+", "__", path)


def link_targets(md_text, base_url):
    """Link targets inside a page: markdown []() plus MDX href="..."."""
    out = []
    for m in re.finditer(r"\[[^\]]*\]\((\S+?)\)", md_text):
        out.append(urljoin(base_url, m.group(1)).rstrip("#"))
    for m in re.finditer(r"href=\"([^\"]+)\"", md_text):
        out.append(urljoin(base_url, m.group(1)).rstrip("#"))
    return out


def ingest(llms_text, source_dir, cache_dir, db_path, core_only, limit):
    entries = parse_llms(llms_text)
    if core_only:
        entries = [e for e in entries if "/cookbook" not in e[1]]
    if limit:
        entries = entries[:limit]
    now = datetime.datetime.now(datetime.timezone.utc) \
        .strftime("%Y-%m-%dT%H:%M:%SZ")
    conn = sqlite3.connect(db_path)
    conn.executescript(SCHEMA)
    ok, failed = 0, 0
    for title, url, blurb in entries:
        body = fetch(url, source_dir)
        if body is None:
            failed += 1
            continue
        with open(os.path.join(cache_dir, slug(url)), "w",
                  encoding="utf-8") as fh:
            fh.write(body)
        conn.execute(
            "INSERT INTO nodes(url, title, blurb, path, fetched, content) "
            "VALUES(?,?,?,?,?,?) "
            "ON CONFLICT(url) DO UPDATE SET title=excluded.title, "
            "blurb=excluded.blurb, path=excluded.path, "
            "fetched=excluded.fetched, content=excluded.content",
            (url, title, blurb, slug(url), now, body))
        ok += 1
    # edges: links (markdown or MDX href) whose target is an ingested
    # page, resolved absolute and with the extension-less .md alias
    id_by_url = {row[0]: row[1] for row in
                 conn.execute("SELECT url, id FROM nodes")}
    for src_url in id_by_url:
        src = id_by_url[src_url]
        body = conn.execute("SELECT content FROM nodes WHERE id=?",
                            (src,)).fetchone()[0]
        src_url = [u for u, i in id_by_url.items() if i == src][0]
        for dst_url in link_targets(body, src_url):
            dst_id = id_by_url.get(dst_url) or id_by_url.get(
                dst_url + ".md")
            if dst_id:
                conn.execute(
                    "INSERT OR IGNORE INTO edges(src, dst, kind) "
                    "VALUES(?,?, 'link')", (src, dst_id))
    conn.execute("INSERT INTO nodes_fts(nodes_fts) VALUES('rebuild')")
    conn.commit()
    edges = conn.execute("SELECT COUNT(*) FROM edges").fetchone()[0]
    nodes = conn.execute("SELECT COUNT(*) FROM nodes").fetchone()[0]
    conn.close()
    return ok, failed, nodes, edges


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--llms", default=DEFAULT_LLMS)
    ap.add_argument("--db", default=None)
    ap.add_argument("--cache", default=None)
    ap.add_argument("--core-only", action="store_true")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--source-dir", default=None)
    args = ap.parse_args(argv)

    from hngh_home import catalog, db_dir
    db_path = args.db or os.path.join(db_dir(), "hngh-knowledge.db")
    cache_dir = args.cache or db_dir("typesafe-docs")
    os.makedirs(cache_dir, exist_ok=True)

    llms = fetch(args.llms, args.source_dir)
    if llms is None:
        sys.stderr.write("typesafe-docs-ingest: cannot fetch index %s\n"
                         % args.llms)
        return 1
    ok, failed, nodes, edges = ingest(
        llms, args.source_dir, cache_dir, db_path, args.core_only,
        args.limit)
    catalog("typesafe-docs-db", db_path,
            "nodes=%d edges=%d ok=%d failed=%d" % (nodes, edges, ok, failed))
    print("typesafe-docs-ingest: db=%s nodes=%d edges=%d ingested=%d "
          "failed=%d" % (db_path, nodes, edges, ok, failed))
    return 1 if (ok == 0 and failed > 0) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
