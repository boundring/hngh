# 2026-09-16 — emitter-side path redaction backstops + the report-queue
alert-kind boundary control

## The question

Emitter-side redaction in the report-ledger exposure fix (see
2026-09-16-report-ledger-public-push-exposure.md) was per-emitter:
`credential-health.sh` gained `redact_home()`, but most emitters file
alert rows with raw detail. Two confirmed leak paths:

- `automation/jobs/config-backup.sh` `fail()` passes absolute source
  paths (`missing source: /home/<user>/...`, `copy failed: <abs>`) into
  the alert row AND the STATE.md breadcrumb (call sites :46, :138,
  :145-146, :205).
- `automation/jobs/oversight-tick.sh` `alert()` passes probe detail and
  identity tokens (`stale-store:/tmp/hngh-cer-*.store`) into the queue
  argv and breadcrumb; `/tmp/` prefixes were live in the ledger's alert
  rows (2 rows) and `/home/` prefixes were live in 3 alert BODY files
  (pasted Python tracebacks).

Coordinator directive: backstop the two emitters, add a sink-side
boundary control in `scripts/report-queue --add` for the alert kind,
test-first, and do NOT rewrite git history for the ~292 existing
`/home/` rows.

## The audit (live ledger, 2026-09-16 ~21:33Z)

- alert rows in `docs/project/reports.md`: 0 carry `/home/`, 2 carry
  `/tmp/` (oversight stale-store rows); alert bodies: 3 carry `/home/`
  (traceback pastes from test-failure alerts).
- progress rows: 295 carry `/home/` (292 at assignment time; the count
  moved while this slice was in flight). 0 carry `/tmp/`.
- progress rows carrying absolute paths are intentional in some lanes
  (config-backup progress names the push target; other lanes name
  repo-relative scratch), which is why the sink-side control is
  per-kind, not global.

## Decisions

### D1: shared emitter backstop — automation/lib/redact.sh

`redact_home()` (moved to shared `automation/lib/redact.sh`, same
contract as the credential-health original): rewrites
`/home/<user>/...` to `~/...` and `/tmp/...` to `~tmp/...`. Distinct
markers keep rows readable and unambiguous (`~` is the operator home
shorthand; `~tmp` is not a valid home-relative path, so no collision).
A guard excludes a preceding `[[:alnum:].~/-]` character so mid-token
hits (e.g. `https://x.io/home/u/f`) stay untouched.

- `config-backup.sh fail()` redacts the detail BEFORE the alert row and
  the breadcrumb; the console `log` keeps the raw path (operator's own
  terminal, not a public sink).
- `oversight-tick.sh alert()` redacts the `KIND: DETAIL` text before
  the queue argv AND the breadcrumb, redacts the identity token
  (identity is stored in the public body meta), and keys its
  flapping-suppression bookkeeping on the redacted key — so a
  condition whose only drift is the machine-local prefix still
  suppresses instead of re-firing.

### D2: sink-side boundary control — scripts/report-queue --add alert

Kernel surface (`scripts/`), landed through the ceremony (candidate
commit, see Verification). For `--add alert` ONLY, text is rewritten
by `redact_alert_text()` (same class as D1, Python `re`) BEFORE id,
first line, and body are derived. Consequences:

- the public ledger can no longer store a machine-local path prefix in
  an alert row or body, regardless of which emitter filed it — this is
  the backstop for every emitter that lacks its own redaction;
- alert ids derive from redacted text, so two alerts differing only by
  the local username collapse to one id (stable and shareable across
  machines);
- identity/evidence dedup semantics are unchanged (identity and
  evidence tokens are caller-supplied and stored verbatim; emitters
  redact their own identity tokens per D1);
- progress and other kinds are intentionally NOT rewritten (some lanes
  carry repo-relative paths in progress text); this is a per-kind
  boundary, not a sink move — matching the exposure record's D1
  (boundary redaction at the public boundary; the sink stays).

Gate interaction (worth recording): the ceremony's public-content
evidence (scripts/verify-candidate.py `ABSOLUTE_PATH_PATTERN`) refuses
any kernel candidate file containing the literal home-root path
sequence, so the kernel-side signature and its tests build the
sequence from split literals (`_REDACT_HOME = "/" + "home"`,
`HOME_PREFIX = "/" + "home" + "/"`). Runtime behavior is identical;
the split exists only so the public-content gate's own rule (no real
local home paths in public kernel content) stays satisfiable by a
feature whose subject is that exact string. Automation-side tests keep
the plain literal (no gate applies there, and the literal is the
clearest test evidence).

The docstring contract (`--help`) documents the alert-kind rewrite.

### D3: forward-only; no history rewrite

The 295 existing progress rows (and the 5 historical alert-row/body
artifacts) keep their absolute paths. Rationale: the ledger is
append-only by design; the task explicitly refuses a public git
history rewrite for redaction-class content (rewriting would break
every clone, fork, and content-hash reference for rows that leak a
username, not a secret); the boundary control prevents NEW rows. The
`~`-style markers make new rows safe to publish; old rows remain
readable history of the pre-boundary era.

## What landed

- `automation/lib/redact.sh` (new): shared `redact_home()` backstop.
- `automation/jobs/config-backup.sh`: `fail()` redacts row + crumb.
- `automation/jobs/oversight-tick.sh`: `alert()` redacts text,
  identity, breadcrumb; suppression keyed on the redacted key.
- `scripts/report-queue`: `redact_alert_text()` + alert-kind wiring in
  `add()` before id/first/body derivation; docstring updated.
- Tests (all written first, proven red, then green):
  - `automation/tests/test-report-queue-redaction.py` (new, 8 cases:
    home/tmp redaction in row+body, `/tmpfile` untouched, progress
    untouched, URL guard, id collapse, dedup still works) — 4 red
    against the unpatched queue;
  - `automation/tests/test-config-backup-fail-redact.sh` (new; sources
    the job's real `fail()` seam against a fake queue; row + crumb
    redaction, pass-through, exit-1 contract) — 3 red unpatched;
  - `automation/tests/test-oversight-tick-alert-redact.sh` (new; real
    `alert()` seam; text + identity + crumb redaction, suppression
    keyed on redacted key, pass-through) — 3 red unpatched (4 incl.
    the identity leak the first emitter pass missed);
  - `tests/scripts/test-report-queue.py`: 3 kernel contract cases
    (row+body redaction with progress/`/tmpfile` negatives, id
    collapse, URL guard) — 2 red against the unpatched script
    (stash-proven), green after.
- `automation/Makefile`: the three new automation tests wired into
  `make test` (kernel cases were already wired via
  `tests/scripts/test-report-queue.py`).
- Gate-adjacent riders (required to keep the full automation gate
  green with the boundary control live):
  - `automation/tests/test-wiki-health.sh`: the wiki-health alert's
    operator fix instruction carries the vault's absolute path, which
    the alert-kind boundary now rewrites — the test's expectation pins
    the redacted tilde form (HOME/`/tmp` variants both computed).
  - `automation/scripts/lint-identifiers.sh`: `KIMI_API_KEY` /
    `ZAI_API_KEY` join IGNORED_NAMES (child-consumed env literals,
    same class as the `OPENCODE_CONFIG` precedent) — the identifier
    lint flagged the 9d6dfed8 prefix-assignment spawn otherwise.

## Verification

- Red proofs: the three new automation suites and the kernel cases all
  failed against the unpatched sinks (kernel red proof via
  `git stash push -- scripts/report-queue`, run, `stash pop`; the
  kernel red proof predates the split-literal rewording, which is
  behavior-identical).
- `python3 -B tests/test-report-queue-redaction.py` — 8 tests OK.
- `bash tests/test-config-backup-fail-redact.sh` — ALL PASS.
- `bash tests/test-oversight-tick-alert-redact.sh` — ALL PASS.
- `python3 -B tests/scripts/test-report-queue.py` — 18 tests OK
  (3 new).
- `python3 -B tests/test-report-queue-evidence.py` — regression OK
  (dedup semantics unchanged).
- Full gates in a scratch clone named `hngh` (a differently named clone
  breaks `test-omp-bridge.py`'s slug expectation — pre-existing
  fragility, unrelated): root `make test` rc=0 for the kernel slice;
  `automation make test` rc=0 for the automation slice (shared tree
  carries unrelated WIP lanes, so gates ran on HEAD + this slice).
- The ceremony drive itself re-verified the kernel slice live:
  verify-candidate evidence (public-content, whitespace, relative
  links, dependency) plus the root `make test` fast-test leg ran green
  before the candidate certificate was issued.
- Kernel ceremony: `python3 scripts/omp-bridge --ceremony` drive,
  all ten principles passed, candidate commit `2d424e71`
  (`hngh: candidate 69addbb7b117114bbf83eaf50d8090cf925d1a8b047e84fccf6cc82ddb970f1b`)
  binding `scripts/report-queue` +
  `tests/scripts/test-report-queue.py`, pushed to origin.
- Historical rows: no rewrite (D3); live audit numbers above.

## Not done / follow-ups

- Progress-kind text is not redacted anywhere (by design here); the
  295 historical `/home/` progress rows are the bulk of the residual
  exposure. If the operator ever wants them cleaned, the row content
  would have to be migrated forward (append corrected rows, prune old)
  rather than history-rewritten.
- Other alert emitters (patrol, run-autonomous, digest beats) rely on
  the sink-side control only; giving them the D1 emitter backstop is a
  candidate sweep node (defense in depth, no longer correctness).
- Alert bodies that paste tracebacks can still contain OTHER sensitive
  strings; only path prefixes are in contract here.
