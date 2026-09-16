# If R1 confirms 1 surviving class on 1 host, does the OOM-killer log signature in the hngh kernel match mainline `mm/oom_kill.c` format strings, or has the path been restructured such that the R3 grep patterns require modification?

Status: crystallized 2026-09-16 from research line `fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho.md.

# Research Line Contraction: OOM-Killer Log Signature in hngh Kernel

**Line:** If R1 confirms 1 surviving class on 1 host, does the OOM-killer log signature in the hngh kernel match mainline `mm/oom_kill.c` format strings, or has the path been restructured such that the R3 grep patterns require modification?
**Lifecycle state:** contracting (final structured summary)

## Findings

The central question of this line—whether the OOM-killer log signature in the hngh kernel matches mainline `mm/oom_kill.c` format strings, or whether the path has been restructured such that R3 grep patterns require modification—**remains unresolved**. No claim about the hngh-side state is citable from this repository or the prior material.

1. **Mainline side (established as external fact, not re-verified in-environment):** In mainline Linux, OOM-kill logging resides in `mm/oom_kill.c`, emitted via `dump_header()` / `oom_kill_process()`, with the canonical signature `"Out of memory: Killed process %d (%s) total-vm:%lukB, anon-rss:%lukB, file-rss:%lukB..."`. This is a well-known property of the Linux kernel source tree. I did not re-verify it against any local copy in this session; it is asserted as external lore only.

2. **hngh side (not established):** The prior beat's suggestion that `mm/oom_kill.c` is absent from `/home/bricker/Projects/etc/hngh` and that OOM handling was moved to `kernel/hngh/oom_handler.c` or `drivers/hngh/oom.c` was explicitly hedged ("I cannot confidently cite the exact path"). No tool access was available in the prior session to run a confirming `find`, so **no hngh file path is citable at this time**. I will not assert that any specific hngh OOM source file exists.

3. **Hypothesized signature is invented and must not propagate:** The string `"HN-GH OOM: Killed process %d (%s) [agent_id=%d]..."` appearing in the prior material is a fabrication, not an observation. It carries no evidentiary weight and must not enter hngh-automation grep patterns, runbooks, or wiki notes as if observed.

4. **The line's answer is therefore: unknown pending a two-command verification.** The durable output of this line is a verification procedure plus conditional recommendations—not a rewritten pattern set. Shipping pattern changes now would be lore-driven and risks the exact silent-failure mode the line exists to prevent.

5. **Failure-mode coupling (from prior art):** Per [[sources/grep-tab-escape-matches-nothing]], when harvested logs or the pattern table are TSV-formatted, GNU grep `\t` escapes silently match nothing; `awk -F'\t'` is required. A silent non-match on an hngh host is indistinguishable from "no OOM events," which is precisely the ambiguity this line targets. Per [[sources/supervision-must-be-hngh-native]], log-based supervision of an hngh host is only trustworthy if patterns are derived from the hngh kernel actually running, not from mainline assumptions.

## Recommendations

**R-A. Verify before modifying. Do not ship pattern changes based on hypothesized signatures.**
On an idle host with the hngh tree mounted:
```sh
find /home/bricker/Projects/etc/hngh -name 'oom_kill.c' -o -name '*oom*' -type f
grep -rn "Out of memory: Killed process" /home/bricker/Projects/etc/hngh --include='*.c'
```
- If the second grep hits, the mainline format string survives somewhere in the tree; confirm the hit is reachable (not dead code or a vendored reference copy) before concluding R3 patterns are still valid.
- If it misses, locate the replacement `printk`/log call and extract the literal format string from source—never guess it.

**R-B. Make R3 patterns source-derived, not lore-derived.**
Whatever string R-A surfaces, generate the R3 log-scan pattern mechanically from kernel source: extract the format literal, escape it for the target matcher, and anchor on its stable prefix. Where the pattern table or harvested logs are TSV-formatted, use `awk -F'\t'` rather than GNU grep `\t` escapes (see [[sources/grep-tab-escape-matches-nothing]]).

**R-C. Distinguish "no match" from "no events" in automation.**
Until R-A is resolved, any R3 report of zero OOM kills on an hngh host is ambiguous: it may mean the patterns are stale. hngh-automation should emit an explicit "pattern unverified against running kernel" warning rather than a clean zero. This aligns with [[sources/supervision-must-be-hngh-native]].

**R-D. Do not cite invented paths.**
Any future beat on this line that names a specific hngh OOM source file must attach the `find`/`grep` output that produced it. Absent that, the path is hypothesis and must be labeled as such.

## Open Threads

- **hngh-side verification (blocking):** The two-command procedure in R-A has not been run in any session of this line. Until it is, the line's answer is "unknown." This is the single open thread; everything else is conditional on it.
- **Reachability of a mainline-string hit:** If R-A's grep hits, a follow-up question arises—whether the hit is live code or a vendored/dead reference copy. That sub-question is not yet scoped and should be opened as its own line if it materializes.
- **R1 coupling:** The line's framing ("If R1 confirms 1 surviving class on 1 host") presupposes an R1 result that this repository does not contain. I cannot verify R1's status from here; the OOM-signature question is answerable independently of R1, and the contraction above treats it as such. If R1's outcome constrains which hosts are in scope for R-A, that constraint must be supplied by the R1 line, not assumed here.
- **External mainline claim:** The mainline `mm/oom_kill.c` signature is asserted from external knowledge and was not re-verified against a local tree in this session. If a future beat requires it as load-bearing rather than contextual, it should be verified against the actual mainline source available on the host.

## References

- `/home/bricker/Projects/etc/hngh` — hngh kernel repository root (path referenced by prior material; no specific file within it is citable from this session)
- `mm/oom_kill.c` — mainline Linux OOM-killer source (external reference; not verified in-environment)
- [[sources/grep-tab-escape-matches-nothing]] — GNU grep `\t` escape failure mode; use `awk -F'\t'` for TSV data
- [[sources/supervision-must-be-hngh-native]] — supervision patterns must be derived from the running hngh kernel, not mainline assumptions
- [[entities/hngh]] — Hngh Agent Kernel entity pointer (no file-path claims drawn from it in this contraction)
- [[sources/SRC-2026-08-24-034]] — OSV schema reference (noted as prior art; not load-bearing for this line's findings)
