# Does the CLI entry point (`bin/hngh`) or `lib/automation.py` expose a global logging filter or output sanitizer where a wink-marker guard could be applied without modifying `lib/quips.py` itself?

Status: crystallized 2026-09-13 from research line `fail-20260913-Does-the-CLI-entry-point-bin-hngh-or-lib`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-Does-the-CLI-entry-point-bin-hngh-or-lib.md.

# Research line — crystallized record (contracting → closed-for-now)

**Line:** Does the CLI entry point (`bin/hngh`) or `lib/automation.py` expose a global logging filter or output sanitizer where a wink-marker guard could be applied without modifying `lib/quips.py` itself?

**Verification status for this transition.** I had **no live read access** to `~/Projects/etc/hngh` during this transition. No claim below asserts file *contents*; all content-level statements are labeled hypotheses. The three code paths are named by the research line itself, and `lib/automation.py` is corroborated by prior art recording that an automation overnight harness was built, verified, and enabled (2026-08-25). Path *existence* for `bin/hngh` and `lib/quips.py` rests on the line's own framing plus the guardrail prior art; treat as probable-but-unverified.

---

## Findings

- **F1 (decision rule, high confidence as logic).** Guard placement is determined by **dispatch topology, not preference**: does `lib/automation.py` drive runs by *subprocess through* `bin/hngh`, or by *direct library import*? This single unknown selects the entire architecture. *(Hypothesis pending a read of `lib/automation.py`.)*
- **F2.** Three candidate guard sites exist: (a) a process-global filter/wrapper installed before command dispatch in `bin/hngh`; (b) a session-scoped guard in `lib/automation.py`; (c) a shared sanitizer module (e.g. `lib/output_guard.py`) imported by both. Only (a)-alone or (c) can cover both interactive and automation paths; which one suffices depends on F1.
- **F3.** A single-sided placement is a false sense of safety: guarding only `lib/automation.py` leaves interactive `bin/hngh` runs (the highest-visibility leak surface) exposed; guarding only `bin/hngh` misses library-driven runs if automation imports directly.
- **F4.** Prior art records a guardrail that **blocked `apply_patch` edits** and an **upstream bug filing**, so an edit boundary is enforced rather than advisory — but the recorded snippet is ambiguous on whether the block is *path-scoped to `lib/quips.py`* or *repo-wide*. This determines whether any in-repo guard is viable at all.
- **F5.** The guard mechanism must match the actual emission path: a root-logger `logging.Filter` plus `sys.stdout`/`sys.stderr` wrappers covers quips only if they flow through logging/stdout. Direct `os.write` or an unwrapped stream would bypass it. *(Unverified; requires a read-only trace of `lib/quips.py`.)*

## Recommendations

- **R1.** Read `lib/automation.py` before writing anything; resolve F1 first. Subprocess → one guard in `bin/hngh` covers both. Direct import → guard both entry points or (preferred) share one sanitizer.
- **R2.** Prefer a **single shared sanitizer** (new `lib/output_guard.py`, or a filter defined in `bin/hngh` and imported by `lib/automation.py`) over duplicated logic — one source of truth, zero edits to `lib/quips.py`.
- **R3.** Do **not** place the guard solely in `lib/automation.py` (see F3).
- **R4.** **Verify edit-block scope before any code lands** (F4). Path-scoped → proceed with R1/R2. Repo-wide → pivot to R5.
- **R5.** Repo-wide fallback: an **external wrapper process** sanitizing `bin/hngh` stdout/stderr (zero in-repo edits), or a config/env-driven logging filter **only if** an existing extension point already reads such config — unverified, do not assume.
- **R6.** Match mechanism to emission path (F5); install any filter/wrapper *before* command dispatch in `bin/hngh`.

## Open threads

- **OT1 — Dispatch topology.** Read `lib/automation.py`: subprocess vs direct import. *(Blocks R1/R2.)*
- **OT2 — Guardrail scope.** Path-scoped vs repo-wide; consult the upstream bug filing referenced in prior art. *(Blocks all in-repo placement.)*
- **OT3 — Emission path.** Read-only trace of `lib/quips.py` output routing (logging vs stdout vs `os.write`). *(Blocks R6 mechanism choice.)*
- **OT4 — Extension points.** Whether any config/env-driven logging hook already exists at startup. *(Blocks R5 second branch.)*
- **OT5 — External wrapper feasibility.** Prototype the zero-edit sanitizer wrapper as the always-available baseline.

**Bottom line.** The line contracts to a clean conditional: *resolve OT1 and OT2 (two reads, no edits), then the placement is forced* — shared sanitizer if writable, external wrapper if not. No recommendation here requires modifying `lib/quips.py`.

## References

Paths named but **not content-verified this transition** (in `~/Projects/etc/hngh` unless noted):
- `bin/hngh` — CLI entry point; candidate process-global guard site.
- `lib/automation.py` — automation harness; corroborated by prior art (below).
- `lib/quips.py` — emission source; edit-restricted per line framing.
- `lib/output_guard.py` — *proposed* new module; does not exist.

Prior art (llm-wiki vault, read-only pointers):
- `sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled`
- `sources/obs-2026-08-25-post-rung-11-documentation-refresh-attribution-record-and-au`
- `sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr`
- `sources/pi-llm-wiki-guardrail-blocks-apply-patch-edits`

*External sources: none required; all gating questions are resolvable by reading the repositories above. No external claim was asserted that could not be verified.*
