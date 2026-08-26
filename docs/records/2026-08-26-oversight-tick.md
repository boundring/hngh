# 2026-08-26 — Oversight tick (procedural + gated-agentic observation)

## Scope

The detect → hook → react → prevent continuum, first live slice:
an observation tick that runs continually over active work, with the
firing-style placement rule the operator specified (cheapest fires
whenever; cheap fires per-minute; agentic rides a slower beat).

## What landed

1. **hngh-automation `jobs/oversight-tick.sh`** — one tick, flock
   single-instance. Procedural probes, instant, no model in the path:
   - stale ceremony stores (`/tmp/hngh-cer-*` `record.lisp` older than
     30 min → alert);
   - working-tree skew (either repo dirty & uncommitted > 4 h → alert);
   - repeated-breadcrumb loop detection.
   Mode `--event=NAME` runs ONLY the instant probes (hook usage: git
   post-commit, ceremony completion), always exits 0. Mode `--steer`
   runs the self-review leg (`optimize:` crumbs). The credential
   probe reuses `jobs/credential-health.sh` (self-heal under flock).
- **Agentic leg (gated, optional)**: when `STEER_MODEL` points at a
   local endpoint, a bounded 60 s call reviews the recent
   `STATE.md` tail and emits `steer: <action>` / `steer: none`
   breadcrumbs; the beat is timestamp-gated
   (`STEERING_BEAT_MIN`, default 10) so a per-minute timer never
   spends per-minute cost; absent the var it is fail-closed off.
- **Mounted** as `cadence/5m/01-oversight.sh` drop-in (the 5 m tier
   exists; cadence-tick runs it flock-guarded).
- **Alert sink**: `report-queue --add alert`, landing rows in the
   hngh reports ledger (`HNGH_REPORT_ROOT` = hngh repo).

## Verification

- Live run: exit 0; emitted 6 real `stale-store` alerts — all
  `/tmp/hngh-cer-*` stores untouched > 4 h (10:37–11:32 vs 16:13),
  zero false positives; alert rows landed in
  `docs/project/reports.md` (18 entries this session).
- `--event` mode: exit 0, no agentic leg, no stale-store matches by
  design (event fires only the instant probes).
- Syntax: `bash -n` clean both files.

## Failure class fixed live

`set -u` + sourced `breadcrumbs.sh` referencing unset
`AUTOMATION_ROOT` → silent exit 1 on first use. Fixed by exporting
`AUTOMATION_ROOT` before the source. (Same failure class as the
stale-anchor guard and the store-mkdir guard: environment contract
violations kill early scripts — the guardrail list gains
"export the repo root before sourcing the lib".)
