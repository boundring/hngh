# hngh v2 — principles

The v1 lesson, from the Lisp loop framework archived at `archive/v1`:
building a framework before there is a measured need accretes unwieldy
debt, and it is hard to reorient mid-stream. v2 takes its lead from the
tools it shepherds — billion-context, oh-my-pi, Tern — each of which does
one job over existing infrastructure and stays thin.

1. Shepherd, don't replace. hngh wraps what the operator already runs:
   omp sessions, Tern tabs, unsloth studio, git. It adds thin CLI entry
   points, ledgers and gates. Never a parallel runtime. Never its own
   daemon unless there is a measured need.
2. Every tool has a selfcheck. It runs sandboxed and exits with honest
   codes. A tool without `hngh-<name>-selfcheck` is not landed.
3. Ledgers are the audit trail. Append-only JSONL. Fold views are
   derived from the ledger and never hand-edited. Exactly one writer per
   ledger file.
4. Gates at operator presence. The tiers are Silent / Confirm /
   Presence-gated / Forbidden (AGENTS.md §11 tiers). "may I act" and "is now a
   safe moment" are different questions.
5. Config and env over code. Model pins, contexts and quotas come from
   env files and overlay yaml. Nothing load-bearing is hardcoded.
6. Measure before features. A capability claim carries its evidence:
   test_out.log, probe output. No feature without a measured need. Delete
   dead weight freely.
7. Boring shapes. Scripts over daemons. Plain files over databases.
   Stdlib over dependencies.
8. Small blast radius. A hngh bug may never take the desktop or live
   sessions down. Three GPU-hang incidents taught the rollout and
   ban-list rules.
9. Never discard work without measuring it. A shipped implementation and
   a proposed one are compared by BEHAVIOUR — a differential harness on
   identical inputs — not by diff size or suspicion. The extra work in a
   proposal is reviewed before it is thrown away. (Operator ruling
   2026-10-31: "Do we know that our shipped implementation is at parity
   or superior? Why can't we review that extra work before we discard
   it?")
10. Decisions get briefs, not binaries. For a contract-level choice, hand
    the operator the benefits, the drawbacks, the cost, the risk, and a
    recommendation with measurements. A yes/no question with no economics
    is not a decision aid. (Operator ruling 2026-10-31: "there should be
    benefits and drawbacks for either choice.")
11. Admission before load. Multiple models may stay resident when they
    FIT: every load passes a VRAM admission gate (current residency +
    estimate <= budget) and uses an explicit context. Never let an
    auto-derived context decide VRAM for us. (Operator ruling
    2026-10-31.)
