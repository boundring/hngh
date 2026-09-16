# 2026-09-16 — report-ledger public-push exposure: path redaction,
# alert dedup, and the single-ledger policy

## The question

Alert rows are appended to `docs/project/reports.md` and
`docs/project/report-bodies/`, which are git-tracked and pushed to the
public `origin` (`git@github.com:boundring/hngh`). Two exposures were
left open by prior nodes:

1. Credential alert text interpolated absolute home paths (leaking the
   operator's username) and had no dedup, so a persisting condition
   (e.g. `ledger-missing: /home/<user>/.hngh-automation/
   credential-freshness.tsv`, `evidence-missing: <token file path>`)
   appended one identical public row per run, forever.
2. A second report ledger had forked at `automation/docs/project/`
   (same public repo, but invisible to the kernel dashboard, unread by
   `--unread`/cursor consumers, and never pruned by `day/02`).

Decision recorded here; both closed in the automation free-commit lane.

## Decisions

### D1: Paths are tilde-redacted at the public boundary; the sink stays

The freshness alert sink stays at the kernel report ledger (the
dashboard, `--unread`, the prune beat, and email digests all read it;
moving it would fork visibility, not fix exposure). Every public-bound
path is redacted `$HOME -> ~` before it reaches a row:

- `automation/lib/credential-evidence.py` (`redact()`, applied to the
  `ledger-missing`, `evidence-missing`, and `hash-mismatch` finding
  classes — the only classes that interpolate paths). The private TSV
  ledger keeps absolute paths.
- `automation/jobs/credential-health.sh` (`redact_home()` inside
  `alert()`) is the backstop for every alert seam, including the
  `$TOKEN_FILE` interpolation in the missing-token alert.

Known residual: historic private breadcrumbs/STATE.md lines may carry
absolute paths; that file is untracked (private sink) and out of scope
here.

### D2: Alert dedup via identity + evidence (row flood cannot recur)

`alert()` now passes `--identity credential:<name>:<shape>` (digits
normalized, so `http=500` and `http=502` share a shape but different
evidence) and `--evidence` (the observed http code when present, else a
checksum of the redacted finding text) with `--window 0` (unlimited
lookback). Contract, per `scripts/report-queue --help`:

- identical finding re-observed: folded into the existing row's `×N`
  marker, zero new rows;
- persisting condition re-checked with unchanged evidence: suppressed
  with a body breadcrumb;
- the condition changes (e.g. different http code): one new row.

So a condition that fires every 5 minutes produces one public row plus
occurrence markers, not one row per run.

### D3: One report ledger; the automation/docs fork is retired

Policy: there is exactly one machine report ledger, the kernel's
`docs/project/reports.md`. No automation job may derive a report root
from the process cwd. Root cause of the fork:
`automation/jobs/hygiene.py::report_root()` fell back to
`os.getcwd()`, and under cadence-tick the cwd is inside
`automation/`, so its two 2026-09-15/16 progress rows landed at
`automation/docs/project/reports.md` + untracked bodies. Fix: the
report root is structural — `HNGH_REPORT_ROOT` override, else the
parent of `automation/` (the kernel repo) — never cwd. The two stray
rows were migrated into the kernel ledger (identity-bearing) and the
forked file reverted; the second ledger now holds only its pre-fork
prose.

## What landed

- `automation/lib/credential-evidence.py` — `redact()`; public-bound
  findings carry `~`-paths (ledger-missing / evidence-missing /
  hash-mismatch).
- `automation/jobs/credential-health.sh` — `alert()` gains
  `--identity/--evidence/--window 0` + `redact_home()` backstop.
- `automation/jobs/hygiene.py` — `report_root()` pins to the kernel
  root (`KERNEL_ROOT = parent of automation/`), docstring contract
  updated.
- `automation/docs/project/reports.md` — reverted to pre-fork state;
  stray bodies removed; rows migrated.
- Tests: `automation/tests/test-credential-evidence.py`
  (`test_path_findings_never_leak_absolute_home`),
  `automation/tests/test-credential-alert-dedup.sh` (new; sources the
  job's real `alert()` seam against a fake queue and asserts
  identity/evidence/redaction contract),
  `automation/tests/test-hygiene.py`
  (`test_07_report_root_never_falls_back_to_cwd`, hermetic sandbox
  tree).

## Verification

- `python3 -B automation/tests/test-credential-evidence.py` — 7 tests OK
  (new test red first).
- `bash automation/tests/test-credential-alert-dedup.sh` — ALL PASS.
- `python3 -B automation/tests/test-hygiene.py` — 8 tests OK (new test
  red first against the cwd fallback; now green, live ledger untouched).
- `bash -n` on the touched shell jobs; automation suite slices below.
- Historical leak audit: `git grep` over every commit touching
  `docs/project` found no committed absolute-home credential path (the
  exposure existed in the writer, not yet in published history), so no
  history rewrite is required; redaction + dedup prevent first leak.

## Not done / follow-ups

- The existing `credential unsloth-token: session token file missing`
  alert carries `$TOKEN_FILE` from config.env (an absolute home path at
  runtime); the `redact_home()` backstop now rewrites it, but a
  config-level default under `~/.config/hngh/` would remove the class.
- `automation/docs/project/report-bodies/` still exists (pre-fork
  bodies for the two rows were deleted; dir may be empty and untracked
  until the next automation sweep notices).
- Alert-lifecycle flows outside credential-health (e.g. patrol) already
  use identity; a repo-wide sweep for identity-less `--add alert`
  callers is a candidate follow-up node.
