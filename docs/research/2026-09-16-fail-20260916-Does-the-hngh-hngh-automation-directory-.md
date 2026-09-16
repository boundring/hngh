# Does the `hngh/hngh-automation` directory exist in the kernel repository, and if so, does it contain a pre-defined capture recipe for R1?

Status: crystallized 2026-09-16 from research line `fail-20260916-Does-the-hngh-hngh-automation-directory-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-Does-the-hngh-hngh-automation-directory-.md.

# Final Structured Summary — `hngh/hngh-automation` Existence & R1 Capture Recipe

**Line:** Does the `hngh/hngh-automation` directory exist in the kernel repository, and if so, does it contain a pre-defined capture recipe for R1?
**State:** contracting (final record)
**Target repo:** `/home/bricker/Projects/etc/hngh`

---

## Findings

### 1. The binary existence question remains unresolved

No prior beat on this line has recorded the output of a direct filesystem probe against `/home/bricker/Projects/etc/hngh/hngh-automation`. The expanding beat produced only hedged language ("highly probable," "likely contains," "may be a subdirectory") without executing `test -d` or `ls` on the path. I cannot verify from this position whether the directory exists; I have no filesystem access and the prior material does not contain a recorded result of such a probe.

### 2. The R1 capture recipe question is subordinate to (1)

The second half of the line — "does it contain a pre-defined capture recipe for R1?" — cannot be answered until (1) is resolved. No file path, directory listing, or recipe content has been recorded in any prior beat. The three LES-fail entries dated 2026-09-15 confirm that attempts to resolve this question failed without producing a concrete artifact.

### 3. One positive observation exists but is untraced

The observation `obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` is the sole piece of evidence cited in favour of existence. However, no prior beat has opened this observation to extract:
- The exact build command or script that produced the "overnight harness."
- The verification step that marked it "enabled."
- Any file paths, commit hashes, or log lines recorded at build time.

Without that trace, the observation is a pointer, not a proof. It may refer to a component that was never committed, was subsequently removed, or lives under a different path (e.g., `/home/bricker/Projects/etc/hngh/scripts/hngh-automation`, an out-of-tree location, or a transient build artifact). I cannot verify which of these is the case without filesystem access.

### 4. The line has been in a resolution loop

Three LES-fail entries from 2026-09-15 (`Does-the-obs-...`, `What-are-the-exact-file-paths-for-the-ca...`, `Has-R1-systemctl-status-list-timers-jour`) show the question was attempted and failed at least three times in a single day. Each expansion re-derived the same uncertainty rather than closing it. The prior material correctly diagnoses this as an **execution gap**, not a knowledge gap: no one has run the command and written down the result.

### 5. No concrete file paths can be cited with confidence

I cannot cite any file path under `/home/bricker/Projects/etc/hngh/hngh-automation` because I have not verified its existence or contents. Any such citation would be speculative. The entity `[[entities/hngh]]` ("Hngh Agent Kernel") confirms the repository is a known project in the vault, but does not enumerate its directory tree.

---

## Recommendations

### A. Execute the binary probe (closes or advances the line)

On any idle host with access to `/home/bricker/Projects/etc/hngh`:

```bash
test -d /home/bricker/Projects/etc/hngh/hngh-automation && echo "EXISTS" || echo "ABSENT"
```

- **If ABSENT:** The line closes. Record the result. The observation `obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` refers to a component that was either never committed, was removed, or lives under a different path. Update the observation's metadata to note the discrepancy.
- **If EXISTS:** Proceed to recommendation B.

### B. Enumerate and search for R1-specific artifacts

```bash
find /home/bricker/Projects/etc/hngh/hngh-automation -type f -o -type l | sort
grep -rn "R1" /home/bricker/Projects/etc/hngh/hngh-automation/ 2>/dev/null
grep -rn "capture" /home/bricker/Projects/etc/hngh/hngh-automation/ 2>/dev/null
```

Look specifically for:
- Files named `r1_capture*`, `capture_r1*`, `recipe_r1*`, or any file whose name contains both an R1 token and a capture/recipe token.
- A manifest, YAML/TOML/JSON config, or shell script that defines what to capture (logs, coredumps, journal entries, timer states) when R1 is triggered.
- Cross-references from the overnight harness entrypoint into this directory.

**If no R1-specific file exists but generic capture infrastructure does:** Record "the directory exists but contains no pre-defined R1 recipe." The line's action item becomes "write the R1 recipe," which is a new, separate line.

### C. Trace the observation to its concrete artifact

Open `[[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]` in the vault and extract:
- The exact build command or script that produced the "overnight harness."
- The verification step that marked it "enabled."
- Any file paths, commit hashes, or log lines recorded at build time.

If the observation was generated by an agent run, check whether the agent's working directory matches `/home/bricker/Projects/etc/hngh` and whether the build log references `hngh-automation` as a path or a logical name.

### D. Do not speculate about "standard kernel repository structures"

The prior material's guess that `hngh-automation` "may be a subdirectory of `scripts/`, `tests/`, or `automation/`" is unfalsifiable and unproductive. One `test -d` call ends the question. If the directory is absent at the canonical path, search for it:

```bash
find /home/bricker/Projects/etc/hngh -type d -name "*hngh-automation*" 2>/dev/null
```

This locates the actual path (if any) without assuming a layout.

---

## Open Threads

| Thread | Status | Blocking condition |
|--------|--------|--------------------|
| Binary existence of `/home/bricker/Projects/etc/hngh/hngh-automation` | **Unresolved** | Requires filesystem access on an idle host; no prior beat has recorded a probe result. |
| R1 capture recipe presence (if directory exists) | **Blocked on existence** | Cannot be answered until the directory's contents are enumerated. |
| Provenance of `obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` | **Untraced** | The observation has not been opened to extract build commands, verification steps, or file paths. |
| Whether the "overnight harness" is a committed artifact or a transient build product | **Unknown** | Requires git history inspection (`git log --all --oneline -- '*hngh-automation*'`) if the directory exists, or observation metadata if it does not. |

---

## References

All references are vault pointers from the prior material on this line. I have not independently verified their contents beyond what the prior beat recorded.

- `[[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]` — Observation: sole positive evidence cited for existence of `hngh-automation`. Not yet traced to a concrete artifact.
- `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — Research Lesson: failed attempt to resolve the existence question (2026-09-15).
- `[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]` — Research Lesson: failed attempt to enumerate file paths for capture artifacts (2026-09-15).
- `[[sources/LES-fail-20260915-Has-R1-systemctl-status-list-timers-jour]]` — Research Lesson: failed attempt related to R1 timer/journal state (2026-09-15).
- `[[sources/LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho]]` — Research Lesson: related R1 confirmation failure (2026-09-15); included in prior art but not directly on this line.
- `[[entities/hngh]]` — Entity: "Hngh Agent Kernel." Confirms the repository is a known project; does not enumerate directory structure.
- `/home/bricker/Projects/etc/hngh` — Target repository path. Cited in the line definition and prior material. I cannot verify its current state from this position.

**Explicit non-verification:** I have not run any command against `/home/bricker/Projects/etc/hngh`. I have not read any file within that repository. All claims about the directory's existence, contents, or absence are conditional on a probe that has not yet been executed and recorded. No claim in this summary asserts filesystem state as fact; all such statements are framed as "requires verification" or "unresolved."
