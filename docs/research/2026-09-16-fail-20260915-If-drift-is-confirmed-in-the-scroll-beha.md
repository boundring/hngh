# If drift is confirmed in the scroll behavior, which other nominally-shared dashboard behaviors (e.g. tab-state persistence, cost display per `2026-08-28-session-cost-display.md`) exhibit the same duplicated-and-diverged pattern?

Status: crystallized 2026-09-16 from research line `fail-20260915-If-drift-is-confirmed-in-the-scroll-beha`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha.md.

# Research Line: Duplicated-and-Diverged Dashboard Behaviors — Final Structured Summary

**Line:** If drift is confirmed in the scroll behavior, which other nominally-shared dashboard behaviors (e.g. tab-state persistence, cost display per `2026-08-28-session-cost-display.md`) exhibit the same duplicated-and-diverged pattern?
**Lifecycle state:** contracting → **crystallized (final record)**

---

## Findings

### F1 — The pattern is systemic, not a one-off.
The "duplicated-and-diverged" failure class — nominally-one behavior implemented in two or more copies that silently diverge, with no test pinning the shared contract — is confirmed at least three times across this codebase family before the scroll-behavior question was even raised:

1. **Verdict rule drift** (`verdict-rule-drift-two-surfaces`): a shared verdict rule drifted across two surfaces *within one repository*. This is the exact structural shape of the suspected scroll-behavior drift, and it converts the line from "does the pattern exist?" to "where else does it exist?"
2. **Timezone rendering** (`timezone-local-vs-utc-rendering-fabricates-missing-commits`): git date display was implemented twice with different semantics (local vs UTC), producing user-visible fabrication of missing commits. Same failure class: two copies, silent divergence, no contract test.
3. **Doc-vs-install drift** (`obs-2026-08-25-night-check-hngh-harness-healthy-timer-doc-vs-install-drift-`): a third instance, but across the doc/code boundary rather than code/code — the documented behavior and the installed behavior diverged.

The scroll behavior, if confirmed, would be **instance #4**. The line's core question is therefore answered in the affirmative at the *pattern* level: drift-after-duplication is a systemic property of hngh/hngh-automation.

### F2 — Rendering logic is the repeat offender surface.
Two of the three confirmed prior cases (verdict rule, timezone rendering) live in rendering/display logic — code that maps shared state to user-visible output. This is the highest-risk duplication surface because divergence is *observable* (two surfaces disagree about the same fact on screen), which is also what makes it catchable. The suspected scroll behavior and the candidate behaviors below are all in this class.

### F3 — The candidate behaviors named in the line are plausible but NOT yet source-confirmed.
The line names two specific candidates: **tab-state persistence** and **cost display** (per `2026-08-28-session-cost-display.md`). I must be explicit about the epistemic status of these:

- The expanding beat completed only orientation (~6.0s wall). It located the line state and four prior-art pointers in the llm-wiki vault, but **did not finish a source-level sweep of `/home/bricker/Projects/etc/hngh`**.
- I therefore **cannot assert** that tab-state persistence or cost display are in fact duplicated-and-diverged. They are *candidates* selected because they match the known pattern's risk profile (shared state → rendered output, multiple surfaces), not because a fresh audit confirmed duplication.
- The cost-display note (`2026-08-28-session-cost-display.md`) is referenced as the **intent document** for that behavior — i.e., it records what the behavior *should* be, which is exactly the artifact needed to detect divergence if two copies exist. Its existence in the vault is asserted by the line itself; I treat it as a pointer, not as evidence of duplication.

### F4 — The confirmation gate is a structural sweep, not an assumption.
The honest state of this line is: **the pattern is confirmed; the specific scroll/tab/cost instances are hypothesized pending a source-level enumeration.** No claim in this record should be read as "we found the duplicated cost display" or "we found the duplicated tab-state persistence." Those remain open threads (O1, O2 below).

---

## Recommendations

**R1 — Enumerate the duplication surface before fixing anything.**
Run a structural sweep of both repos (`/home/bricker/Projects/etc/hngh` and the automation repo) for the known suspect behaviors: scroll handling, tab-state persistence, and session cost display. Concrete grep targets: `addEventListener('scroll'` / `onscroll`, `sessionStorage` / `localStorage`, and the cost-formatting token(s) named in the cost-display note. Output: a two-column table (surface A path : surface B path) for each behavior found duplicated. **Do not start deduplication until this table exists** — fixing instances one at a time is precisely how the pattern got here.

**R2 — Rank by user-visible asymmetry, not by code similarity.**
The two confirmed prior cases (verdict rule, timezone rendering) were caught because they produced *observable contradictions*: two surfaces disagreeing about the same fact in the same session. Prioritize duplicated behaviors where the two copies can be rendered side-by-side in one dashboard session. On this criterion: cost display and tab-state persistence rank highest; scroll behavior ranks third unless the drift causes the layout regression described in `clean-at-any-size-1035px-lesson`.

**R3 — For each confirmed pair, extract one shared module and pin it with a contract test.**
Per-instance fix pattern: (a) pick the copy whose behavior matches the documented intent (the cost-display note is the intent document for its behavior; the clean-at-any-size lesson is the intent document for scroll/layout), (b) move it to a single import location both surfaces consume, (c) add a contract test that renders both surfaces against the same fixture and asserts identical output. The contract test is the load-bearing part — it is the absence of exactly this artifact in all three prior cases that allowed divergence.

**R4 — Treat intent documents as first-class artifacts.**
Each confirmed case had an implicit or explicit "what this behavior should be" document (the cost note, the clean-at-any-size lesson). The drift-vs-install case shows what happens when no such document exists for the installed surface. Recommendation: every nominally-shared dashboard behavior gets a one-paragraph intent note at its canonical module path, so future sweeps have a ground truth to diff against.

---

## Open Threads

**O1 — Scroll-behavior confirmation (the line's trigger).**
The line is conditioned on "if drift is confirmed in the scroll behavior." That confirmation has **not** been performed in this record. The structural sweep (R1) must produce the two-column table for scroll handling before the line can move from "pattern is systemic" to "scroll is instance #4." Until then, the scroll claim is a hypothesis ranked third by R2.

**O2 — Tab-state persistence duplication status.**
Named as a candidate in the line but **not source-confirmed**. The sweep (R1) must determine whether tab-state persistence is implemented once or duplicated across surfaces. If duplicated, it ranks first or second by R2 (shared state → rendered output, side-by-side observable).

**O3 — Cost display duplication status.**
Same epistemic status as O2: named in the line, referenced via `2026-08-28-session-cost-display.md` as its intent document, but **not source-confirmed** as duplicated. The cost note's existence is asserted by the line; I treat it as a pointer. If the sweep confirms duplication, this ranks first by R2 (highest user-visible asymmetry: two surfaces showing different dollar amounts for the same session).

**O4 — Doc-vs-code boundary as a fourth surface class.**
The drift-vs-install case shows the pattern also crosses the doc/code boundary, not just code/code. The sweep (R1) should include a pass over installed artifacts vs. their documentation to catch this class, which is currently under-weighted in R2's ranking (it produces observable contradictions only when a user reads the docs and then uses the install).

**O5 — Cross-repo scope.**
The line says "both repos" implicitly (hngh kernel + automation). The prior-art pointers are vault-level; I have not verified which specific files in `/home/bricker/Projects/etc/hngh` contain the duplicated logic. Any file-path claim in this record is a *search target*, not a confirmed path. The sweep must produce real paths before R3's deduplication can proceed.

---

## What this line crystallizes into

A **reusable detection-and-fix protocol** for the duplicated-and-diverged failure class, plus a **ranked candidate list** (scroll, tab-state persistence, cost display) pending source confirmation. The lasting value is not any single fix but the *table* R1 produces: once every nominally-shared dashboard behavior is enumerated with its surface-A/surface-B paths and its intent document, the line's question ("which other behaviors exhibit the pattern?") has a permanent answer that future drift incidents can be checked against.

---

## References

- `/home/bricker/Projects/etc/hngh` — hngh kernel repository (sweep target; specific file paths not asserted in this record)
- `2026-08-28-session-cost-display.md` — intent document for session cost display behavior (referenced by the line as a pointer; treated as such, not as duplication evidence)
- `[[sources/verdict-rule-drift-two-surfaces]]` — prior-art: shared verdict rule drifted across two surfaces in one repository
- `[[sources/timezone-local-vs-utc-rendering-fabricates-missing-commits]]` — prior-art: local-time vs UTC git date display divergence
- `[[sources/obs-2026-08-25-night-check-hngh-harness-healthy-timer-doc-vs-install-drift-]]` — prior-art: doc-vs-install drift observation
- `[[sources/clean-at-any-size-1035px-lesson]]` — intent document for clean page behavior at any window size (scroll/layout)

**Explicit non-verification note:** I have not performed a fresh source-level audit of `/home/bricker/Projects/etc/hngh` in this contraction. All file-path references above are either vault pointers or search targets from the line's prior material. No claim in this record asserts that a specific duplicated implementation exists at a specific path; those claims remain open threads O1–O5 pending the R1 sweep.
