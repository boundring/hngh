# Loop-history guard 526cd3f exemption cure completed (duplicate merged)

- 2026-09-15 (kernel slice committed 2026-09-14 21:03 EDT as
  `hngh: candidate 785e57b16aa128260b3820d931540341f50d12f0eaec97fcd7cced95c10d97ea`,
  commit `30966c38`, pushed to origin)
- Scope: `tests/scripts/test-loop-history-guard.py` (kernel `tests/`
  surface, driven through the certificate ceremony)

## What was wrong

The 2026-09-14 gate-cure of the portfolio commit
`526cd3fda4f415f12e5b3cc9e963406734d105a8` was left incomplete. The
guard's `KNOWN_EXEMPTIONS` table ended up holding TWO entries for the
same commit:

- the original 2026-09-06 declaration keyed `526cd3f`, with a stale,
  wrong patch-id `4496b3361bc3d606837acfd377b9ead29a636a4d`;
- the 2026-09-14 gate-cure re-declaration keyed `526cd3fd`, with the
  correct patch-id `5b6840dfb796a0baeb4a7193a134a94b8b0ebf36`
  (verified: `git show 526cd3fd | git patch-id --stable`), left
  uncommitted in the working tree.

`tests/scripts/test-loop-history-guard-safeguards.py` iterates every
entry and asserts the registered patch-id equals the live commit's
patch-id, so it failed on the stale entry with
`registered patch-id drift for 526cd3f` -- the kernel gate stayed red
even though the main guard reported 0 violations.

## The cure

Merged into ONE entry keyed `526cd3f` (the key used by the 2026-09-06
record and `docs/project/decisions.md`) with the verified patch-id
`5b6840dfb796a0baeb4a7193a134a94b8b0ebf36` and a reason citing both
events (declared miss 2026-09-06, gate-cure 2026-09-14). One commit,
one exemption.

## Verification

- `python3 tests/scripts/test-loop-history-guard.py`
  -> `loop-history guard: 113 code-surface commits checked, 13 named
  exemption(s), 0 violations`, exit 0 (before: same, since the guard's
  hash-lookup path masked the drift)
- `python3 tests/scripts/test-loop-history-guard-safeguards.py`
  -> `loop-history guard safeguards: ok (reachability + patch-id
  fallback)`, exit 0 (before: assertion error `registered patch-id
  drift for 526cd3f`, exit 1)
- Both suites re-run green at the ceremony commit `30966c38`.

## Not rewritten

The 526cd3fd commit itself remains history, declared by name per the
standing post-hoc policy; this record only completes its exemption
bookkeeping.
