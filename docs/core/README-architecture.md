# The Hngh doc suite — 2026-08-30

Doc suite index v1.1, 2026-08-30 (revised after adversarial audit) · the machine-maintained changelog this suite carried is archived at
`~/Projects/etc/jcode-sessions/2026-10-13/notes/20260830-doc-suite-CHANGELOG.md`
(the day-tier verifier that wrote it is deleted; see the handoff §3.3).

Part of the `~/Projects/etc/20260830` day set. **Start at
[00-introduction.md](00-introduction.md)** — it indexes this suite with
guided reading paths. Each doc is self-contained on its subject and carries
file/record references for every claim, like the originals they grew from.

## The suite

| # | Doc | What it covers | Read when |
|---|---|---|---|
| 00 | [00-introduction.md](00-introduction.md) | indexed introduction, guided paths, glossary | first |
| 01 | [01-architecture-overview.md](01-architecture-overview.md) | one-file overview (8 sections) | orientation |
| 02 | [02-architecture-expanded.md](02-architecture-expanded.md) | v2 overview + the original refactor investigation | deeper one-file read |
| 03 | [03-kernel.md](03-kernel.md) | the Common Lisp kernel: packages, layers, run lifecycle, use cases, adapters, 19 verbs, tests | kernel code work |
| 04 | [04-automation-machine.md](../design/04-automation-machine.md) | cadence tiers, jobs, systemd units, dashboard, gates, sweeps | hngh-automation work |
| 05 | [05-governance-loop.md](../design/05-governance-loop.md) | certificate ceremony end-to-end, closed vocabularies, landing rules | landing kernel changes; ceremony onboarding |
| 06 | [06-observability.md](../design/06-observability.md) | state surfaces, feeds, alerts, watchers, the 2026-08-30 fix set | debugging "why did the machine say that" |
| 07 | [07-roadmap-and-estimates.md](../project/07-roadmap-and-estimates.md) | stage route, exit criteria, measured pacing, per-stage estimates | planning the next wave |
| 08 | [08-refactor-investigation.md](../project/08-refactor-investigation.md) | R1-R7 candidates, sequencing, operator-reserved decisions | deciding what to build next |
| 09 | [09-runbook.md](09-runbook.md) | where things land, stop commands, gates, daily artifacts, dormant items | operating the machine |

## Provenance

Written 2026-08-30 from direct file reads on this machine: kernel sources
(`hngh.asd`, `src/packages.lisp`, `src/**` layout), kernel contracts
(`docs/core/component-map.md`, `docs/core/run-contract.md`, root README),
automation sources (`cadence/README.md`, `jobs/oversight-tick.sh`,
`jobs/agent-supervision.py`, `jobs/sweep-artifacts.sh`, `jobs/ui-audit.mjs`,
`Makefile`, `.gitignore`), the 33h unattended window's evidence
(`docs/project/reports.md` rows 218-337, `digest/2026-08-29.md`,
`digest/REVIEW-2026-08-29.md`, `logs/drop-in-timing.log`), and live systemd
state. Pacing estimates derive only from measured anchors (`07`).
Numbers re-verified 2026-08-30 after an adversarial audit: kernel src =
8,156 LOC raw / 6,984 code-only (`wc -l`, 28 `src/**.lisp`), `hngh.asd`
28 `(:file)` entries, 15 packages in `src/packages.lisp`, 28 cadence
drop-ins, 30 jobs; perishable counts carry "as of 2026-08-30" stamps.

Structure convention (shared by every file): version header, numbered
sections, evidence-cited claims, tables over prose, mermaid only where
structure demands it, cross-links at the end.
