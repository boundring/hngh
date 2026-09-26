# Hngh completion graph

status: seeded 2026-09-25 (operator-directed reorientation, m07360)
authority: docs/records/2026-09-25-completion-graph-seeding.md

The map of work and research needed for Hngh's completion. Not a schedule;
a dependency-ordered node graph. Machinery consumes it as follows:

- Dream briefs cite node ids (overnight-cycle.sh build_dream_prompt
  appends the open-node excerpt; proposals name a parent node).
- Beats file subjects against nodes; P6 question semantics and the P7
  filing budget fence all machine minting. Operator-directed seeds are
  budget-exempt.
- A node ticks `- [x]` when its acceptance line holds; a ticked node stays
  as record. Nodes are never deleted here -- superseded nodes tick with a
  pointer to what superseded them.
- Ledger surfaces (reports.md, ui-grades.md, current-overlay.json) are
  subject to this graph: each writer names which nodes it evidences
  (consumer-at-birth, descent.md artifact-consumer invariant). Their
  content reorients beat-by-beat, never by bulk rewrite.
- Scale rule: one file until ~60 nodes, then per-arc files with a root
  index (decided here, not pre-built). No graph store: beats and dreams
  read text; a store would be a second source of truth.

## Principles base (carried forward, not restated)

Each operator-named ideal already has a mechanism; the graph extends the
mechanisms, never the vocabulary:

- Clean architecture -> kernel/automation boundary, dependency inward,
  fixture-backed behavior (AGENTS.md, Makefile gates).
- US federal charter ideals -> GOVERNANCE.md authority model: delegated
  conditional authority, records over proclamations, certificate ceremony
  as the mutation gate, one recallable office.
- Confucian (li, rectification of names) -> ceremony discipline and the
  principle-line faithfulness gate: a plan admits what its evidence
  actually says (accept-plans.py; decisions.md entry template).
- Taoist (wu-wei, steer before kill) -> side-effect-free kernel;
  supervision that steers once, dies only on the second miss.
- Nihei/Hayashida register -> structural tone of records per
  docs/design/interpretation-doctrine.md: the megastructure is the record
  itself; voice registers never law.

## Arc A -- Descent completion

Goal: wire what docs/design/descent.md specifies but the tree lacks.
Vocabulary is the descent doc's own.

- [ ] A1 adoption-gate
      depends: none | seed: arc-20260925-descent-adoption-gate
      statement: a crystallized research line becomes a backlog row with a
      named consumer and a one-alternation deadline, or auto-revokes to a
      citable dead-letter state.
      acceptance: a crystallized line with no consumer row revokes in a
      test fixture.
- [ ] A2 audit-station
      depends: A1 | seed: arc-20260925-descent-audit-station
      statement: a weekly beat runs descent.md's five falsifiable checks
      plus the write-only artifact count as its first agenda.
      acceptance: beat run produces the five-check row in the reports
      feed.
- [ ] A3 consumption-audit
      depends: none | seed: rides A2's beat once wired
      statement: every artifact names its consumer at birth (front-matter
      or header); a checker fails closed on missing consumer.
      acceptance: new-artifact writer paths carry consumer headers.
- [ ] A4 mimic-red-team
      depends: none | seed: rides A2's beat once wired
      statement: a scheduled session attacks the record -- forge
      evidence, replay a stale candidate, alias a canonical term -- and
      every attack ends in a refusal.
      acceptance: one green attack cycle recorded.

## Arc B -- Dream-graph loop

Goal: Hngh dreams against this map, grounded and budgeted.

- [ ] B1 graph-grounded-dreams
      depends: this file | seed: arc-20260925-dream-graph
      statement: build_dream_prompt appends the open-node excerpt when
      this file exists; dream proposals name a parent node id to be
      adopted downstream; P6/P7 fence all minting (no new fence code).
      acceptance: stub test -- prompt carries graph node ids when the
      file exists, omits cleanly when absent.
- [ ] B2 dream-to-seed-path
      depends: B1 | seed: arc-20260925-dream-graph
      statement: dream briefs file subjects as arc-<date>-<slug>
      questions through the existing seam.
      acceptance: first dream cycle post-landing shows a graph-cited
      subject or an explicit none.

## Arc C -- Local billion-context lane

Goal: measure and then wire a local long-context model lane
(python-vllm-rocm, userspace venv) with existing supervision and
escalation; quota rungs (GLM-5.3-flash, MiMo-2.6-Pro) unchanged.

- [x] C1 vllm-rocm-probe
      depends: none | seed: arc-20260925-local-vllm-probe
      statement: uv venv at ~/.local/share/hngh-vllm-venv +
      python-vllm-rocm install + one foreground smoke (small instruct
      model, --max-model-len bounded by free VRAM); record measured
      context ceiling and behavior against billion-context's target
      endpoint contract (host:port). Halts (park with findings): free
      VRAM < 12 GB, install failure, smoke stall > 20 min. No daemon
      left running.
      acceptance: probe findings recorded (VRAM at start, context ceiling
      or halt reason); pgrep -f vllm empty afterwards.
- [ ] C2 endpoint-wiring
      depends: C1 verdict | seed: rides C1 findings
      statement: config.env VLLM_URL key (${VLLM_URL:-http://127.0.0.1:
      8001} pattern), a vllm leg in model.sh after ollama before deck,
      hngh-services.tsv row with manual-start posture (nothing
      auto-starts; kernel side-effect boundary holds).
      acceptance: model.sh vllm leg answers via curl-stub test in the
      existing chain-test pattern.
- [ ] C3 harness-routing
      depends: C2 | seed: rides C2
      statement: one harness session (omp or jcode) launched with the
      vllm endpoint via SESSION_MODEL/config env seam; launcher code
      changes are a named follow-up if env alone does not suffice.
      acceptance: one bounded task runs against the local endpoint under
      supervision.
- [ ] C4 supervision-coverage
      depends: none (validates against C2 when present) | seed: rides C2
      statement: existing steer/halt/restart + demotion covers
      local-endpoint failure modes (stall, garbage, silence).
      acceptance: supervision fixture with a dead local endpoint steers
      then dies per thresholds.

## Arc D -- OS integration

Goal: self-governance approaching the operating system -- pairing with
package management, tracking operator/system configuration, and
self-adjusting across OS updates. The kernel stays side-effect-free;
all OS touch lives in the automation tier, allowlisted and fail-closed.

- [ ] D1 executable-adapters
      depends: none | seed: arc-20260925-os-adapters
      statement: harness adapters grow a real probe (DE presence,
      wayland/x11, power) using system-awareness patterns; execute()
      stays allowlisted and fail-closed (registry.py pattern).
      acceptance: probe test on this host (KDE) passes; unknown HNGH_DE
      still refuses.
- [ ] D2 package-pairing
      depends: none | seed: arc-20260925-os-package-pairing
      statement: hngh-packages.tsv rows gain update-awareness -- a daily
      patrol check compares pacman -Qi reality against pinned versions;
      drift files a research subject, never an auto-update.
      acceptance: fixture with a stale pin files one subject row.
- [ ] D3 config-drift-checker
      depends: none | seed: rides D2 route shape
      statement: a patrol route checks config.env staleness/drift (keys
      naming dead paths or endpoints).
      acceptance: fixture with a dead endpoint key files an alert row.
- [ ] D4 os-update-self-adjustment
      depends: D1 | seed: rides D1
      statement: post-update verification round -- timers alive (patrol
      already detects), adapters re-probe, a silent break mints one
      research subject (CachyOS 2026-09-13 precedent).
      acceptance: simulated-update fixture mints exactly one subject.

## Arc E -- Debt continuum

Goal: technical debt is visible and periodically harvested, not
accumulated silently.

- [ ] E1 debt-ledger
      depends: none | seed: arc-20260925-debt-ledger
      statement: the ~19 ponytail: ceiling markers index into
      docs/project/debt-ledger.md (file:line, ceiling, upgrade path);
      markers stay in place -- the ledger is the index, not the move.
      acceptance: ledger row count equals the grep count.
- [ ] E2 debt-audit-beat
      depends: E1 | seed: rides E1
      statement: a weekly beat reviews the ledger and files subjects for
      ripe ceilings.
      acceptance: beat run with two fixture ceilings files one subject
      row.

## Arc F -- Ledger-surface reorientation (standing rule, no nodes)

reports.md, ui-grades.md, and current-overlay.json are subject to this
graph (operator authority m07360). Their writers name which nodes they
EVIDENCE under the A3 consumer-at-birth invariant as it lands; content
reorients beat-by-beat. No bulk rewrite, no standalone nodes.
