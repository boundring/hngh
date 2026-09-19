# Jev playbook — full, purposeful, actionable use (2026-09-19)

Source docs: System One (Jev = flagship System One model; calibrated
typed decisions, not prose), Primitives (Choice/Score/Noul composition;
parallel fan-out ~free; speculative questions; split complex judgments;
dot-path state refs), Advanced structure (JSON instructions/criteria;
taxonomy walks; JSON rubrics).

Live proofs this session: 4-key Noul `calm`=0.12 (~1s); 3-question
fan-out over live lanes (choice=reviewer-gates, score=2.27 pressing,
noul collapse=0.36) in 1.3s, one call.

## Strategies: Jev routes work by state

1. **Triage fan-out** (one call, Noul per lane + Choice hottest + Score
   heat): every beat asks once, workers go to the hottest lane.
2. **Claim router** (Choice over idle workers × ready beads): who takes
   what, no coordinator in the loop.
3. **Lane taxonomy walk** (Choice per level, options = children with
   subtrees): work → lane → bead → acceptance step. Beam on close
   probabilities.
4. **Model-rank** (Score per task: cheap-fit spectrum): muse-spark vs
   deepseek vs glm vs burst-gemini, thresholded in code.
5. **Beat pacing** (Score: run/pace/skip spectrum on load + operator
   signals): replaces the failfirst ladder with calibrated judgment.
6. **Collapse deliberation** (Noul absorb? + Choice absorb/record/park
   per completed cluster): the looping-to-collapse thread.
7. **Closure driver** (Choice drive/defer/split per hot bead + Noul
   evidence-sufficient?): the looping-to-closure thread.
8. **Speculative sweep** (13-question cookbook pattern: ask everything
   possibly needed, code ignores the rest): 11.5x cheaper, 9.6x faster
   than serial calls.

## Strategies: Jev routes state by state

9. **Config tuner** (Score per threshold: window widths, quiet guards,
   cache TTLs): state in, level out, code applies.
10. **Guardrail watcher** (Noul per seam: credentials healthy? chain
    intact? budget within?): structured health checks replacing grep.
11. **Budget governor** (Score spend-rate + Choice throttle/normal/burst):
    value-add spending enforced by judgment, not static caps.
12. **Maintenance scheduler** (Choice nightly/weekly/on-demand per
    subsystem from drift signals): ledger sync, Dolt push, log rotation.
13. **Dot-path refs**: questions name state paths
    (`beads.hottest.acceptance`, `timers.hngh count`) so intent survives
    compression. State file pattern: beats write 4-key lines, Jev reads
    the file, never the repo.

## The three loops

- **Looping-to-collapse**: each cycle asks collapse Noul + absorb/record/
  park Choice over completed clusters. Queue shrinks by judgment.
- **Looping-to-closure**: triage fan-out → claim router → worker executes
  → evidence Noul → close-with-comment. Beads drain by judgment.
- **Looping-as-service**: always-on decision endpoint. State file in,
  verdicts out. Safe 2/min lane now; 10/sec burst parked until proven.
  Failover: fail-open to existing guards (never block), breadcrumb on
  fallback, keyless = None.

## Guardrails (balance, care, experimentation)

- Calibrated ≠ correct: confidence routes escalation (low → person or
  reasoning model), never auto-acts on high-stakes closes.
- One snap judgment per question; split complex calls, weight in code.
- Second requests only for real dependencies (fetch more state, pick
  next options); otherwise fan out speculatively in one call.
- Experiment log: every new question shape gets a bead; keep what
  calibrates, kill what drifts.
- Budgets: tokens shared (~32k); questions barely move latency; burst
  lane stays parked.

## Next wirings (ordered)

1. Triage fan-out in the morning digest (one call, hottest lane out).
2. Claim router in worker spawn prompts.
3. Collapse deliberation over completed clusters weekly.
4. Budget governor when OpenRouter spend is instrumented.
5. Maintenance scheduler after manual patterns prove out.
