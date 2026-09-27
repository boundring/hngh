#!/usr/bin/env python3
"""news-ingest -- external RSS/Atom ingest into hngh-news.db.

Reads the feed list from automation/config/news-feeds.tsv, fetches each
enabled feed politely (conditional GET via fetch_state validators), and
stores items deduped by sha256(link)[:8].  --source-dir replaces the
network with per-feed fixture files for hermetic tests.  Prints exactly
one summary line to stdout; diagnostics go to stderr.  A bad feed is
skipped with a note, never a crash: the script exits 0 always.
"""
import argparse
import datetime
import email.utils
import hashlib
import os
import sqlite3
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

AUTOMATION_LIB = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              "..", "lib")
sys.path.insert(0, AUTOMATION_LIB)

DEFAULT_CONFIG = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              "..", "config", "news-feeds.tsv")
UA = {"User-Agent": "hngh-automation/0.1 (news-ingest)"}
TIMEOUT = 30
FEED_CAP = 50

SCHEMA = """
CREATE TABLE IF NOT EXISTS items (
  id TEXT PRIMARY KEY,
  feed TEXT,
  category TEXT,
  title TEXT,
  link TEXT,
  summary TEXT,
  published TEXT,
  fetched TEXT
);
CREATE TABLE IF NOT EXISTS fetch_state (
  feed TEXT PRIMARY KEY,
  etag TEXT,
  last_modified TEXT,
  fetched TEXT
);
"""


def now_iso():
    """Current UTC time as ISO Z."""
    return datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ")


def load_feeds(config_path):
    """Enabled feed rows from the TSV; malformed lines fail closed.

    '#' comments are only recognised on their own lines, never inline.
    """
    feeds = {}
    with open(config_path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) != 5:
                sys.stderr.write(
                    "news-ingest: malformed config line skipped\n")
                continue
            key, category, url, enabled, weight = (p.strip() for p in parts)
            try:
                weight_f = float(weight)
            except ValueError:
                sys.stderr.write(
                    "news-ingest: bad weight for feed %s skipped\n" % key)
                continue
            if enabled != "1" or not 0.0 <= weight_f <= 1.0:
                continue
            feeds[key] = {"feed": key, "category": category, "url": url,
                          "weight": weight_f}
    return list(feeds.values())


def _localname(tag):
    """Tag without any '{namespace}' prefix."""
    return tag.rsplit("}", 1)[-1]


def _child_text(el, name):
    for sub in el:
        if _localname(sub.tag) == name:
            return (sub.text or "").strip()
    return ""


def _link(el):
    """Atom href (rel=alternate preferred) or RSS plain-text link."""
    alternate = first_href = first_text = ""
    for sub in el:
        if _localname(sub.tag) != "link":
            continue
        href = (sub.get("href") or "").strip()
        text = (sub.text or "").strip()
        if href and not first_href:
            first_href = href
        if text and not first_text:
            first_text = text
        if href and sub.get("rel") == "alternate":
            alternate = href
    return alternate or first_href or first_text


def _published(text):
    """RFC822 pubDate or Atom ISO date -> ISO Z UTC, else None."""
    text = (text or "").strip()
    if not text:
        return None
    try:
        dt = email.utils.parsedate_to_datetime(text)
    except (TypeError, ValueError):
        try:
            dt = datetime.datetime.fromisoformat(text.replace("Z", "+00:00"))
        except ValueError:
            return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=datetime.timezone.utc)
    return dt.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_feed(xml_text):
    """Namespace-agnostic RSS 2.0 + Atom -> item dicts (raises on bad XML)."""
    root = ET.fromstring(xml_text)
    items = []
    for el in root.iter():
        name = _localname(el.tag)
        if name == "item":
            items.append({
                "title": _child_text(el, "title"),
                "link": _link(el),
                "summary": _child_text(el, "description"),
                "published": _published(_child_text(el, "pubDate")),
            })
        elif name == "entry":
            items.append({
                "title": _child_text(el, "title"),
                "link": _link(el),
                "summary": (_child_text(el, "summary")
                            or _child_text(el, "content")),
                "published": _published(_child_text(el, "published")
                                        or _child_text(el, "updated")),
            })
    return items


def _item_id(link, title):
    return hashlib.sha256((link or title).encode("utf-8")).hexdigest()[:8]


def fetch(url, key, state, source_dir=None):
    """(status, text, etag, last_modified); status ok|not-modified|error.

    source_dir replaces the network: the body is the file named <key>
    under source_dir; a missing file is a dead feed.  Network mode sends
    If-None-Match / If-Modified-Since when state has validators.
    """
    if source_dir:
        try:
            with open(os.path.join(source_dir, key),
                      encoding="utf-8") as fh:
                return "ok", fh.read(), None, None
        except OSError:
            sys.stderr.write("news-ingest: feed %s: no fixture in %s\n"
                             % (key, source_dir))
            return "error", None, None, None
    headers = dict(UA)
    if state:
        if state[0]:
            headers["If-None-Match"] = state[0]
        if state[1]:
            headers["If-Modified-Since"] = state[1]
    try:
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            if not 200 <= resp.status < 300:
                sys.stderr.write("news-ingest: feed %s: HTTP %s\n"
                                 % (key, resp.status))
                return "error", None, None, None
            body = resp.read().decode("utf-8", "replace")
            return ("ok", body, resp.headers.get("ETag"),
                    resp.headers.get("Last-Modified"))
    except urllib.error.HTTPError as exc:
        if exc.code == 304:
            return "not-modified", None, None, None
        sys.stderr.write("news-ingest: feed %s: HTTP %s\n" % (key, exc.code))
    except (OSError, urllib.error.URLError, ValueError) as exc:
        sys.stderr.write("news-ingest: feed %s: %s\n" % (key, exc))
    return "error", None, None, None


def main(argv):
    ap = argparse.ArgumentParser(
        description="Ingest RSS/Atom news feeds into hngh-news.db.")
    ap.add_argument("--config", default=DEFAULT_CONFIG,
                    help="feed TSV (default automation/config/news-feeds.tsv)")
    ap.add_argument("--db", default=None,
                    help="db path (default <home>/db/hngh-news.db)")
    ap.add_argument("--source-dir", dest="source_dir", default=None,
                    help="read per-feed fixture files instead of network")
    ap.add_argument("--limit", type=int, default=FEED_CAP,
                    help="max items per feed (default 50, hard cap 50)")
    args = ap.parse_args(argv)

    from hngh_home import db_dir
    db_path = args.db or os.path.join(db_dir(), "hngh-news.db")

    feeds = load_feeds(args.config)
    conn = sqlite3.connect(db_path)
    conn.executescript(SCHEMA)

    now = now_iso()
    cap = max(0, min(args.limit, FEED_CAP))
    ok = skipped = 0
    for feed in feeds:
        key = feed["feed"]
        try:
            state = conn.execute(
                "SELECT etag, last_modified FROM fetch_state WHERE feed = ?",
                (key,)).fetchone()
            status, text, etag, last_mod = fetch(
                feed["url"], key, state, args.source_dir)
            if status == "error":
                skipped += 1
                continue
            if status == "not-modified":
                conn.execute(
                    "UPDATE fetch_state SET fetched = ? WHERE feed = ?",
                    (now, key))
                ok += 1
                continue
            for item in parse_feed(text)[:cap]:
                link = item["link"]
                conn.execute(
                    "INSERT OR REPLACE INTO items VALUES (?,?,?,?,?,?,?,?)",
                    (_item_id(link, item["title"]), key, feed["category"],
                     item["title"], link, item["summary"],
                     item["published"] or now, now))
            conn.execute(
                "INSERT OR REPLACE INTO fetch_state VALUES (?,?,?,?)",
                (key, etag, last_mod, now))
            ok += 1
        except Exception as exc:  # fail closed per feed, never crash
            sys.stderr.write("news-ingest: feed %s skipped: %s\n" % (key, exc))
            skipped += 1
    total = conn.execute("SELECT COUNT(*) FROM items").fetchone()[0]
    conn.commit()
    conn.close()
    print("news ingest: %d feed(s) ok, %d item(s), %d skipped"
          % (ok, total, skipped))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
