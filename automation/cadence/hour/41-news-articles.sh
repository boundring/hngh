#!/usr/bin/env bash
# 41-news-articles -- generated newspaper articles for the daily digest.
# The job is fail-closed (model chain down / unreadable digest = no
# article files, exit 0); the drop-in wrapper just mounts it on the hour
# tier after 40-gdelt-news so the edition's articles follow the ranked
# Deck-A blocks. Cap and quota routing live in jobs/news-articles.py.
#
# usage: cadence/hour/41-news-articles.sh  (via cadence-tick.sh TIER=hour)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
mkdir -p "$AUTOMATION_ROOT/logs"
python3 "$AUTOMATION_ROOT/jobs/news-articles.py" "$(date -u +%F)" \
  2>>"$AUTOMATION_ROOT/logs/news-articles.err" || true
exit 0
