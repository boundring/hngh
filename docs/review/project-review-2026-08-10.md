# Bounded project review — 2026-08-10

**Scope**

Reviewed the current Hngh work block from the committed tree through
`f4372d7`, the uncommitted card-147 test diff, the current task/triage records,
Hermes Hngh config, and live seat/watcher state. No source, config, live-seat,
or card-147 commit changes were made during this review.

Reviewed commits:

- `472737d` — quota admission and settlement hardening
- `f4372d7` — quota gate completion and planner staging
- `e4b821d`, `9f0af6e`, `f8b4fc1`, `4865fd9`, `8ddc95e`, `4ac77aa`, `66cb604`,
  `4312c83`, `7aa2e3d` — policy/design sequence for authority, context,
  succession, routing, and cost control

Current evidence:

- Card 128 is committed at `472737d`.
- Focused quota evidence: 65/65 pass; paren lint and `git diff --check` pass.
- Serialized `make test` on that code tree: the planner suite was 52/56;
  other observed suites passed. The four planner failures were the known
  UNKNOWN five-hour quota fixture seam.
- Card 147 currently changes only `tests/unit/test-hngh-planner.lisp`.
- Card-147 focused evidence: 59/59 pass; paren lint and `git diff --check`
  pass. It remains uncommitted pending independent review.
- `hngh-watch.service`: active.
- Live seats: cibo and seu panes alive; killy pane dead. No successor seat was
  launched.
- Hermes Hngh config has `approvals.mode: manual`, `timeout: 60`,
  `cron_mode: deny`, and the effective compression cap is 120,000 tokens.

## Contradictions

1. **Card-147 task acceptance still describes the baseline as `52/56`, while
   the repair now produces `59/59`.** The task file records the original
   baseline at `tasks/147-planner-fixture-baseline-repair.txt:16-23` and the
   revised acceptance at `:38`; this is correct as history but easy to read as
   the current target. The current triage and task should distinguish
   `baseline: 52/56` from `current: 59/59` explicitly before commit.

2. **The project roadmap still mixes old and new sequencing language.**
   `docs/project/next.md` marks card 128 verified and places card 147 next,
   while the older “Immediate next work” and “Up Next” sections retain broad
   historical Wave C/C6 priority rows. This is not a code contradiction, but
   it makes the active frontier less authoritative than
   `current-card-triage-2026-08-10.md`.

3. **The policy says Hngh owns every pre-execution action path before no-input
   promotion, but the live Hermes profile remains an attended manual gate.**
   The design correctly states this as a hold in
   `docs/design/autonomous-action-policy.md:263-273`; the config confirms the
   current manual posture at `/home/bricker/.hermes/profiles/hngh/config.yaml:774-777`.
   This is a healthy intentional hold, not a failure, but promotion must not be
   implied by the design documents alone.

4. **The context design calls for a 120,000-token absolute compression cap,
   while OpenCode still requires a version-verified controller.**
   The Hermes cap is live and verified; the OpenCode design explicitly refuses
   an undocumented key. These are two different enforcement surfaces and must
   remain separately tracked.

## Missing guardrails

1. **Card-147 fixture restoration is not yet independently reviewed.** The
   current test binds the private `*route-defaults*` variable and proves a
   numeric envelope, but the final gate still needs a reviewer pinned to the
   exact dirty-file state. No commit should occur until that PASS is recorded.

2. **The planner fixture binds a private production variable rather than a
   dedicated test seam.** This is acceptable for the narrow repair because no
   production file changed and the binding is scoped by the fixture macro, but
   it is a maintenance seam. A later cleanup card should expose a named test
   fixture API or isolate quota defaults in test support, without weakening the
   production UNKNOWN default.

3. **The UNKNOWN regression test clears `*overrides*` but relies on the
   production `*route-defaults*` binding remaining unchanged.** That is valid
   in the current test process, but the test would be stronger if it asserted
   both the five-hour `:unknown` value and the false gate result. The current
   test proves refusal; it does not independently prove which envelope caused
   refusal.

4. **The full fast gate is not green yet.** Card 147 fixes the planner suite
   locally, but it has not been run against the full serialized fast set after
   the test-only change. The correct next gate is review first, then one
   serialized fast run. Do not relabel the project baseline green until that
   run completes.

5. **Claim cleanup is incomplete.** The claims registry still shows the card
   128 claim without a visible matching release record at the read surface,
   even though the card is committed and reviewer duty was released in lane
   evidence. Reconcile the registry before assigning card 127 or reusing that
   claim path.

6. **The dead Killy seat has no successor yet.** This is not a reason to launch
   one during the review. If a successor is needed later, use a unique assigned
   name and a fresh mission; never reuse the dead Killy socket or lane without
   explicit cleanup.

## Exact proposed section bullets

### `tests/unit/test-hngh-planner.lisp`

- Keep the fixture-local numeric `kimi-sub` envelope scoped to the two planner
  emission tests.
- Keep one explicit UNKNOWN fail-closed regression test outside that override.
- Before commit, add an assertion that the unoverridden `kimi-sub` envelope's
  five-hour cap is `:unknown`, then assert `%quota-gate-open-p` is false.
- Do not alter `src/plugins/quota-spreader.lisp` or
  `src/plugins/hngh-planner.lisp` for this card.

### `docs/project/next.md`

- State the active frontier once: `128 verified/committed -> 147 review -> 127
  consumer`.
- Mark the historical 52/56 result as baseline evidence and 59/59 as the
  current fixture result.
- Keep no-input worker promotion and OpenCode controller work behind their
  explicit pre-exec and effective-surface gates.

### `current-card-triage-2026-08-10.md`

- Add the exact card-147 diff hash or commit SHA after review/commit.
- Record reviewer identity, evidence command, count, and the remaining full
  gate result.
- Reconcile card-128 claim release from the registry before card 127 is
  assigned.

### `docs/journal/2026-08-10.md`

- Record the approval-timeout diagnosis as a wait failure, not a hardline
  detection failure.
- Record the Hermes/OpenCode distinction: Hermes has the verified 120k cap;
  OpenCode still needs a documented controller seam.
- Record the pause decision: no successor launch and no card-147 commit during
  this bounded review.

## Questions operator must decide

1. **Should card 147 keep the private-variable fixture binding, or should we
   spend a separate cleanup card to introduce a named test-only quota seam?**
   Design choice; recommendation: keep the least-change binding for 147 and
   defer cleanup.

2. **Should the dead Killy lane receive a successor seat after this review?**
   Operator-gated; recommendation: not until card-147 review and claim
   reconciliation are complete.

3. **Should the project use `docs/project/next.md` or the current-card triage
   file as the single active-frontier authority?** Design/documentation choice;
   recommendation: `next.md` is the durable roadmap, while triage remains the
   volatile execution ledger and must link back to it.

4. **When may a worker profile leave attended `approvals.mode: manual`?**
   Operator/security gate; recommendation: only after the Hngh pre-exec
   controller, fixture matrix, rollback, and effective OpenCode audit all pass.

## Recommendation

Pause implementation at the current boundary. Do not launch the successor
seat, commit card 147, or begin card 127 yet. First obtain the independent
card-147 review, reconcile the card-128 claim record, then run the serialized
fast gate on the reviewed tree. After that, resume with card 127 only if the
planner consumer remains properly downstream of quota truth.

Attribution: primary Hermes session — openai/gpt-5.6-luna via openrouter, 2026-08-10.
