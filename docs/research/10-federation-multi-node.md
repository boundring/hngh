---
category: federation/multi-node
persona: The Envoy
status: seed
anchored: 2026-10-03
note: automation anchors predate the 2026-10-04 control-room cut (broadsheet/ghost/wire surfaces retired)
---

# Federation & Multi-Node — what hngh runs today

Federation is kernel-shaped first and network second. `src/adapter/federation.lisp` declares a **closed method set** — `+federation-methods+ '(:carrier-bundle :http-claim)`, where carrier-bundle is operator-moved evidence bundles and http-claim is "the same carrier-bundle document fetched from a peer endpoint" (src/adapter/federation.lisp:17-21). Requests are strict: a bounded plain peer identifier (≤64 chars, no URL/path), a method outside the closed set errors, a malformed time window refuses the whole request, and `max-facts` bounds the claim set (:41-56,84-88). The transport is an injected `fetch-remote` port with the same complete/refused result shape as every other transport (:103-111,143-146). Claims are typed and bounded in `src/domain/attestation.lisp`: closed claim kinds (:content-hash :repository-revision :working-tree-status; :18-22), hard size bounds (payload 65536, signature 8192, claims 32, peer 64, skew 86400s; :26-39), and a closed key vocabulary (:rsa-sha256 :ed25519; :41-45). `:federation` is one of the five admitted transports (src/domain/governance.lisp:32-35).

The **fleet view** is deliberately shallow: `GET /fleet.json` shells `fleet-manager --json` one invocation ("no daemon, no ambient collector"), 30s cached, fail-soft to the last good payload but cold-start failures fail closed "instead of inventing an empty pool" (automation/dashboard-server.py:452-456,821-824). The newspaper composer refreshes fleet.json best-effort (fail-soft; automation/cadence/subhour/25-newspaper-compose.sh:18-26) and the broadsheet's 3D map overlays live fleet nodes onto seed nodes (automation/dashboard/broadsheet-view.js:12-16).

Physical-node reach is deck-first: `automation/deck/tailscale-serve.sh` + `hngh-remote.desktop` make the one remaining operator step a double-click (the serve runs on the desktop; the deck userspace serves nothing), and `automation/deck/wake-desktop.sh` sends a WOL magic packet to the desktop's wired NIC MAC `d8:43:ae:45:5d:1a` (automation/REMOTE-ACCESS.md:71-75,121-132). The installer bakes a NetworkManager dispatcher (`70-hngh-wol`) reapplying `ethtool -s wol g` on wired link-up (automation/iso/profile/airootfs/root/install-hngh-os.sh:620-630). The roadmap is explicit: kernel federation rungs (`admit-transport :federation`, `wake-peer`, `fetch-evidence`) are the eventual deck-as-node path (automation/REMOTE-ACCESS.md:115-117), and the phase-1 proposal pins the SteamDeck as a named federation peer with a dedicated store `~/.hngh-automation/store-deck` (docs/DECK-NODE.md:104-110). `research-tree.tsv:14` reserves `stage-7-federation` as a tree root.

## Open questions for web research

1. Carrier-bundle / sneakernet claim exchange formats — how do TUF and in-toto model offline-moved evidence with online verification?
2. Peer admission, pinning, and revocation in tiny federations (2-5 nodes) without a CA bureaucracy.
3. Clock-skew bounds (86400s chosen here) and freshness windows for remote claims — consensus-adjacent practice.
4. Wake-on-LAN + tailnet exposure: security/UX tradeoffs documented by home-fleet projects.
5. "Fleet as data" discovery (one-shot JSON, display-only) vs daemon-based service discovery — when does each suffice?

## Candidate external systems to survey

- TUF (The Update Framework)
- in-toto
- libp2p
- Headscale / Tailscale
- Syncthing (carrier-bundle analogues)
