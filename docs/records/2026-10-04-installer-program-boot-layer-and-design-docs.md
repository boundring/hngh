# 2026-10-04 — Installer program: boot-layer script, design docs, mesh evidence

Program: operator directives of 2026-10-04 (m09401) — script every operation any
Hngh install needs on any OS, including optional live-Omarchy disk/boot management;
mesh phase (SSH keys, tailnet, syncthing, 1Password); final report opened on-screen.

## Landed

- `automation/jobs/omarchy-boot-build.sh` — sudo-prompting boot-layer installer for
  live-Omarchy targets. Phases `census|esp|build|qemu|adopt-check|all`.
  - Safety contract (settled after two failed test rounds): dry-run default always
    exits 0 and never invokes sudo; real execution only via `--yes`; `--yes` without
    a TTY is refused (exit 2) unless `HNGH_BOOT_CONFIRM=YES` is also set, so CI or a
    scripted call can never run destructive work; `run_root` is fail-closed
    (`sudo "$@" || exit $?`) so a failed mkfs can never be followed by a mount.
  - Encodes the E1/E2 corrections: ESP mounts at `/mnt/boot` (fstab pins
    `UUID=317A-31FF` for `/boot`); `pacman -S --needed linux-omarchy limine`
    reinstall-FIRST, then `mkinitcpio -P` (mkinitcpio.d is EMPTY on the target —
    preset comes from the package); limine loader path discovered via
    `ls /usr/bin | grep -i limine`, never guessed; linger via
    `touch /var/lib/systemd/linger/bricker` (`loginctl` has no bus in chroot);
    QEMU boot proof through a qcow2 overlay (kvm when writable, TCG fallback).
  - Env knobs: `HNGH_BOOT_DISK`, `HNGH_BOOT_MNT`, `HNGH_BOOT_USER`,
    `HNGH_ESP_ID` (317A31FF), `HNGH_ESP_LABEL` (OMARCHY-ESP), `HNGH_UPSTREAM`.
- `automation/tests/test-omarchy-boot-build.sh` — 21 hermetic proofs, no real disk,
  no real sudo (PATH sudo shim exit 99 proves the real path is reachable ONLY under
  `--yes` + confirm env). Registered in `automation/Makefile` test list.
- `docs/design/hngh-installer.md` — REQ-I1..I22, GAP-I1..I3: phase requirements
  (census, esp-format, mount+chroot-build, boot-proof, config-adopt, mesh-setup,
  post-boot verify), mesh requirements (operator directive: cross-device SSH keys,
  tailnet/LAN resolution, syncthing per-device backups, 1Password vault sharing),
  wizard QoL, packaged-release gating.
- `docs/design/operator-orchestration.md` — government-emulation identity taxonomy
  (branches, filings, hearings, votes), expeditions, the one-orienting-fixture
  simplification (kernel-to-kernel + orienting-attention fixture unified), jevify
  expansion, awake-time autonomy requirements.
- Design-doc citations updated to point at the landed script (GAP-I1 closed for the
  boot window; mesh GAP-I2 and device-table GAP-I3 stand).

## Mesh evidence

`ssh bricker@192.168.0.16` (reference Omarchy laptop) → `Permission denied
(publickey)` (2026-10-04, BatchMode probe, twice this session). No deployable key;
this is the GAP-I2 seam the mesh-setup phase exists to close. No workaround
attempted (installing keys on a remote device is an operator-gated action).

## Test-shape lessons

First draft gate() required an interactive YES confirm for real execution and
refused no-tty runs even for dry-runs; tests failed 3×. Settled contract: dry-run is
safe by construction (refusal belongs to real mode only); `--yes` is the only key to
execution; TTY-or-confirm-env guards `--yes` itself. Shim-based sudo probing lets
hermetic tests prove the authorization boundary without touching real sudo.

## Status

Boot-layer bring-up scripted and tested; full `cd automation && make test` gate run
recorded in this session's log (`/tmp/gate-m09401.log`). E3/E4 operator-privileged
blocks (mkfs, mkinitcpio, linger, QEMU proof, adopt real-run) remain parked on the
operator in `local://harness-skeleton-program-plan.md` (plan file, session-local).
