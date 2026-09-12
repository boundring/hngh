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

## Wake-on-LAN (both directions, prepared 2026-09-11)

WoL is physical and LAN-local: magic packets are Ethernet/UDP
**broadcast** frames and **never cross tailscale** -- sender and target
must share the 192.168.0.x segment. No daemon runs either side (manual
operator scripts only).

- **Desktop -> deck**: `~/bin/wake-deck` (untracked operator tool) sends
  a magic packet to the deck's Wi-Fi MAC `90:03:71:3f:e1:64` (wlan0) on
  `192.168.0.255`. SteamOS support for WoL is limited; if the deck does
  not wake from soft-off/suspend, that is a hardware/firmware limit,
  not fixable in software.
- **Deck -> desktop**: `automation/deck/wake-desktop.sh` -- copy it to
  the deck the same way as the tailscale-serve shortcut (to
  `~/bin/` or `~/Desktop/` on the deck, `chmod +x`). It targets the
  desktop's wired NIC MAC `d8:43:ae:45:5d:1a` (enp14s0, 192.168.0.186).
  The desktop's `Wake-on` state needs one operator check/enable with
  sudo: `sudo ethtool enp14s0 | grep Wake` -- `Wake-on: g` required,
  else `sudo ethtool -s enp14s0 wol g` plus a persistent enable
  (systemd unit or NM dispatcher). NEVER send a wake packet to a
  machine that is awake.
- **GoPro false-network fix** (needs sudo, operator applies): the GoPro's
  USB interface (cdc_ncm, MAC `04:57:47:7c:ce:3e`) makes NM churn
  connections on dock/undock. Copy
  `automation/deck/gopro-nm-unmanaged.conf.example` to
  `/etc/NetworkManager/conf.d/gopro.conf`, then `sudo nmcli general reload`.

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

## Deck desktop shortcut

`automation/deck/tailscale-serve.sh` + `hngh-remote.desktop` make the
one remaining operator step a double-click on the deck. The serve
command itself runs on the **desktop** (the dashboard binds there); the
deck's userspace tailscale serves nothing -- the deck shortcut just
ssh-triggers it:

1. Copy both files to `~/Desktop` on the deck.
2. `chmod +x ~/Desktop/tailscale-serve.sh` (the .desktop `Exec` is the
   relative hint `./tailscale-serve.sh` -- the script must sit next to
   the entry; adjust the path if you install them elsewhere).
3. Right-click `hngh-remote.desktop` on the deck -> **Allow Launch**
   (SteamOS requirement for untrusted .desktop entries).

The script is idempotent: it checks
`ssh hngh-desktop tailscale serve status` first and exits 0 if 8890 is
already served; otherwise it runs `ssh -t hngh-desktop sudo tailscale
serve --bg 8890` (the desktop's sudo prompt appears in the deck's
terminal). Local precondition: the deck's tailscale must be up
(`tailscale --socket ~/.local/share/tailscaled/tailscaled.sock status`)
so the `hngh-desktop` ssh alias routes. If ssh fails the script says
"desktop unreachable -- check tailscale login on both ends". It is
**manual-run only** -- automation never invokes the serve step
(no-daemon rule).
