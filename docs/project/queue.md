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