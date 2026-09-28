# 2026-09-27 -- wicket: the governed privileged-action channel for package operations

Design + implementation record for the wicket: hngh's ONE sanctioned path
from the automation tier to root for package operations on the
operator's CachyOS host. Motivated by omarchy phase-1
(docs/records/2026-09-12-privilege-model.md remains the base privilege
law; the wicket extends it with a root dispatcher instead of widening
any sudoers surface). Files: automation/lib/wicket.sh (dispatcher),
automation/lib/privileged.sh (user-side seam),
automation/config/wicket.sudoers.example (delegation template),
automation/tests/test-wicket.sh (hermetic suite).

## 1. The law

ONE exact-command sudoers entry pointing at a root-owned dispatcher;
the dispatcher internally allowlists actions against a root-owned
package manifest; everything fail-closed; every execution logged.

- NEVER a persistent root shell, NEVER NOPASSWD:ALL, NEVER interactive
  sudo from automation. The granted command is exactly
  `/usr/local/lib/hngh/wicket.sh install-base` - argument included - so
  there is no way to ask the dispatcher for anything but its one
  reviewed action.
- The manifest (automation/config/omarchy-base.packages, installed to
  /usr/local/lib/hngh/omarchy-base.packages) is root-owned 0444: the
  automation user cannot change the package SET root will install.
- Fail-closed: unknown argv -> usage rc 2; missing/unreadable manifest
  -> rc 4; zero installable packages (all-AUR, comment-only, empty) ->
  rc 4, refusing the empty transaction; pacman absent -> rc 4; pacman
  rc propagates. The dispatcher never prompts (--noconfirm is
  mandatory in the exec'd command line).
- Two audit trails: the dispatcher logs every execution
  (`logger -t hngh-wicket`, before-line with pkgs count + manifest
  path, after-line with rc), and sudoers logs the sudo hit
  independently (journalctl/syslog). The seam additionally crumbs
  best-effort (lib/breadcrumbs.sh).

## 2. Threat model

- Manifest tamper: CLOSED by root ownership. The manifest pins the SET
  of packages; 0444 root:root means the automation tier cannot widen it
  without already having root - at which point the wicket is moot.
- Dispatcher swap: CLOSED by order of operations in the bootstrap
  window - the dispatcher is installed root-owned 0755 BEFORE the
  sudoers grant lands. An exact-command grant to a user-writable script
  would be an arbitrary-root shell in waiting (the user edits the
  script sudo runs); the window makes that state unreachable.
  visudo -cf gates the drop-in install.
- Package install scripts: KNOWN CEILING, deliberately accepted.
  Arch packages carry .INSTALL hooks; once pacman runs them, code
  executes as root. The root-owned manifest pins the package SET, not
  the behavior of its members - this channel is trust-on-manifest
  (same trust the operator exercises on every -S, now delegated).
  `# ponytail:` upgrade path if the operator asks: pin hashes/keywords
  per package in the manifest and have the dispatcher verify before
  exec.
- Sudo timestamp inheritance: DOES NOT APPLY. The common fear - a
  15-minute sudo timestamp letting later commands through - is
  irrelevant here: NOPASSWD grants need no timestamp, and the grant is
  one exact command. `sudo -n` in the seam never prompts; if a
  password would be required the check fails soft to "not armed".
- Prompt-stall at 3am: CLOSED. `--noconfirm` is mandatory; `sudo -n`
  never prompts; nothing on this path can wait on a human.

## 3. Bootstrap window (operator, one time, in this order)

From the hngh repo root (this block is printed verbatim by
automation/lib/privileged.sh when the wicket is not armed; keep in
sync with config/wicket.sudoers.example):

    # (a) dispatcher: root-owned 0755, not writable by the user
    sudo install -D -o root -g root -m 0755 automation/lib/wicket.sh /usr/local/lib/hngh/wicket.sh
    # (b) manifest: root-owned 0444 — root ownership is what makes the
    #     package-set pin real (the user cannot edit what root will install)
    sudo install -o root -g root -m 0444 automation/config/omarchy-base.packages /usr/local/lib/hngh/omarchy-base.packages
    # (c) validate + install the sudoers drop-in (the one password moment)
    visudo -cf automation/config/wicket.sudoers.example && \
      sudo install -m 0440 automation/config/wicket.sudoers.example /etc/sudoers.d/hngh-wicket

The grant line itself (placeholder username `hngh`, rename to the tier
user):

    hngh ALL=(root) NOPASSWD: /usr/local/lib/hngh/wicket.sh install-base

## 4. The seam (what automation may call)

    automation/lib/privileged.sh wicket <action>

- Armed check first: `sudo -n -l -U "$(id -un)"` (never prompts,
  10s timeout, fail-soft) and grep for `wicket.sh install-base`.
- Not armed -> stderr starts exactly `wicket not armed:` followed by
  the bootstrap block (section 3), exit 3.
- Armed -> `sudo -n /usr/local/lib/hngh/wicket.sh <action>`, crumb
  best-effort, exit code propagated.

## 5. What is NOT armed until the operator runs the window

Nothing. Before the bootstrap block runs: no dispatcher exists at
/usr/local/lib/hngh/wicket.sh, no manifest at
/usr/local/lib/hngh/omarchy-base.packages, no drop-in in
/etc/sudoers.d/, and the seam exits 3 on every call. There is no
partial arming state - (a)/(b)/(c) land as one decision, and any
re-run is idempotent. Nothing in this change touches install.sh,
systemd units, or the existing hngh-automation.sudoers.example; no
test exercises real sudo (the suite stubs it).
