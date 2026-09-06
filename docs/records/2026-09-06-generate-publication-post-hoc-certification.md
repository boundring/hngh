# 2026-09-06 — Post-hoc certification of the generate-publication change

## Scope

The portfolio lane landed commit `526cd3f` ("docs: portfolio surface —
ebook build, README pointer, journal mission lines") directly on
`origin/main`. The commit is docs-shaped but also modified the kernel
script `scripts/generate-publication` (ebook/journal build changes,
including the `mission_line` renderer), so it is a code-surface commit
under the loop-history guard — and it carried no candidate label. The
guard caught it and the gate (`make test`) went red, as designed.

## Decision

Pushed history is never rewritten, so the violation itself cannot be
relabeled. The cure follows the two mechanisms this repo already
records, in this order:

1. **Declared, not rewritten.** The guard's named-exemption table lists
   `526cd3f` with the reason, exactly as the pre-guard miss `915e0e3`
   was declared (decision entry 2026-08-25; extended 2026-09-06 in
   `docs/project/decisions.md`). The declaration exempts one past
   commit; the rule for future commits is untouched. This landed as its
   own candidate: `073889d hngh: candidate 6db34f89...`.
2. **Cured through the loop.** The script was reverted to its pre-miss
   content and re-applied as two certificate-bound candidates, so the
   final script content is bound by a real ceremony and every new
   script-touching commit carries a candidate label:
   - Revert candidate: `4edcaaa hngh: candidate 29ab16bd...`
     (content restored from `526cd3f^`, blob `b5ed223`).
   - Re-apply candidate: this commit, binding the final
     `scripts/generate-publication` content (the ebook/journal build
     changes from the portfolio lane) together with this record.

## Evidence

- Loop-history guard before the cure: `1 violation(s): 526cd3f docs:
  portfolio surface ...` (exit 1 in `make test`).
- Each candidate ran the standing ceremony surface end to end against
  real repository evidence: `create-run` (operator loadout, local
  route, mutation tool label, no network) -> `admit-transport run-1
  filesystem repository` -> `propose` under the ten closed principles
  (one claim-proof evidence requirement per principle; verdict state
  admitted, principles=10) -> `issue-cert prepare-candidate` +
  `mutation-check` (git add) -> `issue-cert commit` + `mutation-check`
  (fixed-message `git commit hngh: candidate <content-hash>`).
- The gate after the cure: `make test` green; guard reports 77
  code-surface commits checked, 2 named exemptions, 0 violations.

## Remaining unknowns

None for this miss. The portfolio lane's process gap (a docs lane
treating a kernel script as docs) is the lesson recorded here; the
guard remains the machine-check that the lesson holds.
