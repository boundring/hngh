# G3 malformed-rows consumers — 2026-09-18

## Corrected census (live files, 2026-09-18 ~22:35Z)

- `automation/research-lines.tsv`: 225 lines, headerless, expected 4 fields.
  **Malformed rows: 0.** No blank lines, no `#` comment lines.
- `automation/config/unsloth-contexts.tsv`: 22 lines (1 header + 21 data),
  expected 6 fields (`model_id, server_observed, card_native,
  card_max_extended, source_url, checked_at`). **Malformed rows: 0.**

Correction vs prior banked claims: the only banked "malformed" census in
tree (72 legacy-width rows among 99, `docs/project/lessons-2026-09-16.md:26`
and `automation/agent-handoffs.md:285`) concerns
`automation/research-dispositions.tsv` (5/6/8-field pre-2026-09-12 writer
schema), **not** either file in G3 scope. There is no prior malformed-rows
census for research-lines.tsv or unsloth-contexts.tsv to correct numerically;
the corrected census for both is zero, verified by field-count sweep
(`line.split("\t")` per line vs expected width).

## Per-consumer short-row behavior

Short row = fewer fields than the consumer expects. Outcomes are empirical
(synthetic 1-/2-field rows fed to the real parse function) unless marked
code-read.

### research-lines.tsv consumers

| Consumer parse line | Short-row outcome |
|---|---|
| `automation/jobs/research-routes.py:107-148` (`_read_tsv`, `line_rows` calls it headerless, exactly 4) | **Raises** `ValueError` (fail closed). Verified: 2-field row raises "row has 2 fields, need >= 4"; 5-field over-wide raises "expected 4". |
| `automation/jobs/research-feed.py:257-258` (`len(parts) == 4` gate) | **Silent skip.** Verified by code-read: non-4-field rows are dropped, no error. |
| `automation/jobs/digest-ledger.py:98-99` (`len(parts) >= 2` gate) | **Partial accept.** Code-read: 1-field rows skipped; 2-3-field rows counted under `parts[1]`. |
| `automation/jobs/graph-data.py:56-79` (`read_tsv` headerless, `dict(zip(...))`) + call site `:538-545` | **Silent accept with missing keys.** Verified: 2-field row yields only `id`+`status` keys; `timestamp`/`title` come back `None` via `.get`, and the node detail string renders "None". No raise. |
| `automation/cadence/hour/33-research-beat.sh:300-301,310-311` (`awk -F'\t' '$2=="crystallized"'`), `:334` (`$2=="planned"`), `:442` (state write), `:481,487` (parked filter), `:648-650` (`cut -f1/2/4`) | **Silently ignored / empty.** Verified: `awk $N` on a short row is empty (no match); `cut -f4` on a 2-field row outputs empty with rc 0. A short row can therefore never be selected, and a `cut -f4` title read yields empty without error. |
| `automation/cadence/day/17-torch-audit.sh:146-148` (`awk -F'\t' '{c[$2]++}'`) | **Counted under the empty key.** Verified: a 1-field row increments `c[""]`, rendering as a blank state bucket in the torch report. Cosmetic only. |
| `automation/cadence/30m/50-research-overflow.sh:11` | Comment mention only; no parse. No behavior. |
| `automation/cadence/hour/33-research-beat.sh:219-240` (subjects-file seeding, writes 4-field rows) | Writer, not reader; always emits 4 fields. A short *subjects* line falls to the slug-derivation branch (`:228-232`), unrelated to TSV width. |

### unsloth-contexts.tsv consumers

| Consumer parse line | Short-row outcome |
|---|---|
| `automation/jobs/unsloth-contexts.py:221-222` (`header, rows = lines[0], [l.split("\t") ...]`; indexed writes `rows[idx][1]`, `rows[idx][5]` at `:251-252`) | **No width guard; indexed write assumes 6 fields.** Code-read (not executed live): a short matched row would raise `IndexError` on `rows[idx][5] = today`. Mitigating fact: the live file has zero short rows, and `match_row` keys on `rows[*][0]`, so only a short row whose first field matches a loaded model id could trigger it. |
| `automation/cadence/30m/59-unsloth-observe.sh:11` (invokes `unsloth-contexts.py --observe`) | Inherits the above. No independent parse. |

### Test-only consumers (not live readers)

`automation/tests/test-mcp-read-tsv-cap.py:44,60`,
`automation/tests/test-research-beat-ingest-redact.sh:51`,
`automation/tests/test-graph-data.py:83`,
`automation/tests/test-viz-schema-seam.py:401` seed fixture TSVs; they
exercise parse paths but read no live file.

## Verdict

Fail-closed coverage is uneven, matching the file's risk profile: the strict
reader (`research-routes.py`) raises, the feed reader skips, the graph reader
silently degrades to `None` fields, and the shell readers silently ignore.
With a live census of zero malformed rows in both files, no remediation is
required; the two code-read risks worth noting are
`graph-data.py` `None`-field rendering and `unsloth-contexts.py` unguarded
indexed writes, both unreachable while the census stays at zero.
