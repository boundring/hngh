# Capabilities direction — operator directives 2026-09-03

Status: RECORD. Preserves the operator's 2026-09-03 direction
faithfully, the evidence gathered for it (re-gathered read-only
2026-09-04), and the trajectory it sets. Admits no runtime capability
by itself; the design contracts and plan carry the implementation.

## 1. The six directives (recorded faithfully)

1. **Unsloth management.** Recognize local Unsloth hosting (API up
   ~99% of the time, occasionally halted for updates). Long-run:
   Hngh manages Unsloth AND software generally — stopping/starting
   services, config and update management.
2. **1Password.** Local 1Password is available for credential storage
   with an SDK and CLI (`op`). Hngh should manage software like
   1Password too, and use it for credentials. Security is paramount.
3. **Near-autonomous posture.** Automate any and all "operator
   steps"; difficulties become lessons and tuning; blockers after
   that process get handled with priority above later work.
4. **Queue progress.** The queue needs more reliable progress;
   steady continual pace.
5. **Documentation expansion.** Continual, steady expansion —
   progress AND coherence of intent; expand sections as Hngh itself
   expands.
6. **Open question — browser messaging.** Can the browser-based
   messaging approach be automated, targeting active logins (Google
   Messages web, Discord, WhatsApp, etc.)? The email channel is
   already procedural; this is about a browser-driven channel with
   near-zero token cost.

## 2. Evidence gathered (read-only; gathered 2026-09-04)

- **Systemd user units** (`systemctl --user list-unit-files`,
  `is-active`): llama-server.service **disabled**, unsloth-warm.service
  **disabled**, unsloth-studio.service **enabled**; all three
  inactive at check time. The 2026-09-03 observation (unsloth-studio
  active while :8080 unresponsive) was the prior state; the enable
  state of unsloth-studio (enabled, not disabled as the other two)
  is itself signal — the studio is the unit the operator intends to
  run.
- **Ports**: `curl http://127.0.0.1:8080/health` → 000 (down);
  `curl http://127.0.0.1:11434/` → 200 (Ollama up, Ornith-1.0-9B per
  lib/model.sh chain). The serving gap that sends the delegated lanes
  to paid fallback is confirmed still a serving problem.
- **Secret files** (paths + modes only, contents never read):
  `~/.hngh-automation/unsloth.token` (600), `unsloth.refresh` (600),
  `reviewer-local.conf` (644 — mode flagged in the credentials
  design; whether it carries a secret is not established),
  `notify-email.conf` **absent** (the email channel is dormant by
  design — lib/notify-email.sh's config-absent → one-crumb behavior).
- **1Password CLI**: `command -v op` →
  `~/.linuxbrew/bin/op` (linuxbrew prefix); `op --version` → 2.32.1.
- **Browser probes** (for directive 6): no chromium /
  google-chrome-stable / chromium-browser binary on PATH;
  `import playwright` fails (ModuleNotFoundError);
  `~/.config/chromium` and `~/.config/google-chrome` both exist
  (existence only — never opened). Full analysis:
  docs/research/2026-09-03-browser-messaging-automation.md.
- **Bench history** (stats/model-bench-2026-09-0{1,2,3}.jsonl, 5
  probes, as verified in the 2026-09-03 staging notes): TWO local
  models at 5/5 — unsloth/Ornith-1.0-35B-GGUF all three days;
  bartowski/Qwen3.8-27B-GGUF 4/5→5/5→5/5; gemma-4-12B variants 4/5
  with p1_reader=0 all days; Ollama's Ornith-1.0-9B 5/5, 5/5, then
  3/5 (single-day runs are weak gates — multi-day admission rule
  suggested).
- **Sibling automation slice 2026-09-03** (hngh-automation:
  jobs/service-state.py, scripts/service-ctl.sh,
  cadence/day/11-service-recovery.sh, queue-progress telemetry in
  scripts/email-digest.py): **not yet observed on disk at authoring
  time 2026-09-04** — the directories were listed (jobs/, scripts/,
  cadence/day/ — 10 day-cadence scripts present, 11-service-recovery
  among them NOT yet) and email-digest.py carries no queue-progress
  telemetry yet. Cited by path + slice name, verify-on-arrival; the
  capabilities plan's steps 1/3 gate on its landing.

## 3. Governance amendment carried by this direction

Directive 1 implies one amendment, recorded in
docs/design/service-management.md §3 (the standing rule docs are NOT
silently edited): start/stop/restart of ALLOWLISTED INSTALLED user
units (exactly llama-server, unsloth-warm, unsloth-studio, via
service-ctl) is normal-risk under the 2026-09-03 operator grant;
enable/disable/mask, unit-file edits, enablement changes, and
anything touching the security posture remain critical-class (park).
Hngh starts no daemons of its own — it manages existing installed
software. The kernel's "critical = systemd unit lifecycle beyond an
already-installed unit" rule stays intact: an installed unit's
start/stop is lifecycle WITHIN an installed unit.

## 4. Avoid-duplication note

The 2026-09-03-staging plan (accepted) already owns: bench probe
calibration (its step 2), stage-2/3 exit-criteria sweeps (step 3),
the unsloth recovery note (step 4), and the stage-4 package-upgrade
runbook design (step 6). The capabilities plan cites those steps
where they overlap and does not repeat them; its service/credentials
steps complement (not duplicate) the staging plan's
investigate-only posture by adding the amended-grant control surface.

## 5. Trajectory

Design-first because security is paramount (directive 2): the design
contracts (service-management.md, credentials-posture.md) land before
any implementation slice, so the closed allowlists, refusal taxonomy,
redaction duty, and the critical/normal boundary are fixed before the
first `service-ctl.sh start` or `cred_get` runs. Implementation
follows in the capabilities plan as gated, verify-on-arrival grow
beats (steps 1, 3, 5, 7), with research beats (2, 4, 6, 8) feeding
config-manager, the audit trail, the browser-messaging gate, and the
queue-pace verdict. Directive 3's posture is encoded structurally:
every park names the exact operator step; every failure becomes a
lesson, then takes priority.
