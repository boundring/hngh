# Why did plan acceptance fail with kernel make test rc=2 (x3) for identity overnight:plan-accept-gate:kernel, and is the blocker still open or already resolved?

Status: crystallized 2026-10-08 from research line `fail-20260916-overnight-plan-accept-gate-kernel`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-overnight-plan-accept-gate-kernel.md.

# Crystallization: plan-accept-gate:kernel rc=2 (×3) — lasting record

_line: Why did plan acceptance fail with kernel make test rc=2 (x3) for identity overnight:plan-accept-gate:kernel, and is the blocker still open or already resolved? | state: contracting → contracted (crystallized)_

## Resolution status headline

**The original question is NOT answered by this line, and this record says so plainly rather than papering over it.** Neither the expansion beat nor this contraction produced captured test output, a re-run, or a fix reference. The line's value is therefore: (a) a correct reading of the little evidence that exists, (b) a diagnosis of why the line stalled, and (c) a minimal, ordered path to closure. Any future claim that this blocker is "resolved" requires the R1 experiment below; anything else is assertion without evidence.

## Findings

**F1 — rc=2 from GNU make is a recipe failure, not a usage error.**
GNU make's exit-code convention: 0 = success, 1 = rebuild needed (query mode), 2 = a recipe/target failed. So "kernel `make test` rc=2" means some target reachable from `test` in the kernel build failed during acceptance runs for identity `overnight:plan-accept-gate:kernel`. Exit codes carry no information about *which* target or *which* test — the diagnostic was discarded at the gate.

**F2 — Three identical failures (rc=2 ×3) is a deterministic-signature pattern, not a flake.**
Flaky failures interleave passes. 3/3 identical failures at the same gate indicates one of: (a) a deterministically broken test, (b) a deterministic environment defect on the host (missing tool/dependency, stale artifact, dirty worktree), or (c) gate misconfiguration. These have opposite remediations — only the captured output distinguishes them, and none was captured.

**F3 — "Open or resolved?" is undetermined, and must not be inferred.**
No re-run, fix commit, skip annotation, or line-state transition evidencing closure appears in the prior material. The line was in `expanding` state in `research-lines.tsv`, which records intent to investigate, not resolution. Absence of evidence is not evidence of either state.

**F4 — Meta-finding: this line failed to expand because the evidence was never captured upstream.**
The 2026-10-08 beat recorded only orientation and prior-art pointers before ending (wall_s: 3.0). The gate itself logs only `rc=2`. The line is a victim of R2's absence: with no persisted output, every investigation of this failure class starts from zero. This crystallization treats that as a first-class finding about the automation, not just about the kernel.

**F5 — Verification status of repository claims.**
In this contraction I could not execute shell commands or read files; therefore I assert existence only of: `research-lines.tsv` (cited in the line state), and the hngh kernel repository at `[redacted path] (given in the task). That a `Makefile` with a `test` target exists under that repository is *strongly implied* by "kernel make test" but is **unverified** — the target could live in a subdirectory makefile or an included fragment. All claims about where the gate logic lives are unverified (see OT-2).

## Recommendations (ordered by leverage)

**R1 — Reproduce before theorizing (closes the question in one command).**
In `[redacted path] run `make -n test` to enumerate what the target executes, then `make test` and capture full output. Pass ⇒ blocker resolved or environment-dependent; fail ⇒ the output answers the "why" that rc=2 never could. This should be the entire scope of the next beat on this line or its successor.

**R2 — Persist test output at the acceptance gate.**
The gate behind `overnight:plan-accept-gate:kernel` should tee full stdout/stderr of `make test` to a timestamped artifact keyed by the identity, and store that artifact path in the failure record. Without this, every recurrence hits this line's dead end.

**R3 — Add coarse failure classification at the gate.**
Classify captured output into at least: compile error / test assertion / missing dependency / timeout. Even grep-based classification converts "rc=2 (×3)" from an opaque count into a triage decision (deterministic code failure → block plan; environment defect → alert on host).

**R4 — Treat 3/3 identical failures as a halt condition, not a retry condition.**
Identical-rc retries buy nothing on a deterministic failure; the gate should halt and surface the captured artifact rather than re-run. (The prior beat's truncation cut this off mid-sentence; its intent is preserved here.)

**R5 — Close the loop on this line explicitly.**
After R1, record the outcome in `research-lines.tsv` (state → resolved, with a one-line cause) or spawn a successor line naming the specific failing target. Do not leave this line in an ambiguous state again.

## Open threads

- **OT-1 (blocking):** Result of R1 — does `make test` in `[redacted path] currently pass or fail, and with what output? This alone resolves the original question.
- **OT-2:** Location of the acceptance-gate implementation (expected somewhere in the hngh-automation tooling) — unverified; locating it is prerequisite to R2–R4.
- **OT-3:** Whether the three failures shared a host and worktree state (would discriminate F2's hypotheses b/c from a) — requires gate logs that may not exist (see F4).
- **OT-4:** Whether `make test` exists at the kernel repo root or is dispatched from a subdirectory — unverified assumption underlying all of the above.

## Caveats

- Exit-code semantics (F1) follow GNU make's documented convention; if the kernel uses a non-GNU make, verify against that implementation's documentation.
- No claim in this record rests on external sources beyond that convention; where repository inspection was required and unavailable, the claim is explicitly marked unverified rather than asserted.

## References

- `research-lines.tsv` — line state for this research line (path cited in task; repository-relative).
- `[redacted path] — hngh kernel repository; site of the `make test` failure under investigation.
- Prior beat on this line, dated 2026-10-08 ("Contraction: plan-accept-gate:kernel rc=2 (×3) — status and path forward") — source of findings F1–F3 and recommendations R1–R4, refined here.
- llm-wiki prior-art pointers (read-only, contents not inspected this beat): `entities/hngh`, `sources/LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho`, `sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-`, `sources/SRC-2026-08-24-030`, `concepts/context-distillation`, `sources/SRC-2026-08-18-006`.
