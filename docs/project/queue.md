# Queue — rotating long-term work

One row per queued item; `scripts/rotate-queue` advances rows through
`queued → active → done`. TSV, first line is the header. The full
proposal prose for each item lives in [backlog.md](backlog.md) (same
id); this file is the rotation state.

```
id	status	title	evidence
wake-mutation-lane	queued	Certificate-bound wake mutation lane	backlog boundary proposal; r17 record
node-lattice-admission	queued	Node-lattice admission rung	backlog entry; README vision
bridge-operator-host	queued	Bridge-as-operator-host (run → worker → review → certify)	backlog entry; bridge README
doc-sync-loop	done	Documentation-sync loop (make numbers guard)	rotated 2026-08-25 by rotate-queue
key-rotation-freshness	queued	Evidence-freshness + key-rotation rung	backlog entry; node-lattice risk
pooled-hardware	queued	Pooled hardware / priced routes rung	README Where this is going
tunnel-automation	queued	Ambient-free tunnel keepalive	backlog boundary proposal
governance-benchmark	queued	Governance-benchmark research lane	backlog entry
dss-e-export	queued	DSSE envelope export serializer	backlog entry
```
## Scheduling

The rotation runner is operator-owned (the no-daemon boundary): install
a crontab entry that invokes `scripts/rotate-queue` for the next queued
item. Example (every 6 hours, in the repo):

```
0 */6 * * * cd /home/bricker/Projects/etc/hngh && STORE=$(mktemp -d -u /tmp/hngh-rotation-XXXX) && mkdir -p "$STORE" && sbcl --script scripts/rotate-queue --store="$STORE" --item=NEXT_ITEM --reviewer=/home/bricker/.hngh-automation/reviewer-local.conf "Objective for NEXT_ITEM" <files> >> /tmp/hngh-rotation.log 2>&1
```

Each rotated item commits its own candidate through the full ceremony
(real evidence → real model review → ten-principle verdict →
certificate → mutation). The ledger flip rides in the same commit.
