# reader-audit-m census — hngh-8ls evidence pass (2026-09-22)

Six read-only probes from `.agent-scratch/swarm-resume/BACKLOG-2026-09-20.md:49-56`
executed by a census scout against the wild catalog and repo readers. All 6/6
evidenced; probe spec file PRESENT (nothing missing from the halt).

## P1 catalog-strict-reader-reconciliation — CONFIRMED divergence

`docs/design/strict-reader-spec.md` mentions the catalog TSV ZERO times (the
only 'catalog'-shaped hits are `hngh_mcp_server` filename/log-prefix tokens at
:11,:19,:133,:135,:158). The only in-repo catalog reader,
`automation/lib/hngh_home.py:73 _catalog_rows`, has NO row validation
(census ledger t3b-chunk2-ledger.jsonl:26: "silently accepts malformed rows").
Spec governs ONLY the MCP research-lines/dispositions reader.

## P2 hngh-catalog-disposition — DEAD twin confirmed

`automation/lib/common.sh:17-30 hngh_catalog`: ZERO code call sites
(grep = def + 3 doc/backlog mentions: CHANGELOG.md:544, automation/README.md:59,
docs/agent-notes/backlogs/2026-09-20-successor-plan-backlog.md:56). Dead,
unwired; fate still undecided in records. Live twin = `hngh_home.py:81
catalog()` (append-only, idempotent on raw (kind,path), TSV backslash
escaping), exactly one production caller: `automation/jobs/digest-public.py:332`.
Hermetic tests: automation/tests/test-hngh-home-catalog.py:31-45.

## P3 outside-repo writers/readers — NONE as code

Scanned: ~/.local/bin (no matches), ~/.config/systemd/user (51 files; all
hngh-* units ExecStart INTO the repo: automation.service→ping-hourly.sh,
autonomy→scripts/run-autonomous, cadence-{1m,5m,10m,30m,day}→cadence-tick.sh;
credentials.conf = op CLI token only), /var/spool/cron ABSENT (systemd
timers only), ~/.hngh-automation (no matches). Extended ~/.jcode surface:
TEXTUAL references only (memory logs, census scratch, BACKLOG.md:137).
Row-152 writer identified: archive-pii-digest gate run 2026-09-19
(~/.jcode/scratch/arch-debt-census/census-gate-audit/highvalue-staleness.tsv:7)
— agent procedure, not repo code.

## P4 path-encoding-dedupe — LIVE DEFECT CONFIRMED

File now 154 rows (gate baseline 152 + rows 153-154 on 2026-09-20T10:00:55Z).
Idempotency key (kind,path) is RAW-STRING (common.sh:24-25, hngh_home.py:81-84)
→ EXACTLY 3 duplicate pairs, all kind=dispatch-edition, tilde vs absolute:

- row 13 `~/.hngh/dispatch/2026-09-11.md` ↔ row 145 absolute
- row 14 …/2026-09-12.md ↔ row 144
- row 15 …/2026-09-13.md ↔ row 146

No `//`, `%20`, or `./` variants anywhere. Rows 141-143 carry the same files
under kind=dispatch-html — kind variance is key-legal; spelling variance
within dispatch-edition is the defect. Filed as its own bead for the
normalization fix.

## P5 research-tsv-reader-inventory — declared blind spot REAL

10 mechanical readers of automation/research-lines.tsv:

- STRICT 1: automation/jobs/research-routes.py:148-167 (fail-closed ValueError
  on schema + semantics; stricter than the spec's own reader, yet declared
  out-of-scope by it).
- LOOSE 9: automation/mcp/hngh_mcp_server.py:104 (read_tsv :72-100: blank-drop
  uncounted :85-86, under-wide silently narrowed :96, over-wide fatal
  :97-98), automation/jobs/graph-data.py:56-75 (caller :539, zip-pad),
  automation/jobs/patrol.py:449-479 (silent skips), automation/jobs/
  research-feed.py:249-263 (len==4 filter), automation/jobs/digest-ledger.py:
  93-103 (except-pass), automation/lib/research-harvest.py:131-141 (silent
  subject skips; its _load_rows :95-128 IS validating but only for
  dispositions/lessons), automation/cadence/hour/33-research-beat.sh awk
  family :257-261/:306/:324/:334/:358 (WRITER set_state :474-478 tmp+mv),
  automation/cadence/day/17-torch-audit.sh:145-149 (col2 counts),
  automation/cadence/day/18-mimic-drill.sh:68-72 (sandbox fixture writer,
  not a live-file reader).
- Agent-convention readers (manual, no mechanical validation):
  .omp/agents/hngh-scout.md:16-19, automation/config/opencode/agents/scout.md:
  19-22 (registered opencode.jsonc:198).

Non-readers verified: 50-research-overflow.sh shares 33's body; viz_schema.py
:308-311 and oversight-tick.sh:130-134 are vocabulary mentions; beat-blockers.sh
:41 mention only.

## P6 wild-catalog-drift — no owed rows

Repo-derivable rows = the 10 digest-public editions 2026-09-11..09-20
(digest-public.py sole writer) — ALL present in wild; derivable-missing = 0.
Wild-only = 144 rows: the 143-row one-time migration batch (all stamped
2026-09-13T18:22:55Z; 12 article, 3 dispatch-edition tilde, 114 digest,
1 database, 8 manga, 6 dispatch-html; no in-repo writer at HEAD — 558f192 era,
docs/journal/2026-09-13.md:134) + row 152 gate-written pii-redaction-record.
~/.hngh/dispatch holds 2026-09-11..20.md only → no unwritten rows owed.
Prose doc ~/.hngh/README.md:39-42 documents the manifest contract, not a reader.

## Disposition

All six probes evidenced; bead hngh-8ls closes on this doc. Residuals tracked:

1. P4 dedupe defect → new bead filed (catalog path-normalization fix).
2. P1/P5 spec-vs-reader divergence → operator call whether strict-reader-spec
   extends to the catalog reader; not unilaterally widened here.
