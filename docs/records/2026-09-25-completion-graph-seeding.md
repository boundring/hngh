# Completion-graph seeding (2026-09-25)

principle: the map precedes the work -- a dependency-ordered node graph of
the work and research Hngh's completion needs, planted in the corpus the
existing machinery already reads, so dreams and beats start from
evidence-faithful surfaces instead of re-deriving direction each cycle.

adversarial: a fresh node graph could float free of the repo's own design
and become another unfaithful surface -- every arc is grounded in an
existing specified-but-unwired design (descent.md) or an existing seam
(dream prompt builder, model chain, supervision, patrol routes, registries,
ponytail markers); no new vocabulary is coined, no new service starts, and
the graph is one markdown file, not a second source of truth.

Operator authority (m07360, 2026-09-25): reorient the seeds and basis of
Hngh's research patterns and direction; develop further planning and
research as extensive, well-mapped node graphs; permit dreaming about
needed work; probe local models (python-vllm-rocm in a userspace venv,
billion-context-supported compression) with stall/bad-behavior steering,
halt and restart, and escalation to quota models; keep things simple and
practical; ideals per GOVERNANCE.md (federal charter + Taoist/Confucian
canon, Nihei/Hayashida register per interpretation-doctrine.md); technical
debt as a continual process. Live-cadence files are declared subject to
change (recorded as the graph's arc F standing rule).

## What landed

- `docs/project/completion-graph.md`: 16 nodes across arcs A-F --
  A descent completion (adoption gate, audit station, consumption audit,
  mimic red-team, from docs/design/descent.md's own specified-but-unwired
  design), B dream-graph loop, C local billion-context lane (vllm-rocm
  probe, endpoint wiring, harness routing, supervision coverage), D OS
  integration (executable adapters, package pairing, config drift,
  os-update self-adjustment), E debt continuum (ledger, audit beat), F
  ledger-surface reorientation standing rule. Every node carries
  depends/seed/acceptance; nodes tick per repo checkbox convention.
- 7 operator-directed seed subjects appended to
  `automation/research-subjects.txt` (arc-20260925-* ids, budget-exempt as
  operator-directed): descent-adoption-gate, descent-audit-station,
  dream-graph, local-vllm-probe, os-adapters, os-package-pairing,
  debt-ledger.
- Dream grounding: `automation/scripts/overnight-cycle.sh`
  `build_dream_prompt` appends the open-node excerpt (tail 40) under a
  `Completion graph (cite node ids):` header when
  `$KERNEL/docs/project/completion-graph.md` exists; absent graph leaves
  the prompt unchanged. Test cases added to
  `automation/tests/test-overnight-forethought.sh` (b: without-graph
  asserts no section; b2: with-graph asserts header + node id): all cases
  pass.

## Findings and deviations

- Plan verification floor said ">= 18 nodes"; the plan's exact node list
  is 16 -- 16 is correct (floor was a drafting estimate, exact list
  governs).
- Corpus is live: the 2026-09-26 patrol beat minted 7 recurring patrol
  subjects while this slice ran; unbeaten-set census is racy against the
  beat's truncate/rewrite (observed 24 -> 36 flapping). Seeds verified by
  stable id presence (7/7, two-column, no arc dups), not by census.
- Machine-dup patrol ids (20260925 vs 20260926 recurring classes) are
  native re-mint behavior, fenced by P7 filing budget going forward.

## What deliberately did not land here

- No vllm install/endpoint yet (probe is this slice's bounded step 5,
  findings to follow in its own commit).
- No new service, no graph store, no bulk rewrite of live-cadence files
  (arc F reorients them beat-by-beat under A3's consumer-at-birth).

Grounding audits: DreamModelScout + OsDebtScout read-only scout reports
(this session), both scout-verified against the tree.
