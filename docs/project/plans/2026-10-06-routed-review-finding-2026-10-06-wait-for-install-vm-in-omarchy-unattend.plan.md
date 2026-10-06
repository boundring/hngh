<!-- plan: status=accepted risk=normal accepted=2026-10-06T11:06:40Z routed-from=review-finding:2026-10-06:wait-for-install-vm-in-omarchy-unattend -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-13T11:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-06 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-06:wait-for-install-vm-in-omarchy-unattend`
at 2026-10-06T11:00:42Z. Alert text: `wait_for_install_vm` in omarchy-unattended-install.sh loops on `pgrep -af qemu-system` matching ANY qemu process on the host with no timeout — an unrelated VM (or the stub lingering) hangs the full phase forever. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
