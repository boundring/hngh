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

- Queue rotation stalled since 2026-09-01 ([queue.md](queue.md) shows
  no row rotation since then).
- 62 routed plan files in `plans/`, with same-identity re-routing —
  ten tree-skew candidates on 2026-09-05 alone
  ([bestiary.md](../design/bestiary.md), class: obsolete).
- 4 of 12 automation artifact classes are write-only (operator
  assessment, 2026-09-06). The artifact-consumer invariant and the
  Audit station exist to end this — [the Descent](../design/descent.md)
  is the fix, its adoption gate and weekly checks are specified but
  not yet wired.

## Where it goes

The route is seven stages with exit criteria
([roadmap.md](roadmap.md)): land stage 2, open stage 3, then the
grow/research alternation under the Descent cycle. The long horizon —
a lattice of small ledgered machines — is the end of
[intent.md](../intent.md).

---

Back to the [documentation index](../README.md).
