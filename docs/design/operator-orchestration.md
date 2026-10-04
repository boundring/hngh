# Operator orchestration: government emulation, expeditions, one orienting fixture

This design absorbs three operator directives (2026-10-04): government emulation,
expedition orchestration UX, and kernel-to-kernel simplification of orienting
attention fixtures. Sections 1-2 describe the coordinating layer's model, section 3
states the one-fixture contract, sections 4-5 cover jevify expansion and the
autonomy goal. Every repo claim is anchored `file:line`; anything not yet built is
marked REQ or GAP and never described as existing behavior. Companions:
`docs/design/triple-kernel.md` (kernel boundaries, certificate currency),
`docs/design/megastructure-sim.md` (map simulation stages),
`docs/design/harness-data-plane.md` (the ledgers this orchestration rides on).

## 1. Government-emulation model

hngh's coordinating parts already sit in a federal shape; the emulation names it
and makes the identity rules explicit.

| hngh part | Federal analogue | Evidence |
|---|---|---|
| kernel (`src/`) | executive | command dispatch incl. read-only `status` / `present` (`src/main.lisp:2386-2387`); machine sessions barred from `src/` except certificate-bound mutations (`AGENTS.md:44-50`) |
| automation ring | departments and agencies | tiered cadence drop-ins run per schedule (`automation/jobs/cadence-tick.sh:2-11`); jobs under `automation/jobs/` |
| patrol + gates | oversight committees | standing patrol over `config/patrol-routes.tsv`, deterministic checks, structured findings (`automation/jobs/patrol.py:2-33`) |
| plan files | filings and declarations | `docs/project/plans/<UTC-date>-<slug>.plan.md` written with `status=proposed` front-matter (`scripts/omp-bridge:193-214`, front at :212); accepted only through the ceremony `propose -> issue-cert -> mutation-check` (`AGENTS.md:47-50`), where the commit message is the certificate's content hash (`scripts/ceremony-drive:10-12`) |
| queue + report ledger | public votes and records | `docs/project/queue.md` and `docs/project/timeline.md` read as public state (`scripts/dashboard-readout:34-35`); report rows appended to `docs/project/reports.md` (`scripts/report-queue:2-10`) with alert/progress text redacted to public form before id/row/body derivation (`scripts/report-queue:18-20`) |

Procedural mappings (the paperwork, named as such):

- **Hearings = gate failures.** A patrol FAIL files a report-queue alert under
  identity `patrol:<id>` and appends supportive + adversarial sections to
  `automation/digest/PATROL-<date>.md` (`automation/jobs/patrol.py:20-33`); the
  red-gate route even drives the cure ceremony from the patrol itself
  (`automation/jobs/patrol.py:14-18`).
- **Investigations = patrol findings and research lines.** A patrol+cause pair
  repeating twice auto-queues a research subject (`automation/jobs/patrol.py:24-26`);
  the research beat crystallizes findings into `docs/research/<date>-<id>.md`
  (`automation/cadence/hour/33-research-beat.sh:1228`).
- **Filing ceremony = bureaucracy done right.** `omp-bridge --propose` writes the
  declaration; the certificate ceremony stamps it; `mutation-check` executes the
  bound git mutation (`scripts/ceremony-drive:37-38`); push is its own certificate
  (`scripts/ceremony-drive:403-404`).

REQ-G1 (identity taxonomy). Every coordinating part carries a categorized
identity: **branch** (the roadmap stage or tree branch it serves,
`docs/design/research-tree-of-life.md`), **role** (its function: patrol,
research-beat, worker, curator), **term** (a validity window), **clearance**
(certificate validity -- the certificate already names actor, action, target
state, verification, expiry, `docs/design/triple-kernel.md` section 2). Term has
a working precedent: report identities carry `{expires, escalated}`
(`automation/lib/report_queue.py:172-181`).

REQ-G2 (hearings and investigations are public). A gate failure produces a
public record (report row) plus a findings doc; a repeating failure produces a
research line; each hop is auditable without operator narration. The two-pass
supportive/adversarial format (`automation/jobs/patrol.py:21-23`) stays the
investigation template.

REQ-G3 (filing discipline). Plan files remain the only declaration form;
front-matter (`status`, `risk`, `accepted`) plus step checkboxes are the record
(`scripts/omp-bridge:141-158` reads exactly that). Queue/report rows are the
public vote record: one row, one action, timestamped and id-stamped
(`scripts/report-queue:13-16`).

GAP-1 (no identity registry). Identity strings are ad hoc today: alert
identities `patrol:<id>` (`automation/jobs/patrol.py:24-26`), report identities
with expiry (`automation/lib/report_queue.py:172-181`), free-text reviewer
strings such as `model:kimi:k3-256k` (rows in
`automation/research-dispositions.tsv`). Nothing enumerates parts, roles, terms,
or clearance, and nothing enforces a term ending.

## 2. Expedition orchestration

Research lines are expeditions into a landscape; the ledger state is already
expedition-shaped.

- **Landscape.** Trunk (project purpose), branches (roadmap stages), leaves
  (research lines and candidate seeds) in `automation/research-tree.tsv`, three
  TAB columns `node parent line-id` (`docs/design/research-tree-of-life.md`).
- **Expeditions.** `automation/research-lines.tsv`, headerless 4 columns
  `line_id status last_transition title` (schema `automation/jobs/research-routes.py:24-25`;
  append/transition writer `automation/cadence/hour/33-research-beat.sh:169,261-280`).
- **Findings home.** `automation/research-dispositions.tsv`, header
  `line action verdict reviewer evidence date support oppose followons`, terminal
  action `adopted|parked|killed` (`automation/research-dispositions.tsv:1`).
- **Findings delivered back as messages.** The handoff ledger
  `automation/agent-handoffs.md` (rows `operator-handle|operator-dismiss|mark-read
  | <ts> | automation|<id> | ...`, written only by the dashboard server,
  `automation/dashboard-server.py:204,1226-1228,1446,1556`); crystallized
  findings land as `docs/research/<date>-<id>.md`
  (`automation/cadence/hour/33-research-beat.sh:1228`).
- **Returning party members = completed sessions.** The delegation lifecycle
  `--run-start` / `--run-end` opens and closes bounded runs with a disposition
  (`scripts/omp-bridge:15-19,428-505`); completed sessions surface through
  `automation/jobs/sessions-feed.py:28-29`.
- **Machine time.** Fleet state is reported by `scripts/fleet-manager --json`
  into `automation/dashboard/fleet.json` (via
  `automation/cadence/subhour/25-newspaper-compose.sh:18-23`).
- **Idle megastructure mapping.** `automation/dashboard/map.js` seeds the
  topology (operator host, kernel core, automation ring, cadence tiers, userspace
  home, remote origin -- `automation/dashboard/map.js:12-27`) with the vendored
  three.js module (`automation/dashboard/map.js:54`); simulated observation must
  consume recorded local events only (`docs/design/megastructure-sim.md`).

REQ-E1 (expedition identity). An expedition is a research line or tree node with
an identity per REQ-G1, an assigned resource budget, and a returning-party
record (session disposition, handoff row). The ledgers above hold the parts;
nothing today joins them under one expedition identity.

REQ-E2 (operator assignment UX). The operator can assign time/resources of any
number of machines to lines, trees, or branches, and see the assignment on the
map. This is the expedition-orchestration UX deliverable of the 2026-10-04
directive.

REQ-E3 (findings return as messages). Every expedition finding lands in one of
the two message channels: the handoff ledger (operator-aimed) or a disposition
row + research doc (corpus-aimed). No third channel.

REQ-E4 (honest idle mapping). Until the megastructure-sim stages land, mapped
positions stay labeled editorial (`automation/dashboard/map.js:1-4` already says
so) and expedition state on the map derives from recorded ledger rows, never
from fabricated activity.

GAP-2 (no assignment seam). Fleet state is read-only reporting
(`automation/dashboard/fleet.json`); no ledger records an operator assignment of
machine time to a line. Budget-ish state is scattered and unjoined:
`automation/cadence-params.tsv` tunables, `automation/torch-ledger.tsv`
consumption rows, `automation/state/filing-budget.tsv` (per
`docs/design/harness-data-plane.md` section 1.2-1.3).

## 3. Kernel-to-kernel simplification: one orienting fixture

Advisor concern (2026-10-04): the orienting surfaces are too many and each
recomputes its own slice. Current surfaces, enumerated:

1. `scripts/omp-bridge --orient` -- a four-section markdown brief (queue next,
   roadmap next, working tree, last ceremony commit), recomputed from git and the
   queue/roadmap files (`scripts/omp-bridge:7,291-318`).
2. Five MCP read-only tools: `hngh_present` (`hngh present [RUN]`,
   `src/main.lisp:2387`), `hngh_status` (`hngh status`, `src/main.lisp:2386`),
   `queue_report` (`scripts/report-queue --json`), `dashboard_readout`
   (`scripts/dashboard-readout --json`, spine at :299, derivation note at :317),
   `research_lines` (feed over the two research TSVs,
   `automation/jobs/research-feed.py:3-28`).
3. The report-queue ledger as a reading surface: `docs/project/reports.md` rows
   plus bodies, one shared display cursor (`scripts/report-queue:2-10,60-64`).
4. The dashboard attention surface: unified verdict computation `verdictOf`
   (`automation/dashboard/app.js:492-530`, open-items override comment at
   :529-530), the operator-item handled verbs `open -> handled -> dismissed`
   with arm-then-confirm (`automation/dashboard/app.js:125-233`; POST verbs
   `automation/dashboard-server.py:27-62`, dispatch at :1182-1187), and the
   settings drawer `{attentionCap, rotate, pollMs}`
   (`automation/dashboard/map.js:182-215`).

REQ-K1 (one fixture). Collapse the above into a single orienting fixture any
client (human or agent) can consume: one JSON spine, one human render, one agent
render. All current surfaces become projections of the spine, not independent
computations.

REQ-K2 (spine owns attention state). The spine is the only computation of
attention state. `verdictOf`'s unified override semantics (`app.js:492-530`)
move into the spine producer; views stop re-deriving (today
`automation/dashboard/overview-view.js:57` calls the verdict helper and
`automation/dashboard/map.js:286` slices items by `attentionCap` client-side).

REQ-K3 (agent render). The agent render is the spine JSON itself, consumed by
the MCP reads and by `omp-bridge --orient`; the brief's four sections become
projections (today `--orient` re-reads git, `docs/project/queue.md`, and the
roadmap directly, `scripts/omp-bridge:238-318`).

REQ-K4 (settings stay display-only). `attentionCap`, `rotate`, `pollMs` are
per-browser presentation prefs (`automation/dashboard/map.js:182-215`) and never
become spine fields; a client that ignores them must still see complete state.

GAP-3 (no spine). `scripts/dashboard-readout data_spine()`
(`scripts/dashboard-readout:299`) is the seed but covers queue/session/roster
only; the five MCP tools and `--orient` each recompute different slices from
different sources; `--orient` emits markdown, not machine JSON. Unifying them is
the fixture work, not a rewrite -- the ledgers underneath (section 1 of
`docs/design/harness-data-plane.md`) do not move.

## 4. Jevify expansion

Jev evidence in-repo: the typed-lane self-check `jev self-check ok`
(`docs/records/2026-09-24-ceremony-optimization-and-jev-integration.md:171`,
implementation `automation/ng/jev.py`); the playbook's fan-out strategies,
including the speculative sweep "ask everything possibly needed, code ignores
the rest" (`docs/design/jev-playbook-2026-09-19.md`, strategy 8) and question
matrices as `question-node` rows in `~/.hngh/db/hngh-knowledge.db`
(`docs/design/research-tree-of-life.md`); frozen jevify rubrics for the 2026-10-03
subsystem/dashboard inventories (`docs/records/2026-10-04-harness-control-room-cut.md:21-23`).
The named "results pattern" (a parallel investigative supposition Q&A series) is
not recorded under that name in `docs/records/` -- REQ-J1 and REQ-J2 are
forward-looking, grounded only in the playbook strategies above.

REQ-J1 (forward-looking: investigative committees). A committee review pass
(patrol findings review, research disposition review) runs as a parallel
supposition Q&A fan-out in the playbook's speculative-sweep shape; per-question
verdicts land in the disposition row's `support`/`oppose`/`followons` columns
(`automation/research-dispositions.tsv:1` already reserves them).

REQ-J2 (forward-looking: public votes). Public vote entries become a record
kind alongside `progress|expense|optimization|scheduled|alert`
(`scripts/report-queue:2-10`): one row per voter/subject/verdict, id-stamped and
redacted by the same rules (`scripts/report-queue:18-20`), rendered in the
public record surface of section 1.

GAP-4 (no committee/vote surface). Jev exists as a typed-decision lane
(`automation/ng/jev.py`) plus playbook strategy text; there is no committee
orchestration, no vote ledger, and no results-pattern runner.

## 5. Autonomy goal

hngh maximizes useful awake-time work without operator participation: R&D
(hourly research beat `automation/cadence/hour/33-research-beat.sh:2`, overnight
research `automation/jobs/night-research.sh`), UI/UX evolution runs
(`scripts/evolve-operative`, `scripts/evolve-dashboard-style`), idle observation
(the map's simulated layer, recorded events only,
`docs/design/megastructure-sim.md`). The cadence tiers run unattended under a
per-tier flock (`automation/jobs/cadence-tick.sh:2-11`), and the patrol cures
red gates on its own authority path (`automation/jobs/patrol.py:14-18`).

Operator attention is reserved for point-of-risk confirmations: provider
configuration or service enablement still requires a current policy certificate
or an explicit operator instruction naming the exact action and target
(`AGENTS.md:79-81`). The operator-item ledger is the attention channel, with
arm-then-confirm on handle/dismiss (`automation/dashboard/app.js:125-233`).

REQ-A1 (auditable absence). Every unattended loop leaves a record (crumb, report
row, or handoff row) so a long operator absence remains reconstructable from the
ledgers alone; fail-first applies to the loops themselves (a patrol runner crash
files one alert and exits 0, `automation/jobs/patrol.py:28-33`).

REQ-A2 (attention budget). The single orienting fixture (REQ-K1) is the only
thing the operator must read to be current; `attentionCap`
(`automation/dashboard/map.js:182`) bounds what surfaces per render, and the
spine (REQ-K2) guarantees nothing is lost behind the cap.

REQ-A3 (point-of-risk policy unchanged). Autonomy never extends to the
`AGENTS.md:79-81` action classes; those stay certificate-or-explicit-
instruction, and the 2026-10-04 directives add no new interrupt classes.

## Status

Proposed (2026-10-04), awaiting operator review. Design input for the
harness-skeleton program; this document ships with no code changes and touches
no kernel surface.
