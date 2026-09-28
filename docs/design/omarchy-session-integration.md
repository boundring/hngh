# Omarchy session integration: coexistence, boundaries, agentic seams

Date: 2026-09-28. Companion to `docs/design/omarchy-theming-map.md` and
`docs/design/omarchy-gap-registry.md`. Upstream reference: omacom/omarchy
v4.0.x, clone at `~/Projects/etc/omarchy-upstream` (commit 3faafba2, per
`automation/config/omarchy-base.packages:2`). All facts verified by reading
the cited files (or live host state, marked `host`).

## a. Session coexistence — no sddm.conf change, default session unchanged

The Hyprland wayland-sessions entry ships as a plain data file in the omarchy
tree: `default/wayland-sessions/omarchy.desktop` — `Name=Omarchy (Hyprland
uwsm)`, `Exec=uwsm start -g -1 -e -D Hyprland hyprland.desktop`,
`TryExec=uwsm` (read in clone). It is installed by packaging (uwsm is listed
at `install/omarchy-base.packages:140`; the file lands under
`/usr/share/wayland-sessions/` with the rest of `/usr/share`). Nothing in the
upstream install scripts writes `/etc/sddm.conf*`: the only SDDM-touching
script is `install/login/sddm.sh`, which solely strips
`pam_gnome_keyring.so` lines from `/etc/pam.d/sddm` (read in clone).
SDDM enumerates `/usr/share/wayland-sessions/` dynamically at login and
populates the greeter session list from it; upstream's own greeter theme
confirms this model — `default/sddm/omarchy/Main.qml:11-19` scans
`sessionModel` rows at runtime and merely preselects the row whose name
contains `uwsm`. On the host today the directory holds only
`plasma.desktop` (`host`, `/usr/share/wayland-sessions`), so after phase 1
Omarchy appears as a *second* entry; Plasma stays the default and picking is
a per-login operator choice.

**Decision:** zero `sddm.conf` change. Session selection is dynamic; the
upstream default-first-run autologin behavior (`install/user/first-run/`)
is an ISO concern and is explicitly not adopted.

## b. Bootloader — limine needs ZERO changes (decision, not a gap)

The boot chain is on the avoid-list: `automation/config/omarchy-base.packages:33-39`
excludes `linux-omarchy` (CachyOS 7.2.8-1 kernel stays), `limine-entry-tool`,
mkinitcpio hooks/UKI, sddm theme dropins, and plymouth, citing the phase-1
"session-only, no boot-chain contact" plan (`automation/config/omarchy-base.packages:3`).
Upstream scripts that *would* have touched these are hardware-conditional
(`install/hardware/nvidia.sh:24-26` mkinitcpio early-loading,
`install/hardware/apple/fix-t2.sh:27-30` and `install/hardware/asus/*`
`limine-entry-tool.d` dropins, `install/config/snapper.sh:24`
`limine-snapper-sync` timer) — none run in our lane because the manifest
never names their packages.

Because no kernel, no initramfs, and no bootloader entry change occurs,
**limine 12.9 + the existing mkinitcpio hook chain need zero changes — this
is a design decision (additive userland session stack), not an identified gap.**

## c. X11 today, Wayland only when picked — per-session portals

Ground truth 2026-09-28: `XDG_SESSION_TYPE=x11` (`host`), Plasma X11 entry in
`/usr/share/xsessions/plasmax11.desktop` (`host`), display-manager alias →
`plasmalogin.service` (`host`). Plasma remains the default session; Hyprland
runs only when picked at SDDM (section a).

Portals are per-session by design: xdg-desktop-portal selects backends via
`<wm>-portals.conf` (system: `/usr/share/xdg-desktop-portal/`, user override:
`~/.config/xdg-desktop-portal/`), so the two sessions never share a portal
config. Both backends are already in the phase-1 manifest:
`xdg-desktop-portal-hyprland` + `xdg-desktop-portal-gtk`
(`automation/config/omarchy-base.packages:11-12`; same pair upstream at
`install/omarchy-base.packages:148-149`). Upstream ships no
`portals.conf` at all (grep over clone: none) — Hyprland's portal package
registers itself for the Hyprland session.

**Phase 2 must place** (user-scope only): `~/.config/xdg-desktop-portal/hypr-portals.conf`
pinning `hyprland` + `gtk` backends, plus the uwsm env seam
`~/.config/uwsm/env.d/` — the override point upstream itself documents
(`default/uwsm/env.d/10-omarchy:7`, "Users can override these in
~/.config/uwsm/default or, preferably, ~/.config/uwsm/env.d/*"). This is gap
registry G9 (`docs/design/omarchy-gap-registry.md:45`).

## d. seatd verdict — nothing to enable, ever, in our lane

`seatd` is in the Arch `hyprland` package dependency list (`pacman -Si
hyprland` Depends On, `host`) and is therefore pulled in automatically by
phase 1 — it appears nowhere as an explicit entry in either manifest
(`automation/config/omarchy-base.packages`, `install/omarchy-base.packages`).
Arch's systemd preset does not enable third-party services on install
(`/usr/lib/systemd/system-preset/90-systemd.preset` covers only systemd's own
units; `host`); seatd.service is not present on the host and
`display-manager` is `plasmalogin.service` (`host`). Hyprland under a systemd
boot with uwsm/logind acquires its seat through logind — the uwsm session
wrapper is exactly what launches it (`default/wayland-sessions/omarchy.desktop:4`).
**Verdict: seatd.service stays disabled; no `systemctl enable` for seatd ever
occurs in our lane.**

## e. hngh-omarchy agentic integration (forward-looking; phases 3/4)

1. **Hyprland snippet (phase 3; depends on phase 1 install + G9 env seam).**
   User-scope drop-in `~/.config/hypr/hngh.conf.d/*.conf` (Hyprland reads the
   `hypr/` config dir user-scope; upstream keeps its own logic in
   `default/hypr/helpers.lua`, which routes app launches through
   `uwsm-app --` at `default/hypr/helpers.lua:160` — the snippet should do
   the same). Content: one `workspace = ws:hngh` assignment + a bind opening
   the newspaper/desk `http://127.0.0.1:8890` in the default browser on that
   named workspace. No root, no system config.

2. **owe wallpaper engine (phase 3; depends on 1 + desk IPC beat).**
   `owe` / `owe-lockfeed` are already phase-1 manifest AUR entries
   (`automation/config/omarchy-base.packages:30-31`; v4 ships no
   hypridle/hyprlock/hyprpaper — `automation/config/omarchy-base.packages:4`)
   and upstream first-run enables `owed.service` as a user unit
   (`install/user/first-run/enable-user-units.sh`). Daily themed editions:
   hngh beats push wallpaper directives to owe via its socat IPC — `socat`
   is in both package lists (`automation/config/omarchy-base.packages:22`,
   upstream `install/omarchy-base.packages:122`).

3. **Palette carryover (phase 4; depends on S7 theming map, already landed
   as G6).** The Blueprints hex set maps 1:1 onto omarchy tpl vars
   (`docs/design/omarchy-theming-map.md` table at lines 13-56, mix filters
   48-51, Hyprland decoration guidance section b lines 58-70). Filling
   `config/omarchy/themed/hyprland.lua.tpl` + `foot.ini.tpl` (+ quickshell/
   eww surfaces via theme-set.d hooks, `docs/design/omarchy-theming-map.md:10-11`)
   makes the Hyprland session match the KDE look; the omp/agent seam already
   exists as `pi.json.tpl` (`docs/design/omarchy-theming-map.md:108-116`).

4. **Combined interface (phase 4; depends on 3 + desk API stability).**
   hngh dashboard stays the agentic layer (newspaper UI, G5 desk endpoints);
   `desk-state.json` (dashboard-server.py endpoints per
   `docs/design/omarchy-gap-registry.md:41`) is embedded later as
   omarchy widgets — quickshell/eww panels reading the same JSON, so the
   Hyprland desktop and the browser desk render one state source.

## f. Trust boundaries recap

Nothing in this document grants root. Section a-c are *no-op* verifications
(no config writes at all); sections e are user-scope config files under
`~/.config/` adopted via the desk authorization flow (stage-authz → operator
approval → run, `docs/design/omarchy-gap-registry.md:68-74`). The privileged
surface remains the wicket: exact-command sudoers, root-owned manifest pin,
fail-closed when unarmed (`docs/design/omarchy-gap-registry.md:20-31`); the
boot chain is untouched by decision (section b) and seatd is never enabled
(section d). Two-home split and kernel `src/` surfaces remain untouched
(`docs/design/omarchy-gap-registry.md:78-81`).
