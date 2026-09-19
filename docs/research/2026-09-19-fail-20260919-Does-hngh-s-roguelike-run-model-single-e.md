# Does `hngh`'s "roguelike run model" (single-execution lifecycle) inherently prevent durable state updates for unit practice, requiring an explicit persistence hook that is currently absent?

Status: crystallized 2026-09-19 from research line `fail-20260919-Does-hngh-s-roguelike-run-model-single-e`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260919-Does-hngh-s-roguelike-run-model-single-e.md.

# Research line crystallization: `hngh` roguelike run model and durable unit-practice state

**Line:** Does `hngh`'s "roguelike run model" (single-execution lifecycle) inherently prevent durable state updates for unit practice, requiring an explicit persistence hook that is currently absent?  
**Lifecycle after this transition:** `contracting -> crystallized`  
**Record type:** Final structured summary / lasting record for this line.

## Verification limitation

In this transition I do not have verified file-level access to the contents of `[redacted path] Therefore:

- I cite only the supplied kernel root path, `[redacted path] — correction: `[redacted path] as provided in the prompt.
- I do not assert specific internal file paths, function names, configuration files, database schemas, or automation components unless they are present in the supplied prior material.
- The findings below are grounded in the supplied research line, the prior material for this line, and the supplied kernel root as a grounding boundary.
- Where a claim would require external sources that I cannot verify here, I say so explicitly rather than asserting it.

---

## Contracted question

Under `hngh`'s single-execution roguelike run model, durable unit-practice state does **not** survive by default; if unit-practice state is meant to cross run boundaries, it requires an explicit persistence mechanism at or before the run boundary.

The line is no longer an open design question about whether the model “inherently prevents” durability. It is now a verification task:

> Determine whether `hngh` / `hngh-automation` provides an explicit persistence path for unit-practice state, and if not, confirm that absence as the current state of the system.

The three candidate mechanisms to audit are:

1. **In-run persistence hook** — the run itself serializes durable state before termination.
2. **External boundary supervisor** — a process, service, or automation layer captures state at the run boundary.
3. **Filesystem side effect** — durable state is written as an explicit side effect during or immediately after the run.

---

## Findings

### 1. The roguelike run model does not inherently prevent durable state

The original framing — that the single-execution lifecycle *inherently prevents* durable state updates — is too strong and should be dropped.

A single-execution lifecycle prevents **in-process continuity after termination**, not durable state per se. A process can write to disk, append to a log, update a database

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
