# Sample-to-format mapping (viz-design synthesis input)

Status: SAMPLES -- real outputs collected 2026-09-15T00:17Z, excerpts
verbatim from the named files; the card layouts are proposals for the
viz synthesis, not built UI. Companion to `patrol-report-samples.md`
(render register shapes) and `patrol-payload-schema.md` (the patrol
JSON contract).

Source-location correction: the node named `automation/dispatch/`, but
dispatch editions live under `~/.hngh/dispatch/` (the 2026-09-13
two-home split: userspace outputs in `~/.hngh/dispatch/`, never
committed). No `automation/dispatch` directory exists (checked
2026-09-15).

Feature menu the synthesis can spend:

- markdown tables
- mermaid gantt / flowchart
- structured key-value cards (metric tiles)
- kind/status badges, monospace id chips
- image embeds, perceptual captions (register: `docs/design/display-register-spec.md`)

---

## Sample 1 -- Patrol rounds as produced today

Sources: `automation/agent-handoffs.md` (the `handoff-deaths` check
input), `mcp__hngh__dashboard_readout` (verdict block),
`mcp__hngh__research_lines` (patrol-repeat subjects), and one overnight
run log from `automation/logs/`.

Verbatim, `automation/agent-handoffs.md:1-2` (pipe-delimited ledger):

```
overnight-lead | 2026-09-08T02:57:31Z | 2026-09-02-routed-review-hngh-P1-Commit-6cbdc9c-modifies-doc|run-1 | rc=0 cancelled log=logs/overnight-2026-09-02-routed-review-hngh-P1-Commit-6cbdc9c-modifies-doc-20260907T224407.log model=zai/glm-5.3(paid-fallback) cause=unknown
overnight-lead | 2026-09-08T03:09:22Z | 2026-09-02-routed-tree-skew-hngh|run-1 | rc=1 dead log=logs/overnight-2026-09-02-routed-tree-skew-hngh-20260907T230128.log model=zai/glm-5.3(paid-fallback) cause=unknown
```

Verbatim, dashboard_readout tail (`generated 2026-09-14T20:17:26-04:00`):

```json
{ "verdict": { "state": "all-clear", "reasons": [] } }
```

(the `verdict` object as rooted from the readout payload; verbatim
key-values)

Verbatim, research feed patrol-repeat row (`research-lines.tsv`
backing; JSON via the MCP tool):

```json
{ "line": "patrol-20260914-automation-gate-gate-red", "status": "planned",
  "date": "2026-09-14T10:00:43Z",
  "title": "patrol: surface automation-gate filed gate-red on two consecutive runs -- why does it keep failing and which guardrail closes it?" }
```

Verbatim (first 2 events), overnight run log
`automation/logs/overnight-2026-09-06-routed-tree-skew-hngh-2-20260912T000206.log.json`
(JSONL event stream; line 1 is a stderr notice, line 2 an event):

```json
{"type":"step_start","timestamp":1789185730601,"sessionID":"ses_f6c386221ffeMCnUo88oHdhnuq","part":{"id":"prt_093c7a8240011p5TTkq2eKNMTu","messageID":"msg_093c7a01a0016kKYkWC1VEjjbm","sessionID":"ses_f6c386221ffeMCnUo88oHdhnuq","snapshot":"1fc7519f06c0242a815dbb8e2d29f27777ab3c5f","type":"step-start"}}
```

(line 1 of the file verbatim; line 1 of the file proper -- a stderr
notice `[rtk] rtk binary not found in PATH -- plugin disabled` --
precedes it. The next event is a `tool_use` (bash) whose command reads
`tail -n 30 /home/bricker/Projects/etc/hngh/automation/state/ocgo-agent-lessons.md`;
events continue as JSONL, one tool call per event, each carrying
`timestamp`, `sessionID`, and the full `part` object.)

Target card: **"Rounds" card**

- Header: verdict pill from `verdict.state` (all-clear / red) + a
  key-value strip (surfaces walked, pass/fail counts; the
  `hngh.patrol.v1` envelope fields when the emitter lands).
- Body: handoff history as a **markdown table** (columns: ts | plan |
  run | rc | end-state | model | cause), rows color-coded on
  end-state/cause (`dead`, `cancelled`, `bad-execution`); the
  accumulation signature (>=3 dead/cancelled in last 10) renders as a
  count badge, not a sentence.
- Repeat marker: any research-feed row with a `patrol-` line id and
  status `planned` renders a "queued research subject" badge on the
  matching patrol card (patrol+cause repeated twice).
- Run detail drawer: an overnight log opens as a **mermaid flowchart**
  of the tool_use chain (bash -> read -> edit ...), one node per
  `tool_use` event, first line of the command as node label.

Features: markdown table (primary), key-value cards, badges, mermaid
flowchart (drill-down only). Gantt optional: end-states over time
would show the dead-run clustering, but the table already carries it.

---

## Sample 2 -- Dispatch edition

Source: `~/.hngh/dispatch/2026-09-14.md` (edition no. 8).

Verbatim, lines 1-15:

```
# The Machine Hall - Daily Dispatch (public edition)

Edition no. 8 | 2026-09-14 | source: ~/.hngh/archive/digest/2026-09-14.md | journal: docs/journal/2026-09-14.md

## THE LEDGER

<!-- feeds: ~/.hngh/db/telemetry.db -->
- metered spend: $9.52 across 334 model calls (24h).
- tokens in: 20,993,450.
- research beats: 59; dispatch blocks: 21 active, 10 quiet hours.

> Death took the day off: $9.52 metered, 334 calls, 10 quiet hours. The ledger can wait.

![the day's manga panel: sample-strip-draft.png](../media/manga/sample-strip-draft.png)

> Filed under fiction. The only panel here that will not page anyone.
```

Plus the ASCII "machine hall" text-graphic (same file, lines 17-21):
a 24-column hour strip of `.`/`#`/`:` activity dots over a
`00-------06-------12-------18-------23  UTC` ruler.

Target card: **"Dispatch" card**

- THE LEDGER bullets become **key-value metric tiles** (metered spend,
  model calls, tokens in, research beats, active blocks, quiet hours)
  -- same numbers, scannable at a glance, exact values preserved.
- The ASCII hall becomes a **mermaid gantt** (or hour-binned bar row)
  of activity density across 00-23 UTC; the ASCII art stays available
  as the literal layer for text-only renderers (it is already the
  canonical form -- the gantt is a perceptual upgrade, not a
  replacement).
- Manga image keeps the embed; the two `>` pull-quotes render as
  perceptual captions (register rule: caption never enters a record,
  literal values stay in the tiles).
- Edition header (no., date, source, journal) renders as a small
  key-value line.

Features: key-value cards (primary), mermaid gantt, image embed,
captions. No table needed -- nothing here is row-shaped.

---

## Sample 3 -- Report ledger (automation/dashboard/reports.md)

Source: `automation/dashboard/reports.md` (3,149 lines, the report-queue
human view; row format `| timestamp | kind | id | first line | body |`).

Verbatim, lines 7-8 (header + oldest row):

```
| timestamp | kind | id | first line | body |
| 2026-08-26T16:09:35Z | progress | f79758fd | implementation: 2026-08-26 10 open lane(s); next=lane: hngh-autonomy-build — started: report-queue + run-autonomous + tests | 2026-08-26T16:09:35Z-progress-f79758fd.md |
```

Verbatim, newest row at collection time (line 3149):

```
| 2026-09-15T00:15:18Z | progress | e32010c5 | research line fail-20260912-slow-unit-dropin-33-research-beat.sh reviewed: adopted (adopted -- Structural diagnosis of bimodality and accumulation artifact is high-confidence; R1/R2 verification path is clear and low-cost.) | 2026-09-15T00:15:18Z-progress-e32010c5.md |
```

(Excerpts are verbatim and keep their in-row em dashes; prose here is
ASCII per house rule.)

Target card: **"Ledger" card**

- The file is already a markdown table, so the card renders it as a
  **markdown table** newest-first (the file is oldest-first; the
  dashboard already reads it reversed) with:
  - `kind` as a badge (alert = error color, progress = success,
    scheduled = neutral);
  - `id` as a monospace chip linking to the body file (the last
    column is a relative path -- a plain anchor, not a fetch);
  - `first line` clamped to one line with expand-on-click (research
    verdicts run hundreds of chars);
  - a 24h count strip on top (key-value tiles: alerts / progress /
    scheduled counts) so the shape of the day reads before scrolling.
- No mermaid: a 3k+ row append-only ledger wants virtualization and
  kind filters, not a chart. (Consistent with the adopted
  logs-known-good-patterns line: progressive disclosure, virtualized
  lists, tail mode.)

Features: markdown table (primary), badges, key-value strip,
expand-on-demand rows.

---

## Mapping summary

| Sample | Primary feature | Secondary | Avoid |
| --- | --- | --- | --- |
| Patrol rounds (handoffs + verdict + feed) | markdown table | key-value cards, badges, mermaid flowchart (run drawer) | gantt (table carries it) |
| Dispatch edition | key-value cards | mermaid gantt (hour strip), image embed, captions | tables (nothing row-shaped) |
| Report ledger | markdown table | badges, key-value strip, expand rows | any chart |

Shared rules across all three: literal values always rendered complete
and first; captions are perceptual-only; text-only fallback is the
verbatim source shape (ASCII hall, pipe rows, pipe-ledger lines), never
a lossy summary.
