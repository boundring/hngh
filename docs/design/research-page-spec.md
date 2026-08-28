# Research page

The research-line lifecycle is a campaign board: one card per line, state
as column, next beat visible, crystallized results one click away.

Status: DESIGN — lifecycle rendering for the dashboard Research tab
(dashboard `#p-research` / `#research-root`, `research-view.js`), from the
research-lines ledger and research-feed, 2026-08-28.

Source: `../../research-lines.tsv` (hngh-automation); `dashboard/research.json`
(`jobs/research-feed.py` → `research_lines()`); `dashboard/research-view.js`;
`../../docs/research/*.md`.

Cross-links: [knowledge-base-spec.md](knowledge-base-spec.md),
[logs-page-spec.md](logs-page-spec.md),
[../../docs/project/backlog.md](../project/backlog.md),
[../architecture-index.md](../architecture-index.md).

## 1. Lifecycle

A research line lives in exactly three states, as observed in
`research-lines.tsv` (columns: `id`, `state`, `updated`, `line` — tab
separated, one line per row; `jobs/research-feed.py#research_lines()` parses
4-column rows and a missing file degrades to an empty list):

- **planned** — in the queue, nothing spent (5 of 12 lines today:
  `remote-access-patterns`, `unattended-session-budgets`,
  `virtual-assistant-ux`, `logs-known-good-patterns`,
  `research-publishing-pipelines`).
- **expanding** — beats are being run against it
  (`adversarial-review-patterns`).
- **crystallized** — a result document exists in `docs/research/` named
  `<date>-<id>.md` (all 6 crystallized lines today:
  `2026-08-28-log-presentation-patterns.md`,
  `2026-08-28-wiki-viewer-qol.md`, `2026-08-28-tech-tree-research-ux.md`,
  `2026-08-28-session-cost-display.md`, `2026-08-28-gantt-legibility.md`,
  `2026-08-28-telemetry-schema-exemplars.md`).

The feed is a dumb pass-through: `research.json#lines` is the tsv as JSON —
`{id, state, updated, line}` per row, `generated` timestamp at top level.
The board invents no fourth state and no transition logic.

## 2. Board layout

The Research tab currently renders five generic cards (alternation verdict,
research lanes, design docs, open questions, lessons). The lifecycle re-render
replaces the flat `lines` presentation with a three-column campaign board —
same `rs-grid`/`rs-card` idiom, same fail-closed-per-slot rules, same 60s poll
with draft-protection — plus the existing cards kept below or alongside:

- Three board columns headed **planned / expanding / crystallized** (state
  chips on narrow viewports collapse the columns — the
  `@media (max-width:760px)` single-column rule already exists).
- One card per `lines[]` row in its state's column: the `line` text as card
  title, `id` as sub-label, `updated` rendered through the existing `ago()`
  relative formatter with the raw ISO timestamp as `title`.
- **Crystallized cards link out**: a link to
  `docs/research/<newest-date>-<id>.md` in the hngh repo (the filename
  convention is `<date>-<id>.md`; `log-presentation-patterns` →
  `2026-08-28-log-presentation-patterns.md`). The board derives the filename
  from `id`; it does not parse document contents. A missing document renders
  the state chip without the link — fail closed, no dead links.
- **expanding** cards show the current beat's focus when the feed can name
  one; planned cards show their stated intent (`line` is already a full
  sentence today, e.g. "remote access patterns: WoL, tailnet VPN, SSH,
  headless dashboard exposure").

## 3. Next beat — the missing field

No per-line "next beat" exists anywhere in the data. `research-lines.tsv` has
no schedule column; `research.json#lines[]` carries only `{id, state,
updated, line}`. The only beat-adjacent signal is the repo-level
`alternation` facet (`due`, `balance_window_s`, `last_grow`, `last_research`)
— which says a research beat is due, never *what* the beat should work on.

Minimal feed addition (spec'd, not invented as UI for absent data): one new
optional trailing column `next` (free text, ≤140 chars — "run second
adversarial pass", "digest findings into a crystallization doc"). Changes:

- `research-lines.tsv`: 4→5 columns; rows without `next` stay valid (the
  parser accepts 4 or 5; the 4-column legacy rows keep parsing).
- `jobs/research-feed.py#research_lines()`: pass `next` through when present;
  absent → `null` in the JSON row.
- Board rendering: expanding/planned cards show `next` as a "next beat" line
  when non-null; `null` renders the muted "awaiting beat" placeholder —
  never a fabricated schedule, never a countdown from `updated`.

## 4. Relationship to the existing cards

The alternation verdict card stays: it is the *campaign clock* above the
board ("research beat due" tells the operator the expanding/planned columns
should move). The "add research line" form and per-lane "note" button remain
advisory/organizational prose writes — the board changes none of that; a
proposed lane enters the hngh backlog and only appears on the board once the
beat seeds a tsv row. Design docs, open questions, and lessons cards are
unchanged companions.

## 5. Non-goals

Design only — implementation rides a later build wave; no code, tsv, or feed
changes land with this spec. No transition automation (the board renders
state, it never advances it); no per-line document parsing beyond the
filename convention; no extra states, priorities, or effort estimates — the
lifecycle is exactly planned/expanding/crystallized.
