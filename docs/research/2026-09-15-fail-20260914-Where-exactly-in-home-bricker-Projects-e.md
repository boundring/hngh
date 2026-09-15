# Where exactly in /home/bricker/Projects/etc/hngh does the plan-accept gate harness consume the make exit code, and what is the minimal patch surface to capture failing target, trailing stderr, and /proc metrics at failure time (R2 precondit

Status: crystallized 2026-09-15 from research line `fail-20260914-Where-exactly-in-home-bricker-Projects-e`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-Where-exactly-in-home-bricker-Projects-e.md.

# Contracted line — FINAL SUMMARY

**Line:** Where in `/home/bricker/Projects/etc/hngh` does the plan-accept gate harness consume the make exit code, and what is the minimal patch surface to capture failing target, trailing stderr, and /proc metrics at failure time (R2 precondition)?
**State:** expanding → contracting → **closed (crystallized)** | accumulated wall: ~108s (prior beat) + this beat

---

## Epistemic status (standing, applies to everything below)

No filesystem access to `/home/bricker/Projects/etc/hngh` was available at any point in this line's lifetime. The repo root and the existence of a "plan-accept gate harness" are **premises of the line, not verified facts**. Accordingly, **no file path inside the repo is asserted as existing** — every "where" is expressed as a probe to be run on host touch. External behavior (GNU make error format, `/proc` semantics) is flagged as external rather than asserted. This constraint shaped the whole line: it converged on a *probe-first, schema-first* plan instead of a concrete diff.

---

## Findings

**F1 — The consumption point is almost certainly at the shell layer, not inside make.** *(inference, high confidence)*
A gate harness that "runs make and accepts/rejects a plan" consumes the exit code where `make <target>` is invoked and `$?` (or equivalent) is inspected. The load-bearing unknown is *which* site — a gate Makefile target that shells out, or a shell entrypoint branching on status — and the line could not resolve this without host access. It matters because the control-flow shape decides whether capture code ever runs: a bare `set -e` aborts the wrapper before any post-failure trap or capture block executes.

**F2 — The minimal patch surface is the invocation wrapper, not make internals or recipe logic.** *(inference, high confidence)*
Capturing stderr/stdout via a tee'd ring buffer or temp file at the call site, then acting on nonzero exit, is additive and leaves the success path byte-identical. No recipe changes are required for any of the three capture targets.

**F3 — Failing-target extraction depends on an external, unverified format.** *(external, flagged)*
The standard GNU make failure line `make: *** [<target>] Error N` is the natural extraction source for the failing target. This is documented GNU make behavior, **not verified against the make version in this repo** — a version/pattern check is a mandatory probe, not an assumption.

**F4 — /proc capture must be enumerated, not presumed.** *(inference, low confidence on specifics)*
Generic entries (`/proc/stat`, `/proc/meminfo`, `/proc/loadavg`) are safe defaults, but any kernel counter the failing target specifically exercises must be discovered from the target's domain. Capture should be a cheap read-only probe so it does not perturb the failure state it is meant to record.

**F5 — The durable output of this line is a contract, not a patch.** *(design, high confidence)*
Because the "where" could not be pinned in-line, the lasting artifact is the failure-artifact schema and the probe sequence that makes the patch site exact in a single host touch. This is consistent with the governance posture in prior art: intake parsing must be deterministic, so the schema is fixed *before* the capture mechanism behind it.

---

## Recommendations (apply on host touch, in order)

1. **Probe before patching.** Locate the gate invocation (grep for the gate target / `make` calls), read the return-value handling at that site, and classify it: `set -e` abort vs. explicit `||`/`if !` branch. This names the file and line — the "where" — and determines whether a capture hook can fire at all.
2. **Wrap, don't modify.** At the invocation site: tee stderr (and stdout) to a ring buffer/temp file; on nonzero exit, extract the `make: *** [target] Error N` line for the failing target and flush the buffered tail as trailing stderr. Verify the error-line pattern against the repo's make version first.
3. **Snapshot /proc on the failure path only.** Read the generic entries plus whatever counters the failing target's domain implies, discovered at probe time. Keep it read-only and cheap.
4. **Emit one structured record** — `{failing_target, trailing_stderr_tail, proc_snapshot, make_rc, timestamp}` — as the unit downstream automation consumes. Freeze this schema now; keep R2/R3 capture logic swappable behind it.

---

## Open threads (for successor lines)

- **T1 — Pin the site.** The single unresolved empirical question: which file and line consumes the make exit code, and under what control-flow shape? Resolvable by one grep + one read on the host.
- **T2 — Make version / format verification.** Confirm the `*** [target] Error N` pattern against the repo's toolchain; if it differs (non-GNU make, localized output), adjust extraction.
- **T3 — Target-domain /proc enumeration.** Once a concrete failing target is known, enumerate its relevant `/proc` (and possibly `/sys`) entries empirically.
- **T4 — Intake integration.** How the structured record flows into failure intake (per [[concepts/crowdsourced-failure-intake]]) — schema versioning, retention, and whether stall lessons ([[sources/hngh-2026-09-09-stall-lessons]]) imply additional fields (e.g., wall-clock, retry count).

---

## References

**Repo premises (not file-verified — no host access during this line):**
- `/home/bricker/Projects/etc/hngh` — repo root and plan-accept gate harness, taken as premise only. No internal path asserted.

**Prior art (llm-wiki vault, read-only pointers as provided; content not re-verified this beat):**
- `concepts/crowdsourced-failure-intake`
- `concepts/agent-harness-governance`
- `sources/SRC-2026-08-19-001` (Agent Harness Landscape)
- `sources/SRC-2026-08-24-033` (CHAOSS Metrics Models)
- `sources/backlog-disposition-sweep-reduces-accepted-plans-by-half`
- `sources/hngh-2026-09-09-stall-lessons`

**External claims, flagged as unverifiable within this line (asserted as general knowledge, not as repo facts):**
- GNU make failure-line format `make: *** [target] Error N`.
- `/proc/stat`, `/proc/meminfo`, `/proc/loadavg` semantics and availability.
- Shell behavior of `set -e` vs. explicit status branching.

**Line record:** this summary is the crystallized terminal state; thread T1 is the recommended next line opener.
