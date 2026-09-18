# 2026-09-18: gate cure - loop-history guard red on bbbec8f0

## Symptom

Repo-root `make test` fails on
`tests/scripts/test-loop-history-guard.py` with 1 violation:
`bbbec8f0` ("tests: pin probe-model-route HTTPError-is-live branch",
2026-09-17 11:56) touches `tests/scripts/test-probe-model-route.py`
without the `hngh: candidate <hash>` label or a labeled exemption.

## Diagnosis

The commit is a pure test pin: 40 added lines in
`tests/scripts/test-probe-model-route.py` (HTTPError stand-in + two
pin tests) exercising an already-landed branch of
`scripts/probe-model-route`. It is pre-existing origin history
(`merge-base --is-ancestor bbbec8f0 origin/main` holds). It was not
committed through the ceremony and not covered by the labeled
exemption path (which only permits `src/packages.lisp`).

## Cure

Declared post-hoc in the loop-history guard's `KNOWN_EXEMPTIONS`
(hash primary, patch-id purge-proof fallback), per the standing
post-hoc policy used for the 2026-09-14 and 2026-09-17 gate-cure
patrols. History is NOT rewritten or amended; the declaration commit
itself rides the ceremony (certificate-bound candidate).

Also added a guard regression test in
`automation/tests/test-loop-history-guard-safeguards.py`: labeled
exemptions may never touch kernel `src/` beyond `src/packages.lisp`
(within these fixtures), pinning the guard's labeled-exemption
narrowness so future label abuse is caught by test, not just diff
inspection.

## Verification

- `python3 tests/scripts/test-loop-history-guard.py` -> 0 violations.
- Repo-root `make test` -> exit 0.
- No unrelated changes in the cure commit.
