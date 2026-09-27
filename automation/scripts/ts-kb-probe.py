#!/usr/bin/env python3
"""ts-kb-probe -- query the local Typesafe knowledge graph (slice 3).

Playbook:
  ts-kb-probe.py                         stats: nodes/edges/db path
  ts-kb-probe.py --query "fan-out"       FTS5 recall: top pages + snippets
  ts-kb-probe.py --related <url-part>    1-hop neighbors via edges
  ts-kb-probe.py --live                  one typed Jev Noul call through
                                         lib/typesafe.py (fail-closed:
                                         without TYPESAFE_API_KEY prints
                                         'live: unavailable' and exits 0)

Consumers embed the DB directly: sqlite3 hngh-knowledge.db with
`SELECT url, title FROM nodes_fts JOIN nodes ON nodes.id = rowid
WHERE nodes_fts MATCH ?` for lexical recall, or the edges table for
graph walks. See docs/design/ts-kb-playbook.md.
"""
import argparse
import os
import sqlite3
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "lib"))


def open_db():
    from hngh_home import db_dir
    path = os.environ.get("HNGH_KNOWLEDGE_DB") or os.path.join(
        db_dir(), "hngh-knowledge.db")
    if not os.path.isfile(path):
        sys.stderr.write("ts-kb-probe: no knowledge db at %s "
                         "(run typesafe-docs-ingest.py first)\n" % path)
        sys.exit(2)
    return sqlite3.connect(path)


def stats(conn):
    nodes = conn.execute("SELECT COUNT(*) FROM nodes").fetchone()[0]
    edges = conn.execute("SELECT COUNT(*) FROM edges").fetchone()[0]
    stale = conn.execute(
        "SELECT COUNT(*) FROM nodes WHERE fetched < date('now', '-8 days')"
    ).fetchone()[0]
    print("nodes=%d edges=%d stale(>8d)=%d" % (nodes, edges, stale))


def query(conn, q):
    rows = conn.execute(
        "SELECT nodes.url, nodes.title, "
        "snippet(nodes_fts, 2, '[', ']', '…', 12) "
        "FROM nodes_fts JOIN nodes ON nodes.id = nodes_fts.rowid "
        "WHERE nodes_fts MATCH ? ORDER BY rank LIMIT 3", (q,)).fetchall()
    if not rows:
        print("no matches for %r" % q)
        return
    for url, title, snip in rows:
        print("- %s\n  %s\n  %s" % (title, url, snip.replace("\n", " ")))


def related(conn, part):
    hit = conn.execute(
        "SELECT id, url FROM nodes WHERE url LIKE ? LIMIT 1",
        ("%" + part + "%",)).fetchone()
    if not hit:
        print("no node matching %r" % part)
        return
    nid, url = hit
    for direction, sql in (("->", "SELECT d.url, d.title FROM edges e "
                            "JOIN nodes d ON d.id = e.dst WHERE e.src=?"),
                           ("<-", "SELECT s.url, s.title FROM edges e "
                            "JOIN nodes s ON s.id = e.src WHERE e.dst=?")):
        for u, t in conn.execute(sql, (nid,)).fetchall():
            print("%s %s %s (%s)" % (url, direction, t, u))


def live():
    sys.path.insert(0, os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "..", "lib"))
    try:
        from typesafe import ask_noul
    except Exception:
        print("live: unavailable (typesafe wrapper import failed)")
        return
    v = ask_noul(
        "Local Typesafe knowledge base: 100+ doc pages in "
        "hngh-knowledge.db, weekly refresh drop-in installed.",
        "ts-kb-probe-kb-present",
        "Answer yes only if the described local knowledge base is "
        "sufficient context for advising typed Jev calls.")
    if v is None:
        print("live: unavailable (fail-closed: no key or call failed)")
    else:
        print("live: noul=%.2f" % v)


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--query")
    ap.add_argument("--related")
    ap.add_argument("--live", action="store_true")
    args = ap.parse_args(argv)
    if args.live:
        live()
    if not (args.query or args.related or args.live):
        conn = open_db()
        stats(conn)
        conn.close()
        return 0
    conn = open_db()
    if args.query:
        query(conn, args.query)
    if args.related:
        related(conn, args.related)
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
