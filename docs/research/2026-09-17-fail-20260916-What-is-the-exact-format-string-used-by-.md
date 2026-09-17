# What is the exact format string used by the hngh OOM handler, as extracted from source via `grep -rn "Out of memory" /home/bricker/Projects/etc/hngh --include='*.c'`?

Status: crystallized 2026-09-17 from research line `fail-20260916-What-is-the-exact-format-string-used-by-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-What-is-the-exact-format-string-used-by-.md.

# Research Line Crystallization — FINAL RECORD

_line: exact format string used by the hngh OOM handler, per `grep -rn "Out of memory" [redacted path] --include='*.c'` | state: contracting → closed (UNRESOLVED)_

## Resolution Status

**UNRESOLVED — the core question was never answered by evidence, and this beat cannot change that.**

No beat in this line's history contains grep output. Beat 1 could not execute the command and substituted a training-data guess; Beat 2 correctly retracted it. This crystallization beat likewise has no filesystem or shell access to `[redacted path] so it can add no source-grounded content — only consolidate the record honestly. Closing unresolved is the correct terminal state under the line's own no-source-no-claim rule.

## Findings (grounded solely in the research record)

1. **No tool execution ever occurred.** Zero beats contain a command, exit code, or stdout. Therefore no format-string claim in this line has any evidentiary standing.
2. **One candidate string was proposed and retracted:**
   ```
   "Out of memory: Killed process %d (%s) total-vm:%lukB, anon-rss:%lukB, file-rss:%lukB\n"
   ```
   Status: **RETRACTED.** It resembles a mid-generation upstream-Linux OOM report (upstream variants have added/dropped fields across kernel versions), but that resemblance is training-data recollection — exactly the class of evidence this line disqualified. It must never be cited as an hngh string.
3. **Nothing about the target repository is verified** — not that the path exists, not that it is a kernel tree, not that it contains an OOM handler, not that any specific file within it exists. No path under `[redacted path] is citable.
4. **The line's durable output is methodological, not substantive:** the no-source-no-claim rule — a beat asserting a source-level fact must attach the actual tool result; otherwise it records `UNRESOLVED: tool unavailable` and stops. This rule is well-grounded: it was derived from a caught fabrication attempt documented within the line itself.

## Recommendations (final)

- **Close as `UNRESOLVED: tool unavailable`.** Reopen only on a host with the path mounted; first action on reopen is the verbatim grep.
- **Escalation order if zero hits:** search `"Killed process"`, then case-insensitive `oom`, then drop `--include='*.c'` (the handler may live in a header or non-C file).
- **Vault hygiene:** tag the retracted string above with a hazard/retracted marker so downstream notes cannot resurrect it as fact.
- **Automation gate:** any beat claiming a format string must attach grep exit code 0 plus non-empty stdout to the beat record — codifying finding 4 for the pipeline.

## Open Threads (for any successor line)

- Does `[redacted path] exist, and is it a full kernel tree, a toy kernel, or something else? Unverified.
- Does hngh's OOM handler use the literal "Out of memory" at all, and in a `.c` file? Unverified.
- Beat 2's recommendation 5 was truncated mid-sentence ("If hngh is confirmed to be a …"); recover the full text from the beat record before acting on it.
- Any eventual upstream-Linux comparison requires pinning a kernel version; none was ever pinned here.

## References

**Citable (present in the material supplied to this beat):**
- `research-lines.tsv` — the line's entry and state transitions (expanding → contracting → closed).
- Research beat 2026-09-17 (expanding → contracting) — origin of the retracted candidate string; contains no tool output.
- Research beat 2026-09-17 (contraction) — the retraction, the no-source-no-claim rule, and the automation-gating recommendation.

**Explicitly NOT citable (unverifiable from this beat):**
- Any file path under `[redacted path] — none has been confirmed to exist; zero paths are named.
- Upstream Linux `mm/oom_kill.c` — real in mainline Linux to the best of my training knowledge, but mentioned only as the putative origin of a retracted string; not verifiable in this environment and not an hngh artifact.
- The llm-wiki prior-art pointers (`[[sources/LES-fail-20260915-…]]`

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
