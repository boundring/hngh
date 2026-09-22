# Does the `research-lines.tsv` schema currently include any fields for version pinning (e.g., commit hash, content hash) or timestamps that would allow deterministic stale detection?

Status: crystallized 2026-09-22 from research line `fail-20260922-Does-the-research-lines-tsv-schema-curre`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260922-Does-the-research-lines-tsv-schema-curre.md.

# Contracting Summary: `research-lines.tsv` Schema — Version Pinning & Deterministic Stale Detection

**Line:** Does the `research-lines.tsv` schema currently include any fields for version pinning (e.g., commit hash, content hash) or timestamps that would allow deterministic stale detection?
**State:** contracting → contracted
**Prior beat:** 2026-09-22 (expanding → contracting), model `unsloth:unsloth/Qwen3.8-27B-GGUF`, wall_s 184.0

---

## Findings

### What is verified

1. **The file exists as a line-state store.** The prompt context itself designates `research-lines.tsv` as the line state for this research process. Its TSV format is corroborated by the vault entry `[[sources/grep-tab-escape-matches-nothing]]`, which documents that GNU grep treats `\t` as a stray escape and recommends `awk -F'\t'` for tab-separated files — consistent with a `.tsv` extension.

2. **A prior attempt at this exact question failed.** The vault contains `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]`, a research lesson whose filename encodes the same question and is tagged `fail`. This indicates the question was previously engaged and did not reach a grounded resolution.

3. **Time-based detection has a known correctness hazard in this ecosystem.** The vault entry `[[sources/timezone-local-vs-utc-rendering-fabricates-missing-commits]]` documents that local-time git date display fabricates missing commits. If `research-lines.tsv` carries any timestamp columns, their determinism depends on whether they are stored and compared in UTC rather than host-local time. This is not a hypothetical concern; it is a documented bug class in the hngh environment.

4. **The prior expanding beat did not inspect the file.** The 2026-09-22 beat explicitly labels its schema analysis as *"Hypothetical Inspection (based on standard `hngh-automation` patterns)"* and states: *"Since I am an AI model in a simulation/analysis context without direct shell access to the user's live filesystem in this specific prompt turn, I must rely on the 'Prior material' and standard repository conventions."* The field list it produces (`id`, `title`, `state`, `created_at`, `updated_at`, `last_beat`, `model`, `wall_s`) is therefore an inference, not an observation. No claim in that beat about the presence or absence of specific columns is grounded in a file read.

### What remains unverified

- **The actual column headers of `research-lines.tsv`.** No beat in this line's history has recorded a `head -1` or equivalent inspection of the real file. The prior beat's schema list is explicitly hypothetical.
- **Whether version-pinning columns exist.** Neither the prior beat nor any vault entry I can cite confirms or denies the presence of `commit_hash`, `git_ref`, `content_hash`, or analogous fields.
- **The internal structure of the hngh kernel repository at `[redacted path] The prompt names this path, but I have not read files within it in this line's history. I cannot cite specific file paths inside that repository with confidence.
- **The exact filesystem location of `research-lines.tsv` within the automation repository.** The prior beat references "hngh/hngh-automation" as a repository name but does not record a verified absolute path to the TSV file.

### What can be said about deterministic stale detection *in principle*

Given the two axes the question names:

| Mechanism | Determinism condition | Status in this line |
|---|---|---|
| Timestamp-based (`now − last_beat > T`) | Clock source must be UTC; all hosts must agree on "now" | Unverified. The timezone prior art shows local-time rendering has caused fabricated gaps, so any timestamp column must be confirmed as UTC before it can support deterministic detection. |
| Content-hash-based (`hash(prior_material) ≠ stored_hash`) | Hash function and input scope must be fixed | No evidence in this line's history that such a column exists or is computed. |
| Commit-pin-based (`HEAD ≠ pinned_commit`) | Pin must reference a specific repository and ref | No evidence in this line's history that such a column exists. |

None of these three mechanisms can be confirmed as currently implemented based on the material available to this line.

---

## Recommendations

1. **Read the header row.** The single highest-value action is:
   ```bash
   awk -F'\t' 'NR==1 {for(i=1;i<=NF;i++) print i": "$i}' <path-to-research-lines.tsv>
   ```
   This yields the exact column names and count. It resolves or eliminates every open question in this line in one command. (Use `awk -F'\t'` per the guidance in `[[sources/grep-tab-escape-matches-nothing]]`; do not use `grep -P '\t'`.)

2. **If timestamp columns exist, verify their format and timezone.** Check whether values are RFC 3339 / ISO 8601 with an explicit `Z` or offset, or bare local time. The prior art

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
