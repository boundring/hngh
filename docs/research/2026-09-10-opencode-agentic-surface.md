# opencode as an hngh agentic surface (design analysis)

Date: 2026-09-10. Status: research only; no code changed. English/ASCII.

Question: can the opencode CLI/platform serve as a *generic agentic executor*
for hngh's delegated sessions -- parallel to the `omp -p --model` launch path
-- so delegated sessions ride opencode's own agent loop (and its OpenCode Go
quota) instead of only raw ocgo_chat HTTP calls? Operator directive framing:
"opencode is quota access, not a usage contract" -- hngh drives it on hngh's
terms, at omp feature parity where omp features matter (steering, subagents,
plugins, bili compression), not inside opencode's intended usage patterns.

Evidence bases (every claim below grounds in a probe run or a file read):
- Probes run 2026-09-10 (section 2): `command -v opencode`, config/db reads.
- opencode.ai/docs/cli and /docs/config (read 2026-09-10): run flags, config
  precedence, env vars, permission model.
- automation/lib/launch-session.sh, scripts/overnight-cycle.sh,
  lib/model.sh (ocgo_chat + quota_pace_blocked_5h), lib/causes.sh,
  automation/cadence-params.tsv: executor/pacing/ledger contracts.
- docs/research/2026-09-10-lobehub-api-research.md s4 (Go bucket terms),
  2026-09-10-passthrough-and-quota-interleaving.md s3-R2/R3,
  2026-09-10-bili-lobehub-integration.md, 2026-08-30-delegation-lane-*.md.
- ~/.local/share/opencode/opencode.db schema + row inspection (attribution).

## 1. Verdict (one line)

CONDITIONAL GO -- the wiring shape is one cadence-params executor row plus a
single invocation branch inside launch-session.sh (bridge lifecycle, budget
row, and log contract unchanged), gated on two named blockers: the opencode
binary is NOT installed on this desktop, and agent-internal quota spend is
invisible to the 5h pacer until a post-run attribution emitter lands.

## 2. Local probe results (2026-09-10, commands run verbatim)

- `command -v opencode` -> empty; `opencode --version` -> command not found.
  PATH scanned (~/.local/bin, ~/.npm-global/bin, ~/.bun/bin, /usr/local/bin,
  /usr/bin): no opencode binary anywhere. **Not installed.**
- Remnants of a prior install DO exist:
  - ~/.config/opencode/opencode.jsonc: global config with MCP servers
    (misakanet, codegraph -- both local stdio), permission read-deny
    guardrails (*.env*, ~/.ssh/id_*, auth.json, *.key), plugins
    `opencode-antigravity-auth` + `oh-my-openagent`, a custom
    `unsloth-local` provider block, and ~/.config/opencode/package.json
    pinning `@opencode-ai/plugin` 1.15.13.
  - ~/.local/share/opencode/: opencode.db (+wal/shm), auth.json, log/,
    storage/, 2026-06-era logs.
  - ~/.opencode/node_modules/@opencode-ai/{plugin,sdk}.
- auth.json providers (keys listed, values never read): google,
  kimi-for-coding, xai, github-copilot. **No OpenCode Zen/Go entry** -- the
  Go key currently lives only in Pi's provider store and hngh's key file
  (model.sh ocgo_chat key resolution, automation/lib/model.sh:426-431).
- opencode.db: 492 sessions, 13,535 message rows. `message.data` is JSON
  carrying, per assistant message: `cost` (measured example: 0.003717945),
  `tokens{input,output,reasoning,cache{write,read}}` (example: 8019 in /
  217 out), `modelID`, `providerID`, `time{created,completed}`. This is the
  per-session attribution surface (section 6).

## 3. Headless invocation facts (all from opencode.ai/docs/cli + /docs/config)

- `opencode run [message..]` is the `omp -p` equivalent: non-interactive,
  prompt-as-argument, exits when the turn completes.
- Per-call model pinning: `-m/--model provider/model` on `run` (the same
  one-call pin shape as omp's `--model`); config `model` key is the
  fallback; agents can pin per-agent (`opencode agent create -m`). The
  exact provider id for the OpenCode Go subscription (`opencode models`
  listing) verifies at install time; the raw Go endpoint hngh's HTTP leg
  uses (opencode.ai/zen/go/v1) is opencode's own first-party platform.
- `--auto` auto-approves permissions not explicitly denied -- the
  non-interactive analogue of hngh's standing-authorization block; the
  `permission` config block (and inline `OPENCODE_PERMISSION` env) carries
  explicit denies, and this desktop's config already denies secret reads.
- `--format json` emits raw JSON events (machine-parseable run log);
  `--print-logs`/`--log-level` put diagnostics on stderr.
- `-s/--session`, `-c/--continue`, `--fork` resume or fork an existing
  session; `--dir` sets the working directory; `--title` names the
  session; `--file` attaches files; `--variant` sets reasoning effort.
- `--attach http://localhost:4096` runs against a live `opencode serve`
  instance (avoids per-run MCP cold boot; a daemon is optional, not
  required -- the plain `run` path spawns everything per call).
- MCP client support is first-class (config `mcp` block): misakanet and
  codegraph are already registered on this desktop, so hngh's MCP server
  (automation/mcp/hngh_mcp_server.py) consumes with zero code change.
- Plugins: config `plugin` array + `opencode plugin <module>`; JS plugin
  API via @opencode-ai/plugin; global `--pure` strips external plugins
  (debug path).
- Subagents: `opencode agent create --mode subagent`; background
  subagents sit behind OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS.
- Steering: **no mid-run injection on one-shot `run`** -- `-s/-c` is
  post-hoc continuation (a new user message on a finished session), i.e.
  respawn-with-context, not steering. omp -p has the identical absence;
  this is parity, not regression.
- Config isolation: OPENCODE_CONFIG / OPENCODE_CONFIG_DIR /
  OPENCODE_CONFIG_CONTENT give a machine-session-owned config; hygiene
  vars: OPENCODE_DISABLE_AUTOUPDATE, OPENCODE_DISABLE_LSP_DOWNLOAD,
  OPENCODE_DISABLE_MODELS_FETCH.
- Context window: builtin auto-compaction (OPENCODE_DISABLE_AUTOCOMPACT
  to disable) -- the built-in substitute for bili on this executor.
- Exit codes: undocumented in the docs read. The wrapper-owned `timeout`
  rc=124 contract (launch-session.sh:105) is executor-agnostic; opencode's
  own success/error rc must be probed once at install.

## 4. Parity matrix (hngh requirement | omp today | opencode run | verdict)

| hngh requirement | omp today | opencode | Verdict |
|---|---|---|---|
| Headless one-shot invocation | `omp -p` (launch-session.sh:99-104) | `opencode run` | PARITY |
| Per-call model pin | `--model $SESSION_MODEL` env-routed | `-m provider/model` per call | PARITY (string form differs; row carries the opencode form) |
| Permission/authorization model | omp permission config | `--auto` + config permission denies (config already hardened on this desktop) | PARITY, must copy deny block into executor config (risk 1) |
| MCP client (consume hngh MCP server) | omp MCP config | `mcp` config block; misakanet + codegraph proven locally | PARITY |
| Plugin/extension mechanism | omp extensions | JS plugin API (@opencode-ai/plugin) | PARITY (different API; hngh's session patterns ride prompt + bridge wrapper, not executor plugins) |
| Subagent/delegation support | omp subagents | subagent mode + experimental background subagents | PARITY-ISH (one experimental flag) |
| Mid-run steering | absent | absent (`-s` is post-hoc) | PARITY GAP -- honest: omp lacks it too; not a blocker |
| Log capture for classify_cause | stdout -> logs/overnight-*.log, tail-200 keyword match | stdout capture identical; `--format json` optional richer stream | PARITY (text output to the classifier's log; json to a side file, risk 2) |
| Exit codes | rc + wrapper 124 | undocumented; wrapper timeout unchanged | PROBE NEEDED (one command) |
| Session continuity for respawn | none (stateless one-shot) | `-s/-c/--fork` | opencode ADVANTAGE |
| bili context compression | `bili omp` MITM wrapper (launch-session.sh:40-55) | unverified: bili bundles/wraps the omp CLI specifically; opencode is Node so NODE_EXTRA_CA_CERTS applies in principle, but no bili->opencode path exists today | GAP -- opencode sessions run uncompressed; builtin autocompact is the substitute |
| Budget ledger row (logs/budget.md) | launcher-owned `session-run` row | wrapper unchanged | PARITY (wrapper) |
| Bridge run-start/run-end lifecycle | wrapper-owned, loadout carried in env | wrapper unchanged | PARITY (wrapper) |
| Per-session cost attribution | session-cost parsing of omp transcripts | opencode.db message cost/tokens per session; `--format json` events | PARITY VIA NEW EMITTER (section 6) |
| Context-window behavior | bili maxContextLimit row (bctx-max-context-limit) | builtin autocompact | PARITY (different mechanism, same goal) |

Net: no omp feature hngh exercises is missing from opencode's headless
surface except bili (omp-only wrapper). The load-bearing work is all in the
wrapper, which already exists and is executor-agnostic.

## 5. Wiring recommendation (one shape)

**Executor selection -- one cadence-params row, existing conventions only:**

    session-executor	omp	<provenance>	<note>

- Values: `omp` (default) | `opencode` | `auto`. Empty/absent row = omp
  (fail-closed to today's behavior -- same convention as opencode-model /
  kimi-model empty-means-skip). Env override HNGH_SESSION_EXECUTOR via the
  standard get_param precedence, mirroring every other row.
- `auto` (phase 2, not phase 1) rotates the executor per session class the
  way kimi-research-share / lobehub-research-share / opencode-research-share
  rotate quota pins today -- every Nth session pins executor=opencode.
  Per-lane executor tags are explicitly deferred until interleaving
  telemetry justifies them (same posture as the delegation-lane record's
  queue-first verdict, docs/research/2026-08-30-delegation-lane-*.md R1).

**The launch path -- one branch inside launch_session, everything else
untouched.** At the invocation site (launch-session.sh:96-104) the executor
row picks the child command; executor=opencode runs:

    timeout "$TIMEOUT_S" opencode run --dir "$ROOT" \
      -m "$OC_SESSION_MODEL" --auto \
      "$body" >"$ROOT/$log" 2>&1

with OPENCODE_CONFIG pointed at an hngh-owned config that copies the
existing secret-deny permission block (never referenced by path -- copied,
so operator config churn cannot silently widen machine-session permissions).
Model string composed from the existing `opencode-model` row
(glm-5.3-flash) in `provider/model` form. Bridge run-start (HNGH_LOADOUT
unchanged), context pack, log path, budget row, bridge run-end,
classify_cause, and model-outcome demotion all wrap the child without
parsing omp internals -- verified by reading launch-session.sh end to end:
it consumes only rc, the log path, and classify_cause(log).

What is deliberately NOT built: no second bridge, no per-executor ledger
format, no `opencode serve` daemon (the `--attach` optimization is a later
measure-then-maybe), no new config framework beyond the one row.

## 6. Quota attribution (R2) and the honest telemetry gap

The gap, named plainly: when opencode's agent loop makes its own model
calls, hngh sees NOTHING -- no kind=model telemetry row, so
quota_pace_blocked_5h (model.sh:347-365) counts only HTTP-leg spend. Both
the ocgo HTTP leg and any opencode agent session draw the SAME $12/5h
per-model bucket (same OPENCODE_API_KEY), each with its own independent cap:
until attribution closes, the bucket can be double-spent (HTTP cap 60 calls
assumes it is the only consumer).

What is attributable locally (measured, section 2): opencode.db message
rows carry cost + tokens + providerID/modelID + session_id + timestamps;
`opencode stats --models` aggregates; `opencode export <sessionID>` dumps
one session. Per-session spend IS obtainable post-run.

**Attribution plan:** the executor wrapper, after bridge run-end, parses
the `--format json` event stream it already captured (db as fallback) and
emits the same telemetry rows the HTTP leg emits -- kind=model,
source=ocgo-agent, wall_s, tokens_in/out -- so R2 attribution holds and the
existing 5h pacer sees agent spend with zero pacer changes. The emitter is
one small script consumed at one call site; no new accounting framework.

Reset-window honesty: the subscription's true 5h reset origin is
operator-side and unknowable (model.sh:343-345 already accepts grid
alignment as an approximation for the HTTP leg). Agent-internal spend adds
the same approximation, nothing worse. Exactness would need an opencode-side
remote spend query; none is documented (opencode stats is local-only) --
if one appears, the emitter reads it; until then TIMEOUT_S + the loadout
token/cost limits (HNGH_LOADOUT in launch-session.sh:69) remain the real
mid-session ceiling.

## 7. Distribution / load-balancing forward look

Executor choice is orthogonal to leg choice in the interleaving table
(2026-09-10-passthrough-and-quota-interleaving.md s3): it adds a routing
tag on the session rows, it does not move budget. Amended rows:

| Session class | Executor | Rationale |
|---|---|---|
| T1 mechanical (news, digest, ping) | unchanged: local unsloth, no agent session | no quota, no change |
| T2 research / bounded intelligence sessions | opencode when the row (or auto-share rotation) says so | converts per-call pacing into agent-loop autonomy riding the Go quota; pacing shifts to gate-the-spawn (pace check BEFORE launching) + post-run emitter rows |
| Long-context / bili-needed sessions | stay omp | bili wraps omp only (measured fact, bili doc Q1/Q3) |
| Operator interactive sessions | unaffected | interleaving row 7 stays operator-side |

Spend governance does not fork: sessions-day-max and the failfirst
concurrency ceiling govern both executors; the row is a tag, not a new
budget. Reset-window distribution (5h bucket pacing) when the agent
consumes internally: spawn-gating + the emitter's rows approximate it;
mid-session burn is unthrottleable from outside -- the agent decides its
own calls -- so the honest ceiling stays bounded timeout + loadout limits
until a spend query exists. Load balancing across executors then becomes
the same rotation arithmetic the research shares already use.

## 8. Risks (ranked)

1. **Permission drift.** `--auto` approves everything not explicitly
   denied; hngh's standing-authorization context makes a broadened read
   surface a credential risk. Mitigation is mandatory, not optional: the
   hngh-owned OPENCODE_CONFIG carries the copied secret-deny block
   (opencode.jsonc already demonstrates the exact block).
2. **Classifier drift.** classify_cause (lib/causes.sh:22-44) keyword-matches
   the last 200 log lines; `--format json` output would match keywords
   inside JSON strings unreliably (escapes may split phrases). Mitigation:
   plain-text output to the classifier's log; json events to a side file
   for the emitter. Decided at wiring time, one line either way.
3. **Double-spend on the shared $12/5h bucket** until the emitter lands
   (section 6). Ship order matters: emitter first or same commit, agent
   sessions second -- never sessions before attribution.
4. **Binary absence.** Everything is unverifiable until opencode is
   installed; install method is an operator choice (machine-wide tool).
   Blocker, not a design risk.
5. **Version churn.** opencode moves fast (experimental flags, config
   schema). The executor branch must use only the documented stable
   surface (`run`, `-m`, `--auto`, `--dir`, `--format json`) and treat
   experimental env vars as opt-in, never load-bearing.

## 9. Ship order (conditional GO)

1. Operator installs opencode (method = operator's call); verify
   `opencode --version`, `opencode models` (exact Go provider id), and one
   bounded headless `opencode run` smoke including rc behavior.
2. Attribution emitter + telemetry rows land.
3. The `session-executor` row + launcher branch land (small automation-lane
   diff); default value omp; first opencode session is a supervised
   research-class run, not an overnight development session.

Commit message: `docs: opencode as hngh agentic surface analysis`.
