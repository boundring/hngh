# Tigress duplicate-lids audit verdict (2026-09-18)

Task: audit contradictory verdicts sharing one line id (`line` col 1) in
`automation/research-dispositions.tsv`. Read-only; no ledger writes.
Ground truth: the dispositions TSV itself (row numbers = TSV line numbers,
header row 1, data rows 2..N).

## Method

Grouped all 27 line ids occurring 2x each (54 rows; no lid occurs 3+).
Compared `action` + `verdict` text per pair. Classes:

- AGREE: same disposition, compatible rationale.
- PROGRESS: parked/killed then adopted on a later date with new evidence
  (temporal sequence, explainable).
- CONTRADICTORY: opposite dispositions (adopted vs parked/killed) with
  mutually exclusive rationale on the same evidence base.

## Verdict table (lid -> rows -> verdict)

| lid | rows | verdict |
|---|---|---|
| cistern-test-coverage | 38 killed / 46 parked | AGREE. Both say the crystallized artifact has no findings and the question needs a fresh re-run. Killed-vs-parked is wording, not substance. |
| fail-20260907-slow-unit-dropin-50-research-overflow.sh | 61 parked / 62 parked | AGREE. Same rationale (by-design slow wall). |
| fail-20260909-slow-unit-dropin-33-research-beat.sh | 82 parked / 88 adopted | CONTRADICTORY. Row 82 (2026-09-13) parks: bimodal by design, revisit only if GO-tick wall exceeds ~2x ceiling. Row 88 (2026-09-13, kimi) adopts and explicitly rejects the park ("park rejected while tail grows"). Opposite dispositions, same day. Row 88 cites F3 truncation artifact + drifting median as new evidence; row 82 predates that framing. Resolution: row 88 dominates on newer evidence; the later sibling identity row 120/140 (adopted pair, 2026-09-14/15) confirms the adopted line held. |
| fail-20260909-wake-mutation-lane-src-mutation | 84 adopted / 89 parked | CONTRADICTORY but RESOLVED in favor of row 84. Row 84 (session:opencode-executor, 2026-09-13) cites the landed certificate ceremony (docs/records/2026-09-13-wake-mutation-lane-landing.md, make test green 2894). Row 89 (unsloth, 2026-09-13) parks claiming hallucinated paths -- a reviewer artifact-capability gap, not a subject finding. The ceremony record corroborates row 84. |
| fail-20260910-overnight-plan-accept-gate-kernel | 101 killed / 126 parked | CONTRADICTORY but RESOLVED in favor of row 101. Row 101 (session, 2026-09-14) gives a checkable root cause (status=accepted header, sibling adoption, push-protection cause). Row 126 (unsloth, 2026-09-14) parks for lack of repo access -- reviewer limitation, explicitly stated. Row 101 dominates. |
| fail-20260910-push-blocked-openrouter-key-hngh | 103 killed / 127 killed | AGREE. |
| fail-20260910-slow-unit-dropin-16-remote-push.sh | 102 adopted / 128 parked | CONTRADICTORY but RESOLVED in favor of row 102. Row 102 (2026-09-14) adopts with a measured fix (ENVELOPE entry, failing test first, 432 duplicate rows quantified). Row 128 (unsloth, 2026-09-14) parks for insufficient evidence -- same no-access reviewer class as rows 126/130. Row 102's fix is the checkable artifact. |
| fail-20260911-correction-style-css | 105 killed / 130 parked | CONTRADICTORY but RESOLVED in favor of row 105. Row 105 (session, 2026-09-14) verifies resolution live (style.css exists, 330 rules, no re-occurrence). Row 130 (unsloth) parks pending re-fire. Row 105 dominates on first-hand evidence. |
| fail-20260911-overnight-plan-accept-gate-kernel | 44 adopted / 45 adopted | AGREE. Complementary (root cause + remediation path). |
| fail-20260911-system-network-down | 42 adopted / 43 adopted | AGREE. Complementary (root cause + fix shape). |
| fail-20260911-ui-audit-axe-aria-required-children | 106 killed / 131 adopted | CONTRADICTORY in label only; SUBSTANCE AGREES. Row 106 (session, 2026-09-14) says "fixed, not parked" with a landed fix (344ec39-adjacent pip remount, contract test, zero-row axe repro). Row 131 (unsloth, 2026-09-14) adopts R1-R3 next steps. Both say fix, not park; the killed/adopted split is a labeling artifact of two reviewers seeing pre- and post-fix states. Resolution: the fix described in row 106 is the checkable artifact; no open contradiction on what to do. |
| fail-20260912-correction-3146c023 | 107 killed / 132 adopted | SAME PATTERN as above: row 107 (session) kills with a verified resolution (restart + inline-failure follow-on fix landed); row 132 (unsloth) adopts the evidence-gated fix. Both direct toward fix-done/fix-now, not park. Label contradiction only. |
| fail-20260912-correction-b61fed0f | 111 killed / 134 adopted | SAME PATTERN: row 111 (session) kills with a verified live fix (344ec39, both scrollers engage, contract test); row 134 (unsloth) adopts the fix. Label contradiction only. |
| fail-20260912-correction-407311fb | 109 parked / 133 parked | AGREE. |
| fail-20260912-deck-unreachable-2026-09-12 | 113 parked / 135 parked | AGREE. |
| fail-20260912-overnight-plan-accept-gate-kernel | 114 parked / 136 adopted | CONTRADICTORY, GENUINE. Row 114 (session, 2026-09-14) parks: duplicate identity + transient reds, green gate 2026-09-14T08:12Z verified. Row 136 (unsloth, 2026-09-14) adopts and explicitly rejects parking ("parking violates evidence-gated discipline"), mandating a controlled retest R3. Opposite dispositions with mutually exclusive rationale and no later row arbitrating. Follow-up: re-check gate state and either confirm the row-114 green-gate evidence still holds (park stands) or run the row-136 R3 retest (adopt stands). |
| fail-20260912-patrol-automation-gate | 116 parked / 137 adopted | CONTRADICTORY, GENUINE. Row 116 (opencode-go, 2026-09-14) parks with a live re-run (make test rc=0, transient class). Row 137 (unsloth, 2026-09-14) adopts as active infrastructure risk, mandating verification and fix. No arbitration row. Follow-up: same shape as above -- confirm current crumb cadence intact (park stands) or verify-and-fix (adopt stands). |
| fail-20260912-patrol-paper | 117 parked / 138 parked | AGREE. |
| fail-20260912-slow-unit-dropin-20-workbeat.sh | 121 adopted / 139 parked | CONTRADICTORY, GENUINE. Row 121 (session, 2026-09-14) adopts with a quantified envelope fix (2460s, failing test first). Row 139 (unsloth, 2026-09-14) parks pending phase-level traces. No arbitration row. Follow-up: check whether the row-121 ENVELOPE fix landed in jobs/slow-units.py; if landed, adopt stands, else the park rationale revives. |
| fail-20260912-slow-unit-dropin-33-research-beat.sh | 120 adopted / 140 adopted | AGREE. |
| fail-20260914-system-low-mem | 129 killed / 158 killed | AGREE. |
| govbench-adapter-contract | 24 killed / 47 adopted | CONTRADICTORY, TEMPORAL. Row 24 (kimi, 2026-09-08): crystallized record is an empty transcript, nothing actionable. Row 47 (deck, 2026-09-11): research provided concrete evidence driving implementation -- against the SAME evidence path (docs/research/2026-09-06-govbench-adapter-contract.md). Either the doc gained findings between 09-08 and 09-11 (re-run landed) or one reviewer misread it. Follow-up: inspect the doc's current content and git history between those dates; whichever state holds decides killed vs adopted. |
| govbench-ci-evidence | 25 parked / 48 adopted | PROGRESS. Parked-needs-context (09-08) then adopted-driving-work (09-11) by the same reviewer (deck). Temporal sequence, explainable. |
| govbench-metrics-v1 | 26 killed / 49 parked | WEAK CONTRADICTION. Row 26 (kimi, 09-08): no findings, needs fresh line. Row 49 (deck, 09-11): initial exploration needed. Both agree no findings exist; they differ only on whether the husk stays parked or is closed. No action required beyond normal line hygiene. |
| govbench-scenario-corpus | 27 parked / 50 adopted | PROGRESS. Same reviewer (deck), 09-08 park then 09-11 adopt. Explainable. |
| govbench-voting-prior-art | 28 killed / 51 adopted | CONTRADICTORY, TEMPORAL. Same shape as adapter-contract: row 28 (kimi, 09-08) says incomplete transcript, nothing actionable; row 51 (deck, 09-11) says clear starting point on the SAME evidence path (docs/research/2026-09-07-govbench-voting-prior-art.md). Follow-up: same doc-state/history check. |
| synth-2026-09-08-1 | 39 killed / 54 adopted | CONTRADICTORY, TEMPORAL. Row 39 (kimi, 09-09): crystallization aborted, zero findings. Row 54 (deck, 09-12): clear mapping driving implementation, SAME evidence path (docs/research/2026-09-09-synth-2026-09-08-1.md). Follow-up: same doc-state/history check. |

## Summary counts

- 27 duplicate lids, 54 rows. AGREE: 11. PROGRESS: 2. Resolved-in-favor-of-session-row: 4
  (wake-mutation, 09-10-overnight, 09-10-16-push, 09-11-style-css). Label-only: 3
  (axe-children, 3146c023, b61fed0f -- both sides say fix). Weak: 1 (metrics-v1).
- GENUINE open contradictions needing a follow-up probe: 3
  (09-12-overnight-plan-accept row 114 vs 136;
  09-12-patrol-automation-gate row 116 vs 137;
  09-12-20-workbeat row 121 vs 139).
- TEMPORAL contradictions needing a doc-state/history check: 3
  (govbench-adapter-contract, govbench-voting-prior-art, synth-2026-09-08-1).
- One structural note: every unprivileged-reviewer park (unsloth rows 126, 128,
  130, and the 09-12/09-14 unsloth adopt/park block rows 131-140) explicitly or
  implicitly lacks repo access; where a session-led row with first-hand evidence
  exists on the same lid, the session row dominates. Future dispositions should
  weight reviewer capability, not just count rows.

## Note on cited sources

The plan step cites "three tiger banked specs" for this work log. No file
matching `tiger` exists under docs/ or automation/ (grep, this session; same
finding as the sibling tigress-kimi-telemetry verdict record). The banked
specs actually used: (1) the Scorpion precision note (banked 14:32Z 2026-09-17,
G1 = STATE.md ledger as ground truth -- not directly needed here but sets the
evidence-grounding rule); (2) BACKLOG.md TIER 2 row "tigress 3 gaps ...
Audit contradictory verdicts" (the task definition); (3) the plan step itself
(docs/project/plans/2026-09-18-backlog-p1-completions.plan.md:35-36, which
requires verdicts citing the contradictory row/commit ids -- done above via
TSV row numbers).
