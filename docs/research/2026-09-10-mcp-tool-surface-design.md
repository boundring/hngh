# MCP Tool Surface Design -- omp sessions as hngh clients (plan step 3 precursor)

Status: RESEARCH -- 2026-09-10. Design analysis only; no implementation.

Question: what subcommands and MCP tools serve (a) operator omp sessions
working in this repo, and (b) hngh's own automated omp sessions --
orchestration, schedule optimization, steering, and roguelike stop/restart?

Evidence read: 2026-09-09 omp-hngh integration plan (steps 3-11);
`scripts/omp-bridge` (5 live subcommands); `automation/mcp/hngh_mcp_server.py`
(4 read-only tools); `src/main.lisp` command surface (19 verbs, usage table at
src/main.lisp:422-434); orchestration scripts (rotate-queue,
schedule-heartbeat, run-autonomous, ceremony-drive, report-queue,
dashboard-readout, overnight-cycle.sh, launch-session.sh); stop/restart
machinery (jobs/agent-watchdog.sh, jobs/agent-supervision.py,
jobs/agent-respawn.sh, jobs/resume-pass.sh); bestiary + descent vocabulary;
queue-dependency-inventory (2026-09-09) conflict risks. No live probes.

Doctrine applied: kernel side-effect-free toward omp; no daemon; every
mutation already has exactly one owning path (respawn guard 4: "No second
launcher exists or may be added"). Ponytail rule: every proposed verb cites a
concrete current consumer; speculative verbs are explicitly rejected.

## 1. Verb inventory

### 1.1 Kernel CLI (`scripts/hngh`, usage table src/main.lisp:422-434)

| Verb | Effect | Callers today | MCP |
|---|---|---|---|
| create-run | mutating (store) | cycle (bridge --run-start) | no |
| admit-transport | mutating (store) | cycle, ceremony-drive | no |
| arm-run / start-run | mutating (store) | ceremony-drive loop | no |
| checkpoint | mutating (store) | ceremony loop | no |
| close-run | mutating (store) | bridge --run-end, supervision replace | no |
| propose | mutating (store verdict) | ceremony-drive | no |
| issue-cert | mutating (store cert) | ceremony loop | no |
| mutation-check | mutating (git add/commit) | ceremony loop | no |
| review | mutating (store) + network | ceremony-drive, operator | no |
| terminal | mutating (store receipt) | operator ceremony | no |
| fetch-evidence | mutating (store) + network | federation beats | no |
| wake-peer | mutating + network | wake-mutation lane | no |
| run-worker | mutating (drives worker) | run-worker beats | no |
| verify-attestation | read-only (verifies file vs pins) | credential audit | no |
| list-pins | read-only | operator pin audit | no |
| present | read-only | MCP, dashboards, operator | yes |
| status | read-only | MCP, cycle preconditions | yes |
| select-course | read-only (pure advisory, src/main.lisp:1917) | run-autonomous course choice | no |

Legend: "mutating" = writes store, ledger, git, or session state. A mutating
kernel verb is not a free mutation -- it is certificate-bound (issue-cert ->
mutation-check).

### 1.2 Repo scripts (the adapter tier)

| Script / subcommand | Effect | Who may call |
|---|---|---|
| omp-bridge --orient | read-only brief (queue/roadmap/dirty/ceremony) | operator, external omp session, cycle |
| omp-bridge --register | mutating (handoff ledger line) | external omp session (check-in) |
| omp-bridge --ceremony | mutating (git commit via ceremony-drive) | external omp session, cycle |
| omp-bridge --run-start / --run-end | mutating (kernel run + ledger) | cycle (launch_session), supervision replace |
| ceremony-drive | mutating (certificate-gated commit + push) | cycle, operator; omp via --ceremony |
| rotate-queue | mutating (queue flip + certificate commit) | cycle only (operator scheduler) |
| schedule-heartbeat | mutating per tick; --dry-run read-only | cron tier (operator's scheduler) |
| run-autonomous | mutating per tick (journal, course mount, ceremony slice) | hourly systemd timer |
| report-queue --list/--unread | read-only | operator, feeds, sessions |
| report-queue --add/--mark-read/--prune | mutating (reports ledger + cursor) | feeds, watchdog, operator |
| dashboard-readout | read-only | MCP, operator TUI, cycle |
| overnight-cycle.sh | mutating orchestrator (gated sessions) | 24/7 timer only |
| automation/lib/launch-session.sh | mutating (budget ledger + bridge) | cycle + respawn ONLY (guard 4) |
| jobs/agent-watchdog.sh | log-only (ledger/alert/flag; never kills) | 5m oversight tier |
| jobs/agent-supervision.py | advisory; mutating ONLY on bridge-store runs (close-run dead + re-provision) | 5m oversight tier |
| jobs/agent-respawn.sh | mutating (bounded respawn, guards 1-4) | 30m tier only |
| jobs/resume-pass.sh | read + log writes, no session mutation | boot / cadence day tier |
| scripts/accept-plans.py | mutating (plan acceptance rules) | overnight tick |
| feeds (telemetry, sessions, slow-units, operator-items, plan-feed) | read-only JSON spines | dashboards, MCP candidates |

### 1.3 Already exposed via MCP (automation/mcp/hngh_mcp_server.py)

`hngh_present`, `hngh_status`, `queue_report` (report-queue --json),
`dashboard_readout` (dashboard-readout --json). All read-only; the server
fails closed (non-zero CLI exit -> isError, never a fake payload).

## 2. Proposed step-3 subcommands (scripts/omp-bridge)

The plan (step 3) specifies exactly two. Evidence supports both, plus one
narrow addition to --plan-status's argument surface. Nothing else earns a
subcommand yet.

### 2.1 `--propose <slug> --title TEXT [--risk RISK]`

CLI: `omp-bridge --propose <slug> --title "TEXT" [--risk normal|critical]`

Writes `docs/project/plans/<UTC-date>-<slug>.plan.md` with front-matter
`<!-- plan: status=proposed risk=<risk> -->` and a minimal body naming the
proposing surface. This is the surface docs/project/plans/README.md:43-46
already promises ("An oh-my-pi plugin propose surface participates by writing
`<date>-<slug>.plan.md` with status=proposed") -- step 4's `hngh_propose`
plugin tool and step 6's hngh-executor agent both back onto it. Concrete
current use: today a session proposing a plan hand-writes the file; the
front-matter guard (step 7 candidate rule) has no owned writer to point at.

Fail-closed rules (exit protocol 0/1/2/3 as in omp-bridge's docstring):
  - slug must match `^[a-z0-9][a-z0-9-]*$`, ASCII only, <=64 chars -> 2;
  - empty or missing --title -> 2;
  - target filename already exists -> 1 (duplicate refusal, named in the
    plan step; never overwrite -- a proposed plan is operator review input);
  - plans directory unwritable -> 3;
  - success prints the written path + the front-matter line (the plugin
    reads back --plan-status, it does not parse prose).
  - critical risk: allowed to WRITE (proposing is free); acceptance of
    critical plans stays operator-only per plans/README rules -- the verb
    never sets status=accepted.

Test surface: new `automation/tests/test-omp-bridge.py` (none exists today --
the bridge is untested), hermetic via HNGH_BRIDGE_ROOT/OMP_BRIDGE_* seams
already present: happy path writes file, duplicate slug -> exit 1, non-ASCII
slug -> exit 2, empty title -> exit 2. Run under `make test`.

### 2.2 `--plan-status [SLUG]`

CLI: `omp-bridge --plan-status [SLUG]` -> JSON on stdout.

With SLUG: `{slug, file, status, risk, accepted, steps_total, steps_done}`
parsed from the plan's own front-matter, cross-checked with
automation/dashboard/plans.json (same fields the dashboard already emits --
verified shape: plans.json rows carry slug/status/risk/accepted/
steps_total/steps_done). Without SLUG: array of all plans, newest first.
Exit 2 unknown slug, 3 unreadable front-matter, 0 otherwise.

The plan text specifies --plan-status with no argument; the SLUG argument is
the one evidence-backed addition: step 4's round-trip verification reads back
THE plan just proposed ("writes a plan file and reads status back") -- without
a slug filter the plugin would scrape a global array. Keep the no-arg form as
the default since dashboard/plans.json consumers (step 10 UI) want the full
list.

### 2.3 Considered and REJECTED for step 3

  - `--plan-accept <slug>` -- acceptance authority lives in accept-plans.py +
    plans/README rules (auto-accept normal-risk proposed plans on the
    overnight tick; operator accepts critical). A machine-callable accept
    verb lets a session accept its own proposal: self-dealing. No current
    caller needs it.
  - `--plan-write/--plan-edit <slug>` (edit step bodies): plan steps are
    edited by the executing session in place with its normal editor; a
    wrapper adds a second write path to the same file for zero gain.
  - `--plans` (list plan files as text): --plan-status with no slug covers
    it as JSON; a second human-readable list duplicates dashboard-readout.
  - `--orient --json`: orient's consumers (step 8 context-seeding, skill
    text) are prose consumers; the existing plain-text brief is already
    "read-only and small" per step 8. JSON variant = speculative.

## 3. Proposed MCP tools beyond step 3

The MCP server stays read-only-by-construction: every tool is one subprocess
call to an existing read-only CLI (hngh_mcp_server.py docstring). Tier W
proposals below are about what COULD be exposed and why most must not be.

### 3.1 Tier R -- read-only, safe to expose now

Each cites a named consumer that exists today:

  1. `research_lines` -- automation/research-lines.tsv (+ dispositions).
     Consumer: plan step 9 mandates exactly this tool; hngh-scout agents
     (step 6) orient from it. One subprocess `cat`-equivalent over the TSV.
  2. `handoffs_tail` -- last N rows of agent-handoffs.md (the watchdog +
     bridge-register ledger, hngh-automation side, env-seamed path).
     Consumer: resume-pass.sh reads exactly this surface for recovery; a
     session entering after a death needs the cause row (bestiary classes)
     to avoid respawning a corpse's mission. Read-only, no redeath risk.
  3. `supervision_snapshot` -- automation/dashboard/agent-supervision-state.json
     (+ sessions.json). Consumer: plans #14-16 (queue-dependency-inventory
     merge group 3) exist because sessions hit bridge conflicts they could
     not see; a read tool makes lane health observable before a session
     tries --run-start. Pure file read.
  4. `budget_snapshot` -- logs/budget.md tail + quota posture from
     telemetry aggregates (dashboard JSONs; session-cost.py's inputs).
     Consumer: the plan's cost-controlled decomposition (2026-09-10) makes
     quota-bucket pacing a standing rule ("pace heavy design work within
     the 5h bucket"); sessions currently learn this only by reading ledgers
     by hand. Read-only.
  5. `operator_items` -- dashboard/operator-items.json.
     Consumer: resume-pass counts stale parked operator items; a delegated
     session must know which items are operator-held so it does not
     duplicate or park over them. Read-only.
  6. `hngh_orient` -- omp-bridge --orient as a tool.
     Consumer: step 8 auto-seeds orientation at session start, but a session
     that has been running across a queue rotation needs a re-orient on
     demand; the CLI already exists, the tool is one wrapper. Read-only.
     Expose only when step 4's plugin exists so there is one orientation
     consumer contract.

### 3.2 Tier W -- mutating; who owns the mutation, who may ever call it

Rule: an MCP tool never introduces a second mutation path. Each candidate
below names the existing owning job, or is rejected because none exists.

  1. Steering (inject a message into a live session). REJECTED -- no owning
     path exists anywhere in the repo: agent-watchdog.sh is deliberately
     log-only ("ending-the-session is a logged decision"), supervision
     "never kills, restarts, or mutates a live session" (docstring), and the
     roguelike rule is "steer, don't kill" as an OPERATOR act on a live
     turn, not a scripted injection. omp has no documented message-injection
     API reachable from a side process. Inventing an injection path would be
     an unprompted daemon-shaped feature. Nothing to wrap; do not build.
  2. Stop a stalled session (close-run dead). Owning path: supervision's
     bridge-run replace (hngh close-run dead + rotate record + re-provision
     via omp-bridge --run-start, proven 2026-08-27). An omp session may
     legitimately call ONLY the lifecycle that belongs to its own
     delegation: omp-bridge --run-end on a run it started (disposition
     client-validated, kernel refuses illegal transitions). It must NEVER
     close another session's run: a stalled-bridge-store run is not "stuck",
     it is under a 5m supervision tick with its own replace semantics, and
     two closers racing the same record is the record-conflict label the
     2026-09-09 inventory found. Operator-gated only (by hand, or by
     supervision on its tier).
  3. Respawn (death-and-replacement). Owning path: agent-respawn.sh, whose
     four guards (steer-don't-kill cause routing, once-per-day loop-break,
     daily budget cap shared with logs/budget.md, single launcher authority)
     ARE the certificate for the mutation. Never omp-callable: an omp session
     deciding its own respawn bypasses cause classification (it would mark
     its own death missing-design instead of bad-execution) and the daily
     cap. The stop->brief->replace loop maps exactly onto existing surfaces:
     watchdog logs session-drop -> resume-pass/resume surfaces read the
     handoff -> respawn re-launches via launch-session.sh with the corrective
     brief. An omp session's legitimate slice is Tier R (handoffs_tail +
     supervision_snapshot to SEE the death) plus omp-bridge --run-start when
     the CYCLE asks it to host the replacement -- never the death decision.
  4. rotate-queue advance. Owning path: rotate-queue itself -- queue flip +
     evidence + reviewer + propose + cert + mutation + ledger in ONE closed
     command, invoked by the operator's scheduler. No partial exposure:
     exposing "advance the queue" as a tool would let a session claim a
     lane without the slice work; exposing the inner steps would duplicate
     the ceremony. Cycle-only. An omp session works a lane by being spawned
     through it (run-start), not by rotating the queue.
  5. Heartbeat tick. Owning path: schedule-heartbeat on the cron tier;
     --dry-run is the read-only face, coverable by a Tier R tool if a
     consumer appears -- none cited yet, so not proposed. A machine-
     callable mutating tick would double-fire the scheduler; the script's
     own docstring forbids backgrounding/second schedulers.

## 4. Boundary statement

No daemon: the MCP server is spawned per connection by the client, every
orchestration script is one explicit command that exits, and nothing proposed
here watches or loops. A tool that needs a daemon is a rejected tool.

Kernel side-effect boundary: the kernel never knows omp or MCP exists. All
omp-facing code lives in automation/ adapters and omp-side plugin/rules/skills
(plan architecture constraint, src/main.lisp:38-48). The kernel's own
mutations are not bypassed by adapters -- they are certificate-bound kernel
verbs (propose/issue-cert/mutation-check), and the adapters wrap them or
wrap ceremony-drive, which drives the same loop. What adapters may never do
is mutate repo or session state OUTSIDE a governing path: ledger writes go
to the ledgers the watchdog/cycle already own, git mutations go through
ceremony, session deaths go through supervision/respawn.

Why orchestration mutations stay behind the cycle rather than becoming
omp-callable verbs: the cycle IS the governance for them. rotate-queue
carries the certificate loop in one closed command; heartbeat/run-autonomous
ticks are serialized by their timer ownership; respawn's guards encode
cause-routing and budget caps that a self-interested session cannot apply
honestly to itself. Making these omp-callable does not add capability, it
adds a second caller racing the owner -- exactly the bridge record-conflict
and launch-path duplication the 2026-09-09 inventory and respawn guard 4
already had to close off.

Narrow exception, with its explicit operator cert: the one mutation an
external omp session legitimately performs today is the delegation loop it
rides -- omp-bridge --run-start/--run-end/--register/--ceremony. These stay
omp-callable because each is already bounded by a named governance surface
(kernel loadout limits = the delegated budget; kernel transition refusal =
disposition honesty; global ceremony flock + certificate = the commit). If a
Tier W verb is ever genuinely needed by sessions, the mechanism exists: a
trust-anchor file in the style of the kernel's reviewer file / operator pins
src/main.lisp:1014,1713, where presence of an operator-maintained file is
the admission -- absence fails closed. That file, not an MCP flag, is the
operator cert. None of today's Tier W candidates justify creating it.

## 5. Summary counts and sharpest rejections

Step-3 subcommands: 2 proposed (--propose, --plan-status[SLUG]), 4 rejected.
Tier R tools: 6 proposed (1 already mandated by plan step 9). Tier W: 5
analyzed -- 1 already omp-callable via the existing bridge (its own run
lifecycle), 4 rejected as operator/cycle-only or nonexistent-path.
Sharpest rejections:
  1. Steering injection -- no owning mutation path exists anywhere; watchdog
     is deliberately log-only; would create an unprompted injection daemon.
  2. MCP respawn -- respawn's four guards ARE the certificate; a session
     classifying its own death and resetting its own loop-break/cap
     counters is self-dealing on the exact anti-pattern that killed
     operator trust (agent-handoffs.md 2026-09-05 x4).
  3. --plan-accept -- acceptance authority already lives in accept-plans.py;
     a machine-callable accept verb lets sessions accept their own
     proposals and would bypass the operator's critical-risk review.