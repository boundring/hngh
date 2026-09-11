# Passthrough readiness and quota interleaving analysis

Date: 2026-09-10. Scope: read-only research; this file is the only artifact.
Question: can omp agent sessions delegate model calls through hngh's legs
(hngh-passthrough), and how should quota'd model intelligence be interleaved
across hngh's cycle and its omp sessions?

Evidence bases: automation/stats/model-bench-2026-09-0{9,10}.jsonl,
digest/BENCH-*, digest/RESEARCH-BEAT-* (wall_s headers),
docs/research/2026-09-10-{quota-utilization,cost-landscape,
lobehub-api-research,bili-lobehub-integration}.md, docs/records/
2026-09-10-automation-ci-and-probe-hygiene.md, automation/lib/model.sh,
model-demote.sh, failfirst.sh, scripts/overnight-cycle.sh,
lib/launch-session.sh, cadence-params.tsv, telemetry.db (queried 2026-09-10).
No live paid-API probes were run; bench and existing logs only.

## 0. Instrumentation state (read this before any latency number)

The telemetry `events` table has a `wall_s` column, but `_model_emit`
(automation/lib/model.sh:398-402) never populates it: ALL kind=model rows
(70 unsloth, 29 kimi, zero everything else) have wall_s NULL, and no
tokens_in/tokens_out either. The only per-call latency that exists today is
baked into research-beat digest headers
(automation/cadence/hour/33-research-beat.sh:545-561, `date +%s` around one
model_call). Every wall number below comes from those digest headers or from
manual bounded probes recorded in the research docs. This is the single
cheapest instrumentation gap to close before any passthrough design.

## 1. Timing ledger assessment, per leg

### 1.1 Local bench (desktop unsloth)

- Quality: 7 models x 5 probes on both days (model-bench-*.jsonl). Best
  2026-09-10: bartowski/Qwen3.8-27B-GGUF 5/5; 09-09 best: Ornith-1.0-35B 5/5
  (and that same model later demoted after 9 consecutive bad-execution
  sessions -- automation/lib/model-demote.sh header). Scores are NOT stable
  day to day (unsloth Qwen3.8 4->3, Ornith-35B 5->4 across the two runs);
  the 5/5-gate in select_model (overnight-cycle.sh:160-185, <24h freshness)
  is doing real work.
- Latency: no telemetry wall_s. Digest samples for unsloth/Qwen3.8-27B
  research-beat calls (4096-token budget): 264, 264, 316, 335, 361 s
  (n=5, 09-08/09-09). Bench JSONL timestamps show ~25-35 s per model for
  5 tiny probes (~5-7 s each). Timeout budget: MODEL_TIMEOUT=300 s
  (automation/config.env:21, "first call after model swap can load 1-3 min").
- Staleness: fresh (bench runs daily 01:10, though benchmarking is
  back-burnered per cadence row benchmarking-backburner=1).
- Verdict: READY for passthrough routing -- free, demotion-gated, and the
  only leg with both a formal quality bench and an enforced timeout. But
  264-361 s wall for full-size prompts means it suits async beats, not
  interactive omp turns. Missing measurement: per-call wall_s percentiles
  (the 5 digest samples are one prompt shape).

### 1.2 Deck (deck-7b, llama.cpp/vulkan over tailscale)

- Latency: digest wall_s samples deck:deck-7b: 64, 68, 72, 75, 76 s
  (n=5, spread over 09-08 and 09-10 -- tight variance). Availability probe:
  failfirst.sh deck_up /health with a 4 s budget (cadence row
  deck-probe-timeout=4).
- Quality: no formal bench -- the bench harness scores unsloth models only;
  deck-7b has never been scored. Evidence of competence is indirect (the
  five deck-served research beats all crystallized).
- Staleness: endpoint moved 2026-09-07 (cadence row provenance A2);
  responding as of the 09-10 beat. Zero telemetry rows BY DESIGN
  (model.sh:416-418: overflow-only, rows would skew the saturation
  instrument) -- so utilization is invisible; only digests record use.
- Verdict: READY for bounded overflow routing. Missing measurement: one
  5-probe bench of deck-7b itself (cheapest probe: point the existing
  jobs/model-bench.sh harness at the deck endpoint once).

### 1.3 Kimi (K3 quota leg, api.kimi.com/coding)

- Success data: 29 telemetry rows 09-08..09-10 (telemetry.db query), incl.
  3 on 09-10 after the key correction. The leg works through model.sh's own
  path -- it has emitted kind=model rows on every share-pinned success.
- Latency: digest samples kimi:k3-256k: 71 s and 78 s (n=2). Thin but
  consistent, and bounded prompts only.
- Behavior notes that a passthrough caller inherits (model.sh:291-307):
  burst throttle -> single spaced calls; no temperature field accepted;
  thinking-only models spend reasoning tokens INSIDE max_tokens, so small
  budgets return empty content (>=64 needed for trivial completions).
  Spend guard: kimi-daily-cap=40 + quota_pace_blocked soft pacing
  (model.sh:265-289).
- History that matters: the leg read dead for five days because the health
  probe was unauthenticated (probe-hygiene record; fixed 75ce22c2) -- the
  credential was never the problem.
- Verdict: READY for bounded passthrough. Missing measurement: n=2 latency
  is anecdote; the kimi-share rotation will grow it for free. Add wall_s to
  _model_emit and the ledger fills itself.

### 1.4 LobeHub (Responses-API quota leg)

- In-pipeline success data: ZERO. No kind=model source=lobehub row has ever
  been emitted (telemetry.db: first row per source shows no lobehub entry
  at all). The lobehub-research-share=6 rotation has been firing, and the
  leg has never once completed inside the automation -- it fails silently
  (quota-utilization doc) without a telemetry row.
- Manual-probe data: post-prompt-slim bounded POSTs return 200 `completed`
  in 15-20 s (lobehub-api-research, "Prompt-slim outcome" section); the
  pre-slim 24 s+ calls hit Cloudflare 524s; the historical 524s traced to
  unbounded output, not prompt size alone. Platform-owned 24.6k input-token
  floor per call.
- A passthrough caller also needs: bounded max_output_tokens (else 524 at
  the 30 s Cloudflare edge), the single-agent constraint (model field takes
  agent id agt_6sB8IcJhaTg6, not a model name), and 24.6k input tokens of
  GLM quota burned per call regardless of prompt size.
- Verdict: NOT YET. The 15-20 s number is real but was measured by hand,
  never by the automation. Missing measurement: ONE successful
  MODEL_PIN=lobehub model_call in the automation path, producing the first
  telemetry row (wall time recorded). That is a paid call, so it waits for
  operator authorization -- but it is the single highest-leverage probe in
  this document.

### 1.5 OpenCode Go T2 (opencode.ai/zen/go, GLM)

- Evidence: exactly one bounded POST returning 200-completed
  (lobehub-api-research section 1, hngh-agent b367b0c/2bc5da8). No wall
  time recorded. The provider is omp-native today: models-store.json has an
  `opencode-go` entry (glm-5.1/5.2/5.3 and others, base
  opencode.ai/zen/go/v1) and Pi already routes GLM through it.
- There is NO hngh leg: the model.sh chain is unsloth -> remote -> ollama
  -> deck -> kimi -> lobehub -> archive-only; opencode-go appears nowhere.
  No telemetry source, no cap row, no pacing.
- Reset structure (lobehub-api-research section 4): 5-hour/$12, 7-day/$30,
  monthly/$60 per model. quota_pace_blocked paces against a DAILY cap
  divided across 86400 s -- it has no concept of a 5-hour bucket, so it
  does not transfer to this leg without a new pacing mode.
- Verdict: NOT YET as an hngh leg, and passthrough is arguably the wrong
  shape for it (omp already consumes it directly -- see section 2).

### 1.6 Remote OpenRouter (paid fallback leg)

- Session-level evidence is strong: session-cost telemetry shows 24-32
  z-ai/glm-5.3-flash sessions/day (09-09/09-10, ~$1.00-1.15/day), so the
  endpoint and key demonstrably work at volume. Per-CALL latency is not
  measured anywhere (session-cost.py parses cost, not wall time).
- The in-model.sh remote_chat leg has zero telemetry rows ever -- the paid
  fallback inside model_call has simply never been reached (pins skip it;
  delegated sessions bypass model_call entirely and run `omp -p --model
  zai/glm-5.3` via env).
- Verdict: READY as the omp-native session model it already is. The
  model.sh remote leg needs no passthrough work; it is the rung BELOW
  everything else.

### 1.7 What a passthrough caller needs beyond latency

Any delegation surface inherits the legs' fail-closed contract and budgets:
- Fail-closed-skip: a pinned quota leg that misses (pace-block, 429, down)
  falls through to the local chain; research never blocks on quota state
  (model.sh header). A passthrough tool must preserve this -- return a
  structured miss, never hang.
- Timeout budgets: MODEL_TIMEOUT=300 s global; deck probe 4 s; LobeHub's
  effective budget is Cloudflare's ~30 s edge, which bounded output
  currently satisfies at 15-20 s.
- Output-token behavior: kimi reasoning-inside-max_tokens; LobeHub 524 on
  unbounded output; unsloth's empty-content retry at budget x8 with
  thinking disabled (model.sh:134-199).

## 2. Passthrough design sketch

Three candidate shapes, assessed against the measured latencies.

### (a) omp spawns an hngh CLI summarization/model verb

A `hngh model-call` verb (or a summarization verb on the existing CLI) that
sources model.sh and runs model_call. Latency = leg latency plus CLI spawn
(~0 s). Quota attribution is perfect: _model_emit fires with the caller's
subject, caps and pacing apply unchanged. But it adds a mutating-lane
surface (scripts/) to a repo where the CLI is ceremony-gated, and omp
sessions calling a mutating-lane binary inverts the dependency the
integration plan fixed (2026-09-09-omp-hngh-integration.plan.md: hngh
exposes READ-ONLY surfaces to omp; the kernel never knows omp exists).
Reject as the primary shape.

### (b) MCP tool wrapping model.sh legs, read-only

The hngh MCP server already exists and is registered for omp
(automation/mcp/hngh_mcp_server.py; commits ce7e072/f9b1360; four tools:
present/status/queue_report/dashboard_readout). Adding one more tool --
`hngh_model_call(prompt, max_tokens)` wrapping model_call with a FIXED pin
order -- is an automation-lane change (where omp-facing code belongs per the
integration plan's architecture constraint), keeps quota attribution exact
(telemetry kind=model with the tool subject), and reuses caps, pacing,
health gating, and demotion with zero new mechanisms. Latency = leg latency
(kimi 71-78 s, lobehub 15-20 s once proven, deck 64-76 s) plus stdio spawn.
Concurrency hazard: two omp subagents calling at once double-spend against
the same daily caps; quota_pace_blocked is per-call so it bounds this, but
the tool should serialize or document the race. Governance boundary: the
tool must NOT accept MODEL_PIN from the caller (omp does not choose legs;
the ladder does) and must never touch provider/credential config
(risk=critical per the overnight autonomy rule).

### (c) omp provider pointing at a local hngh proxy

An OpenAI-compatible local proxy that omp registers as a provider entry.
Reject: it is a long-running daemon (systemd lifecycle = critical-class),
it duplicates every cap/pacing/health mechanism model.sh already owns, and
its attribution is weakest (a proxy source obliterates which leg served).
The MCP tool is strictly smaller and better-attributed.

### Recommendation

NOT YET, with a stated condition. omp sessions already have direct native
access to both paid surfaces they actually use (openrouter glm-5.3-flash
env; opencode-go provider entry), so passthrough today would add governance
on top of legs that are 1/6 proven in-pipeline (kimi only). The lazy path:
(1) close the instrumentation gap (wall_s in _model_emit), (2) land the one
in-pipeline lobehub probe, (3) then implement shape (b) as one MCP tool
with fixed pinning -- it is a single automation-lane file edit against an
existing server, and the 2026-09-09 integration plan step 3's omp-bridge
work is a better home for nothing else; the MCP tool is the whole shape.

## 3. Interleaving model (policy table)

Reset windows in force: kimi/lobehub daily caps pace across the UTC day
(quota_pace_blocked, model.sh:265-289); opencode-go resets 5h/$12,
7d/$30, monthly/$60 per model (lobehub-api-research section 4); openrouter
is per-token with REMOTE_DAILY_CAP_CALLS. Operator-away window:
Wed 22:00Z-Thu 02:05Z (cadence row operator-away-windows).

| # | Session class | Window state | Preferred leg | Fallback | Status in code |
|---|---|---|---|---|---|
| 1 | Mechanical work (T1: news, digest, ping summarization) | any | local unsloth bench-ranked | ollama -> deck | IMPLEMENTED: unpinned chain + demotion filter (model-demote.sh) |
| 2 | Research beat, intelligence-shaped | UTC day, kimi cap 40 | MODEL_PIN=kimi on 1/3 runs (kimi-research-share=3), paced | local chain | IMPLEMENTED: 33-research-beat.sh:438-448 |
| 3 | Research beat | UTC day, lobehub cap 50 | MODEL_PIN=lobehub on 1/6 runs (share=6) | local chain | CONFIG yes, LEG UNPROVEN: 0 telemetry rows ever -- gap is proof, not code |
| 4 | Research beat, busy local (load > 0.7) | any | deck pin (deck_up) or quota pin | never defers | IMPLEMENTED: research-load-ceiling routing (33-research-beat.sh:433-437) |
| 5 | Overnight delegated session (T2 class) | 5h bucket fresh | session-model-preference quota rung in select_model | env glm-5.3-flash | IMPLEMENTED but OFF: requires session-model-quota-keys=1 + preference row (overnight-cycle.sh:139-158); unset = env leg. Gap: no omp-addressable preference named yet |
| 6 | Overnight delegated session | 5h depleted / quota demoted | local-bench 5/5 <24h | paid glm-5.3, then archive | IMPLEMENTED (select_model:160-199) |
| 7 | Operator omp sessions | 5h bucket fresh | opencode-go glm-5.3 (fixed $10/mo, $60/model allowance) | openrouter glm-5.3-flash | NOT hngh's to implement: operator-side provider choice; omp already holds both entries |
| 8 | omp subagent fan-out | any | free local (unsloth) or opencode-go | parent provider | GAP: subagents inherit the parent provider; no surface routes them -- this is exactly what shape (b) would serve |
| 9 | Any paid session | operator-away window (Wed 22:00Z-Thu 02:05Z) | local-only; park paid spawns | queue alerts | GAP: row exists, consumer 34-operator-presence-check.sh not built; nothing gates model choice on it |
| 10 | Bench/model selection | daily 01:10 | bench JSONL <24h, 5/5 gate | paid fallback | IMPLEMENTED; note scores swing day to day (section 1.1) |

Gaps worth naming: rows 5 (preference row never populated), 8 (subagent
routing surface absent), 9 (away-window consumer absent). Row 3's gap is
evidence, not code. The accepted 2026-09-10-cost-tiering.plan.md (T1/T2/T3
class tags in select_model) is the landing vehicle for rows 1/5/8 if
executed; it is still all-unchecked.

## 4. TTSR rule candidates

Bar (plan step 7): only rules that close a real observed failure mode.
Each candidate below cites the record that motivates it.

R1 - In-pipeline readiness. A quota leg may serve delegated sessions or
passthrough callers only after it has produced one successful kind=model
telemetry row through the automation path; a hand-run probe does not count.
Trigger: gating any new routing (session-model-preference, MCP tool, share
row) on leg state. Action: check telemetry for a source row before arming;
absence = leg dormant. Evidence: the five-day probe/pipeline divergence --
credential-health read kimi 401 / lobehub 404 while the real legs were
alive (docs/records/2026-09-10-automation-ci-and-probe-hygiene.md), and the
inverse stands today: lobehub probes return 200 in 15-20 s by hand while
the automation path has zero successful rows
(docs/research/2026-09-10-lobehub-api-research.md, prompt-slim outcome;
telemetry.db query 2026-09-10). Both directions of the same lesson.

R2 - Leg attribution. Every model-consuming session writes which leg served
it (leg + source) into its attribution record. Trigger: any session launch
or subagent model call. Action: append model+source to the budget row /
telemetry (the class=<T1|T2|T3> field of cost-tiering plan step 1 is the
mechanism; SESSION_SOURCE export already exists).
Evidence: the coordinator-family blind spot -- SimDesign/QueueDeps sessions
produced zero parseable cost rows, so "$43.72 tracked may UNDER-count"
(docs/research/2026-09-10-cost-landscape.md section 3); and kimi
session-cost parsing captures no cost at all (same doc section 5 note).

R3 - Tightest-window pacing. A multi-window quota source is paced against
its tightest window, never dumped. Trigger: adding opencode-go (5h/7d/
monthly) as any kind of leg or preference. Action: extend pacing to the
5h bucket before the first call lands; a daily-cap pacer (quota_pace_blocked)
would allow a $12 5h bucket to be emptied in one hour.
Evidence: the design implication recorded when the buckets were measured --
"pace T2 calls against this, not dump at once"
(docs/research/2026-09-10-lobehub-api-research.md section 4), plus the
observed front-load failure quota_pace_blocked exists to prevent
(model.sh:265-271) and the $42.06 single-day overspend vs the $10-20 target
(cost-landscape section 1).

R4 - Empty-work quota skip. A quota-pinned call with nothing to process
must downgrade to the local chain instead of burning the cap. Trigger:
share rotation fires but the work queue is empty (pick_line empty, research
pool drained). Action: skip the quota pin, run local, emit no kind=model
row. Evidence: "the model call hits an empty input and emits telemetry with
zero tokens/cost. It does burn quota ... without producing useful work"
(docs/research/2026-09-10-quota-utilization.md section 4) -- and step 9
routing would multiply this futile-call vector into delegated sessions.

R5 - Edge-timeout budget on new legs. Every leg added to the chain declares
its curl --max-time AND bounded max output tokens below the smallest edge
timeout on the path. Trigger: wiring a new endpoint (the hypothetical bili
wiring in the bili doc is the template of what NOT to do unbounded).
Action: leg is rejected from the chain without both values; LobeHub-style
30 s Cloudflare edges are the binding case. Evidence: "the historical 524s
traced to unbounded output, not prompt size alone"
(docs/research/2026-09-10-lobehub-api-research.md, prompt-slim outcome) and
the STATE.md 524 rows on 2026-09-08 (bili-lobehub-integration doc).

Evaluated and rejected for lack of observed failure: quiet-hours model
pinning (the operator-away-windows row has no consumer yet -- a gap, not a
failure; revisit when 34-operator-presence-check.sh exists). The probe-
authentication rule is already landed as the probe-hygiene lint and is not
re-proposed.

## 5. Verdict block

- local unsloth bench: READY (free, benched, demoted-gated; 264-361 s on
  full prompts = async only).
- deck-7b: READY (64-76 s x5 stable; only gap is one 5-probe bench of
  deck-7b itself).
- kimi: READY (29 in-pipeline rows, 71-78 s x2, caps+pacing live).
- lobehub: CONDITIONAL (15-20 s hand-measured post-slim, but 0 in-pipeline
  successes ever; needs one authorized MODEL_PIN=lobehub probe).
- opencode-go T2 / openrouter: NO passthrough needed -- omp consumes both
  natively; adopt opencode-go as an hngh leg only with tightest-window
  pacing (R3).

2026-09-11 update (R1 gap closed, in-pipeline datum landed): wall_s is now
populated on every leg's kind=model row (_model_emit reads the wall-seconds
and usage-token files _post_chat/unsloth_attempt write -- same
tmp-file subshell-escape mechanism as POST_CODE_FILE; chat-completions and
Responses usage shapes both parsed; absent = NULL, never fabricated), and
the one authorized MODEL_PIN=lobehub model_call ran in the automation
path: HTTP 200-completed, wall_s 30.44 s, tokens_in 24638 / tokens_out 14
(the 24.6k input confirms the 28.6k->8k prompt-slim concern is real in
pipeline, not just config). The 30 s row supersedes the 15-20 s
hand-measurement; lobehub's CONDITIONAL status now rests on prompt slim,
not on missing evidence.

Highest-leverage next measurement: populate wall_s in _model_emit, then run
ONE bounded MODEL_PIN=lobehub model_call in the automation path -- it
converts the 15-20 s hand number into an in-pipeline row and is the only
missing datum blocking shape (b).
