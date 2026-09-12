# Installer skeleton - platform checks + polled preferences

2026-09-11/12. Closes the install-path gap the operator flagged ("very, very
important soon") and peer-review finding 1 (blocks-peers: no stranger can
install hngh). Status: working skeleton landed tonight; real distro-matrix
testing is the declared next work, and the finding-1 honesty line stays until
a stranger-capable full path exists.

## What landed

- `install.sh` (repo root, the peer convention: one command from a clone):
  delegates the fail-closed core to `automation/bootstrap.sh` and adds the
  platform-check + interactive layer. Modes:
  - `--non-interactive --check`: validate only; CI-safe (no prompts, no
    writes, exit 0/1 exactly as bootstrap's check).
  - `--non-interactive` (or `-y`): validate + stage machine profile + write
    the choices record with defaults; no prompts.
  - plain: same core, then polls preferences ONLY when stdin is a TTY.
- `automation/lib/platform.sh`: pure detection/map functions (source-only).
  `detect_pm` (pacman/apt-get/dnf/zypper/apk order, matches bootstrap
  --install; empty = no supported manager, never guesses),
  `pkg_for MANAGER TOOL` (per-manager package names), `systemd_user_ok`
  (read-only), `python3_ok` (>= 3.12 kernel floor).
- `automation/tests/test-installer.sh`: fail-closed contract tests (wired
  into `make test` after `test-bootstrap.sh`).

## Design decisions

1. **Root-level `install.sh` delegating to bootstrap.** Peers (omp, bili)
   install from the repo root in one command; the root entry is the
   convention the peer review measured us against. `bootstrap.sh` stays the
   non-interactive core (prereqs + env contract + machine profile) - the
   installer calls it twice (check gate, then stage) rather than duplicating
   any of its logic. Bootstrap's fail-closed semantics are untouched.
2. **Polled preferences are OPERATOR-ENVIRONMENT scope, stated in the
   output.** hngh itself needs only the prereqs; the editor/browser/desktop/
   JS-toolchain polls configure the environment hngh's automation surface
   assumes on this machine. The installer RECORDS choices and prints the
   official install commands for optional companions (omp/bili via the
   npm/bun paths hngh-omp-update.sh maintains) - it installs nothing beyond
   what `bootstrap.sh --install` already does, and never touches systemd:
   `make enable` is printed for the operator to run after smoke review.
3. **Prompt mechanism**: every preference resolves through one `ask` fn -
   env override (`HNGH_EDITOR` etc.) wins, else the default unless stdin is
   a TTY (read from /dev/tty). `--yes`/`--non-interactive` force defaults;
   automation is never prompted. Choices land in
   `automation/config/installer-choices.json` (gitignored) with the mode,
   detected package manager, picks, and UTC timestamp - reproducibility.

## Package map (the prereq set, per manager)

| tool    | pacman (Arch, verified: this box) | apt-get   | dnf     | zypper   | apk     |
|---------|-----------------------------------|-----------|---------|----------|---------|
| python3 | python                            | python3   | python3 | python3  | python3 |
| git     | git                               | git       | git     | git      | git     |
| curl    | curl                              | curl      | curl    | curl     | curl    |
| jq      | jq                                | jq        | jq      | jq       | jq      |
| flock   | util-linux                        | util-linux| util-linux | util-linux | util-linux |
| sqlite3 | sqlite                            | sqlite3   | sqlite  | sqlite3  | sqlite  |
| sbcl    | sbcl                              | sbcl      | sbcl    | sbcl     | sbcl    |

Honesty marker (also in platform.sh's header): the Arch column is
`prereq_pkg` from `lib/prereqs.sh` - the box the tier is developed on. The
other columns are plausible per each distro's package search but UNVERIFIED
on real installs (Debian names python3/sqlite3; Fedora/Alpine ship sqlite).
`--check` on an unverified distro still works - detection and the map only
print; nothing installs outside `bootstrap.sh --install`.

## Test contract (test-installer.sh, hermetic)

- non-interactive `--check` passes the same prereq set bootstrap passes on
  this box (sandboxed PATH), exit 0 + "prerequisites ok";
- `detect_pm` returns pacman with a pacman stub on PATH, empty with none;
- `pkg_for` covers all 7 prereqs across all 5 managers (gap list otherwise);
- prompts are SKIPPED without a TTY (no prompt text in output, run
  completes, choices record says `installer_mode=non-interactive`);
- sentinel grep: no sudo, no curl|bash of third-party scripts anywhere in
  install.sh or lib/platform.sh.

## What's next

- Real distro-matrix testing: Debian/Fedora/openSUSE/Alpine containers -
  verify every non-Arch package name, then flip platform.sh's honesty
  markers to verified. Add `--install` support for each manager (reusing
  bootstrap's per-manager install commands; the sentinel stays).
- Version checks beyond python3 (sbcl version floor for the kernel suite).
- The M-time vision link: this skeleton is the first rung of "a stranger
  clones and gets a working machine"; the full stranger path still needs the
  secrets/desktop story from peer-review finding 1 (machine profile + env
  contract exist; 1Password + operator desktop remain human steps).
