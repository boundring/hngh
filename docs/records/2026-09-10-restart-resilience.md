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
