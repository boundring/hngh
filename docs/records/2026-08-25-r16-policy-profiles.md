# 2026-08-25 — Rung 16: operator policy profiles

## Scope

Lands the operator-tunable policy profile on `propose`: a named,
parsable, fail-closed spec that narrows which requirement kinds a listed
principle may carry, plus the `:review` requirement kind so a profile
can demand review evidence. The closed evaluator is unchanged; a profile
only narrows admission, never broadens it.

## Decision

1. `hngh.domain` gains the pure `evidence-profile` value: a list of
   `evidence-profile-entry` values (principle → permitted requirement
   kinds). Duplicate principles refuse; non-closed kinds refuse;
   permitted kinds are deduplicated. `profile-permitted-kinds` returns
   NIL for an unlisted principle — the plain evaluator behavior.
2. The requirement-kind vocabulary admits `:review` (review facts
   already existed from the rung-6 adapter; no kind could demand them).
3. `evaluate-policy-proposal-under-profile` shares the evaluator body
   (`%evaluate-matrix`) with the plain path, filtered by the profile:
   a listed principle keeps only its permitted kinds; a principle whose
   kinds are all dropped refuses as `missing-principle-result`.
4. `propose` gains `profile=PATH` following the pins/verdict/reviewer
   file precedents: strict `PRINCIPLE<TAB>KIND` lines, `#` comments and
   blanks skipped; a missing file refuses `cannot read profile file`,
   a malformed one `malformed profile file`, both exit 2 before any
   evaluation. Without `profile=`, behavior is unchanged.

## Evidence

- Tests first, red (`check failed: the review requirement kind is
  admitted`), then green: `make test` passes 8 reader guards and 2732
  checks (+13: domain profile value, narrowing refusal/admission,
  duplicate/closed-kind refusals; dispatch-level `profile=` refusal,
  admission, and malformed-file exit-2).
- The dispatch-level tests exercise the real `propose` surface through
  `dispatch-command`: a profile permitting only `:review` refuses a
  claim-proof proposal (exit 1, `missing-principle-result`) and admits
  one carrying review evidence (exit 0).
- Committed through the self-governed validation loop: `src/packages.lisp`
  exports via the chore lane excluded by the dependency guard
  (`e8bfaad`); the implementation and tests were proposed (admitted
  10/10), certified against real evidence, and committed as
  `hngh: candidate aedd723…` (`c7b1985`), pushed; gate green.
- README, changelog, roadmap, and this record updated; the roadmap
  `Next` no longer names policy profiles.

## Remaining unknowns

- The policy-profile rung consumed review kinds; the next standing
  candidate is the bridge-backed continual worker or the node-lattice
  admission rung from the backlog.