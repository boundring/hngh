# Does the `hngh-automation` kernel tree contain any existing "sidecar" or metadata index files (e.g., `.meta`, `.index`) that are already used for segment tracking, which could be repurposed for hold markers?

Status: crystallized 2026-09-17 from research line `fail-20260917-Does-the-hngh-automation-kernel-tree-con`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260917-Does-the-hngh-automation-kernel-tree-con.md.

# Contracted record: `hngh-automation` sidecar / metadata-index reuse for hold markers

**Line:** Does the `hngh-automation` kernel tree contain any existing “sidecar” or metadata index files (e.g., `.meta`, `.index`) that are already used for segment tracking, which could be repurposed for hold markers?  
**Lifecycle state:** contracted  
**Disposition:** No verified existing sidecar or metadata-index file can be claimed from the supplied material. The line remains an open inventory-and-semantics question, not a confirmed design opportunity.

## Findings

1. **No verified kernel-side sidecar exists in the supplied evidence.**  
   The supplied transition material does not identify any concrete file under the stated `hngh` kernel repository root that is already used for segment tracking. No path is supplied demonstrating that a `.meta`, `.index`, `.state`, `.seg`, `.sidecar`, or similar file exists, is written by a known process, and is read for segment-state purposes.

2. **The only named metadata artifact is process-state metadata, not kernel-side segment metadata.**  
   The material names `research-lines.tsv` as the line-state file for this research process. That file is relevant to the research workflow, but it is not evidence that an existing `hngh-automation` sidecar or metadata index exists for segment tracking.

3. **“Repurposing” is currently unverified.**  
   Because no candidate file has been verified with a writer, reader, lifecycle, and invariants, it would be premature to treat repurposing an

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
