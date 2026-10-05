# Federation -- two PCs, one machine impression

Part of the system harness program: an any-Linux-system harness (early targets CachyOS and Omarchy, both Arch-based).

Status: draft (2026-10-03, harness-skeleton program Phase F2). Topology: this CachyOS workstation + the Omarchy SSD (nvme0n1) as the second machine (Phase E makes it bootable); laptop joins later on the same seams.

## 1. Existing seams (evidence)

- `src/adapter/federation.lisp` (+federation-methods+) and `src/application/admit-transport.lisp` -- node-lattice transport admission behind certificates. The kernel already models "admit a transport" as a use case.
- `hngh.domain.attestation` -- certificates as admission proofs (triple-kernel design: cross-kernel currency; node admission is legislation).
- automation/deck/tailscale-serve.sh, wake-desktop.sh, hngh-remote.desktop -- the operator already reaches machines across a tailnet.
- fleet.json + the map's fleet ring -- the surface that renders remote nodes.
- .ssh/authorized_keys already present on the Omarchy SSD's @home.

## 2. Design decisions

- **Transport: ssh + SQLite sync, no new broker.** Nodes sync crumbs.db/report-queue exports over tailscale ssh (pull model, cadence-tier pull (systemd timers) -- matches the four-tier engine; no daemon, kernel stays side-effect-free). Dolt-style refs sync (beads) is the precedent for git-remote-backed sync if queue federation outgrows cadence pull.
- **Identity: per-node machine-id + node certificate.** Admission = the existing admit-transport flow: a node presents a certificate minted by legislation; the peer verifies and records the transport. Bootstrapping = operator runs one ceremony command on the new node with the peer's public material (same trust path as 1Password service account seeding).
- **Queue federation: local-first.** Operator items stay on the node that observed them; a federated view MERGES open items (by identity:crumbs source hash) for the dashboard. Settlements (handle/dismiss) replicate as ledger rows; last-writer wins per item id, settled is terminal (matches settled-shape map semantics).
- **fleet.json expansion: node rows** {node-id, host, last-seen, open-attention, verdict} -- produced per node, merged by the dashboard's feed layer. The map (megastructure-sim P4) renders remote nodes as the far tower.
- **Secrets: two-home split per node.** ~/.hngh (data) vs ~/.hngh-automation (secrets) on BOTH machines; 1Password service account token seeds the second node the same way.
- **Time: monotonic windows, UTC stamps everywhere** (feeds already stamp UTC); playback/sim aligns on UTC.

## 3. What the operator sees

- The control room map shows two structures; the attention rail merges both nodes' open items with a node chip.
- Sessions stay node-local (session observatory shows the local node; a node picker later, not this program).
- Decisions made on either node settle into one merged view; a settled item settles everywhere after the next sync tick.

## 4. Stages

- F-a: node rows in fleet.json + ssh reachability (this program's Phase E proves the second node boots).
- F-b: queue merge view (dashboard feed layer) with per-node chips.
- F-c: certificate-based admit-transport between the two nodes (ceremony lane; plan draft rides Phase D's S2 entry point).
- F-d: laptop onboarding = repeat E+F-b with the same assets (no new code path -- that's the test of the design).

## 5. Non-goals this program

- No real-time messaging bus (cadence pull + SSE-on-local only).
- No shared filesystem (rsync/ssh only).
- No automatic node onboarding without an operator-confirmed certificate.
