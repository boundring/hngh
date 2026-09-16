# Are there any captured build logs from `hngh`'s CI runs available in the repository (e.g., in an `artifacts/` or `logs/` directory) that demonstrate actual recursive make error lines?

Status: crystallized 2026-09-16 from research line `fail-20260916-Are-there-any-captured-build-logs-from-h`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-Are-there-any-captured-build-logs-from-h.md.

# Final Structured Summary — Research Line Contraction

**Line:** Are there any captured build logs from `hngh`'s CI runs available in the repository (e.g., in an `artifacts/` or `logs/` directory) that demonstrate actual recursive make error lines?
**State:** contracting → **contracted (unresolved)**
**Target:** hngh/hngh-automation
**Date:** 2026-09-16

---

## Findings

### F1 — No filesystem verification was performed; the question is unresolved, not answered

The prior beat (2026-09-16) explicitly declined to assert the existence or absence of any CI configuration files, build logs, or artifact directories under `~/Projects/etc/hngh` because no `ls`, `find`, or `git log` command was executed against that path. Per R5 in the prior material, all log-path claims remain **unverified**. The research question therefore does not resolve to "No" (which would require confirming the absence of CI configs) nor to "Yes" (which would require exhibiting a concrete log file containing `make[N]:` with N ≥ 2). It remains **open**.

### F2 — The demonstrable pattern is well-defined but unmet

R3 in the prior material specifies that a single-level make failure (`make: *** [target] Error 1`) does not demonstrate recursion. The minimum evidentiary bar is:

```
make[1]: Entering directory 'subdir'
make[2]: *** [subdir/target.o] Error 1
make[1]: Leaving directory 'subdir'
make: *** [subdir/Makefile:NN: rule] Error 2
```

No such excerpt has been located, generated, or cited in any prior beat. The demonstration gap persists.

### F3 — CI configuration existence is the gating unknown

R1 establishes a binary gate: if none of `.github/workflows/*.yml`, `.gitlab-ci.yml`, or `Jenkinsfile` exist at the root of `~/Projects/etc/hngh`, then no CI runs have occurred and the question resolves to **No** (no captured logs can exist). If any one exists, the line pivots to R2: does that pipeline actually capture make output via `tee`, `actions/upload-artifact`, or a GitLab `artifacts: paths:` block? Neither branch has been evaluated because no filesystem access was exercised.

### F4 — The Crystallized Rebuild Roadmap implies reproducibility as a design goal

`[[sources/SRC-2026-08-18-003]]` (Hngh Crystallized Rebuild Roadmap) frames build reproducibility as a stated objective. If no CI logs are committed or archived, the roadmap's verification step is incomplete. This is a design gap, not merely an evidentiary gap: it means that even if a recursive-make failure were reproduced locally, there would be no canonical artifact path for future beats to cite.

### F5 — SLSA context elevates the logging requirement

`[[sources/SRC-2026-08-24-006]]` (SLSA Supply Chain Levels for Software Artifacts) establishes that build provenance and log retention are supply-chain-relevant controls. The absence of captured CI logs is not a cosmetic omission; it is a gap against the SLSA levels the hngh project has signaled intent to meet. This raises the priority of closing the demonstration gap from "nice-to-have" to "required for roadmap compliance."

---

## Recommendations

### R1 — Execute the gate check (blocking, next beat)

On any host with access to `~/Projects/etc/hngh`, run:

```bash
ls ~/Projects/etc/hngh/.github/workflows/*.yml 2>/dev/null
ls ~/Projects/etc/hngh/.gitlab-ci.yml 2>/dev/null
ls ~/Projects/etc/hngh/Jenkinsfile 2>/dev/null
```

Record the exact output (including "No such file or directory" if applicable) and the `git rev-parse HEAD` of the working tree in the line state. This single step resolves F3 and either closes the line (if all absent → **No**) or opens R2.

### R2 — If CI exists, audit for make-output capture

Inspect the CI config for:
- A `run:` step containing `make ... 2>&1 | tee <logfile>` or an equivalent redirect
- An `actions/upload-artifact@v3` (or later) step with a `path:` pointing at a log file
- A GitLab `artifacts: paths:` block referencing a `.log` or `.txt` file

If none are present, the pipeline does not capture make output regardless of whether an `artifacts/` directory is committed. The recommendation for hngh/hngh-automation is to add an explicit capture step before any artifact upload.

### R3 — Generate one canonical recursive-make error excerpt

If no captured log exists in the repository (or if CI is absent), reproduce a recursive-make failure locally:

```bash
cd ~/Projects/etc/hngh
make -j$(nproc) 2>&1 | tee /tmp/hngh-recursive-make-error.log
```

Verify the output contains `make[2]:` or deeper. Commit a minimal excerpt (≤ 50 lines) to a stable path such as `docs/build-examples/recursive-make-error.txt` (or equivalent, per project convention). This gives future beats a concrete artifact path rather than an ephemeral CI URL. Per R4 in the prior material, use `git add -f` if the path is `.gitignore`-excluded by default.

### R4 — Record the exact path and commit hash in line state

Per R5 in the prior material, any beat that does run on a host with filesystem access must record:
- The exact file path of the log or CI config discovered
- The `git rev-parse HEAD` at the time of observation
- The timestamp of the observation

Until this is done, all log-path claims remain **unverified** and must be marked as such in any downstream citation.

### R5 — Do not assert file paths without verification

This discipline from the prior beat carries forward unchanged. No specific log file path (e.g., `artifacts/build-2026-09-14.log`, `logs/ci-run-001.txt`) may be cited as existing unless it was observed via a filesystem command in a recorded beat. The absence of such paths is equally unverified until the gate check (R1) is executed.

---

## Open Threads

| # | Thread | Status | Blocking condition |
|---|--------|--------|--------------------|
| 1 | Confirm presence/absence of CI config in `~/Projects/etc/hngh` | **Open** | Requires filesystem access or a public repo URL. No prior beat has executed the gate check. |
| 2 | If CI exists, extract one recursive-make error line with depth ≥ 2 | **Open** | Dependent on Thread 1. Cannot be evaluated until CI config existence is confirmed. |
| 3 | Commit a minimal error excerpt as a canonical artifact | **Open** | Dependent on Thread 2 (or local reproduction if CI is absent). No such file has been committed or cited in any prior beat. |
| 4 | Verify whether the Crystallized Rebuild Roadmap's verification step references a specific log path | **Open** | Requires reading `[[sources/SRC-2026-08-18-003]]` in full to determine if it names an artifact path. The prior material only cites it as implying reproducibility; the specific text has not been quoted. |
| 5 | Determine whether SLSA level compliance requires log retention as a hard gate | **Open** | Requires reading `[[sources/SRC-2026-08-24-006]]` in full to identify which SLSA levels mandate build-log retention. The prior material cites it as context but does not quote specific level requirements. |

---

## Disposition

The line is **contracted in an unresolved state**. The research question has not been answered because the gating verification (R1) was never executed. The line carries five open threads into any future re-expansion. The most efficient next beat is a single filesystem check on a host with access to `~/Projects/etc/hngh`, which will either close the line (all CI configs absent → **No**) or pivot to R2/R3 (CI exists → audit for capture, generate excerpt).

The demonstration gap identified in F2 is not merely an evidentiary shortfall; per F4 and F5, it is a design gap against the project's stated reproducibility goal and SLSA alignment. Closing it requires both a local reproduction and a committed artifact path.

---

## References

- `~/Projects/etc/hngh` — hngh kernel repository working tree (path as stated in line definition; existence of specific sub-paths unverified)
- `[[sources/SRC-2026-08-18-003]]` — Hngh Crystallized Rebuild Roadmap (cited in prior material; full text not quoted in this summary)
- `[[sources/SRC-2026-08-24-006]]` — SLSA Supply Chain Levels for Software Artifacts (cited in prior material; full text not quoted in this summary)
- Prior beat 2026-09-16, state expanding → contracting, model unsloth:unsloth/Qwen3.8-27B-GGUF (source of R1–R5 and residual open items table)
