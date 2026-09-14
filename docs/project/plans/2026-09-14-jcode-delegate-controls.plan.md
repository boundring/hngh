<!-- plan: status=accepted risk=normal priority=high accepted=2026-09-14 -->
# 2026-09-14 — Nerve-center Jcode delegation controls: /delegate route + Sessions-tab launch UI

Operator-directed 2026-09-14 ("let's proceed with that plan and
delegation"). Goal: put controls for launching Hngh-integrated
orchestrating Jcode sessions where the architecture says they live —
the nerve center's Sessions tab — backed by the already-landed gated
lane (`jcode-delegate.sh`: pacer, bridge run-start/end, budget row,
lessons). Fanout uses Jcode swarm subagents in separate working
directories (non-commit-clobbering by construction).

## Architecture constraint

The dashboard server stays display-only for *rendering* but already
owns two deliberate mutation-adjacent routes (`/spawn`, `/tile`) under
a strict contract: the client NAMES an operation, the server executes
a fixed, validated command with no operator input passed to a shell.
`/delegate` follows that same contract — the POST body carries only
slug/objective/provider/minutes, each validated against a closed
vocabulary, and the one fixed command is `lib/jcode-delegate.sh`
itself. No free-form command, no shell interpolation of user text.

## Steps

- [x] 1. **Server route `POST /delegate`.** In
      `automation/dashboard-server.py`: validate body
      `{slug, objective, provider, minutes}` — slug through SESSION_RE,
      provider closed-set (zai|unsloth), minutes int clamped 1..30;
      execute `bash lib/jcode-delegate.sh slug objective minutes
      provider` via subprocess (Popen detached, like /spawn; the route
      returns 202 with the slug — the ledger is the result record, not
      the HTTP response). Fail-closed: unknown provider → 400; pacer
      refusal (rc 75) is invisible here (async) and lands in the
      ledger/breadcrumbs instead.
      Verification: pytest with a stubbed delegate script asserts the
      fixed argv, refusal paths, and 202 shape.
- [x] 2. **Sessions-tab control.** In `sessions-view.js`: a
      "delegate" control on the Sessions panel header — small form
      (slug, objective, provider select zai/unsloth, minutes 1-30)
      posting to `/delegate`; result surfaced as a transient status
      line, never an inline error dialog. Register matches the
      existing `.sv-fbtn` visual register.
      Verification: UI-audit route renders; manual witness in the
      operator's browser.
- [ ] 3. **Grade loop evidence.** Run `scripts/grade-interface`
      against the changed panel; attach before/after to the record.
      Verification: grade passes; evidence filed in docs/records/.
      Partial (2026-09-14, coordinator): evidence filed in
      docs/records/2026-09-14-jcode-delegate-controls-landing.md —
      before/after captures (shots per the record), axe ui-audit
      shows the form adds zero findings, 12/12 pytest green. The
      vision-model grade itself did NOT run: reviewer endpoint has
      no image-input-capable model (HTTP 400). Remaining loop:
      add a vl/vision model to the reviewer endpoint, regrade the
      after capture, tick.
- [x] 4. **Non-clobbering fanout doc.** Extend the shared-sense
      record: subagent swarm lanes take separate working directories
      or disjoint file slices; the coordinator commits. Reference the
      existing single-writer rule.
      Verification: record updated; no code.

## Parallelization

Steps 1 and 2 are file-disjoint (server vs client JS) and can fan out
to two swarm subagents; step 3 depends on both; step 4 is docs-only
and parallel-safe. The coordinator (this session) does review,
integration commits, and the push.

## Priority

Operator-directed; rides the top of this lane's queue. Risk: normal —
no kernel surface, no credential surface, the delegate script is
already gated end-to-end.
