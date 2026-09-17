# Does `docs/build-policy.md 5` contain a clause that automatically ratifies coverage claims in `compliance/SLSA.md` into enforceable bindings upon file publication?

Status: crystallized 2026-09-17 from research line `fail-20260917-Does-docs-build-policy-md-5-contain-a-cl`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260917-Does-docs-build-policy-md-5-contain-a-cl.md.

# Crystallized Research Line — Final Structured Summary

**Line:** Does `docs/build-policy.md 5` contain a clause that automatically ratifies coverage claims in `compliance/SLSA.md` into enforceable bindings upon file publication?

**Lifecycle:** contracting → **crystallized** (this summary is the line's lasting record; the line remains live for re-verification the moment filesystem access returns — it is not closed, only settled into a durable form).

---

## Findings

**F1 — No standard mechanism performs "automatic ratification upon file publication."**
In standard build and CI practice, a Markdown document does not self-execute. Publishing (committing) a `.md` file does not parse its prose and convert it into an enforceable policy binding. Enforcement lives in *executable* artifacts: a CI workflow triggered on a path, a build-script hook that parses the doc, or dedicated tooling. This is general tooling behavior; I am stating it as reasoning, **not** as a verified fact about this repository.

**F2 — SLSA levels are not enforced by document publication.**
SLSA (Supply-chain Levels for Software Artifacts) compliance is verified through *provenance attestations* (in-toto) and tooling such as `slsa-github`, which checks a build's provenance against a level. A Markdown file asserting coverage or SLSA level does not, by being published, create an enforceable binding. This is external/general knowledge; I **cannot verify** that this repository actually uses `slsa-github`/in-toto — treat as unconfirmed here.

**F3 — Verification gap (the dominant fact).**
This beat had no filesystem access, and the prior beat's paths are redacted in the supplied material. I therefore **cannot confirm the existence or content** of `docs/build-policy.md` (nor its "5" section/line) or `compliance/SLSA.md` in either repository. The line is still gated on the prior beat's R1. I am deliberately *not* asserting that these files exist, that they contain a ratification clause, or that they do not — none of that is grounded here.

**F4 — "5" is ambiguous.**
`docs/build-policy.md 5` most plausibly means *section 5* or *line 5* of `docs/build-policy.md`, but it could denote a version. This must be disambiguated before any content can be assessed. I will not guess at the clause's text.

## Provisional answer to the line

**Conditionally NO, pending R1.** On conceptual grounds (F1, F2), there is no mechanism by which a Markdown clause auto-ratifies claims into enforceable bindings upon publication — so the described behavior does not exist in standard tooling. But this is **not yet a verified repository finding**, because file existence and content are unconfirmed. If either file is absent, the line closes as **moot** (no clause can ratify claims from a non-existent document). If both exist but no executable mechanism references them, the answer is a firm **no**: at most a descriptive policy statement.

## Recommendations

- **R1 — Gate on file existence (blocking).** Resolve in both repositories:
  `test -f <repo>/docs/build-policy.md` and `test -f <repo>/compliance/SLSA.md`.
  Absent → close moot. Present → proceed to R2. (Highest-leverage check; the prior beat's entire hypothetical apparatus collapses if the files are not there.)
- **R2 — Locate the enforcement mechanism, not the document.** If both exist, search for an *executable* trigger: a CI workflow on these paths (`.github/workflows/` or equivalent), a build-script hook (`Makefile`, `build.sh`, `CMakeLists.txt`, kernel build entry points under `[redacted path] or SLSA tooling (`slsa-github`, in-toto attestation generation, `_provenance` manifests). Concrete sequence:
  1. `grep -r "build-policy" <repo> --include="*.yml" --include="*.yaml" --include="Makefile" --include="*.sh"`
  2. `grep -r "SLSA\|slsa" <repo> --include="*.yml" --include="*.yaml" --include="Makefile" --include="*.sh" --include="*.md"`
  3. `grep -rn "ratif\|binding\|enforce" <repo>/docs/build-policy.md` (if it exists) — enforcement language vs. descriptive.
  If none surface a mechanism → answer **no**.
- **R3 — Reclassify claims if no mechanism exists.** The coverage claims in `compliance/SLSA.md` are *assertions, not bindings*; they do not become enforceable on publication. Any downstream consumer that must treat SLSA level as a hard gate must implement its own verification (e.g., run `slsa-github` against build provenance), independent of the Markdown.
- **R4 — Disambiguate "5."** Confirm whether it is section, line, or version before content assessment.
- **R5 — Do not design document publication as a policy trigger.** If `hngh/hngh-automation` is expected to enforce SLSA levels, wire an explicit attestation-check step into the pipeline rather than relying on file publication as a trigger.

## Open threads

1. **File existence (R1)** — unresolved; blocks everything else.
2. **"5" ambiguity** — section / line / version.
3. **Meaning of "coverage claims"** — test coverage vs. SLSA-level coverage; the phrase is unverified against any file.
4. **CI references** — whether any workflow in either repo references these documents (unverified).
5. **External tooling behavior** — exact `slsa-github`/in-toto semantics are general knowledge, not verified against this repository.

## References

- `[redacted path] — designated hngh kernel repository root (named in the task; **contents unverified this beat**).
- `research-lines.tsv` — line state file for this continuous process (referenced by the task; content beyond the supplied prior material unverified).
- Prior material: research beat 2026-09-17, state expanding → contracting (supplied inline above; its filesystem claims are redacted/unverified).
- Vault pointers (read-only, **not opened this beat**): `[[sources/SRC-2026-08-18-003]]` Hngh Crystallized Rebuild Roadmap; `[[sources/LES-fail-20260915-Does-the-obs-2026-0

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
