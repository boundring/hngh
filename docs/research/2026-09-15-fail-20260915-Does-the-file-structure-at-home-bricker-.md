# Does the file structure at ~/Projects/etc/hngh contain a JSON or YAML record with keys `parse_pass` and `operator_override` for the run tag 2026-09-09-stall-recovery-and-operator-surfaces?

Status: crystallized 2026-09-15 from research line `fail-20260915-Does-the-file-structure-at-home-bricker-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-Does-the-file-structure-at-home-bricker-.md.

## Final Summary for Research Line: `parse_pass` / `operator_override` Record Existence for Run Tag `2026-09-09-stall-recovery-and-operator-surfaces`

### Findings

The research line has been contracted to actionable recommendations. No concrete evidence was found in prior material, and the model did not have access to the filesystem to verify the existence of the specified records. The following recommendations are based on the verification procedure outlined in R1.

### Recommendations

1. **Execute the Verification Pass:**
   - On any host with read access to `~/Projects/etc/hngh`, run the following command block to verify the existence of the `parse_pass` and `operator_override` keys for the run tag `2026-09-09-stall-recovery-and-operator-surfaces`:
     ```bash
     # 1. Locate candidate records by run tag
     find ~/Projects/etc/hngh -type f \
       \( -name '*.json' -o -name '*.yaml' -o -name '*.yml' \) \
       -print0 | xargs -0 grep -l '2026-09-09-stall-recovery-and-operator-surfaces' 2>/dev/null

     # 2. If any file is returned, check for the two keys
     grep -rE '"(parse_pass|operator_override)"\s*:' ~/Projects/etc/hngh --include='*.json' --include='*.yaml' --include='*.yml' -l

     # 3. Cross-reference: confirm both keys co-occur in the same document
     for f in $(grep -rl '2026-09-09-stall-recovery-and-operator-surfaces' ~/Projects/etc/hngh --include='*.json' --include='*.yaml' --include='*.yml' 2>/dev/null); do
       if grep -q '

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
