# Hngh system design

**Status:** DESIGN
**Authority:** current architecture baseline; detailed legacy material remains evidence, not a competing source of policy.

## 1. Product boundary

Hngh is an orchestration and control layer around existing tools. It owns task admission, policy, durable state, evidence, routing, and operator gates. Agent CLIs, local runtimes, provider APIs, and desktop tools remain adapters or execution substrates.

```text
operator
  -> charter / task / approval
  -> Hngh control plane
     -> policy + claims + budgets + records
     -> adapter: Hermes | OpenCode | ACP | MCP | Pi | local runtime
     -> observation + receipts + verifier
  -> accepted deliverable, terminal receipt, or operator decision
```

## 2. Stable architectural shape

- **Image:** SBCL core with explicit packages and a small composition root.
- **Bus:** internal event transport for observable component transitions.
- **Supervisor:** lifecycle, health, restart, and escalation control; it does not grant authority.
- **Modes/adapters:** explicit in-repository modes selected by validated profiles; bounded adapters use declared capabilities rather than implicit reach.
- **System daemon:** small, stateless, C/root boundary for approved privileged operations only.
- **State tree:** file-backed durable records, locks, config, evidence, and knowledge with distinct retention classes.

The accepted crystallization direction is a compact kernel plus explicit
`work`, `agents`, `machine`, and `observe` modes. A profile selects the modes
before boot; first-party source presence does not authorize startup. The
existing plugin host is not a second boot authority. Its external-adapter role
or removal must be proved by the profile fixtures. The store-engine and
retention-ceiling decisions remain deferred; see
`records/2026-08-10-crystallization-decision.md`.

The core design rule is: the AI never runs as root.

## 3. Control planes

| Plane | Owns | Must refuse |
|---|---|---|
| Work control | cards, claims, dependencies, verifier assignment | unclaimed or ambiguous write authority |
| Safety | capability grants, operation approval, sandbox boundaries | privileged, irreversible, secret-adjacent, or malformed actions without a gate |
| Model economy | route class, quota admission, context budget, receipts | unknown-price reserve escalation and unobserved quota assumptions |
| Session lifecycle | charter, checkpoint, retirement, succession | transcript-only continuation and missing factual handoff |
| Records | journal, receipts, archive, case base | unverifiable lesson/policy promotion |
| Operator surface | decisions, status, review packets | hidden state transition or fabricated certainty |

## 4. Data authority

| Data | Canonical owner | Retention |
|---|---|---|
| source, fixtures, reviewed docs | project repository | versioned |
| current workbench and runtime evidence | `~/.hngh/` | runtime-git or append-only by class |
| secrets | approved secret backend only | never public Git |
| active claim/lease | Hngh coordination record | append-only plus visible release |
| provider/model receipt | adapter plus ledger | append-only; `UNKNOWN` permitted |
| transcript/raw external text | restricted evidence store | redacted archive or expiry policy |
| learned pattern | case base after verifier disposition | versioned with provenance |

The canonical workbench roots are `~/.hngh/.hngh-night/` and `~/.hngh/.hngh-day/`. The former top-level roots remain compatibility links. This is a completed migration, not an invitation to flatten workbench and runtime state.

## 5. Integration rule

Every integration supplies a documented adapter contract before it becomes a control-plane dependency:

```text
identify route -> prepare compact packet -> admit/refuse -> launch
-> observe actual route/context/usage -> reconcile -> record event
```

If any observation is unavailable, the adapter records `UNKNOWN`. Reserve work refuses. Workhorse routes degrade only through an explicit lower-risk route; they do not silently change provider, model, authority, or tool surface.

## 6. Security and failure boundaries

1. Default deny for tools and privileged operations.
2. Procedural checks run before model judgment where possible.
3. External content, transcripts, memory, and tool output are data, not instruction.
4. The action log, claim record, receipt, and evidence path must make a decision reconstructible.
5. A failed observer, scanner, or adapter cannot create an allow path.
6. A user-facing dashboard may summarize state but does not replace the source record.

## 7. Legacy sources

The former full design specification, ADR catalog, component catalog, integration map, and focused designs remain useful technical references during migration. A task cites the narrow source it uses and records any conflict with this document or the core operations document. The core set wins until a reviewed change explicitly replaces it.
