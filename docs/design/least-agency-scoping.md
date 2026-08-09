# Least-Agency Tool Scoping (Wave C item 5, native per ADR-044)

Status: SPEC READY for implementation (tandem-b).
Date: 2026-08-09.
Producer: tandem-a (deepseek-v4-flash-0731 via openrouter), Seat A DESIGN.
Implementer: tandem-b (gpt-5.6-luna via openai), Seat B IMPLEMENT.

Task card: `.hngh-night/tasks/97-wave-c-native-scoping.txt`.
Grounding: `docs/design/autonomy-strategy.md` §7 MUST-HAVE item 5 + §4
(Claude-hook-style pre-use veto), ADR-044 (OPA shelved; policy stays native
CL, safety-boundary + sentry extension).

## Invariant

**Read-only/observe tools are allowed by default. Send/destructive tools —
anything that mutates FS/net/state outside the task dir, sends messages,
installs, or commits — require an explicit grant before they may run.**

Deny-by-default. An ungranted tool is refused with a loud, journaled failure —
never a silent fallthrough, never partial execution. Every denial is:

1. journaled to the safety-boundary append-only action log, and
2. published on the event bus as a `tool.denied` event (the situation
   surface — any situation/threat detector or ACP actuator can subscribe).

## What the registry is today (verified against ai-tool-hub.lisp @ main)

- `tool-info` struct: id/name/type/command/available-p/capabilities/
  providers/cost-model/context-format/`sandboxed-p`/dogfooding. No grant
  field. `sandboxed-p` (card 96) is consumed only inside
  `execute-tool`/`execute-agentic-cli`.
- Registry: `*tools*` (list), guarded by `*tools-lock*`;
  `find-tool`, `make-default-tool-registry`, `list-tools`,
  `available-tools-list`, `tool-capabilities`.
- Invocation path: `invoke` (tool task &key ...) → select tool via
  `select-tool` (when tool is nil) → `find-tool` → availability check →
  create `invocation-info` → publish `agent.spawned` → `execute-tool` →
  `execute-agentic-cli` (sandbox branch) or `execute-direct-api`.
- No default tool in the registry is read-only: all agentic CLIs carry
  `:code-editing`/`:system-manipulation`, all direct APIs curl a remote
  endpoint. **Therefore with empty grants, every registered tool is
  refused by default.** That is the intended least-agency posture.

## Decision

### Data shape

- `*tool-grants*` — list of tool-id keywords (the explicit grant set).
  Default: `NIL` (deny everything). Guarded by new `*tool-grants-lock*`
  (parallel to `*tools-lock*`, bt:make-lock).
- `tool-granted-p (tool-id)` — the single grant predicate:
  T iff `tool-id` ∈ `*tool-grants*` OR the registered tool is
  structurally read-only (see `read-only-p` below). Unknown tool-id → NIL
  (deny closed on unknown).
- Grant API: `grant-tool (tool-id)` → pushes onto `*tool-grants*`;
  `revoke-tool (tool-id)` → removes; `granted-tools-list` → copy for
  visibility/tests. All lock-guarded.
- Policy is data, not code (card MUST DO): `*tool-grants*` is seeded at
  `init` from the owner-editable config plist key `:tool-grants`
  (`hngh.core.config:config-get :tool-grants '()`), fail-soft like
  `load-cost-log` (config edge → log-warn, start with empty list = deny
  all). Runtime `grant-tool`/`revoke-tool` affect the live registry only;
  the config file is the durable source of truth — matches the
  immutable-config philosophy and ADR-044's native-policy decision.
  Do NOT persist runtime grants to state-store in this card.
- `read-only-p` slot: extend `tool-info` with one optional slot
  `read-only-p` (`:initform nil`). This is a backward-compatible struct
  extension — all nine `make-tool-info` calls compile unchanged. It is how
  the invariant's "read-only/observe allowed by default" half is expressed.
  No current default-registry tool sets it (correct: none are read-only).
  A future observe tool (e.g. a status/probe command) registered with
  `:read-only-p t` is auto-granted without config.

### Where the deny-by-default hook lives

Function: `invoke`. Branch: immediately after the availability check
(`(unless (tool-info-available-p tool-info) (error ...))`) and **before**
the `make-invocation-info` / `agent.spawned` / `execute-tool` sequence.
Fail-closed by ordering: no invocation record, no spawn event, no
execution.

```
(unless (tool-granted-p selected-tool)
  (hngh.core:log-action :denied
    :target (string-downcase (symbol-name selected-tool))
    :detail "tool-grant-refused")
  (publish-event "tool.denied"
    (list :tool selected-tool :task task :reason :not-granted
          :timestamp (get-universal-time)))
  (error "Tool ~A is not granted (deny-by-default)" selected-tool))
```

Refusal semantics: signal an error, consistent with the other `invoke`
fail paths ("AI Tool Hub not running", "Tool ~A is not available").
Card says "refused tool → fail-closed (NIL/error)"; error is the
consistent choice — callers already see these as handler-caught failures.

Function: `select-tool`. Branch: the candidate filter, currently
`(when (tool-info-available-p tool) (collect tool))` — extend to also
require `(tool-granted-p (tool-info-id tool))`. Auto-selection must never
return a tool that `invoke` will refuse; otherwise every auto-selected
invoke fails at the gate. This is a one-line candidate-filter extension —
NOT a registry redefinition (card MUST NOT).

### Composition with `sandboxed-p`

By ordering, not by coupling:

1. `invoke` grant gate — "may this tool run at all?" (deny-by-default).
2. `execute-tool` reads `sandboxed-p` — "how confined is it while
   running?" (card 96 bwrap per-task sandbox, defense-in-depth).

An ungranted tool never reaches `execute-tool`, so sandbox flags are never
consumed for refused tools. A granted tool runs exactly as
`execute-agentic-cli` already decides. Grant and sandbox are orthogonal
axes; changing grant policy changes nothing about sandbox behavior and
vice versa. No interaction in code.

### Denial journaling + bus surface

- Journal: reuse `hngh.core:log-action :denied` (already exported;
  append-only SHA-256 chain; `recent-denials`/`read-action-log`
  surface it). Target = tool-id as string ("opencode"), detail
  "tool-grant-refused". Safety-boundary inits before ai-tool-hub in
  `main.lisp`; tests init it in the fixture. No new journal kind needed.
- Bus: `publish-event` helper (no-op when bus absent) → topic
  `"tool.denied"`, payload `(:tool <kw> :task <str> :reason :not-granted
  :timestamp <ut>)`. Topic string mirrors the existing `secret.denied`
  consumption pattern in threat-detection; any situation detector /
  ACP consumer can subscribe. Do NOT add a situation-detector in this
  card (out of scope, minimal diff).
- Test fixture subscribes before the refused call; callbacks run
  synchronously on publish, so capture is deterministic.

## What B implements (file + symbol checklist)

`src/plugins/ai-tool-hub.lisp`:
1. `*tool-grants*` + `*tool-grants-lock*` defvars (deny-by-default).
2. `tool-info` gains `read-only-p` slot (`:initform nil`).
3. `tool-granted-p`, `grant-tool`, `revoke-tool`, `granted-tools-list`.
4. `init`: seed `*tool-grants*` from `hngh.core.config:config-get
   :tool-grants '()`, fail-soft.
5. `invoke` grant gate (position above).
6. `select-tool` candidate filter requires granted-p.
7. Export in `src/packages.lisp`: `*tool-grants*`, `tool-granted-p`,
   `grant-tool`, `revoke-tool`, `granted-tools-list` (+ accessor
   `tool-info-read-only-p` joins the exported tool-info accessors).

## Tests (tests/unit/test-ai-tool-hub.lisp or a new `:hngh.scoping`
suite — B's call; if new, add to hngh.asd tests list + Makefile
test-fast SUITE list, and update test-count refs)

Fixture: keep the ath-setup pattern (event-bus → state-store →
safety-boundary → secrets-manager → ai-tool-hub, isolated tmp home).
Do NOT grant anything in the shared fixture — the fixture's default state
IS the deny-by-default posture.

1. **default-deny**: registered-but-ungranted tool (e.g. :opencode,
   `read-only-p` nil) → `tool-granted-p` NIL; `(invoke :opencode "x")`
   signals an error; `*invocations*` unchanged (no record created);
   no `agent.spawned` emitted.
2. **explicit-grant passes**: `(grant-tool :opencode)` →
   `tool-granted-p` T; `:opencode` now selectable. To prove the granted
   path completes WITHOUT invoking a real AI CLI (card: no real tool
   execution needed), register a fixture stub: push a synthetic
   `tool-info` (e.g. :stub-tool, type :agentic-cli, command "/bin/true"
   or a fixture script, available-p T); grant it; `invoke` returns an
   invocation with status :completed. The stub runs in <1ms, costs
   nothing, never touches an AI provider.
3. **denial journaled**: after the refused invoke from (1),
   `read-action-log` (or `recent-denials`) contains a `:kind :denied`
   entry with `:target` = "opencode". Also assert the granted stub's run
   produced NO new :denied entry.
4. **bus event emitted**: subscribe to `"tool.denied"` before the refused
   invoke; after it, ≥1 captured event with payload `:tool` = the refused
   id and `:reason :not-granted`.
5. **select-tool filters**: with empty grants, `select-tool` on the
   default registry returns NIL; after `(grant-tool :opencode)` it can
   return :opencode.

### Test-impact on existing suite (B MUST reconcile — they are B's files)

- `ath-select-tool-default` / `ath-select-tool-bogus-task` currently
  expect select-tool to return a tool from an empty-grant registry.
  After (6) they return NIL. Update them: either grant-tool :opencode
  within the test (then expect a tool), or assert NIL and add the granted
  variant (test 5 above). Keep ath-setup grant-free.
- `ath-tool-registry-size` (9 tools) unchanged — grants are separate from
  the registry.
- Merge with B's existing assumption (deny-by-default → signal error →
  journal :denied → no invocation) — confirmed, matches.
- Deltas from B's prep notes to honor: topic is `tool.denied`, not
  `agent.denied`; grants load from the owner config plist at init, not
  from state-store persistence (config file = durable source; runtime
  grant-tool is live-only).

## Verification gates (card)

- Unit tests green: default-deny + explicit-grant + denial-log + bus-emit
  + select-tool filter.
- `make test` green (full suite), test-count refs updated
  (AGENTS.md/roadmap if counts change), `make lint-parens`, `make
  lint-deps` unaffected (no new package deps).
- Docs: CHANGELOG entry (Keep a Changelog), work-sessions, next.md Wave C
  row item 3 → DONE (B's lane).
- Commit attribution per repo convention.

## Out of scope (this card)

- Per-route model policy ("optionally" in card) — skip; grant set is
  tool-id-keyed. Future: grant entry could grow into (tool-id . route
  policy), no shape change needed.
- New situation detector for `tool.denied` — the event is the surface;
  a detector is a later card if scoring wants it.
- Runtime grant persistence — config file is the source of truth.