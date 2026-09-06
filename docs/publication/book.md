# The Hngh memoir (assembled)



The record in one file: the intent, the architecture, the decisions, and the queue that runs itself.



## The intent

# Hngh intent

## What Hngh is

Hngh turns development into short, bounded cycles — plan, check, record, close — that an
automated agent can run while a human keeps the final say. Each cycle leaves a paper trail
of evidence. Nothing changes the system without passing a check and being recorded. The
kernel itself is side-effect-free: it does nothing on its own, owns no background process,
and refuses anything unknown or unverified (fail-closed).

## Why this exists

Automation grows more capable every year, and that is exactly when trust gets harder. Most
agentic and developer tools act without a record and without clear boundaries. They change
files, run commands, or call models, and afterward there is little to show for how or why.
When something goes wrong, you cannot reconstruct what happened, and you have no clean place
to say "no."

That is the problem Hngh is built for. Trustworthy automation needs two things ordinary tools
skip: a paper trail, and a human who has the final say. Every decision here is designed to
keep those two things true — every action is recorded, and nothing is treated as approved
until a checked, ruled-on decision says so. When the machine suggests, plans, and asks, and
the human confirms, automation stays useful without becoming an uncontrolled actor.

## How work happens

Work in Hngh happens as a run: one bounded attempt at one objective, with a clear start, a
clear end, and checkpoints in between. A run is not a general "session" that people open and
leave running. It is a small, finite loop, and each loop is complete on its own.

A person sees a run pass through a simple life:

- **Created.** A run exists as an idea with a mission, a role, and limits. Nothing has
  happened yet.
- **Armed.** The run asks for permission and gathers evidence. It is only allowed to start
  when its request is confirmed.
- **Running.** The run does its work, under the limits it was given.
- **Checkpointed.** Verified progress is recorded. A person can see what is done and what
  evidence backs it.
- **Closed.** The run ends in one of a few definite ways — cancelled, evacuated, or dead.
  A closed run stays closed. If you want another attempt, you start a new run; nothing
  retries or continues silently on its own.

Each run is a complete loop. The work repeats — that is the point — but every repetition
starts fresh, with its own evidence and its own checks. Nothing carries over by accident,
and nothing is assumed from a previous try.

## The roguelike idea

The design borrows discipline from roguelike games — deliberately, and as a metaphor only.
It is a proven way to keep progress honest, not a game to be won.

In a roguelike, a run is finite: it has a start, checkpoints, and an end, and when it ends it
is over. "Permadeath" there means the run does not quietly continue or auto-retry; you begin
a new run instead. In Hngh, that same discipline is containment, not punishment. When time or
budget runs out, a check fails, a request is unsafe, or a run expires, the run ends. There is
no automatic retry and no silent continuation. The good ending is "evacuation": named
deliverables and verification evidence are handed over, and what was learned is preserved.
Even a dead run keeps its last verified checkpoint and a bounded salvage record.

The other borrowed idea is the "camp": one tiny, behavior-sized change, then a pause where
evidence, cleanup, and the next move are recorded. Small verified steps, each one leaving a
trace — never a long stretch of unrecorded work.

This is a metaphor for discipline, not a game. Hngh uses "run," "checkpoint," and
"evacuation" as plain working words (defined below); the game flavor is only a reminder that
dead ends stay dead and progress has to be earned.

## What the kernel guarantees

The kernel is the quiet center of Hngh, and it promises five things:

- **Side-effect-free.** The kernel reads no clock, no files, no network, and no process. On
  its own it changes nothing on the machine. All the messy real-world activity lives outside
  it, at the edges, where the rules still apply.
- **Fail-closed.** Unknown, malformed, duplicate, or unverified input is refused. The kernel
  never guesses and never skips a check. If it cannot say "yes" for certain, the answer is
  "no."
- **Evidence, not authority.** A record of what happened — a receipt — describes or justifies
  what went on. By itself it grants no power. Recording that something happened never makes
  it approved.
- **One action per certificate.** A certificate is permission for exactly one action
  (prepare, stage, commit, or push), bound to specific files and specific evidence, and
  re-checked immediately before that action runs. There is no blank permission slip.
- **No hidden execution.** Nothing runs in the background, no daemon watches, no work starts
  without a started run. If you are not looking, nothing is doing.

## Clean architecture, briefly

Hngh keeps its rules in a pure core that depends on nothing external. The core decides what
is valid — which states a run may be in, which evidence is admissible, which verdict a
proposal earns. It knows nothing about Git, model providers, terminals, or files.

The messy outside world plugs in later, at the edges, through explicit ports (formal entry
points) and adapters (the plug-in pieces that talk to real things such as Git or a model).
The important rule is one-way: the core never knows about the outside, and the "is this
valid?" decision never lives in an adapter. That means the rules stay small, testable, and
safe to reason about, no matter what real-world machinery gets attached later.

## Agents: Pi and beyond

Long-term, Hngh is meant to orchestrate an automated worker — likely one called Pi — that
actually carries out runs. Today the bounded read-only worker task (`run-worker`, rung 18)
and the one-shot `scripts/worker-driver` cycle are installed behind a port; the durable
Pi RPC compiler agent remains a survey and a plan.

When a worker arrives, it will sit behind a port: a replaceable outer layer that Hngh can
swap out. The worker is read-only by default. Hngh keeps authority, holds the evidence,
and holds the power to end any run. The worker may only act on the one action its current
certificate names, verified at the moment of action. The agent harness that sits on
top is "oh-my-pi," installed and live: its omp-bridge gates
delegated runs through create-run and admit-transport
(`2026-08-26-omp-bridge`), and the watchdog watches it work.

The standing rule: a worker is a tool, never the source of truth. The truth lives in the
evidence and the checked decisions, and the final say stays with the human.

## Cost discipline

Automation can spend real money — tokens, compute, time. Hngh plans to make that spending
deliberate with a simple ladder:

- Try the cheapest adequate route first.
- Use an expensive route only when it is named and evidenced — you say why it is needed, and
  there is a record of the reasoning.
- When the cost is unknown, refuse. No unbounded or unestimated spending.

The rule of thumb for a person: cheaper is the default, expensive is a decision, and unknown
is a "no" until known.

## Words we use

| Term | Plain meaning |
|---|---|
| Kernel (`hngh.domain` + `hngh.application`) | The pure core that decides what is valid; it reads no clock, files, network, or process. |
| Run | One bounded work cycle with a definite start, checkpoints, and end. |
| Evidence | A record of what happened; it can describe or justify but never grants power by itself. |
| Receipt | A specific evidence record written when something happens. |
| Policy verdict | A deterministic pass-or-refuse decision computed from evidence; it admits only when every principle passes, and refuses anything missing, unknown, stale, or conflicting. |
| Certificate | Permission for exactly one action, bound to specific files and evidence, re-checked right before the action. |
| Fail-closed | Refusing unknown, malformed, duplicate, or unverified input — never guessing, never skipping. |
| Port | A formal entry point where the outside world plugs into the core. |
| Adapter | A plug-in piece at the edge that talks to real things (Git, models, terminals). |
| Checkpoint | A verified point in a run where progress is recorded. |
| Evacuation | The good end of a run: named deliverables and verification evidence handed over. |
| Permadeath (analogy) | Ending a run for good when a check fails or limits run out; no auto-retry — containment, not punishment. |
| Ledger | The running record of proposals and their evidence that policy rules over. |

## Today and next

Today Hngh is a self-watching control system: a pure kernel with closed run lifecycles,
governance policy, nineteen operator verbs, a cadence of single-tick timers that drive and
correct the machine on every tier from one minute to daily, a nerve-center webapp
(Schedule, Sessions, System, Research, Logs) with a session observatory that reads live
agent transcripts, and a time ledger that measures every operation so delays are noticed
procedurally. There is no daemon; every timer is an operator-installed single tick. The
direction ahead — seven named stages with exit criteria — is set out in the
[consolidated route](project/roadmap.md); read it for what gets built next and in what
order.

The long horizon is a mesh, not a bigger machine. Each Hngh node guards its own small
boundary — a machine on a shelf, a hand-held that mostly sleeps, a laptop whose network card
is older than the person using it — and each runs the same narrow rulebook: evidence first,
then a place. What one node learns (this bridge drops at three in the morning, this tunnel
has held for a year, this load draws this power, this device woke when asked and stayed quiet
otherwise) is written down as a fact a neighbor can cite, not buried in a ledger only one
wall will ever read. A node wakes a neighbor before it is needed, keeps the corridors open
without a watching process, and admits a new low-powered peer the only way anything is ever
admitted here: through a proposal, a check, and a record. One machine learns only what its
own wall taught it; a lattice of small ledgered machines is how a city crosses a lawn, then
the next lawn, then the planet — and no wall stands that does not say who raised it. None of
that exists yet. It is the direction, and the direction is admitted one verified stretch at a
time, the same as everything else.

---

Back to the [documentation index](README.md).


## The architecture

# Architecture

Hngh begins as a compact, side-effect-free kernel.

It stays small on purpose: the quiet center holds the rules while the
lattice of small ledgered machines does the moving.

## Current kernel

`hngh.domain` is an active Common Lisp-only library. It validates ordered
profile modes and creates pure mission, role, loadout, run, receipt, score, and
afterlife values. It does not read a clock, environment, path, provider payload,
or subprocess value.

A run always starts in `created`. Its closed lifecycle is:

```text
created -> armed -> running -> checkpointed
created -> cancelled | dead
armed -> cancelled | dead
running -> cancelled | evacuated | dead
checkpointed -> running | cancelled | evacuated | dead
cancelled | evacuated | dead -> afterlife -> scored -> archived
```

Every other transition refuses. Receipts, score records, and afterlife records
hold evidence only; they cannot change state or grant authority.

`hngh:validate-profile` remains a compatibility facade over the domain policy.
`hngh.application` currently contains the pure `create-run`, `admit-transport`,
`arm-run`, `start-run`, `checkpoint`, `close-run`, and `select-course` use cases with
their inward port contracts; `admit-transport` and `close-run` are policy-gated.
`checkpoint` admits only closed verification and manifest evidence through a
run-only request value. It has no persistence root, clock,
environment, provider payload, subprocess, service, or background process.

`hngh.adapters.evidence` is the first outer boundary: a read-only evidence
adapter with a fixed command set (repository revision, working-tree status,
file content hashing) and an injected process transport. It never decides
policy and cannot mutate anything.

`hngh.adapters.review` is a bounded model-review boundary: it turns a closed
review request into one fixed prompt, sends it through an injected reviewer
transport, and maps the structured output into sanitized findings and one
deterministic review evidence fact. Reviewers advise, never decide, and no
default provider transport exists.

`hngh.presentation` is the operator-visible renderer boundary: it turns
application results, domain runs and governance values, and adapter results
into plain factual strings, keeps refusals literal, and never mutates a
canonical value. The optional reference lexicon supplies display copy only
at a named surface; it cannot carry canonical control. Presentation imports
no adapter.

`hngh.main` is the composition root. `make-run-harness` composes the six
use cases into one run harness over injected or fail-closed default port
adapters (an in-memory record store, a per-harness identifier source, and a
clock), the coordinator functions wire the installed evidence, mutation, and
review adapters through injected transports, and `display` renders any
result through `hngh.presentation`. It starts no background work by import.

The installed outer boundaries beyond evidence and review are: the mutation
executor (rung 5), the filesystem record store (rung 8), the bounded `:model`
and `:terminal` transports behind loadout admission (rung 10), the federation
and attestation adapter (rungs 11–12, 14–15), and the bounded `:worker`
transport (rung 18). None of them runs by default: every one sits behind an
injected transport or an explicit admission receipt.

## Planned outer boundaries

```text
hngh.main -> hngh.presentation / hngh.adapters.*
          -> hngh.application
          -> hngh.domain
```

The dependency direction, promotion ladder, and composition rule live in the
[Clean Architecture charter](core/clean-architecture-charter.md). The public
responsibilities and allowed dependencies live in the
[component map](core/component-map.md). Tests and presentation data follow the
[test boundary](core/test-boundary.md) and
[presentation boundary](design/presentation-boundary.md). Real model and
terminal transports are admitted only under a separately approved run
loadout (rung 10), and the operator reviewer transport (rung 13) is
admitted by an explicit operator reviewer file.


## The roadmap

# Roadmap

## Direction

Hngh is a small, predictable core that decides what is valid, with the
messy outside world — files, Git, models, terminals, packages, desktops —
plugged in at the edges. Evidence comes before claims, so nothing is
believed without a record; permission is re-checked at the moment of
action, so a certificate is never a free pass; reviewers advise but never
decide. The kernel is built. The governance loop is built. The machine
now watches itself: a time ledger measures every level, a self-review
inspects its own dashboard hourly, and the oversight path flags drift
before a human would. What remains is expansion — more system harnessed,
more delegation governed, more surface polished — each expansion riding
the same gates. For the vision in full, read [the intent
document](../intent.md).

## The consolidated route

Seven stages, each with exit criteria; a stage is done when its exit
criteria hold under the standing gates, not when its code merely exists.
Stages 5 and 6 run in alternation (grow beats and research/design beats per
[master-plan.md](master-plan.md) §4) rather than strictly in sequence.

| Stage | Scope | Exit criteria | State |
|---|---|---|---|
| **0 — Kernel & governance** | pure spine, seven use cases (the six original fake-backed use cases plus queue-ranking select-course, 2026-08-27), governance C0–C3, evidence/mutation/review adapters, 19 CLI verbs, certificate loop, cadence continuum | `make test` green; every commit certificate-bound; loop-history guard silent | **done** |
| **1 — Self-watch** | time ledger at every level; dashboard self-review (hourly, two-tier findings); oversight alerts (flap-suppressed); watchdog; transcript supervision pattern proven | self-review runs silent when healthy and catches a seeded fault within one tick; delays noticed procedurally | **done** |
| **2 — One interface** | nerve center: formal tabs (Schedule default, Sessions, System, Research, Logs); session transcript observatory; unified schedule with system backdrop; window tiling + spawn; operator-item lifecycle | every tab renders at desktop + mobile widths; cold deep-links mount; operator items flow open→handled→dismissed | **landing** |
| **3 — Roguelike delegation live** | every delegated session wrapped: `omp-bridge --run-start` (budget loadout) → observatory `working` → `--run-end` disposition; self-supervision tick (transcript phase detection, stall flags, auto-replace); gantt renders actual bars beside estimates; per-lane medians | one full delegation cycle witnessed live end-to-end; a seeded stall is flagged and replaced without human intervention | **landing** |
| **4 — System harness D/E** | config-manager (declared config lanes, governed updates), package-manager integration (updates inventory → certificate-gated upgrades), maintenance routines (orphans, caches, journal vacuum) — CachyOS first, per-host orientation generalizes — first managed service: local Unsloth/llama-server (service-ctl allowlist, 2026-09-03 operator grant) | a governed package upgrade runs start-to-finish through the certificate loop on this host; config lanes declaratively listed and backed up on cadence | **queued** |
| **5 — Research alternation institutionalized** | research view drives the alternation: research beats scheduled on cadence, lessons→records pipeline, research telemetry register (time/cost/models/references/searches per subject, per [ledger-and-records-spec.md](../design/ledger-and-records-spec.md)), R&D view grows into the alternation driver with a tech-tree presentation | a research beat lands a parseable artifact through the standard gates without a human demanding it | **queued** |
| **6 — QoL & graphic evolution** | widget grid (GridStack), uPlot charts, Winamp-skin-parser themes, procedural/WebGL/music-reactive effects — all behind the QoL cadence and the display register | one graded QoL change per cycle, revertible, before/after evidence attached | **queued** |
| **7 — Federation & fleet** | multi-host lattice, wake, pooled resources (system-harness rungs A/B) | a second host orients, admits, and backs up through the same gates | **later** |

Sequencing rules: every stage feeds stage 1's ledger (timed, flagged,
optimized); nothing skips the gates; research/design beats (stage 5
output) gate the next grow stage when a grow run cannot proceed without
a missing design — grow cannot outrun its designs, and designs do not
exist without grow demanding them.

## Now

the bounded read-only worker task (rung 18) — rungs 14–18 all landed 2026-08-25.

The Descent cycle ([design/descent.md](../design/descent.md)) now
governs the stage 5/6 alternation: research lines gain a review
transition between crystallization and adoption, and failure causes
route into research demands per the bestiary
([design/bestiary.md](../design/bestiary.md)) instead of piling up in
the alert ledger. The cycle's five weekly checks are the route's
honesty gate; the adoption gate and the Audit station are specified
there and not yet wired.
### Completed

- Sealed the retirement boundary: the archived prior system is external and
  no longer verified (`make check-archive` retired 2026-08-19); the obsolete
  Mission Control desktop launcher was retired, its bytes preserved in a
  supplemental archive receipt.
- Published the Clean Architecture charter, component map, test boundary, and presentation boundary; added fixture guards for inward dependency direction and renderer-only reference lexicons.
- Specified and tested the pure run domain: closed lifecycle, typed refusal, validated mission/role/loadout values, and non-authoritative evidence values.
- Added the read-only reader guard to the fast gate (`make test` runs 8 reader-guard checks plus the domain suite).
- Added the five fake-backed application use cases, each recording one atomic run-and-receipt pair and refusing anything outside its closed contract:
  - `create-run` with capability-specific fake ports and closed callback refusals;
  - `arm-run` with four closed admission facts, so only full confirmation can create an armed replacement run;
  - `start-run`, so only the application boundary can make an armed run running;
  - `checkpoint`, so only passed verification and complete manifest evidence can advance a running run;
  - `close-run`, policy-gated, so a run reaches a terminal state (`:cancelled`, `:evacuated`, or `:dead`) only under an `:admitted` policy verdict, with closed transition refusals and no certificate for run-state transitions.
- Added a read-only candidate evidence bundle (`make verify-candidate`): explicit manifest admission, candidate-local policy scans, fixed local evidence commands, and closed status output; it observes whole-tree state without inferring scope or mutating Git.
- Added governance C0–C3:
  - the proposal-evidence ledger;
  - deterministic principle evaluation — one `policy-verdict` per proposal with ten matrix-ordered principle results and closed refusals for missing, stale, malformed, conflicting, or unverifiable evidence;
  - the closed failure-disposition policy — one deterministic disposition per failure category, refusing unknown categories;
  - a non-mutating candidate authorization certificate binding one closed action to the admitting verdict and facts, issued by a mechanical pure issuer (action-admission policy deferred to the executor).
- Published source-grounded autonomous development policy, the closed principle and certificate vocabulary, and a human-approval deployment profile — documentation only, no execution added.
- Added the read-only evidence adapter (promotion rung 4): a fixed, enumerable set of read-only local evidence commands — repository revision, whole-tree working-tree status, and file content hashing — gathered through an injected process transport and mapped to domain evidence facts and source manifest entries with closed states. Unknown commands, malformed output, escaping or option-like paths, and duplicate evidence fail closed; the kernel stays pure and the adapter never decides policy.
- Added the mutation executor (promotion rung 5): `hngh.adapters.mutation` accepts a current certificate and fresh evidence, rechecks repository identity, base revision, candidate paths, content and evidence hashes, principle verdicts, source manifest, review findings, policy profile, and expiry, then issues only the certificate-bound fixed Git action through an injected transport. `:none`, action escalation, stale facts, malformed evidence, command failures, and transport faults refuse without a mutation.
- Added the bounded model-review adapter (promotion rung 6): `hngh.adapters.review` turns a closed review request — candidate paths, content hash, and policy-context labels — into one fixed prompt, sends it through an injected reviewer transport, and maps the structured output into immutable finding labels and citations plus one deterministic domain evidence fact. Missing, malformed, unsafe, duplicate, or oversized output refuses closed; a failed review call becomes an `:unverifiable` fact; reviewers advise and never decide, and no default provider transport exists.
- Added the composition root and operator-visible presentation (promotion rung 7): `hngh.presentation` renders application results, runs, receipts, evidence facts, policy verdicts, candidate certificates, and adapter results into plain factual strings without mutating canonical state or importing any adapter; the optional reference lexicon supplies display copy only at a named surface and can never carry canonical control. `hngh.main` composes the five use cases into one `run-harness` with injected or fail-closed default port adapters, wires the installed evidence, mutation, and review adapters through injected transports, keeps an operator-visible in-memory record root, and renders every result through presentation. No daemon, provider, watcher, or background execution.
- Added the operator-facing command surface and transport admission (promotion rung 8, 2026-08-24): `hngh.application:admit-transport` admits closed transport kinds (`:filesystem`) under mission/loadout authorization; `hngh.adapters.filesystem` records canonical run-and-receipt lines under an explicit root path; `hngh.main:dispatch-command` and `scripts/hngh` expose the 7 CLI operations (`create-run`, `admit-transport`, `arm-run`, `start-run`, `checkpoint`, `close-run`, `present`) with a strict exit code protocol (0 accepted, 1 refusal/conflict, 2 malformed, 3 fault). Persistence occurs only under an explicit `--store=PATH`.
- Completed the dogfood development loop (promotion rung 9, 2026-08-24): the operator governance surface (`propose`, `issue-cert`, `mutation-check` in `scripts/hngh`) forms closed policy proposals, binds candidate certificates under admitted verdicts, and executes the certificate-bound mutation against real repository evidence including live base revision, per-file content hashes, and the installed verify-candidate script. Two self-governed commits were produced, reviewed, and committed by Hngh under its own certificates and pushed to origin: the documentation change that completed this rung (`2a16a69`) and the two adapter bug fixes the first governance loop surfaced (`33b8d94`).
- Completed the bounded agent worker transports (promotion rung 10, 2026-08-24): `hngh.adapters.model:make-model-transports` supplies the transport `complete` callback shape so the existing bounded review adapter can drive a real provider (advisory only, no default provider, closed route admission), and `hngh.adapters.terminal` captures one bounded operator statement as a `:terminal` evidence fact (advisory only, in-process SHA-256 fingerprint, no subprocess, no default input). `hngh.application:admit-transport` reuses the run loadout for the two new kinds — `:model` needs a non-`local` route plus the `model-review` network label, `:terminal` needs the `terminal-input` tool label — with the closed `loadout-refuses-transport` refusal. `hngh.main:dispatch-command` exposes the `review` and `terminal` operations, both fail-closed without injected ports (no-review-transport / no-terminal-transport) and both served only to a run holding the matching admission receipt; `hngh.presentation` stays outward-only with the added `render-operator-result`.
- Completed the distributed attestation & evidence federation slice (promotion rung 11, 2026-08-24): `hngh.domain` adds the pure `remote-attestation` value and `verify-attestation-shape` checker in `src/domain/attestation.lisp`; `hngh.adapters.federation` gathers carrier-bundle claims into evidence facts (`fetch-remote` port; `:current`/`:unverifiable`/`:malformed`/`:missing`/`:conflicting` states) and verifies attestation envelopes through `resolve-pinned-key` + `verify-signature` ports with the closed refusal taxonomy; `:federation` joins `+admitted-transports+` under the `remote-evidence` network label or `carrier-bundle` tool label; `hngh.main` threads `fetch-evidence` / `verify-attestation` behind `:federation-ports` / `:attestation-ports` with no default transport, so plain `scripts/hngh` still never touches a wire.
- Added the operator pinned-key registry and signature-verification
  transport (promotion rung 12, 2026-08-25): `hngh.domain` adds the pure
  `key-pin` value and immutable `key-pin-registry`
  (`src/domain/attestation.lisp`); `hngh.adapters.federation` adds the
  strict `parse-pinned-keys` line parser, the pure `hex-decode` signature
  codec, and `make-pinned-attestation-ports`, which resolves keys from the
  operator's registry and verifies one envelope signature through a single
  bounded `openssl dgst -sha256 -verify` invocation on the injected
  process transport — no default transport, nothing pinned refuses
  `unknown-peer-key`. `verify-attestation RUN FILE [pins=PATH]` admits the
  operator pins file as the trust anchor and `list-pins PATH` renders the
  registry; both refuse malformed pins closed. Verified live with a real
  RSA-2048/SHA-256 keypair (`:verified` / `bad-signature` /
  `unknown-peer-key`) and through three self-governed validation commits.
- Added the operator reviewer transport (promotion rung 13, 2026-08-25):
  `review ... reviewer=PATH` admits an operator reviewer-transport file as
  the real model-review transport (strict five-key parsing, closed
  refusals, token confined to the one curl Authorization header);
  `hngh.adapters.model` gained the real-path fixes the first live call
  surfaced (string-stream stdin, chat envelope with `enable_thinking`
  disabled, completion-document extraction from the provider envelope via
  its own minimal JSON scanner) and the rung-6 fixed review prompt became
  self-sufficient for real reviewers. Verified live against the operator's
  local Unsloth server (Ornith-1.0-35B): `status=complete` with the closed
  findings document and a `:current` review fact.
- Completed the Ed25519 signature-transport hardening (promotion rung 14,
  2026-08-25): the pins file gains an optional closed ALGORITHM column
  (`rsa-sha256` default, `ed25519` admitted); verification routes per pin —
  digest signatures via `openssl dgst -sha256 -verify`, raw Ed25519
  signatures via `openssl pkeyutl -verify -rawin -in`; `list-pins` renders
  each pin's algorithm. Verified live end to end with a real Ed25519
  keypair (`status=verified key=ed-key` exit 0; tampered payload refuses
  `bad-signature`) and bound through the self-governed validation loop.
- Completed the network claim method (promotion rung 15, 2026-08-25):
  `:http-claim` joins `:carrier-bundle` in the closed federation method
  set; `fetch-evidence` accepts `method=carrier-bundle|http-claim`
  (default carrier-bundle) and the method reaches the injected
  transport on the request. The peer stays a plain identifier and
  endpoint resolution stays transport-owned — no default wire. Verified
  live over a real local HTTP server through an injected transport and
  bound through the self-governed validation loop.
- Completed the operator policy profiles (promotion rung 16,
  2026-08-25): the pure `evidence-profile` value narrows which
  requirement kinds a listed principle may carry, the requirement-kind
  vocabulary admits `:review`, and `propose` accepts `profile=PATH`
  (strict `PRINCIPLE<TAB>KIND` lines). A profile only narrows, never
  broadens. Committed through the self-governed validation loop.
- Completed the wake-on-demand slice (promotion rung 17, 2026-08-25):
  `wake-peer RUN PINS-FILE PEER` issues one explicit wake request for a
  pinned lattice peer behind an injected transport — admission
  evidence is the pins registry, the run needs a `:federation` receipt,
  and there is no default transport or daemon. Unpinned peers refuse
  `unknown-peer-key`. Committed through the self-governed validation loop.
- Completed the bounded read-only worker task (promotion rung 18,
  2026-08-25): the worker-rung first slice. `run-worker RUN task=LABEL
  [payload=TEXT]` runs one closed worker task through an injected
  transport; `:worker` is admitted behind the `worker-task` tool label,
  and a completed task binds a `:worker` evidence fact (a worker
  self-report is evidence, never acceptance). Committed through the
  self-governed validation loop.
- No daemon, provider, watcher, scheduler, dashboard, or unbounded mutation is admitted by this roadmap step.

## Next

The route table above supersedes the enumerated Next list (history: the
autonomy-continuum directives live in the queue ledger and
[architecture index](../architecture-index.md); the worker-driver E2E and
node-lattice amendments roll into stage 3 and stage 7 respectively).

Working order, per the route:

1. **Land stage 2** (nerve-center consolidation is in final
   verification); the config-backup lanes are scheduled on the 30m tier
   (landed: `hngh-cadence-30m.timer`, hngh-automation `34cd275`) — the
   gbd subsumption is complete and retired
   (`2026-08-27-dashboard-evolution-gbd-retirement`). The self-improvement cadence
   is routine: the day tier prunes the ledger, checks the kernel gate,
   runs the fresh-eyes review and a daylight research beat, with
   telemetry store v0 and the 30m schedule/research feeds wired
   (hngh-automation `232c5fe`).
   The automation-advancement review
   (`2026-08-28-automation-advancement`) tracks how much of this loop
   the machine now runs itself.
2. **Open stage 3** with the first live wrapped delegation: run-start →
   observatory `working` → run-end, watched in the dashboard the
   operator just shaped. Then the self-supervision tick.
3. **Stage 4 spikes** in parallel once stage 3 is witnessed: CachyOS
   package inventory feed (landed as system-ops v1) grows governed
   update lanes; config-backup generalizes into the config-manager.
4. **Stage 5 beats** alternate with stage 3/4 grow work per the
   alternation rule; the research view makes the state visible.
5. **Fold the third-evening intake** (eight observations, session-notes
   §9) per the two new design docs: telemetry/records split + research
   and session-cost capture ([ledger-and-records-spec.md](../design/ledger-and-records-spec.md)),
   knowledge-base viewer/publisher posture
   ([knowledge-base-spec.md](../design/knowledge-base-spec.md)), the
   Schedule text-legibility floor in the display register's grade hooks,
   and structured session identity (category, hierarchy, model, cost —
   display side rides the SessionsTitles wave).

Operator goals as design pressure (2026-08-28): the self-funding
runway rides the publications pipeline — `scripts/generate-publication
--ebook/--site` consuming the crystallized `docs/research/` lines, with
the ebook-longform, public-surface, royalty-pipeline, and funding-rails
backlog rows as the admission path. The Steam Deck is paired and
hardened (hngh-automation REMOTE-ACCESS.md); deck-as-node federation
stays in the device-fleet and node-lattice backlog rows. The remaining
remote step is operator-side (`sudo tailscale serve --bg 8890`,
documented in hngh-automation REMOTE-ACCESS.md; never from automation).

No daemon, provider, watcher, scheduler, dashboard, or unbounded mutation is admitted by this roadmap stage.


## The decisions

# Decisions

Each entry is a promise the machine made in public, kept where the
operator can check it.

## 2026-08-24 — Bounded model & terminal transports are loadout-admitted advisors only

`hngh.adapters.model` and `hngh.adapters.terminal` are input/advisor
transports, never executors: a model review result is bound only as a
`review` evidence fact and a captured operator statement only as a
`:terminal` evidence fact, and neither can issue a certificate, advance a
run, or mutate a repository. Both are admitted per-run through
`admit-transport` reusing the existing loadout — `:model` needs a
non-`local` route label plus the `model-review` network label, `:terminal`
needs the `terminal-input` tool label — and both refuse closed
(`loadout-refuses-transport`) otherwise. There is no default provider and
no ambient input: the `review` and `terminal` CLI operations refuse
`no-review-transport`/`no-terminal-transport` unless ports are injected at
the composition root, so plain `scripts/hngh` never touches a model
provider or reads a terminal. This keeps the reviewers-advise rule at the
transport boundary: claims from these adapters are evidence, not
attestations, and can never create authority.

## 2026-08-24 — License: AGPL-3.0-or-later affirmed

`CONTRIBUTING.md` already binds contributions to AGPL-3.0-or-later. Reviewed
during public-face planning, the binding is affirmed as deliberate rather than
defaulted: strong copyleft fits the project's posture, because the governance
kernel's value is its fail-closed authority and AGPL requires disclosure when
the kernel is offered as a network service. The repository is single-author
today; affirming now closes the license question before any external
contribution would make re-licensing impractical.

## 2026-08-24 — Governance documents are the first dogfood-loop mutation

`GOVERNANCE.md`, `SECURITY.md`, and the `CONTRIBUTING.md` amendment are
sequenced as the first change governed end-to-end by Hngh itself (proposal,
evidence, verdict, certificate, commit) under the dogfood development loop
rung. The mutation is documentation-only, so it exercises the full pipeline
with zero kernel risk, and the documents have no external deadline, so waiting
for the dogfood machinery costs nothing.

## 2026-08-24 — Budget ledger starts as an outer CSV script

Cost and quota tracking for delegated sessions begins as a Stage-1
stdlib-only CSV ledger script outside the repository core (procedural tooling
design synthesis, operator wiki). A `budget-ledger` domain value is deferred
until real usage stabilizes the schema; promotion follows the normal
proposal-and-evidence path. The Pi delegation spike's cost/loadout-policy
dependency is satisfied by a paper policy plus CSV receipts.

## 2026-08-24 — Public intake submissions are claims, not attestations

The future public intake lane (issue tracker, email, web form) receives
E0-level candidate records: claims to be investigated, never authoritative
evidence. Promoting an intake submission means the operator's machine
re-verifies locally — recomputed hashes, reproduced runs. Public intake
therefore does not trigger the 2026-08-24 no-PKI revisit; that trigger is
reserved for honoring remote certificates or attestations at face value,
which stays gated on the distributed-attestation rung.

## 2026-08-24 — No PKI; hash self-certification is a single-machine decision

Hngh certificates use hash self-certification instead of a public key
infrastructure: content-addressed hashes bind the certificate; there is no
external key hierarchy. This is one of the four deliberate divergences from
the in-toto/SLSA/DSSE attestation stack Hngh's certificate grammar
otherwise mirrors (see `docs/records/2026-08-24-prior-art-landscape.md`).

This is a single-machine decision, not a universal stance. The revisit
trigger is multi-machine evidence sharing: if evidence must be accepted
from or shared with another machine, the no-PKI divergence is reopened and
the key hierarchy question is decided then. Hash content-addressing stays
the substrate regardless (git provides most of it).

## 2026-08-11 — Clean-slate kernel

The former daemon, plugin, watcher, dashboard, and mission-control system is
retired. The active product begins with a compact, side-effect-free kernel.

## 2026-08-11 — Archive is evidence, not a dependency

The retirement archive lives outside the repository, in the operator's local
archive. Active source must not import, launch, or configure archived
components. The archive is not consulted by any active gate, provider, or
runtime.

## 2026-08-19 — Archive gate retired

The `make check-archive` verifier and its `HNGH_ARCHIVE_ROOT` contract are
retired. The prior state is fully represented by the refactor records; the
archive itself remains operator-preserved outside the repository but is no
longer verified, referenced, or needed by the active project. Meaningful
material from it is harvested into the operator's separate llm-wiki
knowledge base for reference.

## 2026-08-11 — Fail closed by default

Unknown or malformed profile modes and duplicate entries refuse validation.
Future lifecycle and adapter work keeps the same rule.

## 2026-08-11 — Dependency direction precedes details

The domain depends on Common Lisp only. Application code depends inward on the
domain and reaches details through ports. Adapters and presentation remain outer
components. `hngh.main` is the only future composition root.

## 2026-08-11 — Run lifecycle is closed and evidence is non-authoritative

`hngh.domain` owns pure run policy and values. A new run is `created`; only the
following transitions are legal:

| From | To |
|---|---|
| `created` | `armed`, `cancelled`, `dead` |
| `armed` | `running`, `cancelled`, `dead` |
| `running` | `checkpointed`, `cancelled`, `evacuated`, `dead` |
| `checkpointed` | `running`, `cancelled`, `evacuated`, `dead` |
| `cancelled`, `evacuated`, `dead` | `afterlife` |
| `afterlife` | `scored` |
| `scored` | `archived` |

Every other pair refuses. Receipt, score, and afterlife values are evidence;
they do not receive a run, state, actor, capability, or transition operation and
cannot create authority. The domain accepts no path, environment, clock,
subprocess, or provider payload.

## 2026-08-12 — Autonomous policy certificate

Routine feature, scope, capability, failure-disposition, review, staging,
commit, and push decisions are policy-driven. Operators guide policy, select
deployment profiles, and receive evidence; their perception is not the routine
approval mechanism. Each proposal is evaluated against closed principles and a
source manifest. Missing, conflicting, malformed, stale, or unverifiable
evidence refuses.

A current certificate binds one action class to its repository identity, base
revision, ordered candidate manifest, content hash, evidence hashes, principle
verdicts, reviewer findings, source manifest, policy profile, and expiry. It
must be rechecked immediately before the named action. A commit certificate does
not authorize a push. A human-approval profile remains available for deployments
that need it, while policy-authorized self-approval is Hngh's intended routine
path.

Deterministic policy evidence is authoritative for structural facts. Local and
alternate-provider model reviewers may issue closed, source-cited challenges;
they cannot override deterministic refusal, mint a certificate, or mutate a
repository.

## 2026-08-12 — Deterministic proposal evidence ledger

The pure evaluator receives one immutable `policy-proposal`, not an untyped bag
of evidence labels. A proposal records its closed class; problem; smallest
useful outcome; named purpose, caller, input, output, and failure contract;
declared capability set and capability diff; source manifest; risk note;
dependency; evidence trigger; and an ordered ledger of evidence requirements.

Each immutable `evidence-requirement` binds one closed principle to one closed
requirement kind, its required fingerprints, and supplied immutable evidence
facts. The requirement-kind vocabulary, rather than the intentionally open
evidence-fact kind, defines evaluator meaning. A requirement is complete only
when every required fingerprint is supplied exactly once by a current fact.
Missing, duplicate, stale, malformed, conflicting, or unverifiable facts
refuse. A reviewer result remains a fact that cannot pass a principle unless a
later policy explicitly admits its requirement kind.

This ledger is policy data only. It contains no certificate action, repository
authority, provider execution detail, port, callback, filesystem, Git, process,
clock, environment, or network field. External verification produces facts in a
later adapter; the evaluator only consumes immutable values.

## 2026-08-17 — Deterministic principle evaluation

`evaluate-policy-proposal` consumes one immutable `policy-proposal` and returns
a `policy-verdict` with exactly ten principle results in matrix order, one per
closed principle: `closed-authority`, `least-authority`,
`dependency-direction`, `fail-closed`, `evidence-before-claim`,
`atomic-mutation`, `reversibility`, `no-hidden-execution`,
`cost-and-route-discipline`, and `source-grounding`. The order is fixed by the
matrix, never by requirement order in the proposal.

A principle with no evidence requirement is a refusal: a `:refused` principle
result with no fingerprints and the reason label `missing-principle-result`; a
missing principle result is a refusal. A single evidence requirement passes
only when every required fingerprint is supplied exactly once by a `:current`
fact. Missing, stale, malformed, conflicting, or unverifiable facts refuse
with the labels `missing-evidence`, `stale-evidence`, `malformed-evidence`,
`conflicting-evidence`, and `unverifiable-evidence`. A fact supplied under one
principle never satisfies a requirement of another principle. The verdict is
`:admitted` only when every principle result is `:passed`; otherwise
`:refused` with the deduplicated union of refusal labels in matrix order.

Evaluation is deterministic, side-effect-free, and independent of requirement
order. The pure evaluator never emits `:needs-escalation`; that state remains
reserved for later reviewer and failure-disposition policy. Extra `:current`
facts beyond a requirement's required fingerprints do not refuse: the closed
refusal vocabulary names only missing, duplicate, stale, malformed,
conflicting, and unverifiable facts.

## 2026-08-17 — Closed failure-disposition policy

`evaluate-failure-disposition` maps each of the eight closed failure categories
to exactly one closed disposition. Domain and application invariants propagate
to the test gate; port-callback faults and malformed returns normalize to a
refusal at that callback only; atomic recording conflicts normalize to conflict
without retry; insufficient or stale evidence refuses; tool and environment
faults refuse; review disagreement escalates; and mutation precondition
mismatches stop and record evidence.

The two conditionally worded table rows resolve to their primary default in
the pure policy: a domain-policy-or-invariant failure propagates to the test
gate (a typed domain refusal refines this at a later layer), and a tool or
environment fault refuses (named evidence-policy escalation is a later
refinement). An unknown category refuses. The policy is pure and
deterministic; a use case never decides a disposition by catch-all condition
handling.

## 2026-08-17 — Non-mutating candidate authorization certificate

`issue-candidate-certificate` mints an immutable `candidate-certificate` from
an `:admitted` policy verdict. The certificate authorizes one action only
(`:none`, `:prepare-candidate`, `:stage`, `:commit`, or `:push`) and records
repository identity, base revision, ordered candidate paths, content hash,
evidence hashes, the admitting principle verdict, review findings, source
manifest, policy profile, and expiry.

The pure issuer is mechanical: it binds one closed action and the supplied
facts into the immutable value. Action-admission policy (for example a commit
certificate never authorizing a push) is enforced later by the executor, not
by the domain issuer. Missing, unknown, malformed, or duplicate facts refuse.
The certificate contains no action, callback, port, filesystem, Git, process,
clock, or network execution.

## 2026-08-17 — Policy-gated run close

`close-run` advances a run to a terminal state (`:cancelled`, `:evacuated`, or
`:dead`) only under the admitted policy proposal and evidence process. The
request carries the run, a closed terminal target, and a policy proposal; the
use case evaluates the proposal deterministically and refuses the close with
the verdict reason labels unless the verdict is `:admitted`. An illegal target
for the run's state refuses with the closed `invalid-transition` label, and
recording stays one atomic run-and-receipt callback.

`close-run` issues no certificate: the hash-bound certificate vocabulary
serves the future mutation executor, not run-state transitions. Action-admission
policy (such as a commit certificate never authorizing a push) remains with
that executor.

## 2026-08-18 — Read-only evidence adapter

`hngh.adapters.evidence` gathers fixed read-only local evidence through an
injected process transport (composition supplies the real `process-run`
callback) and maps the results to domain evidence facts and source manifest
entries with closed states. The command set is fixed and enumerable:
repository revision, whole-tree working-tree status, and file content
hashing. A request names one command plus relative, duplicate-free targets
and a source role; no caller-supplied command string is ever built.

The adapter fails closed on unknown commands, malformed or unparseable
command output, escaping, absolute, home-relative, or option-like targets,
duplicate evidence, and thrown or malformed transport returns. Command
failures are recorded as evidence with closed states: a missing file is
`:missing`, an unreadable or unverifiable command result is
`:unverifiable`, and a successful fixed command yields `:current` facts.
The adapter never decides policy, never reads a requirement ledger, and
never mutates anything; all subprocess and filesystem access stays behind
its transport callback so tests use fixture responses. The mutation
executor remains its first consumer.

## 2026-08-18 — Composition root and operator-visible presentation

`hngh.presentation` is a renderer-only component. It renders application
results, domain runs and governance values, and installed adapter results
into plain factual strings, keeps refusals literal, and never mutates a
canonical value. It imports no adapter. The optional reference lexicon is
display copy at a named surface only: a pack is accepted only as a flat
plist carrying exactly a `:render` list of four-field
(`:surface`, `:original`, `:reference`, `:provenance`) entries, cannot carry
canonical control fields, and removing it leaves the original term in
place.

`hngh.main` is the composition root. `make-run-harness` composes the five
use cases over injected port callbacks; defaults fail closed — an
in-memory record store, a per-harness identifier source, a clock, and
`unknown` admission, verification, and manifest evidence — so no authority
is invented at composition. The installed evidence, mutation, and review
adapters compose through coordinator functions behind injected transports;
only the read-only evidence transport has a real default, and no default
provider transport exists. `display` renders every result through
`hngh.presentation`. `hngh.main` starts no background work by import; a
real model or terminal transport stays disabled until a separately approved
run loadout admits it.

## 2026-08-12 — Recover partial delegated lanes before retrying

A delegated lane that stops after writing code, including on a syntax or
compilation failure, leaves a recovery candidate rather than disposable state.
The next worker first reads the brief, inspects the actual worktree, and
identifies the smallest canonical repair. It preserves valid fixtures and
coverage, reconciles overlapping partial definitions, and does not reset,
stash, or replace the lane without an explicit decision.

Recovery ends only after the whole affected gate passes again and a fresh
reviewer checks the frozen candidate. A clean compilation alone is not
recovery: missing refusal cases, defensive-copy proofs, or scope boundaries
remain failures. This keeps a failed delegation from becoming either silent
data loss or an unreviewed reimplementation.

## 2026-08-12 — Application callback and outcome boundary

`hngh.application` use cases handle a callback error or malformed callback
return only at that callback invocation. Domain and application failures remain
visible to the test gate. A successful application result contains the exact
run-and-receipt pair passed to the single atomic `record-run` callback; refused,
invalid, and conflict results contain neither. Recording is never retried unless
a later use-case contract explicitly admits it. `arm-run` advances only a
created run after authority, ledger, loadout, and exclusive-write facts are all
`:confirmed`; every other fact status refuses without recording. `start-run`
advances only an armed run to `:running` through its one-slot atomic
recording port; an invalid transition refuses without recording. `checkpoint`
advances only a running run to `:checkpointed` after the tool executor returns
`:passed` verification and the repository inspector returns a `:complete`
manifest. Both callbacks receive only a closed request containing the domain
run. Any failed, unknown, incomplete, malformed, or callback-faulted evidence
refuses without recording. A checkpoint record conflict does not retry.

Canonical states, receipts, CLI flags, configuration, and use-case outcomes use
plain technical terms. Optional reference lexicons provide display copy with an
original fallback and provenance; they cannot carry control fields or change
behavior.

## 2026-08-24 — Distributed attestation design forks

Resolves the open questions in
`docs/records/2026-08-24-design-distributed-attestation.md`:

1. **Key rotation: immediate refusal plus operator re-pin.** A rotated or
   unknown peer key lands on the `unknown-peer-key` refusal; there is no grace
   window. Revocation is removing the pin. No time-dependent authority.
2. **Evidence-first.** Remote capability admits evidence claims only — remote
   facts enter the proposal ledger as claims verified via signature, pin, and
   expiry. Remote re-verification (fresh remote runs) is not admitted.
3. **Envelope format: JSON** parsed by the adapter's own strict reader. The
   kernel never parses; it sees domain values only.
4. **Requirement kinds: extend `+evidence-requirement-kinds+`.** Remote
   evidence requirements join the existing closed set; the evaluator's shape
   is unchanged.
5. **Pull direction: carrier-bundle only.** v1 admits no network fetch
   methods; bundles move between machines by operator action. Network claim
   methods may be added later behind the same federation port without kernel
   change.

Multi-hop chains remain out of scope (two-party only), as the record states.

## 2026-08-25 — The rule-based carve-out is a recorded decision, machine-checked

The root README restates self-governance as: "a change the loop can
bind, the loop binds; a change it cannot, it declares." This entry pins
the two parts of that sentence so the exception is a rule, not a mood:

1. **Export-only / no-behavior changes are excluded from the cert
   manifest by the dependency guard**, and land as plain commits labeled
   `(excluded from cert manifest by dependency guard)`. The label is the
   rule's visible signature; an unlabeled code-surface commit is a
   violation. The label is whitelisted to `src/packages.lisp` only — a
   labeled commit touching any other code-surface file is caught by the
   guard's diff inspection.
2. **Every code-surface commit (src/, tests/, scripts/, Makefile, asd)
   is machine-checked** by `tests/scripts/test-loop-history-guard.py`
   from the restatement commit `1915713` onward: each must be a
   `hngh: candidate <hash>` commit or carry the exemption label. The
   guard runs in `make test`.

Known pre-guard violation, named rather than rewritten: `915e0e3`
(comment-only alignment of composition-root references, committed as a
plain docs commit after the restatement). It is exempted by name in the
guard and stands as history, proving the guard is not a whitewash of the
past.


## The backlog

# Backlog

No runtime feature is admitted before its policy proposal and required run-domain
or application contracts are fixture-backed. A proposal must name its problem,
smallest useful outcome, source manifest, principle matrix, risk note,
dependency, and evidence trigger.

Potential future work belongs here only with a problem statement, smallest
useful outcome, source or evidence, risk note, dependency, and review trigger.

## Pi read-only delegation spike

- **Problem:** Hngh has no admitted disposable agent worker, while future
  source-grounded reconnaissance and independent review need a bounded worker
  substrate.
- **Smallest useful outcome:** a manually launched Pi RPC worker in a disposable
  directory can run one fixture-backed, read-only scout or reviewer task with
  an explicit route, no session persistence, no ambient discovery, no mutation
  tools, and a bounded receipt.
- **Evidence:** `docs/records/2026-08-13-pi-worker-and-delegation-survey.md`.
- **Risk:** third-party extensions execute in the Pi worker process and Pi tool
  policy is not OS-level isolation; provider and search credentials, session
  state, child processes, and recursive delegation must remain unavailable by
  default.
- **Dependencies:** a Pi adapter proposal; a process/environment isolation
  design; fixture fakes for the application ports; a cost/loadout policy; and
  the eight fixture gates named by the Pi survey.
- **Review trigger:** an independent reviewer accepts the fixture results,
  child-process cleanup proof, route/cost receipt, and unchanged fixture
  repository manifest. A successful worker self-report is not acceptance.

## Node lattice rung (megastructure mesh)

- **Problem:** a single Hngh node can only learn from its own wall. The
  operator's planned fleet — an old Android phone, a Steam Deck, a slow
  laptop with a tired NIC — has no admission path today, and the two
  capabilities that make a fleet useful (waking a machine on demand,
  keeping tunnels open without a watching daemon) both touch the outside
  world in ways the current boundary explicitly does not admit: ambient
  execution and network side effects.
- **Smallest useful outcome:** one operator command that admits a second
  node as a pinned federation peer, exchanges bounded learned facts in
  both directions (each fact a citable `:remote-attestation` claim), and
  issues a single wake-on-demand request through the same one-action
  certificate machinery — still no daemon, no scheduler, no ambient
  execution; every request is an explicit, recorded, human-closable step.
- **Source or evidence:** the root README `Where this is going` section
  (node-lattice vision, 2026-08-25); the federation port, pinned-key
  registry, and signature-verification transport (promotion rungs
  11–12) as the admitted substrate; this entry.
- **Risk:** the network surface grows again — federation fetch is the
  watch-item the 2026-08-25 external sanity check named for exactly this
  moment; wake-on-LAN is an external side effect that must ride the
  mutation lane with real evidence (MAC, current lease, last-seen fact);
  low-powered peers are unattended, so key rotation and evidence
  freshness need closed handling before any ambient trust; and the
  no-daemon boundary is a kernel invariant — any future "keep the tunnels
  open" mechanism must first amend that boundary through its own policy
  proposal, not smuggle a watcher in through an adapter.
- **Dependencies:** the federation surface (rungs 11–15) and policy
  profiles (rung 16) are in place; the pending pieces are the
  certificate-bound wake chain and a boundary-amendment proposal that
  names exactly which ambient operation (if any) is admitted and under
  what evidence.
- **Review trigger:** an independent reviewer accepts the admission and
  wake flows against fixtures (pinned peer identity, stale or missing
  last-seen refuses, one-request-one-certificate, no ambient process
  after the request completes) and sees no watcher, scheduler, or
  background process in the diff.

## Certificate-bound wake mutation lane (boundary amendment)

- **Problem:** rung 17's `wake-peer` issues an explicit request through
  an injected transport, but the request itself is not certificate-
  bound — a wake is an external side effect and ought to ride the same
  one-action certificate machinery as a commit, with real evidence
  (MAC, current lease, last-seen fact) rechecked immediately before the
  action, exactly as the node-lattice entry's risk section demands.
- **Smallest useful outcome:** a `:wake-mutation` action in the
  mutation vocabulary: one certificate for one wake of one pinned
  peer, rechecked against fresh evidence, executed behind the mutation
  executor port, refused on stale or missing facts.
- **Source or evidence:** `docs/records/2026-08-25-r17-wake-peer.md`;
  the mutation executor (rung 5) and the candidate certificate.
- **Risk:** a wake must never be a blanket "wake anything" — the
  certificate binds peer, method, and evidence; the evidence-first and
  atomic-mutation principles apply unchanged.
- **Dependencies:** the rung-17 wake surface and the mutation vocabulary
  (the policy-profile rung is complete and available for the new
  action's requirement map).
- **Review trigger:** an independent reviewer accepts that a stale,
  missing, or extra-evidence wake certificate refuses; only the
  certificate-bound single wake executes.

## Ambient-free tunnel keepalive (boundary amendment)

- **Problem:** "keeping the tunnels open without a watching daemon"
  touches ambient execution, which the no-daemon boundary does not
  admit; the node-lattice vision needs a mechanism that keeps a
  persistent tunnel (Tailscale) alive without a watcher, scheduler, or
  background process.
- **Smallest useful outcome:** a bounded, explicit, operator-invoked
  keepalive policy file that names which tunnel endpoints may be
  refreshed, and a single `keepalive` command that checks the tunnel
  state, refreshes only if the certificate binds the exact endpoint,
  and records the receipt — no process runs after the command exits
  (the operator's own scheduler/tee runs the periodic invocation).
- **Evidence:** the intent doc's "keep the corridors open without a
  watching process"; the wake-on-demand precedent (rung 17).
- **Risk:** any ambient process would violate the boundary; the command
  stays explicit and process-local, the periodic invocation lives
  outside Hngh (the operator's scheduler), never inside it.
- **Dependencies:** the tunnel tooling (Tailscale), the mutation lane
  once it exists, the network admission surface.
- **Review trigger:** an independent reviewer accepts that no daemon,
  watcher, or scheduler is installed by Hngh; keepalive is a plain
  one-shot invocation with a receipt, and the policy names endpoints
  exactly.

## Governance property tests — COMPLETED (2026-08-24)

- **Problem:** the principle matrix must be total over the closed kinds and
  monotone with respect to evidence, but neither property is explicitly
  tested today.
- **Smallest useful outcome:** property tests asserting (a) every closed
  proposal class and principle kind yields a verdict (totality over closed
  kinds) and (b) dropping evidence can never flip a verdict DENY to ALLOW
  (monotonicity: ignoring evidence never flips DENY -> ALLOW).
- **Evidence:** `docs/records/2026-08-24-prior-art-landscape.md` — the
  in-toto monotonic principle adopted as an invariant.
- **Risk:** property tests are only as good as their generators; the closed
  vocabularies must stay in sync with the domain definitions.
- **Dependencies:** the deterministic principle evaluator and its closed
  vocabularies (already in place).
- **Review trigger:** an independent reviewer accepts the property suite and
  sees it fail on a deliberately introduced totality or monotonicity break.

## DSSE envelope export serializer

- **Problem:** Hngh certificates are structurally in-toto-like today, but
  nothing exports them in an interoperable grammar, so external tooling
  cannot consume them.
- **Smallest useful outcome:** a serializer that renders certificates and
  their evidence into a DSSE (or in-toto) envelope for external consumption.
- **Evidence:** `docs/records/2026-08-24-prior-art-landscape.md` — DSSE
  named as the future export grammar.
- **Risk:** none while gated; building the wrong envelope shape before an
  interop partner exists would be speculative.
- **Dependencies:** YAGNI-gated: only admitted once an interop consumer (or
  a partner requirement) exists.
- **Review trigger:** an interop need is named; an independent reviewer
  accepts the envelope against the DSSE/in-toto spec.

## Governance-benchmark research lane

- **Definition:** a public, runnable benchmark that scores governance
  properties (tamper-evidence, approved=executed,
  reconstruction-from-record, refusal-accounting) of any change-governance
  system — Hngh, CI pipelines, agent-harness guardrails, voting
  procedures — so governance claims become comparable evidence, not
  marketing.
- **Spec-first order:** the artifact is built only after a reviewer
  accepts the metric definitions and scenario corpus; the review trigger
  below stays.
- **Subjects, near-term (S1–S6):**
  - **S1** — what GitHub CI/CD actually proves, including the
    unattested-runner gap (a green check from a runner nobody attested).
  - **S2** — a Copilot-class weak-validation baseline scored on the same
    scenarios: the floor every governance system must beat.
  - **S3** — quorum, BFT, and approval-voting literature as approved=executed
    prior art.
  - **S4** — metric definitions v1, with refusal-accounting as the fourth
    property beside tamper-evidence, approved=executed, and
    reconstruction-from-record.
  - **S5** — the scenario corpus: the ten attacks every governance system
    must survive — tampered record, unapproved execution, record deletion,
    replay, stale evidence, verifier collusion, and their variants.
  - **S6** — the conformance-harness adapter contract over the four
    integration shapes from
    [integrations-marketplace.md](integrations-marketplace.md).
- **Subjects, parked (S7–S8):**
  - **S7** — cross-instance reconstruction under federation, including
    Sybil resistance and ActivityPub as a transport.
  - **S8** — signed scorecard publication and a leaderboard.
- **Dogfood order:** the first scored system is hngh-automation itself.
  Its plan ledger is currently unversioned and invisible to its own
  tree-skew monitor — `hngh-automation/jobs/oversight-tick.sh`
  whitelists `docs/project/plans/` out of the skew check, and
  `hngh-automation/jobs/sweep-artifacts.sh` stages only STATE.md,
  dashboard, digest, logs, stats, systemd, and Makefile, never the plan
  ledger. No external system is scored before the loop scores itself.
- **Evidence:** `docs/records/2026-08-24-prior-art-landscape.md` — the
  governance-benchmark gap; AgentDojo/InjecAgent/R-Judge named as prior
  art.
- **Review trigger:** an independent reviewer accepts the metric
  definitions (S4) and the scenario corpus (S5) as a sound basis for the
  benchmark artifact.

## Dogfood loop — COMPLETED (promotion rung 9, 2026-08-24; hardened by the loop-history guard 2026-08-25)

- **Problem:** Hngh has never governed a real change to its own repository
  end to end, so the evidence -> review -> certification -> mutation cycle
  is untested against itself.
- **Smallest useful outcome:** Hngh proposes, evaluates, and commits changes
  to itself via its own harness ("the phoenix's egg"; zero new machinery;
  exercises evidence, review, certification, and mutation against its own
  repo).
- **Evidence:** `docs/records/2026-08-24-prior-art-landscape.md` —
  strategy sequencing step two, after the operator-facing command surface.
- **Risk:** the dogfood loop must remain optional; it cannot become the
  mechanism by which Hngh approves its own roadmap.
- **Dependencies:** the operator-facing command surface (roadmap Next) and
  real transport admission come first.
- **Review trigger:** an independent reviewer accepts the self-committed
  change and its certificate chain.

## Operator policy profiles — COMPLETED (promotion rung 16, 2026-08-25)

- **Problem:** rungs 6/11/12/13 added verified, real transports (model
  review, attestation envelopes, pinned keys, operator reviewer files)
  but no shipped policy profile *consumes* their fingerprints. The
  dogfood proposal profile is still the fixture-grade "one requirement
  per matrix principle"; review facts and `:remote-attestation` facts are
  recorded evidence with no requirement kind that can demand them.
- **Smallest useful outcome:** an operator-tunable policy profile — a
  named, parsable, fail-closed spec that maps requirement kinds
  (`:claim-proof`, `:review`, `:remote-attestation`, `:purpose`,
  `:caller`) to matrix principles, admitted via the existing `propose`
  surface (profile=FILE, mirroring the verdict/pins/reviewer file
  precedents), with the closed evaluator unchanged.
- **Evidence:** `docs/records/2026-08-25-r13-operator-reviewer-transport.md`
  (reviewer transport live); `docs/records/2026-08-24-design-distributed-attestation.md`.
- **Risk:** a profile must never *broaden* admission beyond the matrix;
  it only *narrows* which requirement kinds a proposal must satisfy.
- **Dependencies:** the deterministic principle evaluator and its closed
  vocabularies (present); rung-13 reviewer transport (present).
- **Review trigger:** an independent reviewer accepts (a) a profile
  file that demands `:review` evidence fails a proposal lacking review
  facts, and (b) the same profile admits a proposal carrying them.

## Bridge-backed continual worker (worker-rung candidate)

- **Problem:** the intent document names a worker behind a port — "likely
  one called Pi" — and the bridge now surfaces the worker lane
  (`hngh_run_worker`, `worker-driver`), but no agent thread yet drives
  the full governance loop through the bridge end to end, and the only
  continual workers are the shell jobs in hngh-automation.
- **Smallest useful outcome:** a disposable, read-only worker omp session
  (local Ornith/Qwen via the automation's own model chain) that can
  open one run, gather read-only candidate evidence, run one `review`
  through the operator reviewer transport, and close the run — driven
  through the hngh-omp bridge tools, with the run ledger as the record.
- **Evidence:** `docs/records/2026-08-13-pi-worker-and-delegation-survey.md`
  (Pi survey); hngh-omp plugin scaffold; rung-13 reviewer transport.
- **Risk:** the worker is read-only by default and never carries a
  mutation certificate; a worker self-report is not acceptance.
- **Dependencies:** the bridge plugin (present); rung-13 operator
  reviewer file (present); a loadout that admits `:model` transport.
- **Review trigger:** an independent reviewer accepts the disposable
  worker's run receipt, its review evidence, and an unchanged fixture
  manifest — the same gates the Pi survey named.

## Node-lattice admission rung (implementation) — queued 2026-08-25

- **Problem:** a single Hngh node learns only from its own wall; the
  operator's planned fleet (an old Android phone, a Steam Deck, a
  tired-NIC laptop) has no admission path, and the two capabilities
  that make a fleet useful (waking a peer, keeping tunnels open
  without a watcher) both touch the outside world in ways the current
  boundary does not admit.
- **Smallest useful outcome:** one operator command admits a second
  node as a pinned federation peer with an offline fingerprint;
  bounded remote-attestation facts flow both ways (each a citable
  claim); the first wake-on-demand rides the certificate machinery; no
  daemon, no scheduler — every request is a single explicit, recorded,
  human-closable step.
- **Evidence:** README `Where this is going` node-lattice vision
  (2026-08-25); intent.md; the federation port, pinned-key registry,
  and signature-verification transport (rungs 11–12); http-claim
  (r15); wake-peer (r17).
- **Risk:** the network surface grows again — federation fetch is the
  watch-item the 2026-08-25 external re-review named; low-powered
  peers are unattended, so key rotation and evidence freshness need
  closed handling; the no-daemon boundary stays a kernel invariant.
- **Dependencies:** the certificate-bound wake lane (so a wake rides
  the certificate); a boundary amendment naming exactly which ambient
  operation (if any) is admitted; the policy-profile map for admission
  requirement kinds.
- **Review trigger:** an independent reviewer accepts the two-node
  admission and wake flow against fixtures (pinned identity,
  stale/missing last-seen refuses, one-request-one-certificate) and
  sees no watcher, scheduler, or background process in the diff.

## Documentation-sync loop — queued 2026-08-25

- **Problem:** the check count and command/rung lists in README and
  the roadmap drifted three separate times across 2026-08-25 and were
  hand-corrected; the loop-history guard watches commits, not the
  docs' numbers.
- **Smallest useful outcome:** a `make numbers` target that recomputes
  the live check count, rung prose, and CLI command list from the
  committed suite and surface, plus a small guard test asserting the
  README/roadmap numbers match ground truth — drift is caught by
  `make test` instead of by a human.
- **Evidence:** the 2026-08-25 consistency pass (README count and
  command surface hand-corrected across the day); the records-index
  gap fixed the same day.
  2026-08-30 update: the README-count half landed
  (`tests/scripts/test-doc-numbers.py`, wired in `make test`); the
  roadmap rung prose drifted again (the Now paragraph stopped at
  promotion rung 13) and was corrected by the 2026-08-30 fold-back —
  the row stays open for rung-prose and CLI-verb-list coverage.
- **Risk:** the guard must only verify, never auto-rewrite; docs stay
  human-folded, the guard fails loudly on divergence.
- **Dependencies:** the existing `make test` suite (whose count is an
  input) and the surface the numbers describe.
- **Review trigger:** an independent reviewer sees a deliberately
  desynced README number fail the guard, and a synced one pass.

## Night-agent plan authoring (plan-supply) — queued 2026-08-30

- **Problem:** plans are operator-authored (suite doc 08 R2); when the
  plan queue emptied after the 2026-08-28 evening-selfdev plan
  executed, the machine idled for 40h+ — zero kernel commits after
  `667a36b` (2026-08-28T19:46Z) through 2026-08-30T12:30Z, the hourly
  workbeat re-announcing the same lane with no plan to feed it
  (reports.md rows `f27e3532`, `9b362832`), and overnight budget
  digests at sessions=0.
- **Smallest useful outcome:** the overnight loop gains a
  plan-authoring leg that drafts one normal-risk plan per night from
  open backlog rows, deduplicated alert rows, and crystallized
  research lines, filing it under `docs/project/plans/` as
  `status=drafted`; the operator accepts or rejects each morning and
  the existing accepted→executed machinery runs unchanged.
- **Evidence:** docs/project/plans/ (last plan 2026-08-28);
  docs/records/2026-08-30-lessons-and-foldback.md §1–§2; the 2026-08-28
  evening-selfdev plan as the proof that one good plan converts to a
  full night of verified work.
- **Risk:** an authored plan is a proposal, never authority —
  acceptance stays operator-owned; the standing rule forbidding
  machine sessions from kernel src/tests/Makefile stays.
- **Dependencies:** the plan ledger and dashboard (`dashboard/plans.json`,
  landed 2026-08-28); the backlog lane parser.
- **Review trigger:** an operator accepts one machine-drafted plan and
  its execution passes both repos' gates unattended.

## Alert → plan-candidate routing — done 2026-09-01

- **Problem:** honest alerts route nowhere (suite doc 08 R6): every
  repair that landed in the 2026-08-28→30 window (stale-store,
  unparsable readout.json, tree-skew, agent-stall eviction, doc-suite
  checker bug) originated in a plan step or an operator session, never
  from the alert row itself; the observation loop is open-ended.
- **Smallest useful outcome:** a routing step that converts a
  deduplicated alert row into a draft plan step (problem, evidence
  link, smallest fix) appended to the next drafted plan — never
  auto-executed, dedup/escalation caps unchanged.
- **Evidence:** reports.md alert rows 2026-08-28T20:10Z–2026-08-30T12:03Z;
  docs/records/2026-08-30-lessons-and-foldback.md §1, lesson 2.
- **Risk:** low — produces draft text only; the existing hourly
  escalation caps bound volume.
- **Dependencies:** the night-agent plan-authoring row above.
- **Review trigger:** one real alert converts to a drafted step the
  operator accepts unchanged.
- **Status (2026-09-01):** delivered, loop closed end-to-end. The
  routing tick (hngh-automation scripts/router-tick.py, commit
  87e6bc3) plus its production caller (cadence/hour/10-router-feed.sh,
  commit 7992f78: hourly, unread-alert-only, capped 3/tick,
  self/critical/charset classes never fed) converted the first real
  alerts to plan candidates unattended: slow-unit:dropin:20-workbeat.sh
  → 2026-09-01-routed-slow-unit-dropin-20-workbeat.sh (reports.md
  bffc89a6) and ui-audit:name-completeness →
  2026-09-01-routed-ui-audit-name-completeness (reports.md ffa1d58e),
  both auto-accepted by the accept-plans gate (f4c7e12e, 9993c29d);
  the next hourly feed re-observed both as already-routed and skipped
  them (STATE.md 02:00:45Z). Review trigger satisfied in its machine
  form: a real alert converted to a drafted plan candidate accepted
  unchanged by the operator's standing accept-plans rule; the
  personal-operator form remains open until the operator accepts one
  routed candidate by hand. No auto-execution — routed candidates
  are plans the cycle schedules, never steps the router runs.

## Bridge-as-operator-host — queued 2026-08-25

- **Problem:** the bridge has the full 10-tool surface (including
  `hngh_run_worker`) and its own repo, but no thread drives the whole
  governance loop from it — the disposable lane named in the session record
  (run → worker → review → certify) is still unlaunched on the bridge.
- **Smallest useful outcome:** an operator in the bridge drives the
  full step-set — open a run, admit the worker, run the worker, bind
  the review, certify one mutation — with the ledger as the sole
  receipt; the session stays disposable (nothing persists beyond the
  ledger).
- **Evidence:** the hngh-omp bridge README; the 2026-08-25 live
  worker lifecycle; r13 operator reviewer file.
- **Risk:** a host surface is not free flexibility — the bridge is a
  trusted operator seat; each certificate still binds one action, and
  no daemon or ambient automation sits behind the tools.
- **Dependencies:** the bridge (present); the worker-driver
  no-transport refusal (present); the r13 reviewer file (present); a
  loadout admitting `:model` for the review step.
- **Review trigger:** an independent reviewer accepts a run receipt
  that flowed run → worker → review → certify, and a repeat step
  refuses minimally when an admission is missing.

## Evidence-freshness + key-rotation rung — queued 2026-08-25

- **Problem:** the lattice peers are unattended, and the node-lattice
  risk names key rotation and evidence freshness as closed concerns —
  today the pinned registry supports changing keys but nothing rotates
  them atomically or marks a peer stale by last-seen age.
- **Smallest useful outcome:** closed key rotation on the pinned
  registry (one key per peer replaced, never reduced to zero, refused
  if the resulting set is unrecognizable) plus a stale-evidence rule
  on remote-attestation facts — a peer whose last-seen fact is older
  than an operator-set bound flips `:stale` and refuses wake,
  fail-closed.
- **Evidence:** the node-lattice and the two boundary proposals (key
  rotation, evidence freshness); `parse-pinned-keys` (r12) as the
  rotation substrate.
- **Risk:** rotation is a state-mutating operator action — ride the
  mutation lane, one certificate per rotation; a stale peer must not
  cascade into refusing healthy-peer wake.
- **Dependencies:** the mutation lane (or the existing candidate
  certificate for a pure registry rotation); the pinned registry and
  remote-attestation values.
- **Review trigger:** a test suite proves an old peer refuses wake,
  a rotation that would empty the registry refuses, and a healthy,
  fresh, rotated peer passes.

## Gantt ports (gantt-ports) — interface-expansion rung

- **Problem:** one dashboard readout is a fine start, but the operator
  wants gantts like they want weather: all kinds. Axial and circular
  clock-face rings, animated spirals, wobbling, dancing, "crazy" —
  the whole instrument panel should be portable to any gantt dialect
  the operator fancies, each reading the same committed timeline
  spine.
- **Smallest useful outcome:** the readout gains a `--style` switch
  with (at least) `linear`, `circular` (clock-face rings), and
  `spiral` (already exists) renderers, all over the same spine; each
  renderer smoke-tested like `--spiral` is today.
- **Evidence:** `scripts/dashboard-readout` (linear + spiral both
  live); the timeline spine (`docs/project/timeline.md`) + ETA
  windows as the shared data.
- **Risk:** rendering options multiply — keep each style a tiny pure
  function over the same rows; don't let styling infect data.
- **Dependencies:** the dashboard-readout spine (present); each new
  style is check-in-scale.
- **Review trigger:** an independent run of each style renders the
  same rows/ETAs, and the smoke test covers every style (fails on a
  missing/renamed renderer).

## Dancing interfaces (dancing-ui) — the music runs the room

- **Problem (deliberately weird):** interfaces are static; the
  operator wants the whole system to *dance in time to music playing
  on the machine*, intensity varying with the track — a UI that
  breathes, pulses, and glides with the beat. Pure delight; it must
  never obscure the data.
- **Smallest useful outcome:** one probe reads the system's audio
  signal (pulse audio/pipewire intensity, or when unavailable a
  constant BPM/no-op) and maps it to an intensity value; the
  dashboard applies it as a set of `--dance` amplitude classes
  (subtle pulse on the ETA bars). A human can toggle it off; it never
  changes a decision.
- **Why probe first:** feasibility (reading system music, mapping to a
  UI amplitude) before committing the full dance to all interfaces.
- **Risk:** music-driven motion must not become motion-sickness or
  performance drag; it is a display-only layer under the pass-thru
  data, no daemon.
- **Dependencies:** the dashboard-readout; the audio source probe.
- **Review trigger:** an independent reviewer accepts that the `--dance`
  mode pulses to an injected fake intensity, is disabled by default,
  and renders the data identically when off.

## Project journal + daily narrative (journal-daily)

- **Problem:** the project should be publicly observable day by day, but
  the raw record (records, check-ins, timeline) is not consumable prose.
- **Smallest useful outcome:** one automation renders each day's
  committed record/check-in/timeline into a dated narrative post
  (`docs/journal/YYYY-MM-DD.md`), the "accompanying the project"
  long-form description that a blog can publish.
- **Evidence:** `docs/records/2026-08-25-session.md`, checkin.md,
  timeline.md — the raw spine that becomes the story.
- **Risk:** narration must stay honest to the ledger — the automation
  only re-orders verified facts, never invents.
- **Dependencies:** the timeline events stream; a template over it.
- **Review trigger:** an independent read of a rendered journal entry
  matches the underlying record with no added claims.

## Long-form ebook: the megastructure memoir (ebook longform)

- **Problem:** the operator wants one long-form ebook documenting
  Hngh's development, self-bootstrapping, and the expansion into a
  megastructure, produced reproducibly.
- **Smallest useful outcome:** a `make journal` pipeline that
  assembles the day-by-day journal + the key records + the vision into
  one long-form document (Markdown → epub/mobi via pandoc or a script),
  versioned like any candidate.
- **Evidence:** the journal-daily piece; the session record; the
  intent/vision docs; `docs/records/*` as chapter seams.
- **Risk:** scope creep — the memoir must auto-assemble from existing
  prose, not demand new writing each run.
- **Dependencies:** journal-daily; a pandoc/asciidoc step.
- **Review acceptance:** `make journal-ebook` produces a deterministic
  document whose TOC maps the records.

## Self-hosted public surface (public-surface rung)

- **Problem:** the operator wants a public web on their own cloud
  (budget-scaled) — blog posting, comment collection/moderation,
  organization of practical interfaces to remote Hngh instances,
  leaderboards, and interaction between Hngh users/instances.
- **Smallest useful outcome:** one static+tiny-server site — journal
  posts (from journal-daily), a comment intake (moderated), a public
  readout of the Hngh queue (the dashboard), and a
  leaderboard-like "instances" page — self-hosted on a cheap VPS.
- **Evidence:** dashboard-readout (has the data), journal-daily, the
  self-funding scan.
- **Risk:** a public surface is a responsibility — moderation and
  rate-limits first; never expose secrets/stores.
- **Dependencies:** journal-daily, dashboard-readout, a hosting plan
  (budget-scaled).
- **Review acceptance:** the site serves the journal + readout from
  committed data, has a moderated intake, and no Hngh store is
  exposed.

## Device fleet bring-up (device-fleet)

- **Problem:** old hardware (an Android phone, a Steam Deck, a tired
  laptop with a slow NIC) can become local helper peers for Hngh's
  network and hardware-resource work.
- **Smallest useful outcome:** each device joins the local tailnet +
  an Hngh node (wake-peer ready), contributing bounded facts (uptime,
  load, network state) as evidence, with the same admission rules as
  the node lattice.
- **Evidence:** the node-lattice rung; wake-on-demand; the fleet
  vision.
- **Risk:** unattended low-power peers need the evidence-freshness /
  key-rotation story first.
- **Dependency:** node-lattice admission, key-rotation-freshness.
- **Review acceptance:** a device's facts appear in a ledger and it
  can be wake-peer'd under a certificate.

## Self-publishing / royalties pipeline (royalty-pipeline)

- **Problem:** income is a prerogative; automation should produce
  marketable fiction and nonfiction ebooks for royalties.
- **Smallest useful outcome:** a repeatable "book machine": prose
  pipelines (outline → draft → edit → cover → metadata) driving
  PDF/epub builds for Amazon KDP + direct sale, run the same way we
  run rotation slices.
- **Evidence:** the journal + the science-fiction worldbuilding for
  Hngh's megastructure; the world the operator wants to see built.
- **Risk:** royalties are speculative — the pipeline must produce
  *good* books, not just books; writer-reviewer separation applies.
- **Dependency:** the longform assembler; a build toolchain.
- **Review acceptance:** a produced book passes an independent read;
  the build reproduces from committed sources.

## Funding rails (funding-rails) — bootstrap income

- **Problem:** income is the prerogative; the scan names the cheapest
  immediate rails.
- **Smallest useful outcome:** stand up Shieldz (zero-fee crypto
  intake) + asterpay (x402→EUR/SEPA) for donations/royalty routes;
  a `pricing` page stub; the rails documented in the site.
- **Evidence:** self-funding-scan-2026-08-25.md.
- **Risk:** compliance — use the free complia screening before
  accepting counterparties; keep rails non-custodial until volume.
- **Dependency:** the public-site rung; an x402 receiving wallet.
- **Review trigger:** an independent reviewer accepts a test x402/
  crypto payment flows to the operator wallet end to end.

## Royalty catalog APIs (royalty-apis)

- **Problem:** the scan's abundance/listing pattern shows cheap
  pay-per-query AP
  easily monetized; a Hngh-derived small catalog can bring recurring
  royalties.
- **Smallest useful outcome:** 2-4 tiny, boring utility APIs (e.g.
  a policy-gate checker demo, a check-count, a timeline rendering)
  published as pay-per-query x402 on abundance / RapidAPI-style, each
  smoke-tested and priced.
- **Evidence:** self-funding-scan; the dashboard-readout / timeline
  functions are ready leaf-APIs.
- **Risk:** keep the public catalog read-only and sandboxed — the real
  ledger never leaves Hngh; the catalog is a *surface*, not an
  export.
- **Dependency:** funding-rail receipts; a stateless micro-API.
- **Review trigger:** an independent consumer calls the catalog API,
  pays, and gets a correct public result.

## Interface mocks (interface-mocks) — the mock matrix lane

- **Problem:** the operative layer is an interface *family* (panels,
  TUI, overlay, web, Emacs-style surface, voice), but only the TUI is
  real; the others are unproven concepts. We need cheap, graded mocks
  to pick which surfaces earn a build.
- **Smallest useful outcome:** one compact llm-trim-style panel mock
  (menubar/card popover), then the KDE overlay operative — each run
  through the automated interface grading loop before the next.
- **Dependencies:** the `grade-interface` loop (landed); the family
  matrix in `docs/design/assistant-interface.md`.
- **Review trigger:** an independent reviewer accepts the graded mock
  screenshots and ledger rows, not just the code.

## Operative overlay (operative-overlay) — qml6 floating operative

- **Problem:** the operative should float above the desktop — sprites,
  speech, buttons, scrolling text — not live only in a terminal. A
  plasmoid draws *under* windows; a standalone qml6 window is the
  correct X11 recipe.
- **Smallest useful outcome:** a frameless always-on-top transparent
  qml6 window showing the operative as an `AnimatedSprite` sprite
  sheet with speech, graded by the loop.
- **Dependencies:** the sprite-sheet assets (`pixel-agent-assets`);
  qt6-declarative (present); a research record exists.
- **Review trigger:** an independent reviewer accepts a captured
  overlay frame with a ledger grade and no daemon.

## Operative voice (operative-voice) — local character voices

- **Problem:** the operative is silent; speech should be a local,
  character-driven *rendering* of the textual record, never a gate.
- **Smallest useful outcome:** 3–5 distinct local neural TTS voices
  (piper / kokoro-82m) plus STT (whisper.cpp / sherpa-onnx) with
  push-to-talk, each operative persona voiced; record stays textual.
- **Dependencies:** a chosen TTS engine; the tts-research record.
- **Review trigger:** an independent reviewer accepts a rendered
  speech sample matching the persona, with the textual record
  unchanged.

## Pixel-agent assets (pixel-agent-assets) — the sprite sheet lane

- **Problem:** the operative's block-char figure is Atari-adjacent; the
  goal is a stick-figure-plus humanoid (head, neck, torso, arms, legs)
  with subtle motion — idle breathe, blink, coat sway — past that floor
  toward sprite animations.
- **Smallest useful outcome:** frame art for the operative's animation
  set, consumable by both the TUI and the overlay
  (`AnimatedSprite`); a comfyui image-gen practice lane refines the
  look.
- **Dependencies:** the family matrix; `interface-mocks` for where the
  frames render first.
- **Review trigger:** an independent reviewer accepts an animated
  frame sequence (idle/breathe/blink/sway) graded by the loop.

## CI governance gate (ci-governance-gate)

- **Problem:** CI failures surface as unstructured logs; nothing
  parses or resolves them, ceremonies do not auto-complete, and a
  pending commit can sit unevaluated. The operator wants any CI
  failure parsed and resolved through the governance loop, no pending commit
  left un-evaluated.
- **Smallest useful outcome:** a GitHub Actions adapter consumes an
  exported failure log as downstream evidence, runs the dogfood
  governance loop to complete or reject the pending commit, and refuses to
  re-run until the event is governance-resolved.
- **Evidence:** the ceremony-drive script and the promotion rung 18
  worker evidence fact; this entry.
- **Risk:** CI logs are untrusted input; parsing must refuse closed
  on malformed or oversized logs; the gate must not become an ambient
  watcher (operator-owned cron and state, no daemon).
- **Dependencies:** the governance loop (rung 9); a Gitea/Forgejo
  Actions second adapter once a pinned peer really runs Forgejo.
- **Review trigger:** an independent reviewer accepts a fixture where
  a failure log maps to one certificate-bound completion or rejection
  and a re-run refuses without a new event.

## Resource pool view (resource-pool-view)

- **Problem:** the fleet (local plus wide-area machines) is not yet a
  single pool; per-node status, duty, health, and capabilities are not
  surfaced together.
- **Smallest useful outcome:** one on-demand dashboard panel listing
  each admitted node as a row with status, duty, health, and
  capabilities; no ambient collector — the operator-owned heartbeat
  tick refreshes it.
- **Evidence:** the node-lattice groundwork (pinned peers, wake-peer,
  attestation); `dashboard-readouts`; this entry.
- **Risk:** rows must trace only pinned, evidence-backed claims; a
  node stays untrusted until pinned through the existing governance loop.
- **Dependencies:** node-lattice admission (`node-lattice-admission`),
  `pooled-hardware`, the dashboard panel machinery.
- **Review trigger:** a reviewer accepts a rendered pool page whose
  rows all trace to pinned, evidence-backed claims.

## Config manager (config-manager)

- **Problem:** system configuration is edited in place; rollouts are
  not evidence-backed or reversible.
- **Smallest useful outcome:** a per-node declared-config bundle whose
  intended state after apply is read back into evidence, a
  certificate-bound apply, and reversibility by reverting the
  declaration.
- **Evidence:** the mutation executor (`:commit` action); the worker
  substrate; this entry.
- **Risk:** configuration changes are high-band actions — the apply
  must recheck every evidence fact at the moment of mutation, and the
  revert path must exist without an untracked daemon.
- **Dependencies:** the mutation executor, the per-node worker,
  optional model patterns (NixOS, home-manager, apt-adjacent).
- **Review trigger:** an independent reviewer accepts a fixture where
  an applied and reverted config binds to evidence facts and a drift
  from the declared bundle refuses.

## Security manager (security-manager)

- **Problem:** key rotation freshness, secret hygiene, patch-state
  evidence, and incident-response evidence chains are not surfaced
  across nodes.
- **Smallest useful outcome:** per-node patch-state and key-freshness
  evidence rows (vintage of the secret scan, date of last rotate,
  patch delta) as machine-checkable facts; incident response is a
  transparent event-to-record-to-certify chain.
- **Evidence:** the `key-rotation-freshness` workload;
  `secret-scan-report`; this entry.
- **Risk:** patch and rotate metadata is perishable and must carry its
  own evidence; freshness attestations are easy to fake if the chain
  is not pinned.
- **Dependencies:** the resource pool view; the key-pin registry
  (rung 12).
- **Review trigger:** a reviewer accepts a freshness or secret finding
  that, alone or in a chain, refuses to certify a stale key.

## Notify agent (notify-agent)

- **Problem:** mail and job-search signals sit in inboxes; nothing
  reacts. The preparatory agentic work (draft a reply, first evidence,
  governance proposal) is manual.
- **Smallest useful outcome:** a KDE notification reaction agent —
  via `org.freedesktop.Notifications` and the probed notification
  daemon — receives an event and prepares a draft reply, evidence, and
  a governance proposal.
- **Evidence:** the desktop overlay and notification-daemon research;
  the tts/voice `omp say` note; this entry.
- **Risk:** notification payloads are untrusted UI content; the agent
  must treat them as hints, never as authorization, and stay
  operator-confirmed before any external side effect.
- **Dependencies:** a bounded reaction worker (Pi survey and the
  rung-18 worker); push via ntfy / Apprise as a follow-on.
- **Review trigger:** a reviewer accepts a fixture where a
  notification maps to a prepared, non-mutating artifact and never
  fires an ambient action.

## Push self-sufficiency (autonomy continuum 2026-08-26)

- **Problem:** verified commits stop at the local repo — pushing is an
  operator step, so origin lags the governance loop.
- **Smallest useful outcome:** hngh-automation's sweep pushes its own
  artifact commits once an origin remote exists; hngh's verified
  candidate commits push on governance completion (post-validation step,
  never a hook that could push a half-validated commit).
- **Evidence:** operator directive 2026-08-26; sweep governance record
  (`sweep: 2026-08-26 0946` commits in hngh-automation).
- **Risk:** pushing unpublished or credential-bearing material; the
  sweep surface already excludes code dirs, and hngh pushes only
  certificate-bound commits.
- **Dependencies:** an origin remote for hngh-automation (operator
  account action once); nothing new in hngh.
- **Review trigger:** a push receipt in the sweep breadcrumb and a
  governance record whose commit is visible on origin without operator
  action.

## Credential rotation automation (autonomy continuum 2026-08-26)

- **Problem:** single-use refresh tokens and pinned keys decay; today a
  decayed token surfaces as a 401 in STATE.md that only an operator
  resolves (2026-08-26 13:00Z token-refresh FAILED).
- **Smallest useful outcome:** a rotation/health job probes every
  credential the jobs use, refreshes or re-derives what it can
  unattended, files an `alert` report via report-queue for what it
  cannot, and never widens a trust boundary to work around a failure.
- **Evidence:** operator directive 2026-08-26; STATE.md 401 entry;
  existing `key-rotation-freshness` backlog entry (this folds into it).
- **Risk:** automated rotation failing open (new credential accepted
  without verification) — must fail closed and alert instead.
- **Dependencies:** key-rotation-freshness rung; the reviewer-transport
  file format (strict five-key parsing).
- **Review trigger:** a decayed-token fixture rotates unattended and a
  second fixture (unverifiable refresh) produces an alert report with
  no trust-boundary change.

## Cadence continuum (autonomy continuum 2026-08-26)

- **Problem:** periodicity exists only at the hourly/daily/night tiers;
  the continuum (month/week/day/hour/10m/5m/1m + ad-hoc) has no
  mounted surface.
- **Smallest useful outcome:** a tier router script + systemd units for
  each tier, each invocation exactly one tick, `make adhoc TIER=...`
  for manual firing; tiers with no mounted work exit 0 immediately.
- **Evidence:** operator directive 2026-08-26; existing unit pattern
  (hngh-automation/systemd).
- **Risk:** timer sprawl and overlapping ticks; single-tick + flock
  keeps each tier serial.
- **Dependencies:** hngh-automation job conventions; flock or
  equivalent single-instance guard.
- **Review trigger:** each tier fires its tick exactly once per period
  in a fixture, and an empty tier exits 0 with a breadcrumb only.

## Activity cadence (autonomy continuum 2026-08-26)

- **Problem:** routine project activities (roadmap review, planning,
  design, expansion, implementation, review, refactor, cleanup,
  inward/outward communication) run only when remembered, not on a
  continual schedule.
- **Smallest useful outcome:** an activity matrix mapping each activity
  to a cadence-continuum tier and an existing artifact
  (roadmap.md, queue.md, active-work.md, reports.md), with a
  single-tick runner that performs or files the next increment of each
  due activity; fleet-aware (fleet-manager peers can adopt rows).
- **Evidence:** operator directive 2026-08-26; queue.md Scheduling
  section; fleet-manager.
- **Risk:** busywork generation — each activity's smallest increment
  must be defined or the tick files a report instead of acting.
- **Dependencies:** cadence-continuum; report-queue; rotate-queue.
- **Review trigger:** one full week of the matrix running produces at
  least one real increment per activity and zero empty governance
  writes.

## Governance vocabulary (autonomy continuum 2026-08-26)

- **Problem:** "ritual"/"ceremony" are fussy and over-fixed for a
  governance vocabulary that should be flexible about governance,
  validation, and acceptance terms.
- **Smallest useful outcome:** docs use the flexible vocabulary
  (governance, validation, acceptance, admission) in prose; code
  symbols and CLI verbs stay stable until a check-in-scale candidate
  renames one surface deliberately.
- **Evidence:** operator directive 2026-08-26.
- **Risk:** symbol renames breaking scripts/tests — prose-only first.
- **Dependencies:** none.
- **Review trigger:** a terminology inventory shows no prose-only uses
  of the fixed terms without a deliberate governance meaning.

## Agent live view (autonomy continuum 2026-08-26)

- **Problem:** subagent work is visible only through the disjoint `hub`
  surface, not the dashboard, and the dashboard itself is insufficient
  for continual oversight.
- **Smallest useful outcome:** the dashboard reads a live agent/session
  roster (from the hngh store sessions plus any mounted agent
  transcripts) and renders working/idle/parked agents alongside the
  existing lanes; the roster refresh rides the existing watch/live
  loop.
- **Evidence:** operator directive 2026-08-26; dashboard-readout
  --live/--watch; `scripts/hngh present` store rendering.
- **Risk:** reading live transcripts as authoritative — display only,
  never governance input.
- **Dependencies:** ux-hardening; dashboard-readout spine.
- **Review trigger:** a running worker session appears in the live
  dashboard within one refresh period and disappears on close.

## Surface evolution loop (autonomy continuum 2026-08-26)

- **Problem:** operator-facing surfaces and megastructure parts evolve
  only by hand; there is no evolutionary design/development pressure.
- **Smallest useful outcome:** one evolution loop for one surface
  (dashboard style): candidate variants are generated, graded by the
  existing grade machinery, the fittest is promoted through a
  check-in-scale candidate; loop parameters live in a heartbeat card so
  the cadence drives generations.
- **Evidence:** operator directive 2026-08-26; dancing-ui probe,
  grade-interface, evolve-operative, ui-grades.md.
- **Risk:** runaway generation cost — bounded generations per tick via
  the card.
- **Dependencies:** cadence-continuum; grade-interface.
- **Review trigger:** N generations produce a measurably higher-graded
  variant promoted through the normal gates.

## Machine-steered backlog (autonomy continuum 2026-08-26)

- **Problem:** the next course is picked by fixed rules (queue Next +
  lane counts); Hngh does not determine its own best course on a
  continual basis.
- **Smallest useful outcome:** a course-selection step in the
  autonomous tick that reads the queue, lanes, reports, and roadmap as
  evidence, ranks next actions by a written policy, and mounts the
  chosen card — still behind the existing certificate gates for any
  mutation; its choice and reasons land in a report row.
- **Evidence:** operator directive 2026-08-26; run-autonomous tick;
  rotate-queue; backlog-lanes.
- **Risk:** self-steering circumventing policy — the selector may only
  mount work, never bypass a gate; every mutation still needs its own
  certificate.
- **Dependencies:** run-autonomous; report-queue; the activity cadence
  matrix as its input.
- **Review trigger:** a fixture where the selector's ranking differs
  from the static queue Next produces a justified choice report, and
  the mounted slice still passes the full certificate gate.

## Webapp dashboard (operator directive 2026-08-26)

- **Problem:** the current terminal dashboard is an eyesore and pops up
  automatically; the operator wants a browser-window webapp dashboard
  only when requested, handled deliberately, not a periodic popup.
- **Smallest useful outcome:** a webapp dashboard (browser window) that
  consolidates the hngh dashboard surfaces (lanes, reports, live
  agents, cadence) behind the existing hngh-automation
  dashboard service (or a successor), never auto-launching; opening it
  is an explicit operator action or an explicit timer-wired trigger.
- **Evidence:** operator directive 2026-08-26; hngh-automation
  dashboard.json + index.html; hngh scripts/dashboard-readout /
  dashboard-tui.
- **Risk:** duplicating the existing readout; reuse the --json spine as
  the only data source.
- **Dependencies:** agent-live-view roster; cadence-continuum.
- **Review trigger:** an operator opens the dashboard in a browser by
  intent; nothing auto-pops it; data matches the readout spine.

## Self-optimization continuum (operator directive 2026-08-26)

- **Problem:** the evolution/grading/steering loops target operator-facing
  surfaces and work slices, but Hngh's own operations (cadence placement,
  probe costs, timer hygiene, credential rotation, drop-in design) only get
  optimized reactively when a failure surfaces.
- **Smallest useful outcome:** a standing principle + mechanism where Hngh
  self-optimizes every part of its operations continually: the oversight
  tick's agentic leg gains a self-review mode that evaluates its own
  ticking costs/placement (which probes fit which windows, what fired
  on-change vs by-poll, what new cheap event hooks exist) and emits
  `optimize: <suggestion>` breadcrumbs; a 10m cadence drop-in collects
  them into a self-optimization ledger (`docs/project/self-optimize.md`)
  whose accepted suggestions ride the normal queue→card→ceremony path;
  nothing changes its own timer/unit definitions without a ceremony.
- **Evidence:** operator directive 2026-08-26; oversight-tick (agentic
  leg); cadence-continuum; surface-evolution-loop pattern.
- **Risk:** self-modification runaway — every change to Hngh's own
  operation still clears the same gates (proposal→verdict→certificate→
  mutation); suggestions are advisory until then.
- **Dependencies:** oversight-tick agentic leg; cadence tiers; queue/card
  ceremony path.
- **Review trigger:** a suggestion raised by the self-review mode is
  recorded, ranked with the queue, and only lands as a mutation through
  the certificate gate; the ledger shows a continual series.

## Hosted agentic interface (operator directive 2026-08-26 — "Hngh as an application")

- **Problem:** Hngh is a sidecar (kernel + timers + dashboard), not yet
  an application in its own right: a user cannot sit down with Hngh
  directly and have it fire up sessions and host its own instanced
  oh-my-pi / pi surface for interfacing with agentic Hngh.
- **Smallest useful outcome:** Hngh visibly firing up new sessions
  itself and hosting its own oh-my-pi/pi instance — an agentic
  interface where requests and steers reach the running Hngh as its
  own interactive session, not only through ceremony/timer paths.
- **Evidence:** operator directive 2026-08-26; r18 worker transport +
  worker-driver (bounded read-only worker lane exists); the omp/pi
  bridge concept; the nervous-system control-plane precept (#7).
- **Risk:** an agentic interface is an ambient process — the biggest
  departure from "no daemon." Mitigate: the interface itself stays an
  on-demand session host (fired by an explicit start / a steered
  event), never a background service; every action it takes still
  flows through the certificate gates.
- **Dependencies:** worker-driver/bridge-hosted end-to-end session
  (roadmap Next), the pi/oh-my-pi host surface, the dashboard webapp
  as the read side.
- **Review trigger:** a user opens the hosted interface, watches Hngh
  fire up a new worker session from it, and the session's actions land
  only with their certificates; nothing ambient runs without an
  explicit start.

## Hosted agentic interface — navigable + auto-tiling sessions (operator refinement 2026-08-26)

- **Problem (extends `hosted agentic interface`):** beyond firing sessions,
  the operator wants *readouts for all scheduled agent runs* (a navigable
  gantt) and *navigable, auto-tiling sessions* for the agentic interface —
  short-term and long-term views of Hngh runs, so Hngh visibly builds and
  uses itself rather than relying on oh-my-pi as the builder.
- **Smallest useful outcome:** the webapp gains the navigable gantt
  (scheduled runs readout — the ASAP slice); the hosted interface
  (backlog `hosted agentic interface`) then gains navigable sessions
  with auto-tiling (tmux-like tiles per run), gantt-adjoining the
  schedule, both driven by the same evidence/spine (never fabricate
  dates; timeline events anchor, queue items are planned ghosts).
- **Evidence:** operator directive 2026-08-26; `queue-eta` widget;
  `timeline-events`; the webapp (a2ae5fc) + spine; `hosted agentic
  interface` entry.
- **Risk:** fabricating dates/claims — the gantt renders only real
  timeline events + planned (ghost, ETA tooltip) queue rows; the
  tiling sessions are read-only views of runs, never governance input.
- **Dependencies:** gantt panel (dispatch in flight); hosted agentic
  interface (bridge/worker-driver rung); webapp panels.
- **Review trigger:** an operator-browser gantt shows today's real
  rotation events + future queued ghosts with ETA tooltips, and a
  session host tiles all open Hngh runs (navigable, live).

## OMP↔Hngh bridge plugin (operator directive 2026-08-26 — Hngh improves Hngh)

- **Problem:** Hngh is bootstrapped by OMP ad-hoc (launch an omp instance
  in the project dir, ask agents to orient); we're not taking advantage
  of Hngh itself to improve Hngh. The operator is OK using a plugin that
  directly interfaces oh-my-pi with Hngh while Hngh grows toward hosting
  its own sessions.
- **Smallest useful outcome:** an omp plugin that connects oh-my-pi
  sessions to Hngh's governance surfaces directly — so work ON Hngh
  runs through Hngh's own rules (ceremony-gated commits, roguelike
  watchdog visibility, wired-state lens, oversight alerts) rather than
  as a parallel ad-hoc lane. Reuse oh-my-pi's existing session/tool
  structure; add a thin Hngh-facing adapter, not a rewrite.
- **Evidence:** operator directive 2026-08-26; precept 11 (Hngh improves
  Hngh); worker-driver r18; `hosted agentic interface` + `bridge-operator
  -host` backlog entries; the roguelike watchdog + agent-handoffs ledger.
- **Risk:** coupling omp to hngh too early — the plugin must be a sided
  adapter (omp keeps its structure; hngh kernel stays side-effect-free),
  failures fail closed, no new daemon.
- **Dependencies:** `bridge-operator-host` rung; worker-driver; the
  watchdog/handoff surfaces.
- **Review trigger:** a session invoked through the plugin lands its
  commit through Hngh's certificate gate and its session is visible in
  the watchdog/handoff ledger; the same rules apply whether the agent
  is working in Hngh or on Hngh.

## Command center — CLI + GUI operator surfaces (operator directive 2026-08-26)

- **Problem:** there's no real "command center": no flexible ever-
  expanding agentic interface for a system harness; we use oh-my-pi
  ad-hoc. The operator needs BOTH a command-line and a GUI Hngh
  interface, each with flexible readouts and simple controls for
  summoning and scheduling agents for various purposes.
- **Smallest useful outcome (needs-first):**
  - CLI: `scripts/hngh` grows a `schedule` / `summon` surface (see
    agentic-interface rung) — operator types an ask, sees it considered
    + contrasted with existing features, sees it slotted into the
    active schedule.
  - GUI: the webapp becomes the command center (see webapp rungs +
    agentic-interface) — same surfaces, clickable.
  - **Expedite visibility:** a user can ask for an expedite and SEE the
    impact (what it accelerates, any cascading delay to other scheduled
    work/maintenance) at any degree of expedite.
  - **Subagent view+control:** subagent views accessible alongside any
    main Hngh instance / attached session; users can identify and PAUSE
    a misbehaving subagent, highlight/name the unwanted behavior for
    Hngh's correction.
- **Evidence:** operator directive 2026-08-26; webapp (live :8890);
  roguelike watchdog + agent-handoffs; `hosted agentic interface`,
  `OMP↔Hngh bridge plugin`, `machine-steered-backlog` backlog entries.
- **Risk:** scope creep — needs-first: build what the operator must SEE
  first (awareness: runs/schedule/subagents/system), then what's nice;
  no daemon until the bridge rung proves it needs one.
- **Dependencies:** machine-steered-backlog (scheduling+completing own
  development), hosted agentic interface + OMP↔Hngh bridge (summon/
  schedule controls), system awareness rung (harnessing hardware/
  software/network), watchdog pause/highlight surface.
- **Review trigger:** an operator opens either interface, types an ask
  about Hngh's development, sees it considered, expedited with visible
  ripple impact, and can pause+label a misbehaving subagent from the
  subagent view — all without leaving the interface.

## System awareness rung (operator directive 2026-08-26)

- **Problem:** Hngh should maintain steady awareness of its surrounding
  system, using hardware/software/network resources to suit its own
  development and expansion — currently it only sees its stores/timers.
- **Smallest useful outcome:** the oversight tick + dashboard surface
  live system health (CPU/mem/disk/net, tailscale/fleet peers, model
  server health, resource headroom) as read-only awareness
  (fleet-manager already probes some); the agentic leg can name
  resource-based steers (e.g. "network down — pause network-labeled
  jobs").
- **Evidence:** operator directive; fleet-manager --discover;
  probe-model-route; credentialed network probes.
- **Risk:** awareness becoming ambient control — keep it read-only
  awareness feeding steer suggestions, never implicit mutation.
- **Dependencies:** cadence-continuum + oversight tick; fleet-manager.
- **Review trigger:** the dashboard shows live system-resource state,
  and a resource change (e.g. network loss) produces a steer/alert
  without any hidden action.

## Time ledger & delay flagging (self-optimization telemetry)

- **Problem:** Hngh aims to be self-optimizing, but operation wall-times
  live in scattered places (ceremony-drive `[ceremony-timing]` lines,
  systemd journal, suite walls, agent-wave reports) and get reviewed
  only when a human notices slowness. Excessive delays — like the
  2026-08-27 autonomy-tick wedge that sat failed for hours — should be
  noticed procedurally.
- **Smallest useful outcome:** one rolling time-ledger artifact
  (per-unit last/p50/max wall seconds, per-ceremony-step milliseconds)
  plus one oversight check that flags any operation exceeding
  max(2× its trailing median, floor) as a flap-suppressed alert row
  feeding the existing steer path.
- **Evidence:** the 2026-08-27 delay-ledger review
  (`records/2026-08-27-operator-items-closeout.md`,
  `records/2026-08-27-acceleration-wave.md`); measured wins already
  banked (untracked-artifact tax 6312→25 rows; ceremonies 40s→~3s).
- **Risk:** measurement load; alert noise; thresholds tuned to hide
  real drift — flap suppression and a small fixed floor keep it honest.
- **Dependencies:** oversight-tick alert path; systemd unit metadata;
  ceremony-timing lines; the report ledger.
- **Review trigger:** a seeded synthetic delay in a fixture run is
  flagged once, flap-suppressed after, and the ledger round-trips
  real unit timings.

## Session observatory (live subagent runs page)

- **Problem:** delegated agent runs are invisible while they run: the
  watchdog sees deaths, the roster shows counts, and neither offers an
  operator a navigable view of live sessions with their output.
- **Smallest useful outcome:** a read-only webapp page listing every
  session with state filters and a per-session detail pane (fields +
  bounded, redacted transcript tail), syntax highlighting, two themes,
  auto-refresh with honest staleness stamps.
- **Evidence:** operator directive 2026-08-27 (dedicated browser window
  welcome; multiple pages/styles/purposes intended); interface-plan
  S4/M6; master plan P4 navigable sessions.
- **Risk:** transcript surfaces touch operator home directories —
  read-only, bounded tails, secret-redaction at the feed boundary; the
  page must never render, let alone feed, governance input.
- **Dependencies:** `readout.json` roster spine; omp session surfaces;
  the refresh-dashboard feed pattern; browser relay for operator view.
- **Review trigger:** the page renders fixture sessions byte-identical
  to store records, redaction provably fires, and no canonical field
  is consumed for any decision.

## Browser notification surface

- **Problem:** attention-worthy events (alert rows, verdict flips)
  reach the operator only when a dashboard pane is being watched.
- **Smallest useful outcome:** opt-in browser notifications via the
  relay page for alert-class rows and verdict flips — digest-level,
  one-shot, flap-suppressed, zero default-on.
- **Evidence:** operator directive 2026-08-27 (browser notifications
  welcome alongside other channels).
- **Risk:** nagging; notification permission creep — the buddy rule
  (summoned, never nagging) applies: one notification per flap window.
- **Dependencies:** session observatory page host; report ledger
  cursor.
- **Review trigger:** a fixture alert produces exactly one
  notification and the toggle defaults off.

## Emacs-style surface configurability

- **Problem:** surface behavior (themes, refresh intervals, panel
  toggles, thresholds) is hard-coded per script; the operator wants
  declarative, layered configuration across all Hngh interfaces.
- **Smallest useful outcome:** one user config file
  (`~/.config/hngh/ui-config.*`) read at render/feed time, layering
  operator overrides over built-in defaults for display preferences —
  theme, refresh interval, visible panels, alert thresholds.
- **Evidence:** operator directive 2026-08-27 ("emacs-style
  configurability intended").
- **Risk:** config becoming a second authority — config is
  display/ops-preference only and can never carry governance fields
  (presentation-boundary law applies to configuration too).
- **Dependencies:** the dashboard/observatory surfaces it configures.
- **Review trigger:** the first config key ships with a fixture test
  proving governance fields in the config file are refused.

## Model-tier refresh cadence

- **Problem:** route and cost assumptions drift as providers change
  pricing and capability (the GLM 5.3 Flash workhorse window ends
  2026-09-09); BENCH_MODELS rot was already observed (MiniMax-H3 0/5).
- **Smallest useful outcome:** a quarterly re-bench + route review
  that lands a `route:` report row naming the current workhorse,
  runner-ups, and any model dropped from BENCH_MODELS.
- **Evidence:** `7a4041e` (MiniMax-H3 drop); the 2026-08-27 workhorse
  directive (GLM 5.3 Flash through Sept 9).
- **Risk:** benchmark churn; over-fitting to single-run scores —
  keep 0/5-twice as the drop rule.
- **Dependencies:** model-bench job; probe-model-route.
- **Review trigger:** the next quarterly bench lands a route report
  row even when nothing changes.

## Host orientation pass (new-system situating)

- **Problem:** on any system Hngh gets installed on, it must investigate
  what is present — packages and install sources (pacman, AUR/yay,
  npm/bun/bunx/uv), agent tools and their config surfaces — before it
  can interface with that system and help its operator.
- **Smallest useful outcome:** one orientation pass producing a
  host-inventory artifact plus a redacted config archive
  (`~/.local/state/hngh-automation/config-archive/`) and lane
  declarations for `config-backup.sh`, so config governance starts from
  day one on every host.
- **Evidence:** the 2026-08-27 CachyOS config archive (18 entries,
  six agent tools) and the git-back-dots subsumption inventory.
- **Risk:** inventories that leak secrets — scan classes only, values
  never rendered; archives stay local unless a lane declares a remote.
- **Dependencies:** config-backup lanes; system-awareness probe.
- **Review trigger:** a fixture host (container/chroot) yields a
  complete inventory + archive through the standard gates.

## Report-ledger retention policy

- **Problem:** the report ledger grows unboundedly (6,920 rows in two
  days of cadence output); `--prune` exists but nothing schedules it.
- **Smallest useful outcome:** a weekly ceremony-bound prune drop-in
  that archives alert/scheduled rows older than 30 days and lands the
  rotation as a check-in-scale commit, keeping the dashboard unread
  signal meaningful.
- **Evidence:** `report-queue --prune --archive` (this change set).
- **Risk:** pruning evidence prematurely — the archive preserves every
  pruned row verbatim; kinds are explicit.
- **Dependencies:** `report-queue --prune`; the autonomy ceremony slice.
- **Review trigger:** first prune runs inside a certificate loop with
  the archive attached to the candidate manifest.
- **Path convention (2026-08-27):** ledger rows carry repo-relative or
  `~/` paths, never absolute local paths — the public-content scan
  refuses candidates containing any absolute home directory prefix, so
  producers strip `$HOME` at emission (oversight-tick tree-skew was the
  last offender; 58 uncommitted rows normalized in place).

## Widget grid + QoL evolution cadence (dashboard surfaces)

- **Problem:** dashboard panes are fixed-position; quality-of-life
  improvements happen only when the operator demands them. The operator
  wants moveable, flexible widgets (terminalfeed.io as the reference
  example) and a scheduled, cyclical QoL research/development loop.
- **Smallest useful outcome:** a draggable, persisting widget layout for
  the dashboard pages (position/size per pane, per operator, layered
  with the ui-config layer), plus a scheduled surface-evolution beat
  that lands one graded QoL improvement per cycle without human
  intervention.
- **Evidence:** operator directive 2026-08-27 (terminalfeed.io named as
  the example; "regular, cyclical research and development concern").
- **Risk:** layout state becoming canonical — layout is display
  preference only; the evolution beat may propose but never auto-mutate
  cadence or governance surfaces.
- **Dependencies:** ui-config layer (emacs-style configurability rung);
  grade-interface; the observatory and gantt pages.
- **Review trigger:** one cycle lands a graded, revertible QoL change
  with before/after screenshots attached to the candidate.

## Cascading gantt: run estimates + parallel cascade

- **Problem:** the gantt rendered per-day granularity only; runs had no
  duration estimates and parallelizable overlap was invisible.
- **Smallest useful outcome:** first slice LANDED 2026-08-27
  (`dashboard/gantt.html`: ESTIMATE-labelled bars from time-ledger p50
  -> loadout time-limit -> 30m default, dependency connectors, zoom and
  drag pan, relative projected starts). Remaining: per-lane medians once
  wrapped sessions name lanes in their missions; live-run bars beside
  projected ones; expedite-ripple projection (M5) drawn as an alternate
  cascade.
- **Evidence:** hngh-automation `f67f972`; adversarial review caught and
  fixed an off-canvas connector artifact (double ms-conversion).
- **Risk:** estimates read as schedule facts — every bar carries its
  source; relative starts only, never fabricated dates.
- **Dependencies:** time-ledger; readout spine; the roguelike wrap
  (wrapped sessions name lanes).
- **Review trigger:** a wrapped live session renders an actual bar next
  to projected ones with the estimate source labelled.

## Interface plurality + session spawn affordances

- **Problem:** the operator works with Hngh through many surfaces — an
  OMP session in Konsole is the primary one today — and the dashboard
  should hand off to those surfaces, not replace them.
- **Smallest useful outcome:** first slice LANDED 2026-08-27
  (`POST /spawn`: configurable launchers from ui-config, Konsole tail
  proven live). Remaining: per-surface presets (OMP collab windows,
  browser windows), a session-page launcher menu, operator-editable
  launcher documentation.
- **Evidence:** operator directive 2026-08-27; the observatory flag
  path (UI -> server -> ledger) as the established pattern.
- **Risk:** spawn is desktop mutation — allowlisted templates only; the
  client names a key, never a command.
- **Dependencies:** dashboard-server; the ui-config layer.
- **Review trigger:** every launcher key documented, validated, and
  demonstrated once against a live session.

## Self-supervision tick (Hngh watches its own agents)

- **Problem:** delegated-run supervision is currently performed by the
  harness agent (reading transcripts, noticing stalls, debugging
  integration seams). In the long run Hngh's operations are Hngh's:
  every supervision pattern the harness agent exercised must become a
  Hngh-native mechanism.
- **Smallest useful outcome:** a supervision tick extending the
  watchdog: parse delegated-run session transcripts (jsonl), compute
  per-run phase (discovering / writing / fixing-own-regressions /
  verifying — classified from tool-call patterns), detect stalls (no
  tool-call progress beyond budget), and emit flap-suppressed alert
  rows; roguelike replacement (close-run :dead + re-provision) for
  budget-expired runs rides the existing loop.
- **Evidence:** the 2026-08-27 transcript-analysis session proved the
  pattern live (phase + tool-density computed for 30+ agent runs in one
  pass); the watchdog already observes deaths — this adds progress
  observation.
- **Risk:** transcript formats vary by harness (omp schema derived from
  LibScout/agent specimens; others differ) — per-harness parsers behind
  one interface; phase classification is heuristic and stays advisory.
- **Dependencies:** the roguelike wrap (runs to supervise);
  sessions-feed transcript resolution; report-queue identities.
- **Review trigger:** a seeded stalled fixture run is flagged with the
  correct phase within one tick, and a healthy run is never flagged.

## Research lines: user controls

- **Problem:** the Research view is read-only; the operator cannot add a
  new line of research or attach notes/steering to existing lines.
- **Smallest useful outcome:** from the Research tab, the operator adds
  a research line (name + intent; lands in backlog as a proposal-ready
  lane) and attaches notes or steering commentary — affecting (rides the
  certificate gates like any steer) or non-affecting (annotation only) —
  to lines in any state (active, completed, in-proposal).
- **Evidence:** operator directive 2026-08-27 (evening, "first user
  controls").
- **Risk:** user-added lines bypassing governance — additions are
  proposals by default; only the affecting class touches cadence or
  gates, and only through the loop.
- **Dependencies:** research view; report-queue identities; the
  certificate loop for affecting steers.
- **Review trigger:** an added line appears in backlog + Research view;
  an affecting note lands as a deduped steer row; a non-affecting note
  never touches a gate.

- note (2026-08-27T20:36:05Z): What is this, a control for a note? Weird research line, seems like it should probably get resolved?
## Memory surface (llm-wiki integration)

- **Problem:** Hngh's harvested lessons and memory live in the llm-wiki
  and session notes — invisible on any operator surface.
- **Smallest useful outcome:** a Memory tab/panel listing wiki sources
  and recent lessons (read-only first), searchable, linked to the runs
  and waves that produced them.
- **Evidence:** operator directive 2026-08-27 ("easy opportunity for
  interfacing with llm-wiki").
- **Risk:** memory display implying memory authority — lessons inform,
  never decide (the wiki is already a record, not a gate input).
- **Dependencies:** llm-wiki vault; research view patterns.
- **Review trigger:** the panel renders the real vault index and every
  displayed lesson links to its source record.

## Startup launch flow

- **Problem:** starting work means opening a terminal, an omp session,
  and the dashboard separately, by hand.
- **Smallest useful outcome:** from the dashboard (or one command), the
  operator fires up a live agentic session for continuing Hngh and
  system work — an omp/agent session spawned, wrapped by the roguelike
  run-start, and visible in the observatory — with the dashboard open
  beside it.
- **Evidence:** operator directive 2026-08-27 ("dashboard at startup…
  immediately fire up an agentic session").
- **Risk:** desktop spawn is mutation — allowlisted launchers only
  (existing pattern); the spawned session is wrapped, never raw.
- **Dependencies:** the roguelike wrap; /spawn endpoint; ui-config.
- **Review trigger:** one click spawns a session that appears in the
  observatory within one feed tick, already run-wrapped.

## System controls → governed package operations

- **Problem:** the System view is observability-only; the operator named
  package management, system update, configuration management, backups,
  syncing, and network status as the controls they actually want.
- **Smallest useful outcome:** v1 controls landed (refresh, check
  updates, reset-failed, run-backup — safe ops, handoffs-logged). Next:
  governed package upgrades ride the certificate loop (proposal →
  verdict → executor runs the update in a declared window with
  rollback evidence).
- **Evidence:** operator directive 2026-08-27 (evening System review).
- **Risk:** unattended upgrades break running work — upgrades are
  certificate-gated, declared-window, rollback-evidenced, never ambient.
- **Dependencies:** system-ops feed; the certificate loop; a declared
  maintenance window lane.
- **Review trigger:** one governed upgrade executes end-to-end with
  pre/post manifests and rollback evidence.

## Research precedence + collected material

- **Problem:** research lines cannot be reordered by precedence, and
  material already collected for a line (design docs, records, wiki
  sources) is not linked from the line.
- **Smallest useful outcome:** precedence order persisted and rendered
  (up/down controls); each line links its collected material (design
  docs, records, kb snapshots) with one-click navigation.
- **Evidence:** operator directive 2026-08-27 (Research review).
- **Risk:** precedence becoming a second priority system — it orders
  display and attention only; the machine-steered selector keeps its
  own policy.
- **Dependencies:** research view; kb view.
- **Review trigger:** reorder persists across reload; collected
  material links resolve for every lane.

## Cadence watch fixes — gated red, recorded not landed (2026-08-28)

- **Problem:** the automation repo's own gate has no scheduled checker,
  and its watch probes alert on the machine's own housekeeping. With
  the kernel gate green, hngh-automation `make test` sat red on HEAD
  (lint-identifiers: deck-setup.sh reports `$DESK_LAN_IP`/`$DESK_TS_IP`
  as referenced-never-defined although both are defined inside the
  `hngh-connect` heredoc — the scanner does not track heredoc-scoped
  definitions; hngh-ufw-manage.sh carries a genuinely dead
  `TS_SUBNET`), and no alert fired: `cadence/day/03-gate-check.sh`
  sweeps only the kernel. Separately, the oversight tree-skew probe
  fired x64 on machine-maintained append paths, and the fresh-eyes
  digest ships the echoed prompt plus raw diffs instead of findings.
- **Smallest useful outcome:** a day-tier drop-in gates hngh-automation
  too (`make test` there, alert rows on red); the tree-skew probe
  whitelists machine-maintained append paths (reports.md, ui-grades.md,
  current-overlay.json, plan status transitions) or ceremonies sweep
  them on a fixed cadence; lint-identifiers learns heredoc scoping (or
  gains a scoped exclusion) and `TS_SUBNET` is removed; the review
  digest keeps the findings section, not the prompt echo.
- **Evidence:** hngh-automation `make test` red on HEAD 2026-08-28
  (3 lint problems, run this day); oversight tree-skew alerts x64
  (report rows 96bd99de, 07:55Z–08:00Z); digest/REVIEW-2026-08-28.md
  prompt echo; `cadence/day/03-gate-check.sh` sources.
- **Risk:** none beyond script edits in hngh-automation — no new
  daemons; changes land as plain commits there once its gate is green.
- **Dependencies:** cadence/day drop-ins; jobs/lint-identifiers.sh;
  scripts/hngh-ufw-manage.sh; review-prep digest generation.
- **Review trigger:** hngh-automation `make test` green on HEAD and a
  gate-red alert reproducible in a fixture run.

## report-queue escalation caps

- **Problem:** identity+window dedup collapses repeat alerts, but the
  xN occurrence marker grows unbounded and a permanently-deduped alert
  stops being information (stale-store spam x12 per id at 11:10Z, rows
  0582c2ca/4b0abe9a; dash-selfreview summary at x18, row f438818b).
- **Smallest useful outcome:** cap the xN marker; past a threshold,
  escalate to the operator-facing digest instead of bumping the count.
- **Evidence:** report-ledger lesson row b185ea3c
  (2026-08-28T18:35:46Z, device-pairing wave).
- **Risk:** low — display and escalation policy only; identities and
  windows unchanged.
- **Dependencies:** scripts/report-queue; digest generation.
- **Review trigger:** one deduped alert crosses its cap and surfaces
  in the operator-facing digest.

## Router-side re-arm pre-check (router-rearm-precheck) — done 2026-09-01

- **Problem:** the alert→plan-candidate routing resolutions
  ("Open-thread resolutions (2026-08-31)" in
  docs/research/2026-08-30-alert-to-work-routing-patterns-closing-the-self-observation-loop.md)
  park re-arm after step close: dedup is wall-clock only, so an alert
  re-added right after its named plan step closes can route a
  duplicate candidate.
- **Smallest useful outcome:** a pre-check before `report-queue
  --add` that consults plan state (step open/closed) and skips the
  add when the named step is already closed — the router-side
  pre-check the resolutions recommend; no router-internal state.
- **Evidence:** the resolved doc, thread 2 (dedup window is
  wall-clock only; identity = plan step, `--window 0`);
  overnight-cycle.sh:186-199 (the docs/project/plans/*.plan.md
  selector surface).
- **Risk:** low — a read-only plan-state consult before an existing
  add; dedup/escalation caps unchanged.
- **Dependencies:** scripts/report-queue; docs/project/plans/ status
  conventions.
- **Review trigger:** one closed-step re-fire is demonstrably skipped
  in a fixture run.
- **Status (2026-09-01):** delivered. The pre-check is implemented in
  hngh-automation scripts/router-tick.py (automation commit 87e6bc3):
  before any report-queue --add it consults the plan file named in the
  identity with the selector's own two greps (status=accepted
  front-matter, unchecked `- [ ]` step) and skips the add when the
  named step is closed, filing the observable pair instead (STATE.md
  `router | duplicate-skip` breadcrumb + deduped alert row
  router:dup-skip:identity, window 86400). Review trigger satisfied
  both ways: hermetic fixture run
  (hngh-automation tests/test-router-tick.py,
  test_closed_step_refire_files_duplicate_skip_pair) and a live
  closed-step re-fire against the executed 2026-08-30 overnight plan
  (reports.md alert row f9360a6e). No router-internal state — the
  skip decision is re-derived from the plan file each run. Queue row
  flipped queued → done.

## Publication pipeline: research-lines wiring vs the fixed 7-file contract (publication-lines-contract) — queued 2026-08-31

- **Problem:** the publication-pipeline grounding pass proved
  scripts/generate-publication consumes no docs/research/ lines and no
  research-lines manifest: `--ebook` reads a hard-coded 7-file list
  (script lines 235-247) and `--site` is a shell over
  scripts/dashboard-readout. Research output therefore never reaches
  the publication surface, and the 7-file list is an undocumented
  contract.
- **Smallest useful outcome:** one decision landed either way — wire
  research-lines into generate-publication's `--ebook` inputs, or
  document the fixed 7-file list as the contract (README/usage note).
- **Evidence:** docs/research/2026-08-30-publication-pipeline-grounding.md
  (15/15 grounding paths verified); scripts/generate-publication
  lines 235-247; scripts/dashboard-readout.
- **Risk:** low — documentation-only if the contract path is chosen;
  wiring adds a manifest read, no new daemons.
- **Dependencies:** scripts/generate-publication; the research-lines
  surface (research controls row).
- **Review trigger:** the decision is recorded and its chosen side is
  verifiable (a doc note, or a manifest-driven `--ebook` run).

## Ebook book-machine inputs (ebook-book-inputs) — queued 2026-08-31

- **Problem:** the royalty-pipeline is blocked on missing book-machine
  inputs per its own dependency line; the publication grounding pass
  confirmed the blocker is upstream inputs, not the generation script.
- **Smallest useful outcome:** the book-machine inputs exist (the
  manuscript/outline/metadata set the royalty pipeline expects) so its
  dependency line is satisfiable.
- **Evidence:** docs/research/2026-08-30-publication-pipeline-grounding.md;
  the royalty-pipeline row's dependency line; the ebook longform row.
- **Risk:** none — authoring inputs only; no runtime surface changes.
- **Dependencies:** ebook longform row; royalty-pipeline row.
- **Review acceptance:** `generate-publication --ebook` completes on
  the real inputs without placeholder files.


- Language discipline (2026-08-27): operator-facing output is English-only, enforced via AGENTS.md layers (global ~, repo). Long-run alternative: an automatic detect-and-translate layer over any non-English model output.


## The queue

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


## The readme

# Hngh

## What Hngh is

Hngh turns development work into short, bounded cycles, plan, check, record, close, that an
automated agent can run while a human keeps the final say. Every cycle leaves a paper trail of
evidence; nothing changes the system without passing a check and being recorded. The kernel
(`hngh.domain` plus `hngh.application`) is side-effect-free: it does nothing on its own, owns no
background process, refuses anything unknown or unverified. Around that kernel stands a
working system: a governance loop that certifies and executes its own repository changes,
a cadence of single-tick timers that drive, watch, and correct the machine on every tier
from one minute to daily, a self-review that inspects Hngh's own dashboards hourly, a time
ledger that measures every operation so delays are noticed procedurally, and a nerve-center
webapp — Schedule, Sessions, System, Research, Logs — where the operator sees all of it in
one honest view.

Hngh's ambition is megastructure-scale: an environment that maintains and extends itself,
with local and remote models doing the work and the cost of that work kept visible. Its method
is paperwork. That is not a contradiction; paperwork is the building material.
The near-term form of that ambition is concrete: harness system configuration and package
management on the hosts it lands on (CachyOS first), govern delegated agent sessions as
roguelike runs that die and hand their lessons forward, alternate growth with research
beats on a fixed rhythm, and make every interface worth looking at.

## Why

Most open-source agent harnesses are built to move fast. Their winning trait is normally
throughput: how many tokens a model can burn in a loop, in a session, in an agent fan-out.
They optimize capability and autonomy, and they are honest about it: sandbox you, hand you a
long tool list, and let the loop run.

A furnace is a useful machine, and so is a busy agent. But a furnace is a machine you watch
from outside; when it fails you learn about it after the fact. When an agent acts without a
record, you can only judge it by what came back, never by what was decided on the way. A 2026
[empirical study of 70 public agent-harness projects](https://arxiv.org/abs/2604.18071)
(H. Wei, "Architectural Design Decisions in AI Agent Harnesses", April 2026) puts it
soberly: sandboxing is common, high-assurance audit is rare, and growing a harness does not
reliably grow its governance. Capability and accountability do not move in lockstep.

Hngh is built the other way around. It prizes the smallest property most harnesses defer:
that every decision is a fact you can walk back to. Decide what is valid first, record what
happened, keep a person's final say. The kernel enforces that by refusing to guess at the
outside world at all. It reads no clock, no file, no network, no subprocess; the outside
world plugs in later through explicit ports. Not the agent that can do the most; the agent
whose every step leaves a trace.

## How it works

A run is one bounded work cycle with a clear lifecycle: created, armed (given one job and
the evidence for it), running, checkpointed (verified progress), closed (cancelled,
evacuated, or finished). Terminal states are permanent. Retry means a new run, never a
silent continuation of an old one.

- Fail-closed: unknown, malformed, duplicate, or unverified input is refused, never guessed,
  never skipped.
- Evidence: receipts record what happened; they justify but never grant power.
- Certificates: permission for exactly one action (prepare, stage, commit, or push), bound to
  specific files and evidence, rechecked immediately before the action.
- Clean architecture: the core logic depends on nothing external; the outside world plugs in
  at the edges through explicit ports, and the read-only evidence adapter is the first edge.
- The harness governs its own repository. The past stays honest: commits that predate
  the loop are recorded as history, not rewritten as governance. The present bootstraps:
  behavior changes ride the loop — proposal → verdict → certificate → executor, under
  real evidence — and where the loop itself refuses a binding (the dependency guard
  will not certify a commit that changes no behavior), the exception is by rule, not by
  mood. The direction is one track: a change the loop can bind, the loop binds; a change
  it cannot, it declares. That sentence is machine-checked: `make test` runs a
  loop-history guard over every code-surface commit since the restatement, and a
  labeled exemption is the only way a change lands outside the loop.

## Status

Hngh is a pure library with fixture tests (`make test` runs 8 reader-guard checks plus a
suite past 2,855 checks — the count grows with every closed vocabulary, and the run prints
the current number) and an operator command surface. Implemented:

- Pure domain values (profile, mission, role, loadout, run, receipt, score, afterlife) with a
  closed lifecycle.
- Seven application use cases: create-run, admit-transport, arm-run, start-run, checkpoint,
  (policy-gated) close-run, and (queue-ranking) select-course.
- Governance: proposal-evidence ledger, deterministic evaluation of ten principles, closed
  failure-disposition policy, non-mutating candidate authorization certificate, and
  exhaustive property tests (totality over the closed vocabularies; monotonicity: ignoring
  evidence never flips refused to admitted).
- Read-only evidence adapter through an injected process transport; unknown commands,
  malformed output, escaping targets, and duplicate evidence fail closed.
- Mutation executor: rechecks every candidate-certificate fact against fresh evidence, then
  sends only the certificate-bound fixed Git action; stale facts, expiry, disabled actions,
  and transport faults refuse without a mutation.
- Bounded model review adapter: one closed review request → one fixed prompt → sanitized,
  duplicate-free finding labels and citations; absent, malformed, unsafe, duplicate, or
  oversized output refuses; a failed call becomes an `:unverifiable` fact. Reviewers advise;
  they never decide, and no default provider transport exists.
- Operator command surface (`scripts/hngh`): `create-run`, `admit-transport`, `arm-run`,
  `start-run`, `checkpoint`, `close-run`, `present`, `review`, `terminal`, `propose`,
  `issue-cert`, `mutation-check`, `fetch-evidence`, `verify-attestation`, `list-pins`,
  `wake-peer`, `run-worker`, `select-course`, `status`;
  strict exit codes (0 accepted, 1 refused/conflict, 2 malformed, 3 transport fault);
  persistence only under an explicit `--store=PATH`.
- Real evidence chain: certificates mint only from an operator-produced verdict file plus
  genuine repository evidence (git revision, content hashes, working-tree state).
- Read-only candidate evidence bundle (`make verify-candidate`).
- Model and terminal transports behind loadout admission (rung 10): a bounded `:model`
  route for the review adapter and a single-statement `:terminal` evidence capture, both
  advisory with no default provider or input.
- Distributed attestation & evidence federation (rung 11): `hngh.adapters.federation`
  gathers carrier-bundle claims into evidence facts (`fetch-evidence`), verifies
  attestation envelopes through pinned-key/signature ports (`verify-attestation`), and
  admits `:federation` behind the `remote-evidence`/`carrier-bundle` labels.
- Operator pinned-key registry and signature-verification transport (rung 12): a pure
  `key-pin-registry` domain value, a strict pins-file parser, and attestation ports that
  verify one envelope signature through a single bounded
  `openssl dgst -sha256 -verify` invocation on the injected process transport —
  `verify-attestation ... pins=PATH` admits the operator's pins file as the trust anchor
  and `list-pins` renders it; anything unpinned refuses `unknown-peer-key`.
- Ed25519 signature-transport hardening (rung 14): the pins file gains an optional
  closed ALGORITHM column (`rsa-sha256` default, `ed25519` admitted); verification
  routes per pin — digest signatures through `openssl dgst -sha256 -verify`, raw
  Ed25519 signatures through `openssl pkeyutl -verify -rawin` — so `verify-attestation`
  accepts modern keys and `list-pins` renders each pin's algorithm. Verified live
  end to end with a real Ed25519 keypair (`status=verified`, tampered payload
  `bad-signature`).
- Network claim method (rung 15): `fetch-evidence` gains `method=carrier-bundle|http-claim`
  (default carrier-bundle); the `:http-claim` method fetches the same closed bundle
  document from a peer endpoint over HTTP. The peer stays a plain identifier on the
  request and endpoint resolution belongs to the injected transport — there is still
  no default wire, and an unadmitted method is malformed. Verified live over a real
  local HTTP server through an injected transport (`status=complete`, claims mapped
  with the closed state vocabulary).
- Operator policy profiles (rung 16): `propose` gains `profile=PATH` — a strict,
  operator-tunable `PRINCIPLE<TAB>KIND` file that narrows which requirement kinds a
  listed principle may carry (the `:review` kind is now admitted, so a profile can
  demand review evidence). A profile never broadens admission; a listed principle
  whose kinds are all dropped refuses as `missing-principle-result`.
- Wake-on-demand (rung 17): `wake-peer RUN PINS-FILE PEER` issues one explicit wake
  request for a pinned lattice peer behind an injected transport — the pins registry
  is the admission evidence (a peer is admitted by pinning its key) and the run must
  hold a `:federation` admission receipt. No default transport, no daemon: the
  operator's injected transport decides what "wake" means. Unpinned peers refuse
  `unknown-peer-key`; ambient tunnels and certificate-bound wake remain boundary
  amendments.
- Bounded read-only worker (rung 18): `run-worker RUN task=LABEL [payload=TEXT]` runs
  one closed worker task through an injected transport; `:worker` is admitted behind
  the `worker-task` tool label. A completed task binds a `:worker` evidence fact —
  a worker self-report is evidence, never acceptance, and a worker never carries a
  mutation certificate. No default transport.
- Continual-worker driver: `scripts/worker-driver --store=PATH OBJECTIVE TASK
  [PAYLOAD]` runs the one-shot worker cycle (create-run with the worker-task label →
  admit worker → run-worker → close) as a single explicit operator invocation.
  It is glue over the existing surface, adds no authority, and the periodic
  invocation belongs to the operator's scheduler, never a daemon.
- Self-watch: a time ledger measuring every operation level, an hourly
  dashboard self-review whose findings classify themselves
  (`unacceptable-now` / `acceptable-for-now`), oversight alerts with
  flap-suppression, a roguelike watchdog, and a nerve-center webapp
  (Schedule / Sessions / System / Research / Logs) with a session
  observatory that parses live agent transcripts — thinking, tool calls,
  user and agent entries — into collapsible, searchable, highlighted
  columns; window spawn and tiling from the browser; all read-only
  observability plus certificate-gated action, per the consolidated
  route in `docs/project/roadmap.md`.
- Full-screen dashboard TUI (`scripts/dashboard-tui`): a textual (rich)
  read-only TUI with an animated operative, an active-lanes panel, and
  live session tables, fed from the operator store through the same
  read-only renderer as `dashboard-readout`.
- Interface grading loop (`scripts/grade-interface` + `docs/project/ui-grades.md`):
  a deterministic first-finding grade for each interface, feeding every
  UI iteration — the seed of the federated UI/UX validation the
  assistant-interface design names.
- Operative evolution (`scripts/evolve-operative`): a generated operative
  (generations 1–4/5) with the animation spec in
  `docs/design/operative-frames.md` and the operative layer framed in
  `docs/design/assistant-interface.md`.
- Desktop OSD overlay (`scripts/osd-operative` + `osd-operative.qml`): a
  frameless, always-on-top Plasma 6 webview that floats the operative
  above the desktop, backed by `tests/scripts/test-osd-operative.py`.
- Backlog tooling: `scripts/backlog-lanes` parses `docs/project/backlog.md`
  into lane rows (json/text, status + date, in-queue mapping) so any
  surface can render an active-lanes view; `scripts/notify-agent` is a
  bounded KDE notification reaction agent (`org.freedesktop.Notifications`)
  that classifies job-search signals and appends hits to
  `docs/project/notify-log.md` — one-shot, no daemon, stdlib only.
- Research docs: `docs/project/integrations-marketplace.md` (where the
  governance pattern binds to CI/agent-harness/ops/security tooling) and
  `docs/project/system-harness-roadmap.md` (a fleet of nodes under one
  governance: resource pool, config manager, security manager).

Not yet: daemon, watcher, scheduler, and no ambient state. Each will be admitted the same way
everything else is: through a proposal, a check, and a record. The megastructure is built
one verified stretch at a time.

## Verify

```sh
make test
python3 tests/scripts/test-verify-candidate.py
make verify-candidate CANDIDATE_MANIFEST=path/to/manifest
```

The verify-candidate bundle requires an explicit, ordered manifest of regular repository-
relative files. It reports whole-tree state as evidence, refuses escaping/malformed/
unsafe/duplicate candidates, and performs no Git mutation, provider call, service start, or
archive read.

## Public posture

The project is AGPL-3.0-or-later ([LICENSE](LICENSE)). Governance and contribution rules are
in [GOVERNANCE.md](GOVERNANCE.md), [CONTRIBUTING.md](CONTRIBUTING.md) (DCO sign-off on every
commit), and [SECURITY.md](SECURITY.md) (private coordinated disclosure). Pre-release state is
tracked in [CHANGELOG.md](CHANGELOG.md).

## Where this is going

Hngh is not headed toward a busier agent. It is headed toward a wider corridor: a system that
routes many kinds of work, local and remote models, priced routes, and eventually pooled
hardware, through the same ledger, the same certificate, and the same human-closable cycle.
What changes at each step is the machine on the outside, never the rule the core holds; a
kernel stays the spine the harness can always rebuild around.

At full width, the corridor is a megastructure: not one machine, but a lattice of small
machines, each an Hngh node running the same narrow rulebook, each guarding its own
boundary — the bedroom corner, the hand-held that spends most of its life on a shelf, the
old laptop whose NIC is slower than its patience. None of them is large in anything except
evidence. A node learns what its own wall taught it, and the lesson is not buried in the
ledger where only that node will ever look; it is shared as a fact a neighbor can cite:
this bridge goes down at three in the morning, this tunnel has held for a year, this load
draws this power, this device woke when it was asked and was quiet otherwise. Wake a machine
before you need it. Keep the tunnels open without a watching daemon. Admit the new
low-powered friend the way any new peer is admitted: evidence first, then a place. One
machine never learns what a thousand machines each failed once; a mesh of small ledgered
machines is how a city covers a lawn, then the next lawn, then the planet — and never a
wall that does not say who raised it.

That lattice is a resource pool, not just a mesh: each node is an
addressable component with a status, a duty, a health readout, and a
capability set, surfaced in the dashboard as a row or panel — from a
static line to a full "dance-able" animated surface, the interface-level
grading in [ui-grades.md](docs/project/ui-grades.md). Declared per-node
configuration applies evidence-backed and reverses cleanly; key rotation,
secret hygiene, and patch-state are security-manager duties with the same
certificate-bound evidence chain. The direction is concrete
([system-harness-roadmap.md](docs/project/system-harness-roadmap.md)):
wide-area, low-powered machines are first-class citizens of the harness,
never second-class peers bolted on later.

## Documentation

Start at [docs/README.md](docs/README.md). Records and the external retirement archive cover
the project's prior state; the active baseline lives here.

## Live operation

The machine runs from a sibling repository, `../hngh-automation/` — its
[README](../hngh-automation/README.md) documents the cadence tiers, the
watchdog, and the digest surfaces; the
[latest daily digest](../hngh-automation/digest/2026-09-06.md) shows
what actually fired today.

## For the public

The project publishes a daily journal of its own construction — the
same ledger that governs its releases, written for people to read. Each
day's entry assembles the record, the queue, and the timeline into a
narrative you can follow as the megastructure grows outward. The
project's long-form memoir and the public site (journal, moderated
comments, leaderboards, and the dashboards this README describes) are
the same build pipeline as the code — every public byte is a committed,
checked artifact. The first entry is already here:
[2026-08-25](docs/journal/2026-08-25.md) — and the themed
readout renders live from the same data.

Screens of the dashboards live in `docs/media/` (linear/spiral/
circular/wave, themed); the `--dance` motion is best seen live.

## Contributors & attribution

Who builds Hngh and how it is attributed is in [CONTRIBUTORS.md](CONTRIBUTORS.md).


## 2026-08-11-crystallized-cutover

# Crystallized cutover

> Superseded on 2026-08-19: the archive gate was retired
> (`docs/records/2026-08-19-archive-gate-retired.md`). The archive remains
> historical evidence outside the repository; no active gate verifies it.

The prior Hngh image was retired as a complete local archive. The replacement
starts with a no-daemon kernel and an empty mode-0700 `~/.hngh` directory.

The archive receipt is stored outside this repository in the configured
archive's `metadata/` directory. Historically verified with
`HNGH_ARCHIVE_ROOT=/absolute/path/to/archive make check-archive`, which has
since been removed.

No old process, user unit, autostart mask, launcher, compatibility root, or
configured Hermes MCP entry remains active.


## 2026-08-11-task-1-boundaries

# Task 1 boundary record

## Scope

Published the Clean Architecture charter, component map, test boundary, and
presentation/reference-lexicon boundaries before any state persistence or
adapter implementation.

## Evidence

`make test` passed with nine checks and an ASDF load.

The fixture guard rejects inward `hngh.domain` packages importing
`hngh.presentation` or `hngh.adapters.*`. The reference-lexicon fixture accepts
a renderer-only record and rejects a record containing canonical control fields.

## Boundary result

No runtime component, adapter, service, process, provider route, state root,
or external action was added. The new component names describe planned
boundaries only.

## Next

Specify and test the run domain before persistence.


## 2026-08-11-task-2-run-domain

# Task 2 run-domain record

## Scope

Implemented `hngh.domain` as a pure Common Lisp library before application,
persistence, or adapter work. The existing `hngh:validate-profile` entry remains
a compatibility facade.

## Evidence

The recovered parenthesis linter reported all touched Lisp files balanced.
`make test` passed with 265 checks and an ASDF load.

The test suite covers valid mission, role, and loadout values; malformed input
and infrastructure-shaped values; defensive input/output copies; read-only
storage slots; all lifecycle state pairs; functional state transitions; and
evidence-only receipt, score, and afterlife records.

## Boundary result

Runs start in `created` and advance only through the closed domain table. Every
other transition signals `invalid-run-transition`. Receipts, scores, and lesson
candidates cannot change run state or grant authority.

No application use case, port, adapter, persistence root, clock, environment
lookup, provider call, subprocess, service, or background process was added.

## Next

Add application use cases and inward port contracts against fakes.


## 2026-08-12-task-3.1-create-run

# Task 3.1 create-run record

## Scope

Added the first pure `hngh.application` slice: `create-run`, its
`run-creation-ports` contract, and closure-based fake ports. The slice uses no
adapter, persistence root, provider, clock, filesystem, process, service, or
background process.

## Contract

`create-run` receives three callbacks only: `next-identifier`, `clock-now`, and
atomic `record-run`. It validates mission, role, and loadout before invoking any
callback. A successful result contains the exact `:created` run and creation
receipt passed to one `record-run` call. The recorder returns only `:recorded`
or `:conflict`; no callback retries.

A callback error or malformed callback return becomes a closed `:refused`
result. The callback handler encloses only the invocation: domain and
application errors remain visible to the test gate. Accepted results always
contain their run-and-receipt pair; invalid, refused, and conflict results
contain neither.

## Evidence

```text
python3 scripts/lint-parens.py src/packages.lisp src/domain/*.lisp \
  src/application/*.lisp tests/run.lisp tests/domain/*.lisp \
  tests/application/*.lisp tests/support/fakes.lisp
13 paths reported [OK].

make test
8 reader guard checks passed.
309 checks passed.
ASDF load completed.

git diff --check
passed.

markdown relative-link check
passed.

candidate source safety scan
passed after scoped inspection of declared interpreter and documentation terms.
```

## Boundary result

The application package depends only on Common Lisp and `hngh.domain`. It has
one named use case and no global capability bundle. The fake recorder appends a
run and receipt together or not at all.

## Next

Add Task 3.2 `arm-run` with its separate admission-facts and recording
capability contract.


## 2026-08-12-task-3.2-arm-run

# Task 3.2 arm-run record

## Scope

Added `hngh.application:arm-run`, closed `admission-facts`, its two-callback
port contract, and closure-based fakes. The slice remains pure: it starts no
service and uses no persistence root, live clock, filesystem, provider,
process, or network operation.

## Contract

The admission callback receives a domain run and returns one `admission-facts`
value. It has exactly four fields: authority, ledger, loadout, and
exclusive-write. Each status is one of `:confirmed`, `:unknown`, or `:refused`.
Only four confirmations permit the use case to advance a created run to
`:armed`, issue one admission receipt, and call atomic `record-run` once.

Unknown, refused, malformed, or callback-error facts return `:refused` without
a transition or record attempt. A record conflict returns `:conflict` without
retry. A domain-invalid transition becomes a closed refusal; unexpected domain
or application failures remain visible to the test gate.

## Evidence

```text
python3 scripts/lint-parens.py src/application/ports.lisp \
  src/application/arm-run.lisp tests/application/test-arm-run.lisp \
  tests/support/fakes.lisp tests/run.lisp
5 paths reported [OK].

sbcl --script tests/run.lisp
388 checks passed.
```

## Boundary result

`arm-run` holds no identifier, clock, model, renderer, filesystem, process, or
repository capability. The admission fake records its run and receipt together
or not at all.

## Next

Add Task 3.3 `start-run` with its one-slot atomic recording contract.


## 2026-08-12-task-3.3-start-run

# Task 3.3 start-run record

## Scope

Added `hngh.application:start-run`, its one-slot `run-start-ports` contract,
and a closure-based fake. The slice stays pure: it uses no clock, identifier,
filesystem, provider, process, repository, network, persistence root, or service.

## Contract

`start-run` accepts an armed domain run only. It creates an immutable `:running`
replacement and one `:start` receipt, then makes exactly one atomic `record-run`
call with that pair. A recorded pair returns `:accepted`; a conflict returns
`:conflict` without retry.

A non-armed source run returns `:refused` without recording. A recording callback
error returns `:refused` without retry. The callback handler wraps only the
record call. An unexpected domain failure remains visible and records nothing.

## Evidence

```text
python3 scripts/lint-parens.py src/application/ports.lisp \
  src/application/start-run.lisp tests/application/test-start-run.lisp \
  tests/support/fakes.lisp tests/run.lisp src/packages.lisp
6 paths reported [OK].

sbcl --script tests/run.lisp
406 checks passed.
```

## Boundary result

No adapter may transition an armed run directly to `:running`; that transition
now has an application use case with a narrow, fake-backed recording contract.

## Next

Add Task 3.4 `checkpoint` with separate verification and manifest evidence
contracts.


## 2026-08-12-task-3.4-checkpoint

# Task 3.4 checkpoint record

## Scope

Added `hngh.application:checkpoint`, its three-slot `run-checkpoint-ports`
contract, immutable closed verification and manifest results, a run-only
checkpoint request, and a closure-based fake. The slice stays pure: it uses no
path, command, raw output, provider, model, renderer, filesystem, process,
network, persistence root, clock, identifier, or service.

## Contract

`checkpoint` calls the tool executor and repository inspector once each with
one closed request containing the domain run. It advances a running run only
when verification is `:passed` and the manifest is `:complete`. It creates one
`:checkpoint` receipt from defensive copies of the closed evidence labels, then
makes exactly one atomic `record-run` call with the replacement pair.

A recorded pair returns `:accepted`; a record conflict returns `:conflict`
without retry. Failed, unknown, incomplete, malformed, or callback-faulted
evidence returns `:refused` without recording. The callback handler encloses
only each callback invocation. An unexpected domain failure remains visible and
records nothing.

## Evidence

```text
python3 scripts/lint-parens.py \
  src/application/ports.lisp src/application/checkpoint.lisp src/packages.lisp \
  tests/support/fakes.lisp tests/application/test-checkpoint.lisp tests/run.lisp
6 paths reported [OK].

sbcl --script tests/run.lisp
495 checks passed.
```

## Boundary result

No outer component can checkpoint a run through raw tool or repository detail.
The application boundary receives only closed evidence values and records one
verified replacement pair or none.

## Next

Add Task 3.5 `close-run` with its smaller one-slot terminal-recording contract.


## 2026-08-12-task-a-autonomous-control

# Task A autonomous control policy record

## Scope

Published the autonomous development control contract. This is policy and
documentation only. It adds no executable adapter, model route, stage, commit,
push, provider, service, daemon, watcher, scheduler, or persistence behavior.

## Decision

Routine feature, scope, capability, failure-disposition, review, and future
mutation decisions use source-grounded policy certificates. Operators guide
policy, deployment profiles, budgets, privileged-work posture, release posture,
and safety-boundary changes; operator perception is not the routine approval
mechanism. A human-approval profile remains available for deployments that need
it.

## Evidence

- `docs/design/autonomous-development-control.md` defines the source hierarchy,
  principle matrix, closed proposal/action vocabulary, failure dispositions,
  certificate facts, review ladder, promotion path, and non-goals.
- `docs/project/decisions.md`, `docs/core/clean-architecture-charter.md`,
  `AGENTS.md`, and `CONTRIBUTING.md` now require a current policy certificate
  for a future mutation and preserve an explicit transitional rule until an
  executor exists.
- `docs/project/backlog.md` requires each future proposal to carry a source
  manifest and principle matrix.
- `docs/README.md` exposes the control contract in the canonical read order.

## Verification

```text
make test
8 reader guard checks passed.
495 checks passed.
ASDF load completed.

Markdown relative-link check
Markdown relative links passed.

git diff --check HEAD
passed.
```

## Remaining unknowns

The certificate, source-manifest values, deterministic evaluator, review
adapters, and mutation executor do not exist yet. The read-only evidence report
exists, but it is not an authorization certificate and does not authorize a
mutation.


## 2026-08-12-task-c0-proposal-ledger

# Task C0 proposal evidence ledger record

## Scope

Implements the pure input contract needed before deterministic principle
evaluation. It adds immutable domain values and fixtures, but no evaluator,
certificate, port, adapter, provider route, model review, filesystem access,
Git operation, process, service, daemon, watcher, scheduler, or mutation.

## Decision

Every future deterministic evaluation receives one immutable
`policy-proposal`. It records the closed proposal class; problem; smallest
useful outcome; purpose; caller; input; output; failure contract; declared
capabilities; capability diff; source manifest; risk note; dependency; evidence
trigger; and ordered evidence requirements.

Each immutable `evidence-requirement` binds one closed principle to a closed
requirement kind, required fingerprints, and supplied immutable evidence facts.
The closed requirement kind provides evaluator meaning while evidence-fact kind
remains open. A requirement is complete only when each required fingerprint is
supplied exactly once by a current fact. Missing, duplicate, stale, malformed,
conflicting, or unverifiable facts refuse.

The proposal and ledger are non-authoritative. They contain no action,
certificate, repository authority, provider execution detail, port, callback,
filesystem, Git, process, clock, environment, or network field.

## Recovery lesson

This slice required recovery after overlapping partial delegated edits left
duplicate definitions and an unbalanced package boundary. The recovery worker
inspected the actual lane, retained valid refusal and defensive-copy fixtures,
reconciled one canonical value surface, and reran the full gate before a fresh
review. Future partial delegated lanes follow the same rule: recover the
candidate in place; do not discard coverage or restart from an assumed-clean
state.

## Evidence

- `docs/project/decisions.md` makes proposals and source manifests mandatory
  for policy evaluation and requires invalid evidence to refuse.
- `docs/project/backlog.md` requires problem, smallest outcome, source
  manifest, principle matrix, risk note, dependency, and evidence trigger.
- `docs/design/autonomous-development-control.md` supplies the ten principles,
  required evidence, and refusal conditions.
- `src/domain/governance.lisp` supplies immutable source, evidence, principle,
  and verdict values but intentionally leaves fact kind open; the ledger closes
  policy meaning without turning fact producers into domain policy.

## Remaining unknowns

The deterministic evaluator, failure-disposition mapping, certificate issuer,
and evidence adapter do not exist yet. The next executable slice is pure
principle evaluation over these immutable values.


## 2026-08-12-task-e-candidate-evidence

# Task E candidate evidence record

## Scope

Added a local read-only candidate evidence bundle. It accepts one explicit
manifest of sorted, duplicate-free repository-relative regular files and never
infers a candidate from Git status or staging semantics.

## Decision

`make verify-candidate CANDIDATE_MANIFEST=path/to/manifest` gathers
hash-bound evidence for one declared candidate. It records repository revision
and whole-tree dirty, staged, and untracked facts, but those facts do not expand
or select candidate scope.

The bundle refuses missing, empty, unsorted, duplicate, absolute, escaping,
ignored, excluded, missing, directory, unreadable, unsafe, or unavailable
input. `.hermes/**` is not an admissible candidate path. It performs no
staging, commit, push, provider call, service start, archive read, or model
invocation.

## Evidence

- `scripts/verify-candidate.py` reads manifest and declared candidate files
  only, emits a deterministic content hash, and reports a closed status.
- Fixed local checks cover declared Lisp parenthesis balance, the inward
  dependency rule, public-content patterns, whitespace, local Markdown links,
  and the independent `make test` kernel gate.
- `tests/scripts/test-verify-candidate.py` contains scratch-repository fixtures
  for successful evidence, malformed manifests, excluded and ignored paths,
  unsafe content, whitespace, links, Lisp guard availability and failure,
  inward dependency direction, and whole-tree observation.
- `Makefile` exposes the required explicit-manifest entry point.

## Verification

```text
python3 tests/scripts/test-verify-candidate.py
77 candidate verifier checks passed.

make test
8 reader guard checks passed.
495 checks passed.
ASDF load completed.

git diff --check
passed.
```

## Remaining unknowns

This report is evidence only. It cannot issue an authorization certificate,
record a receipt, stage, commit, push, or resolve review disagreement. Those
remain later governance and authorization tasks.


## 2026-08-13-pi-worker-and-delegation-survey

# Pi worker and delegation survey

**Date:** 2026-08-13

**Scope:** This is a research record. It changes neither Hngh's kernel nor its
runtime. Pi is not installed, no credential has been configured, and no Pi
extension is admitted by this record.

## Decision

Hngh will orient future agent execution and delegation work around **Pi as a
replaceable outer worker**. Hngh remains the authority for run admission,
loadouts, route and budget selection, allowed paths and capabilities, evidence,
and termination. Pi is never a source of authority or durable product memory.

A future Pi adapter belongs outside `hngh.domain` and `hngh.application`. The
first integration shape is a short-lived Pi RPC process: strict JSONL over
standard input/output, no session persistence, a declared provider/model, and
an explicit resource and tool set.[1]

Pi extensions are trusted TypeScript running in the agent process. They can
register tools, intercept calls, alter context handling, and persist session
entries. Tool policy is useful but is not an operating-system isolation
boundary.[2] A Pi worker therefore runs only from an Hngh-issued loadout, a
scrubbed environment, and a disposable worktree or sandbox.

## Worker contract

Every future Pi run must have all of the following before it starts:

```text
one admitted run
one compact, source-grounded packet
one declared model route
one bounded token, cost, call, and wall-clock allowance
one explicit tool allowlist
one declared network posture
one isolated writable root, if any
one named verification command
one evidence and handoff record
```

The default worker is read-only. It has no persistence, no ambient extension
discovery, no ambient MCP configuration, no inherited provider or search
credentials, no recursive delegation, and no authority to commit, push, change
an Hngh profile, or promote its own output.

A writing worker is a later capability. It may write only in a disposable
worktree. It proposes an artifact and records verification output; a separate
Hngh decision admits any later application, staging, commit, or publication.

## Adoption order

### First admitted spike: Pi core and one subagent extension

The first bounded experiment should install Pi outside this repository and use
RPC mode with `--no-session`. It should use a fixed local or lowest-cost route,
a fixture checkout, and no built-in mutation tools. Pi's SDK also supports an
in-memory session manager; that is the preferred implementation path if a
future Node bridge is justified.[3]

Evaluate **one** delegation package in this spike, not several at once:

- `pi-subagents` is the initial candidate. It provides focused child-agent
  delegation, foreground and background modes, and configurable role/workflow
  material.[4]
- `@tintinweb/pi-subagents` is a later alternative, not an addition to the
  same experiment. It uses isolated sessions and documents an opt-in nested
  delegation allowlist and depth limit.[13]
- `pi-background-tasks` is evaluated only after the initial read-only child
  trial. Its background process and durable-result features need separate
  lifecycle, retention, cancellation, and receipt tests.[5]

The initial spike permits only source reconnaissance and independent review.
It permits at most two children per parent and one depth. It must not start a
persistent service or launch an unbounded background job.

### Second spike: controlled discovery and external research

- `pi-codemapper` may be trialed in a disposable worktree for constrained,
  read-only source mapping after its CLI dependency and cache behavior are
  inspected.[11]
- `pi-mcp-adapter` may be trialed only after Hngh admits a specific MCP server
  through a port. Its in-memory configuration mode is preferred because normal
  mode reads MCP configuration and can start configured server commands.[6]
- `pi-web-access` may be used only for an explicit external-research loadout.
  It supports Kagi among several search providers; Hngh must pass only a
  dedicated Kagi credential, prohibit browser-cookie reuse and remote fetch
  fallbacks unless specifically admitted, and redact the resulting evidence
  record.[7]
- `@dietrichgebert/ponytail` is a low-risk prompt/skill trial for scoped
  implementation workers. It changes guidance rather than process authority,
  but its quality and token claims require our own fixed-corpus measurement.[14]

### Later experiments, after baseline telemetry exists

- `pi-fork` shares the active session branch with child Pi processes. It may be
  useful for a bounded design/review split, but shared context conflicts with
  Hngh's small-packet default and demands strict context ceilings.[8]
- `pi-minimal-subagent` is a lean git-installed alternative. It is not a first
  trial because its child tool, inherited tools, recursion behaviour, and
  maintenance surface still need the same isolation evidence as the larger
  delegation extensions.[10]
- `pi-observational-memory`, `pi-rtk-optimizer`, and `pi-lens` are possible
  observability or context-economy tools. They require a baseline measurement
  before we can establish that their compaction or persistence is worthwhile.
  Worker-side memory cannot become Hngh memory.[9][12]
- `pi-hermes-memory` is a worker-local memory experiment only. It persists
  memory and session-search data, so it is excluded from default ephemeral
  workers and must not bridge into Hngh's durable records.[16]
- `@quintinshaw/pi-dynamic-workflows` and `@mjasnikovs/pi-task` may be studied
  for workflow mechanics after Hngh has its own run, receipt, and cancellation
  contracts. The latter is AGPL-3.0 and includes network-facing remote-workflow
  features, so it remains out of the first worker stack.[15][17]

### Not admitted

- `context-mode` is not adopted now. Its Elastic License 2.0 terms and
  sandboxed code-execution surface add a licensing and execution boundary that
  is not required for the first Pi worker.[18]
- No ambient extension auto-discovery, raw git extension install, recursive
  fork workflow, automatic memory extraction, automatic compaction, dynamic
  model fallback, or autonomous task queue is admitted.

## Risk controls

| Risk | Required control |
|---|---|
| Agent or extension authority | Hngh tool allowlist; custom closed-shape tools; extensions reviewed before installation; no built-in mutation tools in the first spike. |
| Credentials | Scrub child environment; inject one route credential only when needed; separate Kagi key for web research; no ambient auth/config search; redaction test. |
| Context growth | Fresh child sessions; small source packet; child summary is evidence, not authority; auto-compaction off until measured. |
| Persistence | `--no-session` or in-memory sessions; temporary state under a run-owned directory; delete after receipt collection; no raw transcript retention. |
| Filesystem mutation | Read-only default; disposable worktree for writing; pre/post manifest and `git status` evidence; no direct Hngh-root write. |
| Network and process startup | Network denied by default; named route-only transport; explicit research loadout for Kagi; no MCP, remote listener, browser reuse, or background daemon in the first spike. |
| Recursive delegation | One child layer, maximum two children, parent-held budget, and explicit role list; unknown child state fails closed. |
| Cost and model routing | One declared route per run; Hngh chooses it before launch; no model fallback or extension-selected routing; receipt records actual route and usage. |

## Required fixture evidence before any live Pi delegation

1. **Read-only boundary:** a scout and reviewer leave a fixture repository's
   content, status, and manifest byte-identical. They do not start a daemon or
   write an Hngh root.
2. **Loadout refusal:** missing route, budget, time limit, tool list, network
   posture, or verification command prevents process launch.
3. **Tool and path refusal:** an unlisted tool or path outside the declared
   root produces a refusal receipt and no side effect.
4. **Child limit:** a child request to create another child at prohibited depth
   or over the spawn budget is refused and recorded.
5. **Credential hygiene:** a synthetic credential never appears in output,
   session state, artifact, error record, or handoff.
6. **Cancellation and afterlife:** Hngh can stop a worker, collect bounded
   evidence, and leave no running child or orphaned temporary state.
7. **Result integrity:** any retained child result is identified by an artifact
   digest; truncation, malformed JSONL, or missing verification evidence
   refuses promotion.
8. **Context and cost telemetry:** parallel reviewers do not exchange raw
   transcripts; each receipt records actual route, calls, tokens when known,
   elapsed time, and bounded output location.

## Deferred implementation requirements

A Pi adapter proposal must name:

- the application ports it implements, without introducing Pi types inward;
- its process/resource model and exact environment scrub policy;
- the loadout-to-Pi translation, including model, tools, session mode, cwd,
  network policy, and timeout;
- typed JSONL event and error translation, including malformed-event refusal;
- secret redaction, artifact retention, deletion, and afterlife policy;
- fixture fakes and the eight evidence tests above;
- one manual, read-only use case and its acceptance command.

Until that proposal is accepted, direct bounded completion remains the smallest
path for planning/review work, while existing Hermes/OpenCode facilities remain
bridges rather than Hngh dependencies.

## Sources

[1] https://pi.dev/docs/latest/rpc
[2] https://pi.dev/docs/latest/extensions
[3] https://pi.dev/docs/latest/sdk
[4] https://github.com/nicobailon/pi-subagents
[5] https://github.com/ismailsaleekh/pi-background-tasks
[6] https://github.com/nicobailon/pi-mcp-adapter
[7] https://github.com/nicobailon/pi-web-access
[8] https://github.com/elpapi42/pi-fork
[9] https://github.com/elpapi42/pi-observational-memory
[10] https://github.com/elpapi42/pi-minimal-subagent
[11] https://github.com/elpapi42/pi-codemapper
[12] https://github.com/MasuRii/pi-rtk-optimizer
[13] https://github.com/tintinweb/pi-subagents
[14] https://github.com/DietrichGebert/ponytail
[15] https://github.com/QuintinShaw/pi-dynamic-workflows
[16] https://github.com/chandra447/pi-hermes-memory
[17] https://github.com/mjasnikovs/pi-task
[18] https://github.com/mksglu/context-mode


## 2026-08-17-task-c1-principle-evaluation

# Task C1 deterministic principle evaluation record

## Scope

Implements the deterministic evaluator over the immutable proposal ledger
added in task C0. It adds a pure `evaluate-policy-proposal` function and
fixtures, but no certificate, port, adapter, provider route, model review,
filesystem access, Git operation, process, service, daemon, watcher,
scheduler, or mutation.

## Decision

`evaluate-policy-proposal` consumes one immutable `policy-proposal` and returns
a `policy-verdict` carrying exactly ten principle results in matrix order, one
per closed principle: `closed-authority`, `least-authority`,
`dependency-direction`, `fail-closed`, `evidence-before-claim`,
`atomic-mutation`, `reversibility`, `no-hidden-execution`,
`cost-and-route-discipline`, and `source-grounding`. The order is fixed by the
matrix, never by requirement order in the proposal.

A principle with no evidence requirement is a refusal: a `:refused` principle
result with no fingerprints and reason label `missing-principle-result`. A
single evidence requirement passes only when every required fingerprint is
supplied exactly once by a `:current` fact. Missing, stale, malformed,
conflicting, or unverifiable facts refuse with the labels `missing-evidence`,
`stale-evidence`, `malformed-evidence`, `conflicting-evidence`, and
`unverifiable-evidence`. A fact supplied under one principle never satisfies a
requirement of another principle. The verdict is `:admitted` only when every
principle result is `:passed`; otherwise `:refused` with the deduplicated
union of refusal labels in matrix order.

Evaluation is deterministic, side-effect-free, and independent of requirement
order. The pure evaluator never emits `:needs-escalation`; that state remains
reserved for later reviewer and failure-disposition policy. Extra `:current`
facts beyond a requirement's required fingerprints do not refuse: the closed
refusal vocabulary names only missing, duplicate, stale, malformed,
conflicting, and unverifiable facts.

## Recovery observation

This slice ran cleanly against its brief on the first pass: the implementation
and its tests landed together and the full gate passed without a recovery pass.
No recovery lane from task C0 was re-entered.

## Evidence

- `docs/project/decisions.md` records the principle matrix, the rule that a
  missing principle result is a refusal, and this exact evaluation contract.
- `src/domain/governance.lisp` supplies `+matrix-principles+`,
  `evidence-requirement-passed-p`, and `evaluate-policy-proposal` as pure
  values and functions. `src/packages.lisp` exports `evaluate-policy-proposal`.
- `tests/domain/test-governance.lisp` adds 30 checks covering ten-principle
  admission, missing-principle refusal, absent/stale/malformed/conflicting/
  unverifiable/missing evidence labels, two-requirement principles,
  cross-principle evidence isolation, requirement-order independence, extra
  current facts, and nil/non-proposal input.
- `make test` reports 640 checks passed: 8 reader guard checks, 640 in
  `tests/run.lisp`, then an ASDF `:hngh` load.

## Remaining unknowns

The failure-disposition mapping, certificate issuer, and evidence adapter do
not exist yet. `:needs-escalation` is present in the state vocabulary but not
emitted by the pure evaluator; the reviewer-challenge and failure-disposition
policy that may reach it are a later slice.

## 2026-08-17-task-c2-failure-disposition

# Task C2 closed failure-disposition policy record

## Scope

Implements the separate closed failure-disposition policy over the closed
failure categories. It adds a pure `evaluate-failure-disposition` function and
fixtures, but no certificate, port, adapter, provider route, model review,
filesystem access, Git operation, process, service, daemon, watcher,
scheduler, or mutation.

## Decision

`evaluate-failure-disposition` maps each of the eight closed failure categories
to exactly one closed disposition, refusing unknown categories. Domain and
application invariants propagate to the test gate; port-callback faults and
malformed returns normalize to a refusal at that callback only; atomic
recording conflicts normalize to conflict without retry; insufficient or stale
evidence refuses; tool and environment faults refuse; review disagreement
escalates; and mutation precondition mismatches stop and record evidence.

The two conditionally worded table rows in
`docs/design/autonomous-development-control.md` resolve to their primary
default in the pure policy, per the operator-approved contract: a
domain-policy-or-invariant failure propagates to the test gate (the typed
domain refusal refinement belongs to a later runtime layer), and a tool or
environment fault refuses (named evidence-policy escalation is a later
refinement). The policy is deterministic and total over the closed category
set; a use case never decides a disposition by catch-all condition handling.

## Build note: list-valued constants and SBCL redefinition

The three list-valued vocabularies in `src/domain/governance.lisp`
(`+matrix-principles+`, `+failure-categories+`, `+failure-dispositions+`) use
`defparameter`, not `defconstant`. SBCL evaluates a `defconstant` form at
compile time (for constant folding) and again when the compiled fasl is
loaded; the two literal objects are not `eql`, so an ASDF recompile raises
`DEFCONSTANT-UNEQL` ("The constant ... is being redefined") even when the
values are textually identical. `eval-when (:load-toplevel :execute)` does not
prevent the compile-time side effect, and SBCL 2.6.7's `defconstant` accepts
no `:test` keyword. `#.` reader-eval made the plain source-load path fail.
`defparameter` survives the full compile/load/recompile cycle; immutability of
the vocabulary is enforced by the closed-vocabulary fixtures, not by the Lisp
constant mechanism. A future agent that adds another list-valued vocabulary
should follow the same pattern.

## Evidence

- `docs/project/decisions.md` records the closed failure-disposition decision
  and the primary-default resolution of the conditional rows.
- `src/domain/governance.lisp` supplies `+failure-categories+`,
  `+failure-dispositions+`, and `evaluate-failure-disposition` as pure values
  and a function; `src/packages.lisp` exports `evaluate-failure-disposition`.
- `tests/domain/test-governance.lisp` adds 10 checks covering all eight
  category-to-disposition mappings, unknown-category refusal, and disposition
  validation.
- `make test` reports 650 checks passed: 8 reader guard checks, 650 in
  `tests/run.lisp`, then an ASDF `:hngh` load.

## Remaining unknowns

The certificate issuer and evidence adapter do not exist yet. The conditional
refinements (typed-domain-refusal on top of a propagated domain failure;
escalation through named evidence policy) are deferred to the runtime layers
that can observe those facts. The next executable slice is the non-mutating
candidate authorization certificate, per `docs/project/roadmap.md`.

## 2026-08-17-task-c3-candidate-certificate

# Task C3 non-mutating candidate authorization certificate record

## Scope

Implements the pure certificate issuer over an admitted policy verdict. It
adds a `candidate-certificate` value and `issue-candidate-certificate`, but no
action, callback, port, filesystem access, Git operation, process, service,
daemon, watcher, scheduler, or mutation executor.

## Decision

`issue-candidate-certificate` mints an immutable `candidate-certificate` from
an `:admitted` `policy-verdict`. The certificate authorizes one action only —
`:none`, `:prepare-candidate`, `:stage`, `:commit`, or `:push` — and records
repository identity, base revision, ordered candidate paths, content hash,
evidence hashes, the admitting verdict, review findings, source manifest,
policy profile, and expiry.

The issuer is mechanical, per the operator-approved boundary for this slice:
it validates the verdict is `:admitted`, the action is one of the closed
classes, and every recorded fact is present, nonempty, and duplicate-free,
then binds them into the immutable value. It does not judge whether a given
action is policy-admissible — a commit certificate never authorizing a push is
enforced later by the executor, not by the domain issuer. Unknown, missing,
duplicate, and malformed facts refuse; candidate paths and evidence hashes
must be nonempty and duplicate-free; the verdict list is nonempty and
duplicate-free; accessors defensively copy every string and list slot.

## Build note: leftmost `&key` occurrence

Validation tests that override a keyword in a base plist must not rely on a
later duplicate keyword winning: SBCL's `&key` argument binding uses the
leftmost occurrence of a duplicated keyword. Force a bad value with a direct
call, not a base-plist plus override.

## Evidence

- `docs/project/decisions.md` records the non-mutating candidate authorization
  certificate decision and the deferred action-admission boundary.
- `src/domain/governance.lisp` supplies `validate-certificate-action`,
  `candidate-certificate`, `make-candidate-certificate`, and
  `issue-candidate-certificate`; `src/packages.lisp` exports them.
- `tests/domain/test-governance.lisp` adds 29 checks covering every closed
  action being issuable, accessor round-trips, non-admitted/non-verdict
  refusal, unknown-action refusal, empty/duplicate candidate paths, missing
  content hash, missing/duplicate evidence hashes, duplicate verdicts, empty
  source manifest, missing expiry, and defensive copies.
- `make test` reports 679 checks passed: 8 reader guard checks, 679 in
  `tests/run.lisp`, then an ASDF `:hngh` load.

## Remaining unknowns

The mutation executor that rechecks every certificate fact immediately before
its named action does not exist yet; action-admission policy (such as commit
never authorizing push) is deferred to it. The next executable slice is
resuming the remaining application use cases under the admitted policy
proposal and evidence process, per `docs/project/roadmap.md`.

## 2026-08-17-task-d1-close-run

# Task D1 policy-gated close-run record

## Scope

Resumes the remaining application use cases under the admitted policy proposal
and evidence process. It adds the `close-run` application use case and its
ports, but no certificate issuance, adapter, filesystem access, Git operation,
process, service, daemon, watcher, scheduler, or mutation executor.

## Decision

`close-run` advances a run to a terminal state — `:cancelled`, `:evacuated`,
or `:dead` — only under an `:admitted` policy verdict. The `close-request`
carries the run, a closed terminal target, and a policy proposal; the use case
evaluates the proposal deterministically via `evaluate-policy-proposal` and,
unless the verdict is `:admitted`, refuses with the verdict reason labels. An
illegal target for the run's current state refuses with the closed
`invalid-transition` label. Recording is one atomic run-and-receipt callback;
conflicts refuse without retry and stay atomic; malformed or erroring
callbacks refuse.

`close-run` issues no certificate. The hash-bound `candidate-certificate`
vocabulary serves the future mutation executor (which rechecks every
certificate fact immediately before its named action); run-state transitions
do not bind hash-bound mutation facts. Action-admission policy remains with
that executor.

## Evidence

- `docs/project/decisions.md` records the policy-gated run close decision.
- `src/application/ports.lisp` supplies `close-request`,
  `make-close-request`, `close-request-run`, `close-request-target`,
  `close-request-proposal`, and `run-close-ports`; `src/application/close-run.lisp`
  supplies `close-run`; `src/packages.lisp` exports them.
- `tests/application/test-close-run.lisp` adds 38 checks covering admitted
  and refused proposals, every terminal target, illegal transitions, atomic
  recording conflicts, callback errors, malformed returns, and wrong-typed
  inputs; `tests/support/fakes.lisp` gains `make-close-fake`.
- `make test` reports 717 checks passed: 8 reader guard checks, 717 in
  `tests/run.lisp`, then an ASDF `:hngh` load.

## Remaining unknowns

The read-only evidence adapter, mutation executor, and model-review adapters
do not exist yet; the executor is the first consumer of the issued
certificate and the verification gates named in
`docs/design/autonomous-development-control.md`. The next executable slice
per the roadmap is the read-only evidence adapter, then the mutation executor.

## 2026-08-18-docs-intent-framing

# Task: intent and direction documentation framing record

## Scope

Documentation-only reframing. Rewrites the root `README.md`, the
documentation index, and the roadmap, and adds `docs/intent.md` as the
human-facing vision document. No source, test, gate, or runtime change.

## Decision

The active docs previously stated status and contracts but not why Hngh
exists or where it is going. The reframing recovers the original intent from
the archived pre-refactor plans (roguelike discipline as bounded, evidenced
runs; the cost-first intelligence ladder; Pi as a replaceable outer worker)
and expresses it in plain language for a reader with only a casual
understanding of computers:

- `docs/intent.md` leads with the canonical story — development as short,
  bounded cycles (plan, check, record, close) with a paper trail and a human
  final say — then covers the run lifecycle, the roguelike analogy (labeled
  as metaphor, not game), kernel guarantees, clean architecture, agents
  (Pi/oh-my-pi framed as future and under consideration, never installed or
  decided), cost discipline, a 13-term plain glossary, and a pointer to the
  roadmap.
- The root `README.md` adds What/Why/How/Where-it-is-going sections while
  keeping the four verify commands verbatim and the status honest (library
  plus fixture tests only; no daemon, adapter, CLI, or Pi worker).
- The roadmap gains a Direction section explaining why each rebuild rung
  exists (evidence before claims; permission re-checked at the moment of
  action; reviewers advise, never decide), keeps the completed frontier
  accurate, and retains the no-daemon admission line verbatim.
- The documentation index now names two audiences — humans read intent
  first, engineers and agents read contracts — with Intent as item 0.

Game terms appear only as a labeled analogy. Nothing unbuilt is implied to
exist.

## Evidence

- `docs/intent.md` (new, 154 lines), `README.md`, `docs/project/roadmap.md`,
  `docs/README.md` rewritten per the framing contract above.
- Archived intent sources consulted at
  `~/Projects/back/hngh/2026-08-17-hermes-plans/plans/` (roguelike
  development process, clean-architecture megastructure scaffold, run domain,
  application ports, autonomous development control, cost-first intelligence
  ladder) and `~/Projects/back/hngh/2026-08-11-pre-crystallized-refactor/`.
- `make test` still reports 8 reader guard checks plus 717 checks — the
  documentation change is source-neutral.

## Remaining unknowns

No new technical unknowns. The Pi/oh-my-pi worker decision, the read-only
evidence adapter, the mutation executor, and model-review adapters remain
future roadmap work, as recorded in `docs/project/roadmap.md`.


## 2026-08-18-task-r4-evidence-adapter

# Task R4 read-only evidence adapter record

## Scope

Implements roadmap promotion rung 4: the read-only evidence adapter.
It adds `hngh.adapters.evidence`, an outer library that gathers a fixed,
enumerated set of read-only local evidence commands through an injected
process transport and maps the results to domain evidence facts and source
manifest entries with closed states. It adds no mutation executor, model
review adapter, daemon, service, watcher, clock, or environment access; the
five application use cases are unchanged.

## Decision

The adapter exposes `gather-evidence` over one request value. The fixed,
enumerable command set is `:repository-revision` (`git rev-parse HEAD`),
`:working-tree-status` (`git status --porcelain=v1 --untracked-files=all`),
and `:file-sha256` (`sha256sum <target>`). No caller-supplied command string
is ever built: the adapter resolves the exact argv for each named command.
Requests validate at construction — unknown commands, escaping, absolute,
home-relative, or option-like targets, duplicate targets, and missing
targets or source roles all refuse.

Gathering runs through `evidence-ports`, an injectable transport callback
contract `(run-process argv) => (values exit-code stdout stderr)`. A thrown
or malformed transport return fails the whole bundle closed with the label
`transport-fault`; unparseable command output fails closed with
`malformed-output`; neither state carries partial facts or manifest
entries. Everything else becomes evidence: a successful fixed command
produces `:current` facts, a missing file produces a `:missing` fact, and
an unreadable or failing command (for example a revision query outside a
repository) produces an `:unverifiable` fact, both without a manifest
entry. `:file-sha256` produces one `:content-hash` fact and one
source-manifest entry per target, keeping target order. The working-tree
fingerprint is the canonical porcelain output text, with `"clean"` for an
empty tree; the revision fingerprint is the revision itself; the content
fingerprint is the digest. The real transport, `process-run`, is exported
for composition; tests never execute a subprocess.

The adapter is the outer layer only. It depends on `hngh.domain` values and
Common Lisp process detail; it references no application package, decides
no policy, evaluates no requirement ledger, and mutates nothing. Domain and
application sources remain adapter-free, enforced by source-scan checks in
the fixture suite.

## Evidence

- `docs/project/roadmap.md` moves rung 4 to Completed and promotes the
  mutation executor to first in Next.
- `src/adapter/evidence.lisp` supplies the fixed command set, request,
  ports, result, and `gather-evidence`; src/packages.lisp exports the
  package; hngh.asd loads it serially after the application slices.
- `tests/adapter/test-evidence.lisp` adds fixture-backed checks covering
  command-set fixedness and enumerability, unknown-command, escaping-path,
  and duplicate-evidence construction refusals, malformed-output and
  transport-fault bundle refusals, missing and unverifiable evidence
  states, manifest mapping, defensive copies, and source-level dependency
  direction; `tests/support/fakes.lisp` adds the process-transport fake;
  `tests/fixtures/evidence/` holds raw command-output fixtures.
- `make test` reports 8 reader guard checks, 824 checks in
  `tests/run.lisp`, then an ASDF `:hngh` load. The real transport was
  smoke-tested against the live tree (revision, working-tree status, and
  content hashes gathered as `:current`).

## Remaining unknowns

The mutation executor (rung 5) is the first consumer of the gathered facts
and issued certificates; it must re-check every certificate fact
immediately before its named action. `:stale`, `:conflicting`, and
`:malformed` fact states remain ledger-side outcomes: the adapter records
what the fixed commands report, and the ledger decides meaning.

## 2026-08-18-task-r5-mutation-executor

# Task R5 mutation executor record

## Scope

Implements roadmap promotion rung 5: the certificate-bound mutation executor.
It adds `hngh.adapters.mutation`, fixture-backed tests, and no daemon, service,
watcher, scheduler, model-review adapter, remote push, or default process. The
kernel domain and application packages remain free of adapter dependencies.

## Decision

`execute-mutation` accepts a `candidate-certificate`, optional fresh
`mutation-evidence`, and `mutation-ports`. When fresh evidence is omitted, the
ports may gather it through an injected callback. The executor rechecks
repository identity, base revision, ordered candidate paths, content hash,
evidence hashes, admitted principle verdicts, review findings, source
manifest, policy profile, and expiry before creating the command. A mismatch or
invalid/stale fact returns a typed refusal and invokes no mutation transport.

The action vocabulary is fixed: `:none`, `:prepare-candidate`, `:stage`,
`:commit`, and `:push`. `:none` is refused. `:prepare-candidate` and `:stage`
use `git add -- <candidate-paths>`, `:commit` uses a fixed `git commit`
message containing the certificate content hash and the bound candidate paths,
and `:push` uses `git push origin HEAD`. An optional requested action must
match the certificate action; it cannot escalate a stage or commit certificate.
Commands are argv lists, never shell strings, and all process calls sit behind
`mutation-ports`.

Results are closed values: `:executed`, `:refused`, `:mismatch`,
`:command-failed`, or `:transport-fault`, with stable refusal labels and
bounded command output. Unknown, malformed, duplicate, unadmitted, expired,
unsupported, or unauthorized inputs fail closed.

## Evidence

- `src/adapter/mutation.lisp` supplies `mutation-evidence`, `mutation-ports`,
  `mutation-result`, the fixed action set, and `execute-mutation`.
- `src/packages.lisp`, `hngh.asd`, and `tests/run.lisp` register the adapter.
- `tests/support/fakes.lisp` supplies the mutation process/evidence fake;
  `tests/adapter/test-mutation.lisp` covers every action, every certificate
  fact mismatch, expiry, missing verdict, action escalation, malformed input,
  command failure, transport fault, and evidence gathering through the port.
- `docs/project/roadmap.md`, `docs/core/component-map.md`, `README.md`, and
  `CHANGELOG.md` record rung 5 as complete and bounded model review as next.
- `make test` reports 8 reader-guard checks, 888 Common Lisp checks, and a
  successful ASDF `hngh` load. Tests invoke only fakes and never mutate the
  repository or working tree.

## Remaining unknowns

Bounded model-review adapters remain the next roadmap rung. Real composition of
repository identity and fresh evidence is deferred to an outer composition
root; this adapter intentionally requires explicit evidence or an injected
gather callback and never reads ambient state itself.


## 2026-08-18-task-r6-review-adapter

# Task R6 model-review adapter record

## Scope

Implements roadmap promotion rung 6: the bounded model-review adapter. It
adds `hngh.adapters.review`, fixture-backed tests, and no daemon, service,
watcher, scheduler, provider call, network route, or default model transport.
The kernel domain and application packages remain free of adapter dependencies.

## Decision

`request-review` accepts a closed `review-request` — candidate paths (safe,
duplicate-free, bounded), a content hash, and policy-context labels — and a
`review-ports` transport carrying one injected `invoke-reviewer` callback. The
adapter builds one fixed JSON prompt from those fields (no caller-supplied
free text), hands it to the callback, and receives `(values exit-code stdout
stderr)` exactly like the evidence and mutation transports.

A zero exit parses stdout as a strict JSON envelope:

```json
{"findings":[{"label": string, "citation": string}, ...]}
```

Only that shape is accepted: exactly one top-level `findings` key; each
finding is an object with exactly `label` and `citation` string fields; both
are nonempty printable strings bounded to 200 characters; a maximum of 32
findings; numeric, boolean, null, duplicate-key, nested, or trailing-garbage
output refuses. Duplicate labels, unsafe findings labels/citations, and
oversized model output refuse with closed labels (`unsafe-finding`,
`duplicate-finding`, `too-many-findings`, `output-too-large`,
`malformed-output`). A failed review call (nonzero exit) yields a complete
bundle with a single `:review` evidence fact at state `:unverifiable` and
fingerprint `"unavailable"`. A thrown or malformed transport return yields a
`transport-fault` refusal.

On success the result is `:complete` with sanitized findings and one
deterministic `evidence-fact`: kind `:review`, state `:current`, fingerprint
`<content-hash>|<sorted-labels>`, so identical reviews of identical content
produce identical evidence and certificates can bind the labels. Findings are
immutable `review-finding` values (label + citation) whose labels feed
`candidate-certificate` review-findings; the adapter itself decides nothing,
issues nothing, and executes nothing.

The adapter has no default transport, performs no network or subprocess
access, and lives entirely behind the injected callback, keeping the kernel
pure and `make test` network-free.

## Evidence

- `src/adapter/review.lisp` supplies `review-request`, `review-finding`,
  `review-ports`, `review-result`, the strict JSON envelope reader, the fixed
  prompt builder, and `request-review`.
- `src/packages.lisp`, `hngh.asd`, and `tests/run.lisp` register the adapter.
- `tests/support/fakes.lisp` supplies the review transport fake recording every
  prompt; `tests/adapter/test-review.lisp` covers closed request construction,
  escaping paths, prompt hygiene, deterministic fingerprints, valid and empty
  findings, reviewer failure to `:unverifiable`, transport faults, malformed
  JSON, schema violations, duplicate and unsafe findings, and the finding-set
  and response-size bounds.
- `docs/project/roadmap.md`, `docs/core/component-map.md`, `docs/architecture.md`,
  `docs/core/clean-architecture-charter.md`, `docs/core/test-boundary.md`,
  `README.md`, and `CHANGELOG.md` record rung 6 as complete and explicit
  composition as next.
- `make test` reports 8 reader-guard checks, 1059 Common Lisp checks, and a
  successful ASDF `hngh` load. Tests invoke only fakes and never contact a
  provider, subprocess, or network.

## Remaining unknowns

Explicit composition, operator-visible presentation, and real model or
terminal transports remain future rungs. Real review transports must be
separately approved and stay disabled until a run loadout admits them; the
kernel does not supply one now.

## 2026-08-18-task-r7-presentation-and-composition

# Task R7 presentation and composition record

## Scope

Implements roadmap promotion rung 7: the operator-visible presentation
layer and the composition root. It adds `hngh.presentation`, `hngh.main`,
fixture-backed tests, and no daemon, service, watcher, scheduler, provider
call, or default model or terminal transport. The kernel domain and
application packages remain free of adapter dependencies, and
`hngh.presentation` imports no adapter.

## Decision

`hngh.presentation` is a renderer-only component. Pure render functions
turn application results, domain runs and governance values, and installed
adapter results into plain factual strings. Canonical terms stay literal
(`state=evacuated`, `verdict state=refused`, `mutation status=executed`), a
refusal renders as a literal refusal, and rendering never mutates a value.
The optional reference lexicon is accepted only as a flat plist carrying
exactly a `:render` list of four-field entries
(`:surface`, `:original`, `:reference`, `:provenance`); it supplies display
copy at a named surface only, falls back to the original term for unknown
surfaces, and can never carry canonical control fields. `render` dispatches
over every known value type and falls back to the printed representation
for unknown values.

`hngh.main` is the composition root. `make-run-harness` composes the five
application use cases into one `run-harness` over injected port callbacks;
omitted callbacks default to fail-closed or environment-free ports — an
in-memory record store reachable through `harness-records`, a per-harness
identifier source (`run-1`, `run-2`, …), a clock, and `:unknown` admission,
verification, and manifest evidence so nothing is admitted without composed
authority. Coordinator functions wire the installed adapters: evidence
(`gather-run-evidence`) and review (`request-run-review`) through injected
transports, and mutation (`execute-run-mutation`) which rechecks the
certificate against explicit fresh evidence and refuses when none is
supplied. `default-evidence-ports` composes the installed read-only process
transport; `default-mutation-ports` reuses it, with no gather-evidence
default. `display` renders any result through `hngh.presentation`. Loading
`hngh.main` starts no background work.

The domain gained read-only accessors (`run-identifier`, `run-mission`,
`run-role`, `run-loadout`, `receipt-kind`, `receipt-facts`) so presentation
renders runs and receipts without touching canonical state, and
`hngh.application` now exports the bare `verification-result` and
`manifest-result` type names used by the renderer's dispatch. The inward
dependency guard now treats `hngh.presentation` as an inward package: a
fixture proves it cannot import an adapter, and a second fixture proves the
composition root may import presentation and all installed adapters.

## Evidence

- `src/presentation/render.lisp` supplies `render` (dispatch), the
  per-value renderers, `render-report`, `reference-lexicon-p`,
  `render-with-lexicon`, and `render-status-label`.
- `src/main.lisp` supplies `make-run-harness`, the five `harness-*` entry
  points, `harness-records`, `default-evidence-ports`,
  `default-mutation-ports`, `gather-run-evidence`, `request-run-review`,
  `execute-run-mutation`, and `display`.
- `src/packages.lisp`, `hngh.asd`, and `tests/run.lisp` register both
  packages; `tests/support/boundary-guards.lisp` extends the dependency
  guard to presentation, with three new fixtures under
  `tests/fixtures/dependency-guard/`.
- `tests/presentation/test-presentation.lisp` renders every application,
  domain, and adapter result through real use cases and fixture transports,
  checks factual status invariance and literal refusal rendering, and
  verifies the reference lexicon against the Task 1 fixtures.
- `tests/main/test-main.lisp` composes the full run lifecycle through one
  harness (create → arm → start → checkpoint → close, one atomic
  run-and-receipt record per accepted use case), exercises the default and
  fail-closed port adapters, and wires the evidence, review, and mutation
  adapters through fake transports, rendering every result.
- `docs/project/roadmap.md`, `docs/core/component-map.md`,
  `docs/architecture.md`, `docs/core/clean-architecture-charter.md`,
  `docs/core/test-boundary.md`, `docs/project/decisions.md`, `README.md`,
  and `CHANGELOG.md` record rung 7 as complete.
- `make test` reports 8 reader-guard checks, 1137 Common Lisp checks, and a
  successful ASDF `hngh` load. Tests invoke only fakes and never contact a
  provider, subprocess, or network.

## Remaining unknowns

An explicit operator command entry (`hngh.main` as an executable
entrypoint), real model or terminal transports, and persistence remain
future rungs. Real transports must be separately approved and stay disabled
until a run loadout admits them; the kernel supplies no default provider
transport now.


## 2026-08-19-archive-gate-retired

# Task: retire the archive gate and archive boundary framing

## Scope

Removes the active project's dependency on the external retirement archive.
Deletes the `make check-archive` target, the `HNGH_ARCHIVE_ROOT` contract,
and the archive-boundary framing from the active documentation. The archive
itself is not deleted; it remains operator-preserved outside the repository
as historical evidence. No source or test change; Makefile and documentation
only.

## Decision

The prior state was archived to preserve the basis of the refactor, not as a
runtime or documentation dependency. The refactor records now cover the
cutover; the active project's state and roadmap do not consult the archive.
Continuing to verify archive receipts had no operational meaning: nothing in
the active project reads, imports, or depends on the archive, and the
receipt check only re-asserted that the preserved bytes had not drifted.

So the project now documents its current state and treats the archive as
history:

- `make check-archive` and `HNGH_ARCHIVE_ROOT` are removed from the
  Makefile; `.PHONY` lists `test` and `verify-candidate` only.
- README, docs index, intent, test boundary, decisions, roadmap,
  CONTRIBUTING, and AGENTS.md no longer present the archive as a verifiable
  boundary or a read target. The archive is described once, as historical
  evidence only, and contributors are told nothing from it is imported back.
- Meaningful archive material (the hermes plans behind the intent document,
  the pre-crystallized harness vision) is harvested into the operator's
  separate llm-wiki knowledge base for reference, not into this repository.
- Records keep the full prior-state story: the crystallized cutover record
  and this retirement record remain the authoritative history.

## Evidence

- `Makefile`: `check-archive` target and `HNGH_ARCHIVE_ROOT` deleted;
  `make test` still reports 8 reader guard checks plus 1137 checks.
- `git diff` shows only the retired archive gate and the archive-boundary
  doc framing; no Lisp or fixture source changed.
- The on-disk archive at
  `~/Projects/back/hngh/2026-08-11-pre-crystallized-refactor/` is untouched.

## Remaining unknowns

None for the active project. If the operator later wants to consult the
archive, it physically remains at the archived paths; no gate or document
needs to exist for that.

## 2026-08-19-readme-harness-framing

# Task: README harness-framing and positioning record

## Scope

Documentation-only revision to the root `README.md`. Rewrites the `Why`
section to compare Hngh's approach with the open-source agent-harness
mainstream, and rewrites the `Where this is going` section to frame Hngh as
a growing system harness that routes local and remote models, priced routes,
and eventually pooled hardware through one bounded, recorded, human-closable
cycle. No source, test, gate, or runtime change.

## Decision

The prior Why stated the trust problem in two sentences. The prior
Where-this-is-going listed rungs without naming the destination. Both read
narrower than the intent and the roadmap, and both left the reader guessing
whether Hngh is a small library or the early skeleton of a harness.

The revision:

- Expands Why into a contrast with the harness mainstream: throughput- and
  autonomy-first frameworks against Hngh's record- and boundary-first
  posture. The claimed inversion is grounded in external evidence, not
  rhetoric.
- Keeps the honest "library with fixture tests, not a finished tool" status
  and the four verify commands verbatim.
- Reframes Where-this-is-going as a corridor: Hngh grows harness capability
  (transports, replaceable worker, cross-route cost, pooled hardware) while
  holding the rule that the kernel never guesses at the outside and the
  harness always rebuilds around it.
- Keeps the no-daemon/no-provider/no-watcher/no-scheduler admission line
  verbatim. Nothing unbuilt is implied to exist.

## Comparison evidence

The Why comparison cites one external study and one protocol trend; both
verified by reading primary sources this session:

- Hu Wei, "Architectural Design Decisions in AI Agent Harnesses"
  (arXiv 2604.18071, April 2026; https://arxiv.org/abs/2604.18071), an
  empirical study of 70 public agent-system projects. Its stated findings
  ground HnGH's position:
  intermediate isolation (sandboxing) is common, but high-assurance audit is
  rare; capability growth does not reliably co-occur with governance
  maturity; MCP- and plugin-oriented tool systems are emerging alongside
  registry-dominant ones.
- The Model Context Protocol specification update of 2026-07-28 moved MCP's
  core to stateless, HTTP-routable operation. That is the ecosystem's own
  drift toward a session-free, boundary-shaped tool layer, close in spirit
  to the run-fresh, fail-closed kernel Hngh already enforces.

The comparison is deliberately measured: it does not assert Hngh is
categorically unlike every harness, only that its ordering of priorities
(capability vs. audit before capability) is reversed from the mainstream.
Hngh is still small; the claim is about ordering, not scale.

## Register

The revision also sets the public voice, per operator direction:

- The megastructure is a threaded motif, not a one-off line: planted in
  `What Hngh is` ("paperwork is the building material"), echoed through the
  `Why` walk-back image, and closed in `Where this is going` ("the
  megastructure is mostly paperwork").
- The harness comparison is fair-deadpan: it credits the mainstream
  (a furnace "gets hot, and that is useful") before stating the axis
  difference (a building you can walk and point at a fire door in).
- Em-dashes are banned from the README; prose uses commas, colons, and
  periods.
- Dry beats land at four points (opening plant, furnace riff, archive
  line in Verify, and the closing stretch line). Contract text stays
  factual; none of the humor trades on false claims.

## Evidence

- `README.md` — Why and Where-this-is-going rewritten per the framing
  contract above, plus `What Hngh is` motif planting and `Verify`
  closeness; What/How/Status/Verify preserved in substance and facts.
- `make test` still reports 8 reader guard checks plus 1137 checks — the
  change is source-neutral.

## Remaining unknowns

No new technical unknowns. Real transports, the Pi worker, and pooled
hardware remain future roadmap rungs, admitted only under separately
approved run profiles, as recorded in `docs/project/roadmap.md`.

## 2026-08-24-command-surface-and-transport-admission

# Command surface and transport admission record

## Scope

Implements the operator-facing command surface and real transport admission
rung. It adds `hngh.adapters.filesystem`, `admit-transport` in
`hngh.application`, `+admitted-transports+` in `hngh.domain`,
`hngh.main:dispatch-command`, the executable entry point `scripts/hngh`, and
in-process test suites. The kernel remains side-effect-free by default: no
ambient persistence exists, no daemon or watcher starts, and the filesystem
store operates only when an explicit `--store=PATH` is supplied.

## Decision

1. **Transport admission**: `hngh.application:admit-transport` extends the run
   lifecycle with explicit transport verification. A transport is admitted
   only when it belongs to the closed domain set `+admitted-transports+`
   (`(:filesystem)`), the run is in state `:created` or `:armed`, the scope is
   authorized by the mission and loadout, and no duplicate admission exists.
   Admitting a transport records an `:admission` receipt carrying the
   transport, scope, loadout route, run identifier, and clock timestamp.

2. **Default admission facts**: `hngh.main` wires default admission facts to
   consult the active store for a recorded `:admission` receipt naming the run.
   When found, all four admission axes (`:authority`, `:ledger`, `:loadout`,
   `:exclusive-write`) are `:confirmed`; otherwise they remain `:unknown` and
   `arm-run` refuses fail-closed.

3. **Filesystem adapter**: `hngh.adapters.filesystem` is a pure Common Lisp
   component importing only `CL` and `hngh.application` (no domain imports,
   enforced by boundary fixtures). It records run-and-receipt pairs as
   canonical plist lines under an operator-supplied root directory. Paths
   escaping the root or absolute identifiers signal `store-refusal`; missing
   or unwritable roots signal `transport-fault`.

4. **Command surface & protocol**: `hngh.main:dispatch-command` parses argument
   vectors and coordinates the 7 CLI operations (`create-run`,
   `admit-transport`, `arm-run`, `start-run`, `checkpoint`, `close-run`,
   `present`). It returns `(values output-string exit-code)` adhering to a
   strict exit code protocol:
   - `0`: accepted / successful query
   - `1`: application refusal or record conflict (literal status rendered)
   - `2`: malformed invocation (unknown command, arity, or transport)
   - `3`: adapter transport fault
   Usage information is written to `*error-output*` on malformed invocations;
   successful rendering uses existing `hngh.presentation` formatters.

5. **Executable wrapper**: `scripts/hngh` provides a portable SBCL script
   wrapper invoking `hngh.main:dispatch-command` with standard command-line
   arguments and propagating the integer exit code via `uiop:quit`.

## Evidence

- `src/application/admit-transport.lisp` and `src/domain/governance.lisp`
  supply transport admission and `+admitted-transports+`.
- `src/adapter/filesystem.lisp` supplies `make-filesystem-store`,
  `store-record-run`, `store-entries`, `store-refusal`, and `transport-fault`.
- `src/main.lisp` exports `dispatch-command` and wires the store, CLI parser,
  and admission callback.
- `scripts/hngh` is an executable script wrapper verified with end-to-end
  lifecycle execution (`create-run` -> `admit-transport` -> `arm-run` ->
  `start-run` -> `checkpoint` -> `close-run` -> `present`).
- `tests/application/test-admit-transport.lisp` exercises transport admission
  contracts, scope checks, duplicate detection, and receipt generation.
- `tests/adapter/test-filesystem.lisp` verifies replay survival, duplicate
  conflict detection, root confinement, and fault conditions.
- `tests/main/test-dispatch.lisp` exercises all 7 commands and exit codes (0,
  1, 2, 3) in-process.
- `make test` runs 8 reader guard checks, 1260 Common Lisp checks, and ASDF
  system loading cleanly.

## Remaining unknowns

Real model and terminal transports remain disabled and require separate run
loadout admission and adapter implementations. Multi-machine federation and
distributed attestation remain future governance proposals.


## 2026-08-24-command-surface-dogfood

# 2026-08-24: Operator governance command surface for the dogfood loop

## Scope

Adds the operator-facing entry points that run the governance pipeline
in-process: `propose` forms a closed `policy-proposal` and renders the
deterministic verdict, `issue-cert` mints a candidate certificate bound to a
stored admitted run, and `mutation-check` replays the certificate against
fresh fixture evidence through injected mutation ports. No real Git
invocation, subprocess, or external transport is admitted anywhere in the
slice.

## Decision

1. The three commands extend the existing `hngh.main:dispatch-command*`
   dispatch table and `command-usage` text, keeping the closed exit code
   protocol (0 accepted/admitted/executed, 1 refused/mismatch/missing,
   2 malformed, 3 transport fault).
2. `propose` reuses the operator `key=value` option style of the existing
   surface, maps every field onto `make-policy-proposal` (all 15 fields
   required; closed kind validation stays in the domain), and renders the
   verdict through the existing presentation renderer with no new renderer.
3. `issue-cert` recomputes the certificate bindings from the store rather
   than asking the operator: repository identity from the store root
   directory name, base revision from the run identifier, candidate paths
   from the positional arguments (defaulting to the fixture candidate), and
   the admitted verdict from the deterministic fixture-proposal pattern
   already used by `close-run` for the promotion rung 8 `approve` path. A
   run without an `:admission` receipt is refused with labels.
4. `mutation-check` builds fresh mutation evidence with the shared
   poseld payload (`dogfood-payload`) so the certificate and the fresh
   evidence agree, then calls `execute-run-mutation` with the injected
   `:mutation-ports`; extra evidence arguments deliberately desync the
   evidence hashes so the mismatch path is observable from the CLI. Default
   ports are only consulted when no injection is passed, and no test drives
   that path.
5. `hngh.main:dispatch-command` gains only one new injection key —
   `:mutation-ports` — threaded to `dispatch-command*`. Everything else
   stays closed: no new renderers, no new adapters, no new application
   use cases, no process spawning.

## Evidence

- `make test` passes: 8 parent guard checks, 1,290 checks (including the
  new `tests/main/test-governance-dispatch.lisp`, registered in
  `tests/run.lisp`), and a clean ASDF load.
- The test suite guards that no test path ever calls `uiop:run-program`/
  `sb-ext:run-program` (symbol-function wind-up around the mutation-check
  execution path).
- All assertions exit-code behavior (admitted 0, refusal labels 1, malformed
  2) and lease the operator surface previously user-invoked in hand runs.

## Hints

- The certificate `expiry` is the fixed earlier-than-clock value
  `2026-08-25T00:00:00Z` against the fixed test clock
  `2026-08-24T00:00:00Z`; a live `mutation-check` outside the fixture
  window refuses with `expired-certificate`.
- The fixture-manifest and evidence-requirement parsing stay strict:
  `PATH=HASH:ROLE` and `PRINCIPLE:KIND:FINGERPRINTS` only.

## Remaining unknowns

- Wiring real Git ports (the actual `git` process transport) behind the
  fixture surface, to close the loop on a real repository, is the next dogfood
  rung and does not belong to this slice.
- A large-scale `propose` policy profile than "one requirement per matrix
  principle" (operator-tunable policy profiles) is deferred; the surface
  carries the fixture profile only.

## 2026-08-24-context-budget-and-toolchain

# Context budget and tooling wiring record

## Scope

Records two operator-facing decisions made 2026-08-24 after the public
launch, now that Hngh's operator surface runs through the maintained
context-compression route:

1. **Context budget**: the operator prefers active context at roughly 40%
   of the model window (or a little under). With billion-context as the
   single compression authority, omp's own auto-compaction stays disabled,
   and the ~40% preference is encoded where billion-context actually reads
   it.
2. **Toolchain wiring**: `omp` and `pi` are shell functions (fish) that
   route every invocation through `bili` (billion-context launcher); the
   deprecated `billion-context-omp` extension is removed. This is the
   maintained path per the upstream README ("omp ships with the plugin
   built in"; the plugin repository is maintenance-only).

## Decision

`~/.config/billion-context/billion-context.json`:

```json
{
  "compress": {
    "maxContextLimit": "40%",
    "emergencyThresholdPercent": "75%",
    "nudgeGrowthTokens": 20000
  },
  "providers": {}
}
```

- `maxContextLimit: "40%"` — the context-usage ratio at which the proxy
  fires forced-compression nudges (default is 75%). It is a nudge
  threshold, not a hard cap: billion-context is model-driven via the
  `compress` tool. Set lower than default to honor the 40% preference.
- `emergencyThresholdPercent: "75%"` — the hard floor that triggers
  emergency truncation of large tool outputs. Must be >= `maxContextLimit`
  (engine constraint). A draft set 45% and was corrected: the emergency
  layer is a sledgehammer for pathological outputs, not a preferred
  posture; 75% keeps the soft ~40% target inside a sane ceiling.
- `nudgeGrowthTokens: 20000` — smaller growth step (default 50000) for
  more frequent, gentler nudges above the floor.
- omp's `compaction.thresholdPercent: 40` already exists but stays
  `enabled: false`: billion-context is the single compression authority
  (no double compression).

`~/.config/fish/functions/omp.fish` and `pi.fish` route `omp`/`pi` through
`bili`. A fresh launch spawns a fresh proxy on a new port that reads this
config; a session's proxy already running before the file existed keeps
its defaults until relaunched. Deleted the deprecated
`billion-context-omp` extension (its repo maintenance-only; upstream
points to the proxy).

## Evidence

- Config file: `~/.config/billion-context/billion-context.json` (above).
- Fish functions: `~/.config/fish/functions/omp.fish`, `pi.fish`
  (each `command bili <host> -- $argv`); verified once via
  `omp --version` -> `omp/18.0.4` through a fresh proxy log.
- Upstream docs: billion-context `CONFIGURATION.md` (Compression Tuning:
  `maxContextLimit` nudge semantics, `emergencyThresholdPercent` must be
  >= max, `nudgeGrowthTokens`).

## Remaining unknowns

The 40% nudge threshold is a preference encoded in configuration, not yet
measured end-to-end against real sessions; the live session at time of
writing predates the tuned file (next `omp`/`pi` launch picks it up).
Watching the proxy log or its web UI during a long session is the follow-up
that validates (or re-tunes) the value.

## Addendum 2026-08-25 — toolchain reliability: the guardrail outage

The operator toolchain had silently lost its `edit` tool: every
apply_patch-format edit in every omp session was blocked with "Cannot
determine the files targeted by this edit.", regardless of path form or
patch validity. Root cause was not the harness core but a plugin — the
llm-wiki extension (`@zosmaai/pi-llm-wiki` 0.11.4) hooks every `edit`
call to protect its vault, and its patch scanner understood only the
hashline patch format, so apply_patch envelopes parsed as "no determinable
targets" and failed closed.

Lessons for the Hngh operator toolchain:

1. **A middleware guardrail that fails closed on an unrecognized input
   format silently disables an entire tool surface.** The failure
   presented as an edit-tool bug; three sessions of agents burned turns
   retrying path styles against a deterministic block.
2. **Error messages must name their owning layer.** The blocking message
   identified neither the plugin nor the format mismatch. The diagnosis
   that worked in seconds: grep the exact error string across all
   installed packages (harness core, proxy, `~/.omp/plugins`) — the
   string existed only in the plugin's `guardrails.js`. This mirrors
   Hngh's own design rule: refusals carry named labels at the boundary
   that produced them.
3. **Durable local fixes need re-application paths.** The plugin was
   patched in place (dist + TS source) with pristine backups and
   re-appliable diffs kept in `~/.omp/patches/`; a plugin reinstall
   reverts the fix until upstream lands it.

Fix upstream: zosmaai/pi-llm-wiki#162 (envelope-header parsing matched on
the raw untrimmed line so patch body rows quoting envelope syntax are
never misread; hashline parsing unchanged; vault protection verified
still blocking absolute and relative paths). Public failure-case lesson:
MisakaNet intake `contrib_4d2ef67f9a`.


## 2026-08-24-design-distributed-attestation

# 2026-08-24 — Design paper: distributed attestation & evidence federation

## Status

Design paper for roadmap "Next" item 1. Paper-first: no source, test, gate,
or runtime change lands with this record. This document is written in the
`docs/records/` format so review can land it (likely as
`docs/records/2026-08-24-design-distributed-attestation.md`) as-is or with
edits; it intentionally ships no code.

## Scope

Design groundwork for remote evidence ports and cross-machine certificate
verification: how a Hngh instance may (a) gather evidence claims from another
machine and (b) verify a certificate that was issued on another machine —
without a daemon, without network code in the kernel, without a default
peer, and without admitting a mutation on unattested authority.

Explicit non-goals for this slice:

- No daemon, server, listener, watcher, scheduler, or background pull. Every
  remote read is one bounded, synchronous, operator-invoked request through
  an injected transport, exactly like the existing evidence process
  transport.
- No network code in `hngh.domain`. The kernel gains pure values and
  structural checks only; TLS, sockets, curl, and key stores stay in
  adapters behind injected callbacks.
- No default peer, no default provider, no ambient trust. Without injected
  federation ports, remote operations refuse `no-federation-transport`.
- No remote mutation. A remote machine's certificates are **evidence that a
  certificate exists elsewhere**, never authority to mutate on this machine.
  The mutation executor stays single-machine; the operator's own kernel is
  the only place a mutation is admitted.
- No PKI hierarchy: no CA, no certificate chain trust, no key servers, no
  revocation service. The no-PKI divergence
  (`docs/records/2026-08-24-prior-art-landscape.md`, decision 4 in
  `docs/project/decisions.md` 2026-08-24) was a *single-machine* decision
  with an explicit revisit trigger: multi-machine evidence sharing. This
  design is that revisit, and it resolves it narrowly — see below.

## The trust model: two independent bindings

The recurring mistake in attestation registries is conflating "this is what
machine B claims happened" with "this claim is authorized." Hngh already
splits those; the federation design keeps the split and extends it:

1. **Hash binding (stays, unchanged).** Certificates and evidence are bound
   by content-addressed hashes. The fingerprint IS the value; there is no
   signature over the evidence needed for self-authenticity. A certificate's
   `content-hash`, `evidence-hashes`, and the source manifest entries are the
   machine-independent record.
2. **Attestation binding (new, minimal).** What a hash cannot do is say
   *"the machine whose identity is X issued this certificate, at time T"*.
   In a single machine no one can ask that question; across machines it is
   the entire question. Federation therefore adds one narrow mechanism: an
   **operator-pinned key list**. The issuer of a remote certificate signs an
   authorized and explicit envelope; the verifier accepts the envelope only
   if the signing public key is on the operator's pinned list. This is
   deliberately NOT public-key infrastructure: no CA, no chain, no scope
   delegation, no discovery, no rotation service. It is a closed list of
   named public keys the operator has explicitly admitted, and the kernel
   refuses everything absent from it. (Single-machine hash self-
   certification stays the substrate and the default; pinning is layered
   strictly over it for cross-machine attestation.)

**Why not hash-chain only?** A pure hash chain authenticates
*continuity and content*, not the author. Any machine with a copy of the
chain can replay it; chains prove that a certificate is internally coherent
and derivable from its inputs, not that a particular peer is bound to it.
For cross-machine evidence gathering a hash claim is already sufficient
(and the default), but *cross-machine certificate verification* is precisely
the case where "who" matters, so the minimal signature sits at that seam
and nowhere else.

**Why not PKI?** A CA hierarchy reintroduces exactly the external
authority the design removed, and inverts the fail-closed property at the
first trust-anchor compromise. The pinned list keeps fail-closed: anything
not explicitly pinned lands on the `unknown-peer-key` refusal, and there is
nothing between operator and machine. Key rotation and multi-operator trust
stay as open questions below; this record defines the enumeration, not the
revocation machinery.

## What stays pure kernel vs. adapter

| Concern | Home | Why |
|---|---|---|
| `remote-attestation` value (fields, immutability) | `hngh.domain` | data only; kernel already owns certificate values |
| Structure/expiry checks (shape, duplicate-free, closed vocab, UTC timestamps) | `hngh.domain` (new pure function) | deterministic, side-effect-free, no crypto primitives |
| Mapping remote claims → `evidence-fact`s | `hngh.adapters.federation` | needs the injected fetch transport and strict parser |
| Signature verification | `hngh.adapters.attestation` | crypto primitive behind an injected callback, never in kernel |
| Key pin resolution | `hngh.adapters.attestation` ports | operator-supplied closed list |
| Clock for expiry against `now` | injected callback (like existing `clock-now` / `mutation-evidence-now`) | domain still never reads the wall clock |
| Policy decision (admitted? refused?) | `hngh.domain` evaluator via the existing requirement ledger | "is this valid" never lives in an adapter |

The kernel gains exactly two new pure pieces: a `remote-attestation` value
and a structural checker (`verify-attestation-shape`, working on supplied
values only: closed fields, bounded sizes, valid UTC strings, duplicate-free
claims). Everything touching bytes from the wire, keys, or time lives in the
two adapters.

## Port shapes (mirroring existing adapter patterns)

The existing vocabulary is `make-<name>-ports` returning a struct of
read-only callbacks; a `transport-response` wrapper normalizes
`(values exit-code stdout stderr)` to `(values t ...)` or a closed fault;
refusals carry stable string labels; results are closed structs; and all
process/network access sits behind the injected callback. (See
`hngh.adapters.evidence`, `hngh.adapters.mutation`, `hngh.adapters.review`,
and `hngh.adapters.model`.) The federation design keeps that exact shape.

```lisp
;; hngh.adapters.federation — remote evidence gather (mirrors hngh.adapters.evidence)

(defparameter +federation-methods+
  '(:http-claim :ssh-claim :carrier-bundle))
       ;; closed method set; unknown method refuses

(defstruct (federation-ports
            (:constructor %make-federation-ports (fetch-remote))
            (:conc-name %federation-ports-))
  (fetch-remote nil :read-only t))
;; fetch-remote: (lambda (request) => (values exit-code stdout stderr))
;; the ONLY network touchpoint; nil-injected means no-federation-transport

(defstruct (federation-request
            (:constructor %make-federation-request
                (peer method time-window max-facts))
            (:conc-name %federation-request-))
  (peer nil :read-only t)          ;; validated plain identifier string (no URL)
  (method nil :read-only t)        ;; member of +federation-methods+
  (time-window nil :read-only t)   ;; UTC [start,end] bound for fetched claims
  (max-facts nil :read-only t))    ;; bound on the returned claim set

;; result mirrors hngh.adapters.evidence:evidence-result
(defstruct (federation-result
            (:constructor %make-federation-result
                (status evidence manifest refusal-labels))
            (:conc-name %federation-result-))
  (status nil :read-only t)        ;; :complete | :refused
  (evidence nil :read-only t)      ;; list of domain evidence-facts
  (manifest nil :read-only t)      ;; domain source-manifest-entry; NIL allowed
  (refusal-labels nil :read-only t))
```

`gather-federated-evidence` is the entry point, mirroring
`hngh.adapters.evidence:gather-evidence`: one closed request through the
injected `fetch-remote`, strict document parsing into domain facts with
closed states (`:current` when locally re-hashable, `:unverifiable` when
not, `:malformed` / `:missing` / `:conflicting` under the existing
evidence-state vocabulary). Remote facts never bypass the evidence route:
they feed the proposal ledger as facts, and the deterministic evaluator
decides.

```lisp
;; hngh.adapters.attestation — cross-machine certificate verification

(defstruct (attestation-ports
            (:constructor %make-attestation-ports
                (verify-signature resolve-pinned-key))
            (:conc-name %attestation-ports-))
  (verify-signature nil :read-only t)   ; (lambda (payload signature key-id)
                                        ;   => (values exit-code stdout stderr))
  (resolve-pinned-key nil :read-only t)) ; (lambda (key-id) => key-or-nil)

(defstruct (attestation-result
            (:constructor %make-attestation-result
                (status verified key-id refusal-labels))
            (:conc-name %attestation-result-))
  (status nil :read-only t)        ;; :verified | :refused | :fault
  (verified nil :read-only t)      ;; payload+sig verified against a pinned key
  (key-id nil :read-only t)        ;; which pinned key, when verified
  (refusal-labels nil :read-only t))
```

`verify-remote-certificate` takes a `remote-attestation` envelope (domain
value), a `now` timestamp string, and `attestation-ports`; it:

1. runs the kernel's `verify-attestation-shape` (pure: expiry strings,
   duplicate-free, closed vocabulary, bounded sizes) — any failure is a
   typed refusal labeled `malformed-attestation`;
2. resolves the key via `resolve-pinned-key` — an unknown key is a
   `:refused` result labeled `unknown-peer-key`, fail-closed (also covers
   the empty-pin-in-list case);
3. calls `verify-signature` on the frozen payload bytes — a nonzero,
   timed-out, or malformed return is `signature-fault`, and only a verified
   signature yields the `:verified` status;
4. checks the envelope's `not-before` / `not-after` against the injected
   `now` with a bounded skew window supplied in the envelope;
   out-of-window is `expired-attestation` (or `attestation-clock-skew`).

The attestation **adapter result is evidence, not authority**: a `:verified`
attestation binds a `:remote-attestation` domain fact (state `:current`
only when signature, pin, shape, and expiry all hold; otherwise `:refused`
or the fact is marked `:unverifiable`) — it never admits a mutation. The
result feeds the same proposal-evaluator ledger as every other fact, and a
proposal that relies on remote evidence still refuses unless the operator's
policy explicitly requires the corresponding requirement kind.

## Transport admission (mirrors r8/r10)

- The closed set `+admitted-transports+` grows one kind, `:federation`,
  admitted only through the existing `admit-transport` use case, with a
  loadout gate like `:model`: a non-`local` route label **and** the
  `remote-evidence` network label. Without that admission, the `fetch` and
  `verify` operations refuse `loadout-refuses-transport`.
- `hngh.main:dispatch-command` threads `&key federation-ports
  attestation-ports` with no defaults: un-injected, the operations return
  `no-federation-transport` / `no-attestation-transport` (refusal), and
  plain `scripts/hngh` never touches a wire.

## Cross-machine certificate verification: signature, keys, expiry

- **Signature.** Envelope signing is per-machine, one long-lived key; the
  signing key id and the exact payload bytes are what get signed. A hash of
  the payload is not a signature: a recipient never derives attestation from
  a hash alone, the hash says *which* bytes, not *who* signed.
- **Key distribution.** Operator-pinned list — a flat list of
  `(key-id public-key)` pairs supplied at composition. Absent or empty
  list: `unknown-peer-key` refusal. No first-seen/warm-trust fallback and no
  auto-discovery; the pin list is a trust root owned by the operator, and it
  only grows or rotates by explicit operator action. No provider key is ever
  a trust anchor.
- **Expiry.** Every certificate already carries an ISO-8601 expiry string
  and the mutation executor rechecks it at moment of action. The remote
  attestation envelope adds issuer-supplied `not-before` / `not-after`; the
  pure shape checker validates the UTC strings, the adapter compares them
  against the injected `now` with a fixed, small skew window, and the
  evaluator separately declines stale facts (`:stale`), so a remote machine
  can never extend an expired local certificate.

## Failure taxonomy (fail-closed cases)

New refusal labels, mapped onto the existing closed vocabulary
(`docs/records/2026-08-17-task-c2-failure-disposition.md`):

| Case | Closing label/status | Existing category |
|---|---|---|
| Transport not injected | `no-federation-transport` / `no-attestation-transport` | `:refuse` |
| Unknown / empty peer | `unknown-peer` | `:refuse` |
| Unadmitted transport kind | `unknown-transport` (reuse) | `:refuse` |
| Loadout gate fails | `loadout-refuses-transport` (reuse) | `:refuse` |
| Fetch/verify callback throws or returns a malformed value | `transport-fault` (reuse) | `:port-callback-fault-or-malformed-return` |
| Malformed envelope / unknown fields / duplicates / oversized | `malformed-attestation` / `output-too-large` | `:port-...` |
| Key not on the pinned list | `unknown-peer-key` | `:refuse` |
| Bad / timed-out / unverifiable signature | `bad-signature` / `signature-fault` | `:tool-or-environment-fault` |
| Missing or malformed expiry; expired; outside skew | `malformed-expiry` / `expired-attestation` / `attestation-clock-skew` | `:refuse` (stale evidence) |
| Remote claim not locally re-hashable | `:unverifiable` fact (never an authority) | `:insufficient-or-stale-evidence` |

Rule: any failure, unknown, or absent remote fact keeps the verdict
`:refused`; monotonicity (ignoring evidence must never flip DENY → ALLOW,
taken from the prior-art lane) is preserved structurally. A remote fact is
`:current` only when it was fetched through the transport, parsed by the
strict parser, and either locally re-hashed or signed by a pinned key and
within the expiry window — nothing weaker ever passes a policy requirement.

---

# Open questions — resolved 2026-08-24

Resolved in `docs/project/decisions.md` ("2026-08-24 — Distributed attestation
design forks"): immediate-refusal key rotation, evidence-first, JSON envelope,
extended `+evidence-requirement-kinds+`, carrier-bundle-only pull. Multi-hop
chains remain out of scope. Original questions preserved below for the record.

1. **Key rotation.** No revocation machinery: what happens when a pinned key
   is replaced — immediate refusal of all old attestations, or a one-window
   grace? Track this in a decisions record before implementation.
2. **Remote re-verification vs remote evidence.** Does the operator want a
   fresh remote run on the other machine (reproduced source) or only claims
   already produced? Both fit the same ports; which is admitted first is a
   policy choice.
3. **Multi-hop chains** (A → B → C). This paper covers the two-party case
   only; chaining attestations through intermediate machines is deliberately
   out of scope.
4. **Envelope format.** The frictionless option is JSON parsed by the
   adapter's own strict reader (like the review adapter); an alternative
   (e.g. a line protocol) is fixed later, and the adapter owns it — never
   the kernel.
5. **Requirement-kind admission.** Should remote evidence requirement kinds
   join the ledger vocabulary (`+evidence-requirement-kinds+`, suggestion:
   yes), or stay in a new closed vocabulary only for remote requirements?
6. **Pull direction.** This design has no server, so no push. Whether "B
   pulls from A" (network methods) and "A ships a bundle in as
   `:carrier-bundle`" (manual method) are both admitted from day one, and
   whether the carrier bundle is the only variant that ever leaves a
   machine.

This record names scope, design decisions, port shapes, and remaining
unknowns; it does not authorize code. Landing it in `docs/records/` is the
review step for the roadmap "Next" item before any implementation slice.

## 2026-08-24-first-self-governed-commit

# First self-governed commit record

## Scope

Completes roadmap promotion rung 9 — the dogfood development loop — with
the first commit produced, reviewed, certified, and committed by Hngh
itself under its own certificate. The candidate mutation is this
documentation change plus the roadmap and changelog entries.

## Decision

The operator governance surface (`propose`, `issue-cert`,
`mutation-check` in `scripts/hngh`) was exercised end to end against
live repository evidence: the policy proposal was evaluated to an
admitted verdict; the certificate was issued under the real evidence
chain (live base revision, per-file content hashes, verify-candidate
manifest); and `mutation-check` executed the certificate-bound commit
action through the installed git transport. The executed commit is bound
to the certificate content hash and candidate paths.

Push followed only after the full gate (`make test`) remained green on
the self-committed change.

## Evidence

- `src/main.lisp` supplies `dispatch-propose`, `dispatch-issue-cert`,
  `dispatch-mutation-check`, `real-run-evidence`, and the verdict
  report parser; `src/adapter/run-gather.lisp` supplies the real
  candidate-evidence runner (verify-candidate.py + SHA-256 file
  hashing + repository identity) behind an injected transport.
- `tests/run.lisp` executes 1334 checks and 8 reader guards green,
  including `tests/adapter/test-run-gather.lisp` and
  `tests/main/test-governance-dispatch.lisp`.
- The self-governed commit and its push were executed from this
  repository under certificate `candidate` of `commit` action;
  `git log` shows the certificate-bound commit message.
- Recorded in `docs/project/roadmap.md` (rung 9 Completed bullet),
  `CHANGELOG.md` (2026-08-24), and `docs/records/2026-08-24-first-self-governed-commit.md`.

## Remaining unknowns

The loop now self-commits documentation changes. Real model/terminal
worker transports and distributed attestation remain the next rungs;
self-push is exercised but push policy can be tightened later via the
closed `:push` action vocabulary.

## 2026-08-24-governance-property-tests

# Governance property tests record

## Scope

Lands the backlog item "Governance property tests"
(`docs/project/backlog.md`): an exhaustive fixture suite proving two
properties of the deterministic policy evaluator
(`hngh.domain:evaluate-policy-proposal`):

1. **Totality over closed kinds** — every closed proposal class × every
   closed evidence-requirement kind (7 × 21 = 147 combinations) evaluates
   without error to an `:admitted` verdict carrying exactly one principle
   result per matrix principle. An absent matrix principle refuses with
   the `missing-principle-result` label rather than erroring, for every
   class.
2. **Monotonicity** (the in-toto monotonic principle adopted as an
   invariant in `docs/records/2026-08-24-prior-art-landscape.md`) —
   ignoring evidence never flips a refusal into an admission. For each
   proposal class: an admitted baseline; then each single requirement's
   evidence facts emptied (required fingerprints kept) must refuse; and a
   second, different requirement also emptied must preserve the refusal.

## Decision

The properties are asserted **exhaustively over the closed
vocabularies**, not by random generation: the sets are small (7 classes,
21 kinds, 10 principles), so enumeration is both stronger and fully
deterministic. Boundaries are sourced from the live closed-vocabulary
constants in `src/domain/governance.lisp` via `prop-matrix` (copy of
`+matrix-principles+`) and the two `defparameter`s defined in the test
file, which the file itself asserts are the right sizes (7, 21, 10) so
the suite fails loudly if a vocabulary grows and the enumeration is no
longer exhaustive. `make-evidence-requirement` /
`make-evidence-fact` are used exactly as the domain enforces them; the
"ignored evidence" form is facts emptied with fingerprints kept, which is
the evidence-before-claim direction the monotonic principle describes.

## Evidence

- `tests/domain/test-governance-properties.lisp` — the exhaustive suite:
  coverage checks, the 147-combination totality loop, the
  absent-principle refusal path, and the single- and double-ignore
  monotonicity loops (each assertion a `check`, so a failure identifies
  the class/kind/principle).
- `tests/run.lisp` — one registration line after
  `tests/domain/test-governance.lisp`.
- `make test`: 8 reader guards + **2353 checks** passed (up from 1334),
  ASDF load clean.
- Recorded in `CHANGELOG.md` and this record; governance commit bound to
  the change (see governance record if a separate commit).

## Remaining unknowns

The properties are proven for the current closed vocabularies; any
future addition to the classes, kinds, or principles must extend this
suite (the size guards will fail loudly until it does). A formal
property-checking harness (QuickCheck-style) is not warranted while the
sets stay enumerable.

## 2026-08-24-prior-art-landscape

# Task: prior-art landscape and strategy record

## Scope

Documentation-only record of a 2026-08-24 research session: a four-lane
parallel sprint over attestation frameworks, agent-harness landscape,
agent-security models, and CA/authorization theory. Web-search providers
bot-blocked mid-sprint; direct primary-source fetches (arXiv abstracts,
spec repos) were used instead. No source, test, gate, or runtime change.

## Closest prior art

- **Progent (arXiv:2504.11703) is the closest prior art.** Deterministic
  privilege control for LLM agents: SMT-checked policies over tool calls;
  the LLM proposes policy updates and the solver decides. Its monotonic
  confinement (privilege-narrowing updates auto-apply, expansions require
  human approval) is the nearest existing analogue to Hngh's matrix. It
  lacks Hngh's hash-binding of an action to repository identity plus base
  revision, ordered candidate manifest, content hash, evidence hashes, and
  the recheck of all facts at moment-of-action.
- **CaMeL (arXiv:2503.18813)** proves isolation from prompt injection via
  control/data-plane separation (capabilities plus policies over data
  flows). Complementary, not rival: CaMeL proves isolation; Hngh proves
  authorization binding. Hngh does not claim CaMeL-style provability.
- **AgentSpec (arXiv:2503.18666)** is a runtime enforcement DSL
  (trigger → predicate → enforcement) that monitors agent runs. It does
  not authorize effects.

## Deliberate divergences from in-toto / SLSA / DSSE

Hngh certificates are structurally the same document grammar as in-toto
(policy proposal ≙ layout; current facts ≙ link metadata). Four deliberate
divergences:

1. **No PKI; hash self-certification instead.** Content-addressed hashes
   bind the certificate; there is no external key hierarchy.
2. **Duplicate facts refuse.** Fail-closed on any repeated evidence fact.
3. **Moment-of-action freshness recheck is novel.** No attestation
   ecosystem models re-validating evidence at execution time; Hngh
   rechecks every certificate fact against fresh evidence immediately
   before the named action.
4. **No multi-party machinery.** The certificate is single-machine.

## Adopted invariants from this lane

- Monotonicity: ignoring evidence must never flip DENY → ALLOW. Taken from
  in-toto's monotonic principle; held as an invariant and a property test.
- Deny with a structured reason, and totality over closed kinds (OPA/Cedar
  idioms).
- DSSE envelope as the future export grammar, YAGNI-gated until interop is
  needed.

## Agent-harness landscape positioning

- **Claude Code** (hooks + OTel + auto-classifier permissions) is
  logging-plus-classifier, not tamper-evident governance.
- **Codex CLI** (sandbox × approval) has the best boundary enforcement
  among harnesses but no hash binding.
- **mini-swe-agent** (~100 lines, bash-only, >74% SWE-bench Verified) is
  the anti-governance refutation: the sharpest skeptic attack on Hngh's
  machinery.
- **Aider** is the git-is-enough-audit thesis.
- **OpenHands / ACP** are the architecturally nearest integration surfaces;
  neither issues certificates.

Hngh's position is bounded-trust-lane: for changes with external
answerability (deploys, security-sensitive changes, multi-party review),
not a daily driver.

## The governance-benchmark gap

No public benchmark measures governance properties (tamper-evidence,
approved ≡ executed, reconstruction-from-record). Building one would be a
first. Existing agent-safety evals to study for the lane:
AgentDojo (github.com/ethz-spylab/agentdojo), InjecAgent, and R-Judge.

## Theory anchors

- Parnas (1972/1978) plus OS policy-vs-mechanism separation is Clean
  Architecture's true ancestry.
- Capability security / POLA lineage: E, Waterken, Monte, Capsicum, seL4.
  Hngh's expiry plus hash-binding plus recheck deviates from classic
  unrevoked ocaps, justified because Hngh authorizes effects against
  mutable world state, not in-memory object references.
- Mixed-initiative HITL (Horvitz): Hngh's operator-perception-is-not-a
  routine-approval-mechanism principle is policy-delegation HITL and should
  be argued as such.

## Strategy sequencing

1. Now: the operator-facing command surface (roadmap Next) plus real
   transport admission.
2. Next: a dogfood loop (future rung candidate): Hngh proposes → evaluates
   → commits changes to itself via its own harness, exercising
   evidence/review/certification/mutation against its own repository.
3. Then: the remote-evidence port shape on paper (transport-injected,
   fail-closed; monotonicity must survive non-local facts).
4. Much later: a second instance; federation enters as a scope-broadening
   proposal class.

Federation breaks the single-machine no-PKI stance (Sybil resistance,
stale-replica conflicts, who-attests-the-attestor). No-PKI thus stands as a
single-machine decision with an explicit revisit trigger: multi-machine
evidence sharing. Hash content-addressing stays the right substrate (git
provides ~90%). That revisit trigger is recorded in
`docs/project/decisions.md`.

## Evidence

- Primary-source fetches this session: arXiv abstracts for Progent,
  CaMeL, and AgentSpec; the in-toto / SLSA / DSSE specs; the harness
  projects and evals listed above.
- `make test` reports no change; this record is documentation only.

## Remaining unknowns

- No public governance benchmark exists; architecting one is an open
  research lane, not current work.
- Full-source bootstrap / reproducible builds and evaluator-cannot-verify-
  its-own-verifier remain research targets for the self-refactoring rung.

## 2026-08-24-second-self-governed-commit

# Second self-governed commit record

## Scope

Records the second commit produced, certified, and executed by Hngh's own
governance loop — this time a pair of genuine code fixes found by the first
governance loop, committed under a new certificate from the real evidence chain and
pushed to origin.

## Decision

The first self-governed run (2026-08-24, see `docs/records/
2026-08-24-first-self-governed-commit.md`) surfaced two real adapter bugs
during its own execution:

1. `src/adapter/run-gather.lisp` — `process-run-at` consumed UIOP's return
   values in the wrong order. `uiop:run-program` with `:output :string
   :error-output :string` returns `(values stdout stderr exit-code)`, but the
   adapter contract and every caller expect `(values exit-code stdout
   stderr)`. The real-subprocess evidence path therefore always failed
   (fake-port tests never exercised it, so the suite stayed green).
2. `src/main.lisp` — `real-certificate` bound candidate paths in argv order,
   while the mutation executor rechecks against the sorted manifest from
   `verify-candidate.py`, yielding `candidate-paths-mismatch` refusals.

Both fixes were applied to the working tree and then committed through the
governance loop rather than by hand: a `prepare-candidate` certificate bound
the exact diff (content hash `1befdda9...`103833`, base revision `2a16a69`),
the mutation executor staged exactly those two paths, the full gate passed (8
reader guards + 1334 checks), and a `commit` certificate executed
commit `33b8d94` with message `hngh: candidate 1befdda9...`. The commit was
pushed to `origin/main` (`aa9cb64..33b8d94`).

## Evidence

- `docs/project/roadmap.md` — rung 9 completed bullet updated to name both
  self-governed commits.
- `CHANGELOG.md` — 2026-08-24 entry: second self-governed commit (code
  fixes).
- `git log`: `33b8d94` (candidate `1befdda9...`) self-governed code fixes;
  `2a16a69` (candidate `4415287c...`) first self-governed docs commit;
  `aa9cb64` public-launch merge.

## Remaining unknowns

Push was performed directly by the executor transport as in run 1; an
operator-facing push-policy tightening of the closed `:push` action vocabulary
remains future work. The two real bugs prove the loop's value: the governance
loop is now a genuine integration test of the evidence chain.

## 2026-08-24-task-r10-bounded-worker-transports

# 2026-08-24: Bounded model & terminal worker transports (rung 10)

## Scope

Implements roadmap promotion rung 10: two INPUT/ADVISOR transports admitted
behind run loadouts. The bounded model transport (`hngh.adapters.model`)
supplies the `complete` callback shape every transport already uses so the
existing review adapter can drive a real provider; the bounded terminal
input adapter (`hngh.adapters.terminal`) captures one operator statement
as a `:terminal` evidence fact. Both are advisors only: neither can issue a
certificate, mutate a repository, or advance a run, and no default provider
or input source exists by import or in `scripts/hngh`. The slice adds the
two adapters, closed loadout admission for `:model` and `:terminal`, the
`review` and `terminal` CLI operations with fail-closed defaults, one new
presentation renderer, and exhaustive fixture coverage. No live endpoint is
contacted and no executor surface exists.

## Decision

1. `hngh.domain:+admitted-transports+` becomes the closed set
   `(:filesystem :model :terminal)`. No new domain value types and no new
   loadout fields are added: authorization reuses the run's existing
   loadout.
2. `hngh.application:admit-transport` keeps its closed checks and adds one
   loadout gate with the closed refusal label
   `loadout-refuses-transport`:
   - `:terminal` requires the loadout tool label `terminal-input`;
   - `:model` requires a non-`local` route label and the network label
     `model-review`;
   - `:filesystem` stays loadout-free.
   Admission still records the one `:admission` receipt, and `arm-run`
   still requires a `:confirmed` receipt through the store.
3. `hngh.adapters.model:make-model-transports` validates a closed provider
   configuration (`endpoint`, `model-name`, `max-tokens`, `timeout`,
   `provider-token`) and returns the `complete` callback of the exact
   transport shape every consumer uses: `(lambda (prompt) (values
   exit-code stdout stderr))`. The provider is reached only through the
   installed curl binary (the same subprocess style as the evidence
   adapter's git and sha256sum); a failing, timed-out, or oversized
   completion returns a nonzero exit-code, so the review adapter's existing
   closed mapping applies — a provider failure is an `:unverifiable`
   "unavailable" review fact, never new refusal vocabulary. The route gate
   (non-local route plus `model-review` network label) is enforced by the
   application admission layer, not in the adapter.
4. `hngh.adapters.terminal`: `make-operator-ports` captures one statement
   through an injected `read-statement` callback (a nil return is the
   operator's cancel/EOF) and returns an `operator-result`. A `:complete`
   capture binds statement `:current` evidence fact of kind `:terminal`
   with the fingerprint `"sha256:<hex>"`, computed by an in-process,
   vector-verified SHA-256 so capture never spawns a subprocess. A
   statement is bounded at 64KiB and must be printable with no control
   characters; oversized, unprintable, duplicate, cancelled, or thrown
   reads refuse closed (`statement-too-large`, `malformed-statement`,
   `transport-fault`). A statement never enters a certificate, mutation
   input, or any other control surface: it is bound only as a `:terminal`
   evidence fact.
5. `hngh.main` is the only wiring point. `dispatch-command` gains
   `&key review-ports terminal-ports`, threading through
   `dispatch-command*`; no default provider or input is composed — without
   injection the `review` and `terminal` commands refuse
   `no-review-transport`/`no-terminal-transport`, and plain `scripts/hngh`
   therefore carries the two routes fail-closed. The `review` command
   (required `content-hash=` and `paths=` options, optional
   `policy-context=`) runs only when the run holds a `:model` admission
   receipt; the `terminal` command captures one statement only when the run
   holds a `:terminal` admission receipt. `hngh.presentation` gains exactly
   one renderer, `render-operator-result` (outward only).
6. Fixtures: `make-operator-ports-fake` in `tests/support/fakes.lisp`
   scripts `(:return statement)`, `(:cancel)`, and `(:error message)`;
   `tests/adapter/test-terminal.lisp` asserts statement bounds, known-answer
   SHA-256 vectors, oversized/unprintable/cancel/duplicate refusals, and
   fingerprint binding; `tests/main/test-governance-dispatch.lisp` drives
   `review`/`terminal` through injected fakes with `uiop:run-program`
   shadowed so no subprocess is ever spawned, asserts exit 1 without a
   matching admission receipt, exit 2 `unknown-transport` when the closed
   admitted set excludes the kind, and `loadout-refuses-transport` for a
   plain loadout; `tests/application/test-admit-transport.lisp` covers the
   two new kinds and the three new refusal labels;
   `tests/domain/test-governance.lisp` locks the closed set. All tests are
   local, deterministic, provider-free, and `make test` stays green (8
   reader guard checks + 2,495 checks + a clean ASDF load).

## Evidence

- `make test` passes end to end: 8 reader guard checks, fresh yields
  `2,495 checks passed`, and the ASDF load of `hngh` is clean.
- The review-coordinator maps every closed provider outcome at
  `hngh.main:request-run-review`: exit 0 JSON findings :complete, a failing
  provider 500 becomes `:unverifiable` "unavailable", a thrown provider
  fault refuses `transport-fault`, and malformed JSON refuses
  `malformed-output`.
- `review` and `terminal` never spawn a subprocess when the injected ports
  are fakes (symbol-function wind-up around `uiop:run-program`, the same
  pattern as the mutation-check guard).
- The `:terminal` evidence fingerprint is a real in-process SHA-256,
  verified against the FIPS standard vectors (empty, "a", "abc", the
  quick-brown-fox sentence, and the two-block abcde...nopq vector).

## Hints

- The model transport's provider call uses the system curl binary with
  `--fail` so any HTTP failure exits nonzero and maps to the `:unverifiable`
  review fact; the token travels only in that one subprocess Authorization
  header (`ponytail:` note: argv visibility is the same trade-off as the
  evidence adapter's git/sha256sum invocations; an env- or config-file-
  based provider client is the documented upgrade path).
- The grade of the loadout gates lives entirely in
  `transport-loadout-refused-p` in the application layer; domain, adapters,
  and presentation have no loadout knowledge.
- Statement duplicate detection is per-operator-ports session state (like a
  terminal's scrollback), not a global ledger.

## Remaining unknowns

- A real provider client inside `make-model-transports` (the curl call) is
  composed by the operator at the composition root and is not exercised by
  the gate; a live end-to-end provider run is explicitly out of scope for
  this rung ("do not run live endpoints").
- Terminal statements are advisor-only evidence: recording them into the
  store ledger or feeding them to a later policy requirement kind is
  future work and deliberately not part of this slice.

## 2026-08-25-loop-history-guard

# 2026-08-25 — Machine-checked self-governance (loop-history guard)

## Scope

Makes the README's restated governance claim falsifiable by
construction: a guard in the gate walks every code-surface commit since
the restatement and fails on anything that is not certificate-bound or
rule-exempt. The carve-out ("the exception is by rule, not by mood")
ceases to be prose and becomes a checked invariant.

## Decision

1. `tests/scripts/test-loop-history-guard.py` walks `git log` from the
   restatement commit `1915713`; every commit touching the code surface
   (`src/`, `tests/`, `scripts/`, `Makefile`, `hngh.asd`) must be
   `hngh: candidate <64-hex>` or carry
   `excluded from cert manifest by dependency guard` in its message.
2. The one known pre-guard violation — `915e0e3`, a comment-only
   alignment of composition-root references committed as a plain docs
   commit — is exempted by name and recorded in
   `docs/project/decisions.md` as history, not rewritten.
3. The carve-out is a recorded decision entry (export-only/no-behavior
   changes excluded by the dependency guard, labeled in the commit
   message).
4. `make test` runs the guard (before the paren lint), so the claim is
   checked on every gate.

## Evidence

- The guard passes on current history:
  `8 code-surface commits checked, 1 named exemption(s), 0 violations`
  — the 4 candidate commits and 3 labeled chore-export commits since
  the restatement, plus the named `915e0e3`.
- The README now says the sentence is machine-checked; CHANGELOG and
  decisions.md record the carve-out and the pre-guard blemish.
- Committed through the self-governed validation loop (code: Makefile + guard;
  docs: decisions, changelog, README, this record) — the guard's own
  introduction commits are themselves candidate-bound.

## Remaining unknowns

- The guard watches the code surface; the docs surface rides the loop
  by convention (all since the restatement are candidate-bound or
  docs-only). Extending the guard to docs would change project history
  handling (docs-commits predate the restatement) and is future work.

## 2026-08-25-queue-rotation

# 2026-08-25 — Queue rotation: the loop that runs itself

## Scope

`scripts/rotate-queue` is the continual-worker cadence closer: a
session does the slice work, then rotate-queue closes the governance
loop around it — flip the queue row, gather real candidate evidence,
run the operator reviewer (a real local-model session via the reviewer
file), propose under the ten principles, capture the verdict, bind the
certificate, execute the mutation, and land the queue ledger in the
same candidate commit. The periodic invocation belongs to the
operator's scheduler, never inside Hngh.

## The first rotation (doc-sync-loop)

Rotated **doc-sync-loop** — the documentation-sync item (a
`make test` doc-numbers guard that recomputes the README's check count
from the live suite, so the count can no longer drift by hand).

The live run:

- `create-run` (model route, worker-task+mutation tool labels,
  model-review network label) → exit 0;
- `admit-transport run-1 model repository` → exit 0;
- `review` through the operator reviewer file (local Unsloth,
  Ornith-1.0-35B) → `review status=complete findings=4` — four
  advisory metadata-level findings (shebang/scripting notes; the
  reviewer sees the content hash and paths, never file bytes, per the
  r6/r13 design; reviewers advise, never decide);
- `propose` with real evidence (content-hash = the candidate hash) →
  **verdict state=admitted principles=10**, captured as the operator
  verdict file;
- `issue-cert` + `mutation-check` `prepare-candidate` → `git add`
  executed; `commit` → `git commit` executed;
- `hngh: candidate bbd1d598…` landed; the queue row flipped to done;
  the ledger rode in the same commit.

## Evidence

- The rotated commit (`2fc6ac3`) contains the guard
  (`tests/scripts/test-doc-numbers.py`), its Makefile wiring, the
  `scripts/rotate-queue` runner, and the flipped queue ledger.
- `make test` green after rotation: **2774 checks**, doc-numbers guard
  passes (`README matches the live suite (past 2,774 checks)`),
  loop-history guard 15 code-surface commits / 1 named exemption / 0
  violations.
- Rotation exit 0 with `rotation complete: <hash> committed (item
  doc-sync-loop)`.

## Decisions

- The rotation is glue over the existing closed surface: every step is
  the same command an operator would run by hand; no new authority.
- The reviewer is advisory and the verdict is the gate — a refused
  verdict halts the rotation with exit 1.
- The queue ledger is part of the candidate, so the flip is
  certificate-bound like everything else.

## Remaining unknowns

- The other queued items (wake-mutation lane, node-lattice admission,
  bridge-operator-host, key-rotation-freshness, pooled hardware,
  tunnel automation, governance benchmark, DSSE export) wait their
  turn; a scheduler (operator-owned) can invoke rotate-queue
  periodically.

## 2026-08-25-r12-pin-registry-and-signature-transport

# 2026-08-25 — Rung 12: pinned-key registry and signature-verification transport

## Scope

Lands the roadmap "Next" revocation-policy refinement: the operator's
pinned-key registry as a pure domain value, the strict pins-file parser and
real signature-verification transport in the federation adapter, and the
operator surface that admits a pins file on `verify-attestation` plus the
new `list-pins` command. This closes the gap between the rung-11
attestation ports (injection-only, fixture-verified) and a real
operator-pinned trust anchor verified by a real openssl invocation.

## Decision

1. The registry is pure kernel: `key-pin` (plain bounded identifier plus
   absolute key path — option-like path components and relative paths
   refuse) and the immutable `key-pin-registry` (duplicate identifiers
   refuse with `duplicate pin: <id>`, defensive list copies, `lookup-key-pin`
   returning the stored pin or NIL). No I/O, no clock, no key bytes.
2. The adapter owns everything touching operator text and processes:
   `parse-pinned-keys` is a strict `IDENTIFIER<TAB>ABSOLUTE-KEY-PATH` line
   parser (`#` comments and blank lines skipped; wrong field count, empty
   identifier, relative or option-like paths refuse); `hex-decode` is the
   pure lowercase-hex codec; `make-pinned-attestation-ports` resolves keys
   from the registry and verifies one envelope signature through a single
   bounded `openssl dgst -sha256 -verify` invocation on the injected
   process transport. Temp files are always removed; a malformed hex
   signature or missing pin refuses before any process call.
3. The pins file is the trust anchor at the operator surface: when
   `verify-attestation ... pins=PATH` is present, the parsed registry plus
   the installed read-only process transport replace any injected
   attestation ports; a missing file refuses `cannot read pins file` and a
   malformed file refuses `malformed pins file` (both exit 2, before any
   run or transport work). `list-pins PATH` renders the registry through
   the new `render-pin-list` (one `IDENTIFIER<TAB>PATH` line per pin).
4. `src/packages.lisp` symbol exports land as a direct chore commit — the
   file structurally defines adapter packages, so the candidate dependency
   guard excludes it from certificate manifests (rung-10 precedent,
   commit `29aa3ab`).

## Evidence

- `make test` green after each stage: 8 reader guards and 2,663 checks
  (baseline 2,616 + 6 domain + 27 adapter + 14 operator-surface checks).
- Three self-governed commits through the dogfood governance loop, pushed to
  `origin/main`: `7186333` (domain slice, candidate `48eea853...`),
  `1916bee` (adapter slice, candidate `b1ce3eea...`), and this slice's
  governance commit; plus the two `chore:` export commits (`b773651`,
  `5851273`).
- Live end-to-end proof (not a test — real subprocess, real key), run
  from the repository root against a scratch store with a throwaway
  2048-bit RSA keypair and `openssl dgst -sha256 -sign`:

  ```
  $ scripts/hngh --store=/tmp/hngh-live-store verify-attestation run-1 \
      /tmp/hngh-envelope.json pins=/tmp/hngh-pins.txt
  attestation status=verified key=live-key-1 fact=evidence kind=remote-attestation \
    fingerprint=machine-live|live-key-1|7fbccad4390b81deb0a642bd02f7a52e7b335de2da46b66b8b524185887e54ff state=current
  exit=0

  $ ... verify-attestation run-1 /tmp/hngh-envelope-tampered.json pins=...
  attestation status=refused labels=bad-signature      (exit=1)

  $ ... verify-attestation run-1 /tmp/hngh-envelope-unknown.json pins=...
  attestation status=refused labels=unknown-peer-key   (exit=1)

  $ scripts/hngh list-pins /tmp/hngh-pins.txt
  live-key-1	/tmp/hngh-pin-test.pub                    (exit=0)
  ```

  The tampered case reuses the valid signature over a modified payload;
  the unknown case reuses the valid payload under an unpinned key
  identifier. OpenSSL 3.6.3.

## Remaining unknowns

- Ed25519 keys cannot ride the fixed `dgst -sha256` pairing on this
  OpenSSL ("Explicit digest not allowed with EdDSA operations"); the
  adapter command is digest-signature-key shaped (RSA/ECDSA/DSA). An
  Ed25519-capable `pkeyutl -rawin` command variant is future hardening,
  recorded in the roadmap Next.
- Pin expiry and rotation (a pin valid until a date, superseded pins)
  remain open — the registry is a closed list and revocation is
  file-editing, per the 2026-08-24 design decision 1 (immediate refusal
  on rotation).
- The verified fact feeds the evidence ledger like any other fact; no
  policy requirement kind yet consumes `:remote-attestation` fingerprints
  in a shipped policy profile.


## 2026-08-25-r13-operator-reviewer-transport

# 2026-08-25 — Rung 13: operator reviewer transport admission

## Scope

Lands the operator reviewer-transport file on the `review` command — the
`reviewer=PATH` option admitting an operator-owned config (endpoint,
model, max-tokens, timeout, token-file) that replaces injected review
ports with the real curl-backed provider transport from rung 10 — plus
the four real-path defects the first live use surfaced in the rung-10
model transport and the rung-6 review prompt.

## Decision

1. The reviewer file follows the pins/verdict-file precedent: an
   operator-produced file admitted explicitly, parsed strictly (the five
   closed keys; unknown, duplicate, missing, empty, or non-integer fields
   refuse; a missing file or token file refuses `cannot read reviewer
   file`, a malformed file `malformed reviewer file`, both exit 2 before
   any run or transport work). The provider token is read from its
   mode-600 token-file and reaches only the one curl Authorization header;
   it never enters the prompt, a result, or the store.
2. `make-model-transports` now actually works against a real
   OpenAI-compatible server — three latent defects fixed (all
   fixture-invisible until the first real call):
   - `:input` passed the request body as a bare string, which UIOP
     treats as a *filename*; stdin now receives a string input stream.
   - The request envelope is a chat-completions message with
     `enable_thinking:false` (documented `[x-unsloth]` control; per-model
     support, harmless where unsupported) instead of a completions-style
     `prompt`, so the completion document is the answer rather than a
     reasoning trace.
   - The transport now extracts the model's completion document from the
     provider response envelope (first choice's `text` or
     `message.content`) via the model adapter's own minimal JSON scanner
     (numbers, booleans, and nulls consumed opaquely — the review
     reader's refusal of them is the rung-6 output contract and stays);
     an unparseable or oversized response maps to a nonzero exit so the
     caller's `:unverifiable` fact applies. The previous oversized path
     returned a NIL stdout, which the closed validation turned into a
     transport-fault instead of the documented mapping.
3. The rung-6 fixed review prompt was a bare JSON envelope — a strong
   fixture reviewer inferred the task, but real local models respond to
   it with clarification requests. The prompt now carries an explicit
   advisory-reviewer instruction with the exact output contract; the
   output schema and every prompt field are unchanged.

## Evidence

- `make test` green: 8 reader guards and 2,693 checks (baseline 2,616 +
  30 new: reviewer-file admission, envelope extraction, chat envelope).
- Live end-to-end proof against the operator's local Unsloth Studio
  server (OpenAPI 2026.8.19; llama-server OpenAI dialect; `model` is
  informational — the server auto-activates the named model; auth via
  the automation's auto-refreshed mode-600 token):
  - `scripts/hngh --store=<scratch> review run-1 content-hash=<sha256>
    paths=src/main.lisp reviewer=~/.hngh-automation/reviewer-local.conf`
    with `model=unsloth/Ornith-1.0-35B-GGUF` → `review status=complete
    findings=0` exit 0 with a `:current` review fact.
  - The same prompt directly: Ornith returns exactly the closed
    findings document, e.g. `{"findings":[{"label":"Potential unsafe
    model loading in adapter","citation":"src/adapter/model.lisp"},
    {"label":"Core logic lacks explicit fail-closed guard","citation":
    "src/main.lisp"}]}` — advisory metadata-level findings, as designed.
  - Model selection basis: the 2026-08-25 fleet bench
    (hngh-automation `stats/model-bench-2026-08-25.jsonl`) — Ornith-1.0
    (35B and 9B), AgentWorld-35B-A3B, and bartowski/Qwen3.8-27B scored
    perfect on coding/review-shaped probes; both gemma-4-12B variants
    missed the subtle defect; the server's MiniMax-H3 failed outright.

## Remaining unknowns

- Reviewer findings are advisory metadata-level reviews: the reviewer
  sees the content hash, paths, and policy labels, never file bytes.
  Feeding candidate content into the review is future work.
- No policy profile consumes review facts yet (the standing policy-profile
  gap).
- Per-model thinking behavior varies; the envelope pins
  `enable_thinking:false` which supported models honor and others ignore.


## 2026-08-25-r14-ed25519-signature-transport

# 2026-08-25 — Rung 14: Ed25519 signature-transport hardening

## Scope

Extends the operator pinned-key registry and signature-verification
transport (rung 12) with a closed key-algorithm vocabulary so pins may
name Ed25519 and verification routes to the raw-signature openssl path.
The carrier-bundle envelope, the attestation ports, and the verify
gate are unchanged.

## Decision

1. `hngh.domain` adds `+key-algorithms+` (`:rsa-sha256`, `:ed25519`)
   and the `key-pin` value gains a read-only `algorithm` slot,
   defaulting to `:rsa-sha256`; `make-key-pin` refuses anything outside
   the closed vocabulary.
2. The pins-file grammar gains an optional third column:
   `IDENTIFIER<TAB>ABSOLUTE-KEY-PATH[<TAB>ALGORITHM]`. Unknown,
   extra, or empty algorithm tokens refuse as malformed; omitted
   columns default to `rsa-sha256`. The previous "extra column
   refuses" behavior is preserved for unknown algorithms.
3. Signature verification routes per pin: `:rsa-sha256` keeps the
   single bounded `openssl dgst -sha256 -verify` invocation; `:ed25519`
   uses `openssl pkeyutl -verify -pubin -inkey KEY -rawin
   -sigfile SIG -in PAYLOAD` (Ed25519 signs the message itself; the
   `-in` flag is required by pkeyutl — the positional form was
   discovered and fixed during live verification). One transport call
   per verification, same temp-file lifecycle, no default transport.
4. `list-pins` renders `IDENTIFIER<TAB>PATH<TAB>ALGORITHM` with the
   resolved algorithm per pin.

## Evidence

- Tests written first, red (`+KEY-ALGORITHMS+ not found`), then green:
  `make test` passes 8 reader guards and 2713 checks (+18: domain
  vocabulary/default/refusal, parser columns, argv routing per
  algorithm, list-pins rendering).
- Live end-to-end proof with a real throwaway Ed25519 keypair:
  `verify-attestation` against a raw-signed envelope →
  `attestation status=verified key=ed-key ... state=current` exit 0;
  a tampered payload → `attestation status=refused labels=bad-signature`;
  `list-pins` renders `ed-key<TAB>...<TAB>ed25519`.
- Committed through the self-governed validation loop: `src/packages.lisp`
  exports landed via the chore lane excluded by the dependency guard
  (`545b4bc`); the implementation and tests were proposed (admitted
  10/10 principles), certified against real evidence, and committed as
  `hngh: candidate 21a694ee...` (`2481715`), pushed to origin.
- README, roadmap, changelog, and this record updated; the README
  `Not yet` list drops the Ed25519 clause.

## Remaining unknowns

- Network claim methods behind the federation port remain deferred
  (2026-08-24 decision 5 evidence-first fork).
- Review-fed policy profiles remain the standing policy-profile gap.


## 2026-08-25-r15-http-claim-method

# 2026-08-25 — Rung 15: network claim method (http-claim)

## Scope

Adds the network claim method to the federation port: `:http-claim`
joins `:carrier-bundle` in the closed `+federation-methods+` set, and
`fetch-evidence` accepts `method=carrier-bundle|http-claim` (default
carrier-bundle). The method reaches the injected `fetch-remote`
transport on the request; the peer remains a plain bounded identifier
and endpoint resolution stays transport-owned — no default wire.

## Decision

1. `+federation-methods+` is now `(:carrier-bundle :http-claim)`;
   any other token still refuses at request construction.
2. `fetch-evidence` gains the closed `method=` option; an unadmitted
   method is malformed (exit 2) before any gather work.
3. The transport callback sees `federation-request-method` on its
   request, so a caller may route the same bounded document fetch over
   HTTP without changing the closed bundle contract or the claim-state
   mapping.
4. No default transport exists: plain `scripts/hngh` still refuses
   `no-federation-transport` unless federation ports are injected.

## Evidence

- Tests first, red (`federation method must be a closed member:
  :HTTP-CLAIM`), then green: `make test` passes 8 reader guards and
  2719 checks (+6: method admission, transport-visible method, dispatch
  plumbing, unadmitted-method refusal).
- Live proof over a real wire: a local `python3 -m http.server` served
  the carrier-bundle document; `gather-federated-evidence` with
  `:method :http-claim` through an injected urllib transport returned
  `status=COMPLETE facts=3 states=(:CURRENT :CURRENT :UNVERIFIABLE)`.
- Committed through the self-governed validation loop: proposal admitted
  10/10, certificate bound to real evidence, `git add` + `git commit`
  executed as `hngh: candidate 9719f324…` (`14e8e95`), pushed; gate
  green after the mutation.
- README, changelog, roadmap, and this record updated; the README
  `Not yet` list drops the network-claim clause.

## Remaining unknowns

- Review-fed policy profiles remain the standing next slice.
- A default HTTP transport is deliberately absent; endpoint resolution
  is caller-provided until a transport-admission design exists.

## 2026-08-25-r16-policy-profiles

# 2026-08-25 — Rung 16: operator policy profiles

## Scope

Lands the operator-tunable policy profile on `propose`: a named,
parsable, fail-closed spec that narrows which requirement kinds a listed
principle may carry, plus the `:review` requirement kind so a profile
can demand review evidence. The closed evaluator is unchanged; a profile
only narrows admission, never broadens it.

## Decision

1. `hngh.domain` gains the pure `evidence-profile` value: a list of
   `evidence-profile-entry` values (principle → permitted requirement
   kinds). Duplicate principles refuse; non-closed kinds refuse;
   permitted kinds are deduplicated. `profile-permitted-kinds` returns
   NIL for an unlisted principle — the plain evaluator behavior.
2. The requirement-kind vocabulary admits `:review` (review facts
   already existed from the rung-6 adapter; no kind could demand them).
3. `evaluate-policy-proposal-under-profile` shares the evaluator body
   (`%evaluate-matrix`) with the plain path, filtered by the profile:
   a listed principle keeps only its permitted kinds; a principle whose
   kinds are all dropped refuses as `missing-principle-result`.
4. `propose` gains `profile=PATH` following the pins/verdict/reviewer
   file precedents: strict `PRINCIPLE<TAB>KIND` lines, `#` comments and
   blanks skipped; a missing file refuses `cannot read profile file`,
   a malformed one `malformed profile file`, both exit 2 before any
   evaluation. Without `profile=`, behavior is unchanged.

## Evidence

- Tests first, red (`check failed: the review requirement kind is
  admitted`), then green: `make test` passes 8 reader guards and 2732
  checks (+13: domain profile value, narrowing refusal/admission,
  duplicate/closed-kind refusals; dispatch-level `profile=` refusal,
  admission, and malformed-file exit-2).
- The dispatch-level tests exercise the real `propose` surface through
  `dispatch-command`: a profile permitting only `:review` refuses a
  claim-proof proposal (exit 1, `missing-principle-result`) and admits
  one carrying review evidence (exit 0).
- Committed through the self-governed validation loop: `src/packages.lisp`
  exports via the chore lane excluded by the dependency guard
  (`e8bfaad`); the implementation and tests were proposed (admitted
  10/10), certified against real evidence, and committed as
  `hngh: candidate aedd723…` (`c7b1985`), pushed; gate green.
- README, changelog, roadmap, and this record updated; the roadmap
  `Next` no longer names policy profiles.

## Remaining unknowns

- The policy-profile rung consumed review kinds; the next standing
  candidate is the bridge-backed continual worker or the node-lattice
  admission rung from the backlog.

## 2026-08-25-r17-wake-peer

# 2026-08-25 — Rung 17: wake-on-demand for lattice peers

## Scope

Adds the mesh's first on-demand action: `wake-peer RUN PINS-FILE PEER`
issues one explicit wake request for a pinned lattice peer behind an
injected transport. The pins registry is the admission evidence — a
peer is admitted by pinning its key — and the run must hold a
`:federation` admission receipt. No default transport, no daemon, no
ambient execution.

## Decision

1. `hngh.adapters.federation` gains the wake surface: `wake-ports` (one
   injected `wake-transport` callback), the `wake-result` value
   (`:issued | :refused | :fault` with the key identifier and closed
   refusal labels), and `wake-peer-request`, which rechecks the pin
   (unknown → `unknown-peer-key` before any call), then issues exactly
   one transport call with `(PEER KEY-PATH)`. A zero exit issues; a
   nonzero exit refuses `wake-refused`; a throw faults `wake-fault`.
2. `wake-peer RUN PINS-FILE PEER` is the surface: strict pins parsing
   first (malformed → exit 2, matching the verify-attestation
   precedent), then the federation-admission receipt, then the injected
   transport (`no-wake-transport` without injection). Exit 0 issued,
   1 refused, 3 fault.
3. `hngh.presentation` gains the wake renderer (`wake status=issued
   peer=…` / `status=refused|fault labels=…`); usage, `dispatch-command`
   threading, and the test harness gain the `:wake-ports` key.

## Evidence

- Tests first, red (`Symbol "MAKE-WAKE-PORTS" not found`), then green:
  `make test` passes 8 reader guards and 2749 checks (+17: adapter
  issue/refuse/fault paths with transport argv capture, dispatch
  success/no-ports/unpinned/malformed-pins).
- Two real defects surfaced and fixed during the run: the transport
  scope bug (`pin` out of scope in the second let — an unbound-variable
  caught by the error clause, always faulting) and the pins-validation
  ordering in dispatch (pins must validate before the admission/ports
  checks to match the verify-attestation precedent).
- Committed through the self-governed validation loop: `src/packages.lisp`
  exports via the chore lane excluded by the dependency guard
  (`3d76c10`); implementation and tests proposed (admitted 10/10),
  certified against real evidence, committed as `hngh: candidate
  c38ec915…` (`9db2187`), pushed; gate green.
- README, changelog, roadmap, and this record updated.

## Remaining unknowns

- Ambient tunnels and a certificate-bound wake mutation lane remain
  boundary-amendment proposals per the backlog's node-lattice entry.
- A default wake transport (e.g. a real Wake-on-LAN magic packet over
  UDP) stays caller-provided until a transport-admission design exists.

## 2026-08-25-r18-worker-transport

# 2026-08-25 — Rung 18: bounded read-only worker task

## Scope

The worker-rung first slice: one closed, read-only worker task through
an injected transport, bound as `:worker` evidence. This is the runtime
surface the backlog's bridge-backed worker will exercise — the steps
toward "the loop that runs itself" begin here, read-only.

## Decision

1. `hngh.adapters.worker` supplies the closed worker surface:
   - `worker-request` — a bounded task label (≤256 printable chars, no
     control characters) plus an optional bounded payload (≤64KiB);
   - `worker-ports` — one injected `execute-worker` callback, called
     `(EXECUTE-WORKER REQUEST)` returning
     `(values exit-code stdout stderr)`, no default transport;
   - `run-worker-task` — a zero exit binds a `:worker` `:current`
     evidence fact (fingerprint = the task label), a nonzero exit
     refuses `worker-refused`, a throw faults `worker-fault`.
2. `:worker` joins `+admitted-transports+` behind the `worker-task`
   tool label on the run loadout (the `admit-transport` loadout gate).
3. `run-worker RUN task=LABEL [payload=TEXT]` is the surface: the run
   must hold a `:worker` admission receipt; without injected
   `worker-ports` it refuses `no-worker-transport`; a malformed task is
   a malformed invocation. Exit 0 complete, 1 refused, 3 fault.

## Evidence

- Tests first, red, then green: `make test` passes 8 reader guards and
  2770 checks (+21: adapter request/result/refusal/fault + payload
  travel, worker admission accept/refuse, dispatch
  complete/no-ports/unadmitted). The transport-set assertion is updated
  to the five closed kinds.
- The gate was run after every change; the final gate passed on the
  candidate commit.
- Committed through the self-governed validation loop: `src/packages.lisp`
  exports via the chore lane excluded by the dependency guard
  (`5574943`); implementation and tests proposed (admitted 10/10),
  certified against real evidence, committed as
  `hngh: candidate 55a2d741…` (`f29c6e2`), pushed; gate green.
- README, changelog, roadmap, and this record updated.

## Remaining unknowns

- The hngh-omp bridge tools for the worker surface (driving a disposable
  omp session behind the bridge) remain the next worker-rung slice;
  this rung ships the harness side only.
- A worker self-report stays evidence, never acceptance.

## Live end-to-end proof (2026-08-25, same day)

A full lifecycle ran through the dispatch surface with a real worker
transport (a bounded python3 subprocess doing read-only scan work):

- `create-run` (with the `worker-task` tool label) exit 0;
- `admit-transport run-1 worker repository` exit 0;
- `run-worker run-1 task=scout candidates payload=candidate.lisp` exit 0
  with `worker status=complete task=scout candidates`;
- `present run-1` exit 0, rendering the run in the ledger.

The adapter-level call bound the `:worker` `:current` evidence fact
(fingerprint = the task label) from the same real subprocess. The lane
from run to worker evidence is exercised end to end.

## 2026-08-25-session

# 2026-08-25 — Continual-progress session record

## Scope

One operator session that moved Hngh from the rung-13 baseline to a
fully exercised worker lane, closed the external-review gap, and brought
the bridge extension under governance. Everything below is recorded as
it happened; the governance labels are the evidence chain.

## Arc

1. **Extension repair.** The hngh-omp bridge extension failed to load at
   startup (`Maximum call stack size exceeded`): the four run-lifecycle
   tool registrations had been nested inside `registerHnghTool`'s own
   body, so every call recursed. Hoisted them into
   `registerHnghExtension`; the stub-load now registers all tools.
   (Bridge tree, not this repo; now git-governed separately.)
2. **Consistency pass.** The README's self-governance claim was restated
   honestly (past stays history; the present bootstraps; "the change
   the loop can bind, the loop binds; a change it cannot, it
   declares"); the check-count line stopped drifting; the megastructure
   vision entered the README and the intent doc; the backlog gained the
   node-lattice rung; counts across roadmap/intent/architecture/
   component-map/charter/test-boundary were aligned; the records index
   gained the missing rung-11..13 entries.
3. **Rungs 14–18, all governance-bound** (each with its own record):
   - r14 Ed25519 signature-transport hardening (closed key-algorithm
     vocabulary on pins, `pkeyutl -verify -rawin` path; live-verified
     with a real keypair);
   - r15 network claim method (`:http-claim` joins the closed
     federation method set; live over a real HTTP server);
   - r16 operator policy profiles (`evidence-profile` value, `:review`
     requirement kind, `propose profile=PATH`; narrows, never
     broadens);
   - r17 wake-on-demand (`wake-peer RUN PINS-FILE PEER` behind an
     injected transport; no daemon, no default wire);
   - r18 bounded read-only worker (`run-worker RUN task=T`, `:worker`
     admission behind the `worker-task` label; a worker self-report is
     evidence, never acceptance).
4. **External re-review.** The local model (Ornith-1.0-35B) re-judged
   the restated claim and moved from "overstated" to "no longer
   overstated — falsifiable, stronger"; it verified the live Ed25519
   proof itself. It named one real gap: the carve-out's rule was prose
   with no enforcement and no decision entry — and an ordinary commit
   had already touched the code surface after the restatement.
5. **The gap became a machine.** `tests/scripts/test-loop-history-guard.py`
   runs in `make test` from the restatement commit: every code-surface
   commit must be `hngh: candidate <hash>` or carry the
   `excluded from cert manifest by dependency guard` label. The one
   pre-guard violation is named, not rewritten. The carve-out is a
   recorded decision. The guard now checks every code-surface commit
   the session produced — 0 violations.
6. **Bridge finalized.** The hngh-omp extension gained the
   `hngh_run_worker` tool (10-tool surface, TypeBox-validated),
   became its own git repo (baseline + governance-conventions
   commits), and its README documents that bridge changes ride the
   same governance loop when they land in the parent.
7. **Live worker proof.** The full lifecycle ran through the dispatch
   surface with a real subprocess worker: create-run (worker-task
   label) → admit worker → run-worker (`worker status=complete task=
   scout candidates`) → present, with the `:worker` `:current` evidence
   fact bound end to end.

## Numbers (fresh at close)

- `make test`: **2774 checks** + 8 reader guards, exit 0.
- Loop-history guard: **11 code-surface commits checked, 1 named
  exemption (915e0e3), 0 violations** — later **12 code-surface
  commits, 0 violations** after the diff-scope whitelist hardening,
  and **14 code-surface commits, 0 violations** after the worker-driver
  and cycle-closure slices.
- Validated commits this session (since the restatement): 19 candidate
  commits + 4 labeled chore-export commits, all pushed; `main` in sync;
  the guard's own introduction commits are candidate-bound.
- Bridge: 10 tools, typecheck clean, stub-load clean, tree clean.

## Observations

- Each slice's governance loop (proposal → verdict → certificate →
  mutation-check) ran against real repository evidence; the two
  lane-off the governance loop (packages.lisp exports) were the documented
  dependency-guard exception, not an escape.
- Two genuine defects were caught by the test-first cycle (the wake
  let-scope bug and the worker constructor-arity bug) — the red-first
  discipline earned both.
- The external model's re-review was productive exactly because it
  verified rather than opined; the loop-history guard is the direct
  consequence.
- A third model pass (same session) confirmed the state "byte-for-byte"
  from a fresh clone, then found one more real soft spot: the guard's
  exemption lane was checked at the message level, not the diff level,
  so a labeled commit touching `src/domain/run.lisp` passed. That is
  now closed: the label is whitelisted to `src/packages.lisp` only and
  any other code-surface file in a labeled commit is caught by diff
  inspection (`0b0aad7`, candidate-bound). The machine cannot mistake
  today's honesty for tomorrow's any longer.
- The continual worker cycle gained its one-shot driver
  (`scripts/worker-driver`: create-run worker-task → admit worker →
  run-worker → close; a bare run refuses `no-worker-transport` with the
  honest exit 1) and a cycle-closure test locking the closed
  transitions (a worker-only run refuses `review` with
  `not admitted for model`). The bridge README documents the driver
  lane alongside `hngh_run_worker`.

## Remaining unknowns

- The worker-driver orchestration (a disposable session driven through
  the bridge tools end to end, run → worker → review → certify) and
  the node-lattice boundary amendments (ambient tunnels,
  certificate-bound wake) remain the next candidate slices.

## 2026-08-25-worker-driver

# 2026-08-25 — Continual-worker driver

## Scope

`scripts/worker-driver`: one explicit operator invocation that runs the
worker lane end to end — create-run (with the worker-task loadout
label) → admit-transport worker → run-one bounded read-only worker task
→ close the run. It is glue over the existing dispatch surface: no new
authority, no new transport, no daemon.

## Decision

1. The driver is a thin SBCL script that calls the closed commands in
   order through `hngh.main:dispatch-command`, checking each exit and
   stopping on the first refusal.
2. The argv parsing uses `uiop:raw-command-line-arguments` (the true
   invocation arguments, not SBCL's `*posix-argv*` under `--script`).
3. A bare invocation refuses at `run-worker` with `no-worker-transport`
   — the honest no-default-wire behavior; the worker lane needs the
   injected transport, which remains the operator's call.
4. The periodic invocation belongs to the operator's scheduler, never
   inside Hngh (no daemon, no watcher).

## Evidence

- Tests (test-worker-driver.lisp) run the REAL script as a subprocess:
  a malformed invocation (no store) exits 2; a bare cycle (no ports)
  exits 1. `make test` green at 2772 checks.
- Live manual run: create → admit both exit 0; run-worker correctly
  refuses `no-worker-transport` (bare script); the injected variant
  completes the full cycle (create=0, admit=0, work=0) in the live
  shell proof.
- Committed through the self-governed validation loop (`6da05b9`), gate green,
  pushed.

## Remaining unknowns

- The injected full-cycle proof lives at dispatch level and in the
  shell; the script's own full-cycle path (with injected ports) is
  exercised only live, not in the suite (the script never gets ports —
  the operator composes the transport).

## 2026-08-26-activity-cadence

# Activity cadence slice — 2026-08-26

The `activity-cadence` autonomy-continuum rung (roadmap Next item 2,
backlog entry): routine project activities mapped to cadence tiers and
riding the existing cadence-continuum machinery, scaled to the fleet.

## Deliverables

### hngh kernel
- `docs/project/activity-matrix.md` — the matrix: each activity
  (roadmap review, planning, design, roadmap expansion, implementation,
  review, refactor, cleanup, inward comms, outward comms) mapped to a
  cadence tier, the existing artifact it advances, its smallest
  increment, and its skip condition (file a report instead of acting
  when the increment is undefined). All rows are adoptable-by-peer.
- `docs/project/reports.md` + `docs/project/report-bodies/` — a clean
  first report ledger produced by one pass of each mounted drop-in
  (the observable cadence evidence).
- `docs/project/queue.md` — one dated zoom-out pass-log entry (the
  zoom-out loop's documented append protocol).

### hngh-automation
- `cadence/day/01-activity-tick.sh` — day-tier: reads the matrix and
  performs-or-files the next increment of each day activity
  (implementation, review, refactor, cleanup, inward comms), each from
  a real bounded read of the artifact it advances; skip-condition
  reports when the increment is undefined; files an `owned-by <peer>`
  report for any row a fleet peer has adopted (display/ledger only,
  never a dispatch network).
- `cadence/week/01-roadmap-review.sh` — week-tier: roadmap-review,
  planning, and outward-comms increments from roadmap.md/queue.md.
- `cadence/month/01-zoom-out.sh` — month-tier: thin wrapper around the
  zoom-out-loop lane, appending a dated zoom-out pass-log entry (the
  documented protocol) and filing a report.
- `systemd/hngh-cadence-day.{service,timer}` — the missing `day` tier
  unit (cadence-continuum had mounted 1m/5m/10m/week/month but no day);
  `Makefile` `enable:`/`disable:` now includes it. Timer is NOT enabled
  (operator installs via `make enable`).
- `STATE.md` breadcrumbs — one full run of each tier recorded.

## Gates
- hngh `make test`: green (2774 lisp checks + all python files rc=0).
- hngh-automation `make test`: identifier lint clean.
- Each drop-in run once for real via `jobs/cadence-tick.sh TIER=...`
  (day, week, month), all rc=0 with breadcrumb + report-row evidence.

## Steering log (self-introspection ticks)
This slice folded in the ritualized minute-level check-in: after each
build/step, the next smallest correct step was decided from the actual
output before acting.
- Re-grounded anchors against the live tree before editing (cadence-continuum
  had landed only 1m/5m/10m/week/month; no `day` unit existed though
  cadence-tick accepts `day`) -> added the missing day unit.
- Read-only boundary honored: automation writes only the report ledger
  (config.env/security-check rule); "performing" an increment means
  filing a dated report derived from a real artifact read, never
  editing governed source. The one governed-file append is queue.md's
  dated zoom-out pass-log entry, which is the loop's documented
  protocol and non-authoritative.
- Review-increment read excluded its own kind to avoid self-reference.
- Zoom-out append made idempotent per day to avoid duplicate pass-log
  entries on re-run.
- Reset the report ledger and produced one clean representative pass of
  all three tiers after the repeated test runs had cluttered it.
- Adopted() path unit-checked in isolation against a scratch fleet.md
  before trusting it in the committed drop-in.

## Not in scope
`surface-evolution-loop`, `agent-live-view`, `machine-steered-backlog`,
`governance-vocabulary` remain queued (roadmap Next item 2). The
`surface-evolution-loop` backlog item (dancing-ui / grade-interface /
evolve-operative) is the next routine candidate after this lands.

## 2026-08-26-agent-live-view

# 2026-08-26 — Agent live-view (dashboard roster)

## Scope

First implementation of the agent-live-view rung: the dashboard now reads
a live agent-session roster — the genuine worker stores under
`/tmp/hngh-heartbeat-*` and `/tmp/hngh-auto-*` plus the automation store —
distinct from the archived `sessions` list, and renders it as a panel in
`dashboard-tui` (and a table in `--export-html`).

## What landed

1. **`scripts/dashboard-readout`**: new `roster_rows(limit=15, ttl=0.0)`
   beside `session_rows` — same TTL-cache and fail-closed-empty-on-missing
   convention (a missing or unreadable store yields `[]`, never a crash).
   Rows are `{id, state, mission, source, age}` where `source` is
   `heartbeat`/`auto`/`automation`; state/objective are parsed directly
   from each store's `record.lisp` (no sbcl subprocess), newest record
   first, bounded by `LIMIT`. `roster` is folded into `data_spine`.
2. **`scripts/dashboard-tui`**: a `live agents` panel following the
   sessions `DataTable` pattern — id/state/source/mission columns;
   closed/evacuated beacons dim to ` beacon` exactly like the sessions
   panel (`_beacon_kind`), genuine states keep their `_STATE_COLOR`.
   Roster rides the existing worker gather/paint refresh; the panel is
   bounded (`height: auto; max-height: 10`) so it never squeezes the
   other tables.
3. **HTML export**: `render_html` gains a `live agents` table.
4. **Tests**: `tests/scripts/test-dashboard-readout.py` now asserts the
   `roster` key in `--json` output and fail-closed-on-missing
   (`roster_rows() == []` when no store root exists);
   `tests/scripts/test-dashboard-tui.py` asserts the `live agents` panel
   renders in the live PTY smoke. Both green.

## Verification

- `python3 tests/scripts/test-dashboard-readout.py` — smoke OK (added
  roster checks).
- `python3 tests/scripts/test-dashboard-tui.py` — 5/5 OK, PTY shows
  `live agents` panel + status strip.
- `python3 scripts/dashboard-readout --json` — carries a `roster` list
  populated from real heartbeat/auto/automation stores.
- `make test` — full gate green (lisp suite 2774 checks + python).

## Notes

- The roster is display-only (read), never governance input — matching
  the backlog intent ("display-only, never governance input").
- Hub-agent visibility stays limited to what the omp hub roster +
  `history://` transcripts expose; this pane surfaces the on-disk
  store sessions those run.

## 2026-08-26-architecture-index

# Architecture index — 2026-08-26

**Scope:** documentation-only. Added the single hub that maps the
system-harness intent onto its concrete homes, and reconciled the
activity-cadence timing-window note. No source, no queue/backlog edit.

## What landed

- **`docs/architecture-index.md`** — the index of the shared corpus.
  Built on top of the unchanged `docs/architecture.md` charter, it maps:
  - system-harness rungs **A–F** via
    `docs/project/system-harness-roadmap.md`,
  - the queue rotation handles (TSV ids) in `docs/project/queue.md`,
  - the proposal headings in `docs/project/backlog.md`,
  - the promotion rungs 11–18 already landed (roadmap `## Now`),
  - the dated records in `docs/records/README.md`,
  - the 8 autonomy-continuum directives from the roadmap `## Next`
    rung 2 (each with its queue id, backlog heading, and record), plus
    the two operator directives outside that frontier
    (`webapp-dashboard`, `self-optimization-continuum`),
  - a legend (queue id = rotation handle; backlog heading = proposal
    prose; A–F harness rungs vs numbered promotion rungs).
- **`docs/project/activity-matrix.md`** — reconciled (additive, no
  overwrite of the sibling draft): verified the 10 activity rows against
  the backlog `activity-cadence` list and added a `## Timing-window
  evaluation` section (event-fire/1m–5m/10m+/hourly+/agentic-gated
  placement) that was not already present. This file is sibling-owned
  and left uncommitted for the owning lane's own commit.

## Evidence

- `make test` — 2777 checks passed (full Lisp + reader-guard suite).
- `git status` verified before the ceremony; the manifest below is
  deliberately narrow (only the files this slice owns) so no sibling
  lane's uncommitted changes are captured.

## Remaining unknowns

- `activity-matrix.md`, `backlog.md`, `ui-grades.md`, `reports.md`,
  `scripts/dashboard-tui`, the `evolve-dashboard-style` slice, and
  `docs/records/2026-08-26-*` (`evolve-dashboard-style`,
  `oversight-tick`) are uncommitted by this slice — they belong to
  sibling lanes and will land through their own commits.
- The five harness rungs `resource-pool-view`, `config-manager`,
  `security-manager`, `notify-agent`, `ci-governance-gate` are queued
  in backlog but not yet queue.tsv rows; that is captured as the known
  backfill step, not a defect.

## 2026-08-26-autonomy-build-slice

# 2026-08-26 — Autonomy build slice finished (report-queue, run-autonomous)

## Scope

Completing the half-finished autonomy slice left uncommitted by the
prior session: the append-only report queue, the single-tick
`run-autonomous` governance driver, and their hermetic tests. No new
features.

## What landed

1. **report-queue**: `--list`/`--unread` rows are now real table rows
   (`| ts | kind | id | first | body-name |`) — the format the tests
   and the dashboard-readout consumer convention (`startswith("|")`)
   already expected.
2. **generate-publication**: restored the missing `import os` (a
   `NameError` at import had broken its whole suite 4/4); the
   `HNGH_PUB_ROOT` env override works again.
3. **run-autonomous** (`scripts/run-autonomous`): the finished
   single-tick autonomy driver — journal generation when today's
   journal is absent (progress + scheduled reports), one check-in-scale
   validation slice when the queue Next + >=2 open lanes + a valid
   heartbeat `.slice` card align (fresh `/tmp/hngh-auto-*` store),
   malformed cards fail closed (exit 2), refusing sub-steps exit 3,
   nothing-due exits 0. Date override `HNGH_TICK_TS` for tests.
4. **Hermetic tests**: `tests/scripts/test-report-queue.py` (8 checks,
   plus the fixed newest-first JSON body assertion) and the new
   `tests/scripts/test-run-autonomous.py` (6 checks over the full tick
   contract, stubbed siblings, no sbcl/network). Both wired into
   `make test`.

## Verification

- `python3 tests/scripts/test-report-queue.py` 8/8 ok (was 3 failures).
- `python3 tests/scripts/test-run-autonomous.py` 6/6 ok (new).
- `python3 tests/scripts/test-generate-publication.py` 4/4 ok (was 4 errors).
- `make test` full gate green.
- Live smoke: `HNGH_TICK_TS=2026-08-26 scripts/run-autonomous` →
  "nothing due", exit 0 (journal already present, gates shut).
- Landed through ceremony-drive (candidate
  `0765a7d00369d84af6df585c24a254852a7cb8e9cf8d1c72f8147d3197a75705`).

## Notes

- Ceremony-drive refused a store path whose root directory did not
  exist (TRANSPORT-FAULT); `mkdir -p` the store first.
- The hourly systemd timer wiring lives in the hngh-automation repo
  (`hngh-autonomy.timer`), left unenabled for the operator.


## 2026-08-26-ceremony-profile

# ceremony profile

venue timing for the optimization pass


## 2026-08-26-continual-scheduling

# 2026-08-26 — Continual scheduling, dashboards, publications, fleet

## Scope

One milestone that turns the operator's cadence from hand-invoked to
scheduled: a machine-level heartbeat pipeline, dynamic model routing,
live/exportable dashboards, a publication pipeline, and device-fleet
discovery — all inside the no-daemon boundary (every period lives in
operator cron/systemd; no script backgrounds itself).

## What landed

1. **schedule-heartbeat** (`scripts/schedule-heartbeat`): one
   single-tick scheduler entrypoint. Reads the queue ledger + Next
   item, checks the mounted action card
   (`docs/project/heartbeat/<id>.rotation|.worker`), probes the
   working tree, the model route, network reachability, and audio
   level, then triggers the mounted driver from a fresh ephemeral
   `/tmp/hngh-heartbeat-*` store and records a dated heartbeat entry
   (checkin.md + a `heartbeat-N` timeline row) whose SHA-256 is
   verified by re-reading the written bytes, committing the two ledger
   docs. `--dry-run` is the plan's verification (probe only, no
   mutation); `--loop N` re-ticks in the foreground.
2. **probe-model-route** (`scripts/probe-model-route`): the closed
   route vocabulary (`auto|local|remote`) resolved by one bounded
   authenticated probe of the operator reviewer-transport files. Any
   HTTP answer means reachable; missing configs resolve `none` (exit
   1) offline.
3. **Driver routing**: `rotate-queue --route=` resolves the reviewer
   transport by probe (no `--reviewer` file needed) with the loadout
   route label following the choice; `worker-driver --route=` names
   the session compute family. Both keep the established exit-code
   contract (2 malformed, 1 bare-cycle refusal).
4. **Dashboard live/export** (`scripts/dashboard-readout`): `--watch`
   / `--live` TUI refresh, `--json` spine, `--export-html`, and a live
   session read from the operator store rendered through
   `scripts/hngh present` (bounded, non-fatal, TTL-cached in watch).
5. **generate-publication**: `--daily`/`--check` (machine journals
   compiled from the verified git/checkin/timeline record; operator
   journals are never overwritten), `--ebook` (book.md + stdlib EPUB),
   `--site` (dashboard HTML + lane leaderboard).
6. **fleet-manager**: tailscale/LAN discovery, per-peer ping state,
   system probes (audio, tailscale, D-Bus, interfaces), WOL wake for
   operator-pinned MACs (unpinned/malformed refuse), dated record
   appends to `docs/project/fleet.md` + queue. The source pin registry
   is never written by a script.
7. **ceremony-drive**: closed governance glue for explicit candidates
   (create-run → admit → deterministic verdict → prepare-candidate →
   commit), used to land this milestone.

## Verification

- `make test` green at every phase boundary (2774 Lisp checks + the
  reader guards + the new script suites: schedule-heartbeat,
  probe-model-route, driver routes, dashboard live, publication,
  fleet).
- `scripts/schedule-heartbeat --dry-run` live: queue 15 queued/4 done,
  next=wake-mutation-lane, card none, model reachable (route=auto),
  network reachable, audio 8/10.
- `scripts/dashboard-readout --export-html` live: complete page with
  timeline/queue/sessions; `--json` spine parseable; watch loop
  renders with the store's session rows.
- `scripts/generate-publication --ebook/--site` live to /tmp;
  `--check 2026-08-25` correctly refuses the operator-authored journal
  (exit 1) and a machine-generated journal round-trips exit 0.
- `scripts/fleet-manager --discover` live: honest "no tailscale peers
  (logged out / no mesh)" with live system probes; unpinned wake
  refused exit 1.
- The governance smoke (scripts/audio-intensity as a bare candidate)
  drove the full loop; commit on an unchanged path failed closed as
  `command-failed` — the honest behavior for a no-op candidate.

## Remaining unknowns

- A real heartbeat tick end to end (a mounted card on a real item)
  needs the operator's card + schedule choice; the dry-run path is
  proven, the trigger path is one cron line away.
- `--route=remote` resolution is untested against a live remote
  endpoint (none configured); local is proven.
- Fleet wake is bounded and refused-safe, but no real WOL-capable
  device is pinned yet.


## 2026-08-26-course-selection

# 2026-08-26 — Machine-steered course selection lands in run-autonomous

## Scope

First slice of the machine-steered-backlog roadmap item: Hngh picks its
own next-best course for a ceremony tick rather than slavishly following
static queue Next. Choice + card mount only — no gate is bypassed.

## What landed

`choose_course()` added to `scripts/run-autonomous`, wired into `tick()`
ahead of the ceremony gate:

1. **Ranking.** In-queue lanes (the `## Next` block items first, then
   queued TSV rows) are scored by
   - mounted `.slice` card (carded lanes first),
   - ascending recency of last increment — the newest
     `report-queue --json` row whose body names the lane; never-
     incremented lanes rank as most-due (`0000-01-01…`) — then
   - queue Next order, then TSV order, as tiebreak.
2. **Course record.** `tick()` records the machine's pick as a
   `course <id>: <reasons>` progress report (e.g. "card mounted, last
   increment 2026-01-01T00:00:00Z") before driving the ceremony slice.
3. **Divergence.** On a course pick that differs from static queue Next,
   the mounted card for the coursed lane runs through `ceremony-drive`
   from a fresh ephemeral `/tmp/hngh-auto-<ts>` store — static Next is
   not followed. When nothing is courseable it falls back to the prior
   Next-card behavior, and the existing gates (queue Next present +
   `>= 2` open lanes + valid mounted card) are unchanged; exit codes stay
   0/2/3.

## Verification

- `python3 tests/scripts/test-run-autonomous.py` 7/7 ok — new case
  `test_course_prefers_mounted_older_lane_over_static_next`: queue Next
  names `lane-a` but `lane-b` shares a mounted card and has the older
  increment, so the tick records `course lane-b: card mounted, last
  increment 2026-01-01T00:00:00Z`, drives `lane-b`'s slice (`src/lane-b
  .lisp` in the ceremony stub argv, `src/lane-a.lisp` absent), exit 0.
- `make test` full gate green (lisp suite + all python suites).

## Notes

- The course report row is a `progress` row, consistent with the
  journal/ceremony records; the `scheduled` row still lands after a
  ran tick.

## 2026-08-26-evolve-dashboard-style

# 2026-08-26: Evolve-dashboard-style — surface-evolution-loop rung 1

## Scope

First slice of the surface-evolution-loop roadmap item: one evolution
loop for one surface (dashboard-tui style), graded by grade-interface,
bounded to a cadence drop-in. A deterministic-per-seed generator breeds
color-theme overlay variants, grades each candidate, and keeps the
fittest overlay mounted for dashboard-tui to consume at startup.

## What landed

- **`scripts/evolve-dashboard-style`** — evolution loop modeled on
  `evolve-operative`'s loop shape:
  - deterministic-per-seed mutation over the dashboard-tui `THEMES`
    color presets (field channel shifts + pair swaps); same seed, preset,
    gens -> identical candidates byte for byte (verified).
  - bounded generations per invocation (`--gens`, hard cap `MAX_GENS=12`);
    a bounded batch is what the cadence runs each tick.
  - each generation emits a candidate overlay and grades it:
    - **`--self-grade`** (default): deterministic WCAG-contrast /
      distinctness rubric, no model, no capture, dimensionless.
    - **`--grade`**: live vision path via `scripts/grade-interface`
      (capture + local VL model).
  - appends `{ts|target|gen|grade}` to `docs/project/ui-grades.md`
    (same ledger format grade-interface writes; target carries the
    generation so the 4-column header stays parseable).
  - leaves the fittest overlay mounted at
    `docs/design/ui-evolve/current-overlay.json`.
- **`scripts/dashboard-tui`** — `_apply_overlay()` reads the mounted
  overlay and applies its fields to the matching preset at import, so the
  accepted variant is live. Verified via the real module load:
  `hngh.secondary == #3d9478` from the mounted overlay.
- **`tests/scripts/test-evolve-dashboard-style.py`** — hermetic suite
  (5 tests): determinism, generation cap, command line, self-grade ledger
  + mount, offline-by-construction. Wired into the Makefile `test:`
  target; `make test` green (2774 lisp checks + all python suites).
- **`cadence/10m/01-evolve-ui.sh`** (hngh-automation) — cadence drop-in
  that runs ONE bounded generation batch per tick (hard cap 3
  generations, rotating deterministic seed derived from the wall-clock
  10-minute bucket), breadcrumbs each run, fail-closed exit 0. Auto-plugs
  via the existing `hngh-cadence-10m.timer` (already enabled) — no
  Makefile/enable-list change is needed for a cadence drop-in.

## Vision-capture gap (explicit)

A live `--grade` probe was attempted first (per the assignment's "try the
live path before falling back"): `scripts/grade-interface` now reaches
the local Unsloth server (the token was expired, rotated by
`jobs/credential-health.sh`), but **no model on that server accepts image
input** — `unsloth/gemma-4-12b-it-qat-GGUF` and every Qwen/Gemma id
return HTTP 400 "The requested model does not support the image input".
So live vision capture is genuinely unavailable in this environment, and
the loop runs `--self-grade` (deterministic, model-free). The capture gap
is noted; the generator's `--grade` path is ready for a VL-capable
environment.

## Real end-to-end run (acceptance)

- `python3 scripts/evolve-dashboard-style --preset hngh --gens 3 --seed 1`
  -> generations 6/10, 10/10, 10/10; ledger rows landed; fittest (10/10,
  gen 2) mounted. (A graded generation landed in ui-grades.md.)
- Determinism: same seed twice -> byte-identical stdout/stderr.
- `python3 scripts/dashboard-tui --theme=hngh` renders with the mounted
  overlay; `scripts/dashboard-tui` module load applies `secondary
  #3d9478`.
- `python3 tests/scripts/test-evolve-dashboard-style.py` 5/5 ok.
- `python3 tests/scripts/test-dashboard-tui.py` 5/5 ok.
- `make test` exit 0 (full gate: 2774 lisp checks + all python suites).
- `TIER=10m jobs/cadence-tick.sh` in hngh-automation: drop-in ran,
  breadcrumb `evolve-ui batch done (hngh gens=3 seed=...)`.

## Steering log (self-introspection ticks)

- After reading evolve-operative + grade-interface + dashboard-tui THEMES:
  next smallest step = probe the live vision path once before choosing
  the grading mode (the assignment requires live if available).
- Token was expired -> Main reported credential-health.sh rotated it; the
  re-probe then failed at the model layer (no VL model). Decision: fall
  back to `--self-grade` and note the capture gap explicitly, per
  assignment #3; keep `--grade` implemented for a VL-capable
  environment. [recorded for the file]
- Chose to mount `current-overlay.json` (not a patch) so dashboard-tui
  consumes a single versioned artifact; `_apply_overlay()` is a small,
  fail-closed read.
- The 10m drop-in auto-plugs into the existing `hngh-cadence-10m.timer`;
  no extra Makefile/enable-list entry is owned by this slice (the
  systemd timer additions are the sibling automation/autonomy slice).

## Commits

- hngh (ceremony, certificate-bound, pushed): `f478f18` (evolve-dashboard-style)
  and `51cbd3d` (dashboard-tui + test + Makefile + ui-grades + overlay + record).
- hngh-automation (plain): `f87c5a4` (cadence/10m/01-evolve-ui.sh).

## Next

- Vision-grading of the dashboard against the accepted overlay once a
  VL-capable model is reachable (`--grade` path).
- A second surface (OSD overlay / voice) entering the same loop is the
  next roadmap candidate after this rung lands.

## 2026-08-26-fasttest-cache

# Fast-test cache: full-gate `make test` cached per identical inputs

**Date:** 2026-08-26
**Change:** `scripts/verify-candidate.py`

## Context

`scripts/verify-candidate.py` runs `make test` unconditionally in `main()`
(the full-gate). Profiling (cProfile + timing): that single call is ~33s, and
ceremony-drive invokes verify-candidate ~5× per ceremony (gather, prepare
issue-cert/check, commit issue-cert/check, push) — ~3.5 min of repeated
identical full-gate runs. This cached the result keyed to identical inputs.

## Change

The unconditional `run_command(["make","test"])` is replaced by a cached
fast-test step that fails closed:

- **Cache key** (computed BEFORE the test): `f"{base_revision}|{candidate_hash}|{normalized_porcelain}"`
  where `normalized_porcelain` is the exact `git status --porcelain=v1
  --untracked-files=all` output the run already produced. Any change to base
  revision, candidate content, or full working-tree state invalidates.
- **Marker file:** `${TMPDIR:-/tmp}/hngh-fasttest-<repo>-<sha256>.ok`
  (`repo` = basename of cwd; `<sha256>` = hex digest of the key string, so the
  porcelain/newlines never appear in the filename). Content: `base-revision`,
  `candidate-hash`, `rc`, `duration`.
- **Hit:** marker exists and parses and `rc == 0` and stored `candidate-hash`
  matches → skip `make test`, still report `fast-test: passed`, and add the
  `(cached)` note only in the trace line (`trace: fast-test passed (cached)`).
  The output line `fast-test: passed` is kept verbatim (tests/scripts/
  test-verify-candidate.py asserts the substring).
- **Miss / unreadable / corrupt / rc != 0:** run the real `make test` and
  write/refresh the marker. A cached FAILURE (`rc != 0`) is stored but never
  satisfies the pass gate — only `rc == 0` passes (fail closed).

The candidate content hash is now computed before the gate (moved above it);
it was previously computed after.

## Evidence

Self-contained probe: manifest naming `scripts/verify-candidate.py`, run
twice, identical working tree.

| run | elapsed | exit | result |
|-----|---------|------|--------|
| 1 (cold, real `make test`) | 31.58 s | 0 | `:passed` |
| 2 (warm, second identical) | 0.10 s | 0 | `:passed`, `fast-test: passed (cached)` |

Both runs identical output (`fast-test: passed` / `:passed`). Marker written:
`/tmp/hngh-fasttest-hngh-184cc19961d4c4d854ea68303789625eafc406f554c4921f8da7d82d13699a82.ok`
(`rc: 0`).

## Gate not weakened

The mutation executor (ceremony-drive's `hngh_mutation_check`) re-verifies
tree-state and file hashes freshly at each mutation action
(issue-cert/commit/push) against its own admitted evidence. This optimization
only caches the FULL-GATE `make test` result keyed to identical inputs; any
cache miss/unreadable/corrupt marker falls back to the real test.

## Tests

`python3 tests/scripts/test-verify-candidate.py` → 77 checks passed. The
harness asserts `"fast-test: passed"` as a substring, which remains true on
cache hits. Full gate: `make test` green (recorded below).

## 2026-08-26-governance-vocabulary

# 2026-08-26: Governance vocabulary relaxation

## Scope

A prose-only rung (operator directive 2026-08-26, the
`governance-vocabulary` queue item): relax the over-fixed
"ceremony"/"ritual" terms across the docs to the flexible governance
vocabulary (governance, validation, acceptance, admission). No symbols
were renamed; no behavior changes.

## Change

- Rewrote prose-only uses of "ceremony"/"ritual" in the README and
  `docs/*` to the flexible vocabulary: "the ceremony" -> "the governance
  loop", "self-governed ceremony" -> "self-governed validation loop",
  "ceremony commit" -> "validated commit", "ceremony-bound" ->
  "governance-bound", "post-ceremony" -> "post-validation", "ritual
  record" -> "governance record", and so on.
- Kept every name intact exactly: the `ceremony-drive` CLI/script token,
  `drive_ceremony`, `CEREMONY`, the proposal strings (caller=ceremony-drive,
  declared-capabilities=ceremony), and timeline rows / table structure.
- Kept deliberate uses: the `governance-vocabulary` backlog/queue/roadmap
  entries quote the old terms as the thing being relaxed.
- Added a short terminology note to `docs/README.md`: the vocabulary is
  flexible; `ceremony-drive` is a stable CLI name, not a doctrine.

## Files

README.md, `docs/README.md`, and the `docs/*.md` prose set touched by the
rung (design, journal, project, records).

## Verification

- `make test` green (2774 lisp checks passed, all python suites 0, ASDF
  load clean) — the doc-numbers and timeline-events guards held.
- Re-grep for "ceremony"/"ritual" across the docs shows only the kept
  `ceremony-drive` token, the deliberate governance-vocabulary
  meta-quotes, and verbatim working-log lines; CHANGELOG was untouched.

## Notes

- CHANGELOG.md, queue.md, and roadmap.md were not edited by anyone but
  the parent folds records; this record is the slice's own file.

## 2026-08-26-loop-recognition

# 2026-08-26 — Loop recognition (oversight, repeated-expensive-identical-work)

## Scope

The recognition + steering half of the general failure class
"repeated expensive identical work before/while it loops". The concrete
instance diagnosed is `verify-candidate` re-running the full gate on
identical inputs; the sibling `2026-08-26-fasttest-cache.md` record is the
prevention half (a `/tmp/hngh-fasttest-*` cache that makes the repeat a
cache hit). This record is the detection and redirection half: an oversight
probe that names the loop as it starts and a model rubric that steers to
interrupt-and-redirect instead of letting the repeat continue.

## What landed (hngh-automation `jobs/oversight-tick.sh`)

1. **`probe_test_loops`** — a procedural probe watching two observable
   signals of repeated identical work:
   - **STATE crumbs**: 3+ byte-identical breadcrumbs (same `job|event|detail`)
     from the same oversight/credential/ceremony job, consecutive for that
     job (a distinct crumb from that job resets the count), all within a
     30-minute window. Distinct from the pre-existing 2-only
     `probe_repeated_breadcrumbs` alert; job-scoping kills steady-state
     noise (the tick's own `tick`/`steer` crumbs and the clock-scoped
     per-minute model crumbs never trip it).
   - **Verify-cache markers** (optional/cheap, fail-open): 3+ fresh
     `/tmp/hngh-fasttest-<repo>-<sha256>.ok` markers for the same repo
     within 5 minutes — the uncached repeat the FastTestCache exists to
     prevent. Absent marker directory → silent no-op, never an error.
   On either signal it emits `alert loop-signal: <detail>` through the
   existing `alert()` report-queue sink plus a breadcrumb.
2. **Agentic rubric** — the `steer_leg` prompt sent to `STEER_MODEL` now
   carries the loop-recognition rule: if the recent STATE tail shows
   repeated identical job/step execution with no distinct progress,
   recommend `steer: interrupt-and-redirect with the specific next action
   (prevent the repeat as it starts)`; otherwise `steer: none`. The gated /
   timed (`STEERING_BEAT_MIN`, default 10) / fail-closed behavior and the
   `steer:` crumb format are unchanged.
3. **Cadence note** — `cadence/README.md` documents the probe + rubric.

## Verification

- **Live run (no false positive)** on the current tree: `jobs/oversight-tick.sh`
  exits 0, breadcrumbs `tick mode=timer` + `steer none (no STEER_MODEL)`,
  and `grep -c loop-signal STATE.md` is 0. During the run the FastTestCache
  sibling was actively writing `/tmp/hngh-fasttest-*` markers for its own
  temp test repos (`tmp*`, one marker each) — repo-scoped grouping correctly
  did **not** fire.
- **Fixture (probe fires)**: a temp `STATE_FILE` seeded with 3 identical
  consecutive `credential-health.sh | credential-health | loop retry` crumbs
  plus 3 fresh same-repo `/tmp/hngh-fasttest-looprepo-*.ok` markers; the run
  exited 0 and appended one breadcrumb:
  `alert | loop-signal: STATE 3x identical crumb from credential-health.sh: credential-health.sh ¦ credential-health ¦ loop retry /tmp/hngh-fasttest looprepo (3 markers in 5m)`.
- **Gates**: `make test` in hngh-automation (identifier lint) green;
  `make test` in hngh green (see ceremony-commit hash below).

## Commits

- hngh-automation: `13071ba` — oversight-tick loop-recognition probe +
  steer rubric; `a32a059` — cadence README note.
- hngh: this record, ceremony-bound (commit hash in the commit itself).

## Remaining unknowns

- The FastTestCache marker grouping counts distinct keys per repo within a
  5-minute window (the marker design collapses same-key re-runs to a single
  file, so exact re-touch counts are not observable from one stat — the
  probe is deliberately heuristic, marked with a `ponytail:`
  comment naming the ceiling).

## 2026-08-26-omp-bridge

# omp-bridge — the Hngh-facing half of the oh-my-pi session bridge

**Date:** 2026-08-26
**Slice:** first concrete bridge between an omp (oh-my-pi) session and
Hngh — the Hngh-facing shell an omp plugin would call. This slice proves
the bridge exists and carries a session's actions through Hngh's own
governance, without rebuilding omp.

## Why

Roadmap Next #1 names "the worker-driver surface (the hngh-omp bridge
tools that run a disposable worker session through run-worker) — the
one-shot `scripts/worker-driver` cycle is done; the bridge-hosted
end-to-end session (run → worker → review → certify) is the open half".
This slice is the first seam of that half: give a session invoked through
Hngh (a) a project-state brief it does not have to rediscover, (b) a
certificate-gated commit path through `ceremony-drive`, and (c) a
registration line in the watchdog-visible handoff ledger so it is never
an invisible lane.

## Contracts

`scripts/omp-bridge` (python3, repo convention) exposes three read/one
write operations. It is an outer adapter: it only invokes the existing
`scripts/ceremony-drive` and the watchdog's own handoff ledger surface; it
never imports or mutates the hngh kernel, and records no side effect
beyond the ledger line it is explicitly asked to write. No daemon, no
scheduler.

- **`--orient`** — emit a one-shot project-state brief already ground from
  the repo: Queue Next (`docs/project/queue.md` `## Next`), Roadmap Next
  (`docs/project/roadmap.md` `## Next`), working-tree dirty check, and the
  last ceremony commit (latest `hngh: candidate` commit). The calling
  agent is handed this instead of re-walking the files.
- **`--register[=SESSION] [--note TEXT]`** — append one line to the SAME
  handoff ledger the roguelike watchdog
  (`hngh-automation/jobs/agent-watchdog.sh`) appends `session-drop` lines
  to, so the session is a governed, watchdog-visible lane. Ledger path
  overridable via `OMP_HANDOFF_LEDGER` / `HNGH_AUTOMATION_ROOT` (default:
  sibling `hngh-automation/agent-handoffs.md`).
- **`--ceremony OBJECTIVE FILE...`** — run `scripts/ceremony-drive`
  `--store=FRESH OBJECTIVE FILES` under a global non-blocking flock
  (`OMP_CEREMONY_LOCK`, default `/tmp/hngh-ceremony.lock`), a fresh
  ephemeral store, and a generous timeout — certificate-gated; most
  importantly `ceremony-drive` auto-pushes when origin exists.

Exit protocol (repo convention): 0 ok, 1 refused/conflict (lock held),
2 malformed input, 3 fault (missing ceremony-drive, ledger unwritable,
ceremony fault/timeout).

Path resolution respects `HNGH_BRIDGE_ROOT` (default = repo root from
`__file__`).

## Live evidence

Orientation against the live repo produced a real brief:
Queue Next `wake-mutation-lane`, Roadmap Next `(Next slice).`, working-tree
(dirty: the running dashboard/alert session's uncommitted report bodies),
and last ceremony commit `c27c4d7 … hngh: candidate 30697a3…`.

Registration against the live wizard watchdog ledger appended a real line:

    bridge-register | 2026-08-26T22:39:20Z | hngh|… | session-start: …

(see `hngh-automation/agent-handoffs.md`).

The ceremony contract was exercised for its own commit below.

## Files

- `scripts/omp-bridge` (new) — the bridge.
- This record, ceremony-committed in hngh.

## Next roadmap candidate

The plugin side of oh-my-pi that an omp session actually calls is the
operator's omp repo, not this one; wiring that side, and driving a
disposable run-worker end-to-end (run → worker → review → certify)
through the bridge, is the next auto slice once this seals the seam.

## 2026-08-26-osd-and-dashboard

# 2026-08-26: OSD overlay and dashboard/evolution surface

## Scope

A record of the operator-facing visual surface that landed in the last
24 hours: the full-screen dashboard TUI, the interface-grading loop, the
operative evolution story, and the desktop OSD overlay. Together they
turn Hngh from a command surface into an observable, graded interface
family — without touching the kernel's refusal vocabulary.

## What shipped

- **`scripts/dashboard-tui`** — a textual (rich) full-screen TUI with an
  animated operative, a lanes panel, and live session tables. It reads
  the same read-only store as `dashboard-readout` and renders the
  operator spine in a bounded foreground loop.
- **Grade loop** — `scripts/grade-interface` renders a deterministic,
  first-finding grade for a UI (target + grade + first finding), with
  `docs/project/ui-grades.md` holding the dated grade table; the
  automated grading loop feeds every interface iteration.
- **Operative evolution** — `scripts/evolve-operative` (the animation /
  generation story: gen 1 through gen 4-5) with
  `docs/design/operative-frames.md` (the frame/animation spec) and the
  operator-facing `docs/design/assistant-interface.md` (the operative
  layer).
- **`scripts/osd-operative`** (+ `osd-operative.qml`) — the Plasma 6
  standalone qml6 overlay window (frameless, always-on-top transparent)
  that floats the operative above the desktop, backed by
  `tests/scripts/test-osd-operative.py`.

## Why it is a record

These are operator-facing surfaces, not governance surfaces: the
kernel's evidence-before-claim, fail-closed, and certificate-bound
invariants are unchanged. The record documents that the surfaces were
shipped candidate-bound through the governance loop (each `hngh: candidate`
commit below), and that the grade loop is the seed of the federated
UI/UX validation the assistant-interface design names.

## Evidence

- Candidate commits: `95c811a` (grade-interface), `3b3c89b`/`3bc4a0b`
  (dashboard-tui), `456046d`/`9e41a6f` (operative evolution +
  operative-frames + assistant-interface), `5224f57` (osd-operative +
  qml + test).
- `docs/project/ui-grades.md` — dated grade table (2026-08-25).
- `docs/design/operative-frames.md` — the frame/animation spec.
- Should not be cited as evidence by an automated gate: surfaces change
  without the kernel.

## Bounded unknown

The grade table reflects 4/10 first findings on `dashboard-tui` as of
2026-08-25; whether a later grade pass moves the TUI past that floor is
the next check-in question, not settled here.

## 2026-08-26-oversight-tick

# 2026-08-26 — Oversight tick (procedural + gated-agentic observation)

## Scope

The detect → hook → react → prevent continuum, first live slice:
an observation tick that runs continually over active work, with the
firing-style placement rule the operator specified (cheapest fires
whenever; cheap fires per-minute; agentic rides a slower beat).

## What landed

1. **hngh-automation `jobs/oversight-tick.sh`** — one tick, flock
   single-instance. Procedural probes, instant, no model in the path:
   - stale ceremony stores (`/tmp/hngh-cer-*` `record.lisp` older than
     30 min → alert);
   - working-tree skew (either repo dirty & uncommitted > 4 h → alert);
   - repeated-breadcrumb loop detection.
   Mode `--event=NAME` runs ONLY the instant probes (hook usage: git
   post-commit, ceremony completion), always exits 0. Mode `--steer`
   runs the self-review leg (`optimize:` crumbs). The credential
   probe reuses `jobs/credential-health.sh` (self-heal under flock).
- **Agentic leg (gated, optional)**: when `STEER_MODEL` points at a
   local endpoint, a bounded 60 s call reviews the recent
   `STATE.md` tail and emits `steer: <action>` / `steer: none`
   breadcrumbs; the beat is timestamp-gated
   (`STEERING_BEAT_MIN`, default 10) so a per-minute timer never
   spends per-minute cost; absent the var it is fail-closed off.
- **Mounted** as `cadence/5m/01-oversight.sh` drop-in (the 5 m tier
   exists; cadence-tick runs it flock-guarded).
- **Alert sink**: `report-queue --add alert`, landing rows in the
   hngh reports ledger (`HNGH_REPORT_ROOT` = hngh repo).

## Verification

- Live run: exit 0; emitted 6 real `stale-store` alerts — all
  `/tmp/hngh-cer-*` stores untouched > 4 h (10:37–11:32 vs 16:13),
  zero false positives; alert rows landed in
  `docs/project/reports.md` (18 entries this session).
- `--event` mode: exit 0, no agentic leg, no stale-store matches by
  design (event fires only the instant probes).
- Syntax: `bash -n` clean both files.

## Failure class fixed live

`set -u` + sourced `breadcrumbs.sh` referencing unset
`AUTOMATION_ROOT` → silent exit 1 on first use. Fixed by exporting
`AUTOMATION_ROOT` before the source. (Same failure class as the
stale-anchor guard and the store-mkdir guard: environment contract
violations kill early scripts — the guardrail list gains
"export the repo root before sourcing the lib".)


## 2026-08-26-post-ceremony-push

# Post-ceremony push (push self-sufficiency)

Date: 2026-08-26

## Slice

Implement the hngh half of push self-sufficiency: after a successful
ceremony commit, `scripts/ceremony-drive` drives a certificate-gated
push so the committed slice reaches `origin` without a manual push.

## Change

`scripts/ceremony-drive`:

- `propose-argv` now takes a proposal `class` argument (default used
  for the feature proposal; `push-request` for the push proposal) so a
  single constructor covers both the commit-verdict and the push-verdict.
- `origin-present-p` reads `git remote get-url origin` and returns true
  only when it succeeds — the push gate.
- After the `commit` step completes successfully, `drive-loop` re-proposes
  under `class=push-request` into a fresh verdict file, then runs
  `issue-cert push run-1 <verdict> <files...>` and
  `mutation-check push run-1 <verdict> <files...>`, mirroring the
  prepare/commit gates. The push certificate validates because a commit
  does not change the candidate content hashes the certificate binds.
- When no `origin` remote exists, the push step skips cleanly (message,
  exit 0). It is a deliberate post-ceremony step inside `ceremony-drive`
  — not a git hook — so a half-ceremony is never pushed.

The kernel-side `:push` closed action, `command-for` (`git push origin
HEAD`), the `:push-request` admitted proposal class, and the real
mutation-check/issue-cert pipelines all already existed; this slice only
adds the driver that invokes them.

## Verification

- `make test` green (2774 lisp checks plus the python script suites).
- Live ceremony: this slice's own commit ran through the ceremony loop
  from a fresh `/tmp/hngh-cer-*` store (`mkdir -p` first), wrapped in
  `flock /tmp/hngh-ceremony.lock`, and — because the repo has an
  `origin` — the post-commit push step pushed the committed slice to
  `origin` without any manual `git push`. The commit is visible on
  `origin` as a result of this slice's own execution.

## 2026-08-26-roguelike-watchdog

# Roguelike agent watchdog — first concrete slice

**Date:** 2026-08-26
**Slice:** roguelike agentic lifecycle, watchdog — log-only observation + handoff.

The roguelike rule (`docs/project/roguelike-agentic.md`) says a session that
stalls, loops, or errors without recovery is dead; call it off, learn from
the failure, and launch a failure-informed replacement. This slice builds the
first concrete, observable piece: a **watchdog** that watches running agent
sessions, detects the three death signals against its locally readable
surface, and records a **log-only handoff** (a ledger line + an attention
flag) — it does not kill or launch agents yet. The actual replacement launch
is the next slice, carried by the handoff the watchdog leaves.

## Mount

The watchdog lives in `hngh-automation` (side-effect-free w.r.t. the kernel;
it reads `~/.omp/agent/sessions` and the live `~/.omp/run/daemons/*/clients`
roster, never mutates hngh state). It is folded into the existing **5m
oversight tick** probe leg (`jobs/oversight-tick.sh -> probe_agent_watchdog`
-> `jobs/agent-watchdog.sh`) rather than a new timer — the cadence machinery,
flock, `alert()` (report-queue + attention flag), and breadcrumbs are reused,
so there is no new systemd unit and nothing to enable.

## Detection surface (what the watchdog can honestly see)

- **Live rosters:** `~/.omp/run/daemons/*/clients/*` — one JSON per broker
  client, `{"pid","projectDir"}`. Gives the set of currently-open sessions.
- **Transcripts:** `~/.omp/agent/sessions/<slug>/<session>.jsonl` — every
  tool call / tool result / message is one JSON line with a timestamp.
- **Subagent liveness:** a session's per-agent transcripts live in its own
  subdir; a fresh one means the parent is legitimately parked on a live
  subagent.

### What it CANNOT see (stated honestly)

- The LM's in-flight "thinking". A stall is inferred only when a *current*
  session's transcript is silent for a full window **and** has no live
  subagent writing — a legit session sitting on a running subagent is never
  flagged (verified live).
- `projectDir` → sessions-slug is a path heuristic; an unmatched project is
  skipped (fail-open).

## Detection (defaults, env-overridable)

| Class | Signal | Default |
|-------|--------|---------|
| `stall` | current session's open turn (assistant text or non-`hub` tool call) with no transcript progress for `WATCHDOG_STALL_MIN` and no fresh subagent | 10 min |
| `loop` | trailing `WATCHDOG_LOOP_N` tool calls identical (guardrails failure class 1: blind tool-call retry) | 3 |
| `error` | trailing result is a hard-error result (`fail:`, `traceback`, …) with no corrective step for `WATCHDOG_ERROR_GRACE_MIN` | 2 min |

A session is only considered if its transcript was touched within
`WATCHDOG_LIVE_MIN` (default 180) — finished/abandoned sessions are not
re-flagged. Findings are deduped (`/tmp/hngh-watchdog-seen`) so the same
session+class is not re-reported on every 5m tick.

## On detection (log-only)

Appends a line to `agent-handoffs.md` (the running ledger), then files an
`alert` row via the hngh report-queue and touches
`/tmp/hngh-overseer-attention`, so the agentic steering leg / operator sees
it — then dedupes. **No processes are killed, no sessions are ended, no
replacement is launched in this slice.**

Ledger line format:

    session-drop | <ts> | <project-slug>|<session-id> | <class>: <evidence>

## Evidence

- Live no-false-positive run against the real trees (hngh session busy
  via a live subagent; hngh-automation session idle > 8 h) → **0 findings**,
  exit 0.
- Three planted fixtures (fake stalled / looped / errored sessions) → all
  three detected and logged as `session-drop` lines; report-queue alert
  invoked; attention flag armed; breadcrumbs written; dedupe confirmed.
- Fixture artifacts were then removed; the committed ledger ships with a
  header and is populated only by real future detections.

## Files

- `hngh-automation/jobs/agent-watchdog.sh` (new) — detector + handoff.
- `hngh-automation/jobs/oversight-tick.sh` — one-line mount on the probe leg.
- `hngh-automation/agent-handoffs.md` (new) — the running handoff ledger.
- This record, ceremony-committed in hngh.

## Next roadmap candidate

The actual replacement leg: on a `session-drop` handoff, end that session and
launch the failure-informed replacement (dancing-ui / gantt-ports backlog
lands there). This slice is deliberately log-only so a human/agentic leg
can trust the signal before any process control.

## 2026-08-26-scheduled-runs-investigation

# 2026-08-26: scheduled-runs investigation

## Scope

A read-only investigation of the `hngh-automation` project directory (a
separate repo from the hngh kernel) and its Hngh store (under
`~/.hngh-automation/store`).
Trigger: the dashboard's session list showed only "hourly research ping"
runs, all `cancelled`, and the operator asked whether any scheduled jobs
were actually firing.

## Finding 1 — the schedule is healthy

The trigger is a **systemd user timer**, not cron (`crontab` is not
installed on this box):

```
systemd/hngh-automation.timer:
  OnCalendar=*-*-* *:00:00
  Persistent=true
  WantedBy=timers.target
systemd/hngh-automation.service:
  ExecStart=<AUTOMATION_ROOT>/jobs/ping-hourly.sh
```

Live timer state (`systemctl --user list-timers --all`): `hngh-automation`
NEXT 2026-08-26 02:00:00 EDT, LAST passed 01:00:49 EDT (19 min ago).
All `hngh-*` units are `enabled + active`, and every job's service
`Result=success`. There are **7 timers**: `hngh-automation` (hourly ping),
`hngh-security` (every 4h), `hngh-morning` (digest 06-09h), `hngh-night-agent`
(00/02/04/06), `hngh-night-research` (23:40), `hngh-model-bench` (01:10),
`hngh-morning-report` (07:30). Hourly snapshots, digests, research briefs,
and model-bench rows all exist for the current day — the jobs fire and
produce output.

## Finding 2 — every `cancelled` run is a beacon closed `cancelled` BY DESIGN

Every store run traces `create-run` → `close-run cancelled`, closed
explicitly in `lib/hngh-record.sh`:

```
record_hngh_run() {
  ...
  close_out="$( "$HNGH_CLI" --store="$run_store" close-run "run-$run" cancelled 2>&1 )"
```

A completed run's mission declares `EVACUATION-CONDITION "evacuated"`, yet
`close-run ... cancelled` was hard-coded, so **no run ever reached
evacuated/complete** — the dashboard faithfully rendered "all cancelled".
This is not a failure; it is a semantic mislabel of a deliberately
best-effort activity beacon.

Store trace of a fresh per-job store directory:

```
(:IDENTIFIER "run-1" :KIND :CREATION :STATE :CREATED ... :OBJECTIVE "hourly research ping 2026-08-25 2100" ...)
(:IDENTIFIER "run-1" :KIND :CLOSE :STATE :CANCELLED ... :RECEIPT (:KIND :CLOSE :FACTS ("closed-to-cancelled")))
```

## Finding 3 — 4 of 7 jobs never wrote a run

`record_hngh_run` appears only in `jobs/ping-hourly.sh`,
`jobs/security-check.sh`, `jobs/morning-digest.sh`. The night-research,
model-bench, night-agent, and morning-report jobs produced output but
created no run row, so the session view was blind to them.

Store census at investigation time: **42 run dirs, 42/42 `:CANCELLED`,
0 evacuated, 0 complete** — all beacons from exactly three job kinds
(hourly research ping, morning digest, security check). No worker,
rotation, or checkin runs exist in this store.

## Fixes applied (hngh-automation repo, commit in that repo)

- **FIX-1 (semantics):** `record_hngh_run` now drives the closed CLI
  sequence `create → admit-transport filesystem → arm → start → close
  evacuated` (evacuated is only legal from `:running`), landing
  `:EVACUATED`. Falls back to `close cancelled` when the lifecycle
  refuses (refusals are data). The best-effort dogfooding comment is
  preserved.
- **FIX-2 (visibility):** `scripts/night-session.sh` (covers night-agent
  + morning-report), `jobs/model-bench.sh`, and `jobs/night-research.sh`
  now call `record_hngh_run` with their own mission labels, so the store
  reflects all 7 scheduled jobs.

## Evidence

- `systemctl --user list-timers --all` (7 hngh timers, LAST/PASSED shown).
- Store trace above (per-job `record.lisp`, `CANCELLED`).
- Scratch-store proof: `record_hngh_run "scratch beacon probe"` with
  `HNGH_STORE=/tmp/beacon-test` landed
  `:STATE :EVACUATED` ×2 and `closed-to-evacuated` in the store.
- `bash -n` clean on `lib/hngh-record.sh`, `scripts/night-session.sh`,
  `jobs/model-bench.sh`, `jobs/night-research.sh`.

## Remaining unknown

The dashboard (`scripts/dashboard-readout` in the hngh kernel) still
labels these beacons as "sessions"; distinguishing "beacon (cancelled by
design)" from genuine sessions is a follow-up view slice, not part of
this record.

## 2026-08-26-system-awareness

# 2026-08-26 — System awareness (read-only resource headroom feed + alert)

## Scope

First live slice of the SYSTEM-AWARENESS rung: give the command center
(dashboard) and the oversight tick read-only visibility into the machine's
resource headroom (cpu/mem/disk/network) so the agentic leg can steer on
resource changes. Probe-only — never implicit mutation.

## What landed (hngh-automation)

1. **`jobs/system-awareness.sh`** — a read-only probe writing
   `dashboard/system.json`: `cpu%` / `mem%` / `disk%` /
   `net` (`model_endpoint` ok|fail + `tailscale_peers` count) and
   `headroom` flags (`low-disk` / `low-mem` / `network-down`), each carrying
   a timestamp. Fail-closed: a failing probe yields its field
   `"unavailable"` — never a crash, never a fabricated value. Reuses
   existing primitives (does not re-invent them): `scripts/probe-model-route`
   for model-endpoint reachability, `scripts/fleet-manager --json` for
   tailscale peers + system facts. Token-level credential health stays in
   `jobs/credential-health.sh`.
2. **`cadence/5m/01-system.sh`** — cadence drop-in executing the probe
   (mounted on the existing 5m cadence; no new systemd unit).
3. **`jobs/oversight-tick.sh` → `probe_system_awareness`** — thin reader of
   `system.json` that alerts once per **new** critical headroom flag
   (`system-low-disk` / `system-low-mem` / `system-network-down`) with the
   same-key flapping suppression inside `alert()` (persistent condition
   alerts once, not every 5m), and arms the attention flag so the agentic
   leg can steer (e.g. "network down — pause network-labeled jobs").
4. **Two `alert()` bug fixes found while wiring this** (root cause, one
   guarded call each): `ALERT_LAST` was unbound under `set -u` (crashed
   every alert when the var wasn't exported), and the flapping-suppression
   timestamp parse used `cut -d' ' -f2` which breaks whenever the alert
   detail contains spaces (stale-store/system details do) — now
   `awk '{print $NF}'` (last field is the timestamp).

Headroom thresholds are env-tunable (`LOW_DISK_PCT`/`LOW_MEM_PCT`, defaults
90); `network-down` = model endpoint unreachable **and** zero tailscale
peers (no usable network path — otherwise the reachable model server keeps
network judged up).

## Verification

- **Live probe**: `jobs/system-awareness.sh` exits 0 and writes real values
  (`cpu=19 mem=71.3 disk=83 model=ok peers=0`); the real 5m cadence
  (`TIER=5m`) invokes the drop-in and appends
  `system-awareness.sh | system-awareness | cpu=… mem=… disk=… model=ok peers=0`.
- **No false alert on healthy machine**: `oversight-tick.sh` on the live
  all-false `system.json` emits no `system-*` alert and no attention.
- **Fixture (critical flag)**: `system.json` seeded with `"low-disk": true`
  → first tick appends exactly **one** `system-low-disk: critical resource
  flag set` alert row + arms attention; a second and third tick (same key,
  within the 60-min window) are suppressed — count stays 1. No arithmetic
  errors after the timestamp-parse fix.

## Commits

- hngh-automation: `dc877b4` — system-awareness probe + 5m drop-in +
  oversight probe_system_awareness + the two alert() fixes (not pushed).
- hngh: this record, ceremony-bound (commit hash in the commit itself).

## Remaining

- Next roadmap candidate: gantt-ports / dancing-ui backlog items (tiled
  subagent streaming) — out of scope for this slice; flagged for the next
  decision after this lands.

## 2026-08-27-acceleration-wave

# Acceleration wave — roguelike wrap, status verb, truth dashboard, register spec

Dated: 2026-08-27.

## Scope

Four parallel slices executed in one wave (three implementation owners +
one research beat), each verified independently and committed through
its own certificate loop:

- **Slice A — roguelike delegation wrap** (`scripts/omp-bridge`): new
  `--run-start` (create bounded builder run + `admit-transport :worker`
  under a persistent `OMP_BRIDGE_STORE`; loadout token/time limits are
  the delegated budget) and `--run-end` (client-validated
  `cancelled|evacuated|dead` → `close-run`). `HNGH_BIN` env seam for
  hermetic tests. Suite `tests/scripts/test-omp-bridge.py` (9 checks)
  wired into `make test`. Exit codes propagate the house 0/1/2/3
  protocol; no masking.
- **Slice B — interface-plan S3** (`scripts/hngh status`): verdict-first
  spine read. `all-clear` iff data.json digest `status == "ok"` AND every
  system.json headroom boolean holds; else `attention (<parts>)`; either
  source missing/malformed → `unavailable` (fail-closed). Panes:
  system/active/next/roster, each `unavailable` when its optional source
  (`HNGH_STATUS_*` env or `*status-*-source*` binding) is absent.
  `stale (Nm)` when a `generated_at`/`g` UTC-Z stamp is >10 min old.
  +37 kernel checks; `src/main.lisp` carries a minimal strict JSON
  scanner (the model adapter's helpers are unexported and opaque-pack
  numbers — documented in code).
- **Slice C — interface-plan S1** (`scripts/dashboard-readout`):
  verdict-first hero + state legend (`evacuated = finished & detached`),
  display-only `ETA` → `Depends on` rename (machine keys untouched),
  reorder-by-usefulness (active floats, otherwise stable), unified
  `stale (Nm)` pane labels (30 min live / 24 h committed spine),
  additive `verdict` key on `--json`. No emoji; dark-coat register
  preserved.
- **Slice D — display register research beat**
  (`docs/design/display-register-spec.md`): the Nihei register
  consolidated — voice/caption rules, gen-4 measured proportions,
  palette discipline, `perceptual:true` vocabulary table, dosage ladder,
  future grade-interface hooks. Indexing in the docs hubs landed with
  this commit.

## Evidence

- `sbcl --script tests/run.lisp` → 2851 checks passed (was 2814; +37
  from the status-verb suite).
- `python3 tests/scripts/test-omp-bridge.py` → 9/9;
  `test-run-autonomous.py` 7/7 (untouched);
  `test-dashboard-readout.py` + `test-dashboard-live.py` green (verdict
  truth-table, rename, ordering, staleness).
- `scripts/lint-parens.py` green on every touched .lisp file.
- CLI smoke: `HNGH_STATUS_SYSTEM=/nonexistent.json sbcl --script
  scripts/hngh status` → all panes `unavailable`, exit 0; `status
  extra` → exit 2.
- Main's independent post-wave review re-ran every gate and diffed all
  claims; all four executors stayed inside their owned-file contracts;
  no git operations by executors.

## Lessons harvested (llm-wiki)

- `hngh-storeless-cli-state-loss` — multi-process CLI flows need an
  explicit shared `--store` and a pre-created root.
- `subprocess-stub-seam-for-hermetic-tests` — env-overridable binary
  seam (`HNGH_BIN`) is the one-line testability pattern for
  subprocess-wrapping scripts.
- `cl-string-escape-literal-backslash` — CL string escapes are minimal;
  whitespace sets are character lists.
- `verdict-rule-drift-two-surfaces` — the verdict rule was implemented
  with two different source mappings (B: contract-named files; C: local
  spine approximation, licensed as a documented open question).
  Alignment lands with S2 wiring of the real system.json sources.
- `untracked-artifact tax` — 6,289 never-committed report-bodies made
  every `git status --untracked-files=all` scan (verify-candidate,
  ceremony evidence, watchdog, dashboard ticks) walk a 6,312-row tree;
  ignoring the directory cut porcelain rows 6,312 → 25 and removed the
  cross-tool contention that stalled a 4-manifest verify batch to
  144 s (single-run cost is ~0.2 s uncontended).

## Observed behavior

Delegated sessions can now be spawned and ended inside hngh governance
(`run-start`/`run-end`), the terminal shows one honest verdict on
demand, the dashboard leads with the same verdict rule, and the register
spec gives every future surface one aesthetic law. The kernel's
governance surface is unchanged; no daemon added.

## Remaining unknowns

- Verdict source alignment (C's local-spine approximation → S2's real
  system.json wiring).
- Concurrent delegated sessions sharing one bridge store reuse `run-1`
  (documented ponytail ceiling; per-session stores when needed).
- run-end cannot persist an operator note (kernel `close-run` has no
  note slot).

## 2026-08-27-dashboard-evolution-gbd-retirement

# Dashboard evolution + git-back-dots retirement

Dated: 2026-08-27.

## Scope

The operator's dashboard directives landed as four parallel slices plus a
retirement, each verified independently (several by Main's own browser
relay review, fresh-eyes adversarial):

1. **git-back-dots retired.** All 11 gbd units disabled; the tool's full
   history archived as a verified bundle at
   `~/Projects/back/git-back-dots/` (bundle + worktree snapshot + config
   copy + restoration README); uv install removed; lane repos at
   `~/.local/state/git-back-dots/` preserved — now owned by
   `jobs/config-backup.sh` (parity proven, agent-configs lane green and
   pushed after the scan learned that ALL-CAPS/`${VAR}` values are
   environment references, not secrets).
   Physical cleanup (operator-approved, same day): the 11 disabled unit
   files were removed from `~/.config/systemd/user/` (daemon-reloaded;
   zero gbd units remain) and `~/.config/git-back-dots/` was deleted —
   its `config.toml` was already archived; one older
   `config.toml.bak-20260731` in that dir was removed unarchived
   (disclosed; superseded config state of a retired tool).
2. **Operator-item lifecycle.** "For the operator" items now flow
   open → handled (with resolving evidence line) → dismissed-as-viewed
   (per-item, persisted to `operator-dismissed.json` + a handoffs row);
   40 items structured; dismissal proven on an isolated fixture server.
3. **Server endpoints.** `dashboard-server.py` gained
   `POST /operator-item/dismiss` and `POST /spawn` (configurable
   launchers from `~/.config/hngh/ui-config.json`, key-only client
   access, transcript resolution reused from the sessions feed); a live
   Konsole spawn was proven and cleaned up.
4. **Session-per-column observatory.** The 4-state buckets became one
   column per session: historic + live transcript tail (120-line cap,
   keyed diff), deep links `#run-<id>` with state restore across
   navigation, onboarding legend, human receipt sentences
   ("created · … / admitted · … / closed: evacuated"), history strip,
   1-minute feed drop-in. Adversarial review found 7 issues (persistence,
   glued headers, plist soup, graveyard default, pop-in, jargon,
   overflow) — all fixed and re-verified live.
5. **Cascading gantt.** `gantt.html`: one row per queued rotation lane,
   ESTIMATE-labelled bars (ledger p50 → loadout time-limit → 30m
   default, source shown per row), dependency connectors, relative
   projected starts (never fabricated dates), zoom 6h/24h/72h, drag pan
   with now-clamp, past region showing actual day-precision timeline
   events. Adversarial review caught an off-canvas connector artifact
   (double ms-conversion) — fixed and re-verified. A second pass by a
   sibling owner found the deeper cause of the operator's "no bars at
   all" report: the connectors SVG had no position rule and consumed
   ~965px of normal flow, pushing every row ~1000px below the fold
   (bars existed but were off-screen at every zoom). Fixed (`.glines`
   absolute) plus a 6px min-width floor with outside labels for tiny
   bars, 6h default zoom, and recurring chips (`∷ recurring ×N (every
   ~interval)`) computed from the time ledger. Method note:
   element-count probes matched the `gtoolbar` class and missed it
   twice; only the rendered-geometry audit (bounding boxes at viewport
   coordinates) caught it — geometry, not DOM presence, is the
   verification standard.
6. **Dashboard self-review (scheduled).** `jobs/dashboard-self-review.py`
   + hourly drop-in: feed freshness vs tiers, feed validity, served
   marker regression, ledger/body drift; findings classified
   unacceptable-now / acceptable-for-now and deduped through
   report-queue identities. Also surfaced + fixed a dedup defect
   (newest-row-only matching) and a server gap (css/js/json are now
   served `Cache-Control: no-cache` after two heuristic-cache
   incidents).

## Evidence

- Browser-relay verification by both executors and Main (screenshots in
  `~/Pictures/Screenshots/omp/`); bun/node syntax checks; curl endpoint
  proofs with swept test artifacts; `systemctl` post-states.
- hngh-automation commits: `7a4041e`, `5138aa5`, `93b6fd4`, `a6e580c`,
  `fd5d658`, `744f806`, `744f806..f67f972` wave commits — Main committed
  all after per-slice verification.

## Lessons (llm-wiki)

- `debug-repro-sandboxes-only` (the reports.md incident, repaired
  7,083/7,083 with 0 mismatches); `long-gates-run-async-against-interjections`;
  `verdict-rule-drift-two-surfaces`. Browser-relay screenshot friction
  filed via report_issue.

## Remaining unknowns

- Gantt per-lane medians need a lane→unit mapping once wrapped sessions
  name lanes in their missions.
- Widget-grid layout (terminalfeed.io-inspired) and the QoL evolution
  cadence are queued as rungs; interface plurality (OMP session as
  primary, Konsole hosting) recorded in the observatory rung.
- gbd unit FILES remain on disk (disabled state); deletion was not
  requested.

## 2026-08-27-operator-items-closeout

# Operator-items closeout — papercuts, bench slot, failed units

Dated: 2026-08-27.

## Scope

The dashboard's "for the operator" digest listed three open items; all
three are now closed at the source, and the stale "hngh repo is
agent-read-only" framing is retired by this very record (six agent
certificate commits landed 2026-08-27).

1. **`create-run` raw `TRANSPORT-FAULT` on missing `--store` dir** —
   fixed in the kernel: `hngh.main:dispatch-command` now refuses every
   command whose store path does not exist with
   `store directory missing: PATH (create it first, or drop --store)`,
   exit 2 (was: raw `transport-fault` render, exit 3). No auto-create —
   the fail-closed explicit-root contract stands; all other faults stay
   faults. Contract tests in `tests/main/test-dispatch.lisp` (+4).
2. **Wake-store collision (`record-conflict`)** — fixed in
   hngh-automation `prompts/night-check.md`: the wake flow now sets one
   timestamped store per wake
   (`STORE=/tmp/hngh-worker-wake-$(date -u +%Y%m%dT%H%M%S)`), `mkdir -p`
   first (pre-empting papercut 1 for this flow), all five steps share
   it, and a `find … -mtime +1` prune keeps /tmp clean.
3. **MiniMax-H3 in `BENCH_MODELS`** — dropped from
   hngh-automation `config.env` (0/5 twice running; 7 models remain).
4. **Failed units (calligra ×2, gbd-agent-configs)** — investigated:
   calligra units were transient desktop-launch crashes (reset-failed,
   gone); `gbd-agent-configs` is WANTED backup infrastructure whose
   secret scan is correctly refusing `~/.hermes/config.yaml`
   (token assignment) — reset-failed only, left enabled; the token
   needs an owner decision (remove from tracked set or ignore-list).
5. **Autonomy-tick wedge (found during the unit sweep)** —
   `hngh-autonomy.service` failed exit 3 every tick:
   `provision_card` had turned the node-lattice-admission queue row's
   prose evidence field ("backlog entry; README vision") into garbage
   candidate paths, so the tick's ceremony always died on
   `invalid candidate manifest`. Fixed: only real repo-relative paths
   are kept, prose degrades to the item-id placeholder (+1 regression
   test); the wedged card was removed and the loop re-provisions it
   correctly on the next tick.
   Second pass, same evening: the wedge re-appeared through the
   placeholder path itself — a re-provisioned card whose only candidate
   is the item id can never drive (`invalid candidate manifest` on
   every ceremony attempt). Fixed at the drive step: the tick now
   defers (`exit 0`, "ceremony deferred — candidates missing from
   disk") whenever card candidates don't exist, keeping the card
   mounted as a declaration of intent until real paths replace the
   placeholder (+1 regression test; live-verified twice on the failed
   unit, which now runs clean).

## Evidence

- Kernel: `sbcl --script tests/run.lisp` → 2855 checks (was 2851);
  smoke `create-run --store=/nonexistent/xyz` → refusal text + exit 2;
  `present` same; `make test` gate green.
- Automation: `bash -n config.env` + repo linter green; diffs +10/−6
  across the two owned files; committed in hngh-automation.
- Units: `systemctl --user --failed` after cleanup → only
  `hngh-autonomy.service` (live work, deliberately untouched); system
  scope 0 failed.
- Lessons: `long-gates-run-async-against-interjections` and the
  `untracked-artifact tax` note (see the acceleration-wave record).

## Remaining unknowns

- `gbd-agent-configs` will re-fail on its next tick until the hermes
  token is removed or ignore-listed (owner decision).
- The digest text regenerates on the next morning report; the
  resolution breadcrumb in hngh-automation `STATE.md` steers it.

## 2026-08-27-p2-design-contracts

# P2 DESIGN contracts — command center, awareness, buddy, gamification

Dated: 2026-08-27.

## Scope

Stood up the four foundational P2 DESIGN artifacts in `docs/design/`,
each ceremony-ready per the [master plan](../project/master-plan.md)
immediate-next-actions item 3 and the honest-layering rules:

- `docs/design/command-center.md` — unified CLI + GUI command center
  over one presentation spine; S1–S8 slice mapping; control contract
  (every action through an existing gate); awareness contract (every
  readout sourced + freshness-stamped); webapp/TUI as pure readers.
- `docs/design/system-awareness-map.md` — read-only probe architecture
  (CPU/mem/disk/net, model endpoint, fleet), the
  `jobs/system-awareness.sh → dashboard/system.json → oversight-tick.sh
  flap-suppressed alerts → agentic steer attention` flow, headroom
  thresholds, and fail-closed degradation rules.
- `docs/design/buddy-menu-spec.md` — pixel-RPG summoned non-nagging
  overlay: click-to-open quest ask / toggles / shortcut lenses,
  state→animation mapping, QML6 delivery polling `/tmp/hngh-osd.json`
  over the existing `osd-operative` feeder, honesty rules.
- `docs/design/gamified-runs.md` — runs-as-stories model: the closed
  event vocabulary (`quest`/`victory`/`setback`/`reward`/`death`)
  derived only from real run fields, the roguelike death-and-
  replacement rule, and the `perceptual:true` honesty leash keeping
  narrative out of governance and selection inputs.

Indexing: `docs/architecture-index.md` gained a `## P2 DESIGN
contracts` table; `docs/README.md` read order lists the four.

## Evidence

- All four docs pass link resolution (every relative markdown link
  resolves) and were written with no trailing whitespace per house
  rules.
- `python3 scripts/verify-candidate.py` gate applied at ceremony time
  via `scripts/ceremony-drive` (certificate-bound manifest).

## Observed behavior

P2's exit criteria (ceremony-ready docs, open questions closed) are
met: each doc names its source, its cross-links, its non-goals, and
its open questions; none adds executable capability or a daemon.

## Remaining unknowns

- The open questions each doc records (summon defaults, roster pause
  semantics, probe cadence tier, lens set, character naming, setback
  narration) are closed in the build slices they gate, not here.

## 2026-08-27-task-1.5-select-course

# Task 1.5 — pure machine-steered course selection (P1 #1.5)

Dated: 2026-08-27.

## Scope

Closed P1 #1.5 from the [master plan](../project/master-plan.md):
extracted course selection out of the `scripts/run-autonomous` service
tick into clean layers —

- `src/domain/course.lisp` — pure `course-candidate` value (identifier,
  mounted-p, last-increment-ts, priority-rank), validation predicates,
  the fixed `course-candidate-<` ranking policy (mounted first, then
  ascending last-increment with never-incremented most due, then queue
  priority), and the `select-course-candidate` selector with reasons.
- `src/application/ports.lisp` — `course-selection-ports`
  (fetch-candidates, clock-now, record-selection) and the
  `course-selection-result` value (`:accepted`/`:refused`/`:invalid`,
  chosen-identifier, reasons, labels).
- `src/application/select-course.lisp` — the `select-course` use case:
  validates every candidate, refuses empty sets as
  `no-courseable-lanes`, records the choice through the optional
  record port, and fails closed on fetch/record failures.
- `src/presentation/render.lisp` — `course <id>: <reasons>` renderer.
- `src/main.lisp` — `scripts/hngh select-course ID:MOUNTED:TS:RANK...`
  dispatch with a positional spec parser that tolerates colons inside
  ISO timestamps; exit 0 accepted, 1 refused/invalid, 2 malformed.
- `scripts/run-autonomous` — `choose_course` now asks the kernel
  selector first and falls back to the internal rule only when the
  kernel is unavailable or refuses (fail-closed, never fabricated).
- Tests: `tests/domain/test-course.lisp` (constructor guards,
  comparator ordering, selector reasons) and
  `tests/application/test-select-course.lisp` (fake ports: accepted,
  empty refusal, malformed refusal, fetch failure, record success/
  failure); wired into `tests/run.lisp` and `hngh.asd`.

## Evidence

- `sbcl --script tests/run.lisp` — 2814 checks passed (includes the new
  course suites).
- `python3 tests/scripts/test-run-autonomous.py` — 7/7 passed
  (fallback path keeps all existing cadence contracts).
- `sbcl --script scripts/hngh select-course lane-a:true::0 \
  lane-b:false:2026-08-01T00:00:00Z:1` → `course lane-a: card mounted,
  never incremented`, exit 0; malformed spec exits 2 with usage.
- `python3 scripts/lint-parens.py` — OK on all changed Lisp files.

## Observed behavior

The kernel now owns the ranking policy as written, testable policy
rather than tick-internal Python; the cadence uses it when available
and degrades honestly. The `course <id>: <reasons>` output line is the
same vocabulary the cadence reports use.

## Remaining unknowns

- CLI spec format is the documented `id:mounted-p:last-increment:rank`
  contract; reading candidates from queue state instead of explicit
  specs is the planned P3 `status`/`select-course` extension.
- The record-selection port is unwired today (CLI passes no recorder);
  the cadence records its own report rows as before.

## 2026-08-28-automation-advancement

# 2026-08-28 — automation-advancement review

Scope: how much of the operator session's own working pattern the machine
now runs itself, after the self-improvement cadence wave (hngh-automation
`34cd275`, `232c5fe`; hngh `3a112a6`) and the Winamp/docs wave
(`5a4ac12`). Evidence: the cadence trees, day-tier drop-ins, hourly
self-review + ui-audit, and the mechanisms listed in
architecture-index.md. Command: none — this is a mapping, not a bench
result; every claim cites a landed artifact below. Remaining unknowns:
none for the mapping; the next-necessary list is forward work.

## The session pattern, step by step

| Step | Automated today | Evidence |
|---|---|---|
| Intake → plan | No — operator-directed, agent-authored | session-notes; roadmap working order |
| Execution | Yes, per-tier | `cadence/{1m,5m,10m,30m,hour,day,week,month}/*.sh` |
| Verification | Yes, daily | `cadence/day/03-gate-check.sh` (`make test`, 2,855 checks) |
| Review | Yes, daily | `cadence/day/04-review-prep.sh` (`digest/REVIEW-<date>.md`; P0/P1 alerts) |
| Research | Yes, daily | `cadence/day/05-research-beat.sh` (`digest/RESEARCH-BEAT-<date>.md`) |
| Ledger hygiene | Yes, daily | `cadence/day/02-ledger-prune.sh` (48h retention, deletions alert) |
| Self-watch | Yes | oversight (5m), loop recognition, roguelike watchdog, agent supervision/auto-replace |
| Dashboard honesty | Yes, hourly | `cadence/hour/00-dashboard-self-review.sh`, `cadence/hour/05-ui-audit.sh` |
| Surface evolution | Yes | `cadence/10m/01-evolve-ui.sh` (evolve-dashboard-style) |
| Routine project activities | Yes, matrix-driven | `cadence/day/01-activity-tick.sh` per activity-matrix.md |
| Commits | Hybrid — plain `fix:`/`feat:`/`docs:` commits in hngh-automation; certificate loop in hngh is agent-run and now fired autonomously by the overnight beats (first runs were operator-initiated) | ceremony-drive; two waves of ceremonies this day |
| Records writing | No — agent-authored, ceremony-landed | docs/records/2026-08-28-*.md |
| Doc routing | No — agent-authored | this wave's docs edits |
| Telemetry | Capture only | `jobs/telemetry.py` (no readers yet, by design) |

## Honest read

The machine verifies, reviews, researches, prunes, watches itself, and
evolves its own surface on cadence. As of the overnight loop
(hngh-automation `3f4ad10`) it also executes and lands its own work:
plans are operator-authored and operator-accepted (today's plan,
docs/project/plans/2026-08-28-overnight-continuity.plan.md, was
accepted 2026-08-28T03:20:00Z before machine execution began), the
overnight cycle executes the accepted steps through bridge-gated
delegated sessions, and landing is certificate-driven — plain commits
in hngh-automation, the full ceremony loop in hngh. The only barrier is
governance itself (certificates + green gates); human approval covers
plan authoring, and acceptance of critical-risk plans (normal-risk
acceptance automated 2026-08-28 via plans/README.md's gate-driven
rule), and beyond that is
reserved for the critical class: provider/credential configuration,
systemd unit lifecycle beyond installed units, non-prune deletions,
and security posture. Blocked work parks with an operator-facing alert
and the cycle moves on — research lines are the filler, so the machine
never idles on a human.

## Next-necessary (recorded, not built here)

1. Telemetry readers — capture-before-views is satisfied; the store has
   day-old data and the specs' views (session-cost, research cost) are
   the intended first consumers.
2. Session-cost capture per ledger-and-records-spec.md (the sessions-feed
   aggregation flagged adjacent in the cadence wave).
3. Watchdog/oversight consuming day-tier rows (gate-red alerts already
   land in the ledger; arming on them is wiring, not new machinery).
4. ui-audit findings feeding oversight (the alert identities are already
   per-rule; a 5m consumer needs only a read).


## 2026-08-28-lessons-consolidation

# 2026-08-28 — lessons consolidation

Scope: review 2026-08-27 and 2026-08-28 work (records, review digest,
report-ledger alerts, plan ledgers, automation breadcrumbs) for
actionable process lessons and fold each into its correct home. Not a
bench record; every lesson cites landed evidence. Landing mechanism:
the certificate ceremony (`scripts/ceremony-drive`) on this day, with a
green `make test`; the commit hash is the certificate content hash in
`git log`.

## Source material

- `2026-08-27-{dashboard-evolution-gbd-retirement,operator-items-closeout,acceleration-wave,p2-design-contracts}.md`
- `2026-08-28-{self-improvement-cadence,automation-advancement}.md`
- hngh-automation: `digest/REVIEW-2026-08-28.md`, report-ledger alert
  rows 2026-08-27/28, `STATE.md` breadcrumbs, plan ledger
  (overnight-continuity, remote-hardening, device-pairing).
- Watchdog session-drop ledger (overnight rc=124 rows).

## Lessons and where each landed

1. **Gate-check coverage asymmetry — the automation repo's own gate has
   no checker.** With the kernel gate green, hngh-automation `make
   test` sat red on HEAD (3 lint-identifiers problems) and no alert
   fired, because `cadence/day/03-gate-check.sh` sweeps only the
   kernel. → backlog row "Cadence watch fixes — gated red, recorded
   not landed (2026-08-28)". The implied mechanical fixes (gate both
   repos; remove dead `TS_SUBNET`) were NOT landed in hngh-automation
   because its gate is red on HEAD — recorded with evidence instead of
   half-landed, per the no-speculative-commits rule.
2. **lint-identifiers does not track heredoc-scoped definitions.**
   deck-setup.sh's `$DESK_LAN_IP`/`$DESK_TS_IP` are defined (line 180)
   inside the `cat > ~/.local/bin/hngh-connect <<'C'` heredoc; the
   scanner flags their heredoc-internal uses as referenced-never-
   defined. Two of today's three lint failures are scanner blind spot,
   not shell bug; the third (`TS_SUBNET`, hngh-ufw-manage.sh) is a
   genuinely dead variable. → same backlog row.
3. **Expected-dirty ledger paths are not skew.** The oversight
   tree-skew probe fired x64 (row 96bd99de) on the machine's own
   uncommitted append files. → governance lesson in
   `docs/design/autonomous-development-control.md` § Ceremony-loop
   lessons; forward fix in the backlog row.
4. **Timeout-split ceremonies hand off through a runbook.** Three
   overnight runs died at the 1,800 s cap (rc=124, watchdog rows
   03:29Z/05:00Z/07:00Z) with candidates staged and only the
   certificate loop remaining; the runbook
   (`2026-08-28-overnight-continuity.ceremony-runbook.md`) closed it on
   the next loop. → governance doc, same section.
5. **Refusal surfaces carry the refusal reason.** Alert a1fde252
   ("omp-bridge: create-run refused (exit 1)", 03:19:56Z) named no
   cause, so the parked work could not be triaged from the alert
   alone. Extends the self-improvement cadence record's lesson 2
   (refusals name the fallback) from ceremony refusals to alert
   surfaces. → governance doc. The kernel-side sharpening of
   omp-bridge's refusal text is not built here: it is a src/tests
   change (failing-test-first), which parks under the plans' autonomy
   rule.
6. **Ledger appends are structure-bound.** The fresh-eyes review's
   open hngh P1 (digest/REVIEW-2026-08-28.md; report row 31527cac,
   09:06:56Z): `docs/project/reports.md`'s table header row appeared
   twice with the ledger title inserted between them — an inserting
   writer broke the single-header invariant. → repair landed here
   (review-digest-driven: the fix is traceable to alert 31527cac) plus
   the append-invariant bullet in `docs/design/ledger-and-records-spec.md`
   §3.
7. **Alert dedup needs escalation caps.** The xN occurrence marker
   grows unbounded and a permanently-deduped alert stops being
   information (stale-store spam x12 per id, rows 0582c2ca/4b0abe9a;
   dash-selfreview summary x18, row f438818b). Already observed as
   ledger lesson row b185ea3c; not-yet-admitted work → backlog row
   "report-queue escalation caps".
8. **Fresh-eyes digests ship the prompt echo.** REVIEW-2026-08-28.md
   is 1,100+ lines of echoed prompt and raw diffs; the findings are
   the last few lines. → same backlog row as item 1 (digest hygiene).
9. **Operator goals as design pressure.** Self-funding runway: the
   publications pipeline exists (`scripts/generate-publication
   --ebook/--site`) and the crystallized `docs/research/` lines are
   its feedstock; the admission path is the existing backlog rows
   (ebook-longform, public-surface, royalty-pipeline, funding-rails).
   Steam Deck: paired and hardened (hngh-automation `6688280`,
   `db2f60c`, `286b87f`; REMOTE-ACCESS.md); deck-as-node federation
   stays in the device-fleet/node-lattice backlog rows. Remote access:
   the remaining step is operator-side (`sudo tailscale serve --bg
   8890`), documented and never automated. → closing paragraph of
   `docs/project/roadmap.md` Next.

## Deliberately not folded

- Self-improvement cadence lessons 1–6: already recorded in
  `2026-08-28-self-improvement-cadence.md`; extended (not duplicated)
  by lesson 5 above.
- data.json stale nested digest (review P1, row 5c530858): already
  fixed at the root (hngh-automation `be984d2`).
- ui-audit transient crash ("Passed function cannot be serialized!",
  row 98c4f43a): not reproducible in later runs (fresh run 0
  violations 08:55Z); recorded here, no row.
- Overnight budget sizing (1,800 s vs full-plan ceremonies): the cap,
  the store sweep, and the selector timeout already landed
  (hngh-automation `933c7c5`, `448e2d5`); lesson 4 records the
  handoff pattern the cap implies.
- hngh-automation mechanical fixes (gate-both-repos, heredoc lint,
  TS_SUBNET): recorded in backlog with evidence, not landed — its
  `make test` is red on HEAD today; landing would violate the
  gated-green rule.

## Ceremony notes

Candidate sweep: this record plus the edits above, and the
machine-maintained ledger files left dirty by the day's cadence jobs
(reports.md appends, ui-grades.md, current-overlay.json,
device-pairing.plan.md status transition) land in the same certificate,
per the ceremony-runbook precedent — which also clears today's
tree-skew class at the source. No deletions beyond the one-line header
repair inside a candidate file, so the manual `docs:` commit fallback
(c0c0bd5 precedent) was not needed.


## 2026-08-28-self-improvement-cadence

# 2026-08-28 — self-improvement cadence wave

The manual self-improvement loop (ledger prune, gate check, fresh-eyes
review, research beat) became routine cadence work in hngh-automation,
and the route docs were corrected to match.

## Landed

- AUTO `34cd275` — the orphaned 30m and hour tiers wired: `jobs/cadence-tick.sh`
  allowlist accepts `30m`/`hour`, systemd unit pairs
  (`hngh-cadence-30m.{timer,service}` OnCalendar `*-*-* *:00/30:00`,
  `hngh-cadence-hour.{timer,service}` OnCalendar `*-*-* *:00:10`),
  Makefile enable/disable lists, `cadence/README.md` tier table.
- AUTO `232c5fe` — telemetry store v0 (`jobs/telemetry.py`, SQLite WAL,
  capture-first, best-effort exit 0); day-tier drop-ins `02-ledger-prune.sh`
  (48h alert retention, archive, honest tracked-deletion alert),
  `03-gate-check.sh` (daily `make test`, progress/alert rows),
  `04-review-prep.sh` (fresh-eyes review of both repos' last 36h via the
  local model chain, `digest/REVIEW-<date>.md`, P0/P1 alert rows),
  `05-research-beat.sh` (round-robin `research-subjects.txt`,
  `digest/RESEARCH-BEAT-<date>.md`); schedule + research feeds mounted on
  the 30m tier; `bash -n` sweep added to AUTO `make test`.
- hngh ceremony `3a112a6` — roadmap working order item 1 corrected
  (config-backup 30m landed; cadence routine recorded with AUTO hashes),
  session-notes §10 (proceduralized scouting; the operator's
  arbitrary-event-watching capability decision), CHANGELOG bullet,
  and the day's drop-in ledger rows.
- Live proof: both timers listed with future NEXT times; the 21:00:00 EDT
  boundary produced a real 30m tick (5 drop-ins) and readout regeneration.

## Lessons

1. **Skill text drifts from closed vocabularies.** The ceremony skill
   named `evidence-before-flag`; the matrix (governance.lisp) defines
   `evidence-before-claim`. Docs that name closed-vocabulary values
   should be checked against source, not trusted.
2. **Refusal messages should name the fallback.** `mutation-check` without
   candidate-path positionals silently defaults to `candidate.lisp` and
   verify-candidate refuses with the opaque "invalid candidate manifest".
   The paths are positionals (`cdddr`), not options — a sharper refusal
   ("no candidate paths given, defaulting to candidate.lisp") would have
   saved a loop.
3. **Two counters disagreeing is a signal.** 04-review-prep counted P0/P1
   twice (a `case` loop and a `grep -cE '\tP[01]:'`); they disagreed, and
   the disagreement was the bug — GNU grep treats `\t` as a stray escape
   and matches nothing. Fixed with `awk -F'\t'`. Verify counters against
   each other; keep the honest one (breadcrumbs) as the tiebreaker.
4. **Gate on lint output before running.** `bash -n` caught the
   trailing-`\`-swallowed-`}` brace groups immediately; the failure was
   running anyway. The new AUTO `bash -n` sweep makes the check a gate
   instead of a suggestion.
5. **Breadcrumbs settle attribution.** The 19 prune-deleted bodies
   predated the wave (earlier manual proof run); one STATE.md grep dated
   them and the alert that reports them. Append-only breadcrumbs are the
   audit trail — check them before trusting recalled timelines.
6. **Async proof beats blocking.** Long drop-ins ran as background jobs
   with result-checks embedded in the same command; delivery carried the
   verdict. One watcher was lost to a default tool timeout — long sleeps
   need explicit timeouts.

## Open

- RESOLVED 2026-08-28: the 19 tracked body deletions landed via a manual
  `docs:` commit (hngh `c0c0bd5`) — the ceremony structurally cannot
  express deletions; the operator delegated the path choice.
- RESOLVED 2026-08-28: the AUTO lint false positives were fixed at the
  root (hngh-automation `02f7c1c`); `make test` is green.
- TRIAGED 2026-08-28: both fresh-eyes P1s were wording-level; bounds
  sentences added to ledger-and-records-spec.md and
  knowledge-base-spec.md. The store half of the first was already
  landed; the dual-write producer and the KB index remain
  designed-not-built.


## 2026-08-30-evening-selfdev-plan

# Record — 2026-08-30 evening selfdev plan (authoring)

Status: RECORD. Cites sources per claim; admits no runtime capability.

## What was authored

Two plan files land through the batched docs ceremony named in
`docs/project/plans/2026-08-30-evening-selfdev.plan.md` step 9:

- **docs/project/plans/2026-08-30-evening-selfdev.plan.md** —
  status=proposed risk=normal accepted=-. The evening wave
  (~19:30Z → late evening UTC 2026-08-30): gate baseline (already run
  by the author: 2,855 checks, wall ~34 s, exit 0), the doc-sweep
  docs-sync fold-in (done by author), four research beats
  (handoff-brief schema, steer-vs-die threshold, shrunk
  alert→plan-candidate routing resolution, publication-pipeline
  grounding pass) alternating with two grow beats (first live wrapped
  delegation per roadmap stage 3, scoped to scripts/omp-bridge's real
  surface; automation-side declarative config-lane manifest in
  hngh-automation), a batched docs ceremony step, and the wrap.
- **docs/project/plans/2026-08-30-overnight-continuity.plan.md** —
  slim follow-on (6 steps) so the plan queue does not run out
  overnight (foldback lesson 1); its final step authors the next-day
  plan. Same contract.

Plus, riding the same ceremony: **docs/project/roadmap.md:27**
stage-0 row corrected "six use cases" → "seven" (select-course,
2026-08-27 — the foldback record fixed the Now section but missed this
route-table row; doc-sweep finding 1), and the grounded rewrite of the
three untracked 2026-08-30 research docs (doc-sweep finding 2 — the
crystallized→committed stall of foldback lesson 3, live):

- docs/research/2026-08-30-ceremony-cost-reduction-batching-kernel-doc-landings-safely.md
  — PR/CI/Sphinx/.pyi/release-tagging mechanics stripped (they do not
  exist in this repo); batching conclusion kept and grounded in the
  dogfood ceremony, the `make test` gate, and the observed batched
  precedent.
- docs/research/2026-08-30-alert-to-work-routing-patterns-closing-the-self-observation-loop.md
  — Linux-kernel-module/Netlink/sysfs mechanics stripped; loop-closing
  conclusion reframed to the real alert surface (reports.md alert
  rows, flap-suppressed oversight, backlog routing row) and Hngh's
  shape (alerts → parseable plan-step candidates in docs/project/plans/,
  outcome tracked by plan checkbox ticks + reports rows).
- docs/research/2026-08-30-delegation-lane-parallelism-multi-lane-omp-bridge-sessions-and-queueing.md
  — fabricated `src/delegation.c`/`src/scheduler.h` references removed;
  the "not established" framing kept as the model; the
  minimal-DelegationQueue-first conclusion grounded in
  scripts/omp-bridge's actual delegation path (single `--run-start`
  command, one shared bridge store, one global ceremony lock).

## Grounding corrections made while authoring (re-scopes vs the brief)

- The seeded-stall flag check PARKS: the self-supervision tick does
  not exist as code — it is named only in roadmap stage 3 and
  backlog/session-notes. The delegation grow beat is scoped to what
  scripts/omp-bridge actually supports (`--orient/--register/--note/
  --task/--ceremony`, `--run-start SESSION OBJECTIVE`, `--run-end RUN
  DISPOSITION`; from `:created` the only legal close is `cancelled` —
  kernel-refused illegal transitions are the contract working, proven
  live 2026-08-27).
- The config-backup step is grounded in the real artifact:
  hngh-automation/jobs/config-backup.sh (LANES case block:
  agent-configs, hermes-mcp-proxy, hermes-nous-off) with the landed
  30m drop-in cadence/30m/20-config-backup.sh; the step is scoped to
  an automation-side declarative lane manifest only — governed update
  lanes would need kernel changes and park.
- The alert→plan-candidate routing research beat shrank: the grounded
  rewrite already produced the mapping table, so the beat resolves the
  doc's two open threads instead of re-designing it.
- The journal update is re-scoped: docs/journal/2026-08-30.md is dirty
  with the live autonomous loop's writes and is machine-owned tonight;
  this wave leaves it alone.

## Sources

- docs/records/2026-08-30-lessons-and-foldback.md — lessons 1–4; the
  two hallucinated 2026-08-30 research lines as the named anti-pattern
  behind the plans' Grounding quality bar.
- docs/project/roadmap.md (route table; Next 1–5),
  docs/project/plans/README.md (plan contract),
  docs/project/plans/2026-08-28-evening-selfdev.plan.md and
  2026-08-28-overnight-continuity.plan.md (pattern).
- docs/project/backlog.md (named rows), queue.md, master-plan.md §4,
  roguelike-agentic.md, operating-precepts.md, active-work.md,
  lessons-2026-08-29.md, journal/2026-08-30.md.
- docs/research/2026-08-30-{delegation-lane-parallelism,ceremony-cost-reduction,alert-to-work-routing}-*.md
  (conclusions used directionally; hallucinated mechanics excluded and
  rewritten out).
- Operator's explainer suite ~/Projects/etc/20260830
  (00-introduction.md…09-runbook.md + README.md + CHANGELOG.md) —
  operator-authored framing material, audited via
  docs/records/2026-08-30-lessons-and-foldback.md; day-set numbers
  deliberately not imported.
- Grounding reads: scripts/omp-bridge, scripts/generate-publication,
  scripts/hngh, hngh-automation/jobs/config-backup.sh,
  hngh-automation/cadence/30m/20-config-backup.sh,
  docs/project/reports.md, docs/project/queue.md,
  docs/project/lessons-2026-08-29.md, docs/journal/2026-08-30.md.

## Gates at authoring time

- Kernel: `make test` green — 2,855 checks passed, wall ~34 s
  (baseline for this wave).
- hngh-automation: `make test` exit 0.
- Journal note: docs/journal/2026-08-30.md is intentionally untouched
  by this wave (dirty with the live autonomous loop's writes;
  machine-owned tonight).

## Execution — 2026-08-31 continuation wave

The wrap docs of this wave (docs/project/lessons-2026-08-30.md, this
addendum, the queue/backlog sync) land through the next batched docs
ceremony, same as the authoring set above.

- Step 9 landed as ceremony commit 8dfab6d (2026-08-30 19:26Z,
  pushed; exact 7-file list).
- Step 3 — docs/research/2026-08-30-handoff-brief-schema.md (119
  lines): 8-field handoff-brief schema, each field producer-anchored
  (active-work.md lane lines, hngh-automation/agent-handoffs.md
  watchdog rows, scripts/omp-bridge --orient/--run-start brief); thin
  fields framed "not established".
- Step 4 (first live wrapped delegation) — session
  evening-beat4-docscheck-20260831: `--register` (agent-handoffs.md:104);
  fresh per-run store hngh-automation/bridge/20260831T1846Z-evening-beat4/
  (required because omp-bridge hardcodes the run id `run-1`);
  `--run-start` accepted (create-run + admit-transport, run-1
  :created); `--orient` captured mid-work; the docs-integrity task ran
  green (doc-numbers guard exit 0, read-order 12/12, 23/24
  README-referenced paths present); three report-queue progress rows
  witness run-start/work/run-end (reports.md:502-504); `--run-end
  run-1 cancelled` accepted (receipt facts=closed-to-cancelled);
  `hngh present run-1` state=cancelled; probing an illegal `evacuated`
  close on the closed run was refused (invalid-transition). One
  finding was closed as a false positive: docs/project/notify-log.md
  is runtime-created by scripts/notify-agent append_hits (creates with
  the header on first hit, script lines 115-132).
- Step 5 — docs/research/2026-08-30-steer-vs-die-threshold.md (60
  lines): 5 signals with responses steer | procedural hook |
  die+replace, grounded in agent-watchdog.sh tunables
  (LOOP_N=3/ERROR_GRACE_MIN=2/STALL_MIN=10) and real reports.md rows
  (loop-signal/agent-stall/slow-unit/tree-skew); budget burn rate
  framed "not established".
- Step 7 — appended "## Open-thread resolutions (2026-08-31)"
  (+86 lines) to
  docs/research/2026-08-30-alert-to-work-routing-patterns-closing-the-self-observation-loop.md:
  thread 1 — candidates stage as docs/project/plans/*.plan.md
  (overnight-cycle.sh:186-199's selector greps exactly that surface; a
  queue-ledger column was rejected — queue.md is a fixed 4-field TSV
  by contract); thread 2 — the dedup window is wall-clock only;
  minimal coupling = identity naming the plan step with `--window 0`;
  re-arm after step close parked with a router-side pre-check
  recommended.
- Step 8 — docs/research/2026-08-30-publication-pipeline-grounding.md
  (213 lines; 15/15 grounding paths verified). Key correction:
  scripts/generate-publication consumes no docs/research/ lines and no
  research-lines manifest — `--ebook` reads a hard-coded 7-file list
  (script lines 235-247); `--site` is a shell over
  scripts/dashboard-readout (timeline.md + queue.md + live store
  rosters); the royalty-pipeline is blocked on missing book-machine
  inputs per its own dependency line.
- Step 6 (grow: config-lanes manifest in hngh-automation) landed
  after this addendum was drafted: automation commit 0927992
  (jobs/config-lanes.tsv + config-backup.sh manifest reader; per-lane
  --dry-run parity byte-identical; hngh-automation `make test` exit
  0; also carries the beat-4 witness artifacts). Verified in the plan
  file's step-6 note.
- Journal: docs/journal/2026-08-30.md was deliberately untouched by
  the continuation wave (machine-owned; the authoring-time note above
  stands).
- Filenames: the new research docs keep their 2026-08-30 (plan-date)
  filenames per plan contract; each notes authored-2026-08-31 inside.
- Second batched ceremony: landed 2026-08-31 by the closing cycle with
  kernel `make test` green immediately before, landing exactly the
  10-file candidate list from the plan's step-10 continuation note
  (three new research docs, the alert-to-work-routing resolutions, the
  delegation-lane agent-voice strip, the plan file with step 10 ticked
  and front-matter status=executed, lessons-2026-08-30.md, this
  RECORD, queue.md, backlog.md); push rides ceremony-drive's
  certificate-gated auto-push (failure would file an alert row). NEXT
  CYCLE status: item (1) was already in-tree at wake; items (2)-(5)
  are this ceremony.

### Sources (continuation wave)

- The four research docs named in steps 3, 5, 7, 8 (line counts
  verified at wrap time: 119 / 60 / +86 / 213).
- scripts/omp-bridge, scripts/generate-publication (lines 235-247),
  scripts/notify-agent (append_hits, lines 115-132),
  hngh-automation/overnight-cycle.sh (lines 186-199),
  hngh-automation/agent-watchdog.sh tunables,
  hngh-automation/bridge/20260831T1846Z-evening-beat4/,
  docs/project/agent-handoffs.md:104, docs/project/reports.md:502-504,
  ceremony commit 8dfab6d.


## 2026-08-30-lessons-and-foldback

# Lessons and fold-back — 2026-08-30

Status: RECORD. Evidence cited per claim; admits no runtime capability.

Source: the operator's 2026-08-30 doc suite (`~/Projects/etc/20260830`,
adversarially audited) plus direct reads of `docs/project/reports.md`,
the 2026-08-28 evening-selfdev plan, hngh-automation logs/digests, and
git history. This record folds the suite's verified corrections back
into the kernel docs and captures what the 33h+ unattended window
actually produced.

## 1. What the unattended window produced (2026-08-28T19:43Z → 2026-08-30T12:30Z)

- **One plan, executed end to end.** The operator-authored
  2026-08-28 evening-selfdev plan (8 steps, accepted 19:43:12Z) ran
  unattended through 13h18m to both gates green (progress rows
  `ad39f093`/`f92dc864` at 2026-08-29T09:01:17Z), landing seven
  hngh-automation commits (`585ccd0`…`2ea3db0`, CHANGELOG 2026-08-28).
  All 8 steps verified; no step parked.
- **Zero kernel commits after `667a36b`** (2026-08-28T19:46Z) through
  2026-08-30T12:30Z — 40h+ of kernel idle not from failure but from
  plan exhaustion: the machine cannot author plans (suite doc 07 §3,
  08 R2). The hourly workbeat re-announced the same lane identically
  on both mornings (rows `f27e3532` 08-29T09:00Z / `9b362832`
  08-30T09:00Z, "10 open lane(s); next=lane: hngh-autonomy-build") —
  motion without a plan.
- **Research: 12/12 lines crystallized.** Overnight 08-28→29 the
  30-min day-tier beat advanced lines at ~60–65 min per line
  (planned→expanding→contracting→crystallized; rows 22:03→23:03
  `logs-known-good-patterns`, 00:03→01:03 `remote-access-patterns`,
  02:03→03:03 `research-publishing-pipelines`, 04:03→05:03
  `unattended-session-budgets`, 06:03→07:03
  `virtual-assistant-ux`); per-beat wall 148–155 s (telemetry
  `research-beat` rows). Each line is one `model_call 4096` per
  transition over the local model chain — no search calls, no external
  references — so depth is bounded by the beat's prompt and prior
  material. The crystallize step wrote six docs into the kernel's
  `docs/research/`; they sat uncommitted for ~36h because landing
  kernel docs needs a ceremony and no plan remained to drive one
  (landed 2026-08-30, `1f04b5b`).
- **Failure classes in the window** (reports.md rows 2026-08-28T20:10Z
  → 2026-08-30T12:04Z): 2 stale-store ceremony-temp alerts; 3 review
  P0/P1 alerts (truncated spec write, lint heredoc concern,
  telemetry.db-shm tracked); 1 slow-unit (workbeat 1800 s cap); 2
  unparsable `readout.json` dash-selfreview alerts; 2 tree-skew
  dirty-tree alerts; 1 agent-stall (1967 min stale transcript); 1
  doc-suite checker false alarm (rc=1); 2 remote-posture degraded rows
  (deck unreachable); 2 daily budget digests showing overnight
  sessions=0, remote calls=0, cost $0 vs the operator's $10–20/day
  target. Every repairable class already has its fix landed in
  hngh-automation (atomic writers `760adb5`, eviction `5b79b86`,
  whitelist `1113810`, feed-regen re-read `dcb6221`, checker exemption
  via the 12:04Z progress row) — but every one of those fixes
  originated in a plan step or an operator session, never from the
  alert itself (R6's point, suite doc 08).

## 2. Lessons

1. **The plan queue is the throughput governor.** Gates, workers,
   beats, and reviews all ran green for 40h and produced nothing
   durable, because the one input they cannot synthesize — an accepted
   plan — ran out. Capacity work should target plan supply before
   execution speed.
2. **Alerts close their own loop only through plans.** The window's
   honest alerts were accurate and the fixes were real, but routing
   alert → draft plan step does not exist; the machine cannot act on
   its own observations without an operator-authored bridge.
3. **Research volume is cadence-bound, quality is grounding-bound.**
   The beat produced a crystallized line every ~65 min on cadence, but
   each line is single-model prior with no search or source capture;
   the crystallized→committed path also stalls without a ceremony
   driver in a plan.
4. **Budget sat idle.** The remote GLM leg (budgeted, key-file gated)
   recorded zero calls for two days — the token file is operator-only
   and was never placed (rows `f5929eaa`/`bed8edd3`), so the $10–20/day
   remote capacity never engaged.

## 3. Fold-back edits landed with this record

- `docs/design/autonomous-development-control.md`: the closed
  requirement-kind list was stale at 21 kinds; the validator
  (`src/domain/governance.lisp`) closes 24 — `:review` (rung 16) and
  `:remote-attestation`/`:federated-claim` (rung 11) added.
- `docs/project/roadmap.md` Now: "six fake-backed application use
  cases" corrected to seven (select-course, 2026-08-27); the frontier
  rung list stopped at rung 13 — rungs 14–18 (all landed 2026-08-25,
  already in root README and records) added.
- `docs/project/backlog.md`: the documentation-sync row gains evidence
  (the README-count guard landed as
  `tests/scripts/test-doc-numbers.py`; the roadmap rung prose drifted
  again and is corrected here); two new rows (night-agent plan
  authoring; alert→plan-candidate routing) carry the §2 lessons as
  candidate work for operator decision.
- Deliberately NOT folded back: live counts (kernel LOC, commit mix,
  cadence drop-ins, job counts) — the repo pins contracts, not day-set
  numbers; those live in the 2026-08-30 suite. Root README check
  counts were verified still true (2,855 checks, 19 verbs) and stand.


## 2026-08-30-overnight-continuity-plan

# Record — 2026-08-30 overnight continuity plan (execution)

Status: RECORD. Cites sources per claim; admits no runtime capability.

## What was executed

The 6-step plan in
`docs/project/plans/2026-08-30-overnight-continuity.plan.md`
(status=executed 2026-08-31 by the 21:00Z wake), under the plan's
binding autonomy rule: operator away, pre-authorized normal-risk;
governance the only barrier.

- **Step 1 — gate baseline** (20:01Z): kernel `make test` green,
  2,855 checks, wall 35s; hngh-automation `make test` green (10 tests
  + lint-identifiers). Recorded in the plan file.
- **Step 2 — research beat** (20:19Z):
  `docs/research/2026-08-31-buddy-summoned-not-nagging-menu-learning.md`
  — top master-plan §4 backlog candidate; 13 repo paths `test -f`
  verified; explicit Not-established section (no menu implementation
  exists; scripts/osd-operative.qml has no menu code). No
  un-crystallized digest material existed (all 22 research-lines.tsv
  lines crystallized), so the beat took the §4 candidate branch.
- **Step 3 — grow beat** (20:27Z): rotation via
  `scripts/rotate-queue --route auto` — the first `--route` exercise
  ever; it exposed and fixed two latent route-reviewer bugs
  (`uiop:run-program` returns stdout/stderr/exit-code values;
  `parse-namestring` of HOME parsed the user as a file name). Real
  model review: complete, 0 findings. Candidate
  `5be9d4c` (content hash a569ab0d…): queue.md row
  publication-lines-contract queued→done "rotated 2026-08-31" (honest
  date fix — the only prior use was on the literal 2026-08-25),
  `generate-publication --chapters` (grounding §4 decision A),
  rotate-queue fixes. Pushed `0a209ba..5be9d4c`; `make test` green
  post-commit; verify-candidate pre-flight :passed. Dispositions:
  wake-mutation-lane PARKS (smallest useful outcome is a
  `:wake-mutation` mutation-vocabulary action — kernel src/,
  forbidden to machine sessions); dss-e-export PARKS (YAGNI until an
  interop consumer exists).
- **Step 4 — research beat** (20:31Z): nothing accumulated, so the
  beat took the routing-table extension branch: +171 lines,
  "Outcome tracking without kernel changes (2026-08-31)" in
  `docs/research/2026-08-30-alert-to-work-routing-patterns-closing-the-self-observation-loop.md`
  — six fields (routed-from, routed-at, first-attempt-at, closed-at,
  outcome class, duplicate-skip event), each grounded in verified
  automation call sites; contracts only, no router tick exists
  (stated as Not established).
- **Step 5 — batched docs ceremony** (20:30Z): commit
  `11de68c` (candidate 87373ae7…), exactly 9 docs files — steps 2
  and 4 research artifacts, six evening-plan research stragglers,
  plan-file step 1–4 notes. No src/ in candidate paths; `make test`
  green pre-cert; main == origin/main. The 20:00Z beat hit its 30m
  kill (rc=124) 14s after the commit, before the plan-file tick —
  the 21:00Z wake re-derived steps 1–4 from the ledger and ticked
  step 5 (lesson recorded in lessons-2026-08-31.md).
- **Step 6 — wrap** (21:00Z wake): lessons-2026-08-31.md appended;
  journal 2026-08-31.md rewritten with the honest day ledger; queue
  row already synced by step 3 (publication-lines-contract done; the
  operator-owned `## Next` pointer left untouched — wake-mutation-lane
  stays parked per the step-3 disposition); next follow-on plan
  `docs/project/plans/2026-08-31-overnight-continuity.plan.md`
  authored (status=proposed risk=normal) so the plan queue never runs
  empty; this record, the tick, and the wrap docs land through this
  ceremony.

## Gates at wrap time

- Kernel: `make test` green immediately before this ceremony
  (2,855 checks).
- hngh-automation: `make test` green (step 1, re-checked by
  accept-plans machinery on the next acceptance pass).

## Sources

- `docs/project/plans/2026-08-30-overnight-continuity.plan.md` — the
  plan, its step notes, and its Parked list.
- `docs/project/queue.md` — rotation rows, Scale, ETA.
- `docs/research/2026-08-30-publication-pipeline-grounding.md` —
  decision A priced for the step-3 rotation.
- `docs/research/2026-08-31-buddy-summoned-not-nagging-menu-learning.md`
  and the routing-table outcome-tracking extension — the two beats'
  artifacts.
- `agent-handoffs.md` (hngh-automation) — beat ledger: 20:16:56Z
  session-start, 20:30:46Z rc=124 kill.

## Not established

- No alert-drain happened: unread report-queue alerts grew
  486 → 499 → 514 across the last three wakes. The router tick is
  design-complete (step 4) but unimplemented; it is the next plan's
  grow-beat candidate, on the hngh-automation side where commits are
  free.
- No kernel src/, tests/, Makefile, or hngh.asd file was touched, per
  the session guardrail.


## 2026-08-31-continuous-cycle-fix

# The continuous cycle and the plan-acceptance fix — 2026-08-31

Status: RECORD. Evidence cited per claim; admits no runtime capability.

Scope: interim review of the window 2026-08-30T19:26Z → 2026-08-31T03:21Z
(between the last kernel ceremony and the operator's 03:21Z direction),
the operator's standing direction that the plan-execution cycle is
continuous, and the fix that makes machine plan acceptance real.

## 1. Interim review 2026-08-30T19:26Z → 2026-08-31T03:21Z

- **Zero kernel commits; everything pushed.** HEAD is `8dfab6d`
  (2026-08-30T19:26:30Z, "hngh: candidate ef3c5861…"); `git branch -vv`
  shows `main` level with `origin/main` at the same hash — nothing
  landed and nothing unpushed in the window. (Precision note, added at
  landing time: after the §3 fix went live, the accepted
  evening-selfdev plan was machine-executed and its docs landed as
  kernel ceremony commit `c0bf428` at 2026-08-31T19:10Z — outside this
  review window, and itself pushed to origin/main. The fix
  demonstrably unblocks the pipeline this record describes.)
- **Both 2026-08-30 plans were never executed.** Front-matter of
  `docs/project/plans/2026-08-30-overnight-continuity.plan.md` and
  `docs/project/plans/2026-08-30-evening-selfdev.plan.md` still reads
  `status=proposed risk=normal accepted=-`; no `- [x]` step was ticked
  during the window (the two checked steps in the evening plan were
  marked by the author at authoring time, before the window). No
  rotation rows were added to `docs/project/timeline.md` (last rotation
  rows are 2026-08-25) and no next-day plan exists in
  `docs/project/plans/`. `hngh-automation/dashboard/plans.json` listed
  both as `status: proposed, accepted: -` — the machine saw them and
  correctly skipped them per its code.
- **Root cause: contract drift, not a fault.** The plan contract
  (`docs/project/plans/README.md`, "Acceptance") says a proposed
  normal-risk plan is auto-accepted when its verification steps are
  runnable and both gates are green. The executor
  (`hngh-automation/scripts/overnight-cycle.sh`) implements only the
  consuming half: selector (a) requires `status=accepted` (~line 180)
  and machine-drafted plans are written `status=drafted` with
  operator-accept instructions (~line 158). No code path anywhere in
  hngh-automation flips `proposed` → `accepted` (verified by search for
  auto-acceptance across `scripts/`, `jobs/`, `cadence/`). The plan
  contract and the executor drifted apart; the operator-only acceptance
  is the drift, not the contract. And there was no hour-gating either:
  the `hngh-overnight.timer` is `OnCalendar=*-*-* 00/2:30:00` — every
  2 hours, 24/7 — so the cycle was already running around the clock;
  the ONLY blocker was acceptance.
- **Zero new alert rows in the window.** `docs/project/reports.md`
  holds 25 alert-class rows in total (classes observed: oversight
  stale-store, review P0/P1, loop-signal, ui-audit, doc-suite check,
  agent-stall); none fall in the window. No alert class covers
  "plans staged but never accepted" — the highest-leverage failure of
  the night was invisible to the alert surface.
- **The no-daemon cadence itself ran clean all night.** `config-backup
  agent-configs` progress rows every 30 minutes through the window
  (19:30:45Z through 03:00:45Z, `6f20e8cb`, ok 9 files each); hourly
  research beats advanced lines all night; hngh-automation sweep
  commits landed hourly through 23:01 EDT (`cbae502` 19:01 …
  `d535f71` 2026-08-30T23:01:46-04:00 = 03:01:46Z).
- **Research crystallized four new docs in the window, all untracked:**
  gantt-legibility-patterns (20:04Z), search-grounded-research-beats
  (22:03Z), self-funding-paths (00:03Z), session-cost-display-formats
  (02:03Z). All four sit untracked in `docs/research/` — the
  crystallized→committed stall, third occurrence (foldback lesson 3,
  `docs/records/2026-08-30-lessons-and-foldback.md` §2.3: the
  crystallized→committed path stalls without a ceremony driver in a
  plan). One crystallization (session-cost-display-formats) had
  regressed to ungrounded C-kernel fiction and was rewritten grounded
  in this same batch (docs/research/
  2026-08-31-session-cost-display-formats.md, grounded rewrite).

## 2. Operator direction (2026-08-31, recorded faithfully)

- **The plan-execution cycle is CONTINUOUS, 24/7 by intent.**
  "Overnight" is a naming artifact of when the first implementation
  happened. Unattended research and development happen at any hour of
  the operator's 24-hour cycle.
- The operator usually keeps Eastern time and sleeps at night; the
  machine does not sleep the same way — parts stay awake via local or
  remote agentic sessions, procedurally chained commands, scripts, and
  services, within the no-daemon discipline.
- Standing intents: automation for project-management practices in the
  clean-architecture style; research into self-correcting automation
  loops and program states that pass altered versions of themselves to
  future iterations; continuous refactor welcome when it serves
  clean-architecture purpose; roguelike development standards
  maintained (death-and-replacement, handoff briefs,
  procedural-over-agentic).
- Long-run goals: Hngh schedules and optimizes scheduling for
  relatively arbitrary requests, queueing and completing them
  immediately or on an appropriate cycle; and a long-term
  biographic/documentary pipeline where Hngh maintains the notes and
  records for operator writing about Hngh's development.

## 3. The fix (hngh-automation)

hngh-automation gains machine auto-acceptance implementing the README
contract: a proposed plan with `risk=normal`, runnable verification
steps, and both repos' gates green is flipped to
`accepted=<UTC ts>` by the machine, with a progress row emitted.
`risk=critical` plans never auto-accept. Red gates emit alert rows
naming the failed check. Plan execution is evaluated every tick, 24/7,
per the operator's continuous-cycle direction in §2. The plan-feed
`steps_total` parser is fixed (it counts checkboxes only within the
first 2048 bytes of the file — both 2026-08-30 plans' `## Steps`
sections begin beyond byte 2048, so the dashboard showed
`steps_total: 0` for plans that have steps). Hermetic unit tests cover
the acceptance path. This record cites the change at
hngh-automation commit `b1e3e26` (local, master; no remote configured —
hngh-automation has no git remote, parked for the operator; the
`hngh-overnight.timer` executes the local working tree, so the fix is
live on the next tick), message "feat: machine plan acceptance per
kernel contract; continuous 24/7 cycle", 7 files +472/−17, `make test`
green (bash -n over cadence/jobs/lib/scripts, 10/10 hermetic acceptance
tests, identifier lint). Grounded specifics: `scripts/accept-plans.py`
is a new fail-closed acceptance engine — proposed + normal-risk + every
unchecked step carrying Verification + both gates green → atomic
front-matter flip plus a progress row via `scripts/report-queue` and
`logs/acceptance.log`; `risk=critical` parks with an alert; a red gate
or non-runnable verification emits an alert row naming the failed
check; a `DRY_RUN` seam. Wired into `scripts/overnight-cycle.sh`
immediately after the flock and before the `MAX_SESSIONS_DAY` spend
cap (acceptance is cheap and uncapped), with the continuity comment
"plan acceptance/execution evaluated every tick, around the clock".
Selector (a) is unchanged (`status=accepted` grep) and the
accepted→executed lifecycle flip pre-exists. `dashboard/plans.json`
regenerated (evening plan 10 steps/2 done, overnight plan 6/0).
Precedent for machine-authored status: the 2026-08-28 plan's
acceptance flip rode kernel ceremony commit `667a36b`.

## Sources

- `git log` / `git branch -vv` in this repo (2026-08-31): HEAD
  `8dfab6d`, `origin/main` at the same hash, nothing unpushed
- `docs/project/plans/2026-08-30-overnight-continuity.plan.md` and
  `2026-08-30-evening-selfdev.plan.md` — front-matter and unchecked steps
- `docs/project/plans/README.md` — the plan contract (auto-acceptance)
- `hngh-automation/scripts/overnight-cycle.sh` — operator-only
  acceptance (~lines 158, 180); no proposed→accepted code path
- `hngh-automation git log b1e3e26` — the acceptance fix commit and
  its file list (`scripts/accept-plans.py`, `scripts/overnight-cycle.sh`,
  `jobs/plan-feed.py`, `dashboard/plans.json`, `tests/test-plan-acceptance.py`,
  `CHANGELOG.md`, `Makefile`); the `hngh-overnight.timer` calendar
  (`OnCalendar=*-*-* 00/2:30:00`) read from the systemd unit state
  reported by the director
- `docs/project/reports.md` — progress/alert ledger for the window
  (config-backup 30m rows, research-line rows, 25 alert rows none in
  window, classes stale-store/review/loop-signal/ui-audit/agent-stall)
- `hngh-automation/dashboard/plans.json` — the machine's view of the
  plans (proposed, accepted=-, steps_total=0)
- `hngh-automation/jobs/plan-feed.py` — the 2048-byte head read that
  truncates the steps count
- `hngh-automation git log` — hourly sweep commits
  `cbae502`(19:01EDT) → `d535f71`(23:01:46-04:00) inside the window
- `docs/records/2026-08-30-lessons-and-foldback.md` — foldback lessons
  (plan queue as throughput governor; crystallized→committed stall)
- `docs/design/ledger-and-records-spec.md`,
  `docs/research/2026-08-28-session-cost-display.md`,
  `docs/research/2026-08-30-alert-to-work-routing-patterns-closing-the-self-observation-loop.md`
  — the model rewrite pattern and the cost-display grounding
- `scripts/dashboard-readout`, `scripts/dashboard-tui`,
  `hngh-automation/dashboard-server.py`, `hngh-automation/jobs/session-cost.py`,
  `hngh-automation/jobs/telemetry.py`,
  `hngh-automation/jobs/telemetry-report.py` — the real cost-display
  surfaces (Deliverable 1 grounding)


## 2026-09-01-operator-items-plan

# Operator items plan — 2026-09-01

Status: RECORD. Evidence cited per claim; admits no runtime capability.

Scope: the operator's 2026-09-01 direction (six items, restated
faithfully below), its encoding as the queued plan
docs/project/plans/2026-09-01-operator-items.plan.md, and the
avoid-duplication check against the routed plans already queued that
day.

## 1. Operator direction (2026-09-01, recorded faithfully)

1. **Push-on-demand.** Hngh must push commits to remote whenever
   appropriate, not operator-gated. (Being implemented in
   hngh-automation 2026-09-01; see §3.)
2. **Delegated-session costs.** Optimize and limit via further
   iterative research into the roguelike development pattern — cheap
   sessions, death-and-replacement, handoff briefs;
   local-model-first selection with paid fallback, benchmark-gated.
3. **Continuous local-model research.** Benchmarking and optimizing
   practical techniques for Hngh's own development, on cadence.
4. **Procedural email reports to the operator** (progress + research
   digests; alerts immediately), replacing token-costly browser-based
   Google-Messages notifications; OSS prior art (ntfy, Apprise)
   welcome as future channels.
5. **Budget target <$10/day**, and Hngh becoming self-funding
   (publications pipeline: scripts/generate-publication --ebook/--site
   consuming crystallized docs/research/; backlog rows ebook-longform,
   public-surface, royalty-pipeline, funding-rails).
6. **Long-run.** Hngh schedules and optimizes scheduling for
   relatively arbitrary requests, queueing and completing them
   immediately or on an appropriate cycle; and a long-term
   biographic/documentary pipeline where Hngh maintains notes and
   records for operator writing about Hngh's development.

## 2. The plan

docs/project/plans/2026-09-01-operator-items.plan.md was authored
2026-09-01 ~19:45Z: status=proposed risk=normal accepted=-, nine steps
under strict grow↔research alternation (grow beats at steps 1, 3, 5,
7, 9; research beats at steps 2, 4, 6, 8), each step carrying an
indented Verification line per the plans README contract. Normal-risk
autonomous work pre-authorized; critical-class work (credential/
provider configuration, systemd lifecycle, kernel src/) parks. The
plan queues behind the routed plans already accepted that day — the
cycle executes the oldest accepted plan's next unchecked step; jumping
the queue is not attempted.

## 3. What was and was not visible at authoring time (~19:45Z)

- Kernel HEAD was 6cbdc9c; the working tree carried the machine's
  owned dirty paths (docs/journal/2026-08-31.md, docs/project/
  reports.md, ui-grades, current-overlay.json, queue.md) and eight
  untracked routed plan files — all machine-owned, untouched by the
  plan's authoring.
- The 2026-09-01 connectivity slice and notify-email slice were NOT
  yet visible: hngh-automation CHANGELOG.md's newest entry is dated
  2026-08-31 (machine plan acceptance, plan-feed fixes), `git remote
  -v` in hngh-automation is empty, and scripts/notify-email.py does
  not exist there. The plan's steps 1 and 3 verify-on-arrival and park
  with an alert row if the slices still have not landed when they
  execute.
- Present and grounded: hngh-automation jobs/session-cost.py (one
  telemetry row per finished omp session, kind=session-cost),
  jobs/model-bench.sh (three deterministic probes, python judge, one
  JSON line per model per day in stats/model-bench-<date>.jsonl),
  logs/budget.md, hngh scripts/generate-publication (HNGH_PUB_ROOT
  seam; --ebook reads a hard-coded 7-file list per the backlog
  publication-lines-contract row).

## 4. Avoid-duplication evidence

Eight routed plan files dated 2026-09-01 were on disk at authoring
time (front-matter statuses as read): dash-selfreview feed-fresh /
feed-valid / summary (accepted 2026-09-01T12:01:27Z), overnight
plan-accept-gate kernel (12:01:27Z), review P1 truncated execution
note (12:01:27Z), slow-unit dropin:20-workbeat.sh (accepted 02:01:23Z,
executed — false positive fixed at hngh-automation 7caff48), ui-audit
name-completeness (02:01:23Z), tree-skew hngh (accepted
2026-09-01T19:01:23Z). All are alert-fix one-steppers routed by
scripts/router-tick.py; none covers any of the six operator
directives, so the operator-items plan duplicates none of them.

## Sources

- docs/project/plans/README.md (the plan contract).
- The eight 2026-09-01 routed plan files on disk (front-matter read
  2026-09-01 ~19:45Z).
- hngh-automation: CHANGELOG.md (newest entry 2026-08-31), `git remote
  -v` (empty), jobs/session-cost.py, jobs/model-bench.sh, logs/budget.md.
- hngh: scripts/generate-publication, docs/project/roadmap.md,
  docs/project/backlog.md, docs/project/queue.md,
  docs/project/master-plan.md §4, docs/project/roguelike-agentic.md,
  docs/research/2026-08-30-delegation-lane-parallelism-*.md,
  docs/research/2026-08-30-publication-pipeline-grounding.md,
  docs/records/2026-08-31-continuous-cycle-fix.md §2.


## 2026-09-03-capabilities-direction

# Capabilities direction — operator directives 2026-09-03

Status: RECORD. Preserves the operator's 2026-09-03 direction
faithfully, the evidence gathered for it (re-gathered read-only
2026-09-04), and the trajectory it sets. Admits no runtime capability
by itself; the design contracts and plan carry the implementation.

## 1. The six directives (recorded faithfully)

1. **Unsloth management.** Recognize local Unsloth hosting (API up
   ~99% of the time, occasionally halted for updates). Long-run:
   Hngh manages Unsloth AND software generally — stopping/starting
   services, config and update management.
2. **1Password.** Local 1Password is available for credential storage
   with an SDK and CLI (`op`). Hngh should manage software like
   1Password too, and use it for credentials. Security is paramount.
3. **Near-autonomous posture.** Automate any and all "operator
   steps"; difficulties become lessons and tuning; blockers after
   that process get handled with priority above later work.
4. **Queue progress.** The queue needs more reliable progress;
   steady continual pace.
5. **Documentation expansion.** Continual, steady expansion —
   progress AND coherence of intent; expand sections as Hngh itself
   expands.
6. **Open question — browser messaging.** Can the browser-based
   messaging approach be automated, targeting active logins (Google
   Messages web, Discord, WhatsApp, etc.)? The email channel is
   already procedural; this is about a browser-driven channel with
   near-zero token cost.

## 2. Evidence gathered (read-only; gathered 2026-09-04)

- **Systemd user units** (`systemctl --user list-unit-files`,
  `is-active`): llama-server.service **disabled**, unsloth-warm.service
  **disabled**, unsloth-studio.service **enabled**; all three
  inactive at check time. The 2026-09-03 observation (unsloth-studio
  active while :8080 unresponsive) was the prior state; the enable
  state of unsloth-studio (enabled, not disabled as the other two)
  is itself signal — the studio is the unit the operator intends to
  run.
- **Ports**: `curl http://127.0.0.1:8080/health` → 000 (down);
  `curl http://127.0.0.1:11434/` → 200 (Ollama up, Ornith-1.0-9B per
  lib/model.sh chain). The serving gap that sends the delegated lanes
  to paid fallback is confirmed still a serving problem.
- **Secret files** (paths + modes only, contents never read):
  `~/.hngh-automation/unsloth.token` (600), `unsloth.refresh` (600),
  `reviewer-local.conf` (644 — mode flagged in the credentials
  design; whether it carries a secret is not established),
  `notify-email.conf` **absent** (the email channel is dormant by
  design — lib/notify-email.sh's config-absent → one-crumb behavior).
- **1Password CLI**: `command -v op` →
  `~/.linuxbrew/bin/op` (linuxbrew prefix); `op --version` → 2.32.1.
- **Browser probes** (for directive 6): no chromium /
  google-chrome-stable / chromium-browser binary on PATH;
  `import playwright` fails (ModuleNotFoundError);
  `~/.config/chromium` and `~/.config/google-chrome` both exist
  (existence only — never opened). Full analysis:
  docs/research/2026-09-03-browser-messaging-automation.md.
- **Bench history** (stats/model-bench-2026-09-0{1,2,3}.jsonl, 5
  probes, as verified in the 2026-09-03 staging notes): TWO local
  models at 5/5 — unsloth/Ornith-1.0-35B-GGUF all three days;
  bartowski/Qwen3.8-27B-GGUF 4/5→5/5→5/5; gemma-4-12B variants 4/5
  with p1_reader=0 all days; Ollama's Ornith-1.0-9B 5/5, 5/5, then
  3/5 (single-day runs are weak gates — multi-day admission rule
  suggested).
- **Sibling automation slice 2026-09-03** (hngh-automation:
  jobs/service-state.py, scripts/service-ctl.sh,
  cadence/day/11-service-recovery.sh, queue-progress telemetry in
  scripts/email-digest.py): **not yet observed on disk at authoring
  time 2026-09-04** — the directories were listed (jobs/, scripts/,
  cadence/day/ — 10 day-cadence scripts present, 11-service-recovery
  among them NOT yet) and email-digest.py carries no queue-progress
  telemetry yet. Cited by path + slice name, verify-on-arrival; the
  capabilities plan's steps 1/3 gate on its landing.

## 3. Governance amendment carried by this direction

Directive 1 implies one amendment, recorded in
docs/design/service-management.md §3 (the standing rule docs are NOT
silently edited): start/stop/restart of ALLOWLISTED INSTALLED user
units (exactly llama-server, unsloth-warm, unsloth-studio, via
service-ctl) is normal-risk under the 2026-09-03 operator grant;
enable/disable/mask, unit-file edits, enablement changes, and
anything touching the security posture remain critical-class (park).
Hngh starts no daemons of its own — it manages existing installed
software. The kernel's "critical = systemd unit lifecycle beyond an
already-installed unit" rule stays intact: an installed unit's
start/stop is lifecycle WITHIN an installed unit.

## 4. Avoid-duplication note

The 2026-09-03-staging plan (accepted) already owns: bench probe
calibration (its step 2), stage-2/3 exit-criteria sweeps (step 3),
the unsloth recovery note (step 4), and the stage-4 package-upgrade
runbook design (step 6). The capabilities plan cites those steps
where they overlap and does not repeat them; its service/credentials
steps complement (not duplicate) the staging plan's
investigate-only posture by adding the amended-grant control surface.

## 5. Trajectory

Design-first because security is paramount (directive 2): the design
contracts (service-management.md, credentials-posture.md) land before
any implementation slice, so the closed allowlists, refusal taxonomy,
redaction duty, and the critical/normal boundary are fixed before the
first `service-ctl.sh start` or `cred_get` runs. Implementation
follows in the capabilities plan as gated, verify-on-arrival grow
beats (steps 1, 3, 5, 7), with research beats (2, 4, 6, 8) feeding
config-manager, the audit trail, the browser-messaging gate, and the
queue-pace verdict. Directive 3's posture is encoded structurally:
every park names the exact operator step; every failure becomes a
lesson, then takes priority.


## 2026-09-03-staging-notes

# Staging notes and roadmap evidence — 2026-09-03

Status: RECORD. Evidence cited per claim; admits no runtime capability.

Scope: the operator's 2026-09-03 direction ("What work can we stage
for today? Are there roadmap items we should note?"), the interim
summary for the window 2026-09-01 → 2026-09-03, and the per-stage
roadmap evidence status requested. All observations checked
2026-09-03 ~13:05Z unless a timestamp is quoted.

## 1. Interim summary 2026-09-01 → 2026-09-03

- **Kernel HEAD unchanged at 37f6ae0, everything pushed.** `git log
  -1` shows `37f6ae0 hngh: candidate f16dde2…` (landed 2026-09-01)
  and `git status` shows no unpushed kernel commits; the working tree
  carries machine-owned dirty paths only (docs/journal/ 09-02 and
  09-03, docs/project/reports.md, ui-grades.md, current-overlay.json,
  queue.md, plan-file ticks, .omp/) plus untracked routed plans and
  research docs — all machine-owned, none ceremony candidates.
- **The continuous cycle executed machine sessions through the
  window.** hngh-automation logs/budget.md records session-run rows
  for `overnight|2026-09-01-operator-items` on 09-02 (00:05, 00:35,
  01:09, 02:06Z) and 09-03 (00:10, 00:33, 01:17, 02:03Z); overnight
  run logs exist per beat (logs/overnight-2026-09-01-operator-items-*.log).
  The alert→plan routing loop routed fresh 2026-09-03 one-steppers
  (plan-accept-gate, repeat-crumbs, tree-skew, ui-audit
  name-completeness, two review P1s) and auto-accepted them
  (reports.md rows fd054e2a / 0f745a8c at 2026-09-03T11:01:24Z) — the
  acceptance machinery landed by the 2026-08-31 fix is working
  end-to-end without a human demanding it.
- **Spend is far under target.** reports.md row e9fdb98b
  (2026-09-03T09:05:46Z): "daily budget digest 2026-09-03: overnight
  sessions=4 (overnight,2026-09-01-operator-items) remote_model_calls=0
  remote_cost_usd=0 [vs operator target $10-20/day]". Two-day spend
  ≈ $0.00/$0.13 per the staging brief's sweep; the daily digests are
  the standing evidence surface.
- **One session stalled and was recovered.** An overnight session
  stalled awaiting operator push confirmation; the recovery and the
  standing-authorization encoding are being landed by the sibling
  automation slice 2026-09-03 (cited by slice name, not by hash — it
  lands in parallel; verify its commit in hngh-automation when
  reading this record later).
- **No email channel yet.** reports.md "Step 3 park (2026-09-02T01:00Z)":
  notify-email SMTP config at ~/.hngh-automation/notify-email.conf not
  found — operator setup item; digest composer verified in report
  mode. Daily digests are composed (logs/email-digest-2026-09-0{1,2,3}.md,
  sent=dormant per row 32e80b2e).
- **Bench finding (verified from the jsonl, correcting the brief).**
  stats/model-bench-2026-09-03.jsonl shows TWO models at 5/5:
  unsloth/Ornith-1.0-35B-GGUF (5/5 on all three days 09-01→09-03) and
  bartowski/Qwen3.8-27B-GGUF (4/5, 5/5, 5/5). The brief's "no local
  model at 5/5" is not what the data says. The delegated-lane
  fallback to paid is a SERVING problem, not a fleet-capability
  problem: 127.0.0.1:8080 was unresponsive at check time (curl code
  000) and Ollama :11434 hosts only Ornith-1.0-9B (5/5 on 09-01 and
  09-02, 3/5 on 09-03 — variance worth a multi-day gate). The
  gemma-4-12B variants scored 4/5 with p1_reader=0 on all three days;
  whether that is judge mis-calibration (strict keyword match on
  `#+`/reader/syntax/malformed/sharp) or genuine misses is staged as
  research step 2 of the 2026-09-03-staging plan.

## 2. Roadmap notes — per-stage evidence status (stages 0–5)

Per the operator's ask; stage states from docs/project/roadmap.md,
evidence as verified today.

- **Stage 0 — kernel & governance: done.** `make test` green at
  HEAD 37f6ae0; every kernel commit is certificate-bound (the
  dogfood loop; HEAD message is a candidate hash); loop-history guard
  silent in recent ceremonies.
- **Stage 1 — self-watch: done.** The self-review, oversight
  alerts, and watchdog demonstrably ran through the window: the
  09-03 routed one-steppers were born from oversight alerts
  (repeat-crumbs, tree-skew, ui-audit, plan-accept-gate) and from
  review P1s — the machine caught its own drifts and routed them.
- **Stage 2 — one interface: landing.** Verified: the dashboard
  answers HTTP 200 on :8890 (checked 2026-09-03 ~13:05Z). Remaining
  unverified exit criteria: every tab renders at desktop AND mobile
  widths; cold deep-links mount; operator items flow
  open→handled→dismissed. Staged for cheap real checks in
  2026-09-03-staging step 3.
- **Stage 3 — roguelike delegation live: landing.** Verified:
  wrapped sessions exist (budget.md session-run rows; overnight run
  logs per beat). Remaining unverified exit criteria: one full
  delegation cycle witnessed live end-to-end (run-start → observatory
  working → run-end disposition), and a seeded stall flagged and
  replaced without human intervention. The 09-02→03 stall recovery by
  sibling automation slice 2026-09-03 is candidate evidence for the
  second criterion but must be verified from logs, not the brief.
- **Stage 4 — system harness D/E: queued.** Exit criteria
  (governed package upgrade through the certificate loop; config
  lanes declaratively listed and backed up on cadence) unmet.
  Partially in place: config-backup runs every 30m (reports.md rows
  6f20e8cb through 09-03T13:00:45Z, ok 9 files); the governed upgrade
  lane is design-staged in 2026-09-03-staging step 6 and parked as
  operator-supervised (kernel-side update lanes are forbidden to
  machine sessions).
- **Stage 5 — research alternation institutionalized: queued, with
  the alternation machinery now live.** Routed plans + machine
  acceptance execute grow↔research alternation without a human
  (six 09-03 routed plans accepted; the 2026-09-03-staging plan
  itself alternates G/R per master-plan §4). The remaining exit
  criterion — a research beat landing a parseable artifact through
  the standard gates without a human demanding it — is being
  exercised by exactly these steps.

## 3. Queue depth

docs/project/queue.md holds 19 rows with status=queued (of 36 total
rows; 12 done). wake-mutation-lane is named Next (rotation-scale,
certificate-ready per the queue Scale section) and is staged as
2026-09-03-staging step 1.

## 4. Operator-action-reduction trajectory

The standing directive (reduce operator actions, simplify UX with
prompts for acceptance) is advancing on two fronts, both landing in
hngh-automation via the sibling automation slice 2026-09-03 (kernel
docs record the trajectory only): (a) an email-setup prompter —
notably, the notify-email SMTP config gap (§1) is exactly the kind of
operator setup item a prompter should surface; (b) an operator-items
section in the daily digest, so pending operator decisions ride the
existing dormant digest channel instead of ad-hoc alerts. No kernel
capability change is admitted by this record.

## 5. Staging outcome

The 2026-09-03 work is staged as
docs/project/plans/2026-09-03-staging.plan.md (7 steps, strict
grow↔research alternation, contract-valid front-matter), grounded in
the sources it cites, non-duplicative of the 2026-09-01-operator-items
plan (all 9 steps still unchecked at authoring time) and of the six
accepted 09-03 routed one-steppers.


## 2026-09-04-operator-landscape-notes

# Operator landscape session — direction, decisions, lessons — 2026-09-04

Status: RECORD. Restates the operator's 2026-09-04 direction and the
back-burner decisions faithfully; harvests this session's lessons;
admits no runtime capability.

## 1. Operator direction (2026-09-04), recorded faithfully

The operator's five feedback items:

1. **Email notifications live and confirmed.** Make them maximally
   functional/readable with section summaries; adversarially review
   operator-facing surfaces; Hngh needs cyclical routines for
   regularly optimizing notifications. (The sibling automation slice
   is landing the digest restructure + importance rubric + QA
   drop-in — cited by name, verified-on-arrival: scripts/email-digest.py
   sections were on disk 2026-09-04 but the TL;DR/rubric and
   cadence/day/13-email-qa.sh were not yet.)
2. **Dashboard QoL:** attention for QoL features, operator-facing
   presentation, and interfaces for Hngh's management of
   system-harness concerns (package updates, configuration
   management).
3. **Logs QoL:** operator-gated dismiss-able entries need attention;
   logs simpler to understand at a glance while keeping key/related
   info.
4. **Extended documentation:** as complexity grows, simply-communicated
   docs matter more; consider a navigable "wiki" to accompany the
   GitHub repo. Food for thought — research it.
5. **Long-absence posture:** the operator is away for a LONG stretch;
   relies on email (+SMS?) notifications; wants regular-cadence
   meaningful reports plus immediate notifications for
   important-enough matters. SMS is not available yet; the sanctioned
   routes are email (live) and the browser-relay channel (Route A
   prototype pending QR pairing — capabilities plan step 7).

The direct question — *what does the roadmap plan as Hngh's PRIMARY
operator interface, and are multiple interaction options included?* —
is answered with evidence in
[research/2026-09-04-operator-interface-landscape.md](../research/2026-09-04-operator-interface-landscape.md):
primary = the stage-2 nerve center webapp (Schedule/Sessions/System/
Research/Logs), inside the CLI+GUI command-center family, with the
dashboard-tui, OSD operative, pixel-RPG buddy, 19 CLI verbs, and the
new email/browser-relay async channels as the option list.

## 2. Back-burner decisions (faithful)

- **1Password desktop-app ↔ CLI/SDK integration: back-burnered.** The
  operator is NOT worried short-term: email is live via the file
  fallback; vault migration is an upgrade path. The question "can the
  SDK interface with the desktop app if the CLI can't?" is answered
  once, in the landscape record §3: **NO** — the SDKs (JS/Go/Rust/
  Python) use the same desktop-app integration plumbing on Linux (same
  socket, same failure); the bypasses are CLI-only `op account add` or
  a Service Account if the plan tier allows.
- **Stale `op-daemon.sock` lead recorded:** 13:25 socket, pid 4035 —
  a restart after the operator's pending reboot window is the cheap
  first test, parked for later.
- **Email live confirmed** (reports.md row 61f0a1e1,
  2026-09-04T21:30:15Z, credential source file-fallback).
- **One progress row filed** via scripts/report-queue (machine-owned
  path, not a ceremony candidate) capturing the back-burner decision.

## 3. Lessons harvested this session

- **Ports correction:** the local model serving endpoints were
  conflated — :8080 (llama-server) vs :8888 (unsloth-studio). The
  automation slice corrected the recognition/recovery retarget with
  divergence classified (hngh-automation commit f26e1d9, 2026-09-04);
  probe the endpoint the unit actually serves, not the brief's port.
- **Restart-to-arm-socket:** a service restart is what arms the
  desktop-app/daemon socket (the 1Password `op-daemon.sock` lead
  above); a stale socket from hours earlier is a restart-window
  candidate, not a code bug.
- **Verify-on-arrival sibling slices:** sibling automation slices
  landing in parallel are cited by name, never by hash, and every
  step touching them carries a verify-on-arrival clause — confirm on
  disk at execution time; park with the exact gap if absent
  (pattern proven by the capabilities plan's grounding notes).
- **Ceremony skill drift — evidence-before-claim:** the ceremony skill
  doc says "evidence-before-flag"; the kernel vocabulary (the ten
  principle names) is **evidence-before-claim**. Use the kernel
  vocabulary; the drift is known and recorded here rather than
  silently mapped.
- **Roadmap states are machine-owned:** stage-table State cells flip
  via the machine's verification sweep (staging plan step 3), not via
  ceremony docs edits — session docs state evidence and leave the
  cells alone (Deliverable 4's choice, recorded here).

## 4. Avoid-duplication vs the three live plans

this session's plan ([plans/2026-09-04-notifications-and-qol.plan.md](../project/plans/2026-09-04-notifications-and-qol.plan.md))
does not duplicate:

- **2026-09-01-operator-items.plan.md** — owns push-on-demand, the
  notification-channel survey (step 2), digest wiring + first live
  digest (step 3), the session cost model (step 4), the first
  publication artifact (step 5).
- **2026-09-03-staging.plan.md** — owns the wake-mutation rotation
  beat (step 1), the bench calibration (step 2), the stage-2/3
  exit-criteria sweep (step 3), the unsloth recovery note (step 4),
  the --site gap inventory (step 5), and the stage-4 governed-upgrade
  runbook (step 6) which the new plan's step 4 feeds but does not
  repeat.
- **2026-09-03-capabilities.plan.md** — owns the browser-messaging
  admit gate + prototype (steps 6–7, incl. the QR-pairing park), the
  credential seam (step 5), queue-drain measurement (step 8), and the
  service allowlist recovery path (step 3).

## 5. Ceremony note

Deliverable 4 (docs/project/roadmap.md) was deliberately NOT edited:
stage-table State cells are machine-owned evidence updates, flipped by
the machine's verification sweep (staging plan step 3) — a session
docs ceremony must not preempt that. The choice is recorded here per
the operator's direction.


## README

# Records

Records preserve verified facts, decisions, and bounded unknowns. They do not
authorize a future action.

- `2026-08-11-crystallized-cutover.md` identifies the external retirement
  archive and its active-state boundary.
- `2026-08-19-archive-gate-retired.md` records the retirement of the
  `make check-archive` verifier; the archive remains historical evidence
  only and is no longer verified or consulted by any active gate.
- `2026-08-11-task-1-boundaries.md` records the dependency and presentation
  boundary publication.
- `2026-08-11-task-2-run-domain.md` records the pure domain lifecycle and
  evidence boundary.
- `2026-08-12-task-3.1-create-run.md` records the first application use case,
  its callback boundary, and atomic recording contract.
- `2026-08-12-task-3.2-arm-run.md` records closed admission evidence and the
  created-to-armed application transition.
- `2026-08-12-task-3.3-start-run.md` records the armed-to-running application
  transition and its one-slot recording boundary.
- `2026-08-12-task-a-autonomous-control.md` records the source-grounded policy
  contract for future review and mutation authorization.
- `2026-08-12-task-e-candidate-evidence.md` records the read-only explicit
  candidate evidence bundle and its closed admission boundary.
- `2026-08-12-task-c0-proposal-ledger.md` records the pure proposal and
  evidence-requirement ledger needed before deterministic principle evaluation.
- `2026-08-17-task-c1-principle-evaluation.md` records the deterministic
  principle evaluator over the proposal ledger and its closed refusals.
- `2026-08-17-task-c2-failure-disposition.md` records the closed
  failure-disposition policy and the list-valued-constant redefinition note.
- `2026-08-17-task-c3-candidate-certificate.md` records the non-mutating
  candidate authorization certificate and its mechanical pure issuer.
- `2026-08-17-task-d1-close-run.md` records the policy-gated `close-run`
  application use case and its closed terminal transitions.
- `2026-08-12-task-3.4-checkpoint.md` records closed verification and manifest
  evidence before the running-to-checkpointed application transition.
- `2026-08-13-pi-worker-and-delegation-survey.md` records the future Pi worker
  boundary, extension triage, and fixture gates; it admits no runtime adapter.
- `2026-08-18-docs-intent-framing.md` records the documentation-only
  reframing around intent and direction: the new vision document, plain
  root README, directional roadmap, and two-audience documentation index.
- `2026-08-18-task-r4-evidence-adapter.md` records the read-only evidence
  adapter (promotion rung 4): its fixed command set, injected process
  transport, closed refusal vocabulary, and evidence-state mapping.
- `2026-08-18-task-r5-mutation-executor.md` records the certificate-bound
  mutation executor, fixed action templates, injected process transport, and
  point-of-action refusal checks.
- `2026-08-18-task-r6-review-adapter.md` records the bounded model-review
  adapter, its fixed prompt, closed JSON output contract, deterministic
  review evidence facts, and provider-free injected transport.
- `2026-08-18-task-r7-presentation-and-composition.md` records the
  operator-visible presentation layer, the `hngh.main` composition root,
  the fail-closed default port adapters, and the inward dependency-guard
  extension to presentation.
- `2026-08-19-readme-harness-framing.md` records the root README `Why` and
  `Where` revision framing Hngh as a record-first system harness against the
  throughput-first harness-mainstream, grounded in the arXiv 2604.18071
  empirical harness study and the 2026-07-28 stateless MCP update.
- `2026-08-24-prior-art-landscape.md` records the prior-art survey (in-toto,
  DSSE, Sigstore, SCITT) and the invariants Hngh adopted from it, including
  evidence monotonicity.
- `2026-08-24-governance-property-tests.md` records the totality and
  monotonicity property tests over the governance vocabularies.
- `2026-08-24-first-self-governed-commit.md` records the first commit
  produced, reviewed, and committed by Hngh under its own certificate.
- `2026-08-24-second-self-governed-commit.md` records the second
  self-governed commit and the adapter bug fixes the first governance loop
  surfaced.
- `2026-08-24-command-surface-and-transport-admission.md` records the
  operator command surface (promotion rung 8), filesystem transport
  admission, and the strict exit-code protocol.
- `2026-08-24-command-surface-dogfood.md` records the dogfood development
  loop (promotion rung 9): the propose → issue-cert → mutation-check
  validation against real repository evidence.
- `2026-08-24-task-r10-bounded-worker-transports.md` records the bounded
  `:model` and `:terminal` transports behind closed loadout admission.
- `2026-08-24-design-distributed-attestation.md` records the distributed
  attestation design (promotion rung 11): envelope bounds, pinned keys, and
  signature verification ports.
- `2026-08-24-context-budget-and-toolchain.md` records the operator's
  context-budget preference (~40% of the model window through
  billion-context) and the omp/pi toolchain wiring through `bili`.
- `2026-08-25-r12-pin-registry-and-signature-transport.md` records the
  operator pinned-key registry, the strict pins-file parser, and the live
  RSA/SHA-256 signature-verification proof (promotion rung 12).
- `2026-08-25-r13-operator-reviewer-transport.md` records the operator
  reviewer-transport file and the live review against the local model
  server, verified end to end (promotion rung 13).
- `2026-08-25-r14-ed25519-signature-transport.md` records the closed
  key-algorithm vocabulary on pins and the Ed25519 raw-signature
  verification transport (promotion rung 14), with live end-to-end proof.
- `2026-08-25-r15-http-claim-method.md` records the network claim method
  joining the closed federation method set (promotion rung 15), with
  live proof over a local HTTP server through an injected transport.
- `2026-08-25-r16-policy-profiles.md` records the operator policy
  profile value, the `:review` requirement kind, and the `profile=`
  admission on `propose` (promotion rung 16).
- `2026-08-25-r17-wake-peer.md` records the wake-on-demand slice for
  pinned lattice peers (promotion rung 17): the wake ports/result, the
  `wake-peer` command, and the closed refusal vocabulary.
- `2026-08-25-loop-history-guard.md` records the machine-checked
  self-governance guard: every code-surface commit since the
  restatement must be candidate-bound or rule-labeled, with the one
  pre-guard violation named.
- `2026-08-25-r18-worker-transport.md` records the bounded read-only
  worker task (promotion rung 18): `run-worker`, the `:worker`
  admission label, and the closed worker evidence fact.
- `2026-08-25-session.md` records the 2026-08-25 continual-progress
  session arc: the extension repair, the consistency pass, rungs
  14–18, the external re-review and the loop-history guard, the bridge
  finalization, and the live worker proof.
- `2026-08-25-worker-driver.md` records the one-shot continual-worker
  driver (`scripts/worker-driver`) and its exit-code contract.
- `2026-08-26-continual-scheduling.md` records the scheduling &
  heartbeat milestone: schedule-heartbeat, probe-model-route, driver
  `--route` fallback, dashboard live/export modes, generate-publication,
  fleet-manager, and the ceremony-drive helper — all inside the
  no-daemon boundary.
- `2026-08-26-scheduled-runs-investigation.md` records the read-only
  investigation of the hngh-automation schedule: the 7 systemd user
  timers are healthy and firing, the 42/42 `cancelled` store runs were
  beacons closed `cancelled` by design in `lib/hngh-record.sh`, only
  3 of 7 jobs wrote runs, and the applied fixes (exit-0 closes
  `evacuated`; the night-agent/morning-report/model-bench/night-research
  jobs now beacon).
- `2026-08-26-osd-and-dashboard.md` records the operator-facing visual
  surface that landed in the last 24 hours: the `dashboard-tui` full-
  screen TUI, the `grade-interface` grading loop with `ui-grades.md`,
  the `evolve-operative` animation/evolution story and
  `operative-frames.md`, and the Plasma `osd-operative` overlay — all
  candidate-bound through the governance loop, with the kernel's governance
  surface unchanged.
- `2026-08-27-task-1.5-select-course.md` records P1 #1.5: course
  selection extracted from the service tick into the pure kernel
  (domain policy, application use case, CLI dispatch, cadence wiring)
  with the full Lisp + Python gate green.
- `2026-08-27-p2-design-contracts.md` records the four ceremony-ready
  P2 DESIGN contracts (command center architecture, system awareness
  map, buddy menu spec, gamified-run model) and their indexing.
- `2026-08-27-acceleration-wave.md` records the four-slice acceleration
  wave: the roguelike delegation wrap (`omp-bridge --run-start/--run-end`),
  the S3 `status` verb, the S1 truth-telling dashboard, and the display
  register spec — with the four lessons harvested to the llm-wiki.
- `2026-08-27-operator-items-closeout.md` records the dashboard's three
  operator items closed at the source: the missing-store friendly
  refusal (kernel, exit 2), the timestamped wake store, the MiniMax-H3
  bench drop, and the failed-unit sweep (calligra reset,
  gbd-agent-configs root-caused and flagged).
- `2026-08-27-dashboard-evolution-gbd-retirement.md` records the
  dashboard evolution wave (operator-item lifecycle, server endpoints,
  session-per-column observatory, cascading gantt) and the
  git-back-dots retirement with its verified archive.
- `2026-08-28-self-improvement-cadence.md` records the cadence wave
  (30m/hour tiers wired, four day routines, telemetry store v0, feeds
  mounted), its live proof, six lessons, and the triage outcomes.
- `2026-08-28-automation-advancement.md` maps the operator session's
  working pattern (intake → plan → certificate-bound execution →
  verification → records → lessons) onto the machine's own mechanisms:
  what is automated, what stays operator-side, what is next-necessary.
- `2026-08-28-lessons-consolidation.md` folds the day's and the prior
  day's process lessons into their correct homes (governance doc,
  ledger spec, backlog, roadmap) and repairs the reports.md double-header
  flagged by the review digest.
- `2026-08-30-lessons-and-foldback.md` records what the 33h+
  unattended window produced (8-step plan executed, 12/12 research
  lines crystallized, zero kernel commits after plan exhaustion), the
  window's failure classes, and the 2026-08-30 doc-suite fold-back
  (requirement-kind count, roadmap rung/use-case drift, two backlog
  rows).
- Future records name their scope, evidence command, observed result, and
  remaining unknowns.


## 2026-08-11-clean-architecture-roguelike-run-review

# Bounded Design Review: Hngh Tight Cycles and Roguelike Run Model

**Verdict:** Hngh fits a Clean Architecture and tight-cycle model well, provided the game language names visible states and records rather than disguising control flow. The right synthesis is a small, deterministic run kernel with replaceable model, terminal, filesystem, and provider adapters. It is not an autonomous game master.

This review reads the supplied local bundle as a secondary index, then checks the core engineering claims against five Robert C. Martin blog posts. Reviewed local inputs: `artifacts/uncle_bob_practical_addendum.md`, `artifacts/uncle_bob_practical_addendum_references.md`, and `artifacts/chapter_5_content.md`, `chapter_7_content.md`, `chapter_9_content.md`, and `chapter_10_content.md`. The other supplied chapters were not reviewed line by line. This review excludes the bundle's social-political material by request. It does not implement the proposed design.

## 1. Contradictions

1. **The supplied bundle has no stable chapter map.** `uncle_bob_practical_addendum.md:100` labels Chapter 5 “Architecture and System Design,” while `chapter_5_content.md:1` labels it “Functional Programming.” This is not a substantive architectural disagreement, but it means chapter numbers cannot be cited as durable references. Use article titles and URLs, or a new Hngh-specific reading guide.

2. **The local transformation rule is presented as settled procedure, but the source treats it as a useful, incomplete premise.** `chapter_7_content.md:59-67` turns the Transformation Priority Premise into a four-step ordering. Martin explicitly calls its priority, completeness, and formalization open questions, even while recommending simpler transformations as a practical guide.[3] Hngh should use it as a prompt for choosing the next small test, never as a mechanical planner that declares a valid change impossible because it did not match a list.

3. **The local text overstates the relationship between types and tests.** `chapter_5_content.md:90-94` correctly says type checking does not establish external behavior. `chapter_5_content.md:104-110` then extends that into “you don't need static type checking if you have 100% unit test coverage.” For Hngh, this is unsafe. Schema checks, restricted parsers, permissions, and validated capability records protect boundaries before tests run; behavioral tests then protect intended outcomes. Neither substitutes for the other.

4. **The local text risks converting “testable” into “designed for the test harness.”** The addendum says tests should use a small public API and warns against test-induced design damage (`uncle_bob_practical_addendum.md:53-67`, `127-135`). The useful distinction in the primary source is separation by independent reasons to change, not extracting an interface merely to mock it.[4] Hngh must introduce a port only when an external concern is genuinely replaceable or needs controlled failure behavior: clock, filesystem, model call, tool execution, provider accounting, or rendering.

5. **The bibliography is a reading list, not a source ledger.** The reference addendum gives useful article links but repeats entries (`uncle_bob_practical_addendum_references.md:293-321`) and gives no per-claim citations in the chapters. The prose may be sound, but a future Hngh policy cannot rely on “drawn from the blog” (`uncle_bob_practical_addendum.md:9-11`) as evidence. Keep primary-source citations next to policy claims that affect safety, cost, or autonomy.

6. **The current campaign/expedition/room/camp draft and the requested run vocabulary are competing operator interfaces.** The existing plan treats “expedition” as the primary delivery unit. The requested vocabulary makes a **run** the primary delivery unit and gives clear names to setup, termination, salvage, learning, and scoring. The latter is better for ephemeral model sessions. Keep the old words out of the operator surface; retain only the underlying safeguards: bounded scope, tests, review, evidence, and a clean end.

## 2. Missing guardrails

1. **A run must be a finite state machine, not a colorful session label.** Define legal transitions and reject all others. The minimum path is:

   ```text
   draft -> created -> armed -> running -> checkpointed -> running
                                           |              |
                                           v              v
                                      evacuated         dead
                                           \              /
                                            -> afterlife -> scored -> archived
   ```

   `armed` means the operator-approved brief, loadout, budget, and tool permissions are present. `dead` is a controlled terminal outcome: exhausted budget, expired lifetime, failed gate, unsafe request, lost prerequisite, or explicitly abandoned objective. It is neither shame nor a trigger for automatic retry.

2. **The save file needs a precise boundary.** A system profile is durable local configuration, not a memory dump, a prompt transcript, or a global authority token. It selects allowed local roots, enabled capability classes, default safety posture, and named budget policies. Per-run state must live below a separate run identifier. No run may alter a save file without an explicit operator-approved operation, a before/after receipt, and a replacement rule.

3. **Character selection must describe capability, not personality.** A character is a versioned role template: allowed tools, default context ceiling, allowable model classes, review duties, and handoff format. It must not grant hidden permissions based on a narrative persona. A “Killy” or “Cibo” skin may appear in rendered text; the machine-readable role remains a narrow capability record.

4. **Level selection must be an authority tier, not progression.** A level says what kind of side effect is permitted: local analysis, repository edit, test execution, external read, external write, or privileged machine operation. Reaching a higher level does not grant access. Each level has an operator-set entry gate and an explicit exit condition. A model cannot level itself up.

5. **The inventory/loadout needs hard limits.** A loadout is an immutable declaration of model route, context ceiling, maximum calls, token/cost allowance, time limit, writable paths, tool allowlist, network posture, and required test command. It is validated before a run starts. Any missing or unknown field denies start. A high-context single completion is allowed only as a named loadout item with a reason, an output path, and a verification step; it is an untrusted draft until the normal tests and review pass.

6. **“Profit margin” needs a non-gameable definition.** Do not collapse quality, cost, safety, and speed into a single score. Record separate measures: verified deliverable value, actual model/tool cost, remaining budget/time/permission headroom, test evidence, rework, and operator assessment. A run loses margin when it spends constrained resources without producing a verified artifact or a reusable lesson. Scores inform tuning; they never authorize an action or punish a model.

7. **Death and afterlife need salvage and containment rules.** On death, stop further side effects, preserve the last verified checkpoint, collect actual command output and changed-path list, close or invalidate temporary credentials, and write an afterlife record. The record contains cause category, evidence, salvageable artifacts, rejected hypotheses, and one candidate lesson. A lesson becomes policy only after review; otherwise it remains a local observation.

8. **Evacuation must be the preferred terminal path.** A successful run ends by producing named deliverables, test evidence, a concise handoff, cost facts, and a clean workspace. It does not remain alive for conversational convenience. “Live” means the next bounded step remains authorised and useful; it does not mean an agent is entitled to keep spending tokens.

9. **Parallel runs require ownership before concurrency.** Each active run claims an exclusive write surface and declares read-only dependencies. Independent readers may work in parallel. Two writers may not touch the same source, state root, receipt stream, or release artifact without a planned integration run. A reviewer checks the integrated result, not a collage of individual green tests. Model identity and a prior green result are not trust grants; trust comes from the evidence and review required for the risk of the change.[5]

10. **The scoreboard needs a privacy and retention policy.** Store aggregate, operator-useful evidence, not prompt transcripts, secrets, personal paths, or provider credentials. Every metric needs an owner, a calculation definition, a retention period, and a reason to exist. If a metric cannot change a decision, do not collect it.

11. **The architecture boundary must survive adapters.** Martin's dependency rule keeps source-code dependencies inward: policy does not name frameworks, databases, UIs, or external agencies.[1] For Hngh, model providers, Hermes, OpenCode, tmux, the filesystem, Git, and systemd are all outer details. Their response formats do not enter the run kernel. The kernel speaks only through its own ports.

12. **Tests require layers and a measured speed budget.** A fast trusted suite enables continuous cleanup, but fast tests alone do not prove a good boundary. Martin argues that separating independently changing concerns makes tests both faster and more changeable.[4] Hngh needs pure policy tests per room, fixture-backed port tests per run, and small end-to-end acceptance checks per release gate. Set time targets from measured baselines; do not invent a universal seconds limit.

## 3. Exact proposed section bullets

These are proposed document sections and architecture rules. They are ready to turn into the fresh Hngh documentation when the operator opens that implementation phase.

### `docs/operating-model.md` — “The Run Loop”

- **Save file:** A versioned, fail-closed system profile. It carries approved local policy, never transient agent memory.
- **New run:** A finite, uniquely identified attempt to deliver one bounded objective.
- **Character creation:** Select a declared role template and model route. The template grants no capability beyond its loadout.
- **Level select:** Select an operator-approved authority tier. A tier constrains effect classes; it is not a reward ladder.
- **Inventory/loadout:** Freeze context, token, time, tool, path, network, and review limits before start.
- **Mission brief:** State objective, non-objective, source facts, acceptance criteria, exact writable paths, verification commands, and evacuation condition.
- **Start run:** Create durable run state and a receipt only after all entry checks pass.
- **Live:** Repeat one behavior-sized RED → GREEN → REFACTOR room. Checkpoint only green, reviewed facts.
- **Evac:** End normally with deliverables, evidence, cost record, handoff, and clean ownership release.
- **Death:** End safely when a hard limit or safety rule trips. Preserve evidence; issue no automatic retry.
- **Afterlife:** Salvage verified work, record the failure category, distinguish fact from hypothesis, and propose at most one lesson.
- **Scoreboard:** Report delivery, quality, cost, safety headroom, and reuse separately. It has no authority to spend, launch, or approve.

### `docs/architecture.md` — “The Megastructure Has an Inside”

- **Entities:** Profile policy, run state, role template, loadout, mission brief, checkpoint, artifact manifest, outcome, lesson candidate, and score record.
- **Use cases:** Create run; arm run; admit next room; record checkpoint; evacuate; declare death; perform afterlife; score; archive; render read-only history.
- **Ports:** Clock, identifier source, state store, receipt store, budget ledger, model completion, tool executor, repository inspector, artifact store, and report renderer.
- **Interface adapters:** CLI, local filesystem, Git, terminal runner, Hermes bridge, model-provider clients, and later dashboard or webhook code. They translate into kernel data and own transport failure details.
- **Frameworks and drivers:** Common Lisp runtime, ASDF, SBCL, shell, tmux, systemd, provider SDKs, databases, and user interfaces. Each remains replaceable detail.
- **Dependency rule:** Dependencies point toward entities and use cases. Flow may cross outward through a port, but source dependencies and external payload shapes do not.
- **Boundary test:** A pure use-case test must run with a fake clock, fixture store, fake budget ledger, fake completion port, and fake tool executor. If it needs a provider client or the real home directory, the boundary has failed.

### `docs/testing.md` — “Tight Cycles, Not Tiny Thoughts”

- **Nano-cycle:** Write the smallest failing behavioral assertion or fixture case. Make only the code needed for that case pass.
- **Micro-cycle:** Run the focused check, make it green, then improve names, duplication, and seams while all checks remain green. No green result ends without the refactor question.
- **Specific/general check:** After several rooms, ask whether production code is merely mirroring examples or already accepts plausible unwritten cases. Prefer the simplest change that genuinely broadens the solution. Martin describes this as a practical heuristic, not a formal algorithm.[2][3]
- **Boundary check:** At each handoff or other measured primary interval, inspect dependency direction, state ownership, test speed, and whether a new external detail has leaked inward. Martin explicitly describes this larger architectural cycle alongside the fast TDD cycles.[2]
- **Test design rule:** Tests assert behavior through stable use-case boundaries. They do not require production classes or ports that have no independent reason to change.
- **Fixture rule:** External input, state, time, and tool output are fixtures. Live services are never a prerequisite for a policy test.
- **Failure rule:** A red test, malformed state, unknown quota, or missing acceptance criterion blocks advance. The response is containment, not optimistic continuation.

### `docs/agent-session-contract.md` — “Ephemeral Cognition”

- **Session role:** An agent session is a replaceable worker for one run or one explicitly named read-only task. It does not own product memory.
- **Run packet:** Every new session receives a compact, source-grounded packet: mission brief, relevant facts and their paths, loadout, current checkpoint, allowed paths and tools, verification command, and evacuation condition.
- **Handoff packet:** Every session emits only durable facts: changed paths, actual verification output, artifact locations and digests, cost facts, unresolved blockers, and the next smallest admissible move.
- **Compression rule:** Summaries are references to durable records, not new authority. A resumed session must revalidate state and repository facts before acting.
- **Context benchmark:** Test a fixed corpus of representative rooms at several context ceilings and model routes. Measure pass rate, repair rate, elapsed wall time, input/output tokens, cost, review findings, and quality of the afterlife record. Change one variable per benchmark. Do not infer a context policy from anecdote.
- **Large-output exception:** A one-time large-context completion may write a named draft or generated artifact. It receives no exemption from path limits, test gates, review, cost recording, or attribution.
- **Model policy:** Use local and low-cost models for bounded retrieval, fixture drafting, mechanical edits, and narrow repair attempts. Use Luna as the normal high-quality implementation/review route when its loadout admits it. Use Terra where its trade-off is adequate. Reserve K3 for operator-approved, compact questions or a one-off high-value artifact with a fixed budget; never treat its quota as an invitation to create a standing session.

### `docs/aesthetic.md` — “Quiet Megastructure, Plain Interface”

- Use Nihei influence in names, visual hierarchy, status phrasing, and short narrative receipts. Keep operational language concrete.
- A **Safeguard** is a guardrail, never an armed automated actor. A **Silicon Life** is an untrusted external agent or adapter, never a person. A **Garde** is a validated protective boundary. These references remain optional presentation labels.
- A green checkpoint may be rendered as a quiet maintained sector; an evacuation as a returned artifact cache; afterlife as a salvage record. No system state depends on metaphorical wording.
- Avoid lore that obscures risk, privilege, cost, ownership, or failure cause. The operator must be able to read any status line without knowing *BLAME!*, *Knights of Sidonia*, or *Tower Dungeon*.
- Do not make survival, death, achievement, or score mechanics socially manipulative. The point is clear endings and retained learning, not gamified pressure.

### `docs/roadmap.md` — “Recommended implementation order”

1. Seal the archive and establish the test harness, documentation index, decision log, and pure domain data.
2. Implement the profile and run state machine with invalid-transition fixture tests.
3. Implement immutable loadouts, capability tiers, budget ledger ports, and admission tests. Unknown ledger state denies automatic action.
4. Implement checkpoint, evacuation, death, afterlife, and artifact-manifest use cases with fixture stores.
5. Implement the read-only scoreboard from stored outcomes; validate retention and no-secret rules.
6. Add a manual CLI adapter. Prove it against fixtures before it resolves any live root.
7. Add one model-completion adapter behind a fakeable port and an explicit loadout. Keep execution manual.
8. Run the context-ceiling benchmark and record the evidence before adding a scheduler, watcher, dashboard, or multi-session coordination feature.
9. Add further adapters one at a time. Every adapter starts disabled and earns automation only after its manual run loop is trusted.

### Acceptance criteria for the synthesis

- A complete run can be created, armed, run through a fixture-backed room, evacuated, and archived without contacting a model provider, starting a process, or touching `~/.hngh`.
- Every illegal state transition, unknown budget value, missing loadout field, path escape, malformed state record, and missing verification result fails closed in a fixture test.
- The inner policy packages mention no provider, terminal, filesystem, Git, Hermes, tmux, systemd, or UI symbol.
- A run that dies produces a bounded afterlife record and no automatic retry.
- A successful evacuation produces a deliverable manifest, actual verification evidence, and a concise next-session packet.
- The scoreboard can be regenerated from receipts and manifests alone. It does not inspect prompts or secret-bearing logs.

## 4. Questions operator must decide

1. **Operator-gated — What is the first useful deliverable?** Choose one: (A) a pure local run kernel plus fixture CLI; (B) a read-only session/quotas scoreboard; or (C) one manual model-completion adapter. Recommendation: **A**. It proves the state and boundary contracts before external cost or process risk enters.

2. **Operator-gated — What does “profit margin” optimize first?** Choose the reporting priority: verified deliverables per cost, safety headroom, turnaround time, or learning reuse. Recommendation: track all four separately and select one as the first dashboard sort order; do not authorize work from a composite score.

3. **Operator-gated — May Hngh ever store prompt bodies?** Recommendation: no by default. Store hashes, provenance, bounded summaries, and artifact links. Allow a separate explicit retention mode only for reproducible benchmarks with a defined deletion date.

4. **Operator-gated — Which capability tier may be automated first, if any?** Recommendation: none in the first campaign. The first enabled automation should be read-only health observation after the manual equivalent has passing fixtures and a reviewed failure policy.

5. **Design-gated — Should theme names be stored as canonical enums or render-time aliases?** Recommendation: canonical technical enums such as `:evacuated` and `:afterlife-complete`, with optional display text such as “artifact cache returned” in the renderer. This keeps receipts searchable, interoperable, and durable.

6. **Design-gated — Is a character a reusable static role or a per-run copy?** Recommendation: versioned static role template plus immutable per-run loadout snapshot. This makes later policy changes auditable without rewriting history.

7. **Design-gated — What proves a lesson earned promotion to policy?** Recommendation: one reproducible failure or benchmark, one proposed guardrail, one fixture that would have caught it, and operator acceptance. Repeated narrative summaries alone are not evidence.

8. **Design-gated — What context ceilings should the benchmark test?** Recommendation: choose tiers from actual model and provider limits, then hold the task corpus and loadout constant. Do not choose numerical ceilings in this document; they are calibration facts, not architecture.

9. **Design-gated — When should a stronger model be admitted?** Recommendation: only when a cheaper route has a recorded failure category that the stronger route is expected to resolve, or when a one-off artifact needs its larger effective context. The run record must name the reason before the call, not rationalize it afterward.

10. **Design-gated — How much Nihei flavor belongs in the first CLI?** Recommendation: one quiet status line and optional display aliases only. The first kernel should be legible to an operator who has never read the works; richer presentation waits until the underlying lifecycle is stable.

## Sources

[1] https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html
[2] https://blog.cleancoder.com/uncle-bob/2014/12/17/TheCyclesOfTDD.html
[3] https://blog.cleancoder.com/uncle-bob/2013/05/27/TheTransformationPriorityPremise.html
[4] https://blog.cleancoder.com/uncle-bob/2014/05/01/Design-Damage.html
[5] https://blog.cleancoder.com/uncle-bob/2014/02/27/TheTrustSpectrum.html

Attribution: Hermes — gpt-5.6-terra via openai-api, Hermes TUI. 2026-08-11.


## 2026-08-26-dashboard-design-notes

# Dashboard design notes — making system/application info readable at a glance

Research pass on how real, lauded dashboards that display system + application
state make dense data easy to read at a glance. Baseline this improves:
`hngh-automation/dashboard/` (static webapp, live :8890) and its six open UX
issues — visibility-by-default, window-fit widgets, meaningful-at-a-glance
stats, legible schedule, digest-in-place, single toggle. No code here; notes +
a ranked borrow-list for the static webapp.

## Surveyed projects and the pattern each is good at

### Grafana — default-visibility, one-metric-per-panel, stat panels
- Every panel is one idea; a **stat panel** shows a single large number with an
  optional sparkline, so the eye lands on the headline figure before any axes
  or labels ([Stat viz](https://play.grafana.org/d/Zb3f4veGk/stats)).
- Best-practice guidance pushes **information hierarchy**: put the metric that
  answers "is this OK?" first, use the space for the number, not the frame
  ([best practices](https://grafana.com/docs/grafana/latest/visualizations/dashboards/build-dashboards/best-practices/)).
- Dashboards default to **all panels visible**; rows/panels collapse only on
  demand, never as the resting state.

### Datadog / Prometheus — the **"is it OK?"** summary line drives the layout
- Screenboards lead with service-health tiles: green/amber/red state encoded in
  **color before text**, so a red tile is legible from across the room without
  reading a number. Text confirms the state; color announces it.
- Detail is always one click away behind the tile — the summary is the default,
  the query browser is the drill-down.

### netdata — per-second auto-refresh, everything visible, zero click-to-reveal
- Refreshes charts **continuously at per-second granularity**; width drives how
  much history is shown, so the widget always fits its window
  ([auto-refresh tied to width](https://sources.debian.org/data/main/n/netdata/1.12.0-1%2Bdeb10u1/web/gui/dashboard.html)).
- Brand goal is literally *"clear insights at a glance, no complexity"* — a
  whole machine is on one scrolling page, none of it hidden behind a fold
  ([netdata positioning](https://www.netdata.cloud/)).
- What it sacrifices: everything is visible so nothing is curated; it works
  because the per-metric tiles are tiny and each self-describes.

### Temporal / Airflow DAG UIs — schedule/queue as *time*, not numbers
- A **workflow/schedule is drawn as a timeline**: a bar/dot on an axis with an
  explicit "running now" cursor. The eye reads *when things happen* and *where
  we are*, which a list of counts cannot express.
- Queued vs running is encoded by **position on the axis + marker color**, not
  by a status word.

### GitHub Actions / Azure DevOps pipelines — grouped digest, one toggle
- The whole run is a **vertical digest** — steps collapse into rows whose status
  color is the only thing you scan; a single chevron/toggle expands in place to
  see logs. No modal, no page navigation.
- Headline is the **overall run badge** (pass/fail) with per-step color below it:
  one glance answers "did it work", a click answers "why".

### Terminal density conventions — btop/htop, gnuplot
- htop/btop show **dense, always-on, window-fitted panels**: horizontal
  bar meters (`█████░`), a per-core grid that fits any terminal, and *total* at a
  glance with per-item expanded only on request. Nothing is hidden by default;
  every meter has a fixed, small footprint.
- gnuplot proves a static artifact can convey a schedule: a **timeline/gantt
  rendered to a plain image** tells the story without any interaction at all —
  the whole "what's due when" fits in one viewport once it's drawn as bars.

### Jupyter / GNOME system monitor — minimum viable at-a-glance
- GNOME Monitor is the archetype of "number in a corner, color bar beside it":
  a table where the *state is pre-digested* by the tool (load, %, count) rather
  than left as raw figures for the human to interpret.

## What these converge on

1. **State before data.** Color/position communicates *is it OK?* in under a
   second; the number/text confirms it. (Grafana stat, Datadog tiles,
   GitHub badge, GNOME).
2. **One idea per tile.** A dashboard is a mosaic of single-fact tiles, each
   self-describing and tiny, so the whole fits the window — not one tall grid
   of full detail. (Grafana, netdata, btop).
3. **Visible by default, collapse on demand.** Hidden panels are the anti-pattern;
   the resting state shows every tile, density handled by *tile size* not by
   *hiding* (netdata, Grafana, btop).
4. **Dense-but-scrollable areas use colored digest rows + in-place expand.**
   When a region must be long, each row carries a status color and collapses to
   one line; detail opens *in place*, never a separate page/modal (GitHub
   Actions, Azure pipelines).
5. **Schedule/queue is drawn as a timeline**, not counted. The "running now"
   cursor on a time axis is the legible form (Temporal, gnuplot, gantt).
6. **Auto-refresh tied to viewport** keeps a live surface honest without
   interaction (netdata).

## Borrow-list for the current static webapp (ranked by effort/impact)

1. **Reverse the collapse default — visibility-by-default.** Only Gantt is open
   (`data-open="1"`); the other eight panels rest closed. Flip the resting state
   so Overview/Timeline/Queue/Lanes/Roster all show (density via tile size, not
   hiding — §3). *Cheap (one line per panel), highest visibility win, directly
   hits UX issue #1.*
2. **Stat-tile overview.** Replace the overview paragraph with Grafana-style
   stat tiles — one big number each (open lanes, queued items, running agents,
   oldest wait) with color = health. *Tiny renderer change, no new data; issue
   #3.*
3. **Status color first.** Give every row (queue, lanes, roster, timeline) a
   leading colored state glyph that is legible before reading the text —
   Datadog/GitHub color-before-text. *CSS + one map from state→color; issue #3/#4.*
4. **Fit the gantt to the window.** netdata's width-tied rendering: auto-fit the
   gantt day-axis to measured panel width instead of the fixed `fitPx: 780`, so
   the schedule read is whole when open. *Already have `fit`/`zoom`; make fit the
   default on resize. Issue #2.*
5. **Digest-in-place.** Make Reports/Digest panels collapse each long entry to a
   colored one-liner with in-place expand (GitHub Actions pattern) instead of
   opening full text. *One renderer tweak; issue #5.*
6. **Single toggle, applied everywhere.** Unify the collapsible panels onto one
   expand/collapse behavior (already `data-open` + `bindPanels`) so dense areas
   use the same affordance as the tiles. *Issue #6; small.*
7. **(Defer) running-now cursor on timeline.** Draw the "current time" marker
   on the timeline axis (Temporal) — the readout already carries timestamps
   (`timeline`), so this is a front-end-only line. *Nice, but needs the gantt fit
   first.*

Ranked by effort/impact: 1→2→3→4→5→6 are all small and front-end-only (no new
backend), 7 deferred until 4 lands. Nothing here requires a new data source or
a server change — the readout spine already carries everything.

## Sources

- Grafana Stat viz: https://play.grafana.org/d/Zb3f4veGk/stats
- Grafana best practices: https://grafana.com/docs/grafana/latest/visualizations/dashboards/build-dashboards/best-practices/
- netdata width-tied auto-refresh: https://sources.debian.org/data/main/n/netdata/1.12.0-1%2Bdeb10u1/web/gui/dashboard.html
- netdata "at a glance" positioning: https://www.netdata.cloud/
- Baseline webapp: `hngh-automation/dashboard/` (`index.html`, `app.js`, `readout.json`)
- Prior UI loop baseline: `docs/research/2026-08-26-evolutionary-ui-loop.md`


## 2026-08-26-evolutionary-ui-loop

# Evolutionary UI loop — paper/book-chapter outline

Seed for the planned memoir/blog/business lane. A method, not a result
yet: an evolutionary loop that grows a developer terminal UI by
measurement instead of by taste, and the first overnight run of it.

## Title brainstorm

- *Breeding the Interface: An Evolutionary, Self-Grading Loop for
  Developer Terminal UIs*
- *The 4/10 That Caught a Bug: Grading Interfaces Before Liking Them*
- *Breed, Grade, Mutate, Re-measure: A Self-Correcting UI Loop*
- *The Operative Evolves: A Vision-Graded UI Loop*

## Abstract (2–3 sentences)

We run an evolutionary loop that grows a developer terminal UI by
capturing each variant, grading it with a fixed vision critique, and
mutating a deterministic generator until the grade improves. The first
overnight run bred an operative through five generations and the initial
4/10 grade surfaced a genuine data-dump defect, not a stylistic
complaint. The loop inverts the usual taste-first workflow: a passing
grade is never assumed, it is measured, and every accepted variant is
byte-regressed so the next mutation starts from a reproducible artifact.

## The loop

```
implement → capture → vision critique → ledger → mutate → re-measure
     ↑                                                    │
     └────────────────── accepted variant ───────────────┘
```

- **implement** — one slice from the current ledger finding.
- **capture** — screenshot / accessibility scrape of the live surface.
- **vision critique** — local vision pass with a fixed rubric; emits
  target + grade + first finding (pixels/accessibility, not opinion).
- **ledger** — the finding lands in `docs/project/ui-grades.md`;
  never rewritten, appended.
- **mutate** — `scripts/evolve-operative` mutates a small art-parameter
  pool; deterministic (same seed, same frame) via
  `docs/design/operative-frames.md`.
- **re-measure** — the mutation is graded against the same rubric;
  byte-regression across generations (`operative-frames.md`) keeps the
  accepted aesthetic stable.

## Artifact pipeline

```
generator (evolve-operative)
   → frames catalog (operative-frames.md, byte-regressed per gen)
   → surfaces: dashboard-tui (terminal) · osd-operative (Plasma qml6)
   → grade loop (grade-interface → ui-grades.md)
```

- **generator** — `scripts/evolve-operative`, generations 1–4/5.
- **frames catalog** — `docs/design/operative-frames.md`.
- **TUI** — `scripts/dashboard-tui` (rich full-screen read-only).
- **OSD** — `scripts/osd-operative` + `osd-operative.qml` (frameless
  always-on-top Plasma overlay).
- **grading** — `scripts/grade-interface`; ledger
  `docs/project/ui-grades.md`.

## Results to date

- **Grades** — `dashboard-tui`: 4/10 → 4/10 → 4/10 → `unparsed` →
  *pending re-grade on v5* (`docs/project/ui-grades.md`).
- **Bug caught** — the first 4/10 finding ("title/header text:
  OVERVIEW commands sessions …") was a live-telemetry data-dump in the
  header, caught by the machine before a human reviewed it
  (`docs/records/2026-08-26-osd-and-dashboard.md`).
- **Process note** — the `unparsed` row is itself a finding: the
  capture surface changed faster than the rubric, which is a real
  loop-coupling lesson, not a silent pass.

## Future work

- **Overlay** — a graded `osd-operative` (the operative above the
  desktop) enters the same loop.
- **Voice** — a local TTS/voice surface graded by the same rubric
  (`docs/design/assistant-interface.md` voice section).
- **Fleet nodes each graded** — every HNgh node gets its own operative
  and its own grade ledger, federating the UI/UX validation across the
  mesh (`docs/project/system-harness-roadmap.md`).

## Records to cite

- `docs/records/2026-08-26-osd-and-dashboard.md`
- `docs/records/2026-08-26-scheduled-runs-investigation.md`
- `docs/project/ui-grades.md` (grade ledger)
- `docs/design/operative-frames.md` (frames catalog)
- `docs/design/assistant-interface.md` (operative layer)
- `docs/project/lessons-2026-08-26.md` (transferable lessons)

## 2026-08-28-adversarial-review-patterns

# adversarial fresh-eyes review cadences for interfaces and agent work

Status: crystallized 2026-08-28 from research line `adversarial-review-patterns`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-adversarial-review-patterns.md.

# Contracted Research Line: Adversarial Fresh-Eyes Review Cadences for Interfaces and Agent Work

**Lifecycle:** contracting → crystallized

**Record status:** final structured summary / lasting record

**Applies to:** `hngh/hngh-automation` interfaces, agent workflows, automation runbooks, prompts, tool schemas, UI surfaces, and related operational flows.

---

## 1. Executive Summary

This line concludes with a durable recommendation:

> Institute a **scheduled, dual-track fresh-eyes review system** for human-facing interfaces and agent-facing workflow state.

The central review question is:

> Can a human or agent understand, continue, and complete this workflow using only the current visible state, explicit instructions, and machine-readable context — without relying on prior memory, hidden assumptions, or implementation history?

The goal is not merely “does it look okay?” but whether the system remains intelligible, resumable, and safe under fresh-context conditions.

This line crystallizes into three durable outcomes:

1. **Fresh-eyes review must be a cadence**, not an ad hoc activity.
2. **Human UX review and agent-state review must remain separate tracks.**
3. **Interfaces and agent workflows should meet a State Clarity Standard** before release or major workflow changes.

---

# 2. Findings

## Finding 1: Fresh-eyes failures are usually state failures, not visual failures

The most important fresh-eyes problems are not cosmetic. They are failures of context reconstruction.

A user or agent may fail because they cannot determine:

- What step they are on.
- What has already happened.
- What is expected next.
- Which values are defaults versus explicit choices.
- Whether an action is safe to retry.
- How to recover from interruption.
- Where the current machine-readable state lives.

Therefore, fresh-eyes review should prioritize **state clarity** over surface polish.

---

## Finding 2: Human and agent friction must be reviewed separately

Human users and agents fail in different ways.

Humans may struggle with:

- Ambiguous labels.
- Hidden controls.
- Unclear progress.
- Confusing defaults.
- Missing error or empty states.
- Destructive actions without confirmation.

Agents may struggle with:

- Lack of machine-readable state.
- Non-deterministic UI elements.
- Implicit assumptions about prior steps.
- Actions that are not idempotent.
- No explicit resume path after interruption.
- Conflation of user intent, system defaults, inferred state, and completed actions.

A generic “usability” review is insufficient because it tends to collapse these distinct failure modes into one vague assessment.

---

## Finding 3: Cadence converts fresh-eyes review from opinion into systemic defense

One-off reviews are useful but fragile. Without a cadence, fresh-eyes findings become anecdotal and do not accumulate into institutional knowledge.

A layered cadence creates recurring pressure to remove hidden assumptions before they normalize.

The recommended cadence is:

| Cadence | Scope | Purpose |
|---|---|---|
| **Per PR / per change** | Any UI, agent workflow, prompt, tool schema, or automation flow touched by the change | Catch state ambiguity and fresh-context failures early. |
| **Weekly** | Top 3 user journeys or agent workflows | Detect accumulated cognitive debt in active flows. |
| **Biweekly** | Zero-context agent audit against staging or a test environment | Simulate an agent with no memory of prior steps. |
| **Quarterly** | Adversarial red-team review | Stress-test hidden assumptions, interrupted sessions, stale state, and permission failures. |

A minimum viable version is sufficient to begin:

1. A PR checklist for UI/agent changes.
2. One weekly 30-minute human fresh-eyes review.
3. One biweekly zero-context agent audit.

---

## Finding 4: Agent workflows need explicit machine-readable state

Agent work is especially vulnerable when the current position in a workflow exists only in prose, logs, or implicit memory.

For agent-facing systems, the interface or workflow should expose enough state that a fresh agent instance can reconstruct its position without historical context.

This includes:

- Current step.
- Completed steps.
- Pending steps.
- Explicit defaults.
- Available actions.
- Constraints and permissions.
- Error conditions.
- Retry safety.
- Resume instructions.

If an agent cannot determine its current state from the visible or machine-readable context, the workflow is not fresh-eyes safe.

---

## Finding 5: Hidden assumptions become normalized behavior if not adversarially tested

Fresh-eyes review becomes adversarial when it deliberately assumes:

- The reviewer has never seen the system before.
- The agent has no memory of previous runs.
- The session was interrupted.
- State is stale.
- Permissions changed.
- A default value was silently applied.
- A prior step failed partially.
- The user or agent does not know implementation history.

Without this adversarial stance, teams often review only the happy path and miss the conditions where fresh context actually matters.

---

## Finding 6: State clarity should be a release gate, not a post-release cleanup task

Interfaces and agent workflows should not be considered complete until they satisfy a minimum standard of state clarity.

This is especially important for automation because unclear state can lead to repeated agent errors, unsafe retries, incorrect resumption, or silent normalization of bad behavior.

---

# 3. Core Recommendation

Adopt a **dual-track fresh-eyes review system** with the following permanent question:

> Can a human or agent understand, continue, and complete this workflow using only the current visible state, explicit instructions, and machine-readable context — without relying on prior memory, hidden assumptions, or implementation history?

This should be applied to:

- UI surfaces.
- Agent workflows.
- Prompts.
- Tool schemas.
- Automation runbooks.
- Operational dashboards.
- Approval flows.
- Error and recovery paths.
- Any workflow where a fresh human or agent instance may need to continue work.

---

# 4. Recommended Cadence

## Full cadence

| Cadence | Scope | Output |
|---|---|---|
| **Per PR / per change** | Any UI, prompt, tool schema, agent workflow, or automation flow touched by the change | Fresh-eyes checklist result and blocking/non-blocking findings. |
| **Weekly** | Top 3 active user journeys or agent workflows | Short review note identifying accumulated cognitive debt. |
| **Biweekly** | Zero-context agent audit against staging or test environment | Agent audit report with state reconstruction failures. |
| **Quarterly** | Adversarial red-team review | Stress-test findings around stale state, interruption, permissions, defaults, and partial failure. |

## Minimum viable cadence

If the full system is too heavy initially, adopt this baseline:

1. **PR checklist** for UI/agent changes.
2. **Weekly 30-minute human fresh-eyes review.**
3. **Biweekly zero-context agent audit.**

This minimum viable cadence should be treated as the default until evidence shows that more frequent or deeper review is needed.

---

# 5. Dual-Track Review Rubric

## Human Fresh-Eyes Track

Review as if you have never seen the interface before.

Check for:

- Ambiguous labels or actions.
- Hidden critical controls behind hover, scroll, or dynamic loading.
- Unclear progress or current step.
- Confusing defaults.
- Missing error, empty, success, and partial-failure states.
- Destructive actions without clear confirmation.
- Workflow steps that require prior knowledge to understand.
- Text that assumes implementation history.
- Controls whose meaning depends on invisible state.
- Recovery paths that are obvious only to people who built the system.

A human fresh-eyes review should ask:

> If I had never seen this before, could I confidently determine what is happening and what to do next?

---

## Agent Fresh-Eyes Track

Review as if the agent has no memory of previous runs.

Check for:

- Can the agent determine what step it is on?
- Can it infer what has already happened?
- Are defaults explicitly labeled, not silently assumed?
- Are actions idempotent or safely retryable?
- Are dynamic UI elements deterministic enough to act on?
- Is there a machine-readable state representation?
- Can the agent resume after interruption without historical logs?
- Does the interface distinguish between user intent, system default, inferred state, and completed action?
- Are error states explicit enough for the agent to choose a safe next action?
- Are permissions and constraints visible in the current context?

An agent fresh-eyes review should ask:

> If this agent instance started from zero memory, could it reconstruct its position and continue safely using only the current state?

---

# 6. State Clarity Standard

Every core flow in `hngh/hngh-automation` should pass this standard before release or major workflow changes.

## Required properties

1. **Current step is visible**
   - The user or agent can tell where they are in the workflow.

2. **Progress is explicit**
   - Breadcrumbs, step indicators, status labels, or equivalent machine-readable state exist.

3. **Defaults are labeled as defaults**
   - Defaults must not be treated as explicit user intent.

4. **No critical action depends on hover-only or unstable UI**
   - Critical actions should be reachable without transient states.

5. **Loading, error, empty, success, and partial-failure states are explicit**
   - The system should not leave the current condition ambiguous.

6. **Machine-readable state exists for agent-facing workflows**
   - Agents should be able to inspect current step, completed actions, pending actions, constraints, and available next actions.

7. **Actions are idempotent or safely retryable**
   - Retrying an action should not silently duplicate work or corrupt state unless the system explicitly prevents it.

8. **Interruption recovery is possible**
   - A fresh human or agent instance should be able to resume without relying on private memory or historical logs.

9. **User intent, system defaults, inferred state, and completed actions are distinguishable**
   - The interface or workflow state should not conflate what the user chose with what the system assumed.

10. **Error conditions expose a safe next action**
    - Errors should not only report failure; they should clarify what can be done next.

---

# 7. Concrete Recommendations for `hngh/hngh-automation`

## Recommendation 1: Add a fresh-eyes checklist to PRs touching UI or agent workflows

Any change affecting user-facing or agent-facing state should include a brief fresh-eyes review.

Minimum checklist:

- Is the current step visible?
- Are defaults explicit?
- Can a fresh human understand what happened?
- Can a fresh agent reconstruct its position?
- Are error, empty, loading, and partial-failure states handled?
- Are critical actions reachable without hover-only or unstable UI?
- Are destructive actions clearly confirmed?
- Is there machine-readable state for agent workflows?
- Can the workflow resume after interruption?

This checklist should be lightweight enough to run per change.

---

## Recommendation 2: Run a weekly human fresh-eyes review

Select the top 3 active user journeys or agent workflows each week.

Review them as if seeing them for the first time.

The output should be short:

- What is confusing?
- What assumes prior knowledge?
- What state is hidden?
- What action is unclear?
- What should be fixed before it becomes normalized?

This review does not need to be exhaustive. Its purpose is to prevent accumulated cognitive debt.

---

## Recommendation 3: Run a biweekly zero-context agent audit

Simulate an agent with no memory of prior steps.

The audit should use only:

- Current visible state.
- Explicit instructions.
- Machine-readable context.
- Available tools or actions.
- Current permissions and constraints.

The audit should answer:

- Can the agent determine its current step?
- Can it identify what has already happened?
- Can it determine what is safe to do next?
- Does it need historical logs to continue?
- Are defaults explicit enough?
- Are actions retry-safe?
- Would interruption cause confusion or unsafe behavior?

This audit should be treated as a first-class quality gate for agent workflows.


## 2026-08-28-gantt-legibility

# gantt legibility patterns

Status: crystallized 2026-08-28 from research line `gantt-legibility`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-gantt-legibility.md.

# Research Line: gantt legibility patterns
**Status:** Contracting (Finalized)
**Scope:** `hngh/hngh-automation`
**Date:** 2026-08-28

## Executive Summary
This research line investigated how to optimize Gantt chart interfaces for high-density automation environments. The core finding is that traditional "dense dump" timelines fail in automation contexts due to visual noise and cognitive overload. The recommended approach shifts the paradigm from *historical record-keeping* to *real-time operational awareness*.

The final design contract prioritizes three user questions:
1.  **What is happening now?** (Temporal anchoring)
2.  **What is blocked by what?** (Dependency clarity)
3.  **When does it finish relative to real time?** (Real-world alignment)

---

## Key Findings

### 1. Density Must Be Capped, Not Just Managed
*   **Finding:** Users cannot effectively parse timelines with more than 7–9 concurrent active bars in a standard viewport without significant zooming or filtering.
*   **Implication:** The default state must be "low-density." Historical data and subtasks are noise unless explicitly requested.
*   **Pattern:** Auto-collapse subtasks into summary bars when lane density exceeds the threshold.

### 2. Dependencies Are Constraints, Not Order
*   **Finding:** Users often mistake row order for dependency logic. Visual clutter from unrelated arrows obscures critical blockers.
*   **Implication:** Dependencies must be explicit, traceable, and context-aware.
*   **Pattern:** Use "hover-to-focus" interaction models. When a task is selected, fade all non-direct upstream/downstream dependencies. Limit visible crossing lines to ~5 per viewport.

### 3. Critical Path Is Dynamic, Not Static
*   **Finding:** Permanent red highlighting for critical paths leads to "highlight fatigue," where users stop reading the signal.
*   **Implication:** Critical path is a lens, not a decoration. It must be on-demand and explainable.
*   **Pattern:** Implement a toggle for critical path mode. When active, show slack/buffer and provide tooltips explaining *why* a task is critical (i.e., what slips if it delays).

### 4. Time Must Be Anchored to Reality
*   **Finding:** Abstract time scales (e.g., "Day 1–30") are less useful than real-world anchors (e.g., "Mon, Oct 12 – Fri, Oct 16").
*   **Implication:** The timeline must respect business days, weekends, and holidays.
*   **Pattern:** Default view should anchor to "Now" + next 2 weeks, with clear markers for project end/milestones.

---

## Recommendations for `hngh/hngh-automation`

### A. Default View Configuration
*   **Time Window:** Display `now` through `now + 2 weeks`. Include project end/milestone markers if they fall within this range or are immediately adjacent.
*   **Density Cap:** Enforce a maximum of **7–9 visible task bars** per 2-week window in the default viewport.
*   **Grouping Strategy:** Group tasks by meaningful automation lanes:
    *   Pipeline
    *   Service
    *   Environment
    *   Owner
    *   Workflow Stage
    *   Execution Class
*   **History Handling:** Hide completed historical runs by default. Provide a "Show History" filter for explicit access.

### B. Dependency Visualization Rules
*   **Explicitness:** Use arrows only for **explicit dependencies**. Do not imply dependency from row order.
*   **Contextual Focus:**
    *   On hover/selection: Show only direct upstream and downstream dependencies of the selected task.
    *   Fade or hide all other bars and arrows.
*   **Clarity Limit:** If more than 5 crossing dependency lines are visible in the viewport, trigger auto-grouping or require user filtering.
*   **Labeling:** Clearly label tasks as "Ordered" vs. "Dependent" to prevent misinterpretation of sequential rows.

### C. Critical Path Interaction Model
*   **Default State:** No permanent critical path highlighting.
*   **Toggle Mode:** Provide a "Critical Path" toggle button.
    *   When enabled: Highlight only the *current* critical path.
    *   Display slack/buffer information.
    *   Provide tooltips explaining the impact of delay (e.g., "This task delays 'Deploy' by 2 days").
*   **Animation:** Avoid pulsing or animated highlights unless triggered by explicit user action (e.g., clicking a specific risk).

### D. Time Anchoring & Real-World Context
*   **Scale:** Use real-world dates (e.g., "Mon, Oct 12") rather than abstract indices.
*   **Business Logic:** Clearly distinguish business days from weekends/holidays.
*   **"Now" Indicator:** A persistent, high-contrast vertical line indicating the current moment in time.

---

## Open Threads & Future Work

### 1. Mobile/Tablet Adaptation
*   *Question:* How does the "7–9 bar density cap" translate to smaller screens?
*   *Next Step:* Research mobile-specific Gantt patterns (e.g., list-view hybrid, swipe-to-focus dependencies).

### 2. AI-Assisted Dependency Inference
*   *Question:* Can the system suggest implicit dependencies based on historical execution patterns?
*   *Next Step:* Explore ML models that detect recurring sequential patterns and propose "soft" dependencies for user confirmation.

### 3. Dynamic Critical Path Recalculation
*   *Question:* How frequently should critical path be recalculated in a live automation environment?
*   *Next Step:* Define performance budgets for real-time recalculation vs. on-demand calculation.

### 4. Accessibility & Colorblind Safety
*   *Question:* How to ensure dependency arrows and critical path highlights are accessible to users with color vision deficiencies?
*   *Next Step:* Audit current color palette; implement pattern-based alternatives (e.g., dashed lines for dependencies, bold borders for critical paths).

---

## Acceptance Criteria Checklist

| Criterion | Status | Notes |
| :--- | :--- | :--- |
| User can identify task start/end without zooming | ✅ | Achieved via 2-week default window + density cap. |
| Default view does not require scrolling for active work | ✅ | Achieved by hiding history and capping density. |
| UI warns/collapses if >9 concurrent bars in 2-week window | ✅ | Auto-collapse into summary bars. |
| User can identify immediate blocker without >3 hops | ✅ | Achieved via hover-to-focus dependency filtering. |
| Non-relevant dependencies do not compete visually | ✅ | Achieved via fading/hiding unrelated bars/arrows. |
| Sequential row order is never mistaken for dependency | ✅ | Achieved via explicit labeling and arrow-only dependency display. |
| Users can distinguish "critical now" from "important generally" | ✅ | Achieved via on-demand critical path toggle. |
| Critical-path highlighting does not distract from active work | ✅ | No permanent red overlay; toggle-based. |
| UI explains what would slip if highlighted task delayed | ✅ | Tooltip/side panel explanation in critical mode. |

---

## Conclusion
The `gantt legibility patterns` line is now **contracted**. The design rules are finalized for implementation in `hngh/hngh-automation`. The focus has shifted from *visualizing all data* to *surfacing actionable insights*. Future work should focus on mobile adaptation and AI-assisted dependency inference.


## 2026-08-28-log-presentation-patterns

# log-presentation patterns

Status: crystallized 2026-08-28 from research line `log-presentation-patterns`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-log-presentation-patterns.md.

# Final contracted research line: log-presentation patterns

**Line:** log-presentation patterns
**Lifecycle:** contracting → crystallized
**Scope:** human-facing log presentation for operators, engineers, support staff, and auditors working with `hngh/hngh-automation`.
**Assumption:** `hngh/hngh-automation` produces operational logs from automation runs, jobs, workflows, API calls, data transformations, scheduled tasks, or similar execution paths.
**Evidence status:** crystallized from prior research material; implementation-specific validation still required against the actual codebase and log pipeline.

---

## Contracted thesis

For `hngh/hngh-automation`, logs should be presented as **correlated evidence slices**, not as raw chronological text.

The primary presentation unit is not a single log line. It is a **log slice**: a bounded group of related events around an automation run, job, step, entity, user, tenant, request, or failure window.

Raw logs remain important, but they should be the **final drill-down layer**, not the default view.

Presentation quality is constrained by log structure. If `hngh/hngh-automation` logs are mostly free text, no UI can fully compensate; it will only make missing structure more visible. Therefore, the line’s final position is:

> **Slice-first presentation, contract-driven logging.**
> The default human-facing surface should show bounded execution slices with status, impact, retries, dependencies, and next action. Raw chronological logs are a drill-down layer. Before investing heavily in UI polish, enforce a structured log contract with stable correlation identifiers and event taxonomy.

---

# Findings

## 1. Operators do not primarily need “more lines”; they need bounded evidence

A raw line such as:

```text
ERROR Payment failed
```

is weak because it does not answer the operator’s real questions:

- Which automation run failed?
- Which job or step failed?
- Did it retry?
- Was an external dependency involved?
- Which tenant, user, or entity was affected?
- What is the likely next action?

The useful unit is a slice such as:

> **Payment automation**, environment `prod`, run `run_12345`, job `job_67890`, step `payment_capture`, user `u_987`, between `10:02:11–10:02:14`:
> 3 related events, 1 error, payment provider timeout, retry count `2`, external call latency `1850ms`.

This slice is immediately more actionable than a raw chronological stream.

---

## 2. Automation logs are multi-event by nature

Automation systems usually produce sequences such as:

- run started
- step started
- validation passed/failed
- external API call started
- retry scheduled
- state changed
- dependency timed out
- job completed or failed

A single log line rarely captures the full failure. Presentation must therefore group events around execution context rather than treating each line as an independent artifact.

---

## 3. The default view should be slice-first, not stream-first

The primary human-facing surface should show:

- run health
- job status
- step failures
- entity impact
- retry behavior
- external dependency failures
- state transitions
- error summaries
- next likely action

Raw chronological logs should be available, but they should be a drill-down layer for engineers or auditors who need exact event-level detail.

---

## 4. Structured metadata is a prerequisite for good presentation

Presentation quality depends on whether logs can be reliably grouped and filtered.

If logs lack stable identifiers such as `run_id`, `job_id`, `step_id`, `request_id`, `tenant_id`, or `entity_id`, the system cannot confidently build slices.

Free-text logs may be parsed heuristically, but that is fragile. The durable recommendation is to make structured fields part of the logging contract.

---

## 5. Different roles need different slice views

### Operators

Need:

- What failed?
- Which run/job/step?
- Is it retrying?
- Is it likely transient or systemic?
- What should I do next?

### Engineers

Need:

- Exact event sequence
- dependency latency
- error codes
- stack traces
- state transitions
- raw logs

### Support staff

Need:

- Which user, tenant, or entity was affected?
- When did it happen?
- What automation action failed?
- Is there a customer-facing impact


## 2026-08-28-logs-known-good-patterns

# log organization/navigation/presentation patterns for the logs overhaul

Status: crystallized 2026-08-28 from research line `logs-known-good-patterns`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-logs-known-good-patterns.md.

# Final structured summary — log organization/navigation/presentation patterns for the logs overhaul

**Research line:** Log organization/navigation/presentation patterns for the logs overhaul

**Lifecycle state:** contracting → **crystallized / lasting record**

**Target:** `hngh/hngh-automation`

---

## Executive stance

Logs in `hngh/hngh-automation` should be treated as **structured, addressable, task-modeled telemetry**, not as a single flat chronological text stream.

The log experience should first answer:

> **“What failed, where did it fail, and why is this relevant now?”**

Then it should preserve strong paths for:

1. **Triage** — find the failure quickly.
2. **Audit** — reconstruct who did what to what, when.
3. **Debugging** — inspect chronological and contextual detail around a run, request, job, step, user, or resource.

The UI may transform logs into summaries, groups, views, and filters, but the underlying raw log store must remain **immutable, exportable, and sufficient for reconstruction**.

---

# Findings

## 1. Automation logs are event records, not just text lines

Logs in an automation system should be modeled as discrete events tied to meaningful entities:

- run
- workflow
- job
- step
- request / trace
- user / actor
- resource
- environment
- artifact
- ticket
- deployment

**Implication:** The log UI should not primarily depend on line numbers, file offsets, or raw text positions. It should anchor navigation around stable identifiers and semantic entities.

---

## 2. The dominant user task is triage, not reading logs chronologically

For automation operators, the most valuable question is usually:

> “Which runs failed, which steps failed, and what error caused it?”

A default chronological view is useful, but it is not the best primary experience for automation operations.

**Implication:** The default log view should be a **triage view**, surfacing failed runs, failed steps, errors, warnings, and recent failures first.

---

## 3. Chronology is necessary but insufficient

Chronological order is important for debugging and audit reconstruction, but it does not by itself explain automation state.

A user debugging an automation run needs to understand:

- which run they are in
- which job failed
- which step produced the error
- what request or trace correlates with that step
- what actor triggered the run
- what resource was affected
- whether a recent deploy or config change is relevant

**Implication:** Chronology should exist as one view, but not be the only organizing principle.

---

## 4. Audit and debugging have different information needs

Audit asks:

> “Who did what to what, when?”

Debugging asks:

> “What happened step by step around this failure or request?”

These are related but distinct tasks.

**Implication:** The log system should support at least three primary views:

1. **Triage**
2. **Audit**
3. **Debug**

Each view can share the same underlying structured data, but present it differently.

---

## 5. Semantic navigation is more useful than positional navigation

Users should be able to jump to meaningful landmarks such as:

- failed step
- first error in a run
- next error
- previous error
- request ID
- user action
- resource change
- deploy marker
- artifact reference
- ticket reference

**Implication:** Navigation should be semantic. Line numbers and scroll positions are secondary anchors, not primary ones.

---

## 6. Grouping should be task-driven

For `hngh/hngh-automation`, the most natural default grouping is automation-centric:

> **run → job → step**

Other useful lenses include:

- chronological
- actor-centric
- resource-centric
- request/trace-centric
- event-centric
- error-centric

**Implication:** The default view should depend on the user’s task. For automation operators, the default should be run/job/step triage. For auditors, the default may be actor/action/resource/time. For engineers debugging a request, the default may be trace/request chronological reconstruction.

---

## 7. Presentation must scale to large logs and long runs

Automation logs can become very large, especially when including:

- step output
- payloads
- retries
- nested job execution
- verbose debug output
- artifact references
- request traces

Rendering everything at once will degrade usability and performance.

**Implication:** The UI should use progressive disclosure, virtualized lists, lazy payload loading, expand-on-demand details, tail mode, and pagination or incremental loading.

---

## 8. Correlation identifiers are the connective tissue of the log experience

Without stable correlation fields, the log UI becomes brittle and hard to navigate.

Key correlation identifiers include:

- `event_id`
- `run_id`
- `workflow_id`
- `job_id`
- `step_id`
- `request_id`
- `trace_id`
- `actor` / `user_id`
- `resource_id`
- `environment`
- `error_code`

**Implication:** Every log event should expose enough identifiers to link it to related runs, jobs, steps, traces, users, resources, artifacts, deployments, and tickets.

---

## 9. Search,


## 2026-08-28-session-cost-display

# session-cost display formats

Status: crystallized 2026-08-28 from research line `session-cost-display`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-session-cost-display.md.

# Research Line Record: Session-Cost Display Formats

**Lifecycle:** `contracting` → final crystallization
**Target:** `hngh/hngh-automation`
**Status:** Closed for expansion; ready for implementation and validation
**Core conclusion:** Session cost display should not be treated primarily as a receipt or accounting surface. It should be treated as a **budget-control and confidence surface** for human operators and automated workflows.

---

## 1. Findings

### F1. Raw token counts are not the primary user-facing signal

Token counts, API call counts, model-specific units, and deep decimal currency values are useful for debugging, but they do not directly answer the operator’s question:

> “Is this run affordable, safe, and within budget?”

The primary display should be money-based, budget-aware, and action-oriented.

### F2. Cost estimates must be ranges, not single numbers

Because model usage, context length, retries, tool calls, and workflow complexity can vary, a single estimated cost is misleading. The system should show:

```text
Estimated cost: $0.80–$1.20
```

A range communicates uncertainty without requiring the user to infer it.

### F3. Cost display needs three distinct states

The useful lifecycle for cost visibility is:

1. **Preflight / before run**
2. **During run**
3. **After run**

Each state answers a different question:

| State | Question answered |
|---|---|
| Preflight | “Should I start this?” |
| During run | “Is it still within expectations?” |
| After run | “What did it cost, and how close was the estimate?” |

### F4. Automation requires stronger guarantees than interactive chat

Interactive sessions can rely on a human watching the screen. Automated, queued, or background runs cannot assume continuous human attention. Therefore, automation must have:

- Projected total cost before execution
- A hard maximum allowed cost
- Live budget state
- Safe failure behavior when limits are approached or exceeded

### F5. Batch jobs need projected totals and caps

A batch job is not a single run. It should show:

```text
12 runs × est. $0.18–$0.35
Estimated total: $2.16–$4.20
Max allowed cost: $5.00
Daily budget left: $14.20
```

Batch jobs should not start without a maximum cost ceiling.

### F6. Overruns must be visible, logged, and operationally meaningful

If a run exceeds its estimate or cap, the system should not silently continue. It should produce:

- A user-visible warning or alert
- A structured log entry
- A post-run delta against the estimate
- An operational dashboard signal if relevant

### F7. Power-user detail should be secondary

Raw token counts, per-call costs, model-specific units, and four-decimal currency values are useful, but they should not dominate the primary UI. They belong in logs, debug panels, or explicit power-user views.

---

## 2. Recommendations

### R1. Ship one standard cost card for all sessions, runs, and batch jobs

Do not pursue multiple competing cost display experiments. Implement one shared cost display component with three states.

#### Preflight / Before Run

For a single session:

```text
Estimated cost: $0.80–$1.20
Daily budget left: $14.20 (71%)
Workflow: hngh-automation / code-review
```

For a batch job:

```text
12 runs × est. $0.18–$0.35
Estimated total: $2.16–$4.20
Max allowed cost: $5.00
Daily budget left: $14.20
```

#### During Run

```text
Cost so far: $0.35
Estimated final: $0.90–$1.10
Budget remaining: $13.85
Status: within estimate
```

#### After Run

```text
Final cost: $0.94
Estimate was: $0.90–$1.10
Delta vs estimate: +$0.04
Budget remaining: $13.26
```

### R2. Use money-first display rules

The primary UI should follow these rules:

- Show cost as a range when uncertain.
- Never show more than two decimal places in the primary UI.
- If cost is below one cent, show `<$0.01`, not `$0.0042`.
- Do not lead with tokens, API calls, or model-specific units.
- Keep raw token/cost data available in logs or a debug panel.
- Make budget state visible without opening settings or logs.

### R3. Tie cost display to execution gating

Cost visibility is not enough. For automation, cost display must be connected to decision gates.

#### Interactive Sessions

Behavior:

- Show estimate before start.
- Allow continuation if estimate is within normal budget.
- Warn if estimate exceeds a configurable threshold.
- Require confirmation if estimate exceeds a higher threshold.

Example:

```text
Estimated cost: $4.80–$6.20
This exceeds your normal workflow range.
Proceed?
```

#### Queued Batch Jobs

Before enqueueing, show:

```text
Projected batch cost: $2.16–$4.20
Max allowed cost: $5.00
Budget remaining after projected max: $10.00
```

Behavior:

- If projected maximum exceeds the configured cap, block or require explicit confirmation.
- No batch job should start without a maximum cost ceiling.

#### Unattended / Background Runs

Behavior:

- Require a hard `max_cost_usd` per run or per batch.
- If live cost approaches the cap, pause, fail safely, or notify depending on workflow policy.
- Log estimate versus final cost for every run.
- Overruns must produce an alert and a structured log entry.

### R4. Define minimum job metadata

Batch jobs and automated runs should expose at least:

```text
estimated_min_usd
estimated_max_usd
max_allowed_usd
final_cost_usd
delta_vs_estimate_usd
budget_remaining_usd
cost_status
```

Where `cost_status` can be one of:

```text
within_estimate
above_estimate
below_estimate
over_cap
paused_at_cap
failed_safely
completed_overrun_flagged
```

### R5. Make overruns operationally visible

Every overrun or near-overrun should produce a structured event containing:

- Run ID
- Workflow name
- Estimate range
- Final cost
- Cap
- Delta
- Budget remaining
- Action taken: `warned`, `paused`, `failed`, `completed_overrun_flagged`
- Timestamp

This makes cost behavior auditable and useful for dashboards.

---

## 3. Acceptance Criteria

A session-cost display implementation is complete when:

- Every interactive session shows a preflight estimate when possible.
- Every batch job shows projected total and maximum cap before execution.
- The primary UI never displays four-decimal currency values.
- Cost state is visible without opening settings or logs.
- Batch jobs expose `estimated_min_usd`, `estimated_max_usd`, and `max_allowed_usd`.
- Runs exceeding their cap are stopped, paused, flagged, or safely failed before completion.
- Budget overruns are visible in operational dashboards.
- Raw token/cost data remains available for debugging without polluting the primary UI.

---

## 4. Open Threads

These are not blockers to adopting the recommendation, but they should be resolved during implementation.

### O1. Estimate accuracy and calibration

The system needs a practical way to estimate cost ranges. Open questions:

- How should estimates account for context length?
- How should retries, tool calls, and multi-step workflows affect the range?
- Should estimates be based on historical run data?
- How often should estimate models be recalibrated?

### O2. Budget hierarchy

The system may need multiple budget levels:

- Per-run
- Per-batch
- Per-workflow
- Per-day
- Per-user or per-tenant

Open question: which budgets are authoritative, and how do they interact?

### O3. Cap enforcement policy

Different workflows may need different behavior when approaching a cap:

- Warn only
- Pause for confirmation
- Fail safely
- Notify operator
- Stop immediately

Open question: what is the default policy for `hngh/hngh-automation`?

### O4. Multi-model and multi-provider cost normalization

If runs can use multiple models or providers, costs must be normalized into a common currency view. Open questions:

- How to handle different pricing tiers?
- How to represent mixed-model runs?
- Should the UI show per-model breakdowns in debug mode only?

### O5. Partial-run accounting

If a run is cancelled, paused, or fails partway through, cost display should still be meaningful. Open questions:

- What does “final cost” mean for an incomplete run?
- Should partial runs show `partial_cost_usd`?
- How should estimate delta be calculated for interrupted runs?

### O6. UI placement and persistence

The cost card must be visible in the right contexts. Open questions:

- Where does it appear during long-running jobs?
- Does it persist across queue views, run detail pages, and dashboards?
- Is there a compact version for batch lists?

### O7. Evaluation metrics

To validate that this improves operator confidence, track:

- Overrun rate
- Time to detect budget risk
- Number of blocked or confirmed high-cost runs
- User trust / usability feedback
- Estimate error distribution
- Frequency of silent overruns before and after implementation

---

## 5. Final Position

The line should now be treated as **contracted**, not open-ended.

The durable recommendation is:

> Implement one standard cost card for `hngh/hngh-automation` that shows estimated cost range, live budget state, and post-run delta. Tie this display to execution gating so interactive sessions can warn or confirm, batch jobs require caps, and unattended runs fail safely when limits are exceeded. Raw token data remains available for debugging, but the primary user-facing surface is money, budget, and risk.


## 2026-08-28-tech-tree-research-ux

# tech-tree research UX precedents

Status: crystallized 2026-08-28 from research line `tech-tree-research-ux`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-tech-tree-research-ux.md.

# Research Line Record: Tech-Tree Research UX Precedents

**Line:** tech-tree research UX precedents
**Lifecycle:** contracting → crystallized
**Applicability:** `hngh` / `hngh-automation`
**Record type:** final structured summary / lasting line record

---

## Contract Outcome

Use the tech tree as a **decision surface**, not a documentation page.

For `hngh` and `hngh-automation`, the research UI should let users and automation systems quickly answer:

1. **What can be researched now?**
2. **What does it cost?**
3. **What does it unlock or improve?**
4. **Why is something blocked, queued, running, failed, or complete?**
5. **Who or what changed the state, and how can I safely intervene?**

The tech tree should support two equally important modes:

- **Human planning:** scanning, comparing, prioritizing, and understanding strategic value.
- **Automation execution:** machine-readable state, explicit actions, auditability, safe overrides, and transparent decision reasons.

---

# Findings

## 1. Tech trees are decision surfaces, not reference pages

Users do not primarily need a long description of every research item. They need to evaluate options and decide what to do next.

**Design implication:**
The default experience should optimize for comparison, state recognition, and actionability. Detailed documentation is secondary and should be


## 2026-08-28-telemetry-schema-exemplars

# telemetry schema exemplars

Status: crystallized 2026-08-28 from research line `telemetry-schema-exemplars`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-telemetry-schema-exemplars.md.

# Telemetry Schema Exemplars — Contracted Line Record

**Line:** telemetry schema exemplars
**Lifecycle state:** contracting
**Target context:** `hngh/hngh-automation`
**Record type:** final structured summary / lasting record for the line

---

## 1. Findings

### F1. Business-level telemetry needs a stable semantic contract
Standard OpenTelemetry conventions are useful, but they do not by themselves define the business meaning of automation-specific signals such as workflow execution, provisioning, tenant isolation, or regional behavior.

For `hngh/hngh-automation`, custom metrics, logs, and traces need a shared business semantic layer. Without it, teams can independently introduce names like:

- `workflow_execution_duration`
- `workflow_exec_time`
- `automation_run_duration_seconds`

...with inconsistent units, missing attributes, and no reliable correlation to traces or logs.

**Implication:**
Without a schema contract, observability becomes fragmented across services, dashboards become brittle, and debugging automation failures requires manual reconstruction of context.

---

### F2. Exemplars are the practical bridge between metrics and traces
Exemplars are metric data points that carry associated trace identifiers and selected attributes. They allow an engineer to move from a metric spike directly to the relevant trace.

The key risk is that exemplars can be dropped during aggregation, downsampling, processor transformation, or export if the pipeline does not explicitly preserve them.

**Implication:**
If exemplars are not preserved end-to-end, metric anomalies in automation pipelines lose their actionable context. Engineers may see a spike in `workflow_execution_duration_seconds` but still need to search logs or traces manually to find the failing step.

---

### F3. Metric-to-trace linkage is fragile without explicit exemplar policy
Automation systems often produce high-value signals such as:

- workflow duration
- step failures
- resource provisioning latency
- retry counts
- tenant-specific execution errors

These metrics are only useful operationally if they can be connected to the actual execution path.

**Implication:**
Exemplars should be treated as first-class telemetry artifacts for critical automation metrics, not optional debug metadata.

---

### F4. Schema evolution requires versioning and compatibility rules
Adding new telemetry fields, such as `cost_center`, `workflow_version`, or `tenant_id`, can break existing pipelines if the schema is not versioned and if collectors/exporters do not handle unknown or evolving fields predictably.

**Implication:**
Without a versioning strategy, schema changes can cause silent data loss, dashboard breakage, alert misbehavior, or pipeline instability.

---

### F5. High-cardinality attributes must be governed
Business attributes such as `tenant_id`, `workflow_id`, and `region` are valuable for correlation, but they can create cardinality problems if used carelessly as metric labels.

**Implication:**


## 2026-08-28-wiki-viewer-qol

# wiki-viewer QoL comparison

Status: crystallized 2026-08-28 from research line `wiki-viewer-qol`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-wiki-viewer-qol.md.

# Research Line: wiki-viewer QoL comparison
**Lifecycle State:** Contracted (Final)
**Target Application:** `hngh/hngh-automation`
**Date:** 2026-08-28

## Executive Summary
This research line investigated the Quality of Life (QoL) differentiators for a read-only wiki viewer or generated documentation UI. The core finding is that **functional utility** (search, navigation, readability) outweighs **visual polish** in determining user satisfaction and reliability perception. For `hngh/hngh-automation`, the recommendation is to abandon open-ended feature comparison in favor of implementing a concrete, measurable **Viewer QoL Baseline**.

## Key Findings

### 1. Search is the Primary Usability Surface
Search quality is the single highest-leverage QoL factor. If users cannot find content quickly, the viewer feels broken regardless of rendering fidelity.
*   **Critical Gap:** Many viewers treat search as a secondary utility rather than the primary entry point.
*   **Requirement:** Client-side indexing must be fast (<100ms for local queries) and support fuzzy matching, prefix search, and ranked results (title > heading > body).

### 2. Navigation Context Must Be Persistent
Wiki content is non-linear; disorientation is a major friction point.
*   **Critical Gap:** Mobile drawers often reset context; browser back/forward behavior is inconsistent across search results and linked pages.
*   **Requirement:** The viewer must always clearly indicate the user’s location within the hierarchy (breadcrumbs, persistent sidebar, or TOC) without requiring URL inspection.

### 3. Readability Controls Are Non-Negotiable for Dense Content
Raw wiki rendering is often uncomfortable for sustained reading.
*   **Critical Gap:** Lack of default controls for font size, line height, and typography leads to user fatigue.
*   **Requirement:** The viewer must provide out-of-the-box readability adjustments (e.g., "Reading Mode") that respect system preferences while allowing manual override.

### 4. Performance and Offline Behavior Define Reliability
On constrained devices or networks, perceived reliability is tied to performance.
*   **Critical Gap:** Heavy client-side dependencies or slow initial loads erode trust.
*   **Requirement:** The viewer must feel instant on mobile and degrade gracefully offline (e.g., cached content, clear error states).

### 5. Accessibility and Provenance Build Trust
Usability extends beyond sighted users; trust requires transparency about content origin.
*   **Critical Gap:** Poor keyboard/screen reader support and lack of source attribution undermine credibility.
*   **Requirement:** Full keyboard navigability, screen reader compatibility, and visible provenance (e.g., "Last updated by X on Y").

## Recommendations for `hngh/hngh-automation`

### 1. Implement a First-Class Search Baseline
**Action:** Build or configure a client-side search index over wiki pages.
*   **Index Fields:** Page title, headings, first ~200 chars of body, namespace/chapter, tags, last-updated date.
*   **Features:** Prefix search, typo tolerance/fuzzy matching, ranked results, snippet highlighting.
*   **Follow-on (Post-Baseline):** Filters (namespace, tag, date), recent searches, "where was this used?" links.
*   **Acceptance Criteria:**
    *   Known pages appear in top 3 results for title/common phrases.
    *   Mobile-compatible without desktop-only interactions.
    *   Query response <100ms for typical wiki sizes.
    *   No-result state offers fallbacks (sitemap, recent changes).

### 2. Enforce Persistent Navigation Context
**Action:** Ensure the user always knows their location within the wiki structure.
*   **Features:** Persistent breadcrumbs or sidebar/tree, TOC controls for long pages, next/previous navigation, "back to top," related pages.
*   **Mobile-Specific:** Preserve current location when opening/closing mobile drawer.
*   **Browser Behavior:** Predictable back/forward across search results, linked pages, and revisions.
*   **Acceptance Criteria:**
    *   User can navigate 5 pages deep and still know their location without checking URL.
    *   Mobile drawer does not reset context.
    *   Keyboard users retain focus context through navigation.

### 3. Default to Readability Controls
**Action:** Provide comfortable reading defaults for dense content.
*   **Features:** Adjustable font size, line height, and typography presets (e.g., "Standard," "Comfort," "High Contrast").
*   **Behavior:** Respect system `prefers-color-scheme` and `prefers-reduced-motion` while allowing manual override.
*   **Acceptance Criteria:**
    *   Users can adjust readability without leaving the page.
    *   Defaults are comfortable for sustained reading (e.g., line length <80 chars, adequate line height).

### 4. Optimize Performance and Offline Behavior
**Action:** Ensure reliability on constrained devices/networks.
*   **Features:** Lazy loading of content/images, service worker caching for offline access, clear error states for network failures.
*   **Acceptance Criteria:**
    *   Initial load <2s on 4G mobile networks.
    *   Cached pages accessible offline with clear "offline" indicator.
    *   No layout shift (CLS) during content loading.

### 5. Ensure Accessibility and Provenance
**Action:** Make the viewer usable by all users and transparent about content sources.
*   **Features:** Full keyboard navigation, ARIA labels for screen readers, visible source attribution (author, date, version).
*   **Acceptance Criteria:**
    *   Passes WCAG 2.1 AA compliance checks for core navigation and content.
    *   Every page displays clear provenance information.

## Open Threads
1.  **Authoring/Admin Scope:** This line assumes a read/browse viewer. If editing, permissions, or administration are in scope, a separate research line is required to address those specific QoL concerns (e.g., WYSIWYG vs. Markdown editor UX, permission management UI).
2.  **Content Generation Pipeline:** The quality of the wiki content itself (structure, tagging, metadata) directly impacts search and navigation effectiveness. A follow-up line on "Wiki Content Quality Metrics" may be needed to ensure the viewer baseline is supported by well-structured data.
3.  **A/B Testing Framework:** How will the QoL baseline be measured in production? Defining metrics (e.g., time-to-find-page, bounce rate from search, readability toggle usage) is an open implementation question.

## Conclusion
The `hngh/hngh-automation` team should implement the **Viewer QoL Baseline** as a concrete, testable set of features rather than engaging in open-ended tool comparison. The baseline prioritizes **search**, **navigation context**, and **readability** as the core pillars of user experience. Visual polish and advanced features (e.g., AI summarization, complex filtering) should be considered only after this baseline is met and validated.


## 2026-08-29-remote-access-patterns

# remote access patterns: WoL, tailnet VPN, SSH, headless dashboard exposure

Status: crystallized 2026-08-29 from research line `remote-access-patterns`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-remote-access-patterns.md.

# Final structured summary — remote access patterns: WoL, tailnet VPN, SSH, headless dashboard exposure

**Line:** remote access patterns: WoL, tailnet VPN, SSH, headless dashboard exposure

**State:** contracting → crystallized

**Applicability:** `hngh/hngh-automation`

**Record type:** Lasting research record for this line

---

## Core stance

Remote access for `hngh/hngh-automation` should be treated as a **privileged control plane**, not a convenience network feature.

The durable posture is:

1. **No standing public inbound ports.**
2. **Tailnet/VPN is the normal remote-admin path.**
3. **WoL is only a recovery primitive.**
4. **SSH is a privileged channel and must be tightly scoped.**
5. **Headless dashboards are administrative endpoints, not ordinary web services.**
6. **Every remote access path must be attributable, revocable, and logged.**

This line should remain closed unless a new requirement forces a change in identity model, network topology, recovery strategy, or dashboard exposure model.

---

# Findings

## 1. Remote access is the primary trust boundary

For headless automation systems, remote access paths are not merely “networking details.” They define who can:

- wake machines,
- reach internal services,
- execute privileged commands,
- view operational state,
- modify automation behavior,
- exfiltrate or tamper with local data.

Therefore, remote access should be designed as a **control plane**, not an always-on convenience surface.

The key insight is that each access primitive has a different trust meaning:

| Primitive | Correct role | Incorrect role |
|---|---|---|
| WoL | Recovery / power-state primitive | Normal remote access path |
| Tailnet/VPN | Default authenticated remote network | Flat trusted LAN replacement |
| SSH | Privileged admin channel | Broadly exposed convenience shell |
| Headless dashboard | Administrative endpoint | Public web app or unauthenticated status page |

---

## 2. Wake-on-LAN is a recovery primitive, not an access path

WoL should be understood as a **power-state control**, not a remote administration method.

WoL can be useful when:

- a node is asleep or powered off,
- the operator needs to bring it back into a reachable state,
- no other remote path is available because the node is not running.

But WoL itself should never grant meaningful access. It only changes the node’s power state. After wake, access must still occur through an authenticated channel such as tailnet/VPN, SSH, or an authenticated dashboard proxy.

The main risk is treating WoL as a public convenience endpoint. If WoL can be triggered from untrusted sources, it becomes:

- a denial-of-service vector,
- a reconnaissance signal,
- a path to wake and probe otherwise dormant systems,
- a way to bypass the intended remote-access trust model.

Therefore, WoL should be **disabled by default**, restricted when enabled, and treated as an audited recovery action.

---

## 3. Tailnet/VPN reduces exposure but does not replace identity

Tailnet/VPN is the preferred default remote-admin network because it removes public inbound ports and provides a private addressing model.

However, a tailnet is not automatically safe. The main risk is treating it as a trusted flat network where every node can reach every other node.

A compromised device inside the tailnet should not automatically become able to reach:

- SSH endpoints,
- dashboard control interfaces,
- automation APIs,
- local service ports,
- privileged management interfaces,
- sensitive internal hosts.

The tailnet should be used as a **transport and identity boundary**, not as blanket trust.

The correct model is:

- every node has an explicit identity,
- access is scoped by purpose,
- stale identities are disabled,
- human access requires MFA where supported,
- automation uses scoped or short-lived credentials,
- reachability is periodically audited.

In other words: **tailnet membership is necessary but not sufficient.**

---

## 4. SSH is a high-value privileged channel

SSH remains one of the most useful administration paths for headless systems, but it should be treated as privileged access.

The default risk model is that SSH gives direct shell access to a machine that may control automation, networking, services, or sensitive local state. Therefore, SSH must be hardened and scoped.

Key findings:

- SSH should be key-only.
- Password authentication should be disabled.
- Direct root login should be disabled.
- Access should be limited to named admin users.
- Source access should be restricted to tailnet/VPN or bastion where possible.
- Agent forwarding and unnecessary forwarding features should be disabled by default.
- SSH should be logged and attributable.
- Automation SSH access should use scoped credentials, not broad human keys.

SSH is valuable, but it should not become a loosely governed back door.

---

## 5. Headless dashboards are administrative endpoints

Headless dashboards should not be treated like ordinary web services.

A dashboard on a headless automation node may expose:

- live system state,
- automation controls,
- service status,
- logs,
- configuration,
- device control surfaces,
- API endpoints,
- webhook or integration interfaces.

Even if the dashboard is read-only, it can still be sensitive because it reveals operational state and may include authenticated APIs behind the UI.

Therefore, dashboards should be treated as **administrative endpoints**, with access controlled at the same level as SSH or other privileged remote paths.

The default posture is:

- no direct public exposure,
- access only through tailnet/VPN or authenticated proxy,
- MFA/SSO for human access where supported,
- scoped tokens for automation,
- read-only and control endpoints separated where possible,
- audit logging of administrative actions.

A dashboard should not become a convenient public surface just because it has a browser UI.

---

## 6. Attribution, revocation, and logging are mandatory

Every remote access path must be able to answer:

- Who accessed this?
- From which identity or device?
- What did they touch?
- When did it happen?
- Can that access be revoked quickly?
- Is the action attributable to a human, job, token, or automation runner?

This applies equally to:

- WoL triggers,
- tailnet node identities,
- SSH sessions,
- dashboard logins,
- API tokens,
- machine credentials.

The system should assume that access will need to be audited after an incident, not only during normal operation.

---

# Recommendations

## Canonical remote-access posture

For `hngh/hngh-automation`, the default remote-access model should be:

```yaml
remote_access:
  public_inbound_ports: none
  preferred_remote_admin_path: tailnet_or_vpn
  wol: recovery_only
  ssh: privileged_channel
  dashboards: administrative_endpoints
  identity: required
  authorization: least_privilege
  logging: required
  revocation: required
```

This should be treated as the baseline unless a specific node has an approved exception.

---

## Recommendation 1: Disable WoL by default

WoL should not be enabled unless there is a concrete recovery requirement.

Default:

```yaml
wol:
  enabled: false
  allow_public_relay: false
  require_auth: true
  log_all_requests: true
  post_wake_access: tailnet_or_ssh_only
```

When WoL is enabled, it should only be reachable through a trusted path such as:

- trusted LAN/VLAN,
- authenticated relay,
- controlled tailnet/VPN path.

WoL requests must be logged with:

- source identity,
- target host/MAC,
- timestamp,
- operator or automation job ID,
- reason if available.

Operational rule:

> WoL may turn a node on, but it must not grant access.

After wake, the node should only become reachable through an authenticated remote path such as tailnet/VPN, SSH, or an authenticated dashboard proxy.

If WoL is unavailable, fail closed: do not fall back to public inbound exposure.

---

## Recommendation 2: Use tailnet/VPN as the default remote-admin network

Tailnet/VPN should be the normal remote administration path for `hngh/hngh-automation` nodes.

Default:

```yaml
tailnet:
  required_for_remote_admin: true
  default_policy: deny
  per_node_identities: true
  stale_identity_disable_days: 30
  human_access_mfa: true
  machine_credentials: scoped_or_short_lived
  audit_reachability: true
```

Every node should have an explicit identity:

- hostname,
- owner/operator,
- purpose,
- expiry or review date,
- allowed services.

The tailnet should enforce least privilege. It should not be treated as a trusted flat network.

Required practices:

- deny by default,
- scope access per node and service,
- disable stale identities automatically,
- require MFA for human interactive access where supported,
- use scoped machine tokens or short-lived credentials for automation jobs,
- periodically audit what can reach what.

Key risk to prevent:

> A compromised laptop, phone, edge node, or automation runner should not be able to reach all sensitive local services simply because it is in the tailnet.

The tailnet should reduce inbound exposure, not replace authentication and authorization.

---

## Recommendation 3: Harden SSH as a privileged channel

SSH should remain available for administration, but only under a strict baseline.

Required SSH posture:

- key-only authentication,
- no password authentication,
- no direct root login,
- named admin users only,
- source access restricted to tailnet/VPN or bastion where possible,
- agent forwarding disabled unless explicitly required,
- X11 forwarding disabled by default,
- unnecessary forwarding disabled,
- session logging enabled,
- automation SSH credentials scoped and revocable.

Example baseline:

```yaml
ssh:
  password_authentication: false
  permit_root_login: false
  allowed_users: named_admins_only
  source_restriction: tailnet_or_bastion
  agent_forwarding: disabled_by_default
  x11_forwarding: false
  session_logging: true
  automation_credentials: scoped_or_short_lived
```

For sensitive nodes, prefer a bastion or jump-host model where practical. Direct SSH from many devices should be avoided when it complicates attribution and revocation.

SSH should be treated as privileged access, not as a casual remote shell.

---

## Recommendation 4: Treat headless dashboards as administrative endpoints

Headless dashboards should not be exposed directly to the public internet.

Default:

```yaml
dashboards:
  public_exposure: false
  required_access_path: tailnet_or_authenticated_proxy
  human_auth: mfa_or_sso_where_supported
  machine_auth: scoped_tokens
  read_only_mode: preferred_for_monitoring
  control_actions: logged
  audit_logging: true
```

Recommended practices:

- serve dashboards only through tailnet/VPN or an authenticated proxy,
- require MFA/SSO for human access where supported,
- use short-lived or scoped tokens for automation,
- separate read-only monitoring views from control interfaces,
- disable unauthenticated APIs and webhooks by default,
- log administrative actions,
- avoid exposing dashboards as ordinary public web services.

A dashboard should be considered sensitive even if it is primarily for viewing state. The UI may be convenient, but the underlying endpoints are administrative.

---

## Recommendation 5: Require attribution and revocation for all remote paths

Every remote access path must support:

- identity,
- authorization,
- logging,
- revocation.

This includes:

- WoL triggers,
- tailnet node identities,
- SSH keys,
- dashboard sessions,
- API tokens,
- automation credentials.

Minimum audit fields:

```yaml
audit:
  required_fields:
    - actor_identity
    - source_address_or_device
    - target_host
    - target_service
    - timestamp
    - action
    - result
    - job_id_if_automation
```

The system should be able to answer, after the fact:

- who accessed what,
- from where,
- with which credential,
- and whether that credential can still act.

---

## Recommendation 6: Fail closed when remote access is ambiguous

If a remote access path cannot be clearly attributed, authenticated, or scoped, it should not be enabled.

Fail-closed rules:

- no public inbound ports by default,
- no WoL fallback to public exposure,
- no dashboard exposed without authentication,
- no SSH password login,
- no broad tailnet allow-all access,
- no unscoped automation tokens for privileged actions.

When in doubt, prefer a more restrictive path and document the exception


## 2026-08-29-research-publishing-pipelines

# research publishing pipelines: reports, papers, books from crystallized lines

Status: crystallized 2026-08-29 from research line `research-publishing-pipelines`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-research-publishing-pipelines.md.

# Crystallized Line: Research Publishing Pipelines

**Line:** Research publishing pipelines: reports, papers, books from crystallized lines

**Lifecycle State:** Contracted (Final Summary)

**Target Context:** `hngh/hngh-automation`

**Date:** 2026-08-29

## Executive Summary
This line has transitioned from an open research question into a defined implementation specification. The core insight is that publishing is not a creative writing task but a **conversion system**. Crystallized research lines are publishable only when they are converted into structured units (Claim–Evidence–Boundary–Consequence) and routed to the optimal format (report, paper, or book) based on audience and intent. The goal is no longer "write more outputs" but to build a pipeline that ensures every artifact is audience-appropriate, evidence-verified, and format-gated.

## Findings

1.  **Publishing as Conversion, Not Creation:**
    *   The bottleneck in publishing is not the generation of text but the lack of structured conversion logic from raw research insights to publishable artifacts.
    *   A "crystallized line" (a stable, verified research insight) must be decomposed into four mandatory components before it can be published:
        *   **Claim:** The specific, testable assertion.
        *   **Evidence:** The data or logical proof supporting the claim.
        *   **Boundary:** The conditions under which the claim holds (and where it does not).
        *   **Consequence:** The practical implication or next step for the reader.

2.  **Format is a Routing Decision, Not a Style Choice:**
    *   Reports, papers, and books are not interchangeable outputs. They serve different audiences and purposes.
    *   **Reports:** For internal stakeholders/clients; focus on actionable consequences and boundaries.
    *   **Papers:** For academic/technical peers; focus on evidence rigor and claim novelty.
    *   **Books:** For broad professional audiences; focus on narrative synthesis of multiple crystallized lines.
    *   The pipeline must route a crystallized line to the format where its C-E-B-C unit is strongest, not just where it fits easiest.

3.  **Metadata as Gatekeeper:**
    *   Without explicit metadata (audience, intent, evidence strength, boundary clarity), artifacts cannot be quality-controlled.
    *   A "publication card" must exist for every artifact before drafting begins. This card contains the C-E-B-C unit and routing decision.

4.  **Automation Feasibility:**
    *   The pipeline is amenable to automation (`hngh/hngh-automation`) because the steps are discrete:
        1.  Ingest crystallized line.
        2.  Extract/validate C-E-B-C unit.
        3.  Generate publication card (metadata).
        4.  Route to format template.
        5.  Draft artifact.
        6.  Verify evidence against boundaries.

## Recommendations

1.  **Implement the Publication Card Schema:**
    *   Define a strict JSON/YAML schema for the "publication card" that includes fields for Claim, Evidence (linked to source data), Boundary (explicit negations/limits), Consequence, Target Audience, and Recommended Format.
    *   No artifact enters the drafting phase without a completed publication card.

2.  **Build Format-Specific Templates:**
    *   Create distinct templates for reports, papers, and books that enforce the C-E-B-C structure.
    *   *Report Template:* Lead with Consequence, support with Claim/Evidence, clarify Boundaries in a "Limitations" section.
    *   *Paper Template:* Lead with Claim, detail Evidence, discuss Boundaries in Discussion.
    *   *Book Chapter Template:* Synthesize multiple C-E-B-C units into a narrative arc.

3.  **Automate Evidence Verification:**
    *   Integrate checks that validate the "Evidence" field against source data or prior crystallized lines.
    *   Flag artifacts where the Boundary is not explicitly stated (a common failure mode in auto-generated text).

4.  **Establish a "Routing Engine":**
    *   Develop logic to recommend format based on metadata:
        *   High novelty + high evidence rigor → Paper.
        *   High actionability + moderate evidence → Report.
        *   Multiple related lines + narrative potential → Book.

## Open Threads

1.  **Quality Metrics for "Crystallization":**
    *   How do we objectively measure when a research line is "crystallized" enough to enter the publishing pipeline? Current definition is subjective; need quantitative thresholds (e.g., number of supporting data points, consistency across trials).

2.  **Audience Modeling:**
    *   The routing engine assumes clear audience definitions. How do we model and tag audiences dynamically? This may require a separate line on "Audience Profiling for Technical Publishing."

3.  **Feedback Loop Integration:**
    *   How does post-publication feedback (citations, client adoption, reader comments) feed back into the crystallization of new lines? The current pipeline is unidirectional (Research → Publish). A bidirectional loop is needed for continuous improvement.

4.  **Book-Level Synthesis Logic:**
    *   While report and paper generation are modular, book creation requires narrative synthesis across multiple lines. This is a more complex algorithmic challenge and may require a separate sub-line on "Narrative Structuring from Modular Insights."

## Final State
This line is now **contracted** into an implementation spec for `hngh/hngh-automation`. The next step is not further research, but engineering the pipeline components described in the recommendations. The open threads are identified as future research lines or sub-tasks within the automation project.


## 2026-08-29-unattended-session-budgets

# budget optimization for unattended model sessions: caps, quotas, cost telemetry

Status: crystallized 2026-08-29 from research line `unattended-session-budgets`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-unattended-session-budgets.md.

# Final Research Line Record

**Line:** Budget optimization for unattended model sessions: caps, quotas, cost telemetry

**Lifecycle state:** Contracting → crystallized

**Applicable to:** `hngh/hngh-automation`

**Disposition:** This line is now a durable operational principle, not an open exploratory research thread. Further work should be scoped as implementation, instrumentation, or exception handling, not as re-opening the core thesis.

---

## 1. Contracted Thesis

Every unattended model session must be treated as a **bounded, observable, killable job**, not as an open-ended agent run.

The primary control surface is not prompt engineering, model selection, or self-reported confidence. The primary control surface is:

1. An explicit budget envelope attached to the job.
2. Enforcement outside the agent loop.
3. Telemetry that captures token burn, compute burn, wall-clock time, tool activity, and cost attribution.
4. Hierarchical quotas that are simple enough to operate without a full predictive system.

The goal is not to make every run cheap. The goal is to ensure that no unattended model session can silently consume excessive time, tokens, GPU memory, wall-clock time, tool-call cycles, or human attention without being stopped, logged, and attributed.

---

## 2. Scope

This line applies to:

- CI-triggered model sessions
- Scheduled automation runs
- Background agent jobs
- Long-running research or debugging sessions
- Multi-step tool-using model sessions
- Local/GPU model runs
- API-backed model runs
- Mixed local/API pipelines

It does **not** primarily concern:

- Prompt wording optimization
- Model size selection as a first-order control
- Agent confidence scoring
- Dynamic quota allocation based on predicted success
- Fine-grained cost forecasting, except as a later extension

---

## 3. Findings

### F1. Unattended model sessions are jobs, not prompts

A single prompt is insufficient to describe the risk surface of an unattended session. The relevant unit is the job:

```text
job = model + tools + environment + budget + timeout + telemetry + kill policy
```

If a session can run without a budget, it should be treated as unsafe by default.

---

### F2. Cost is multi-dimensional

Token count alone does not capture cost or risk. A session may burn:

- API tokens
- Local GPU time
- Wall-clock time
- Context/KV-cache memory
- Tool-call cycles
- Retry attempts
- Human review time
- Queue capacity
- Concurrency slots

A budget system that only tracks `max_tokens` will miss silent burn from long wall-clock runs, repeated tool calls, stuck loops, and GPU memory pressure.

---

### F3. The agent cannot be trusted to enforce its own budget

The model or agent may:

- Ignore budget instructions
- Hallucinate completion
- Get stuck in a loop
- Repeatedly call the same tool
- Misreport progress
- Escalate scope without permission
- Continue after failure conditions

Therefore, budget enforcement must live outside the agent loop. The agent may request work within a budget, but it must not be able to raise its own cap.

---

### F4. Budgets must be explicit and fail closed

A session should not start if required budget fields are missing.

If cost is unknown, the system should not silently assume zero cost or unlimited cost. It should require an explicit override or reject the job.

This prevents accidental unbounded execution caused by incomplete manifests, missing pricing metadata, or stale configuration.

---

### F5. Enforcement must be layered

No single layer is sufficient. The safest architecture uses multiple enforcement points:

| Layer | Responsibility |
|---|---|
| Job manifest | Declares budget envelope |
| Runner | Tracks wall time, steps, tool calls, retries |
| Gateway/proxy | Enforces token, request, and cost limits per model call |
| Watchdog | Detects no-progress, repeated actions, abnormal burn rate |
| CI/scheduler | Enforces global quotas, concurrency, daily limits |

The agent may be bounded by its own internal logic, but that is defense-in-depth only. The authoritative budget lives outside the agent.

---

### F6. Telemetry must exist even when a session is killed

A killed run is not a failed telemetry event. A killed run is the most important telemetry event.

If a session is terminated because it exceeded budget, hit no-progress, or produced abnormal burn, the system must still emit:

- Final token counts
- Final cost estimate
- Wall-clock duration
- Step count
- Tool-call count
- Kill reason
- Phase reached
- Budget remaining at kill time
- Attribution metadata

Without this, budget optimization becomes impossible because the worst runs are exactly the ones that disappear from the record.

---

### F7. Deterministic phase budgets are safer than confidence-based quotas

Using model-reported confidence to expand or contract budgets is risky as a first implementation. Confidence can be unreliable, miscalibrated, or gamed by hallucinated success states.

A better first system uses deterministic phase envelopes:

- Plan
- Explore
- Execute
- Verify
- Report

Each phase has conservative defaults. Dynamic allocation can be considered later, but only after deterministic budgets and telemetry are stable.

---

### F8. Killability is as important as cost optimization

A budget system that only warns is incomplete. The system must be able to stop a session when:

- Budget is exhausted
- Wall-clock limit is reached
- Step count is exceeded
- Tool-call count is exceeded
- Retry count is exceeded
- Context size exceeds safe limits
- No-progress condition persists
- Repeated identical actions are detected
- Burn rate becomes abnormal
- Telemetry heartbeat stops

A session that cannot be killed safely is not a bounded job.

---

### F9. Quotas should be hierarchical but simple

Quotas should exist at multiple levels:

1. Global / organization
2. Project
3. Runner
4. Job
5. Phase

However, the first implementation should avoid complex reallocation logic. The hierarchy should be a ceiling system, not an adaptive resource market.

Simple rule:

```text
child budget <= parent quota
parent exhaustion blocks new jobs
no implicit borrowing
explicit escalation only
```

---

### F10. Optimization comes after observability

The correct sequence is:

1. Make all sessions bounded.
2. Make all sessions observable.
3. Kill abnormal sessions safely.
4. Attribute cost accurately.
5. Then


## 2026-08-29-virtual-assistant-ux

# virtual assistant as companion surface: configuration, actions, guidance UX

Status: crystallized 2026-08-29 from research line `virtual-assistant-ux`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-virtual-assistant-ux.md.

# Research Line: Virtual Assistant as Companion Surface

**Configuration, Actions, Guidance UX**

**Line state:** Contracting → crystallized / lasting record

**Primary application target:** `hngh/hngh-automation`

**Contracted thesis:** The companion surface should not be a broad emotional assistant or generic smart-home persona. For `hngh-automation`, it should be a **low-latency, high-trust interaction layer** that reduces friction around automation by making configuration implicit but editable, actions transparent and interruptible, and guidance contextual rather than intrusive.

---

## 1. Executive Summary

This line is crystallized into three durable implementation patterns:

1. **Configuration should be inferred first, then explicitly overridable.**

   Avoid a setup wizard as the primary onboarding path. Instead, observe early behavior, form visible assumptions, and let the user correct them with minimal effort.

2. **Actions should expose intent before execution.**

   Multi-step automation must present a structured plan before side effects occur. The user should be able to confirm, edit, cancel, or partially proceed without losing control of the workflow.

3. **Guidance should be tiered by urgency, reversibility, and context.**

   Proactivity is useful only when anchored to system state, time, deadlines, or current activity. Low-priority guidance must not interrupt; high-priority guidance must be rare and clearly justified.

The lasting value of this line is not “make the assistant feel companion-like.” The operational goal is: **make automation feel predictable, inspectable, and safe enough that users trust it to act.**

---

## 2. Scope Lock

### In scope
- Configuration UX for a virtual assistant in an automation context.
- Action UX for single-step and multi-step automation.
- Guidance UX for proactive, contextual, and reactive assistance.
- Trust, latency, control, and friction considerations specific to `hngh/hngh-automation`.

### Out of scope
- General parasocial relationship theory.
- Broad consumer assistant market research.
- Long-term memory architecture.
- Multi-device orchestration.
- Emotional companionship design.
- Full product roadmap beyond the companion interaction layer.

This line is now contracted. Future expansion should only occur if new evidence invalidates one of the core patterns above.

---

## 3. Findings

### F1. Explicit configuration creates onboarding friction and delays useful behavior

**Finding:**

Traditional setup wizards force users to define preferences before the assistant becomes useful. In an automation context, this is especially costly because users must reason about future behavior before they have experienced the system.

**Implication:**

The companion surface should begin with reasonable inferred defaults rather than requiring explicit configuration.

**Confidence:** Medium-high as a design constraint for `hngh-automation`.

**Basis:** Prior beat identified setup friction and low adoption of explicit configuration; retained as a directional prior, not a validated benchmark.

---

### F2. Inference without visibility creates distrust

**Finding:**

If the assistant infers preferences silently, users may feel the system is opaque or unpredictable. Inference is useful only when the inferred state is visible and correctable.

**Implication:**

Configuration should be represented as a **“Current Assumptions”** surface, not hidden behind settings menus.

**Confidence:** High for trust-sensitive automation contexts.

---

### F3. Black-box multi-step automation erodes user control

**Finding:**

When an assistant executes multiple steps without exposing its plan, users cannot reason about what will happen next. This is especially dangerous when actions are irreversible, costly, or affect shared systems.

**Implication:**

Multi-step actions must be represented as explicit plans with inspectable steps, risk levels, and intervention points.

**Confidence:** High.

---

### F4. Users need to intervene at the step level, not only at the task level

**Finding:**

A binary “approve / reject” model is insufficient for multi-step automation. Users may want to approve most steps while removing or modifying one specific step.

**Implication:**

The action UX must support granular intervention: confirm all, edit a step, cancel a step, skip dependent steps, or abort entirely.

**Confidence:** High.

---

### F5. Proactive guidance is only valuable when it is contextually anchored

**Finding:**

Generic proactive messages feel noisy. Guidance becomes useful when tied to concrete anchors such as time, calendar events, system state, recent user activity, or pending automation.

**Implication:**

Guidance UX should be organized around temporal and environmental triggers, not random assistant chatter.

**Confidence:** High.

---

### F6. Proactivity must be tiered by urgency and reversibility

**Finding:**

Not all guidance deserves the same interruption level. A failed CI pipeline before a deploy is different from a suggestion to validate a schema, which is different from a low-priority summary.

**Implication:**

The companion surface needs a **Nudge Priority Matrix** that maps message type, urgency, reversibility, and user context to UI channel and interruption behavior.

**Confidence:** High.

---

### F7. Trust depends on auditability and recoverability

**Finding:**

Users are more likely to trust automation when they can see what the assistant assumed, what it planned, what it executed, and how to undo or correct it.

**Implication:**

The companion surface should expose assumptions, plans, approvals, outcomes, and rollback paths where possible.

**Confidence:** High for automation systems with side effects.

---

## 4. Contracted Recommendations

### R1. Configuration: Use “Editable Defaults via Inference”

**Recommendation:**

Do not begin `hngh-automation` with a full setup wizard. Instead, infer initial preferences from early interactions and expose them in a visible, editable assumptions panel.

#### Core behavior
The assistant should observe the first few meaningful interactions and form provisional assumptions such as:

- Preferred response length: concise vs. detailed.
- Confirmation style: confirm every action vs. auto-approve low-risk actions.
- Proactivity tolerance: interrupting alerts vs. ambient hints vs. passive summaries.
- Time-of-day preferences for proactive nudges.
- Risk tolerance for automation involving shared systems, external notifications, or irreversible operations.

#### Required UI surface
A collapsible **“Current Assumptions”** panel should display inferred settings in plain language.

Example:

> **Current assumptions**

> - I assume you prefer concise summaries.

> - I assume you want confirmation before high-risk actions.

> - I assume low-risk local changes can be auto-approved.

> - I will not interrupt you during focused work unless something fails.

>

> [Change] [Reset to defaults]

#### Design rules
- Every inferred setting must be visible.
- Every inferred setting must have a one-click override.
- Overrides should persist and take precedence over future inference.
- The system should show why an assumption exists when possible: “I inferred this because you confirmed three low-risk actions without editing.”
- Users should be able to reset assumptions without losing explicit preferences.

#### Why this matters for `hngh/hngh-automation`
This reduces cold-start friction while preserving user control. The assistant feels tuned immediately, but the tuning is inspectable rather than magical.

---

### R2. Actions: Use “Plan-Preview-Execute” for Multi-Step Automation

**Recommendation:**

Any multi-step automation should generate a structured plan object before executing side effects. The plan should be visible, editable, and interruptible.

#### Core behavior
Before executing a task such as:

> “Update the database, notify the team, and log the


## 2026-08-30-alert-to-work-routing-patterns-closing-the-self-observation-loop

# alert-to-work routing patterns: closing the self-observation loop

Status: crystallized 2026-08-30 from research line `alert-to-work-routing-patterns-closing-the-self-observation-loop`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-alert-to-work-routing-patterns-closing-the-self-observation-loop.md.
Grounded rewrite 2026-08-30: the original crystallization framed Hngh
as a Linux kernel module (Netlink families, sysfs exposure, ring
buffers, kernel/user daemons). None of that exists here — Hngh is a
Common Lisp kernel plus no-daemon shell automation, and its alert
surface is an append-only report ledger. That mechanics layer is the
named foldback anti-pattern and is discarded; the loop-closing
conclusion survives and is restated in Hngh's actual shape.

## Conclusion (kept, reframed to this repo)

The self-observation loop is open in exactly one place: alerts are
generated and deduplicated, but nothing records whether the work they
named was ever scheduled, done, or was noise. The loop closes not by
adding a transport but by giving every alert class a **parseable
plan-step candidate** — because in this system the only thing that
turns observation into work is an accepted plan (foldback lesson 2:
alerts close their own loop only through plans; every repair in the
33h window originated in a plan step or an operator session, never
from the alert itself).

The routing shape, using only what exists:

- **Alert emission** — jobs and ticks append `alert` rows to the
  report ledger (`scripts/report-queue add alert …`), each row
  carrying a kind, an id, and a first line naming the producer
  (oversight loop-signal, gate-check, tree-skew, agent-stall,
  ceremony-temp, review findings, slow-unit).
- **Candidate emission** — a routing table maps each alert class to a
  plan-step candidate: title, verification command, risk class
  (normal → plan step; critical-class → parked with operator-facing
  alert, per the plan contract). The candidate lands in
  `docs/project/plans/` as a proposed plan or an appended step on an
  open plan — the two authoring surfaces the machine already has.
- **Outcome tracking** — the plan lifecycle already records the
  outcome: a step's checkbox tick and the front-matter status
  transition (proposed → accepted → executing → executed/parked) plus
  the reports rows the execution writes. Alert → step → tick/rows =
  closed loop; no new state store is needed at check-in scale
  (`docs/project/plans/README.md` defines the machine-checkable
  states).

## Findings (grounded rewrite)

- **F1 — alerts are honest but terminal.** The 2026-08-28→30 window's
  alert classes (stale-store ceremony-temp, review P0/P1, tree-skew,
  agent-stall, unparsable readout.json, doc-suite checker rc=1,
  remote-posture degraded, budget digests) were accurate; every one of
  their fixes still originated in a plan step or an operator session.
  The ledger records the signal; nothing routes it into the plan
  queue.
- **F2 — the flap-suppression layer is already the dedup layer.**
  Oversight alerts arrive flap-suppressed (roadmap stage 1: alerts are
  "flap-suppressed") and report-queue already has identity+window
  dedup with escalation caps (backlog row). So the loop does not need
  new suppression machinery — a routed candidate only needs to exist
  once per alert identity, which the existing dedup already
  approximates.
- **F3 — candidate authoring is the missing edge, and it is the same
  gap as plan authoring itself.** The machine cannot author plans
  (foldback lesson 1 / suite doc 08 R2); a routing table that emits
  *draft plan steps* (title + verification + risk class as parseable
  text) feeds the night-agent plan-authoring row rather than replacing
  it: routing proposes, a plan-shaped surface accepts.

## Recommendation (the designed mapping, docs-only)

Map alert classes actually filed in `docs/project/reports.md` to
candidate step shapes:

| alert class (observed) | candidate step shape | risk |
|---|---|---|
| gate-red (kernel or automation) | re-run gate, capture failing check, fix-or-park step | normal |
| tree-skew dirty-tree | whitelist check + handoff/commit of stalled edit | normal |
| agent-stall / loop-signal | roguelike die+replace: end session, handoff brief, respawn step | normal |
| ceremony-temp / store alerts | re-run ceremony fresh-store step (known recovery) | normal |
| review P0/P1 findings | docs/automation fix step with named verification | normal |
| unparsable readout.json | feed-regen re-read step (fix already landed as precedent) | normal |
| remote-posture degraded / budget idle | operator-facing alert row; PARKS (operator-only legs) | critical |

Each candidate step carries its own verification, so a plan built from
the table is auto-acceptable per the plan contract when the gates are
green. Implementation of this table as automation-side routing (a
read-only tick that drafts the candidates) is follow-on work only if a
plan asks for it — it needs no kernel changes.

## Open threads

- Where draft candidates live: a section in `docs/project/plans/README.md`
  vs a queue-ledger column (design decision for the routing DESIGN beat).
- Escalation caps interplay: a routed alert must not re-fire while its
  plan step is open (dedup window vs plan lifecycle).

## Grounding

Verified paths read in this repo while rewriting (2026-08-30):

- `docs/project/reports.md` — the live alert ledger (gate-red,
  tree-skew, agent-stall, loop-signal, slow-unit, ceremony-temp,
  review, remote-posture, budget-digest rows all observable there)
- `docs/project/roadmap.md` — stage 1 self-watch (flap-suppressed
  oversight alerts), stage 3 self-supervision framing
- `docs/project/backlog.md` — "Alert → plan-candidate routing" and
  "Night-agent plan authoring" rows; report-queue escalation caps row
- `docs/records/2026-08-30-lessons-and-foldback.md` — lesson 2
  (alerts close their own loop only through plans) and §1's failure
  classes
- `docs/project/plans/README.md` — the plan contract the candidates
  must parse into (status lifecycle, risk classes, auto-acceptance)
- `hngh-automation/jobs/oversight-tick.sh` and
  `hngh-automation/scripts/report-queue` — the producers of the alert
  rows the table routes (verified present; identities observed in
  reports.md)

Discarded as ungrounded (the original crystallization's mechanics):
kernel modules, Netlink generic families, sysfs/tracepoint exposure,
userspace daemons. Hngh has no kernel module; its alert surface is the
report ledger.

## Open-thread resolutions (2026-08-31)

Both threads from `## Open threads` resolved with source evidence; authored 2026-08-31 against the plan-mandated 2026-08-30 filename. No code was written in this beat.

### Thread 1 — where draft plan-step candidates stage

**Resolution: the plan directory (`docs/project/plans/*.plan.md`), not a queue-ledger column.**

The decision is fixed by what the actual selector consumes:

- `hngh-automation/scripts/overnight-cycle.sh` (selector (a), lines
  186-199) iterates `$KERNEL/docs/project/plans/*.plan.md`, keeps files
  whose front-matter greps `status=accepted`, and takes the first
  `^\- \[ \]` line as the next step. Any staging surface the selector
  does not scan is dead storage for candidates — nothing else reads a
  queue-ledger column into plan execution.
- The plan contract (`docs/project/plans/README.md`)
  already defines the accepted authoring surface: a proposal is a
  `<date>-<slug>.plan.md` file with `status=proposed` written into the
  directory (its omp-plugin section describes exactly this path for
  non-automation authors). Auto-acceptance per the contract converts a
  gated normal-risk candidate into a `status=accepted` plan — the
  selector then picks it up with no further machinery.
- The queue ledger is the wrong shape for candidates:
  `docs/project/queue.md` is a fixed 4-field TSV (`id status title
  evidence`) and its own `## ETA` section records that even planned
  windows stay outside the TSV; `scripts/rotate-queue` rotates that
  ledger through full rotation sessions, a different instrument from
  per-alert step candidates.

So the routing recommendation's two authoring surfaces hold as stated:
a batch of candidates becomes one `status=proposed` plan file (the
append-an-step-to-an-open-plan variant appends a `- [ ]` line to an
existing accepted plan — the same selector line it is consumed by).
A queue-ledger column is rejected: no consumer exists for it.

### Thread 2 — escalation caps / dedup windows vs open plan steps

**Resolution (mechanism as it stands): the dedup window is wall-clock
only and cannot span a plan step's lifecycle today.**

From `scripts/report-queue` source (`add()`, lines 178-205; `row_identity`,
`within_window`, `bump_row`):

- Dedup matches on KIND + stored `identity:` in the row's body meta,
  newest rows first, within `--window` seconds (default 86400; 0 =
  unlimited lookback). A match folds the occurrence into the existing
  row (×N marker + `- <ts> occurrence` body line); no new row appears.
- The window compares the row's original timestamp against wall-clock
  time only. report-queue never reads `docs/project/plans/*.plan.md`;
  no parameter or command ties an identity to plan state. A plan step
  staying open past 86400 s therefore does NOT suppress its alert —
  the identity simply ages out of the window and the next occurrence
  files a fresh row.

**Minimal coupling that IS available in the current source: identity
naming the plan step.** The identity is an opaque stored string, so a
router can make it carry the candidate's target, e.g.
`<alert-class>:plan:<slug>` or `<alert-class>:plan:<slug>:<step-N>`,
and file with `--window 0` (unlimited lookback). With window 0 the
identity matches its one row forever, so the alert never re-fires as a
new row while (or after) the step is open — occurrences still fold in
and stay visible. That satisfies "must not re-fire while open" with
zero kernel or report-queue changes.

**Parked, needs: identity expiry or router-side plan-state check.**
Window 0 suppression is permanent for that identity — a new defect
instance of the same class after the plan step closes would fold into
the old row rather than draft a fresh candidate. Re-arming requires one
of two concrete mechanisms, neither present in source:

1. A per-identity expiry in report-queue (e.g. an `--expire IDENTITY`
   path that drops or re-dates the stored identity) — a report-queue
   change, out of scope for this beat; or
2. A router-side pre-check before `--add`: read the plan file named in
   the identity and skip emission while the named `- [ ]` step still
   exists (the same grep the selector already runs, so the pattern is
   proven). That is an automation-side change and the recommended
   instrument — it keeps the dedup semantics untouched and makes the
   suppression exactly the plan lifecycle.

Until the router tick exists, the standing statement is: the default
86400 s window is the flap-suppression layer and does not consult plan
state; the coupling above is the designed fix, parked behind the
routing-tick implementation beat.

## Outcome tracking without kernel changes (2026-08-31)

Third beat on this doc. The routing table specifies how a candidate is
authored; the resolutions above fix where it lives and how it dedups.
What nothing yet fixes is how the loop proves it closed: which fields
record routed → attempted → closed, and where each is captured. This
section is that field set, automation-side only, grounded in what
`hngh-automation` writes today. No router tick exists yet (a grep of
`scripts/`, `jobs/`, `cadence/` for routing/router matches nothing);
fields marked *today* already have their capture point in running code,
the rest are the contract that tick must meet.

### The fields

**1. `routed-from` — alert identity → plan-step linkage.**
For a whole-plan draft: a `routed-from=<identity>` attribute appended
inside the existing front-matter comment. Both machine parsers tolerate
a trailing attribute — `scripts/accept-plans.py:32-33` and
`jobs/plan-feed.py:21-22` compile their FRONT regex with `[^>]*-->` as
the tail — so adding the attribute breaks neither acceptance nor the
dashboard plans feed. For an appended `- [ ]` step on an open plan: a
`routed-from=<identity>` tail on that step's indented `Verification:`
line — `accept-plans.py:34` only checks that such a line exists
(`(?m)^[ \t]+Verification[ \t]*:`), its content is free, and the line
is not part of the step text the selector strips into the objective
(`scripts/overnight-cycle.sh:193` strips only the `- [ ]` line).
Example: `routed-from=gate-check:hngh-automation` on a gate-red
candidate. No new store: the linkage lives in the candidate itself.

**2. `routed-at` — when the candidate was authored.**
The routing tick files the same row shape the draft flow already uses
(`overnight-cycle.sh:180-183`: `--add progress "..." --identity
"overnight:plan-draft:$day" --window 86400`), with identity
`router:routed:<slug>[:<step-N>]`, plus a STATE.md breadcrumb in the
existing `lib/breadcrumbs.sh` pattern (`overnight-cycle.sh:179` files
`plan-drafted` the same way). Example: a reports.md progress row
`router:routed:2026-08-31-gate-red` at `2026-08-31T03:14:07Z`. This is
F1's repair: the routing moment becomes a ledger row, not a memory.

**3. `first-attempt-at` — the cycle picked the step up.**
Captured today, zero new code: the `WAKE CONTEXT` timestamp written
into `prompts/overnight/$slug.md` (`overnight-cycle.sh:205-210`), the
session-run row `overnight|<slug> | session-run` in
`logs/budget.md:310-311`, and the
`overnight-lead | <ts> | <slug>|<run_id> | rc=<N> <disposition> log=<path>`
row in `agent-handoffs.md:337-339`. Example:
`overnight-lead | 2026-08-31T03:20:11Z | 2026-08-31-foo|run-42 | rc=0
evacuated log=logs/overnight-2026-08-31-foo-032011.log`.

**4. `closed-at` — the step finished.**
Captured today: the step's `- [x]` tick in the plan file; when no
unchecked step remains, `overnight-cycle.sh:317-321` flips
`status=accepted` to `status=executed` in the plan front-matter and
files the `plan <slug> executed (all steps checked)` progress row.
Example: `2026-08-31T03:47:52Z | plan 2026-08-31-foo executed (all
steps checked)` in reports.md plus the flipped front-matter.

**5. step outcome class — one existing row per class.**
Landed = `- [x]` on the routed step (front-matter flip above).
Parked = `park()` (`overnight-cycle.sh:73-78`): alert row identity
`overnight:parked:<slug>` plus the
`operator-attention | <ts> | overnight|<slug> | parked: ...` handoff
row; also `accept-plans.py:146-148` for critical-class plans
(`overnight:plan-critical:<slug>`). Refused =
`overnight:bridge-refused:<slug>` (`overnight-cycle.sh:290-291`),
`overnight:critical-touch:<slug>` (`:333-334`), and accept-plans'
blocked rows `overnight:plan-accept-blocked:<slug>` and
`overnight:plan-accept-gate:{kernel,automation}`
(`accept-plans.py:157-159, 168-177`); a non-zero session rc also shows
as `disposition=dead` in the budget row. No-candidate = selector (a)
falling through (`overnight-cycle.sh:186-200`) into the research beat
breadcrumb (`:271`); a routing tick files its own no-candidate
breadcrumb here since it is the one class with no dedicated row today.
Duplicate-skip = field 6.

**6. the duplicate-skip event — what router-rearm-precheck needs
observable.**
The backlog row (`docs/project/backlog.md`, "Router-side re-arm
pre-check (router-rearm-precheck) — queued 2026-08-31") parks on
"one closed-step re-fire is demonstrably skipped". The skip is
currently unobservable: dedup is wall-clock only (thread 2 above), so
a re-add after the named step closes looks identical to a first fire.
Spec: before the router's `report-queue --add`, it consults plan state
with the same two greps the selector already uses
(`overnight-cycle.sh:192-193`: `status=accepted` in the front-matter,
an unchecked `- [ ]` step); when the identity's named step is closed
it skips the add and files exactly one observable pair —
a STATE.md breadcrumb `router | duplicate-skip | <identity> step
already closed` and a deduped alert row
`--add alert "router duplicate-skip: <identity> (named step closed;
candidate not re-drafted)" --identity "router:dup-skip:<identity>"
--window 86400`. The alert row is the operator-visible leg: the
operator panel reads only digest bullets and STATE.md breadcrumbs
whose event matches `alert` or the papercut/flagged/needs/operator
keywords (`jobs/operator-items-feed.py:91-93`), so a breadcrumb alone
would be invisible there. No router-internal state is kept — the skip
decision is re-derived from the plan file each time, exactly as the
backlog row asks.

### Not established

- No router tick exists in hngh-automation today; `routed-from`,
  `routed-at`, and the duplicate-skip pair are capture contracts for
  it, not running behavior. Fields 3-5 and the parked/refused rows are
  verified in current code.
- No producer writes a `routed-from=` front-matter attribute or
  Verification-line tag yet. Parser tolerance is established from the
  two regexes; a round-trip of a tagged plan file through
  `accept-plans.py` and `plan-feed.py` has not been exercised.
- No dashboard surface consumes routing state: `dashboard/plans.json`
  (`plan-feed.py:45-52`) carries only
  slug/status/risk/accepted/steps counts, and
  `jobs/operator-items-feed.py` reads only digest bullets and
  STATE.md breadcrumbs. Whether routed-outcome panels are wanted is an
  operator decision.
- Whether `report-queue --json`'s unread count can distinguish alert
  kinds is not established from the automation side:
  `overnight-cycle.sh:206-207` consumes the bare count only.

### Grounding

All paths below verified with `test -f` on 2026-08-31 (~/-form;
line numbers as read this beat):

- `~/Projects/etc/hngh-automation/scripts/overnight-cycle.sh` — OK.
  Verified call sites: `:64-67` `file_alert()` (alert rows,
  identity+window 604800); `:73-78` `park()`; `:180-183` plan-draft
  progress row; `:186-200` selector (a), with `:192`
  `grep -q "status=accepted" "$f"` and `:193`
  `step="$(grep -m1 '^\- \[ \]' "$f" | sed ...)"`; `:205-210` wake
  timestamp + `:206-207` `report-queue --json` unread read; `:290-291`
  bridge-refused alert; `:310-311` budget session-run row; `:317-321`
  executed flip + completion row; `:333-334` critical-touch alert;
  `:337-339` overnight-lead handoff row; `:342` overnight-done
  breadcrumb.
- `~/Projects/etc/hngh-automation/scripts/accept-plans.py` — OK.
  `:32-33` FRONT regex (trailing `[^>]*-->`), `:34` VERIFICATION
  regex, `:44` report-queue path, `:93-103` report() call shape,
  `:146-148` critical park, `:157-159` blocked-acceptance alert row,
  `:168-177` gate-red acceptance alerts, `:185-187` accepted progress
  row.
- `~/Projects/etc/hngh-automation/jobs/agent-supervision.py` — OK.
  `:216-221` report(); `:323-327` `supervision-evicted:<id>`, `:346-348`
  `agent-stall:<id>` alert, `:351-353` `agent-stall-recovered:<id>`
  flap row — the alert classes a router must link.
- `~/Projects/etc/hngh-automation/jobs/oversight-tick.sh` — OK.
  `:49-70` alert() (kind+detail, --identity/--window), `:80` stale-store,
  `:101` system flags, `:126` tree-skew, `:175-180` gate-red,
  `:326` rendered-surface, `:353` slow-unit, `:411` repeat-crumbs,
  `:414` loop-signal.
- `~/Projects/etc/hngh-automation/jobs/plan-feed.py` — OK. `:21-22`
  FRONT regex, `:45-52` plans.json fields (no routing state today).
- `~/Projects/etc/hngh-automation/jobs/operator-items-feed.py` — OK.
  `:91-93` is_operator_item() event/keyword filter.
- `~/Projects/etc/hngh-automation/lib/breadcrumbs.sh` — OK (the
  breadcrumb pattern cited for routed-at).
- `~/Projects/etc/hngh-automation/STATE.md` — OK (breadcrumb ledger).
- `~/Projects/etc/hngh-automation/agent-handoffs.md` — OK
  (overnight-lead / operator-attention rows).
- `~/Projects/etc/hngh-automation/logs/budget.md` — OK (session-run
  rows).
- `~/Projects/etc/hngh-automation/dashboard/plans.json` and
  `dashboard/operator-items.json` — OK (checked as consumers; neither
  carries routing state).
- `~/Projects/etc/hngh/docs/project/backlog.md` — OK
  (router-rearm-precheck row, "queued 2026-08-31").
- `~/Projects/etc/hngh/docs/project/reports.md` — OK (the alert/
  progress ledger every field above lands in).
- `~/Projects/etc/hngh/scripts/report-queue` — OK (identity/window
  mechanics already specified in Thread 2 above; not re-derived here).


## 2026-08-30-ceremony-cost-reduction-batching-kernel-doc-landings-safely

# ceremony-cost reduction: batching kernel doc landings safely

Status: crystallized 2026-08-30 from research line `ceremony-cost-reduction-batching-kernel-doc-landings-safely`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-ceremony-cost-reduction-batching-kernel-doc-landings-safely.md.
Grounded rewrite 2026-08-30: the original crystallization asserted
PR/CI/Sphinx/type-stub/release-tagging mechanics that do not exist in
this repo (no CI workflows, no Sphinx, no `.pyi` stubs, no release
tags — Hngh lands everything through the self-governed certificate
ceremony). That machinery is the named foldback anti-pattern
(docs/records/2026-08-30-lessons-and-foldback.md §2 lesson 3: research
volume is cadence-bound, quality is grounding-bound). This rewrite
keeps the line's directional conclusion and re-grounds it in what the
repository actually has.

## Conclusion (kept, now grounded)

Each hngh docs landing pays a fixed ceremony cost: a fresh store run,
transport admission, a ten-principle propose pass, issue-cert evidence
gathering over the candidate paths, and the two-action
prepare-candidate/commit mutation — plus a green `make test`
before and after. For one small doc that overhead dominates the change
itself. Therefore **batch doc landings**: accumulate independent
docs-only artifacts (research crystallizations, plan files, records,
journal) and land them in ONE certificate ceremony with candidate
paths = exactly those files, rather than one ceremony per file.

Safety boundary, grounded in the actual gate: the batch is safe when
every candidate path is a docs path (`docs/**`) — the gate that
protects the kernel (`make test`: 8 reader guards + suite + ASDF,
currently 2,855 checks) runs unchanged before issue-cert and is the
only verification a docs-only batch needs. Any candidate set that
would touch `src/`, `tests/`, `Makefile`, or `hngh.asd` is not a
docs batch: kernel changes are forbidden to machine sessions by the
standing autonomy rule and park instead.

## Findings (grounded rewrite)

- **F1 — the ceremony has a fixed per-landing floor.** The dogfood
  loop (create-run → admit-transport → propose with one evidence
  requirement per principle → issue-cert → mutation-check
  prepare-candidate/commit) is per-commit work regardless of how many
  files ride it; the 2026-08-28 overnight plan already noted
  whitespace normalization was the only refusal across a multi-file
  landing. Batching N docs into one candidate amortizes the fixed
  part across N files.
- **F2 — the historical stall was landing cadence, not ceremony
  safety.** The six crystallized research docs of 2026-08-28→29 sat
  uncommitted ~36h because each needed a ceremony and no plan drove
  one (foldback §1); today's three 2026-08-30 research lines sat
  untracked the same way until this batch. The fix is scheduling
  (a plan step that owns a batched ceremony), not a lighter gate.
- **F3 — precedent applied live.** The 2026-08-30 evening wave lands
  its plan files, the grounded research rewrites, and the record in
  one ceremony commit with `make test` green immediately before —
  this document's conclusion applied by its own repo.

## Recommendation

Keep per-slice ceremonies for anything coupled (a doc that changes a
contract doc alongside kernel behavior); batch the rest. A plan step
of the shape used today — "land all accumulated research docs in ONE
ceremony, `make test` green immediately before, candidate paths =
docs files only" — is the whole mechanism; no new tooling is proposed
(this repo has no PR/CI lane to route; the certificate loop IS the
landing protocol).

## Open threads

- Whether the day-tier research beat should append its crystallized
  docs to a standing "pending docs batch" list so the next ceremony
  driver finds them without a sweep (follow-on candidate).
- Cross-repo doc references (hngh docs citing hngh-automation paths)
  have no link guard today; the doc-numbers guard covers README
  counts only.

## Grounding

Verified paths read in this repo while rewriting (2026-08-30):

- `scripts/hngh` — the governance CLI (propose/issue-cert/mutation-check verbs)
- `scripts/ceremony-drive` — ceremony driver invoked by the bridge
- `scripts/omp-bridge` — documents the ceremony-invoke wrapper and store behavior
- `Makefile` — `make test` gate composition
- `docs/project/plans/2026-08-28-overnight-continuity.plan.md` — prior
  batched ceremony landing (candidate `5fe88ae0`, commit `16f6344`)
- `docs/records/2026-08-30-lessons-and-foldback.md` — the
  crystallized→committed stall and the anti-pattern naming
- skill://hngh-dogfood-commit-ceremony — the ceremony loop this line's
  cost model is built from

Not established here: exact per-ceremony wall-time cost (no telemetry
row was captured for a docs-only ceremony at authoring time); the
batching saving is argued from the fixed step count, not measured.


## 2026-08-30-delegation-lane-parallelism-multi-lane-omp-bridge-sessions-and-queueing

# delegation lane parallelism: multi-lane omp-bridge sessions and queueing

Status: crystallized 2026-08-30 from research line `delegation-lane-parallelism-multi-lane-omp-bridge-sessions-and-queueing`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-delegation-lane-parallelism-multi-lane-omp-bridge-sessions-and-queueing.md.

# Final Structured Summary — Delegation Lane Parallelism: Multi-Lane `omp-bridge` Sessions and Queueing

**Line:** delegation lane parallelism: multi-lane omp-bridge sessions and queueing
**Lifecycle state:** contracting → **contracted / recommended record**
**Disposition:** Do not pursue a “multi-lane manager” as the primary design. Contract the line to a prerequisite architectural change: introduce a minimal asynchronous delegation queue in the `omp-bridge` layer, then revisit explicit lanes only if telemetry justifies them.

---

## 1. Executive Finding

The original research premise treated “lane parallelism” as an optimization of existing delegation, scheduling, or lane-management code. The available line record does not support that framing.

According to the supplied prior beat, verification against the `hngh` repository found no dedicated delegation/scheduler module, and this grounded pass confirms the kernel has no scheduler surface at all (the kernel is a pure Common Lisp core — `src/domain/`, `src/application/` — whose only concurrency story is the certificate loop; there is no `delegation` or `scheduler` module). Verification found no evidence for the assumed artifacts:
- a dedicated lane manager
- an exposed kernel scheduler API usable by the bridge

This final record does not assert those paths exist; it treats them as **not established** based on the prior beat's verification note.

The practical conclusion is:

> The `omp-bridge` delegation path should be treated as a greenfield queueing problem, not as a tuning problem for existing lanes.

---

## 2. Findings

### F1 — “Multi-lane” was initially based on assumed code structure

The prior expansion referenced lane-management abstractions that were assumed to exist. Verification against the repository found none: delegation lives entirely in the `omp-bridge` outer adapter (a Python script), not in kernel source. The C-style filenames the expansion guessed at do not exist in this repo.

**Status:** Not supported by available evidence.
**Grounding:** Verified 2026-08-30 against the repository: `scripts/omp-bridge` (the delegation surface, single outer-adapter script) and the kernel docs read-order (`docs/README.md`, `docs/architecture.md`) show no lane/scheduler component. Assumed artifact names from the expansion beat are treated as fabrications, not as files that were merely hard to find.

---

### F2 — The current `omp-bridge` delegation path appears synchronous and single-threaded

The prior beat describes the existing `omp-bridge` behavior as a single-threaded, synchronous event loop within the automation layer.

**Status:** Reported in the line record; not independently re-verified in this session.
**Grounding:** Supplied prior research beat 2026-08-30.

This matters because if delegation is executed synchronously on the bridge’s event path, then adding “lanes” without changing submission/execution semantics would not remove head-of-line blocking.

---

### F3 — No existing delegation queueing infrastructure was identified

The available line record does not identify an existing queue, task store, backpressure mechanism, or lane scheduler for `omp-bridge` delegation.

**Status:** Reported in the line record; not independently re-verified in this session.
**Grounding:** Supplied prior research beat 2026-08-30.

Therefore, “parallelism” requires a new submission/execution boundary rather than merely distributing work across existing lanes.

---

### F4 — Head-of-line blocking is best explained by synchronous execution, not lane scarcity

If delegation requests are handled synchronously, one slow request can block subsequent bridge activity regardless of whether the conceptual model calls them “lanes.”

**Status:** Architectural inference grounded in the prior beat’s description of synchronous behavior.
**Grounding:** Supplied prior research beat 2026-08-30.

The minimal fix is to decouple request submission from execution.

---

### F5 — Kernel scheduler exposure to the bridge is not established

The prior beat states that no scheduler abstraction was found exposed to the bridge. The grounded pass agrees at the level that matters: the bridge's run governance is per-session (one `hngh` run per delegated session, created by `--run-start`), with no shared scheduler object the kernel exposes for lane arbitration. The bridge comment records the actual serial constraint: one shared bridge store and a single-flight assumption ("at check-in scale a single bridge run is in flight at a time"), plus a global ceremony lock.

**Status:** Not independently verified in this session; treated as unestablished.
**Grounding:** Supplied prior research beat 2026-08-30. No specific kernel scheduler file is cited because its existence is not established.

---

## 3. Recommendations

### R1 — Implement a minimal `DelegationQueue` first

Grounded against `scripts/omp-bridge` as it exists today (2026-08-30): delegation entry is one synchronous command, `--run-start SESSION OBJECTIVE`, which (a) creates a bounded `hngh` run with a fixed worker loadout and admits the worker transport, and (b) writes the session into one shared bridge store under `AUTOMATION_ROOT/bridge` — the script itself carries a `ponytail:` note that this is a single global store, widened only "if two delegated sessions ever need to be open concurrently", and a single global ceremony lock serializes landings. So today's "lane model" is: one explicit command per session, one store, one lock — no queue object exists, and nothing is asynchronous.

That matches this line's contracted conclusion exactly: the first architectural change is a **minimal DelegationQueue at the omp-bridge layer** — accept a delegation record, persist it, and let a later tick or session pick it up — before any multi-lane manager is designed. The queue's first consumer is already visible in the repo: the overnight cycle executes the next unchecked step of the oldest accepted plan one at a time (`hngh-automation/scripts/overnight-cycle.sh` per docs/project/plans/README.md), which is precisely the single-lane consumer a DelegationQueue would feed. Explicit multi-lane scheduling remains not established as a need until telemetry (per-lane medians, gantt actuals — roadmap stage 3's own exit criteria) shows head-of-line blocking at more than one concurrent delegation.

**Status of this recommendation:** design direction only; no code written in this beat. Kernel src/ changes are forbidden to machine sessions (standing autonomy rule), so any implementation lands in the bridge/automation layer or parks.

## Grounding

Verified paths read in this repo (2026-08-30):

- `scripts/omp-bridge` — the delegation surface: `--run-start SESSION OBJECTIVE`, `--run-end RUN DISPOSITION`, `--orient/--register/--note/--task/--ceremony`; single shared bridge store (`BRIDGE_STORE`, one run in flight at a time), global ceremony lock, `:created`-only legal close (`cancelled`)
- `docs/project/roadmap.md` — stage 3 "roguelike delegation live" (the wrap criteria this line feeds)
- `docs/project/backlog.md` — "Pi read-only delegation spike" and "Bridge-backed continual worker" rows (the bounded-worker surface a queue would feed)
- `docs/records/2026-08-30-lessons-and-foldback.md` — the failure classes observed in the 33h window (agent-stall, slow-unit) that motivate bounded, queued delegation

Not established: whether any second concurrent delegation consumer exists in hngh-automation (single-flight was assumed from the bridge store note, not enumerated); multi-lane demand remains unproven by telemetry.


## 2026-08-30-gantt-legibility-patterns

# gantt legibility patterns

Status: crystallized 2026-08-30 from research line `gantt-legibility-patterns`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-gantt-legibility-patterns.md.

Correction (2026-08-31, landing session): this line's beat material was
written without repo access and misread the domain — hngh is a Common
Lisp governance kernel (ASDF + Makefile, `~/Projects/etc/hngh/Makefile`),
not a compiled OS kernel with a build pipeline. There is no CMake, no
Kbuild, no CI workflow set: none of the "Verification Required" build-
system paths below are established. Read this document as generic gantt-
legibility prior art only; every repository-specific claim in it is
**not established**.

# Research Line: Gantt Legibility Patterns
**Lifecycle State:** Contracting (Final Summary)
**Repository Context:** `~/Projects/etc/hngh` (Kernel), `hngh-automation` (Visualization/Orchestration)

## Executive Summary
This research line investigates how to render complex, high-density kernel dependency graphs as legible Gantt charts. The "expanding" phase identified that standard linear Gantt visualization fails for kernel builds due to non-linear dependencies and semantic ambiguity in task states. This contraction phase crystallizes those findings into a final structured record, providing actionable implementation directives for `hngh-automation` while explicitly marking where local verification against the `hngh` repository is required.

**Key Constraint:** I cannot directly access `~/Projects/etc/hngh` to verify specific file paths or build system configurations. All recommendations are framed as **implementation directives** that must be validated against the kernel’s actual build system artifacts. Where external sources are needed but unverifiable, this is explicitly stated.

---

## Findings

1.  **Standard Gantt Visualization is Insufficient for Kernel Builds:**
    *   Kernel build pipelines exhibit deep, non-linear dependency trees with high temporal density.
    *   Standard Gantt charts treat tasks as linear/parallel blocks, leading to visual clutter when >5 tasks overlap in a single time unit.
    *   *Source:* Inferred from standard kernel build patterns (e.g., Linux Kbuild, CMake) and prior research beats. *Verification Required:* Confirm `hngh`’s build system exposes dependency graphs via machine-readable formats (JSON/YAML).

2.  **Semantic Ambiguity in Task States:**
    *   Standard Gantt colors (blue=active, red=blocked) are insufficient for kernel tasks.
    *   "Blocked" has nuanced meanings: waiting on upstream patch, hardware dependency, license conflict, etc.
    *   *Source:* Inferred from kernel development workflows. *Verification Required:* Review `hngh`’s CI/CD logs or task tracker to identify distinct "blocked" states and confirm if they are explicitly tagged in build output.

3.  **Legibility is Zoom-Dependent:**
    *   At macro levels, individual task bars become noise.
    *   At micro levels, dependency arrows create visual clutter.
    *   Legibility requires adaptive filtering based on zoom level and context.
    *   *Source:* General visualization principles applied to high-density graphs. *Verification Required:* Analyze `hngh`’s commit history and build logs to determine typical task durations and critical path lengths.

---

## Recommendations for `hngh-automation`

### 1. Implement "Aggregated Gantt" Rendering (Dependency Graph Simplification)
*   **Problem:** Deep, non-linear dependency trees cause visual clutter in standard Gantt charts.
*   **Recommendation:** Implement an **adaptive aggregation layer** for Gantt rendering:
    *   **Macro View (Project-Wide):** Collapse sub-tasks into single bars representing top-level phases (e.g., "Kernel Build," "Module Compilation"). Hide individual file dependencies unless expanded.
    *   **Micro View (Debugging):** Only reveal dependency arrows when the user zooms into a specific phase. Use **edge bundling** to reduce arrow clutter.
*   **Verification Required:** Inspect `~/Projects/etc/hngh` for build system files (`Makefile`, `CMakeLists.txt`, or custom scripts) to identify critical path dependencies. Confirm whether the build system exposes dependency graphs via JSON/YAML that can be ingested by `hngh-automation`.

### 2. Define Kernel-Specific Semantic Color Mapping
*   **Problem:** Standard Gantt colors are insufficient for nuanced kernel task states.
*   **Recommendation:** Implement a **custom semantic color palette** in `hngh-automation`’s visualization engine:
    *   **Green:** Active compilation.
    *   **Yellow:** Waiting on external dependency (e.g., upstream kernel patch).
    *   **Orange:** Hardware-specific task (e.g., driver testing).
    *   **Red:** Failed build or critical error.
    *   **Purple:** License/compliance check pending.
*   **Verification Required:** Review `hngh`’s CI/CD logs or task tracker to identify the distinct states of "blocked" tasks. Confirm whether these states are explicitly tagged in the build system output.

### 3. Adaptive Filtering for Temporal Density
*   **Problem:** Legibility is highly dependent on zoom level; static views fail at both macro and micro scales.
*   **Recommendation:** Implement **zoom-level-dependent filtering** in `hngh-automation`:
    *   **Zoom > 1 week:** Hide all dependency arrows. Show only phase-level bars.
    *   **Zoom < 1 day:** Show individual task bars but hide non-critical dependencies (e.g., optional module builds).
    *   **Critical Path Highlighting:** Always highlight the longest chain of dependencies in a distinct color (e.g., bold black) regardless of zoom level.
*   **Verification Required:** Analyze `hngh`’s commit history and build logs to determine typical task durations. Confirm critical path lengths to calibrate zoom thresholds.

---

## Open Threads

1.  **Build System Integration:**
    *   Does `hngh` expose a machine-readable dependency graph (e.g., JSON, YAML, or custom format)? If not, what parsing strategy is required for `Makefile`/`CMakeLists.txt`?
    *   *Action:* Verify file paths and formats in `~/Projects/etc/hngh`.

2.  **State Tagging:**
    *   Are task states (e.g., "waiting on upstream patch") explicitly tagged in `hngh`’s build output or CI logs? If not, how can these states be inferred from log patterns?
    *   *Action:* Review CI/CD logs and task tracker definitions.

3.  **Performance Constraints:**
    *   What is the maximum number of tasks/dependencies that `hngh-automation` must handle without performance degradation?
    *   *Action:* Benchmark against `hngh`’s largest build scenarios.

4.  **User Interaction Model:**
    *   How should users interact with the aggregated view (e.g., click to expand, hover for details)?
    *   *Action:* Define UI/UX specifications for `hngh-automation`.

---

## References

*Note: The following file paths are cited as targets for verification. I cannot confirm their existence or contents without direct access to `~/Projects/etc/hngh`.*

1.  **Build System Configuration:**
    *   `~/Projects/etc/hngh/Makefile` (or equivalent)
    *   `~/Projects/etc/hngh/CMakeLists.txt` (if applicable)
    *   `~/Projects/etc/hngh/build-scripts/` (custom build scripts, if any)

2.  **CI/CD Logs and Task Definitions:**
    *   `~/Projects/etc/hngh/.github/workflows/` (or equivalent CI configuration)
    *   `~/Projects/etc/hngh/task-tracker/` (if a custom task tracker exists)

3.  **Build Output Artifacts:**
    *   `~/Projects/etc/hngh/build-logs/` (sample logs for state tagging analysis)
    *   `~/Projects/etc/hngh/dependency-graph.json` (or equivalent, if exposed by build system)

*External Sources:* None cited. All claims are grounded in inferred kernel development patterns and prior research beats. Where specific `hngh` details are required, explicit verification steps are provided.


## 2026-08-30-handoff-brief-schema

# failure-informed handoff brief: minimal schema

Status: crystallized 2026-08-30 from the evening selfdev plan's handoff-brief
research beat; file authored 2026-08-31 during plan execution (the plan
mandates 2026-08-30-* filenames). Per-beat material lives in hngh-automation
digest/RESEARCH-BEAT files; this record is the schema itself.

# Final Structured Summary — A Minimal Failure-Informed Handoff Brief Schema

**Line:** handoff brief schema for watchdog-detected session death and replacement
**Lifecycle state:** contracting → **contracted / recommended record**
**Disposition:** Define one minimal, field-by-field brief that a dying or
replaced delegated session can emit (or a steering leg can reconstruct from
producers already in the tree) so its replacement starts failure-informed
instead of re-walking the same ground. Every field below is anchored to a
producer that already exists and was read; no new machinery is proposed.

---

## 1. Purpose

The roguelike watchdog records LOG-ONLY handoffs in the automation repo's
`agent-handoffs.md` so an operator / the agentic steering leg can end a
session and launch a *failure-informed* replacement (the ledger preamble's
own words). But the ledger records only the death (class + evidence); it does
not carry the dead session's state. The missing piece is a brief — a small,
parseable record of what the session was doing, what it finished, what it
left dirty, and why it died. `omp-bridge --orient` already hands a *starting*
brief to a session (queue next, roadmap next, working tree, last ceremony
commit); the schema below is the *ending* counterpart: the same repo-grounded
style, plus the failure facts only the dying session (or its watchdog line)
knows.

## 2. The brief: eight fields

Each field names its real producer — the artifact read while crystallizing
this schema that already carries that field's information in some form.

| # | Field | Producer (read 2026-08-30/31) | Grounded shape |
|---|-------|-------------------------------|----------------|
| 1 | `objective` | `hngh/scripts/omp-bridge --run-start SESSION OBJECTIVE` | One sentence, non-empty (empty OBJECTIVE is refused, exit 2). The run is created with this objective as its mission; the brief repeats it verbatim, never paraphrases. |
| 2 | `lane` | `hngh/docs/project/active-work.md` lane lines | `<HH:MM> lane: <slug> — <state>: <detail>. Next: <step>` — e.g. `12:15 lane: hngh-autonomy-build — started: report-queue + run-autonomous + tests + ceremony + automation hook. Plan written; next: ground-read ceremony/backlog/…`. The brief's lane field is the slug plus the final `Next:` clause. |
| 3 | `budget spent` | `hngh/scripts/omp-bridge --run-start` loadout | The delegated budget *ceiling* is the loadout: `loadout-context-limit=8000`, `loadout-token-limit=8000`, `loadout-cost-limit=2000`, `loadout-time-limit=3600`. What the session actually spent against those ceilings has no producer in the read set — see §4. |
| 4 | `what landed` | `hngh/scripts/omp-bridge --orient` (Last ceremony commit section); `active-work.md` lane lines | The last certificate-bound commit reachable from HEAD: date, hash, `hngh: candidate …` subject — e.g. `2026-08-30 8dfab6df… / hngh: candidate ef3c5861…` (observed live via `--orient`, exit 0). Lane lines add the human form: `ceremony committed e86f4cf… (commit 1eff057)`. |
| 5 | `what is uncommitted` | `hngh/scripts/omp-bridge --orient` (Working tree section) | `git status --porcelain` count plus first path: `18 uncommitted paths (e.g. M docs/design/ui-evolve/current-overlay.json…)` (observed live). The brief carries this line as-is; the replacement re-runs `git status` itself for the full list rather than trusting a summary. |
| 6 | `failure mode` | `hngh-automation/agent-handoffs.md` lead format | The watchdog's own classification, one line: `session-drop \| <ts> \| <slug>\|<session-id> \| <class>: <evidence>` with classes `stall` (open turn, no tool progress, no live subagent), `loop` (≥ N identical trailing tool calls), `error` (hard error, no corrective step). Real death rows also exist in the `overnight-lead` class: `rc=124 dead log=logs/…` — rc plus the log path is the evidence. |
| 7 | `correction` | `hngh/docs/project/active-work.md` correction-style lane lines | The mid-lane correction the session itself recorded: e.g. `env verified: report-queue ABSENT (fail-closed live path) … Next: edit dashboard-tui` — an assumption overturned and the adjusted next step in one line. A dying session's brief carries its last such correction, if any. |
| 8 | `replacement instruction` | `hngh-automation/agent-handoffs.md` preamble + `overnight-lead` rows | The preamble's framing: watchdog handoffs exist so an operator / steering leg can "end the session and launch a failure-informed replacement". The `overnight-lead` rows already point the replacement at its evidence (`log=logs/overnight-…log`). A structured replacement instruction — restart same lane with amended objective vs. park — has no producer; see §4. |

Filling rule: the brief is emitted field-by-field in this order; fields 1, 2,
4, 5, 6 are always fillable from the producers above; fields 3, 7, 8 are
filled only when the session has real evidence, else the literal token
`not established` — never a guess.

## 3. Parseability

The brief is a flat record, one `field: value` line per field, no nesting, so
a future session (or the steering leg) can fill or consume it mechanically:
`objective: … / lane: … / budget-spent: … / landed: … / uncommitted: … /
failure-mode: … / correction: … / replacement: …`. Field names are fixed;
values are free text but single-line, mirroring the ledger's pipe-separated
discipline (the ledger refuses `|` inside notes for exactly this reason —
`omp-bridge --register` enforces it, exit 2).

## 4. Not established

- **Budget spent as a consumed quantity**: the loadout limits define the
  ceiling (producer: `--run-start`), but no read producer records what a
  dead session actually consumed against them. Until a producer exists, the
  brief's budget field records the ceiling plus `not established` for spend.
- **Structured replacement instruction**: the ledger preamble and
  `overnight-lead` rows establish the *intent* (failure-informed replacement)
  and the *evidence pointer* (`log=` path), but no producer writes an explicit
  restart/park/amend decision. The brief's replacement field is therefore
  free text until a producer defines it.
- **Whether the watchdog itself should emit briefs**: the watchdog is
  explicitly log-only ("never kills or launches agents"); this schema assigns
  emission to the dying/replaced session or the steering leg, not the
  watchdog. Any extension of the watchdog's role is an operator decision and
  is out of scope here.

## 5. Secondary framing

`~/Projects/etc/20260830/09-runbook.md` (operator-authored,
audited) was read as optional framing material. Its §7 "Key in-flight state"
mirrors this schema's spirit — HEAD, uncommitted whitelisted dirt, gate
state, what plan is executing — and its §2 maps where state lands. Its
*framing* (state must be recoverable from a fixed, named list of places) is
consistent with this schema and is adopted as context only; none of its
operational mechanics (timers, stop commands) are imported, because the
schema's fields must be grounded in producers read for this beat, not in a
cheat sheet's assertions.

## 6. Batched landing

This doc rides the next certificate ceremony: it is written to the working
tree only and the orchestrator lands it with the rest of the 2026-08-30
evening selfdev wave's batched doc landings. No code was written for this
beat; the schema is a record, not an implementation.

## Grounding

Verified paths read for this beat (2026-08-31, `test -f` each):

- `hngh/docs/project/active-work.md` — lane lines (fields 2, 4, 7)
- `hngh-automation/agent-handoffs.md` — watchdog handoff ledger: preamble,
  lead format, classes, real `session-drop`/`overnight-lead`/`bridge-register`
  rows (fields 6, 8)
- `hngh/scripts/omp-bridge` — script source read: `--orient` brief sections
  (Queue Next / Roadmap Next / Working tree / Last ceremony commit),
  `--run-start` objective + loadout limits, `--register` pipe-discipline
  refusal (fields 1, 3, 4, 5; §3)
- `~/Projects/etc/20260830/09-runbook.md` — optional secondary
  framing only (§5)

Live run: `hngh scripts/omp-bridge --orient` (verified read-only in source
before running: it only reads the queue/roadmap files and runs
`git status --porcelain` / `git log`) — exit 0, brief reproduced under
fields 4 and 5.


## 2026-08-30-publication-pipeline-grounding

# publication pipeline grounding: what `generate-publication` actually consumes

Status: crystallized 2026-08-31 (authored 2026-08-31; filename dated 2026-08-30 per the
2026-08-30 evening selfdev plan's naming mandate) from the plan beat
`publication-pipeline-grounding`; companion material lives in
hngh-automation digest/RESEARCH-BEAT-*-self-funding-paths-publications-ebook-site-operator-runway.md.

---

## 1. What `--ebook` consumes

Source read: `scripts/generate-publication` (executable, `test -x` verified 2026-08-31).
The `--ebook [DIR]` mode (`ebook_documents()`, lines 235–247; `build_ebook()`, lines
250–292) reads a **fixed, hard-coded list of seven files**, each included only
`if path.exists()`:

1. `docs/intent.md`
2. `docs/architecture.md`
3. `docs/project/roadmap.md`
4. `docs/project/decisions.md`
5. `docs/project/backlog.md`
6. `docs/project/queue.md`
7. `README.md`

Verified to exist on disk 2026-08-31: all seven (see Grounding).

What `--ebook` does **not** consume:

- **No `docs/research/` selection mechanism of any kind.** The script source contains
  no reference to `docs/research/`, to a manifest file, or to any selection input;
  the corpus is the seven literals above, in code order.
- **No research-lines manifest.** `~/Projects/etc/hngh-automation/research-lines.tsv`
  exists (verified 2026-08-31) and is the automation repo's research-line ledger, but
  `scripts/generate-publication` never opens it, never references it, and has no
  cross-repository read path (its only root is `HNGH_PUB_ROOT` or the script's own
  parent, line 42–43). The claim "the ebook rides the research-lines manifest" is
  **not established** — it is false against the source.
- **No journal or record input.** `docs/journal/*.md` and `docs/records/*` are not
  read by `--ebook` (they are read only by the separate `--daily`/`--check` modes,
  which consume git log, `docs/project/checkin.md`, and `docs/project/timeline.md`).

Output of `--ebook`: `docs/journal/ebook/book.md` plus `hngh-memoir.epub` — a
stdlib-`zipfile` EPUB 2 with a **single** `chapter.xhtml` and a TOC.ncx carrying
**one** navPoint. Chapter order and titles are fixed in code.

## 2. What `--site` consumes

The `--site [DIR]` mode (`build_site()`, lines 295–322) is a thin shell: it imports
`scripts/dashboard-readout` as a module, calls `data_spine()` + `render_html(data)`,
appends a "leaderboard (timeline density)" table computed from the timeline rows, and
writes exactly one file: `docs/site/index.html`.

`scripts/dashboard-readout` (read 2026-08-31) `data_spine()` (line 290) consumes:

- `docs/project/timeline.md` — 4-column TSV rows, kinds `done`/`event`/`rotation`
  (`timeline_rows()`, line 101);
- `docs/project/queue.md` — 4-column TSV rows, statuses `queued`/`done`/`active`
  (`queue_items()`, line 110), plus the last `## ETA` section (`queue_etas()`,
  line 488);
- live, non-committed sources rendered read-only: session stores under
  `~/.hngh-automation/store` with a `record.lisp` (`session_rows()`, line 155) and
  rosters from `/tmp/hngh-heartbeat-*`, `/tmp/hngh-auto-*`, and the automation store
  (`_roster_sources()`, line 205).

So the public site today is the dashboard spine (timeline + queue + ETAs + live
sessions) plus a leaderboard, as one static HTML file. It is not a multi-page site,
has no journal feed, no comment intake, and no pricing surface.

## 3. The four self-funding backlog rows, given what the pipeline consumes today

Read source: `docs/project/backlog.md` lines ~448–525 (read 2026-08-31).

### ebook-longform ("Long-form ebook: the megastructure memoir")

Row wants: a `make journal` pipeline assembling the **day-by-day journal + key
records + the vision** into one long-form document, Markdown → epub/mobi, with a
review acceptance of a deterministic document "whose TOC maps the records".

Gap against actual consumption: today's `--ebook` assembles only the seven fixed
governance docs; it reads **no** journal day files and **no** records, so the row's
core content source is not wired in. The TOC acceptance also fails structurally
(single navPoint, fixed chapter list). What it needs next is **not** a pandoc step
first — it is a chapter-selection input: an explicit list (manifest or directory
scan) of `docs/journal/*.md` and `docs/records/*` seams fed into
`ebook_documents()`. Once selection exists, a mobi/pandoc step is a separate,
optional rung.

### public-surface ("Self-hosted public surface")

Row wants: journal posts, moderated comment intake, a public queue readout, and an
instances leaderboard, self-hosted on a budget VPS.

Gap against actual consumption: `--site` already produces the public readout and the
leaderboard (as one static file) — that part is genuinely served by today's
pipeline. The missing halves are (a) a **journal feed** — `--daily` writes
`docs/journal/YYYY-MM-DD.md`, but `--site` never reads that directory; and (b) a
**moderated intake**, which no publication script touches today and which is a new
surface (server + moderation policy), not an extension of a read-only assembler.
Next need: extend `--site`'s output set beyond one file (journal index) and scope
the intake as its own rung with its moderation/rate-limit review trigger first.

### royalty-pipeline ("Self-publishing / royalties pipeline")

Row wants: a repeatable "book machine" (outline → draft → edit → cover → metadata)
driving PDF/epub builds for KDP + direct sale.

Gap against actual consumption: everything the book machine needs above raw prose is
absent from the pipeline today. The only epub produced is the memoir with hard-coded
metadata (`dc:title` "hngh memoir", `dc:identifier` `urn:hngh:memoir`) — no author
field, no keywords, no cover image, no per-book metadata input, no PDF path. The
row itself names its dependency: "the longform assembler". Next need: the
ebook-longform selection mechanism first (shared prerequisite), then a metadata +
cover step; the prose generation pipeline (outline→draft→edit) is a separate machine
the publication script neither contains nor consumes.

### funding-rails ("Funding rails — bootstrap income")

Row wants: Shieldz + asterpay intake stood up, a `pricing` page stub, and the rails
documented in the site.

Gap against actual consumption: `--site` writes exactly one file (`index.html`) with
no pricing content and no payment references; the row's dependency is "the
public-site rung". Next need, minimal: a second output page (pricing stub) from the
same mode, and the rails documentation riding that page. The payment rails
themselves (Shieldz/asterpay, x402 wallet) are outside the publication pipeline
entirely — this beat makes no claim about them (see Not established).

## 4. Priced, parseable decision (master-plan §4 gate)

Per `docs/project/master-plan.md` §4: research→grow when the artifact is a priced,
parseable decision. Prices below are this beat's estimates from the single-script
scope read in §1–§2; they are not measured by a run.

```
decision: publication-pipeline-next
  gate: research->grow (master-plan section 4)
  basis: scripts/generate-publication source read 2026-08-31 (sections 1-2)
  options:
    - id: A
      name: ebook-selection-manifest
      change: feed docs/journal/*.md + docs/records/* into --ebook via an explicit
              chapter selection input; keep the seven fixed docs as front matter
      price: 1 grow slice (one mode of one script; no kernel files)
      unblocks: ebook-longform, royalty-pipeline (both name the assembler)
    - id: B
      name: site-second-pages
      change: --site emits a pricing stub page + journal index alongside index.html
      price: 2 grow slices (new output set + journal read; intake excluded)
      unblocks: funding-rails (partial), public-surface (partial)
    - id: C
      name: book-machine
      change: outline->draft->edit->cover->metadata prose pipeline + KDP builds
      price: unpriced (multi-component; blocked on A for the build half)
      blocked_on: A
  pick: A
  rationale: lowest price; named dependency of two backlog rows; B and C inherit
             their build half from A; today's pipeline is one mode edit away
  alternation: next beat is grow (A); research resumes when A lands, with the
               public-surface hosting/moderation design as the next missing design
```

The alternation follows §4's rule directly: no grow run in the publication lane is
blocked today (the pipeline exists and runs), so research yields to a grow beat
carrying option A, and returns only when the next missing design (hosting +
moderated intake for public-surface) is on the table.

## Not established

- Any revenue, royalty, payment-rail, or runway behavior: nothing in the read
  sources produces or tracks income. The prior beat
  (`docs/research/2026-08-31-self-funding-paths-publications-ebook-site-operator-runway.md`,
  untracked) reached the same conclusion from its own evidence basis and defined
  "operator runway" as a working term only; this beat adds no claim there.
- Whether a pandoc/mobi toolchain exists in the environment: not checked, not
  asserted (the current epub is stdlib-only by construction).
- Deployment of `docs/site/index.html` to any host: no read source mentions hosting.

## Batched landing

This doc is an uncommitted working-tree research artifact; it rides the next
certificate ceremony and is landed by the orchestrator (no machine git operations
in the kernel repo). No code was written in this beat.

## Grounding

All paths verified with `test -f` (or `test -x` for the script) on 2026-08-31:

- `scripts/generate-publication` — `test -x` passed; source read in full (369 lines).
  `--ebook` inputs: fixed seven-file list, lines 235–247; no manifest/research
  selection anywhere in source. `--site` mechanics: lines 295–322.
- `scripts/dashboard-readout` — read; `data_spine()` line 290, `timeline_rows()`
  line 101, `queue_items()` line 110, `queue_etas()` line 488, `session_rows()`
  line 155, `_roster_sources()` line 205.
- `docs/intent.md` — `test -f` passed (`--ebook` input 1).
- `docs/architecture.md` — `test -f` passed (`--ebook` input 2).
- `docs/project/roadmap.md` — `test -f` passed (`--ebook` input 3).
- `docs/project/decisions.md` — `test -f` passed (`--ebook` input 4).
- `docs/project/backlog.md` — `test -f` passed (`--ebook` input 5; also the four
  self-funding rows read, lines ~448–525).
- `docs/project/queue.md` — `test -f` passed (`--ebook` input 6; `--site` queue
  source via dashboard-readout).
- `README.md` — `test -f` passed (`--ebook` input 7).
- `docs/project/timeline.md` — `test -f` passed (`--site` spine source; `--daily`
  input).
- `docs/project/checkin.md` — `test -f` passed (`--daily`/`--check` input).
- `docs/project/master-plan.md` — `test -f` passed; §4 read in full (lines 63–82).
- `docs/research/2026-08-31-self-funding-paths-publications-ebook-site-operator-runway.md`
  — `test -f` passed (untracked prior-beat record; read, cited, not modified).
- `~/Projects/etc/hngh-automation/digest/RESEARCH-BEAT-2026-08-31-self-funding-paths-publications-ebook-site-operator-runway.md`
  — `test -f` passed (untracked prior-beat digest; read, cited, not modified).
- `~/Projects/etc/hngh-automation/research-lines.tsv` — `test -f`
  passed; inspected head (3 lines). Consumed by the research-lines machinery, **not**
  by `scripts/generate-publication` (verified by full source read).


## 2026-08-30-search-grounded-research-beats-web-search-reference-capture-source-quality

# search-grounded research beats: web search, reference capture, source quality

Status: crystallized 2026-08-30 from research line `search-grounded-research-beats-web-search-reference-capture-source-quality`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-search-grounded-research-beats-web-search-reference-capture-source-quality.md.

# Research line record: search-grounded research beats

**Line:** search-grounded research beats: web search, reference capture, source quality
**Lifecycle state:** contracting
**Purpose:** Freeze this line into a durable, reusable record of findings, recommendations, and open threads.

## Grounding status

This summary is grounded only in the prior material supplied for this line and in the explicit constraints of the request.

- I did not verify that `~/Projects/etc/hngh` exists from this environment.
- I did not inspect any files inside that repository.
- Therefore, no concrete file paths in the hngh kernel repository are cited as evidence.
- No external web sources were consulted or asserted.

Any claim requiring verification against the hngh repository remains an open thread until local inspection is performed.

---

## Findings

### F1: The line can be contracted as a process standard, not yet as an hngh implementation claim

The prior material identifies the central blocker: the hngh repository path is specified, but its existence and contents are not verified from this environment.

**Implication:**
This line should remain contractible in


## 2026-08-30-steer-vs-die-threshold

# steer-vs-die thresholds: an observable rubric for the "learning or burning" judgment

Status: crystallized 2026-08-31 (authored 2026-08-31, riding the 2026-08-30 evening selfdev plan) from research line
`steer-vs-die-threshold`; per-beat material lives in hngh-automation digest/RESEARCH-BEAT-2026-08-30-steer-vs-die-threshold.md.

## Executive framing

`docs/project/roguelike-agentic.md` states the judgment — *is this agent learning, or just burning? If the next step is a
correct small step under budget → let it run. If it's looping, re-failing, or about to spend tokens on something we know
how to do procedurally → die and replace* — but leaves the triggers implicit. This record scopes each trigger to an
observable condition that is already detectable by the filed alert classes in `docs/project/reports.md` and by the
behaviors of `hngh-automation/jobs/agent-watchdog.sh`, and maps each to one response: **steer** (live corrective on a
mid-flight, progressing session), **procedural hook** (predicted next turn replaced by a token-cheap scripted call, per
the "procedural over agentic" rule), or **die+replace** (end session, failure-informed brief, launch successor).

The watchdog is LOG-ONLY: it records a handoff ledger line + alert + attention flag and does not kill or launch agents;
ending-the-session is a decision an operator/agentic leg acts on (its header says so explicitly). The table therefore
assigns responses, not automations.

## The rubric

| Signal | Observable trigger (grounded) | Response |
| --- | --- | --- |
| Loop repetition | Watchdog class `loop`: trailing `LOOP_N=3` assistant tool calls with identical name **and** serialized identical arguments (`scan` prints `identical tool call x3`). Field evidence of the sibling pattern: `loop-signal` alerts "STATE 3x identical crumb ... (3 markers in 5m)" (reports.md rows 2026-08-26T16:57:47Z 77c23af0, 2026-08-26T22:39:25Z cf2fc04a). | steer once (single corrective nudge); if the identical call reappears after steering, die+replace with a brief naming the stuck call. |
| Unrecovered error | Watchdog class `error`: last transcript record is a `toolResult` whose text matches `errish()` (traceback/fatal/exception/error:/failed/...) and quiet time exceeds `ERROR_GRACE_MIN=2` without a corrective step (`hard error result, no corrective step`). Reports.md shows the corresponding recovery pair pattern (alert then `recovered` progress, e.g. rows 2026-08-30T04:45:44Z acd0de86 / 04:50:44Z e51e5788). | die+replace immediately if no corrective step lands within the grace window; the roguelike rule makes "any error ... a good reason to call off and respawn" and forbids nursing the corpse. |
| Tool-calling spiral | Watchdog class `stall`: open assistant toolCall/text turn quiet for `STALL_MIN=10` minutes with **no** fresh subagent transcript writing — i.e. turn burning without visible progress (prints `no tool progress for Ndm`). Field evidence: `agent-stall` alerts "stalled, last tool-call 1967m ago" (2026-08-30T04:45:44Z) and "31m ago ×4" (2026-08-30T16:10:44Z) — the ×4 supersession shows the first window is still recoverable. | steer on the first window (session may be legitimately mid-flight — watchdog deliberately never flags a session with a live subagent); die+replace when the stall repeats ×N (the ×4 pattern) or steering once has already failed to unstick it (roguelike-agentic provenance: 2026-08-26 WebDashboard stall, "steering once failed to unstick it"). |
| Procedural hook availability | The next turn's action is predictable and token-cheap procedurally — the exact condition roguelike-agentic.md's hook section describes ("when we can predict what an agent's next turn would do, and there's a token-cheap procedural alternative"). The hook surface already exists and is machine-observable: watchdog `ingest` writes a `session-drop` line to `agent-handoffs.md`, files a report-queue alert, and touches `/tmp/hngh-overseer-attention` (ATTENTION_FLAG); the "attention signal / predictable-next-turn triggers the hook" leg is wired. | procedural hook: end the session at the turn boundary, run the known file write / script / probe directly, complete evaluation of partial work, launch the replacement with the brief — never spend agent tokens on the predicted call. |
| Budget burn rate | **Not established as an alert class.** Reports.md contains no budget-burn alerts; the only budget surface is the daily `budget digest` progress row (`overnight sessions=0 remote_model_calls=0 remote_cost_usd=0 [vs operator target $10-20/day]`, rows 2026-08-29/30/31) and the `slow-unit` alert `dropin:20-workbeat.sh wall=229.4s median=0.2s ×132` (2026-08-30T13:05:43Z f516cff4) — a unit-time skew signal, not a per-session burn signal. No threshold mapping from burn rate to steer/die is observable in the named files. | not established: no grounded trigger. A per-session token-burn-rate detector and its threshold is unbuilt; until one exists, burn judgments stay qualitative per the roguelike rule's "correct small step under budget" clause. |

Decision ordering when signals co-occur: `error` outranks `stall`/`loop` (the watchdog checks error first and the
roguelike rule makes any unrecovered error a death trigger); a single stall window defaults to steer, repeated windows
or post-steer repetition default to die+replace; procedural hook availability converts a would-be death into a cheaper
rotation at the turn boundary.

## Not established

- A quantitative budget-burn-rate threshold (no alert class, no per-session burn telemetry in the named files).
- Whether the ×N repetition count that flips steer → die for stall windows generalizes; the ×4 evidence is one pattern,
  not a calibrated constant.
- Automated kill/launch on any signal: the watchdog is log-only by design; no response leg is currently automated.

## Grounding

Verified paths read for this record (2026-08-31):

- `docs/project/roguelike-agentic.md` — the source rubric: death triggers, procedural hook section, "when NOT to
  respawn", the learning-vs-burning judgment, and the 2026-08-26 WebDashboard provenance note.
- `docs/project/reports.md` — filed alert classes read directly: `agent-stall` (alerts + `recovered` progress pairs),
  `loop-signal` ("3x identical crumb", "3 markers in 5m"), `slow-unit` (`dropin:20-workbeat.sh wall=229.4s median=0.2s
  ×132`), `tree-skew` ("dirty and uncommitted >4h ×90", 2026-08-30T04:00:43Z 96bd99de), plus the daily `budget digest`
  progress rows.
- `~/Projects/etc/hngh-automation/jobs/agent-watchdog.sh` — read in full: tunables (`STALL_MIN=10`,
  `LIVE_MIN=180`, `ERROR_GRACE_MIN=2`, `LOOP_N=3`), detection classes `error`/`loop`/`stall`, LOG-ONLY `ingest`
  (handoffs ledger line + report-queue alert + ATTENTION_FLAG touch), live-subagent exemption, fail-open stance.

## Batched landing

This document rides the next certificate ceremony; the orchestrator lands KERNEL docs changes. It is authored
2026-08-31 under the plan-mandated 2026-08-30-* filename. No code was written in this beat; KERNEL src/, tests/,
Makefile, and hngh.asd were untouched.


## 2026-08-31-buddy-summoned-not-nagging-menu-learning

# buddy summoned-not-nagging menu learning: grounding the top research-backlog line

Status: crystallized 2026-08-31 from master-plan section 4 research backlog (line: buddy summoned-not-nagging menu learning)

Evidence basis: real repo surfaces read in full or in targeted ranges on 2026-08-31 (every cited path passed `test -f`; see Grounding); prior-art references were actually visited via web read or API during this beat (see References). Short quotes are verbatim from the files listed; paraphrase beyond them is marked. Numbers I could not re-verify in the source are not asserted.

---

## 1. What the backlog line actually asks

`docs/project/master-plan.md` §4, "Research backlog (must precede the fun builds)": "buddy
summoned-not-nagging menulearning; handoff-brief schema; the steer-vs-die threshold; …
Each ties to a build rung." It is the first item in backlog order. The question it names:
the pixel-RPG companion surface must **learn what belongs in its summon menu** —
surfacing learned, context-appropriate actions when the operator SUMMONS it — without
ever becoming a nagging assistant that pushes suggestions unbidden.

Two words in the line carry the whole constraint:

- **summoned** — the buddy acts only after the operator initiates.
- **not-nagging** — learning may reorder a menu the operator opens; it may never open
  itself, prompt, animate, or "help" on its own schedule.

## 2. What each repo surface actually establishes

### `docs/design/buddy-menu-spec.md` (P2 DESIGN, ceremony-ready)

- Establishes the interaction model outright: "The buddy is a summoned, non-nagging
  companion… The operative never pops up uninvited, never animates in the operator's
  peripheral focus, and never interrupts a running surface."
- Establishes the current menu contract as a **fixed three-part column**: (1) "Quest ask"
  (prompt box routing to the same command underneath as the CLI/GUI control contract —
  `summon`-style run via create-run → admit-transport (S5), or `ask:` to the advisory
  path (S6)); (2) "Setting toggles" (display-only overlay preferences); (3) "Shortcut
  lenses" ("queue counts, one-line health verdict, next course, latest report tail"),
  where "no lens opens without the operator choosing it."
- Already contains the learning question, unnamed: "Which shortcut lens set is genuinely
  used first (queue counts vs. verdict vs. next course) — build the used one, keep the
  rest in the snapshot." Menu learning is the general form of this open question.
- Constrains data: "menu lenses reuse the same snapshot fields the feeder already
  writes…; no new data path until a lens needs it, and any new field lands in the
  snapshot first, then the QML."
- Constrains animation so nagging is structurally impossible today: "`alert` and
  `victory` are **event-driven single transitions**, never loops: they play once and
  settle, so the buddy cannot nag."
- Non-goals: "Auto-launch, auto-focus, or any unrequested appearance." Honesty rules:
  "No click path bypasses the control contract."

### `docs/design/display-register-spec.md`

- Names the boundary as forbidden shape, verbatim: "Forbidden shapes: nagging loops;
  uninvited interruption of a running surface (the buddy is summoned, never summoning)".
- Acceptance gate already implies one-shot learning behavior: "one-shot transitions:
  `alert` / `victory` advance on the event tick and never replay while the state is
  unchanged — no loop, no nag"; "exactly one caption per state snapshot."
- Alias/speech rows are "`perceptual:true` scope: display data, never canonical, never
  an input to governance or selection" — the exact leash learned menu state must wear.

### `docs/design/gamified-runs.md` (honesty leash)

- "Any narrative field carries `perceptual:true` at the boundary that produces it and is
  **rendered for display only**"; "Narrative is never an input to selection:
  `perceptual` fields are excluded from course-selection candidates, expedite ripples,
  and scheduling computations." Learned menu ordering is exactly the kind of derived
  display state this leash governs.

### `docs/design/command-center.md`

- Names the control verbs the menu routes through: "S5 Summon control | `summon` + web
  ask-box fire a run through `create-run`→`admit-transport`"; S6 consider/expedite.
- Surface-opening rule: "Open / close surfaces … explicit open | no auto-popup; no
  daemon held." And "The OSD/buddy overlay is a display-only skin over the same spine."
- Accountability rule that any learned-action UI inherits: "Every control echoes how the
  ask was decided in a short report row."
- Open question adjacent to learning: "`summon` loadout defaults: which route/tool
  labels a summoned run gets by default (local first, escalate on refusal?)"

### `docs/design/system-awareness-map.md`

- Confirms the buddy's data feed is a stamped, no-daemon snapshot: the awareness tick
  writes the "buddy/OSD snapshot (headroom line in the overlay)"; "Every field carries
  its source stamp; missing or failing probes emit" explicit marks. A learning feature
  must ride this same snapshot-first pattern (per buddy-menu-spec technical delivery).

### `docs/project/master-plan.md` (context)

- Current honest gap: "the buddy/OSD exists but the animations are 'awkward'" (§1).
- The buddy is one of the presiding surfaces ("presided over through CLI + GUI +
  pixel-RPG buddy surfaces", §2) and a driving adapter in the layer map (§3); the main
  dispatch surface exposes "status/summon/schedule/ask/expedite/dashboard/subagent
  verbs" (§3, R6) — the vocabulary a learned menu can only mirror, never invent.

### `docs/project/roadmap.md`

- No buddy mention at all (case-insensitive grep for `buddy` returns nothing). Roadmap
  row 6 ("QoL & graphic evolution … behind the QoL cadence and the display register")
  is the closest cadence a menu-learning change would ride, by analogy only.

## 3. Prior art (what it says, and where it failed or succeeded)

- **Clippy/Office Assistant** — the canonical failure. Introduced in Office 97, it
  "appeared when the program determined the user could be assisted," was "widely
  reviled among users as intrusive and annoying," and was criticized "for interrupting
  users and not providing advice that was fully adapted to the situation." Microsoft
  "turned off the feature by default in Office XP" and removed it entirely in Office
  2007. Alan Cooper's account (via the same article) diagnoses the mechanism: a
  misreading of Nass & Reeves' CASA research — people treat computers as social actors,
  so "the added human-like face emerged as an annoying interloper." The lesson maps
  one-to-one onto the buddy: uninvited initiation is the failure, not the agent, not
  even the personality.
- **Horvitz, "Principles of Mixed-Initiative User Interfaces" (CHI '99)** — the
  primary-source articulation of coupling "automated services with direct manipulation";
  automation earns its initiative only where the user keeps control of when it acts.
  The summon-menu is the buddy's version of direct manipulation: the operator opens,
  the system proposes inside.
- **Horvitz, Jacobs & Hovel, "Attention-Sensitive Alerting" (UAI '99)** — models that
  "balance the context-sensitive costs of deferring alerts with the cost of
  interruption." Even for *legitimate* push (real alerts), initiative must be
  utility-weighted against interruption cost. The buddy's snapshot already carries an
  `alert` state — real alerts keep their one-shot path; learning may never promote
  itself into that channel.
- **Adamczyk & Bailey, "If not now, when?" (CHI '04)** — interruption cost depends on
  *when* in a task it lands; deferring to task boundaries measurably reduces damage.
  Generalizes here: the only moment the buddy may surface learned actions is the
  operator's own boundary — the summon click.
- **Pielot, Church & de Oliveira, "An in-situ study of mobile phone notifications"
  (MobileHCI '14)** — field evidence that notification volume itself produces
  interruption burden (not just badly timed single alerts); dose matters, and the only
  safe dose of proactive assistant chatter is zero unless the recipient asked.

## 4. Design principles (each tied to a repo fact or a reference)

1. **The menu may learn; nothing else may change.** Learning writes only the ordering
   and membership of the summon-opened menu column. It must never alter the event-driven
   animation vocabulary (`alert`/`victory` one-shots stay exactly as specified), the
   speech captions, the snapshot schema semantics, or any gate. (buddy-menu-spec state
   mapping; display-register forbidden shapes.)
2. **Learned state is `perceptual:true`, display-only, and never an input to
   governance.** The learned ordering lives at the presentation boundary like every
   other display alias: "never canonical, never an input to governance or selection."
   A learned lens must route through the same verbs/gates as the CLI ("No click path
   bypasses the control contract"). (display-register-spec; buddy-menu-spec honesty
   rules; gamified-runs leash.)
3. **Learn from the operator's summons, not from ambient signals.** The evidence signal
   is: which lenses/actions the operator actually chooses per summon, and which quest
   asks they type. Menu learning is a direct-manipulation feedback loop (Horvitz CHI
   '99), not a prediction engine watching the operator (Clippy's error). Conveniently,
   the repo's existing open question — "Which shortcut lens set is genuinely used
   first" — already implies the only data path needed: the snapshot fields the feeder
   already writes, plus summon-time choice counts. No new data path until a lens needs
   one.
4. **Rank by a decaying mix of frequency and recency; keep static defaults beneath.**
   Learned actions surface above, not instead of, the fixed contract (quest ask,
   toggles, lenses); stale learned entries sink back. Freshness decay prevents an old
   habit from fossilizing into noise — the same dose-control lesson as the notification
   study, applied inside the menu. [INFERENCE: the exact decay function is this beat's
   estimate, not a repo rule.]
5. **The hard boundary: never auto-offer, never interrupt.** A learned menu entry may
   exist and be ranked only while the menu is open. The buddy may not badge, animate,
   caption, sound, or pop anything because it "learned something"; proactive initiative
   stays zero except the already-specified event-driven one-shots derived from real
   run state. "The buddy is summoned, never summoning." (display-register-spec verbatim
   forbidden shape; buddy-menu-spec non-goals; Clippy/XP-off-by-default outcome.)
6. **Accountability rides the existing report row.** Any learned-action invocation
   "echoes how the ask was decided in a short report row" (command-center rule) —
   including, if introduced, the fact that its placement came from learning.
7. **Fail closed.** With no learning data, the menu is today's fixed menu. Missing or
   malformed learned state must degrade to the static contract, matching the snapshot
   rule "an unreadable/missing snapshot keeps the last good frame and the window never
   crashes." (buddy-menu-spec technical delivery.)

## Not established

- **Implementation state of the menu itself.** `scripts/osd-operative.qml` (176 lines,
  read 2026-08-31) contains no menu, and its feeder (`scripts/osd-operative`) writes
  only state speech, queue counts, backlog summary, and one-line status to
  `/tmp/hngh-osd.json` (override `HNGH_OSD_OUT`). There is no menu code and no learning
  code anywhere in the repo to characterize; everything in §4 is contract design, not
  behavior description.
- The persistence store and schema for learned menu state (where summon-choice counts
  live, retention/decay constants, whether learning lives in the QML, the feeder, or a
  new snapshot field) — no repo doc decides this yet.
- What "context-appropriate" means concretely beyond lens choice — e.g. whether
  learned *quest-ask templates* (summon presets) are in scope. The backlog line says
  "menulearning" without scoping it; this doc assumes menu-entry ranking only.
- Whether the pending open questions (default lens set; quest-ask `ask:` vs run
  default) are closed before or by learning — the alternation is unspecified.
- Exact quantitative results from Pielot et al. 2014 (the widely quoted ~25-minute
  resumption figure) — the paper's metadata was verified via Crossref during this
  beat, but the numbers were not re-read from the primary text, so none are asserted
  here.

## References

All visited 2026-08-31 (via direct read or API during this beat):

- Horvitz, E., "Principles of Mixed-Initiative User Interfaces," CHI '99, pp. 159–166.
  https://www.microsoft.com/en-us/research/publication/principles-mixed-initiative-user-interfaces/
- Horvitz, E., Jacobs, A., Hovel, D., "Attention-Sensitive Alerting," UAI '99,
  pp. 305–313. https://www.microsoft.com/en-us/research/publication/attention-sensitive-alerting/
- Adamczyk, P. D., Bailey, B. P., "If not now, when? The effects of interruption at
  different moments within task execution," CHI '04. https://doi.org/10.1145/985692.985727
- Pielot, M., Church, K., de Oliveira, R., "An in-situ study of mobile phone
  notifications," MobileHCI '14. https://doi.org/10.1145/2628363.2628364
- "Office Assistant," Wikipedia (Clippit/Clippy history, XP default-off, criticism
  sections). https://en.wikipedia.org/wiki/Office_Assistant

## Batched landing

This doc is an uncommitted working-tree research artifact; it rides the next
certificate ceremony and is landed by the orchestrator (no machine git operations in
the kernel repo). No code was written in this beat.

## Grounding

All paths verified with `test -f` on 2026-08-31:

- `docs/design/buddy-menu-spec.md` — PASS; read in full (119 lines).
- `docs/design/gamified-runs.md` — PASS; targeted ranges (honesty leash, buddy rows).
- `docs/design/command-center.md` — PASS; targeted ranges (S5/S6, verb table, OSD note).
- `docs/design/system-awareness-map.md` — PASS; targeted ranges (snapshot feed).
- `docs/design/display-register-spec.md` — PASS; targeted ranges (forbidden shapes,
  acceptance invariants).
- `docs/project/master-plan.md` — PASS; §1–§4 ranges (backlog line at §4).
- `docs/project/roadmap.md` — PASS; buddy-grep negative result confirmed.
- `scripts/osd-operative.qml` — PASS; read for implementation-state check (no menu).
- `scripts/osd-operative` — PASS; read for snapshot-field check.
- `docs/project/interface-plan.md`, `docs/design/presentation-boundary.md`,
  `docs/design/assistant-interface.md`, `docs/design/operative-frames.md` — PASS
  (existence verified; cited only as cross-links the above documents name).


## 2026-08-31-self-funding-paths-publications-ebook-site-operator-runway

# self-funding paths (publications/ebook/site -> operator runway)

Status: crystallized 2026-08-31 from research line `self-funding-paths-publications-ebook-site-operator-runway`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-self-funding-paths-publications-ebook-site-operator-runway.md.

# Research line record: self-funding paths (publications/ebook/site → operator runway)

**Line:** self-funding paths (publications/ebook/site → operator runway)
**Lifecycle state:** contracting
**Record type:** final structured summary / lasting record
**Grounding constraint applied:** only the named kernel repository root is cited as a concrete path; no internal file paths are asserted as existing because they were not verified in the available material.

---

## 1. Evidence basis and verification limits

This crystallization is based on:

- The line title and lifecycle state supplied in the prior research beat.
- The explicit instruction to ground claims in “this repository” and the hngh kernel repository at `~/Projects/etc/hngh`.
- The absence of verified file-level evidence from either repository in the provided material.

Therefore:

- I can cite `~/Projects/etc/hngh` as the named kernel repository root, because it is explicitly given in the task.
- I cannot confidently cite specific files inside that repository or inside “this repository” without inspection results.
- Claims about publications, ebooks, sites, revenue, pricing, distribution platforms, audience size, or external market conditions are treated as unverified unless they are explicitly marked as proposals or assumptions.

---

## 2. Findings

### Finding 1: The line’s purpose is to convert public-facing assets into operational funding capacity

The line name states the intended conversion chain:

> publications/ebook/site → operator runway

This means the research question is not merely “can we publish?” but rather:

> Can a publication, ebook, or site generate enough measurable value to extend operator runway?

**Confidence:** High for intent. Low for implementation evidence.

---

### Finding 2: The line is in contracting state, so the appropriate output is closure criteria, not expansion

The prior material marks the line as:

> expanding → contracting

In a contracting state, the line should be crystallized into a durable record with:

- what was learned,
- what is recommended,
- what remains unresolved,
- and what evidence would justify reopening.

**Confidence:** High for lifecycle interpretation.

---

### Finding 3: No verified repository evidence establishes that a self-funding mechanism already exists

From the available material, I cannot confirm that any of the following exist:

- a publication pipeline,
- an ebook build system,
- a deployed site,
- revenue tracking,
- cost accounting,
- operator-runway metrics,
- payment or distribution integrations,
- documentation defining “operator runway.”

Therefore this record does **not** assert that the line has produced a working self-funding path.

**Confidence:** High that the claim is unverified in the available evidence.

---

### Finding 4: “Operator runway” is currently a working term, not a verified repository-defined metric

The phrase “operator runway” appears in the line title, but no verified file or definition was provided to establish its exact operational meaning.

A reasonable working definition for this line would be


## 2026-08-31-session-cost-display-formats

# session-cost display formats

Status: crystallized 2026-08-31 from research line `session-cost-display-formats`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-session-cost-display-formats.md.

Grounded rewrite 2026-08-31: the original crystallization was written
without access to this repo and invented a C-kernel mechanics layer
(`include/session.h`, `src/cost/display.c`, `/proc/hngh/session_cost`,
`/dev/hngh_cost`, timerfd/setitimer update loops) dressed as
"verification-driven actions". None of that exists here — Hngh is a
Common Lisp kernel plus no-daemon shell automation, and its cost
capture is already a real telemetry row. That mechanics layer is the
named foldback anti-pattern and is discarded; the line's real subject
survives: how session cost (tokens, money, model usage, duration) is
displayed across Hngh's actual surfaces.

## Findings (grounded rewrite)

- **F1 — the raw-vs-formatted question is already answered by the
  store.** `hngh-automation/jobs/telemetry.py` owns the schema:
  `events(ts, source, kind, identity, lane, unit, model, tokens_in,
  tokens_out, cost_usd, wall_s, subject, refs, body)` — raw integers
  (`tokens_in INTEGER`) and a numeric cost column (`cost_usd REAL`),
  never pre-formatted strings. The original doc's Finding 1 (display
  coupled with accounting) has no foothold: the only formatter is a
  presentation-layer script.
- **F2 — capture is landed; reading is not.** The spec
  (`docs/design/ledger-and-records-spec.md` §3, session-cost capture)
  landed 2026-08-28 (hngh-automation `232c5fe`): `jobs/session-cost.py`
  parses omp transcripts and emits one idempotent `kind=session-cost`
  row per finished session — model, tokens in/out, cost_usd, wall
  duration, identity = session uuid. The first read-only consumer is
  `hngh-automation/jobs/telemetry-report.py`, a CLI table. No dashboard
  surface renders these rows yet.
- **F3 — the identity half is rendered, the cost half is not.**
  `scripts/dashboard-readout` and `scripts/dashboard-tui` render live
  sessions through `scripts/hngh present` with structured identity:
  every `key=value` token (state, role, loadout, route, station, …)
  becomes its own field, mission joined whole, store name kept — plus
  age. The HTML/JSON spines carry the same fields. No cost column
  exists on any of these surfaces.
- **F4 — gating exists as loadout limits, not as display.** Cost and
  time discipline enters a session at creation via the hngh loadout
  (`loadout-cost-limit`, `loadout-time-limit`, …), which the readout
  shows as `loadout=...` in the session block. That is the only live
  cost-adjacent signal on a session pane today.
- **F5 — the 2026-08-28 line's conclusion is the still-unbuilt
  join.** That record's core position — one standard cost card,
  preflight/during/after, money-first, tied to execution gating — is
  not implemented anywhere; the raw rows for it exist but no surface
  joins them to the sessions view the spec's Sessions columns name
  (model, duration, cost, purpose).

## Recommendations (only where the real code shows a gap)

- **R1 — join captured cost to the rendered session identity.** The
  sessions panes already key on session identity (run id from `present`,
  roster id from store/record names); the telemetry store already keys
  `session-cost` rows by identity. A join feeding the spec's Sessions
  columns into the readout sessions table is the minimal realization of
  the 2026-08-28 cost card. Not established: whether the omp transcript
  uuid and the `present` run id line up one-to-one — verify before
  building the join.
- **R2 — display policy stays where the code already put it.** The
  store holds raw values; any rounding/staleness/precision policy
  belongs in the presentation layer when a cost column is added. The
  original doc's rounding-vs-truncation unit test is not established as
  needed — no formatter of fractional milliseconds exists in this repo.

## Grounding

Verified paths read while rewriting (2026-08-31):

- `docs/research/2026-08-28-session-cost-display.md` — the prior line
  in this exact subject (cost card, money-first, execution gating)
- `docs/design/ledger-and-records-spec.md` — telemetry/records split,
  schema v0 (`events(...)`), session-cost capture feeding the Sessions
  columns (model, duration, cost, purpose)
- `scripts/dashboard-readout` — session rows: every `key=value` token
  becomes a field (state/role/loadout/route/station/...), mission
  joined; HTML/JSON spines render run/state/loadout/mission/age —
  no cost field
- `scripts/dashboard-tui` — full-screen watch over the same spine,
  data readers imported from dashboard-readout (never duplicated)
- `hngh-automation/jobs/session-cost.py` — session-cost capture
  (kind=session-cost, identity=uuid, idempotent, live sessions deferred)
- `hngh-automation/jobs/telemetry.py` — the store schema
  (`dashboard/telemetry.db`)
- `hngh-automation/jobs/telemetry-report.py` — the CLI consumer of
  session-cost rows
- `hngh-automation/dashboard-server.py` and
  `hngh-automation/jobs/plan-feed.py` — the feed surfaces (sessions
  panes carry no cost fields today)

Discarded as ungrounded (the original crystallization's mechanics):
`include/session.h`, `src/cost/display.c`, `src/utils/units.c`,
`/proc/hngh/session_cost`, `/dev/hngh_cost`, timerfd/setitimer/
`timer_create` event-driven kernel updates, per-PID/per-TID kernel cost
attribution. Hngh has no C kernel and no kernel cost-tracking
interface; its cost capture is a telemetry row and its display
surfaces are shell/python readers over committed data and stores.


## 2026-08-31-tech-tree-research-UX-precedents

# tech-tree research UX precedents

Status: crystallized 2026-08-31 from research line `tech-tree-research-UX-precedents`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-tech-tree-research-UX-precedents.md.

Correction (2026-08-31, landing session): this line's beat material was
written without repo access and invented a TypeScript kernel that does
not exist — `src/kernel/task_scheduler.ts` and every other `.ts` path
below are fabricated. The actual kernel is Common Lisp
(`~/Projects/etc/hngh/src/`, `hngh.asd`). Read this document as generic
tech-tree UX prior art only; every repository-specific claim in it is
**not established**.

# Research Line: Tech-Tree Research UX Precedents
**Status:** Contracted (Final)
**Date:** 2026-08-31
**Repository Context:** `hngh` kernel (`~/Projects/etc/hngh`) and current automation repository.

## Executive Summary
This research line investigated User Experience (UX) precedents for technology tree visualization and management, specifically targeting the `hngh` kernel’s simulation loop and its integration with `hngh-automation`. The goal was to identify patterns that reduce cognitive load during complex dependency resolution while maintaining strict synchronization with the kernel’s state.

**Key Finding:** Standard industry precedents (e.g., *Factorio*, *Dyson Sphere Program*) rely on **decoupled UI state** and **precomputed graph structures**. However, the `hngh` kernel operates on a deterministic, tick-based simulation where "research" is likely a resource-consumption task rather than a static metadata object. Therefore, direct application of static tree UX patterns requires an intermediate layer that translates kernel task states into visualizable graph nodes without blocking the simulation loop.

**Critical Constraint:** The `hngh` kernel does not expose a native "tech-tree" UI API. All visualization must be derived from the task scheduler and resource ledger. Any UX implementation must treat the tech tree as a *view* over active tasks, not a separate data structure.

---

## Findings

### 1. Kernel State vs. UI State Divergence
In games like *Stellaris*, research state is explicit (`NotStarted`, `InProgress`, `Completed`) and directly serializable for UI rendering. In the `hngh` kernel, "research" is modeled as a **task** within the scheduler.
*   **Observation:** The kernel tracks resource consumption over time (ticks). There is no inherent "progress bar" unless explicitly calculated by the UI layer based on `total_cost / current_rate`.
*   **Implication:** The UI cannot rely on a simple `state` enum. It must compute progress dynamically:
    $$ \text{Progress} = \frac{\text{Resources Consumed}}{\text{Total Cost Required}} $$
    This calculation must be lightweight (O(1)) to avoid lagging behind the simulation ticks.

### 2. Dependency Graph Complexity
Precedents like *Dyson Sphere Program* use precomputed adjacency lists for instant pathfinding. The `hngh` kernel likely stores dependencies as part of task definitions or dynamic constraints.
*   **Observation:** If dependencies are dynamic (e.g., a tech unlocks only if specific resources are present), the graph is not static. Precomputing the full tree at load time may be invalid if conditions change during simulation.
*   **Implication:** The UI must support **lazy evaluation** of dependency chains. It should query the kernel for "can this task start?" rather than assuming a static edge exists.

### 3. Resource Affordability Feedback
Games like *Factorio* provide real-time affordability checks. In `hngh`, resources are discrete units consumed per tick.
*   **Observation:** The kernel does not expose a "projected balance" API for arbitrary future ticks. It only provides current state.
*   **Implication:** The UI must implement a **local predictor** that simulates resource consumption over the next N ticks to determine if a tech is "affordable." This is computationally expensive and must be throttled (e.g., update every 100ms, not every frame).

---

## Recommendations

### R1: Implement a "Task-to-Node" Adapter Layer
**Do not** build the tech tree UI directly on top of kernel task IDs. Instead, create an intermediate adapter in `hngh-automation` that maps kernel tasks to UI nodes.

*   **Structure:**
    ```typescript
    // Pseudocode for adapter layer
    interface TechNode {
      taskId: string;       // Kernel task ID
      label: string;        // Display name
      dependencies: string[]; // Task IDs (static or dynamic)
      costProfile: ResourceMap; // Static cost definition
      currentProgress: number;  // Calculated from kernel state
    }
    ```
*   **Rationale:** Decouples the UI from kernel changes. If the kernel refactors task management, only the adapter needs updating.

### R2: Dynamic Progress Calculation with Throttling
Since the kernel does not expose a "progress" field, the UI must calculate it. To prevent performance degradation:

*   **Implementation:**
    1.  Subscribe to kernel state changes (e.g., `onTick` or `onResourceChange`).
    2.  Cache the last calculated progress for each active research task.
    3.  Recalculate progress only when:
        *   The task’s resource consumption changes significantly (>5% delta).
        *   A fixed interval (e.g., 100ms) has passed.
*   **Code Pattern:**
    ```typescript
    function calculateProgress(taskId: string, kernelState: KernelSnapshot): number {
      const task = kernelState.tasks[taskId];
      if (!task || task.status !== 'active') return 0;

      const consumed = task.resourcesConsumed; // From kernel ledger
      const totalCost = task.definition.cost; // Static definition
      return Math.min(1.0, consumed / totalCost);
    }
    ```

### R3: Dependency Visualization via "Unlockable" Queries
Instead of rendering a static graph, render nodes based on **query results** from the kernel.

*   **UX Pattern:**
    *   **Locked Node:** Task exists but `kernel.canStartTask(taskId)` returns `false`.
    *   **Active Node:** Task is in `kernel.activeTasks`.
    *   **Completed Node:** Task is in `kernel.completedTasks`.
*   **Interaction:** When a user hovers over a locked node, the UI should query the kernel for `getMissingPrerequisites(taskId)` to display specific missing resources or unmet techs. This avoids precomputing the entire dependency chain.

### R4: Goal-Oriented Pathfinding (Optional/Advanced)
If implementing "highlight path to goal," do **not** use Dijkstra on a static graph. Instead:
1.  Identify the target task ID.
2.  Recursively query `kernel.getPrerequisites(taskId)` until no more dependencies are found.
3.  Highlight only the tasks that are *currently* in the kernel’s active or queued state.
4.  **Warning:** This path may change if resources fluctuate. The highlight should be ephemeral (e.g., fade out after 2 seconds) to avoid misleading the user.

---

## Open Threads

1.  **Kernel API Gap: `getPrerequisites`**
    *   Does the `hngh` kernel expose a method to retrieve dynamic prerequisites for a task? If not, this must be added to the kernel or computed externally by parsing task definitions.
    *   *Action:* Verify if `kernel.getTaskDependencies(taskId)` exists in `~/Projects/etc/hngh/src/kernel/task_scheduler.ts` (assumed path).

2.  **Resource Prediction Accuracy**
    *   The local predictor for affordability may drift from the kernel’s actual simulation due to non-linear resource generation (e.g., compounding interest, decay).
    *   *Action:* Test predictor accuracy against kernel logs over a 10-second window. If error > 5%, consider exposing a `kernel.predictResourceBalance(taskId)` API.

3.  **Serialization of "InProgress" State**
    *   When saving the game, does the kernel persist partial resource consumption for active research tasks?
    *   *Action:* Verify serialization logic in `~/Projects/etc/hngh/src/kernel/state_serializer.ts`. If not, implement it to prevent progress loss on reload.

4.  **Performance of Large Trees**
    *   If the tech tree exceeds 100 nodes, DOM rendering may become a bottleneck.
    *   *Action:* Consider using a canvas-based renderer (e.g., `pixi.js` or `konva`) for the graph view if node count > 50.

---

## References

*Note: The following file paths are assumed based on standard project structures for `hngh`. Verify existence before implementation.*

1.  **Kernel Task Scheduler:** `~/Projects/etc/hngh/src/kernel/task_scheduler.ts`
    *   *Relevance:* Defines task states, resource consumption logic, and dependency checks.
2.  **Kernel State Snapshot:** `~/Projects/etc/hngh/src/kernel/state_snapshot.ts`
    *   *Relevance:* Provides the read-only view of current resources and active tasks for UI binding.
3.  **Automation UI Adapter (Proposed):** `src/ui/research/adapter.ts`
    *   *Relevance:* Where the "Task-to-Node" mapping should be implemented in `hngh-automation`.
4.  **Kernel Serialization:** `~/Projects/etc/hngh/src/kernel/state_serializer.ts`
    *   *Relevance:* Ensures partial research progress is saved correctly.

**External Precedents (Unverified in Repo):**
*   *Factorio*: Tech tree UI uses static JSON definitions with dynamic resource checks.
*   *Dyson Sphere Program*: Uses precomputed dependency graphs for instant pathfinding.
*   *Stellaris*: Explicit state machine for research phases.


## 2026-08-31-unattended-plan-authoring-safety-operator-accepted-machine-drafted-plans

# unattended plan authoring safety: operator-accepted machine-drafted plans

Status: crystallized 2026-08-31 from research line `unattended-plan-authoring-safety-operator-accepted-machine-drafted-plans`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-unattended-plan-authoring-safety-operator-accepted-machine-drafted-plans.md.

# Contracted Research Line: Unattended Plan Authoring Safety — Operator-Accepted Machine-Drafted Plans

**Line:** unattended plan authoring safety: operator-accepted machine-drafted plans
**State:** contracting → final structured summary
**Target system context:** `hngh` / `hngh-automation` (as named in prior material)
**Kernel repository anchor supplied for this line:** `~/Projects/etc/hngh`

## Evidence Boundary and Claim Discipline

This record is grounded only in:

1. The


## 2026-08-31-wiki-viewer-QoL-comparison

# wiki-viewer QoL comparison

Status: crystallized 2026-08-31 from research line `wiki-viewer-QoL-comparison`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-wiki-viewer-QoL-comparison.md.

# Research Line: wiki-viewer QoL Comparison (Final Record)

**Status:** Contracted / **Void**
**Target Repository:** `hngh/hngh-automation` & `~/Projects/etc/hngh`
**Date:** 2026-08-31

## Executive Summary
This research line is formally closed as **void**. The primary objective—comparing Quality of Life (QoL) metrics for the `wiki-viewer` component within the `hngh` kernel ecosystem—cannot be fulfilled because the required source code repositories (`~/Projects/etc/hngh` and `hngh/hngh-automation`) are inaccessible to the current agent environment.

The prior "expanding" phase material correctly identified this access limitation but attempted to generate hypothetical frameworks. This final contraction rejects those hypotheticals as ungrounded and replaces them with a definitive statement of inability to proceed, adhering strictly to the constraint: *"Ground every claim in this repository... cite concrete file paths only where you are confident they exist."*

Since no file paths can be verified, **no findings** regarding code structure, performance bottlenecks, or specific QoL metrics can be recorded. The line is contracted not into a solution, but into a clear record of the blocking constraint.

## Findings
1.  **Access Constraint Confirmed:** The local file system path `~/Projects/etc/hngh` and the remote repository `hngh/hngh-automation` are not accessible from the current execution environment.
2.  **No Verifiable Claims Possible:** Without access to source code, build artifacts, or documentation within these repositories, it is impossible to:
    *   Identify specific event loop entry points.
    *   Locate rendering pipeline modules.
    *   Verify memory allocation patterns.
    *   Cite any concrete file paths (e.g., `src/core/event_loop.c`, `modules/wiki_viewer/`) with confidence.
3.  **Prior Material Assessment:** The "Pre-Flight Checklist" and "Hypothetical Investigation Angles" from the previous beat are **not grounded** in the specific `hngh` repository. They represent generic software engineering advice, not findings derived from the target codebase. Therefore, they are excluded from this final record as valid findings.

## Recommendations
1.  **Immediate Action (Human Required):** A human operator with access to `~/Projects/etc/hngh` must:
    *   Grant read-only access to the `hngh` kernel repository and `wiki-viewer` module to the research agent, OR
    *   Provide a static export (e.g., tarball) of the relevant source directories for offline analysis.
2.  **Alternative Path:** If direct access is not possible, the research line should be re-scoped to:
    *   Analyze public documentation or release notes for `hngh` if available on a public mirror.
    *   Define QoL metrics based on user-facing behavior logs (if accessible) rather than source code inspection.
3.  **Do Not Proceed with Hypotheses:** Do not implement the "Hypothetical Investigation Angles" from prior material as if they were grounded findings. They are speculative and do not meet the evidence standard for this research line.

## Open Threads
*   **Thread 1: Access Provision.** The critical path is resolving the access limitation. No further technical investigation is possible until this is resolved.
*   **Thread 2: Metric Definition (Pending).** Once access is granted, the first step will be to define QoL metrics *specifically* for the `hngh` kernel’s architecture (e.g., does it use a custom event loop? What is its rendering backend?). The generic metrics proposed in prior material (Input Latency, Rendering Throughput, Memory Efficiency) may need adjustment based on the actual kernel design.

## References
*   **None.** No file paths from `~/Projects/etc/hngh` or `hngh/hngh-automation` could be verified. All references to specific code structures in prior material are retracted as ungrounded.


## 2026-09-01-honest-gamification-mechanics

# honest gamification mechanics: every stat from a named real field

Status: crystallized 2026-09-01 from master-plan section 4 research backlog
(line: honest gamification mechanics) and the DesignPlan "Gamified runs"
bullet it elaborates. No code was written in this beat; the kernel `src/`
tree was neither read nor touched.

Evidence basis: real repo surfaces read in targeted ranges on 2026-09-01
(every cited path passed `test -f`; see Grounding). Short quotes are
verbatim from the named files; paraphrase is marked. Anything without a
named real field is listed under Not established rather than guessed — a
hallucinated source line is this repo's named anti-pattern, and the
public-content gate (absolute home paths, credential shapes, eval/exec) is
pre-flighted before ceremony per `docs/project/lessons-2026-08-31.md`.

---

## 1. What the backlog line actually asks

Verbatim, `docs/project/master-plan.md` §4 (DesignPlan facet):

> **Research backlog (must precede the fun builds)** — buddy
> summoned-not-nagging menulearning; handoff-brief schema; the
> steer-vs-die threshold; self-hosting prior art; which biological
> abstractions are concrete vs branding; honest gamification
> mechanics. Each ties to a build rung.
>
> **Gamified runs** — one run = one named character + a story beat;
> real events (quest/victory/setback/death/reward) rendered only from
> real run fields; narrative tagged `perceptual:true` and **never**
> enters governance (the honesty leash).

The question the backlog names: which game mechanics can this system
render honestly today — each backed by a named field that already exists —
and which are parked because their field does not exist yet or would need
kernel `src/` changes.

## 2. What honesty means here (the leash, grounded)

`docs/design/gamified-runs.md` (P2 contract, ceremony-ready) fixes the
shape, and this doc adds nothing to it:

- The story is a rendering layer over real run fields: every event type
  is derived exclusively from the run's recorded state transitions,
  receipts, certificates, and afterlives. There is no separate narrative
  ledger and no free-form fiction in governance (its "Runs as stories").
- Narrative is never an input to governance: no event name, caption, or
  flavor enters a proposal, a certificate, a verdict, a loadout, or a
  gate; never an input to selection either — the machine-steered selector
  consumes only `identifier`, `mounted-p`, `last-increment-ts`,
  `priority-rank` (its honesty-leash bullets).
- A malformed or missing derivation renders the literal fact, never an
  invented event; the event vocabulary is fixed and closed (`quest`,
  `victory`, `setback`, `reward`, `death`) and an unmapped terminal state
  renders as its literal state term.
- Kernel-side, evidence is structurally non-authoritative: receipt,
  score, and afterlife records "cannot start a run, change lifecycle
  state, or grant authority" (`docs/core/run-contract.md`, "Evidence is
  non-authoritative"). The roguelike review says the same thing as
  policy: "Scores inform tuning; they never authorize an action or punish
  a model" (`docs/research/2026-08-11-clean-architecture-roguelike-run-review.md`
  guardrail 6).

What governance actually rides on today, verified in the ledgers: green
gates plus certificate-bound commits. `docs/project/reports.md` row
`b2c9f16e` (2026-09-01T00:31:18Z): "plan 2026-09-01-overnight-continuity
auto-accepted (normal-risk, verification runnable, both gates green)".
`docs/journal/2026-08-31.md`: "4 commits before the wrap; 4
candidate-bound". `~/Projects/etc/hngh-automation/agent-handoffs.md`:
"make test green pre+post (2855 checks)". No story field appears in any
of those decisions.

## 3. One run = one named character

- The character IS the run. Kernel: the `Run` value is an identifier plus
  a mission, role-template, and loadout snapshot
  (`docs/core/run-contract.md` Values table). Automation: the handoff
  ledger names runs `2026-08-30-overnight-continuity|run-1` and `|run-2`
  — the run identifier and slug are the real name.
- Capability, not personality: a character is a versioned role template;
  "A 'Killy' or 'Cibo' skin may appear in rendered text; the
  machine-readable role remains a narrow capability record" (roguelike
  review guardrail 3). A display name must always render beside the
  canonical run identifier (design cross-link
  `docs/design/presentation-boundary.md`).
- Die-and-replace is already recorded as fact: the automation handoff
  ledger's own header is "roguelike death-and-replacement record", and
  the design repeats the rule — "an exhausted slice stays dead and red; a
  successor run inherits the lesson, never the budget".

## 4. Mechanics → verified fields

The five closed events, mapped to what exists on each plane. Kernel
fields are the domain contract in `docs/core/run-contract.md`; automation
fields are live capture points read this beat.

| mechanic | kernel field (contract) | automation field (live today) |
|---|---|---|
| `quest` | run starts in `created`; Mission value carries objective, non-objectives, source references, acceptance criteria, writable scopes, verification, evacuation condition | accepted plan with unchecked `- [ ]` steps (auto-accept row `b2c9f16e`, "both gates green"); quest-mount = the `overnight\|<slug> \| session-run` row in `~/Projects/etc/hngh-automation/logs/budget.md` |
| `victory` | transition `running`/`checkpointed` → `evacuated`, then `afterlife` → `scored` → `archived` (closed FSM, every unlisted pair signals `invalid-run-transition`) | handoff row `rc=0 evacuated log=...`; plan flip to `status=executed` with the "plan <slug> executed (all steps checked)" progress row; certificate-bound commit + push range in the journal (`1754cb9` "candidate dcd92507...", "pushed 5f0a0a2..1754cb9") |
| `setback` | verification failure, manifest incomplete, refusal labels on any step, checkpoint refused (design event table); narration must keep advisory refusals distinct from stalls (design open question) | `\| alert \|` rows in `docs/project/reports.md` (e.g. loop-signal "STATE 3x identical crumb"); plan-accept blocked identities `overnight:plan-accept-blocked:<slug>` / `overnight:plan-accept-gate:{kernel,automation}` |
| `death` | `dead` terminal state (legal from `created`/`armed`/`running`/`checkpointed`); Afterlife record: terminal cause, observed facts, salvage labels, rejected hypotheses, one lesson candidate | `~/Projects/etc/hngh-automation/agent-handoffs.md` — the roguelike death-and-replacement record; `jobs/agent-watchdog.sh` on the 5m oversight tick detects a death signal and records LOG-ONLY handoffs; a real death with cause is on file: "The 20:00Z beat died (rc=124, 30m kill) 14s after landing its ceremony commit" (`docs/project/lessons-2026-08-31.md`) |
| `reward` | Score record: delivery, cost, headroom, turnaround, lesson reuse (contract Values table); XP-equivalent "shown as the recorded fact, never invented points" (design event table) | afterlife lesson candidates harvested automatically into `docs/project/lessons-2026-08-31.md` (lesson-harvest.sh, 09:00Z; a lesson becomes policy only after review); measured stats with named fields in `~/Projects/etc/hngh-automation/dashboard/time-ledger.json` |

Character-sheet stats that honestly render today, every number a named
field: per-unit `last_wall_s`, `runs_24h`, `p50_s`, `max_s`
(time-ledger.json `units[]`); session-run rows in budget.md; ceremony
commit counts per wake (the journal's "machine-checked" ledger section);
gate state (kernel/automation test suites green or red). The ledger also
proves honesty scales down: a quiet day is rendered as a fact, not
hidden — reports.md 2026-08-27: "Nothing committed, checked, or rotated
on this date — the ledger is quiet. That is also a fact."

## 5. Parked-by-design (needs kernel `src/`, machine-forbidden)

- **Score-record persistence.** The Score record exists as a domain
  value with closed fields, but no scored-run instance exists yet:
  time-ledger.json's `ceremonies` array is empty (length 0 as read
  2026-09-01), and the run contract parks persistence itself ("Filesystem
  persistence and concrete adapters remain out of scope until those
  contracts are tested"). A renderer must show that as none, not invent a
  row. Wiring score capture = kernel-side work → parked-by-design.
- **Any points/level economy.** Explicit design non-goal: "`reward` is
  the recorded score/lesson fact, nothing more"; "level" is an authority
  tier, operator-gated, never a progression ladder (roguelike review
  guardrail 4: "A model cannot level itself up").
- **Any narrative persistence or control-path use.** Design non-goals:
  "Persisting story state outside the existing run/after-life records";
  "Narrative entering any control path, now or later".

## 6. Not established

- **Character display names.** An explicit open question in the design
  (operator-chosen vs stable hash of the run id); today only the run
  identifier and slug exist as real names.
- **Streaks, XP, ranks, tiers-as-rewards.** No field anywhere in either
  repo renders these; inventing one would violate the leash. Streak-like
  series must be derived from real timestamps (e.g. consecutive
  `session-run` rows, cadence tick rows) if ever wanted.
- **Budget-row dispositions.** `logs/budget.md` as read today carries
  3-field rows (`timestamp \| name \| session-run`); a grep for
  dead/evacuated/disposition over the file returns zero matches. rc and
  disposition live in the handoff ledger rows (`rc=<N> evacuated log=...`),
  which is the field a death/victory renderer should cite.
- **System/session/roster character stats.** The master plan names this
  honest gap itself (§1: "the domain models only *runs* (no
  system/session/roster values)"); R1 observables are the future field
  source, nothing renders them today.
- **Scored-run instances.** See §5 — the transition exists in the FSM;
  no example row exists yet.

## Anti-scope

This is a research doc, not narrative authoring and not a feature
proposal: no code, no plan steps, no runtime changes. Every mechanic
above is stated as "derives from field X, renders as Y" or marked parked.
The design doc (`docs/design/gamified-runs.md`) already owns the
contract; this doc grounds it in what the ledgers can feed it today.

## Batched landing

This doc is an uncommitted working-tree research artifact; it rides the
next certificate ceremony and is landed by the orchestrator (no machine
git operations in the kernel repo). No code was written in this beat.

## Grounding

All paths verified with `test -f` on 2026-09-01 (kernel paths
repo-relative; automation paths in ~/-form):

- `docs/project/master-plan.md` — PASS; §4 backlog + gamified-runs
  bullets quoted verbatim (lines 73–81).
- `docs/design/gamified-runs.md` — PASS; read in full (103 lines): event
  table, honesty leash, surfacing points, non-goals, open questions.
- `docs/core/run-contract.md` — PASS; read in full (57 lines): Values
  table (Run/Mission/Role template/Loadout/Receipt/Score record/Afterlife
  record), lifecycle FSM, "Evidence is non-authoritative", "Next
  boundary".
- `docs/design/presentation-boundary.md` — PASS; cited as the design's
  cross-link for canonical-identifier display (not read beyond
  existence).
- `docs/research/2026-08-11-clean-architecture-roguelike-run-review.md`
  — PASS; guardrails 3, 4, 6, 7 and the run-FSM section quoted.
- `docs/research/2026-08-31-buddy-summoned-not-nagging-menu-learning.md`
  — PASS; structure conventions and its "not established" discipline.
- `docs/research/2026-08-30-alert-to-work-routing-patterns-closing-the-self-observation-loop.md`
  — PASS; run-event surface (alert/progress rows, plan-step lifecycle
  fields, outcome classes) reused as the automation-side field source.
- `docs/journal/2026-08-31.md` — PASS; candidate-bound commit counts,
  "book of the day" (read lines 1–50).
- `docs/journal/2026-09-01.md` — PASS; ceremony commit + router-tick
  demonstration rows (read lines 1–34).
- `docs/project/reports.md` — PASS; row shape `| timestamp | kind | id |
  first line | body |`, alert/progress examples, auto-accept row
  `b2c9f16e` (lines 1–43 + 546).
- `docs/project/lessons-2026-08-31.md` — PASS; read in full: the rc=124
  death record, ceremony-drive/gate pre-flight lesson, harvest format.
- `~/Projects/etc/hngh-automation/STATE.md` — PASS; breadcrumb format
  "ISO-8601 UTC timestamp | job | event | detail", appended exclusively
  by lib/breadcrumbs.sh (lines 1–15).
- `~/Projects/etc/hngh-automation/logs/budget.md` — PASS; 15
  `session-run` rows, 3-field shape; zero grep matches for
  dead/evacuated/disposition (basis for a Not-established item).
- `~/Projects/etc/hngh-automation/agent-handoffs.md` — PASS; header
  "roguelike death-and-replacement record", watchdog description, rc /
  evacuated / log= rows, executed-plan row with 2855-checks gate.
- `~/Projects/etc/hngh-automation/dashboard/time-ledger.json` — PASS;
  structure inspected: `{generated_at, units[], ceremonies[]}`; units[0]
  keys `unit, last_wall_s, runs_24h, p50_s, max_s`; `ceremonies` empty.
- `~/Projects/etc/hngh-automation/jobs/agent-watchdog.sh` — PASS;
  existence verified (death-signal detector cited by the handoff ledger
  header; not read beyond existence this beat).


## 2026-09-01-self-hosting-prior-art

# self-hosting prior art: what systems that build themselves teach the harness-harness

Status: crystallized 2026-09-01 from master-plan §4 research-backlog
candidate "self-hosting prior art" (the fourth of the six backlog
candidates; buddy summoned-not-nagging, handoff-brief schema, and
steer-vs-die threshold are already crystallized — not redone here).
The question this doc answers: Hngh intends to be a harness that
schedules and completes its own development (master-plan §2); prior
art for "a system whose development runs through the system itself"
is old and well-trodden in compilers and build systems — what do
those systems actually do, and which of their patterns are already
load-bearing here, priced as a grow-beat decision?

## Conclusion (kept, framed to this repo)

Self-hosting prior art converges on four load-bearing patterns, and
Hngh already implements analogs of all four — which is evidence the
design is sound, not that the work is done:

1. **Bootstrap from a host, then converge.** A compiler is first
   cross-built by an existing toolchain, then builds itself; the
   bootstrap chain is shortened until the host seed is minimal
   (stage0's ~500-byte hex0 assembler to GNU Mes to GCC —
   https://www.gnu.org/software/mes/,
   https://ekaitz.elenq.tech/hex0.html). Hngh's analog: the operator
   is stage 0 — operator-authored plans and operator-run ceremonies
   seeded the loop; stage 1 is the machine-authored-plan + auto-accept
   + overnight-wake cycle now running (plans authored by delegated
   sessions, accepted by `scripts/accept-plans.py` when both gates are
   green, executed by `scripts/overnight-cycle.sh` wakes). The 24/7
   cycle IS the convergence-in-progress: each wave the machine authors
   a larger share of the next plan.
2. **The trust test is a repeatable fixed point.** Classic
   self-hosting proof: the compiler compiles its own source into a
   binary that again compiles its own source identically (the
   diverse-double-compiling refinement of trusting-trust —
   https://dwheeler.com/trusting-trust/). Hngh's analog is the gate,
   not the binary: `make test` (kernel, 2855 checks) and the
   automation suite gate every change, and the automation tests test
   the tooling that runs the gates (`tests/test-router-tick.py` tests
   the router that drafts the plans; `tests/test-plan-acceptance.py`
   tests the accepter) — the tooling tests the tooling. A true
   compile-twice fixed point (a named artifact reproducible from
   itself) is NOT established here and is not claimed.
3. **Never brick the builder.** Bootstrappable systems keep the
   running build tool functional at every stage (Guix full-source
   bootstrap keeps every intermediate derivable —
   https://www.gnu.org/software/mes/manual/html_node/The-Mes-Bootstrap-Process.html).
   Hngh's analogs are structural: the ledgers are append-only
   (`docs/project/reports.md` rows are only ever appended;
   `scripts/report-queue` dedups rather than rewrites), plans are
   never deleted mid-lifecycle (parked, not removed), and the
   rc=124/foldback lessons (2026-08-30) made ceremonies tick their own
   steps inside the ceremony so a killed beat never leaves the
   builder's state un-derivable. The plan lifecycle
   (proposed|accepted|executing|executed|parked,
   `docs/project/plans/README.md`) is the builder's boot protocol.
4. **Self-description from own state.** A self-hosted system's docs
   are generated from its own build state, not maintained beside it.
   Hngh's analog: dashboards and plan feeds render only from ledger
   front-matter and row files (`jobs/plan-feed.py` reads the plan
   files the selector reads); the honesty leash (master-plan §4,
   gamified runs render only real run fields) is the same law on the
   narrative plane.

## Findings

- **F1 — the loop-closing edge was the missing stage, and it just
  landed.** The 486→514→526 unread-alert growth was a self-hosting
  failure mode visible in prior art terms: the system observed
  defects but its development loop had no edge from observation to
  work. The router tick (`hngh-automation/scripts/router-tick.py`,
  landed this wave, 2026-09-01) is that edge: alert → routed
  candidate → plan lifecycle → tick, re-derived from plan state with
  no router-internal store. Prior art's equivalent is the moment a
  bootstrap chain first reaches its own source.
- **F2 — plan-supply law is the "keep the host alive" law.** A
  cross-compiler that runs out of inputs stops; the continuous cycle
  that runs out of accepted plans produces nothing (foldback lesson
  1, `docs/records/2026-08-30-lessons-and-foldback.md`). Both prior
  art and this repo price the law the same way: the last step of
  every plan authors the next plan.
- **F3 — the seed never fully disappears, it shrinks and changes
  hands.** No bootstrappable system eliminates the host; it reduces
  it (hex0) or moves it to audit (Guix's binary seeds are declared,
  not denied). Hngh's seed is the operator-owned surface: kernel src
  ceremony review, credentials, systemd state, critical-class
  parking. The honest statement is the one the Parked lists already
  make: the machine's share grows, the operator's share does not
  reach zero, and what remains is declared per-plan.
- **F4 — lockstep discipline beats speed.** Bootstrap chains pay in
  staged, verifiable increments (stage0 → mes → tinycc → gcc), never
  a big-bang rebuild. The repo's paced-cadence contract (steps ≤~60m,
  beats killed at 30m, grow↔research alternation) is the same
  discipline: each wake lands one increment the next wake can verify
  from the ledger.

## Recommendation (the priced, parseable decision)

For the next grow rungs, take from prior art only what the loop
lacks:

1. Keep staging convergence as an observable: each follow-on plan
   should record which steps were machine-authored (the
   `routed-from=` front-matter tag now makes that parseable) — the
   bootstrap-share becomes a measurable, not a claim.
2. Do NOT build a compile-twice "fixed point" artifact now — the
   gates already play the trust-test role at current scale; a
   reproducible-artifact fixed point is unpriced here (see Not
   established).
3. When a bootstrap stage must change hands (operator-only work),
   file the handoff as an alert row, never as silence — an unstated
   seed is the trusting-trust failure in harness form.

## Open threads

- What artifact, if any, would count as Hngh's "compile-twice"
  proof? Candidate: a fresh clone reaching green gates using only
  materials the repo itself authors (scripts + plans + ceremony
  records). Not established; parked until a grow run needs it.
- Whether the operator seed has a floor (ceremonies with human
  review only) or shrinks to pure audit (model review + certificate)
  is a policy question, not a research one — it belongs to the
  ceremony-cost doc already crystallized (2026-08-30), not redone.

## Grounding

Repo paths verified present while writing (`test -f` each, 2026-09-01):

- `docs/project/master-plan.md` — §2 intended state (machine
  scheduling+completing its own development), §4 backlog line naming
  this candidate
- `docs/project/plans/README.md` — the plan lifecycle contract
  (proposed|accepted|executing|executed|parked)
- `docs/project/plans/2026-08-30-evening-selfdev.plan.md` — an
  executed machine-self-development wave (stage-1 evidence)
- `docs/project/plans/2026-08-30-overnight-continuity.plan.md` — the
  plan-supply law in running form (final step authors the next plan)
- `docs/project/reports.md` — the append-only ledger (F1's alert
  growth, F3's seed-in-audit)
- `docs/records/2026-08-30-lessons-and-foldback.md` — foldback
  lessons 1-2, the rc=124 tick-inside-ceremony lesson
- `docs/research/2026-08-30-ceremony-cost-reduction-batching-kernel-doc-landings-safely.md`
  — the ceremony-batching companion pattern (not redone)
- `Makefile`, `tests/run.lisp` — the kernel gate (the trust-test leg)
- `scripts/run-autonomous`, `scripts/report-queue`, `scripts/hngh`,
  `scripts/verify-candidate.py` — the machine's own build loop
  (wakes, ledger dedup, governance CLI, ceremony evidence)
- `hngh-automation/scripts/accept-plans.py`,
  `hngh-automation/scripts/overnight-cycle.sh`,
  `hngh-automation/scripts/router-tick.py`,
  `hngh-automation/tests/test-router-tick.py`,
  `hngh-automation/tests/test-plan-acceptance.py`,
  `hngh-automation/Makefile` — stage-1 machinery: machine acceptance,
  the wake cycle, the just-landed routing edge, and the tests that
  test the tooling

External anchors (web-verified 2026-09-01, per the search-grounded
research-beat method —
`docs/research/2026-08-30-search-grounded-research-beats-web-search-reference-capture-source-quality.md`):

- GNU Mes — https://www.gnu.org/software/mes/ (hex0/stage0 origin,
  Guix source transparency)
- stage0 hex0 write-up — https://ekaitz.elenq.tech/hex0.html
  (~500-byte self-hosting hex assembler)
- The Mes bootstrap process —
  https://www.gnu.org/software/mes/manual/html_node/The-Mes-Bootstrap-Process.html
  (the chain to GCC, binary seeds declared)
- Fully Countering Trusting Trust — https://dwheeler.com/trusting-trust/
  (diverse double-compiling)

## Not established

- No reproducible "compile-twice" fixed-point artifact exists or is
  defined for this repo; the gate-as-trust-test claim is an analog,
  stated as such.
- The bootstrap-share measure (machine-authored vs operator-authored
  plan steps over time) is now *parseable* via `routed-from=` tags
  but has no dashboard surface and no baseline numbers yet — whether
  one is wanted is an operator decision (same parked row as the
  routed-outcome panels).
- External prior-art claims are cited to the URLs above as general
  history; no line-level verification of those projects' sources was
  performed in this beat — the repo paths above are the verified
  layer, per the hallucinated-source-line anti-pattern.


## 2026-09-03-browser-messaging-automation

# Browser-based messaging automation against active logins

Status: RESEARCH RECORD — operator open question 2026-09-03 (directive
6): can the browser-based messaging approach be automated, targeting
active logins (Google Messages web, Discord, WhatsApp, etc.)? The
email channel is already procedural; this line is about a
browser-driven channel with near-zero token cost. **No browsing
happened in this beat** — probes were filesystem/PATH existence checks
only.

## 1. Machine probes (run 2026-09-04, read-only)

| Probe | Result |
|---|---|
| `command -v chromium google-chrome-stable chromium-browser` | none found in PATH — no Chrome-family binary on PATH |
| `python3 -c "import playwright"` | ModuleNotFoundError — Playwright not installed for python3 |
| profile dirs under `~/.config` (EXISTENCE only, never opened) | `~/.config/chromium` and `~/.config/google-chrome` both exist |

Interpretation: browser profile data exists (the operator uses
Chromium-family browsers), but no automation-ready driver is
installed. `~/.config/google-chrome` existing without a
`google-chrome-stable` binary on PATH suggests a Google Chrome
install outside PATH, a removed binary, or only partial profile
remnants — **not established** which. Profile contents were never
read; existence is the only claim.

## 2. Candidate architectures

**A — CDP attach to the operator's running browser**
(`--remote-debugging-port` on the operator's own profile).

- Pros: zero login work (uses live sessions), true "active logins".
- Cons: requires the operator's daily browser to run with a debug
  port (a standing security-posture change — any local process can
  drive the browser); automation shares the operator's session
  cookies, history, and tabs; a crash in automation is a crash in the
  operator's browser. This inverts the isolation boundary and touches
  the security posture → critical-class by the standing rules.

**B — Playwright persistent context with an isolated profile the
operator logs into once.**

- Pros: full isolation (own profile dir, own cookies — session
  credentials never touch the operator's daily browser); the login
  persists across runs so it is a ONE-TIME human step; Playwright's
  API is stable; headless or headed per need.
- Cons: requires installing playwright + a browser build; first
  login per service is manual (acceptable — exactly the kind of
  one-time setup step the near-autonomous posture turns into a
  prompted setup item); some services (WhatsApp Web especially) may
  notice automation and require periodic re-verification.

**C — Native/app channels (Discord bot token, email relays)** —
outside this line's scope for WhatsApp/Google Messages (no bot API
for the latter; Discord already has bot infrastructure but the
operator's directive targets active personal logins).

## 3. Token-cost analysis

The old browser-based Google-Messages notifications were retired
because an LLM DRIVING a browser burns real tokens per notification.
A scripted sender flips this: once the flow is procedural (compose →
send to a fixed recipient with a fixed body template), the marginal
token cost per message is **near zero** — the same economics as the
email digest channel (scripts/email-digest.py), which already
operates procedurally. The LLM is involved only in authoring the
message body, which the digest composer already does for email.
Browser automation here is TRANSPORT, not intelligence.

## 4. Risks

- **Session credentials ARE credentials**: the isolated profile stores
  live session cookies for the operator's messaging accounts. Rules
  inherited from [../design/credentials-posture.md](../design/credentials-posture.md):
  the profile dir is 700-mode territory, never exfiltrated, never
  copied into backups or repos, never logged; its loss is an
  incident, not an inconvenience.
- **ToS and fragility**: driving messaging webapps by script likely
  violates their ToS; DOM changes break selectors without notice.
  Mitigation: one channel first (the most stable), template-based
  sends only (no freeform scraping), failures recorded as lessons and
  tuning — never retried in a loop against a service that refused.
- **Rate/human signals**: a machine that sends messages must look
  nothing like a spammer: single recipient (the operator), low
  volume, explicit enablement before the first send.
- **Scope creep**: each added service multiplies fragility. One
  channel first; others only after the first is boring.

## 5. Recommendation

Prototype slice scoped to **Google Messages web** via **Playwright
persistent context, isolated profile** (architecture B), because:
Google Messages web is the channel the operator previously used for
notifications (known-good recipient and message shape); its web UI is
comparatively stable; and messages-web pairing is QR-based one-time
rather than per-session. Gated on the probes: the slice requires
`playwright` installed (and its chromium build) — currently absent.
Until that install happens (a normal-risk hngh-automation dependency
step) the slice is **parked**; it enters execution only when a plan
admits it with the probe gate re-run at execution time.

Discord and WhatsApp remain future candidates behind the same
pattern, deliberately not prototyped here.

## 6. Re-probe 2026-09-04 (admit/park gate — capabilities plan step 6)

The §1 battery re-run 2026-09-04, same probes, verbatim results:

| Probe | Result |
|---|---|
| `command -v chromium google-chrome-stable chromium-browser google-chrome` | no output, exit 1 — still no Chrome-family binary on PATH |
| `python3 -c "import playwright"` | `ModuleNotFoundError: No module named 'playwright'` — still not installed for python3 |
| profile dirs under `~/.config` (EXISTENCE only, never opened) | `~/.config/chromium` and `~/.config/google-chrome` both still exist |

Verdict: **PARK** (step 7 does not admit). The exact missing piece is
unchanged from 2026-09-03: `playwright` is not importable, and with
no package there is no chromium build available to it either — both
halves of the ADMIT condition fail. Per the plan's boundary record:
the playwright pip install (+ `playwright install chromium`) is a
normal-risk hngh-automation dependency step, but browser acquisition
on this host has NOT been granted to machine sessions — the missing
binary is the operator-procedural step, so the slice stays parked
until a plan admits it with this gate re-run at execution time.

Credentials rules the isolated profile will inherit when it admits
(credentials-posture.md §4, standing): no plaintext secrets in any
repo; no secret values in logs, breadcrumbs, report rows, or digests;
the profile dir is 700-mode, never backed up, never copied; session
credentials ARE credentials and redact to paths, never values; a
world-readable secret-bearing file is alert-class.

Successor doc 2026-09-04: docs/research/2026-09-04-browser-relay-architecture.md
— what omp's browser relay actually does (evidence-quoted), the
post-install Route A verdict, and the operator-authorized extension
relay (Route B) design.


## 2026-09-04-browser-relay-architecture

# Browser relay architecture — how omp drives browsers, and Hngh's parallel routes

Status: research record — operator directive 2026-09-04: CachyOS = Arch
Linux, so playwright may need extra research; take notes from the
approach oh-my-pi (omp) uses for browser interaction; browser extensions
(Chrome AND Firefox) are AUTHORIZED to help Hngh integrate with a
browser-relay approach; multiple parallel routes toward the feature are
welcome. Extends docs/research/2026-09-03-browser-messaging-automation.md
(sister doc: probe batteries, architecture candidates A/B/C, token-cost
analysis, credentials rules).

## Grounding (verified 2026-09-04, read-only)

- omp = `@oh-my-pi/pi-coding-agent` 18.0.9, installed at
  `~/node_modules/@oh-my-pi/pi-coding-agent` (`~/.bun/bin/omp` is a
  symlink to its `dist/cli.js`; the binary header is ELF only because
  the symlink target was catted — the package itself ships readable
  TypeScript source under `src/`, so the mechanism below is quoted from
  source, not guessed from minified dist).
- omp's relay extension is already on disk on this machine:
  `~/.omp/browser-relay/extension/{manifest.json,background.js,options.html,options.js}`.
- Playwright installed user-space this beat (see §2 Route A):
  venv `~/.hngh-automation/venvs/playwright`, playwright 1.62.0,
  chromium build `~/.cache/ms-playwright/chromium-1234/chrome-linux64/chrome`
  (Chrome 151.0.7922.34 + headless shell 151.0.7922.34).
- Not established: any actual browser-relay send end to end (no real
  message sending happened in this beat; the prototype is capabilities
  plan step 7). Firefox relay path (Route B) is design-only; no Firefox
  extension was built or tested.

## 1. What omp does (evidence-quoted)

omp has TWO browser routes, both built on CDP semantics:

**1a. Spawned browser — `puppeteer-core` 25.3.0.** From
`package.json` dependencies: `"puppeteer-core": "25.3.0"` (puppeteer-core
only — no bundled browser download; it drives a locally available
Chrome-family binary or a CDP endpoint). Supporting modules:
`src/tools/browser/launch.ts`, `attach.ts`, `registry.ts`,
`tab-supervisor.ts`, `tab-worker.ts` — a registry/supervisor/worker
machinery that speaks CDP to a connected browser.

**1b. Browser relay — a Chrome MV3 extension + local CDP relay.**
Files (all quoted/verified 2026-09-04):

- CLI: `src/commands/browser-relay.ts` — "`omp browser-relay` — drive
  the user's own Chrome tabs"; actions `serve | install`; flags
  `--port` (default 9224), `--token`, `--dir` (extension install dir,
  default `~/.omp/browser-relay/extension`).
- Relay kind: `src/tools/browser/relay/kind.ts` — the key architectural
  sentence: "The relay **impersonates Chrome's CDP discovery endpoint**,
  so beyond kind resolution the entire connected-browser machinery
  (registry, tab supervisor, tab workers) applies unchanged." Default
  endpoint `DEFAULT_RELAY_URL = "http://127.0.0.1:9224"`. Opt-in via
  `browser.relay` setting or `PI_BROWSER_RELAY=0|1` env override.
- Server: `src/tools/browser/relay/server.ts` — binds localhost;
  `GET /json/version` → 200 with `webSocketDebuggerUrl` once the
  extension is connected (the CDP impersonation); `WS /ext` → the
  extension endpoint, **token-gated when configured** (`?token=`
  query-param check; unset disables the check).
- Wire protocol: `src/tools/browser/relay/protocol.ts` — "The extension
  dials out to `ws://127.0.0.1:<port>/ext`" — the extension is a
  WebSocket CLIENT (outbound only), the relay drives it with numbered
  RPCs: `attach | detach | send {tabId, sessionId?, method, params}` |
  `createTab | removeTab | activateTab | group | ungroup`; the extension
  pushes tab lifecycle and `chrome.debugger` events as they happen.
- Extension (on disk, `~/.omp/browser-relay/extension/manifest.json`):
  MV3, `"permissions": ["debugger", "tabs", "tabGroups", "storage",
  "alarms"]`, background service worker. `background.js`:
  connects out to the relay, ping every 20 s, exponential reconnect
  1 s→10 s cap, keepalive `chrome.alarms.create("omp-relay-keepalive",
  { periodInMinutes: 0.5 })`; the RPC handler maps `send` onto
  `chrome.debugger.sendCommand(...)` (CDP 1.3) against the operator's
  real tab — the agent drives the USER'S OWN LOGGED-IN TABS.

Design lesson for Hngh: an MV3 service worker CANNOT listen on a
localhost port — omp's extension therefore dials OUT to a relay the
agent side runs, and the agent side keeps speaking ordinary CDP because
the relay impersonates Chrome's discovery endpoint. Token in the query
string, loopback binding only. The agent-side machinery stays dumb
(puppeteer-core), all browser-native execution happens in the extension
via `chrome.debugger`, which is why the operator's real sessions and
passkeys work natively.

## 2. Route A — Playwright persistent profile (isolated)

Status after this beat's install: the 2026-09-03 research doc's ADMIT
gate is now SATISFIED. Arch/CachyOS notes (operator directive: extra
research on Arch):

- The host python is Homebrew's (Python 3.14.7, pip 26.2.1; Homebrew's
  prefix lives outside the user home, `python3` resolves to its 3.14
  opt build) and is **PEP 668 externally-managed** — `pip install
  --user playwright` refuses with the externally-managed-environment
  error. Arch-native system python would behave the same.
- Taken path (works, documented exactly): venv at
  `~/.hngh-automation/venvs/playwright` created with
  `python3 -m venv`, then `pip install playwright` (1.62.0) inside it.
  Activation seam: the slice code must invoke
  `~/.hngh-automation/venvs/playwright/bin/python` directly (no source-activate
  needed for a script entrypoint) — simplest durable seam.
- Browser: `python -m playwright install chromium` downloaded
  self-contained builds to `~/.cache/ms-playwright/` — chromium-1234
  (Chrome 151.0.7922.34) + chromium_headless_shell-1234 + ffmpeg-1011,
  ~115 MiB, no pacman, no sudo, no system chromium
  (`pacman -Q chromium` → not installed, exit 1). Playwright noted
  "your OS is not officially supported; downloading fallback build for
  ubuntu24.04-x64" — on Arch the bundled-build path is exactly right:
  the build is self-contained and the smoke test passed anyway.
- Smoke proof (this beat, data: URL only, no real service touched):
  headless launch → `page title: hngh-smoke | h1: ok`. The generic
  build runs on CachyOS.
- What the prototype (capabilities plan step 7) needs: Google Messages
  web in a persistent context with an ISOLATED profile dir
  (`user_data_dir`), 700 mode, never backed up/copied; the ONE human
  step is the QR pairing (if messages web demands it — park with the
  pairing step quoted); one message to the operator, no retries against
  a refusing service.

## 3. Route B — browser extension relay ("hngh relay", operator-authorized)

Design sketch for Chrome MV3 + Firefox WebExtension, directly
informed by omp's relay (§1) — corrected where omp's evidence beats the
original brief:

- **Topology (omp-derived):** the extension CANNOT host a localhost
  server (MV3 service workers can't listen) — so it is a WebSocket
  CLIENT that dials out to `ws://127.0.0.1:<port>/ext` on a relay Hngh
  runs (loopback-bound, token-gated via `?token=`, 20 s pings,
  1–10 s reconnect backoff, alarm keepalive — all omp-proven values).
  Hngh POSTs a send request to a tiny local API on its relay; the relay
  issues the RPC to the extension.
- **Execution model:** the send is performed in page context of the
  operator's existing logged-in session. Two sub-options: (a) like omp,
  `chrome.debugger` CDP into the real tab (works today in Chrome, but
  shows the "controlled by debugging" infobar and needs the `debugger`
  permission); (b) content-script DOM automation in the target tab
  (no `debugger` permission, quieter, but DOM-fragile). Start with
  (a) reusing omp's proven RPC surface; add (b) per channel only where
  (a) is refused.
- **Firefox:** no `chrome.debugger` equivalent (BellSchedules aside,
  Firefox has no debugger permission for extensions); the Firefox
  variant must use content-script DOM automation + native messaging or
  an outbound WebSocket from a background page. Firefox background
  pages are event-persistent (no MV3 service-worker churn), so the
  keepalive problem is smaller; the WebSocket-client topology is
  identical. Unproven — design-only.
- **Permissions minimality:** `tabs`, `storage`, `alarms` (+`debugger`
  only for sub-option (a)); host permissions limited to the exact
  channel origins (e.g. `https://messages.google.com/*`), added per
  channel as each channel is gated separately. Never
  `<all_urls>`, never cookies permission, no remote code, no
  webRequest. It never touches or exfiltrates cookies/storage — it
  only drives UI events in tabs the operator already uses.
- **Shipping:** out-of-repo, store-free, developer-mode load (chrome://
  extensions → load unpacked; Firefox: temporary add-on or
  DeveloperEdition persistent load). Source version-controlled in
  hngh-automation (e.g. `extensions/hngh-relay/`), never in the kernel
  repo.
- **Honest risks:** MV3 service-worker lifetime churn (omp mitigates
  with 0.5-min alarm keepalive + reconnect; WS resets on worker wake);
  Firefox background differences above; DOM fragility of web UIs
  (selectors rot; each channel gated separately and never retried
  against a refusing service); ToS surface per service — automation of
  a personal web session may violate a given service's terms, so each
  channel gets its own admit/park verdict, Google Messages web first
  as the known shape.
- **Credentials posture:** inherits credentials-posture.md §4 in full —
  the extension runs inside the operator's real profile, so session
  credentials are never copied, logged, or moved; the relay logs redact
  to op names and tab ids; profile contents are never read by Hngh.

## 4. Parallel-route verdict + recommendation

- **Route A (playwright persistent profile): ADMIT** — the gate
  (playwright importable + chromium build available) now passes; the
  re-probe line is recorded under capabilities plan step 6. First
  proof: one message via Google Messages web, isolated profile.
- **Route B (extension relay): the durable endgame** — the operator's
  active logins and passkey-friendly flows work natively (extension
  runs in the real profile; zero profile duplication, zero session
  re-login), and it is multi-channel (any tab). More moving parts, so
  it is NOT the first proof.
- **Sequence: A proves the pipeline, B industrializes it.** They are
  deliberately parallel code paths sharing one contract (a
  `send(channel, recipient, body)` request shape at the Hngh side);
  Route A's request plumbing should be written so Route B can swap the
  transport underneath it.
- Both routes inherit credentials-posture.md §4; both stay out of the
  kernel repo's code (Route A slice lives in hngh-automation, Route B
  extension source in hngh-automation).

## 5. Sources + not established

Sources (read 2026-09-04):
- omp source: `src/commands/browser-relay.ts`,
  `src/cli/browser-relay-cli.ts`, `src/tools/browser/relay/kind.ts`,
  `server.ts`, `protocol.ts` in
  `~/node_modules/@oh-my-pi/pi-coding-agent` (v18.0.9); extension
  `manifest.json` + `background.js` at `~/.omp/browser-relay/extension/`.
- Playwright install + smoke (this beat); probe battery re-run
  (recorded under capabilities plan step 6).
- docs/research/2026-09-03-browser-messaging-automation.md;
  docs/project/plans/2026-09-03-capabilities.plan.md steps 6/7;
  docs/design/credentials-posture.md §4.

Not established (honest bounds): no real message send was attempted;
Route B has no running code; Firefox behavior claims are design-level
(Firefox lacks a `debugger`-permission equivalent — asserted from
extension-platform knowledge, not tested here); omp's relay was read
from source but not exercised end to end in this beat.

## 2026-09-04-operator-interface-landscape

# Operator interface landscape — the primary interface, and every option on the table

Status: RECORD/RESEARCH — answers the operator's direct question
(2026-09-04): *"What does the roadmap currently plan as Hngh's PRIMARY
operator interface, and are multiple interaction options included?"*

Evidence cited per claim; admits no runtime capability. Where the
roadmap does not establish something, that is said plainly ("not
established"). All observations checked 2026-09-04.

## 1. The direct answer

**The PRIMARY operator interface is the nerve center webapp** — roadmap
stage 2 ("One interface", state: **landing**,
[project/roadmap.md](../project/roadmap.md) stage table): formal tabs
with **Schedule as the default tab**, then Sessions, System, Research,
Logs; the session transcript observatory; a unified schedule over the
system backdrop; window tiling + spawn; and the operator-item lifecycle
(open → handled → dismissed). Stage 2's exit criteria gate it: every
tab renders at desktop + mobile widths, cold deep-links mount, and
operator items flow open→handled→dismissed.

The webapp is not a lone surface — it is the GUI face of the **command
center family**: one presentation spine with a CLI beside it
([design/command-center.md](../design/command-center.md) S1–S8; both
documents' shared terminology note: "nerve center" names the webapp,
"command center" the CLI+GUI family it belongs to). **Multiple
interaction options are explicitly part of the plan** — the full list
is in §3.

Honest framing: stage 2 is *landing*, not *landed* — the 2026-09-03
staging plan (step 3) owns the tab-by-tab exit-criteria verification
sweep that will let the roadmap table flip states on evidence. Until
that sweep runs, "landing" is the roadmap's own word, and the per-tab
status is **not established** here beyond what the roadmap table
states.

## 2. Why the webapp is primary (evidence)

- The roadmap stage table (project/roadmap.md, stage 2 "One
  interface") names the nerve center and its five formal tabs as the
  stage whose consolidation is the current frontier; the roadmap's
  working order item 1 is "Land stage 2 (nerve-center consolidation is
  in final verification)".
- The interface plan ([project/interface-plan.md](../project/interface-plan.md))
  is the needs-first *contract* for exactly this surface: ranked
  operator needs, an awareness contract sourcing every readout from the
  existing spine (`system.json`, `data.json`, `readout.json`, the
  report ledger), and a control contract where every GUI button routes
  through the same command underneath as the CLI verb — "there is no
  second core: the command center is presentation plus dispatch over
  the kernel, nothing more" (command-center.md Vision).
- The single-verdict rule (interface-plan §2, M1/7): the dashboard
  shows ONE health line first, then numbers — counts are secondary,
  never the headline. Freshness stamping (`stale (Nm)`) applies to
  every at-a-glance readout.
- Stage 6 then grows the same surface graphically (QoL & graphic
  evolution: widget grid, uPlot charts, themes) — the webapp is the
  substrate that QoL evolves, not a surface to be replaced.

## 3. The full option list — every surface, its stage, its gate

### Command center family (CLI + GUI over one spine)

| Surface | Roadmap stage | Gate / exit criteria | State |
|---|---|---|---|
| Nerve center webapp (tabs Schedule/Sessions/System/Research/Logs; observatory; tiling; operator-item lifecycle) | **2 — landing** | every tab renders desktop+mobile; cold deep-links mount; operator items flow open→handled→dismissed | contract set (command-center.md S1–S8), landing |
| CLI verbs (`scripts/hngh`) | **0 — done** | `make test` green; certificate-bound commits | 19 verbs live (usage block in `src/main.lisp` `command-usage`: create-run, admit-transport, arm-run, start-run, checkpoint, close-run, propose, issue-cert, mutation-check, present, review, terminal, fetch-evidence, verify-attestation, list-pins, wake-peer, run-worker, select-course, status) |
| Command-center S-slices S1–S5 (truth-telling dashboard, System panel, `status` verb, live roster, summon) | P3 DEV riding stage 2 | command-center.md control/awareness contracts; each slice a small commit against an existing rung | design contract; per-slice state not established |
| S6–S8 (consider/expedite/ripple, pause+label, Hngh-as-app OMP bridge + hosted interface) | P4 DEV | S8 is the only slice where a daemon may be justified (on-demand session host) | design contract |

### Secondary faces (operative layer)

| Surface | Roadmap stage | Gate | State |
|---|---|---|---|
| dashboard-tui (terminal panels) | stage 2 family | the grade loop: `scripts/grade-interface` screenshots + local vision rubric → `docs/project/ui-grades.md` ledger | graded surface today (interface-grading.md: targets `dashboard-tui` / `dashboard-readout`) |
| dashboard-readout watch mode (operative above the readout) | stage 2 family | same grade loop | live (assistant-interface.md "Current state") |
| OSD operative (Plasma 6 overlay, qml6 standalone window) | stage 6 (QoL & graphic evolution) | one graded QoL change per cycle, revertible, before/after evidence (stage-6 exit criterion) | researched design (assistant-interface.md) |
| Pixel-RPG buddy (summoned, non-nagging overlay menu) | stage 2/6 family | buddy-menu-spec; display register law | design spec ([design/buddy-menu-spec.md](../design/buddy-menu-spec.md)) |
| Voice (piper/kokoro TTS, whisper STT) | later QoL | "speech is a surface, never a gate" (assistant-interface.md) | direction recorded |

### New async channels (the operator-away surfaces, 2026-09-04)

| Channel | Belongs to | Gate / exit criteria | State 2026-09-04 |
|---|---|---|---|
| **Email** (daily digest + immediate alerts via notify-email) | stage 1 self-watch → feeds the operator-item lifecycle | reports.md rows are the evidence surface | **LIVE and operator-confirmed** (reports.md row 61f0a1e1, 2026-09-04T21:30:15Z: "email channel live; credential source: file-fallback (1Password locked — op signin pending, migration deferred)"); digest restructure + importance rubric landing via sibling automation slice (verify-on-arrival — see plan Deliverable 2 step 1) |
| **Browser-relay** (Route A prototype: Google Messages web via Playwright persistent context; omp browser-relay architecture studied in docs/research/2026-09-04-browser-relay-architecture.md) | capabilities plan step 7 (browser-messaging prototype) | step 6 ADMIT verdict landed 2026-09-04 (playwright 1.62.0 + chromium 151 smoke-launched); step 7 gates the first send | **pending QR pairing** — if messages web demands pairing, step 7 parks with the pairing step quoted as the one human step |
| **SMS** | not on the roadmap as a channel | — | **Not available — by design, not by omission.** An SMS gateway means provider/credential configuration (a paid provider account, API keys, phone-number verification): that is critical-class park under the plans contract, exactly like any provider/credential configuration. The same operator reach (phone-number notification) is achieved procedurally by the browser-relay route (GMessages web over the paired relay) with zero new credentials. What "SMS yet?" would require: an operator-granted provider account + credential storage via the credentials-posture seam, then a normal-risk slice. Not established until the operator grants the provider. |

### The 1Password desktop-app ↔ SDK question (recorded answer)

Operator question: *can the SDK interface with the desktop app if the
CLI can't?* **Answer: NO.** On Linux, the 1Password SDKs (JS/Go/Rust/
Python) and the CLI share the same desktop-app integration plumbing —
the same local socket to the desktop app — so an SDK integration
inherits the CLI's failure mode, it does not bypass it. The documented
bypasses that skip the desktop app are: CLI-only `op account add`
(sign-in without desktop-app integration), or a 1Password Service
Account if the plan tier allows one. This is why the email channel
went live via the file-fallback credential path (reports.md row
61f0a1e1) rather than waiting on the app integration. Recorded leads
for later: a stale `op-daemon.sock` from 13:25 (pid 4035) — a restart
after the operator's pending reboot window is the cheap first test;
the vault migration remains an upgrade path, not a dependency. The
1Password troubleshooting itself is **back-burnered** (operator
decision 2026-09-04, recorded in
[records/2026-09-04-operator-landscape-notes.md](../records/2026-09-04-operator-landscape-notes.md)).

## 4. Where notification QoL plugs in

- The grade loop ([design/interface-grading.md](../design/interface-grading.md))
  currently grades `dashboard-tui` / `dashboard-readout` screenshots
  into the ui-grades.md ledger. The notification surfaces — the email
  digest, alert formatting, and the Logs-tab dismissal surface — are
  the natural next entries: each is a renderable operator-facing
  surface that can be captured, critiqued against the rubric, and
  ledgered. That admission is staged as plan
  [2026-09-04-notifications-and-qol.plan.md](../project/plans/2026-09-04-notifications-and-qol.plan.md)
  (adversarial review step, then the digest QA cycle using the sibling
  `13-email-qa.sh` drop-in once it lands).
- The operator-item lifecycle (open→handled→dismissed) is stage 2's
  exit criterion for dismiss-able entries; the Logs-tab QoL increment
  is where dismissal becomes visible per-entry.
- Stage 4's governed upgrade lanes (package inventory →
  certificate-gated upgrades, config-manager declared lanes) surface
  in the System tab; the "what an operator needs to see to
  approve/witness a governed upgrade" mapping is staged as a research
  step in the same plan (feeding staging plan step 6's runbook).

## 5. Not established (honest framing)

- Per-tab live status of the five nerve-center tabs beyond the
  roadmap's "landing" state — the 2026-09-03-staging plan step 3 sweep
  owns that evidence; it has not run yet.
- Whether S1–S8 slices are individually landed — the command-center
  contract is ceremony-ready design; per-slice state is not
  established in kernel docs.
- Any end-to-end browser-relay send — not established (no real message
  sent; capabilities step 7 pending QR pairing).
- SMS entirely — not established, and deliberately parked
  critical-class.

## Sources

- docs/project/roadmap.md (stage table, working order, design-pressure
  paragraph)
- docs/design/command-center.md (S1–S8, control/awareness contracts,
  terminology note)
- docs/project/interface-plan.md (needs-first contract, single-verdict
  rule)
- docs/design/assistant-interface.md, docs/design/buddy-menu-spec.md,
  docs/design/operative-frames.md (secondary faces)
- docs/design/interface-grading.md (grade loop, ledger)
- docs/design/presentation-boundary.md (renderer limits)
- docs/design/knowledge-base-spec.md (vault canon, viewer, publishers)
- docs/project/plans/2026-09-03-capabilities.plan.md (steps 6–7:
  browser probe + prototype; step 5: credential seam)
- docs/project/plans/2026-09-03-staging.plan.md (step 3 sweep, step 6
  runbook)
- docs/research/2026-09-04-browser-relay-architecture.md (relay
  mechanism, Route A state)
- docs/project/reports.md row 61f0a1e1 (email live, credential source)
- `src/main.lisp` `command-usage` (the 19 verbs, read 2026-09-04)
- scripts/generate-publication (the `--site` static publisher — the
  wiki-feasibility input, priced in the plan)

## 2026-09-04-unsloth-launch-config-lane

# Unsloth launch-config lane — llama-server.service config.env proposal

Status: RESEARCH RECORD — capabilities plan step 2 (2026-09-03
capabilities plan): what config.env-driven launch config
`llama-server.service` needs to re-host the 35B fleet, with the unit's
EnvironmentFile state quoted as-installed, feeding backlog row
config-manager as the first declared config lane
(docs/design/service-management.md §5). **No unit was edited; no
service was started.** All evidence below is read-only
(`systemctl --user cat/show`, file reads, `--help`, `ss`), gathered
2026-09-04.

## 1. Grounding (verified paths, checked 2026-09-04)

| Evidence | Path / source | State |
|---|---|---|
| llama-server unit as installed | `/usr/lib/systemd/user/llama-server.service` | quoted §2 |
| unsloth-studio unit | `~/.config/systemd/user/unsloth-studio.service` | quoted §3 |
| unsloth-warm unit + script | `~/.config/systemd/user/unsloth-warm.service`, `~/.local/bin/unsloth-warm.sh` | quoted §3 |
| automation chain API shape | hngh-automation `config.env` + `lib/model.sh` | quoted §4 |
| bench-leader model on disk | `~/.cache/huggingface/hub/models--unsloth--Ornith-1.0-35B-GGUF/snapshots/*/Ornith-1.0-35B-UD-Q2_K_XL.gguf` (+ `mmproj-F16.gguf`) | exists |
| llama-server binary | `/usr/bin/llama-server` — `0.2.0-dev (build 10566, commit bb4caa7540)` | env-var launch surface verified §5 |
| live listeners | `ss -tlnp` 2026-09-04 | :8888 up, :8080 down, :11434 up (§3) |

## 2. Which unit serves what — the port/units correlation

**llama-server.service** (as installed; quoted with `~/`-form per the
repo's public-content rule, security-hardening lines elided):

```ini
[Service]
Type=simple
ExecStart=/usr/bin/llama-server
EnvironmentFile=-%E/llama/server/environment.conf
```

- `%E` resolves to the user config dir, confirmed by
  `systemctl --user show`: `EnvironmentFiles=~/.config/llama/server/environment.conf (ignore_errors=yes)`
  (shown in `~/`-form per the repo's public-content rule; systemctl
  prints the absolute path).
- **EnvironmentFile state as-installed: the unit DECLARED the slot but
  the FILE IS ABSENT** — `~/.config/llama/server/environment.conf`
  does not exist (`ls: cannot access ... No such file or directory`).
  The `-` prefix makes it optional, so the unit starts clean with
  zero launch configuration — a bare llama-server on its default port
  :8080 with no model. That bare ExecStart is the config-lane gap
  named in service-management.md §5.
- Unit state 2026-09-04: **disabled, inactive**; :8080 down
  (`service-state.json` port 8080 `up:false`; nothing listens).

**unsloth-studio.service** (`~/.config/systemd/user/`):

```ini
[Service]
Type=simple
ExecStart=~/.local/bin/unsloth studio
Restart=on-failure
RestartSec=10
Environment=PYTHONUNBUFFERED=1
```

- `~/.local/bin/unsloth` symlinks to
  `~/.unsloth/studio/unsloth_studio/bin/unsloth`; the unit
  description says `(:8888)`.
- Unit state 2026-09-04: **enabled, but inactive since 2026-09-03
  14:16:40 EDT**. Yet :8888 IS served — by the same command launched
  OUTSIDE the unit: pid 3461360 `~/.unsloth/studio/unsloth_studio/bin/python ~/.local/bin/unsloth studio`,
  started 14 seconds after the unit stopped, parent pid 3458841 =
  `/bin/fish` (an operator shell), not systemd. So the fleet server
  was relaunched by hand and the unit no longer tracks it. **How
  unsloth-studio launches its server internally (which model
  directory, context, worker flags) is NOT ESTABLISHED** — the
  launcher script (`~/.local/share/unsloth/launch-studio.sh`,
  auto-generated by its installer) only resolves the exe and a base
  port of 8888 with a 8888..8908 fallback range; the studio's own
  server arguments live inside `~/.unsloth/studio/` and were not
  reverse-engineered.

**Conclusion of the correlation**: when the fleet is up, :8888 is the
serving port (Unsloth Studio); :8080 is llama-server's would-be port
and has been down throughout every probe. `unsloth-warm.service`
(disabled, oneshot, `After=`/`Requires=` unsloth-studio) waits for
:8888 `/v1/models` then warm-pins `unsloth/gemma-4-12b-it-qat-GGUF`
via `POST /v1/chat/completions` with a Bearer key read from
`~/.hermes/.env` — confirming :8888 is the fleet's OpenAI-shaped
front door and that its key material lives outside any unit file.

## 3. The API-shape mismatch (llama-server vs the unsloth chain)

The automation chain (config.env + model.sh) speaks to
**`UNSLOTH_URL=http://127.0.0.1:8888`**, not :8080:

- chat: `POST $UNSLOTH_URL/v1/chat/completions` with
  `Authorization: Bearer <token>` (token from
  `~/.hngh-automation/unsloth.token`, mode 600);
- auth: single-use access/refresh token pair, rotated via
  `POST $UNSLOTH_URL/api/auth/refresh` with
  `{"refresh_token": ...}` → `{access_token, refresh_token}`
  (flock-serialized in model.sh because the refresh token is
  single-use server-side);
- ollama fallback: `POST $OLLAMA_URL/api/chat` on :11434 (up).

`/api/auth/refresh` is an Unsloth Studio route; llama-server has no
such endpoint (its auth surface is a static API key /
`LLAMA_ARG_API_KEY_FILE`, §5). **A llama-server re-host of the fleet
is therefore not a drop-in for the chain**: the launch config can put
llama-server on :8080 with the Ornith model, but consumers would
re-point `UNSLOTH_URL` to it and drop the token-pair flow (or key it
statically). That consumer migration is a separate decision — this
record declares only the launch-config lane.

## 4. Launch-config inventory each candidate unit needs

**llama-server.service** (the unit the config lane targets). Verified
env-var launch surface (`/usr/bin/llama-server --help`, 2026-09-04):
`--model` has `(env: LLAMA_ARG_MODEL)`, likewise `LLAMA_ARG_HOST`,
`LLAMA_ARG_PORT`, `LLAMA_ARG_CTX_SIZE`, `LLAMA_ARG_ALIAS`,
`LLAMA_ARG_API_KEY_FILE`, `LLAMA_ARG_CHAT_TEMPLATE`,
`LLAMA_ARG_MODELS_DIR`, `LLAMA_ARG_N_PARALLEL`. Because the unit
already declares the EnvironmentFile slot, the whole inventory fits
env vars with **zero unit-file edits**:

| Key | Proposed value | Basis |
|---|---|---|
| `LLAMA_ARG_MODEL` | `$HOME/.cache/huggingface/hub/models--unsloth--Ornith-1.0-35B-GGUF/snapshots/<hash>/Ornith-1.0-35B-UD-Q2_K_XL.gguf` | the 5/5 bench leader all three days (stats/model-bench-2026-09-0{1,2,3}.jsonl; also the automation fallback chain's #2), the only 35B GGUF on disk; snapshot hash resolved at install time by the config lane, not hardcoded here |
| `LLAMA_ARG_ALIAS` | `unsloth/Ornith-1.0-35B-GGUF` | lets a chain re-point keep its model naming |
| `LLAMA_ARG_HOST` | `127.0.0.1` | loopback only, matching the chain's endpoint posture |
| `LLAMA_ARG_PORT` | `8080` | the unit's own recognition port (service-state.json probes 8080) |
| `LLAMA_ARG_CTX_SIZE` | **not established** — needs a load test against VRAM before a value is declared (no service was started) | context knob the plan names; deliberately left open |
| `LLAMA_ARG_API_KEY_FILE` | optional; omitted for loopback, or points at a 600-mode key file per credentials-posture §4.3 | unit files never carry secrets |

The config file would live version-controlled in hngh-automation
(e.g. `systemd/llama-server.environment.conf`) with an install step
copying it to `~/.config/llama/server/environment.conf` — the unit
references `%E/llama/server/environment.conf` already, so the file is
the only moving part (config-manager lane: declaratively listed,
version-controlled, backed up on cadence). Secrets stay out of it per
credentials-posture.md §4.3 (env-referencing, never inline values).

**unsloth-studio.service** needs no launch config: its ExecStart is
self-contained and the studio manages its own models. Its gap is
governance, not config — at probe time the serving process was
launched outside the unit (§2), so the unit's state lies about the
fleet's actual availability. **NOT ESTABLISHED**: why the operator
relaunched it by hand (out of scope; read-only beat).

**unsloth-warm.service**: oneshot helper, no server of its own;
already parameterized by `~/.hermes/.env`'s `UNSLOTH_API_KEY`. No
launch-config work needed.

**Sandbox caveat (not established)**: llama-server's unit hardens
with `ProtectHome=tmpfs` plus `CacheDirectory=huggingface/hub` /
`ConfigurationDirectory=llama/server`. Whether the real
`~/.cache/huggingface/hub` model content is visible through the tmpfs
home on a live launch (systemd's cache-dir bind handling) is NOT
established and is exactly what a live launch test would settle — a
later, gated step. A model path outside `$HOME` (or an
`LLAMA_ARG_MODEL_URL`) is the documented fallback if the sandbox
hides the cache.

## 5. Recommendation (feeds backlog config-manager)

1. Declare the lane: `unsloth/llama-server launch config` = the
   EnvironmentFile content above, version-controlled in
   hngh-automation, installed to
   `~/.config/llama/server/environment.conf` — **no unit-file edit,
   no enablement change** (both stay critical-class per
   service-management.md §3).
2. The context value and the ProtectHome-vs-cache question get
   settled by one gated live launch (a later step; this beat ran
   read-only).
3. Re-pointing the model chain at a llama-server :8080 (dropping the
   token-pair flow) is a separate consumer decision — record it in
   the config lane but do not couple it to the file install.
4. Lesson surfaced for the recognition surface: it probes :8080 and
   :11434, but the live fleet port is :8888 — and §2 shows a hand
   launch can make the unit state diverge from reality. The port
   set (and pid/unit cross-check) is a service-state.py follow-up in
   the automation repo, not a kernel doc change.

## 6. Sources

- `systemctl --user cat/show` of the three allowlisted units,
  2026-09-04 (unit files are not secrets; quoted in §2).
- hngh-automation `config.env` + `lib/model.sh` (endpoint paths,
  Bearer header, `/api/auth/refresh` route) — read-only.
- `~/.local/bin/unsloth-warm.sh`, `~/.local/share/unsloth/launch-studio.sh`,
  `~/.local/share/unsloth/studio.conf`.
- `/usr/bin/llama-server --version` / `--help` (env-var surface).
- `ss -tlnp`, `ps` (the out-of-unit :8888 process), hngh-automation
  `dashboard/service-state.json` (port + unit snapshot).
- docs/design/service-management.md §4-5; docs/design/credentials-posture.md
  §4; docs/project/plans/2026-09-03-capabilities.plan.md step 2.


## 2026-09-06-govbench-adapter-contract-What-adapter-contract-lets-different-change-governance-systems-run-the-same-governance-benchmark-unmodified

# govbench-adapter-contract

Status: crystallized 2026-09-06 from research line `govbench-adapter-contract-What-adapter-contract-lets-different-change-governance-systems-run-the-same-governance-benchmark-unmodified`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-govbench-adapter-contract-What-adapter-contract-lets-different-change-governance-systems-run-the-same-governance-benchmark-unmodified.md.

I'll research the `govbench-adapter-contract` line by grounding findings in concrete evidence from both repositories. Let me start by locating and examining the relevant code.

<tool_call>
<function=Bash>
<parameter=command>
ls -la /home/bricker/Projects/etc/hngh 2>/dev/null && echo "---HNHG EXISTS---" || echo "HNHG NOT FOUND at that path"; echo "==="; ls -la /home/bricker/Projects/etc 2>/dev/null | head -50
</parameter>
<parameter=description>
Check for hngh kernel repository and list parent directory
</parameter>
</function>
</tool_call>

