# Key-rotation-freshness rung: dead-leg repair and steady state

Date: 2026-09-16
Lane: automation free-commit (credential-health + lib/credential-evidence.py)
Rung: key-rotation-freshness (backlog 2026-08-25; first increment 2026-09-16)

## What shipped dead

The first increment of the freshness rung wired
`lib/credential-evidence.py` into `jobs/credential-health.sh` with three
defects that only functioned together — producing total silence instead
of evidence:

1. **record ignored the production epoch.** The call site passes
   `record unsloth-session "$TOKEN_FILE" "$ledger" "$(date +%s)"`, but
   `main()` read the epoch only from `--now` (argv[5] when argv[4] was
   `--now`). The positional epoch was silently dropped and `record()`
   defaulted `now=0`, so hermetic runs pinned `rotate_epoch=0,
   scan_epoch=0`. Any real check against such a row must report `stale`.
2. **check crashed on the live clock.** The call site is
   `check "$ledger" "$ola"` with no `--now`; `main()` then evaluated
   `os.time()`, which does not exist on Python 3 (AttributeError, exit
   1). Stderr was discarded (`2>/dev/null`) and the while-read pipe got
   nothing, so the freshness leg emitted no finding — ever — while the
   docstring promised fail-closed behavior.
3. **The wiring sourced params.sh after using it.** The OLA line called
   `get_param` before `lib/params.sh` was sourced, so the OLA silently
   became empty (command-not-found under `set -u` semantics of the job),
   which after fix 1 alone would have made every run an argv refusal or
   an unbounded alert.

## Why half-fixing was an alert storm

The epoch-0 ledger row is real (shipped on this host before the fix).
Patching only `os.time() -> time.time()` makes every hourly run emit
`stale: unsloth-session (rotate epoch 0 older than OLA)`; without the
alert-identity dedup each emission was a new row in the publicly pushed
report ledger. The defects had to be fixed as one slice: argv shapes,
clock default, stderr visibility, seed semantics, and dedup.

## Decided steady state

**Seed-on-first-healthy-probe (bootstrap), then tracked rotations only.**

- The first run whose ledger is empty/absent records the unsloth-session
  row at the live clock before checking. Nothing can be stale before a
  seed exists, so the bootstrap cannot manufacture a false alert.
- Afterwards only the tracked 401-rotate path re-records. Therefore:
  - `stale` = no tracked rotation within the OLA (the evidence chain
    stopped being exercised — operator attention);
  - `hash-mismatch` = the token file changed outside the tracked path
    (an unrecorded rotation — exactly the rung's target signal).
- `ledger-missing` is impossible in steady state (the job seeds before
  checking), so it remains a genuine anomaly signal when it appears.
- The OLA bound is the cadence-params `credential-fresh-ola` row
  (default 604800 = 7d), env override `CREDENTIAL_FRESHNESS_OLA`. A
  malformed value falls back to the designed default rather than
  arming a finding storm.
- Findings are bounded (`head -n 5` per run) and ride the alert()
  identity dedup (`credential:<name>:<shape>` + evidence), so a
  degraded ledger degrades to a bounded, folded public footprint.
- Legacy epoch-0 rows on existing hosts: migrated once to the live
  clock by this slice (the digest still matched the live token, so the
  re-record is the honest fact).

## Hardening while in the file

- `record()` fchmods the ledger 600 on every write: `O_TRUNC` alone
  keeps an existing file's wider mode (the 0600 promise was
  creation-only).
- Non-integer epoch/OLA input fails closed with a `malformed-argv:`
  SystemExit (exit 1) — never a silent 0, never a traceback.
- record/check stderr is no longer discarded in the job: a digest
  refusal (evidence missing at rotate time) is visible in the systemd
  journal instead of vanishing.

## Verification

- `python3 -B automation/tests/test-credential-evidence.py`: 12 cases
  green (6 prior + 5 new + 1 path-redaction case from the parallel
  exposure slice). New cases invoke the exact production argv shapes:
  positional-epoch record pins a non-zero epoch; `check LEDGER OLA`
  with no `--now` verifies against the live clock; re-chmod-on-rewrite;
  malformed-argv refusals on epoch and OLA; extra-argv refusal.
- End-to-end shape check with literal production commands (record with
  `$(date +%s)`, check with bare OLA) on a scratch token file.
- `bash -n automation/jobs/credential-health.sh` clean.
- Full gate `make test`: green (2931 kernel checks + suite).
