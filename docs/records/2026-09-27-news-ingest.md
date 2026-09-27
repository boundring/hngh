# 2026-09-27 -- news ingest + newspaper composer (broadsheet data layer)

Status: shipped | Owner: automation lane | Tests: test-news-ingest.py,
test-newspaper-compose.py (hermetic, no network), test-cadence-collapse.sh
table rows for both beats.

## What and why

The WebGL broadsheet front page needs a local data pipeline: external
wire coverage plus in-house signals composed into one committed JSON
page (`automation/dashboard/newspaper.json`) that the dashboard serves
statically. Two cadence beats keep it fresh: hourly ingest (news,
weather, this-day), subhour compose (front page rebuild).

## Feeds (config/news-feeds.tsv)

TSV: feed<TAB>category<TAB>url<TAB>enabled<TAB>weight. '#' comments own
line only (parser enforces). 14 enabled feeds, all verified live on
2026-09-27 (BBC world/politics/business/sport/technology, Phoronix,
HN frontpage, arXiv cs.AI, Quanta, NASA, IEEE Spectrum robotics,
Defense News, Rock Paper Shotgun, LWN). Flagships weight 0.7:
bbc-world, phoronix-linux; all others 0.5. Dropped candidates:
feeds.bbci.co.uk/news/sport/rss.xml (404 -- live path is
/sport/rss.xml). arXiv publishes on weekdays only (skipDays): the feed
itself is live, zero items on weekends is expected, not an outage.

## news-ingest.py

Stdlib only. RSS 2.0 + Atom via xml.etree (namespace-agnostic).
Conditional GET: etag/last-modified persisted per feed in fetch_state,
If-None-Match/If-Modified-Sent on refetch, 304 skips parsing. Per-feed
cap 50 (newest first), dedup by sha256(link)[:8] primary key so shared
links across feeds count once. Per-feed fail-closed (one dead feed
never blocks the rest), script exits 0 always -- the beat files the
progress row, exit codes are not the failure channel. DB lives in the
hngh userspace home: db_dir()/hngh-news.db (two-home split honored;
HNGH_HOME_DIR seams everything in tests). Seams: --config --db
--source-dir --limit. UA 'hngh-automation/0.1', timeout 30s.

## weather-ingest.py + this-day-ingest.py

Weather: open-meteo current conditions, no API key. Coordinates from
cadence-params.tsv rows weather-lat/weather-lon (40.71 / -74.01, NYC
approximation), env HNGH_WEATHER_LAT/LON override. Cache 1h into
db_dir()/weather-state.json (HNGH_WEATHER_STATE seam), fail-open:
fetch failure with no cache prints a note and exits 0 with no state
file (composer treats that as weather=null). Output JSON:
{temp_c, summary, source:"open-meteo", fetched}.

This-day: Wikipedia onthisday REST
(api.wikimedia.org/feed/v1/wikipedia/en/selected/MM/DD, UTC date),
top 3 selected events. Chose a per-day state file
(db_dir()/onthisday.json keyed by day) over a db table: one row per
day, no queries, the whole file is the cache -- a db would add schema
for no gain. Fail-open like weather.

## newspaper-compose.py

Local-only rebuild of newspaper.json (default output beside the
dashboard static root; --out/--dashboard/--home-db/--db seams).
Schema exactly: {generated, edition{date, number, slot, weather,
system{queue_depth, sessions_active, fleet[{name,online,os}]}},
queues, articles[], editions[]}. Article: id (sha256(link or
title)[:8], stable across runs), category, headline, deck, body[],
span, score, ts, sources[], choices[]. Operator decision cards carry
choices with endpoint literals /operator-item/handle and
/operator-item/dismiss and payload ids that are the real
operator-item ids (view tests grep the literals;
dashboard-server.py owns the routes).

Scoring: news = feed weight * exp(-age_h/36), +0.05 boost when the
category has queued plan work (cap 1.0). Fixed: operator 0.95 (the
decision floor), sessions 0.60, this-day 0.55, research 0.40. span:
score >0.85 -> 3, >0.6 -> 2, else 1; at most ONE span-3 per edition
(highest score; with current fixed scores only operator cards can
reach 3). edition.number = past-edition count + 1; slot = UTC
hour//8 (three editions/day).

Edition policy: db items newer than 72h form today's page; older
items are grouped by UTC date into past editions -- the 7 most
recent dates, 40 articles capped per date, spans forced to 1 (past
editions never lead). queues = readout plan statuses by count + one
entry per category present on today's page; queue_depth counts
status=="queued" rows; sessions_active mirrors sessions.json.
Never fabricates: a missing input is a stderr note plus a skip
(weather -> null, this-day -> column absent, fleet -> [], sessions ->
0), and the page still publishes. Only hard errors (unwritable
output) exit non-zero; the beat reports them but always exits 0.

## Beats

cadence/hour/35-news-ingest.sh: runs news, weather and this-day
ingests (this is the only network-touching leg), files one
report-queue progress row (identity news-ingest, window 86400) and a
breadcrumb; exit 0 always.
cadence/subhour/25-newspaper-compose.sh: best-effort fleet snapshot
refresh (scripts/fleet-manager --json -> dashboard/fleet.json,
fail-soft) then newspaper-compose.py; progress row identity
newspaper-compose; exit 0 always. Both beats follow the typesafe beat
shape (lib/common.sh + breadcrumbs.sh) and are registered in
test-cadence-collapse.sh (subhour 1m, hour 60m).

## Tests + verification

test-news-ingest.py: fixture RSS/Atom parse, dedup across feeds, 50
cap, dead feed fail-closed, conditional-get state rows; subprocess
with sandboxed HNGH_HOME_DIR, no network. test-newspaper-compose.py:
fixture db + fixture dashboard feeds; exact schema key sets, one
span-3 cap, score-desc order, operator choices (literal endpoints,
real ids), queue counts, editions grouping (7 dates, 40 cap,
numbering), fail-open on missing inputs, sample fixture
tests/fixtures/newspaper.sample.json parses with the same top-level
keys. Both suites green locally; live run 2026-09-27: 14/14 feeds ok,
371 items, composed page 397 articles / 7 editions with live weather.

## Home split

News db + weather/this-day caches live under the hngh userspace home
(~/.hngh/db via lib/hngh_home.py db_dir(), HNGH_HOME_DIR overridable);
the composed newspaper.json and its fleet snapshot live in the repo's
automation/dashboard/ (served statically). Nothing writes outside
those two homes.
