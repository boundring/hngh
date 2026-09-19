# Jev in the wild vs Jev in hngh — comparison (2026-09-19)

Sources: explainx top-10 use cases (Sep 16), LangChain harness guide
(Sep 17, ModelRouter + AutoMode middleware), valyu practical guide
(Sep 17: 5 patterns, launch-week builds, jaggedness page).

## Wild use cases mapped to hngh work

| # | Wild use case | Primitive | Hngh counterpart | Status |
|---|---|---|---|---|
| 1 | Support ticket routing | Choice | Beat triage fan-out (`hngh-1de`) | Tracked, unwired |
| 2 | Fraud-tier scoring | Score | Model-rank cheap-fit Score | Mapped, pending bead |
| 3 | Moderation triage (Noul gate + Choice) | Noul+Choice | Beat-skip gate + lane Choice | WIRED (`d740d967`) |
| 4 | Real-time NPC/agent decisions | Choice | Claim router (worker × bead) | Designed, unwired |
| 5 | A/B + feature-flag routing | Choice | Beat pacing Score | Designed, unwired |
| 6 | Guardrail on LLM output | Noul | Evidence-sufficient Noul at close-out | Designed, unwired |
| 7 | Map-reduce classification | Choice/Score | Backlog triage at scale | Future |
| 8 | Voice turn-taking | Noul | Operator-active Noul | WIRED (beat-skip) |
| 9 | Dynamic pricing scoring | Score | Budget governor Score | Designed, unwired |
| 10 | Recommendation re-ranking | Score/Choice | Hottest-lane Choice | PROVEN live |
| 11 | Computer use dispatch ($0.0002/step) | Choice | City-state → action dispatch | Future |
| 12 | LLM autorouting + confidence | Choice | ModelRouter equivalent in model.sh | Partial (static ladder) |

## Patterns we should steal (valyu five)

1. **Speculative fan-out**: our triage call should ask all 13-ish
   lane questions at once (12.2x cheaper, 10x faster than serial).
2. **Confidence-gated routing**: per-action thresholds scaled to cost
   of being wrong — our close-out needs this (low confidence → person).
3. **Composite scoring**: bead-heat = weighted Noul/Choice/Score atoms;
   re-weight in code, not prompts.
4. **Cascade**: Jev classifies, code handles the easy branch with NO
   model at all, frontier takes the hard minority. Our beats should
   have a pure-code fast path (pattern: skip-guard already does).
5. **Retrieve-then-judge**: Jev knows only the state we hand it.
   `city-state.py` IS our retriever — keep it lean (context rot is
   real: accuracy falls with irrelevant state).

## Builds to study (launch-week, self-reported)

- **browser-use/jev-ultrafast** (641★): dynamic indexed action space,
  one Jev call picks op + target; speculative fan-out on actions;
  Zurich→London in 7.1s at $0.0039. Lesson: ask all action variants
  in one round trip.
- **awlevin/typesafe-computer-use**: OCR + Jev + writing-model-only;
  $0.0002/decision vs $0.032 Opus; ~1.5s vs 5.5s per step. Caveat:
  every reasoning bit the frontier did free must be rebuilt as
  deterministic state. Directly applicable to our beats.
- **jarrodwatts/jev-trader**: one decision per block, ~81ms model
  latency, dry-run mode. Lesson: ship dry-run first (our beats-held
  state IS a dry-run harness).
- **RomanSlack/jev-drone**: Jev advisory-only at 2.5Hz under code-owned
  50Hz safety reflex. Lesson: Jev never owns safety — our fail-open
  posture already matches.
- **devagrawal09/jev-review** (48★): staged code reviewer (Noul risk →
  Choice/Score profiles → routing). Closest to our reviewer gates.
- **1kpapers.com**: 1,018 papers, summaries $3.99 vs classifications
  $0.08, 256ms/paper. Lesson: different models per workflow stage.
- **Ad-blocker failure**: rescanned everything (no cache), no vision,
  cost scaled per-element not per-page, privacy self-defeat. Lessons:
  cache verdicts (our 30s beatskip cache does), cost-unit discipline,
  data boundaries.

## Failure modes to carry (jaggedness page)

- Reads literally: write the question you mean (our beat-skip
  instructions need this care).
- Not a calculator: one Noul per item, count in code.
- Dates are text: Choice over enumerated options, ordering in code.
- Context rot: retrieve-then-judge, lean state.
- State not hostile: user content in state is our threat model.
- Cannot hallucinate values but CAN be confidently wrong: never sole
  gate on high-stakes closes.
- Pin `jev-1.13.0` when thresholds are tuned (`jev-latest` moves).

## Self-prompting harness direction

The wild pattern that matches the operator's vision: LangChain's
ModelRouter + AutoMode middleware = Jev deciding which model acts and
whether tool calls proceed. Hngh's generalization: Jev inside the
cadence loop deciding lane/worker/model/pace per beat, with the
4-key state file as the context the automated self-improvement writes
to itself. The beats-held state is the safe lab: wire triage fan-out
(`hngh-1de`) first, observe calibration, then claim router, then
budget governor. Each loop makes the next loop's state richer —
compounding by construction.
