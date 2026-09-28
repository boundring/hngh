# Omarchy integration gap registry + dependency schedule

Date: 2026-09-27 (evening wave). Operator intent (m01201, paraphrased): Hngh gains procedural
interfaces for operators to authorize/configure/install Omarchy as a layer onto CachyOS —
surfaced in the newspaper-styled dashboard webapp (Chrome first-class, responsive), using
CachyOS-optimized packages, layering Omarchy core/add-ons, coordinating updates of both with
operator authentication prompts; all gaps itemized, scheduled, then executed by fanned-out
agent streams. Hngh doubles as a security tool.

## Verdicts (decided this wave)

1. **Governed-fleet blocker is NOT on the omarchy critical path.** The lane is
   orchestration-only (session launch/supervision/respawn/telemetry; zero pacman/sudo/package
   surface — forensics grep). Root cause of the park: three rc=124 deaths at the overnight
   executor's own 1800s ceiling against one oversized Slice C step (evidence:
   `automation/agent-handoffs.md:1061/:1312/:1361`, log tails show mid-work kills, incl. the
   17:37Z run that authored the agent-respawn sessions-day-max fix — landed as 958c1949).
   Fix: split Slice C into C1/C2/C3 budget-sized sub-steps + delete parked row
   `automation/state/beat-blockers.tsv:9`; ledger self-clears on next ok.
2. **Privileged channel policy: the wicket, not a persistent root session.** An omp/Hngh
   session with computer-use gets governed privileged ops through a root-owned dispatcher
   (`/usr/local/lib/hngh/wicket.sh`) allowlisted by a root-owned copy of the package manifest,
   granted via ONE exact-command sudoers line (per-command NOPASSWD, never ALL — the existing
   `automation/config/hngh-automation.sudoers.example` law). No root shell, no tmux streaming
   into root, no chroot. Properties: no-expires (NOPASSWD exact command needs no sudo
   timestamp; the distro-default 15m ticket inheritance window is bypassed by `sudo -n` exact
   command), fail-closed (unarmed → printed remediation, exit 3), audited (`logger -t
   hngh-wicket` + breadcrumbs). Known ceiling (`ponytail`): trust-on-manifest — Arch packages
   may carry install scripts, so the manifest pin defines the trust boundary; upgrade path is
   hash/keyword pinning if the operator asks. Chroot stays an operator-performed rescue tool,
   not an automation surface.

## Gap registry

| # | Gap (intention vs state) | Status | Surface |
|---|---|---|---|
| G1 | No governed package actuator (only bootstrap.sh interactive sudo) | **Wicket in flight** (S2): dispatcher + sudoers example + `privileged.sh` seam + tests; unarmed until operator runs bootstrap window | `automation/lib/wicket.sh`, `automation/lib/privileged.sh`, `automation/config/wicket.sudoers.example` |
| G2 | No drift checker (pins vs pacman reality) | **S1 in flight**: `automation/jobs/pins-drift.py` + daily beat `30-pins-drift.sh` + `automation/config/hngh-pins.tsv` (path deviation: `hngh-packages.tsv` is the 2026-09-11 repo registry) | jobs + cadence/calendar/daily |
| G3 | No omarchy automation in repo (zero upstream reference) | **S4 LANED** 9357a0c4: shallow clone `~/Projects/etc/omarchy-upstream` @ 3faafba2 (v4.0.x), manifest `automation/config/omarchy-base.packages` (21 pkgs, 3 AUR-marked, avoid-list excluded/commented) | config + operator projects dir |
| G4 | No readiness reporting | **S5 LANED** (uncommitted): daily beat `31-omarchy-readiness.sh`, 17-check suite, live row 7c145d21 `a=yes b=yes(21) c=no d=no e=unknown` | cadence/calendar/daily |
| G5 | No operator-facing install/configure surface | **S3 in flight**: installation desk (`/desk.html`, `/desk-state.json`, POST `/desk/stage-authz`, `/desk/run-phase-1`) — newspaper-styled, buttons-with-printed-outcome idiom, fail-closed until approval + armed wicket | dashboard-server.py + dashboard/desk.* |
| G6 | Theming/color-theory port unmapped | **S7 LANED** (uncommitted): `docs/design/omarchy-theming-map.md` — Blueprints → `{{ *_strip }}` table, fonts, app coverage, phase-4 checklist | docs/design |
| G7 | Fleet blocker parks the roadmap beat | **S6 in flight**: plan split + row delete + triage record | state + docs/project/plans |
| G8 | Coordinate CachyOS + omarchy updates with auth prompts | Scheduled (post-phase-1): reuse wicket action surface + pins-drift; design after real install exists | — |
| G9 | omp × Hyprland session integration (env vars, portals, XDG currents per-session) | Scheduled (post-phase-1): portals.conf per-session override, environment.d audit (10-hngh-path.conf), uwsm unit wiring | — |
| G10 | Security hardening backlog (scout-verified risks) | Scheduled: systemd user units migrate env-injected secrets → `LoadCredential=` + `NoNewPrivileges=`; cert-receipt ledger is append-only but unverified-on-read; bootstrap.sh:53-71 still bare interactive sudo | systemd dropins, scripts |

## Dependency schedule

```
S4 clone+manifest (done) ──┬─> S5 readiness (done)
                           ├─> S1 pins-drift ──┐
S2 wicket (in flight) ─────┼──────────────────┼─> OPERATOR WINDOW 1 (bootstrap wicket)
                           │                  │         │
S7 theming map (done)      │                  ▼         ▼
                           └──────────────> S3 desk (in flight) ──> OPERATOR WINDOW 2
                                              │        (stage-authz → approve → run phase 1)
                                              ▼
                                   phase 1 landed (hyprland session beside KDE)
                                              ├─> G9 omp×Hyprland wiring
                                              ├─> G8 update coordination
                                              └─> phase 2 config adopt → phase 3 bins → phase 4 look port (S7 table)
S6 blocker split+readmit (in flight, independent — unblocks overnight roadmap beat)
```

## Operator authorization windows (requested at close)

- **Window 1 — wicket bootstrap** (one-time, three commands, root): install dispatcher
  root-owned 0755, install root-owned manifest copy 0444, validate + install sudoers drop-in.
  Exact block printed by `privileged.sh` when unarmed and by the desk.
- **Window 2 — phase 1 execution**: desk "Stage authorization" → operator approves the
  `desk-authz:phase-1` item (newspaper verb button) → "Run phase 1" executes
  `wicket install-base` (pacman -Sy --needed --noconfirm over the non-AUR manifest; AUR
  lines stay a user-session paru concern, shown but not run as root).

## Security posture (all prior considerations preserved)

Two-home split untouched (kernel/cert state in `~/.hngh-automation`, userspace in `~/.hngh`);
kernel `src/` surfaces untouched this wave; every privileged action: exact-command grant →
manifest pin → `--noconfirm` single transaction → journal audit; fail-closed on every
missing precondition; no daemons added (dashboard server + systemd timers already exist).
