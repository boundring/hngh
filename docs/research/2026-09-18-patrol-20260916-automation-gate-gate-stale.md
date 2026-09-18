# patrol: surface automation-gate filed gate-stale on two consecutive runs -- why does it keep failing and which guardrail closes it?

Status: crystallized 2026-09-18 from research line `patrol-20260916-automation-gate-gate-stale`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-patrol-20260916-automation-gate-gate-stale.md.

# Crystallized record — patrol: gate-stale on two consecutive runs

**Line:** patrol: surface automation-gate filed gate-stale on two consecutive runs -- why does it keep failing and which guardrail closes it?
**State:** contracting → crystallized (final structured summary; the line's lasting record)
**Provenance & verification limit:** This crystallization is drawn from the prior beat record (2026-09-18, expanding→contracting) and the read-only vault pointers named in References. I did **not** independently read or confirm concrete file paths inside `[redacted path] in this beat, and the prior material does not name them; so I cite only the vault source pointers below and flag every claim that would require a specific on-disk path as unverified rather than asserting it.

## Findings

**F1 — The failure is systemic, not incidental.** Two consecutive runs both filed `gate-stale`. The pattern indicates a missing dependency edge in the pipeline, not transient flakiness. (Carried from the prior beat; consistent with the harness being live and the gate exercised on every run — see `obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled`.)

**F2 — Path resolution drift is the proximate cause.** The gate validates an artifact whose path has shifted or was never materialized at the expected location. The gate fails because the file it is supposed to validate is *not where the gate reads* — not because the content is wrong. (Supported by `LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca`.)

**F3 — Staleness is structural.** The refresh/regeneration step that should produce the gated artifact either never runs in the automation sequence, or it runs but writes to a path the gate does not read. Two identical consecutive failures rule out flakiness and point to a missing hard dependency edge. (Carried from the prior beat; consistent with F1/F2.)

**F4 — The investigation protocol itself is fragile.** The diagnosing beat failed: per the prior record, the model entered a meta-loop questioning its own filesystem access, hit an injection

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
