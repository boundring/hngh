# 2026-09-12 -- privilege model: 1Password keyed access, sudoers delegation, checkbox grant surface

Design + implementation record for the two privilege questions hngh now
answers on purpose instead of by accident: how the automation tier enters
1Password (KEYED, never interactive re-auth), and how permitted sudo /
privileged automation is granted, scoped, and audited. Incident that
motivated it, live-state verification, fix, sudoers.d delegation design,
the checkbox profile spec (now shipped), and the btrfs time-travel
posture under the OS-harness vision
(docs/records/2026-09-11-operating-system-harness-vision.md).

## 1. The incident

1Password's updated desktop app prompted 4-5 times for `/bin/bash` CLI
access, each prompt demanding the system (sudo-level) password. The
prompts are the DESKTOP-APP INTEGRATION mechanism: the app ties CLI
authorization to the app session and re-asks per binary/app pair. That
mechanism is correct for the operator's interactive use and completely
wrong for unattended automation - an automation tier that can hit a
desktop-app unlock prompt is an automation tier that can stall at 3am
on a human secret.

## 2. Live state, verified read-only 2026-09-12

- `op` 2.39.0 (linuxbrew); `op account list` answers (AGENTS.md probe).
- Shell env: `ONEPASSWORD_SERVICE_KEY` present (1),
  `OP_SERVICE_ACCOUNT_TOKEN` present (0) - the mapping the interface
  record describes was NOT applied in the running session.
- Proof by scope: unmapped `op vault list` enumerated `Private` (+ 4
  more) in ~15 s - the DESKTOP scope; the service account deliberately
  excludes `Private`. With `OP_SERVICE_ACCOUNT_TOKEN` mapped from the
  service key, `op vault list` returned the service scope (etc.,
  Hobbies, Job hunt, Medical, School years - no Private) in ~1.5 s and
  `op whoami` answers.
- Verdict: the service-account keyed path WORKS RIGHT NOW. The prompts
  happened because nothing in the repo performed the mapping, so `op`
  fell back to desktop-app integration - exactly the mechanism that
  prompts.
- Repo-side gap found: no script under automation/ referenced
  `OP_SERVICE_ACCOUNT_TOKEN` at all; the mapping existed only in
  operator-env folklore.

## 3. Keyed access - the fix

Root cause fixed at the shared seam (automation/lib/credentials.sh),
which every secret consumer routes through: when `OP_SERVICE_ACCOUNT_TOKEN`
is unset and `ONEPASSWORD_SERVICE_KEY` is non-empty, the library maps and
exports it, so `op` ignores the desktop app entirely (documented op
behavior: with the service token set, desktop integration is bypassed).
A pre-set token is never overwritten; an empty key maps nothing, so the
envfile tier operators are unaffected. `op_ready()` now falls back to
`op account list` because `op whoami` lies under desktop integration
("not signed in" while per-command auth works) - the known quirk from
the 2026-09-09 interface record, folded in here.

Operator-side steps (done by the operator in 1Password's UI; hngh never
creates or rotates the account):

1. 1Password desktop app -> create a SERVICE ACCOUNT (Developer
   dashboard) with read-only access to exactly the vaults hngh needs
   (currently the 5 non-Private vaults already in scope).
2. Copy the token into the operator env declaration that already exists
   (~/.config/plasma-workspace/env/env_vars.sh, chmod 600, value never
   handled by hngh tooling) and
   `systemctl --user import-environment ONEPASSWORD_SERVICE_KEY`.
3. Desktop-app integration stays enabled for INTERACTIVE use; it will
   keep prompting for /bin/bash access and that is now cosmetic - the
   automation tier never rides it. Declining/re-granting the CLI grant
   cannot break hngh anymore.
4. Rotation: mint a new service-account token, swap the env value, next
   session uses it. No script changes; the old token dies with its
   expiry (service-account tokens are dated by design). If the env file
   is ever lost, the token is recoverable from the vault via the
   desktop-authenticated CLI (fallback documented in the interface
   record).
5. Verify (no secrets printed):
   `env | grep -c OP_SERVICE_ACCOUNT_TOKEN` after mapping; scope check
   is `op vault list` - Private absent == keyed path.

## 4. Sudo delegation - the sudoers.d drop-in design

Principle: key-based entry for secrets (section 3), SCOPED sudoers for
host actions, checkbox profile for everything else. hngh never edits
sudoers itself - /etc/sudoers.d is operator/cert surface; the repo
ships the validated TEMPLATE (automation/config/hngh-automation.sudoers.example)
and the operator installs it:

    visudo -cf automation/config/hngh-automation.sudoers.example
    sudo install -m 0440 <validated copy> /etc/sudoers.d/hngh-automation

Template law (enforced by test-permissions.sh):

- exact commands with exact args via Cmnd_Alias - NEVER `NOPASSWD:ALL`
  (the test greps non-comment lines for NOPASSWD:ALL);
- only genuinely-root classes admitted today: `paccache -r`, `paru -Sc`
  (cache hygiene; installs/upgrades stay operator-run), `ethtool wol`,
  `btrfs subvolume snapshot|list` (section 6);
- `systemctl --user` deliberately ABSENT: user units need no root, and
  `sudo systemctl --user` as root would target root's manager - wrong
  target, so the class does not exist;
- no `btrfs subvolume delete` in the grant: restore is snapshot-over;
  deletes stay operator-run;
- audit: every sudo call is already breadcrumb-logged by hngh
  (lib/breadcrumbs.sh) AND independently journaled by sudoers itself -
  two trails, neither under hngh's control.

## 5. The checkbox grant surface (public installer)

ONE authoritative grant surface: automation/config/permissions-profile.json
(shipped default = everything denied). The installer seeds from it
(`--profile FILE` to start from a stricter/looser seed), renders
checkbox prompts on a TTY (or takes the seed as-is non-interactive),
and writes the resolved profile to
~/.hngh-automation/permissions-profile.json (env seam:
HNGH_PERMISSIONS_PROFILE). hngh machinery reads grants ONLY through
automation/lib/permissions.sh (perm_load/perm_validate/perm_granted):
the file's PRESENCE + VALIDITY is the admission - fail-closed means a
missing profile is minimum grants and an invalid one is minimum grants
+ a loud error; nothing can be widened by hngh discretion.

Schema (v1):

    {
      "version": 1,
      "secret-access": "1password" | "envfile" | "none",
      "host-actions": { "snapshots": bool, "package-updates": bool,
                        "wol": bool },
      "file-paths": ["/absolute/dir", ...],   # no "..", validated
      "social-posting": bool,
      "kernel-gates": "operator-only"          # the ONLY admitted value
    }

- secret-access: which tier may read secrets at all (1password keyed
  path per section 3; envfile = file fallback only; none = dormant).
- host-actions.*: 1:1 with the sudoers Cmnd_Alias classes; false means
  the corresponding sudoers line is commented out at install.
- file-paths: the scope for per-directory time travel (section 6) and
  the general "these directories are hngh's working surface" grant.
- social-posting: public social surfaces stay dormant while denied
  (docs/records/2026-09-11-social-surfaces-policy.md is the policy).
- kernel-gates: hardwired operator-only - certificate ceremony,
  src/, tests/, Makefile are never hngh-discretion (this record only
  makes the pre-existing boundary machine-readable).

## 6. btrfs time travel - the canonical "fancy" grant

The OS-harness vision names per-directory btrfs snapshots/restorations
as in-stream agent time travel. Posture: it is an ORDINARY checkbox
grant, not a special mechanism. `btrfs subvolume snapshot` needs root
even when the tree is user-owned (the snapshot target is the parent
subvolume), so the design maps it to the sudoers drop-in: `HNGH_BTRFS_SNAP` admits
exactly `btrfs subvolume snapshot` and `btrfs subvolume list`, scoped
in the profile by file-paths (the time-travel root(s), e.g.
/srv/hngh-time-travel). Machinery (future slice) would snapshot the
directory before an agent mutation and restore by re-snapshotting the
old state over the new - no delete grant, no rm-class sudo class ever.
Until that slice exists, the grant is inert: the checkbox only admits
the sudoers class.

## 7. Tests + verification

automation/tests/test-permissions.sh (hermetic, 0.5 s): default profile
minimum; 7 malformed variants rejected with fail-closed stays; missing
profile minimum; granted profile flips exactly its classes; sudoers
template has no NOPASSWD:ALL and parses under `visudo -cf`; installer
--profile non-interactive writes the resolved profile + choices record;
TTY checkbox run flips only the granted class (piped stdin - `script`
spins on file-backed stdin, use a pipe). test-credentials.py gains the
mapping contract (service key reaches op; pre-set token wins).

Related: docs/records/2026-09-09-1password-service-account-interface.md
(the interface contract this record wires shut),
docs/design/autonomous-development-control.md (operator-gated domains),
automation/config/env.example (key names only).
