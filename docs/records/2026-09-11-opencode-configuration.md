# hngh opencode configuration layer, delegation roles, lessons loop

Date: 2026-09-11. English/ASCII. Design base:
docs/research/2026-09-10-opencode-agentic-surface.md (s5 wiring, s6
attribution, s8 risks, s9 ship order); executor wiring record
docs/records/2026-09-11-opencode-executor.md. This record covers the
mission's four build items: the config layer, the self-steering lessons
loop, the ACP verdict, and the first supervised session.

## 1. Config layer (automation/config/opencode/)

Files:

- opencode/opencode.jsonc — the hngh-owned OPENCODE_CONFIG target. The
  executor branch (launch-session.sh) points OPENCODE_CONFIG here.
- opencode/agents/executor.md — executor agent system prompt.
- opencode/agents/scout.md — scout agent system prompt (referenced from
  the config's `hngh-scout` agent entry via {file:}).

Layering facts (opencode.ai/docs/config): a custom config merges OVER the
operator's global ~/.config/opencode/opencode.jsonc (precedence: global <
OPENCODE_CONFIG < project). The repo has no project opencode.json and no
.opencode/ directory, so the merge surface is exactly: global, then this
custom config.

Carried vs the prior install:

- Secret-deny permission block copied VERBATIM from the operator's global
  config — a superset of the committed baseline
  automation/config/opencode-safety.jsonc (which stays as the superset
  test's baseline; test-ocgo-launch.py enforces it). Never referenced by
  path, so operator config churn cannot widen machine-session permissions
  (design risk 1).
- MCP servers: hngh's own server (python3
  /home/bricker/Projects/etc/hngh/automation/mcp/hngh_mcp_server.py,
  stdio — exposes the mcp__hngh_* read tools: hngh_present, hngh_status,
  dashboard_readout, queue_report, research_lines) plus misakanet and
  codegraph copied verbatim from the prior install after verifying both
  are local stdio commands that exist
  (~/.local/share/misakanet/.venv/bin/python + scripts/mcp_server.py;
  codegraph at ~/.local/bin/codegraph). All three verified `connected`
  via `opencode mcp list` with the config active.
- Model: opencode-go/glm-5.3-flash — the operator's Go quota model
  (glm-5.3-flash carries the $60/mo limit = the $12/5h bucket; operator
  directive 2026-09-11: this is the only opencode model tonight, never
  list-prefer or configure others). small_model is pinned to the SAME id
  so lightweight tasks (title/summary/compaction) can never route to
  another model id. default_agent: executor. autoupdate: false (machine
  sessions must not churn the binary mid-night). share: disabled.

Deliberately OUT (prior-install evaluation, documented decision):

- Plugins opencode-antigravity-auth + oh-my-openagent: no hngh purpose.
  The Go quota authenticates via the OPENCODE_API_KEY environment
  variable (verified: `opencode auth list` Environment section lists
  "OpenCode Zen OPENCODE_API_KEY"; no auth.json entry needed, verified
  key VALUE never read or printed). The operator keeps both plugins in
  their personal config. Honest note: the global config still merges in,
  so those plugins still load for machine sessions (observable:
  oh-my-openagent's librarian/llmtrim agents and websearch/context7/
  grep_app MCP servers appear in `opencode agent/mcp list`); a custom
  config cannot remove them short of OPENCODE_CONFIG_DIR isolation.
  Accepted: they set no hngh-owned key.
- The unsloth-local provider block: bench-gated local models route
  through omp legs (operator directive 2026-09-11 item 2: the config
  layer must not alter model selection for existing legs); opencode
  sessions never touch it.

Agent roles (opencode agent format: `agent.<name>` with mode/prompt/
permission/model; verified against /docs/agents and the live binary):

- executor — mode primary (the `opencode run --agent executor` surface),
  model pinned opencode-go/glm-5.3-flash. Mirrors
  .omp/agents/hngh-executor.md: ONE verified assignment per session;
  plan steps go through the ceremony loop (propose -> issue-cert ->
  mutation-check), commit only on a green gate, never amend, no push
  from a commit certificate; research-class assignments delegate the
  survey to @hngh-scout and land exactly one docs/research/ draft; hard
  boundaries (no provider/credential config, no secrets, no
  ~/.omp/agent/rules/); terse, English/ASCII.
- hngh-scout — mode subagent, model pinned opencode-go/glm-5.3-flash,
  permission edit/bash/task/todowrite = deny (the documented
  tool-restriction mechanism; verified `opencode agent list` shows
  "hngh-scout (subagent)"). Mirrors .omp/agents/hngh-scout.md:
  READ-ONLY research scout, docs/research/ drafts only, TSV rows are
  drafted as text for a separate writer session.

Naming note: the scout agent is `hngh-scout`, not `scout` — `scout` is a
reserved built-in name and an agent entry named `scout` with an
agent-level permission block silently fails to load (found in live
`opencode agent list`; the built-in scout did not appear in 1.18.30's
list, but the collision still dropped the entry). The rename is the
whole fix.

## 2. Self-steering meta-thread (the lessons loop)

Write side — launch-session.sh, opencode branch, after classification:

- append_ocgo_lesson() appends one line per opencode session to
  automation/state/ocgo-agent-lessons.md (durable state dir, gitignored
  like every other state file):
  `<UTC ts> | <cause class> | <sentence the next session should know>`.
- The sentence comes from lesson_for_cause() (lib/causes.sh, next to the
  bestiary keyword map it derives from) — deterministic, no model call:
  bad-execution -> "the step was too big or never verified: shrink the
  step and prove the thing works on its own surface before claiming
  done", missing-knowledge -> "you ran an interface that does not
  exist: read the real docs or source for the exact name", etc.
- Cap: header lines + newest 200 entries, oldest dropped (test
  test_lessons_append_and_cap runs 205 appends hermetically).
- Happy-path skip (first-session finding, section 4): a clean rc=0 exit
  classified unknown matched no failure keyword — appending would
  pollute the file with "you failed" noise on every success, so the
  append fires only when rc!=0 OR the cause is a known class.

Read side — the agent definitions instruct (executor.md, scout.md):
read the tail of automation/state/ocgo-agent-lessons.md as the FIRST
action of every session and actively steer away from every recorded
class; when your own assignment fails, name the cause class plainly so
the next lesson line is accurate. That is the learning loop.

Gap check the mission named: the model-demote outcome counter
(record_model_outcome) fired for the opencode branch but was keyed to
$SESSION_MODEL — the omp leg's model, not the one the opencode session
actually used (cross-contamination: ocgo failures could demote the omp
model's counter). Fixed: outcome_model is set to "opencode-go/<model>"
inside the branch; the row after tonight's session reads
`opencode-go/glm-5.3-flash  1  0` (one consecutive bad-execution).

Second fix the branch needed (found by the failing-session test): the
attribution emitter ran last inside the opencode branch, so LAUNCH_RC was
the EMITTER's exit code — the child's real rc (timeout kills, crashes)
never reached the disposition/cause/demote spine. The branch now captures
oc_rc immediately after the child and restores it before the case
statement.

## 3. ACP verdict: DEFER

ACP (Agent Client Protocol) turns opencode into a JSON-RPC/stdio agent
subprocess for an interactive editor host (Zed, JetBrains, nvim, via
`opencode acp`; opencode.ai/docs/acp). What it would offer hngh:
streaming multi-turn sessions against a long-lived backend instead of
spawn-per-session, and editor-hosted interactivity. Verdict: DEFER. Two
named reasons: (a) hngh's orchestration is a batch supervisor — the
spawn-per-session `opencode run` shape already gives wrapper-owned
lifecycle, log capture, and telemetry, and the emitter closes the only
accounting gap; (b) ACP adds a host-process dependency and a client
protocol without closing any named hngh gap — mid-run steering stays
absent in both shapes, and the one real gap (a remote spend query for
exact 5h-bucket honesty) is not part of ACP. Adopt trigger: a genuinely
interactive operator surface (editor/TUI host) driving hngh sessions.

## 4. First supervised session (2026-09-11T03:32Z)

Invocation: HNGH_SESSION_EXECUTOR=opencode env override only (the
session-executor cadence row stays EMPTY — dormant default stands);
launch_session first-ocgo-agent-supervised, TIMEOUT_S=600, task =
research-class draft on session-level self-steering loops (research line
alert-to-work-routing-patterns-closing-the-self-observation-loop), real
bridge run-1, --auto under the pinned config, --agent executor.

Credential wiring: OPENCODE_API_KEY is already in the systemd USER
environment (verified present via `systemctl --user show-environment`,
count only — values never printed), and the executor branch now carries
the same trust pattern as model.sh ocgo_chat as the fallback: key file
${OPENCODE_KEY_FILE:-~/.config/hngh/opencode-key}, mode 600 required,
value passed to the child as command-scoped env only (never echoed,
never exported into the launcher's shell, so sibling children never
inherit it). Both paths are hermetically tested.

Result (verbatim):

- Exit: LAUNCH_RC=0 (child ended its turn with reason "stop"),
  disposition=cancelled, wall=83s (bound was 600s).
- Attribution (the emitter's telemetry row, automation/dashboard/
  telemetry.db): ts=2026-09-11T03:34:05Z, source=ocgo-agent, kind=model,
  identity=ses_f7179a85bffeJAPHuoFs3RSO0k, tokens_in=112883,
  tokens_out=7788, cost_usd=0.038110290000000005,
  model=opencode-go/glm-5.3-flash. 16 steps (15 tool-calls, 1 stop).
- Classification: cause=bad-execution — a keyword FALSE POSITIVE (the
  log tail mentions "budget/breadcrumbs"; no actual budget/timeout
  failure). Noted, not fixed: classify_cause is the shared deterministic
  spine; the lessons loop records what it says.
- Lessons loop proof: automation/state/ocgo-agent-lessons.md gained
  exactly one line:
  2026-09-11T03:34:05Z | bad-execution | budget/cap/exhausted/timeout --
  the step was too big or never verified: shrink the step and prove the
  thing works on its own surface before claiming done
- Demote counter: opencode-go/glm-5.3-flash -> 1 consecutive
  bad-execution (not demoted; threshold 2).
- Budget ledger: one `overnight|first-ocgo-agent-supervised | session-run`
  row in logs/budget.md; bridge run-1 closed cancelled.

Task outcome, honest: the assigned draft
(docs/research/2026-09-11-ocgo-agent-self-steering.md) was NOT produced.
The executor delegated the web survey to a background @hngh-scout
subagent, then ended its turn while the scout was still running —
`opencode run` exits when the primary turn ends and the background
subagent dies with it. This is the loop's first real lesson and it is
now load-bearing: executor.md carries the rule "never end the session
with work in flight; wait for subagent results and integrate them
before your final message". The draft remains a future session's task.

Quota distribution: tonight's spend (~$0.038) sits inside the same
$12/5h Go bucket; the pacer (lib/model.sh quota_pace_blocked_5h) counts
sources ocgo,ocgo-agent together against opencode-cap-5h-calls=60, so
the HTTP leg and agent sessions now share one cap with no pacer changes.
Forward plan for 7d/monthly windows: calls-based like every other leg
until per-window cost data justifies more (same posture as the design
doc's s6/s7 — no cost-driven accounting until a spend query exists).

Disclosure: during sandbox debugging, a stub was misnamed (`oc` instead
of `opencode`) and the REAL binary ran one small session before the
mistake was caught: ~23k tokens in / 72 out, ~$0.0035, same pinned
config, telemetry captured to the sandbox db only, repo touched
read-only. Disclosed here because it was real paid spend outside the
one authorized session; total Go-bucket spend tonight is ~$0.042.

## 5. Tests and verification

- automation/tests/test-ocgo-launch.py extended (11 hermetic tests): the
  executor branch uses the new config when present; the config layer
  itself (real files): deny-block superset over opencode-safety.jsonc,
  MCP registrations (hngh + copied misakanet/codegraph), agent roles
  (executor primary, hngh-scout subagent with edit/bash deny), model +
  small_model + agent models all pinned to opencode-go/glm-5.3-flash,
  plugin key absent; lessons append caps at 200 entries; no-credential
  and too-open-key-file both fail-closed to omp; a 600 key file wires
  the key into the child (length observable, value never printed); a
  failed session (rc!=0, keyword-classified) appends its lesson; a
  clean session appends nothing.
- cd automation && make test: green (exit 0, includes lint-identifiers).
- opencode --version: 1.18.30 (unchanged).
- Commit: `feat: hngh opencode config layer with delegation roles and
  lessons loop` (+ record/session-evidence commit).

## 6. Ship state

- session-executor row: EMPTY (dormant default stands). Tonight's
  session rode the env override only. Row armed 2026-09-11 per operator
  word (value `opencode`); the first machine-ridden beat will be
  visible in logs/budget.md and telemetry source=ocgo-agent.
- The ocgo HTTP leg, pacing, and model selection for every other leg are
  untouched (operator directive 2026-09-11 item 2/4; benchmarking stays
  back-burnered).
