# rp-story-cards: Stage 6 story cards — story-view.js row pipeline mapped to story.html

Read-only mapping of `automation/dashboard/story-view.js` (304 lines) and
`automation/dashboard/story.html` (49 lines). Builds on hist-renders-b.md
(todayFromStamp, ledger slicing, caps idiom) and rp-mirror.md (reports.md
symlink mirror). All refs file:line relative to `automation/dashboard/`.

## Data flow overview

```
refresh()  story-view.js:289-304
  fetchText("plans.json")        :297   (8s abort, no-store; helper :31-41)
  fetchText("reports.md")        :299   symlink -> ../../docs/project/reports.md (rp-mirror.md)
  renderAll(feed, text)          :302
```
No polling: one automatic refresh on load (:304) plus the manual
`#refresh-btn` listener (:303). Contrast: graph-view uses shared
`window.HnghPoll` 60s (hist-renders-b.md).

## renderAll — orchestration (story-view.js:266-281)

1. Sets `#stamp` text to `plans.json generated <feed.generated>` (:267-270).
2. `today = todayFromStamp(feed)` (:271). If null/short stamp -> `showErr(...)`
   and return — nothing rendered (:272-275). Fail-closed honesty rule: the
   banner id `storyerr` is kept literal for the contract test (:43-45;
   story.html:28).
3. `rows = todayRows(reportsText, today)` (:276) — the UTC-date slice.
4. Sections in order: `renderAccepted(feed)` :277, `renderSteps(feed, rows)`
   :278, `renderBlockers(feed, rows)` :279, `renderParks(feed)` :280.
   Each writes innerHTML into its section body via `setBody()` (:103-107).

## Date derivation — todayFromStamp (story-view.js:51-57)

- Takes `feed.generated` (a string from jobs/plan-feed.py) and slices the
  first 10 chars: `stamp.slice(0, 10)` = `YYYY-MM-DD` in UTC (the ledger
  writes `...T...Z` ISO stamps; reports.md rows start
  `| 2026-08-26T16:09:35Z |`, verified in reports.md:8).
- Returns null for missing/short stamps; the caller fails closed (:272-275).
- Verified: no `new Date()` anywhere in the derivation — "today" is the
  feed's own day, never a client-prayed Date (:51-52 comment is binding).
- Edge: slicing is a substring check, not a date parse — a malformed stamp
  of length >= 10 still yields a "date"; the date-window filter then simply
  matches zero rows, so the page shows "no report-queue rows today"
  (renderSteps :188-190) rather than wrong data.

## todayRows — UTC-date filter (story-view.js:61-67)

- Builds `prefix = '| ' + today + 'T'` (:63) and keeps lines whose first
  `len(prefix)` chars equal it (:64-66). This is the pipe-table ledger's
  row decoder for one day.
- Verified against the live ledger shape (reports.md:5 header
  `| timestamp | kind | id | first line | body |`; data rows
  `| 2026-08-26T16:09:35Z | progress | f79758fd | ... | ... |`):
  the `'| YYYY-MM-DDT'` prefix matches exactly the data rows for that UTC
  day. Header, separator/blank lines, and prose never match (they do not
  start with `| YYYY-MM-DDT`).
- Scope: hardcoded single-day window. A multi-day history view must
  generalize this filter (start/end date params), not re-implement it
  (hist-renders-b.md item 1).

## rowParts — pipe-row parsing (story-view.js:69-71)

`row.split('|').map(trim)` on `| 2026-08-26T16:09:35Z | alert | id | text | body |`
yields parts: `[0]` timestamp, `[1]` kind, `[2]` id, `[3]` first line,
`[4]` body filename — matching the 5-column ledger table (workq-report-shape.md;
app.js:345-355 uses the same shape). Known artifact: a body cell containing a
literal `|` would over-split; no escaping of `|` exists in the ledger format,
so parsers tolerate this by positional use only.

## How the rows land in the story.html cards

story.html declares four panels, each `<section class="panel">` with a body
div the renderer fills by id:

| card | story.html | renderer | rows used |
|---|---|---|---|
| accepted & executing | :30-33 (`#sec-accepted-body` :32) | renderAccepted :155-170 | none (plans only) |
| steps completed today | :35-38 (`#sec-steps-body` :37) | renderSteps :172-200 | per-plan row map, `row.indexOf(p.slug)` :181-184 |
| blockers | :40-43 (`#sec-blockers-body` :42) | renderBlockers :202-236 | alert rows + real edges |
| parks | :45-48 (`#sec-parks-body` :47) | renderParks :238-263 | none (plans only) |

### Hour buckets — verified absent

There are NO hour buckets in story-view.js or story.html. Rows are bucketed
by *UTC date* only (todayRows). The finest time granularity rendered is the
full `parts[0]` ISO timestamp string shown per alert row
(renderBlockers :228-230, class `tstamp`). Any hour-of-day grouping for a
history view would be new logic; the natural insertion point is alongside
todayRows (:61-67), grouping `rowParts(row)[0].slice(11, 13)`.

### Alert rows (renderBlockers :204-206, 224-232)

- Detection: `rowParts(row)[1] === 'alert'` (:204-206) — kind column equality.
- Rendering: `alerts.slice(-15)` (:226) — keeps the LAST 15 (most recent,
  since the ledger is oldest-first, rp-mirror.md); no "(N of M)" cap line
  here, unlike the other sections.
- Each rendered as `<p class="alert-row" title="same row the report-queue
  keeps">` showing timestamp (`parts[0]`, class `tstamp`) and first line
  (`parts[3]`) (:227-231). Id and body columns are dropped in the card.
- Empty state: `dim('no alert rows today')` (:233). Followed by the
  section's one dry aside (:234-235).

## Caps idiom recap (verified line numbers)

30 accepted (:164-167), 20 chapters (:195-198), 12 blockers (:218-221),
15 alerts (slice only, no marker :226), 40 parks (:251-254); each capped
section except alerts appends `<p class="dim">(N of M shown)</p>`.

## Honesty rules verified in the row path

- Footnote hashes only from hex tokens in today's rows (`HEX` :17,
  `hashesFor` :75-89); renderSteps passes ceremony=null (:193) so only row
  hex reaches footnotes. renderAccepted passes `{}` (:165) — no footnotes.
- Missing facts render dim placeholders (`dim()` :24-26), never fabricated.
- Fail-closed banner id `storyerr` (story.html:28; story-view.js:46-49).

## Reuse notes for a future history view

1. Generalize `todayRows` to a date window (from/to), keep the
   `'| YYYY-MM-DDT'` prefix discipline (story-view.js:61-67).
2. Keep `rowParts` positional contract (5 cells) for kind/id/first-line.
3. Hour buckets do not exist yet; add as pure helper next to todayRows for
   headless contract tests (pattern: graph-view's no-DOM helpers,
   hist-renders-b.md item 8).
4. Alert-row detection `rowParts(row)[1] === 'alert'` is the single source;
   do not re-derive from prose.
5. Data path is the reports.md symlink (rp-mirror.md): no copy lag, but
   repo-level readers can lag up to ~1h behind the live kernel ledger
   (hour-tier ledger sync).
