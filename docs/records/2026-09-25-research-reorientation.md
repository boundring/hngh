# Research and plan corpus reorientation (2026-09-25)

principle: evidence-faithful surfaces only -- staged research and plans that no longer reflect the live repo misdirect every future cycle, so the corpus is reoriented against ground truth, not accumulated.

adversarial: a bulk deletion driven by two subagent audits could itself be unfaithful -- every verdict class was sample-verified against the tree (steps vs cited disposition row, target paths vs live layout, supersession vs live config), and the discard set was rebuilt mechanically (non-routed `dev-*` with zero ticked steps = 64, matching the audit count exactly) before deletion.

Operator authority: 2026-09-25 session -- "we're open to checking over any
and all research to archive or reorient for Hngh's intent and structure now,
its base principles. Practically any of its research and plans are subject to
change for reorientation." The same session had already discarded a
hallucinated-steps plan trio on operator instruction.

## Subjects layer (research queue)

Ground truth: `research-subjects.txt` held 331 rows; 12 legacy bare-title
rows plus 80 patrol/fail rows (2026-09-13..25) had no disposition. Read-only
audit verdicts: KEEP 8, REORIENT 1, ARCHIVE 83.

- 83 `killed` rows appended to `research-dispositions.tsv` with reason
  `reorientation 2026-09-25 -- <class reason>` and this record as the doc
  reference. File integrity verified: 373 = 290 + 83 rows, all new rows
  6-column, original prefix byte-preserved.
- 1 subject reoriented in place: `patrol-20260925-automation-gate-gate-stale`
  now carries the question "why does the check still find no gate crumb
  against the crumbs-db seam after the refoundation moved crumb readers off
  STATE.md, and which guardrail or re-baseline closes it?"
- Remaining open subjects: exactly 9 (8 recurring-class KEEPs + 1 REORIENT).

KEEP classes are live recurring patrols (automation-gate-gate-red, feeds/
handoffs/manga/pending-checks/systemd-units/github-ci/journal classes). The
12 legacy bare titles were duplicates of already-disposed slug lines.

## Plans layer (kernel plan feed)

Ground truth: 619 plan files; header-authoritative statuses: 294 accepted,
181 parked, 77 executed, 44 expired, 4 done, 1 complete, 14 legacy-disposed.
Only 1 file was genuinely `status=proposed`. A grep-based count of 13
"proposed" files was a substring artifact -- 5 of those were executed/closed
records. Staged research has zero open lines: all 261 `research-lines.tsv`
rows are `reviewed` (terminal).

Read-only audit of 90 files (named non-dev plans + all non-routed `dev-*`):
KEEP-LIVE 22 - SUPERSEDED 8 - UNFAITHFUL 34 - DEAD-SURFACE 26 - UNCERTAIN 0.

Discarded: 64 files, all unexecuted (`dev-*`, non-routed, zero ticked steps):

- 34 UNFAITHFUL: cite adopted disposition rows but carry unrelated template
  steps (e.g. 2026-09-22-dev-synth-2026-09-19-1 cites integrity/checksum
  research rows while its steps build generic `lib/job_contract.sh`
  scaffolding). Bulk-accepted 2026-09-18T01:41:57Z, none executed. The
  previously discarded trio was this class, not an outlier.
- 26 DEAD-SURFACE: steps target the retired sibling-tree layout
  (root-level `lib/`, `jobs/`, `scripts/`, `dashboard/`), absent here.
- 4 SUPERSEDED: cited fix landed elsewhere (slow-unit MODEL_TIMEOUT=300 at
  `automation/config.env:32` + `automation/lib/model.sh` max-time; sn-627926
  fixed same day).

Kept despite defunct verdicts (records of landed work, several cited by live
code): 2026-09-09-omp-hngh-integration (all steps executed, artifacts live),
2026-09-22-launch-item-trio and 2026-09-22-ram-guardrails-dashboard-controls
(landed; `automation/lib/memory-gate.sh` header cites its plan),
2026-09-04-notifications-and-qol (self-dispositioned parked record).
KEEP-LIVE also includes the 11 `routed-*` procedural plans (router
lifecycle; self-resolve as subjects get dispositions) and
2026-09-18-backlog-p2p3-coverage (accepted, unchecked, grounded in operator
backlog, targets live surfaces).

## Verification

- Discard set rebuilt mechanically and matched the audit exactly:
  non-routed `dev-*` with zero `- [x]` steps = 64 = 3 named + 31 + 26 + 4.
- Sample verification per class (steps vs cited row, paths vs live layout,
  supersession vs live config) passed before deletion.
- Disposition ledger integrity re-checked in a fresh interpreter after the
  subjects-layer writes (9 unbeaten remain, 83 rows 6-col, prefix intact).
- `automation/make test` green post-change (corpus files are not test
  fixtures); root `make test` green.

## Why this closes

The refoundation (P0-P10) moved crumb readers, supervision, and research
minting onto seams that no longer produce the drift these subjects and husk
plans tracked. P6 (question-not-beat) and P7 (filing budget) fence the
re-mint loops that generated the unfaithful class. The corpus now reflects
the live repo; future beats start from evidence-faithful surfaces only.
