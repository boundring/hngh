# What is the exact observable terminal contract (exit code, status file, or log line) that the hngh kernel produces for both clean-complete and timeout-complete states?

Status: crystallized 2026-09-16 from research line `fail-20260915-What-is-the-exact-observable-terminal-co`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-What-is-the-exact-observable-terminal-co.md.

# Research Line: hngh Terminal Contract — Final Structured Summary (Contracted)

**Line:** What is the exact observable terminal contract (exit code, status file, or log line) that the hngh kernel produces for both clean-complete and timeout-complete states?
**State:** contracting → **contracted** (final record; line remains in motion on idle hosts)
**Date of contraction:** 2026-09-16

---

## Contracted Question

> For each terminal state—clean-complete and timeout-complete—identify the **minimal observable** that an external caller (hngh-automation's contract verifier) can rely on to distinguish the two without parsing partial logs or inferring from wall-clock duration. If no single observable suffices, name the compound predicate and its failure mode.

This is narrower than the original expanding-state question. It excludes "is the contract well-designed" in favor of "what does the caller actually see, and is it sufficient."

---

## Epistemic Status (carried forward)

I do **not** have a live read of `~/Projects/etc/hngh` in this pass or any prior beat on this line. All file paths referenced below are **candidates to verify**, not confirmed citations. No primary-source claim about the hngh kernel's internal behavior is asserted as fact; each is framed as a testable hypothesis with an explicit decision criterion. The prior art vault entries listed in References are read-only pointers whose full text I cannot re-verify beyond the titles and dates shown in the line state.

---

## Findings

### F1 — No terminal-state discriminator has been confirmed

As of this contraction, **no single observable** (exit code, status file field, or log sentinel) has been verified as distinguishing clean-complete from timeout-complete in the hngh kernel. The prior beat (2026-09-16, planned → expanding) established the decomposition into three candidate observables and the hypothesis that at least one may be insufficient alone; this contraction converts those hypotheses into a bounded verification protocol. No new primary-source evidence has been gathered between beats.

### F2 — The delegated-contract-verification requirement is deterministic

The prior art pointer `[[concepts/delegated-contract-verification]]` (created 2026-08-2x) frames the caller's need as a *deterministic* terminal signal: the automation layer must be able to classify the run's terminal state without ambiguity. If the kernel emits exit code `0` in both clean-complete and timeout-complete, any caller that treats non-zero as failure will **silently misclassify** timeout-complete as clean-complete. This is the highest-risk failure mode identified on this line.

### F3 — Incremental writes complicate the status-file path

The prior art pointer `[[concepts/llm-upstream-idle-timeout-incremental-writes]]` indicates that the kernel performs **incremental writes** during execution (not a single terminal write). This means the status artifact at timeout-complete may reflect the last incremental write rather than a finalized terminal record. The critical sub-question is whether the timeout path triggers a **finalizing write** (atomic rename, explicit terminal field) or leaves only the last incremental state. This is the central uncertainty in R2 below.

### F4 — Exit-code behavior is unverified

The specific exit code the kernel returns for timeout-complete is unknown. Two candidate mechanisms exist:
- An internal alarm/signal handler that sets a custom non-zero code (e.g., `1`, `124`, or a project-specific value).
- A wrapper (`timeout(1)` or equivalent) that imposes the timeout externally and returns its own convention (GNU `timeout(1)` uses `124`).

I cannot verify which mechanism hngh uses. The code `124` is a GNU coreutils convention; I flag it as an **external, unverified** association, not a claim about hngh's source.

### F5 — Log-line sentinel is the least-constrained candidate

If neither exit code nor status file provides a clean discriminator, the remaining candidate is a **log-line sentinel**: a specific line (or pattern) emitted to stdout/stderr at terminal state. The prior material does not name a specific sentinel string; this remains an open thread (OT-3 below).

---

## Recommendations

These are the bounded set of actions that resolve the contracted question. They are ordered by cost and dependency. Each has an explicit decision criterion so that the next beat can record a pass/fail without re-deriving the logic.

### R1 — Pin the exit-code contract with a two-state probe

**Action:**
1. Run the kernel under a controlled timeout (a task guaranteed to exceed the idle window). Capture `$?` immediately after process exit.
2. Run a task that completes within budget. Capture `$?`.
3. Record both codes. Repeat each at least once to rule out flakiness.

**Decision criterion:**
- **Both `0`:** Exit code is *not* a discriminator. The contract must rest on the status file or log sentinel. Proceed to R2, then R3.
- **Timeout non-zero:** Record the code as the primary discriminator. Verify it is stable across restarts and not an artifact of the wrapper (check whether `timeout(1)` is in the process tree vs. an in-kernel alarm). If the code is `124`, confirm whether that is from a wrapper or from hngh's own signal handler.

**Why this matters:** Cheapest probe, highest misclassification risk if wrong. The delegated-contract-verification requirement (F2) makes this the first gate.

**External/unverified:** The specific code `124` is GNU `timeout(1)` convention. I cannot verify whether hngh uses that wrapper or an internal mechanism. Treat any non-zero code as a hypothesis until the source confirms the emission site.

---

### R2 — Verify status-file atomicity in the timeout path

**Action:**
1. Identify the status artifact. Candidate paths to check (unverified): `hngh/status.json`, `hngh/run_state.yaml`, or any file written by a module matching `grep -rn "status\|run_state\|terminal" ~/Projects/etc/hngh --include="*.py"`. Confirm the actual path from source before proceeding.
2. Trigger a timeout-complete run. Immediately after process exit, read the artifact. Check:
   - Does the file exist?
   - Is it syntactically valid (JSON-parseable / YAML-loadable)?
   - Does it contain a terminal field distinguishing `timeout` from `complete` (e.g., `"status": "timeout"`, `"state": "timed_out"`)?
3. Repeat for clean-complete. Diff the two artifacts.

**Decision criterion:**
- **Timeout path writes a finalized, parseable record with an explicit terminal field:** The status file is the contract. Document its schema and write-path (atomic rename vs. in-place truncate). This resolves the line.
- **Timeout path leaves only the last incremental write** (no terminal field, or a truncated/partial file): The status file is *not* a reliable discriminator for timeout-complete. Proceed to R3.

**Why this matters:** F3 (incremental writes) makes this the central uncertainty. If the kernel does not finalize on timeout, any caller reading the status file will see a mid-execution state and cannot distinguish "timed out" from "still running."

---

### R3 — Identify or define the log-line sentinel (compound predicate fallback)

**Action:**
1. Capture full stdout/stderr for both clean-complete and timeout-complete runs.
2. Search for a line that is **unique to one terminal state** and absent in the other. Candidate patterns: `"run complete"`, `"timeout reached"`, `"idle window exceeded"`, or a structured JSON/YAML line emitted at terminal state.
3. If no single log line discriminates, define the **compound predicate**: e.g., `(exit_code == 0) AND (status_file.status in {"complete", "timeout"}) AND (log contains sentinel_X)`. Name each conjunct and its failure mode.

**Decision criterion:**
- **A unique log line exists for each state:** The log sentinel is a valid secondary discriminator (useful when the status file is absent or partial). Document the exact string and its emission site in source.
- **No single observable suffices:** The contract is the compound predicate. Document it explicitly, including which conjunct is primary and which is fallback. Name the failure mode: e.g., "if the status file write is interrupted by SIGKILL, the caller falls back to log parsing; if the log buffer is unbounded, this degrades."

**Why this matters:** This is the last-resort path. If R1 and R2 both fail to yield a clean discriminator, the caller must rely on a compound predicate, which is more fragile but still deterministic if all conjuncts are verified.

---

## Open Threads

These are items that **cannot be resolved without direct access** to `~/Projects/etc/hngh` or a live run of the kernel. They remain open on the line; they do not block the contraction but they define what the next beat (if the line resumes) must verify.

| ID | Thread | Blocker |
|----|--------|---------|
| OT-1 | Actual exit code for timeout-complete | Requires a live run or source read of the signal/alarm handler in hngh. Cannot be determined from vault pointers alone. |
| OT-2 | Status-file path, schema, and write-path (atomic vs. in-place) | Requires source read of the module that writes the status artifact. The candidate paths (`status.json`, `run_state.yaml`) are unverified. |
| OT-3 | Log-line sentinel string (if one exists) | Requires a live run with full output capture, or source read of the terminal-state logging call site. |
| OT-4 | Whether the timeout mechanism is internal (in-kernel alarm) or external (`timeout(1)` wrapper) | Requires process-tree inspection during a timed-out run, or source read of the invocation path. Affects interpretation of any non-zero exit code. |
| OT-5 | Full text of `[[sources/SRC-2026-08-24-020]]` (Hngh Run Contract) | The vault pointer exists but I cannot re-verify its full content beyond the title and creation date. It may contain a pre-existing contract specification that would resolve R1–R3 without a live run. |

---

## References

All references below are named as they appear in the line state or prior material. I flag verification status explicitly.

| Reference | Type | Verification status |
|-----------|------|---------------------|
| `~/Projects/etc/hngh` | hngh kernel repository (primary source) | **Unverified in this pass.** No file paths within this repo are confirmed to exist. All path mentions in R1–R3 are candidates. |
| `[[concepts/delegated-contract-verification]]` | Vault pointer (prior art) | Title and creation date (2026-08-2x) visible in line state. Full text not re-verified. |
| `[[concepts/llm-upstream-idle-timeout-incremental-writes]]` | Vault pointer (prior art) | Title visible in line state. Full text not re-verified. The "incremental writes" claim (F3) is derived from this title; I flag it as a hypothesis pending source confirmation. |
| `[[sources/SRC-2026-08-24-020]]` — Hngh Run Contract | Vault pointer (prior art) | Title and creation date visible. Full text not re-verified. May contain a pre-existing contract specification (see OT-5). |
| `[[entities/hngh]]` — Hngh Agent Kernel | Vault pointer (entity) | Title visible. Full text not re-verified. |
| `[[concepts/clean-architecture]]` | Vault pointer (prior art) | Title visible. Not directly load-bearing for this line's contraction; listed for completeness of the prior-art set. |
| `[[concepts/clean-architecture-for-machine-intelligences]]` | Vault pointer (prior art) | Title visible. Not directly load-bearing; listed for completeness. |
| GNU `timeout(1)` exit code `124` | External convention | **Unverified for hngh.** This is a coreutils convention, not a claim about hngh's source. Flagged in R1 and F4. |

---

## Disposition

This line is **contracted**. The final structured summary above is the lasting record. The contracted question is bounded: it asks for the minimal observable (or compound predicate) that distinguishes clean-complete from timeout-complete, with an explicit failure mode if no single observable suffices. The three recommendations (R1–R3) are ordered by cost and dependency, each with a pass/fail decision criterion. Five open threads (OT-1 through OT-5) name exactly what requires direct repository access or a live run to resolve. No claim in this record is asserted as verified fact about the hngh kernel's internals; every such claim is framed as a testable hypothesis with an explicit verification path.

The line remains in motion on idle hosts. If it resumes, the next beat picks up at OT-1 through OT-5 and records pass/fail against R1–R3 without re-deriving the decomposition.
