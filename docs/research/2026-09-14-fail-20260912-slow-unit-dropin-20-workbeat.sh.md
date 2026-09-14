# Why does dropin:20-workbeat.sh show wall=1964.6s against a 40.3s median (x6), is that latency a defect or expected forethought-dream+plan-session work, and what disposition (fix or park) does the evidence support?

Status: crystallized 2026-09-14 from research subject `fail-20260912-slow-unit-dropin-20-workbeat.sh`; routed 2026-09-12T20:00:35Z by scripts/router-tick.py from alert identity `slow-unit:dropin:20-workbeat.sh`.

## 1. Verification status (stated up front)

Unlike the sister crystallizations `2026-09-14-fail-20260910-slow-unit-dropin-16-remote-push.sh.md` (park; no execution access) and `2026-09-13-fail-20260909-slow-unit-dropin-33-research-beat.sh.md`, every claim below was verified directly against the working tree and the live ledger during the 2026-09-14T15:1xZ session:

- `automation/jobs/slow-units.py:25` — the ENVELOPE entry for `dropin:20-workbeat.sh` read `1800.0 + 60.0` at research time (stale constant, unchanged since the 2026-09-01 envelope landing).
- `automation/scripts/overnight-cycle.sh:33` — `TIMEOUT_S="${OVERNIGHT_TIMEOUT:-1800}"`, the hard `timeout` cap on the delegated executor session.
- `automation/scripts/overnight-cycle.sh:809-821` — the forethought dream leg (landed 2026-09-10): `TIMEOUT_S="${OVERNIGHT_DREAM_TIMEOUT:-600}"` (line 815) set around `launch_session "$slug-dream"` (line 816), run synchronously inside the same beat wall before the executor leg, then restored.
- `automation/dashboard/time-ledger.json` (generated 2026-09-14) — `dropin:20-workbeat.sh`: `last_wall_s=1796.987`, `p50_s=799.257`, `runs_24h=24`, `max_s=2384.771`.
- Routed alert: wall=1964.6s, median=40.3s, x6.

## 2. Findings

**F1 — The unit is multimodal by design (high confidence, direct observation).**
One script (`scripts/overnight-cycle.sh`) runs hourly as a drop-in and behind `hngh-overnight.service`. Its legs: quick skip-exits (~0.2s, the historical median), bounded beats (~150-240s), and full overnight plan sessions capped by `TIMEOUT_S` (1800s). The module docstring and the 2026-09-01 envelope landing already classify it as bimodal-by-design; the dream leg adds a third legitimate mode.

**F2 — The envelope is stale, not the unit (high confidence, direct).**
When `1800+60` was set (2026-09-01), the unit wall was bounded by the executor leg alone. Since 2026-09-10 the forethought dream leg adds a synchronous second session inside the same wall: dream up to 600s + executor up to 1800s, so legitimate completions reach ~600+1800+overhead. Every observed wall fits that arithmetic — alert 1964.6s and ledger max 2384.771s are both under 2460 = 1800+600+60, and both sit far above the stale envelope 1860. The alert fired on the newest legitimate mode, exactly the false-positive class the envelope mechanism exists to suppress (44 false rows 2026-08-27..09-01 before envelopes landed).

**F3 — Parking would re-alert (ledger evidence).**
Sister identity `dropin:33-research-beat.sh` re-routed 5x while its disposition sat parked without landing; its fix (ENVELOPE raise, commit a579084) closed it. The 16-remote-push raise (2362f89) closed 432 duplicate alerts. A bare park here leaves the 1860-2460s window flagging every long dream+session completion.

## 3. Disposition

**ADOPTED — fixed, not parked.**

Fix: raise ENVELOPE to `1800 + 600 + 60 = 2460s` for `dropin:20-workbeat.sh` AND `hngh-overnight.service` — the two keys run the same script and share the dream leg; the module comment binds them as a pair. Failing test first in `automation/tests/test-slow-units.py`: the newly observed in-envelope walls (1964.6s alert wall, 2384.771s ledger max) fail against the stale 1860 envelope, and the over-envelope case moves from 1861.0s to 2461.0s.

Risk of the raise: a genuinely wedged overnight cycle between 1860s and 2460s now waits one extra hour before flagging. Accepted — the upstream `timeout 1800` still kills the executor leg, so a wall in that window is by construction dream+session work, not a runaway process.

## References

- `automation/jobs/slow-units.py:20-41` — ENVELOPE dict and module docstring
- `automation/tests/test-slow-units.py:23-53` — workbeat cases pinning the arithmetic
- `automation/scripts/overnight-cycle.sh:33,815-816` — executor cap and dream leg
- `automation/dashboard/time-ledger.json` — observed walls
- Class precedents: commits 2362f89 (16-remote-push) and a579084 (33-research-beat); docs `2026-09-14-fail-20260910-slow-unit-dropin-16-remote-push.sh.md`, `2026-09-13-fail-20260909-slow-unit-dropin-33-research-beat.sh.md`
- Prior art: `docs/research/2026-08-29-unattended-session-budgets.md`
