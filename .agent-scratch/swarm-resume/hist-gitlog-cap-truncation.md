# hist-gitlog-cap-truncation: newest-wins truncation rule for the gitlog feed

Date: 2026-09-15. READ-ONLY spec, no repo files edited. Builds on
hist-windows-caps.md (two-layer caps), hist-windows-git.md (7d window + newest-400
cap), hist-gitlog-b.md (spine inventory).

## 1. Observed ordering/truncation conventions in existing feeds

The repo convention is overwhelmingly **newest-first ordering + keep-the-head
slice** (sort desc, then `[:N]` / `head -n N` / `[:limit]`), never
oldest-first-then-keep-tail for display feeds:

1. `scripts/report-queue:255-256` — `def newest_first(rows): return
   list(reversed(rows))`; consumed at `scripts/report-queue:305`, `:311`, `:325`
   (queue listings and JSON export present newest first). The append-only
   ledger at `scripts/report-queue:248-250` appends newest LAST (chronological
   file order), and every read path reverses it.
2. `scripts/report-queue:224` — `for r in reversed(read_rows()):` scans the
   ledger newest-first when deduplicating/bumping prior reports.
3. `scripts/dashboard-readout:168-171` — session stores sorted by
   `record.lisp` mtime `reverse=True`; then `scripts/dashboard-readout:176`
   slices `stores[:limit]` (line 156: `session_rows(limit=5, ...)`).
4. `scripts/dashboard-readout:278-280` — roster candidates
   `.sort(key=lambda c: c[0], reverse=True)` then `candidates[:limit]`
   (roster_rows limit=15, line 258). Sort-desc-then-slice is the exact shape
   proposed for gitlog.
5. `automation/cadence/hour/10-router-feed.sh:5,48` — "picks distinct routable
   identities newest-first", iterating `for r in rows:  # newest-first` and
   stopping on the per-tick cap.
6. `automation/cadence/day/04-review-prep.sh:40-41` — after a `git log`
   listing, `oldest=$(... tail -n 1)` and `newest=$(... head -n 1)`: git-log
   native output order is newest-first, and head/tail index that order
   directly.
7. `automation/cadence/day/19-ux-review.sh:75` and
   `automation/cadence/day/10-bench-fresh.sh:13` — newest-artifact pickers:
   `ls -1t ... | head -1` / `ls -t ... | head -n1`.
8. `automation/lib/common.sh:40-46` — `newest_snapshot()`: "iterate the
   sorted glob and keep the last match (= highest HHMM = newest)"; same
   newest-wins intent expressed as keep-the-max.
9. Counter-example (deliberate, NOT a display feed):
   `automation/jobs/feedback-ingest.py:96` and
   `automation/cadence/30m/54-feedback-ingest.sh:4` — operator-items ingest is
   "capped 20/tick oldest-first": a *work-drain* queue consumes oldest first
   so nothing starves. That is a processing-order rule, not a presentation
   rule; it does not apply to the recency spine.
10. Chapter/ebook assembly, `scripts/generate-publication:592` —
    `sorted(matched)`: lexicographic stem sort = chronological for
    date-stemmed files (`YYYY-MM-DD`), i.e. oldest-first for a *book*
    ordering. Again not a recency feed.

## 2. Spec: gitlog feed truncation rule (newest-wins)

For the recent-history spine gitlog source, per hist-windows-git.md §2
(`--since = now_utc - 7d`, cap 400; hist-windows-caps.md table: gitlog
per-source cap 200 in the two-layer scheme — apply whichever layer this feed
is specified under, the RULE is identical):

1. Producer emits `git log --format=%s%x09%h --since=<start>` with NO
   `--max-count` (matches the existing spine,
   `scripts/generate-publication:103-111`, which passes no cap). Fetch the
   full window, do not pre-cap inside git.
2. Sort entries `ts` descending (tie-break: `key`/hash ascending for
   determinism). For a raw producer that trusts git, native `git log` order is
   already newest-first (evidence: `automation/cadence/day/04-review-prep.sh:40-41`),
   so sorting is a normalization pass over parsed rows, not a re-query.
3. Truncate by slicing the head: `entries[:cap]`. Keep the FIRST `cap` rows of
   the desc-sorted list. Newest-wins: the newest 400 (or per-source 200)
   entries survive; older entries in the window are dropped.
4. Never use the oldest-wins shape (`entries[-cap:]`); never drop mid-list;
   never narrow `--since` to emulate a cap (hist-windows-git.md §2: density
   is uneven, date window and cap are independent controls).
5. No partial-window/truncation marker in the payload (hist-windows-git.md §2;
   history/1 envelope has no such field). No padding or backfill when fewer
   than cap entries exist — emit what the window yields.
6. Rationale from convention: every existing display feed in this repo
   (report-queue newest_first, dashboard-readout sort-reverse-then-slice,
   router-feed newest-first scan) presents newest-first and bounds size by
   keeping the head. A gitlog feed that kept the OLDEST 400 would contradict
   every sibling feed and would show the start of the week instead of now.

## 3. Interaction with the merged feed

Per hist-windows-caps.md §2-3: per-source caps apply first (this slice), then
the merged list is re-sorted `ts` desc across all sources and cut to the total
cap (500) — again head-keeping. So gitlog truncation is newest-wins at BOTH
layers, and the final feed ordering is genuine timestamp interleave with
newest entry first.
