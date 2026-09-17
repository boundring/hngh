# rp-patrol-digest: Stage 9 patrol digest two-pass format, read-back, repeat-cause auto-queue

Scope: how `automation/jobs/patrol.py` appends run sections to
`PATROL-<date>.md` (supportive + adversarial two-pass), how the previous
FAIL set is read back for repeat detection, and the research-subjects
auto-queue. Read-only; no repo edits.

## 1. Contract overview

- `automation/jobs/patrol.py:21-26` (module docstring): each check prints a
  `PASS <patrol>/<check> <detail>` or `FAIL <patrol>/<artifact> <cause> <detail>`
  line; FAILs file report-queue alerts (identity `patrol:<id>`) and append to
  `automation/digest/PATROL-<date>.md` in "supportive + adversarial sections,
  the publication-review two-pass format". A patrol+cause pair repeating on
  two consecutive runs auto-queues a research-subjects entry
  (house convention, `cadence/hour/33-research-beat.sh`).

## 2. Section writer: `findings_md` (patrol.py:1259-1286)

- Header `## <ISO8601 UTC timestamp> run` (line 1262).
- Optional quip line in italics (1263-1265), from `lib/quips.py`
  (invoked at main, line 1419-1427; failure-safe, "no quip, never a crash").
- `### Supportive pass` (1266): one `- [ok] <name> -- <detail>` per PASS (1269).
- `### Adversarial pass` (1270): one `- FAIL <patrol>/<artifact>: <cause> -- <detail>`
  per FAIL (1273-1274); a clean patrol prints `- ok <id> -- no red findings` (1276).
- `### The rounds` (1282-1285): operator morning checklist mapping each FAIL
  to surface + artifact: `- ROUNDS <id> -> surface: <surface>; artifact: <artifact> (<cause>)`.

## 3. Append path in `main` (patrol.py:1388-1442)

- Findings doc is append-only, "one section per run; the previous section is
  the repeat-detection memory" (1410-1411).
- `read_runs(digest_dir, date, now_s)` (1416) is called BEFORE the append.
- Section built by `findings_md` (1429) and appended with `open(path, "a")`
  (1428-1431). Path: `digest_dir/PATROL-<date>.md`; default digest dir is the
  userspace home `~/.hngh/archive/digest` (env `PATROL_DIGEST_DIR`, 1197-1201).
- Each FAIL then files a report-queue alert with identity `patrol:<pid>` and
  `--evidence <detail>` (so dedup only re-fires on a recurred condition;
  `report_alert`, 1321-1341) and calls `queue_repeat_subjects` (1437-1439).
- Queued rids print as `QUEUED research-subject <rid>` (1440-1441).

## 4. Read-back of previous FAIL set: `read_runs` (patrol.py:1229-1256)

- Reads ONLY yesterday's and today's files: `PATROL-<yday>.md` and
  `PATROL-<date>.md` (1234-1239). Docstring: "the findings doc is the only
  patrol state there is" (1231-1232) -- stateless beyond the digest itself.
- Splits on run headers: `## ` line ending in ` run` (1246-1250).
- Parses FAIL lines with regex `- FAIL ([\w-]+)/[^:]+: ([\w-]+)` (1251-1253),
  i.e. captures (patrol, cause) pairs; returns list of per-run fail lists,
  oldest first.

## 5. Repeat-cause auto-queue: `queue_repeat_subjects` (patrol.py:1289-1318)

- Repeats = intersection of previous-run (patrol, cause) set with the
  current FAIL set (1294-1295); only the LAST previous run is used
  (`prev_runs[-1]`, main line 1438).
- For each repeat, rid = `patrol-<YYYYMMDD>-<patrol>-<cause>` (1298, 1305);
  question line capped at 240 chars: "patrol: surface <patrol> filed <cause>
  on two consecutive runs -- why does it keep failing and which guardrail
  closes it?" (1306-1308).
- Dedup: skips if `rid\t<question>` already present in
  `research-subjects.txt` (1300-1311), then appends (1312-1315). Best-effort
  (OSError swallowed, 1316-1317).

## 6. Live verification (userspace digest, `~/.hngh/archive/digest/`)

- `PATROL-2026-09-15.md` has 30 run sections today; the latest
  (`## 2026-09-15T14:21:01Z run`) matches the format exactly: quip line,
  `### Supportive pass` with 12 `- [ok]` lines, `### Adversarial pass` with
  4 FAILs (handoffs bad-execution, automation-gate gate-red, manga
  manga-stale, github-ci bad-execution) and `### The rounds` with 4 ROUNDS
  lines -- one per FAIL.
- Live repeat queue worked: `automation/research-subjects.txt` contains e.g.
  `patrol-20260915-automation-gate-gate-red`, `patrol-20260915-handoffs-bad-execution`,
  `patrol-20260915-github-ci-bad-execution`, each with the exact two-consecutive-runs
  question text from patrol.py:1306-1308.

## 7. Test coverage

- `automation/tests/test-patrol.py:553-571`
  `test_repeat_cause_queues_research_subject`: writes a prior-day
  `PATROL-2026-09-11.md` containing a `## ... run` section with one FAIL
  (feeds/feed-stale), makes the feed stale, runs `--tier 30m`, asserts
  `patrol-20260912-feeds-feed-stale` printed and appended to
  research-subjects.txt, then re-runs and asserts no duplicate (rid dedup).
- `automation/tests/test-viz-schema-patrol.py:7`: docstring ties findings_md
  two-pass sections + stdout PASS/FAIL contract to the viz schema tests.

## 8. Downstream hooks (sibling artifacts)

- Write side (alerts): `report_alert` -> `scripts/report-queue --add alert`
  with `--identity patrol:<pid> --window 86400 --evidence <detail>`
  (patrol.py:1321-1341) -- see rp-ledger.md.
- Read side: `morning_report` (`--morning`, patrol.py:1445-1497+) re-reads
  the findings doc counting `- [ok]` / `- FAIL` lines and emits a `## The rounds`
  summary into the daily digest, with per-cause counts and top-3 items.
- Downstream of research-subjects queueing: `cadence/hour/33-research-beat.sh`
  crystallizes queued subjects into lessons (per docstring, patrol.py:25-26);
  disposition tracking see hist-dispositions-b.md.

## 9. Format caveats

- read_runs regex (1251) requires the strict `FAIL <patrol>/<artifact>: <cause>`
  shape; the writer (1273) matches it. The `ok <id>` no-red line (1276) is
  intentionally NOT matched.
- Only two days of memory: a failure pattern broken by one clean day resets
  repeat detection; day boundary uses UTC (`time.gmtime`, 1234-1237).
