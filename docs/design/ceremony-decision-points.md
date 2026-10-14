# hngh kernel ceremony loop: decision-point inventory

Scope: the propose -> issue-cert -> mutation-check -> commit-on-green loop in
this repo (hngh), plus the plan-lifecycle decisions that feed it
and the post-commit push leg that closes it. Read-only survey; no repo file
was modified. Every "outputs" list is what the code actually implements, with
file:line evidence. "Decider" names the layer that owns the branch today.

Orientation sources: AGENTS.md (ceremony boundary, AGENTS.md:43-56,
82-84), docs/project/plans/README.md (plan contract, :17-107),
docs/design/autonomous-development-control.md (policy doctrine,
:64-145, :219-274), docs/design/gate-inventory.md (gate audit :9-25),
docs/project/plans/2026-08-28-overnight-continuity.ceremony-runbook.md
(loop specifics :46-63).

Loop shape implemented today (scripts/ceremony-drive:1-41):
create-run -> admit-transport -> [fast-lane branch | propose verdict ->
dry-run stop | prepare-candidate -> commit -> push-leg]. The merged verb
`mutation-check <action> run-1 <verdict>` mints the certificate and executes
the bound mutation; the commit message is the certificate's content hash.

---

## Stage 0: run admission (preconditions of the loop)

### D1. create-run accept / refuse
- (a) Trigger: first command of every ceremony-drive loop
  (scripts/ceremony-drive:434-446) and of omp-bridge --run-start
  (scripts/omp-bridge:471-480).
- (b) Inputs: OBJECTIVE positional, role (builder), fixed loadout keys
  (route-label, context/token/cost/time limits, tool labels, network labels,
  writable scopes) passed as `key=value` args
  (ceremony-drive:436-445, omp-bridge:472-480).
- (c) Outputs: run created in :created state and recorded; or exit 2 with
  "create-run needs an objective and a role", "unknown create-run key", or
  "malformed create-run: ..." (src/main.lisp:607-632). House exit protocol
  0/1/2/3 (omp-bridge docstring:48-50).
- (d) Decider: kernel application use case (src/application/create-run.lisp)
  via harness (src/main.lisp:235, 619-630); pure script logic.
- (e) Cadence: per-run (once per ceremony invocation).

### D2. admit-transport admission
- (a) Trigger: immediately after create-run (ceremony-drive:447-450,
  omp-bridge:483-486).
- (b) Inputs: run identifier, transport keyword (closed set :filesystem
  :model :terminal :federation :worker, src/domain/governance.lisp:32-41),
  optional scope; run state from store; loadout labels bound at D1.
- (c) Outputs (all implemented, src/application/admit-transport.lisp:61-105):
  - accepted + admission receipt ("admitted")
  - refused "unknown-transport" (:65-68)
  - refused "invalid-transition" when run not in :created/:armed (:69-71)
  - refused "loadout-refuses-transport" when the transport's label
    precondition fails (e.g. :model requires non-local route + model-review
    network label; :worker requires worker-task tool label) (:72-79,
    predicate at :30-48 area, labels shown :73)
  - refused "unauthorized-scope" when scope outside writable-scopes (:80-88)
  - refused callback-refusal / "duplicate-admission" conflict on the
    record port (:89-105).
  Refused admission exits 1 (dispatch layer, src/main.lisp:634-657; missing
  run -> missing-run-output).
- (d) Decider: kernel policy from the loadout the calling script fixed.
- (e) Cadence: per-run.

### D2b. mutation-check's admission recheck
- (a) Trigger: every mutation-check invocation (src/main.lisp:1506-1513).
- (b) Inputs: store, run identifier.
- (c) Outputs: proceed; or refused exit 1 "mutation-check refused: run <id>
  not admitted" (main.lisp:1509-1513); missing run -> missing-run-output
  (:1506-1508).
- (d) Decider: kernel dispatch (receipt lookup, main.lisp:110-141).
- (e) Cadence: per mutation-check (twice per drive commit leg + push leg).

---

## Stage 1: propose

### D3. omp-bridge --propose surface validation (plan file creation)
- (a) Trigger: a session files a new plan (scripts/omp-bridge:192-224).
- (b) Inputs: SLUG (must match ^[a-z0-9][a-z0-9-]*$, ASCII <=64),
  --title non-empty, --risk in {normal, critical}; PLANS dir target path
  <UTC-date>-<slug>.plan.md (omp-bridge:196-207).
- (c) Outputs: write file with front-matter
  `<!-- plan: status=proposed risk=<risk> accepted=- -->` exit 0; exit 2
  slug/title/risk malformed; exit 1 "plan already exists, never
  overwritten"; exit 3 unwritable (omp-bridge:196-221). Proposing is free:
  risk=critical is writable here; acceptance never happens at this surface
  (omp-bridge:193-195).
- (d) Decider: script logic (omp session propose surface; contract at
  docs/project/plans/README.md:61-72).
- (e) Cadence: per new plan (rare per session).

### D4. candidate evidence gather (feeds both propose and mutation-check)
- (a) Trigger: ceremony-drive entry (gather-evidence, ceremony-drive:139-145,
  373-376) and each mutation-check mint (real-run-evidence,
  src/main.lisp:1457-1462).
- (b) Inputs: candidate file list, cwd; runs scripts/verify-candidate.py
  --manifest through the process transport; git identity + per-file sha256
  (src/adapter/run-gather.lisp:139-202).
- (c) Outputs: evidence plist (repository-identity, base-revision,
  candidate-paths, content-hash, evidence-hashes, working-tree-state,
  source-manifest) on :passed; or refusal label from:
  - verify-candidate.py's closed refusal set (scripts/verify-candidate.py:
    287-346): invalid arguments; missing candidate manifest; invalid
    candidate manifest; unavailable git evidence; parenthesis evidence
    failed; dependency evidence failed; public-content evidence failed
    (credential-shaped content / absolute local path / shell execution,
    :240-258); whitespace evidence failed; relative-link evidence failed;
    candidate evidence failed. `:passed` terminator required (:378).
  - adapter-level refusals: "malformed candidate paths" (:146-148),
    "malformed candidate evidence" (report parse, :164-168),
    "unavailable repository identity" (:169-172), "unavailable file hash"
    (:173-178), "verify-candidate failed" (non-zero exit / subprocess
    fault, :198-202), first `:refused <label>` line relayed (:64-75).
  Evidence refusal halts the drive (ceremony-drive:143-144).
- (d) Decider: script logic, fail-closed (AGENTS.md:69).
- (e) Cadence: per ceremony, and re-run per mutation-check action
  (prepare-candidate and commit each re-gather; ceremony-drive:502-508).

### D5. fast-lane eligibility (skip the model-review propose leg)
- (a) Trigger: --fast-lane passed (ceremony-drive:451-470).
- (b) Inputs: whole working-tree diff vs HEAD (-w --ignore-blank-lines,
  --summary, --name-status) and verify-candidate exit over the candidate
  files (whitespace-only-candidate-p ceremony-drive:304-331;
  verify-candidate-clean-p :333-351).
- (c) Outputs: eligible -> write mechanical all-pass verdict report
  (verdict-report-fast.txt, "verdict state=admitted principles=<all 10
  passed>", mechanical-verdict-path :353-371) and go straight to
  mutation-check commit; not eligible -> exit 2 "fast-lane refused:
  candidate is not whitespace-only (or carries mode/add/remove changes)"
  or "verify-candidate not clean" (:456-463). No push certificate is
  minted in the fast lane (:468-470).
- (d) Decider: script logic (purely mechanical; P5c rung,
  ceremony-drive:452-455).
- (e) Cadence: per --fast-lane ceremony invocation (off the default path).

### D6. the ten-principle verdict (the gate of the loop)
- (a) Trigger: `hngh propose key=value...` (ceremony-drive propose-feature
  :474-478 and propose-push :405-410; operator surface src/main.lisp:1235).
- (b) Inputs: the immutable policy-proposal: closed class, problem, outcome,
  purpose, caller, contracts, declared capabilities + diff, source-manifest,
  risk-note, dependency, evidence-trigger, evidence-requirements
  (PRINCIPLE:KIND:FINGERPRINT), evidence-facts, review-findings,
  content-hash (src/main.lisp:1105-1110, 1267-1288; kinds closed at
  src/domain/governance.lisp:79-88; classes closed at :8-12). ceremony-drive
  composes the argv from real gathered evidence with one requirement+fact
  triple per principle (evidence-triples ceremony-drive:189-232;
  sha256 fingerprints :174-185). Missing loadout keys or a missing .md
  conclusion link leave the fact unsupplied (ceremony-drive:189-194, 205,
  227-232).
- (c) Outputs: per-principle :passed/:refused and verdict state
  :admitted/:refused (missing principle result -> refused
  "missing-principle-result"; requirement passes only when every required
  fingerprint is supplied exactly once by a :current fact; zero supplies ->
  missing-evidence, duplicates -> conflicting-evidence; stale/malformed/
  conflicting/unverifiable fact states add labels)
  (src/domain/governance.lisp:363-457; %evaluate-matrix :404-443;
  make-verdict-from-results :445-457). Render: exit 0 admitted, exit 1
  refused, exit 2 malformed (src/main.lisp:1299-1304). :needs-escalation is
  in the closed vocab (:91-97) and accepted by the report parser
  (main.lisp:1341-1343, 1370-1377), but the deterministic evaluator emits
  only :admitted/:refused today; no live producer of :needs-escalation
  exists in the ceremony path (see open questions).
- (d) Decider: kernel deterministic evaluator (the machine; policy fixed by
  the operator, docs/design/autonomous-development-control.md:227-235,
  interpretation-doctrine.md §5 "Meaning is read; the evaluator decides").
  Model review is advisory only and never satisfies an evidence requirement
  (ceremony-drive:17-19, 27-32; main.lisp:1179-1198).
- (e) Cadence: per proposal: twice per standard ceremony (commit proposal
  + push proposal), once in fast lane (mechanical verdict instead of this
  evaluator), zero in dry-run after this point.

### D6b. policy-profile narrowing
- (a) Trigger: propose with profile=<path> (src/main.lisp:1289-1298).
- (b) Inputs: operator profile file, strict PRINCIPLE<TAB>KIND lines
  (main.lisp:1200-1233).
- (c) Outputs: profile read failure -> exit 2 "propose refused: cannot
  read/malformed profile file"; else evaluation over only permitted kinds;
  a listed principle whose kinds are all dropped refuses as missing
  (governance.lisp:539-557, "The profile only narrows" :482-487).
- (d) Decider: kernel evaluator over operator-authored profile.
- (e) Cadence: rare (operator profiles, rung 16).

### D7. dry-run dream stop
- (a) Trigger: --dry-run (ceremony-drive:480-501).
- (b) Inputs: verdict text, candidate paths, content hash, store path.
- (c) Outputs: stop before the executor; print per-step exit codes and the
  exact mutation-check commands the real drive would run; exit 0. No
  prepare-candidate, no commit certificate, no push leg (:34-41).
- (d) Decider: invocation flag (operator/rehearsal choice).
- (e) Cadence: rehearsal only.

---

## Stage 2: issue-cert (certificate mint, inside mutation-check)

### D8. mint gate: certificate issued or not
- (a) Trigger: real-certificate mint inside the merged mutation-check verb,
  after the verdict and evidence checks (src/main.lisp:1463-1466).
- (b) Inputs: parsed/admitted verdict; repository-identity, base-revision,
  sorted candidate-paths, content-hash, evidence-hashes, review-findings,
  source-manifest, policy-profile "real", expiry = now + 86400s
  (main.lisp:1413-1428).
- (c) Outputs: exactly one certificate binding one closed action
  (:none :prepare-candidate :stage :commit :push :wake-mutation,
  governance.lisp:564-567); mint refuses (error -> malformed path) when the
  verdict is not :admitted (governance.lisp:642-664, "Certificate requires
  an admitted verdict"). Mint-time receipt appended on success, ledger
  fault never gates (scripts/cert-receipts.lisp:30-55; ceremony-drive:429-433).
- (d) Decider: mechanical issuer; the verdict is the only input that can
  block (governance.lisp:646-651 docstring).
- (e) Cadence: per action per ceremony (commit cert, push cert; fast lane
  commit cert only).

---

## Stage 3: mutation-check (execute / interpret)

### D9. verdict-source interpretation
- (a) Trigger: mutation-check receives an in-process verdict struct or a
  verdict report path (src/main.lisp:1447-1453; dispatch :1514-1519).
- (b) Inputs: verdict file text at PATH (strict two-line format,
  main.lisp:1314-1399).
- (c) Outputs: proceed; refused exit 1 with label "missing-verdict-file"
  (:1406-1408) / "malformed-verdict-evidence" (any shape deviation,
  :1329-1361, count!=10 :1383-1385) / "unadmitted-verdict" (:1454-1456);
  missing third positional -> refused "missing-verdict-evidence"
  (:1515-1519); parse exception -> exit 2 "malformed mutation-check"
  (:1520-1521).
- (d) Decider: kernel parser + state check (deterministic; the operator
  produced the report, the kernel validates it).
- (e) Cadence: per mutation-check.

### D10. executor precondition pass/fail (the mutation-check gate itself)
- (a) Trigger: execute-mutation immediately before the fixed command
  (src/adapter/mutation.lisp:394-428, 430-473).
- (b) Inputs: certificate facts vs freshly gathered mutation-evidence
  (identity, base-revision, candidate-paths, content-hash, evidence-hashes,
  verdict signatures, review-findings, source-manifest, policy-profile,
  now). Requested action from CLI must match the certificate action.
- (c) Outputs (closed MUTATION-RESULT statuses, mapped to exits at
  src/main.lisp:1485-1490):
  - :executed -> exit 0
  - :mismatch -> exit 1, any of (mutation.lisp:275-315):
    repository-identity-mismatch, base-revision-mismatch,
    candidate-paths-mismatch, unsafe-candidate-path, content-hash-mismatch,
    evidence-hashes-mismatch, principle-verdicts-mismatch,
    review-findings-mismatch, source-manifest-mismatch,
    policy-profile-mismatch
  - :refused -> exit 1, any of (mutation.lisp:317-341, 430-472):
    malformed-expiry, expired-certificate, unadmitted-certificate-verdict,
    missing-principle-verdict, unsafe-candidate-path, malformed-input,
    unsupported-action, unauthorized-action, no-op-action,
    missing-fresh-evidence, malformed-evidence, evidence-gather-fault,
    gather label from D4
  - :transport-fault -> exit 3 ("transport-fault", mutation.lisp:415-418)
  - :command-failed -> exit 1 ("command-failed" + git's exit code,
    mutation.lisp:423-427) — a red gate here is a fact, not a decision.
  Every refusal performs no mutation transport call (mutation.lisp:434-435).
- (d) Decider: executor policy, deterministic recheck ("rechecked before the
  fixed command", mutation.lisp:3-6; doctrine :129-131).
- (e) Cadence: per action (prepare-candidate, commit, push, wake-mutation);
  commit leg runs it twice (prepare + commit each re-gather).

### D11. per-action command binding
- (a) Trigger: precondition passed (mutation.lisp:355-379).
- (b) Inputs: certificate action + candidate paths + content-hash.
- (c) Outputs: fixed argv — :prepare-candidate/:stage -> `git add -- <paths>`;
  :commit -> `git commit --message "hngh: candidate <content-hash>" --
  <paths>`; :push -> `git push origin HEAD`; :wake-mutation -> `hngh
  wake-peer <base-revision> <pins...>`; otherwise refused
  "unsupported-action" (mutation.lisp:409-411).
- (d) Decider: script logic; the executor never invokes a shell or chooses
  policy (mutation.lisp:3-6).
- (e) Cadence: per action.

### D12. drive-level proceed/abort chaining
- (a) Trigger: after every step in drive-loop (create-run, admit-transport,
  propose, each execute, push propose).
- (b) Inputs: exit code of the previous step.
- (c) Outputs: 0 -> continue to next step; any positive code -> return it
  immediately, loop ends, no later stage runs (ceremony-drive:446, 450,
  478, execute at :423-433, push propose at :411-412). There is NO in-drive
  retry: a refused ceremony is surfaced, never re-attempted inside the
  drive (retry handling lives one layer up, D19/D21).
- (d) Decider: ceremony-drive script logic.
- (e) Cadence: per ceremony.

---

## Stage 4: commit-on-green, push-now-vs-hold

### D13. commit-now (the "green" landing)
- (a) Trigger: prepare-candidate succeeded and commit mutation-check minted
  (ceremony-drive:506-507).
- (b) Inputs: commit certificate (D8) + fresh evidence recheck (D10).
- (c) Outputs: `git commit` executed with the certificate-bound message;
  receipt appended; else the D10 closed statuses.
- (d) Decider: executor + verdict already admitted (no human anywhere on
  this path for normal-class candidates; AGENTS.md:74-84 — verified commits
  need no prior operator instruction).
- (e) Cadence: per ceremony (the commit-on-green moment).

### D14. push-now vs skip
- (a) Trigger: after a successful commit (push-leg, ceremony-drive:401-422).
- (b) Inputs: `git remote get-url origin` exit code (origin-present-p,
  ceremony-drive:281-288).
- (c) Outputs: origin exists -> run a SECOND full propose under
  class=push-request into a fresh verdict (D6 with push capability facts,
  ceremony-drive:194-232), keep verdict-report-push.txt, then
  mutation-check push; any positive exit aborts. No origin -> clean skip,
  exit 0 "committed (no origin; push skipped)" (:419-421). A commit
  certificate never authorizes a push (ceremony-drive:13-16, 402-404;
  mutation.lisp docstring governance.lisp:648-651).
- (d) Decider: script logic on repository config; the push verdict is the
  kernel's.
- (e) Cadence: per ceremony (post-commit).

### D15. ceremony lock / timeout decisions (bridge wrapper)
- (a) Trigger: omp-bridge --ceremony wraps ceremony-drive
  (omp-bridge:339-425).
- (b) Inputs: global flock /tmp/hngh-ceremony.lock (LOCK_EX|LOCK_NB),
  CEREMONY_TIMEOUT (default 1800s), store writability, findings file.
- (c) Outputs: exit 1 "ceremony already in progress (lock held)"
  (:383-388); exit 3 on timeout "no commit landed; store removed"
  (:404-407) / unwritable store (:368-372) / missing ceremony-drive
  (:348-351); exit 2 empty objective/files/malformed findings
  (:352-357, read-findings-file ceremony-drive:106-135); else relay
  ceremony-drive's code (:411-414). Findings ride as advisory data, capped
  at 32 rows x 200 chars, fail-closed malformed.
- (d) Decider: script logic.
- (e) Cadence: per bridge-invoked ceremony.

---

## Feeding layer: plan lifecycle decisions (accept / hold / park / execute)

### D16. plan auto-accept ladder (accept-plans.py, one pass per plan per tick)
- (a) Trigger: cadence tick runs automation/scripts/accept-plans.py over
  docs/project/plans/*.plan.md (contract docs/project/plans/README.md:
  41-56).
- (b) Inputs per plan: front-matter status/risk/accepted; git HEAD status of
  the same file; `principle:` line; explicit docs/design/... references;
  Verification lines per step; both repos' `make test` exit codes; gate
  flock.
- (c) Outputs, in code order (accept-plans.py:394-540):
  - identity drift (HEAD accepted vs tree proposed/unaccepted) -> alert +
    blocked plan-identity-drift (:401-414)
  - status=held -> still-held missing-design, or re-proposed when the
    design landed (:415-430)
  - risk=critical -> parked for the operator, never machine-executed
    (:431-436)
  - no `principle:` line -> blocked missing-principle (:437-446)
  - referenced design doc missing -> status=held + research-subject demand
    (:447-462)
  - a step without a Verification line -> blocked step-N-no-verification
    (:479-491)
  - gate lock busy -> deferred, blocked gate-lock-busy, retry next tick
    (:496-514)
  - kernel gate red -> blocked kernel-gate-red-rc<N> for all runnable plans
    (:516-524); automation gate red -> blocked automation-gate-red-rc<N>
    (:525-532)
  - else -> auto-accepted: status=proposed -> accepted with UTC timestamp
    (:533-540).
- (d) Decider: script logic implementing standing operator policy
  (README.md:41-47; doctrine :227-249 "operator decides the POLICY").
- (e) Cadence: per cadence tick, per proposed plan.

### D17. body-hold self-park marker
- (a) Trigger: a proposed plan carries
  `**HOLD - do not accept/execute without promotion.**` before ## Steps
  (docs/project/plans/README.md:48-56).
- (b) Inputs: plan body line matching /HOLD.*do not accept/i.
- (c) Outputs (documented contract): parked <slug>
  body-hold-promotion-required + deduped alert; status stays proposed;
  removing the marker re-enters the pool. Drift note: no consumer for the
  marker exists in the current accept-plans.py (no HOLD match found
  accept-plans.py:1-540) — see open questions.
- (d) Decider: script logic per contract; promotion to executed is an
  explicit operator/later-session act (README.md:55-56).
- (e) Cadence: per tick per held plan (rare).

### D18. step selection + execution dispatch (overnight-cycle.sh)
- (a) Trigger: every development beat.
- (b) Inputs: plan front-matter status, first unchecked step, priority=high
  flag, synth-origin marker, blocker-row state, FORETHOUGHT_DEPTH.
- (c) Outputs: only status=accepted plans supply steps; parked blocker rows
  are excluded from rotation; ordering = priority=high bucket, then
  filename order, synth-origin last; concurrency per fail-first tier
  (automation/scripts/overnight-cycle.sh:644-684, 719-728, 1146-1186).
- (d) Decider: script logic.
- (e) Cadence: per beat (24/7 cycle, README.md:36-40).

### D19. retry-vs-escalate on repeated failure (blocker ledger)
- (a) Trigger: a session death (degraded/failed) on a plan step
  (overnight-cycle.sh:1155-1174; automation/lib/beat-blockers.sh:1-92).
- (b) Inputs: outcome ok/degraded per session; cause class; same-cause
  attempt count in state/beat-blockers.tsv; blocker-escalate-n (default 2);
  blocker-park-cooldown-hours.
- (c) Outputs: success -> blocker_clear (row removed); failure -> attempts
  bumped; attempts >= escalate-n and not yet parked -> blocker_park
  (state=parked, beat-parked alert, plan excluded at :664-667) — bounded
  retries, never infinite; parked rows auto-unpark after cooldown and
  attempts reset (:59-92 header comment). rc=75 (bridge refused) -> failed,
  alert, blocked event (:1052-1059).
- (d) Decider: script logic (the supervision plane's rubric: repeats are a
  loop; docs/design/gate-inventory.md:14).
- (e) Cadence: per session death; park rare (escalate threshold).

### D20. forethought dream gating
- (a) Trigger: before launching an executor session for a step
  (overnight-cycle.sh:740-757, 1120-1150).
- (b) Inputs: step text regexes (kernel paths src/|tests/|Makefile|
  hngh.asd; unproven markers unverified|unproven|extension|hook|
  session_start|MCP; sibling file-sharing), blocker-row presence,
  FORETHOUGHT_DEPTH, typed-brief helper gate (typed-first:
  overnight-cycle.sh:815+).
- (c) Outputs: dream session launched (bounded 600s) / cached brief reused /
  typed brief rendered with no session / dream dead-empty -> "step proceeds
  undreamed" breadcrumb (fail-open, advisory-only, :1016-1028).
- (d) Decider: script logic; the dream itself never mutates.
- (e) Cadence: per risky step (depth 1) or every step (depth >=2).

### D21. session outcome classification
- (a) Trigger: session end (overnight-cycle.sh:1060-1067).
- (b) Inputs: rc, log non-emptiness, disposition, cause.
- (c) Outputs: ok (rc=0 and log non-empty) vs degraded; rc=75 ->
  bridge-refused alert + failed; dead:missing-knowledge or
  dead:missing-design -> research-subject demand seeded (:1095-1104);
  accepted plan with no unchecked steps -> status=executed + progress row
  (:1069-1076); post-session critical-path audit -> alert, never
  auto-revert (:1080-1090).
- (d) Decider: script logic.
- (e) Cadence: per session.

### D22. keyword park at dispatch layer
- (a) Trigger: queue item / step text evaluated
  (overnight-cycle.sh:254-256).
- (b) Inputs: title text vs regex provider|credential|token|systemd|
  security|secret|delet.
- (c) Outputs: park for operator with alert; never attempted
  (overnight-cycle.sh:11-12).
- (d) Decider: script logic (mirrors critical-class policy).
- (e) Cadence: per queued item / plan text per beat.

### D23. red-gate cure (patrol)
- (a) Trigger: kernel-gate-red detection by jobs/patrol.py gate-cure route
  (automation/jobs/patrol.py:15-18, 1043-1047).
- (b) Inputs: loop-history guard red state; violating commit hashes +
  patch-ids; LARGE-precheck classes (credentials/systemd/spend paths,
  patrol.py:845-866); doctrine amendment (SMALL matter,
  autonomous-development-control.md:251-274).
- (c) Outputs: eligible (operator-approved, suite-validated class) ->
  declare in KNOWN_EXEMPTIONS + decisions.md batch entry + drive
  ceremony-drive itself (:936-980); LARGE-surface content, red suite, or
  verdict refusal -> file alert + park for operator (doctrine :265-270).
  The ten-principle verdict and verify-candidate (make test) stay the gate;
  nothing bypasses them (:269-270).
- (d) Decider: machine patrol within the recorded SMALL-matter policy;
  operator boundary unchanged for LARGE.
- (e) Cadence: rare (only on red-gate detection).

### D24. run close disposition
- (a) Trigger: delegation death/landing -- omp-bridge --run-end
  (omp-bridge:491-503) or operator close-run.
- (b) Inputs: client-supplied disposition from the closed set
  cancelled|evacuated|dead (DISPOSITIONS omp-bridge:430; close-target-for
  src/main.lisp:764-770).
- (c) Outputs: legal transition applied; illegal ones refused
  invalid-transition exit 1 (src/application/close-run.lisp:54-55; the
  refusal is the contract working, omp-bridge docstring:20-28); malformed
  disposition exit 2 (main.lisp:771-779). A bridge run never enters
  :running, so its legal close from :created is cancelled.
- (d) Decider: calling session picks the disposition honestly; kernel
  validates legality (lifecycle state machine).
- (e) Cadence: per delegated run end.

### D25. review verb (advisory rung, no authority)
- (a) Trigger: optional operator run `hngh review run-1
  content-hash=... reviewer=<file>` (src/main.lisp:1003-1056).
- (b) Inputs: reviewer transport file, content-hash, paths, policy-context;
  run must hold a :model admission receipt.
- (c) Outputs: review findings (bounded, source-cited) or refused:
  no-review-transport / not admitted / transport-fault / output-too-large /
  output error (review.lisp:197-198, 481-493). Findings can ride a proposal
  as advisory data and never satisfy an evidence requirement
  (main.lisp:1179-1198; ceremony-drive:27-32); review disagreement maps to
  :needs-escalation in the failure-disposition table
  (governance.lisp:62) but cannot override a deterministic refusal
  (doctrine:133-145, interpretation-doctrine.md §5).
- (d) Decider: model critic advises; kernel remains the gate.
- (e) Cadence: optional per ceremony (operator-invoked; ceremony-drive
  itself runs zero review round-trips, ceremony-drive:17-19).

---

## Who decides today (summary)

- Kernel deterministic evaluator: every verdict (D6, D6b), certificate mint
  gate (D8), every executor precondition/mismatch/refusal (D9, D10),
  lifecycle legality (D2, D24). It "judges; it never initiates"
  (interpretation-doctrine.md §4).
- Script logic (ceremony-drive, omp-bridge, accept-plans.py,
  overnight-cycle.sh, patrol.py, beat-blockers.sh): sequencing, abort, the
  push-now/skip branch, plan accept/hold/park/blocked ladder, dream
  routing, retry counting, park escalation, gate-cure eligibility. All of
  this is codified operator policy, amended in records (doctrine :219-249,
  :251-274).
- Human (operator): critical-class plans (D16), body-hold promotion (D17),
  LARGE-matter surfaces (credentials, provider config, systemd lifecycle,
  spend caps, non-prune deletions, public surface — doctrine :227-235),
  keyword parks (D22), LARGE ceremony refusals (D23), reserve-reviewer
  exceptional review (doctrine:139-140). "Only actions with NO certificate
  path park on the operator" (hngh-minimal-core-spec.md principle A3,
  :44-46; AGENTS.md:47-50).
- jcode/omp sessions: author proposals and plan files (D3), call the drive
  (D15), choose close dispositions honestly (D24); they hold no authority
  of their own — a session's work rides run governance (omp-bridge:15-18).

## Cadence summary

- per-run: D1, D2, D24.
- per-ceremony (per commit attempt): D4 (entry gather), D5, D6 (x2 standard:
  commit + push proposals), D7, D8/D9/D10/D11 (per action), D12, D13, D14,
  D15, D25 optional.
- per-cadence-tick (per plan/step): D16, D17, D18, D20, D21, D22.
- per-failure: D19 (attempt bump), D23 (red gate).
- rare: D6b (operator profiles), D17 (body holds), D23 (gate cure).

## Validation

- All file:line references were read directly in the working tree at
  the hngh checkout (git checkout as found; no writes to the
  repo). Verifier cross-checks: grep for each refusal label cited
  (unadmitted-verdict main.lisp:1456, not-admitted :1511,
  missing-verdict-evidence :1519, mutation adapter labels
  mutation.lisp:317-341, verify-candidate refusals :287-346,
  accept-plans note() calls :414-540, overnight blocker park :1167-1174).
- The loop order and the merged-verb design were confirmed against
  ceremony-drive's own header (:1-41) and its drive-loop body
  (:373-508).

## Open questions / what I did not check

1. Body-hold drift: plans/README.md:48-56 documents accept-plans.py
   emitting `parked <slug> body-hold-promotion-required`, but no HOLD
   matcher exists in the current accept-plans.py. Either the consumer
   moved or the contract is stale; I did not search the automation git
   history to date the change.
2. :needs-escalation has no live producer in the ceremony path I traced
   (the deterministic evaluator emits only :admitted/:refused; the parser
   accepts it and the failure-disposition table maps review-disagreement to
   it). Whether the combiner/review lane can emit it end-to-end was not
   traced into src/adapter/review.lisp's finding synthesis.
3. The wake-mutation leg (:wake-mutation certificate action) exists in the
   closed action vocabulary and command table but I did not walk its
   federation/pins preconditions (dispatch-wake-peer, src/main.lisp:1677+)
   to the same depth.
4. I read plans/ headers + README + the ceremony runbook only, per task
   scope; individual plan bodies may encode additional per-plan decisions
   not inventoried here.
5. GOVERNANCE.md sections 2/6/7 and decisions.md were referenced via
   doctrine docs but not read directly; exact governance-article numbering
   for each decision is therefore second-hand.
