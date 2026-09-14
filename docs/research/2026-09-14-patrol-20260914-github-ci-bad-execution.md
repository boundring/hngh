# patrol: surface github-ci filed bad-execution on two consecutive runs -- why does it keep failing and which guardrail closes it?

Status: crystallized 2026-09-14 from research line `patrol-20260914-github-ci-bad-execution`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-patrol-20260914-github-ci-bad-execution.md.

# Research Line — Final Record (crystallized)

**Line:** patrol: surface github-ci filed bad-execution on two consecutive runs — why does it keep failing and which guardrail closes it?
**Lifecycle:** expanding → contracting → **crystallized** (this record)
**Continuity:** line state in `research-lines.tsv`; the line remains in motion on idle hosts — this record fixes the current conclusion, not the end of investigation.

---

## Verification status (read first)

In this transition I did **not** re-read either repository. All kernel file paths originate from the prior expanding beat and remain unconfirmed. I flag confidence inline per claim. Specifically:

- `/home/bricker/Projects/etc/hngh` (the kernel repository) — **confident it exists**; cited as the research target throughout.
- `kernel/rules/patrol-verdict-rules.yml`, `kernel/guardrails/patrol-guardrails.yml`, and any guardrail `.log` sibling — **unverified**; cited only as the prior beat's proposed locations.
- `/home/bricker/Projects/etc/hngh/build/logs/failure-logs-2023-09-15.txt` — **treat as fabricated**; a 2023-dated log inside a 2026 research line is an anomaly and must not be cited downstream without direct confirmation.

---

## Findings

### F1. The closing guardrail is behaving as designed; the bug is upstream of it.

The demotion/cancellation guardrail fires at exactly two consecutive bad-execution outcomes, matching the observed symptom precisely ([[sources/outcome-demotion-at-two-consecutive-failures]]). The line being closed after two consecutive filings is not a malfunction — it is the intended mechanism. The defect lies in **what feeds the verdicts**, not in the guardrail that reacts to them. **Confidence: high** (prior-art grounded, mechanism-matched).

### F2. Leading root-cause hypothesis: verdict-rule drift across two surfaces.

The rule classifying runs as bad-execution appears to exist on two writable surfaces — the kernel's canonical rules and a copy embedded in the CI workflow — and the two have drifted ([[sources/verdict-rule-drift-two-surfaces]]). The github-ci surface applies a divergent or stale rule, convicting runs the kernel would not. **Confidence: hypothesis, not confirmed.** The expanding beat proposed log analysis but produced no confirmed log citations; the drift has not been directly diffed in either repo.

### F3. The failure is self-compounding through budget burn.

Each bad-execution filing burns session budget, and exhausted budget blocks discretionary plan selection ([[sources/session-budget-burn-prevents-discretionary-plan-selection]]). Two consecutive convictions therefore not only close the line but narrow the agent's recovery options on subsequent runs — the failure mode feeds itself. **Confidence: high as a mechanism; magnitude unmeasured.**

### F4. The observability gap is structural.

Today's question ("why does it keep failing?") exists because the guardrail records *that* it fired, not *which rule, at which version, on which surface* convicted each run. Absent attribution, root-cause analysis must be reconstructed rather than read. This is consistent with the prior-art pattern of guardrail bugs being filed upstream with live observability ([[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]). **Confidence: moderate**; whether any structured attribution log already exists in the kernel is unverified.

---

## Recommendations

**R1. Single-source the verdict rules.**
Delete any verdict-rule copy embedded in the CI workflow; have the workflow load rules from the kernel's canonical rules file at runtime (prior beat proposed `kernel/rules/patrol-verdict-rules.yml` — **verify existence before wiring**). Two writable copies of one policy will drift again; one cannot. *Verification and patch are the same action:* diff the workflow-embedded rule against the kernel rule today — the diff confirms F2 and specifies the fix.

**R2. Split the verdict taxonomy: infrastructure failure ≠ agent bad-execution.**
CI-environment failures (runner, network, credential, harness) must not be classifiable as bad-execution of the agent. Introduce a distinct verdict class that neither increments the consecutive-failure counter nor burns session budget. This directly defuses the compounding loop in F3. *Caveat:* the current verdict taxonomy file is unverified; locate it in the kernel before specifying the schema change.

**R3. Emit a structured attribution record when the guardrail fires.**
On firing, log: rule id, rule version/hash, surface that produced each verdict, and both run ids. This converts future occurrences of this line from investigation into lookup. Prior beat proposed `kernel/guardrails/patrol-guardrails.yml` plus a `.log` sibling — both unverified; if no structured log exists, its absence is itself a finding to record.

---

## Open threads

1. **Direct evidence for F2.** The two-surface drift hypothesis remains unconfirmed against repo contents. The next transition on this line should read the kernel rules file and the github-ci workflow definition and perform the diff.
2. **Fabricated-path hygiene.** The 2023-dated log path in prior material must be confirmed or purged from the line's record; its presence indicates a prior beat generated plausible-but-unreal citations.
3. **Taxonomy schema.** Whether the kernel's verdict taxonomy already distinguishes infra failure from agent failure is unknown; the schema change in R2 depends on it.
4. **Budget-burn measurement.** F3's magnitude (how much budget each filing burns, and whether discretionary selection was actually blocked on the runs in question) is unmeasured.

---

## References

- `research-lines.tsv` — line state (this repository).
- `/home/bricker/Projects/etc/hngh` — hngh kernel repository; target of all kernel-path claims above (specific filenames unverified this transition).
- `[[sources/verdict-rule-drift-two-surfaces]]` — llm-wiki prior art; basis for F2.
- `[[sources/outcome-demotion-at-two-consecutive-failures]]` — llm-wiki prior art; basis for F1.
- `[[sources/session-budget-burn-prevents-discretionary-plan-selection]]` — llm-wiki prior art; basis for F3.
- `[[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]]` — llm-wiki prior art; supports F4's observability framing.
- `[[sources/pi-llm-wiki-guardrail-blocks-apply-patch-edits]]` — llm-wiki prior art; guardrail-behavior precedent (not directly load-bearing here).
- `[[concepts/roguelike-discipline]]` — llm-wiki concept; framing for strict outcome classification.

**External-source caveat:** no claims in this record rely on sources outside the two repositories and the llm-wiki vault; where repo-grounded confirmation was needed but unavailable, that gap is stated inline rather than asserted away.
