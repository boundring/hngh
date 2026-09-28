# fail-20260913-patrol-gate-cure — red-gate self-cure surface disposition

- Date: 2026-09-28 (UTC)
- Subject: `fail-20260913-patrol-gate-cure` in `automation/research-subjects.txt`
- Routed plan: `docs/project/plans/2026-09-13-routed-patrol-gate-cure.plan.md`
- Alert identity: `patrol:gate-cure` — `gate-cure-refused` on kernel, x2
  (`automation/STATE.md` 2026-09-13T20:00:19Z router row; plan occurrence
  2026-09-13T21:00:39Z re-occurrence)
- Disposition: **parked (resolved-transient); fixed, verified on its own
  surface 2026-09-28**

## Question

The gate-cure route (2026-09-13) files `gate-cure-refused` on kernel when
its red-gate self-cure refuses. Why did it keep failing on 2026-09-13,
which guardrail closes it, and does it still fail today?

## Evidence read

- Routed blockers were gate redness, not the cure logic itself: the plan's
  own occurrences plus `automation/STATE.md` 2026-09-13T20:00:49Z and later
  rows record `plan-blocked ... kernel-gate-red-rc2` and
  `automation-gate-red-rc2` — the ceremony gate refused because the suite
  was red, so no cure commit could land.
- The cure mechanism has since been hardened:
  `automation/jobs/patrol.py:993` `check_gate_cure` and `:971`
  `cure_red_gate`; the LARGE pre-check that refuses with
  `gate-cure-refused` and parks (`patrol.py:1008-1013`) was shipped as
  SMALL-matter amendment (`automation/CHANGELOG.md:848`).
- Live surface run 2026-09-28: `python3
  tests/scripts/test-loop-history-guard.py` from the kernel root returned
  rc=0 — `loop-history guard: 153 code-surface commits checked, 27 named
  exemption(s), 0 violations`. Gate green; check_gate_cure's green path
  (`patrol.py:1005-1007`) is the one that fires today: quiet, no ceremony,
  no alert.
- Recurrence stopped: zero `gate-cure-refused` patrol rows in
  `automation/STATE.md` after 2026-09-14; the last events are the 09-14
  research-ledger rows (STATE.md 68826-68827).
- Sibling subjects already closed by operator reorientation:
  `patrol-20260913-gate-cure-gate-cure-refused` and
  `patrol-20260923-gate-cure-gate-cure-refused` are killed in
  `automation/research-dispositions.tsv` (rows 347, 364, reorientation
  2026-09-25) citing `docs/records/2026-09-25-p3c-gate-refusals.md`.

## Doctrine applied

Fail-closed (README contract): a red gate refuses the cure and parks the
alert rather than fabricating a pass; the reoccurred subject is parked,
not improvised. Ceremony-only kernel mutation held: this session verified
the surface read-only and mutated nothing under `src/` or `tests/`.

## Findings

1. The routed alert was a true-but-transient red-gate episode: the
   gate-cure patrol correctly refused to auto-cure while the suite was
   red (gate-cure-refused is the designed fail-closed verdict, not a bug).
2. No guardrail defect remains: the guard is green live (0 violations),
   the alert class has not fired since 2026-09-14, and adjacent refusal
   handling was reworked by the 2026-09-25 refoundation record.
3. The routed plan's original step was blocked by the red gates, and the
   blocked loops were superseded by the P3C lane — the correct terminal
   state is fixed/transient, recorded as policy-distinct parked.

## Recommended next line

None. If `patrol:gate-cure` re-fires with a fresh red gate, reopen via
research-subjects with the new occurrence dates and treat it as a new
episode of the same surface (not a resurrection of this record).
