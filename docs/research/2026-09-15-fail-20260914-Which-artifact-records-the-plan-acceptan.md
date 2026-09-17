# Which artifact records the plan-acceptance event for 2026-09-09-stall-recovery-and-operator-surfaces, and does it distinguish parse_pass from operator override as R2 requires?

Status: crystallized 2026-09-15 from research line `fail-20260914-Which-artifact-records-the-plan-acceptan`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-Which-artifact-records-the-plan-acceptan.md.

# Contracted line record: `2026-09-09-stall-recovery-and-operator-surfaces` plan-acceptance artifact and R2 distinction

**Line:** Which artifact records the plan-acceptance event for `2026-09-09-stall-recovery-and-operator-surfaces`, and does it distinguish `parse_pass` from operator override as R2 requires?  
**Disposition at contraction:** Unresolved pending filesystem inspection. No named artifact can be asserted from the supplied material, and no R2 compliance claim can be made without inspecting a concrete structured record.

## Findings

1. **The line contains two distinct questions.**
   - **Existence:** Does an artifact exist that records the plan-acceptance event for the run tagged `2026-09-09-stall-recovery-and-operator-surfaces`?
   - **R2 distinction:** If such an artifact exists, does it encode `parse_pass` and `operator_override` as separate, auditable signals rather than one conflated acceptance boolean?

   These must not be collapsed. A parse log that says “plan passed structural checks” does not answer the R2 question by itself.

2. **No concrete acceptance artifact is established in the supplied material.**
   The prior beat identified a relevant prior-art pointer, `[[sources/hngh-2026-09-09-stall-lessons]]`, titled “Hngh stall lessons: model burn, acceptance parsing, orp.” That title indicates that acceptance parsing was discussed as a lesson, but it does not prove that a plan-acceptance event record exists for the run tag.

3. **The prior-art pointer is not sufficient evidence.**
   A source note about “acceptance parsing” may point toward the right area of investigation, but it is not itself an acceptance-event artifact. It may describe a process, a failure mode, or a lesson; it does not necessarily contain the event record for `2026-09-09-stall-recovery-and-operator-surfaces`.

4. **R2 compliance cannot be assessed from the supplied material.**
   R2 requires that the artifact make the distinction between automatic parse validation and operator override visible without reading prose. The minimum test is:
   - `parse_pass` can be true while `operator_override` is false.
   - `parse_pass` can be false while `operator_override` is true.
   - The two events have separate timestamps or equivalent temporal markers.
   - A single field such as `accepted: true` is insufficient, because it cannot represent “parse failed but operator overrode” or “parse passed but operator rejected.”

5. **The decisive next step is inspection, not further conceptual expansion.**
   The line cannot be resolved by title inference alone. It requires inspecting the hngh kernel repository at `~/Projects/etc/hngh` and the relevant hngh-automation working tree for files or structured rows tied to the run tag `2026-09-09-stall-recovery-and-operator-surfaces`.

6. **No external source is used or verified here.**
   The only prior-art material relied on is the supplied llm-wiki pointer and prior beat text. I cannot verify any external source, and no external claim is made.

## Recommendations

### R1 — Execute the filesystem inspection before closing the line

Run at minimum:

```sh
ls -la ~/Projects/etc/hngh
find ~/Projects/etc/hngh -type f \
  \( -name "*stall*" -o -name "*recovery*" -o -name "*operator*" \
     -o -name "*acceptance*" -o -name "*plan-accept*" \) 2>/dev/null
grep -rl "2026-09-09-stall-recovery" ~/Projects/etc/hngh \
  --include="*.md" --include="*.json" --include="*.yaml" \
  --include="*.tsv" --include="*.log" 2>/dev/null
```

Then run the equivalent search in the current hngh-automation working tree. Record the output, including negative results. A beat that cannot execute shell must hand off to a host that can; it must not substitute assumed conventions for observed filesystem state.

### R2 — Apply the R2 compliance test mechanically

If an artifact is found, check whether it contains at least two independently settable fields or equivalent structured keys, such as:

```text
run_tag = 2026-09-09-stall-recovery-and-operator-surfaces
parse_pass = true | false
operator_override = true | false
parse_ts = <timestamp or null>
override_ts = <timestamp or null>
actor = <operator identity, if present>
rationale = <short reason, if present>
source_pointer = <link to prior-art or command output, if present>
```

The artifact fails R2 if it only has a single acceptance boolean. It also fails if the distinction is only visible in prose and not in structured fields or column names.

### R3 — Keep the stall-lessons source separate from the acceptance artifact

`[[sources/hngh-2026-09-09-stall-lessons]]` may be useful as a pointer, but it should not be treated as the plan-acceptance event record unless inspection shows that it contains the required structured fields for the run tag.

### R4 — If no artifact exists, record the negative result durably

If inspection finds no plan-acceptance event record,

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
