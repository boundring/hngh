# Privileged System Daemon Staging Plan

> **Status:** blocked from installation until the safety gates below are met.

**Goal:** Make hngh a durable, user-observed system harness across user-space restarts and human-initiated CachyOS maintenance, without granting an incomplete root daemon authority over package, filesystem, snapshot, or reboot operations.

## Current verified state

- Mission Control is live in tmux as `hngh-mc`; its hngh pane runs `make run` and the queue driver is active.
- A fifth read-only maintenance pane now reports pacman-lock state, update count, kernel-update count, pacnew/pacsave count, and `hngh-status` every 30 seconds.
- `make test` passed: **980 pass, 0 fail, 0 skip**.
- `bin/hngh` and `build/hngh-system` are stale June artifacts. They are not installed under `/usr/local`.
- No `hngh-system.service`, D-Bus policy, helper scripts, `hngh` group, or system daemon process is installed.
- The checked-in user service is not deployable: it targets missing `/usr/local/bin/hngh` and calls unsupported `hngh --stop`.
- The checked-in root daemon is not deployment-safe: `InstallPackages` builds a shell command with `pacman -S --noconfirm --needed`; snapshot creation hard-codes `/.snapshots`; the helper template has no helper payloads; D-Bus policy advertises methods the daemon does not implement; root writes are direct, non-atomic `fopen` calls.

## Decision

Do not install or enable `hngh-system.service` before the hardening work lands and passes fixture plus isolated-system tests. It would create a root D-Bus attack surface without delivering the intended safe update lifecycle.

Use the user-space hngh process and Mission Control now. It is sufficient for observation, queue persistence, local-model work, hibernation, and human-observed update preparation.

## Phase 0 — immediate, current system

1. Keep the Mission Control maintenance pane running while the user uses KDE/Cachy-Update.
2. Do not enqueue stable-system or privileged tasks. Ordinary local text-out tasks remain safe.
3. Before the user starts an update, record a durable queue checkpoint. Existing queue has no work in `:queued` or `:running`, so no work needs hibernation now.
4. During the update, observe the pacman database lock and do not dispatch new work that depends on a stable package set.
5. After the update and any required reboot, re-open Mission Control, re-run read-only status checks, review pacnew/pacsave files, and inspect failed/blocked queue entries before resuming work.

## Phase 1 — make the user daemon actually deployable

**Files:**
- `src/core/main.lisp`
- `systemd/user/hngh.service`
- `Makefile`
- `tests/integration/m0-full-stack.sh`
- add focused FiveAM or shell integration tests as appropriate
- `docs/guides/mission-control.md`
- `docs/project/next.md`

Required work:

1. Add an explicit `--stop` behavior or remove `ExecStop=`. The unit must not start a second foreground daemon when systemd stops it.
2. Ensure the service starts one durable hngh process with `HNGH_HOME=%h/.hngh`, has bounded restart behavior, and exits cleanly on SIGTERM.
3. Remove hard-coded `/usr/local` assumptions. Package/install one authoritative binary location, or generate the unit from the chosen install prefix.
4. Add a systemd user-unit verification test using materialized fixture unit files. It must assert real executable paths and a valid stop contract.
5. Build a fresh binary only after source tests pass. Test it with a temporary `HNGH_HOME`; do not replace the currently running Mission Control daemon until its health and state restoration are verified.

**Acceptance:** `systemd-analyze verify` succeeds against a unit whose `ExecStart` exists; `systemctl --user start/stop/restart` preserves and rehydrates an isolated queue; SIGTERM produces no queue corruption.

## Phase 2 — queue hibernation and maintenance coordinator

Execute the approved Day-Ralph plan first:

`hngh/.hermes/plans/2026-08-01_135346-day-ralph-maintenance-coordination.md`

The scheduler needs versioned records, leases, dependency gates, pause/resume, and a procedural maintenance observer before treating restart/update downtime as a normal operating condition. Model routes remain independent from action authority.

**Acceptance:** a simulated maintenance window pauses only `:requires-stable-system` tasks; an asserted active window pauses all dispatch; state survives user-daemon restart; no model call is necessary to determine any state transition.

## Phase 3 — reduce the root daemon to a read-only health surface

**Files:**
- `src/system-daemon/main.c`
- `systemd/hngh-system.service`
- `systemd/org.hngh.System.conf`
- add `tests/system-daemon/` fixture/harness coverage
- `docs/design/adr/NNNN-privileged-maintenance-operations.md`

Before installing the daemon, remove every mutation method from its first deployment. Expose only a typed `GetStatus`/health method that returns daemon version and supported capability names. Its D-Bus policy permits only that method to an explicitly-created, least-privileged group.

The privileged-daemon audit found hard blockers that must remain explicit in this plan: caller-controlled `chmod` can request setuid bits; `/usr/lib/systemd/system/` is currently writable through the allowlist; writes are non-atomic; `NoNewPrivileges=no` disables a key kernel safeguard; and the checked-in policy pre-authorizes unimplemented methods. The read-only deployment must therefore remove all mutation handlers and all mutation-policy grants, not merely promise that callers will refrain from using them.

The health method must be testable against a private D-Bus daemon or equivalent isolated fixture; it must not require the host system bus, root, package manager, or btrfs.

**Acceptance:** daemon is installed but has no capability to run pacman, write `/etc`, create snapshots, execute helpers, or reboot. A non-member D-Bus caller is denied; the named user-group caller can query health only.

## Phase 4 — privileged operations one capability at a time

No implementation begins without an accepted ADR that specifies authorization, idempotency, journal/recovery, rollback, timeout, cancellation, and user-visible approval for each method.

Order:

1. **Read-only status** — updates, pacnew paths, pacman lock, reboot hint.
2. **Snapshot preflight** — discover the actual btrfs/snapper topology. No hard-coded `/.snapshots`; snapshot failure is a hard stop.
3. **Single managed-file write** — strict path allowlist, descriptor-relative traversal defense, temp-file + fsync + atomic rename, mode validation, backup first, audit event. No arbitrary content path.
4. **Package transaction** — only after the above. No shell string construction, no `--noconfirm`, no precomputed-list substitution for a full upgrade. It must be initiated by a human-approved maintenance task and use an exact transaction contract.
5. **Reboot/rollback** — last. Always separate, interactive confirmation. Never initiated by a model or an unattended queue.

At each phase, use a separate systemd helper with a single fixed operation and minimal `ReadWritePaths=`. Do not use the current catch-all template until it has real, reviewed helper payloads. Use direct argv execution (`fork`/`execvp` or equivalent), never `popen` or a constructed shell command. System file writes require validated relative paths, no setuid/setgid/sticky mode bits, a pre-write backup, temp-file + `fsync` + atomic rename, and a structured audit event with caller identity.

The root unit must set `NoNewPrivileges=yes`, deny home access, narrow address families to the exact D-Bus requirement, bound capabilities and system calls, define a short shutdown timeout, and install a SIGTERM path that drains one active operation. Test its exact sandbox on the target OS before claiming btrfs support; do not guess its required device access.

## Hot-update contract

- Build and test in a fresh artifact location.
- Create a queue/state checkpoint before switching binaries.
- Stop only the user daemon; the root daemon remains stateless and should not own work.
- Start the replacement; it validates queue schema and rehydrates only durable state.
- Mark a running lease stale rather than retrying it blindly.
- If startup or health fails, restore the previous user binary and state checkpoint; do not alter package state.
- Package hngh-core and hngh-system together only after a real split-package build exists and version-skew detection is tested.

## Explicit non-goals before this plan is complete

- No autonomous CachyOS update.
- No automatic pacnew merge.
- No root model process.
- No root access to provider credentials or the user home.
- No background reboot.
- No daemon installation just to satisfy a design diagram.
