# 2026-09-17 ledger boundary normalization (stored raw rows)

## Trigger

Census found 319 committed `docs/project/reports.md` table rows (all
kind=progress) still carrying raw `~/...` paths, newest
2026-09-17T02:21:39Z, plus 327 body files under
`docs/project/report-bodies/` with raw path text (324 progress,
3 alert). The certified sink guard widening 79eb4733 (`hngh: candidate
ebd74640...`) commits the progress-class redaction, which appeared to
contradict the stored rows.

## Mechanism (timing, not a bypass)

79eb4733 is dated `2026-09-16 22:31:20 -0400` = **2026-09-17T02:31:20Z**
UTC. The raw rows landed 02:03:44Z-02:21:39Z, i.e. BEFORE the widening
commit; tilde-form rows start 02:50:01Z, after it. The runtime sink at
`79eb4733^` (827df7d9) wrote progress rows with
`redact_text=(kind == "alert")`, so the writer itself emitted raw
progress text until the widening landed. Single-sink audit: every
production writer calls `scripts/report-queue --add` (router-tick via
`HNGH_REPORT_QUEUE`, research-beat `REPORT=...`, causes/failfirst/
model-demote/news-screen/notify-email); only sandboxed tests open
`reports.md` directly. No stale checkout: cadence `KERNEL` resolves to
this checkout, and no second copy of the sink is referenced. The
raw alert bodies (2026-09-14 x2, 2026-09-16T20:30:28Z) predate the
alert guard's meta coverage; zero raw values exist in stored
`identity:`/`last-evidence:` body metas (guards covered metas from
2026-09-16, and `normalize_boundary` read-back matched nothing to fix).

## Disposition executed

Stored text is data, and the ledger is public-bound: applied the sink's
own `redact_boundary` (the exact idempotent rewrite the guard applies at
the argv boundary) to `docs/project/reports.md` and every raw-carrying
body file. Result: 334 files rewritten, 1012 raw boundary hits
(`/home/` + `/tmp/` families) reduced to 0 residual, table row count
preserved (3742 before/after). Mid-token matches (URL path components)
are preserved by design, mirroring the guard. Kernel `src/`, the sink
script, and tests are untouched (this commit is the docs lane; the
guard itself was already certified in 79eb4733).

## Post-state

Newest ledger rows (02:50:01Z onward through 07:00Z this morning) are
all tilde-form; the sink redacts progress at `add()` since 02:31:20Z.
No second sink exists to close. Stale-checkout theory disproven by
`automation/cadence/hour/33-research-beat.sh:152`
(`KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"`).
