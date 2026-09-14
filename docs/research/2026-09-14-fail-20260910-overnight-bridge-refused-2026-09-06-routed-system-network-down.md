# fail-20260910-overnight-bridge-refused-2026-09-06-routed-system-network-down

**Question:** Why did overnight beat 2026-09-06-routed-system-network-down
refuse its bridge run with `conflict labels=record-conflict`, and which
guardrail closes the class?

## Evidence read

- Alert text (routed plan header, 2026-09-10T23:00:33Z): "overnight beat
  2026-09-06-routed-system-network-down could not open a bridge run:
  conflict labels=record-conflict".
- `automation/lib/launch-session.sh` lines 64-73: the refusal mechanism is
  documented in-source -- hngh records `run-1` per bridge store, so two
  `--run-start` calls against one store record-conflict. A beat used to
  share one store across its dream pass and executor (and extra plan
  slots), so every launch after the first refused rc=75 with no session
  and no spend (the 2026-09-11 throughput stall).
- The fix is landed: commit `a1d9b26` (2026-09-11, "fix: per-launch bridge
  store (beat stall) + rc=124 timeout classified transient") introduced
  `launch_store()` -- a fresh store dir per launch
  (`$STORE/launch-<slug>-<timestamp>-<pid>`), and `launch_session` pins
  `OMP_BRIDGE_STORE` to it for both the run-start and the raised-limits
  retry, so run-end closes the run in the same store (lines 119-141).
- A second guard for the same class: the `$slug` positional must ride to
  `launch_store` -- a bare call loses positionals under `set -u` (bash
  5.3), silently voiding the per-launch dir and falling back to the
  shared default, re-producing record-conflict (lines 120-123, caught
  live by the 2026-09-11 bili-ocgo verification run).
- Queue state 2026-09-14: no unread alert row remains for this identity;
  the sibling row `260121eb` (same cause, worker-transport-wiring,
  2026-09-11) is already past the report cursor.

## Doctrine applied

- Obsolete/bestiary rule: check current ledger state before acting on
  anything read earlier -- the alert predates its own fix.
- Fail-closed contract: the refusal was correct behavior (hngh refused a
  duplicate run record); the bug was the caller sharing a store, not the
  gate.

## Findings

1. Root cause: shared bridge store across launches inside one beat ->
   second `--run-start` hits the `run-1`-per-store record rule ->
   rc=75 refusal, no session, no spend.
2. Fixed before research: `launch_store()` per-launch store dirs
   (a1d9b26, 2026-09-11) close the class; run-start/run-end share the
   pinned store per launch.
3. Residual risk is the `set -u` positional-loss path, which is
   comment-guarded and was verified live 2026-09-11.

## Recommended next line

None -- the line closes as resolved-before-research. If a record-conflict
refusal reappears after 2026-09-11, that is a NEW failure class (per-launch
store regression), not this one.
