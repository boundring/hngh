#!/usr/bin/env python3
"""weather-ingest -- current conditions for the broadsheet news lane.

Fetches open-meteo current weather for the cadence-params lat/lon rows
(env HNGH_WEATHER_LAT / HNGH_WEATHER_LON override) and caches the result
for 1h. Cache hit: no network. Fetch/parse failure: fail-open -- a stale
state file is kept in place, nothing is created when none exists. Every
operational path exits 0.
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

UA = {"User-Agent": "hngh-automation/0.1 (weather-ingest)"}
CACHE_SECONDS = 3600
PARAMS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                           "..", "cadence-params.tsv")

# WMO weather interpretation codes -> short English summary.
WMO = {
    0: "clear", 1: "mostly clear", 2: "partly cloudy", 3: "overcast",
    45: "fog", 48: "fog", 51: "drizzle", 53: "drizzle", 55: "drizzle",
    56: "drizzle", 57: "drizzle", 61: "rain", 63: "rain", 65: "rain",
    66: "rain", 67: "rain", 71: "snow", 73: "snow", 75: "snow",
    77: "snow", 80: "rain showers", 81: "rain showers", 82: "rain showers",
    85: "snow showers", 86: "snow showers", 95: "thunderstorm",
    96: "thunderstorm", 99: "thunderstorm",
}


def fetch_json(url):
    """Parsed JSON body, or None on any failure."""
    try:
        req = urllib.request.Request(url, headers=UA)
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8", "replace"))
    except (OSError, ValueError):
        return None


def param(key):
    """Value column for a key in automation/cadence-params.tsv, or None."""
    try:
        with open(PARAMS_PATH, encoding="utf-8") as fh:
            for line in fh:
                if line.startswith("#"):
                    continue
                cols = line.rstrip("\n").split("\t")
                if cols and cols[0] == key:
                    return cols[1]
    except OSError:
        pass
    return None


def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).strftime(
        "%Y-%m-%dT%H:%M:%SZ")


def read_cache(path):
    """Contract JSON with fetched < 1h old, else None."""
    try:
        with open(path, encoding="utf-8") as fh:
            state = json.load(fh)
        when = datetime.datetime.strptime(
            state["fetched"], "%Y-%m-%dT%H:%M:%SZ").replace(
                tzinfo=datetime.timezone.utc)
        age = (datetime.datetime.now(datetime.timezone.utc) - when).total_seconds()
        if 0 <= age < CACHE_SECONDS:
            return state
    except (OSError, ValueError, KeyError, TypeError):
        pass
    return None


def write_state(path, state):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(state, fh, sort_keys=True)
        fh.write("\n")
    os.replace(tmp, path)


def main(argv=None):
    ap = argparse.ArgumentParser(description="cache current open-meteo weather")
    ap.add_argument(
        "--state",
        default=os.environ.get("HNGH_WEATHER_STATE")
        or os.path.join(db_dir(), "weather-state.json"))
    args = ap.parse_args(argv)

    cached = read_cache(args.state)
    if cached is not None:
        print("weather cached: %s, %s C" % (cached["summary"], cached["temp_c"]))
        return 0

    lat = os.environ.get("HNGH_WEATHER_LAT") or param("weather-lat")
    lon = os.environ.get("HNGH_WEATHER_LON") or param("weather-lon")
    if not lat or not lon:
        print("weather-ingest: no weather-lat/weather-lon row",
              file=sys.stderr)
        print("weather unavailable")
        return 0

    url = ("https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s"
           "&current=temperature_2m,weather_code" % (lat, lon))
    current = (fetch_json(url) or {}).get("current") or {}
    state = None
    try:
        state = {
            "temp_c": float(current["temperature_2m"]),
            "summary": WMO.get(int(current["weather_code"]), "weather"),
            "source": "open-meteo",
            "fetched": now_iso(),
        }
    except (KeyError, TypeError, ValueError):
        pass
    if state is not None:
        try:
            write_state(args.state, state)
        except OSError:
            state = None
    if state is not None:
        print("weather: %s, %s C (open-meteo)"
              % (state["summary"], state["temp_c"]))
        return 0

    if os.path.exists(args.state):
        print("weather-ingest: fetch failed, keeping stale cache",
              file=sys.stderr)
        print("weather stale: kept previous state")
    else:
        print("weather-ingest: fetch failed, no cache", file=sys.stderr)
        print("weather unavailable")
    return 0


if __name__ == "__main__":
    sys.exit(main())
