# What merge-and-lint algorithm enforces "add assertions + override severity, never silently delete a base `must`" across profiles before a third host class appears?

Status: crystallized 2026-10-05 from research line `fail-20261005-What-merge-and-lint-algorithm-enforces-a`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20261005-What-merge-and-lint-algorithm-enforces-a.md.

# Research Line Crystallization (Final Record)

**Line:** What merge-and-lint algorithm enforces "add assertions + override severity, never silently delete a base `must`" across profiles before a third host class appears?
**Lifecycle:** expanding → contracting → **crystallized** (this transition)
**Line state file:** `research-lines.tsv`

**Verification caveat for this record:** This crystallization transition ran without live repository inspection, so no file paths in `[redacted path] are cited beyond what prior beats established. All structural claims below derive from the prior beats on this line and the read-only llm-wiki prior-art pointers. Anything that would require confirming current file contents is marked **unverified** rather than asserted.

---

## 1. Findings (durable conclusions)

**F1. The core invariant is preservation, not deduplication.**
Prior art ([[sources/verdict-rule-drift-two-surfaces]]) documented a real case of a shared verdict rule drifting across two surfaces — the failure mode this line exists to prevent. The merge operation must treat a base `must` assertion as something that can be *overridden in severity* but never *dropped silently*. Deletion requires an explicit, recorded operation.

**F2. Merge must be a structured three-phase function, not a value-level union.**
Verdict rules are structured objects — (predicate, severity, source, timestamp) — not opaque values. The correct algorithm shape is: (a) parse both profiles into structured assertion sets, (b) run a conflict-detection pass that flags duplicate predicates across profiles, (c) merge with preservation semantics where every base `must` survives unless explicitly overridden.

**F3. Lint is a merge-time gate, not a post-hoc audit.**
The "before a third host class appears" constraint only has teeth if the linter runs *at merge time* and rejects merges that would: (a) introduce a third host class without explicit approval, (b) orphan a `must` assertion (no surviving class to enforce it), or (c) change a base `must`'s severity without an explicit override record.

**F4. Assertion identity is scoped per host class.**
The R1 survival constraint (1 surviving class on 1 host — [[sources/LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho]]) means assertions should be keyed by `(predicate, host_class_id)`, not by predicate alone. Predicate-only keying makes cross-class collisions invisible and merges lossy. Whether the hngh kernel currently keys assertions this way is **unverified** — flagged as an open thread.

**F5. Merge output must be deterministic.**
The sandbox-only repro constraint ([[sources/debug-repro-sandboxes-only]]) requires the merge to be a pure function of its inputs: stable lexicographic ordering over profile names, no hash-order dependence, no random tie-breaking. Related prior art ([[sources/obs-2026-08-26-hngh-worker-wake-scratch-store-path-collides-across-wakes]]) shows this repository class already suffers path-collision bugs from implicit environment assumptions — the same failure family as nondeterministic merge output.

---

## 2. Recommendations (final, actionable)

| # | Priority | Artifact | Action |
|---|----------|----------|--------|
| R1 | Immediate | `merge_profile.py` (hngh-automation) | Three-phase merge: parse → detect conflicts → merge with preservation. Run as pre-commit hook or CI gate. |
| R2 | Short-term | `lint_profiles.py` (hngh-automation) | Post-merge validation: no orphaned `must` assertions; host class count ≤ 2 unless explicitly approved; severity overrides recorded, never silent. |
| R3 | Medium-term | hngh kernel profile schema | Refactor assertion keys to `(predicate, host_class_id)` **if** current keying is predicate-only (verify first — see O1). |
| R4 | Ongoing | `determinism_test.py` | Run merge twice on identical input in a sandbox; assert byte-identical output. |

Note: R1/R2/R4 name scripts proposed by prior beats as *new* artifacts; none of these paths are asserted to exist in either repository.

---

## 3. Open Threads (handed off, not closed)

- **O1. Unverified kernel schema.** Does the hngh kernel key profile assertions by predicate alone or by `(predicate, host_class_id)`? This determines whether R3 is a refactor or a no-op. Requires reading the hngh kernel repo — not performed in this line's lifetime.
- **O2. Override-record format.** Severity override is mandated as "explicit," but the line never settled the record format (changelog entry vs. inline annotation vs. separate overrides file). Underspecified for implementation.
- **O3. Third-class approval mechanism.** The linter must allow a third host class "when explicitly approved," but no approval artifact (signed config, manual gate, tracked exception) was designed.
- **O4. Cross-class assertions.** F4 scopes assertions per class, but genuinely cross-class rules (e.g., global invariants) need a defined representation; currently only flagged as "manual review."
- **O5. External validation.** No external merge-semantics literature (e.g., CRDTs, three-way merge tools, OPA/Rego policy merging) was consulted or verified in this line. Claims about "naive merging" failure modes rest solely on the single observed drift incident, not on surveyed practice.

---

## 4. References

Repositories and files named with confidence:
- `[redacted path] — hngh kernel repository (root; specific internal paths unverified)
- `research-lines.tsv` — line state file for this research process

Prior-art pointers (llm-wiki vault, read-only):
- [[sources/verdict-rule-drift-two-surfaces]] — the motivating drift incident
- [[sources/LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho]] — R1 survival constraint grounding F4
- [[sources/debug-repro-sandboxes-only]] — sandbox-only repro constraint grounding F5
- [[sources/obs-2026-08-26-hngh-worker-wake-scratch-store-path-collides-across-wakes]] — corroborating path-collision failure family

Proposed-but-not-created artifacts (named as recommendations only): `merge_profile.py`, `lint_profiles.py`, `determinism_test.py`.

---

**Line status:** crystallized. The record above is the lasting artifact; O1–O5 are available as seeds for future lines if the third host class or schema refactors make them live.
