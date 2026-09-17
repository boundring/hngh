# 2026-09-17 -- stall-recovery step 9: quota-routing mechanism verified on its own surface; plan-text evidence was obsolete

## Question

Plan 2026-09-09-stall-recovery-and-operator-surfaces step 9 ("wire pre-paid
quota models into session routing") carried a bad-execution blocker
(blk-20260916) after a prior lane died on an oversized, unverified step. The
dream brief for this wake asserted the mechanism was ALREADY LANDED and the
plan text's evidence line obsolete. Was it?

## Decision

**Yes. The step-9 mechanism is landed and verified; this session's residual
slice was verification + the plan-file tick only.** No production surface was
edited. Arming stays off (`session-model-quota-keys=0`): arming is
critical-class operator territory (certificate or explicit instruction).

## Evidence (each read fresh this session)

- `automation/tests/test-quota-routing.sh` -- ALL PASS, rc=0, 24 cases
  (env > quota-row > local-bench > paid-fallback ladder, no-key refusal,
  demoted/unhealthy-leg skips, T1/T2/T3 interactions, budget source tags);
  registered in `automation/Makefile:174`.
- `automation/cadence-params.tsv` rows 58-59 -- `session-model-quota-keys=0`,
  `session-model-preference` empty (unarmed before and after this session;
  no param writes).
- `automation/scripts/overnight-cycle.sh:194-223` -- the quota rung behind
  the fail-closed gate (`get_param session-model-quota-keys 0` must equal
  "1"), `quota_leg_healthy` health probe + `model_demoted` demotion per
  entry, one deduped alert per beat on an unhealthy leg; `SESSION_SOURCE`
  parsed from select_model's "model|source" pipe and exported (:246-249).
- `automation/lib/launch-session.sh:499-505` -- budget rows carry model and
  source attribution (source=quota is observable only when a quota-routed
  session actually runs; with keys unarmed, verified by test inspection).

## Obsolete plan text

The step-9 evidence line quoted overnight-cycle.sh:123 "model routing
(future, not implemented)". That comment predated the landed rung; trusting
it verbatim is the likely cause of the prior bad-execution blocker. The
plan file now carries the LANDED/VERIFIED annotation on step 9.

## Residual loop

The full automation `make test` was red at tick time on the sibling
router-tick scrub-single-source lane (`test-router-tick.py`
test_two_consecutive_pathy_fragments_cut_before_the_first fails against
sibling-unstaged edits in `automation/scripts/router-tick.py` +
`automation/lib/scrub.py`) -- unrelated to this docs-only slice. The
step-9 tick is staged, uncommitted, per the step-6 precedent; the ceremony
commit lands when that lane is green. Kernel gate green (`make test`,
2931 checks passed).
