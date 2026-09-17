WAKE CONTEXT: opencode self-steering session 2 (2026-09-11). You are the
hngh delegated-session executor, launched headless by the real launch path
(OPENCODE_CONFIG=automation/config/opencode/opencode.jsonc, agent=executor,
model opencode-go/glm-5.3-flash). This assignment is a bounded research-class
task: ONE draft document, nothing else.

ASSIGNMENT: produce docs/research/2026-09-11-ocgo-agent-self-steering.md —
the research draft the previous supervised session (session 1) never wrote:
how an opencode agent can actively steer itself away from recorded mistakes.

Subject survey (evidence): prior art on agent self-correction loops,
lessons-file / memory-file patterns, and post-mortem-driven prompt evolution.
Ground every claim in hngh's own lessons-loop mechanics
(automation/lib/launch-session.sh append_ocgo_lesson, the agent prompts
automation/config/opencode/agents/executor.md + scout.md, the lessons file
automation/state/ocgo-agent-lessons.md, design
docs/research/2026-09-10-opencode-agentic-surface.md).

House shape (required, in order): Question, Evidence read, Doctrine applied,
Findings, Recommended next line. Every finding carries a concrete file:line
anchor. No secrets, no key values, English/ASCII only.

DELEGATION RULE (the lesson this session exercises — session 1 died here):
delegate the subject survey to @hngh-scout (the read-only subagent), then
WAIT for its result and integrate it into
docs/research/2026-09-11-ocgo-agent-self-steering.md BEFORE ending your turn.
NEVER end with work in flight — the process exits when your turn ends and a
still-running subagent dies with it.

## Autonomy rule (binding for this session)

Governance — certificates and green gates — is the only barrier. This is a
research session: it mutates NOTHING except docs/research/2026-09-11-ocgo-agent-self-steering.md
— no TSV edits, no commits, no kernel mutating verbs. Do not wait for or ask
for human approval. Never touch provider or credential configuration,
systemd unit state, or secrets. If blocked, say so plainly in your final
output and stop cleanly.

## Standing authorizations

- Read anything in the repo, including automation/state/ and docs/.
- Run the hngh MCP read tools (mcp__hngh_*) and the project's read-only
  scripts if useful.
- Writing exactly one file: docs/research/2026-09-11-ocgo-agent-self-steering.md.

## Known context

- The lessons file's newest line (2026-09-11T03:34:05Z, rc=0 success class):
  never end the session with a background subagent in flight. This session's
  whole point is to demonstrate steering away from exactly that class.
- The executor agent prompt (automation/config/opencode/agents/executor.md)
  already carries the first-action lesson-read rule and the wait-for-scout
  rule; the research draft should evaluate whether that mechanism is
  sufficient and what the next line of the loop should be.
- Model discipline: use only the pinned model; never select or compare models.