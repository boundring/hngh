# rp-patrol-emit — Stage 1 patrol emit: FAIL lines -> report-queue calls

Read-only exploration of `automation/jobs/patrol.py` (1532 lines). Sibling
artifacts: `rp-ledger.md` (write semantics/dedup), `rp-patrol-digest.md`
(digest side).

## 1. Machine contract

- stdout per check: `PASS <patrol>/<check> <detail>` or
  `FAIL <patrol>/<artifact> <cause> <detail>` (docstring :21-23; print
  sites patrol.py:1406-1409).
- FAIL collection: `run()` returns `(results, 0)` where each result has
  `passes`/`fails` of `(artifact, cause, detail)` triples (:1345-1389).

## 2. The single emit call site

`report_alert(text, identity, evidence=None)` — patrol.py:1321-1339:

- Binary: `REPORT_QUEUE_BIN` env override, default
  `<REPO>/scripts/report-queue` (:1327-1329). REPO = repo root (:47-48).
- argv: `[bin, "--add", "alert", text, "--identity", identity,
  "--window", "86400"]` + `["--evidence", evidence]` if evidence
  (:1332-1335). Window is hard-coded 86400 — the same default as
  report-queue's own `--window` default (rp-ledger).
- Environment: `HNGH_REPORT_ROOT` set from `PATROL_REPORT_ROOT` else REPO
  (:1330), so patrol writes into the same report root the cadence uses.
- Invoke: `subprocess.run(..., stdout/stderr DEVNULL, timeout=30)`;
  returns `r.returncode == 0`; OSError/SubprocessError -> False (:1336-1339).
  **Best-effort / fail-open**: a lost queue write is a suppressed False,
  never a crash.

## 3. Actual calls

| Site | Identity | Evidence token |
|---|---|---|
| patrol.py:1432-1436 — per FAIL in `main()` | `"patrol:" + pid` | `detail` (the failing detail string, i.e. the current-state token) |
| patrol.py:1522-1523 — runner crash handler | `"patrol:runner"` | `repr(exc)` |

- Text format at :1433: `"patrol %s: %s on %s -- %s" % (pid, cause,
  artifact, detail)`.
- Evidence semantics (docstring :1322-1326): with evidence, dedup only
  re-fires when the condition recurred (new detail); unchanged stale
  condition is suppressed within the 86400s window.

## 4. Exit codes

- `main()` returns 0 on normal completion (:1442) including when FAILs
  occurred (FAIL is a finding, not an error).
- Usage error: unknown patrol id -> `return [], 2` from run() (:1361-1362)
  and main returns rc (:1402-1404). Only usage errors exit 2 (:31-32).
- Runner crash: top-level `except Exception` at :1517-1524 files one
  `patrol:runner` alert and `sys.exit(0)` — a crumb, never tick damage
  (:30-31, :1519-1524).
- `SystemExit` re-raised (:1516), so argparse usage errors still exit 2.

## 5. Fail-open paths around the emit

- Check crash -> synthetic FAIL `(surface, "check-crash", repr(exc))`,
  remaining checks still run (:1381-1384). That FAIL then flows through
  the normal :1432 alert path (identity still `patrol:<patrol-id>`, not
  `patrol:runner`).
- Unknown check name in routes -> `unknown-check` FAIL (:1378-1380).
- Lost research-subjects append (queue_repeat_subjects :1297-1317):
  OSError swallowed (:1317), alert already fired independently.
- Quip failure swallowed (:1425-1428) — digest section unaffected.

## 6. Downstream of the emit (context for digest sibling)

- Findings append to `PATROL-<date>.md` (:1412-1422) before alerts fire.
- Repeat detection: `queue_repeat_subjects(ctx, prev_runs[-1], [(pid,
  cause)])` (:1437-1439) — patrol+cause on two consecutive runs appends a
  `patrol-<day>-<patrol>-<cause>` research-subjects line (:1297-1317);
  rids echoed as `QUEUED research-subject <rid>` (:1440-1441).
- Cadence callers: `automation/cadence/30m/58-patrol.sh:20` (`--tier 30m`)
  and `automation/cadence/day/27-patrol.sh:22` (`--tier day`), both
  capturing stdout for their own crumb handling.

## 7. Verified consistency with rp-ledger

- One identity per patrol per run (`patrol:<pid>`) + evidence token =
  same-cause suppression within 86400s, re-fire only on changed detail.
  Matches report-queue dedup rules documented in rp-ledger (default
  window 86400, evidence-keyed re-fire).
- Patrol never writes ledger rows itself; only via the report-queue
  binary, honoring `HNGH_REPORT_ROOT`/`PATROL_REPORT_ROOT` env seam
  (testable hermetically).
