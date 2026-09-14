# Why does dropin:20-workbeat.sh show wall=1964.6s against a 40.3s median (x6, routed 2026-09-12T20:00:35Z), is that latency a defect or expected forethought-dream+plan-session work, and what disposition (fix or park) does the evidence support?

Status: crystallized 2026-09-14 from research line `fail-20260912-slow-unit-dropin-20-workbeat.sh`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260912-slow-unit-dropin-20-workbeat.sh.md.

# Contracted line record — `dropin:20-workbeat.sh` wall/median divergence

**Line:** Why does `dropin:20-workbeat.sh` show `wall=1964.6s` against a `40.3s` median (x6, routed `2026-09-12T20:00:35Z`) — is that latency a defect or expected forethought-dream+plan-session work, and what disposition does the evidence support?

**State:** contracting → **contracted**

**Disposition recommendation:** **Park as evidence-pending.** Do not classify as fixed, and do not classify as confirmed expected forethought work. The available evidence supports holding the line open with a concrete reactivation trigger: obtain a phase-level decomposition of the outlier run and correlate it against the forethought-dream/plan-session schedule or gate state.

---

## Findings

### 1. The confirmed quantitative core is narrow

The only directly confirmed facts are the line metadata:

- one observed sample has `wall=1964.6s`;
- the reported median across x6 is `40.3s`;
- the instance was routed at `2026-09-12T20:00:35Z`.

The ratio is approximately:

```text
1964.6 / 40.3 ≈ 48.75×
```

That is a large divergence, but the metadata alone does not explain what the wall time included.

### 2. The continuous-motion framing matters

The line must not be read as a scheduled batch that stalled. The prior material correctly frames `x6` as six observed samples of a continuously moving dropin on idle hosts, with the routed timestamp marking when this instance was routed to a host.

Therefore the operative question is:

> Why did this one sampled run take ~48× the median wall time?

not:

> Why did a batch stall?

### 3. The two numbers are not yet demonstrably measuring the same quantity

The `wall=1964.6s` value and the `40.3s` median may both be wall-clock durations, but the available material does not establish:

- whether the outlier run started and ended under the same definition of “run”;
- whether the routed timestamp is start, dispatch, enqueue, completion, or some other boundary;
- whether the six samples share the same code path, host class, session state, and gate behavior;
- whether the wall time includes sleep/wait, lock hold, network I/O, active CPU, or external session gating.

Without that alignment, the 48× gap cannot be cleanly attributed to a defect or to expected forethought work.

### 4. No execution trace exists in the available material

The prior expansion reached the same ceiling: without direct access to the relevant execution trace and repository artifacts, the line cannot be definitively classified.

That remains the honest epistemic limit of this contracted record.

### 5. “Expected forethought-dream+plan-session work” is plausible but unverified

It is plausible that a dropin may wait on or participate in a forethought-dream or plan-session window, especially if such windows are governance/rehearsal-oriented and do not mutate live ledgers. However, the available material does not verify:

- that this run fell inside such a window;
- that the wall time was spent waiting on a documented gate;
- that the wait was bounded by design;
- that no mutation or ledger side effect occurred;
- that the forethought/plan-session behavior is the cause rather than a coincidental overlap.

Therefore “expected forethought work” remains a hypothesis, not an established finding.

### 6. “Defect” is also unproven

There is no demonstrated defect in the available material. Specifically, there is no evidence of:

- deadlock;
- unbounded lock hold;
- retry storm;
- network stall;
- scheduler starvation;
- repeated execution;
- ledger corruption;
- incorrect state transition;
- missing completion event;

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
