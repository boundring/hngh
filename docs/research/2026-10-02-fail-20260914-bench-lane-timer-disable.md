# Why is hngh-model-bench.timer still enabled+active after the bench-trigger lane disable step, and what closes the residue: a machine-side guard or an operator systemctl action?

Status: crystallized 2026-10-02 from research line `fail-20260914-bench-lane-timer-disable`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-bench-lane-timer-disable.md.

# Final Structured Record

**Research line:** Why is `hngh-model-bench.timer` still enabled+active after the bench-trigger lane disable step, and what closes the residue: a machine-side guard or an operator `systemctl` action?

**Lifecycle state:** contracted — final record

**Date:** 2026-10-02

---

## Verdict

The residue is closed by an **operator action**, not a machine-side guard — with one conditional exception. The mechanism is documented systemd behavior, not a defect in the harness:

- `systemctl disable` only removes the `timers.target.wants/` symlink. It never stops a running timer. The disable step as described leaves the timer `disabled` but `active (waiting)` until the next reboot.
- The correct close is `systemctl disable --now hngh-model-bench.timer` (or an explicit `systemctl stop` alongside the disable). This is the operator-side fix.

A machine-side guard is warranted **only if** something in the automation re-enables the timer after the lane-disable step. If the prior observation of an "overnight harness built/verified/enabled" cycle is accurate, an enable/verify step in that cycle is the prime suspect for re-arming the timer — in which case operator action alone fights a losing loop and a guard is required.

---

## Findings

| # | Finding | Confidence | Source |
|---|---------|------------|--------|
| F1 | `systemctl disable` does not stop an active timer; it only removes the `timers.target.wants/` symlink. The timer remains `active (waiting)` until reboot. | High — systemd manpage behavior | systemd documentation |
| F2 | `systemctl disable --now` (or `disable` + `stop`) is the correct operator action to fully close the timer. | High — systemd manpage behavior | systemd documentation |
| F3 | If the harness re-enables the timer after the disable step, operator action alone is a losing loop; a machine-side guard is required. | Medium — depends on unverified harness behavior | — |
| F4 | The prior observation of an "overnight harness built/verified/enabled" cycle is the prime suspect for re-arming the timer. | Low — observation-based, not yet traced | [[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]] |
| F5 | `Persistent=true` in the unit file would cause a missed run to re-fire after reboot regardless of disable/stop ordering. | Unknown — unit contents not verified | — |

---

## Recommendations

### R1 — Fix the disable step (operator action; do this first)

Change the lane-disable step to `systemctl disable --now hngh-model-bench.timer`. If the harness must keep disable and stop as separate operations, add `systemctl stop hngh-model-bench.timer` immediately after the disable. This resolves the "enabled+active after disable" symptom in the common case.

### R2 — Audit the unit for `Persistent=true`

Locate the unit file (search order: `/etc/systemd/system/hngh-model-bench.timer`, then `/etc/systemd/system/hngh-model-bench.timer.d/*.conf` drop-ins, then the packaged unit under `/usr/lib/systemd/system/` or the distribution-specific equivalent, then the source copy in the hngh kernel repository). If `Persistent=true` is set, a missed run re-fires after reboot regardless of the disable/stop ordering — remove it or pair it with R3.

> **Explicit caveat:** I cannot verify the unit's contents from here. This is an inspection task, not an assertion.

### R3 — Use `mask` when the lane must stay dead

`systemctl mask hngh-model-bench.timer` (symlink to `/dev/null`) defeats any re-enable path — including a well-meaning harness verify step or a manual `systemctl start`. If the overnight cycle re-enables the timer, masking is the minimal machine-side enforcement and is preferable to inventing a new guard mechanism.

### R4 — Machine-side guard only if re-enable is confirmed

If, and only if, tracing shows the harness re-arming the timer, add a drop-in at `/etc/systemd/system/hngh-model-bench.timer.d/lane-guard.conf` with a `ConditionPathExists=` gate file owned by the lane-enable tooling. This makes the timer's liveness a function of an explicit operator-created flag file rather than of orchestration side effects.

> **Explicit caveat:** Do not build this speculatively — it adds a second source of truth and its own failure mode (stale gate file = silently dead lane).

### R5 — Add a post-disable verification step to the harness

The disable step should be followed by an assertion: `systemctl is-enabled hngh-model-bench.timer` must not return `enabled`, and `systemctl is-active hngh-model-bench.timer` must return `inactive` (or `failed`). Fail the lane transition if either check fails. This converts the current silent residue into a loud, attributable failure and would have surfaced this line's question at the moment it was introduced.

### R6 — Decision rule for "guard vs. operator action"

- Nothing re-enables the timer → R1 alone closes the line. Done.
- The harness re-enables it → R3 (mask) is the minimal fix; R4 only if a more granular gate is needed.

---

## Open Threads

| Thread | Status | Notes |
|--------|--------|-------|
| T1 | Open | Confirm whether the overnight harness cycle re-enables the timer (requires tracing) |
| T2 | Open | Verify unit file contents for `Persistent=true` (requires inspection of `/etc/systemd/system/hngh-model-bench.timer` and drop-ins) |
| T3 | Open | Determine whether R1 alone suffices or whether R3 is needed (depends on T1 outcome) |

---

## References

- systemd manpage — `systemctl disable`, `systemctl stop`, `systemctl mask` behavior (external; not in the hngh repository)
- [[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]] — prior observation of overnight harness cycle
- hngh kernel repository: `[redacted path] — unit file location and harness code (paths cited where inspection is required; contents not verified from this record)
- [[concepts/moment-of-action-freshness]] — attestation freshness recheck (read-only pointer; not directly applicable to this line)
- [[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]] — prior research lesson on the same observation (read-only pointer)

---

**Line closure condition:** R1 is applied and T1 is resolved (either confirmed benign → line closed; or confirmed re-enable → R3 applied → line closed). Until then, this record remains active.
