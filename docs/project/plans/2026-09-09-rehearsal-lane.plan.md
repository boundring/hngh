<!-- plan: status=accepted risk=normal accepted=2026-09-09T21:01:37Z -->
# 2026-09-09 — rehearsal lane: dry-run ceremony, isolated gate, curator skeleton

Operator-directed 2026-09-09 (omp session design task). Design:
docs/design/rehearsal-and-self-order.md. The plan implements the
first rehearsal rung — pre-validating scheduled mutations by running
the existing certificate loop against scratch stores, plus the
curator skeleton — with zero side effects on real stores, ledgers,
or plan files. Machine ledger sync commits this plan file with the
day's records slice.

## Steps

- [ ] 1. Add `--dry-run` to scripts/ceremony-drive (test-first). The
      flag runs the full loop — create-run + admit-transport + propose
      + issue-cert prepare-candidate — against a fresh scratch store
      (`/tmp/hngh-dream-<ts>`), then stops: no `mutation-check` at all
      (the mutation executor would run the certificate-bound Git
      command on the real repository), no commit certificate, no push
      leg. It prints a report: per-step exit codes, the rendered
      verdict text, candidate paths, content hash, and the exact
      commands the real drive would run. Add the failing test to the
      hngh-automation script suite BEFORE the behavior change: it
      drives `sbcl --script scripts/ceremony-drive --dry-run` against
      a fixture candidate and proves (a) exit 0 on a clean candidate
      and refusal exit on a broken one, (b) no new commit, staged
      index entry, or push in the test repo, (c) no store or ledger
      writes outside the temp dir.
      Verification: suite test green for success and refusal paths;
      no git commit or push observable during the dry run; existing
      ceremony tests and `make test` green.
- [ ] 2. Isolated-worktree gate rehearsal (test-first). Add
      automation/scripts/rehearse-gate.sh: `git archive HEAD` (+ any
      named candidate files) unpacks into a temp dir and runs the
      named repo's `make test` there, printing the exit code and
      last failing check only. Wire it into accept-plans.py as an
      opt-in (`ACCEPT_ISOLATED_GATE=1`) so gate pre-validation runs
      on an archived tree instead of contending with parallel
      delegated sessions — the 2026-09-09 kernel-gate-red-rc2 and
      automation-gate-red-rc2 blocks were load-correlated
      (schedule-optimization plan step 5), and the 2026-09-02
      routed-review wake proved the `git archive` pattern green while
      the working tree was red. Suite test first: sandbox archive
      runs the stub gate, dirty-working-tree diffs stay out of the
      archived copy, and the opt-in off-by-default preserves current
      behavior.
      Verification: suite test proves archived-tree isolation and
      opt-in default; an isolated rehearsal on this repo exits 0
      matching a green gate; `make test` green in both repos.
- [ ] 3. Curator beat skeleton (test-first). Add a cadence drop-in
      (automation/cadence/day/) that reads the work graph inputs
      (accepted plan front matter, queue.md, automation/dashboard/
      plans.json) and emits exactly two machine actions and two
      report verbs: (a) `priority=high` front-matter flagging per
      the schedule-optimization step 2 selector key, and (b)
      duplicate-scope merge proposals as parked-superseded
      dispositions with inline evidence (`cause=`, `reason=`,
      `disposed=`, router convention) — each plan-file mutation
      landed through scripts/ceremony-drive per
      docs/design/rehearsal-and-self-order.md, never edited outside
      a certificate. Handoff flags (deck node,
      automation/docs/DECK-NODE.md Phase 3) and enabling-work
      staging land as operator-items only in this rung. Suite test
      first: proposals reference only plans that exist, guardrails
      hold (never risk=critical, never already-parked, no
      counter-evidence means no action), and no plan file changes
      outside the ceremony path.
      Verification: suite test covers flag, disposition, guardrail,
      and no-op cases; a dry beat against the live tree emits
      operator-items and changes nothing; `make test` green.
- [ ] 4. Records. Fold the first dry-run rehearsal and the first
      curator beat's output into docs/records/ (kernel repo, via the
      normal ceremony) and the hngh-automation CHANGELOG, citing the
      dream store, verdict, and any refusal rows verbatim.
      Verification: dated record in docs/records/ with the rehearsal
      evidence; automation CHANGELOG entry; `make test` green.

## Execution notes

- Steps 1 and 2 are independent; 3 depends on 1 (it reuses the
  dry-run store discipline); 4 depends on 1-3 having run once.
- Every plan-file mutation in steps 1 and 3 lands through the
  certificate ceremony; the acceptance sweep keeps reading front
  matter the way it does today (accept-plans.py VERIFICATION regex
  `^[ \t]+Verification[ \t]*:` — Verification lines stay on their own
  indented lines).
- Guardrail inherited from the design doc: a rehearsal refusal files
  evidence and never suppresses the real action's governance.
- 2026-09-13 step-1 repair-to-green (the behavior and its test already
  existed from the blocked 2026-09-12 attempt; the dream pass
  under-called two of the four root causes): dream-store-path date
  format `%J` -> `%d`, dream store now auto-created (scratch stores
  are created; explicit --store stays fail-closed), verdict-text
  `let` -> `let*` so the initializer's setf lands inside the binding
  (the `[dream] verdict:` row printed "verdict pending" before), and
  verify-candidate.py whitespace scan now refuses control characters
  (the test's refusal bait is `\x7f`). Test file
  tests/scripts/test-ceremony-drive-dry-run.py is green 4/4 but
  remains UNCOMMITTED: it is untracked scratch from the blocked
  session, and tests/ plus Makefile changes are forbidden this
  session, so the box stays unticked. Next session with tests/
  authorization: commit the test (its final refusal assertion was
  repaired in the working tree — the original asserted a clean
  `git status` after deliberately dirtying the fixture, which no
  drive code path can satisfy), wire it into make test, then tick
  step 1.
