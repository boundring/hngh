# What CI/CD systems publish machine-checkable evidence of change governance, and what do their artifacts cover?

Status: crystallized 2026-09-11 from research line `govbench-ci-evidence`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-govbench-ci-evidence.md.

### Final Structured Summary

#### Research Line: What CI/CD systems publish machine-checkable evidence of change governance, and what do their artifacts cover?

**Current Lifecycle State:** Contracting

**Repository Structure Analysis:**
- **`/home/bricker/Projects/etc/hngh`**: The kernel repository containing core logic, headers, and build scripts.
- **`hngh-automation`**: The CI/CD and automation layer containing pipeline definitions, scripts for testing, packaging, and deployment, and configuration files for linters, formatters, and security scanners.

**Key Observation:**
For a kernel-level project, "change governance" involves ensuring binary integrity, ABI stability, and security compliance. Machine-checkable evidence must cover:
1. **Source Integrity**: Commit hashes, signed commits.
2. **Build Reproducibility**: Identical inputs produce identical outputs (hashes of binaries).
3. **Security Posture**: Static analysis results, dependency scans.
4. **Test Coverage**: Unit/integration test results mapped to specific code changes.

#### Recommendations for `hngh/hngh-automation`

1. **Publish Signed Build Attestations (SLSA Level 3+):**
   - **Rationale:** For a kernel component, trust is paramount. External CI/CD systems do not natively publish machine-checkable evidence of build provenance in a portable format.
   - **Action:**
     - Integrate `sigstore` into the final packaging step of `hngh-automation`.
     - Generate an attestation file (`bundle.json`) that includes:
       - The exact source commit hash from `/home/bricker/Projects/etc/hngh`.
       - The build environment fingerprint (OS, compiler version).
       - A cryptographic signature over the final binary artifact.
   - **Artifact Coverage:** This covers "who built it," "from which source," and "in what environment." It is machine-checkable via `cosign verify` or `in-toto verify`.

2. **Emit Structured Test Evidence (JUnit + Coverage Mapping):**
   - **Rationale:** Standard CI logs are human-readable, not machine-checkable. To prove that a change in the kernel code was tested, you need structured data linking test cases to source lines.
   - **Action:**
     - Configure the test runner in `hngh-automation` to output **JUnit XML** and **LCOV/HTML coverage reports**.
     - Create a post-processing script in `hngh-automation` that parses these outputs and generates a JSON manifest:
       ```json
       {
         "commit": "<sha>",
         "tests_passed": 142,
         "tests_failed": 0,
         "coverage_delta": "+0.5%",
         "uncovered_lines_in_changed_files": []
       }
       ```
   - **Artifact Coverage:** This covers "did the change break anything?" and "is the new code tested?" It is machine-checkable by a downstream compliance gate that rejects merges if `tests_failed > 0` or `coverage_delta < threshold`.

#### Open Threads

1. **Integration with Existing CI/CD Systems:**
   - How to integrate these attestation and test evidence mechanisms with existing CI/CD systems like GitLab, Jenkins, or GitHub Actions.

2. **Automated Compliance Checks:**
   - Implementing automated compliance checks that verify the attestation and test evidence

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
