# Kernel gate red: diagnosis and cure options (operator review)

Date: 2026-09-11. Status: memo for operator review — no cure applied.
Follow-up session implements the operator's chosen option.

## 1. Reproduction (verified this session)

    make test   -> rc=2
    tests/scripts/test-loop-history-guard.py
    loop-history guard: 2 violation(s):
      adb0307 fix: omp-bridge --plan-status accepts bare slug or date-prefixed stem
      572d3e2 feat: omp-bridge --propose and --plan-status (plan step 3)
    every code-surface commit must be 'hngh: candidate <hash>' or a labeled rule-based exemption

Failing check: `tests/scripts/test-loop-history-guard.py` (Makefile:11 `test` target),
exit 1 -> make exits 2. Exactly the failure the research line
`fail-20260911-overnight-plan-accept-gate-kernel` named.

## 2. What the guard enforces

Invariant (tests/scripts/test-loop-history-guard.py:10-14): every commit after the
restatement `1915713` that touches the code surface (src/, tests/, scripts/, Makefile,
hngh.asd) must either (a) carry subject `hngh: candidate <64-hex>` (CANDIDATE
regex, :52), (b) sit in the named-exemption table KNOWN_EXEMPTIONS (:36-49), or
(c) carry the `excluded from cert manifest by dependency guard` label restricted
to src/packages.lisp (:53-54). Anything else is a violation (:107) and fails the
gate (:108-116). Purpose: make the README ceremony claim machine-falsifiable —
the ledger of behavior changes is reconstructible from commit subjects alone.
## 3. The offending commits — and the twist

Both offenders touch `scripts/omp-bridge` (code surface) and landed outside the
loop on 2026-09-10 (author dates 20:47:53 / 21:02:46 -0400):

- 572d3e2 "feat: omp-bridge --propose and --plan-status (plan step 3)"
  (scripts/omp-bridge +148, automation/tests/test-omp-bridge.py +107, ...)
- adb0307 "fix: omp-bridge --plan-status accepts bare slug or date-prefixed stem"
  (scripts/omp-bridge +14/-5, automation/tests +19)

**Both are PUSHED**: `git branch -r --contains` shows origin/main contains both,
and `git rev-list --left-right --count origin/main...HEAD` is 0 0 — HEAD equals
upstream. History rewrite of them is off the table by position, and by the
2026-09-06 decision ("pushed history is never rewritten", docs/project/decisions.md:388).

**The twist — the cure already happened, then a purge orphaned it.** Ceremony
commit e79ed08 ("hngh: candidate 8ce5af35...", 2026-09-11 02:37, = f2f04e3 before
a rewrite) applied the documented declare-and-cure cure (decisions.md:439-459):
it added KNOWN_EXEMPTIONS entries for `a2f4d0e` and `31768d2`, the declaration
entry in decisions.md, and the cure record
docs/records/2026-09-11-omp-bridge-post-hoc-certification.md. The gate went
green ("gate cure f2f04e3" recorded at 02:38).

At 10:57 the same morning, `git filter-branch: rewrite` (reflog HEAD@{2026-09-11
10:57:53}) ran a secret-scrub history purge (recorded in aceb75b "docs:
secret-scrub record — history purge..."): it redacted credential-shaped strings
in docs/research/2026-09-10-lobehub-api-research.md (git diff a2f4d0e 572d3e2
shows exactly that file, 2 lines changed) and thereby rewrote the hash of every
descendant commit. Consequences:

- a2f4d0e -> 572d3e2 and 31768d2 -> adb0307 (same subjects, same author dates,
  trees differ only by the redaction); the pre-purge hashes are now ORPHANED
  objects, unreachable from any ref (`git log --all` finds nothing).
- e79ed08's exemption table still names the orphaned hashes -> the rewritten
  twins violate again -> gate red since 10:57.
- Exemptions for 915e0e3 and 526cd3f survive because they predate the first
  tree-modified commit and kept their hashes.

So the root cause is NOT a new governance miss: it is **declaration-hash
desynchronization** — the exemption register is keyed by commit hash, and a
history rewrite silently invalidates every registered hash at or after the
first modified commit. The 2026-09-06/09-11 declaration mechanism is sound;
its keying is not purge-proof.

## 4. The push block (confirmed same check)

automation/cadence/hour/16-remote-push.sh push_repo(): when the gate crumb is
red/none/stale it re-runs `make test` inline (:84-106); on failure it saves the
log to automation/logs/gate-rerun-hngh-*.log and breadcrumbs "push-refused",
returning without pushing. Every gate-rerun log today ends in the same
loop-history guard 2-violation output — same check, same commits. No new
commit can be pushed by the automation until the guard is green. (Direct
manual `git push` is not script-gated; the block is automation policy.)

## 5. Research-line answer (already crystallized)

docs/research/2026-09-11-fail-20260911-overnight-plan-accept-gate-kernel.md,
F3 (:28-29) and verdict (:12): "The miss **can** be declared and re-certified
without rewriting history — via an append-only supersede event... Truncating
or rewriting the log would itself trip any guard worth the name." The line was
reviewed and adopted the same morning (research-lines.tsv:42, disposition
"adopted"). The 2026-09-11 cure (e79ed08) then EXECUTED exactly that answer.
This memo's addition: the executed cure worked once and was broken by the
secret-scrub purge — the cure must be re-applied AND made purge-proof.

## 6. Options

### A. Re-declare the post-purge hashes (declare-and-re-certify, re-run)

The sanctioned mechanism already exists: the 2026-09-06 decision
(decisions.md:380-402) and the 2026-09-11 execution (e79ed08) define a
declaration as (1) a named-exemption entry in KNOWN_EXEMPTIONS with a reason
string, (2) a decisions.md entry, (3) the change content bound by a real
certificate through the loop. For this miss the content was already bound by
e79ed08's certificate (per-file sha256 evidence over the whole bridge); only
the two hash keys desynchronized.

Mechanics (one ceremony candidate, mirrors e79ed08):

    python3 scripts/omp-bridge --propose loop-history-purge-redeclare \
      --title "Re-declare omp-bridge misses at post-purge hashes"
    # edit tests/scripts/test-loop-history-guard.py KNOWN_EXEMPTIONS:
    #   replace "a2f4d0e" -> "572d3e2", "31768d2" -> "adb0307" (keep reasons,
    #   add "(hashes post secret-scrub rewrite 2026-09-11)")
    # append a short supersede note to decisions.md:439 entry
    python3 scripts/omp-bridge --ceremony   # issue-cert -> mutation-check
    # commit subject: hngh: candidate <hash>  (lands via mutation-check)

Equivalent MCP path: hngh_propose -> hngh_issue_cert -> hngh_mutation_check.
Risk: minimal; exact precedent (three prior declarations: 915e0e3, 526cd3f,
a2f4d0e/31768d2). Guard unweakened — same scan range, same subject rule.
Residual risk: if another history rewrite ever happens, the register breaks
again (that residual is Option C's job).
Executor: ceremony loop (machine-drivable end-to-end; operator reviews cert).

### B. Amend / rewrite the offending commits

OFF THE TABLE. 572d3e2 and adb0307 are contained in origin/main and
HEAD == origin/main (verified: git branch -r --contains; rev-list 0 0). A
rebase changing their subjects would require a force-push of shared history,
violates the 2026-09-06 decision ("pushed history is never rewritten"), and
would itself be a second filter-branch-class event days after the first —
the very operation that caused today's red. Even if unpushed it would be
wrong here: the guard's job is an honest ledger, and the subjects are not
actually lies; the commits only lack the candidate label.

### C. Guard evolution: purge-proof exemption keying (governance surface)

The real defect is that KNOWN_EXEMPTIONS is keyed by a 7-char hash that any
history rewrite invalidates. Widening the guard's allowed declaration forms
(e.g. when a registered hash is unreachable, resolve by exact subject +
author-date, requiring a unique match, and verify the declared content via
tree/signature) would make declarations survive rewrites. With a test
(orphaned registered hash + unique subject match -> resolved, not violated;
ambiguous match -> still fails). This changes the governance surface — it
relaxes what the machine accepts as "declared by name" — so it is an
OPERATOR DECISION, not a machine default. Mechanics: same ceremony path as
Option A; can ride in the same candidate commit or a follow-up.
Risk: a too-loose match (subject-only) could whitewash a rewritten miss;
mitigate with unique-match + author-date + no-content-divergence checks.

## 7. Recommendation (one paragraph)

Run Option A now — a single ceremony candidate that re-keys the two
exemption entries to 572d3e2/adb0307 and appends the supersede note to the
2026-09-11 decisions entry; it is the exact, precedent-backed cure the
research line's F3 answer already adopted, and it is fully machine-drivable
through omp-bridge --ceremony with the operator reviewing the certificate.
Fold the minimal slice of Option C into the same candidate — not a general
widening, but a standing guard self-check that every KNOWN_EXEMPTIONS hash
must resolve in reachable history (fails loudly at declaration time, which
would have turned the 10:57 purge breakage into an immediate, self-naming
failure instead of a silent two-day red). Reject B outright. After the cure,
"baked-in capability" = (1) the exemption-register reachability self-check
above, and (2) optionally a gate-cure flow in the ceremony drive: parse the
loop-history guard's violation output -> propose the re-declaration plan ->
issue-cert -> re-certify — so the next desynchronization is cured by one
command, with the ledger append-only throughout.

## 8. Purge runbook (baked in with the 2026-09-11 recertification)

Any future history rewrite (filter-branch / filter-repo) MUST be
followed immediately by either a re-declaration ceremony re-keying the
affected KNOWN_EXEMPTIONS hashes (the 2026-09-11 recertification is the
precedent), or is performed with the patch-id keying already active —
in which case the rewritten twins still match by patch-id, but the
standing exemption-reachability self-check fires on the orphaned
registered hashes and fails the gate with a self-naming message until
the register is re-keyed. In practice: run
`python3 tests/scripts/test-loop-history-guard.py` right after any
rewrite; a red `exemption ... unreachable` line IS the signal to
re-declare via ceremony.
