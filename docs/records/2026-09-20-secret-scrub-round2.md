# Secret scrub round 2: journal env leak + OPENCODE history purge (2026-09-20)

Operator-directed security pass, executed 2026-09-20. Two separate
incidents converged today: a systemd journal credential leak and a
second git-history rewrite for the OPENCODE API key.

## 1. systemd journal env leak

### Mechanics

`~/.config/plasma-workspace/env/env_vars.sh` holds 29 lines in
`export KEY=value` form (a normal Plasma session startup env file,
sourced by startplasma). 14 hngh unit drop-ins referenced this file via
`EnvironmentFile=`. systemd's EnvironmentFile parser is not a shell:
it treats the line literally, so the full `export KEY=value` text was
accepted as an environment entry whose VALUE contained the verbatim
line, and it was logged into the persistent systemd journal whenever
units printed or dumped their environment. Result: 29 key-value lines
echoed verbatim into the persistent journal.

### Exposure window

- Env file mtime: 2026-09-18 10:08 EDT (when the export-form content
  landed).
- Journal evidence from: 2026-09-18 13:56 EDT (system journal).
- Leak continued until 2026-09-20 ~11:22 EDT, when the units were
  repointed and hngh timers halted.

### Exposure scope

29 distinct keys (names only; values are never reproduced here). The
key set includes provider API keys used by automation (OpenCode,
OpenRouter, and other provider/model credentials among the 29).
Any operator with journal read access (or any process on the host with
journal access) could read all 29 values for roughly two days.

### Remediation

- All 14 hngh unit EnvironmentFile drop-ins repointed to
  `~/.hngh-automation/unsloth.env` (two-home secrets side, 0600
  permissions).
- All hngh timers halted; research beats halted.
- Research beats were independently halted after a degenerate
  all-'a' user-prompt incident (tracked separately under
  session_penguin investigation, not part of this record's scope).

### Open items

- Rotation of all 29 exposed keys: bead hngh-ag3 (open).
- Journal vacuum: the persistent journal still contains the leaked
  lines; needs a vacuum/rotation pass to shrink retention (requires
  journalctl operator action).
- Remaining keys still resident in the plasma env file pending
  migration to `~/.hngh-automation/`; the file itself is not a leak
  vector while no unit references it, but it should be drained.

## 2. Git-history scrub round 2 (OPENCODE sk- prefix)

### Why a second round

Round 1 (2026-09-20 b7ee5f1f, see
`docs/records/2026-09-20-git-history-secret-scrub.md`) purged `ghp_`
shapes from all history but treated the OPENCODE_API_KEY only as a
tip-redaction in 339a2f4e (bead hngh-dzf): current files were cleaned,
but the key with prefix `sk-7ZXC` remained in 4 historical blobs in
main's reachable ancestry (0bf0a666, 2158f2e3, 64716cec, afc75ef7).
The repo is public (boundring/hngh), so those blobs were publicly
fetchable.

### What round 2 did

- git filter-repo rewrite of the FULL history in an isolated mirror
  clone, with a literal replace-text rule `sk-7ZXC` -> `***REMOVED***`
  (prefix-shape rule; full value never written into rule files).
- Pre-scrub backup bundle (contains the secret; never push):
  `~/.hngh-automation/hngh-pre-scrub-backup-20260920.bundle`
  plus local tag `pre-scrub-backup-20260920`.
- Force-pushed rewritten `refs/heads/main` to origin.

### Verification / limits

- The exposed key is verified dead upstream (rotated), so residual
  exposure is value-nonlive.
- GitHub-side unreachable objects: pre-rewrite commits/blobs remain
  on GitHub's servers until their platform GC. A support request is
  being filed (draft:
  `.agent-scratch/github-gc-support-request.md`) asking GitHub to run
  garbage collection and stop serving cached views / raw endpoints of
  pre-rewrite objects, per
  https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository.
- As with round 1: other clones may still hold pre-rewrite objects
  locally and must not force-push old history back.

## Follow-ups

- hngh-ag3: rotate all 29 journal-exposed keys.
- Journal vacuum (operator lane; persistent journal holds leaked
  values until vacuumed).
- Drain remaining keys out of the plasma env file into
  `~/.hngh-automation/`.
- Confirm GitHub support GC completion; re-probe raw/codeload
  endpoints for pre-rewrite SHAs afterwards.