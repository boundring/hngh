# 2026-09-25 — P10: refoundation close + first ceremony decay review

principle: ceremony is medicine — it is kept only while its evidence
says it is earning its cost, and the decay review is where that is
decided (GOVERNANCE.md §12; receipts contract in
records/2026-09-25-p5-ceremony-decay.md).
adversarial: a 30-day window seeded by one real action and zero
fast-lane rides can falsely certify "not yet decayable" — the review
below states its sample size openly and defers the 80% ruling.

## What this records

The refoundation pass (P1–P10) is closed: all ten phases committed,
both gates green in one run, plan checkboxes ticked.

Phase ledger (all 2026-09-25, main):
- P1 crumbs-db reader migration, P2/P3 queue pointer + pickers +
  gate-refusal records, P4 single supervision plane (63b90447),
- P5 ceremony receipts + fast lane (certificate lane; kernel `make
  test` 2954 checks), P6 research gewu boundary (8185a775),
- P7 initiative budget + P9 canon method (971fd091),
- P8 typed-everything strict (2dd0f935).

## First ceremony decay review (P5d)

Evidence base: `~/.hngh-automation/cert-receipts.tsv` (the receipts
ledger), read 2026-09-25.

- 103 receipt rows, all stamped 2026-09-25 (day 0 of the ledger).
- 2 distinct content-hashes: 1 live in `git log --grep='hngh:
  candidate'` (the real P5 certificate triple: prepare-candidate +
  commit + push), and the documented fixture-noise hash `4ad0b80e…`
  carrying 100 rows from pre-crash manual smokes (excluded per the
  P5 record).
- 315 historical `hngh: candidate` commits predate the ledger —
  ceremony volume before P5 is countable from git, not receipts.
- Fast lane: 0 actions so far. Baseline for the decay rule is 0/1
  real ceremony actions.

Ruling: the 80% fast-lane rule (retire full-lane whitespace handling
when the fast lane covers >= 80% of ceremony actions by count after
30 days) stays armed, not decided — one real action is below any
honest sample floor. Re-review 2026-10-25 or after the next 10
receipt rows, whichever is later.

Session-level ceremony cost (measured 2026-09-24, standing context):
88.67s job wall for a ceremony drive whose instrumented steps summed
~3.68s; warm SBCL load ~0.2s. The cost sits in session overhead
(orientation, model turns, retries), not kernel work — which is what
P5's receipts + fast lane and P6's cached context-pack attack.

## Tensions adjudicated this quarter (GOVERNANCE §12, per P9c)

- Determinism against throughput (P8): typed records decide, advisory
  text can raise a gate but never open one. Park-on-untyped trades
  routing availability for decision provenance; the typed-gap rows
  are the starvation signal.
- Filing discipline against equality of voice (P7): every signal is
  still recorded (crumbs/question rows); the budget only bounds new
  filing surface — a crumb is a lower-cost voice, not a silenced one.
- The method against the voices (P9): canon method binds at every
  decision seam; the canon voices themselves stay non-endorsed.

## Preserved verbatim (L12)

`GOVERNANCE.md:111-207` SHA-256 at close:

    76d6e5d1a2ad4f611d75dcf06d9d97ed2e64eb7cf94756ba5aaebab738a50d43

Matches the P0-recorded hash in
records/2026-09-25-canon-audit-refoundation.md — never clauses, ten
principles, and the certificate path byte-unchanged through the pass.

## Verification

- `cd automation && make test`: RC=0 (~200s full run).
- Root `make test`: 2954 checks passed, RC=0.
- `sed -n '111,207p' GOVERNANCE.md | sha256sum` → the hash above.
- `git diff` at commit: only this record, CHANGELOG, roadmap, and the
  plan-file checkbox ticks.
