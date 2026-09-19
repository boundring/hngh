# patrol: surface github-ci filed service-down on two consecutive runs -- why does it keep failing and which guardrail closes it?

Status: crystallized 2026-09-19 from research line `patrol-20260918-github-ci-service-down`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-patrol-20260918-github-ci-service-down.md.

## Contraction record

**Line:** `patrol: surface github-ci filed service-down on two consecutive runs -- why does it keep failing and which guardrail closes it?`  
**Lifecycle state:** contracting → crystallized as the line’s lasting record.

### Verification boundary

I can ground this contraction only in the supplied prior-art pointers and the named `hngh` kernel repository root: `[redacted path] I cannot verify concrete file paths inside that repository or inside the automation repository from this environment, so no internal file paths are asserted here. External GitHub/CI status is not independently verified; it is treated only as a remote surface named in the line.

---

## Findings

1. **The incident is a repeated `github-ci` service-down verdict, not a one-off flake.**  
   The line observes `service-down` on two consecutive runs. Under the supplied drift rule, when the same down-state appears across the relevant surfaces, it should be treated as confirmed drift rather than transient noise. This is grounded in the prior-art pointer `[[sources/verdict-rule-drift-two-surfaces]]`.

2. **It keeps failing because the automation model demotes after two consecutive bad-execution failures.**  
   The supplied outcome rule says that consecutive bad-execution failures trigger cancellation/demotion at two consecutive failures. Once demoted, automatic recovery or retry is no longer the closure path. If the underlying down-state remains unresolved, patrol will keep surfacing the same guardrail condition

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
