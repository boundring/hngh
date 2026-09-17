# Journal status values spec (verdicts, DISPATCH lead lines, stall-ledger tokens)

Task `hist-journal-dispatch-status` — read-only exploration, 2026-09-15.
Source of truth: `scripts/generate-publication` (kernel surface, read-only),
`automation/lib/beat-blockers.sh`, `automation/research-lines.tsv`,
`automation/state/beat-blockers.tsv` (runtime, gitignored). Siblings:
`hist-journal-format.md` (section order), `hist-journal-extract-ledger-story.md`
(ledger/story contract).

## 1. Verdict derivation (dispatch_numbers, scripts/generate-publication:139-183)

`dispatch_numbers(day)` builds `states` = histogram of column 2 (state) over
`automation/research-lines.tsv` rows with >= 2 tab fields. Then:

```
advancing = states["planned"] + states["expanding"]
verdict   = "advancing" if advancing > 0
            else "holding" if states["reviewed"] > 0
            else "quiet"
```

- `advancing`: at least one research line in state `planned` or `expanding`.
- `holding`: zero advancing, but at least one `reviewed` (work done, awaiting
  the next beat to move it forward).
- `quiet`: no lines in any of the three states counted (e.g. all
  `crystallized` or the TSV missing/empty).
- Fail-open doctrine (docstring, lines 141-143): missing feed, locked sqlite,
  or unparsable json reads as 0/quiet — "the dispatch is a morning headline,
  never a governance input."

Live distribution in research-lines.tsv (2026-09-15): 24 planned,
1 expanding, 132 reviewed, 2 crystallized → advancing=25, verdict=advancing.
State vocabulary observed: planned, expanding, reviewed, crystallized.
Only planned/expanding/reviewed participate in the verdict.

## 2. DISPATCH lead lines (dispatch_section, lines 185-212)

`## DISPATCH` section, three bullets then the verdict line:

1. `- **{sessions}** sessions launched today; **${spend:.2f}** spent across
   **{calls}** model calls in the last 24h.`
   - sessions: lines in `automation/logs/budget.md` starting with `{day}` and
     ending `session-run`.
   - spend/calls: `~/.hngh/db/telemetry.db`, `events` where
     `kind='session-cost'`, ts >= now-24h; calls = count, spend = round(sum
     cost_usd, 2). Read-only URI, 2s timeout, exception swallowed.
2. `- **{advancing}** research lines advancing ({by_state}).`
   - `by_state` = sorted `"{state} {count}"` joined by ", ", or
     `"none seeded"` when states is empty.
3. `- **{open_items}** operator items open.`
   - `automation/dashboard/operator-items.json`, items with status=="open".
4. `Verdict: {verdict}.` (note trailing period)

Closed by an HTML comment `<!-- sources: ... -->` naming all four feeds
(budget.md, telemetry.db, operator-items.json, research-lines.tsv).

## 3. README dispatch table row (dispatch_table, lines 214-222)

Inside `dispatch:begin`/`dispatch:end` sentinels in README.md:
`| {day} | {sessions} | ${spend:.2f} | {advancing} | {open_items} |`
(flat count of advancing lines; verdict word itself does not appear here),
plus `Deep read: [the journal](docs/journal/{day}.md).`

## 4. Story verdict line (story_section tail, lines 356-365)

The day's story closes with one verdict line reusing the DISPATCH verdict:
`Verdict: {verdict} - {advancing} research line(s) advancing,
{open_items} operator item(s) open, {blockers} blocker(s) on file.`
(no trailing period; singular/plural always "(s)" style).

## 5. Stall-ledger (beat-blockers) status tokens

Schema (automation/lib/beat-blockers.sh:5-7):
`id<TAB>scope<TAB>cause<TAB>first-seen<TAB>attempts<TAB>state<TAB>last-update`
(id = `blk-YYYYMMDD-<scope sanitized to [a-zA-Z0-9._-]>`; timestamps
`YYYY-MM-DDTHH:MM:SSZ`).

State tokens, complete set (beat-blockers.sh):
- `active` — set on every blocker_record write (line 47/55: `$6 = "active"`)
  and when blocker_tick unparks (line 82).
- `parked` — set by blocker_park when attempts >= blocker-escalate-n
  (bounded retries); auto-unparks after blocker-park-cooldown-hours
  (default 24) via blocker_tick, which resets attempts to 0 (diagnosis
  restarts).
- (removal) — blocker_clear deletes the row entirely on success; there is no
  "cleared" token. An empty/absent ledger means no blockers.

generate-publication rendering (day_blockers, lines 258-270): rows whose
field 4 (first-seen) starts with `{day}`; fail-open on missing file. Story
block text (lines 341-350): when rows exist —
`The stall ledger gained {n} row(s): {lane} stalled ({cause}, x{attempts}) and now sits {status}.`
joined by "; "; when none —
`The stall ledger is quiet for the day - no beat blockers filed.`
So the status token surfaces verbatim in the story paragraph ("sits active",
"sits parked"). Feeds tag: `automation/state/beat-blockers.tsv`. Ledger
producers: beat watchdog (jobs/beat-watchdog.py detector) and overnight beat
remediation loop; research beat wires it at scope `research:<id>`
(cadence/hour/33-research-beat.sh:534).

Current ledger sample: all 4 rows `active`, e.g.
`blk-20260914-publication-latest-draft.json  publication:latest-draft.json  bubble-third-point  2026-09-14T09:07:04Z  1  active  2026-09-15T09:07:17Z`.

## 6. Quick reference

| Token | Produced by | Meaning |
|---|---|---|
| advancing (verdict) | dispatch_numbers | >=1 line planned/expanding |
| holding (verdict) | dispatch_numbers | 0 advancing, >=1 reviewed |
| quiet (verdict) | dispatch_numbers | none of the three states |
| active (blocker state) | blocker_record / blocker_tick | stall under bounded retry |
| parked (blocker state) | blocker_park | attempts >= escalate-n, cooldown |
