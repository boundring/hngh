# Message Coordinator (hngh-coord) — squad coordination plane

**Status**: design; card 101. **Layer**: Wave C / Hngh squad substrate.
**Owner directive 2026-08-09**: any-number-of-agents coordinator MCP — a
crucial Hngh component, not scratch infra.

## 1. Why (what failed, what this is not)

The first tandem (brief-based, card 97) delivered. The ACP-driven director
(v2) failed as a control plane: `hermes acp` is a single-editor session
server; driving our own sessions through it meant fighting IDE-integration
ceremony (caps negotiation, `mcpServers` param, content-block payloads,
prompt-as-request) and the briefs never landed. Verdict (M9.37):

- Seats are **normal Hermes sessions** — full TUI, normal interactivity.
- **ACP is a client protocol** for speaking to *external* agents (hngh's
  `acp-client.lisp`, A1–A4, interop-verified).
- Coordination between our own agents goes through a **shared server** they
  message — not a process that drives them.

hngh-coord is that shared server: the coordination plane under squads of
N agents. It is NOT a control plane (no session driving, no process
parentage). It is the auditable channel through which Hngh's autonomy loop
(L2/L3 situation detectors, C6 planner) will observe and steer agents.

## 2. Two faces, one store

```
  seat A (Hermes, MCP client) ──┐
  seat B (Hermes, MCP client) ──┤      ┌─────────────────────────┐
  seat C (Hermes, MCP client) ──┼────▶ │  hngh-coord             │
                                │      │  • MCP face (tools)     │── store:
  hngh acp-client / external ───┼────▶ │  • ACP face (newline)   │  ~/.hngh-night/coord/
  ACP peers                     ─┘      │  • one append-only      │  messages.jsonl
                                        │    jsonl store          │
                                        └─────────────────────────┘
```

- **MCP face** — what running Hermes sessions use. Native MCP tools
  (`mcp_hngh_coord_*`), registered like misakanet. This is the channel the
  v2 experiment was missing: seats coordinate through tools in their own
  session, no protocol ceremony.
- **ACP face** — what protocol-level clients use (hngh's `acp-client.lisp`,
  future external agents). Same store; ACP `session/prompt`-style messages
  land as coordination notes. This satisfies "agents interact with the
  coordinator via ACP" for clients that speak ACP natively.

One store, two transports. Framing is protocol-specific and NOT
interchangeable (mcp-server-setup reference, the 2026-08-08 ACP lesson):
- MCP: Content-Length headers + body (LSP-style)
- ACP: newline-delimited JSON, one message per line, no embedded newlines

## 3. Store

Append-only jsonl at `~/.hngh-night/coord/messages.jsonl`. Each line:

```json
{"ts": 1234567890, "from": "A", "to": "B", "kind": "question|note|steer|state|review",
 "body": "free text", "id": "coord-0001"}
```

- `to` may be `"*"` (broadcast).
- Compatible with the tandem inbox/outbox convention and readable by the
  card-94 hash-chain (`verify-action-log`) for audit — the coordinator is
  not a command channel, so no execution gating here; seats decide (card-97
  grants gate tool execution).

## 4. MCP tools

| tool | args | purpose |
|---|---|---|
| `register` | `agent_id, role` | join the squad; agent_id from env/argv default |
| `post_message` | `to, kind, body` | deliver to agent's inbox (or `*`) |
| `read_inbox` | — | messages addressed to me, oldest first, mark read |
| `status` | — | coordinator view: agents, open cards, last activity |
| `steer` | `agent_id, text` | operator/peer-initiated coordination note |

Agent identity: `HNGH_COORD_AGENT` env or `--agent` argv; the coordinator
records first-seen + last-seen per id.

## 5. Agent lifecycle + coordination protocol

1. **Register** on start (`register(agent_id, role)`) → appears in `status`.
2. **Message** peers (`post_message`) — conversational and strategic:
   questions, notes, review requests, state updates.
3. **Read inbox** between work phases — poll `read_inbox` before/after each
   unit, same discipline as the tandem inbox/outbox but tool-native.
4. **Steer** — operators or the autonomy loop inject coordination notes;
   seats treat `steer` like the tandem STEER: convention (authoritative
   operator direction).
5. **Status** — the loop (L2/L3, C6) reads `status` as an observation
   surface: who's alive, who's stalled, what's open.

## 6. I/O shape (both faces)

- Register/probe: `initialize` (MCP) / ACP `initialize` — capability
  negotiation per face.
- Message routing is by `to` field; `read_inbox` returns only my mail.
- Errors are JSON-RPC errors; malformed frames fail closed (log + error
  response, never crash the server).

## 7. Verification gates (card MUST DO)

- Framing regression tests BEFORE any client wiring:
  `tests/scripts/test-coord.py` — MCP Content-Length compose/parse, ACP
  newline round-trip, post→read routing, multi-seat, register→status.
- `hermes mcp list` connected + `hermes mcp test hngh-coord` real output.
- Probe ACP client (newline JSON) → post → MCP client read → in store.
- `make test` green (pytest hooked into test-suite).

## 8. Future (not this card)

- Hngh's L2/L3 detectors consuming `status` + inbox as observation feeds.
- C6 planner posting cards/specs through `post_message`.
- Hash-chain audit over the coordinator store (card 94 `verify-action-log`
  already handles jsonl journals).
- Web/API face if a remote squad needs it (not now — local-first).