<!-- plan: status=accepted risk=normal priority=high accepted=2026-09-14 -->
# 2026-09-14 — Jcode primary harness: staged integration plan

Operator-directed 2026-09-14. Companion record:
`docs/records/2026-09-14-jcode-primary-harness-admission.md` (rationale,
architecture constraint, unknowns). This plan is dependency-ordered like
the 2026-09-09 omp plan; each step verifies on its own surface. All code
is edge-tier (`automation/`); the kernel never learns Jcode exists.

## Steps

- [ ] 1. **Orientation artifact for Jcode sessions.** A repo-root-facing
      `AGENTS.md` addendum + a `~/.jcode`-side rules/skills package
      giving any Jcode session in this repo the same orientation the omp
      plugin provides (omp-bridge --orient, MCP tools, ceremony
      awareness). Verification: a fresh `jcode -p` session in this repo
      answers three orientation questions correctly without re-walking.
- [ ] 2. **Transport verification + worker driver choice.** Verify the
      local Jcode build's SDK surface (launch/connect, spawn depth,
      swarm behavior) with a throwaway Node probe; decide SDK (Node shim
      in `automation/`) vs direct CLI spawn for the worker driver, with
      the decision recorded. Verification: probe script asserts one
      launched session runs a prompt to `turn_done` and `close()` reaps.
- [ ] 3. **Governed Jcode worker lane.** Driver in `automation/` wrapped
      `--run-start` → observatory `working` → `--run-end`; bounded
      read-only task class first (same rung-18 shape as the omp lane);
      spawn depth budget declared; fail-closed on undeclared paths.
      Verification: one witnessed cycle in the run ledger; seeded stall
      auto-replaced per governed-fleet §4.
- [ ] 4. **Permission bridge.** `permission_request` events routed to the
      certificate loop: default deny; allow only against a live mutation
      certificate naming the action class; `autoApprove` forbidden
      outside certificate-scoped lanes. Verification: forced permission
      request in an uncertified lane is denied and logged; certified lane
      allows exactly the named action.
- [ ] 5. **Observatory surface.** Nerve-center Sessions preview of Jcode
      sessions via `connect()`/`peekSession`. Verification: preview
      renders a live session transcript without attaching.
- [ ] 6. **Config lane + installer option.** `~/.jcode` declared in the
      governed-fleet config lanes on the 30m cadence; Hngh installer
      gains a Jcode install option (deferred to the OS-harness
      installer-skeleton rung, 2026-09-11 ladder). Verification: config
      lane lands in the cadence matrix; installer option specified (not
      necessarily built).
- [ ] 7. **Omp coexistence review.** Inventory omp surfaces vs Jcode
      equivalents; retirement is a named record per surface, never a
      default. Verification: inventory table in a record.

## Priority

Steps 1-2 precede discretionary queue work (operator directive 2026-09-14).
Steps 3-4 double as governed-fleet stage-3 exit evidence (one witnessed
delegation cycle with a seeded stall auto-replaced), so they advance stage
3 rather than preempt it.
