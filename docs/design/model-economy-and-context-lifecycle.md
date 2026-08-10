# Model economy and context lifecycle

Status: DESIGN — operator policy, 2026-08-10.
Cross-links: `model-routing.md`, `quota-spreader.md`,
`k3-bounded-completions.md`, `prompt-matrix.md`, `watcher-layer.md`.

## Decision

Hngh routes the broad majority of work to local models or remote routes priced
at **$0.20/M input tokens or less**. A remote route above that threshold is a
strategic reserve regardless of its output price, provider, name, or apparent
subscription marginal cost. UNKNOWN price is reserve. No reserve route appears
in an automatic fallback chain.

Sol's approximately $15 session and K3's measured 72.97% 5-hour drawdown are
not routine-work costs. They are evidence that broad session context, long
system prompts, large tool surfaces, and many-turn continuation must be
controlled before a model call—not rationalized afterward.

## Observed baseline

The operator-visible monitor screenshot at 2026-08-10 13:36 showed a fresh
Cibo/Luna session at **72.6K context** after only two minutes. Its startup
surface reported 48 tools, 74 skills, and 4 MCP servers. Browser/media/voice/
GUI toolsets had already been disabled, so the remaining cost is chiefly base
instruction assembly, skill catalog exposure, and MCP schemas. This is an
evidence point, not an estimate: card 130 inventories it and card 132 adds a
component ledger before any further pruning claims.

## Route classes

| Class | Admission | Examples | Automatic fallback |
|---|---|---|---|
| `:local` | available capacity | Unsloth/Ollama models | yes |
| `:workhorse` | ordinary task and budget envelope | Flash, Luna when price is <= $0.20/M input | yes, after local/route preference |
| `:reserve` | explicit admission record only | K3, Sol, Terra, GLM/MiMo/MiniMax/Gemini when price exceeds threshold, all UNKNOWN-price routes | never |

A catalog record is data, not prose:

```lisp
(:route :name :provider :model
 :input-usd-per-million <number-or-:unknown>
 :billing-pool <keyword> :class <keyword>
 :context-window <integer-or-:unknown>
 :observed-at <timestamp>)
```

Changing price, provider, or model invalidates the observation. A stale or
missing observation yields `:reserve`.

## Reserve admission

Reserve admission returns `:allow` or `:refuse`, never an implicit fallback.
The request record must contain:

```lisp
(:request-id :route :authority-class :packet-fingerprint
 :input-estimate :output-cap :five-hour :seven-day :thirty-day
 :reservation-id :evidence-path :decision :reason :timestamp)
```

`authority-class` is a named situation such as `:sanity-review`,
`:code-final-review`, `:plan-veto`, or `:design-authority`. The packet is
one-turn and no-tools by default. It contains only the task decision, current
state summary, named source excerpts, and acceptance question. No transcript
replay, broad system prompt, or tool schemas are attached.

Quota truth must be authoritative and coupled. Card 128 supplies the five-hour
bucket, amount-aware projection, ledger rollup, reservation, post-call actual
reconciliation, and overage refusal before card 127 can consume the predicate.
The configured cap is UNKNOWN until provider observation/config supplies it;
UNKNOWN refuses automatically.

## Context lifecycle

A model window is a physical maximum, not a working target. Every continual
agent owns a small context budget relative to its configured window.

| Stage | Window fraction | Procedural action |
|---|---:|---|
| `:observe` | <12% | record component ledger only |
| `:warn` | >=12% | compose compact handoff at next phase boundary |
| `:compact` | >=18% | summarize and respawn before accepting unrelated work |
| `:refuse-continuation` | >=25% | reject new work unless an explicit continuation gate names why the old transcript is indispensable |

The immediate Hermes configuration mirrors the compact stage: compression at
18%, 10% target ratio, 8 recent and 3 opening messages protected, 120-message
hygiene cap, and 80 maximum turns. These are operational guardrails, not
provider facts; Hngh must measure outcomes and tune them conservatively.

The component ledger has no model in its hot path:

```lisp
(:session-id :route :observed-at
 :system-prompt-estimate :tool-schema-estimate :skills-estimate
 :memory-estimate :task-packet-estimate :transcript-estimate
 :total-estimate :window :stage :action :handoff-path)
```

A deterministic estimator is sufficient initially: stable byte/word estimate,
component sizes, and deltas. Exact tokenizer support may replace it later but
must not block refusal or compaction.

## Compact handoff and fresh launch

A handoff is the sole bridge across a context reset:

```markdown
# HANDOFF-<seat>
route: <actual provider/model>
context-stage: <observe|warn|compact|refuse-continuation>
task: <card and one-sentence state>
write-boundary: <exact files>
evidence: <tests/artifacts>
next-action: <one action>
blocker: <none or precise gate>
```

A fresh seat receives only its task card, this handoff, current claim/budget
state, and named source excerpts. It does not inherit a whole old transcript,
all historical lanes, or irrelevant tool definitions.

## Prompt and capability profiles

Prompt assembly remains Skeleton–Bones–Flesh, but every component must declare
why it is present, its estimate, a maximum, and an omission fallback.

| Profile | Enabled surfaces | Forbidden by default |
|---|---|---|
| `hngh-worker` | terminal, file, code execution, narrow web, skills, memory, session search, delegation/cron when task requires | browser, media, voice, GUI, unrelated MCP |
| `research` | worker + web extraction | mutation tools and broad media |
| `operator-ui` | worker + computer use/browser only for named UI task | automatic remote vision/media |
| `media` | explicit operator task only | all normal Hngh work |

Disabled toolsets and MCPs must not load their schemas into the profile. The
runtime controls profile selection at launch; it does not rely on agents to
ignore unused affordances. On 2026-08-10 the active Hermes config removed
Blender, Unreal Engine, and NotHumanSearch MCPs; only Hngh, MisakaNet, and
DepScope remain pending profile audit. OpenCode likewise retains only MisakaNet
after its unfiltered DepScope and NotHumanSearch MCPs were removed.

## Measured Hermes profiles

`hermes prompt-size` is the fixed-prompt acceptance probe; it runs offline.
Measurements on 2026-08-10:

| Profile | Fixed system | Tool schemas | Skills | Route |
|---|---:|---:|---:|---|
| `default` | 29.3 KB | 63.7 KB / 37 tools | 93 indexed | workhorse/coder |
| `hngh-lean` | 29.6 KB | 45.5 KB / 18 tools | 93 indexed | coordination/review |
| `hngh-minimal` | 7.1 KB | 13.3 KB / 7 tools | 0 | local procedural only |

`hngh-minimal` is configured to Unsloth Gemma 4 12B with no remote fallback;
its enabled surfaces are terminal, file, and code execution. Its fixed prompt
is about 20.4 KB, roughly 78% below the default fixed prompt. It is the
baseline for local sweeps, procedural classification, and fixture benchmarks.
It must not be used for tasks requiring retained skills, web research, or
operator interaction.

## Accuracy and situation routines

The default path is procedural:

1. compare a claim with its named evidence path, test output, pane state, or
   source probe;
2. classify context stage and no-progress/idle state from timestamps, claims,
   lane movement, and process state;
3. reserve and reconcile model calls against the ledger;
4. write a redacted event with evidence and action;
5. use a local judge only when deterministic classifiers produce `:ambiguous`.

No routine claims an agent is working from a single busy frame. No routine
retries a failed delivery as though it were delivered. A situation event is
append-only and feeds watcher, dashboard, and future optimizer from one source.

## Hot-swappable adapters

Hngh owns a narrow `model-control` contract; Hermes and OpenCode are adapters,
not reimplemented clients:

```text
catalog -> classify -> estimate -> admit/refuse -> launch packet
        -> observe actuals -> reconcile -> situation journal
```

Adapters must support: route selection, profile selection, packet injection,
context observation, compact-handoff request, and actual-usage receipt. Missing
adapter evidence fails closed for reserve calls and degrades workhorse calls to
the configured local/cheap route.

## Benchmark discipline

Context/profile tuning is a local or cheap-model research task only. Fixtures
supply fixed task packets and scored outputs. Compare one parameter at a time:
profile, context budget, handoff shape, compression threshold, or tool surface.
Record quality, completion, retries, latency, and estimated input. Do not run
paid comparative trials by default; promotion requires a meaningful measured
benefit and a bounded cost record.

## Ordered delivery

1. Card 128: quota truth.
2. Card 127: planner use of the hardened gate, default refuse.
3. Card 131: replace Sentry's fixed 256K-only context watch with the component
   ledger and lifecycle events.
4. Card 132: prompt-matrix component budgets and compact-handoff generator.
5. Card 130: audit minimal Hermes/OpenCode surface; then apply named profiles
   and remove non-purposeful MCP servers.
6. Card 133: model-control adapter contract plus Hermes/OpenCode launch seams.
7. Card 134: fixture-first, local/cheap context/profile benchmark runner.

No autonomous reserve escalation, paid benchmark fan-out, or permanent shell
watcher feature is part of this design.
