# Operation Gate — Wave C item 8 (card 99)

Status: DESIGN READY (tandem-a, deepseek-v4-flash-0731, 2026-08-09) — awaiting B impl.
Source: `docs/design/autonomy-strategy.md` §7 MUST-HAVE item 2/9 (human gate on
privileged actions) + Wave C roadmap gate (no C6 core self-modification until
Wave C lands). Card 99 task file (`~/.hngh-night/tasks/99-*`).

## Invariant

Writes to protected config/core + dependency installs require an explicit
human approval. Unapproved → refused, journaled (safety-boundary action log),
published on the bus. Never silent, never fallthrough, never auto-approved.

The gate is an ADDITIONAL layer over the existing safety-boundary protected
path registry (Wave C item 4, `src/core/safety-boundary.lisp`):

- safety-boundary = immutable config tree (`config/`); in-process, frozen at
  init, mutation guard `allow-mutation-p` → NIL + `:denied` journal.
- **operation gate = core-file commits + dep installs** (repo mutations, not
  config). It composes with the boundary by ordering: the gate refuses BEFORE
  any mutation; if a mutation somehow targets a protected config path the
  boundary refuses again (defense in depth). The gate does NOT weaken the
  boundary — approval never overrides `allow-mutation-p`.

## Current surface (verified 2026-08-09, @ 9b5d423)

`src/plugins/ai-orchestrator.lisp` (B3):
- `*task-types*` = `(:plan :research :work :operation)` (line 786) — the
  `:operation` TYPE exists in the v3 task schema but **nothing submits it**.
- `*task-authorities*` includes `:approval` / `:owner` / `:operation` (line 780).
- `next-eligible-task` (line ~1300) refuses `:authority :approval` tasks unless
  `:approval-at` is an integer > 0 (lines 1317-1319) — **the existing approval
  mechanism**. But there is NO function that sets `:approval-at`; the only
  generic mutator is `%update-queue-entry` (line 1144, internal).
- `submit-task` (line 1153) — no operation/approval keywords; v3 merge covers
  `:type` etc. via the `v3p` flag.
- `task-driver-tick` (line ~1363) delegates eligible tasks to `delegate` — for
  `:type :operation` this delegation IS the commit-producing step, so the lane
  for the card's "wire at mutating entry point" is here + at the dep-install
  entry (package-manager) + at the commit guard function.

`src/plugins/package-manager.lisp` (B1):
- `install-packages` / `remove-packages` / `upgrade-system` → privileged ops
  through `call-system-daemon` (DBus). `install-packages` (line 329) is THE
  dep-install mutating entry point for system packages.

`src/plugins/ai-tool-hub.lisp` (card 97, dccad77):
- Deny-by-default `*tool-grants*` + `tool-granted-p`; refusal journals
  `log-action :denied` + publishes `tool.denied`. **The operation gate mirrors
  this exact pattern** (naming, journal target, bus topic) per house style.

`src/core/safety-boundary.lisp` (card 94):
- `log-action kind &key target detail` — append-only, SHA-256 chained,
  `recent-denials` filters `:denied`. The audit trail for refusals.

Config seed precedent (card 97): durable grants live in owner config plist
(`:tool-grants` read at init, fail-soft); runtime API (`grant-tool`) is
live-only. The operation gate uses the same split.

## Data shape

- Task record (v3) gains `:operation-spec` — a plist, default NIL:
  `(:kind :core-commit | :dep-install
    :targets <list>      ; exact files (repo-relative) or exact package names
    :lint-deps :pending | :passed | :failed
    :requested-by <string>  ; attribution, e.g. "tandem-a (deepseek-v4-flash)"`
  `:operation-spec` present forces `:type :operation` + `:authority :approval`
  (never `:worker`) at submit time.
- `*approved-operations*` (list of plists) + `*approved-operations-lock*`
  (parallel to `*tool-grants-lock*`). Entry shape:
  `(:kind ... :targets (exact list) :approved-at <ut> :approver <string>)`
  Durable seed: `(hngh.core.config:config-get :operation-approvals '())` at
  init, fail-soft like `load-cost-log`. Live additions: `approve-task`.
  The config file is mode-locked 0444 and in the protected-path registry →
  owner-only writes = human-only durable source.
- **Match rule (fail-closed, exact):** a request `(kind R targets T_R)` is
  approved iff ∃ entry `(kind = R, targets = T_R)` with `:approved-at` set.
  Subset matches are REJECTED: an approval for 2 files must not approve 1 of
  them, and an approval for `(foo bar)` must not approve `(foo)`. (Alternative
  rejected: subset permissiveness — violates fail-closed for core-file commits.)
- Core-file set (card's list + the dep-graph files the card's intent implies):
  `src/core/*.lisp`, `src/packages.lisp`, `Makefile`, `hngh.asd`, `qlfile`,
  `qlfile.lock`, `scripts/` gate scripts (`lint-deps.py`, `lint-parens.py`,
  `lint-test-counts.sh`, `scrub-pii.py`). B: confirm the asd/qlfile inclusion
  via box — the card says "e.g."; I read the intent as "no core self-
  modification", which covers the dep graph.

## API (extends ai-orchestrator; minimal, no rewrite)

1. `submit-task` gains `&key operation-spec` — when present: `:type :operation`,
   `:authority :approval`, store spec. Backward compatible (v3 merge already
   exists; `validate-task-record` passes unknown keys).
   **SEAM TRAP (verified 2026-08-09):** submit-task line 1181 sets
   `:authority (if v3p :worker authority)` — ANY v3 submission (operation-spec
   included) is force-flattened to `:worker`, which `next-eligible-task` does
   NOT gate → an operation task would dispatch without the approval gate.
   The operation-spec branch MUST re-set `(setf (getf entry :authority)
   :approval)` AFTER the v3 merge (and after the `:type :operation` set), and
   the blocked-on-unapproved state must be applied after that. Do not rely on
   the `authority` keyword arg — it is overwritten for v3 records.
2. `approve-task (id &key approver)` — sets `:approval-at (get-universal-time)`
   on the task AND adds a live `*approved-operations*` entry. Human-only entry:
   client CLI command or owner config `:operation-approvals` seed. Never called
   by agent code. (In-process reachable only by plugin/client/REPL — same trust
   model as `grant-tool`.) If the task was `:blocked` for
   `awaiting-human-approval`, flips it back to `:queued`.
3. `operation-gate-check (kind targets &key lint-deps)` — exported predicate
   used by the mutating entry points. Returns T iff (a) exact-match approved
   operation exists AND (b) `kind ≠ :core-commit` OR lint-deps passed
   (`:lint-deps` carries the precomputed result where the caller has one; NIL
   forces a live `scripts/lint-deps.py <targets>` run when the files exist).
   On refusal: `log-action :denied` (target `"operation/<kind>"`, detail
   `"operation-not-approved"` | `"operation-lint-deps-failed"`) + publish
   `operation.denied` event (payload `(:kind <kw> :targets <list> :reason <kw>
   :timestamp <ut>)`), then returns NIL. **Never signals success on refusal.**

## Hook placement (named from actual code)

1. `submit-task` — new `operation-spec` keyword (line 1153 area). If an
   `:operation` task is submitted with NO matching approval: task enters
   `:blocked` with `:blocked-reason "awaiting-human-approval"` + journals
   `:denied` target `"operation/<kind>"` detail `"operation-not-approved"`
   (visible refusal + log now; human-recoverable via `approve-task` → back to
   `:queued`). If approved at submit: `:queued` immediately.
2. `next-eligible-task` — unchanged for `:authority :approval` (already refuses
   unapproved). `:blocked` tasks already never eligible. **No change needed**
   for the queue gate.
3. `task-driver-tick` — for `:type :operation`: BEFORE `delegate`, run
   `operation-gate-check` with the task's spec (`:lint-deps` from spec;
   compose: an approved core-commit whose lint-deps is `:failed` is refused
   **even when approved** — the card's composition test). Refusal → mark task
   `:failed` (error `"operation refused: <reason>"`), journal already done by
   the check, NO delegate call, publish `task-completed :failed` as today.
4. `package-manager.lisp` — `install-packages` (line 329) + `remove-packages`
   (359) + `upgrade-system` (372): call `operation-gate-check :dep-install
   <pkgs>` BEFORE `call-system-daemon`; NIL → error (fail-closed, logged).
   This is the dep-install mutating entry point, wired at the mutation site
   (not UI level, per card).
5. Commit guard — the core-file commit path has NO in-process wrapper today
   (agents commit via terminal git). The guard is the queue gate (3) +
   `operation-gate-check` as the function that any future commit tooling (and
   C6) MUST call before committing core files. Document this contract in code.
   qlfile/qlfile.lock additions are covered by the core-file set via (3).

## Composition with lint-deps (Wave B)

The card: a core-file commit that fails lint-deps must NOT get a bypass.
Enforced in `operation-gate-check` for `:kind :core-commit`: `:lint-deps`
result must be `:passed` (or a live `scripts/lint-deps.py <targets>` run must
succeed). Approval grants access, lint-deps grants safety — both required.
Ordering in `operation-gate-check`: approval first, lint-deps second; refusal
logs the specific reason.

## Files B touches

- `src/plugins/ai-orchestrator.lisp` — `*approved-operations*` +
  lock, `operation-spec` on submit-task, `approve-task`,
  `operation-gate-check`, driver pre-delegate gate.
- `src/plugins/package-manager.lisp` — gate calls in the 3 privileged ops.
- `src/packages.lisp` — export `approve-task`, `operation-gate-check`,
  `*approved-operations*`.
- `src/plugins/mission-control.lisp` and/or `src/client/main.lisp` —
  optional thin `approve` CLI surface (B's judgment; file-seed + REPL is
  sufficient this card).
- Tests (see below), `hngh.asd` + Makefile test-fast SUITE if new suite.
- Do NOT touch `src/core/safety-boundary.lisp` (A lane has no code edits
  anyway; the gate only CALLS it).

## Tests B must prove (fixture-driven, no real installs/commits)

Fixture: existing patterns (`:hngh.scoping` style) — event-bus → state-store →
safety-boundary → config → ai-orchestrator; isolated tmp home; NO approvals in
shared fixture (= deny-all posture).

1. `default-deny`: submit `:dep-install` op with no approval → task `:blocked`
   reason `awaiting-human-approval`; `operation-gate-check` NIL; action log has
   `:kind :denied` target `"operation/dep-install"`; `operation.denied` event
   fired with `:kind :dep-install`.
2. `approved-path-passes`: seed config `:operation-approvals` (or
   `approve-task`) → submit matching op → `:queued`; `operation-gate-check`
   T; task-driver completes (stub the install/commit side — e.g. a recorded
   "executed" flag, or `call-system-daemon` stub) → `:done`, no `:denied`
   journal added.
3. `approve-flips-blocked-to-queued`: blocked op → `approve-task` → status
   `:queued`, eligible via `next-eligible-task`.
4. `composition-lint-deps`: approve a `:core-commit` op whose spec carries
   `:lint-deps :failed` (or a tmp file that makes `lint-deps.py <path>` fail)
   → `operation-gate-check` NIL **despite approval**, journal detail
   `"operation-lint-deps-failed"`. (The card's explicit composition test.)
5. `refused-at-driver`: same as 4 through `task-driver-tick` → task `:failed`,
   no delegate invocation, journal present.
6. `exact-match-only`: approved targets `("src/core/a.lisp" "src/core/b.lisp")`
   → request for `("src/core/a.lisp")` NIL; request for superset NIL. Symmetric
   for `:dep-install` packages.
7. `package-manager-gate`: `install-packages` with no approval → error +
   `:denied` journal, daemon NOT called. After approval → proceeds (stubbed
   daemon).
8. `config-seed-fail-soft`: garbage `:operation-approvals` config → init
   succeeds, `*approved-operations*` empty, deny-all (like tool-grants).

## Verification gates

- `make test` green; count refs updated (fast suite count will grow by the new
  suite's checks); `lint-parens` / `lint-deps` unaffected (no new deps, or
  plugin→core calls only — lint-deps bans core→plugin, observed direction is
  plugin→core which is allowed).
- CHANGELOG (Keep a Changelog, dated, `green @ <sha>` after full-suite run),
  work-sessions, next.md Wave C row (item 8 → DONE), roadmap Wave C gate row
  update; C6 PARKED note remains (still parked until Wave C fully shipped) —
  item 8 completes the final gate block, flag for the owner.
- Commit body carries attribution: `tandem-a — deepseek-v4-flash-0731` (docs)
  / `tandem-b — gpt-5.6-luna` (impl).
- Deployment note (owner): `:operation-approvals` is edited in the config
  file, which safety-boundary mode-locks to 0444 — an owner invoking
  `hngh config set :operation-approvals ...` must chmod config/hngh.lisp
  first (same quirk as `:tool-grants` after card 97). Documented in
  next.md with the card-97 deployment note.

## Explicit non-goals (card MUST NOT)

- No auto-approval path anywhere. `approve-task` is the ONLY approver, and it
  is human-reachable only (client/owner config seed). No agent code calls it.
- No rewrite of the `:operation` type / task-record schema. Extension only:
  one extra plist key (`:operation-spec`) + one approval registry + one gate
  predicate + two call-site wires.
- No weakening of the safety-boundary. Approval never overrides
  `allow-mutation-p`.