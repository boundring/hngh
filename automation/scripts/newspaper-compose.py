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
import importlib.util
import json
import math
import os
import re
import sqlite3
import subprocess
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

# page shape (hngh-internal desks lead; wire is capped; Jev-consulted
# 2026-09-27: wire_cat cap10 @0.37, wire share <=40% @0.22, system desk
# led by load @0.5; research/session caps resolved from the operator
# brief's "capped hard" since Jev confidence was noise there)
WIRE_CAT_CAP = 10
WIRE_SHARE = 2.0 / 3.0  # wire_cap = int(2/3 * hngh) -> wire <= 40% of page
SESSION_CAP = 8
RESEARCH_CAP = 6
OPERATOR_CAP = 12


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
    operator-item ids; endpoint literals are view-tested, do not edit).
    Capped at OPERATOR_CAP freshest cards plus one overflow note --
    the 2026-09-27 broadsheet review flagged a 40-card edition as the
    amplification stage of operator-items-feed's CAP=40 flood."""
    arts = []
    rows = op.get("items") if isinstance(op, dict) else None
    open_items = [it for it in rows or []
                  if it.get("status") in (None, "", "open")]
    open_items.sort(key=lambda it: (
        it.get("last_seen") or it.get("first_seen") or "",
        str(it.get("id") or "")), reverse=True)
    for it in open_items[:OPERATOR_CAP]:
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
    if len(open_items) > OPERATOR_CAP:
        fams = {}
        for it in open_items[OPERATOR_CAP:]:
            fam = (it.get("text") or "").split("|")[0].strip() \
                or "(unlabeled)"
            fams[fam] = fams.get(fam, 0) + 1
        arts.append(base_article(
            "operator-desk", "operator",
            "Operator desk: %d more open items on the console"
            % (len(open_items) - OPERATOR_CAP),
            "Open operator items beyond the front-page cap; handle or "
            "dismiss them on the console.",
            ["%s: %d" % (k, v) for k, v in
             sorted(fams.items(), key=lambda kv: (-kv[1], kv[0]))[:5]],
            z(NOW), 0.74, [{"label": "operator-items", "url": ""}]))
    return arts


def session_articles(sessions):
    """sessions.json -> one hngh-activity article per active session."""
    rows = sessions.get("sessions") if isinstance(sessions, dict) else None
    rows = sorted(rows or [], key=lambda s: (
        s.get("age") if isinstance(s.get("age"), (int, float)) else float("inf"),
        str(s.get("id") or "")))[:SESSION_CAP]
    arts = []
    for s in rows or []:
        mission = (s.get("mission") or "").strip() or "(no mission)"
        body = ["mission: %s" % mission,
                "state: %s" % (s.get("state") or "unknown"),
                "age: %ds" % int(s.get("age") or 0)]
        arts.append(base_article(
            "session-%s" % s.get("id"), "system",
            sentences(mission, 1), mission, body,
            sessions.get("generated") or "", 0.66,
            [{"label": "sessions", "url": ""}]))
    return arts


def research_articles(routes):
    """research-routes.json -> opportunities-category articles, capped
    at RESEARCH_CAP with one honest overflow note (route stubs are the
    lowest-value slot fill; the 2026-09-27 review counted 100)."""
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
    shown = arts[:RESEARCH_CAP]
    if len(arts) > RESEARCH_CAP:
        stats = {}
        for r in (rows or [])[RESEARCH_CAP:]:
            st = r.get("status") or "unknown"
            stats[st] = stats.get(st, 0) + 1
        shown.append(base_article(
            "opportunities-desk", "opportunities",
            "Opportunities desk: %d more routes on the bench"
            % (len(arts) - RESEARCH_CAP),
            "Research routes beyond the front-page cap.",
            ["%s: %d" % (k, v) for k, v in
             sorted(stats.items(), key=lambda kv: (-kv[1], kv[0]))[:5]],
            routes.get("generated") or "", 0.39,
            [{"label": "research-routes", "url": ""}]))
    return shown


def system_resources(home_db):
    """system-resources.json from the db home, refreshed when stale
    (>30 min) by a subprocess run of system-ingest.py; None = no data."""
    path = os.path.join(home_db, "system-resources.json")
    res = load_json(path, "system resources")
    if isinstance(res, dict) and parse_z(res.get("generated") or "") \
            and score_age(res["generated"]) <= 30.0:
        return res
    try:
        subprocess.run([sys.executable, "-B",
                        os.path.join(AUTOMATION_ROOT, "scripts",
                                     "system-ingest.py"),
                        "--out", path],
                       capture_output=True, timeout=60)
        res = load_json(path, "system resources")
    except (OSError, subprocess.SubprocessError):
        return None
    return res if isinstance(res, dict) else None


def system_articles(res, fleet):
    """Machine resource snapshot -> 1-3 system-desk articles (fleet
    status folds into the lead body; absent data skips silently)."""
    if not res:
        return []
    src = [{"label": "system-resources", "url": ""}]
    ts = res.get("generated") or ""
    online = sum(1 for n in fleet if n["online"])
    fl = "%d/%d fleet nodes online" % (online, len(fleet)) if fleet else ""
    arts = []
    load = res.get("load") or {}
    if load.get("load1") is not None and res.get("cpu_threads"):
        arts.append(base_article(
            "system-load", "system",
            "Load: %.2f / %.2f / %.2f on %d threads" % (
                load["load1"], load["load5"], load["load15"],
                res["cpu_threads"]),
            "Load averages over 1, 5 and 15 minutes on this machine.",
            ["load 1/5/15m: %.2f / %.2f / %.2f" % (
                load["load1"], load["load5"], load["load15"])] +
            (["fleet: %s" % fl] if fl else []),
            ts, 0.80, src))
    mem = res.get("memory") or {}
    if mem.get("total_mb"):
        used = mem["total_mb"] - mem.get("avail_mb", 0.0)
        arts.append(base_article(
            "system-memory", "system",
            "Memory: %.1f/%.0f GB used (%.0f%%)" % (
                used / 1024.0, mem["total_mb"] / 1024.0,
                mem.get("used_pct", 0.0)),
            "Memory use from /proc/meminfo.",
            ["total: %.1f GB" % (mem["total_mb"] / 1024.0),
             "available: %.1f GB" % (mem.get("avail_mb", 0.0) / 1024.0)],
            ts, 0.79, src))
    disks = res.get("disks") or []
    if disks:
        arts.append(base_article(
            "system-disks", "system",
            "Disks: %s" % ", ".join(
                "%s %.0f%%" % (os.path.basename(d["path"].rstrip("/")) or
                               d["path"], d["used_pct"]) for d in disks),
            "Disk use on the repo home and the hngh db home.",
            ["%s: %.0f%% used, %.1f GB free" % (
                d["path"], d["used_pct"], d["free_gb"]) for d in disks],
            ts, 0.78, src))
    return arts


def activity_article(crumbs_path):
    """Crumbs journal -> one honest one-hour activity digest (no crumbs
    or no rows -> absent)."""
    if not crumbs_path or not os.path.exists(crumbs_path):
        return None
    cutoff = z(NOW - datetime.timedelta(hours=1))
    try:
        conn = sqlite3.connect(crumbs_path)
        rows = conn.execute(
            "SELECT event, job FROM crumbs WHERE ts >= ?",
            (cutoff,)).fetchall()
        conn.close()
    except sqlite3.Error:
        return None
    if not rows:
        return None
    events, jobs = {}, {}
    for ev, job in rows:
        events[ev] = events.get(ev, 0) + 1
        jobs[job] = jobs.get(job, 0) + 1
    n_alert = events.get("alert", 0)
    headline = "Last hour: %d machine events%s" % (
        len(rows), ", %d alert%s" % (n_alert, "s" if n_alert != 1 else "")
        if n_alert else "")
    body = ["%s: %d" % (k, v) for k, v in
            sorted(events.items(), key=lambda kv: (-kv[1], kv[0]))[:5]]
    body += ["busiest: %s (%d)" % (j, c) for j, c in
             sorted(jobs.items(), key=lambda kv: (-kv[1], kv[0]))[:3]]
    return base_article(
        "activity-digest", "system", headline,
        "What the machine did in the last hour, from the crumbs journal.",
        body, z(NOW), 0.77, [{"label": "crumbs", "url": ""}])


def cap_news(news, total_cap):
    """Wire articles capped per category and in total (hngh-internal
    desks keep the majority of the page)."""
    by_cat = {}
    for a in news:
        by_cat.setdefault(a["category"], []).append(a)
    wire = []
    for cat in sorted(by_cat):
        wire += sorted(by_cat[cat],
                       key=lambda a: (-a["score"], a["id"]))[:WIRE_CAT_CAP]
    wire.sort(key=lambda a: (-a["score"], a["id"]))
    return wire[:total_cap]


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


def ghost_decorate(articles):
    """Ghost-counsel complete summaries on the front slots (operator
    directive 2026-09-27). Fail-open but LOUD: when the ghost lane
    produces nothing, returns a short quiet reason for the edition
    marker and files one deduped report-queue breadcrumb (script
    layer: libs may not import sibling libs)."""
    try:
        spec = importlib.util.spec_from_file_location(
            "hngh_ghost_voices",
            os.path.join(AUTOMATION_LIB, "ghost-voices.py"))
        gv = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(gv)
        got, quiet = gv.ghost_summaries(
            articles[:12],
            "%s-%d" % (NOW.strftime("%Y-%m-%d"), NOW.hour // 8))
    except Exception as exc:
        print("newspaper-compose: ghost summaries failed (%s)" % exc,
              file=sys.stderr)
        return "ghost bridge unusable (%s)" % exc
    landed = 0
    for a in articles[:12]:
        g = got.get(a["id"])
        if g:
            a["ghost"] = {"voice": g["voice"], "text": g["text"]}
            landed += 1
    if quiet and landed == 0:
        try:
            import report_queue
            report_queue.report(
                "model", "ghost desk quiet: %s" % quiet,
                identity=gv.QUIET_IDENTITY, window=gv.QUIET_WINDOW_S)
        except Exception:
            pass
    return quiet if quiet and landed == 0 else None


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

    sess_data = load_json(dpath("sessions.json"), "sessions") or {}
    articles = operator_articles(
        load_json(dpath("operator-items.json"), "operator items") or {},
        queues)
    sess = session_articles(sess_data)
    articles += sess
    articles += research_articles(
        load_json(dpath("research-routes.json"), "research routes") or {})
    fleet = load_json(dpath("fleet.json"), "fleet") or {}
    fleet = fleet_nodes(fleet)
    articles += system_articles(system_resources(args.home_db), fleet)
    dig = activity_article(os.environ.get("HNGH_CRUMBS_DB") or
                           os.path.join(AUTOMATION_ROOT, "state",
                                        "crumbs.db"))
    if dig:
        articles.append(dig)
    td_art = thisday_article(td or {})
    if td_art:
        articles.append(td_art)

    def keep(arts):
        # junk filter: empty or near-empty headlines are layout residue
        # ("FOLLOWON:"-style stubs from research-routes rows), not news
        return [a for a in arts
                if len("".join(a["headline"].split())) >= 8]

    articles = keep(articles)
    news = keep(news)
    # hngh-internal desks keep the majority: wire capped per category and
    # at <=40% of the page total
    articles += cap_news(news, int(len(articles) * WIRE_SHARE))
    # masthead histogram: plan statuses + every category on today's page
    for art in articles:
        queues[art["category"]] = queues.get(art["category"], 0) + 1
    apply_spans(articles)
    ghost_quiet = ghost_decorate(articles)

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
                            "sessions_active": len(
                                sess_data.get("sessions") or []),
                            "fleet": fleet}}]

    out = {"generated": z(NOW),
           "edition": editions[0],
           "queues": queues,
           "articles": articles,
           "editions": past_editions}
    if ghost_quiet:
        out["ghost_quiet"] = ghost_quiet
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
