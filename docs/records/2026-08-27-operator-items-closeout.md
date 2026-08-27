# Operator-items closeout — papercuts, bench slot, failed units

Dated: 2026-08-27.

## Scope

The dashboard's "for the operator" digest listed three open items; all
three are now closed at the source, and the stale "hngh repo is
agent-read-only" framing is retired by this very record (six agent
certificate commits landed 2026-08-27).

1. **`create-run` raw `TRANSPORT-FAULT` on missing `--store` dir** —
   fixed in the kernel: `hngh.main:dispatch-command` now refuses every
   command whose store path does not exist with
   `store directory missing: PATH (create it first, or drop --store)`,
   exit 2 (was: raw `transport-fault` render, exit 3). No auto-create —
   the fail-closed explicit-root contract stands; all other faults stay
   faults. Contract tests in `tests/main/test-dispatch.lisp` (+4).
2. **Wake-store collision (`record-conflict`)** — fixed in
   hngh-automation `prompts/night-check.md`: the wake flow now sets one
   timestamped store per wake
   (`STORE=/tmp/hngh-worker-wake-$(date -u +%Y%m%dT%H%M%S)`), `mkdir -p`
   first (pre-empting papercut 1 for this flow), all five steps share
   it, and a `find … -mtime +1` prune keeps /tmp clean.
3. **MiniMax-H3 in `BENCH_MODELS`** — dropped from
   hngh-automation `config.env` (0/5 twice running; 7 models remain).
4. **Failed units (calligra ×2, gbd-agent-configs)** — investigated:
   calligra units were transient desktop-launch crashes (reset-failed,
   gone); `gbd-agent-configs` is WANTED backup infrastructure whose
   secret scan is correctly refusing `~/.hermes/config.yaml`
   (token assignment) — reset-failed only, left enabled; the token
   needs an owner decision (remove from tracked set or ignore-list).

## Evidence

- Kernel: `sbcl --script tests/run.lisp` → 2855 checks (was 2851);
  smoke `create-run --store=/nonexistent/xyz` → refusal text + exit 2;
  `present` same; `make test` gate green.
- Automation: `bash -n config.env` + repo linter green; diffs +10/−6
  across the two owned files; committed in hngh-automation.
- Units: `systemctl --user --failed` after cleanup → only
  `hngh-autonomy.service` (live work, deliberately untouched); system
  scope 0 failed.
- Lessons: `long-gates-run-async-against-interjections` and the
  `untracked-artifact tax` note (see the acceleration-wave record).

## Remaining unknowns

- `gbd-agent-configs` will re-fail on its next tick until the hermes
  token is removed or ignore-listed (owner decision).
- The digest text regenerates on the next morning report; the
  resolution breadcrumb in hngh-automation `STATE.md` steers it.