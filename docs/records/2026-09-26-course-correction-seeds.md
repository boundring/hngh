# 2026-09-26 — Course-correction seeds

Record of the operator's 2026-09-26 course-correction directive and the
seven-slice plan it produced (`local://hngh-course-correction-plan.md`,
executed 2026-09-27). This file is the durable seed store: the doctrine
decisions, the follow-on lanes, and the feedback harvest. Slices 1–6 each
carry their own record/doc; this one carries the vision and the leftovers
that must not evaporate.

## Productivity-first doctrine

Hngh's activity budget should spend mostly on expansive, productive work.
Vestibular work (re-orientation, re-feeding, re-alerting on the same
finding) is waste by definition. Concretely landed: feed-once router cursor
(slice 1), three-digests-a-day email (slice 2), quota rebalance toward zai
with every paid leg paced (slice 5).

## Email doctrine

Three digests a day at 07:30 / 15:30 / 22:00 America/New_York — operator
wakes 07:30, works 09:00–17:00, dinner 19:30, bed 22:30–23:00. No on-event
emails of any kind, including GitHub CI notifications (`HNGH_NOTIFY_IMMEDIATE=0`
default). Transport: `cadence/subhour/57-digest-send.sh`; capture stays
report-queue + dashboard.

## Newspaper direction

The dashboard's first surface is a skeuomorphic newspaper (landed as slice
6: `index.html` front page, console moved to `console.html`). Follow-on
lane `arc-20260926-newspaper-lane-2`: migrate console tabs into newspaper
articles, winamp-style draggable/skinnable frames, landing polish.

## Tree-of-life research structure

Design: `docs/design/research-tree-of-life.md`. Storage:
`automation/research-tree.tsv` (node/parent/line-id), seeded with the trunk,
the seven active stages, and the current leaf seeds. Wiring (graph-data,
research-routes, dashboard tree view) is follow-on lane
`arc-20260926-tree-of-life-wiring`.

## Pantheon expansion policy

`config/ghost-voices.tsv` (39 ghosts) + `lib/ghost-voices.py` landed with
slice 4. Canon-compatibility contract: the 17 canon voices remain
documentary-only via `tao-confucian-canon` (GOVERNANCE.md); hngh-native
ghosts are style registers for digest/editorial decoration, never
governance input, never machine-fact inventors (stale-mention guard).

## Quota doctrine summary

zai/GLM-5.3-Flash is the majority workhorse under its 300/5h and
1500/week (Monday-UTC) caps; opencode + kimi absorb bursts (kimi 40/day);
xiaomi is the long-one-shot creative leg, now paced at 40/day with
chat-level telemetry emit (slice 5); local unsloth serves the overnight
research lane free. Full doc: `docs/design/quota-doctrine.md`.

## Typesafe meta-cycle

The typesafe docs KB (`~/.hngh/db/hngh-knowledge.db`, 111 nodes / 300
edges, weekly refresh) is the substrate for Jev/System-One advising.
Follow-on lanes: `arc-20260926-fractal-fanout` (question-matrix generation
loops over the KB; matrices stored as `question-node` kind rows).
Jev advises, never certifies; deterministic refusals stay authoritative.

## omp-session meta-cycle seed

`arc-20260926-omp-session-meta-cycle`: procedurally routed oh-my-pi
sessions on billion-context-customized local models — sessions that
compose, launch, and supervise other sessions as a standing meta-cycle.
Long-horizon; not scheduled.

## Feedback harvest (distilled 2026-09-27)

- The 40 open operator items (`[feedback:idea] from email`, 2026-09-25
  19:05Z → 2026-09-26 20:04Z, ~30 min cadence) carry **zero recoverable
  idea text**: every referenced crumb payload is the literal
  `[feedback:idea] from email` (verified against `automation/state/crumbs.db`
  writer offsets 184774…206673). The email→feedback capture path loses the
  text upstream of `jobs/feedback-ingest.py`.
- No `fb-*` research subjects were minted from them — there is nothing
  genuinely new inside. Items are NOT dismissed (operator's call, now one
  click in the newspaper Decisions section).
- One genuinely new subject did emerge from the distillation itself:
  `fb-20260927-1-feedback-capture-integrity` — where is the text lost
  between the digest-email feedback form, imap capture, and the ingest
  standardizer, and what fail-closed guard belongs there? (Tree leaf under
  stage 1, self-watch.)

## CHANGELOG note

The plan called for a `### 2026-09-26` changelog section; all seven slices
actually landed on 2026-09-27, so the entries live under the existing
`### 2026-09-27` section (one dated section per real day).
