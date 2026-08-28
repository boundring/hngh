# 2026-08-28 — self-improvement cadence wave

The manual self-improvement loop (ledger prune, gate check, fresh-eyes
review, research beat) became routine cadence work in hngh-automation,
and the route docs were corrected to match.

## Landed

- AUTO `34cd275` — the orphaned 30m and hour tiers wired: `jobs/cadence-tick.sh`
  allowlist accepts `30m`/`hour`, systemd unit pairs
  (`hngh-cadence-30m.{timer,service}` OnCalendar `*-*-* *:00/30:00`,
  `hngh-cadence-hour.{timer,service}` OnCalendar `*-*-* *:00:10`),
  Makefile enable/disable lists, `cadence/README.md` tier table.
- AUTO `232c5fe` — telemetry store v0 (`jobs/telemetry.py`, SQLite WAL,
  capture-first, best-effort exit 0); day-tier drop-ins `02-ledger-prune.sh`
  (48h alert retention, archive, honest tracked-deletion alert),
  `03-gate-check.sh` (daily `make test`, progress/alert rows),
  `04-review-prep.sh` (fresh-eyes review of both repos' last 36h via the
  local model chain, `digest/REVIEW-<date>.md`, P0/P1 alert rows),
  `05-research-beat.sh` (round-robin `research-subjects.txt`,
  `digest/RESEARCH-BEAT-<date>.md`); schedule + research feeds mounted on
  the 30m tier; `bash -n` sweep added to AUTO `make test`.
- hngh ceremony `3a112a6` — roadmap working order item 1 corrected
  (config-backup 30m landed; cadence routine recorded with AUTO hashes),
  session-notes §10 (proceduralized scouting; the operator's
  arbitrary-event-watching capability decision), CHANGELOG bullet,
  and the day's drop-in ledger rows.
- Live proof: both timers listed with future NEXT times; the 21:00:00 EDT
  boundary produced a real 30m tick (5 drop-ins) and readout regeneration.

## Lessons

1. **Skill text drifts from closed vocabularies.** The ceremony skill
   named `evidence-before-flag`; the matrix (governance.lisp) defines
   `evidence-before-claim`. Docs that name closed-vocabulary values
   should be checked against source, not trusted.
2. **Refusal messages should name the fallback.** `mutation-check` without
   candidate-path positionals silently defaults to `candidate.lisp` and
   verify-candidate refuses with the opaque "invalid candidate manifest".
   The paths are positionals (`cdddr`), not options — a sharper refusal
   ("no candidate paths given, defaulting to candidate.lisp") would have
   saved a loop.
3. **Two counters disagreeing is a signal.** 04-review-prep counted P0/P1
   twice (a `case` loop and a `grep -cE '\tP[01]:'`); they disagreed, and
   the disagreement was the bug — GNU grep treats `\t` as a stray escape
   and matches nothing. Fixed with `awk -F'\t'`. Verify counters against
   each other; keep the honest one (breadcrumbs) as the tiebreaker.
4. **Gate on lint output before running.** `bash -n` caught the
   trailing-`\`-swallowed-`}` brace groups immediately; the failure was
   running anyway. The new AUTO `bash -n` sweep makes the check a gate
   instead of a suggestion.
5. **Breadcrumbs settle attribution.** The 19 prune-deleted bodies
   predated the wave (earlier manual proof run); one STATE.md grep dated
   them and the alert that reports them. Append-only breadcrumbs are the
   audit trail — check them before trusting recalled timelines.
6. **Async proof beats blocking.** Long drop-ins ran as background jobs
   with result-checks embedded in the same command; delivery carried the
   verdict. One watcher was lost to a default tool timeout — long sleeps
   need explicit timeouts.

## Open

- RESOLVED 2026-08-28: the 19 tracked body deletions landed via a manual
  `docs:` commit (hngh `c0c0bd5`) — the ceremony structurally cannot
  express deletions; the operator delegated the path choice.
- RESOLVED 2026-08-28: the AUTO lint false positives were fixed at the
  root (hngh-automation `02f7c1c`); `make test` is green.
- TRIAGED 2026-08-28: both fresh-eyes P1s were wording-level; bounds
  sentences added to ledger-and-records-spec.md and
  knowledge-base-spec.md. The store half of the first was already
  landed; the dual-write producer and the KB index remain
  designed-not-built.
