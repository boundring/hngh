# 2026-10-06 -- omarchy unattended install lane: driver, full flow, seed options, wizard

The Omarchy provisioning lane moved from operator-typed commands to a
governed GUI. Four landings, one lane, each gate-green and pushed.

## Landings

- `b2d13d7f` -- automation/jobs/omarchy-unattended-install.sh (NEW):
  phases seed | run | verify, dry-run default, --yes executes. Seed
  writes the cidata pair with schema provenance against the ISO's OWN
  omarchy-cidata-load (bare sfs-relative unsquashfs extraction; loud
  SCHEMA-UNVERIFIED fallback). Run defaults to the qcow2 pilot overlay
  over the backing disk (backing untouched); --real-disk is the explicit
  step behind a y/N gate naming the disk + FORMATTED. Verify boots the
  target disk-only with hostfwd 2222 and returns BOOTED+SSH /
  BOOT_ONLY / TIMEOUT, always killing its VM. Secrets live under
  HNGH_SECRETS_HOME (default ~/.hngh-automation/omarchy-unattended,
  0700); hashes redacted everywhere incl. stage logs.
- `32a2c115` -- the `full` phase: two-command operator flow (pilot chain,
  then full --yes --go-real which refuses without a green pilot
  manifest) and prints the fresh limine entry block via
  omarchy-boot-build.sh emit-entry (read-only) with hand-paste
  instructions for the host limine.conf.
- `0695492f` -- seed options: --package/--packages-from, --repo
  (custom_repositories: the CachyOS x86-64-v3/v4 repos plug in here),
  --service, --tailscale-authkey. Key-shape ground truth extracted from
  omarchy-4.0.4.iso: tailscale_authkey is a cidata FILE (sibling of
  authorized_keys), never a JSON key; packages/services JSON keys are
  genuinely consumed (loader copies user_configuration.json wholesale;
  orchestrator archinstall_adapter.py:23,27 add_additional_packages /
  enable_service). Authkey written as the cidata file, exactly-one-key
  validation, never printable.
- wizard (this record's commit) -- the installation desk gains a
  Winamp-skinned installer wizard (automation/dashboard/wizard.html +
  wizard-view.js + wizard.css, no framework, poll-chain only) served by
  automation/dashboard-server.py routes: /wizard-state.json assembly,
  iso-select / iso-download (https + hostname allowlist, curl child +
  pidfile), seed (synchronous driver exec), terminal (the privileged
  pattern), entry-preview. automation/tests/test-dashboard-wizard.py:
  27 proofs.

## The terminal-window authorization pattern (design decision)

Privileged steps (pilot, go-real, verify) are NEVER driven through HTTP.
The server spawns a real terminal window running the ENTIRE driver phase
command (HNGH_TERMINAL -> $TERMINAL -> kitty -> konsole -> alacritty ->
foot -> xterm; 409 with remediation when no display env). The operator's
sudo password and every y/N gate happen in that window; the per-tty sudo
timestamp covers the whole phase because the phase runs in the very tty
that authorized it. The wizard watches stage-log tails + pgrep -af
qemu-system liveness. Password material never crosses HTTP.

## Deliberate limits

- Wizard seed is defer-only: the POST route refuses non-defer seeds with
  remediation (credentials never cross HTTP; hashed-credential seeding
  stays a CLI act via --credentials-hash). Defer mode = passwordless
  install, first-boot user creation.
- Kernel swap stays manual: kernels ["linux-omarchy"] is boot-layer
  coupled (emit-entry template assumes it).
- Secrets/config porting from existing installs is a future `port`
  phase, not a seed flag.

## Verification

- make -C automation test GREEN at every landing (wizard landing:
  5m8s wall, incl. the 27-proof wizard suite and identifier lint).
- Whitespace-clean diffs enforced (git diff -w == git diff) after the
  edit-tool reformat fault seen earlier in this lane.
