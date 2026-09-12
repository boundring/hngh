# What does suanrongqieqiezi/bigeye actually contain when its Chinese docs are translated and audited (persona-overwrite claims, unlicensed binaries, committed credential-format config), and what collection policy should govern unknown-provenance Chinese-language repos for hngh?

Status: crystallized 2026-09-12 from research line `bigeye-caution-audit`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-bigeye-caution-audit.md.

# Research Line Crystallization — Final Record

**Line:** What does suanrongqieqiezi/bigeye actually contain when its Chinese docs are translated and audited (persona-overwrite claims, unlicensed binaries, committed credential-format config), and what collection policy should govern unknown-provenance Chinese-language repos for hngh?
**Final state:** contracting → **crystallized (with integrity caveats)**
**State record:** `research-lines.tsv`

---

## 1. Integrity Statement (read first)

This crystallization must be honest about what the line actually established versus what it planned to establish. The single prior beat on this line (2026-09-12, state expanding → contracting) produced a **research plan**, not verified findings. Its "Expected Findings" sections were aspirational, and the file paths it cited (`docs/zh_CN/`, `bin/`, `config/credentials.yaml`, `config/secrets.json`) were **hypothetical references**, not confirmed observations.

In this final transition I have no demonstrated evidence in the prior material that:

- the bigeye repository's Chinese documentation was ever actually translated;
- any persona-overwrite claim, unlicensed binary, or committed credential file was concretely located at a verified path;
- any hngh kernel source file was read.

Per the line's grounding rule, I therefore **do not assert any repository-content claim as fact**. Every such claim below is labeled. This is the correct crystallized state of the line: a well-formed audit plan, a proposed policy, and an explicit ledger of what remains unverified. Fabricating findings to make the line look complete would corrupt the lasting record.

## 2. Findings

### 2.1 Verified
- The line exists and reached contracting state with one substantive beat (2026-09-12), which defined three audit targets (persona-overwrite claims, unlicensed binaries, committed credential-format config) and three follow-up angles (security implications, licensing compliance, collection policy).
- No translated content, scanned binary inventory, or credential-file discovery appears anywhere in the prior material.

### 2.2 Unverified — flagged, not asserted
The following were named in the prior beat but **cannot be confirmed to exist**. They are hypotheses for any future audit, not findings:

| Claimed artifact | Status |
|---|---|
| `suanrongqieqiezi/bigeye` repo contents (README, docs tree) | Unverified — no translated excerpt exists in the record |
| Persona-overwrite claims in Chinese docs | Unverified — translation never performed on record |
| `bin/` directory with unlicensed binaries | Unverified — hypothetical path |
| `config/credentials.yaml`, `config/secrets.json` | Unverified — hypothetical paths; no credential material was actually shown |
| hngh kernel file paths under `/home/bricker/Projects/etc/hngh` | Unverified — no kernel file was cited from direct reading |

### 2.3 Substantive output: proposed collection policy
The one deliverable this line *can* legitimately crystallize is the policy recommendation, since policy design rests on reasoning rather than on unverified repo contents. Proposed policy for **unknown-provenance Chinese-language repos entering hngh**:

1. **Quarantine by default.** Unknown-provenance repos enter a holding area, never the trusted corpus, until audit completes.
2. **Translation before ingestion.** All docs (README, `docs/`, inline comments with operational claims) must be machine-translated and spot-checked by a fluent reviewer before any content informs hngh behavior. Language opacity is itself a risk flag, not a neutral property.
3. **Three-gate audit** (the line's original targets, kept):
   - *Persona/behavior claims:* any documentation asserting that the component overrides identity, persona, or system instructions is a hard reject pending human review.
   - *Binary provenance:* any committed binary without a verifiable source and license is a hard reject. Hashes recorded; binaries rebuilt from source or excluded.
   - *Secret-shape scan:* committed config matching credential formats (keys, tokens, connection strings) triggers revocation advice to the upstream owner and exclusion of the file, regardless of whether the secret is live.
4. **Provenance scoring.** Attributable author history, signed commits, and a recognized license raise trust; anonymous single-commit dumps of mixed docs+binaries score lowest and require full manual audit.
5. **Ledger requirement.** Every audit records *what was actually read* (paths confirmed to exist) separately from *what was searched for and not found* — precisely the distinction this line's own record failed to maintain.

## 3. Recommendations

- **Adopt the policy above** as hngh's standing rule for unknown-provenance repos; it is the line's durable contribution.
- **Do not cite this line as evidence about bigeye's contents.** The record supports only "an audit was planned."
- If bigeye remains of interest, re-open as a **new line** whose first beat performs the translation and reports confirmed paths only.
- Amend the beat format so "Expected Findings" can never be misread as findings; require a `verified:` / `hypothesized:` split.

## 4. Open Threads

1. Actual translation and audit of bigeye's Chinese docs — never performed on record.
2. Empirical test of whether the persona-overwrite / unlicensed-binary / committed-credential triad is common in unknown-provenance repos (would sharpen gate thresholds).
3. Tooling for automated credential-format and binary-license scanning in the quarantine pipeline.
4. hngh kernel-side enforcement point for quarantine status (no kernel file has been confirmed as the integration point).

## 5. References

**Confirmed to exist (line's own records):**
- `research-lines.tsv` — line state ledger (cited in the task framing)
- Prior beat note 2026-09-12 on this line (reproduced in the task's prior material)

**Referenced but unverified — named for completeness, not cited as evidence:**
- `suanrongqieqiezi/bigeye`: `README.md`, `docs/zh_CN/`, `bin/`, `LICENSE`, `config/credentials.yaml`, `config/secrets.json` — all hypothetical paths from the prior beat's plan
- `/home/bricker/Projects/etc/hngh` — kernel repository named in the grounding instruction; no specific file within it was confirmed read during this line
- Prior-art vault pointers `[[sources/SRC-2026-08-18-007]]` and `[[sources/chartlibrary-io-developers-api]]` — listed in prior material; relevance to this line was never established on record and cannot be verified here
