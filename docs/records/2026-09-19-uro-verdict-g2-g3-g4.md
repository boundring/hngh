# URO independent verdict on G2/G3/G4 evidence (2026-09-19)

Reviewer: jcode coordinator session (did not author the evidence commits;
evidence authored by `hngh-machine`). Independence rule: a reviewer who did
not author the work accepts the results before close
(per docs/project/decisions.md reviewers-advise rule). This record is the
verdict. Sample run reviewed: G2/G3/G4 evidence commits below.

## G2 ACCEPT — telemetry-vs-STATE.md reconciliation (3294b858)

Evidence: `docs/records/2026-09-18-g2-telemetry-ledger-reconciliation.md`.
Ground-truth claim (STATE.md breadcrumb ledger) verified in structure:
`_model_emit()` at `automation/lib/model.sh:714` writes one kind=model row
per successful call; emit sites at `automation/lib/model.sh:745` (kimi),
`automation/lib/model.sh:856` (zai), `automation/lib/model.sh:970,982`
(unsloth), `automation/lib/model.sh:1005` (ollama),
`automation/lib/model.sh:908,921,999` (remote); zai per-attempt served
markers at `automation/lib/model.sh:827,843`; deck no-emit by design at
`automation/lib/model.sh:860`. Verdict: ACCEPT the no-correction verdict.
Category-mismatch reasoning (per-attempt breadcrumbs vs per-call telemetry)
is sound; zai paired-timestamp double-fire note is a genuine observation.
Follow-up optional, not blocking: success breadcrumb per emit site, dedupe
zai paired markers.

## G3 ACCEPT — malformed-rows census (eafc0ba3)

Evidence: `docs/records/2026-09-18-g3-malformed-rows-consumers.md`.
Census claim (zero malformed in both files) is plausible and the correction
note (72 legacy-width rows belong to research-dispositions.tsv, not G3-scope
files) is honest scope hygiene. Consumer cites spot-checked:
`automation/jobs/research-routes.py:107` fail-closed reader exists;
`automation/jobs/research-feed.py:258` (`len(parts) == 4`) silent-skip gate
exists; `automation/jobs/digest-ledger.py:99` (`len(parts) >= 2`) exists;
`automation/jobs/graph-data.py:56` `read_tsv` exists;
`automation/jobs/unsloth-contexts.py:251-252` unguarded indexed writes
exist. (Beat-script line cites in the record reference an older script
revision; the awk/cut short-row characterization remains behaviorally true
for TSV shell readers, but exact `:300-301` numbers should not be quoted
against the current file.) Verdict: ACCEPT with that line-number caveat.
No remediation required while census stays zero.

## G4 ACCEPT — fixture-fanout census (4a1579df)

Evidence: `docs/records/2026-09-18-g4-fixture-fanout-census.md`.
Guard rule cites verified: `tests/scripts/test-loop-history-guard.py:245`
(CODE_SURFACE), `tests/scripts/test-loop-history-guard.py:246` (CANDIDATE
regex), exemption entries at `:73` (7637c560), `:81` (e6e98f7), `:90`
(a5520fb2), `:177` (ba6b390), `:181` (d2d8f51), `:203` (04f0001), `:208`
(29d2a27), `:217` (c3bf986). Guard re-run 2026-09-19: 143 code-surface
commits checked, 27 named exemptions, 0 violations. The record's own
"Not checked" section (certificates behind candidate labels, automation/ or
docs/ Fixture commits, pre-guard history) correctly bounds the verdict.
Verdict: ACCEPT as "sanctioned" within the stated narrowed read-only scope.

## Bead effects

- hngh-uro: SATISFIED by this verdict (independence rule stated above,
  non-author review of the G2/G3/G4 sample run, verdict recorded here).
- hngh-4ym: SATISFIED (verdict on G2/G3/G4 evidence rendered, this file).
- hngh-4j4: NOT re-closed. The uro dependency is now satisfied, but the
  bead's Global criterion (three tiger banked specs cited in work log,
  tracked by open hngh-h84) remains unsatisfied, and G5/tigress items
  (551dc129, 65036365, 36b43f72) postdate the original close without a
  reviewer verdict. Re-close requires hngh-h84 resolution plus a verdict
  pass over G5/tigress evidence. No waiver granted.
