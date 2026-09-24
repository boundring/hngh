# 2026-09-24 - ceremony deep-cut: real per-principle evidence, findings plumbing, timing lines

Operator direction (2026-09-24): "Things still seem too complicated for
their own good, of late: however we can streamline Hngh's operations, we
should. Jev calls should help a lot with that, given the right approach."
Then: "let's think in more detail about how our ceremony can be
streamlined and improved, using all relevant infrastructure (including
things like Jev to produce the results needed to run the ceremony more
cheaply and efficiently). Dig deeper into the docs to see exactly how it
works." Plan Q&A decisions: scope = ALL of it, phased; dream pass =
typed-first hybrid; verdict depth = DEEP per-principle evidence (the
larger kernel surgery, same certified slice). Plan:
local://streamline-operations-plan.md (session plan file); this record is
its Phase 1 landing. Phases 2-4 (ops cuts, dream hybrid, residuals) land
as free-tier follow-ups and append here.

## The cuts (K1)

- real-issue-cert is deleted; real-mutation-check is the single
  mint+execute verb (it already re-verified everything). The drive drops
  from 6 kernel commands to 3: propose / mutation-check prepare-candidate
  / mutation-check commit. The push leg keeps its own propose +
  mutation-check push pair - "A commit certificate never authorizes a
  push" (docs/design/autonomous-development-control.md:129-131) is
  doctrine, not code.
- The verdict temp-file round-trip is gone on the drive path: the verdict
  STRUCT flows in-process (the rendered 2-line report still lands in the
  store as the audit artifact). The strict text parser survives for
  EXTERNAL operator verdict files and now accepts only the 2-line form.
- Verdict report is 2 lines instead of 12:
  `verdict state=<admitted|refused> principles=<name:result,...>` (all
  ten, fixed matrix order) and `evidence=<fact-count> findings=<n>
  hash=<content-hash>`. A missing principle result remains a refusal
  (design doc :49) - the form shrinks, the semantics do not.
- The legacy dogfood/fixture mutation path (~153 lines) is deleted -
  production always passes a verdict file.
- Preserved untouched: the fixed `hngh: candidate <hash>` message and
  recheck-then-execute (src/adapter/mutation.lisp), the
  content-hash-mismatch refusal, the prepare/commit pair separation (the
  parked disposition `transaction-certificate-system-mutations`
  disconfirmed collapsing them: environmental drift, atomicity), the
  push/commit cert separation, fail-closed filesystem replay, and every
  refusal label/exit code. tests/scripts/test-loop-history-guard.py is
  green unchanged.

## Doc-faithful evidence semantics (K2)

The design doc's own contract (docs/design/autonomous-development-control.md
:98-101: "A requirement passes only when every required fingerprint is
supplied exactly once by a :current fact") is now the implemented
semantics, not a description of a self-echo:

- 21 matrix-named requirements replace the ten identical claim-proof
  copies: closed-authority x {purpose, caller, input-contract,
  output-contract, failure-contract}; least-authority x {capability-set,
  capability-diff}; dependency-direction x {static-source}; fail-closed x
  {closed-failure-disposition}; evidence-before-claim x {claim-proof};
  atomic-mutation x {base-revision, candidate-manifest, content-hash};
  reversibility x {reversion-or-containment}; no-hidden-execution x
  {component-import}; cost-and-route-discipline x {route, budget,
  token-limit, expiry}; source-grounding x {source-manifest,
  conclusion-link}.
- Facts arrive INDEPENDENTLY via
  `evidence-fact=<principle>:<kind>:<fingerprint>` from real gathering
  (gather-evidence values, manifest per-file sha256 and role digests,
  digests of the declared propose values, a new
  `reversion=revert:<base-revision>;containment=local-commit` key, the
  run loadout's route/cost/token/time values, and the first .md candidate
  for conclusion-link). parse-evidence-requirement no longer self-echoes
  facts; unknown kinds refuse (the 24 closed kinds live in
  src/domain/governance.lisp).
- Matching is exactly-once per required fingerprint against facts of the
  SAME principle and kind (0 = missing-evidence, >1 =
  conflicting-evidence); cross-principle supply stays structurally
  impossible (design doc :102-103) and is a refusal when attempted.
- Fingerprint rule: 64-char lowercase sha256 hex, computed as
  sha256("<principle>:<kind>:<value>") so one value feeding several
  kinds never collides under the global exactly-once dedupe; non-hex or
  wrong-length refuses at parse (exit 2). `content-hash=` is now a
  required propose key (64-hex) so the verdict's hash= field always
  round-trips.
- Fail-closed consequences (intended): a bare run without HNGH_LOADOUT
  omits the route/budget/token-limit/expiry facts and
  cost-and-route-discipline refuses (the closed matrix IS the
  enforcement); no .md candidate -> conclusion-link unmet -> refusal.
  Absent values bind to an empty digest so they can never match a real
  fact. A raw `scripts/hngh propose` outside the drive must now supply
  content-hash= and real facts to pass anything - the one-shot
  `python3 scripts/omp-bridge --ceremony` wrapper supplies them all.
- Reality anchor unchanged: real-mutation-check re-gathers and compares
  cert vs evidence (src/adapter/mutation.lisp:303-305, :430-475) and
  verify-candidate.py re-verifies; fact lies cannot survive to the
  mutation.

## Findings as bounded data (K3, the Jev hook)

- scripts/ceremony-drive gains `--findings=PATH` (optional; absent = the
  exact old behavior): tab-separated `<principle>\t<text>\t<cite>`,
  fail-closed (exit 2) on >32 lines, any empty field, text or cite
  >200 chars, or an unknown principle name. Bounds mirror
  src/adapter/review.lisp:19-20 so typed challenges and chat reviews
  share one shape.
- Findings flow into the certificate's review-findings field (previously
  hard-wired `'()` at every mint site) and are compared cert-vs-evidence
  like any other value. They are recorded DATA: advisory challenges,
  never principle-satisfying evidence (design doc :57 refuses "model
  opinion as proof"; :144-145 keeps uncited/unbounded results from
  passing anything).
- NEW free-tier producer automation/scripts/typed-challenges.py
  (OBJECTIVE FILE... -> TSV on stdout, always exit 0, fail-open): one
  batched System One call (lib/typesafe.py NEW ask_nouls) with one Noul
  per principle refusal condition (design doc :51-62); a question fires
  one finding at v >= 0.7; cite = the candidate file list. Citation
  caveat (recorded): System One returns labels and probabilities only,
  so the typed cite names the judged source set, not lines; line-level
  cites remain the chat reviewer's job.
- The executor persona runs the producer first (optional, fail-open) and
  passes --findings= through the one-shot wrapper; scripts/hngh review
  stays the operator's optional deep review.

## Timing lines and the loadout derivation (K4 + wrapper)

- scripts/ceremony-drive wraps argv parse + asdf load in one
  `[ceremony-timing] startup-load <N> ms` line; scripts/omp-bridge prints
  `[ceremony-timing] bridge-sweep|bridge-mkdir|bridge-lock|bridge-rmtree|
  bridge-total <N> ms`. Same grammar as the drive's step lines, so
  automation/jobs/time-ledger.sh's parser picks every one up unchanged.
  The 88.67s job wall vs 3.68s instrumented steps gap now attributes by
  subtraction in the existing ledger (backlog.md:1073-1096 owns the
  delay-flag review; the answer itself stays an open measurement).
- The bridge derives `HNGH_LOADOUT='loadout-route-label=ceremony
  loadout-cost-limit=2000 loadout-token-limit=50000
  loadout-time-limit=<ceremony timeout>'` when the caller supplies none
  (explicit env wins) so the cost-and-route-discipline facts exist in the
  live run. The caps copy the automation session defaults; the operator
  can tighten them by exporting HNGH_LOADOUT.

## Implementation notes (gate-caught, fixed in-slice)

- The plan's co-change list missed
  tests/presentation/test-presentation.lisp:99-109, which pinned the old
  12-line verdict rendering; the gate caught it. Re-pinned to the 2-line
  contract (admitted: `verdict state=admitted`,
  `principles=closed-authority:passed`, `evidence=`, `findings=0`,
  `hash=`; refused: `verdict state=refused`,
  `source-grounding:refused` - the refused-close fixture omits exactly
  source-grounding). The "refusals stay literal" guarantee is unchanged
  and stays pinned at the struct level (reason-labels carry
  "missing-principle-result", asserted at
  tests/main/test-governance-dispatch.lisp:275-278 and
  tests/domain/test-governance.lisp:612-615).
- The doc-numbers guard enforces README's live suite count: +20 net
  checks (new deep-evidence fixture cases) moved it to 2,954 -
  README.md:67 updated, guard green ("README matches the live suite").
- Suite delta: 2,934 -> 2,954 checks.

## Verification

- Full kernel gate green on the final tree: `make test` -> "2954 checks
  passed." (38.01s wall + system load clean; loop-history guard "151
  code-surface commits checked, 27 named exemption(s), 0 violations";
  doc-numbers guard "README matches the live suite (past 2,954 checks)").
- Full automation gate green (175.11s; every suite OK incl.
  automation/tests/test-typesafe-wrapper.py; `lint-identifiers: clean`,
  `lint-home-paths: clean`).
- tests/scripts/test-ceremony-drive-commit-identity.py 2/2 OK - the
  rewritten path end to end: create-run -> admit-transport -> propose
  with 21 real facts -> verdict (10 distinct results) -> cert ->
  mutation-check -> commit, author AND committer
  boundring <boundring@gmail.com> (0.8s for both tests).
- Source-grounding refused the first fixture run (evidence=20,
  source-grounding:refused) because its candidate carried no .md
  conclusion link. The derivation stands (doctrine: "refuse when a claim
  has no citable source" - a doc-less candidate SHOULD refuse, and every
  verified commit carries its docs/record per the repo rule); the
  fixture now carries its citable source (docs/fixture.txt ->
  docs/fixture-note.md) and a fixture HNGH_LOADOUT (unknown allowance
  refuses; the kernel never self-declares its budget).
- Placement: rides the 2026-09-23 handoff's open item 2 (simplify the
  ceremony - design task first, then certified kernel slice); this
  ceremony is that slice's evidence half. Queue Next `pooled-hardware`
  and roadmap "Land stage 2" untouched.

## Landing shape (gate-caught deviation)

- The first K5 run refused at gather-evidence:
  `ceremony-drive: evidence refused: public-content evidence failed`
  (fail-closed; nothing staged - the timing lines still landed:
  bridge-sweep 9 ms, startup-load 113 ms, bridge-total 275 ms).
- Cause: verify-candidate's public-content gate
  (scripts/verify-candidate.py:18 ABSOLUTE_PATH_PATTERN over whole
  candidate files, public_content_error :240+) forbids home-root tokens
  in kernel-candidate content, and CHANGELOG.md + automation/CHANGELOG.md
  carry scrub-DOCUMENTATION lines quoting the pattern itself (the scrub
  entry's `<user>` home-dir example; the lint's fixture-login note).
  Legal in tracked content (lint-home-paths allows fixture logins by
  design), but they cannot ride a kernel ceremony candidate - and root
  changelogs had never been in one before (docs tier commits freely).
- Resolution: the tier split the repo already defines. ONE ceremony over
  the kernel surface + this record (it passes the gate, so the
  same-candidate-set rule holds for records) plus ONE free-lane commit
  for the free tier (.omp/, docs, changelogs, automation/). Same shape
  as the identity-flip slice (one ceremony + free commits). "One
  ceremony per slice" holds; no second ceremony; no historical changelog
  text was rewritten to satisfy a gate.
