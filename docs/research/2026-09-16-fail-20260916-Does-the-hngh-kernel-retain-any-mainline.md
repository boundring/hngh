# Does the hngh kernel retain any mainline `mm/oom_kill.c` code paths, and if so, are they reachable in the build configuration?

Status: crystallized 2026-09-16 from research line `fail-20260916-Does-the-hngh-kernel-retain-any-mainline`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-Does-the-hngh-kernel-retain-any-mainline.md.

# Crystallized Research Line: `mm/oom_kill.c` Retention & Reachability in hngh

**Line:** Does the hngh kernel retain any mainline `mm/oom_kill.c` code paths, and if so, are they reachable in the build configuration?
**State transition:** contracting → **crystallized** (final record)
**Distillation basis:** research beat 2026-09-16 (planned→expanding, unsloth:unsloth/Qwen3.8-27B-GGUF); prior art vault entries listed below.

---

## Findings

### F1 — No verified findings exist for this line.

As of crystallization, **zero empirical claims about the hngh tree have been confirmed or refuted.** The prior beat (2026-09-16) established three methodologically sound investigation angles—source presence, build-gate reachability, and runtime interception—but could not execute any inspection against `~/Projects/etc/hngh` because the research host lacked read access to that path. Every hypothesis generated in that beat (file present, file split across multiple files, file stubbed, file absent) remains unadjudicated.

This is recorded explicitly so that no downstream consumer of this line mistakes the *absence of evidence* for *evidence of absence*. The question is well-formed; the investigation protocol is bounded and executable; but the hngh tree has not been observed.

### F2 — The investigation protocol is complete and single-pass.

The prior beat produced a four-stage checklist (R1–R4 below) that, when executed on any host with read access to the kernel tree, resolves the line in one pass. No further methodological design work is required. The line's remaining cost is purely *access*: it needs one shell session against the tree.

### F3 — The question has a well-defined decision boundary.

The two sub-questions decompose cleanly:

| Sub-question | Resolved by | Outcome if resolved |
|---|---|---|
| Is mainline `mm/oom_kill.c` source retained? | R1 (file-presence probe) | PRESENT → proceed to R2; ABSENT → line closes, see F4 |
| Is the code reachable in the build configuration? | R2 (Kconfig/Makefile) + R3 (symbol table) | Unconditional `obj-y` or no Kconfig gate → always linked; conditional → depends on defconfig; absent from symbol table → not in final image |

A third, softer sub-question—*is the code path shadowed at runtime by a custom hngh handler?*—is resolved by R4 and does not change the build-reachability answer but affects operational reachability.

### F4 — If `mm/oom_kill.c` is absent, the line's question mutates.

The original question presumes mainline OOM-kill code *might* be retained. If R1 returns ABSENT, the correct follow-up is not "no" to the original question but a *new* question: **what OOM behaviour does hngh implement, and where?** Candidates include custom allocator-failure hooks in `mm/` or `arch/`, renamed or restructured files (e.g., an `oom/` subdirectory), or inherited behaviour from a non-mainline base. This is recorded as an open thread, not a finding, because it has not been investigated.

---

## Recommendations

These are the bounded, executable actions for hngh-automation on an idle host with read access to `~/Projects/etc/hngh`. They are ordered by dependency; each stage gates the next.

### R1 — File-presence probe (gate)

```bash
for f in mm/oom_kill.c mm/oom_v2.c mm/vmscan.c; do
  test -f "~/Projects/etc/hngh/$f" && echo "PRESENT $f" || echo "ABSENT  $f"
done
```

**Decision:** ABSENT for `mm/oom_kill.c` → line closes per F4. PRESENT → proceed to R2. The inclusion of `mm/oom_v2.c` and `mm/vmscan.c` is diagnostic: their presence or absence alongside `oom_kill.c` indicates whether the OOM subsystem was pruned wholesale or selectively.

**Honesty note:** I cannot assert whether any of these files exist in the hngh tree. The prior beat hypothesised presence, splitting, stubbing, and absence; none is confirmed. This probe is the first observation.

### R2 — Build-gate inspection (Kconfig + Makefile)

```bash
# 1. Is the object unconditionally compiled?
grep -n 'oom_kill' ~/Projects/etc/hngh/mm/Makefile

# 2. Is there a Kconfig gate?
grep -rn 'OOM_KILL\|oom_kill' \
  ~/Projects/etc/hngh/mm/Kconfig \
  ~/Projects/etc/hngh/init/Kconfig 2>/dev/null

# 3. What does the active .config say? (if a build tree exists)
grep -E '^CONFIG_OOM_KILL' ~/Projects/etc/hngh/.config 2>/dev/null \
  || grep -E '^CONFIG_OOM_KILL' \
     ~/Projects/etc/hngh/arch/x86/configs/*defconfig 2>/dev/null
```

**Decision rule:**
- `obj-y += oom_kill.o` (unconditional) with no Kconfig symbol → always linked. Reachability: **yes, unconditionally.**
- `obj-$(CONFIG_…) += oom_kill.o` → reachability depends on the defconfig or `.config`. Record which configuration is active and whether the symbol is set.
- No match in `mm/Makefile` → the object is not compiled from that directory; check for a renamed or relocated source file before concluding absence.

### R3 — Symbol-table confirmation (post-build)

```bash
SYMFILE=$(find ~/Projects/etc/hngh -maxdepth 2 \
  \( -name 'vmlinux' -o -name 'System.map' \) | head -1)
if [ -n "$SYMFILE" ]; then
  grep -E ' (T|t|U) oom_kill_process$| (T|t|U) out_of_memory$| (T|t|U) __oom_kill_process$' \
    "$SYMFILE"
fi
```

**Interpretation:** `T`/`t` = defined in this binary (reachable). `U` = undefined reference (linked from elsewhere or dead). Absence of all three symbols = the code path is not in the final image regardless of source presence. This is the strongest single artefact for the reachability sub-question and supersedes R2 if a built image exists.

### R4 — Runtime-interception check (custom OOM handler)

Execute only if R1–R3 show mainline code *is* present and linked:

```bash
grep -rn 'out_of_memory\|oom_kill_process\|__alloc_pages.*__GFP_NORETRY' \
  ~/Projects/etc/hngh/mm/ --include='*.c' --include='*.h'
```

**Purpose:** Identify whether hngh-specific allocation-failure hooks pre-empt the mainline `out_of_memory()` path. If a custom handler intercepts before the mainline OOM killer is invoked, the code is *linked but operationally unreachable*—a distinction that matters for security and reliability analysis even if the build-reachability answer is "yes."

**Honesty note:** I cannot verify whether such hooks exist in the hngh tree. This check is included because the prior beat identified runtime interception as a distinct angle from build reachability, and the question's phrasing ("reachable in the build configuration") does not exclude operational shadowing.

### Execution protocol for hngh-automation

1. Run R1. If ABSENT → report and close (see F4).
2. If PRESENT → run R2. Record the Makefile line, Kconfig symbol (if any), and active `.config` value.
3. If a built image exists → run R3. Record symbol-table entries.
4. Run R4. Record any custom hooks found.
5. Report all four stages in one pass. The line's answer is the conjunction of these observations.

---

## Open Threads

### OT1 — Primary: execution of R1–R4.

The entire question remains open pending a single shell session against `~/Projects/etc/hngh` on a host with read access. No further design work is needed. This thread reopens the line if and when that observation is made.

### OT2 — Secondary: OOM behaviour in the absence of mainline source.

If R1 returns ABSENT for `mm/oom_kill.c`, the question mutates per F4. The new question—"what OOM behaviour does hngh implement, and where?"—requires a different investigation (searching `mm/`, `arch/`, and any custom directories for allocation-failure handling). This is a *new* line, not a continuation of this one, and should be opened separately if R1 confirms absence.

### OT3 — Tertiary: operational vs. build reachability.

Even if R2/R3 confirm the code is linked, R4 may reveal that hngh's custom allocation-failure handling pre-empts the mainline path. In that case, the answer to "are they reachable in the build configuration?" is **yes** (the code is in the image), but the operationally meaningful answer is **no** (the path is shadowed at runtime). This distinction should be recorded in any downstream security or reliability assessment that consumes this line's result.

### OT4 — Quaternary: base-kernel provenance.

The prior art entry `[[entities/hngh]]` ("Hngh Agent Kernel") and `[[sources/SRC-2026-08-18-003]]` ("Hngh Crystallized Rebuild Roadmap") are referenced in the vault but their content was not available to this crystallization. If hngh's base kernel is a specific mainline release (e.g., 5.x, 6.x), the expected state of `mm/oom_kill.c` differs by version (the file was restructured in some releases; `mm/oom_v2.c` appeared in others). Without knowing the base, R1's ABSENT result is ambiguous between "pruned by hngh" and "never present in this base." This thread is open pending access to the rebuild roadmap or a `Kconfig` header identifying the base version.

---

## Line Disposition

**Status:** Crystallized. The line's lasting record is this document. It will not be reopened unless R1–R4 are executed and the observations contradict or refine the decision rules above, or unless OT2/OT3/OT4 produce new evidence that changes the answer.

**Answer as of crystallization:** *Unknown.* The question is well-formed, the protocol is complete, but no observation has been made. The line's value to downstream consumers is its bounded, single-pass investigation protocol (R1–R4) and its explicit decision rules, not a resolved finding.

---

## References

The following are the concrete references grounding this crystallization. File paths under `~/Projects/etc/hngh/` are cited as **expected locations in a Linux-derived kernel tree**, not as confirmed-present files; their existence is the subject

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
