# why does the project vault rebuild fail/underperform and what fixes it?

Status: crystallized 2026-09-20 from research line `fail-20260920-ctx-wiki-rebuild-project-eb53145f`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260920-ctx-wiki-rebuild-project-eb53145f.md.

# Research Line Crystallization — Final Record

_line: why does the project vault rebuild fail/underperform and what fixes it? | state: contracting → **crystallized** | scope: lasting summary of findings, recommendations, open threads_

**Scope honesty note (carried forward):** this transition, like the previous one, runs without live filesystem read access. I could not open the vault or `[redacted path] to verify paths, line numbers, or whether any roadmap items have since landed. Accordingly: **no concrete file paths are asserted as facts anywhere below.** The only artifacts cited are the four prior-art vault notes, referenced by their vault identifiers. Every kernel-level claim is phrased as a hypothesis plus a verification step. External sources beyond these repositories were not consulted and are not claimed.

---

## 1. Line question (as resolved)

The rebuild failure/underperformance is best explained not as a single defect but as a **composition of three pipeline mechanisms**, possibly amplified by **one measurement confound**. The line's contribution is the failure model itself plus a priority-ordered remediation sequence whose ordering is load-bearing (fix observability/idempotency first, or later fixes cannot be measured).

## 2. Findings (the failure model)

Synthesized from [[sources/wave-delay-spec-fixes-20260827]], [[sources/obs-2026-08-19-authored-vs-studied-project-distinction]], and [[sources/SRC-2026-08-18-003]]:

- **F1 — Schema drift at the scout → crystallize boundary.** Extraction emits records whose shape has drifted from what crystallization expects, causing silent drops. Observable symptom: vault thinner than the raw material justifies. *Unverified at the code level.*
- **F2 — Non-atomic land.** Writes occur in place; an interrupted rebuild leaves mixed old/new state, and reruns compound damage rather than converge. The rebuild is therefore **non-idempotent** — the single most damaging property, because it corrupts the baseline against which every other fix would be measured. *Unverified at the code level.*
- **F3 — Multi-key mishandling.** One logical entity arriving under several keys produces duplication (bloat) or an arbitrary silent winner (loss). Whether any dedup logic exists at all is unknown.
- **F4 — Confound: authored vs. studied uniformity.** Per [[sources/obs-2026-08-19-authored-vs-studied-project-distinction]], if the pipeline does not branch on this distinction, studied/external material inflates F1's drop count and consumes rebuild budget on low-value re-crystallization — making localized defects look like global underperformance.

**Root-cause status:** [[sources/cistern-project-findings]] remains the empirical root-cause node and was never read within this line. The model above is therefore a **best-supported hypothesis**, not a confirmed diagnosis.

## 3. Recommendations (priority-ordered; order is intentional)

- **R1 — Make land atomic first.** Stage new vault state in a temp/staging location, then swap via rename (atomic on POSIX filesystems); add a content-hash skip so unchanged entities aren't rewritten. Rationale: non-idempotency poisons measurement of everything downstream. *Verify in the hngh kernel: locate the land/write step; check for write-then-rename vs. in-place mutation and any staging-directory discipline.*
- **R2 — Schema contract at the scout/crystallize boundary.** Validate incoming records against an explicit schema version; route failures to a quarantine/dead-letter set rather than silently dropping or aborting. This converts invisible loss into a `dropped_records` metric, which is also the instrument needed to test whether F1 actually dominates. *Verify: find where scout output is deserialized; check whether validation exists.*
- **R3 — Explicit multi-key identity resolution.** Define a canonical-key rule (stable content hash or explicit alias map); one logical entity lands exactly once; collisions emit warnings instead of a silent winner. *Verify: search the kernel for key/dedup handling in crystallize/land.*
- **R4 — Branch the rebuild on authored vs. studied.** After R1–R3, split rebuild accounting and scheduling by class: re-crystallize authored material eagerly, studied material lazily or on-demand; report `dropped_records` per class so F4 stops masquerading as F1.

**Sequencing argument (the line's main methodological finding):** R1 before R2/R3 because idempotency is a precondition for trustworthy measurement; R2 before heavy F1 remediation because the quarantine metric tells you whether the drift is real and where; R4 last because it is an optimization that only makes sense once loss modes are observable.

## 4. Open threads

1. **Read [[sources/cistern-project-findings]].** The single highest-value next action; it may confirm, refute, or reorder the F1–F4 model.
2. **Ground-truth pass over the hngh kernel** (`[redacted path] confirm or refute each "Verify" step in §3 and replace hypotheses with cited file paths. This line never achieved that grounding.
3. **Check [[sources/SRC-2026-08-18-003]] (the rebuild roadmap) against current kernel state** — some items may already have landed, which would change R1–R4 priorities.
4. **Baseline metrics before any fix:** rebuild wall time, vault entity count vs. raw-material count, and (once R2 lands) `dropped_records` per class. Without a baseline, "underperform" remains unquantified — itself an unresolved sub-question of this line.
5. **Idempotency test definition:** specify the acceptance test for R1 (kill the rebuild mid-flight N times; assert final vault state is identical to an uninterrupted run).

## 5. Confidence summary

| Claim | Status |
|---|---|
| Four-part failure model (F1–F4) | Hypothesis, grounded in prior vault notes, not in code |
| R1–R4 recommendation set and ordering | Reasoned from the model; not validated against the kernel |
| Existence/content of the four cited vault notes | Grounded (prior-art pointers within this line) |
| Any specific file path in either repository | **Not asserted** — no read access in any transition of this line |

---

## References

Cited artifacts (llm-wiki vault, read-only pointers — the only grounded sources on this line):

- [[sources/wave-delay-spec-fixes-20260827]] — Wave delay fixes: scout schemas, atomic land, multi-key *(origin of F1–F3)*
- [[sources/obs-2026-08-19-authored-vs-studied-project-distinction]] — Observation: Authored vs Studied project distinction *(origin of F4)*
- [[sources/SRC-2026-08-18-003]] — Hngh Crystallized Rebuild Roadmap *(acknowledged-fix roadmap; created: unknown)*
- [[sources/cistern-project-findings]] — Cistern Project Findings *(created: 2026-09-07; unread empirical root-cause node — open thread #1)*

Repositories referenced but **not verified** (no file paths asserted):

- `[redacted path] (hngh kernel — target of all "Verify" steps)
- The project vault itself

No external sources were used; none are claimed.

_line state: crystallized. Reactivation trigger: completion of open thread #1 or #2, whichever comes first._
