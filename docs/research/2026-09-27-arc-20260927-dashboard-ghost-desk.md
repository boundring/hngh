# How should each edition carry ghost-counsel summary blocks or an explicit ghost_quiet marker, never silently neither?

Status: crystallized 2026-09-27 from research line `arc-20260927-dashboard-ghost-desk`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260927-dashboard-ghost-desk.md.

# Research Line Crystallization: Ghost-Counsel Summary Blocks & `ghost_quiet` Markers

**Line:** How should each edition carry ghost-counsel summary blocks or an explicit ghost_quiet marker, never silently neither?
**Date:** 2026-09-27
**State:** Contracting → Final
**Model:** unsloth:unsloth/Ornith-1.0-9B-GGUF
**Wall Clock:** 30.0s

---

## 1. Findings

### 1.1 Core Principle Established

Every ghost instance must carry exactly one of two structural markers — never neither. This is not metadata; it is a behavioral contract signal. The system must treat the absence of a marker as non-compliance, not as a neutral state.

### 1.2 Dual-State Schema Confirmed

The prior beat (2026-09-27) established a dual-state marker schema with two distinct conditions:

| Marker | Condition | Required Fields |
|--------|-----------|-----------------|
| `ghost_summary` | Ghost has performed activity | `last_activity_ts`, `action_digest`, `state_transition` |
| `ghost_quiet` | Ghost is intentionally silent | `last_activity_ts`, `quiet_reason`, `next_check_interval` |

This schema is small enough to be embedded in the ghost's own state file, avoiding coupling to a separate monitoring service.

### 1.3 Active Declaration Over Passive Scanning

Background processes must communicate state to their host system. Passive scanning creates a window where a ghost can operate without documentation. Active declaration closes that window.

### 1.4 Hierarchical State Aggregation

Ghost state should aggregate hierarchically:
- **Leaf ghosts** (individual processes): full `ghost_summary` or `ghost_quiet`
- **Branch ghosts** (groups): condensed aggregation — `any_child_active`, `last_child_activity_ts`, `child_count`
- **Root ghost** (system): `ghost_quiet` when all children are quiet, `ghost_summary` when any child is active

### 1.5 Constrained Vocabulary for Quiet Reasons

Free-text reasons create an auditability gap. A constrained vocabulary enables downstream components to filter and aggregate without NLP:

```
quiet_reason ∈ {
  "idle",           # No work to do
  "waiting",        # Blocked on external dependency
  "draining",       # Shutting down
  "error",          # Failed to perform work
  "suppressed"      # Explicitly silenced by operator
}
```

### 1.6 Digests Over Raw Logs

The `action_digest` in `ghost_summary` should be a deterministic hash of the ghost's recent actions, not raw log output. Raw logs create storage pressure and maintenance burden.

---

## 2. Recommendations for hngh/hngh-automation

### Recommendation 1: Adopt the Dual-State Marker Schema

Each ghost instance must carry exactly one of two structural markers — never neither. The schema is embedded in the ghost's own state file.

**Implementation:** Per-ghost state object read on every tick by the automation layer.

### Recommendation 2: Enforce via Active Declaration, Not Passive Scanning

Ghosts must declare their state before operating. The lifecycle hook requires a state declaration at two points:
1. **On activation** — ghost declares `ghost_summary` with initial state
2. **On inactivity** — ghost declares `ghost_quiet` after a configurable timeout (e.g., 30s of no activity)

If neither marker is present when the automation layer checks, the ghost is treated as **non-compliant** and its operations are blocked until it declares state.

### Recommendation 3: Hierarchical State Aggregation

Parent ghost state files contain a `children` array with references to child ghost state files. The parent's marker is derived from child states, not independently maintained. This prevents state drift where a parent claims silence while a child is active.

### Recommendation 4: Quiet Reason Must Be Auditable

The `quiet_reason` field uses a constrained vocabulary (see §1.5). This enables monitoring, alerting, and operator dashboards to filter and aggregate without NLP.

### Recommendation 5: Summary Blocks Must Include a Digest, Not Raw Logs

The `action_digest` is a deterministic hash of the ghost's recent actions. This prevents storage pressure and log maintenance burden.

---

## 3. Open Threads

| Thread | Status | Notes |
|--------|--------|-------|
| Exact timeout values for `next_check_interval` | Open | Prior beat suggested 30s; needs tuning against actual ghost workloads |
| Digest algorithm choice (SHA-256 vs. others) | Open | Prior beat did not specify; needs security review |
| Integration with existing hngh-automation state files | Open | Needs concrete file path mapping |
| Backward compatibility with ghosts that predate this schema | Open | Migration path not specified |
| Operator-facing UI for `ghost_quiet` reasons | Open | Constrained vocabulary enables this; design not yet done |

---

## 4. References

### Repository Sources (hngh)

| Reference | Status |
|-----------|--------|
| `[redacted path] | Repository root; referenced as ground truth for all claims |
| `research-lines.tsv` | Line state tracking; this line's state transition recorded here |

### Prior Material Sources (wiki-style pointers from prior beat)

| Reference | Status |
|-----------|--------|
| `[[sources/pi-llm-wiki-guardrail-blocks-apply-patch-edits]]` | Cited in prior beat for structural block enforcement principle; **cannot independently verify file path** |
| `[[sources/async-proof-pattern-for-long-drop-ins]]` | Cited in prior beat for active declaration pattern; **cannot independently verify file path** |
| `[[sources/SRC-2026-08-18-009]]` | Cited in prior beat for ultrametric routing pattern; **cannot independently verify file path** |
| `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` | Cited in prior beat; **cannot independently verify file path** |
| `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]` | Cited in prior beat; **cannot independently verify file path** |
| `[[sources/sincetmw-ai-cultural-intelligence]]` | Cited in prior beat; **cannot independently verify file path** |

### External Sources

**None asserted.** All claims are grounded in the hngh repository and the prior beat material. No external sources were invoked.

### Caveats

- The prior beat material (2026-09-27) is the primary source for all 5 recommendations. This crystallization is a re-statement and refinement, not new discovery.
- File paths for prior material sources are cited as-is from the prior beat; I cannot independently verify their existence in the repository.
- The dual-state schema, active declaration pattern, hierarchical aggregation, constrained vocabulary, and digest-over-logs recommendations are all derived from the prior beat's prior art analysis.

---

**End of line.** This record supersedes the prior beat at 2026-09-27 for this line.
