# 2026-09-20 -- STATE.md writer/reader 4-field compat audit (writers-reader-compat)

## Scope

Task: check STATE.md readers vs writers consistency; verify the 4-field
breadcrumb format assumptions hold for all writers, with
`jobs/operator-items-feed.py` and the dashboard parsers named.

## The contract

`lib/breadcrumbs.sh` defines the canonical writer: one line per event,
`<ISO-ts> | <job> | <event> | <detail>`, pipes inside detail escaped to
`¦`. Readers that parse structurally:

- `jobs/operator-items-feed.py:87` -- `split(" | ", 3)`, requires
  exactly 4 parts, else skips the line (fail-closed file, prior feed
  kept on parse error).
- `jobs/patrol.py:146-160` -- `split(" | ")`, requires 4 parts.
- `jobs/beat-watchdog.py:52-62,105-124` -- substring match on
  `| overnight-done |` plus `split(" | ")[0]` for timestamps.
- `lib/common.sh:141-144` (`update_dashboard`) -- `split("|", 3)` with
  strip, last 60 crumbs into `dashboard/data.json`.
- Loose shell greps: `jobs/doc-suite-update.sh:66`,
  `cadence/hour/16-remote-push.sh:38-46` (`last_gate`),
  `jobs/oversight-tick.sh:154,389,401`, `cadence/day/17-torch-audit.sh:173`,
  `scripts/overnight-cycle.sh:81` (cold-start awk).

## Findings

1. **Readers are uniformly tolerant**: every structural reader skips
   non-4-field lines rather than crashing. No reader assumed more than
   the 4-field shape; no writer emits a different field count.
2. **Writers were the weak side.** The 2026-09-19 gate-red spill: when a
   repo's `make test` fails, `cadence/day/03-gate-check.sh` files a
   report-queue alert whose text embeds the last 10 lines of make
   output; `file_report()` (:18-25) passes that same multiline text to
   `breadcrumb()` when the report-queue append fails (`report-fail`
   path). 85 raw traceback lines landed in the live STATE.md (e.g. at
   lines 12784-12792, 56050-56061, 120227+), one spill per red gate day
   since 2026-09-09.
3. **Fix already staged (uncommitted) at the lib**:
   `lib/breadcrumbs.sh:11` folds newlines
   (`${detail//$'\n'/ }`), plus `tests/test-breadcrumb-single-line.py`
   (hermetic: sources the real lib against a temp `STATE_FILE`).
4. **Two Python writers rolled their own crumb line** and lacked the
   fold: `scripts/router-tick.py:157-166` (`breadcrumb(job, event,
   detail)`) and `jobs/service-state.py:149-159` (`breadcrumb(event,
   detail)`). Both escaped pipes but not newlines. Fixed this slice:
   `detail = " ".join(detail.split())` before the append.
5. **Direct shell writers are compliant**: `scripts/night-session.sh`
   printf-writes 4-field lines (:26,35,52) but every argument is a
   single-line scalar (path, count, rc, basename). `jobs/security-check.sh:25`
   passes a 12-line tail into `breadcrumb` but sources
   `lib/breadcrumbs.sh`, so the lib fold covers it.

## Guard test growth

`tests/test-breadcrumb-single-line.py` now also:

- execs each Python writer's `breadcrumb()` against a temp `STATE_FILE`
  with a multiline detail and asserts a single 4-field line results
  (per-writer arity: router-tick 3 args, service-state 2 args);
- asserts lib output satisfies the shared reader contract (every line
  parses to 4 ` | `-separated fields).

## Verification

- `python3 -B tests/test-breadcrumb-single-line.py` -- 6 tests OK.
- Full `make test` -- ALL PASS, identifier lint clean (2026-09-20T02:12Z).

## Not done / open

- Historical spill lines remain in the live STATE.md (append-only file;
  all readers tolerate them; no cleanup path exists by design).
- `cadence/day/03-gate-check.sh` `file_report()` still breadcrumbed the
  full multiline alert text on the report-fail path; the lib fold makes
  that safe at the boundary, so the caller was not changed (single
  enforcement point).
- Only two Python writers exist today; a future writer must either
  source the lib or uphold the fold itself (guard test pattern shows
  how to pin it).
