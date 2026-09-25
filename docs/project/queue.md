# Queue — rotating long-term work

The rotation is the machine's patience: one row per item, and
`rotate-queue` turns the crank.

One row per queued item; `scripts/rotate-queue` advances rows through
`queued → active → done`. TSV, first line is the header. The full
proposal prose for each item lives in [backlog.md](backlog.md) (same
id); this file is the rotation state.

```
id	status	title	evidence
wake-mutation-lane	done	Certificate-bound wake mutation lane	landed 2026-09-13 through the certificate ceremony: :wake-mutation in the closed mutation vocabulary (src/adapter/mutation.lisp, src/domain/governance.lisp, tests/adapter/test-mutation.lisp, tests/domain/test-governance.lisp) binding the r17 wake surface; docs/records/2026-09-13-wake-mutation-lane-landing.md
node-lattice-admission	done	Node-lattice admission rung	rotated 2026-09-15
bridge-operator-host	done	Bridge-as-operator-host (run → worker → review → certify)	rotated 2026-09-16: certificate-gated session commits live through scripts/omp-bridge --ceremony (candidates 054f08f0, 9e0779b0, cf36b6f2 this week, ceremony-drive auto-push); bridge surface + worker-driver refusal + r13 reviewer + :model loadout all present; session watchdog visibility via --register handoff ledger; docs/agent-notes/jcode-orientation.md
doc-sync-loop	done	Documentation-sync loop (make numbers guard)	rotated 2026-08-25 by rotate-queue
key-rotation-freshness	done	Evidence-freshness + key-rotation rung	landed 2026-09-23 (row flipped on verified evidence): lib/credential-evidence.py fail-closed (ledger-missing/stale/hash-mismatch/evidence-missing/malformed) + 28 hermetic tests green, wired jobs/credential-health.sh section 7 with OLA cadence-params credential-fresh-ola=604800 (env CREDENTIAL_FRESHNESS_OLA); records docs/records/2026-09-16-credential-evidence-hardening.md + 2026-09-16-credential-freshness-rung-dead-legs.md; vault-cutover follow-through remains (env_vars.sh stub, docs/records/2026-09-21-vault-cutover-freshness.md)
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
crumbs-writer-flip	queued	Crumbs writer-flip (crumbs.db becomes source)	backlog entry; brief rec 2
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
ebook-book-inputs	queued	Ebook book-machine inputs to unblock the royalty-pipeline	research crystallized 2026-09-08: docs/research/2026-09-08-ebook-book-inputs.md (ceremony da3d441) — priced decision: per-book metadata input first (--chapters selection already landed); grow beat queued
alert-plan-routing	done	Alert→plan-candidate routing loop (tick + production caller)	closed 2026-09-01: router-tick 87e6bc3 + router-feed caller 7992f78 (hngh-automation); first live routings reports.md bffc89a6 + ffa1d58e, auto-accepted f4c7e12e/9993c29d; already-routed skips observed 02:00:45Z
```
## Struck rows (2026-09-24)

TSV rows stay unchanged for the rotation parser; the strike is recorded
here, adjacent to the rows.

- self-funding-plan - no aligned purpose in the foundation phase, 2026-09-24 (content/commercial lane; restore from git to re-open as a named future lane)
- ebook-book-inputs - no aligned purpose in the foundation phase, 2026-09-24 (content/commercial lane; restore from git to re-open as a named future lane)

## Completed rotations (folded 2026-09-24)

One dated line per done row. Prose that lived below the TSV for done
rows is folded here; the TSV rows keep the rotation state unchanged.

- 2026-08-25 doc-sync-loop - documentation-sync loop (make numbers guard), rotated by rotate-queue.
- 2026-08-25 dashboard-readouts - dashboard readouts (spiral + circular + dance styles live), rotated.
- 2026-08-25 timeline-events - machine-readable timeline events per rotation (Makefile + test wired), rotated by check-in #4.
- 2026-08-25 queue-eta - planned-window (ETA) column on queue rows (this widget is the item), implemented by check-in #5.
- 2026-08-27 push-self-sufficiency - repos push their own verified commits (sweep + post-validation); ceremony-drive auto-push proven both repos.
- 2026-08-27 governance-vocabulary - ritual/ceremony terms relaxed to a flexible governance vocabulary; records use governance terms.
- 2026-08-27 agent-live-view - automatic subagent work view integrated into the dashboard (session observatory on the nerve center).
- 2026-08-27 machine-steered-backlog - select-course pure use case + cadence wiring; Hngh picks its own next-best-course continually.
- 2026-08-27 credential-rotation-auto - folded into key-rotation-freshness (retirement lane); full no-operator credential/token rotation + health alerts.
- 2026-08-31 publication-lines-contract - publication pipeline: research-lines wired into generate-publication or the 7-file contract fixed.
- 2026-09-01 router-rearm-precheck - router-side re-arm pre-check before report-queue --add (hngh-automation scripts/router-tick.py, commit 87e6bc3).
- 2026-09-01 alert-plan-routing - alert -> plan-candidate routing loop closed (router-tick 87e6bc3 + router-feed 7992f78; first live routings reports.md bffc89a6 + ffa1d58e).
- 2026-09-13 wake-mutation-lane - certificate-bound wake mutation lane landed through the certificate ceremony (:wake-mutation in the closed mutation vocabulary); docs/records/2026-09-13-wake-mutation-lane-landing.md.
- 2026-09-15 node-lattice-admission - node-lattice admission rung rotated.
- 2026-09-16 bridge-operator-host - bridge-as-operator-host (run -> worker -> review -> certify) rotated; certificate-gated session commits live through scripts/omp-bridge --ceremony.
- 2026-09-23 key-rotation-freshness - evidence-freshness + key-rotation rung landed (lib/credential-evidence.py fail-closed + 28 hermetic tests); vault-cutover stub remains.

## Next

- **Land stage 2** — next queued (roadmap.md:198: nerve-center
  consolidation is in final verification; the config-backup lanes are
  scheduled on the 30m tier).

- pooled-hardware — re-queued 2026-09-25 with cause: stale Next (set
  2026-08-25, 31 days) and dep-circular — its open dep "resource pool
  view" is a backlog lane, not a queue item.

## Scheduling

The cadence owns the clock (the "operator-owned" note is obsolete; the
no-daemon boundary still holds: a cron or systemd timer invokes the
tick, the tick never backgrounds itself). Install a crontab entry that
invokes `scripts/rotate-queue` for the next queued item. Example (every
6 hours, in the repo):

```
0 */6 * * * cd ~/Projects/etc/hngh && STORE=$(mktemp -d -u /tmp/hngh-rotation-XXXX) && mkdir -p "$STORE" && sbcl --script scripts/rotate-queue --store="$STORE" --item=NEXT_ITEM --reviewer=~/.hngh-automation/reviewer-local.conf "Objective for NEXT_ITEM" <files> >> /tmp/hngh-rotation.log 2>&1
```

Cron runs with a minimal environment (`SHELL=/bin/sh`, bare `PATH`,
no login rc); if `sbcl` or `python3` live outside `/usr/bin:/bin`,
add explicit `SHELL=`/`PATH=` lines at the top of the crontab — see
[docs/project/heartbeat-service.md](heartbeat-service.md) for the
full note.

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

- **2026-09-01** — zoom-out pass via activity cadence: digest 2026-09-01.md; candidate intake to queue ledger

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

- **check-in-scale:** doc-number refreshes.
- **rotation-scale:** pooled-hardware, tunnel-automation, ux-hardening,
  ecosystem-integrations, governance-benchmark, dss-e-export,
  marketplace-governance, compliance-dashboard,
  ledger-format-standard.
- Done and struck rows' scale notes folded 2026-09-24 (check-in-scale:
  timeline-events, queue-eta; rotation-scale: wake-mutation-lane,
  node-lattice-admission, bridge-operator-host, key-rotation-freshness,
  dashboard-readouts, self-funding-plan).

## ETA

Planned windows (operator-set; the TSV stays 4-field — ETAs live here).
Gives "future" a date so a gantt can place bars.

- others — on rotation, roughly one per cadence
- DONE windows folded into Completed rotations (folded 2026-09-24)

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
