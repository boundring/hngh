# Why did the feedback-apply beat file alert identity correction-style-css ("style.css missing or unparseable; quick item t1 left unapplied" x2) on 2026-09-11, does the condition still reproduce, and what disposition (fix or park) closes it?

Status: crystallized 2026-09-14 from research line `fail-20260911-correction-style-css`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260911-correction-style-css.md.

# Final record: `correction-style-css` alert (2026-09-11)

_line state: contracting → crystallized | disposition: evidence-gated, closed as procedure_

## Summary

On 2026-09-11 the feedback-apply beat filed alert identity `correction-style-css` twice, each with the condition **"style.css missing or unparseable; quick item t1 left unapplied."** This line asked why the alert fired, whether it still reproduces, and what closes it.

The lasting conclusion of this line is that `correction-style-css` is an **apply-path failure scoped to one quick item (`t1`)**, not a general CSS defect and not merely a beat-file anomaly. The line cannot assert a final fix/park verdict on the evidence available to it, so it closes by fixing the **disposition procedure and decision rule** that any idle host can execute in one pass.

## Findings

**Established (from prior material on this line):**

1. The alert names its failed unit: quick item `t1`, targeting `style.css`, with the failure mode "missing or unparseable." The `x2` repetition most plausibly represents one unresolved item re-alerting across consecutive beats, not two independent failures — but this is an inference, not a verified fact.
2. The alert wording conflates two distinct failure classes that require different dispositions:
   - *Missing*: the expected `style.css` path does not exist where the apply path looks for it.
   - *Unparseable*: the file exists but is rejected by a parser/validator.
3. Prior art establishes that apply-patch edits can be blocked by guardrails, so `t1` may be *blocked* rather than *pending* even if the CSS is valid and present.
4. Prior art establishes that missing store directories have caused transport faults in the hngh kernel environment, so a "missing" verdict may be environmental (run/store path) rather than a content defect.
5. Prior art establishes that disposition sweeps can materially reduce accepted plans, so `t1` may have been swept out of acceptance — which would make the alert stale rather than live.

**Not established:**

- Whether the condition still reproduces. No current repository state, beat file, apply queue, or guardrail state was verified during this line. Reproduction status remains **unknown**, and this is stated explicitly rather than asserted either way.
- The concrete target path the apply path expects for `style.css`.
- Which validator rule (if any) rejected the file, or which guardrail (if any) blocked the apply.

## Recommendations (the closing procedure)

A single idle-host pass resolves the line. In order:

1. **Audit alert state, not the beat file.** Check whether `correction-style-css` still appears in current feedback-apply state and whether `t1` is still pending, blocked, superseded, applied under another identity, or dropped by a disposition sweep.
2. **Fork on the failure class.** If *missing*: record the expected path, check parent/store directory existence (per the prior transport-fault precedent), and determine whether the path is run-specific or generated. If *unparseable*: capture the exact parser/validator error and preserve a minimal failing fixture for regression.
3. **Check guardrail state before forcing an apply.** If a guardrail is the active blocker, disposition is a policy/path correction, not a CSS fix.
4. **Apply the decision rule:**
   - **Fix** only if `t1` is still in an accepted plan **and** the apply path still fails on a verified missing/unparseable/blocked condition.
   - **Park** if `t1` is stale, superseded, already applied, swept out of acceptance, or the condition is environmental/transient with no dependent work.

## Disposition of this line

**Closed as: park-pending-evidence, procedure fixed.** The line's durable output is the decision rule above. If a future beat observes `correction-style-css` re-firing, reopen with the step-1 audit result attached; the line should not be re-litigated from zero.

## Open threads

- Live reproduction check on an idle host (step 1 above) — never executed within this line.
- The `x2` repetition pattern: whether re-alerting of a single unapplied quick item across beats is intended beat behavior or noise that should be deduplicated by item identity.
- Whether "missing or unparseable" should be split into two distinct alert identities, since they route to different fixes.

## References

- hngh kernel repository root (only path asserted with confidence): `~/Projects/etc/hngh`
- Line state: `research-lines.tsv` (as named in the line header; contents not re-verified at crystallization)
- Prior-art pointers (llm-wiki vault, read-only):
  - `sources/pi-llm-wiki-guardrail-blocks-apply-patch-edits`
  - `sources/backlog-disposition-sweep-reduces-accepted-plans-by-half`
  - `sources/obs-2026-08-26-hngh-create-run-transport-fault-on-missing-store-dir`
  - `sources/timezone-local-vs-utc-rendering-fabricates-missing-commits` (carried in prior material; not load-bearing for any finding above)

No external sources were used. Claims that would require live repository or queue inspection are marked unverified rather than asserted.
