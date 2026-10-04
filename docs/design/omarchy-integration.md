# Omarchy integration — interface parts, plugin hosts, omp delta

Status: draft (2026-10-04, harness-skeleton program Phase E design input). Answers the
operator's three questions: which Omarchy parts to interface with, what a hngh Omarchy
plugin should host, what a hngh oh-my-pi plugin should do in Omarchy context. Companion
docs: `docs/design/omarchy-session-integration.md` (session coexistence, phases 1-4),
`docs/design/omarchy-gap-registry.md` (G1-G10), `docs/design/omarchy-theming-map.md`
(palette port). Anchoring law: repo claims carry `file:line`; target-root claims are
marked `target` (the mounted Omarchy root on /dev/nvme0n1p2, read 2026-10-04 at
/run/media/bricker/f5b8200b-76ee-41f6-a4dd-9216f8358836); anything not yet built is
marked **(design)** and never described as existing behavior.

## 1. Omarchy parts to interface with

Target facts (`target`): Omarchy 4.0.4 on /dev/nvme0n1p2 subvol @ (kernel linux-omarchy,
hyprland 0.56.2, foot, limine 12.8.0 + snapper-sync + mkinitcpio hook, ~300 `omarchy-*`
commands in /usr/bin). The boot layer is NOT provisioned: `@/boot` is empty (no kernel
image, no initramfs, no limine.conf). hngh touches exactly the user-scope layer plus its
own units; the boot chain and system defaults stay operator territory.

| Part | On the target today | hngh integration point | Mechanism | Seam |
|---|---|---|---|---|
| Hyprland config | `~/.config/hypr/{hyprland.lua,monitors,input,bindings,looknfeel,autostart}.lua` + `hyprsunset.conf`, `xdph.conf` (`target`); `hyprland.lua` bootstraps via `$OMARCHY_PATH/default/hypr/bootstrap.lua`, then `require`s Omarchy defaults then the user fragments | user fragments (`autostart.lua`, `bindings.lua`) — hngh entries are personal overrides loaded after Omarchy defaults | adopt (copy) from upstream clone; later: user-fragment edits | `automation/jobs/omarchy-config-adopt.sh:124-126` |
| foot.ini | `~/.config/foot/foot.ini`: `include=~/.local/state/omarchy/current/theme/foot.ini`, JetBrainsMono Nerd Font (`target`) | theme include point; hngh look lands through the theme file, never by clobbering the include chain | adopt (copy) if the clone ships `config/foot/` | `automation/jobs/omarchy-config-adopt.sh:135-140` |
| systemd user units + linger | `~/.config/systemd/user/default.target.wants/` holds only pipewire (`target`); `/var/lib/systemd/linger` empty (`target`) — no hngh units installed yet | dashboard service + cadence timers + `loginctl enable-linger` for the tier user | unit copy into `~/.config/systemd/user`, `systemctl --user enable --now`, `loginctl enable-linger` | `automation/Makefile:12-23`, `automation/iso/profile/airootfs/root/install-hngh-os.sh:331` |
| shell.json | `~/.config/omarchy/shell.json` v1: idle timers + bar layout of `omarchy.*` widget ids (`target`) | bar slot for the hngh widget (plugin `barWidget.defaultSection: right`) | adopt (copy) of upstream `config/omarchy/shell.json`; plugin rescan | `automation/jobs/omarchy-config-adopt.sh:128`, `automation/omarchy-plugin/boundring.hngh/manifest.json` |
| env.d | no `~/.config/uwsm/env.d/` on the target yet (`target`) | session environment: `OMARCHY_PATH` (has a seam), `HNGH_*` / `PATH` (gap registry G9) | adopt template write of `10-hngh-omarchy.conf` into `<home>/.config/uwsm/env.d/`, same write/skip/backup law | `automation/jobs/omarchy-config-adopt.sh:142-167` |
| limine / snapper | `/etc/default/limine` (`ESP_PATH="/boot"`, kernel cmdline `rootflags=subvol=@`), `/etc/limine-entry-tool.conf` + `.d`, `/etc/limine-snapper-sync.conf`, `/etc/snapper/configs/root` (`target`) | read-only for hngh; boot provisioning is the operator's E3/E4 windows | none (decision: no boot-chain contact) | avoid-list `automation/config/omarchy-base.packages:43-47` |
| omarchy-* tooling | `omarchy-shell`, `omarchy-plugin-{add,clone,validate,enable,disable,list,update}`, `omarchy-hook`, `omarchy-theme-set-pi`, `omarchy-notification-send`, `omarchy-state`, `omarchy-update-*` (`target`) | plugin install/validate, hook drop-ins, theme sync into the pi host, notification surfacing | invoke the shipped commands; never fork or patch them | `automation/tests/test-omarchy-plugin.py:14-22` (plugin contract pin) |

Per-part detail:

**a. Hyprland config.** The config is Lua-composed: `hyprland.lua` loads Omarchy defaults
then `hypr.monitors` / `hypr.input` / `hypr.bindings` / `hypr.looknfeel` /
`hypr.autostart` as user fragments that survive package updates (`target`). The adopt
seam copies the upstream clone's `config/hypr/*` into `~/.config/hypr/`
(`automation/jobs/omarchy-config-adopt.sh:124-126`) with copy / skip-identical /
backup-then-copy semantics and a `.bak` refusal on conflict
(`automation/jobs/omarchy-config-adopt.sh:71-110`). hngh content (a workspace + a bind
opening `http://127.0.0.1:8890`, per `docs/design/omarchy-session-integration.md`
section e.1) lands as edits to the user fragments **(design)** — never as edits to
upstream defaults.

**b. foot.ini.** The file delegates color to the generated theme
(`include=~/.local/state/omarchy/current/theme/foot.ini`, `target`). hngh look flows
through the theme (`docs/design/omarchy-theming-map.md`), and the adopt seam copies an
upstream `config/foot/` when present (`automation/jobs/omarchy-config-adopt.sh:135-140`).
No hngh-owned foot config is needed.

**c. systemd user units + linger.** This is the one place hngh installs persistent
machinery. `make enable` copies `automation/systemd/*.service|*.timer` into
`~/.config/systemd/user` and enables the timers plus `hngh-dashboard.service`
(`automation/Makefile:12-23`); the dashboard unit execs `%h/Projects/etc/hngh/automation/dashboard-server.py`
(`automation/systemd/hngh-dashboard.service:8`); cadence timers drive
`jobs/cadence-tick.sh` (`automation/systemd/hngh-cadence-calendar.service:9`,
`hngh-cadence-hour.service:13`, `hngh-cadence-subhour.service:9`), which runs
`cadence/<tier>/*.sh` drop-ins in lexical order under a per-tier flock
(`automation/jobs/cadence-tick.sh:2-11`). Linger is what keeps a headless tier user's
units alive: `loginctl enable-linger "$TIER_USER"` in the installer tail
(`automation/iso/profile/airootfs/root/install-hngh-os.sh:331`). Service verbs route
through the allowlisted `automation/scripts/service-ctl.sh:36` (system units are never
touched, `automation/scripts/service-ctl.sh:22`).

**d. shell.json.** Adopt copies upstream's file wholesale
(`automation/jobs/omarchy-config-adopt.sh:128`); the hngh bar presence is a plugin
concern (manifest `barWidget` block), not a shell.json edit. The widget polls
`/newspaper.json` for `queues.operator`
(`automation/omarchy-plugin/boundring.hngh/BarWidget.qml:53,63`) — the filename stays
even as the dashboard's front page becomes the control room, so this consumer does not
move.

**e. env.d.** The adopt seam owns this file: it writes
`<home>/.config/uwsm/env.d/10-hngh-omarchy.conf` pinning `OMARCHY_PATH` to the clone so
`hyprland.lua`'s `$OMARCHY_PATH/default/hypr/bootstrap.lua` resolves in dev-link mode —
and deliberately writes no `PATH` (upstream prepends `$OMARCHY_PATH/bin` itself)
(`automation/jobs/omarchy-config-adopt.sh:13-17,142-167`; the exact two-line body is
pinned by `automation/tests/test-omarchy-config-adopt.sh:66-80`). Same write / skip /
backup law as every adopt_file. Upstream documents `~/.config/uwsm/env.d/*` as the user
override point (`docs/design/omarchy-session-integration.md` section c). Residual gap
(G9): `HNGH_*` / `PATH` additions and the portals audit — **(design)** they land as
further env.d drop-ins, never as secrets (see section 2). Nothing has run on the target
yet: no `~/.config/uwsm/env.d/` exists there (`target`).

**f. limine / snapper.** Decision, not a gap: hngh reads, never writes. The phase-1
manifest's avoid-list excludes `linux-omarchy`, `limine-entry-tool`, and mkinitcpio/UKI
hooks (`automation/config/omarchy-base.packages:43-47`); the wicket's manifest pin
cannot name them. Provisioning the empty `@/boot` is the plan's privileged E3/E4
operator windows (mkfs ESP, mkinitcpio, limine install, QEMU boot proof) — exact
commands are printed for the operator to run, never automated by hngh.

**g. omarchy-* tooling.** hngh composes with the shipped CLI instead of reimplementing
it: `omarchy plugin validate|add` for the plugin lane (`target`;
PLUGINS_DIR `~/.config/omarchy/plugins` per `omarchy-plugin-add`), `omarchy-hook` runs
named hooks from `~/.config/omarchy/hooks/<name>[.d/]` (`target`) — hookable points on
the target are `battery-low.d`, `font-set.d`, `post-boot.d`, `post-update.d`,
`pre-refresh-pacman.d`, `theme-set.d` (`target`) — and `omarchy-theme-set-pi` syncs the
generated theme into `~/.pi/agent/themes/omarchy-system.json` (`target`), which is the
pi/omp theming seam `docs/design/omarchy-theming-map.md:108-116` anticipated.

## 2. What a hngh Omarchy plugin should host

The Omarchy plugin (`automation/omarchy-plugin/boundring.hngh/`, v0.1.0) is the desktop
expression of the dashboard; the repo's automation seams remain the source of truth.
What the plugin hosts, versus what it points at:

- **Bar widget + desk panel (exists).** The plugin directory hosts exactly four files —
  `manifest.json`, `BarWidget.qml`, `Panel.qml`, `README.md` (`target`-independent: see
  `automation/omarchy-plugin/boundring.hngh/`). The manifest declares one `bar-widget`
  kind with `entryPoints.barWidget`, `allowMultiple: false`, `defaultSection: "right"`,
  category `hngh` (`automation/omarchy-plugin/boundring.hngh/manifest.json`).
  `BarWidget.qml` shows `hngh N` from `queues.operator` (GET
  `http://127.0.0.1:8890/newspaper.json`) with `hngh ?` fail-open
  (`automation/omarchy-plugin/boundring.hngh/BarWidget.qml:53,63`); `Panel.qml` lists
  operator decision cards with `handle` / `park` (note required — the dashboard rejects
  noteless park) against the allowlisted `/operator-item/*` endpoints
  (`automation/omarchy-plugin/boundring.hngh/Panel.qml:32,126,164`; endpoint set pinned
  by `automation/tests/test-omarchy-plugin.py:14-22`). The plugin talks only to
  `127.0.0.1:8890` — no external hosts (same test pins it). README claims vs exists:
  the claimed contract (30 s bar poll, six endpoints, note-required park, fail-open) is
  all present in the files; the claimed status is honest — v0.1.0 structure validated,
  QML never exercised live because no `omarchy-shell` runs on the dev host
  (`automation/omarchy-plugin/boundring.hngh/README.md`).
- **Unit files: hosted by the repo, not the plugin (decision).** The dashboard service
  (`automation/systemd/hngh-dashboard.service`, port from `automation/config.env:77`,
  binds 0.0.0.0 for LAN/phone access) and the cadence-tick user units
  (`automation/systemd/hngh-cadence-{subhour,hour,calendar}.{service,timer}`) install
  via `make enable` (`automation/Makefile:12-23`) with linger enabled by the installer
  tail (`automation/iso/profile/airootfs/root/install-hngh-os.sh:331`). A QML plugin
  cannot own units; its README states the dependency and the failure mode (unreachable
  dashboard shows `hngh ?`, `automation/omarchy-plugin/boundring.hngh/README.md`).
- **Config adopt material: hosted by the repo.** `jobs/omarchy-config-adopt.sh` (hypr,
  shell.json, hooks, foot, plus the `uwsm/env.d/10-hngh-omarchy.conf` `OMARCHY_PATH`
  pin — section 1a-1e) plus `jobs/omarchy-preflight.py:2-7`, the pre-install/adopt
  snapshot into `<hngh-home>/db/omarchy/preflight-<UTC>.tar.zst`.
  **(design)** Hook drop-ins the plugin needs (e.g. a `theme-set.d` touch that refreshes
  the bar widget on theme change) ship in the plugin dir and are copied into
  `~/.config/omarchy/hooks/<name>.d/` at install — same copy-not-patch law as adopt.
- **Home skeletons: hosted by the repo.** Two homes, two laws. `~/.hngh` is userspace
  data (digests, db, archives) — `automation/lib/hngh_home.py:16-22`,
  `automation/lib/common.sh:11-15`. `~/.hngh-automation` is the control/credential home
  (tokens mode 600, permissions profile, service state, store):
  `automation/config.env:4,37-38,64,92`, `automation/install.sh:506`,
  `automation/lib/service-mgmt.sh:18`. Split law recorded in
  `docs/design/omarchy-gap-registry.md:78-81`. The plugin holds neither: it reads the
  dashboard API, never a home. Neither home exists on the target (E1 census); the
  install path creates both.
- **Secrets seam placement.** 1Password service account is the documented path: `op`
  binary seam `automation/lib/credentials.sh:17`, `OP_SERVICE_ACCOUNT_TOKEN` (mapped
  from `ONEPASSWORD_SERVICE_KEY`, `automation/lib/credentials.sh:26-27`, contract in
  `docs/records/2026-09-09-1password-service-account-interface.md`), file fallback
  under `~/.hngh-automation/` (`automation/lib/credentials.sh:45`). On Omarchy this
  placement is unchanged; `omarchy-install-service-1password` (`target`) may provision
  the 1Password app, but hngh's seam is the service-account token in the user-manager
  environment, never the app. **(design)** The G10 `LoadCredential=` migration
  (`docs/design/omarchy-gap-registry.md:46`) is the upgrade path for that injection.
- **Install/update path (all test-proven seams, reused as-is).**
  1. Preflight snapshot — `jobs/omarchy-preflight.py` (test `tests/test-omarchy-preflight.py`,
     `automation/Makefile:197`).
  2. Phase-1 packages through the wicket — `bash automation/lib/privileged.sh wicket
     install-base` over the root-owned manifest pin
     (`automation/dashboard-server.py:224-237`; sudoers law
     `automation/config/wicket.sudoers.example:50-54`).
  3. AUR add-ons through the no-sudo build lane — `jobs/aur-build.sh:3-19` (makepkg
     `--noconfirm`, never `-s`, never root; artifact staged via privileged.sh, follow-up
     `wicket install-file` printed; test `tests/test-omarchy-aur-build.sh`).
  4. Phase-2 config adopt — `jobs/omarchy-config-adopt.sh` (test `tests/test-omarchy-config-adopt.sh`,
     `automation/Makefile:203`).
  5. Units + linger + verify — `make enable`, `loginctl enable-linger`, `:8890`
     port-owner check (`automation/iso/profile/airootfs/root/install-hngh-os.sh:331-352`);
     retiering via `install-hngh-os.sh --tier-migrate`
     (`automation/iso/profile/airootfs/root/install-hngh-os.sh:337-362`, tested in
     `tests/test-iso-build.sh`).
  6. Plugin hand-install — copy `boundring.hngh` into `~/.config/omarchy/plugins` +
     `omarchy-shell shell rescanPlugins`, validate with `omarchy plugin validate`
     (`automation/omarchy-plugin/boundring.hngh/README.md`; contract pinned by
     `tests/test-omarchy-plugin.py`).

Explicit non-goals:

- No hngh pacman/AUR package and no new root surface: privileged acts stay inside the
  wicket (exact-command sudoers + root-owned manifest pin).
- No boot-chain writes — limine, snapper, mkinitcpio, kernel choice are operator/E3-E4
  territory (`automation/config/omarchy-base.packages:43-47`).
- No in-place patching of Omarchy upstream files or shipped `omarchy-*` commands;
  everything lands in user scope (`~/.config`, `~/.hngh*`).
- No external network from the plugin; `127.0.0.1:8890` only, pinned by
  `automation/tests/test-omarchy-plugin.py`.
- No new daemon: the dashboard server and the cadence timers already exist
  (`docs/design/omarchy-gap-registry.md` security posture).

## 3. What the hngh oh-my-pi plugin should do in Omarchy context

Current surface (exists):

- **MCP server `hngh`** (`automation/mcp/hngh_mcp_server.py`, stdio): five read-only
  tools wrapping repo CLIs — `hngh_present`, `hngh_status` (kernel CLI via the
  `HNGH_MCP_KERNEL`/`HNGH_MCP_KERNEL_CMD` seams,
  `automation/mcp/hngh_mcp_server.py:46-51`), `queue_report` (`scripts/report-queue
  --json`), `dashboard_readout` (`scripts/dashboard-readout --json`), `research_lines`
  (strict-reader TSV feed) — registry `automation/mcp/hngh_mcp_server.py:127-131`.
  Shared with Jcode by the same registration (`docs/records/2026-09-14-omp-coexistence-review.md:17`).
- **omp plugin `hngh-bridge`** (`automation/omp-plugin/package.json:11-14`): tools
  `hngh_propose` / `hngh_opencode` / `hngh_jcode` / `hngh_brief` wrapping
  `scripts/omp-bridge` (plan propose, governed delegation, orientation seeding), plus
  the `orient` extension entry.
- **Orientation injection.** `src/orient.ts` runs `python3 scripts/omp-bridge --orient`
  at `session_start` when the cwd is the hngh repo, injects the brief as a custom
  session message, dedups via the `com.hngh.orient` entry, 5 s bound, fail-open
  (`automation/omp-plugin/src/orient.ts:25,44,63`); the brief itself is queue Next +
  roadmap Next + working tree + last ceremony commit (`scripts/omp-bridge:291-318`).
  AGENTS.md states the same contract for agents that orient manually: run `--orient`
  once, prefer the MCP tools over re-reading repo files (`AGENTS.md:15-22`).

What changes when the omp host runs ON Omarchy — and what deliberately does not:

| Concern | Off-Omarchy (today's desktop) | On Omarchy (tier home) | Delta |
|---|---|---|---|
| Repo path | `~/Projects/etc/hngh` | must land at `~/Projects/etc/hngh` — the target has no `~/Projects` at all (E1 census); install/tier-migrate creates it (`automation/iso/profile/airootfs/root/install-hngh-os.sh:337`) | none in code — `bridgeCandidates` (`automation/omp-plugin/src/index.ts:21-22`) and `ExecStart %h/Projects/etc/hngh/automation/dashboard-server.py` (`automation/systemd/hngh-dashboard.service:8`) both hard-assume that path, so the repo checkout is a prerequisite, not a variant |
| Service discovery | `systemctl --user` + `scripts/service-ctl.sh` allowlist | identical; linger keeps the user manager alive (`install-hngh-os.sh:331`) | none |
| Dashboard reachability | `127.0.0.1:8890` | identical; dashboard binds 0.0.0.0 (`automation/config.env:77`), plugin and omp tools use loopback | none |
| Theme | pi theme hand-set | `omarchy-theme-set-pi` syncs `~/.local/state/omarchy/current/theme/pi.json` → `~/.pi/agent/themes/omarchy-system.json` (`target`) | zero code; the pi host inherits the Omarchy theme |
| Host facts | none in AGENTS.md | session lives inside the Omarchy desktop (hyprland, foot, hooks, plugin bar) | **(design)** one AGENTS.md addendum block |

Minimal delta **(design)**: one AGENTS.md addendum ("running on Omarchy": dashboard at
`http://127.0.0.1:8890`, service verbs via `scripts/service-ctl.sh`, bar widget is the
plugin's, theme synced by `omarchy-theme-set-pi`, boot chain off-limits). Nothing else:
the MCP tool names, the omp-plugin tool shapes, and the orient extension key on repo
presence, which holds on the Omarchy tier home exactly as it holds today. No new tools
for an Omarchy host — the five MCP reads plus the four bridge tools cover host state,
and anything host-specific that outgrows the addendum belongs to the roadmap's G9
(`docs/design/omarchy-gap-registry.md:45`), not to the plugin.

## 4. Gaps (no seam yet — stated, not designed around)

1. **env.d residual (G9).** The adopt seam writes only the `OMARCHY_PATH` pin
   (`automation/jobs/omarchy-config-adopt.sh:142-167`); `HNGH_*` / `PATH` additions and
   the portals/environment audit have no seam (`docs/design/omarchy-gap-registry.md:45`).
   On the target nothing is written yet — no `~/.config/uwsm/env.d/` exists (`target`).
2. **Plugin distribution.** `boundring.hngh` installs by hand-copy only; there is no git
   repo for `omarchy plugin add` (`automation/omarchy-plugin/boundring.hngh/README.md`).
3. **QML unexercised.** The widget/panel are validated structurally (manifest contract +
   endpoint pin, `automation/tests/test-omarchy-plugin.py`) but never run against a live
   omarchy-shell — none exists on the dev host. Bar placement in `shell.json`'s layout
   versus the manifest's `defaultSection` is likewise unverified.
4. **Boot layer unprovisioned on the target (E1 census).** `@/boot` is bare, and the
   preconditions are thinner than the plan's chroot sketch expected: `fstab` already
   pins an ESP by `UUID=317A-31FF` while `nvme0n1p1` is blank (no filesystem signature),
   `/etc/mkinitcpio.d/` is empty (no `linux-omarchy.preset`), and `HOOKS` carry no
   limine hook — so E3 must provision preset + hook plus the ESP filesystem, not merely
   regenerate an image. E3 (ESP formatted to the fstab-pinned UUID, mkinitcpio, limine)
   and E4 (QEMU boot proof) are operator-run privileged windows per the program plan.
   Target hostname is `brickertop-omarchy`.
5. **hngh runtime skeleton absent on the target (E1 census).** Zero hngh units
   (`~/.config/systemd/user` holds only `default.target.wants` with pipewire-pulse
   entries) and `/var/lib/systemd/linger` empty; no `~/.hngh`, no `~/.hngh-automation`,
   and no `~/Projects` under `@home/bricker` at all (`target`). Everything sections 2-3
   describe — homes, repo checkout at `~/Projects/etc/hngh`, units, linger, plugin dir —
   lands through the install path on a host that has none of it; `make enable` and the
   installer tail have run on no Omarchy system.
6. **Secrets injection is env-based.** Tokens reach processes via user-manager
   environment + mode-600 files under `~/.hngh-automation/`; the G10 `LoadCredential=`
   migration is unscheduled work (`docs/design/omarchy-gap-registry.md:46`).
7. **Update coordination (G8).** Coordinating omarchy/CachyOS updates with operator auth
   prompts has no design yet (`docs/design/omarchy-gap-registry.md:44`) — it will reuse
   the wicket action surface and pins-drift when built.
8. **AUR lane terminal step.** The no-sudo build stages the artifact and prints the
   `wicket install-file` follow-up (`automation/jobs/aur-build.sh:15`) — there is no
   unattended AUR install, by the wicket's law, not by oversight.
