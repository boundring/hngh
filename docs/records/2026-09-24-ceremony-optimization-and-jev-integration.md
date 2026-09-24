# 2026-09-24 - ceremony optimization and Jev integration

Operator asks (2026-09-24) and answers.

1. "How long did the ceremony take this time?" The certificate ceremony run
   (the machine-identity flip) took 88.67s of job wall, but the instrumented
   drive steps sum to 3.68s: mutation-check-push 2266ms (the git push),
   issue-cert 184-269ms, mutation-check 183-562ms, and propose/create-run/
   admit-transport ~0ms each. Drive startup plus a full system load is
   0.166-0.201s real. The machine timeline agrees: candidate commit
   aece42f5 sits 44s from the next plain commit. The certificate ceremony
   is therefore a seconds-scale event; the ~84s between 3.68s and 88.67s is
   outside the drive (omp-bridge wrapper or harness round-trip on
   backgrounded jobs, unattributed) and stays an open measurement question
   for the backlog time-ledger row (docs/project/backlog.md:1073-1096).
2. "What can we do to simplify and streamline our ceremony?" The evidence
   says the cost is not the certificate machinery but the model turns
   around it: orientation (up to 3.6M input tokens), timeout overhang
   (6 rc=124 kills in 7 days; 44% of ~32 sessions produced nothing; the
   2026-08-28 wave died "with candidates staged and only the certificate
   loop remaining"), duplicated gate runs (now cached), and the +600s dream
   pass. This slice lands the free-tier levers (Part A below). Kernel-tier
   levers (e.g. skipping the push leg's second verdict,
   scripts/ceremony-drive:280-321) stay reserved for the certified kernel
   slice of handoff open item 2 ("design task first").
3. "What can we do to further integrate and fully exploit Jev?" Hngh's
   classification/decision points now route through typed TypeSafe System
   One judgments (Choice/Noul with confidence) with fail-closed legacy
   fallbacks, batched one-request-per-beat; the local Jev lane gains the
   typed /v1/systemone path beside the existing chat lane; and the
   typesafe-ai skill plus a catalogue of 18 TypeSafe cookbook recipes land
   alongside (docs/design/ts-integration-assessment.md
   "## Cookbook catalogue (2026-09-24)").

## Session-ceremony cost levers (free tier; automation/, docs/, .omp/ only)

- One-shot ceremony default (.omp/agents/hngh-executor.md): the ceremony
  loop is `python3 scripts/omp-bridge --ceremony "OBJECTIVE" FILE...`
  (propose -> issue-cert -> mutation-check -> commit -> push in one call);
  the raw verbs remain only for surgical re-runs. Records and CHANGELOG
  edits land in the SAME candidate set as the code - never a second
  ceremony for records. Checkpoint-before-the-wall: at half the time
  budget, commit what is green, stage the rest, and write the remaining
  loop into the plan file.
- State digest (automation/lib/context-pack.sh): context packs carry one
  line - `state digest: beads <open> open/<closed> closed | queue next: <q>
  | roadmap next: <r>` - so sessions stop burning orientation tokens on
  facts one read already answers.
- Respawn evidence (automation/jobs/agent-respawn.sh write_brief): the
  `landed:`/`uncommitted:` fields are read-only git probes (derived repo
  root, never a literal home path); `uncommitted: clean` is an observed
  value, probe failure stays `not established`.
- Dream-brief reuse (automation/scripts/overnight-cycle.sh): dream briefs
  cache under state/dream-briefs/ keyed by sha256("$slug:$dream_step") and
  are reused when the same step is re-queued (breadcrumb
  `forethought-dream-cache`) - the +600s dream pass is paid once per step.

## Typed Jev decision seams (site -> question -> threshold -> fallback)

- automation/cadence/hour/33-research-beat.sh (research review verdict):
  one Choice {adopted, parked, killed} over {line digest, supportive pass,
  adversarial pass, doc excerpt 8000}; min_conf 0.60 (the
  consistency_choice top-prob bar); fallback = the legacy VERDICT grep;
  both absent -> the existing `research review verdict unparseable`
  alert + exit 0 (row unwritten).
- automation/cadence/day/06-review-disposition.sh (review-finding
  severity): one Choice {P1, P2, nit} per finding line, batched into one
  request per digest; min_conf 0.5 plus the monotone rule (typed can
  RAISE a finding, can never silently LOWER a model-flagged P1);
  fallback = the parsed `- P1:`/`- P2:`/`- nit:` prefix; the nit-skip is
  the named policy constant and its count now reflects final severities.
- automation/jobs/oversight-tick.sh (steer hazard): one Noul - "repeated
  identical execution with no distinct progress?" - over the recent tail;
  fire bar 0.7 (the sde_cascade FIRE_T pattern); fallback = the entire
  existing steer-model curl + `case` block unchanged (fail-open legacy).
  Advisory only: breadcrumbs are the whole surface.
- automation/ng/cadence.py (bead triage file/retry/escalate/close): the
  existing typed lane now batches - ONE typed /v1/systemone request per
  beat via jev.ask_batch (typed-first, local chat lane as fallback),
  CONF_MIN 0.5 maps low-confidence answers to UNCERTAIN, and failure
  keeps the fail-closed ESCALATE shape (batch-failure parity with
  per-question fail()).
- Infrastructure: automation/lib/typesafe.py gains
  `ask_choices(state, questions)`, `ask_choice -> (label, confidence)`,
  and the pure `arbiter(typed, legacy, labels, min_conf=0.5)` - the one
  precedence rule (typed wins at confidence, else legacy, else None);
  automation/ng/jev.py gains `_typed_batch` (one POST /v1/systemone with
  state/questions/usage per the documented schema).

Deliberately NOT converted: router-feed criticality stays the
deterministic ERE denylist (a safety park must not soften under
inference); plan admission (accept-plans.py) stays deterministic - "Jev
recommends, never certifies". Declined session levers: the push-leg
verdict skip (kernel tier), a new time ledger (backlog.md:1073-1096 owns
it), watchdog repeat-orientation detection (nice-to-have).

## Skill and cookbook catalogue

- typesafe-ai skill (MIT, typesafe-ai/skills) installed to both homes:
  ~/.omp/agent/managed-skills/typesafe-ai/SKILL.md and the repo copy
  .omp/skills/typesafe-ai/SKILL.md; both sha256-match the fetched URL
  (71ea90d7906c6554c4f4c460ef7361b2d26f59116ccdae986dc6d997b9389f52).
  `omp skill install` rejected a directory target ("expected
  @scope/name[@version|range|tag]") so the pre-decided plain-file-drop
  fallback landed both copies; `omp skill info` shares the registry-spec
  limitation (presence verified via the managed-skills directory).
- Cookbook catalogue: 18 TypeSafe cookbook recipes (docs.typesafe.ai/
  cookbooks; llms.txt confirms full coverage) with per-recipe problem
  shape, primitives, and decomposition trick, plus the seam mapping (a)-(d)
  and the adopt-now/adopt-later shortlist, landed in
  docs/design/ts-integration-assessment.md "## Cookbook catalogue
  (2026-09-24)".

## Placement (fit with planned next-steps)

- This slice rides operator-directed open item 2 (ceremony simplification:
  "design task first, then certified kernel slice"). The free-tier half is
  this record's Part A; the kernel-tier half of open item 2 (verdict
  boilerplate, store churn, push-leg verdict skip) remains the next
  ceremony work behind its certificate path.
- Queue Next `pooled-hardware` (deps open: resource-pool view, key-pin
  registry rung 12) and roadmap "Land stage 2" are untouched and remain
  the natural next queue/roadmap work.
- The time-ledger row (docs/project/backlog.md:1073-1096) remains the
  measurement slice; its "ceremony-timing lines" dependency is the natural
  follow-up, and the ~84s wrapper/harness gap recorded above is its first
  open question - nothing new is instrumented here.

## Implementation notes (recorded deviations from the plan text)

- Dream briefs are cached on executor death (rc != 0) rather than on
  dream success: the re-queued (killed) step is the population the lever
  targets (the rc=124 kill set), and store-on-death keeps the existing
  forethought and beat-blockers suites green with zero test edits.
- agent-respawn.sh write_brief derives the kernel repo with
  `git -C "$(dirname "$0")/../.." rev-parse --show-toplevel` (cwd
  fallback) instead of a cd/pwd form, so the function survives the
  sed-extract/eval shape its hermetic tests (and the verification
  throwaway) use.
- ng/jev.py failure semantics split: a whole-call typed/local failure
  yields None answers ("jev-error", no park) while the per-question soft
  fail() Answer shape keeps "jev-escalate" + park - the only split that
  preserves every pre-existing cadence branch and its order.
- The severity glue composes exactly as the plan text specifies: the
  arbiter label (typed wins >= 0.5) then the stricter-of with the parsed
  prefix, so a typed answer can RAISE a `- nit:` to P1/P2 and can never
  LOWER a flagged P1 (both directions proven in the throwaway).
- automation/CHANGELOG.md rides the levers commit carrying both its
  ceremony bullet and its jev bullet (one file, one write; a per-commit
  split would need partial staging for no behavioral gain).

## Verification (as landed)

- SDK pinning: `typesafe_sdk.TypeSafeClient.system_one` accepts
  `model: str | None = None` (verified by signature inspection at
  implementation time), so every typed call passes the pinned id
  `model="jev-1.13.0"` directly - no alias ever resolves.
- Skill + catalogue slice: the fetched URL, the managed-skills copy, and
  the repo copy all sha256 to
  71ea90d7906c6554c4f4c460ef7361b2d26f59116ccdae986dc6d997b9389f52;
  the managed-skills directory listing shows typesafe-ai/SKILL.md
  (`omp skill info` cannot address a non-registry spec - see the finding
  above).
- Severity/steer slice: `bash -n` clean on both scripts; the no-key
  behavioral throwaway (typesafe functions sed-extracted, file_report
  stubbed) routes `- P1: alpha` to the alert path with ident
  `review-finding:2026-09-24:alpha` and counts `- nit: beta` in the
  "1 nit finding(s) skipped" line; a stubbed-typed check proves the
  monotone rule both ways (typed nit over a flagged P1 stays P1; typed P1
  over `- nit:` raises to P1, 0 nits skipped).
- Typed lane (automation/ng/jev.py self-test): `jev self-check ok` -
  typed DONE mapping with usage.input_tokens=42, confidence 0.3 ->
  UNCERTAIN/None, ask_batch of 3 -> exactly ONE request + 3 answers,
  typed 500 -> local chat fallback parsed via `Label:`.
- Batched beat (throwaway: fake /v1/systemone + TYPESAFE_API_KEY=x +
  loopback TYPESAFE_BASE_URL + fabricated events): exactly 1 typed
  request for 3 events; emits slice.proposed / bead.close / slice.retry
  mapped 1:1; `automation/ng/cadence.py --dry-run` self-check green.
- Session levers: respawn brief shows a real `git log --oneline -3` and
  ';'-joined dirty paths (empty status -> "clean"); context_state_digest
  prints `state digest: beads 12 open/50 closed | queue next:
  pooled-hardware | roadmap next: Land stage 2` and the pack stays at
  the 1500-byte cap with the line present; dream cache attempt 1 (dream
  ok, executor dies) stores 1 brief, attempt 2 launches 1 session with
  the `forethought-dream-cache` breadcrumb and the cached sanity-checks
  appended; persona `grep -c 'omp-bridge --ceremony'` = 1.
- Full gate `cd automation && make test` green on the final tree before
  the code commits (every suite OK; `lint-identifiers: clean`,
  `lint-home-paths: clean`; 176.8s wall) - covers (1) and the no-key
  legacy paths (7): with TYPESAFE_API_KEY absent every arbiter falls
  back to the legacy parse.
