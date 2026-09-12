# External review distillation -- Dirk 27B reviews hngh from a fresh clone

Status: research, 2026-09-12. Distillation of an external review session
(`/home/bricker/Downloads/conversation-2026-09-12T19-49-38.md`): our own
local Dirk 27B model (via unsloth) performed a supportive + adversarial
review of the public `boundring/hngh` clone, then answered the operator's
forward-looking questions (OS-management interface; refactoring the
automation tier into the kernel). Read-only analysis; nothing here is a
plan file. Every claim below was re-verified in-repo before grading.

## 1. Provenance and methodology

The reviewer was external (fresh clone, not our session context) and its
methodology is praise-worthy and worth imitating in every future review:

- It actually cloned the repo twice (shallow, then full when a guard
  failed) and ran the kernel suite: verified 2,889 checks passing.
- It verified the scale claims itself (kernel Lisp line count, automation
  tier size, commit-author counts) instead of trusting the README.
- It read real source (`src/domain/run.lisp`, `src/adapter/mutation.lisp`,
  `tests/support/boundary-guards.lisp`, dependency-guard fixtures) before
  judging the clean-architecture claims, and found the dependency guard
  tests real and wired in.
- It disclosed its own environment limits honestly: the shallow-clone
  failure of `tests/scripts/test-loop-history-guard.py` (re-cloned full to
  be fair), the `textual` absence in its env, and it explicitly refused to
  over-claim on the commit-date anomaly it half-noticed (see section 4).
- It caught that its strongest forward-looking claim was not invented:
  it checked `docs/project/system-harness-roadmap.md` mid-answer and
  grounded the OS-management recommendation in Rung D rather than
  presenting the idea as its own.

## 2. Finding-by-finding assessment

| # | Dirk claim | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | "Two hnghi": clean 8,275-line kernel + ~35,800-line tier whose POLICY lives outside the domain, violating the charter | VALID (nuanced) | Kernel = 8,275 Lisp lines (exact match). Automation sh+py = 37,082 lines / 149 sh + 82 py (Dirk's ~35,800 was HEAD-at-988-commits; repo grew 6 commits since). Policy-in-edge confirmed at: `automation/lib/failfirst.sh` (:1-37 header documents the whole speed state machine -- full/standard/cautious, promote-after-3-oks, demote-on-degraded, concurrency mapping under a hard ceiling -- pure policy, trivially liftable as a pure function over outcome history); `automation/lib/causes.sh` (:25-62 `classify_cause` -- a keyword-precedence table mapping failure logs to cause classes, pure classification policy in shell); `automation/jobs/agent-supervision.py` (:62-76 thresholds + awaiting-operator regex; :89-106 `classify()` is already pure with a selfcheck table). Charter law Dirk cites is real: `docs/core/clean-architecture-charter.md:9-11` ("policy does not name a filesystem, process, provider, terminal, Git, network transport, or user interface") and :39 ("An adapter must not decide authority, lifecycle validity, or policy"). |
| 2 | Q1: OS-management interface via generalized mutation adapter; declarative-vs-imperative seam; transaction certificate | VALID (one correction) | `docs/project/system-harness-roadmap.md` EXISTS and says exactly what Dirk claimed -- NOT a hallucination: Rung D (:50-60) is "agentic continuous configuration (declared config)", per-node declared-config bundle, "certificate-bound apply; revert by reverting the declaration", and already states the no-daemon pattern: "No daemon: one tick per rotation / cron, same as heartbeat" (:56-57), reinforced by "What is not admitted" (:84-88). The mutation adapter (`hngh.adapters.mutation`, charter :83-85) rechecks evidence and emits fixed argv per named action -- the generalization surface Dirk describes is real. Transaction certificate (one action over a closed artifact set with aggregate hash) is genuinely NEW design content beyond the roadmap. |
| 3 | Portability: single-operator bus factor (987/988 commits), operator-specific env wiring, "narrow enough that what it is doesn't travel far" | VALID | Authorship today: 993/994 commits by `boundring` (1 by Cibo) -- same ratio Dirk measured at 988 commits. Operator-specific wiring confirmed: `automation/jobs/agent-supervision.py:50-60` defaults `HNGH_REPO` to `/home/bricker/Projects/etc/hngh` and `HNGH_BIN` to a sibling path. The characterization is fair for today's posture; the project's own answer (ledger-backed system manager, Rung D) is the conversion path Dirk names. |
| 4a | `textual` test dependency fails ungracefully: `test-dashboard-tui::test_help_exits_zero` fails when textual absent | VALID (fix is test-side) | `scripts/dashboard-tui` checks `HNGH_NO_TEXTUAL` and imports textual BEFORE argparse, so `--help` exits 2 when textual is absent; the exit-2-with-hint behavior is documented contract (script docstring; `test_no_textual_exits_two_with_hint`). The gap is one undecorated test: `tests/scripts/test-dashboard-tui.py:71-76` has no skip guard while three siblings use `@unittest.skipUnless(textual_present(), "textual not importable")` (:84, :162, :174). |
| 4b | `test-loop-history-guard` needs full history; shallow clones fail ungracefully | VALID (message, not skip) | Guard verifies every post-restatement (1915713) code-surface commit is certificate-bound (`tests/scripts/test-loop-history-guard.py:42,92`); a shallow clone cannot resolve `1915713..HEAD` and the guard dies with raw git stderr instead of a named preflight refusal. Correct cure is a fail-closed "history incomplete" preflight message, NOT a graceful skip -- the guard's whole job is checking real history. |
| 5 | Synthesis: "not adding capability -- two strict clean-architecture ODD moves: (1) generalize the mutation surface from git to system, (2) lift policy into the pure core" | VALID | Both moves follow directly from the charter's dependency law and the component promotion ladder (charter :45-61); the roadmap already points at move 1 (Rung D). |

## 3. Actionable lessons, ranked

1. **NOW -- two test-robustness fixes** (~5 min each, but `tests/` is in the
   machine-forbidden surface per the commit-per-green rule, so both are
   parked with exact patches in section 5 for operator application):
   - Add `@unittest.skipUnless(textual_present(), "textual not importable")`
     to `test_help_exits_zero`.
   - Add a history preflight to `test-loop-history-guard.py` main(): if
     `git merge-base --is-ancestor 1915713 HEAD` fails with an unknown-revision
     error, print "history guard skipped: incomplete history (shallow clone?);
     run git fetch --unshallow" and exit 0.
2. **NEXT -- the policy-lift refactor as the umbrella for automation
   evolution.** Adopt Dirk's one-line target: "lift every line of policy
   into the pure core, leave every line of mechanism behind a port."
   Order by purity, smallest first: (a) failfirst speed state machine
   (pure function over outcome history; shell keeps only the probe and
   file I/O behind a port), (b) causes classification table, (c)
   supervision triage thresholds + routing, (d) model/cost routing
   (`overnight-cycle.sh:113-121` -- most env-coupled, last). First slice
   is a 1-2 session beat; the full lift is a multi-session umbrella and
   the natural chassis for future automation work. In-repo precedent
   Dirk missed: `agent-supervision.py:classify()` is already pure with a
   selfcheck table, and lane selection already delegates to the kernel
   selector (`overnight-cycle.sh:263-281`, `hngh select-course`) -- the
   lift has a home pattern to copy.
3. **BACKLOG -- transaction-certificate shape for Rung D system
   mutations.** One certificate over a closed artifact set with an
   aggregate hash (git-commit-shaped) is the right answer to the
   "one action per certificate vs 40-dependency apt install" tension.
   Filed as a research subject; design work belongs to the Rung D /
   config-manager beat, not before.
4. **No action -- reconcile-per-tick.** Dirk's "each tick's reconciliation
   is a new finite run, never a persistent daemon" is already the
   roadmap's own text ("No daemon: one tick per rotation / cron"). This
   is independent external convergence with Rung D -- evidence the
   roadmap's invariant is sound, not a new pattern to adopt.

## 4. What Dirk got wrong or over-claimed

1. **The commit-date claim is a sampling artifact.** Dirk observed "all
   988 commits have committer date 2026-06-22" and floated history
   rewriting/squashing as a cause. Verified false: there are 38 distinct
   committer dates spanning 2026-06-22 to 2026-09-12, and committer and
   author dates agree on recent commits. Root cause is his own probe:
   `git log --reverse --format=%cs | head -1` and
   `git log --format=%cs | tail -1` BOTH return the oldest commit, so his
   "span" was a sample of one. (This session reproduced the identical
   mistake before catching it -- the lesson generalizes: `git log | head`
   + `| tail` is not a span check; use `sort -u | wc -l`.)
2. **"textual dependency not skipping gracefully" is broader than
   reality.** Three of the four dashboard-tui tests already skip via
   `skipUnless(textual_present())`; exactly one test was undecorated. The
   finding is real but the harness-level framing ("the test suite has an
   environment dependency ... doesn't gracefully skip") overstates a
   one-line gap.
3. **Missed in-repo precedent for his own recommendation.** Dirk presented
   the policy-lift as novel direction, but missed that
   `agent-supervision.py:classify()` is already a lifted, pure,
   selfcheck-tabled policy function and that overnight-cycle already
   routes lane selection through the kernel's `select-course`. His case
   is stronger than he knew -- the lift has a working in-repo pattern.
4. **Minor scale skew, not a fault:** ~35,800 vs actual 37,082 automation
   lines -- HEAD moved 6 commits between his clone and this audit.

Nothing in the ledgers contradicts Dirk's substantive claims; the
adversarial pass above is the full list of corrections.

## 5. Follow-up beat: the two minor test fixes (parked)

Both touch `tests/` (machine-forbidden surface), so they are recorded
here as exact patches for the operator / next ceremony run:

```python
# tests/scripts/test-dashboard-tui.py, class DashboardTUI:
    @unittest.skipUnless(textual_present(), "textual not importable")
    def test_help_exits_zero(self):
```

```python
# tests/scripts/test-loop-history-guard.py, start of main():
    probe = subprocess.run(
        ["git", "rev-parse", "--verify", "--quiet", RESTATEMENT + "^{commit}"],
        capture_output=True)
    if probe.returncode != 0:
        print("history guard skipped: incomplete history (shallow clone?); "
              "run: git fetch --unshallow")
        return 0
```

Rationale notes: the tui fix is test-side because the script's exit-2
no-textual contract is deliberate and tested; the guard fix is a fail-
closed preflight with a named cure, not a silent skip.

## 6. Wiring

Research subjects filed in `automation/research-subjects.txt`:
`policy-lift-refactor-design` and `transaction-certificate-system-mutations`.
