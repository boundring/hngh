# Newspaper paid-cost conversion (2026-09-13)

Decision: the daily newspaper pipeline no longer spends paid model
calls. Trigger: operator directive 2026-09-13 after the metered ledger
showed $5.55 across 220 model calls / 5,088,023 tokens in / 585,009
tokens out over 24h (docs/dispatch/2026-09-13.md, edition no. 7).

Classification of the pipeline after conversion:

- Procedural (zero model calls): GDELT 2.0 fetch + rank + [Cat]
  category mapping (jobs/gdelt-news.py); headline generation from the
  URL slug (polish_headline is now a deterministic normalizer; the
  hourly per-headline model call through the paid chain is deleted);
  digest assembly; digest-html / digest-public / digest-local
  rendering; publication-review checklists; edition metadata + log
  writing.
- Editorial (LOCAL model only, token-capped): article drafting
  (jobs/news-articles.py). pick_pin() returns MODEL_PIN from env (test
  seam) or "local" (unsloth -> ollama); the kimi/ocgo quota rotation
  and the remote/deck paid fallbacks are unreachable from this lane.
  Token cap per session: cadence-params row newspaper-article-budget
  (default 1024; env NEWS_ARTICLES_BUDGET overrides). Cap: max 6
  articles/UTC day (newspaper-articles-cap row).

Scheduling: one edition per UTC date is built by
jobs/newspaper-edition.py, mounted as cadence/hour/
41-newspaper-edition.sh (replacing the hourly 41-news-articles.sh).
The gate builds only inside the sleep window -- cadence-params row
newspaper-sleep-window, default 01:30-06:30 LOCAL time (env
HNGH_NEWSPAPER_WINDOW overrides). Hour-tier ticks land at :00, so a
window that does not span an hourly boundary builds nothing that day.
edition.json is the idempotence marker; a failed build (bad window,
missing digest, chain down) breadcrumbs and retries on the next hour
tick until the window closes. No new daemon or timer; the change rides
the existing hngh-cadence-hour tier.

Output layout (operator userspace-home policy 2026-09-13: user data
lives in ~/.hngh, never in the repo, never committed):

    ~/.hngh/newspaper/<date>/digest.md      copy of the day's digest
    ~/.hngh/newspaper/<date>/articles/      local-model article drafts
    ~/.hngh/newspaper/<date>/media/         story illustrations (local GPU)
    ~/.hngh/newspaper/<date>/index.html     self-contained rendered page
    ~/.hngh/newspaper/<date>/edition.json   metadata + cost telemetry

Telemetry: edition.json records model_sessions, tokens_in,
tokens_out, paid_calls (always 0 by construction) and the window; one
line per edition is appended to automation/logs/newspaper-edition.log.
Note: the local unsloth llama-server leg may omit usage fields, in
which case token counters read 0 while the session count stays honest
(verified live 2026-09-13: 1 session, tokens 0, paid_calls 0, wall
~64s for a one-article edition).

Verification: targeted suites green (tests/test-news-articles.sh,
test-newspaper-window.py, test-news-desk.py, test-gdelt-news.py,
test-external-content.py, test-digest-html.py, test-digest-local.py);
live end-to-end smoke on the real local llama-server produced a full
edition with zero paid calls. Committed separately once the shared
automation gate returns green (it was red at the time of this record
from an unrelated flaky imagegen test being fixed in parallel).
