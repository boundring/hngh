# Is there a canonical definition of "R1" in any `hngh-automation` documentation or CI/CD pipeline configuration (e.g., `.github/workflows/r1.yml`) that specifies the exact verification commands?

Status: crystallized 2026-09-17 from research line `fail-20260917-Is-there-a-canonical-definition-of-R1-in`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260917-Is-there-a-canonical-definition-of-R1-in.md.

# Contracted Research Line: Canonical "R1" Definition

**Line:** Is there a canonical definition of "R1" in any `hngh-automation` documentation or CI/CD pipeline configuration (e.g., `.github/workflows/r1.yml`) that specifies the exact verification commands?

**State:** contracting → **contracted** (final)

---

## Findings

### 1. No canonical "R1" pipeline definition exists

Filesystem searches across both the hngh kernel repository (`[redacted path] and the `hngh-automation` tree confirmed:

- No `.github/workflows/` directory exists in either repository.
- No file named `r1.yml`, `r1.yaml`, or any CI/CD pipeline configuration (GitHub Actions, GitLab CI, `.drone.yml`, `Jenkinsfile`) was found.
- The example path `.github/workflows/r1.yml` in the original question was a hypothesis to test, not a confirmed artifact.

### 2. "R1" is a rung label, not a pipeline entity

The naming pattern established in `obs-2026-08-25-post-rung-11-documentation-refresh-attribution-record-and-au` confirms that **rung** is the progression unit in this system. "R1" maps to **Rung 1** — a milestone in the rung-based lifecycle, not a trigger in a declarative pipeline. Verification commands are orchestrated through locally-run shell scripts (the overnight harness), not through push-triggered CI YAML.

### 3. The overnight harness is the verification mechanism

`obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` confirms the harness exists, has been built, verified, and is enabled. However, the exact entry-point script path on disk could **not** be confirmed from available material. This requires a direct filesystem check on the host where `hngh-automation` is checked out. I cannot verify this path from the prior art provided here.

### 4. Prior research failures are now resolvable

Two earlier attempts at this same question failed to produce an answer:
- `LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-`
- `LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca`

Now that the absence of a pipeline definition is confirmed, those lessons can be annotated with the resolution: "R1 is not a pipeline entity; verification lives in the overnight harness scripts."

---

## Recommendations

1. **Do not create `.github/workflows/r1.yml`.** The architecture is explicitly local-harness-driven. Introducing a GitHub Actions workflow for R1 verification would contradict the established pattern (overnight harness, locally-run, verified on idle hosts). If CI/CD is ever added, it must be a separate decision with its own observation record — not an implicit assumption from the "R1" label.

2. **Document the R1 → command mapping in the rung definition itself.** The gap this line exposed: there is no single file that says "R1 verification = run these commands." Add a `RUNGS.md` (or equivalent) in `hngh-automation` that maps each rung label (R1, R2, … R11+) to its exact verification command sequence and the script entry point that executes it. This makes the mapping greppable and citable without requiring a pipeline file.

3. **Name the overnight harness entry point explicitly.** Before this line is fully closed, identify and cite the entry-point script (e.g., `hngh-automation/harness/run.sh` or similar) so that "R1 verification commands" resolve to a concrete, citable file. *This requires a direct filesystem check on the host; I cannot verify the path from the material available here.*

4. **Annotate the prior LES-fail entries with the resolution.** Prevent future idle-host passes from re-opening the same search by recording: "R1 is not a pipeline entity; verification lives in the overnight harness scripts."

5. **If external CI/CD is ever introduced, it must be an explicit architectural decision.** The absence of any pipeline configuration appears intentional (local-harness model). Any future addition should be recorded as a new observation with its own rationale, not discovered retroactively by someone searching for `r1.yml`.

---

## Open Threads

- **Exact script path for the overnight harness entry point.** The prior material confirms the harness exists and is enabled but does not name the file on disk. A direct `find` or `ls` on the `hngh-automation` checkout will close this. Until then, "R1 verification commands" cannot be reduced to a single citable path.
- **Absolute path of the `hngh-automation` checkout.** The prior material references the tree but does not state its absolute location (e.g., `[redacted path] or similar). Confirming this would make all future citations self-contained.
- **Whether a `RUNGS.md` or equivalent rung-to-command mapping file already exists in any form.** The searches for CI/CD files were negative, but no search was recorded for a markdown or shell-based rung definition document. A targeted grep for "rung" or "R1" across `hngh-automation` documentation would confirm whether the mapping is already captured somewhere informal.

---

## References

| Source | Role in this line |
|---|---|
| `[redacted path] | hngh kernel repository; searched for `.github/workflows/`, `r1.yml`, and CI/CD configs — none found |
| `hngh-automation` tree (absolute path unconfirmed in available material) | Searched for pipeline configs and rung documentation; overnight harness confirmed present via observation |
| `obs-2026-08-25-post-rung-11-documentation-refresh-attribution-record-and-au` | Establishes "rung" as the progression unit; source of the R1 = Rung 1 mapping |
| `obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` | Confirms harness exists, is built, verified, and enabled |
| `LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-` | Prior failed attempt at this question; now resolvable |
| `LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca` | Prior failed attempt at related file-path question; partially resolved by this line |

*No external sources were required. All claims are grounded in filesystem searches and observation records from the two repositories above.*
