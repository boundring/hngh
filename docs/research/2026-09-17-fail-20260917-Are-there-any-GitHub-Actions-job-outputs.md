# Are there any GitHub Actions job outputs in `hngh-automation` named `slsa_level` or similar aliases that are consumed by subsequent jobs' `if:` conditions to control artifact retention?

Status: crystallized 2026-09-17 from research line `fail-20260917-Are-there-any-GitHub-Actions-job-outputs`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260917-Are-there-any-GitHub-Actions-job-outputs.md.

## Contracted research record

**Line:** Are there any GitHub Actions job outputs in `hngh-automation` named `slsa_level` or similar aliases that are consumed by subsequent jobs’ `if:` conditions to control artifact retention?  
**State:** contracting → crystallized as the line’s lasting record.  
**Evidence limit:** No verified workflow-file contents from `hngh-automation` or the `hngh` kernel repository are available in this record. Therefore no concrete workflow file paths can be cited with confidence.

---

## Findings

1. **No confirmed `slsa_level` job output is evidenced.**  
   The available line material does not establish that any GitHub Actions job in `hngh-automation` declares an output named `slsa_level`.

2. **No confirmed alias is evidenced as a retention-control output.**  
   No verified evidence was found for similar aliases such as `supply_chain_level`, `attestation_level`, `verification_level`, or comparable names being used as GitHub Actions job outputs.

3. **No confirmed downstream `if:` consumption is evidenced.**  
   No verified evidence was found showing that a later job’s `if:` condition consumes an output named `slsa_level` or a similar alias.

4. **The proposed mechanism would require explicit workflow wiring.**  
   For the line’s premise to be true, a workflow definition would need to show at least:
   - a job declaring an output such as `slsa_level`, and
   - a later job or step using something like `if: ${{ needs.<job>.outputs.slsa_level == ... }}`  
     to gate artifact retention behavior.  
   No such file-level evidence is available in this record.

5. **SLSA terminology cannot be externally verified here.**  
   The term “SLSA level” may relate to supply-chain assurance levels, but I cannot verify external SLSA documentation from the required repositories in this context. That claim is therefore left unasserted beyond noting the naming plausibility.

---

## Recommendations

1. **Treat the line as unconfirmed rather than affirmatively true.**  
   Do not assume that artifact retention in `hngh-automation` is controlled by a `slsa_level` job output unless a workflow file explicitly demonstrates that wiring.

2. **If retention policy must be auditable, make it explicit.**  
   If the intended design is for SLSA-like levels to control artifact retention, the workflow should name the output clearly and show the consuming `if:` condition in the same repository’s workflow definitions.

3. **For future verification, inspect the actual workflow definitions.**  
   The decisive evidence would be found in the repository’s GitHub Actions workflow files, not in external documentation alone. Look for:
   - `outputs.slsa_level` or similar aliases,
   - downstream `if:` conditions referencing those outputs,
   - artifact deletion, retention, or lifecycle actions gated by those conditions.

4. **If no such wiring exists, close the operational assumption.**  
   If direct inspection finds no `slsa_level`-style output controlling retention, then artifact retention should be understood as governed by default GitHub Actions retention behavior, environment policy, external tooling, or another mechanism—not by SLSA-level job outputs.

---

## Open threads

1. **Direct workflow-file inspection remains necessary.**  
   This record cannot convert “no evidence available” into “verified absence.” A direct inspection of `hngh-automation`’s workflow definitions is still required to close the question definitively.

2. **The `hngh` kernel repository may contain reusable workflow material.**  
   It is possible that reusable workflows, composite actions, or job templates in the `hngh` kernel repository set SLSA-like outputs consumed by `hngh-automation`. No such evidence is available here.

3. **Artifact retention may be controlled outside GitHub Actions.**  
   The line does not resolve whether retention is instead controlled by storage lifecycle rules, external policy, CI environment configuration, or another system outside the workflow files.

---

## References

- `hngh-automation` repository: named in the research line; no verified workflow file contents are cited here.
- `hngh` kernel repository at `[redacted path] named as the local kernel repository root; no verified workflow file contents are cited here.
