---
category: supervision/init
persona: The Warden
status: seed
---

# Supervision & Initialization — what hngh runs today

hngh's automation tier is supervised entirely by **systemd --user** with three timers and a fail-closed tick runner. `make enable` installs and starts `hngh-cadence-subhour.timer`, `hngh-cadence-hour.timer`, `hngh-cadence-calendar.timer`, plus `hngh-credential-health.timer`, `hngh-overnight-lead.timer`, and `hngh-dashboard.service` (automation/Makefile:19-23). A single tick runs every drop-in of one tier in lexical order and exits 0 on any drop-in failure (automation/jobs/cadence-tick.sh:1-12); per-drop-in wall time goes to `logs/drop-in-timing.log` as a time-ledger source (automation/jobs/cadence-tick.sh:103-119). Single-flight is a per-tier `flock -n` on `LOCK="~tmp/hngh-cadence-${TIER}.lock"`, and a contended tick files a `tick-skip` crumb instead of queueing (automation/jobs/cadence-tick.sh:81-87). Two cross-tier gates ride the same script: `bailiff_check` halts **every** tier while the watch audit has findings (skip-with-crumb, gate_refusal bailiff; automation/jobs/cadence-tick.sh:49-58) and a RAM belt gates the rapid tier (automation/jobs/cadence-tick.sh:70-74).

Initialization is install-time, not first-boot-only. The ISO installer cannot run `make enable` from chroot (no systemd user manager), so it wires a self-disabling `hngh-firstboot.service` user unit that runs `make enable` at first login with a retry loop and logger fallback, with linger already set (automation/CHANGELOG.md:36-57). `--tier-migrate` (codified from commit f2b1cee0) migrates supervision between users: stop/disable the old tier's hngh-* user units, move `~/.hngh-automation` and the repo to the new tier home, then enable-linger + install.sh + smoke + `make enable` under an explicit `XDG_RUNTIME_DIR`/`DBUS_SESSION_BUS_ADDRESS` export (the su/ssh-session gap; automation/iso/profile/airootfs/root/install-hngh-os.sh:196-205), verify the :8890 listener's uid belongs to the new tier, and only then retire the old linger and flip tty1 autologin (automation/iso/profile/airootfs/root/install-hngh-os.sh:257-262). The migration order is STOP OLD → ENABLE NEW → VERIFY PORT OWNER → RETIRE OLD LINGER, asserted by 20 red-first installer tests (automation/CHANGELOG.md:58-62).

## Open questions for web research

1. What are established patterns for systemd **user-manager** first-boot provisioning (linger vs `user@.service` dependency tricks) and how do self-disabling first-boot units compare to cloud-init user-data?
2. How do other projects safely migrate a service tree and supervision between local users on a live installed system (home move + unit re-enable without a stale port owner)?
3. Timer design tradeoffs for homelab cadences: `Persistent=`, `RandomizedDelaySec=`, `AccuracySec=` vs flock-based single-flight — where does each fail?
4. What supervision stacks are used where systemd is unwanted (s6-rc, runit, daemontools) and what do they give up for user-session services?
5. Precedent for watchdog/circuit-breaker gates that suspend a whole task ladder (like `bailiff_check`) — deadman switches, systemd `OnFailure=`, or dedicated sentinel units?

## Candidate external systems to survey

- systemd user units + timers (linger semantics)
- s6-rc / s6-linux-init
- runit
- launchd (user agents, disabled-state model)
- cloud-init / first-boot provisioning models
