# 2026-09-28 — omarchy arm fix, distro update-watch, ISO scaffold

## Wicket arm fix (sudoers placeholder trap)

Phase-1 desk flow was blocked: the operator ran the pinned bootstrap
block verbatim, but `sudo -n -l -U bricker` still showed no wicket
grants and `automation/lib/privileged.sh wicket version` exited 3
(`wicket not armed:`).

Root cause: `automation/config/wicket.sudoers.example` granted a
placeholder user `hngh` (comment said "rename to the user the
automation tier runs as"), while the pinned bootstrap blocks
(privileged.sh `_pv_bootstrap_block`, dashboard-server.py
`DESK_BOOTSTRAP_PINNED`) install the example **verbatim** — no rename
step anywhere in the printed flow. Verbatim run arms nothing: the
drop-in grants a ghost user, the real operator's `sudo -l` never shows
wicket lines. Design trap, not operator error.

Fix: grants retargeted to `%wheel` (the operator group) — works
verbatim on this desktop, laptop deploy inherits it, no per-machine
rename step. Command scope unchanged (three exact
`/usr/local/lib/hngh/wicket.sh <action>` grants, no NOPASSWD:ALL).
`DESK_BOOTSTRAP_PINNED` trailing comment synced ("# grants %wheel").
test-wicket.sh template law green; full `make test` green (2954 checks,
rc 0) with the change in tree.

Operator state at record time: dispatcher + root manifest installed
(root-owned, verified), omarchy signing key
`40DFB630FF42BCFFB047046CF0134EE680CAC571` imported to the pacman
keyring; pending operator commands: sudoers drop-in install, `[omarchy]`
repo append to /etc/pacman.conf. (Machine precedent for user-scoped
grants — the hngh-automation ufw grant — is operator-configured outside
the repo; the repo template needed the portable form.)

## Weekly distro update-watch

`automation/cadence/calendar/weekly/31-distro-update-watch.sh` —
archlinux.org news feed, CachyOS + omarchy latest GitHub releases;
7-day last-seen dedup under `$HNGH_HOME_DIR/db/distro-watch/`;
per-source URL env overrides (`HNGH_DISTRO_{ARCH,CACHYOS,OMARCHY}_URL`);
NEW_CAP 5 rows; first sighting arms state only (sibling
28-omp-changelog-watch convention). Hermetic test (27 checks, stubbed
curl). Registered in `automation/cadence/README.md` weekly list.

## Live-ISO scaffold

`automation/iso/profile/` (mkarchiso releng shape, CachyOS kernel +
znver4 repos, `[omarchy]` repo last, omarchy session core mirroring
`config/omarchy-base.packages`, avoid-list intact) +
`automation/iso/build-live-iso.sh` wrapper (seams MKARCHISO_BIN /
ISO_PROFILE_DIR / ISO_WORKDIR / ISO_OUTDIR, artifacts under
`~/.hngh/db/iso`, never escalates). `automation/tests/test-iso-build.sh`
(11 checks, mkarchiso stub). Wired into automation/Makefile (bash -n
sweep + test target). archiso NOT yet installed on the host — building
a real artifact still needs `pacman -S archiso` (operator command).

## Jevify verdict (phase-1 manifest vs this desktop)

Deterministic pre-pass (pacman -Q + pacman -Si): 4 of 25 already
installed, 18 available from CachyOS znver4/extra repos, 3 only in
`[omarchy]` (hyprland-preview-share-picker, owe, owe-lockfeed). Judge
pass over 17 units: all additive (zero Conflicts/Replaces against the
installed Plasma stack), session_risk ≤ 0.54. Phase-1 set does not
touch the boot chain; Plasma X11 remains the default session.
