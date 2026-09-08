# Remote access — the vacation topology

How to reach Hngh and this desktop from anywhere. Set up 2026-08-28.

## Topology

- **Desktop** `brickertop` — tailnet `100.83.36.27`, LAN `192.168.0.186`.
  sshd active (password + key). Dashboard (`hngh-dashboard.service`)
  binds `0.0.0.0:8890`. Tailscale daemon: system service.
- **Steamdeck** `steamdeck` — tailnet `100.79.162.3`, LAN `192.168.0.64`,
  user `deck`. Tailscale **userspace mode** (no root, survives SteamOS
  updates): `~/.local/bin/tailscaled` via
  `~/.config/systemd/user/tailscaled.service` (SOCKS5 on
  `127.0.0.1:1055`), state in `~/.local/share/tailscaled/`.

## From the deck, anywhere with internet

- **Dashboard**: `~/.local/bin/hngh-tunnel` → browse
  `http://localhost:8890`.
- **Shell**: `ssh hngh-desktop` (host alias in `~/.ssh/config` routes
  through `tailscale nc` — SteamOS has no `nc` binary; don't switch the
  alias to plain nc).
- Raw reachability check: `~/.local/bin/tailscale --socket \
  ~/.local/share/tailscaled/tailscaled.sock ping 100.83.36.27`.

## From any other device

Install tailscale, log into the same tailnet (`boundring@`), then:
dashboard at `http://100.83.36.27:8890`, ssh `bricker@100.83.36.27`
(key auth). For HTTPS instead of HTTP, run once on the desktop:
`sudo tailscale serve --bg 8890` → `https://brickertop.<tailnet>.ts.net`.

## Known limits

- **Power-on-when-off is physical**: WoL needs an always-on LAN sender
  (router WoL feature or smart plug + BIOS "AC power loss = Power On").
  If the desktop loses power remotely, wait until someone is home.
- **Security posture (2026-08-28, trip-hardened)**: all deck↔desktop
  traffic rides WireGuard (tailscale) — hostile networks see only
  encrypted UDP; ssh adds a second layer. Deck sshd is KEY-ONLY
  (`/etc/ssh/sshd_config.d/10-hngh-keyonly.conf`, password auth
  disabled). Desktop sshd: key auth works; password auth is still
  enabled — operator step to close it:
  `echo 'PasswordAuthentication no' | sudo tee /etc/ssh/sshd_config.d/10-hngh-keyonly.conf && sudo systemctl restart sshd`.
  ufw on the desktop blocks LAN :8890 by design; the dashboard is
  reachable only over the tailnet. Tailscale key expiry (~180d) is not
  a factor for week-scale trips.
- **Syncthing pairing deferred** (2026-08-28): both sides have binaries
  (`/usr/bin/syncthing` here, `decky-syncthing.service` on the deck) and
  zero configured folders; ssh+git+tailnet already carry all hngh state,
  so there is no concrete sync need — revisit when an offline-folder
  requirement exists.
- Steam Remote Play remains the full-desktop streaming channel (PC on);
  the tailnet path above is the headless work channel.
- The deck's tailscaled user service runs while the desktop-mode session
  is logged in; a full reboot requires logging back into desktop mode
  once (or `loginctl enable-linger deck` with sudo, follow-up).

## Device pairing route (repeatable)

The formal six-step procedure for connecting any new device to Hngh,
distilled from the Steamdeck pairing (2026-08-28):

1. **Tailscale join** — install tailscale (flatpak on SteamOS; static
   userspace tarball also works root-free), log into the operator's
   tailnet.
2. **Installer** — run `scripts/deck-setup.sh <desktop-tailnet-ip>` on
   the device (idempotent: userspace tailscale + wrapper, ssh alias,
   helpers, bashrc block, linger).
3. **Konsole mirror** — copy the desktop's Konsole profile AND its
   referenced .colorscheme files (a profile without its scheme falls
   back to white).
4. **Launchers** — the installer writes four .desktop shortcuts (Shell,
   omp, Dashboard, Watch) into ~/.local/share/applications and the
   desktop.
5. **Key exchange** — `hngh-keysync` (or ssh-copy-id) registers the
   device key with the desktop; register it with GitHub for
   desktop-down pushes.
6. **Verification** — `hngh-doctor` (5 checks) + the System-page remote
   posture card on the dashboard.

## hngh integration

- System page carries the live remote posture (tailscale state/IP, sshd,
  dashboard bind) via `jobs/system-feed.py probe_remote` (`89f3f36`).
- The hourly self-review is the natural home for a `hngh-remote` probe
  (tailnet reachable, dashboard serving over it) — follow-up wave.
- Kernel federation rungs (`admit-transport :federation`, `wake-peer`,
  `fetch-evidence`) are the eventual deck-as-node path; a deck-native
  hngh flatpak is a follow-up wave, not a dependency.
