# State of the project

*Prose sections are hand-maintained. The "Verified numbers" block below
regenerates weekly from the live ledgers by the Audit station
(`hngh-automation/cadence/week/02-torch-audit.sh`, part of
[the Descent](../design/descent.md)): only content between the
`torch:begin` / `torch:end` sentinels is rewritten, the rest stays
hand-edited.*

## What Hngh is

Hngh turns development into short, bounded cycles — plan, check, record,
close — that an automated agent runs while a human keeps the final say.
Every cycle leaves a paper trail; nothing changes the system without
passing a check and being recorded. Full statement:
[intent.md](../intent.md).

## What runs today

- **Kernel** at promotion rung 18 with governance C0–C3
  ([roadmap.md](roadmap.md) "Now"): pure run domain, seven use cases,
  certificate loop, bounded read-only worker task. `make test` past
  2,855 checks.
- **Seven stages** ([roadmap.md](roadmap.md) route table); stage 2 —
  the nerve-center consolidation — is landing; stage 3 roguelike
  delegation is landing beside it.
- **Automation tier live** at hourly and day cadence
  (`../hngh-automation/cadence/`): oversight tick, workbeat, review
  beat, research beat, gate check, digests. Routing, acceptance,
  dispositioning, watchdog, and feeds all run deterministic; model
  surfaces fail closed-skip — verified per
  [the Descent's control-plane invariant](../design/descent.md).

## Verified numbers

<!-- torch:begin -->
Regenerated weekly from live ledgers by
hngh-automation `cadence/week/02-torch-audit.sh` — do not hand-edit
inside the sentinels.

- Research lines: 6 planned, 23 crystallized (hngh-automation/research-lines.tsv).
- Queue Next: wake-mutation-lane, set 2026-08-25 (12 days old) (hngh docs/project/queue.md).
- Plan ledger: 77 plan files, 63 routed candidates (hngh docs/project/plans/).
- Operator items: 40 open (hngh-automation/dashboard/operator-items.json; display cap 40).
- Gates: 03-gate-check.sh — gate-green — hngh-automation: make test ok (hngh-automation/STATE.md crumb tail).
<!-- torch:end -->

## What is broken and being fixed

- Queue rotation still stalled since 2026-09-01 ([queue.md](queue.md)
  shows no row rotation since then).
- 63 routed candidates in the plan ledger (77 files in `plans/`).
  Same-identity re-routing now parks at threshold via the disposition
  spine — router escalation with bump-in-place landed 2026-09-06. The
  historical x10 tree-skew burst stands on record
  ([bestiary.md](../design/bestiary.md), class: obsolete).
- 3 of 16 artifact classes are write-only per the torch ledger
  (hngh-automation `torch-ledger.tsv`): digest-BENCH, digest-RESEARCH,
  email-qa.log — wire-or-delete pending. digest-REVIEW flipped live
  the same day via the review-findings sink. The artifact-consumer
  invariant runs weekly under [the Descent](../design/descent.md)'s
  Audit station (`hngh-automation/cadence/week/02-torch-audit.sh`).

## Where it goes

The route is seven stages with exit criteria
([roadmap.md](roadmap.md)): land stage 2, open stage 3, then the
grow/research alternation under the Descent cycle. The long horizon —
a lattice of small ledgered machines — is the end of
[intent.md](../intent.md).

---

Back to the [documentation index](../README.md).
