# 2026-09-12 -- GDELT as a hngh news source family

Operator directive: the morning paper's first edition should carry broad
variety of world news (good and bad) with continual priority optimization
on story selection. GDELT 2.0 was named as the new source family.

## What landed

- `automation/jobs/gdelt-news.py` -- stdlib-only lane (urllib + zipfile +
  csv): fetches `lastupdate.txt`, downloads the newest 15-minute export
  window (falling back 15/30 minutes; GDELT rotates aggressively and the
  index can serve stale URLs), filters it through the editorial lens,
  ranks by the priority formula, and appends a Deck-A-shaped block to
  `digest/<date>.md`. Every item cites its SOURCEURL, so summaries link
  real articles (the low-level particulars the operator asked for).
- `automation/cadence/hour/40-gdelt-news.sh` -- hour-tier cadence drop-in
  (cadence-tick scans the tier dir, so this file IS the registration).
  Hour tier chosen over 30m: the export window is 15 minutes and the
  digest is hourly; 30m would double block count without adding a new
  window class. NOT added to SOURCES: fetch_rss normalization cannot
  unzip a CSV archive, and a dedicated script keeps the lens+ranking in
  one place. GKG is not fetched at runtime (deferred, see below).
- `automation/tests/test-gdelt-news.py` -- hermetic (fixture zip,
  refused-localhost lastupdate), wired into `make test`.

## Editorial lens (hngh's own, documented per the directive)

Two lanes, tone-balanced by construction:

- **world lane** (bad news): CAMEO QuadClass 3 (verbal conflict) or 4
  (material conflict), or GoldsteinScale <= -5 regardless of class.
  Covers CAMEO roots 10-20 (demand/disapprove/reject/threaten/protest/
  reduce-relations/coerce/assault/fight/mass violence).
- **good lane**: CAMEO EventRootCode 05 (diplomatic cooperation),
  06 (material cooperation), 07 (provide aid: economic/military/
  humanitarian/peacekeeping/asylum), 08 (yield: sanctions eased,
  leadership acceded, releases, ceasefires) with AvgTone > 0. The
  operator suggested 062-064 / 081-084; reading the CAMEO manual showed
  the honest cooperative set is the whole roots 05/06/07/08 family, so
  the lane uses roots, not the two sub-code ranges.

Score bands carry the honest severity label (CRITICAL/NOTABLE/CONTEXT
map straight onto the existing Deck A tags):

    world: score = NumSources * (|GoldsteinScale| + 2)
           CRITICAL >= 60, NOTABLE >= 20, else CONTEXT
    good:  score = NumSources * (AvgTone + 5)
           NOTABLE >= 15, else CONTEXT; good news is CAPPED at NOTABLE
           so positive tone can never read as an emergency

Recency: within one 15-minute window every row is equally fresh, so the
recency term is a no-op today; it becomes exp(-age_hours/6) when the
lane later ranks across multiple windows. One CRITICAL lead per block;
up to 4 world + 2 good items per block; SOURCEURL dedup within window
and across runs (state/gdelt-seen.tsv, 24h window).

## Codebook citations

- GDELT-Data_Format_Codebook.pdf (2.0 export): 61 tab-separated fields;
  EventRootCode #28, EventBaseCode #27, QuadClass #29, GoldsteinScale
  #30, NumSources #32, AvgTone #34, SOURCEURL #60. Verified live against
  window 2026-09-12T040000 (751 rows, 61 fields).
- CAMEO.Manual.1.1b3.pdf: roots 01-20 (05 diplomatic cooperation,
  06 material cooperation, 07 PROVIDE AID with 073 humanitarian aid,
  08 YIELD with 0871 ceasefire), QuadClass 1-4.
- GKG codebook (deferred at runtime; probed live once for structure:
  27 fields, Themes are `;`-separated, DocumentIdentifier #4 joins
  SOURCEURL at 750/751 in the probe window).

## Live samples (window 0515 UTC, first edition run)

    CONTEXT: FIGHT SRI LANKA: No Fuel Price Increase Ceylon Petroleum
    Corporation (https://srilankamirror.com/news/no-fuel-price-increase-ceylon-petroleum-corporation/)
    NOTABLE: DIPLOMATIC-COOPERATION BANK: Article71459131
    (https://www.thehindu.com/brandhub/pr-release/jk-bank-secures-best-bank-award-for-digital-transformation/article71459131.ece)
    CONTEXT: FIGHT UNITED STATES: Pzpg S12
    (https://www.wsws.org/en/articles/2026/09/12/pzpg-s12.html)

Known caveat (documented, not hidden): CAMEO codes are lead-derived --
metaphorical "fights" (sport sweeps, weather) can land in the world
lane. The band reflects the code, not our judgment; the model digest
blocks upstream remain the editorial filter for fine severity.

## Deferred deeper features (the "reconstruction from ngrams" tier)

- GKG theme timelines: hour-over-hour theme frequency deltas as a trend
  deck block (e.g. TECHNOLOGY / WB_* theme surges).
- GKG V2Counts/persons/orgs enrichment of ranked items.
- Multi-window rolling aggregation (last N exports) so NumSources
  accumulates across 15-minute windows and the recency term activates.
- CAMEO base-code (27) granularity: 190/190 for armed conflict vs
  080/087 for de-escalation headlines.
- Queued as research subject `gdelt-gkg-trends` in
  automation/research-subjects.txt.
