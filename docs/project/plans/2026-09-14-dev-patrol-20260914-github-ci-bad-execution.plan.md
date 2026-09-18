<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-14 - dev-patrol-20260914-github-ci-bad-execution (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the crystallized run-close invariant from patrol-20260914-journal-error-unclaimed-err, upstream feed attribution for guardrail verdicts from patrol-20260914-github-ci-bad-execution, and comic-specific action/reaction beat-pair annotation with narrative_mode mapping from story-beat-taxonomy.

## Steps

- [ ] Add `lib/patrol_run_close.py` implementing the run-close invariant: a function that inspects a patrol run's filed journal-errors and returns failure reason `unclaimed-err` with attribution metadata (error id, run ordinal) when any error lacks a claim or waiver record before scoring.
  Verification: make test

- [ ] Extend the cadence guardrail verdict emitter in `cadence/verdict_emit.sh` to include upstream feed attribution fields (source job name, input fingerprint, consecutive-run ordinal) in the payload emitted for bad-execution filings.
  Verification: bash -n cadence/verdict_emit.sh

- [ ] Refactor `jobs/manga-draft.py` beat annotation to resolve each panel/beat unit via comic-specific action-beat/reaction-beat pairs, assigning exactly one narrative_mode value (image-only, dialogue-only, or mixed) per unit.
  Verification: python3 jobs/manga-draft.py --self-check

- [ ] Add `lib/beat_narrative_map.py` defining the mapping from beat class to expected narrative_mode ratio bounds for consumption by `jobs/manga-vision.py`.
  Verification: make test

- [ ] Write `tests/test_run_close_invariant.py` asserting that a patrol run with an unclaimed journal-error is scored as failed with reason `unclaimed-err` and carries attribution metadata.
  Verification: make test

- [ ] Append the crystallized invariant conclusion and guardrail closure condition to `digest/RESEARCH-BEAT-20260914-patrol-20260914-journal-error-unclaimed-err.md` linking the implemented check to the line's contracted record.
  Verification: grep -q 'run-close invariant' digest/RESEARCH-BEAT-20260914-patrol-20260914-journal-error-unclaimed-err.md
