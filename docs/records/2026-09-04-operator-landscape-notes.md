# Operator landscape session — direction, decisions, lessons — 2026-09-04

Status: RECORD. Restates the operator's 2026-09-04 direction and the
back-burner decisions faithfully; harvests this session's lessons;
admits no runtime capability.

## 1. Operator direction (2026-09-04), recorded faithfully

The operator's five feedback items:

1. **Email notifications live and confirmed.** Make them maximally
   functional/readable with section summaries; adversarially review
   operator-facing surfaces; Hngh needs cyclical routines for
   regularly optimizing notifications. (The sibling automation slice
   is landing the digest restructure + importance rubric + QA
   drop-in — cited by name, verified-on-arrival: scripts/email-digest.py
   sections were on disk 2026-09-04 but the TL;DR/rubric and
   cadence/day/13-email-qa.sh were not yet.)
2. **Dashboard QoL:** attention for QoL features, operator-facing
   presentation, and interfaces for Hngh's management of
   system-harness concerns (package updates, configuration
   management).
3. **Logs QoL:** operator-gated dismiss-able entries need attention;
   logs simpler to understand at a glance while keeping key/related
   info.
4. **Extended documentation:** as complexity grows, simply-communicated
   docs matter more; consider a navigable "wiki" to accompany the
   GitHub repo. Food for thought — research it.
5. **Long-absence posture:** the operator is away for a LONG stretch;
   relies on email (+SMS?) notifications; wants regular-cadence
   meaningful reports plus immediate notifications for
   important-enough matters. SMS is not available yet; the sanctioned
   routes are email (live) and the browser-relay channel (Route A
   prototype pending QR pairing — capabilities plan step 7).

The direct question — *what does the roadmap plan as Hngh's PRIMARY
operator interface, and are multiple interaction options included?* —
is answered with evidence in
[research/2026-09-04-operator-interface-landscape.md](../research/2026-09-04-operator-interface-landscape.md):
primary = the stage-2 nerve center webapp (Schedule/Sessions/System/
Research/Logs), inside the CLI+GUI command-center family, with the
dashboard-tui, OSD operative, pixel-RPG buddy, 19 CLI verbs, and the
new email/browser-relay async channels as the option list.

## 2. Back-burner decisions (faithful)

- **1Password desktop-app ↔ CLI/SDK integration: back-burnered.** The
  operator is NOT worried short-term: email is live via the file
  fallback; vault migration is an upgrade path. The question "can the
  SDK interface with the desktop app if the CLI can't?" is answered
  once, in the landscape record §3: **NO** — the SDKs (JS/Go/Rust/
  Python) use the same desktop-app integration plumbing on Linux (same
  socket, same failure); the bypasses are CLI-only `op account add` or
  a Service Account if the plan tier allows.
- **Stale `op-daemon.sock` lead recorded:** 13:25 socket, pid 4035 —
  a restart after the operator's pending reboot window is the cheap
  first test, parked for later.
- **Email live confirmed** (reports.md row 61f0a1e1,
  2026-09-04T21:30:15Z, credential source file-fallback).
- **One progress row filed** via scripts/report-queue (machine-owned
  path, not a ceremony candidate) capturing the back-burner decision.

## 3. Lessons harvested this session

- **Ports correction:** the local model serving endpoints were
  conflated — :8080 (llama-server) vs :8888 (unsloth-studio). The
  automation slice corrected the recognition/recovery retarget with
  divergence classified (hngh-automation commit f26e1d9, 2026-09-04);
  probe the endpoint the unit actually serves, not the brief's port.
- **Restart-to-arm-socket:** a service restart is what arms the
  desktop-app/daemon socket (the 1Password `op-daemon.sock` lead
  above); a stale socket from hours earlier is a restart-window
  candidate, not a code bug.
- **Verify-on-arrival sibling slices:** sibling automation slices
  landing in parallel are cited by name, never by hash, and every
  step touching them carries a verify-on-arrival clause — confirm on
  disk at execution time; park with the exact gap if absent
  (pattern proven by the capabilities plan's grounding notes).
- **Ceremony skill drift — evidence-before-claim:** the ceremony skill
  doc says "evidence-before-flag"; the kernel vocabulary (the ten
  principle names) is **evidence-before-claim**. Use the kernel
  vocabulary; the drift is known and recorded here rather than
  silently mapped.
- **Roadmap states are machine-owned:** stage-table State cells flip
  via the machine's verification sweep (staging plan step 3), not via
  ceremony docs edits — session docs state evidence and leave the
  cells alone (Deliverable 4's choice, recorded here).

## 4. Avoid-duplication vs the three live plans

this session's plan ([plans/2026-09-04-notifications-and-qol.plan.md](../project/plans/2026-09-04-notifications-and-qol.plan.md))
does not duplicate:

- **2026-09-01-operator-items.plan.md** — owns push-on-demand, the
  notification-channel survey (step 2), digest wiring + first live
  digest (step 3), the session cost model (step 4), the first
  publication artifact (step 5).
- **2026-09-03-staging.plan.md** — owns the wake-mutation rotation
  beat (step 1), the bench calibration (step 2), the stage-2/3
  exit-criteria sweep (step 3), the unsloth recovery note (step 4),
  the --site gap inventory (step 5), and the stage-4 governed-upgrade
  runbook (step 6) which the new plan's step 4 feeds but does not
  repeat.
- **2026-09-03-capabilities.plan.md** — owns the browser-messaging
  admit gate + prototype (steps 6–7, incl. the QR-pairing park), the
  credential seam (step 5), queue-drain measurement (step 8), and the
  service allowlist recovery path (step 3).

## 5. Ceremony note

Deliverable 4 (docs/project/roadmap.md) was deliberately NOT edited:
stage-table State cells are machine-owned evidence updates, flipped by
the machine's verification sweep (staging plan step 3) — a session
docs ceremony must not preempt that. The choice is recorded here per
the operator's direction.
