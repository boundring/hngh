# omp changelog watch lane (2026-09-27)

Directive: 2026-09-27 operator instruction to integrate new oh-my-pi
changes into hngh operations daily, checking
packages/coding-agent/CHANGELOG.md with regularity.

Design: automation/cadence/calendar/daily/28-omp-changelog-watch.sh
fetches the upstream changelog once per day (UA-pinned, 30s timeout),
diffs released version headings against a last-seen state file in the
userspace home (db/omp-changelog/last-seen; two-home split respected,
nothing committed from it), and files one identity-deduped progress row
per new release (identity omp-changelog:<version>, 30d window) so
releases surface in the operator newspaper and feed the daily
integration lane. First run only arms the watch (one armed row, state =
newest) so a fresh install never floods the queue. A failed fetch files
a fetch alert (7d window) and leaves state untouched. When last-seen is
absent from upstream headings (history rewrite) or the backlog exceeds
the per-run cap (5), the watch re-arms with one alert row instead of
flooding. Fail-closed: every path exits 0; on success only breadcrumbs
escape.

Out of scope by design: no auto-upgrade of the omp package, no LLM
summarization of changelog entries, and no automatic adoption of new
features -- evaluation of each release stays with operator sessions
reading the filed rows.

Verification: automation/tests/test-omp-changelog-watch.sh (15
assertions, hermetic file:// fixtures): arm, idempotent re-run,
per-version rows oldest-first, state advance, fetch-failure alert with
untouched state, history-rewrite re-arm.
