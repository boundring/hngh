# rp-overview: Stage 7 overview attention-crumb counting (read-only exploration)

Artifact path: `.agent-scratch/swarm-resume/rp-overview.md`
Source: `automation/dashboard/overview-view.js` (Camp tab / overview view)

## Attention-crumb pipeline

- Breadcrumb source: `crumbsBlock(d)` reads `d.breadcrumbs` from the data.json
  payload already fetched by app.js (`overview-view.js:91-93`). No fetch of its
  own; the view composes only pre-fetched JSONs (header comment, lines 7-9).
- Filter regex (line 94): `/CRITICAL|NOTABLE|alert|failure/i.test(c.event || '')`
  - Case-insensitive, tested only against `c.event` (never `c.detail`).
  - Matches the four attention classes: CRITICAL, NOTABLE, alert, failure.
  - Regex note: `alert` and `failure` also match as substrings of longer event
    strings (e.g. `prealert`, `alertfoo`); there is no word-boundary anchor.
- Selection: `.slice(-5).reverse()` (line 95) takes the 5 most recent matching
  crumbs and reverses to newest-first for display.

## Rendering into overview cards

- Each crumb row is a `<div class="crumb ...">` (lines 99-108) with:
  - severity class (line 101-102): second regex
    `/CRITICAL|alert|failure/i` -> `alert`; NOTABLE matches fall to `notable`.
    So "alert" styling = CRITICAL/alert/failure; NOTABLE is the softer class.
  - spans: `.cts` (ts), `.cjob` (job), `.cevent` (event), `.cdetail`
    (detail, also in title attr) — all passed through `esc()` (lines 28-32).
- Wrapped in a block titled "Attention crumbs" (line 109), inserted into the
  overview HTML composition at `render()` line 187 (between opBlock and
  dispatchBlock). Tab summary also counts total report entries
  (line 210: `((d && d.breadcrumbs) || []).length + ' report entries'`).

## Empty-state note (verified)

- Lines 96-98: when the filter yields nothing, the block renders
  `<span class="ok-note">no attention crumbs in the report stream</span>` —
  explicitly says "report stream", matching the breadcrumb data source.
- Missing/undefined payload handled: `(d && d.breadcrumbs) || []` (line 92),
  so no data is also an empty state, not an error.

## Verdict

- Filter regex, slice(-5) newest-first, and empty-state note all verified
  against the file as described. No anomalies beyond the unanchored
  substring matching of `alert|failure` (cosmetic, fail-safe direction:
  over-matches rather than misses attention events).
- Display layer only; header comment states it is never governance input
  (line 23-24).
