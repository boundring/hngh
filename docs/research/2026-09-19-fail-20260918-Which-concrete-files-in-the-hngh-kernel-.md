# Which concrete files in the `hngh` kernel repository define the precondition checks that cause `gate-red` to persist across consecutive runs?

Status: crystallized 2026-09-19 from research line `fail-20260918-Which-concrete-files-in-the-hngh-kernel-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260918-Which-concrete-files-in-the-hngh-kernel-.md.

# Final structured summary — `gate-red` persistence precondition checks

**Line:** Which concrete files in the `hngh` kernel repository define the precondition checks that cause `gate-red` to persist across consecutive runs?
**State:** contracting → crystallized (this record is the line's lasting artifact)
**Repository root (given, not independently verified):** `[redacted path]

> **Verification posture for this record.** The prior beat reached *leads, not file-level confirmations*. Every specific internal path in the prior material was redacted (`[redacted path]`) and none has been confirmed against the tree. Accordingly, this summary cites concrete paths **only** where they are given as fact (the repository root) or named as vault pointers; it does **not** assert the existence of any internal file. Where a claim would require a source I cannot verify here, it is flagged rather than asserted.

---

## 1. Findings

### 1.1 What is established
The line has a coherent *mechanism hypothesis* but no confirmed *file*. The persistence of `gate-red` across consecutive runs is explained by one (or a combination) of three candidate precondition surfaces, each grounded in a named prior source:

| Candidate precondition surface | Mechanism by which `gate-red` persists | Provenance | File confirmed? |
|---|---|---|---|
| **Worker-wake scratch-store path collision** | A non-run-scoped (static) scratch path is shared by run *N* and run *N+1*; absent/conditional cleanup lets state written in run *N* be read in run *N+1*. This is the *minimal sufficient condition* for persistence. | `[[sources/obs-2026-08-26-hngh-worker-wake-scratch-store-path-collides-across-wakes]]` | **No** — failure mode concrete, module not named |
| **Verdict-rule drift across two surfaces** | A shared verdict rule is duplicated on two surfaces; one writes the `gate-red` state, the other re-evaluates it against stale/different inputs → apparent persistence as an *inter-surface* artifact (write-once / read-many). | `[[sources/verdict-rule-drift-two-surfaces]]` | **No** — duplication pattern confirmed, surfaces not named |
| **Operational/service-level state** | State that outlives the process — surviving classes, timers, journal entries — carries the gate forward independent of any single file. | R1 lesson notes (three entries, titles only) | **No** — no file mapping |

### 1.2 The decisive open question
The line cannot be closed on "which concrete files" because the *identifier itself* is unconfirmed as literal. If `gate-red` is written as a fixed string, a single grep resolves the defining/consuming/persistence sites. If it is **constructed dynamically** (e.g. `f"gate-{color}"` where `color` is a variable), no literal grep will surface it and the search must pivot to the color/state enum or gate-state-machine module. This branch is unresolved and gates everything downstream.

### 1.3 What is *not* established
- No internal path under `[redacted path] has been verified as defining the `gate-red` precondition checks.
- It is not yet determined whether persistence is **intra-file** (a state value surviving in one module's store), **inter-surface** (drift between two verdict surfaces), or **service-level** (timers/journal/surviving classes). These are mutually distinguishable and require different fixes.

---

## 2. Recommendations (standing leads for idle-host motion)

These are *continuous* checks, not a one-shot batch; each re-arms as the tree moves.

1. **Literal-to-symbol sweep of the kernel tree.** Search `[redacted path] — correction: `[redacted path] — for every normalized form of the gate identifier (`gate-red`, `GATE_RED`, `red_gate`). A single pass surfaces (a) the **defining** site, (b) every **consuming** site (read/compare/branch), and (c) any **persistence** site (disk write, journal, env var, state file surviving process exit). *Zero hits* is itself a finding: it confirms dynamic construction and forces pivot to the color/state enum or gate-state-machine module.

2. **Trace scratch-store path construction.** Locate the module that builds the worker-wake scratch-store path (candidate subdirectories: `worker/`, `wake/`, `scratch/` — *not confirmed*). Determine whether the path is derived from a **run-scoped** identifier (per-run UUID/timestamp) or a **static** one. A static path plus absent-or-conditional cleanup at wake-end is the minimal sufficient condition for cross-run persistence and would close the line on this surface.

3. **Diff the two verdict-rule surfaces.** Once surfaced by (1), diff the precondition logic between them. Test specifically for the **write-once / read-many** pattern: one surface writes `gate-red` to a shared location; the other reads it every run without re-deriving. If confirmed, persistence is an inter-surface artifact and no single file is "at fault."

4. **Inspect operational persistence artifacts.** Check surviving classes, timers, and journal state for gate-carrying entries that outlive process exit. This isolates the service-level contribution and distinguishes it from (2) and (3).

5. **Re-arm on drift.** Because the verdict-rule surface is a known drift locus, any edit touching either surface re-opens the line; treat the diff in (3) as a recurring precondition check, not a one-time audit.

---

## 3. Open threads

- **The concrete file set is unconfirmed.** This is the central open thread and the reason the line contracts to *leads* rather than a closed answer. No internal path is asserted here.
- **Literal vs. dynamic identifier** (see §1.2) — unresolved; determines whether recommendation 1 can terminate the search.
- **Persistence class** — intra-file vs. inter-surface vs. service-level — unresolved; each maps to a different fix and a different "defining file."
- **Cleanup semantics** of the scratch store (absent vs. conditional) — unverified; required to confirm candidate surface 1 as sufficient.
- **R1 lesson-note → file mapping** — the three operational-persistence entries are titles only; no file correspondence has been established.

---

## 4. Explicit non-verifiable claims

- I **cannot verify** that any specific internal file under `[redacted path] exists or defines the `gate-red` precondition checks; all such paths were redacted in the prior material and are therefore *not* cited as fact here.
- The candidate subdirectory names (`worker/`, `wake/`, `scratch/`) are **search heuristics, not confirmed paths**; they are offered only to focus recommendation 2.
- The content of the R1 lesson notes beyond their titles is **not available in this context**; claims about them rest on the prior beat's characterization and are flagged as such.

---

## References

Concrete sources cited in this record:

- `[redacted path] — `hngh` kernel repository root (given as fact; internal paths not independently verified).
- Prior research beat 2026-09-19, line state expanding → contracting (the truncated prior material supplied to this transition; source of the three candidate surfaces and the mechanism hypotheses in §1.1).
- `[[sources/obs-2026-08-26-hngh-worker-wake-scratch-store-path-collides-across-wakes]]` — vault pointer (read-only); provenance for the scratch-store path-collision lead. Content taken from the prior beat; not independently re-read here.
- `[[sources/verdict-rule-drift-two-surfaces]]` — vault pointer (read-only); provenance for the two-surface verdict-rule drift lead. Content taken from the prior beat; not independently re-read here.
- R1 lesson notes, three entries (titles only) — named in the prior material as `[[entities/hngh]]`-adjacent sources (`LES-fail-20260915-*`); provenance for the operational/service-level persistence lead. Titles only; no file mapping available.

*No internal file path is listed as a verified reference because none has been confirmed in this context.*
