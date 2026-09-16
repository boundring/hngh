# Credential-evidence integrity hardening on the repaired rung

Date: 2026-09-16
Lane: automation free-commit (lib/credential-evidence.py + tests)
Follows: 06fa18d7 (dead-leg repair) + 129da833 (repair record)

## What this slice adds

The 06fa18d7 repair made the rung function; this slice closes the
remaining integrity holes found by re-deriving the contract from the
production argv shapes, as a pure test-first increment on the already
repaired lib:

1. **Duplicate credential names fail closed.** `_read` already returned
   multiple rows per name; `check()` happily verified each and printed
   ok. Now every instance reports `duplicate-row` and NO ok is printed
   for a duplicated name: a ledger that repeats a credential is
   untrustworthy (which row would `record` have replaced? Both claims
   are suspect until a human looks).
2. **Epoch grammar = unsigned digits.** A rotate or scan epoch field
   failing `^\d+$` is `malformed-row` (catches "-5", "1e9", " NaN",
   "0x10"); a parseable-but-future rotate epoch (vs the check clock) is
   also malformed — same-host clock, no skew allowance by design.
3. **OLA 0 disables stale only** (cadence-params
   `credential-fresh-ola` documented semantics): integrity findings
   (ledger-missing / hash-mismatch / evidence-missing / malformed /
   duplicate) still fire.
4. **Evidence-path trust domain.** `record()` stores canonical absolute
   paths only: a relative evidence path resolves beside the LEDGER (same
   trust domain) or the record refuses (`evidence-missing`), and a row
   with a relative path can never verify from any cwd — the prior
   behavior stored the raw path, whose meaning depended on the caller.

## Verification

- `python3 -B automation/tests/test-credential-evidence.py`: 22 cases
  green (6 red → green in this slice: duplicate-row, future epoch,
  negative epoch, garbage scan epoch, OLA-0 semantics, beside-ledger
  path trust + refusal).
- Production argv shapes from jobs/credential-health.sh:58,:182 remain
  first-class regression cases (positional-epoch record; bare `check
  LEDGER OLA` live-clock check).
- Peer suites: test-credential-alert-dedup.sh, test-probe-hygiene.sh,
  test-credential-kimi.sh green; `bash -n` clean.

## What was deliberately NOT changed

- Epoch 0 stays a stored-verbatim legal timestamp (fail-visible: the
  row then reports stale), matching 06fa18d7's strict-parse decision;
  an ABSENT record epoch stamps the live clock.
- The record call site stays `record NAME TOKEN LEDGER "$(date +%s)"`;
  the job-side bootstrap/dedup/redaction from the co-lane is untouched.
