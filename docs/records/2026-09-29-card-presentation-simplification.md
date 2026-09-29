# Card presentation simplification (2026-09-29)

## Problem

Collapsed broadsheet cards carried two presentation defects: a dead
legacy code path rendered `a.narrative` as a second deck-styled
paragraph whenever a feed carried the old string form, and the source
line (supporting info) printed on every card even collapsed —
supporting info leaked into the matter/summary layer.

## Change

- `automation/dashboard/broadsheet-view.js`: the legacy
  string-narrative branch is deleted — the composer emits object
  narratives only (`newspaper-compose.py:511`,
  `{"place", "line"}`), so the string path was dead for current
  feeds. `narrativeHTML` (the object form) is the single narrative
  path.
- `automation/dashboard/broadsheet.css`: `.art .srcline` is now
  `display: none`, revealed by `.art.expanded .srcline` — the source
  line joins the expanded-only supporting-info contract (rest
  paragraphs, ghost counsel, guidance table, narrative aside, btop
  embed), including ink-reveal animation and reduced-motion parity.
- `automation/tests/test-broadsheet-view.py`: the string back-compat
  pin (an implementation pin on dead code) is deleted; a new pin
  holds the expanded-only srcline contract.

## Verification

- View suite: 62/62 OK; `node --check` clean.
- Browser smoke (production page): 6 cards, no console errors,
  source line absent collapsed and visible after expansion.
