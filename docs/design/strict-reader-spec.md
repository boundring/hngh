# Strict reader contract (research TSV feed)

Malformed rows are skipped, counted, and logged — never silently repaired,
never allowed to kill the whole feed, never silent about their own count.

Status: PROPOSED 2026-09-20 — contract and failing test sketch landed
(`automation/tests/test-mcp-read-tsv-strict.py`); reader implementation is
the follow-up slice (node `reader-audit-m::strict-reader-spec` artifact).

Source: reader-audit-m node family 2026-09-20; malformed-row probe against
`automation/mcp/hngh_mcp_server.py::read_tsv` (evidence in §7).

Cross-links: [research-page-spec.md](research-page-spec.md),
[fail-first.md](fail-first.md),
[../../docs/records/2026-09-20-mcp-research-feed-strict-reader-spec.md](../records/2026-09-20-mcp-research-feed-strict-reader-spec.md).

## 1. Scope

The `research_lines` MCP tool (`automation/mcp/hngh_mcp_server.py`) reads
two append-only ledgers:

- `automation/research-lines.tsv` — HEADERLESS, exactly 4 fields
  (`line_id`, `status`, `last_transition`, `title`).
- `automation/research-dispositions.tsv` — one pinned 9-column header row
  (`line`, `action`, `verdict`, `reviewer`, `evidence`, `date`, `support`,
  `oppose`, `followons`), then data rows.

Out of scope, on purpose:

- `automation/jobs/research-routes.py::_read_tsv` stays fail-closed (it
  RAISES on malformed rows; the server's fail-soft cache keeps the last
  good feed). This spec shares its malformed-row taxonomy, not its
  behavior: the MCP feed degrades with counters, the routes builder
  refuses.
- `automation/jobs/graph-data.py::read_tsv` unchanged.
- Kernel-side readers: separate nodes (the o9j/o9k numeric-reader family).
- Writer-side hygiene (CR/NUL/newline emission): the sibling
  `reader-audit-m::writer-cr-nul` node owns it; this document only fixes
  what the reader must do when writers misbehave.

## 2. Malformed-row taxonomy

Per physical data line, first matching category wins, in this order:

1. `undecodable` — the line fails strict UTF-8 decode. (Today a bad byte
   raises mid-file and kills the whole read.)
2. `cr` — any `\r` byte anywhere in the line (a CRLF-writing writer, or
   an embedded bare CR). The reader must read with newline translation
   disabled (`newline=""` or binary) so CR survives to be classified;
   universal-newline text mode silently turns CR into a line break and
   splits the row in two (probe: today a lone `\r` mid-line yields two
   wrong rows). CR is never stripped: stripping is repair, and repair
   hides the writer bug this counter exists to surface.
3. `nul` — any `\x00` byte (the classic failed-substitution writer bug:
   a shell variable that read from a missing file). NUL is never removed
   from a kept row.
4. `blank` — empty or whitespace-only line: skipped, counted. (Today it
   is dropped without any count.)
5. `comment` — first non-space character `#`: skipped, counted. This is
   read parity with `research-routes.py` and `graph-data.py`; today the
   MCP reader returns `# a comment` as a data row to the model.
6. `field-count` — tab count does not match the expected width. There is
   no quoting and no escaping in this format: a tab is always a
   separator, so an embedded raw tab IS an over-wide row, and an
   embedded raw newline IS the write-side hole that produces two
   fragment lines which each fail field-count here.
   - `research-lines.tsv` (width 4): any row with ≠ 4 fields is skipped
     and counted.
   - `research-dispositions.tsv` (width 9): rows with fewer than 3 or
     more than 9 fields are skipped and counted; rows with 3 to 8 fields
     are PADDED with empty trailing fields to 9 and counted as
     `padded_legacy`. The live ledger carries 72 legacy rows (67 six-,
     3 five-, 2 eight-field, 2026-09-20 census); the pad accommodation
     mirrors `research-routes.py` (`min_fields=3, pad_to=9`) so the MCP
     feed and the routes builder agree on what a usable row is. Padding
     is counted, not silent.
7. Otherwise the row is kept, verbatim. The reader performs no field
   trimming; downstream builders own `.strip()` (existing behavior).

## 3. Skip-and-count semantics

- A malformed row never aborts the read, never enters `rows`, and never
  consumes a `ROW_CAP` slot. Classification happens first; the cap then
  keeps the NEWEST (last) `ROW_CAP` USABLE rows, where usable = kept +
  padded (the existing newest-kept contract of
  `automation/tests/test-mcp-read-tsv-cap.py`).
- `read_tsv` returns `(rows, truncated, counters)` — a 3-tuple (today a
  2-tuple). `counters` is a dict with stable JSON keys:

      raw_lines            physical lines in the file
      header               0 or 1 (header row consumed)
      kept                 rows returned
      padded_legacy        rows padded to width 9 (dispositions only)
      skipped_blank
      skipped_comment
      skipped_field_count
      skipped_cr
      skipped_nul
      skipped_undecodable
      skipped_total        sum of the five skipped_* families
      cap_dropped          usable rows older than the cap slice
      truncated            bool (usable rows exceeded ROW_CAP)
      first_skipped        ≤ 5 entries {line, category}, file order

- Invariant: `raw_lines == header + kept + padded_legacy + skipped_total
  + cap_dropped`. Every physical line is accounted for exactly once.
- `tool_research_lines` keeps its existing result keys (`lines`,
  `dispositions`, `truncated`, `counts`) and adds
  `counters: {"lines": {...}, "dispositions": {...}}` so machine
  consumers branch on counts, never on the absence of an error.

## 4. Fatal vs degraded (where fail-closed still applies)

- FATAL — the whole `research_lines` call returns `isError: true` with a
  message naming the file and reason:
  a file missing or unreadable; the dispositions header malformed
  (wrong width, empty or duplicate column names, CR or NUL in it) or
  drifted from the pinned 9-column header; or the feed is empty-but-not:
  `kept + padded_legacy == 0` while the file has raw data lines. A feed
  that would silently render as empty is a lie, not a degradation.
- DEGRADED — `isError` stays false; rows plus counters come back:
  any `skipped_total >= 1`.
- Data-level problems never use JSON-RPC protocol error codes. The
  result boundary fails closed (never partial rows mixed with a silent
  success); the feed level fails soft (skip and count).

## 5. Logging

- stderr only. stdout is JSON-RPC framing and must stay clean (the
  server already writes its startup banner to stderr; same channel).
- Per skipped row, one line, capped at the FIRST 10 skips per file per
  call, in file order:
  `hngh-mcp: research-lines.tsv:123: skipped field-count (5 fields, expected 4)`
- Then one summary line per file:
  `hngh-mcp: research-lines.tsv: 13 rows skipped (field_count=11, cr=1, nul=1)`
- Logging is the human trail; the counters in the payload are the
  machine contract. A consumer must not need the log to be correct.

## 6. Exit codes (CLI seam)

The stdio MCP server has no per-request exit code; its process exit
stays 0 and data problems surface as `isError` results (§4). For any
CLI wrapper embedding this reader (a `--check` mode for beats/CI), the
contract is:

- exit 0 — clean read (`skipped_total == 0`);
- exit 1 — degraded (`skipped_total > 0`, usable rows remain);
- exit 2 — fatal (the §4 fatal boundary).

`padded_legacy > 0` alone does not degrade the exit code (it is the
counted accommodation, visible in counters for writers to eventually
fix). Exit 2 matches the rc-2 fail-closed path `research-routes.py`
already uses for its validation failures.

## 7. Today's seams (evidence, probed 2026-09-20)

All probes against `read_tsv` as of
`automation/mcp/hngh_mcp_server.py:72-100`; rows written to temp files,
module loaded via importlib (same harness as
`automation/tests/test-mcp-read-tsv-cap.py`):

| malformed input                    | today's behavior                                   | seam        |
|------------------------------------|----------------------------------------------------|-------------|
| over-wide lines row (5 fields)     | RuntimeError kills the whole `research_lines` call | fail-locked |
| under-wide lines row (3 fields)    | kept; dict silently missing later keys             | fail-open   |
| under-wide dispositions row        | kept; dict silently missing later keys             | fail-open   |
| `#` comment line                   | returned as a data row                             | parity drift |
| CRLF file                          | rows read clean (universal newlines eat `\r`)       | silent luck |
| embedded bare CR mid-line          | row silently split into two fragments              | fail-open   |
| NUL byte in a value                | passes through into the returned value             | fail-open   |
| blank lines                        | dropped, uncounted                                 | invisible   |
| non-UTF-8 byte                     | decode error kills the whole read                  | fail-locked |

Code seams: `:84` strips only `\n` (CR handling delegated to text mode);
`:85-86` drops blank lines uncounted; `:96` headerless keys are sliced to
the row's own field count (under-wide silently narrows); `:97-99` raises
on over-wide (one bad row poisons the whole feed) and `zip`-pads nothing
for under-wide headered rows.

Live-file impact of landing this contract: zero skipped rows. Census
2026-09-20: research-lines.tsv 231 rows, all exactly 4 fields, 0 `#`,
0 CR; research-dispositions.tsv 187 rows at 9 fields + 72 legacy rows
(all >= 5 fields, so all pad, none skip).

## 8. Non-goals

- No quoting/escaping extension to the format: writers must not embed
  tabs, newlines, CR, or NUL in values; the reader refuses, it does not
  parse around them (sibling node `reader-audit-m::writer-cr-nul` owns
  the writer side).
- No change to the fail-closed routes reader or to graph-data.py.
- No silent repair of any kind: no CR stripping, no NUL removal, no
  field trimming at the reader layer.