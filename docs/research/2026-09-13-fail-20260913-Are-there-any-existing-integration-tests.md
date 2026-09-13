# Are there any existing integration tests or CI pipelines that already exercise the `lib/automation.py`  `bin/hngh` boundary, and do they pass with the current implementation?

Status: crystallized 2026-09-13 from research line `fail-20260913-Are-there-any-existing-integration-tests`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-Are-there-any-existing-integration-tests.md.

# Research Line: `lib/automation.py` ↔ `bin/hngh` Boundary Testing & CI Coverage

**Line State:** Contracting (final structured summary)
**Question:** Are there any existing integration tests or CI pipelines that already exercise the `lib/automation.py` ↔ `bin/hngh` boundary, and do they pass with the current implementation?

---

## Findings

### F1 — An overnight harness exists but is not a synchronous CI gate

The observation record `obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` documents that an overnight harness was built, verified, and enabled for exercising the automation boundary. However, per the expanding-phase analysis, this harness operates on a deferred schedule (overnight runs) rather than as a blocking pre-merge check. It therefore provides *eventual* regression detection, not *preventive* gating.

**Confidence:** High — grounded in the observation record cited in prior material. I cannot independently verify the harness's current operational status or its exact invocation path within this session; that would require reading the harness script and its scheduler configuration in-repo.

### F2 — A "Hngh Test Boundary" concept is formally tracked

Source document `SRC-2026-08-24-029` ("Hngh Test Boundary") establishes that the boundary between `lib/automation.py` and `bin/hngh` is a recognized, named test concern in the project's documentation. This confirms the boundary is not an afterthought; it has been identified as a distinct integration surface warranting dedicated coverage.

**Confidence:** High — the source ID is cited in prior material. I cannot verify the full text of SRC-2026-08-24-029 beyond its title and the context provided in prior material.

### F3 — An upstream guardrail bug indicates active instability at this boundary

The observation `obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr` records that a guardrail bug was filed against the upstream hngh kernel. The expanding phase interpreted this as evidence that the CLI contract (exit codes, stdout format, flag surface) is in flux and that `lib/automation.py`'s assumptions about `bin/hngh` behavior are not yet stable.

**Confidence:** Medium-High — the observation ID is cited; the specific bug details (which guardrail, which kernel version, resolution status) are not fully specified in the prior material I can see. I cannot verify whether this bug has been resolved in the current kernel at `~/Projects/etc/hngh` without reading that repository's changelog or issue tracker.

### F4 — No committed synchronous CI boundary test was identified in the expanding phase

The core finding of the expanding phase is negative: no existing integration test or CI pipeline job was found that (a) invokes the real `bin/hngh` binary, (b) exercises it through `lib/automation.py`'s code path, and (c) runs as a required pre-merge gate. The overnight harness (F1) covers the boundary but does not block merges.

**Confidence:** Medium — this is the expanding phase's conclusion based on its survey of the repository. I cannot re-run that survey in this session. If a CI configuration file (e.g., under `.github/workflows/`, `.gitlab-ci.yml`, or a Makefile target) was added after the expanding phase's last observation, this finding may be stale. The line is always in motion; a new job could have landed between beats.

### F5 — Pass/fail status of any existing boundary exercise is unconfirmed

The prior material does not record a definitive pass/fail result for the overnight harness against the *current* implementation. The guardrail bug (F3) suggests at least one failure mode was observed, but whether the harness now passes cleanly after kernel-side fixes is not established in the available material.

**Confidence:** Low — this is an explicit gap. I cannot verify current pass/fail status without executing the test or reading recent CI logs.

---

## Recommendations

### R1 — Add a committed boundary integration test (blocking)

Create `tests/integration/test_automation_hngh_boundary.py` (or equivalent path consistent with the repo's existing test layout). Requirements:

- Invokes the real `bin/hngh` executable via `subprocess.run()`; no mocking of the binary.
- Covers the happy path and one known failure mode (e.g., invalid flag or missing config file) sufficient to detect CLI contract drift.
- Is scoped as a *boundary* test, not a full CLI surface-area test.

This directly addresses F4: if no such test exists in CI, this is the minimal addition that converts deferred detection into synchronous gating.

### R2 — Wire the boundary test into CI as a required check

Add a dedicated job (GitHub Actions workflow step, GitLab CI stage, or equivalent) that:
1. Builds or installs the `hngh` kernel dependency at a pinned version.
2. Runs the boundary integration test from R1.
3. Is marked as a required/mandatory check for merge.

This makes the boundary a *gate* rather than an *audit*. The overnight harness (F1) can remain as a secondary, broader-surface verification layer, but it should no longer be the sole regression detector.

### R3 — Pin the kernel version in CI and re-validate on bump

Given F3 (active upstream instability), the CI job must pin the `hngh` kernel version explicitly (lockfile, `requirements.txt` entry, or a version constant in the CI setup script). Any kernel version bump requires manual re-validation of the boundary test before the pin is updated. This prevents silent contract drift from reaching the merge gate.

### R4 — Document the boundary contract in-repo

Create or update a document (e.g., `docs/boundary-contract.md` or a section within existing `hngh-automation` docs) stating:
- The exact CLI contract `lib/automation.py` expects from `bin/hngh` (exit codes, stdout/stderr format, side effects on filesystem).
- Which test file enforces this contract.
- How to run the boundary test locally.
- The relationship to `SRC-2026-08-24-029`.

This ensures the *why* of the boundary test survives beyond the original author's context.

### R5 — Audit and reposition the overnight harness

Review the overnight harness (per F1) against the new CI job from R2. If the CI job now covers the same happy-path + failure-mode scope, the overnight harness should be re-scoped to:
- Cover broader surface area (more flags, more config permutations) that is impractical for a fast CI gate.
- Serve as a *canary* for long-running or resource-intensive scenarios.
- No longer be the primary regression detector for the core boundary contract.

If the overnight harness duplicates the CI job's scope exactly, it is redundant for regression detection and should be retired or explicitly re-scoped.

### R6 — Confirm current pass/fail status (immediate action)

Before R1–R5 are implemented, run the existing overnight harness (or any other boundary exercise identified in F4) against the current `lib/automation.py` and the current kernel at `~/Projects/etc/hngh`. Record the result. This closes gap F5 and establishes a baseline: if the boundary is currently passing, R1–R2 are *preventive*; if it is failing, they are *remedial* and should be prioritized accordingly.

---

## Open Threads

| Thread | Status | Why it remains open |
|--------|--------|---------------------|
| Current pass/fail of boundary exercise | Unconfirmed (F5) | Requires executing the test or reading recent CI/harness logs. Not resolvable from prior material alone. |
| Resolution status of upstream guardrail bug | Unknown | The observation records the *filing*; no subsequent observation in the available material records resolution. Would require checking the hngh kernel repo's issue tracker or changelog at `~/Projects/etc/hngh`. |
| Exact CI configuration surface | Unverified (F4) | The expanding phase found no synchronous boundary job, but I cannot confirm whether a `.github/workflows/`, `.gitlab-ci.yml`, or Makefile target was added after that survey. A fresh `grep -r "hngh" .github/ .gitlab-ci.yml Makefile` would close this. |
| Overnight harness scope vs. CI scope overlap | Unquantified (R5) | The observation confirms the harness exists and is enabled, but its exact test matrix (which flags, which configs, which kernel versions) is not specified in the available material. Needed to decide redundancy. |
| Kernel repo file layout at `~/Projects/etc/hngh` | Not independently verified | Prior material references `bin/hngh` as the binary path within that repo. I am citing this path based on prior material's claims and the research line's own framing. I have not independently confirmed the directory structure in this session. |

---

## References

1. **Prior material, expanding phase** (this research line, beat 2026-09-13): Contains the survey findings (F4), the overnight harness identification (F1), and recommendations R1–R5 as initially drafted. Truncated at 4000 bytes in the provided context; recommendation 5 was cut mid-sentence.

2. **`obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled`** — Observation record documenting construction, verification, and enablement of the overnight harness for `hngh-automation`. Cited in prior material as the primary evidence for F1.

3. **`obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr`** — Observation record documenting the filing of a guardrail bug against upstream hngh. Cited in prior material as evidence for F3 (active boundary instability).

4. **`SRC-2026-08-24-029`** ("Hngh Test Boundary") — Source document establishing the test boundary as a named, tracked concern. Cited in prior material; supports F2 and R4.

5. **`SRC-2026-08-24-026`** ("Hngh Roadmap (current state, 2026-08-24)") — Source document providing roadmap context for the hngh project as of 2026-08-24. Referenced in prior art list; not directly load-bearing for findings F1–F5 but provides temporal context.

6. **`concepts/hngh-lessons-current`** (created 2026-09-07) — Concept note on current hngh lessons. Referenced in prior art list; may contain distilled operational knowledge relevant to R3 (version pinning) and R5 (harness re-scoping), but its full content is not available in this session.

7. **`~/Projects/etc/hngh`** — The hngh kernel repository path, referenced as the location of `bin/hngh`. Cited based on prior material's framing and the research line's own question. I have not independently verified its directory structure in this session; see Open Threads row 5.

8. **`lib/automation.py`** — The automation library module whose boundary with `bin/hngh` is the subject of this line. Path cited per the research line's framing. Full contents not independently verified in this session.

---

*Line crystallized. The question "do they pass with the current implementation?" remains explicitly open (F5, Open Thread 1) and should be the first action item upon resumption: execute R6, record the result, then proceed with R1–R5 in that order.*
