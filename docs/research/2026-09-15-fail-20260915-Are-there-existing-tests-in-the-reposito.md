# Are there existing tests in the repository that assert on the distinction between clean-complete and timeout-complete states, or is this gap untested?

Status: crystallized 2026-09-15 from research line `fail-20260915-Are-there-existing-tests-in-the-reposito`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-Are-there-existing-tests-in-the-reposito.md.

# Contraction: clean-complete vs. timeout-complete test coverage in hngh

## Findings

**The gap is empirically unverified, not confirmed.** The expanding beat recorded intent (two shell commands against `~/Projects/etc/hngh`) but preserved no output: no file listing, no grep result, no test-tree enumeration. No state-machine definition, sentinel value, exit-code contract, or status-file schema has been located. Consequently:

- **No test asserting the clean-complete / timeout-complete distinction has been identified.** This is an absence of evidence, not evidence of absence. The line's motivating question — "is this gap untested?" — remains open.
- **No file paths inside the repository are cited in this record.** I am not confident any specific path exists beyond the repository root itself. Any stronger claim would conflate studied intent with verified fact, violating the authored-vs-studied discipline that governs this line.
- The distinction *must* be named somewhere in the kernel — an enum member, a sentinel string, an exit code, or a status-file value — before any test can assert on it. That naming site has not been located.

**What is known from prior art (vault pointers, read-only):**

- The project already reasons in terms of promotion rungs and attestation (`[[sources/obs-2026-08-25-hngh-promotion-rung-11-distributed-attestation-completed-pus]]`). A timeout-complete state is semantically a *failed or incomplete* rung, not a successful one; conflating the two in test assertions would mask a real regression.
- An env-overridable binary seam for hermetic subprocess tests is documented (`[[sources/subprocess-stub-seam-for-hermetic-tests]]`). This is the correct leverage point for testing timeout behavior without wall-clock sleeps.

## Recommendations

**1. Execute the three-search protocol and record raw output.**

Run against `~/Projects/etc/hngh`, in this order:

```bash
# (a) Locate state definitions — the distinction must be named before it can be tested
grep -rn -E "clean.?complete|timeout.?complete|TIMEOUT_COMPLETE|CLEAN_COMPLETE|CleanComplete|TimeoutComplete" \
  --include='*.py' --include='*.sh' --include='*.ts' --include='*.go' --include='*.rs' .

# (b) Locate the test tree
find . -type d \( -name 'test*' -o -name '*_tests' -o -name 'spec*' \) -not -path '*/.git/*' -not -path '*/node_modules/*'
find . -type f \( -name 'test_*' -o -name '*_test.*' -o -name 'test.*' -o -name 'conftest.*' \) -not -path '*/.git/*'

# (c) Cross-reference: for each state-name hit from (a), check whether it appears under a path from (b).
#     A definition-site hit with zero test-site hits is the signature of the untested gap.
```

Adjust `--include` extensions to whatever `ls ~/Projects/etc/hngh` reveals on first contact. Record raw output verbatim in the next beat; do not paraphrase.

**2. Classify into exactly one verdict and contract accordingly.**

| Verdict | Condition | Action |
|---|---|---|
| **(a) Distinction tested** | A test file asserts both arms (clean-complete *and* timeout-complete) on an observable terminal contract | Close the line: "covered." Cite the test file and asserting lines. |
| **(b) Partially tested** | One arm is asserted, the other only implicitly exercised (e.g., timeout path tested, clean path assumed) | Restate the line around the missing arm; the gap is real but narrower than originally framed. |
| **(c) Untested** | Neither arm appears under any test path | Proceed to recommendation 3. The gap is confirmed. |

Do not let the line linger in expanding past these three searches. The verdict is cheap to obtain; one beat has already been spent without producing it.

**3. If (c), write the test at the subprocess seam, not against wall-clock time.**

- **Timeout-complete test:** stub the subprocess via the env-overridable binary seam so it never returns (or returns only after a fake clock advances). Assert on the *observable terminal contract* — exit code, status-file contents, or emitted log/status line — whichever the kernel actually produces.
- **Clean-complete test:** stub an immediate success exit. Assert the same observable contract under the clean path.
- **Never** assert timeout behavior by sleeping real seconds in CI. That is flaky by construction and couples test duration to host load.

**4. For hngh-automation: treat the distinction as a promotion-gate contract.**

Given the project's existing rung/attestation model, a timeout-complete state must be treated as a *failed or incomplete* rung in any attestation chain. A test that treats both states as equivalent (e.g., asserting only "process exited" without distinguishing *how*) would pass while masking a real regression. The test must assert the distinction explicitly.

## Open threads

1. **The three searches have not been run.** Every finding above is bounded by this absence. The line cannot contract to a verdict until raw output exists in the record.
2. **The naming convention for the two states is unknown.** The grep pattern in recommendation 1(a) is a best-guess based on common conventions. If the kernel uses an entirely different vocabulary (e.g., `DONE` vs. `EXPIRED`, or numeric status codes), the search will miss and the verdict will be falsely (c). First contact with the repository will resolve this.
3. **The observable terminal contract is unspecified.** Whether the kernel signals completion via exit code, a status file on disk, a log line, or an IPC message has not been determined. The test in recommendation 3 cannot be written until this is known.
4. **Vault pointer contents are unverified beyond their titles.** The promotion-rung observation and the subprocess-seam note are cited as directional prior art. Their full text may contain constraints (e.g., which seam variables are overridable, which rungs gate on which states) that would sharpen recommendations 3 and 4. Reading them in full is a prerequisite to writing the test, not an optional enrichment.

## References

- `~/Projects/etc/hngh` — repository root (guaranteed by line definition; no internal paths verified)
- `[[sources/obs-2026-08-25-hngh-promotion-rung-11-distributed-attestation-completed-pus]]` — promotion-rung / attestation model (vault pointer; full contents not read in this beat)
- `[[sources/subprocess-stub-seam-for-hermetic-tests]]` — env-overridable binary seam for hermetic subprocess tests (vault pointer; full contents not read in this beat)
- `[[sources/obs-2026-08-19-authored-vs-studied-project-distinction]]` — authored-vs-studied discipline governing what may be claimed as verified (vault pointer)
