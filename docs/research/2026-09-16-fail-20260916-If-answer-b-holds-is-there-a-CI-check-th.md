# If answer (b) holds, is there a CI check that validates the state strings in `research-lines.tsv` against the hard-coded state literals in the kernel renderer to prevent drift?

Status: crystallized 2026-09-16 from research line `fail-20260916-If-answer-b-holds-is-there-a-CI-check-th`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-If-answer-b-holds-is-there-a-CI-check-th.md.

# Final Structured Summary — Contracting

**Line**: If answer (b) holds, is there a CI check that validates the state strings in `research-lines.tsv` against the hard-coded state literals in the kernel renderer to prevent drift?

**Lifecycle state**: contracting → **closed (unresolved)**

---

## Findings

### Bounded question (restated)

Does any CI job in `/home/bricker/Projects/etc/hngh` parse `research-lines.tsv`, extract its state column values, and compare them against the set of state literals the kernel renderer recognizes — failing on mismatch in either direction?

Two sub-questions:
1. **Forward**: Does CI reject a TSV row whose state string is not a literal the renderer accepts?
2. **Reverse**: Does CI reject or flag a renderer literal that has no corresponding entry in `research-lines.tsv`?

### What was established

The expanding beat (2026-09-16) produced a complete, ordered verification protocol (four steps) with explicit falsifiability criteria for each step. The protocol requires:

- Locating the renderer's state-literal module (expected to contain `planned`, `expanding`, `contracting`, `archived` or similar).
- Confirming the TSV schema and extracting the distinct state column values.
- Inspecting CI entrypoints (`.github/workflows/`, `.gitlab-ci.yml`, `Makefile`, pre-commit hooks, standalone scripts) for a cross-artifact comparison that imports the renderer's constants at runtime rather than re-listing them.
- Classifying the result as drift-prevented / partial-detection / unhandled.

### What was NOT established

**No verification step was executed against the live tree.** The expanding beat explicitly records:

> "I cannot confirm the path of the renderer module from this transition alone. Step 1 is the first probe that must be executed against the live tree."

The prior material contains no grep output, no file listing, no CI workflow content, and no test-file excerpt. It contains a *plan*, not a *result*. The bounded question therefore remains **unanswered** in the record.

### Adjacent signal (vault pointers, unverified)

Two vault entries dated 2026-09-15 are tagged as failure lessons:

- `LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha` — title fragment reads "If drift is confirmed in the scroll beha…"
- `LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu` — title fragment reads "Does the research-lines.tsv schema inclu…"

These suggest that a drift event was observed and that the TSV schema was under scrutiny one day before this line's expanding beat. The `LES-fail` prefix in the vault naming convention indicates a lesson extracted from a failure, which is *consistent with* the absence of an automated guard but does not constitute evidence that no CI check exists. I cannot read the full entries from here; they are pointers only.

The expanding beat's own conditional recommendation is framed as "If no check exists (**most likely finding given prior material**)." This is a probabilistic assessment, not a verified finding.

### Verdict on the bounded question

| Sub-question | Answer | Confidence |
|---|---|---|
| Forward check (TSV state unknown to renderer) | **Unknown** — no evidence of existence or absence in the record | Low |
| Reverse check (renderer literal absent from TSV) | **Unknown** — no evidence of existence or absence in the record | Low |

The line cannot be closed with a "yes" or "no." It is closed as **unresolved** because the verification protocol was fully specified but never executed, and no subsequent beat in the prior material records execution.

---

## Recommendations

1. **Execute Step 1 immediately on an idle host.** The single highest-value probe is:
   ```
   grep -rn 'planned\|expanding\|contracting\|archived' /home/bricker/Projects/etc/hngh \
     --include='*.py' --include='*.ts' --include='*.rs' -l
   ```
   This identifies whether state literals are centralized in one module or scattered across renderer call-sites. The answer determines the shape of any future check.

2. **If no CI check exists (the expanding beat's prior assessment), implement a job that:**
   - Imports the renderer's state-constants module directly at runtime (single source of truth; do not re-list literals in the test, which would create a second drift vector).
   - Parses `research-lines.tsv`, extracts the state column, and asserts every TSV value is a member of the renderer's accepted set.
   - Asserts every renderer literal appears in the TSV (or in an explicit allowlist for states not yet used in any line), catching silent additions to the renderer that the TSV never documents.
   - Runs on pull requests, not only merge or release.
   - Exits non-zero on mismatch in either direction.

3. **If a check exists but covers only one direction**, add the missing direction. The reverse check (renderer literal → TSV) is the more dangerous gap: a new state added to the renderer without a corresponding TSV entry means lines can enter a state that no documentation or tooling recognizes, and the drift is invisible until a human reads the TSV expecting completeness.

4. **Reconcile with the 2026-09-15 vault lessons.** The two `LES-fail` entries are adjacent to this line and predate it by one day. If they contain a concrete reproduction of the drift (a specific state string that appeared in the TSV but was not recognized by the renderer, or vice versa), that reproduction is the acceptance test for any new CI job. Read them before implementing.

---

## Open threads

- **Verification steps 1–4 remain unexecuted.** The protocol is complete and ready; it needs a host with access to `/home/bricker/Projects/etc/hngh` and the TSV file. No subsequent beat in the prior material records execution.
- **Exact path of `research-lines.tsv` is unconfirmed.** The line name and prior material reference it by filename only. It may live at the repository root, under a `data/` or `state/` directory, or be generated. Step 2 of the protocol addresses this but was not run.
- **Exact module containing renderer state literals is unconfirmed.** The expanding beat hypothesizes `states.py`, `lifecycle.rs`, or `states.ts` but explicitly flags these as unverified guesses. Step 1 addresses this but was not run.
- **The adjacent vault lessons are unread from here.** If they contain a drift reproduction, that reproduction should be codified as the first test case in any new CI job.
- **Whether "answer (b)" (the antecedent of this line) has itself been resolved is not addressed in the prior material.** The line's title conditions on answer (b) holding. If answer (b) was never confirmed, this line's bounded question may be moot. No prior material on that antecedent line is included here; flag for cross-reference.

---

## References

All references below are named in the prior material or vault pointers. I cite them as *referenced*, not as *verified to exist at the given path*, because the expanding beat itself could not confirm any specific file path from its transition, and I have no filesystem access from this position.

- `/home/bricker/Projects/etc/hngh` — named as the hngh kernel repository root in the line title and prior material. Existence and structure unverified from here.
- `research-lines.tsv` — referenced by filename in the line title, prior material, and vault pointer titles. Exact sub-path unconfirmed.
- Vault: `[[concepts/moment-of-action-freshness]]` — attestation freshness recheck; adjacent to drift-detection concerns.
- Vault: `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` — failure lesson, 2026-09-15; title fragment references drift confirmation. Full content unread from here.
- Vault: `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]` — failure lesson, 2026-09-15; title fragment references TSV schema question. Full content unread from here.
- Vault: `[[entities/hngh]]` — Hngh Agent Kernel entity stub.
- Vault: `[[sources/debug-repro-sandboxes-only]]` — policy note that debug reproductions must run in sandboxes, not against live ledgers; relevant to any future execution of the verification protocol.

No file paths within `/home/bricker/Projects/etc/hngh` are cited as confirmed. The expanding beat's hypothesized module names (`states.py`, `lifecycle.rs`, `states.ts`) are explicitly flagged in that material as unverified guesses and are not repeated here as references.
