# What is the absolute path of the overnight harness entry-point script (e.g., `run.sh`) in the `hngh-automation` checkout, and can it be cited as the canonical source for R1 verification?

Status: crystallized 2026-09-18 from research line `fail-20260917-What-is-the-absolute-path-of-the-overnig`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260917-What-is-the-absolute-path-of-the-overnig.md.

# Research Line — Contracted Summary

**Line:** What is the absolute path of the overnight harness entry-point script (e.g., `run.sh`) in the `hngh-automation` checkout, and can it be cited as the canonical source for R1 verification?

**State:** contracting → final record

---

## Findings

1. **The `hngh-automation` checkout root is unresolved.** Every prior reference to its path in the supplied material is redacted or truncated. No concrete absolute path (e.g., `[redacted path] or any other form) has been observed. The kernel repository root, `[redacted path] is established by the research-line framing, but the automation checkout's location relative to it is unconfirmed.

2. **No entry-point script has been verified at a concrete path.** Conventional guesses (`run.sh`, `overnight.sh`) appear in prior material as hypotheses, not observations. No file listing, directory walk, or documentation excerpt in the supplied material names an actual script at an absolute path inside the `hngh-automation` tree.

3. **"R1" has no verified local definition.** Neither the supplied material nor any cited repository-local document observed here defines what "R1 verification" means as a check, gate, or artifact. Without that mapping, no script can be cited as canonical *for R1* specifically; it could at most be cited as an entry point for whatever harness it actually drives.

4. **Prior attempts to resolve this line failed.** The vault entries `LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-` and `LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca` record earlier failures on closely scoped questions (whether the 2026-08-25 observation is sufficient; what the exact file paths are). The current state is consistent with those failures: the question remains open.

5. **The prior beat was truncated.** The expanding-state completion hit the `max_tokens` cap (`finish_reason=length`) before finishing its recommendation list. This contracted summary supersedes and completes that record.

---

## Recommendations

1. **Do not cite a guessed path as canonical.** Until a file is observed at a concrete absolute path inside the `hngh-automation` checkout, any reference to `run.sh`, `overnight.sh`, or similar is a hypothesis, not a citation.

2. **Resolve the checkout root on the host.** Inspect the filesystem (e.g., `ls [redacted path] or version-control remotes to locate the `hngh-automation` tree. Record:
   - The absolute path of the checkout root.
   - Its revision, commit hash, or working-tree state if version-controlled.
   - Whether it is a sibling of `[redacted path] a subdirectory, or elsewhere.

3. **Apply an evidence checklist before citing any script as canonical for R1.** A candidate must satisfy *all* of:
   - The file exists at a concrete absolute path (verified by `test -f` or equivalent).
   - It is executable (`-x`) or explicitly invoked through an interpreter (`bash`, `python`, etc.).
   - It is referenced by harness documentation, a Makefile target, CI configuration, scheduler entry, service unit, or harness manifest.
   - It invokes checks against the hngh kernel tree at `[redacted path] (or a pinned checkout of it).
   - It produces or gates an R1 result artifact, log, status file, or explicit pass/fail output.

4. **If no single script is the entry point, cite the actual orchestrator.** Acceptable alternatives:
   - A Makefile target (e.g., `make overnight` in a named `Makefile`).
   - A CI workflow or job definition (e.g., `.github/workflows/overnight.yml`).
   - A scheduler or service unit file (e.g., a cron entry, systemd unit).
   - A harness manifest that names the real command line.
   
   Do not substitute a guessed `run.sh` when the real orchestrator is different.

5. **Do not assert an external definition of R1.** If the repositories do not define "R1" locally, say so explicitly. The citation must name the exact check or artifact that constitutes R1 verification; if no such mapping exists in the supplied material, state that the label is undefined in-repo and the question cannot be answered as posed.

6. **Citation format (once verified):**
   > `<absolute path to entry point>` in `hngh-automation` at revision `<revision>`, invoked as `<command>`, against `[redacted path] at revision `<revision>`.
   
   Fill every placeholder from observed evidence; do not leave them as placeholders in a final citation.

---

## Open Threads

| # | Thread | Status |
|---|--------|--------|
| 1 | Absolute path of the `hngh-automation` checkout root | Unresolved — requires host inspection |
| 2 | Identity and path of the overnight harness entry-point script | Unresolved — no file observed |
| 3 | Repository-local definition of "R1" (or confirmation of its absence) | Unresolved — not found in supplied material |
| 4 | Whether `hngh-automation` is version-controlled and at what revision | Unknown |
| 5 | Whether the entry point targets `[redacted path] directly or a pinned copy | Unknown |

---

## References

The following are named because they are the only sources available to this line. No file *within* `[redacted path] or within the `hngh-automation` tree has been verified from the supplied material; those paths are cited as reference points, not as evidence of specific files.

- `[redacted path] — hngh kernel repository root, stated in the research-line framing. No internal file paths are asserted here.
- `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — prior failed lesson on whether the 2026-08-25 observation suffices.
- `[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]` — prior failed lesson on exact file paths for the automation checkout.
- `[[concepts/agent-harness-governance]]` — Agent-Harness Governance Positioning (created 2026-08-24).
- `[[sources/SRC-2026-08-24-030]]` — Case Study: Overnight Multi-Agent Sprint (2026-08-24).
- `[[concepts/contributor-points]]` — Contribution Points (MisakaNet) (created 2026-08-24).
- `[[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]` — Observation: overnight harness built, verified, enabled.

**External sources:** None cited. The definition of "R1" and the identity of the entry-point script are not verifiable from any external source available in this material. If they exist in documentation outside the two repositories named above, that fact has not been established here.
