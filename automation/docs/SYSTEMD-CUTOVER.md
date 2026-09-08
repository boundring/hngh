# P4 systemd cutover runbook (operator)

Source units: `hngh-automation/systemd/` (synced to `hngh/automation/systemd/`).
All units now point at `/home/bricker/Projects/etc/hngh/automation`. Nothing is
installed or activated yet — run these commands manually.

## Procedure

1. Install new units:
   `cp hngh/automation/systemd/* ~/.config/systemd/user/`
2. Reload: `systemctl --user daemon-reload`
3. Green check BEFORE touching the old set — start one new unit once:
   `systemctl --user start hngh-cadence-hour.service`
   `systemctl --user status hngh-cadence-hour.service` (expect active/exited, rc=0)
4. If green: disable old set (all hngh-* units), then enable+start new set:
   `systemctl --user list-unit-files 'hngh-*' --state=enabled` (old ones)
   `systemctl --user disable --now <old units...>`
   `systemctl --user enable --now <new timers...>`
5. Verify timers: `systemctl --user list-timers 'hngh-*'`
6. Rollback if step 3 fails: keep old units enabled; fix source, re-copy,
   `daemon-reload`, retry.

Constraints: never disable old set before the cadence-hour green check.
