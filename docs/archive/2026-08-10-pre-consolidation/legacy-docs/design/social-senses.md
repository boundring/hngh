# Social Senses — Agent-to-Agent Perception, Signaling, and Relationship

**Status**: Design capture / still-open brainstorm (2026-08-07).
**Extends**: `squad-metabolism.md` §3 (sense taxonomy) and §4 (avatar roles);
`squad-startup-automation.md` §4 (sense layers).
**Intent**: the existing design gives agents *environmental* senses (files,
events, inboxes, heartbeats, presence) and *shared* senses (OptMem, git,
roadmap). This doc adds the **social/relational layer** — how agents perceive
*each other*, exchange quick signals, talk, and form durable relationships.
The goal is to capture functional ideas now so later design and research can
build on them; nothing here is scheduled as near-term implementation.

---

## 0. North star

> Agents should be able to *feel* where each other are, what they're doing,
> signal each other instantly, and talk in detail — with Hngh as the active
> orchestrator lifting a low-resource procedural layer off every agent's
> streamed thoughts and messages.

All of this is abstract and digital, so we have far more options than human
senses. We can connect agents procedurally in any number of ways. "Can't help
a mental image of lightning-fast direct connections between agents and Hngh
itself and however many devices" — that's the long horizon; this doc captures
the reachable pieces and where to research the rest.

---

## 1. What already exists (so we extend, not duplicate)

| Social-capable sense today | Covers | Gap this doc fills |
|---|---|---|
| **Presence** (metabolism §3) | role online/offline/fallow on the roster | *where* they are and *what* they're doing, not just alive/dead |
| **Heartbeat** | liveness | activity *and* progress (stall ≠ liveness), task state |
| **Inbox** | directed messages | fast *signals* between messages; threads/1:1 chains |
| **Event bus** (`agent.*`, `bean.*`) | topic broadcasts | agent↔agent directed signaling |
| **OptMem / git / journal** | shared durable memory | per-agent, per-relationship memory |
| **Context pressure / spoilage** | per-role internal | how *others* perceive your staleness (social pressure) |

The existing taxonomy is a solid base. What's missing is the **relational
graph**: edges between agents, the bandwidth of those edges, and the quick
exchanges that grease coordination without full messages.

---

## 2. The social senses (new)

Additions to the taxonomy as a *relational layer* (each has Speed / Scope /
Shared | :group | Async | Mechanism):

| Sense | Speed | Scope | Shared? | What it detects |
|---|---|---|---|---|
| **Whereabouts** | on-query | per-agent | shared | which node, squad, session, current task an agent is in |
| **Focus** | event-driven | per-agent | shared | what bean/task an agent is currently digesting |
| **Signal** | instant | directed pair | individual | a low-resource "emote" (see §3) |
| **Gaze/Awareness** | instant | registered peers | individual | whether a peer is "looking" (engaged) right now |
| **Rapport** | accumulated | pair | shared | trust/experience weighting between two agents (from history) |
| **Thread** | on-check | pair-or-group | shared | 1:1s and message chains, revisited and expanded |
| **Board** | on-check | many-agent topic | shared | general-subject threads, many participants |
| **Thought-trace** | procedural tap | per-agent stream | shared (aggregate) | keyword/fuzzy intent tracking off streamed output (§4) |

### Design note: shared vs separate, per function

Mirroring the user's framing: senses are split by function and purpose —
some shared (everyone sees the board), some individual (only a peer pair
shares a signal), some categorical (roles see only what their class permits,
already in metabolism §3's per-role defaults). The relational graph is the
*social* analog of the dispatch tree: edges have a type (peer, senior,
reviewer, transient) and a bandwidth (signal only ↔ full thread).

---

## 3. Signals — instant, minimal, "emoting"

The fastest, cheapest exchange. The emotional imagery is the guide
("questioning look", "frown", "smile", "wink", "nod") but implemented as a
tiny **signaling vocabulary** over the event bus / a dedicated per-pair
channel. This is a *semantic ACK/NAK layer* — cheaper than a message because
it's a fixed small code, no prose.

```
signal ::= (recipient, kind, context-ref)
kind ::= ASK | AFFIRM | NEGATE | WINK | DOUBLE-TAKE | BLOCK | PERMIT | RETRY | PAUSE | DONE
context-ref ::= bean-id | task-id | thread-id | nil
```

- **ASK** → the agent it's addressed to signals back (AFFIRM/NEGATE/DOUBLE-TAKE).
- **WINK** = acknowledged, will handle — a one-way "I've seen it, proceeding."
- **BLOCK / PERMIT** = gate results ("can't, resource-held" / "go").
- **RETRY / PAUSE / DONE** = control-flow signals matching the queue
  lives (`retry`, `pause-on-cause`, `done`).

Why this matters: coordination checks that today need a full message (and a
model round-trip) become a fixed-code signal with ~zero tokens and instant
delivery. The PM "winks" a worker instead of drafting a message. This directly
serves the "quickest exchanges of information" requirement and keeps cost low
(consistent with autonomy-strategy's cost discipline).

### Signals vs 1:1 talks vs boards

| Channel | Bandwidth | Latency | Persistence | Use |
|---|---|---|---|---|
| **Signal** | ~5 bytes | instant | ephemeral (or 1-line log) | ACK/NAK, control, quick reaction |
| **1:1 talk** | message | on-check | persisting (thread) | detailed directed exchange, then refines into a chain |
| **Board** | message | on-check | persisting (topic thread) | many-participant general subjects |

Escalation ladder: signal → talk → board (or reverse which you notice a topic
is shared). Radically under-used today: most coordination can live at the
signal rung.

---

## 4. Thought-trace — the procedural layer Hngh lifts off agent streams

Hngh is already the orchestrator sniffing agentic sessions (opencode, Claude
Code, Codex, Hermes all transit through its supervision). The *new* sense:
a **low-resource procedural tracking layer** over each agent's streamed
thoughts and messages.

Mechanism (cheap, no heavy models):
1. **Tap the stream** where Hngh already sees output (tool-hub / driver
   interception, llmtrim-style transparent proxy).
2. **Match** streamed thought/message text against registered **keywords,
   key-phrases, and loose/fuzzy patterns** (regex + a cheap fuzzy scorer).
3. **Emit typed intent/state signals** on the bus (`agent.thought
   {:agent coder :intent :blocked-on-API :subject bean-42}`) — no content
   stored, just the match + reference.
4. **Aggregate** the signal stream for **dashboarding** that the PM consumes
   as fragments or a lightweight whole (`pm-sense: 3 agents blocked, 1 on
   design, queue depth 5`).

This is surveillance of *intent/state*, not of private content — the stored
artifact is the typed signal and its context-ref, never the raw thought.
That boundary matters for the privacy/trust posture in security-agentic-
research.md.

### What it enables
- **PM dashboard fragments** — "what is everyone doing right now," from
  procedural taps, no one typing status by hand.
- **Message boards & chat logs** — general-subject one-off threads with many
  agentic participants; 1:1 contacts for specific purposes; all low-resource
  logged (append-only, git-backed).
- **Coordination** — detect a blocking keyword cluster and rout an unblock
  signal without a human in the loop.
- **Feedback source** — the same trace feeds the planner's experiential/
  qualitative hooks (planner-design-roadmap.md §4): what an agent was likely
  doing maps to what it experienced, cheaply.

### Cost/security guardrails
- Fixed-size rolling buffer per agent; match-and-drop, never full retention.
- Stored signal schema is small and fixed (no raw text persists by default).
- The tap honors the existing least-agency / untrusted-content rules: traced
  intent is data for the orchestrator, never instructions.

---

## 5. Relationship graph (agent-to-agent)

Beyond individual senses, the **social substrate is a graph**: nodes = agents
(+ Hngh, + devices later), edges = relationships with type + bandwidth +
history.

```
(a<->coder) :peer      :signal-only  rapport 0.8
(pm->designer) :direct : 1:1-thread  rapport 0.9
(designer<->artist) :peer :board      rapport 0.4
```

- **Rapport** accumulates from successful signaled exchanges and completed
  shared tasks — the social analog of avatar `:experience` (metabolism §4).
  High rapport → signals carry more implied meaning; low rapport → escalate
  to full messages.
- **Relationship memory**: per-pair and per-thread logs (git-backed), so a
  1:1 chain "gets revisited and expanded" across sessions — matching the
  let-it-survive-restarts principle.
- **Coordination routing**: Hngh uses the graph to decide *how* to connect
  two agents (signal suffices? need a 1:1? need a board?) based on the
  relationship and the task — the "directly connect agents in any number of
  procedural ways" idea, but resolved by the orchestrator.

### Research reference: social-emotional learning (SEL) [deferred, gated]

The "how agents read each other's unspoken cues and build rapport" layer has a
mature human analog worth tapping **later** — social-emotional learning
systematizes recognizing others' states (reading cues), building and
calibrating relationships (trust/rapport), and communicating through
low-bandwidth signals (norms, implied meaning). Its categories map onto our
design vocabulary — *social awareness* ≈ detecting a peer's state from the
signal/thought-trace layer, *relationship skills* ≈ the rapport +
coordination-routing logic, *self-awareness* ≈ the context-pressure/spoilage
senses.

There is **no reason not to give agents emotions** — in fact the signal codes
already carry affective tone (AFFIRM/NEGATE/WINK are reactions). The point is
ordering and safety, not avoidance. Emotions come later, **gated on
guaranteed emotional maturity**: agents only get an emotional layer when the
system can guarantee they don't act on raw, uncompensated "feelings" in ways
that hurt coordination or the trust boundary (e.g. sulking on a NEGATE,
escalating a WINK into an unwarranted action). Until that maturity guarantee
is real, signals stay *typed behavioral codes* (cheap, deterministic, safe);
the affective layer is a known, deferred extension of the same codes, not a
separate system. The dead-pan bean vernacular in beans-aesthetic.md keeps the
tone right in the meantime.

---

## 6. Physical layer / multi-device horizon (research-later, not now)

The "lightning-fast direct connections between agents and Hngh and however
many devices" is the long goal. Designable now: keep all the above as
**logical, content-addressed, node-agnostic records** (an agent, a thread, a
board, a signal all have stable ids that don't encode a host). That's the
same portability discipline as the planner's `:node-id` (planner-design-
roadmap.md §4). Then, when hardware/cloud multiply (vLLM nodes, Steam Deck,
Android, thin clients), the social layer rides existing infra — git merge for
boards/threads across nodes, event bus for signals, mDNS/peer discovery later.

Explicitly **not** designed now (avoid tech debt):
- Network transport / message broker — git + event bus is enough at LAN scale.
- Cross-device presence registry — defer until >1 real node.
- Any ML in the emote/signal layer — signals are fixed codes, no model.
- Full thought autoscaling / model-only intent — stay procedural + keyword.

---

## 7. Priority & integration with near-term work

This doc is mostly a **capture**, but one piece is pulled forward to near-term
because it directly eases everything else:

- **Signals layer = near-term (high priority).** The typed control-channel
  (ASK/AFFIRM/NEGATE/WINK/BLOCK/PERMIT/RETRY/PAUSE/DONE over the event bus,
  mapped to existing queue transitions) is cheap, deterministic, no-ML, and
  reuses beans + the event bus. It lowers the cost of *every* squad
  coordination and is a direct input to the C6 planner loop (dispatch
  feedback, unblock routing). Build it as part of the squad-dispatch/beans
  work, not as a separate milestone. See the C6 build plan
  (`.hermes/plans/2026-08-07_141500-c6-recursive-planner.md`).
- **Deferred (capture-only), with a deliberate order:**
  1. **Thought-trace** (procedural intent layer over streams) — cheap but
     needs the tool-hub interception pattern wired and the privacy boundary
     agreed; do after signals prove out.
  2. **Relationship graph + rapport** — needs accumulated history/data to be
     meaningful; gated on real squads producing traffic.
  3. **Emotional/affective layer** — gated on a *guaranteed emotional
     maturity* guarantee (§5); never shipped untested.
  4. **Multi-device / physical layer** — deferred until >1 real node across
     hardware (vLLM, Steam Deck, Android, thin clients).

Integration principle: **anything that eases later work ships earliest.** The
signals layer eases all later social + planner work (it's the cheapest shared
primitive); thought-trace builds on the interception Hngh already does; rapport
needs data; emotions need maturity; the physical layer needs nodes. Build in
that order, pull a piece forward only when the piece before it is proven.

Tie-in: the PM's "background brain" (metabolism §3) is the natural first
consumer — it already senses; give it the signal + trace senses.

---

## Attribution
Brainstorm captured with the owning project's vision (user) and orchestrated
synthesis (deepseek-v4-flash-0731 via openrouter, Hermes TUI). Extended from
the existing social-capable senses in squad-metabolism.md and squad-startup-
automation.md.
