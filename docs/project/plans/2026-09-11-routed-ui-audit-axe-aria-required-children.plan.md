<!-- plan: status=accepted risk=normal accepted=2026-09-11T07:02:25Z routed-from=ui-audit:axe:aria-required-children -->
# 2026-09-11 — routed candidate

Routed by scripts/router-tick.py from alert identity `ui-audit:axe:aria-required-children`
at 2026-09-11T04:00:48Z. Alert text: ui-audit axe:aria-required-children: 1 violation(s) — #tabs

## Steps

- [x] Delve: open research subject fail-20260911-ui-audit-axe-aria-required-children for ui-audit:axe:aria-required-children; record disposition; then fix or park
      Verification: research subject fail-20260911-ui-audit-axe-aria-required-children present in research-subjects.txt with a recorded disposition; alert fixed or parked
      Resolved 2026-09-14 (overnight-lead, fixed not parked): root cause found on the axe surface itself -- feedback-view.js injectPips() appended the .fb-pip button (implicit button role) into #tabs (role=tablist), and a tablist may own only role=tab children; the static HTML was always clean, which is why the identity re-occurred 2026-09-11..09-14 without landing. Fix: pip mounts on the nav wrapper (tabs.parentNode.appendChild, feedback-view.js:41-49) + nav flex rule (style.css:457-462); contract test FeedbackPipPlacement red-first then green (tests/test-dashboard-p1-ui.py); one-shot axe repro reports zero aria-required-children rows post-fix; automation make test green rc=0. Subject + disposition recorded in automation research-subjects.txt / research-dispositions.tsv (killed); crystallized in docs/research/2026-09-14-ui-audit-axe-aria-required-children.md. Slice files landed inside sibling commit 4630885 (staged-index sweep, content verified intact). axe:color-contrast stays open under its own routed plan.
