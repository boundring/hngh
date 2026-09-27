#!/usr/bin/env python3
"""this-day-ingest -- Wikipedia on-this-day events for the broadsheet lane.

Cache call: ONE state file (env HNGH_THISDAY_STATE, default
~/.hngh/db/onthisday.json) holding the latest day's selected events. If
its day equals today (UTC) we exit 0 without touching the network; an
older day is refetched and overwritten. Fetch/parse failure keeps ANY
existing cache (even a stale day) and exits 0; with no cache nothing is
written. Every operational path exits 0.
"""
import argparse
import datetime
import json
import os
import sys
import urllib.request

AUTOMATION_LIB = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                              "..", "lib")
sys.path.insert(0, AUTOMATION_LIB)

from hngh_home import db_dir  # noqa: E402

UA = {"User-Agent": "hngh-automation/0.1 (this-day-ingest)"}
MAX_EVENTS = 3


def fetch_json(url):
    """Parsed JSON body, or None on any failure."""
    try:
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8", "replace"))
    except (OSError, ValueError):
        return None


def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ")


def utc_today():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")


def pick_events(data):
    """First 3 selected entries as contract rows; [] when unusable."""
    events = []
    for entry in (data or {}).get("selected") or []:
        try:
            page = (entry.get("pages") or [{}])[0]
            url = (((page.get("content_urls") or {})
                    .get("desktop") or {}).get("page")) or ""
            events.append({"year": int(entry["year"]),
                           "text": str(entry["text"]),
                           "url": url})
        except (KeyError, TypeError, ValueError, IndexError):
            continue
        if len(events) == MAX_EVENTS:
            break
    return events


def read_cache(path):
    """Cached contract JSON, or None."""
    try:
        with open(path, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


def write_state(path, state):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(state, fh, sort_keys=True)
        fh.write("\n")
    os.replace(tmp, path)


def main(argv=None):
    ap = argparse.ArgumentParser(description="cache Wikipedia on-this-day events")
    ap.add_argument(
        "--state",
        default=os.environ.get("HNGH_THISDAY_STATE")
        or os.path.join(db_dir(), "onthisday.json"))
    args = ap.parse_args(argv)

    today = utc_today()
    cached = read_cache(args.state)
    if cached and cached.get("day") == today:
        print("this-day cached for %s: %d events"
              % (today, len(cached.get("events") or [])))
        return 0

    mm, dd = today[5:7], today[8:10]
    url = ("https://api.wikimedia.org/feed/v1/wikipedia/en/"
           "onthisday/selected/%s/%s" % (mm, dd))
    events = pick_events(fetch_json(url))
    state = None
    if events:
        state = {"day": today, "events": events, "fetched": now_iso()}
        try:
            write_state(args.state, state)
        except OSError:
            state = None
    if state is not None:
        print("this-day %s: %s" % (today, "; ".join(
            "%s %s" % (e["year"], e["text"].split(".")[0]) for e in events)))
        return 0

    if cached:
        print("this-day-ingest: fetch failed, keeping cache for %s"
              % cached.get("day"), file=sys.stderr)
        print("this-day stale: kept events for %s" % cached.get("day"))
    else:
        print("this-day-ingest: fetch failed, no cache", file=sys.stderr)
        print("this-day unavailable")
    return 0


if __name__ == "__main__":
    sys.exit(main())
