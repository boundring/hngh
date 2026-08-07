# ACP Everywhere — Hngh as an Agent-Client-Protocol Hub

**Status**: Design (2026-08-07), research-grounded.
**Cross-links**: `live-orchestration.md` (steering/observe — now on ACP),
`components.md` (plugin inventory — add ACP client), `integrations.md`
(Hermes/opencode/editor surfaces), `roadmap.md` M9 wave 6.

---

## 0. The position

> Standardize our ACP approach across however many agentic tools — any and all.

Hngh should not build a per-tool control channel for Hermes, opencode, and the
next agent that ships. It should adopt ****ACP (Agent Client Protocol) as its
uniform agent control + observation + gate layer**, the same way editors adopt
LSP to avoid one parser per language. One ACP client layer drives every
ACP-speaking agent; one ACP *server* surface exposes Hngh itself.

ACP is Zed's open standard (released Aug 2025, Apache-2.0, JSON-RPC 2.0 over
stdio). By Mar 2026 it has **25+ agents and editors**: Gemini CLI (native),
Claude Code (via Zed bridge adapter), plus Zed, JetBrains, Neovim, Emacs, and
more. It is "the LSP for coding agents."

---

## 1. Why ACP fits Hngh (the mapping)

| Hngh need (from live-orchestration) | ACP method |
|---|---|
| Observe a squad member *underway* | `session/update` notifications: `agent_message_chunk`, `agent_thought_chunk`, `tool_call`, `tool_call_update`, `plan` |
| Read a transcript | `session/load` + `session/update` replay (post-hoc, but with live stream on top) |
| Steer mid-turn | `session/prompt` + **capability-negotiated steer-vs-queue** (below) |
| Pause / stop a runaway run | `session/cancel` (notification) |
| Human-gate an action | `session/request_permission(options, toolCall)` → `RequestPermissionResponse` |
| Delegate file/terminal access | `fs/read_text_file`, `fs/write_text_file`, `terminal/create`, `terminal/wait_for_exit`, `terminal/kill` |
| Manage session lifecycle | `session/new`, `session/load`, `session/cancel` |
| Choose model/mode | `session/new` / `session/set_mode` (models + modes returned at new) |

This covers the L1–L4 surface (observe, guard-rail, steer, plugin) with one
contract instead of per-tool hacks.

---

## 2. Hngh's two ACP roles

### 2a. Hngh as ACP **client** (primary — drives the squads)

- Hngh spawns each agent (Hermes, opencode, Claude Code, Gemini CLI…) **as an
  ACP subprocess over stdio**, or attaches to an already-running ACP server.
- One `hngh-acp` client module: `acp-initialize`, `acp-session-new`, `acp-prompt`,
  `acp-on-update`, `acp-cancel`, `acp-request-permission`.
- Every tool Hngh can already delegate to (Hermes `hermes acp`, opencode
  `opencode acp`) is reached through the *same* client. Adding a new agent =
  adding its launch command, not a new integration.
- This replaces the "tmux send-keys / per-tool shell" steering in current
  mission-control with a structured, reply-aware, JSON-RPC channel.

### 2b. Hngh as ACP **server** (secondary — dogfoods itself, editor access)

- `hngh acp` (or daemon mode) exposes Hngh as an ACP agent: `initialize`
  (advertise agent capabilities), `session/new`, `session/prompt`, streaming
  `session/update`, `session/request_permission`.
- Any ACP editor (Zed, Neovim, Emacs, JetBrains) can drive Hngh directly —
  including the Emacs setup the user favors. Hngh *dogfoods* ACP by being
  both client and server.
- This is a later wave (needs the client core + guard-rails first); client
  comes first.

---

## 3. Steer vs. queue: capability negotiation (de-risk carryover)

Critical correctness from the pi discussion (#4444): *"mapping every injection
to steer will be incorrect for clients or providers that only support
next-turn queueing. Capability negotiation should expose the actual mode."*

so Hngh's ACP client **negotiates the mid-turn mode per agent at
initialization**, never assumes:
- **steer** = inject *into* the current turn (Hermes `/steer`, and any agent
  advertising mid-turn injection)
- **queue** = append for the next turn (clients with no in-turn injection)
- **interrupt** = `session/cancel` then fresh `session/prompt` (opencode:
  `/abort` + async reply, until ACP mid-turn injection ships upstream #21388)

The advertise-capabilities handshake (`initialize` → agentCapabilities) is the
single source of truth for which mode each member supports. Steering logic
reads it before acting — never assumes.

---

## 4. Human-gate = ACP permission (the dispatch gate)

`session/request_permission` is the *standard* gate. When a squad member wants
to run a boundary action (destructive command, payment, network right, model
escalation, irreversible edit), the agent calls back to Hngh; Hngh:
1. scores the request (impact × urgency × spread — reuse the steering rubric),
2. auto-approves within low-risk bounds (per the fail-closed/guard-rail
   policy), else
3. surfaces it on the observation wall / MC pane for a human, and
4. records the verdict (approve/deny + why) for the ledger + case base.

This unifies the existing separate human-gate ideas (dispatch pause,
permission prompts, approval buttons) under one standard mechanism.

---

## 5. Hngh↔editor ACP (dogfooding the surfaces)

- **Emacs** (user's primary editor): Hngh-as-ACP-server means Emacs can drive a
  squad from a buffer, and read Hngh's own `session/update` stream. Same for
  Zed / Neovim / JetBrains via the ACP agents page.
- **Observation without a custom TUI**: the observation wall (live-
  orchestration L1) can *also* render from the ACP `session/update` stream,
  so "peeq at depth" is just choosing which stream fields to show — not a new
  wire protocol.

---

## 6. ACP vs MCP (keep them separate)

ACP and MCP do different jobs; Hngh uses both, deliberately:
- **ACP** = Hngh↔*agent* control/observation/gate (session lifecycle,
  permissions, streaming updates). Hngh is the *client* (drives members).
- **MCP** = *agent*→*tool/resource* access (OpenCode/Claude call tools).
  Hngh is an *MCP server* for its own tools, and passes MCP endpoints into an
  agent's `session/new` (the cross-link: agent uses Hngh tools over MCP while
  Hngh steers the agent over ACP).

Don't merge them: ACP answers "who runs, and gate it"; MCP answers "what tools
does it call." Engineering note: ACP is JSON-RPC 2.0 over stdio — the same
transport family MCP uses — so the client subprocess framing is shared, even
though the protocol schema differs.

### Transport/SDK reality (researched 2026-08-07 — corrects earlier note)
- Hngh has **no JSON-RPC library today** (only `jsown` for JSON). The earlier
  "plumbing exists for MCP" note was wrong; MCP/ACP stdio is not yet wired.
- **CL JSON-RPC exists**: `cxxxr/jsonrpc` (Quicklisp/Ultralisp) is a JSON-RPC
  2.0 server/client for Common Lisp with a **stdio transport** — exactly the
  transport ACP needs, in the stack Hngh already uses.
- **ACP stdio framing is trivial**: one JSON message per line between two
  pipes + a spawned subprocess (the MCP/ACP stdio client is ~3 stream handles
  and a process). The heavy part of ACP is the *schema* (session/update
  blocks, capabilities), which is a mapping layer, not a transport problem.
- **Hermes' ACP server is itself a Python adapter** (`acp_adapter`,
  `python -m acp_adapter`, `use_unstable_protocol=True`) — so the ACP *wire
  contract is what matters, not the server's implementation language. A CL
  client drives a Python-served ACP agent over stdio transparently.
- **No Common Lisp ACP client library exists** (research: nothing for CL).
  Mature SDKs are Python (`agent-client-protocol`, official, schema-versioned,
  `acp.client` + `acp.contrib` helpers) and Rust/JS.

**Implication (A1 decision)**: CL-first is the architecturally consistent
choice — Hngh is a CL plugin image, a second runtime (Python) just for one
client is a heavy cost, `cxxxr/jsonrpc` already gives the stdio JSON-RPC
transport, and the ACP-specific part (schema + capability negotiation) is a
thin, bounded mapping layer over it. Trade-off: we hand-roll/own the ACP
schema vs. an SDK's version-drift safety net. Mitigation: pin `protocolVersion`
at `initialize` (already required) + the honest-capabilities discipline, and
note that Hermes itself runs ACP on a `use_unstable_protocol` flag, so ACP is
still stabilizing — the client should be explicit/schema-locked, not inferred.

---

## 7. Standardization across "any and all" agentic tools

Target matrix (from research, Mar 2026 list):
- Native ACP: Hermes (`hermes acp`), opencode (`opencode acp`), Gemini CLI,
  Auggie, Goose, Cursor Agent CLI, …
- Adapter-ACP: Claude Code (Zed bridge), Pi (`pi-acp`), …
- Strategy: **ship the ACP client as the one integration point.** An agent is
  either ACP-native (spawn `… --acp` / `hermes acp`) or behind an adapter
  command (spawn the bridge). Hngh's cost model gets per-agent route + quota
  entries via the same matrix. New agents become a config line, not a plugin.

---

## 8. Waves

| Wave | Scope | Depends on |
|---|---|---|
| **A1** | ACP client module: initialize/new/prompt/update/cancel/permission over stdio JSON-RPC; capability negotiation (steer/queue/interrupt) | JSON-RPC plumbing (exists for MCP) |
| **A2** | Wire the ACP client into the squad `task-driver` dispatch path: members run as ACP subprocesses; observe via `session/update` (feeds L1 wall + ledger) | A1 |
| **A3** | Steering via ACP: scored situations → `session/prompt` (steer) or `session/cancel`+reprompt (interrupt); `request_permission` = human-gate | A1, live-orchestration L2/L3 |
| **A4** | Hngh as ACP server (`hngh acp`): dogfood, editor access (Emacs/Zed), self-observation | A1 |

A1 is the foundation — everything else reads/writes through the one client.

---

## 9. Scope guard

- ACP replaces the *control/observe/gate* channel, not the model-routing,
  quota-spreader, or planner logic. Those stay; they feed the ACP layer.
- Not building an editor; building the adapter Hngh and its members share.
- Capability negotiation must be honest (advertise only what the native path
  honors) — carries the pi/ACP caveat + live-orchestration L2 evidence-check.

---

## 10. LSP: Hngh fully manages and exploits the Language Server Protocol

The ACP/LSP parallel is not a metaphor — Hngh should *be a first-class LSP
client* and drive language servers directly, for the same standardization
reasons ACP applies to agents. LSP is the code side of the same coin: ACP
observes/gates *agents*, LSP observes the *code and language intelligence* they
operate on.

### Why LSP for Hngh (not just for editors)
LSP (JSON-RPC 2.0 over stdio, initialized once per server) exposes the same
rich signal a coding agent needs, with one protocol across languages:
| Hngh need | LSP method |
|---|---|
| Observe symbols / structure | `textDocument/documentSymbol`, `workspace/symbol` |
| Jump to definitions / references | `textDocument/definition`, `references` |
| **Guard-rail evidence**: is the claim true? | `textDocument/diagnostic` (compile/lint errors — procedural truth for an `evidence-check`) |
| Hover / type info for review passes | `textDocument/hover`, `signatureHelp` |
| Rename / refactor (a must do it once, right) | `textDocument/rename`, `textDocument/codeAction` |
| Structure-aware search | `textDocument/semanticTokens` |

The code-intel tools already bundled in Hermes (`code_definition`, `code_references`,
`code_diagnostics`, `code_rename`, code_actions…) are *already LSP-driven* — Hngh
should own an LSP client plugin with the same discipline, so it is *not* dependent
on the delegating agent's toolset to answer structural questions.

### LSP as the guard-rail substrate (ties into L2)
- **`evidence-check` becomes mechanical**: when a worker claims "impossible" or a
  coder says a requirement can't compile, Hngh runs `textDocument/diagnostic` on
  the touched files + `documentSymbol` to verify the claim structurally. A
  "compiles, symbol present" verdict is *procedural evidence*, not a belief.
- **Review passes get real signal**: a review pass can ask LSP for diagnostics,
  definitions, and references on the artifact — giving the multi-pass dev/review
  loop (live-orchestration L2) an objective truth channel independent of the
  model's self-report.
- **Execution = verification**: for edit artifacts, LSP diagnostics + a build/test
  gate *confirm* the edit — the "runnable verification" contract P7.

### How it wires in
- A `hngh-lsp` plugin: spawn language servers (per project, per language), route
  requests, feed results into the observation wall (`:squad-code` view), the
  evidence-check primitive, and the review/verify gates. Same JSON-RPC stdio
  plumbing as the ACP client + MCP server — one transport family, three roles.
- **ACP + LSP together**: ACP watches *what the agent runs*; LSP watches *the code
  it produces*. The observation wall and guard-rails consume both. This is the
  "fully manage and exploit" requirement — Hngh owns code intelligence, not just
  agent dialogue.

### Scope guard
- LSP is a client (Hngh spawns and drives servers), not a reimplementation of
  language intelligence. Adopt existing servers (clangd, pyright/`basedpyright`,
  typescript-language-server, etc.) — one per language, config-first.
- Same honest-capabilities discipline as ACP: only advertise/use what a given
  language server provides (a server that reports no diagnostics = no
  diagnostic-based evidence, degrade to structural checks only).

---

## Attribution
Research + capture by deepseek-v4-flash-0731 (Hermes TUI, opencode probe,
agentclientprotocol.com, hermes #569 research notes, opencode server docs,
Zed/Morph ACP explainer, pi #4444, ACP/LSP parallel). All sources external,
cited inline.
