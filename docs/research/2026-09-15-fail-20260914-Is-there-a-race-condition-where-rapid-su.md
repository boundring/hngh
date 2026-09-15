# Is there a race condition where rapid successive clicks on "mark read" trigger an idempotency guard that silently drops subsequent writes?

Status: crystallized 2026-09-15 from research line `fail-20260914-Is-there-a-race-condition-where-rapid-su`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-Is-there-a-race-condition-where-rapid-su.md.

# Contracted Research Line — Final Record

_line: Is there a race condition where rapid successive clicks on "mark read" trigger an idempotency guard that silently drops subsequent writes? | state: contracting → contracted_

**Verdict: UNRESOLVED — plausible mechanism, never grounded in code.** The line closes without confirmation or refutation. Across both the prior beat (2026-09-15) and this transition, the mark-read write path in the hngh kernel repository was never identified at file level, and no file under `/home/bricker/Projects/etc/hngh` could be enumerated from the material available in-transition. Everything below is either (a) process record of what was and was not verified, or (b) general reasoning about the failure class, flagged as such. No file paths are asserted that could not be verified; inventing them would poison the record.

## Findings

**F1. No file-level evidence exists on this line.** The prior beat states explicitly that its supplied material names no mark-read handler, idempotency guard, or state-transition module in the hngh kernel. This transition adds nothing to overturn that: the only concrete artifacts available were the prior beat (truncated at 4000 bytes) and three read-only wiki pointers. The line's central question was never tested against implementation code.

**F2. The load-bearing term is "silently drops *subsequent writes*," and it decomposes into cases of unequal severity.** General distributed-systems reasoning, *not* derived from hngh source:

| Suppression scenario | Legitimate write lost? | Severity |
|---|---|---|
| Monotonic state (unread→read only); duplicate click after first write commits | No — end state identical | None, provided it's observable |
| Suppression keyed on an *in-flight* first write that subsequently fails | Yes — often with a success-shaped response | High |
| Non-monotonic state (read↔unread toggle) inside the suppression window | Yes — a legitimate reversal is absorbed | High |
| Over-broad dedup key (per-session, per-click-token, per-batch) collaterally suppressing a *different* item's write | Yes — collateral suppression | High |

The single most decisive unknown is whether read-state in hngh is monotonic. If it is, most of the hypothesis collapses into "idempotent no-op, correct behavior"; if it toggles, or if suppression is keyed to in-flight rather than committed writes, the lost-write bug is real.

**F3. Prior art on this line is adjacent only.** The three llm-wiki pointers concern (per their truncated descriptions) a guardrail bug filed upstream against hngh analytics, a pi-llm-wiki guard

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
