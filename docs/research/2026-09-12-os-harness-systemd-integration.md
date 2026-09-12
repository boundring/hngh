# What depth of systemd integration (user units, generators, timer-vs-unit tradeoffs) makes an OS-harness harness cleanly alongside a host systemd rather than fighting it?

Status: crystallized 2026-09-12 from research line `os-harness-systemd-integration`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-os-harness-systemd-integration.md.

# Research Line: systemd Integration Depth for an OS-Harness Harness

**Line:** What depth of systemd integration (user units, generators, timer-vs-unit tradeoffs) makes an OS-harness harness cleanly alongside a host systemd rather than fighting it?
**State:** Contracted (final structured summary)
**Date:** 2026-09-13

## Verification Caveat (Load-Bearing)

This session I could not inspect the working tree of `/home/bricker/Projects/etc/hngh` or the host vault directly. The only paths asserted with confidence are:
1. The repository root itself, as given in the task framing.
2. systemd's documented user-unit search path (`~/.config/systemd/user/`), stated from prior knowledge of `systemd.unit(5)` — not re-verified this session.

All harness-internal claims below are marked *needs verification* unless explicitly grounded in the prior material or external documentation I can cite by name. Where a claim requires external sources I cannot verify, I say so explicitly rather than asserting it.

---

## Findings

### F1. Coexistence vs. Fighting is Decided at the Which-Manager Layer
The single highest-leverage decision is **which systemd instance** owns the harness units. A user manager (`systemctl --user`) runs inside the host's cgroup tree under `user.slice`, with its own unit namespace and dependency graph. Registering system units instead causes the harness to compete with the host for ordering, targets, and `daemon-reload` timing — this is where "fighting systemd" actually begins. The prior observation `obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` indicates the overnight harness was already "enabled," but *whether it is user-scope or system-scope needs verification against the repo*.

### F2. Timer + Oneshot Is the Default Execution Primitive
For scheduled or remediation-style workloads, a `.timer` + `Type=oneshot` pair with `Persistent=true` is the correct default. Each run is idempotent: a fresh process inspects state, acts if needed, exits. Polling-daemon designs (`Type=simple` + sleep loop) are rejected at review. A daemon unit (`Type=notify`, `WatchdogSec=`, `Restart=on-failure`) is permitted only when the workload is genuinely event-driven (`.path` units, `.socket` activation, D-Bus signals), with justification in a comment header in the unit file itself. The ROCm watcher case (`SRC-2026-08-18-010`) is the canonical in-house example: remediation is idempotent and latency-tolerant, so timer+oneshot wins; a wedged check self-heals on the next tick with no liveness protocol to get wrong.

### F3. No Generators. Runtime Unit Emission Instead
The harness must not install anything into systemd's generator directories. When dynamic units are needed (per-agent, per-task), the harness process itself writes the unit file into `~/.config/systemd/user/`, validates with `systemd-analyze --user verify <unit>` *(documented behavior from prior knowledge — confirm the `--user` flag's verify support on the host's systemd version before relying on it)*, runs `systemctl --user daemon-reload`, and enables the unit. This keeps the harness's unit surface visible, greppable, and auditable in a single directory tree rather than scattered across generator output paths.

### F4. Boot Persistence Comes from Linger, Not System Targets
Persistence across reboots is achieved via `loginctl enable-linger` for the harness user, not from system targets or multi-user.target dependencies. This keeps the harness entirely within the user manager's lifecycle while still surviving host restarts. *Whether the current repo uses linger or some other mechanism needs verification.*

---

## Recommendations (Enforceable in Code Review)

### R1. Fix Integration Depth at the User Manager — Permanently
All hngh-automation units live under `~/.config/systemd/user/` and are managed exclusively via `systemctl --user`. Boot persistence comes from `loginctl enable-linger` for the harness user, not from system targets.

**Enforcement:** A repo-level invariant — no file in the hngh automation tree may reference `/etc/systemd/system`, and no install script may invoke `systemctl` without `--user`. This is cheap to grep in CI.

### R2. Timer + Oneshot Is the Default; Daemons Require Written Justification
For every scheduled or remediation-style workload in hngh-automation:
- Ship a `.timer` + `.service` pair with `Type=oneshot`, `Persistent=true`.
- Each run must be idempotent — a fresh process that inspects state, acts if needed, exits.
- Reject polling-daemon designs at review.

A daemon unit is permitted only when the workload is genuinely event-driven, and the justification goes in a comment header in the unit file itself.

**Decision rule, one line:** *poll → timer+oneshot; react → daemon or activation unit, with justification.*

### R3. No Generators. Runtime Unit Emission Instead
The harness must not install anything into systemd's generator directories. Dynamic units are written by the harness process into `~/.config/systemd/user/`, validated, reloaded, and enabled at runtime. This keeps the unit surface in a single auditable directory tree.

### R4. Linger for Persistence, Not System Targets
Use `loginctl enable-linger` for boot persistence. Do not wire the harness into system targets or multi-user.target dependencies. *Current repo state needs verification.*

---

## Open Threads

1. **Scope Verification:** Whether the overnight harness (`obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled`) is user-scope or system-scope remains unverified against the repo. This is the single most important open question for R1 enforcement.
2. **`systemd-analyze --user verify` Support:** The `--user` flag's verify support depends on the host's systemd version. Needs confirmation before R3's validation step can be relied upon in CI.
3. **Linger Adoption:** Whether the current repo uses `loginctl enable-linger` or some other persistence mechanism needs verification. If it uses system targets, R4 is not yet satisfied.
4. **Generator Directory Hygiene:** No evidence was found of generator usage in the prior material, but absence of evidence is not evidence of absence. A grep for `/usr/lib/systemd/user-generators` or `~/.config/systemd/user-generators` in the repo would close this thread.

---

## References

- `/home/bricker/Projects/etc/hngh` — repository root (given in task framing)
- `[[sources/SRC-2026-08-18-010]]` — Unsloth ROCm libhsa Segfault Workaround & Systemd Watcher (canonical timer+oneshot example)
- `[[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]` — Observation: overnight harness built, verified, enabled
- `[[concepts/agent-harness-governance]]` — Agent-Harness Governance Positioning
- `[[sources/SRC-2026-08-19-001]]` — Agent Harness Landscape: Empirics and Positioning
- `systemd.unit(5)` — user-unit search path documentation (prior knowledge, not re-verified this session)
- `loginctl(1)` — linger mechanism documentation (prior knowledge, not re-verified this session)
