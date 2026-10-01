# Omarchy Hyprland layer on CachyOS (2026-10-01)

Date: 2026-10-01. Scope: login-screen session option; no boot-chain
contact (kernel/limine/initramfs untouched by design — see the
avoid-list in `automation/config/omarchy-base.packages`).

## State verified

- Wicket armed: the sudoers grant covers install-base/stage/install-file
  (`/etc/sudoers.d` root-only; `sudo -n -l` lists the three actions).
  Root copies byte-identical to the repo (md5 pair verified: wicket.sh
  d10e3d27..., omarchy-base.packages 1b5f3dfb...).
- Phase-1 session stack COMPLETE: `wicket install-base` rc 0
  ("nothing to do") and desk `run-phase-1` rc 0 after operator approval
  (desk-authz-phase-1 handled 2026-10-01). All base manifest packages
  present: hyprland 0.56.2, uwsm, quickshell, foot, portals, owe +
  owe-lockfeed, hyprpicker/hyprsunset, grim/slurp/cliphist/wl-clipboard/
  wtype/brightnessctl/pamixer/wireplumber/xdg-terminal-exec.
- `omarchy-core`/waybar/walker/anyrun/hyprland-plugins are NOT part of
  the phase-1 session-only manifest (and omarchy-core is upstream's
  meta-package, absent from every configured repo here). The session
  option does not need them; the manifest header records the derivation
  (omacom/omarchy @ quattro, clone commit 3faafba2).
- Laptop ground truth: no omarchy.desktop exists there either — Omarchy
  boots via `hyprland-uwsm.desktop` (`Exec=uwsm start -e -D Hyprland
  hyprland.desktop`). The desktop's labeled entry mirrors that shape.
- Readiness beat green (rc 0, reporting-only; d=true via
  hyprland.desktop presence).
- Note: the beat's session boolean matches only `hyprland-omarchy.desktop`
  or `hyprland.desktop`, so the labeled `omarchy.desktop` entry is
  invisible to it; d already passes via the pre-existing
  hyprland.desktop, and no beat change is planned.

## Operator actions (approval given; pasted in their terminal)

1. `/usr/share/wayland-sessions/omarchy.desktop` — Name=Omarchy entry,
   same uwsm exec line as the laptop's hyprland-uwsm.desktop.
2. `/etc/plasmalogin.conf` `Session=plasma` -> `Session=omarchy`
   (default at the greeter; Plasma stays selectable).
   Value shape: the shipped conf uses the bare session stem
   (`Session=plasma`), so the bare stem is the shape-consistent value;
   plasmalogin 6.7.4 is a stripped Qt/KF6 binary with no shipped
   example documenting a suffixed form.

Visual greeter/session confirmation happens at the operator's next
logout — asked, never forced.

## Follow-ups (not done)

- `waybar`/`walker`/`anyrun` desktop chrome from upstream Omarchy, if
  wanted later: separate package decision, not needed for the session.
- Desk phase-2+ phases if the operator ever wants the full upstream
  config adopt; the config-adopt path touches ~/.config only.
