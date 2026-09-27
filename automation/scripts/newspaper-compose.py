#!/usr/bin/env python3
"""newspaper-compose -- broadsheet front-page data layer (2026-09-27).

Rebuilds the WebGL broadsheet feed (default automation/dashboard/
newspaper.json) from the news lane + dashboard feeds:

  <home>/db/hngh-news.db      items from news-ingest.py (last 72h =
                              today's edition; older = past editions)
  <home>/db/weather-state.json weather-ingest.py cache (fail-open null)
  <home>/db/onthisday.json    this-day-ingest.py cache (fail-open skip)
  dashboard/readout.json      queue depth + plan-queue statuses
  dashboard/operator-items.json  open items -> operator decision cards
  dashboard/sessions.json     active sessions -> hngh-activity articles
  dashboard/research-routes.json  research threads -> opportunities
  dashboard/fleet.json        fleet-manager snapshot (system masthead)

Fail-open: a missing input file is a stderr note plus a skip -- the
edition still publishes with what exists. Never fabricates: an empty
category is absent, not padded. Scoring: news = feed weight (news-feeds
.tsv col 5, default 0.5) * recency decay exp(-age_h/36), +0.05 boost
when the category has queued plan work; operator decision cards are
fixed high (0.95 floor). span: score>0.85 -> 3, >0.6 -> 2, else 1, at
most ONE span-3 per edition (highest score). Local-only, exits 0 on
every expected path (the subhour beat wraps it).
"""
import argparse
import datetime
import hashlib
import json
import math
import os
import re
import sqlite3
import sys

AUTOMATION_LIB = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              "..", "lib")
AUTOMATION_ROOT = os.path.abspath(os.path.join(AUTOMATION_LIB, ".."))
sys.path.insert(0, AUTOMATION_LIB)

def _news_db_dir():
    """hngh userspace db home (two-home split; HNGH_HOME_DIR seams)."""
    from hngh_home import db_dir
    return db_dir()


DASHBOARD = os.environ.get("HNGH_DASHBOARD_DIR") or \
    os.path.join(AUTOMATION_ROOT, "dashboard")
NOW = datetime.datetime.now(datetime.timezone.utc)


def z(d):
    """datetime/str -> ISO Z string (pass through unparseable)."""
    if isinstance(d, str):
        return d
    if d.tzinfo is None:
        d = d.replace(tzinfo=datetime.timezone.utc)
    return d.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_z(s):
    """ISO-ish string -> aware UTC datetime, else None."""
    if not s:
        return None
    try:
        d = datetime.datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None
    if d.tzinfo is None:
        d = d.replace(tzinfo=datetime.timezone.utc)
    return d


def sha8(s):
    return hashlib.sha256(s.encode("utf-8", "replace")).hexdigest()[:8]


def load_json(path, note):
    """Parsed json or None (missing/corrupt = stderr note, skip)."""
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError) as exc:
        print("newspaper-compose: skip %s (%s)" % (note, exc),
              file=sys.stderr)
        return None


def feed_weights():
    """feed name -> weight from config/news-feeds.tsv (default 0.5)."""
    weights = {}
    path = os.path.join(AUTOMATION_ROOT, "config", "news-feeds.tsv")
    try:
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                if line.startswith("#") or not line.strip():
                    continue
                cols = line.rstrip("\n").split("\t")
                if len(cols) >= 5:
                    try:
                        weights[cols[0]] = float(cols[4])
                    except ValueError:
                        pass
    except OSError as exc:
        print("newspaper-compose: skip news-feeds.tsv (%s)" % exc,
              file=sys.stderr)
    return weights


def sentences(text, limit=2):
    """First <=limit sentences of text (deck builder, no fabrication)."""
    text = re.sub(r"\s+", " ", (text or "").strip())
    if not text:
        return ""
    parts = re.split(r"(?<=[.!?])\s+", text)
    return " ".join(parts[:limit])


def paragraphs(text):
    """Summary -> body paragraphs (blank-line split, else one para)."""
    text = (text or "").strip()
    if not text:
        return []
    paras = [p.strip() for p in re.split(r"\n\s*\n", text) if p.strip()]
    return paras or [text]


def score_age(ts):
    """Age in hours of an ISO ts (inf when unparseable)."""
    d = parse_z(ts)
    if d is None:
        return float("inf")
    return max(0.0, (NOW - d).total_seconds() / 3600.0)


def news_article(row, weights, queues):
    """hngh-news.db row -> broadsheet article (score/span rules)."""
    age_h = score_age(row["published"] or row["fetched"])
    weight = weights.get(row["feed"], 0.5)
    score = weight * math.exp(-age_h / 36.0)
    if queues.get(row["category"], 0) > 0:
        score = min(1.0, score + 0.05)
    summary = (row["summary"] or "").strip()
    return {
        "id": sha8(row["link"] or row["title"]),
        "category": row["category"],
        "headline": row["title"] or "(untitled)",
        "deck": sentences(summary),
        "body": paragraphs(summary),
        "span": 1,
        "score": round(score, 4),
        "ts": z(parse_z(row["published"] or row["fetched"]) or NOW),
        "sources": [{"label": row["feed"], "url": row["link"]}],
        "choices": [],
    }


def db_articles(db_path, weights, queues, fresh_h=72.0):
    """(today's news articles, past-edition date groups) from the db."""
    today, editions = [], []
    try:
        conn = sqlite3.connect(db_path)
        conn.row_factory = sqlite3.Row
        rows = conn.execute(
            "SELECT feed, category, title, link, summary, published,"
            " fetched FROM items").fetchall()
        conn.close()
    except sqlite3.Error as exc:
        print("newspaper-compose: skip news db (%s)" % exc, file=sys.stderr)
        return today, editions
    past = {}
    for row in rows:
        art = news_article(row, weights, queues)
        ts = parse_z(row["published"] or row["fetched"])
        if ts is not None and score_age(row["published"] or
                                        row["fetched"]) > fresh_h:
            past.setdefault(ts.strftime("%Y-%m-%d"), []).append(art)
        else:
            today.append(art)
    for date in sorted(past, reverse=True)[:7]:
        arts = past[date][:40]
        for art in arts:
            art["span"] = 1  # editions never lead
        editions.append({"date": date, "articles": arts})
    return today, editions


def base_article(kind, category, headline, deck, body, ts, score, sources):
    return {
        "id": sha8("%s/%s" % (kind, headline)),
        "category": category,
        "headline": headline,
        "deck": sentences(deck, 3),
        "body": body,
        "span": 1,
        "score": score,
        "ts": ts,
        "sources": sources,
        "choices": [],
    }


def operator_articles(op, queues):
    """Open operator items -> decision cards (choices carry the real
    operator-item ids; endpoint literals are view-tested, do not edit)."""
    arts = []
    items = op.get("items") if isinstance(op, dict) else None
    for it in items or []:
        if it.get("status") not in (None, "", "open"):
            continue
        text = (it.get("text") or "").strip()
        art = base_article("operator-item", "operator",
                           sentences(text, 1) or "(empty item)",
                           text, paragraphs(text),
                           it.get("last_seen") or it.get("first_seen") or "",
                           0.95,
                           [{"label": "operator-items", "url": ""}])
        oid = it.get("id") or art["id"]
        art["choices"] = [
            {"label": "Handle",
             "outcome": "Marks the item handled (operator-approved.json).",
             "action": {"endpoint": "/operator-item/handle",
                        "payload": {"id": oid}}},
            {"label": "Dismiss",
             "outcome": "Moves the item to operator-dismissed.json; "
                        "it returns in the next edition if it re-fires.",
             "action": {"endpoint": "/operator-item/dismiss",
                        "payload": {"id": oid}}},
        ]
        arts.append(art)
    return arts


def session_articles(sessions):
    """sessions.json -> one hngh-activity article per active session."""
    rows = sessions.get("sessions") if isinstance(sessions, dict) else None
    arts = []
    for s in rows or []:
        mission = (s.get("mission") or "").strip() or "(no mission)"
        body = ["mission: %s" % mission,
                "state: %s" % (s.get("state") or "unknown"),
                "age: %ds" % int(s.get("age") or 0)]
        arts.append(base_article(
            "session-%s" % s.get("id"), "system",
            sentences(mission, 1), mission, body,
            sessions.get("generated") or "", 0.60,
            [{"label": "sessions", "url": ""}]))
    return arts


def research_articles(routes):
    """research-routes.json -> opportunities-category articles."""
    rows = routes.get("routes") if isinstance(routes, dict) else None
    arts = []
    for r in rows or []:
        title = (r.get("title") or "").strip() or "(untitled route)"
        term = r.get("terminus") or {}
        body = ["status: %s" % (r.get("status") or "unknown"),
                "terminus: %s %s" % (term.get("action", ""),
                                     term.get("date", ""))]
        arts.append(base_article(
            "route-%s" % r.get("id"), "opportunities",
            sentences(title, 1), title, body,
            routes.get("generated") or "", 0.40,
            [{"label": "research-routes", "url": ""}]))
    return arts


def fleet_nodes(fleet):
    """fleet-manager payload -> [{name, online, os}] (both shapes)."""
    nodes = fleet.get("nodes") if isinstance(fleet, dict) else fleet
    out = []
    for n in nodes or []:
        if isinstance(n, dict):
            out.append({"name": n.get("name") or "?",
                        "online": bool(n.get("online")),
                        "os": n.get("os") or ""})
    return out


def thisday_article(td):
    """onthisday.json -> one world-history column (absent if empty)."""
    events = td.get("events") if isinstance(td, dict) else None
    if not events:
        return None
    lines = ["%s: %s" % (e.get("year", "?"), (e.get("text") or "").strip())
             for e in events[:3]]
    day = td.get("day") or ""
    return base_article(
        "onthisday-%s" % day, "world",
        "On this day%s" % (" -- %s" % day if day else ""),
        lines[0] if lines else "", lines,
        td.get("fetched") or "", 0.55,
        [{"label": "wikipedia on this day", "url":
          "https://api.wikimedia.org/feed/v1/wikipedia/en/onthisday/"
          "selected/%s" % day[5:].replace("-", "/") if day else ""}])


def apply_spans(arts):
    """Sort desc by score, span by threshold, ONE span-3 max."""
    arts.sort(key=lambda a: a["score"], reverse=True)
    span3_left = True
    for a in arts:
        a["span"] = 3 if (a["score"] > 0.85 and span3_left) else \
            (2 if a["score"] > 0.6 else 1)
        if a["span"] == 3:
            span3_left = False
    return arts


def compose(args):
    weights = feed_weights()
    dashboard = args.dashboard or DASHBOARD
    dpath = lambda name: os.path.join(dashboard, name)  # noqa: E731

    readout = load_json(dpath("readout.json"), "readout.json") or {}
    queue_rows = readout.get("queue") or []
    queue_depth = sum(1 for q in queue_rows
                      if isinstance(q, dict) and q.get("status") == "queued")

    queues = {}
    for q in queue_rows:
        if isinstance(q, dict):
            key = q.get("status") or "unknown"
            queues[key] = queues.get(key, 0) + 1

    weather = load_json(os.path.join(args.home_db, "weather-state.json"),
                        "weather cache")
    td = load_json(os.path.join(args.home_db, "onthisday.json"),
                   "on this day cache")

    news, past_editions = db_articles(args.db, weights, queues)

    articles = operator_articles(
        load_json(dpath("operator-items.json"), "operator items") or {},
        queues)
    sess = session_articles(
        load_json(dpath("sessions.json"), "sessions") or {})
    articles += sess
    articles += research_articles(
        load_json(dpath("research-routes.json"), "research routes") or {})
    fleet = load_json(dpath("fleet.json"), "fleet") or {}
    fleet = fleet_nodes(fleet)
    td_art = thisday_article(td or {})
    if td_art:
        articles.append(td_art)
    articles += news
    # masthead histogram: plan statuses + every category on today's page
    for art in articles:
        queues[art["category"]] = queues.get(art["category"], 0) + 1
    apply_spans(articles)

    # weather fail-open: only a well-formed cache becomes the masthead
    # value; anything else composes as null (the page renders dry).
    if not (isinstance(weather, dict) and "temp_c" in weather
            and "summary" in weather):
        weather = None

    editions = [{"date": NOW.strftime("%Y-%m-%d"),
                 "number": len(past_editions) + 1,
                 "slot": NOW.hour // 8,
                 "weather": weather,
                 "system": {"queue_depth": queue_depth,
                            "sessions_active": len(sess),
                            "fleet": fleet}}]

    out = {"generated": z(NOW),
           "edition": editions[0],
           "queues": queues,
           "articles": articles,
           "editions": past_editions}
    return out


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--db",
                    default=os.path.join(_news_db_dir(), "hngh-news.db"))
    ap.add_argument("--out",
                    default=os.path.join(DASHBOARD, "newspaper.json"))
    ap.add_argument("--dashboard", default=None,
                    help="override the dashboard feeds dir (tests)")
    ap.add_argument("--home-db", default=_news_db_dir(),
                    help="override the hngh home db dir (tests)")
    args = ap.parse_args(argv)
    try:
        out = compose(args)
        tmp = args.out + ".tmp"
        os.makedirs(os.path.dirname(os.path.abspath(args.out)),
                    exist_ok=True)
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(out, fh, indent=1, sort_keys=True)
            fh.write("\n")
        os.replace(tmp, args.out)
    except (OSError, sqlite3.Error, ValueError) as exc:
        print("newspaper-compose: failed (%s)" % exc, file=sys.stderr)
        return 1  # crash only; every expected path above is exit 0
    print("newspaper composed: %d article(s), %d edition(s)"
          % (len(out["articles"]), len(out["editions"])))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
