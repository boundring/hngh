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
