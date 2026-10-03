# 2026-10-03 — Newspaper readability tranche

## Conclusion

The follow-up operator feedback on the dashboard resolved into four
landed slices: (1) article text is print-clean — home paths render as
`~/` via the kernel scrub convention and raw markup is stripped, both at
the single `base_article` seam in `newspaper-compose.py`, and omp
delegation prompts ("Complete assignment thoroughly: …") no longer
print as session articles; (2) settlements stick — the operator-items
feed keeps a persisted settled-shape map so a dismissed/parked alert
whose digits churn (new pid, new wall time) stays settled instead of
minting a fresh content hash that no ledger knew; (3) the broadsheet
never splits a card across columns, expansion scrolls the card back
into view after the `column-span` reflow, the paper carries a low-opacity
SVG-turbulence newsprint grain, and the console header ticker is a
static ellipsized line instead of an 18-second marquee; (4) the daily
lesson harvest echoes a repo-relative guardrails path, so the generator
no longer re-leaks the absolute home path into `docs/project/lessons-*`
and trips `lint-home-paths` every day.

## Evidence

- `6f7fed15` — composer `_presentable()` (scrub `redact_home` + tag
  strip + space collapse) applied to headline/deck/body in
  `base_article`; `session_articles` skips missions matching
  `^Complete assignment thoroughly`; `PresentableText` tests (2).
- `a15e243a` — `settled_key()` (producer|kind verbatim, digit-collapsed
  tail), `"settled"` map persisted in `operator-items.json`, fuzzy
  force only when the row would otherwise print open, sticky relay
  across churn, map rebuilt fresh each run (prunes when the source
  stops); `SettledShapes` tests (3). Ledger precedence unchanged:
  RESOLVED crumb > exact ledger id > fuzzy shape > open.
- `2d46fc98` — `break-inside: avoid` on `.art`; expand handler calls
  `scrollIntoView({ block: 'nearest', behavior: 'smooth' })`;
  `body::after` SVG feTurbulence grain at 0.06 opacity;
  `.lcd-ticker-inner` static block + ellipsis (animation, hover-pause,
  keyframes, redundant reduced-motion block removed; winamp theme
  override never re-added motion); `NewsprintAndFlow` tests (4).
  Note: `p.rest` progressive reveal was already wired — most cards
  simply carry single-paragraph bodies, so the visible gap was scroll
  containment, not the reveal.
- `25faeb09` — the composer's static verb-effect guidance spelled its
  placeholder as `<id>`; rephrased in words so the expanded verb table
  carries no angle-bracket text (the last three `<tag>` hits in the
  live feed were these constants, not leaked markup).
- `15637fd8` — `01-lesson-harvest.sh:134` echoes
  `${GUARDRAILS#$HNGH_REPO/}`; `:32` keeps the absolute path for real
  file checks; param expansion verified to print
  `docs/project/agent-guardrails.md`.
- Full `cd automation && make test` green after every slice
  (~290 s each; the only intermediate red was the new fixture itself
  leaking a real home path, fixed to a fake login before commit);
  `lint-identifiers` and `lint-home-paths` clean.
- Live browser proof: separate record section below (front page probes
  for clean text, unsplit cards, expand containment, ticker animation
  name, settled-map behavior).

## Scope

- Composer-side only: the digests, crumbs, and sessions feeds still
  carry absolute paths in storage; the newspaper prints them tilded.
  The crumbs `$digest` absolute leaks in the harvest script
  (`:124`/`:150`) are intentionally untouched — the composer-side
  tilding cleans what the newspaper prints from crumbs.
- Settlement stickiness is shape-scoped: two genuinely different alerts
  sharing a digit-collapsed first line would suppress together; the
  map prunes when the source stops emitting, and a returning exact
  ledger id always outranks the map.
- The delegation skip is the single known wrapper pattern; other
  wrappers would need their own pattern.
