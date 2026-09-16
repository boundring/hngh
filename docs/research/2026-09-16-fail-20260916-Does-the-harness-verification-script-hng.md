# Does the harness verification script (`hngh-automation/verify.sh` or equivalent) already include a `grep -qF 'Storage=persistent'` check that would make the external audit redundant?

Status: crystallized 2026-09-16 from research line `fail-20260916-Does-the-harness-verification-script-hng`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-Does-the-harness-verification-script-hng.md.

# Line record — `Storage=persistent` harness-check redundancy

**Line:** Does the harness verification script (`hngh-automation/verify.sh` or equivalent) already include a `grep -qF 'Storage=persistent'` check that would make the external audit redundant?
**State:** contracting → crystallized (final structured summary; line remains in motion on idle hosts, not batched)

## Epistemic status (binding constraint)

From this transition I **cannot read `~/Projects/etc/hngh`**, nor confirm that `hngh-automation/verify.sh` exists or contains any check. Therefore no claim below rests on the contents of a specific kernel-repo file, and no path in that tree is asserted to exist. The only paths named are the line's candidate (`hngh-automation/verify.sh`) and the kernel root (`~/Projects/etc/hngh`); both remain **unverified here**. No external source is treated as verified.

## Findings

1. **Existence of the check is unestablished.** Whether a `grep -qF 'Storage=persistent'` (or any equivalent) lives in the harness verification script cannot be confirmed from this transition. The line's premise is therefore still an open empirical question, not a settled fact.
2. **Token presence ≠ redundancy.** Even granting that a bare fixed-string grep exists, it does not by itself make an external audit redundant. Redundancy requires three conditions to hold *simultaneously*:
   - **C1 — Existence + fidelity:** a harness check exists and detects the *same defect class* as the external audit.
   - **C2 — Gate liveness:** that check runs at the decision point with *blocking* semantics (failure stops build/deploy/action).
   - **C3 — Scope + freshness equivalence:** it inspects the *same artifact, in the same scope, at the same moment of action* as the external audit.
3. **A raw `grep -qF` is only a weak C1 candidate.** A fixed substring can be satisfied by a comment, documentation, a template, a disabled unit, a generated-but-not-installed file, a stale source copy, or a false positive in an unrelated config section. It proves the token appears somewhere; it does not prove the storage configuration is correct, installed, and gated.
4. **Default posture.** Until C1–C3 are evidenced, the external audit is *not* redundant and should be retained. Closing the line on token presence would be a category error (confusing "string present" with "defect class caught at the moment of action").

## Recommendations

- **R1 — Do not close on token presence.** Keep the line open until C1–C3 are evidenced; treat any discovered `grep -qF 'Storage=persistent'` as a smoke signal, not redundancy proof.
- **R2 — Upgrade from token grep to scoped structural validation.** If `Storage=persistent` is a harness/unit config key, the check should at minimum: anchor the expected line (e.g. `grep -qE '^[[:space:]]*Storage=[[:space:]]*persistent[[:space:]]*$' "$artifact"`); assert no conflicting `Storage=` value; confirm the correct section/unit when the format is sectioned; and prefer a parser/validator over grep where one exists.
- **R3 — Prove gate liveness, not script existence.** Evidence required: the exact command or CI/deploy hook that invokes the verification script; confirmation that a nonzero exit fails the pipeline; and a negative test in which `Storage=persistent` is removed/altered and the gate fails. An advisory, skippable, or failure-ignored script fails C2 → audit not redundant.
- **R4 — Check the moment-of-action artifact.** Validate the artifact actually used at action time (final installed/generated path), with a hash/checksum, a timestamp close to the action point, and confirmation that no later step overwrites or regenerates it after verification. If the kernel repo generates/installs/rewrites storage configuration, the check must target that generated/installed output, not a hand-maintained source copy — *where that generation occurs in `~/Projects/etc/hngh` is unverified from here.*
- **R5 — Add mutation/negative tests to the harness.** The harness should fail when the storage setting is absent or wrong, so C1 fidelity is demonstrated by behavior, not by reading the script.

## Open threads

- **Existence + contents** of `hngh-automation/verify.sh` (or its true equivalent) — unverified; must be read directly from the tree before any redundancy claim.
- **Decision-point gate identity + blocking semantics** — which hook/CI step runs the check, and does nonzero exit actually stop action?
- **Moment-of-action artifact path** — final installed/generated location of the storage config, its hash, and whether a later step regenerates it.
- **Scope equivalence** — same artifact, same section/unit, same moment as the external audit (C3).
- **Disposition** — absent C1–C3 evidence, retain the external audit; revisit only when the three conditions are jointly demonstrated.

## References

All kernel-repo paths below are **named candidates, not confirmed to exist**; no claim in this record depends on their contents.

- `hngh-automation/verify.sh` — named candidate harness verification script. **Existence UNVERIFIED** from this transition.
- `~/Projects/etc/hngh` — named kernel repository root. **Accessibility/contents UNVERIFIED** from this transition.
- `research-lines.tsv` — continuous line-state ledger for this research process (the line's own state record).
- Prior-art vault pointers (read-only, as provided; taken on the strength of the pointer list, not independently re-read):
  - `sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-`
  - `sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca`
  - `concepts/moment-of-action-freshness`
  - `concepts/agent-harness-governance`
  - `sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu`

No external source is asserted as verified; where a claim would require reading the kernel tree or the vault notes directly, it is flagged unverified above rather than stated as fact.
