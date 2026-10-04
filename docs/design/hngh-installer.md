# Hngh installer -- one scripted step family for any install on any OS

Status: proposed (2026-10-04, harness-skeleton program Phase E design input).
Requirements for the installer script family growing out of the E-phase work on the
powered-off Omarchy root (/dev/nvme0n1). Companions: `docs/design/omarchy-integration.md`
(gaps 1-8), `docs/design/harness-data-plane.md` (gap 4),
`docs/design/omarchy-gap-registry.md` (G1-G10, wicket law). Anchoring law: repo claims
carry `file:line`; target-root claims cite
`docs/records/2026-10-04-omarchy-drive-e1-census-e2-assets.md` (E1 census) or are marked
`target`; plan-only commands are marked **(encoded source)**, never called landed code.
The boot-window sequence itself is landed as `automation/jobs/omarchy-boot-build.sh`
(dry-run default, `--yes` at a TTY, `HNGH_BOOT_CONFIRM=YES` for scripted runs).

## 1. Purpose and principle

REQ-I1 (scripted steps). Any operation needed by ANY Hngh install on ANY OS becomes a
scripted, sudo-prompting step. A step requests sudo only when that step needs privilege;
every other step runs unprivileged. No standing root session: privileged acts stay
operator-typed blocks or route through the wicket contract
(`automation/lib/privileged.sh:1-14`; `docs/design/omarchy-gap-registry.md:20-25`).

REQ-I2 (fail closed). Every script: dry-run by default (adopt precedent: `--dry-run` /
`HNGH_CONFIG_ADOPT_DRY=1`, `automation/jobs/omarchy-config-adopt.sh:22,28`); apply mode
prints the exact privileged commands first; destructive steps refuse without `--yes` or a
typed confirmation; no tty and no `--yes` = refusal (`install-hngh-os.sh:473-476`).
Exit codes fixed: 0 ok, 2 usage, 3 fail-closed (`install-hngh-os.sh:14-15`). Nothing
half-verified proceeds.

REQ-I3 (sudo at the point of need). The one-password-moment pattern is the standard: sudo
runs inside the installer for exactly the step that needs it; non-interactive runs print
the commands as operator steps instead (`install.sh:529-571`, phase 6b). mkfs, mount,
arch-chroot, efibootmgr windows stay operator-supervised (section 5); automation verifies
their results, never types them.

REQ-I4 (provenance). Every run records what was requested, changed, and skipped. Reuse,
do not reinvent: the choices record (`install.sh:572-610`), breadcrumbs
(`automation/lib/privileged.sh:43-50`), the adopt per-file log
(`automation/jobs/omarchy-config-adopt.sh:71-110`).

Existing family inventory (build on these; do not fork the conventions):

| Script | Role | Family law it already encodes |
|---|---|---|
| `install.sh` | one-command public face | systemd never touched here; enable printed (`install.sh:2-11`); phase 6b one sudo moment (`install.sh:529-571`); phase 5 registry-driven companion services, register-only default (`install.sh:399-445`) |
| `automation/iso/profile/airootfs/root/install-hngh-os.sh` | full-disk ISO install + `--tier-migrate` | exit 0/2/3 (`:14-15`); `--yes` skips typed confirms (`:45-47`); chroot linger via file because loginctl needs a live logind (`:636-638`); firstboot tail unit (`:652`); port-owner verify (`:347-357`); recovery card (`:687`) |
| `automation/jobs/omarchy-config-adopt.sh` | Omarchy user-config adopt | dry-run (`:22,28`); copy / skip-identical / backup-then-copy (`:71-110`); uwsm env hook (`:13-17,142-167`) |
| `automation/jobs/omarchy-preflight.py` | read-only census | snapshot archive, 60s stamp, `--dry-run` prints plan (`:1-24`) |
| `automation/lib/privileged.sh` + `wicket.sh` | governed privileged channel | unarmed = exit 3 + printed bootstrap block (`automation/lib/privileged.sh:1-14`) |
| `automation/jobs/aur-build.sh` | AUR build, no sudo | stages the artifact, prints the `wicket install-file` follow-up (`automation/jobs/aur-build.sh:15`) |

## 2. Phase requirements

Seven phases, in order. Each is a script (planned home: `automation/jobs/`), idempotent
and resumable (section 4), each naming its own verification. Boot-window commands come
from the program plan's E3/E4 blocks **(encoded source)** -- landed as
`automation/jobs/omarchy-boot-build.sh` (phases `census|esp|build|qemu|adopt-check|all`;
hermetic proofs `automation/tests/test-omarchy-boot-build.sh`, registered in
`automation/Makefile`). (GAP-I1 is closed for 2.2-2.4; see Gaps.)

| Phase | REQ | Dry-run behavior | Destructive gate | Verification |
|---|---|---|---|---|
| census | REQ-I5 | default mode; prints the inventory, writes nothing | none (read-only) | archive written with manifest + sha256 (`omarchy-preflight.py:10-17`) |
| esp-format | REQ-I6 | prints the exact mkfs line, changes nothing | `--yes` or typed confirm; refuses w/o tty | `lsblk -f` shows vfat with the pinned volume id |
| mount + chroot-build | REQ-I7 | prints the mount/chroot/pacman/mkinitcpio/limine/efibootmgr block | per-command confirm or `--yes`; never batched with other phases | kernel payload + preset + initramfs + EFI entry present; linger file set |
| boot-proof | REQ-I8 | prints the qemu-img/qemu lines; never creates the overlay in dry-run | overlay-only writes; refuses if target would be written | guest reaches a logged-in desktop; real SSD untouched |
| config-adopt | REQ-I9 | adopt `--dry-run` (copy/skip/backup counts printed) | backup-then-copy is the worst case; no clobber | adopt summary + env-hook body pinned by `automation/tests/test-omarchy-config-adopt.sh:66-80` |
| mesh-setup | REQ-I10 | prints per-device key/address/sync/secret actions | key writes and secret reads gated; `--yes` or confirm | ssh both directions on every named pair; per-section checks below |
| post-boot verify | REQ-I11 | always safe; reads only | none (read-only) | :8890 owner, linger, timers, feed end-to-end |

### 2.1 census (REQ-I5)

Snapshot BEFORE any install/adopt action, read-only: user configs, avoid-list system files,
explicit package list (`automation/jobs/omarchy-preflight.py:1-12`), plus the boot-layer
facts the E-phase needed: ESP filesystem signature, `@/boot` contents,
`/etc/mkinitcpio.d/` contents, fstab ESP line, linger directory
(`docs/records/2026-10-04-omarchy-drive-e1-census-e2-assets.md:15-23`). Dry-run IS this
phase's default and only honest mode: nothing here may write.

### 2.2 esp-format (REQ-I6)

Destructive. The one encoded command **(encoded source)** (script phase `esp`;
refuses to touch a mounted ESP):

    sudo mkfs.vfat -F 32 -i 317A-31FF -n OMARCHY-ESP /dev/nvme0n1p1

The volume id is forced because fstab pins `UUID=317A-31FF` for /boot before the ESP
filesystem existed (E1 census, record :23); a default mkfs id breaks the pinned mount.
The script prints the command, names what it destroys (whatever is on the target partition
at run time), and refuses without `--yes` or a typed confirmation naming the device.
Verification: `lsblk -fs /dev/nvme0n1p1` reports vfat, label OMARCHY-ESP, and the pinned
UUID. Cross-reference: this closes the ESP half of `docs/design/omarchy-integration.md`
gap 4 (:245); the preset/hook half belongs to 2.3.

### 2.3 mount + chroot-build (REQ-I7)

Operator-supervised block, printed in full (arch-chroot stays a rescue tool,
`docs/design/omarchy-gap-registry.md:25`): mount `@` (+ `@home`, `@log`, `@pkg`) and the
ESP at the fstab-pinned mountpoint, then inside the chroot, in order:

1. `pacman -S --needed linux-omarchy limine` -- REINSTALL FIRST: /boot was bare, the
   kernel payload drops /boot/vmlinuz-linux-omarchy and creates
   /etc/mkinitcpio.d/linux-omarchy.preset; the preset dir was EMPTY, so `mkinitcpio -P`
   alone regenerates nothing (E1 census, record :16-21).
2. `mkinitcpio -P` -- regenerate initramfs into the now-present /boot.
3. limine EFI install via the omarchy tooling found by inspection
   (`ls /usr/bin | grep -i limine`; loader path finalized from that output, not guessed).
4. `efibootmgr --create --disk /dev/nvme0n1 --part 1 --label "Omarchy (limine)" --loader
   '\EFI\limine\limine.efi'`.
5. `touch /var/lib/systemd/linger/<user>` -- `loginctl enable-linger` fails in a chroot
   (no bus); the file-touch is precedent (`install-hngh-os.sh:636-638`).

Verification (scriptable, after the operator block): preset exists, initramfs under
/boot, EFI entry listed, linger file present. Closes the runtime-skeleton half of
`docs/design/omarchy-integration.md` gap 5 (:253) only once 2.6/2.7 also land.

### 2.4 boot-proof (REQ-I8)

QEMU boot of the real disk through a qcow2 overlay so guest writes land in the overlay and
nvme0n1 stays pristine **(encoded source)** (script phase `qemu`, kvm when `/dev/kvm`
is writable, TCG fallback):

    qemu-img create -f qcow2 -b /dev/nvme0n1 -F raw /tmp/nvme0n1-boot-test.qcow2
    sudo qemu-system-x86_64 -enable-kvm -m 8G -smp 8 \
      -drive file=/tmp/nvme0n1-boot-test.qcow2,format=qcow2,if=virtio \
      -bios /usr/share/ovmf/x64/OVMF_CODE.fd -vga virtio -display gtk

Requirements: OVMF present (`pacman -Q edk2-ovmf`, printed as an operator step when
absent); kvm optional -- `-enable-kvm` drops to TCG when /dev/kvm is inaccessible (E4
block), and the phase reports which mode ran. Refuses any variant that would open the
backing disk read-write. Success = guest reaches a logged-in Omarchy desktop; only then is
the physical reboot offered as a separate confirmed act. Failure text names the overlay
path so the operator can replay the boot by hand.

### 2.5 config-adopt (REQ-I9)

Runs the existing adopt seam, unchanged (`automation/jobs/omarchy-config-adopt.sh:13-17,
142-167`): copy / skip-identical / backup-then-copy of upstream `config/<rel>` into the
target home, plus the uwsm env hook pinning `OMARCHY_PATH`. Two added requirements:

- `OMARCHY_UPSTREAM_DIR` must resolve to a boot-valid HOST path (e.g.
  `~/Projects/etc/omarchy-upstream`), never a `/run/media/...` mount path --
  the env hook pins the path permanently and a removable-media path dangles at boot.
- The phase runs adopt `--dry-run` first and shows the copy/skip/backup counts as the
  point-of-risk confirmation body (dry-run census 2026-10-04: copy=0 skip=12 backup=5).

Verification: adopt exit 0; env-hook body byte-equal to the pinned body
(`automation/tests/test-omarchy-config-adopt.sh:66-80`); backups in the run record.

### 2.6 mesh-setup (REQ-I10)

The operator directive of 2026-10-04; full requirements in section 3. Dry-run prints the
per-device plan; each destructive or secret-touching step confirms separately; checks are
per section 3 requirement, not one aggregate exit.

### 2.7 post-boot verify (REQ-I11)

Read-only, always safe, runs on the booted target (or inside the QEMU guest):

- dashboard: :8890 answers AND is owned by the tier user (port-owner precedent
  `install-hngh-os.sh:347-357`); a listening port alone is not proof.
- linger: `/var/lib/systemd/linger/<user>` present, user manager reachable.
- timers: the `make enable` unit set active (`automation/Makefile:12-23`).
- feeds end-to-end: must not stop at "service up". Known dead hop: `update_dashboard`
  reads the wrong digest dir, data.json digest length observed 0
  (`docs/design/harness-data-plane.md:388`); verify checks a cadence run actually landed
  digest/queue content in the served JSON, else reports gap 4 by name. This phase turns
  gap 4 into an installer-visible failure, not a silent empty field.

Verification output is one card in the recovery-card idiom (`install-hngh-os.sh:687`):
target, boot entry, dashboard, verify commands, what remains operator-owned.

## 3. Mesh-setup requirements (operator directive 2026-10-04)

Evidence: ssh to the reference Omarchy laptop 192.168.0.16 failed with
`Permission denied (publickey)` (operator evidence, 2026-10-04) -- no key provisioned.
The installer PROVISIONS the mesh; it never assumes it. Each REQ is a mesh-setup sub-step
with its own dry-run, gate, and check.

REQ-I12 (cross-device SSH keys). For each of a user's devices, generate or copy the key
pair and install the public key into every peer's authorized_keys, key-only where policy
says so (deck precedent `automation/REMOTE-ACCESS.md:40-41`; desktop password auth still
on, closing it is an operator step, `:42-44`). Gate: key writes confirm at point of risk.
Check: `ssh -o BatchMode=yes <peer> true` succeeds both directions for every named pair --
empty output is a failure, exactly the 192.168.0.16 case.

REQ-I13 (address resolution: tailnet vs LAN). One host, two addresses; resolve each device
by role, not a hardcoded IP. Seed (extend, not replace): `automation/REMOTE-ACCESS.md:7-16`
records per device tailnet + LAN pairs (desktop `100.83.36.27` / `192.168.0.186`, deck
`100.79.162.3` / `192.168.0.64`). Requirement: a machine-readable device table (row: name,
tailnet addr, LAN addr, ssh user, role) driving mesh scripts and ssh config generation;
LAN preferred when reachable, tailnet otherwise; WoL stays LAN-only (broadcast never
crosses tailscale, `automation/REMOTE-ACCESS.md:63-66`).

REQ-I14 (syncthing per-device config backups). Both sides ship binaries with zero
configured folders ("Syncthing pairing deferred", `automation/REMOTE-ACCESS.md:48-50`);
that deferred state is the gap: pair devices and configure per-device backup folders for
config surfaces not in git (hngh homes; secrets dirs excluded, see REQ-I15). Gate: folder
paths and devices named in a typed confirmation. Check: the folder shows on both devices
and a test file round-trips. ssh+git+tailnet stay the primary state carriers; syncthing is
the config-fileshare backup lane, not a second source of truth.

REQ-I15 (1Password vault + per-machine local config). Secrets cross devices through the
1Password service account, never through mesh files: `OP_SERVICE_ACCOUNT_TOKEN` is the
headless seam (`docs/records/2026-09-09-1password-service-account-interface.md:17`),
least-privilege by scope (:21-24). Per machine the installer writes only the local shape
(env placement under `~/.hngh-automation/`, mode-600; the injection posture of
`docs/design/omarchy-integration.md` gap 6 (:260)); the token is placed as an
operator-confirmed act and never logged (REQ-I4 records that it happened, not its value).
Check: the credential-health seam can reach the vault (`automation/jobs/credential-health.sh`).

REQ-I16 (software targeted from other Linux installs). The carry-over set is data, not
code: the companion-services registry (`automation/config/hngh-services.tsv`, driven by
`install.sh:399-445`) gains rows for targeted software (disposition: install / configure /
register-only / skip). Default stays register-only -- recorded, nothing installed; an
explicit install prints the operator step and the package-manager command (system package
manager only, never a curl-piped script, `install.sh:5-8`). AUR candidates ride the
no-sudo build lane (`automation/jobs/aur-build.sh:15`).

REQ-I17 (themes, preferences, security settings). Porting is adopt-shaped: themes through
the theming map (`docs/design/omarchy-theming-map.md`), preferences through the 2.5 adopt
seam, security settings as a printed operator block (key-only sshd, ufw scope; posture in
`automation/REMOTE-ACCESS.md:36-46`). Same copy / skip-identical / backup-then-copy law;
never silent clobber of an existing machine's look.

## 4. Wizard QoL requirements

REQ-I18 (dry-run default). Every phase script defaults to plan-only: prints the exact
commands it would run (privileged ones verbatim), writes nothing. Apply mode is the
explicit opt-in (adopt's `--dry-run` / `HNGH_CONFIG_ADOPT_DRY=1`,
`automation/jobs/omarchy-config-adopt.sh:22,28`).

REQ-I19 (--yes for unattended). `--yes` accepts every typed confirmation in the run and
nothing else: never skips verification, never widens scope (`install-hngh-os.sh:45-47`).
No tty and no `--yes` = refusal with exit 2 and the rerun command printed
(`install-hngh-os.sh:473-476`).

REQ-I20 (resume / skip per phase). `--phase <name>` runs one phase, `--skip <name>` excludes
one; rerunning a completed phase is a no-op or a fresh verified pass (adopt skip-identical
`automation/jobs/omarchy-config-adopt.sh:71-110`; preflight stamp
`automation/jobs/omarchy-preflight.py:22-23`). A failed phase is retryable; state lives in
the REQ-I4 record, not the shell session.

REQ-I21 (plain-language confirmations at the point of risk). Each confirmation says what
changes, what it destroys or exposes, and how to undo it (recovery-card voice,
`install-hngh-os.sh:687`). Point of risk = destructive disk acts (2.2, 2.3), secret
placement (REQ-I15), key writes (REQ-I12), the reboot offer (2.4). Everything else is
read-only or covered by the phase-level `--yes`.

## 5. Packaged-release gating

REQ-I22. Which phases gate a release, and which stay operator-privileged:

| Phase | Release gate | Privilege posture |
|---|---|---|
| census (2.1) | YES -- green in CI/hermetic test | none (read-only) |
| esp-format (2.2) | no (per-machine destructive) | operator-supervised: printed mkfs block, typed confirm |
| mount + chroot-build (2.3) | no (per-machine destructive) | operator-supervised: chroot is a rescue tool, never automation (`docs/design/omarchy-gap-registry.md:25`) |
| boot-proof (2.4) | YES at the script level -- overlay creation + command assembly tested hermetically; actual boot is per-machine evidence | sudo for qemu only; backing disk read-only enforced |
| config-adopt (2.5) | YES -- seam already test-pinned (`automation/tests/test-omarchy-config-adopt.sh`) | unprivileged |
| mesh-setup (3) | YES at the script level; per-device acts are operator-confirmed | keys/secrets confirm at point of risk |
| post-boot verify (2.7) | YES -- read-only checks hermetically testable | none (read-only) |

Gating law: a release blocks on the scriptable phases tested end-to-end (census, adopt,
verify) and on the operator-privileged phases (esp-format, mount+chroot) being correct as
PRINTED COMMANDS -- reviewed text plus a hermetic test of the print/confirm logic, never a
privileged CI run. Matches the wicket posture: exact-command grants and printed operator
windows, never automated root (`docs/design/omarchy-gap-registry.md:20-25`;
`install.sh:529-571`).

## Gaps

GAP-I1 (closed 2026-10-04). `automation/jobs/omarchy-boot-build.sh` is in the tree with
hermetic tests (`automation/tests/test-omarchy-boot-build.sh`, 21 proofs, Makefile-registered);
the 2.2-2.4 encoded-source command sequences above are now executed by its
`esp`/`build`/`qemu` phases. Remaining gap: none for the boot window; mesh (GAP-I2) and
device table (GAP-I3) stand.

GAP-I2. Mesh key provisioning (REQ-I12) has no in-repo seam today: nothing generates or
distributes ssh keys, and `automation/REMOTE-ACCESS.md` records key posture by hand. The
REQ-I13 device table does not exist yet -- REMOTE-ACCESS.md is its seed, not its format.

GAP-I3. Post-boot feed verification (2.7) depends on the digest dead hop being fixed
(`docs/design/harness-data-plane.md:388`); until then the verify phase reports the gap by
name and cannot claim end-to-end feed health.

## Status

Proposed (2026-10-04). Awaiting operator review.
