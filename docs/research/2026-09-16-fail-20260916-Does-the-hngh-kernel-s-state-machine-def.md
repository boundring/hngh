# Does the hngh kernel's state machine definition file explicitly list the valid states for `research-lines.tsv`, and does that list match the domain enumerated in R2 Step 2?

Status: crystallized 2026-09-16 from research line `fail-20260916-Does-the-hngh-kernel-s-state-machine-def`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-Does-the-hngh-kernel-s-state-machine-def.md.

# Contracted research record

**Line:** Does the hngh kernel’s state machine definition file explicitly list the valid states for `research-lines.tsv`, and does that list match the domain enumerated in R2 Step 2?  
**Lifecycle state:** contracting — crystallized as a contracted record  
**Answer status:** Not determinable from the supplied material. No grounded match or mismatch can be asserted.

## Findings

1. **This is a parity check, not a documentation lookup.**  
   The line requires three verified artifacts before it can be closed:
   - A concrete hngh kernel file that explicitly declares the valid states for `research-lines.tsv`.
   - The exact R2 Step 2 enumeration of the domain.
   - A direct comparison between those two enumerated sets.

2. **The supplied material identifies only the repository root and the line-state file name.**  
   It names the hngh kernel repository root as `/home/bricker/Projects/etc/hngh` and refers to `research-lines.tsv` as the line-state file. However, it does not verify a specific state-machine definition file path inside that repository, nor does it provide verified text from such a file.

3. **No verified R2 Step 2 enumeration is present in the supplied material.**  
   The phrase “R2 Step 2” is referenced as the source of an enumerated domain, but the supplied material does not quote or verify that enumeration. Without that text, there is no second set against which to compare any kernel-defined state list.

4. **Therefore, neither match nor mismatch can be claimed.**  
   The correct contracted position is that the parity claim remains unverified. It would be incorrect to record “the lists match” without the R2 Step 2 enumeration, and it would also be incorrect to record “the lists do not match” without both enumerated sets.

5. **Absence in the supplied material is not evidence of absence in the repository.**  
   The line cannot be closed as a negative finding merely because the state-machine file has not been identified here. A negative conclusion would require verified search or inspection evidence showing that no such explicit list exists, or that the relevant file does not contain one.

## Recommendations

1. **Locate the kernel state-machine definition file.**  
   Search `/home/bricker/Projects/etc/hngh` for files that define lifecycle states, valid states, state transitions, or references to `research-lines.tsv`. The target artifact should explicitly list the valid states for `research-lines.tsv`, not merely mention the filename.

2. **Extract the exact valid-state list.**  
   Once a candidate file is found, record:
   - the file path,
   - the exact enumerated states,
   - whether the enumeration is normative, descriptive, or incidental,
   - and any normalization rules that affect state names.

3. **Obtain the verified R2 Step 2 domain enumeration.**  
   Identify the repository file, process document, or prior research artifact that contains R2 Step 2. Extract the exact enumerated domain from that source. If no such source can be located, the line should remain open rather than being closed by inference.

4. **Compare the two sets directly.**  
   The comparison should be explicit and textual:
   - Does every state in the kernel file appear in R2 Step 2?
   - Does every item in R2 Step 2 appear in the kernel file?
   - Are there aliases, case differences, punctuation differences, or missing entries?

5. **Close only after one of these outcomes is verified:**
   - The lists match exactly.
   - The lists do not match, with a concrete diff.
   - No explicit kernel state-machine list exists for `research-lines.tsv`.
   - R2 Step 2 does not enumerate the relevant domain in a verifiable form.

## Open threads

- Does a state-machine definition file exist inside `/home/bricker/Projects/etc/hngh` that explicitly lists valid states for `research-lines.tsv`?
- If such a file exists, what is its exact path and enumeration?
- What is the exact R2 Step 2 enumeration of the domain?

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
