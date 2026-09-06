# The Descent

Status: DESIGN — 2026-09-06. The cyclical loop that governs self-improvement.

Cross-links: [display-register-spec.md](display-register-spec.md),
[presentation-boundary.md](presentation-boundary.md),
[bestiary.md](bestiary.md),
[writing-register.md](writing-register.md),
[autonomous-development-control.md](autonomous-development-control.md),
[roguelike-agentic.md](../project/roguelike-agentic.md),
[master-plan.md](../project/master-plan.md),
[roadmap.md](../project/roadmap.md).

## The loop

Self-improvement here is a cycle, not a ladder. One pass through the six
stations is one Stratum (see the Lexicon). The cycle feeds itself: a failure
classified at one station becomes a research demand at another, and the final
station measures what the loop consumed — not what it produced.

The stations carry dual names. The canonical name is the boring one; the
display alias is the flavored one. Scope rules are in the Lexicon and in the
[display register](display-register-spec.md).

## Stations

### 1. Observe / Lookout

- **Inputs:** cadence probes, session transcripts, ledger tails, report
  queues.
- **Outputs:** alert rows in the report ledger, lesson harvests, watchdog
  handoff rows, breadcrumbs.
- **Exists today:** the oversight tick runs deterministic probes every
  5 minutes — stale ceremony stores, working-tree skew, gate-red
  escalation, ui-audit regression, repeat breadcrumbs, loop signals,
  system headroom, slow units (`hngh-automation/jobs/oversight-tick.sh`).
  Session phase classification (discovering / writing / verifying /
  stalled / terminal) is a pure function over transcript counters
  (`hngh-automation/jobs/agent-supervision.py`, `classify()`). The daily
  lesson harvest scans records and the handoff ledger into
  `docs/project/lessons-<date>.md`
  (`hngh-automation/cadence/day/01-lesson-harvest.sh`).

### 2. Disposition / Verdict

- **Inputs:** alerts and failures from Observe.
- **Outputs:** one cause class per failure and one route per cause
  (see [bestiary.md](bestiary.md)).
- **Exists today:** the kernel owns the closed failure-disposition policy
  ([autonomous-development-control.md](autonomous-development-control.md),
  "Failure disposition"). The router maps alert identities to plan
  candidates with dedup and daily escalation
  (`hngh-automation/scripts/router-tick.py`); plan acceptance is a
  deterministic gate over runnable verification plus green `make test`
  in both repos (`hngh-automation/scripts/accept-plans.py`).
- **Designed, not built:** automatic cause classification of a failure
  row into a bestiary class. Today a human or an agent reads the alert
  and classifies it; the router routes identities, not causes.

### 3. Research / Delve

- **Inputs:** research demands — routed from Disposition, seeded from the
  subject list, or written by the operator.
- **Outputs:** crystallized research lines in `docs/research/`, one file
  per line.
- **Exists today:** the day-tier research beat advances one line per beat
  through planned → expanding → contracting → crystallized and writes
  the crystallized result into the kernel's `docs/research/`
  (`hngh-automation/cadence/day/05-research-beat.sh`; state in
  `hngh-automation/research-lines.tsv`). All 22 lines crystallized by
  2026-08-31; the beat has idled since, filing nothing.
- **Designed, not built:** the demand wire. Nothing auto-appends a
  missing-knowledge or missing-design cause to the subject list; the
  beat only advances lines that already exist. Until that wire lands,
  Disposition cannot feed Research, and the loop breaks at station 3.
  The research-line review transition (a line passes a fresh-eyes
  review before it may be adopted) is specified here and unbuilt; the
  daily review beat (`hngh-automation/cadence/day/04-review-prep.sh`)
  reviews commits, not lines.

### 4. Adopt / Loot

- **Inputs:** reviewed, crystallized lines.
- **Outputs:** backlog rows with named consumers.
- **Exists today:** the backlog is the admission surface
  ([backlog.md](../project/backlog.md)); every row already requires a
  problem, outcome, evidence, risk, dependency, and review trigger.
- **Designed, not built:** the adoption gate (below). A crystallized
  line can currently sit forever with no consumer; 22 of 22 sit exactly
  there as of 2026-09-06.

### 5. Grow / Forge

- **Inputs:** adopted backlog rows, routed plan candidates, admitted
  certificates.
- **Outputs:** landed changes, each through the standing gates.
- **Exists today:** the hourly workbeat and the overnight cycle execute
  accepted plans (`hngh-automation/cadence/hour/20-workbeat.sh`,
  `hngh-automation/scripts/overnight-cycle.sh`); kernel changes pass
  ceremony-drive under certificate
  ([autonomous-development-control.md](autonomous-development-control.md)).
  The grow/research alternation is the master plan's stage 5/6 rule
  ([master-plan.md](../project/master-plan.md) §4).
- **Designed, not built:** the respawn executor — kill and relaunch a
  dead session with a failure-informed brief, per
  [roguelike-agentic.md](../project/roguelike-agentic.md). The watchdog
  is log-only today; it records deaths, it never executes them
  (`hngh-automation/jobs/agent-watchdog.sh`).

### 6. Audit / Torch

- **Inputs:** the Stratum's own artifacts — plans, digests, research
  files, backlog rows, alert rows.
- **Outputs:** deletions, wiring decisions, and the weekly check
  verdict.
- **Exists today:** fragments. The oversight tick's tree-skew and
  rendered-surface probes audit fragments of the tree; doc-suite checks
  links daily (`hngh-automation/jobs/doc-suite-update.sh`).
- **Designed, not built:** the consumption audit and the Mimic
  red-team beat. The consumption audit is the artifact-consumer
  invariant enforced periodically (below). The Mimic is a scheduled
  session whose job is to attack the record — forge evidence, replay a
  stale candidate, alias a canonical term into a record — and every
  attack must end in a refusal. Neither exists.

## Invariants

### The adoption gate

A crystallized research line becomes a backlog row with a named consumer
and a one-alternation deadline, or it auto-revokes. "Named consumer"
means a file, script, surface, or role that will use the line's
findings; "one alternation" is one grow/research cycle
([master-plan.md](../project/master-plan.md) §4). Revocation moves the
line to a dead-letter state, not deletion — the record stays citable.
Today nothing enforces this; the gate is specified here for the first
time.

### The artifact consumer invariant

Every artifact names its consumer at birth. An artifact is anything the
loop writes: plan candidate, digest, research line, feed, ledger. The
front-matter or header states who reads it. A write-only artifact is
deleted or wired at the next Audit station — no third option. The
2026-09-06 assessment counts 4 of 12 automation artifact classes as
write-only; that count is the Audit station's first agenda.

### The control-plane invariant

The automation control plane stays model-free. Models fill content; they
never run the loop. Verified 2026-09-06 by reading the wiring:

- Routing is deterministic — `hngh-automation/scripts/router-tick.py`
  maps identities to candidates in pure Python.
- Acceptance is deterministic — `hngh-automation/scripts/accept-plans.py`
  gates on runnable verification plus `make test` exit codes.
- Dispositioning (alerts, escalation, dedup) is deterministic shell and
  Python in `hngh-automation/jobs/oversight-tick.sh`.
- The watchdog logs and never kills or launches
  (`hngh-automation/jobs/agent-watchdog.sh`).
- The feeds (dashboard, schedule, research, plan, sessions) are
  deterministic scripts under `hngh-automation/cadence/` and
  `hngh-automation/jobs/`.

Model surfaces fail closed-skip: the steering leg without a model logs
"none" and moves on (`oversight-tick.sh` `steer_leg`); the research beat
and review beat file an "unavailable" alert and exit 0 when the model
chain is down (`05-research-beat.sh`, `04-review-prep.sh`). A model
failure degrades one beat's content, never the control flow.

## The falsifiable weekly checks

Five checks, run weekly once the Audit station is wired. Each is a yes/no
over the week's record:

1. Every admitted item reached a terminal disposition within 7 days.
2. At least one failure was classified into a bestiary class
   ([bestiary.md](bestiary.md)).
3. At least one research line was consumed — cited, adopted, or revoked.
4. Zero write-only artifact classes.
5. At least one disposition landed as a change. A week that fails check
   5 takes its own disposition: the loop itself becomes a Disposition
   input.

## Lexicon

Flavor names are display-register data. See
[display-register-spec.md](display-register-spec.md) §5 and
[presentation-boundary.md](presentation-boundary.md) for the boundary
law these rows inherit.

| Flavor name | Canonical term | Scope |
|---|---|---|
| Lookout | Observe | station |
| Verdict | Disposition | station |
| Delve | Research | station |
| Loot | Adopt | station |
| Forge | Grow | station |
| Torch | Audit | station |
| the Descent | self-improvement loop | the cycle |
| Stratum | one completed loop cycle | per cycle |
| Bestiary | failure taxonomy | [bestiary.md](bestiary.md) |
| Mimic | red-team beat | designed, not built |
| Camp | beat check-in pause | grow-tier rhythm |
| Inventory | artifact consumer registry | Audit input |
| Megastructure | the hngh kernel (this repository) | alias only |
| the City | hngh-automation | alias only |
| Builders | delegated worker agents | alias only |

Scope rules:

1. NEW ops-tier artifacts (dashboards, digests, feeds, overlays —
   anything the City writes) may carry flavor names canonically. The
   flavor IS the artifact's name there; `the Descent`, `Camp`,
   `Torch`, `Mimic`, `Bestiary`, and `Inventory` live at this tier.
2. KERNEL canonical terms never rename. Run states, evidence kinds,
   certificate actions, CLI verbs, and record fields keep their
   technical names in every record, receipt, and API. Flavor is
   display-alias-only at this tier and never enters a canonical
   record — the same rule as any perceptual alias
   ([presentation-boundary.md](presentation-boundary.md)).
3. `Megastructure`, `the City`, and `Builders` are aliases, never
   names: no path, package, CLI flag, or record field may use them.
   A record says `hngh-automation`, never `the City`.

---

Back to the [documentation index](../README.md).
