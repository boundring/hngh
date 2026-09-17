# Journal source location spec (recent-history spine)

Task: `hist-journal-location` — canonical repo-relative path, ROOT/JOURNAL_DIR
seam, kernel vs automation repo ownership, HNGH_HOME resolution for the
journal source feeding the recent-history spine. Read-only exploration,
2026-09-15.

## 1. Canonical path

- The journal lives in the **kernel repo checkout**, at repo-relative
  `docs/journal/`, one file per UTC day: `docs/journal/YYYY-MM-DD.md`
  (e.g. `docs/journal/2026-09-15.md`). Confirmed present: files from
  2026-08-25 through today, plus subdirs `docs/journal/ebook/` (generated
  book artifacts, per records 2026-09-06).
- Nothing journal-related lives under the userspace home `~/.hngh/`
  (actual listing: `archive/ catalog.tsv db/ dispatch/ imagegen/ manga/
  newspaper/ tools/ wiki/` — no journal dir). The journal is a
  **committed kernel-repo doc surface**, not userspace data. Do not route
  it through `hngh_home()` / `HNGH_HOME_DIR`.

## 2. The ROOT / JOURNAL_DIR seam (kernel scripts)

Two kernel scripts define the seam, both override-able for hermetic tests:

- `scripts/generate-publication` (lines 59-61):
  `ROOT = Path(os.environ.get("HNGH_PUB_ROOT") or Path(__file__).resolve().parent.parent)`
  then `JOURNAL_DIR = ROOT / "docs" / "journal"`.
- `scripts/run-autonomous` (lines 45-47):
  `ROOT = Path(os.environ.get("HNGH_RUN_ROOT") or <script's parent.parent>)`
  then `JOURNAL_DIR = ROOT / "docs" / "journal"`.

So the env seams are per-script: `HNGH_PUB_ROOT` (generate-publication) and
`HNGH_RUN_ROOT` (run-autonomous). Tests exercise them by monkeypatching
`mod.JOURNAL_DIR = Path(tmpdir)` directly (`tests/scripts/test-generate-publication.py`)
rather than via the env var. Note: `scripts/` is kernel code surface
(machine sessions don't touch it without ceremony), and env seams there are
for tests only, not a production path override.

generate-publication also has `hngh_home()` (lines 71-76: `HNGH_HOME_DIR`
or `~/.hngh`) but that is only for telemetry/digest DBs — explicitly
documented "the kernel does not import it" — and is **never** used for
journal paths.

## 3. Who writes `docs/journal/`

Machine-owned surface (docs/research/2026-09-02-biographic-cadence-design.md:
"docs/journal/ stays machine-owned and is cited, not rewritten"; the day-tier
capture cites it, NEVER rewrites it). Writers:

- `scripts/run-autonomous` (kernel, hourly hngh-autonomy.timer): generates
  the **previous day's** journal on the first tick of a UTC day
  (`journal_day()` = today-1, to avoid the 0-commits freeze bug, see
  docstring lines 66-79) by invoking `generate-publication --daily`;
  refuses if the file already exists.
- `scripts/generate-publication --daily [DATE]`: compiles
  `docs/journal/YYYY-MM-DD.md`; refuses overwrite when present; `--check`
  validates counters; `--force` refreshes drifted machine-ledger journals
  (operator-authored ones — no `- **N** commits` header — are never touched).
- `automation/jobs/daily-writeups.sh` (morning): locates the kernel checkout
  via `KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"` (from
  `automation/config.env:57`, where `HNGH_HOME` = the kernel repo path —
  a DIFFERENT meaning from userspace `HNGH_HOME_DIR`!), then runs drift
  refresh over `docs/journal/$day.md` for yesterday/today.
- `automation/cadence/hour/30-kernel-ledger-sync.sh`: commits changed
  kernel doc surfaces `docs/journal docs/project docs/design docs/research`
  as one dated sync commit (writer of the git history, not the file content).
- Operator can hand-author a journal (e.g. 2026-08-25 per records);
  machine then refuses to overwrite it.

## 4. Path resolution rules for the spine

For the recent-history spine reading journals, resolve in this order:

1. Repo-relative: `docs/journal/` inside the kernel repo root (the same
   root as this exploration: `/home/bricker/Projects/etc/hngh`). Glob
   pattern `docs/journal/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md`
   (daily files only; excludes `ebook/` subdir).
2. Root override seams: honor `HNGH_PUB_ROOT` / `HNGH_RUN_ROOT` if set
   (test hermeticity), else `Path(__file__).resolve().parent.parent` style
   repo-root anchoring. In the automation tier the kernel checkout is
   `HNGH_HOME` (config.env) defaulting to `$HOME/Projects/etc/hngh`.
3. NEVER resolve journals via `HNGH_HOME_DIR` / `~/.hngh` — that home is
   for newspaper/manga/db/dispatch/wiki outputs only; journals are
   committed repo docs.
4. Files are UTF-8 markdown, machine-ledger journals carry the header
   `- **N** commits` (the drift-refresh eligibility marker); operator-
   authored ones lack it.

## 5. Naming-collision hazard (flag for implementers)

`HNGH_HOME` (kernel repo checkout path, automation config.env) vs
`HNGH_HOME_DIR` (userspace `~/.hngh` data home) vs `HNGH_PUB_ROOT` /
`HNGH_RUN_ROOT` (kernel-script test seams). The recent-history spine must
not conflate them: the journal source is the kernel repo root via
`HNGH_PUB_ROOT`/`HNGH_RUN_ROOT`/repo-anchored `ROOT`, or automation-side
`HNGH_HOME`, never the userspace home.

## Sources

- scripts/generate-publication:59-76 (ROOT/JOURNAL_DIR/hngh_home)
- scripts/run-autonomous:45-47,66-79,94-101 (seam, journal_day, existence)
- automation/jobs/daily-writeups.sh:10-47 (KERNEL resolution, drift refresh)
- automation/cadence/hour/30-kernel-ledger-sync.sh:26-33 (commit surfaces)
- automation/config.env:57-58 (HNGH_HOME = kernel checkout)
- tests/scripts/test-generate-publication.py:41-72 (JOURNAL_DIR monkeypatch)
- docs/research/2026-09-02-biographic-cadence-design.md (machine-owned rule)
- ~/.hngh listing (no journal dir in userspace home)
- docs/journal/ directory listing (2026-08-25..2026-09-15 daily files)
