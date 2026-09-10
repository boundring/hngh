# Restart resilience: durable behavioral state

Date: 2026-09-10. Scope: peer-review finding 4
(docs/research/2026-09-10-peer-standard-review.md) — behavioral state in
fixed /tmp paths resets on reboot, so the system forgot its own
degradations every boot.

## Problem

lib/failfirst.sh defaulted its state dir to `/tmp/hngh-failfirst`.
After the 2026-09-10 unplanned reboot, every fail-first ladder (per
operation speed, outcome counts, observed ceilings) came back fresh.
model-demote.tsv already had the right pattern:
`$AUTOMATION_ROOT/state/model-demote.tsv`.

## Migration

- `lib/failfirst.sh`: `FF_DIR` now defaults to
  `$AUTOMATION_ROOT/state/failfirst` (same convention as
  model-demote.sh; `FAILFIRST_STATE_DIR` override kept for tests).
  `failfirst_state_file` performs a one-shot migration: when the old
  `/tmp/hngh-failfirst/failfirst-<op>` exists and the new file does
  not, one `mv` carries it over (a mid-migration halt loses nothing).
- `cadence/day/20-model-saturation.sh`: `failfirst_summary` reads the
  same new default.
- `/tmp` retained only for lockfiles; `tmp-postcode.txt` stays where it
  is (scratch within one run chain, not cross-process state).
- `automation/.gitignore`: `state/*` with `!state/.gitkeep`; the dir is
  kept via committed `state/.gitkeep`.

## Verification

`make test` full suite green; hermetic check
`env -i HOME=$HOME PATH=/usr/bin:/bin:/usr/local/bin make test` green
(no test needs real /tmp/hngh-failfirst state — sandboxes set
`FAILFIRST_STATE_DIR`, which suppresses migration).

## Graceful shutdown (plan 19 step 7)

overnight-cycle.sh now traps SIGTERM/SIGINT: it stops spawning new
delegated sessions, writes one dated breadcrumb (`shutdown-signal`,
with the in-flight session slugs from a /tmp scratch list — the run id
only exists after a launch completes) and exits non-zero. No new state
files: the record lives in STATE.md alongside the existing breadcrumbs.

On entry (after the existing flock — extended, not duplicated) the
cycle scans STATE.md for a `shutdown-signal` newer than the last
`overnight-done`. If found, it breadcrumbs `cold-start-unclean` and
skips that beat's session batch (one tick, via the same STOP flag the
trap honors) so orphaned in-flight sessions from the killed beat are
not double-spawned; the beat still exits cleanly with `overnight-done`,
which restores the ordering and the next tick runs normally.

What survives a halt now: failfirst ladders and model-demote counters
(durable state/, section above), the shutdown breadcrumb, the ledger
rows sessions already wrote (budget.md, agent-handoffs.md). What does
not: the killed beat's un-run slots (re-picked next tick) and in-flight
session output after the process-tree dies.

Proof: tests/test-overnight-shutdown.sh (wired into `make test`) —
SIGTERM mid-run gives rc=1 + `shutdown-signal` breadcrumb naming the
in-flight session; the cold start after it breadcrumbs
`cold-start-unclean` and does not spawn; a clean run resumes spawning.
