#!/usr/bin/env python3
"""gdelt-news -- GDELT 2.0 ranked world events for the daily digest.

Pulls the latest 15-minute export window (lastupdate.txt -> export zip,
previous 15-min windows as fallback since GDELT rotates fast), filters
it through hngh's editorial lens, ranks by a priority score, and appends
a digest-Deck-A-shaped block to digest/<date>.md. Per-story SOURCEURL is
the citation link, so every item cites a real article.

Editorial lens (two lanes, tone-balanced by construction):
  world lane: CAMEO QuadClass 3|4 (verbal/material conflict) or
              GoldsteinScale <= -5 -- the bad-news lane.
  good  lane: CAMEO EventRootCode 05|06|07|08 (diplomatic/material
              cooperation, provide aid, yield/de-escalation) with
              AvgTone > 0 -- the good-news lane, capped at NOTABLE so
              positive tone can never read as an emergency.
Priority score (continual priority optimization; within a single
15-minute window every row is equally fresh, so the recency term is
reserved for the deferred multi-window aggregate):
  world: score = NumSources * (|GoldsteinScale| + 2)
  good:  score = NumSources * (AvgTone + 5)
Bands: CRITICAL >= 60, NOTABLE >= 20 (good lane NOTABLE >= 15), else
CONTEXT. Dedup by SOURCEURL within the window and across runs via the
seen-state file (24h window) so the paper does not restate old items.

Sources: GDELT-Data_Format_Codebook.pdf (2.0 export: 61 fields;
EventRootCode #28, QuadClass #29, GoldsteinScale #30, NumSources #32,
AvgTone #34, SOURCEURL #60), CAMEO.Manual.1.1b3.pdf (event taxonomy).
Fail-closed: always exits 0; unreachable GDELT means no block and a
breadcrumb -- the morning paper never fails because of this lane.

usage: jobs/gdelt-news.py <YYYY-MM-DD> [--export ZIP] [--digest DIR]
           [--state PATH] [--snapshot-dir DIR]
"""
import csv
import io
import json
import os
import re
import sys
import time
import urllib.request
import zipfile
from datetime import datetime, timedelta, timezone

LASTUPDATE_URL = os.environ.get(
    "GDELT_LASTUPDATE_URL",
    "https://data.gdeltproject.org/gdeltv2/lastupdate.txt")
ROOTS = {  # CAMEO root codes (EventRootCode #28), manual table in ch. 6
    "01": "STATEMENT", "02": "APPEAL", "03": "INTENT-COOPERATE",
    "04": "CONSULT", "05": "DIPLOMATIC-COOPERATION",
    "06": "MATERIAL-COOPERATION", "07": "PROVIDE-AID", "08": "YIELD",
    "09": "INVESTIGATE", "10": "DEMAND", "11": "DISAPPROVE",
    "12": "REJECT", "13": "THREATEN", "14": "PROTEST",
    "15": "MILITARY-POSTURE", "16": "REDUCE-RELATIONS", "17": "COERCE",
    "18": "ASSAULT", "19": "FIGHT", "20": "MASS-VIOLENCE",
}
WORLD_CRITICAL, NOTABLE, GOOD_NOTABLE = 60.0, 20.0, 15.0
MAX_WORLD, MAX_GOOD = 4, 2  # items per lane per block


def _ascii(text):
    return str(text).encode("ascii", "replace").decode("ascii")


def breadcrumb(event, detail):
    state = os.environ.get("STATE_FILE", os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "STATE.md"))
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    try:
        with open(state, "a") as fh:
            fh.write("%s | gdelt-news | %s | %s\n"
                     % (ts, event, detail.replace("|", "!")))
    except OSError:
        pass


def _get(url, timeout=60):
    req = urllib.request.Request(url, headers={
        "User-Agent": os.environ.get("USER_AGENT", "Mozilla/5.0 hngh-automation/0.1")})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read()


def latest_export_zip():
    """lastupdate.txt -> latest export zip URL; on 404 step back 15/30 min
    (GDELT rotates aggressively and serves stale indexes)."""
    body = _get(LASTUPDATE_URL, timeout=30).decode("ascii", "replace")
    url = ""
    for line in body.splitlines():
        parts = line.split()
        if len(parts) >= 3 and parts[2].endswith(".export.CSV.zip"):
            url = parts[2]
    if not url:
        raise ValueError("no export zip in lastupdate index")
    stamp = re.search(r"/(\d{14})\.export\.CSV\.zip$", url)
    if not stamp:
        raise ValueError("unparsable export zip url: " + url)
    base = datetime.strptime(stamp.group(1), "%Y%m%d%H%M%S")
    for back in (0, 15, 30):  # newest-first, bounded
        ts = (base - timedelta(minutes=back)).strftime("%Y%m%d%H%M%S")
        candidate = url.replace(stamp.group(1), ts)
        try:
            return _get(candidate_https(candidate), timeout=120)
        except Exception as exc:
            breadcrumb("export-fetch", "%s failed: %s" % (ts, exc))
    raise OSError("no export window reachable within 45 minutes")


def candidate_https(url):
    # data.gdeltproject.org 301s plain http to https; go straight there.
    return url.replace("http://", "https://", 1)


def _headline(url):
    """Per-story link -> readable headline from the URL slug (the export
    carries no title field; the slug is the article's own words)."""
    tail = url.rstrip("/").split("/")[-1]
    tail = re.sub(r"\.[a-z0-9]{1,5}$", "", tail, flags=re.I)
    words = [w for w in re.split(r"[-_+]+", tail) if w]
    words = [w for w in words if not (w.isdigit() and len(w) >= 4)]
    if not words:
        words = [w for w in re.split(r"[-_+]+", tail) if w]
    return (" ".join(words).title()[:100]) or "GDELT event"


def rank_rows(raw_csv, hhmm):
    """Raw export CSV text -> ranked lane items. Skips malformed rows."""
    best = {}
    for row in csv.reader(io.StringIO(raw_csv), delimiter="\t"):
        if len(row) < 61 or not row[60].strip().startswith("http"):
            continue
        try:
            ns = int(row[32])
            gold = float(row[30])
            tone = float(row[34])
        except ValueError:
            continue
        url, root, quad = row[60].strip(), row[28].strip(), row[29].strip()
        g = _gold_or_none(row[30])
        if g is not None and (quad in ("3", "4") or g <= -5.0):
            item = {"lane": "world", "score": ns * (abs(g) + 2.0)}
        elif root in ("05", "06", "07", "08") and tone > 0.0:
            item = {"lane": "good", "score": ns * (tone + 5.0)}
        else:
            continue
        item.update(url=url, root=root, hhmm=hhmm,
                    actors="/".join(a for a in (row[6], row[16]) if a))
        prev = best.get(url)
        if prev is None or item["score"] > prev["score"]:
            best[url] = item
    return sorted(best.values(), key=lambda i: -i["score"])


def _gold_or_none(text):
    try:
        return float(text)
    except ValueError:
        return None


def band_of(item):
    if item["lane"] == "good":
        return "NOTABLE" if item["score"] >= GOOD_NOTABLE else "CONTEXT"
    if item["score"] >= WORLD_CRITICAL:
        return "CRITICAL"
    return "NOTABLE" if item["score"] >= NOTABLE else "CONTEXT"


def render_block(items, hhmm, day):
    world = [i for i in items if i["lane"] == "world"][:MAX_WORLD]
    good = [i for i in items if i["lane"] == "good"][:MAX_GOOD]
    lines = ["## %s %s" % (hhmm, day),
             "_sources: gdelt | model: gdelt-2.0 export (procedural ranking)_"]
    for rank, item in enumerate(world + good):
        tag = band_of(item)
        if rank > 0 and tag == "CRITICAL":
            tag = "NOTABLE"  # one CRITICAL lead per block
        who = item["actors"] + ": " if item["actors"] else ""
        lines.append("%s: %s %s%s (%s)" % (
            tag, ROOTS.get(item["root"], "EVENT"), who,
            _ascii(_headline(item["url"])), _ascii(item["url"])))
    return "\n".join(lines) + "\n" if len(lines) > 2 else ""


def load_seen(path, cutoff):
    """state rows 'epoch\\turl' newer than cutoff -> set of urls (prunes old)."""
    seen, keep = set(), []
    try:
        for line in open(path):
            parts = line.rstrip("\n").split("\t", 1)
            if len(parts) == 2 and float(parts[0]) >= cutoff:
                seen.add(parts[1])
                keep.append(line.rstrip("\n"))
    except (OSError, ValueError):
        pass
    return seen, keep


def record_seen(path, keep, urls, now):
    rows = keep + ["%d\t%s" % (now, u) for u in urls]
    try:
        tmp = path + ".tmp"
        with open(tmp, "w") as fh:
            fh.write("\n".join(rows[-5000:]) + "\n")
        os.replace(tmp, path)
    except OSError:
        pass


def main(argv):
    if len(argv) < 2 or not re.match(r"^\d{4}-\d{2}-\d{2}$", argv[1]):
        print("usage: gdelt-news.py <YYYY-MM-DD> [--export ZIP] "
              "[--digest DIR] [--state PATH] [--snapshot-dir DIR]",
              file=sys.stderr)
        return 2
    day = argv[1]
    args = argv[2:]
    def opt(flag, default):
        return args[args.index(flag) + 1] if flag in args else default
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    digest_dir, state = opt("--digest", os.path.join(root, "digest")), opt("--state", os.path.join(root, "state", "gdelt-seen.tsv"))
    snap_dir = opt("--snapshot-dir", os.path.join(root, "snapshots", day))
    now = time.time()
    try:
        blob = open(opt("--export", ""), "rb").read() if "--export" in args \
            else latest_export_zip()
        if not blob:
            raise OSError("empty export payload")
        zf = zipfile.ZipFile(io.BytesIO(blob))
        member = zf.namelist()[0]
        raw = zf.read(member).decode("utf-8", "replace")
        stamp = re.search(r"(\d{14})", member)
        hhmm = stamp.group(1)[8:12] if stamp else \
            datetime.now(timezone.utc).strftime("%H%M")
    except Exception as exc:
        breadcrumb("fetch-failed", "fail-closed skip: %s" % exc)
        return 0  # the paper publishes without GDELT
    items = rank_rows(raw, hhmm)
    seen, keep = load_seen(state, now - 86400)
    fresh = [i for i in items if i["url"] not in seen]
    if not fresh:
        breadcrumb("quiet", "no fresh ranked items in window %s" % hhmm)
        return 0
    world, good = 0, 0
    picked = []
    for i in fresh:
        if i["lane"] == "world" and world < MAX_WORLD:
            picked.append(i); world += 1
        elif i["lane"] == "good" and good < MAX_GOOD:
            picked.append(i); good += 1
    block = render_block(picked, hhmm, day)
    if not block.strip():
        return 0
    try:
        os.makedirs(digest_dir, exist_ok=True)
        with open(os.path.join(digest_dir, day + ".md"), "a") as fh:
            fh.write("\n" + block)
    except OSError as exc:
        breadcrumb("digest-write-failed", str(exc))
        return 0
    record_seen(state, keep, [i["url"] for i in picked], int(now))
    try:  # bounded evidence snapshot: the ranked items, not the raw zip
        os.makedirs(snap_dir, exist_ok=True)
        with open(os.path.join(snap_dir, "gdelt-%s.json" % hhmm), "w") as fh:
            json.dump({"date": day, "window": hhmm,
                       "items": picked}, fh, ensure_ascii=True)
    except OSError:
        pass
    breadcrumb("block", "window %s: %d world + %d good items"
               % (hhmm, world, good))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
