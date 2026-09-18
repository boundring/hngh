# 2026-09-18 -- stall-recovery step 10: fresh-eyes review model selection verified on its own surface; suite registration was the only residual

## Question

Plan 2026-09-09-stall-recovery-and-operator-surfaces step 10 ("fix the
fresh-eyes review beat's model selection") asked for a quota ladder on
the review/digest lane and an unparseable->demotion signal. The dream
brief (2026-09-18T12:44Z) asserted the mechanism was already landed and
the residual slice was verify-and-tick plus one dropped suite
registration. Was it?

## Decision

**Yes. Landed (commits 6854d2d0, 1907079f) and verified; this
session's residual was the Makefile suite registration (automation
commit e69c119b) plus this tick.** No production surface beyond the
automation Makefile/CHANGELOG was edited.

## Evidence (each read fresh this session)

- `automation/lib/model.sh:874-896` -- MODEL_PIN=review routes
  deck -> kimi -> zai -> ocgo legs, the unsloth bench last resort,
  remote (paid openrouter) never in this lane.
- Both pin sites carry `MODEL_PIN="${MODEL_PIN:-review}"`:
  `automation/cadence/day/04-review-prep.sh:79` and
  `automation/jobs/morning-digest.sh:37` (the plan's digest-leg
  clause).
- `automation/cadence/day/04-review-prep.sh:109-119` -- an unparseable
  review feeds `record_model_outcome "$used" bad-execution` (sourced
  from lib/model-demote.sh), the same counter step 1 uses.
- `automation/tests/test-review-ladder.sh` -- ALL PASS rc=0 cold this
  session (~2s, hermetic); now registered in the automation Makefile
  test target (Makefile:156) beside the other model-leg suites
  (CHANGELOG.md already named it one of the four unsloth-leg suites).
- Live proof: telemetry kind=review rows 2026-09-14..16 served by
  `ocgo:glm-5.3-flash` and 2026-09-17 by the unsloth last resort --
  all parseable, subjects recorded, digests in
  ~/.hngh/archive/digest/REVIEW-2026-09-1*.md (an unsloth-served
  parseable review satisfies the live-beat clause per the 2026-09-17
  row). The 2026-09-18 beat mounted 12:32:02Z and was still mid-ladder
  (leg retries live) at tick time; not waited on.

## Known ceiling (documented, not unilaterally widened)

The demotion feed is real and test-proven but currently inert
downstream: the beat records colon-form model keys (deck:deck,
ocgo:glm-5.3-flash -- the last_model_used/telemetry form), while the
session ladder's model_demoted guards consult slash-form rung keys
(env/quota/bench/paid; the existing state/model-demote.tsv rows are
slash-form), and lib/model.sh's review ladder itself carries no
model_demoted guard. Widening the key surface or adding a ladder guard
is a follow-up slice; this step ships what the plan asked and records
the ceiling.

## Residual loop

Full automation `make test` red on the sibling router-tick
scrub-single-source lane only
(test_two_consecutive_pathy_fragments_cut_before_the_first; the
failing test reads neither changed file; `make -k` shows every other
suite OK) -- the same lane the 2026-09-17 step-9 record named. Kernel
gate green (`make test`, 2931 checks, rc=0), so this tick's ceremony
path was open.
