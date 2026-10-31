# hngh v2 — principles

v1 lesson (the Lisp loop framework, archived at `archive/v1`): framework-building
before measured need accretes unwieldy debt and is hard to reorient mid-stream.
v2 follows the lead of the tools it shepherds — billion-context, oh-my-pi, Tern —
each of which does one job over existing infrastructure and stays thin.

1. **Shepherd, don't replace.** hngh wraps what the operator already runs —
   omp sessions, Tern tabs, unsloth studio, git. Thin CLI entry points, ledgers,
   gates. Never a parallel runtime, never its own daemon unless measured need.
2. **Every tool has a selfcheck.** Sandboxed, honest exit codes; a tool without
   `hngh-<name>-selfcheck` is not landed.
3. **Ledgers are the audit trail.** Append-only JSONL; fold views are derived,
   never hand-edited; exactly one writer per ledger file.
4. **Gates at operator presence.** Silent / Confirm / Presence-gated / Forbidden
   (AGENTS.md §11 tiers) — "may I act" and "is now a safe moment" differ.
5. **Config and env over code.** Model pins, contexts, quotas via env files and
   overlay yaml; nothing load-bearing hardcoded.
6. **Measure before features.** Capability claims carry evidence (test_out.log,
   probe output). No feature without a measured need; delete dead weight freely.
7. **Boring shapes.** Scripts over daemons, plain files over databases, stdlib
   over dependencies.
8. **Small blast radius.** A hngh bug may never take the desktop or live sessions
   down (three GPU-hang incidents taught the rollout and ban-list rules).
9. **Never discard work without measuring it.** A shipped implementation and a
   proposed one are compared by BEHAVIOUR (differential harness on identical
   inputs), not by diff size or suspicion; the extra work in a proposal is
   reviewed before it is thrown away. (Operator ruling 2026-10-31: "Do we know
   that our shipped implementation is at parity or superior? Why can't we
   review that extra work before we discard it?")
10. **Decisions get briefs, not binaries.** For a contract-level choice, hand the
    operator benefits, drawbacks, cost, risk, and a recommendation with
    measurements — a yes/no question with no economics is not a decision aid.
    (Operator ruling 2026-10-31: "there should be benefits and drawbacks for
    either choice.")
11. **Admission before load.** Multiple models may stay resident when they FIT:
    every load passes a VRAM admission gate (current residency + estimate <=
    budget) and uses an explicit context; never let an auto-derived context
    decide VRAM for us. (Operator ruling 2026-10-31.)
