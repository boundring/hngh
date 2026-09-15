# Do host-level telemetry outside the line record (sysstat/sar archives, journald OOM-killer entries, cron logs) survive for the 2026-09-12 window, allowing retroactive defect-vs-transient classification without waiting for a controlled retes

Status: crystallized 2026-09-15 from research line `fail-20260914-Do-host-level-telemetry-outside-the-line`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-Do-host-level-telemetry-outside-the-line.md.

# Crystallized Record: Host-Level Telemetry Survival for the 2026-09-12 Window

**Line:** Do host-level telemetry outside the line record (sysstat/sar archives, journald OOM-killer entries, cron logs) survive for the 2026-09-12 window, allowing retroactive defect-vs-transient classification without waiting for a controlled retest?
**Lifecycle:** expanding → **contracted (final)**
**Lasting record — this document supersedes the 2026-09-15 beat for citation purposes.**

---

## 1. Findings

**F1. The line produced a protocol, not a verdict.** The core deliverable of this line is a three-class probe-and-classify procedure (§3 below). No *survives / pruned* verdicts for any host were recorded in the line record (`research-lines.tsv`) before contraction. The retroactive-classification question is therefore **formally unresolved** — the line closes with a defined procedure and an unanswered empirical question, not with a classification of the 2026-09-12 window.

**F2. Structural asymmetry across telemetry classes was established by reasoning, not by host inspection.** The three classes have different survival risk profiles:

- **journald OOM entries** are the highest-risk class: if the test hosts are provisioned with journald's default volatile storage, this class is *structurally absent* rather than merely rotated, and no probe can recover it. Whether the hngh-automation harness provisions persistent journald could not be verified from this line; the provisioning templates were not located or read.
- **sysstat/sar archives** depend on naming convention (`saYYYYMMDD` on sysstat ≥ 11, `saDD` on older) and on rotation policy, both host-local. Their survival is an empirical question per host.
- **cron logs** (Debian/Ubuntu `/var/log/cron*`, RHEL-family date-format variants) typically survive several rotation cycles, making them the most likely class to persist — but this is a general-systems expectation, not a verified property of any specific host in scope. Flag as unverified.

**F3. An evidentiary bar for defect-vs-transient classification was adopted from prior art.** The classification protocol borrows the evidence-level semantics from SRC-2026-08-24-011 (MisakaNet Trust Semantics): a *defect* claim requires reproducible, in-band kernel-log correlation; a *transient* claim requires absence of the fault signature across all surviving telemetry plus a plausible external cause. This bar is defined but was never applied to real data on this line.

**F4. A kernel-source dependency was identified but not verified.** The defect indicator hinges on log signatures emitted by the OOM-killer path — in a mainline-derived layout, `mm/oom_kill.c` (`oom_kill_process()`, `oom_reaper`). The line explicitly recorded that it **cannot verify** whether `~/Projects/etc/hngh/mm/oom_kill.c` exists unmodified or whether hngh restructures this path. Any future application of the protocol must first confirm the OOM-path source file in the hngh tree and adjust grep patterns accordingly.

## 2. What this line did *not* establish (honesty boundary)

- No host was probed; no survival verdicts exist. Any future claim that "telemetry survived" or "was pruned" for 2026-09-12 is **not** supported by this line.
- The hngh-automation provisioning templates were not read; claims about ephemeral containers, volatile journald, or sar configuration on test hosts remain hypotheses.
- Kernel source paths in the hngh tree are inferred from mainline convention and are unverified.
- The prior-art vault sources cited (SRC-2026-08-24-006, -011, -025; obs-2026-08-25-…) are read-only pointers outside the two in-scope repositories; their contents were taken as given by the prior beat and are not independently verified here.
- The prior beat was truncated at ~4000 bytes in the line record; sections 2b–end (cron/sar classification detail and any closing threads) are partially reconstructed in this crystallization and may lose nuance from the original.

## 3. Recommendations (the line's actionable residue)

**R1. Run the probe table immediately on every host active during the window.** One probe per class, binary verdict per host, recorded in `research-lines.tsv` or a child note:

| Class | Probe (as root) | Survives if |
|---|---|---|
| sysstat/sar | `ls -l /var/log/sa/sa20260912* 2>/dev/null; ls -l /var/log/sa/sa12 2>/dev/null` | A non-empty file covering the 12th exists (either naming scheme) |
| journald OOM | `journalctl --since "2026-09-12 00:00" --until "2026-09-13 00:00" -t oom_kill -o short-precise \| head -40`; also `journalctl --disk-usage` and check `Storage=` in `journald.conf` | ≥ 1 line, **or** persistent storage confirmed with the window inside retention |
| cron logs | `zgrep -l "2026-09-12" /var/log/cron*` (Debian/Ubuntu) or `grep -c "Sep 12" /var/log/cron-*` (RHEL-family) | ≥ 1 matching line |

**R2. Apply the per-class fallback rule.** If all three classes are pruned on every candidate host → close the question permanently and **execute a controlled retest** with telemetry capture designed in advance (persistent journald, sysstat enabled, cron logging verified at provisioning time). Do not spend further effort on retroactive classification.

**R3. If ≥ 1 class survives on ≥ 1 host, classify per the SRC-2026-08-24-011 evidence bar:**
- *Defect:* `oom_kill` entry where the killed process is an hngh test-runner or module-load path, **and** preceding kernel log shows an allocation-failure trace (`page allocation failure`, `slab: Unable to allocate`) attributable to hngh kernel code — **only after** verifying the OOM-path source in the hngh tree (see F4).
- *Transient:* OOM or gap where the killed process is a co-tenant workload, a host reboot boundary, or where no hngh-attributable signature appears in any surviving class for the window.

**R4. Make future windows self-describing.** The strongest lesson of this line: the classification question should never need retroactive archaeology. Recommend the hngh-automation harness persist journald (`Storage=persistent`), enable sysstat collection, and snapshot `/var/log/sa/`, journald OOM entries, and cron logs into the line record at run time. This converts the entire question class from "does telemetry survive?" to "read the record." This recommendation is grounded in the harness's role as provisioner but its implementation location in the automation tree is unverified.

## 4. Open Threads (handoff to future lines)

1. **OT-1 — Verdict execution:** Run R1 and record per-host verdicts. Time-sensitive; each day of delay degrades sar/cron survival odds. If this thread is picked up after ~2026-09-19 (7 days post-window), assume cron/sar marginal and journald (if volatile) gone.
2. **OT-2 — Provisioning audit:** Locate and read the hngh-automation provisioning templates; determine `Storage=` for journald, sysstat enablement, cron logging, and whether hosts are ephemeral. This resolves F2 from hypothesis to fact.
3. **OT-3 — Kernel OOM-path confirmation:** Verify the OOM-killer source path in `~/Projects/etc/hngh` (mainline-expected: `mm/oom_kill.c`); record the actual log-format strings the hngh kernel emits so future grep patterns are grounded, not assumed.
4. **OT-4 — Harness-level telemetry capture (from R4):** If adopted, this thread supersedes OT-1/OT-2 as the durable fix.
5. **OT-5 — Line-record truncation:** The 2026-09-15 beat's tail was truncated in the record; if the untruncated original exists elsewhere (host logs, editor backups), reconcile against §2's honesty boundary.

---

## References

- `research-lines.tsv` — line state record (this repository; existence asserted by the line state header).
- `~/Projects/etc/hngh` — hngh kernel repository (in scope; specific internal paths **not** verified, see F4/OT-3).
- `~/Projects/etc/hngh/mm/oom_kill.c` — *expected* OOM-killer path per mainline convention; **unverified**, flagged throughout.
- hngh-automation tree — referenced by the prior beat; specific provisioning-template paths not identified or verified.
- [[sources/SRC-2026-08-24-011]] — MisakaNet Trust Semantics: Evidence Levels and Lesson Verification (evidentiary bar; llm-wiki vault, read-only, contents not re-verified).
- [[sources/SRC-2026-08-24-006]] — SLSA Supply Chain Levels (vault pointer; not directly load-bearing for this line's findings).
- [[sources/SRC-2026-08-24-025]] — Hngh Prior-Art Landscape Record (vault pointer).
- [[sources/obs-2026-08-25-post-rung-11-documentation-refresh-attribution-record-and-au]] — Observation note (vault pointer; title truncated in source record).
- Prior beat: "research beat 2026-09-15" (model unsloth:unsloth/Qwen3.8-27B-GGUF, wall_s 126.0) — truncated at ~4000 bytes in the line record.

**Crystallization note:** This record deliberately closes the line *without* a telemetry-survival verdict. The line's lasting contribution is the probe-and-classify protocol (§3) plus an explicit map of what remains unverified (§2, §4). Future lines should cite this document rather than the truncated 2026-09-15 beat.
