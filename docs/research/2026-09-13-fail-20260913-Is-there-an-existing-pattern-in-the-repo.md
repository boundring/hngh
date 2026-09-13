# Is there an existing pattern in the repository for lexical guards or text sanitization (e.g., in `lib/logs.py` or `lib/display.py`) that could be reused for quips?

Status: crystallized 2026-09-13 from research line `fail-20260913-Is-there-an-existing-pattern-in-the-repo`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-Is-there-an-existing-pattern-in-the-repo.md.

# Research Line Crystallization (Contracting → Final Record)

**Line:** Is there an existing pattern in the repository for lexical guards or text sanitization (e.g., in `lib/logs.py` or `lib/display.py`) that could be reused for quips?
**Lifecycle:** expanding → contracting → **crystallized (this record)**

---

## Findings

1. **The core question cannot be resolved from this turn's vantage.** The kernel repository root `/home/bricker/Projects/etc/hngh` was supplied as ground truth, but no filesystem inspection was available in any beat of this line. Consequently, the existence of `lib/logs.py`, `lib/display.py`, or any sanitizer module named in the line's phrasing remains **unverified** — these are hypotheses embedded in the research question, not confirmed files.

2. **The design answer, however, is stable regardless of the audit outcome.** The line converged on a principle that does not depend on which files exist: **quips are untrusted display text and must pass through exactly one lexical guard choke point before rendering or logging.** This holds in all three audit outcomes (existing guard found / partial guard found / no guard found).

3. **One beat was lost to a truncation failure.** The 2026-09-13 beat hit the max_tokens cap mid-recommendation (finish_reason=length). The surviving portion (recommendations 1–2) is preserved below in completed form; no substantive findings were lost, only prose.

## Recommendations (lasting record)

1. **Audit before adding code.** Search `/home/bricker/Projects/etc/hngh` for lexical-guard terms: `quip`, `sanitize`, `redact`, `scrub`, `escape`, `guard`, `display`, `log`. If a reusable text-output guard exists in the kernel, consume it from `hngh-automation` rather than building a parallel quip-specific sanitizer.

2. **Prefer one choke point.** All quips — regardless of origin (static table, templated, model-generated) — should pass through a single guard function at the display/log boundary, not at each call site. This makes the guard auditable and prevents drift between output paths.

3. **If no guard exists, add the minimal version in the kernel, not the consumer.** A shared guard belongs in `hngh` (per the prior-art principle that supervision and safety mechanisms must be Hngh-native); `hngh-automation` should import it, not reimplement it.

4. **Guard semantics should be conservative:** strip or escape control characters, bound length, and neutralize any markup the display layer interprets. Do not attempt semantic filtering of quip content — that is a curation problem, not a sanitization problem.

## Open Threads

- **Unresolved:** whether `lib/logs.py` or `lib/display.py` (or equivalents) actually exist in the kernel and whether either already contains a sanitization pattern. This requires a live filesystem audit; it is the single concrete next action if this line reopens.
- **Adjacent:** if quips are ever model-generated, the guard question compounds with prompt-injection surface in display text — worth a separate line if that feature lands.

## Verification Limits

- No file paths beyond the supplied repository root `/home/bricker/Projects/etc/hngh` are asserted to exist.
- Prior-art vault pointers were read-only prompt text; their linked content could not be verified beyond titles.
- No external sources were consulted; none are claimed.

## References

- `/home/bricker/Projects/etc/hngh` — hngh kernel repository root (supplied; contents unverified this line)
- Prior-art vault pointers (titles only, unverified): `sources/supervision-must-be-hngh-native`, `sources/async-proof-pattern-for-long-drop-ins`, `sources/timezone-local-vs-utc-rendering-fabricates-missing-commits`
- `research-lines.tsv` — line state record

*This is the line's lasting record. Reopening condition: filesystem access to the kernel repository, at which point thread #1 resolves in one audit pass.*
