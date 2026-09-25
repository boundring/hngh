# 2026-09-25 — P5: ceremony decay rungs

## What this records

Refoundation phase P5 (R5: ceremony is medicine without decay review)
lands the graduated middle rung between full ceremony and no ceremony.
Three pieces, one certificate lane, kernel-surface `scripts/` changes:

1. **Certificate receipts** (`scripts/cert-receipts.lisp`, new). Every
   certificate action (prepare-candidate, commit, push) that
   ceremony-drive completes appends a receipt row
   `timestamp|content-hash|action|expiry` to
   `cert-receipts.tsv` under the automation home
   (`automation/lib/hngh_home.py` resolution; `HNGH_RECEIPTS_PATH`
   overrides for tests). Appending is fail-open by design: a receipt
  IO hiccup must not unwind a completed, verified mutation. Receipts
   are the decay-review evidence base — counts, ages, and lane
   distribution become measurable instead of folklore.

2. **rotate-queue fail-closed chain** (`scripts/rotate-queue`). The
   doubled mutation-check per action (residue from the P5b verb fix:
   two verbs, one do-step each) is collapsed to a single
   mint-and-execute call per action, and each successful
   mutation-check records a receipt. Balance: every mint has exactly
   one execute and one receipt.

3. **Fast lane** (`scripts/ceremony-drive --fast-lane`). For
   whitespace-only candidates (blank lines, trailing-newline
   normalization — zero semantic delta), the drive runs
   create-run + admit-transport + the two hygiene gates
   (whitespace-only-candidate-p, verify-candidate-clean-p), then ONE
   mechanical commit with no model round-trip and no push leg. Push
   stays its own certificate; none is minted here. `--fast-lane`
   requires `--store` (refuses with usage, exit 2).

## Bugs found and fixed on the way

- verify-candidate.py accepts ONLY `--manifest` (one sorted
  repo-relative path per line), never positional files. The drive now
  writes a temp manifest. Lesson: interface contract, not assumption.
- Excess close paren in whitespace-only-candidate-p (line 331).
  Whole-file depth tracing misled twice; the SBCL reader was
  decisive: `(require :asdf) (asdf:load-asd "<abs>/hngh.asd")
  (asdf:load-system :hngh)` then read the file. Reader verdicts:
  ceremony-drive 23 forms, rotate-queue 13, cert-receipts.lisp 5.
  Standing lesson: parser beats eyeballs for balance bugs.

## Verification

- `tests/scripts/test-ceremony-receipts.py` (new, 4 checks):
  fast-lane refuses substantive change (exit 2, no commit, no
  receipts); fast-lane commits blank-line-only change (exit 0, HEAD
  advances, subject `hngh: candidate <hash>` matching the
  fast-lane-complete hash, one receipt row); `--fast-lane` without
  `--store` refuses with usage; receipts CLI append + cat round-trip.
- `tests/scripts/test-ceremony-drive-dry-run.py`: 7/7 (unchanged).
- Root `make test`: green, 2954 checks.
- rotate-queue live fixture (fail-closed chain, /tmp): create-run +
  admit-transport + evidence pass; review with dead endpoint yields
  `review status=complete findings=0`, propose refuses
  `fact=evidence kind=review fingerprint=unavailable
  state=unverifiable`, exit 2, no commit, no receipts, ledger
  untouched; store reuse across attempts refuses
  `conflict labels=record-conflict`.

## Decay review hook

The closing phase (P10) re-checks receipts: if the fast lane covers
>= 80% of ceremony actions by count after 30 days, the full lane's
whitespace handling is retired into the fast lane entirely.
Decay counts join DISTINCT content-hash values against `git log
--grep='hngh: candidate'` subjects: rows whose hash has no surviving
commit are fixture noise (19 such rows from pre-crash manual smokes
already sit in the ledger, hash
4ad0b80eedd8d228f906cd993626e0a5bbbf078342dfcf28435995da9d7ab863)
and are excluded.
