#!/usr/bin/env bash
# Deck-side, operator-run only: wake the desktop over LAN with a magic
# packet. Needs the deck on the home LAN (192.168.0.x) AND the desktop
# in a sleep state that honors WoL -- NEVER run it while the desktop is
# awake. Magic packets are LAN broadcast; they do NOT cross tailscale,
# so this only works when both machines are on the same Wi-Fi/LAN
# segment (the deck at home qualifies; over the internet it does not).
# No packages needed: SteamOS ships python3, which sets SO_BROADCAST
# for us (bash /dev/udp cannot send to a broadcast address).
set -u

DESKTOP_MAC="d8:43:ae:45:5d:1a" # brickertop enp14s0 (wired NIC, 192.168.0.186)
BCAST="192.168.0.255"

python3 - "$DESKTOP_MAC" "$BCAST" <<'EOF'
import socket, sys
mac = bytes.fromhex(sys.argv[1].replace(":", "").replace("-", ""))
pkt = b"\xff" * 6 + mac * 16
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
s.sendto(pkt, (sys.argv[2], 9))
print("magic packet sent to %s over %s" % (sys.argv[1], sys.argv[2]))
EOF

echo "sent. If the desktop did not wake: check the NIC wake state (operator, on the desktop):"
echo "  sudo ethtool enp14s0 | grep Wake  # 'Wake-on: g' required; 'd' means disabled"
echo "  sudo ethtool -s enp14s0 wol g     # enable persistently via a systemd unit or NM dispatcher"
