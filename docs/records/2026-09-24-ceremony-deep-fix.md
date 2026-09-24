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

## Phase 2 - ops streamlining (2026-09-24)

Behavior-identical cuts plus the typed levers; free-tier commit
`automation: ops streamlining (guard-ladder, probe gate, emit_plan,
triage hoist, report shim)` (13 files, 352+/216-).

- O1 guard-ladder fold (automation/lib/model.sh:1161-1206): the five
  copy-pasted guard blocks collapse to one ordered leg loop with per-leg
  skip sets; proven byte-identical across 130 pre/post scenarios
  (rc/MODEL_USED/reply/leg-attempt order).
- O2 probe gate: the studio probe (models + queue) moved inside the
  beatskip verdict refresh window (automation/lib/model.sh:1094-1129):
  3 requests per window became 1. Comment drift fixed; the schedule row
  now precedes the beatskip row (byte-identical payloads).
- O3 emit_plan (automation/scripts/overnight-cycle.sh:331-381): the
  twin plan producers share one model lane and three fail-closed gates;
  plan bytes unchanged (md5 efae894eb612c893363d977019174a9f
  before/after). Declined its deeper write-fold: the byte-critical
  per-kind write sets stay in the callers verbatim.
- O4 triage hoist: automation/lib/typesafe.py NEW triage_glue + a
  `__main__` dispatch; jobs/morning-digest.sh:22-30 and
  cadence/hour/33-research-beat.sh:72-78 shrink to the one-call glue
  (16/16 old-vs-new byte-equivalence).
- O5 report shims: the four private report paths move behind NEW
  automation/lib/report_queue.py report() (evidence-token policy
  single-sourced); 125 scoped tests green.
- O6 typed levers: raise_step_classes (raise-only, arbiter min_conf
  0.5; T3 voted t1 stays T3) and the ux-review typed-first register
  pass (fire bar 0.7; rows `ux: <register> risk p=N.NN`; nothing fired
  -> one `ux: no findings (typed)` row and no chat call; any None ->
  the legacy chat path byte-identical). O6b's question set = the two
  house registers named in the header and prompt (writing-register,
  display-register): the prompt has no clean dimension list; reading
  approved via operator IRC during the slice.
- R2 closed by observation (no edit): automation/lib/model.sh:798-819
  _model_emit already emits `${wall:+--wall-s "$wall"}` from curl
  time_total - kind=model rows carry wall times; one path kept, not
  two.

## Phase 3 - typed-first dream briefs (2026-09-24)

- automation/scripts/overnight-cycle.sh: dream_typed_brief :795-844
  renders the five dream fields from ONE typed judgment (three Choice
  questions + two risk-framed Nouls over state {pack, plan, step} = the
  dream prompt text, the plan text, the step text); the run block
  :988-1001 tries the typed brief BEFORE the dream session (elif
  ordering): all-green -> the five `field: value` lines replace the
  session, flow into the EXISTING `## Dream sanity-checks` append +
  dream_informed=1, and cache at the same dream_cache_key path.
- Escalation gate (hard, fail-closed): requirements=clear,
  surfaces=named, split=single with every Choice confidence >= 0.5,
  failure-modes Noul < 0.5, sanity-checks Noul < 0.5. Anything else
  (low confidence, any None, no TYPESAFE_API_KEY) prints nothing and
  the existing session dream runs unchanged.
- Coherence fix over the plan text: the sanity-checks question is
  risk-phrased ("Is the step verification too weak to catch a wrong
  implementation?") so BOTH Nouls share the plan's "both Nouls < 0.5"
  green rule; field NAMES kept verbatim per the dream-brief contract.
- Verification (fake loopback /v1/systemone, TYPESAFE_API_KEY=x): no
  key -> launches=1 (session path byte-identical); all-green typed ->
  launches=0, dream_out = 5 lines exactly, sanity-heads=1, breadcrumb
  `forethought-dream-typed`, cache stored.
  tests/test-overnight-forethought.sh, tests/test-beat-blockers.sh,
  tests/test-session-class.sh green with zero test edits.
- Gate-caught: automation/scripts/lint-identifiers.sh flagged `defined
  but never referenced: DREAM_PACK` - the env prefix sat at line start
  (line-start NAME= is a definition there; only $NAME counts as a
  reference). Fixed with the POSIX `env` prefix (names move mid-line,
  invisible to the lint); the house inline-glue pattern avoids this by
  living inside `$(...)`. Lint clean and proof re-run green after.
- Known seam: build_dream_prompt now runs before the cache check (both
  typed and session paths share the prompt file), so the prompt
  artifact is written on cache hits too. Harmless; noted for honesty.

## Phase 4 - residuals (2026-09-24)

- R1 (the backlog row's named review trigger):
  NEW automation/tests/test-slow-units-e2e.py (3 hermetic cases):
  (i) fixture time-ledger.json -> slow-units.py one row plus the
  report-queue identity+window ` xN` bump args through the real
  probe_time_ledger seam; (ii) oversight-tick.sh's alert() with mocked
  filing: the same slow-unit row twice within SUPPRESS_MIN -> one call,
  and a second call after the window with the same identity (the
  flap-suppressed alert feeding the steer path); (iii)
  jobs/time-ledger.sh's journal / `[ceremony-timing]` / drop-in parse
  round-trips into a temp time-ledger.json (unit, last_wall_s, runs_24h,
  p50_s, max_s, step/ms/ts). Wired into automation/Makefile after
  test-slow-units.py. The seeded-delay rule stays covered by
  tests/test-slow-units.py - not duplicated.
- R2: closed by observation (see Phase 2) - no second wall-s path.
- R3: docs/project/queue.md's key-pin registry rung 12 dep is VERIFIED
  struck (roadmap.md rung-12 entry + the r14 ed25519 record as
  evidence); `pooled-hardware` keeps its one open dep (resource pool
  view). The strike rode the machine ledger-sync commit 4f268513
  mid-session (cadence sweep) - recorded here so the landing shape is
  honest.
- Placement: this slice rides handoff open item 2's attention; Queue
  Next `pooled-hardware` and roadmap "Land stage 2" untouched; the
  backlog.md:1073-1096 time-ledger row remains the measurement slice -
  its named review trigger now exists, and the ~84s ceremony gap stays
  an open measurement question for that row (this plan instrumented
  the attribution, not the answer).
