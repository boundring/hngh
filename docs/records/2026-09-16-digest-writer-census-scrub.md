# 2026-09-16 — digest mega-block writer census: every writer guarded through the one scrub seam

## The question

Deep-task node `llc-gate-mega-feed-direct-writers` (from the
`cred-llm-render-chain-leak::gate` critique): `digest-ledger.build()`
was scrubbed (2026-09-16 seam record), but the OTHER writers of
`archive/digest/<date>.md` were never enumerated. Gate-verified: the
2026-09-16 patrol findings carried a FAIL detail with a GitHub runs URL
plus journal host detail, and `patrol.py morning_report` quotes top-3
FAIL detail strings verbatim into the daily digest — which deck B, the
operator email, the LAN dashboard, and the newspaper all render
verbatim (the egress-boundary record's surfaces).

## The census (complete sweep of the automation tree)

Writers of `archive/digest/<date>.md` (the DAILY digest — every path
below ends in `<date>.md` and appends/creates the day file):

| writer | seam | free-text risk | guard status |
|---|---|---|---|
| `jobs/ping-hourly.sh:99-107` | block write (news summary) + `digest-ledger.py` append (mega line) | model summary; mega quotes | **this slice**: block now written through `lib/digest-block.sh append_news_block` (scrubs the summary); mega line already scrubbed in-builder |
| `jobs/gdelt-news.py:381-384` | block append (procedural, no model) | actors + slug-derived headline from wire data | **this slice**: every rendered line scrubbed in `render_block` |
| `jobs/patrol.py morning_report:1813-1897` | `## The rounds` append (counts + top-3 FAIL details) | FAIL details = journal/log-derived strings | **this slice**: details scrubbed (`scrub_paths`) at the writer |
| `jobs/digest-ledger.py` (via ping-hourly) | `### NEWS FROM THE MEGASTRUCTURE` block | posture crumbs, operator-item text | already scrubbed (2026-09-16 seam record; `last_plan`/`queue_next` gaps tracked in `llc-gate-scrub-site-divergence`) |

Sidecar digest files in the same directory — each a SEPARATE file, not
the daily digest; out of scope but listed so the census is honest:

- `MORNING-<date>.md` (`jobs/morning-digest.sh:43-49`) — model
  summary, standalone file.
- `REVIEW-<date>.md` (`cadence/day/04-review-prep.sh:96-99`) — model
  response, standalone file.
- `RESEARCH-<date>.md` (`jobs/night-research.sh:60-65`) — model
  summary, standalone file.
- `RESEARCH-BEAT-<date>-<id>.md` + `RESEARCH-REVIEW-...`
  (`cadence/hour/33-research-beat.sh:752-760, 843-866`) — model
  output, standalone files.
- `BENCH-<date>.md` (`jobs/model-bench.sh:90-113`) — procedural
  ranking, standalone file.
- `DRAFT-PLAN-<date>.md` (`scripts/overnight-cycle.sh:328, 399`) —
  model draft, standalone file.
- `PUBLICATION-REVIEW-<date>.md` (`jobs/publication-review.py:246`) —
  review findings, standalone file.

These sidecars feed the email-digest lanes (which redact secrets at
compose, `scripts/email-digest.py:762`) but none of them is rendered
by deck B/the newspaper; the render-chain gaps that DO involve them
are tracked by the sibling node `llc-gate-render-layer-scrub`.

The task also named `git-auto-land.py` as a direct digest writer
"identified by the egress audit". **No such file exists** — not in the
kernel repo, not in `~/Projects/etc/hngh-automation`, not anywhere in
git history, and no report-queue or digest code path references it.
The gate's own critique trace described it as a `write_body` caller of
`scripts/report-queue` (the kernel sink bypass node's subject, where it
is equally absent). If it ever existed it predates the refactor
archive. The kernel `scripts/report-queue` write-path audit is
`llc-gate-sink-alert-body-bypass`'s scope; this census treats
git-auto-land as nonexistent, not unguarded.

## Chokepoint decision: the writer, through ONE scrub

The fix lands at each WRITER, not at the readers, for two reasons:

1. Readers of `digest/<date>.md` are many and growing (deck B in
   `digest-html.py`, the email HTML part in `html-digest.py`, the
   dashboard route, `digest-local.py` dispatch copies, the newspaper
   pipeline, `night-research.sh` corpus). Scrubbing at every reader is
   N guards and any new reader leaks by default. Scrubbing at the
   writers is M (4) guards and a new reader cannot undo it.
2. The identity seam stays single: all four writers now route free
   text through the SAME `scrub_paths` definition
   (`jobs/digest-ledger.py`, `PATH_TOKEN_RE`: URLs consumed first and
   kept verbatim, home/tmp/tilde tokens fail-closed to
   `[redacted path]`).

The shell writers get `automation/lib/digest-block.sh`:
`digest_scrub`/`scrub` (one line) and `digest_scrub_all` (multi-line),
which import the ledger module's `scrub_paths` — no second regex
exists in the tree. `append_news_block` (file, HHMM, date, model,
sources, summary) writes the `## HHMM <date>` block exactly as
ping-hourly did, with the summary scrubbed per line.

## What landed

- `automation/lib/digest-block.sh` (new) — the shell writer seam:
  `scrub`, `digest_scrub_all`, `append_news_block` (sources param
  preserved; the model summary is scrubbed line-by-line).
- `automation/jobs/ping-hourly.sh` — the block write routes through
  `append_news_block`; behavior otherwise byte-identical.
- `automation/jobs/gdelt-news.py` — `render_block` scrubs every
  rendered line through `scrub_paths` imported from digest-ledger
  (fail-open to identity only if the module cannot load; URLs survive
  because the seam consumes them first).
- `automation/jobs/patrol.py` — re-exports `scrub_paths` from
  digest-ledger; `morning_report` scrubs each top-3 FAIL detail;
  `findings_md` scrubs FAIL detail lines in the findings doc too
  (the rounds read from that doc; defense in depth, the doc itself is
  not an operator surface).
- `automation/Makefile` — the new test file registered.

## Tests (red first)

- `automation/tests/test-digest-append-scrub.py` (new) — the seam:
  block shape preserved (`## HHMM <date>` + `_sources: ... | model:`
  line), a pathy model summary lands scrubbed (`/home/...` -> the
  marker, prose kept), tilde/tmp tokens die, and `scrub` output equals
  `digest_ledger.scrub_paths` output for the four token classes
  (identity-seam pin). Red before the seam existed (file absent ->
  all 4 failed); green after.
- `automation/tests/test-gdelt-news.py` — `test_block_scrubs_path_tokens`:
  a fixture GDELT row with `/home/...` and `~/...` actor codes renders
  into the block scrubbed while the story survives (asserted by URL).
  Red: the pathy actors rendered verbatim. Green after.
- `automation/tests/test-patrol.py` —
  `test_morning_rounds_redact_pathy_fail_details`: two pathy unknown
  journal errors -> morning rounds block carries `[redacted path]`,
  zero raw tokens, rounds block still present. Red: `/tmp/x.store` in
  the digest verbatim. Green after.

## Validation

- `python3 -B tests/test-digest-append-scrub.py` 4/4 OK
- `python3 -B tests/test-gdelt-news.py` 10/10 OK
- `python3 -B tests/test-patrol.py` 40/40 OK
- `python3 -B tests/test-patrol-roadmap.py` 10/10 OK
- `python3 -B tests/test-digest-html.py` 13/13 OK
- `python3 -B tests/test-digest-local.py` 2/2 OK
- `python3 -B tests/test-news-desk.py` 12/12 OK
- `python3 -B tests/test-viz-schema-patrol.py` OK;
  `test-report-queue-evidence.py` 3/3 OK;
  `test-config-backup-fail-redact.sh` ALL PASS;
  `test-oversight-tick-alert-redact.sh` ALL PASS
- `bash jobs/ping-hourly.sh` live run: exit 0, today's digest gained
  the regular gdelt block through the untouched cadence path (no
  digest-ledger window open; block byte-shape unchanged).

## What this does not cover

- The mega line's `last_plan`/`queue_next` quotes in digest-ledger
  are unscrubbed (deliberately left to `llc-gate-scrub-site-divergence`,
  which owns marker/token-family unification across ALL scrub sites).
- The sidecar digest files (MORNING/REVIEW/RESEARCH/BEAT/BENCH/
  DRAFT-PLAN/PUBLICATION-REVIEW) are written unscrubbed; their text
  reaches the operator only through lanes with their own redaction or
  through the render-chain surfaces owned by
  `llc-gate-render-layer-scrub`.
- `/Users/`, `/root/`, `//host/` path families are outside the seam's
  token family everywhere (same divergence node).
- `scripts/report-queue` evidence/identity/occurrence redaction is the
  kernel sink node's scope, not this census's.
