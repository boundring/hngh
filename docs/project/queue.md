# Queue — rotating long-term work

The rotation is the machine's patience: one row per item, and
`rotate-queue` turns the crank.

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
credential-rotation-auto	done		folded into key-rotation-freshness (retirement lane) 2026-08-27 — Full no-operator credential/token rotation + health alerts	2026-08-26 STATE 401; folds into key-rotation-freshness
pooled-hardware	queued	Pooled hardware / priced routes rung	README Where this is going
tunnel-automation	queued	Ambient-free tunnel keepalive	backlog boundary proposal
governance-benchmark	queued	Governance-benchmark research lane	backlog entry
push-self-sufficiency	done		ceremony-drive auto-push proven both repos 2026-08-27 — Repos push their own verified commits (sweep + post-validation)	operator directive 2026-08-26
cadence-continuum	queued	Timing tiers: month/week/day/hour/10m/5m/1m + ad-hoc	operator directive 2026-08-26
activity-cadence	queued	Routine project activities on the continuum (review→comms), fleet-scaled	operator directive 2026-08-26
governance-vocabulary	done		vocabulary relaxed; records use governance terms 2026-08-27 — Relax ritual/ceremony terms to flexible governance vocabulary	operator directive 2026-08-26; check-in-scale
agent-live-view	done		session observatory live on nerve center 2026-08-27 — Automatic subagent work view integrated into the dashboard	operator directive 2026-08-26; folds into ux-hardening
surface-evolution-loop	queued	Evolutionary design/development loop for all operator surfaces	operator directive 2026-08-26; extends dancing-ui + grade-interface
machine-steered-backlog	done		select-course pure use case + cadence wiring landed 2026-08-27 — Machine-gated governance: Hngh picks its own next-best-course continually	operator directive 2026-08-26; extends run-autonomous + rotate-queue
dss-e-export	queued	DSSE envelope export serializer	backlog entry
dashboard-readouts	done	Dashboard readouts (spiral + circular + dance styles live)	rotated 2026-08-25
timeline-events	done	Machine-readable timeline events per rotation	rotated by check-in #4 2026-08-25; Makefile + test wired
queue-eta	done	Planned-window (ETA) column on queue rows	implemented by check-in #5 2026-08-25
ux-hardening	queued	UX/interface pass (Emacs-style extensible operator surface)	imeline.md
ecosystem-integrations	queued	(CachyOS/Linux/dbus/system-harness/device integrations)	vision.md
zoom-out-loop	queued	Quarterly zoom-out market/news poll + candidate intake	timeline.md
marketplace-governance	queued	Marketplace-gov lane (audit/authorization of marketplace agents)	market-scope-2026-08-25.md
compliance-dashboard	queued	Freemium-hosted compliance dashboard + report export	market-scope-2026-08-25.md
ledger-format-standard	queued	Publish the ledger/cert format as an open standard	market-scope-2026-08-25.md
self-funding-plan	queued	Self-funding plan (sponsorship, hosted compliance, docs-first)	market-scope-2026-08-25.md
router-rearm-precheck	done	Router-side re-arm pre-check before report-queue --add	implemented 2026-09-01 in hngh-automation scripts/router-tick.py (commit 87e6bc3); fixture test + live closed-step re-fire skip demonstrated (reports.md row f9360a6e)
publication-lines-contract	done	Publication pipeline: wire research-lines into generate-publication or fix the 7-file contract	rotated 2026-08-31
ebook-book-inputs	queued	Ebook book-machine inputs to unblock the royalty-pipeline	publication-pipeline-grounding.md; backlog royalty-pipeline row
alert-plan-routing	done	Alert→plan-candidate routing loop (tick + production caller)	closed 2026-09-01: router-tick 87e6bc3 + router-feed caller 7992f78 (hngh-automation); first live routings reports.md bffc89a6 + ffa1d58e, auto-accepted f4c7e12e/9993c29d; already-routed skips observed 02:00:45Z
```
## Next

- **wake-mutation-lane** — rotate next (pins wake to the certificate lane; unblocks node-lattice admission). Set by check-in #1 2026-08-25.

## Scheduling

The rotation runner is operator-owned (the no-daemon boundary): install
a crontab entry that invokes `scripts/rotate-queue` for the next queued
item. Example (every 6 hours, in the repo):

```
0 */6 * * * cd ~/Projects/etc/hngh && STORE=$(mktemp -d -u /tmp/hngh-rotation-XXXX) && mkdir -p "$STORE" && sbcl --script scripts/rotate-queue --store="$STORE" --item=NEXT_ITEM --reviewer=~/.hngh-automation/reviewer-local.conf "Objective for NEXT_ITEM" <files> >> /tmp/hngh-rotation.log 2>&1
```

Each rotated item commits its own candidate through the full governance
loop (real evidence → real model review → ten-principle verdict →
certificate → mutation). The ledger flip rides in the same commit.

The autonomous heartbeat layer sits in front of that same runner: one
`scripts/schedule-heartbeat` tick probes the ledger + system preconditions
and triggers the mounted driver when an item is eligible, then records a
dated heartbeat entry with SHA-256 verification. It is the same
no-daemon rule — a cron or systemd timer invokes the tick, the tick
never backgrounds itself. Example (every 3 hours, in the repo):

```
0 */3 * * * cd ~/Projects/etc/hngh && python3 scripts/schedule-heartbeat --route=auto >> /tmp/hngh-heartbeat.log 2>&1
```

For a systemd user timer unit instead of crontab, see
[docs/project/heartbeat-service.md](heartbeat-service.md).
## Zoom-out pass log

- **2026-08-26** — zoom-out pass via activity cadence: digest 2026-08-26.md; candidate intake to queue ledger

A zoom-out pass polls market/news/opportunity sources and feeds new
queue candidates or reprioritization. Record each pass here (dated).

- **2026-08-25** — market-opportunity framing: captured in
  `docs/project/market-scope-2026-08-25.md`; added marketplace-
  governance, compliance-dashboard, ledger-format-standard, and
  self-funding-plan candidates to the ledger.

## Scale (calibration from check-in #2)

Which items are check-in-scale (small, one-session fix, could ride a
check-in) vs rotation-scale (a full rotate-queue session with model
review). Helps the cadence pick the right instrument.

- **check-in-scale:** timeline-events (machine-readable rotation
  events), queue-eta (ETA column), doc-number refreshes.
- **rotation-scale:** wake-mutation-lane, node-lattice-admission,
  bridge-operator-host, key-rotation-freshness, pooled-hardware,
  tunnel-automation, dashboard-readouts, ux-hardening,
  ecosystem-integrations, governance-benchmark, dss-e-export,
  marketplace-governance, compliance-dashboard,
  ledger-format-standard, self-funding-plan.

## ETA

Planned windows (operator-set; the TSV stays 4-field — ETAs live here).
Gives "future" a date so a gantt can place bars.

- wake-mutation-lane — next rotation (after a full session is carved,
  target ~this week)
- node-lattice-admission — after wake-mutation-lane
- queue-eta — DONE today (this widget is the item)
- bridge-operator-host — after node-lattice
- timeline-events — DONE (2026-08-25)
- others — on rotation, roughly one per cadence

## Interface-spec candidates (operator-requested "practical nonsense")

- **gantt-ports** — port the dashboard for many gantt options:
  axial/circular (clock-face rings), animated spirals, "crazy, dancing,
  wobbling" variants. Rotation-scale, after dashboard-readouts densifies.
- **dancing-ui** — interfaces that "dance" in time to music playing on
  the system, intensity varying with the track. Cross-project (omp +
  Hngh + local UI), a real UX-experiment backlog item; feasibility
  first probe (read system music source, map intensity to a CSS/js
  amplitude) before committing to the full dance.

## dancing-ui — status

- Probe (scripts/audio-intensity) is LIVE: reads the system's playing
  audio and returns 0..10; 0 when silent. Wire `--dance auto` in
  dashboard-readout to poll it; the full dance (amplitude to CSS/js,
  cross-project) is the next step after the readout hook.

## Fleet observation

- 2026-08-26 — fleet scan: no mesh session (tailscale logged out);
  system probes live (audio sink-inputs, D-Bus up, interfaces view).
  See [fleet.md](fleet.md).
