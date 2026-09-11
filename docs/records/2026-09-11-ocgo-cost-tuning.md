# 2026-09-11 - Ocgo session cost tuning (burn attribution, reducers, optimizer verdict)

## Question

Operator directive: "prioritize limiting opencode's token usage to the extent
that we can, try to drive its cost for use down as low as possible... If we
need Hngh to micromanage opencode's config and continually rewrite and
optimize its agent harnessing, is that at all feasible?"

## Measured baseline (session 2, verified)

- Session 1: 112,883 in / 7,778 out, $0.0381. Session 2: 144,495 in /
  6,022 out, $0.0377. glm-5.3-flash: $0.15/M in, $0.50/M out, so INPUT is
  ~86% of cost.
- Primary data: `logs/overnight-ocgo-selfsteer2-20260911T093738.log.json`
  (session 2's `opencode run --format json` event stream; 12 steps, 14
  tool_use events, one session `ses_f6f4fd27effeaobMAgD3vdPVsy`).

## Burn attribution (parsed from the event stream)

Every step's `tokens.total = input + output + reasoning + cache.read` exactly,
so `input` is FRESH (uncached) tokens and cache reads are billed separately.
Session 2 fresh input = 144,495 (sum of per-step input). Cache reads =
391,360 tokens at the discounted cache rate. Cost split: fresh input ~$0.022
(57%), cache reads ~$0.013 (35%), output ~$0.004 (11%) = ~$0.038.

Top 3 fresh-input consumers (per-step, verbatim from the stream):

| Step | Event | In (fresh) | Cache read | What happened |
|---|---|---|---|---|
| 0 | step_finish msg Rh6WA3 | 25,198 | 0 | First request: system prompt + executor agent prompt + 3 MCP servers' tool schemas + assignment + context pack. Boilerplate re-billed on every later miss. |
| 1 | step_finish msg oWexI8 | 33,153 | 576 | Near-total cache miss one step after step 0: the whole 25k prefix re-billed fresh, plus the lessons read output injected (whole-file read, 29,158 chars). |
| 7 | step_finish msg iUgy0J | 45,261 | 0 | Full re-bill after a 286 s idle gap (scout subagent run): entire ~37k conversation history billed fresh again, plus the scout result (call_omo_agent, 32,766 chars, ~8k tok). |

Top 3 tool-output burns (chars -> approx tokens at 4:1):

| Tool | Output chars | ~tokens | Detail |
|---|---|---|---|
| call_omo_agent (scout survey result) | 32,766 | ~8.2k | Full survey transcript injected into parent history in one step |
| read automation/state/ocgo-agent-lessons.md | 29,158 | ~7.3k | Whole-file read; the prompt says read the TAIL (~30 lines) only |
| read automation/lib/launch-session.sh | 12,282 | ~3.1k | Whole-file read of a 200+ line script |

Scout subagent traffic: only the parent-side result (33k chars) is visible in
this stream; the subagent session's own tokens were not captured by the
emitter (it reads the parent's event stream only).

Levers in expected-savings order:

1. Cache-miss elimination (steps 1+7+8 = 91,992 fresh tokens, 64% of session
   input): keep the session warm (long idle gaps invalidate the provider cache
   TTL); nothing in config forces this - watch the burn TSV for it.
2. Scout result digest cap (33k chars -> <2k): landed in scout.md.
3. Whole-file read discipline (lessons 7.3k + launch-session 3.1k + future
   src/main.lisp / README / docs/records reads): landed in executor.md.
4. Initial boilerplate 25k (MCP tool schemas x3 + system/agent prompt): NOT
   landed - misakanet/codegraph MCP servers are prime candidates to disable
   for machine sessions; parked as the day-tier optimizer's first candidate.
5. small_model -> free local llama-server: removes flash spend from
   title/summary/compaction entirely.

## Reducers landed (commit this record ships in)

- **Reducer A** - `automation/config/opencode/opencode.jsonc`: `unsloth-local`
  provider block restored (approach copied verbatim from
  `~/.config/opencode/opencode.jsonc`: `@ai-sdk/openai-compatible`,
  `baseURL: {env:UNSLOTH_BASE_URL}`, `apiKey: {env:UNSLOTH_API_KEY}` - env-var
  references, never literals; no key value in the file). One model carried:
  `unsloth/Ornith-1.0-9B-GGUF`. `small_model` pinned to
  `unsloth-local/unsloth/Ornith-1.0-9B-GGUF`. Risk, honestly: a 9B local model
  writes worse titles/summaries than glm-5.3-flash - accepted for throwaway
  summary artifacts; NOT acceptable for the primary agent, which stays
  glm-5.3-flash (operator preference). Requires UNSLOTH_BASE_URL and
  UNSLOTH_API_KEY in the launcher environment (llama-server 127.0.0.1:8888,
  token-gated); if unset, opencode fails small_model calls best-effort.
- **Reducer B** - `agents/executor.md` + `agents/scout.md`: short
  "## Input budget" section (<12 lines each): never whole-file read
  src/main.lisp, README.md, docs/records/*, automation/STATE.md,
  ocgo-agent-lessons.md (tail only); grep with `-m` limits and narrow slices;
  trust the pre-digested context pack; scout results are digests <~2k chars.
- **Telemetry** - `jobs/ocgo-attribution.py` gains `--burn PATH`: appends the
  top-3 largest tool outputs per session stream to
  `state/ocgo-agent-burn.tsv` (`utc_date | session_id | tool | output_chars |
  desc`, append-only, best-effort, tested on a fixture stream); launcher wires
  it. This is the per-session top-burner attribution the optimizer reads.

## Optimizer feasibility verdict: FEASIBLE, with fences

- (a) Write side already exists: the config layer is hngh-owned committed
  files (`automation/config/opencode/`), change-safe by construction.
- (b) Loop shape: per-session telemetry (emitter already records totals; now
  also the top-burn TSV) -> a day-tier review that lands AT MOST ONE config
  change per UTC day (prompt tersification, a deny-rule for a wasteful
  pattern, a scout scope cap), gated by `make test` + the config-parse test;
  rollback = `git revert` (config changes are committed files). One
  change/day pacing means no churn loop.
- NOT automatable, ever:
  - permission/deny-block widening (never; test-ocgo-launch.py enforces the
    superset direction anyway),
  - model re-routing of the primary agent (operator decision only),
  - anything touching credential config or key values.
- Verdict: FEASIBLE with those fences. First queued candidate: disable
  misakanet/codegraph MCP servers for machine sessions (largest remaining
  fixed input cost, tool schemas on every request).

## bili-on-opencode verdict: VIABLE-NEXT (not implemented here)

`billion-context` is a universal context-compression proxy ("any agent that
can set a base URL - zero per-agent adapter code"). opencode builds its
request client-side, so a MITM compressor applies. Two dedicated integration
paths already exist upstream: the `bili opencode` launcher ("MITM for HTTPS +
temp opencode.json (/bili/ for HTTP) + thin /acp plugin") and the in-process
`opencode-acp` extension. A manual alternative also works without any cert
gymnastics: point the provider block's `baseURL` at the local HTTP proxy
(`http://localhost:8787/bili/` prefix) via the existing `{env:...}` pattern -
NODE_EXTRA_CA_CERTS is only needed for the HTTPS MITM path, which plain HTTP
`/bili/` avoids. Guard before landing: `bili opencode` writes a temp
opencode.json which must not silently replace the hngh-owned OPENCODE_CONFIG
layer (the secret-deny block would be at risk); integration must merge with
the pinned config or ride opencode-acp in-process. Expected win: compresses
conversation history, i.e. the 391k cache-read tokens (35% of cost) and the
miss re-bills - the levers prompt discipline cannot reach. Parked as a
VIABLE-NEXT line, not tonight's change.

## Prior-install plugin evaluation (llmtrim / librarian)

Not adopted: they were rejected in the 2026-09-11 config-layer decision (no
hngh purpose) and llmtrim's net effect on input burn is unproven - a plugin
agent adds its own system-prompt tokens to every request, and the same
trimming is now covered by the agent prompts (bounded reads) plus the bili
candidate (wire-level compression). Revisit only if the burn TSV shows
whole-file reads persisting despite the prompt discipline.

## Tests

- New: `tests/test-ocgo-config-cost.py` (wired into `make test`): config
  JSONC parses; small_model pins to `unsloth-local/` while model + executor
  stay glm-5.3-flash; provider block uses `{env:...}` refs not literals;
  both agent prompts carry the input-budget markers; emitter appends the
  top-burn TSV from a fixture event stream (seam: the stream path argument).
- Updated: `tests/test-ocgo-launch.py` small_model assertion follows the
  new contract. `tests/test-ocgo-attribution.py` unchanged and green.