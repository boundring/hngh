# 2026-09-22 — crumbs DB schema contracts (db-migration slices A + B)

Plan: docs/project/plans/2026-09-22-crumbs-db-schema-contracts.plan.md
(brief: docs/agent-notes/briefs/2026-09-22-database-migration-investigation.md,
commit 02dd4be5 — recommendation 1 [schema-first gate tests] plus the first
step of recommendation 2 [first Tier-2 journal migration, STATE.md crumbs]).
Governing-process framing: these contracts are the codified rules the
kernel+automation federation enforces on its own journals — schema as
constitutional constraint, not convention.

## What landed

### Slice A — research TSV schema-contract gate test

- `automation/tests/test-research-schema.py`: grammar tests feed hermetic
  tmpdir TSVs through the REAL parser (`jobs/research-routes.py`
  `_read_tsv`, importlib-loaded with the established
  `tests/test-routes-view.py` pattern) — header drift raises, rows below
  `min_fields` raise, over-wide rows raise, `pad_to` fills legacy
  3-5-field disposition rows to the 9-col writer schema, `#` comment and
  blank lines are skipped, missing file returns `[]` (fail-soft reader
  contract). Live contracts parse the actual repo data through the same
  parser: line rows with known status vocabulary (STATUS_FAMILIES),
  disposition rows accepted under the 9-col header + pad shim, active
  lesson ids > 0, live lessons header equal to LESSONS_HEADER exactly.
  Exact counts are never asserted — the research beat appends hourly.
- Registered in `automation/Makefile` immediately after the
  `research-tsv-path-sweep.py --check` line (research block).

### Slice B — STATE.md crumbs sqlite mirror

- `automation/lib/crumbs-db.py`: stdlib-only sqlite3 mirror of the
  STATE.md crumb journal. `sync` reads complete newline-terminated lines
  past a byte-offset watermark (`crumbs_meta.state_byte_offset`; absent
  = 0 = full backfill), imports 4-field crumbs whose timestamp matches
  the strict Z format, counts non-crumb spill lines in
  `crumbs_meta.skipped_total`, all in one transaction (the watermark
  advances only with the commit). WAL journal mode, additive-only DDL
  (`crumbs`, `crumbs_meta`, `idx_crumbs_event`). Any exception exits 0
  silently — the fail-open telemetry.py contract, so the mirror can
  never fail a tick. `--verify` prints row count / watermark /
  skipped_total for smoke checks; not wired anywhere.
- `automation/cadence/1m/15-crumbs-sync.sh`: 1m-tier drop-in (dir-based
  mounting per cadence/README.md — drop the file, the runner picks it up
  next tick; no systemd edit). Read-only with respect to STATE.md, so
  operator-items-feed and patrol readers are unaffected.
- `automation/tests/test-crumbs-db.py`: hermetic subprocess tests
  (tmp STATE.md + tmp db via CLI flags) — import + idempotent second
  sync, append imports exactly one more, mid-file spill lines skipped
  and counted, bad-timestamp rows skipped, trailing partial line waits
  for completion, and `PRAGMA table_info(crumbs)` == [ts, job, event,
  detail] in order (the additive-only anchor: future columns append,
  never mutate).
- Also registered the orphaned
  `automation/tests/test-breadcrumb-single-line.py` (written 2026-09-20,
  never registered — gate gap found during this session), beside the new
  test block immediately before the final lint-identifiers line.

## Why mirror-first

The crumbs DB is a derived index synced fail-open from the append-only
STATE.md journal — NOT the source of truth. Writers (breadcrumbs.sh plus
the python writers) and readers (grep-based) stay untouched, so the hot
path carries zero regression risk. A later slice flips readers or
writers only after a consumer proves the store. The schema value lands
immediately: a table with vocabulary-typed fields, enforced at sync
time.

## Ceiling note (ponytail)

The byte-offset watermark assumes the documented append-only invariant
of STATE.md (automation/Makefile smoke comment). If STATE.md is ever
rewritten, this sync is retired with the writer-flip slice that causes
it.

## Skip decisions (recorded, not silent)

- Disposition action vocabulary: the live gate deliberately does NOT
  assert disposition actions against ROUTE_ACTIONS (adopted/parked/
  killed) — one legacy row carries action='fixed', and vocabulary
  enforcement belongs to the disposition writer, not the reader gate.
- reports.md grammar: no schema-contract gate for the report queue.
  reports.md is freeform prose (markdown reports), not a structured TSV
  — there is no writer header to drift against, and a grammar gate
  would pin prose shape for no read-side consumer.

## Verification

- Slice A: `python3 -B tests/test-research-schema.py` OK (9 tests) from
  automation/; live shape at gate time 245 line rows / 273 dispositions
  / 105 active lessons (baselines, not assertions); full `make test`
  green.
- Slice B: `python3 -B tests/test-crumbs-db.py` OK (6 tests); real
  backfill imported 141,074 rows (STATE.md at 141,169 lines; the 95
  legacy spill lines land in skipped_total — 141,074 + 95 = 141,169,
  every line accounted). Second run imported only the 3 lines the 1m
  cadence appended in between; third run imported 0 — idempotent on the
  live journal. `bash cadence/1m/15-crumbs-sync.sh` exit 0 with counts
  unchanged, and the 1m runner picked up the drop-in within a tick
  (tier-launch rows visible in the mirror itself). Full `make test`
  green (slice B rides the same gate as the LAYERS registration for
  `crumbs-db.py` in tests/test-lib-dependencies.py).