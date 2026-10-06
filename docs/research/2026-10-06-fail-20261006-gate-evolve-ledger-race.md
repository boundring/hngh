# Why does the kernel gate test tests/scripts/test-evolve-dashboard-style.py count the LIVE ledger docs/project/ui-grades.md with an exact +2 row assertion while cadence/subhour/01-evolve-ui.sh appends to that same ledger every 600s (no coordination), and what kernel-side hardening (ceremony-lane candidate: filter counted rows to the test's own preset namespace) plus the automation gate-lock protocol closes the kernel-gate-red-rc2 race?

Status: crystallized 2026-10-06 from research line `fail-20261006-gate-evolve-ledger-race`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20261006-gate-evolve-ledger-race.md.

# Research Line Crystallization — kernel-gate-red-rc2 race

**Line:** Why does the kernel gate test `tests/scripts/test-evolve-dashboard-style.py` count the LIVE ledger `docs/project/ui-grades.md` with an exact `+2` row assertion while `cadence/subhour/01-evolve-ui.sh` appends to that same ledger every 600s (no coordination), and what kernel-side hardening (ceremony-lane candidate: filter counted rows to the test's own preset namespace) plus the automation gate-lock protocol closes the race?

**Final state:** contracting → **crystallized** (lasting record below).

---

## Provenance note (read this first)

This crystallization synthesizes the line's stated premise and prior beats. In this final transition I was unable to execute fresh file reads against either repository, so claims below are tiered:

- **Tier 1 (line-stated):** facts asserted in the research line itself — the three file paths, the 600s cadence, the `+2` assertion, the absence of coordination.
- **Tier 2 (inferred mechanism):** causal structure that follows necessarily from Tier 1 facts (e.g., why the race manifests).
- **Tier 3 (unverified):** anything about file *contents*, the ceremony-lane implementation, or the gate-lock protocol's current state. These are marked as such rather than asserted.

Prior beats on this line repeatedly hit LES-fail lessons (see References) about asserting unverified paths and drift in scroll/cadence behavior — so this record errs toward explicit uncertainty over confident citation.

---

## Findings

### F1. The race is structural, not incidental (Tier 1→2)

Three facts compose the defect:

1. `tests/scripts/test-evolve-dashboard-style.py` asserts an **exact row-count delta of +2** against `docs/project/ui-grades.md`.
2. `cadence/subhour/01-evolve-ui.sh` **appends rows to that same ledger on a 600s cadence**, unconditionally.
3. There is **no coordination** between the two — no lock, no sentinel, no namespace separation.

Given (1)–(3), any cadence append that lands inside the test's count window inflates the observed delta beyond +2 and turns the kernel gate red. The failure mode is intermittent and timing-dependent, which matches the "rc2" (flaky re-run) character of the named race: the gate is not wrong about style, it is wrong about *whose rows it is counting*.

### F2. The root cause is a missing ownership boundary on a shared mutable artifact (Tier 2)

The ledger is doing double duty: it is both **live operational state** (cadence appends) and **test fixture** (counted rows). Exact-delta assertions are only sound when the counter owns the counted set. The test implicitly assumes exclusive ownership of the ledger for the duration of its run; the cadence script violates that assumption by design. Neither component is individually buggy — the *contract* between them is absent.

### F3. Two candidate fixes, complementary not competing (Tier 1, mechanism Tier 2)

- **Kernel-side hardening (ceremony-lane candidate):** filter counted rows to the **test's own preset namespace**. This makes the test's delta immune to foreign appends regardless of timing — the counted set becomes `{rows the test itself wrote}`, so cadence appends are invisible to the assertion. This fixes the *test's correctness*.
- **Automation gate-lock protocol:** cadence lane acquires/skips around a gate-held lock so it does not mutate shared artifacts while the kernel gate is running. This fixes the *system's hygiene* — even a correctly-filtered test benefits from not racing a writer on the same file (e.g., partial-write interleavings, mtime-sensitive logic elsewhere).

The line's framing already points at the right answer: **do both**. Namespace filtering alone leaves the write/write hazard; gate-lock alone leaves the test brittle to any future non-cadence writer that doesn't know about the lock.

### F4. The ceremony-lane fit (Tier 3 — unverified)

Whether row-namespace filtering lands cleanly depends on the ceremony loop's closed-vocabulary/path conventions (see `hngh-ceremony-loop-mechanics` in prior art). If ledger rows carry or can carry a preset/origin tag within the existing vocabulary, filtering is a small, idiomatic change. If rows are untagged freeform, the fix requires a schema touch, which raises the ceremony cost. **I could not verify the current row schema in this transition.**

---

## Recommendations

**R1. Make the test count only its own rows (primary fix).**
Tag the rows the test writes with its preset namespace and filter the count to that tag. Acceptance criterion: the test passes with a cadence append deliberately injected mid-run. This is the minimal change that removes the race's *effect*.

**R2. Implement the automation gate-lock as a separate, general protocol (secondary fix).**
Cadence lanes should check a gate-held sentinel before mutating any artifact a gate test reads or writes, and skip (not block — a 600s lane can afford to skip a tick) when the gate is active. Skipping rather than blocking avoids coupling cadence liveness to gate duration.

**R3. Add a regression test for the race itself.**
A test that appends a foreign row to the ledger during the style test's window and asserts the gate stays green. Without this, a future refactor can silently reintroduce the shared-fixture assumption.

**R4. Document the ownership rule.**
One line near the ledger and one in the test: "this ledger is live state; tests must never assert absolute or raw-delta row counts against it without namespace filtering." Cheap, prevents the next instance of the same pattern.

**R5. Prefer R1 before R2 in landing order.**
R1 unblocks the gate deterministically and is self-contained; R2 is broader and touches the automation harness. Landing R2 first risks gate-green-by-luck (the lock holds, but the test remains fragile).

---

## Open threads

- **O1. Row schema of `docs/project/ui-grades.md`:** does a namespace/preset field exist, or must one be added? (Tier 3 — unverified this transition.) Determines whether R1 is a filter change or a schema change.
- **O2. Gate-lock mechanism:** file-lock, sentinel file, or harness-level pause? The prior art mentions an "overnight harness built/verified/enabled" observation that may already contain a locking primitive worth reusing — not confirmed.
- **O3. Blast radius:** are there *other* kernel gate tests with exact-delta assertions against live artifacts? This race is likely a pattern, not an instance. A grep for delta/count assertions against files under cadence write-paths would answer this; not performed here.
- **O4. rc2 forensic:** whether the observed red gate actually correlates with cadence tick timestamps (confirming the diagnosis empirically rather than structurally) — log cross-referencing not performed in this transition.

---

## References

Paths named in the research line itself (Tier 1; existence stated by the line, contents not re-verified this transition):

- `tests/scripts/test-evolve-dashboard-style.py` (kernel repository)
- `docs/project/ui-grades.md` (this repository, live ledger)
- `cadence/subhour/01-evolve-ui.sh` (this repository, 600s cadence lane)
- Kernel repository root: `[redacted path]

Prior-art pointers (llm-wiki vault, read-only; titles truncated in source material):

- `sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-` — research lesson (automation-related failure)
- `sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca` — research lesson (path-verification failure; directly informs this record's provenance tiering)
- `sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha` — research lesson (drift confirmation)
- `sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` — observation (possible gate-lock precursor; see O2)
- `sources/obs-2026-08-25-post-rung-11-documentation-refresh-attribution-record-and-au` — observation
- `sources/hngh-ceremony-loop-mechanics` — ceremony loop conventions (relevant to F4/R1 cost)

**Explicitly unverified:** current contents of all three code/ledger files, the ledger row schema, and the present state of any gate-lock or harness locking primitive. No external (non-repository) sources are relied on anywhere in this record.

---

*Line closed as crystallized. Reactivation triggers: O1 schema confirmation, O3 blast-radius grep, or a new red-gate event that survives R1.*
