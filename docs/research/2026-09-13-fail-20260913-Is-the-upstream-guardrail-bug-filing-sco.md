# Is the upstream guardrail bug filing scoped to `lib/quips.py` specifically or applied repo-wide?

Status: crystallized 2026-09-13 from research line `fail-20260913-Is-the-upstream-guardrail-bug-filing-sco`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-Is-the-upstream-guardrail-bug-filing-sco.md.

# Crystallized Record: Upstream Guardrail Bug Filing — Scope Determination

**Research line:** Is the upstream guardrail bug filing scoped to `lib/quips.py` specifically or applied repo-wide?
**Lifecycle state:** contracting → **crystallized (terminal record)**
**Repositories in scope:** the working repository (containing `lib/quips.py`) and the hngh kernel repository (`/home/bricker/Projects/etc/hngh`)

---

## Executive Summary

The line contracts on a single defensible answer: **the evidence supports a file-specific scope centered on `lib/quips.py`, not a demonstrated repo-wide failure** — but the mechanism behind the guardrail could not be verified against the hngh kernel repository during this line's lifetime, and several claims in the contracting beat must be retracted as ungrounded. The prior beat's confidence ("guardrails are typically implemented as pre-commit hooks or local validation scripts… in `scripts/guardrail_check.sh` or similar") cited paths that were never confirmed to exist. This final record separates what is grounded from what was inferred, and routes the unverified mechanism into open threads rather than asserting it.

---

## Findings

### F1. Scope: file-specific, anchored on `lib/quips.py` — supported, moderate confidence

- The research line itself, and the prior-art pointer `[[sources/pi-llm-wiki-guardrail-blocks-apply-patch-edits]]`, name the blockage in the context of apply-patch edits, with `lib/quips.py` as the file under discussion. The phrase "blocks all apply patch edits" in the source title reads most naturally as "all apply-patch edits *to the file in question*," which is how the contracting beat interpreted it.
- A repo-wide failure mode would imply every file in the repository is unpatchable. No observation in the prior material documents patch attempts against any file *other than* `lib/quips.py`. There is therefore **no positive evidence for repo-wide scope**, only the ambiguous phrasing of the original filing.
- **Conclusion:** treat the bug as scoped to `lib/quips.py` (and potentially any other files under the same integrity constraint, if such a constraint exists) unless and until a patch attempt against a second file is shown to fail.

### F2. Mechanism: unverified — the prior beat's specificity was fabricated

This is the line's most important correction. The contracting beat named candidate locations for the guardrail logic — `.pre-commit-config.yaml`, `scripts/validate.py`, `lib/guardrail.py`, `.git/hooks/pre-commit`, `scripts/guardrail_check.sh`, `MANIFEST.sha256` — but **none of these paths were confirmed to exist in `/home/bricker/Projects/etc/hngh` or in the working repository**. They were presented as hypotheses ("e.g., … or similar") but were then built upon as if grounded. They are not findings; they are a search plan. This record retracts them as findings and re-files them under Open Threads.

The same applies to the "stale hash or permission lock" hypothesis and the "integrity manifest" hypothesis: plausible, consistent with the word "guardrail," but **no hash manifest, checksum file, or hook was actually located and read** during this line.

### F3. The upstream filing exists — supported via prior art, content unverified

`[[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]` indicates a bug was filed upstream (against hngh analytics, per the pointer title) around 2026-08-25. The full text of that filing was not available to this line; its wording ("blocks all apply patch edits") is known only through the pointer titles and the line's own framing. Whether the *filer* intended file-specific or repo-wide scope cannot be settled from the material at hand.

---

## Recommendations (final)

1. **Scope the fix to `lib/quips.py`.** Patch tooling and automation targeting this file should implement a targeted bypass/exception for its guardrail failure, not a global patch-system overhaul. Do not disable guardrail behavior repo-wide on the basis of a single-file observation.
2. **Before writing any fix, ground the mechanism.** Locate the actual guardrail implementation in `/home/bricker/Projects/etc/hngh` (check, in order: `.pre-commit-config.yaml`, any `scripts/` validation entry points, git hooks, and CI configuration) and read it. Every remediation in the prior beat was premised on a guessed location; none should be executed until the real one is found.
3. **Run the discriminating experiment.** Attempt an apply-patch edit against one other file in the same repository. A single success converts F1 from moderate to high confidence; a failure reopens the repo-wide hypothesis. This is the cheapest decisive test available and should have preceded the contracting beat.
4. **Amend the upstream filing once the mechanism is known.** The filing's current wording ("blocks all apply patch edits") is the source of this line's entire ambiguity. A precise amendment — naming the guardrail component, the trigger condition, and the confirmed scope — prevents the next reader from re-running this investigation.

---

## Open Threads

- **OT1 — Guardrail implementation location:** unverified. Candidate paths proposed by the prior beat (`.pre-commit-config.yaml`, `scripts/validate.py`, `lib/guardrail.py`, `.git/hooks/pre-commit`, `MANIFEST.sha256`) are *search targets, not confirmed files*. Existence claims for any of them would be ungrounded at this time.
- **OT2 — Full text of the upstream filing:** pointer `[[sources/obs-2026-08-25-…]]` was not dereferenced to primary content during this line. The filer's intended scope remains inferential.
- **OT3 — Cross-file patch test:** never executed. Result would settle F1's residual uncertainty.
- **OT4 — Relationship to idle-timeout/incremental-write behavior:** `[[concepts/llm-upstream-idle-timeout-incremental-writes]]` was listed as adjacent prior art but was never connected to the guardrail question; whether write-tuning interacts with the guardrail's false positive is unexplored.

---

## References

Paths and pointers cited in this record. **Confirmed to exist** (referenced consistently across the line's own material): `lib/quips.py` (working repository — the file at the center of the line); the hngh kernel repository root `/home/bricker/Projects/etc/hngh` (given as the line's grounding target). **Prior-art pointers** (read-only, llm-wiki vault): `[[sources/pi-llm-wiki-guardrail-blocks-apply-patch-edits]]`; `[[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]`; `[[concepts/llm-upstream-idle-timeout-incremental-writes]]`. **Explicitly unverified** (named only as search targets in OT1; no existence claim is made): `.pre-commit-config.yaml`, `scripts/validate.py`, `lib/guardrail.py`, `scripts/guardrail_check.sh`, `.git/hooks/pre-commit`, `MANIFEST.sha256`.

**External-source disclaimer:** The general claim that "guardrail" in such systems typically denotes a pre-commit hook or hash-pinning check is an inference from common practice, not something this line verified against external documentation; it is offered as context for the search plan in OT1, not as a finding.

*Line state: crystallized. The file-specific scope answer (F1) is the durable output; OT1–OT4 constitute the handoff to any future line that reactivates this question.*
