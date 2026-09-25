# State of the project

*Prose sections are hand-maintained. The "Verified numbers" block below
regenerates daily from the live ledgers by the Audit station
(`hngh-automation/cadence/calendar/daily/17-torch-audit.sh`, part of
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
hngh-automation `cadence/calendar/daily/17-torch-audit.sh` — do not hand-edit
inside the sentinels.

- Research lines: 256 reviewed, 1 expanding (hngh-automation/research-lines.tsv).
- Queue Next: Land stage 2, set 2026-09-25 (0 days old) (hngh docs/project/queue.md).
- Plan ledger: 608 plan files, 497 routed candidates (hngh docs/project/plans/).
- Operator items: 27 open (hngh-automation/dashboard/operator-items.json; display cap 40).
- Gates: 16-remote-push.sh — gate-refresh — hngh: gate crumb was stale — make test re-run green (hngh-automation/STATE.md crumb tail).
<!-- torch:end -->

## What is broken and being fixed

- Queue rotation is running again: the hourly heartbeat tick is live
  (`hngh-automation/cadence/README.md`, `31-heartbeat`), with
  heartbeat #1 recorded and fifteen heartbeats on the ledger as of
  2026-09-07.

- 0 of 18 artifact classes are write-only per the torch ledger
  (hngh-automation `torch-ledger.tsv`) as of 2026-09-24: digest-BENCH,
  digest-RESEARCH, and email-qa.log all gained readers in the
  unresolved-matters pass (email-digest bench/qa lines; the research
  beat's REVIEW evidence). digest-REVIEW flipped live 2026-09-06 via
  the review-findings sink. The artifact-consumer invariant runs daily
  under [the Descent](../design/descent.md)'s Audit station
  (`hngh-automation/cadence/calendar/daily/17-torch-audit.sh`).

## Where it goes

The route is seven stages with exit criteria
([roadmap.md](roadmap.md)): land stage 2, open stage 3, then the
grow/research alternation under the Descent cycle. The long horizon —
a lattice of small ledgered machines — is the end of
[intent.md](../intent.md).

---

Back to the [documentation index](../README.md).
