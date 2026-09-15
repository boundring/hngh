<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260912-correction-b61fed0f (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the `fail-20260912-correction-b61fed0f` research line by fixing the symmetric scrolling defect in the sessions observatory dashboard, where both the session list and transcript detail panes fail to scroll due to a shared layout container lacking proper overflow containment.

## Steps

- [ ] Inspect `dashboard/sessions.html` (or equivalent) to identify the shared parent container for the left session list and right transcript detail panes
  Verification: grep -n "overflow" dashboard/sessions.html | head -20
- [ ] Add CSS `overflow-y: auto` and `max-height: calc(100vh - header-height)` to both pane containers in `dashboard/sessions.html` to establish independent scroll contexts
  Verification: bash -n dashboard/sessions.html || true && grep -c "overflow-y" dashboard/sessions.html
- [ ] Verify that the parent layout container has `display: flex` and `height: 100%` or equivalent to prevent page-level scrolling from hijacking pane scrolls
  Verification: grep -A5 "class=\"sessions-layout\"" dashboard/sessions.html | grep -E "display|height"
- [ ] Run the full test suite to ensure no regressions in dashboard rendering or other automation jobs
  Verification: make test
