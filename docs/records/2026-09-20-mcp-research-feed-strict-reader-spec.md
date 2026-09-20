# 2026-09-20 — Strict-reader contract for the MCP research TSV feed

Node: `reader-audit-m::strict-reader-spec` (deep task graph,
`gap-shared-store-replay::reader-audit-m`). Spec:
[docs/design/strict-reader-spec.md](../design/strict-reader-spec.md).
Failing test sketch: `automation/tests/test-mcp-read-tsv-strict.py`.

## What

Defined the strict-reader skip-and-count contract for the
`research_lines` MCP tool reader
(`automation/mcp/hngh_mcp_server.py::read_tsv`): malformed data rows
(wrong field count, embedded raw tab/newline, CR, NUL, undecodable
bytes, blank/comment noise) are skipped, counted per category, logged
to stderr, and surfaced as stable counters in the tool result; the cap
operates on usable rows only; a pinned-header / all-malformed feed is
fatal (`isError`), and a CLI wrapper embedding the reader exits
0/1/2 (clean/degraded/fatal). The reader never repairs (no CR strip, no
NUL removal); repair hides the writer bugs the counters exist to
surface. The fail-closed reader in `automation/jobs/research-routes.py`
keeps raising and shares the taxonomy, not the behavior.

## Evidence (probes, 2026-09-20)

Today's `read_tsv` (`automation/mcp/hngh_mcp_server.py:72-100`) is
fail-locked on over-wide rows (one bad row kills the whole feed,
RuntimeError at `:97-99`), fail-open on under-wide rows (dict silently
loses later keys via `zip`, `:96`/`:99`), feeds `#` comment rows to the
model as data (parity drift vs research-routes.py), passes NUL through,
and silently splits rows on embedded CR (universal newlines). Full
probe table: spec §7; the passing `CurrentSeams` tests pin the same
seams hermetically.

Live census 2026-09-20 (the contract lands with zero skipped rows):
research-lines.tsv 231 rows all exactly 4 fields, 0 CR, 0 NUL, valid
UTF-8; research-dispositions.tsv 187 rows at 9 fields + 72 legacy rows
(67 six-, 3 five-, 2 eight-field, all >= 5, so all pad under the
`min_fields=3, pad_to=9` accommodation, none skip).

## Decisions

- Skip-and-count, not fail-closed, for data rows in the MCP feed
  (display layer); fatal only for unreadable files, malformed/drifted
  header, and empty-but-not feeds (`kept + padded == 0` with raw data
  lines present). No JSON-RPC protocol error codes for data problems.
- Dispositions rows of 3..8 fields pad to 9 and count as
  `padded_legacy` instead of skipping: 28% of the live ledger is
  legacy-width; skipping it would gut the feed and diverge from
  research-routes.py.
- Readers read with newline translation disabled so CR is visible and
  counted; CRLF luck is not a contract.
- Logging: stderr only (stdout is JSON-RPC framing), first 10 skips per
  file then one summary line.
- Exit codes belong to CLI wrappers embedding the reader (0 clean,
  1 degraded, 2 fatal); the stdio server itself keeps process exit 0.

## Validation

`python3 automation/tests/test-mcp-read-tsv-strict.py`: 21 tests, OK
(7 passing CurrentSeams characterizations, 14 StrictContract tests
skipped until the implementing slice lands the `(rows, truncated,
counters)` reader, then CurrentSeams is deleted and the class unskipped).

## Next

- Implementing slice: strict `read_tsv` per spec (sibling nodes
  `reader-audit-m::wild-rows` / `::writer-cr-nul` probe the row corpora
  and writer-side CR/NUL hygiene; their findings fold into the
  implementer's fixture set).
- If the reader-audit campaign wants the same counters for
  graph-data.py, file it separately; this contract deliberately does
  not touch it.