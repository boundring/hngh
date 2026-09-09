# Adversarial review: email digest + dashboard Logs tab

Date: 2026-09-09
Scope: scripts/email-digest.py output + dashboard Logs tab (`dashboard/index.html#p-logs`)
Method: read yesterday's digest verbatim; read Logs tab rendering code; read as operator who has not seen a digest in 3+ days.

## Findings table

| # | Surface | Finding | Severity | Evidence |
|---|---------|---------|----------|----------|
| F1 | Digest TL;DR | Status line is a single number with no severity breakdown. `ATTENTION: 50 alert(s)` tells the operator nothing about which alerts need action vs. which are noise. | High | `status: ATTENTION: 50 alert(s) in 24h` — no tier split (critical/notable/info). |
| F2 | Digest Progress | 82+ plan names listed with truncated slugs and no status grouping. The operator cannot tell which plans matter without scrolling past 80 lines of `2026-09-04-routed-agent-stall-om parked steps 0/1 (new)`. | High | `(+82 more live plan(s) — full state in the dashboard)` — the "full state" lives in the dashboard, but the digest itself forces the operator to read all 82 truncated lines first. |
| F3 | Digest Alerts | Heavy dedup cascade: same alert appears 4–5× as "escalated", "dedup escalation", "dedup: suppressed", "router dedup escalation" — all the same underlying issue. The operator sees noise where one fix is needed. | Medium | Lines like `router escalated: ttsr-fit:OmpSurfaces re-occurred 3 times` followed by `router dedup escalation: ttsr-fit:OmpSurfaces recurring — suppressed 3 times` — identical root cause repeated. |
| F4 | Digest Budget | Raw telemetry dump (`events by source/kind: unsloth model 20, ui-audit ui-audit 17, ...`) with no interpretive line. The TL;DR already has spend; the body just repeats it in structured form without adding insight. | Low | `telemetry report — 2026-09-09 (db: ...)` followed by 25+ lines of source/kind counts. |
| F5 | Logs tab | No dismiss-able operator items surface yet — the tab renders `#logs-ops` but the dismiss action is only wired through `data-dismiss` buttons that require operator items to exist. Empty state has no actionable path. | Medium | `app.js:453` renders `#logs-ops` innerHTML; dismiss handler at line 180 requires `data-dismiss` target. If no operator items, the section is empty. |
| F6 | Digest Operator items | The operator-items section lists "2026-09-04-notifications-and-qol: 1. GRO" — a truncated plan name with no context about what step 1 requires. The operator must open the plan file to understand. | Medium | `2026-09-04-notifications-and-qol: 1. GRO` — truncated slug, no plain-language description. |

## Top-5 improvements (ranked)

1. **F1: Severity-tier the status line.** Split `ATTENTION: 50 alert(s)` into `ATTENTION: 50 alert(s) — 3 critical, 12 notable, 35 info`. The operator needs the first decision: "do I need to read more?" Severity tiers let them decide at a glance.

2. **F2: Collapse the plans list.** Replace the 82+ line list with a summary: `14 parked / 9 accepted / 29 with unchecked steps / 19 queued`. The "full state" lives in the dashboard; the digest should point there, not duplicate it.

3. **F3: Dedup alerts before listing.** Fold suppressed/escalated/dedup variants into the unique alert. One line per unique alert, with the dedup count as a suffix. This alone would cut the 50-item list to ~15.

4. **F5: Add a dismiss-able operator-items surface.** Each operator item gets a one-line row (what happened, when, severity) with a dismiss action that records the dismissal in the report ledger. This is the Logs-tab QoL increment from step 5.

5. **F6: Plain-language operator items.** Expand the plan slug to a one-line description: `2026-09-04-notifications-and-qol: verify digest restructure landed (step 1)` instead of `1. GRO`.
