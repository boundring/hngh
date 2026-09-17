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

- [x] 1. Add `--dry-run` to scripts/ceremony-drive (test-first). The
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
- 2026-09-15 step-2 code landed in the automation lane (commit
  72e0d7a6): the committed-but-red rehearsal artifacts from 550e8ff5
  were repaired rather than recreated — test fixture now writes the
  stub gate log to an ABSOLUTE path outside the archive temp dir (the
  EXIT trap destroyed the relative log/ write; 7/7 RehearseGate cases
  green red-then-green), rehearse-gate.sh gained the REHEARSE_LOG env
  seam as its --log default (the test pins the env, one line),
  accept-plans.py gained the off-by-default ACCEPT_ISOLATED_GATE=1
  opt-in (both gates rehearse through the script; red or rc=2 refuse
  blocks acceptance fail-closed; automation rehearsal skipped when the
  kernel rehearsal is red; script resolved adjacent to accept-plans.py,
  not under HNGH_AUTOMATION_ROOT, so sandbox test roots work), and the
  suite is wired into the automation Makefile. tests/test-rehearse-gate
  .py 10/10 green; automation `make test` green; kernel `make test`
  green in the working tree (lisp suite, rc=0).
- 2026-09-15 step-2 verification blocker (box stays unticked): the
  plan's "isolated rehearsal on this repo exits 0" clause is not met —
  the rehearsal refused rc=2 fail-closed on the kernel tree because
  tests/scripts/test-loop-history-guard.py runs `git log` in the
  working repo, which a `git archive HEAD` copy lacks (breadcrumb row
  2026-09-15T08:44:57Z | rc=2, tail: CalledProcessError git log
  1915713..HEAD exit 128). Sandbox rehearsal behavior itself is proven
  by the suite. Operator-item: an out-of-repo seam in
  test-loop-history-guard.py (kernel tests/ surface, forbidden this
  session) before archived-tree kernel gates can run; no
  improvisation around a forbidden surface.
- 2026-09-17T10:20Z step-2 blocker refresh (rehearsal-lane wake): the
  out-of-repo seam now EXISTS but is uncommitted — the
  fixture-containment lane (dead session, edits stamped 05:56-06:16Z)
  pinned test-loop-history-guard.py git reads to KERNEL_GIT_DIR and
  wrote docs/records/2026-09-17-fixture-containment-gitdir.md, all
  uncommitted in the kernel working tree; HEAD still carries the
  pre-seam guard, so `git archive HEAD` rehearsals keep refusing rc=2.
  The containment lane owns the ceremony landing of its own edits;
  this session's autonomy rule keeps kernel tests/ forbidden. New live
  signal: the kernel gate is currently red (STATE.md
  kernel-gate-red-rc2 plan-blocked crumbs 10:01Z), so no live
  ceremony can run today anyway. Step 2 verification stays parked on
  the containment lane's ceremony commit; step 3 proceeds (it does
  not depend on step 2's unmet rehearsal clause).
