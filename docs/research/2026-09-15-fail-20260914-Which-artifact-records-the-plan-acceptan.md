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

## R1/R2 execution — host inspection (2026-10-07)

Executed on-host by the routed session for plan
`2026-09-15-routed-research-beat-injection-fail-20260914-Which-artifact-records-the-plan-acceptan`
(the adopted disposition's R1 obligation). The triggering alert was the
docfilter capture-side filter working as designed — injection signature(s)
in the unsloth Qwen3.8-27B-GGUF capture were redacted at write time; the
alert row has aged out of the report prune (no row for the identity remains
in `docs/project/reports.md` or `docs/project/report-bodies/`), and the
research-beat picker skips `reviewed` lines, so no future capture can
re-fire it for this subject.

### R1 — the artifact exists; two surfaces record the acceptance event

1. `hngh-automation/logs/acceptance.log` (ACCEPT_LOG default,
   `automation/scripts/accept-plans.py:67`): append-only event log, row
   shape `<UTC ts> | <verb> <slug> [<detail>]`. Observed rows for the run
   tag:
   - `2026-09-09T14:01:12Z | blocked 2026-09-09-stall-recovery-and-operator-surfaces kernel-gate-red-rc2` (repeated 14:31:12Z)
   - `2026-09-09T15:01:13Z | accepted 2026-09-09-stall-recovery-and-operator-surfaces 2026-09-09T15:01:13Z`
   - five further `blocked … step-1-no-verification` rows, 2026-09-10T00:00:18Z through 02:30:15Z
2. Plan-file front-matter comment
   (`docs/project/plans/2026-09-09-stall-recovery-and-operator-surfaces.plan.md`
   line 1): carries `accepted=2026-09-09T15:01:13Z` and the later disposal
   (`status=parked … cause=obsolete disposed=2026-09-27T01:46:59Z
   reason=superseded…`); no parse/override fields.

### R2 — representational-capacity verdict: FAILS

- The writer's whole verb set is `accepted <slug> <ts>`, `blocked <slug>
  <cause>`, `held <slug> <cause>`; the tokens `parse_pass` and
  `operator_override` appear nowhere in `automation/scripts/accept-plans.py`
  nor in any repo file (repo-wide search: zero hits outside research prose).
- No row kind represents "parse failed but operator overrode": an operator
  override is a hand-edit of the front-matter comment and leaves no
  acceptance.log row at all. `parse_pass=true` with `operator_override=true`
  collapses into the same single `accepted` row as a plain parse pass.
- One timestamp per event; no `override_ts` / `actor` / `rationale`
  fields; R2's minimum schema is unmet.
- The gap is visible on real data: the same plan was `accepted` at
  2026-09-09T15:01:13Z and then re-blocked `step-1-no-verification` five
  times on 2026-09-10 — the record alone cannot classify the 15:01:13Z
  event. O1 of sibling line
  `fail-20260910-overnight-plan-accept-blocked-2026-09-09-stall-recovery-and-operator-surfaces`
  stays open for the same reason.

**Answer:** the plan-acceptance event is recorded in
`hngh-automation/logs/acceptance.log` (plus the plan comment's
`accepted=<ts>`), and it does NOT distinguish `parse_pass` from
`operator_override`; the distinction is reconstructible only from git
history of the plan comment — prose/history, not structured fields. The
line's question is answered; R1 is discharged.
