# System-harness roadmap — a fleet of nodes under one governance

Hngh as a system harness + configuration + security manager across the
operator's fleet. Local and wide-area machines are a resource pool; each
is a node that is addressable, observable, and (only under evidence and
a certificate) actionable. The rungs below climb from the existing
node-lattice groundwork to steady benchmarking. Each rung: problem /
smallest useful outcome / dependencies / review trigger. Queue-item
mappings reference [queue.md](queue.md) ids.

## Rung A — node lattice (groundwork, in place)
**Problem:** a single node learns only from its own wall; a fleet needs
pinned admission before any pooling.
**Smallest useful outcome:** already landed — pinned federation peers,
wake-peer, distrusted-attestation, key pins, Ed25519 + carrier
signature transport.
**Dependencies:** promotional rungs 11–18.
**Queue mapping:** `node-lattice-admission` (queued extension),
`wake-mutation-lane` (next rotation), `bridge-operator-host`
(run → worker → review → certify, already the governance driver),
`key-rotation-freshness`.

## Rung B — resource pool view
**Problem:** the fleet is not yet a single pool; per-node status, duty,
health, and capabilities are not surfaced together.
**Smallest outcome:** one panel listing each admitted node as a row with
status / duty / health / capabilities, refreshing on demand; no ambient
collector (operator-owned heartbeat already exists).
**Dependencies:** Rung A pinned admission; `dashboard-readouts` panel
machinery.
**Review gate:** a reviewer accepts a rendered pool page whose rows all
trace to pinned, evidence-backed claims.
**Queue mapping:** `resource-pool-view` (new entry) + `pooled-hardware`
(rotating).

## Rung C — component-level status in the dashboard
**Problem:** per-node rows only; duties and health are granular but not
compositional. The operator wants "varying levels of dance-able
interfaces" per node — a node's surface should be graded and inkable,
from a static row to animated pods.
**Smallest useful outcome:** each node row renders its interface level
(quiet/static/motion) with the existing dance style live already in
dashboard-readouts; per-node components are first-class rows.
**Dependencies:** `ui-grades` + `dancing-ui` infrastructure.
**Queue mapping:** `ui-grades.md` (existing dance grades),
`dancing-ui` (interface-expansion rung), `ux-hardening` (Emacs-style
extensible surface), `assistant-overlay` (the operative layer the row
panels dress up).

## Rung D — agentic continuous configuration (declared config)
**Problem:** configuration is edited in place; rollouts are not
evidence-backed or reversible.
**Smallest outcome:** a per-node declared-config bundle whose intended
state after apply is read back into evidence; certificate-bound apply;
revert by reverting the declaration. No daemon: one tick per rotation /
cron, same as heartbeat.
**Dependencies:** the mutation executor (`:commit` action), `worker`
research, `config-manager` backlog entry.
**Queue mapping:** `config-manager` (new); model patterns for
NixOS/home-manager/Debian-adjacent forms.

## Rung E — security-manager duties
**Problem:** key rotation freshness, secret hygiene, patch-state
evidence, and incident-response evidence-chain are not surfaced across
nodes.
**Smallest outcome:** per-node patch-state and key-freshness evidence
rows (vintage of secrets scan, date of last rotate, patch delta) all as
`:remote-attestation`/machine-checkable facts; incident response = a
transparent event→record→certify chain.
**Dependencies:** rung B (pool view) + `key-rotation-freshness`.
**Queue mapping:** `key-rotation-freshness` (queued), `security-manager`
(new), `secret-scan-report`.

## Rung F — steady benchmarking / optimization
**Problem:** no steady, parameterized, repeated evaluation per node,
results into the ledger.
**Smallest:** a parameterized run per node (cost, time, quality) whose
results append to the ledger as evidence facts; no new daemon.
**Dependencies:** `governance-benchmark` (research lane) + worker-run
substrate (r18).
**Queue mapping:** `governance-benchmark`, `self-funding-*` (results
feed the value prop).

## What is not admitted
No daemon, scheduler, watcher, provider, or unbounded mutation. Every
apply sits behind a certificate; requests are explicit, recorded, and
human-closable. The node-pool view is a *view* (read-only render of
recorded facts), not an ambient controller.

## Review indexing for the roadmap
New rungs (`resource-pool-view`, `config-manager`, `security-manager`,
`notify-agent`, `ci-governance-gate`) must land as backlog entries in
[backlog.md](..) before any governance binding; each carries the
established Problem/Smallest/Evidence/Risk/Dependencies/Review trigger
shape.