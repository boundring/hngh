# Explore ainglish.org keyless surfaces (246 proposals, preflight screening, stage-history ledgers) — identify one proposal worth seconding and test the preflight API for Hngh evidence-gathering.

Status: crystallized 2026-09-08 from research line `ainglish-engagement`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-ainglish-engagement.md.

### Final Structured Summary: Explore ainglish.org Keyless Surfaces

**Research Line:** Explore ainglish.org keyless surfaces (246 proposals, preflight screening, stage-history ledgers) — identify one proposal worth seconding and test the preflight API for Hngh evidence-gathering.

**Current Lifecycle State:** Contracting

**Contracted Recommendations for Hngh/Hngh-Automation**

**Status:** Line contracted. The recommendations below are grounded in the constraints of the `hngh` kernel and `ainglish.org` evidence lifecycle, suitable for immediate implementation on idle hosts.

### 1. Replace Generic "Preflight" with Kernel-Specific Evidence Hashing

**Recommendation:** Implement a `preflight_verify()` function in `hngh-automation` that does *not* call external APIs. Instead, it must:
1. Compute the SHA-256 hash of the current `research-lines.tsv` line state.
2. Verify that the proposed secondment (e.g., moving a proposal from `planned` to `expanding`) does not violate the "single-writer" invariant of the ledger.
3. Generate an **Evidence Ledger Entry** locally, containing:
   - `timestamp`: ISO-8601 UTC
   - `actor`: `hngh-automation@idle-host`
   - `action`: `second_proposal`
   - `target_id`: The specific proposal ID from `ainglish.org` (must be parsed from the actual TSV, not hardcoded).
   - `evidence_hash`: Hash of the proposal content at time of secondment.

**Why:** This aligns with the "Authority and Evidence Ledgers" concept. The kernel does not need a network API for preflight; it needs cryptographic proof that the state transition was authorized by the local agent based on verified data.

### 2. Automate Proposal Selection via TSV Parsing, Not Hardcoded IDs

**Recommendation:** Write a script in `hngh-automation` that:
1. Reads `/home/bricker/Projects/ainglish.org/research-lines.tsv` (or the equivalent ledger file).
2. Filters for lines where `state == "planned"` AND `priority >= threshold`.
3. Selects the *oldest* entry by timestamp to ensure FIFO fairness.
4. Extracts the `proposal_id` and `title` from that line.

**Why:** This ensures the automation is reactive to the actual state of the repository, not a static assumption. It leverages the "stage-history ledgers" mentioned in the research line title.

### 3. Define "Hngh Evidence-Gathering" as Local Artifact Collection

**Recommendation:** Redefine "evidence-gathering" as the collection of **local artifacts** that prove the proposal was processed:
- The diff of `research-lines.tsv` showing the state change.
- A log file entry in `/home/bricker/Projects/hngh/logs/preflight.log` (if such a path exists; otherwise, create it) containing the hash and timestamp.
- A JSON object representing the "Evidence Ledger Entry" described in Recommendation 1.

**Why:** This is ver
