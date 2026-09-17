# Candidate reconciliation closure: the feasible rung landed, the
# ledger proposal

Date: 2026-09-17
Lane: automation free-commit (jobs/patrol.py + config + tests); kernel
proposal only, no kernel edits
Inputs: a4e1-store-inventory (store record census), a4e2-hash-
reconciliation (feasibility verdict)
Upgrade: 2026-09-17 — the gap classification (design gap, not known
limitation) and the remediation adoption are of record in
docs/records/2026-09-17-certificate-ephemerality-of-record.md.

## The gap

Every code-surface commit carries the subject `hngh: candidate
<64hex>`, and the kernel loop-history guard
(tests/scripts/test-loop-history-guard.py:193) accepts any subject
matching that regex (:284) — it has no artifact to consult. The a4e2
census closed the question of whether one exists:

- The mint path (scripts/hngh issue-cert -> src/main.lisp
  real-issue-cert:1442 -> issue-candidate-certificate,
  src/domain/governance.lisp:577-599) produces an in-memory certificate
  struct (governance.lisp:492-533); the rendered
  `certificate action=... content-hash=...` line (render.lisp:97-111)
  goes to stdout only.
- The store (~/.hngh-automation/store, 932 record.lisp files, kinds
  CREATION/ADMISSION/START/CLOSE/CHECKPOINT) contains zero 64-hex
  tokens, zero certificate-kind receipts; a full ~/.hngh-automation
  grep for 8 known hashes returns nothing.
- Side channels exist by accident (opencode transcripts in
  automation/logs/*.log.json captured renders for exactly 2 of 8
  hashes; ephemeral /tmp/hngh-fasttest-*.ok markers, same 2), which is
  evidence a ledger is missing, not a ledger.

So strict label-to-LEDGER reconciliation is INFEASIBLE today, and the
weak rung — the hash is deterministic over the certificate's candidate
paths (sha256(path+NUL+bytes+NUL), scripts/verify-candidate.py:129) —
is FEASIBLE from git alone. This record lands the weak rung and
proposes the strong one.

## What shipped (the feasible rung)

`CHECKS["candidate-reconciliation"]` in automation/jobs/patrol.py,
mounted day-tier as route `recon` (surface candidate-history) in
config/patrol-routes.tsv, next to its sibling `kernel-gate`:

- Walks the newest 24 candidate-labeled commits
  (PATROL_RECON_LOOKBACK), recomputes the hash from each commit's own
  changed paths + blob bytes, compares to the label. The commit-path
  assumption holds empirically: 9/9 newest exact, 38/40 across the
  newest 40 on this repo (the two misses predate the check; see
  below). Cert paths exceeding the commit diff (117d463f's proven
  case) make this a conservative check: it may declare a divergence
  the mint actually covered — fail-closed direction, declared rows are
  the relief valve.
- Fails closed on divergence (`label-content-divergence`, cause class
  bad-execution) and on unreadable history (`recon-fault`); quiet PASS
  on a plain history with zero labels.
- Declared divergences: config/patrol-candidate-recon-exempts.tsv
  (12-hex sha-prefix + reason, matched as a prefix; the guard's
  declared-miss convention). The two pre-closure stragglers are
  declared rows: 331fc6334bde (not re-derivable from git alone under
  any plausible path set) and 117d463fe1ad (matches only under its
  certificate's 2-path set). Rows are removed once the commit ages out
  of the lookback window.
- Wired into the automation gate (automation/Makefile test), with
  tests/test-candidate-hash-reconciliation.py — 7 unittest cases,
  written failing-first (FAILED failures=1 errors=6 pre-implementation;
  OK after), against a real temp git repo per the test-patrol.py
  RealGitClassifier convention.

Live evidence, single-route run against the real kernel repo:

    PASS recon/candidate-reconciliation 22/24 reconciled, declared 2

Honest limit, stated on the check itself: this binds label to content.
It detects a mistyped/stale/forged-hash label and any post-commit
content rewrite (history rewrite or blob substitution), but it cannot
distinguish a legitimate mint from a forged self-consistent commit —
the hash is public and deterministic. Only the ledger closes that.

## The proposal (the infeasible rung, kernel-side, not implemented)

The missing artifact is a mint-time certificate receipt. Minimal
closure, following the kernel's own seams:

- **Writer:** at `real-issue-cert` (src/main.lisp:1442) or
  `issue-candidate-certificate` (governance.lisp:577), append one
  receipt form to the run's existing store record.lisp — the store is
  already the append-only receipt surface, already bound to the run
  identity, and already written by the ceremony; the receipt needs no
  new writer machinery. Shape, matching the existing schema: a
  `(:kind :certificate :state (issued) :receipt (:kind :certificate
  :facts ("content-hash=<64hex>" "action=<action>"
  "base=<revision>" "paths=<n>")))` form. This is a kernel `src/`
  mutation: certificate path via the ceremony (propose -> issue-cert
  -> mutation-check), not a machine free-commit.
- **Location:** the minting run's store/record.lisp (the run that
  minted the certificate). A global append-only ledger under
  ~/.hngh-automation (e.g. ledger/certificates.tsv, one row per mint:
  epoch, content-hash, action, base) is the alternative if
  cross-run queries should not walk per-run records; the per-run
  record keeps the two-home split cleaner, the global ledger makes the
  checker O(1). Either persists outside git, which is correct: the
  store is machine state, not repo surface.
- **Checker:** extend the automation patrol check (free-commit lane)
  with a second phase: for each candidate-labeled commit in the
  window, require a ledger row with the matching content-hash; a
  labeled commit with no row FAILs `label-unbacked` (forged or
  mint-lost), a row whose hash does not match the label FAILs
  `label-ledger-divergence`. The existing recompute phase stays as
  the content-binding leg; together they close both directions
  (label-content and label-mint).
- **Verification:** the kernel guard can stay as-is; the ledger
  requirement lives patrol-side until the operator promotes it into
  the kernel gate (which would need src/ changes in
  test-loop-history-guard.py's enforcement path — out of scope here).

Explicitly out of scope for this slice: any src/, tests/, Makefile, or
hngh.asd edit (2026-09-03 staging boundary); the ceremony lane owns
that surface.

## Falsifiable predictions

If the ledger proposal lands as designed, then for any new candidate
commit: (1) the recompute phase reconciles (unless the cert-path
exceeds the diff, in which case the receipt's path count makes the
delta legible); (2) the ledger phase finds the mint row within the
same tick; (3) a forged self-consistent commit fails `label-unbacked`
within one patrol day — currently it would pass both the kernel guard
and the recompute leg indefinitely.
