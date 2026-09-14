<!-- plan: status=executed risk=normal accepted=2026-09-12T09:02:15Z routed-from=ui-audit:axe:aria-required-children -->
# 2026-09-12 — routed candidate

Routed by scripts/router-tick.py from alert identity `ui-audit:axe:aria-required-children`
at 2026-09-12T04:00:49Z. Alert text: ui-audit axe:aria-required-children: 1 violation(s) — #tabs

## Steps

- [x] Delve: open research subject fail-20260912-ui-audit-axe-aria-required-children for ui-audit:axe:aria-required-children; record disposition; then fix or park
      Verification: research subject fail-20260912-ui-audit-axe-aria-required-children present in research-subjects.txt with a recorded disposition; alert fixed or parked
      Resolved 2026-09-14 (overnight-lead, fixed not parked): subject consolidated as fail-20260911-ui-audit-axe-aria-required-children (research-subjects.txt line 96) with disposition recorded 2026-09-14 (research-dispositions.tsv row 106, killed): axe failureSummary named the disallowed child ("button[aria-label]") -- feedback-view.js injectPips() appended the .fb-pip button directly into #tabs (a role=tablist may own only role=tab children); the static HTML was always clean, the violation appeared only after JS ran, which is why the 09-11..09-14 re-routes never landed. Fix landed 2026-09-14 (commit 4630885): pip mounts on the nav wrapper (tabs.parentNode.appendChild) + style.css nav[aria-label="dashboard sections"] flex rule; disposition swept in research commit d33c723. Alert fixed: node jobs/ui-audit.mjs re-run this session 2026-09-14T14:04Z against the served dashboard (127.0.0.1:8890) -- 0 violation(s), exit 0, no harness fault; sibling 09-13/09-14 re-route plans parked obsolete.
