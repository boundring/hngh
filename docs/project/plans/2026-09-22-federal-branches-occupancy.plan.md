# Federal charter occupancy: bailiff, bead intake, drafting-passage split, executive guard, ledger convergence

Plan origin (operator, 2026-09-22): "What would it mean to restructure Hngh into
the three branches per the accepted federal charter?" The charter
(docs/project/plans/2026-09-20-federal-charter.plan.md, accepted
2026-09-20T17:35:00Z) is NOT redesigned here — this plan occupies it. Basis:
three-branch gap audit delivered 2026-09-22. "Let's be thorough as we proceed."

## Branch findings (audit basis)

- JUDICIAL: close to done. Kernel src/ ~3k LOC, ceremony enforced, kernel gate
  green. No work here.
- LEGISLATIVE: half-built. Crossed wire A — router drafts AND shapes law
  (shape_for risk=normal fallthrough auto-routes parked critical alerts into
  normal-risk candidates; partially closed by class channel
  docs/records/2026-09-22-router-alert-class-channel.md). Crossed wire B —
  intake is report-body file scanning, not the charter's event-driven bead
  intake (charter plan:100-110: bead chamber + state_emitter bead.ready +
  Jev triage).
- EXECUTIVE: ~70k LOC edge vs 3k kernel. Ceilings already landed (dispatch
  cap, RAM gate, quota legs, worker certificate scopes). Crossed wire C —
  executive docket discretion: overnight-cycle.sh plan-priority-selector picks
  which plans run (executive should execute the chamber's docket, not shape it).
- BAILIFF MISSING: automation/ng/watch.py emits audit.finding but ZERO
  consumers in cadence drop-ins or overnight gates — the kernel-gate-red-
  halted-nothing crisis repeats whenever nobody reads findings.

## Steps

- [ ] 1. Bailiff wire: watch.audit findings halt cadence tiers
      (automation/cadence-tick.sh sourcing a new automation/lib/bailiff.sh;
      fail-closed on audit.finding presence, keyed to gate red / audit
      findings; reuse memory-gate.sh + STOP=1 crash-net pattern from
      overnight-cycle.sh:789-790 and :56-70).
      Verification: python3 automation/ng/test-bailiff.py green + full
      automation gate green + live tick smoke (bailiff check runs, exit 0
      clean, exit non-zero on seeded finding).
- [ ] 2. Executive guard: Jcode node/depth caps enforced at spawn time
      (launch-jcode.sh pre-spawn check calling automation/ng/jcode_guard.py
      on the prompt's plan/session graph; fail-closed rc on cap violation;
      env seams HNGH_NODE_CAP/HNGH_DEPTH_CAP honored).
      Verification: automation/tests/test-jcode-spawn-guard.py green +
      full automation gate green.
- [ ] 3. Bead intake convergence: cadence polls bd directly for open beads
      (automation/ng/cadence.py _open_beads already does; wire it into the
      hour tier via a new drop-in automation/cadence/hour/25-bead-beat.sh;
      state_emitter stays judgment-only — no bead events added).
      Verification: python3 automation/ng/test-dispatch-gate.py green +
      drop-in smoke run + full automation gate green.
- [ ] 4. Ledger convergence + records: ng/ledger/events.jsonl accumulates
      only judgment events (already true by state_emitter contract); beads
      stay work ledger of record; docs/records/2026-09-22-federal-branches-landing.md
      records the occupancy state and CHANGELOG entry.
      Verification: docs/records file exists + CHANGELOG entry + both gates
      green (kernel make test rc=0; automation gate ALL PASS).

## Non-goals

- No kernel src/ edits (constitution untouched).
- No big-bang edge rewrite; overnight-cycle.sh docket stays until a later
  amendment moves plan selection into the chamber's hands explicitly.
- No bicameralism/parties/elections (charter deliberately skips them).

## Risk

- Normal. Everything lands in automation/ (free-commit surface after gates);
  kernel untouched; existing ceilings (dispatch cap, RAM gate, class channel)
  stay in force throughout.
