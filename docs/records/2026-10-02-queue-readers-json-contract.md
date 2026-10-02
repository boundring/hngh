# 2026-10-02 — queue readers on the --json contract

## Conclusion

`scripts/dashboard-tui` and `scripts/osd-operative` consumed the
report queue through a flag pair that never worked, so the TUI's
queue tab permanently showed "queue not alive" and the osd status
strip silently omitted the reports bit. Both now call
`scripts/report-queue --json` (no `--unread`), read the payload's
real schema keys (`first`, `body`-as-text), and render again. The
contract is pinned by `tests/scripts/test-queue-readers-json.py`
(red before the fix: the exact dispatch-order failure plus both key
misreads; 3/3 after).

## Evidence

- Dispatch order: `scripts/report-queue` runs the `--unread`
  command before `--json`; with both flags the unread-count TEXT is
  what stdout carries, and `json.loads` fails. Both readers wrapped
  that in fail-closed handlers, converting a permanent contract
  break into a permanent empty render — the bug never surfaced as
  an error anywhere.
- Key misreads: the payload rows are
  `{"ts","kind","id","first","body"}` with `body` carrying body
  TEXT; the readers read `first_line` (absent — every first line
  rendered as empty) and treated `body` as a report-bodies
  filename.
- Fix shape: `scripts/dashboard-tui` `_reports()` drops `--unread`
  from the argv; `_report_body_text()` uses `body` text with
  `first` fallback (the report-bodies file-walk is gone — the
  payload resolves bodies already). `scripts/osd-operative`
  `report_status()` drops `--unread` and renames the key.
- Existing suites `tests/scripts/test-dashboard-tui.py` (5 tests)
  and `tests/scripts/test-osd-operative.py` (3 tests) stay green:
  they pinned only the fail-closed fallbacks, never live payload
  rendering — which is exactly how the break survived.
- Hermeticity: the new test seeds a sandbox queue through the
  `HNGH_REPORT_ROOT` seam (env holds for the readers' own
  subprocesses) and never touches the real ledger.

## Scope

Readers only; `scripts/report-queue` semantics unchanged (the
`--json` payload already carries only unread rows — the `--unread`
flag was always redundant for these callers). Found during the
close-half refactor discovery (plan
`hngh-close-half-refactor-plan`, slice S6); the read-side break
mattered because S2 made the digest the progress-cursor closer and
S1 made the cursor self-healing — consumers must render the stream
they now close.
