# patrol: surface research-ledger filed harvest-stale on two consecutive runs -- why does it keep failing and which guardrail closes it?

Status: crystallized 2026-09-22 from research line `patrol-20260922-research-ledger-harvest-stale`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-patrol-20260922-research-ledger-harvest-stale.md.

# Contracted Research Record — `patrol`

**Line:** `patrol: surface research-ledger filed harvest-stale on two consecutive runs -- why does it keep failing and which guardrail closes it?`  
**Lifecycle state:** contracting → final structured summary  
**Grounding basis:** This transition is grounded only in the supplied line state, prior material, and the named repository root `[redacted path] I did not independently verify deeper file paths, schemas, or guardrail implementations from that repository in this transition. Where a claim depends on unverified structure, it is labeled as such.

---

## 1. Findings

### 1.1 `harvest-stale` is a consistency/evidence-reconciliation failure, not necessarily data loss

The recurring `harvest-stale` condition should be read as a **verification mismatch**, not automatically as corruption or lost evidence.

The most defensible interpretation is:

- The research ledger records evidence pointers for a line.
- A later harvest run tries to reconcile those pointers against the current repository state.
- If the recorded evidence no longer matches the live state, the run files `harvest-stale`.
- If the baseline is not updated after a legitimate change, the same mismatch can recur on the next run.

This makes the failure **persistent by construction** if the system keeps comparing against an old baseline instead of re-baselining after accepted drift.

**Verification status:** This is a strong structural inference from the line name and prior material. The exact comparison logic in `[redacted path] was not verified here.

---

### 1.2 Two consecutive `harvest-stale` runs indicate a missing or ineffective re-baseline step

The key operational problem is not merely that one run failed stale. The important signal is that **two consecutive runs** produced the same failure class.

That pattern implies one of the following:

1. The evidence baseline was never refreshed after the first stale result.
2. The repository legitimately moved between runs, but the ledger still points at the old state.
3. The harvest process treats any byte-level or commit-level drift as stale without distinguishing:
   - expected evolution,
   - accidental drift,
   - true evidence invalidation.
4. The guardrail that should close or demote the line after repeated failure is either:
   - not wired to `harvest-stale`,
   - not persisting closure state,
   - or only logging without changing lifecycle state.

**Verification status:** Unverified hypothesis based on the supplied failure pattern and prior material. No concrete guardrail implementation path was verified in this transition.

---

### 1.3 The likely root cause is missing evidence pinning in the ledger schema

If `research-lines.tsv` does not carry stable versioning metadata, the harvest process cannot reliably distinguish:

- “the file changed since last verification,”
- “the line was rebaselined and should now point at the new state,”
- “the evidence is genuinely invalid.”

A minimal robust ledger schema would need fields such as:

- `commit_pin` — the repository commit at which evidence was verified,
- `evidence_hash` — hash of cited file contents at verification time,
- `last_verified_ts` — timestamp of last successful verification,
- `baseline_state` — e.g. `active`, `re-baselined`, `stale`, `demoted`.

Without those fields, the system has no stable anchor for what “current” means at verification time.

**Verification status:** Unverified schema claim. The line state names `research-lines.tsv`, but I did not verify its actual columns or full path in this transition.

---

### 1.4 The guardrail that closes the line is the consecutive-failure demotion/cancellation guardrail

Based on the supplied prior material, the closing control is best described as a **consecutive-failure guardrail**, specifically one associated with:

- `outcome-demotion-at-two-consecutive-failures`
- “bad-execution cancellation”

In other words, the line should not remain indefinitely in a failing loop. After two consecutive bad executions — here, two consecutive `harvest-stale` results — the guardrail should close the line by demotion or cancellation, depending on policy.

The important distinction is:

- **Harvest logic** explains *why* the failure recurs.
- **Guardrail logic** determines *when the line stops being pursued*.

If the line is still open after two consecutive `harvest-stale` runs, then one of these is true:

1. The guardrail threshold has not actually been reached in persisted state.
2. `harvest-stale` is not being counted as a bad execution for that guardrail.
3. The guardrail fired but closure/demotion was not recorded.
4. The line was reopened or re-armed after closure without resetting the evidence baseline.

**Verification status:** The prior material names the relevant guardrail concept, but I did not verify its concrete implementation path in `[redacted path] or any automation repository.

---

## 2. Recommendations

### 2.1 Add explicit evidence pinning to the ledger

The ledger should record enough state to make stale detection deterministic.

Recommended fields for `research-lines.tsv` or its equivalent:

| Field | Purpose |
|---|---|
| `commit_pin` | Pins evidence to a specific repository commit |
| `evidence_hash` | Records content hash of cited files at verification time |
| `last_verified_ts` | Records when the last successful verification occurred |
| `baseline_state` | Tracks whether the line is active, rebaselined, stale, or demoted |
| `failure_class` | Records the latest failure class, e.g. `harvest-stale` |
| `consecutive_failures` | Counts consecutive failures for guardrail evaluation |

This turns “stale” from an ambiguous flag into a testable condition:

> Is the current evidence still valid at the pinned commit and hash?

**Verification status:** Recommendation only. The actual schema was not verified in this transition.

---

### 2.2 Force re-baselining before allowing a third consecutive failure

The cleanest fix for the recurring loop is to change the post-failure behavior:

1. On first `harvest-stale`:
   - record failure,
   - keep line active,
   - do not yet demote.

2. On second consecutive `harvest-stale`:
   - trigger re-baselining,
   - reset evidence pointers to the current repository head if policy allows it,
   - mark the line as `re-baselined`,
   - allow one additional verification run.

3. If a third consecutive failure occurs after re-baselining:
   - apply the consecutive-failure guardrail,
   - demote or cancel the line,
   - persist closure state explicitly.

This breaks the pathological loop where the system keeps testing the same old baseline against a newer repository state.

**Verification status:** Design recommendation. No implementation path was verified here.

---

### 2.3 Make the closing guardrail explicit and observable

The guardrail should not be implicit. It should be visible in the ledger or line state.

Minimum observable behavior:

- `consecutive_failures` increments on each bad run.
- At threshold `2`, the system records which guardrail fired.
- The line state changes to a terminal or demoted state, unless re-baselining policy explicitly intervenes.
- Closure reason is stored, e.g.:
  - `closed_by_consecutive_failure_demotion`
  - `cancelled_by_bad_execution_guardrail`

This prevents the ambiguous situation where a line appears “still open” even though it has already crossed the failure threshold.

**Verification status:** Recommendation only. The exact guardrail implementation was not verified in this transition.

---

### 2.4 Pin citations at creation and update time

Every research line should carry evidence anchors when it is created or materially updated.

At minimum, the process should capture:

- repository commit SHA,
- file paths cited by the line,

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
