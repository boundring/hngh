# Does the CI/CD pipeline configuration (e.g., `.github/workflows`, `Jenkinsfile`, or `Makefile`) explicitly invoke `hngh-automation/verify.sh` and treat its exit code as a build failure?

Status: crystallized 2026-09-16 from research line `fail-20260916-Does-the-CI-CD-pipeline-configuration-e-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-Does-the-CI-CD-pipeline-configuration-e-.md.

# Research Line: CI/CD Invocation of `hngh-automation/verify.sh` and Failure Propagation

**Line State:** Contracted (Final Record)
**Repository Anchor:** `/home/bricker/Projects/etc/hngh`
**Date:** 2026-09-16

## Executive Summary

The research question—whether the CI/CD pipeline configuration explicitly invokes `hngh-automation/verify.sh` and treats its exit code as a build failure—remains **unresolved** due to insufficient evidence in the available material. No workflow file, Jenkinsfile excerpt, or Makefile target was provided that confirms this invocation. Consequently, the line is closed with a status of **Unverified**, not "Confirmed Absent." The two-part predicate (explicit invocation + failure propagation) cannot be validated without direct access to the repository's pipeline definitions.

## Findings

1.  **Lack of Pipeline Evidence:** No supplied material contains `.github/workflows/*.yml`, `Jenkinsfile`, or `Makefile` content that explicitly names `hngh-automation/verify.sh`.
2.  **Unverified Existence:** The existence of `hngh-automation/verify.sh` at the relative path under `/home/bricker/Projects/etc/hngh` is not confirmed in the provided context.
3.  **Exit Code Contract Unknown:** Without access to the script source or pipeline configuration, the exit-code contract (0 for pass, non-zero for fail) cannot be verified.
4.  **No Failure Propagation Proof:** There is no evidence that the script's exit code is treated as a hard build failure (e.g., via `set -euo pipefail`, being the final command in a step, or explicit `exit $?` handling).

## Recommendations

### R1: Verify and Enforce Explicit Invocation
If the pipeline does not currently invoke `verify.sh`, add an explicit step. If it does, ensure the invocation is unambiguous.

**GitHub Actions Example:**
```yaml
- name: Verify automation
  run: bash hngh-automation/verify.sh
```

**Makefile Example:**
```make
.PHONY: verify
verify:
	bash hngh-automation/verify.sh
```

**Critical Constraint:** The script must be the **last command** in its job/target, or the shell environment must use `set -euo pipefail`. Do **not** wrap the invocation in error-suppressing patterns such as `|| true` or `continue-on-error: true`.

### R2: Pin Failure-Propagation Semantics
Ensure the surrounding shell guarantees that a non-zero exit from `verify.sh` fails the build. Acceptable patterns include:
*   `set -euo pipefail` at the top of the entrypoint script.
*   The script being the final command in the CI step.
*   Explicit capture and propagation: `exit $?`.

**Reject Anti-patterns:**
*   `bash hngh-automation/verify.sh || true`
*   `make verify || echo "non-fatal"`
*   Wrapper scripts that catch `$?` and return 0 regardless of outcome.

### R3: Document the Verification Contract
Add a citable predicate to `README.md`, `CONTRIBUTING.md`, or `hngh-automation/README.md` stating:
1.  The exact command CI runs: `bash hngh-automation/verify.sh`.
2.  That a non-zero exit is a **hard build failure**.
3.  The specific pipeline file(s) and line numbers that enforce this (e.g., `.github/workflows/ci.yml`, line N).

This converts an implicit convention into an auditable fact, allowing future research lines to resolve the question by reading a single document rather than inferring from repository layout.

## Open Threads

The following items remain open and require direct inspection of the repository on an idle host to close:

1.  **File Existence:** Confirm whether `hngh-automation/verify.sh` exists at `/home/bricker/Projects/etc/hngh/hngh-automation/verify.sh`.
    *   *Action:* `ls -la /home/bricker/Projects/etc/hngh/hngh-automation/verify.sh`
2.  **Pipeline Presence:** Confirm whether `.github/workflows/`, `Jenkinsfile`, or `Makefile` exists in the kernel repo and references the script.
    *   *Action:* `grep -rn "verify.sh" /home/bricker/Projects/etc/hngh/.github/workflows/ /home/bricker/Projects/etc/hngh/Jenkinsfile /home/bricker/Projects/etc/hngh/Makefile`
3.  **Script Logic:** Verify the exit-code contract of `verify.sh` itself (does it return 0 on pass, non-zero on fail?).
    *   *Action:* Read source code of `hngh-automation/verify.sh`.

## References

*   `/home/bricker/Projects/etc/hngh` (Kernel repository root; existence of specific pipeline files unverified)
*   `hngh-automation/verify.sh` (Script path; existence and content unverified in current material)
*   Prior Material: Research beat 2026-09-16 (Line state: expanding -> contracting)
