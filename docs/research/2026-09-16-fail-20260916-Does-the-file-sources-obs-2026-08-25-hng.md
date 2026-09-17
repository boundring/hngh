# Does the file `sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` contain the literal string `Storage=persistent`?

Status: crystallized 2026-09-16 from research line `fail-20260916-Does-the-file-sources-obs-2026-08-25-hng`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-Does-the-file-sources-obs-2026-08-25-hng.md.

# research beat 2026-09-16 (contraction — final record)

_line: Does the file `sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` contain the literal string `Storage=persistent`? | state: contracting → crystallized | context: continuous line, this record produced in-motion_

---

## Verdict

**UNRESOLVED at crystallization.** No recorded transition on this line has ever executed a direct content probe of the target file. The binary question was never answered from file contents — every artifact this line produced concerns *method*, not *content*. This is stated explicitly rather than papered over: in this transition I have no file-content access to the vault or to `~/Projects/etc/hngh`, so no verdict (true or false) is asserted. The filename's semantics ("built-verified-enabled") were correctly never admitted as evidence, and must remain inadmissible.

## Findings

1. **The question is a literal-string membership test** over one vault file: `sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled`. It admits exactly two defensible answers and requires one fixed-string probe to settle. Nothing cheaper or more inferential is admissible.

2. **The prior beat (2026-09-16, expanding→contracting) recorded evidence status as "unresolved; no direct file-content evidence."** Its entire output was a probe procedure plus governance recommendations. No result was recorded, and none has appeared since.

3. **Prior art records a documented failure on this exact query**: `sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-`, with a sibling path-evidence lesson at `sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca`. Together these fix the corrective rule under which this line has operated: for literal-string questions, the only admissible evidence is exact command output from the file itself. Filename semantics, paraphrase, and related governance prose are insufficient.

4. **The corrected procedure is already specified and remains valid**: `LC_ALL=C grep -F -- 'Storage=persistent' sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled`, recording exit status, match count, context if matched, repository revision or working-tree state, and timestamp.

5. **Near-miss hazard, flagged as external knowledge**: `Storage=persistent` is the systemd *journald* storage directive, whereas systemd *timer* units use the distinct key `Persistent=true`. This distinction is general platform knowledge, not verified against any file in this repository or in `~/Projects/etc/hngh` during this line's lifetime; it motivates but does not substitute for the probe. An observation note about a harness being "enabled" could plausibly contain either form — which is precisely why only the literal probe settles membership.

6. **No transition produced even indirect characterizations** (size, format, structure) of the target file, so no inference chain of any kind is available — nor would one be admissible if it were.

## Recommendations (final, standing)

- **R1 — Execute the probe.** Run the fixed

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
