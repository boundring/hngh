# Why did patrol fire gate-stale "no gate crumb found" on hngh-automation (routed 2026-09-12T21:03Z), and what disposition (fix or park) closes alert identity patrol:automation-gate?

Status: crystallized 2026-09-14 from research line `fail-20260912-patrol-automation-gate`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260912-patrol-automation-gate.md.

# Research Line Crystallization — patrol:automation-gate

**Line:** Why did patrol fire gate-stale "no gate crumb found" on hngh-automation (routed 2026-09-12T21:03Z), and what disposition (fix or park) closes alert identity `patrol:automation-gate`?
**Lifecycle:** expanding → contracting → **crystallized**
**State at close:** contracting (final record)

---

## Epistemic status (read first)

This line's recorded beats contain the research question and prior-art pointers, but **no verified in-repository findings were captured in the record** — the expanding beat opened with intent to investigate and the trail ends there. I have not been able to confirm specific file contents in `~/Projects/etc/hngh` or the automation harness repo during this transition. Accordingly:

- Findings below are split into **(A)** claims grounded in the prior-material record and **(B)** hypotheses that remain unverified and are labeled as such.
- I name concrete paths only where the prior record itself names them. Candidate repo paths are listed under "Verification steps" as *places to check*, not as confirmed citations.

---

## Findings

### A. Grounded in the record

1. **The harness exists and was healthy as of 2026-08-25.** Prior observation `obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` records the hngh-automation overnight harness as built, verified, and enabled. So the alert is not "harness never existed."

2. **A doc-vs-install drift was already observed on this harness.** Prior observation `obs-2026-08-25-night-check-hngh-harness-healthy-timer-doc-vs-install-drift` records a night check finding the harness healthy *but* with drift between the timer's documentation and its installation. This is the strongest in-record precursor to a "no gate crumb found" alert ~2.5 weeks later: if the unit that writes the gate crumb is documented but not actually installed/enabled (or vice versa), patrol will correctly find no fresh crumb.

3. **An evidence-gated disposition process exists for exactly this kind of call.** `backlog-disposition-sweep-reduces-accepted-plans-by-half` records a disposition sweep methodology (fix vs. park gated on evidence), which is the appropriate frame for closing `patrol:automation-gate`.

### B. Unverified hypotheses (not asserted as fact)

- **H1 (most likely):** The crumb writer (timer/cron unit or harness rung) silently stopped producing the gate crumb — consistent with the known doc-vs-install drift — while patrol's staleness check kept running. Alert is a true positive.
- **H2:** The harness runs fine but writes the crumb to a path the patrol no longer reads (path/schema drift after a refactor). Alert is a false positive caused by observer/observed mismatch.
- **H3:** The gate was intentionally superseded or decommissioned, and the patrol identity was never retired. Alert is stale-by-design and should be parked.

Distinguishing H1/H2/H3 requires repository inspection that is **not in this line's record**; I cannot verify which holds from here.

---

## Recommendations

1. **Disposition: conditional FIX, not park — pending one verification pass.** The record shows a real, previously-flagged drift on this exact harness (finding A2), which biases toward H1/H2 over H3. Parking without checking risks silencing a true-positive guard on infrastructure other lines depend on. Fix is the disposition; park only if verification confirms H3.

2. **Verification steps before closing (each is a place to *check*, not a confirmed citation):**
   - In `~/Projects/etc/hngh`: locate the patrol check that emits "no gate crumb found" and confirm the crumb path and staleness threshold it reads.
   - In the hngh-automation harness: confirm whether the crumb-writing step (timer unit / rung) is installed, enabled, and has run since 2026-09-12T21:03Z; reconcile against the drift noted in the 2026-08-25 night check.
   - Compare the writer's output path against the patrol's read path to rule out H2.

3. **Close the alert identity explicitly:** whichever branch holds, record the disposition in `research-lines.tsv` and apply the evidence-gated method from the backlog-disposition sweep, so `patrol:automation-gate` does not re-enter as an ambiguous identity.

4. **If H1 confirmed:** fix = reinstall/reenable the crumb writer *and* correct the doc-vs-install drift at its source, since this is the second signal on the same seam.

---

## Open threads

- **OT-1:** Which of H1/H2/H3 holds — requires the repo inspection above; no verified answer exists in the record.
- **OT-2:** Whether the 2026-08-25 doc-vs-install drift was ever actually remediated or only observed; if only observed, this alert is its recurrence and the two lines should be linked.
- **OT-3:** Whether patrol alert identities have a defined retirement path at all (relevant if H3); no evidence of one appears in this line's record.

---

## References

Paths named in this line's own record (prior material and prompt); confidence is limited to their being named in the record, not re-verified on disk this transition:

- `research-lines.tsv` — line state file (named in prompt).
- `~/Projects/etc/hngh` — hngh kernel repository (named in prompt).
- `sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled` — llm-wiki vault, prior art.
- `sources/obs-2026-08-25-night-check-hngh-harness-healthy-timer-doc-vs-install-drift-` — llm-wiki vault, prior art (title truncated in record).
- `sources/backlog-disposition-sweep-reduces-accepted-plans-by-half` — llm-wiki vault, prior art.
- `sources/obs-2026-08-25-post-rung-11-documentation-refresh-attribution-record-and-au` — llm-wiki vault, prior art (title truncated in record).
- `sources/SRC-2026-08-24-016`, `sources/SRC-2026-08-24-018` — governance sources in vault; **not load-bearing** for this line's technical question.

**Explicitly unverifiable from this record:** any specific crumb-writer unit name, crumb file path, or patrol check source file inside the kernel repo. No such path is cited above because none could be confirmed; claims requiring them are labeled as hypotheses (H1–H3) rather than asserted.
