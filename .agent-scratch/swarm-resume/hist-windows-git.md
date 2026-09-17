# hist-windows-git: per-source extraction window for the git history source

Date: 2026-09-15. READ-ONLY spec; no repo files edited. Builds on sibling
artifacts hist-gitlog-dedupfmt-shape.md (entry shape, producer command) and
hist-windows-schema.md (merged feed envelope, dedup keys, ordering). This
artifact fixes the WINDOW layer only: commit range, date bounds, file
scoping, and the hand-off format for the merge layer.

## 1. Repo facts measured (live, 2026-09-15)

- `git rev-list --count HEAD` = 1470 commits; first commit author date
  `2026-06-22T13:20:00-04:00`; HEAD at spec time `2026-09-15T09:54:27-04:00`.
- Trailing-window sizes: `--since=2026-09-01` -> 879 commits;
  `--since=2026-09-08` (7 days) -> 753 commits;
  `--since=2026-09-14` (24h) -> 178 commits; merges in the 7d window: 0
  (merges exist repo-wide but none recent, so `--no-merges` would change
  nothing today; per the sibling shape spec the feed still does NOT pass
  `--no-merges`, to stay consistent with the publication spine
  scripts/generate-publication:103-111).
- Commits average ~100+/day in the recent regime, so a date-bounded window
  is the correct primary control; a cap is the secondary safety bound.

## 2. Chosen window: trailing 7 days + hard cap 400

```
start = now_utc - 7 days   (trailing, recomputed at build time)
end   = now_utc            (no future filter needed; git ignores the future)
```

- Rationale for 7 days: matches the recent-history spine's purpose
  (operator "what happened this week" view) and the sibling sources'
  scale — reports ledger is a trailing-24h dashboard read plus a full
  append-only store (hist-reports-window), records is date-prefixed files
  with ~30 records in the last 3 days (hist-records-recency), journal is
  23 daily files. A 24h gitlog window (178 commits) would visually drown
  the ~10-30 non-git entries per day in the merged feed; 7 days yields
  ~753 gitlog entries vs roughly a hundred other-source entries, still
  git-heavy but scannable, and it degrades gracefully if the pace drops
  (empty window is a valid feed, see section 5).
- Hard cap: after `--since` filtering, keep the newest 400 entries
  (truncation rule = newest-wins, matching the sibling cap spec
  hist-gitlog-dedupfmt-cap). 400 bounds the merged payload at ~150-200 KB
  worst case (gitlog entries are ~200 bytes serialized) while covering
  even the hottest observed days. If `--since` yields more than the cap,
  the producer truncates and does NOT emit a partial-window marker (the
  history/1 envelope has no such field; freshness is the file stamp per
  the sibling shape spec).
- Window boundary is INCLUSIVE-START per git semantics: `--since=<ISO>`
  includes commits with author date > the instant. Boundary-straddling
  commits (exactly at the cutoff second) may flip in/out between builds;
  this is acceptable for a display feed — do NOT add explicit range
  anchoring (e.g. pinned SHA ranges), because a SHA-anchored range makes
  the feed depend on unreachable history and breaks reproducibility after
  rebase/gc. The commit HASH-keyed dedup (sibling spec) makes any
  window-edge nondeterminism harmless for the merge layer.

## 3. Date bounds: author date, UTC normalization

- Filter on `--since` (git filters on commit date by default for
  `--since`, but entries carry AUTHOR date per the sibling shape spec).
  Note the mismatch explicitly: git's `--since`/`--until` match COMMIT
  date. In this repo `%aI` == `%cI` in 499/500 recent commits (rebase
  artifact only), so the drift is one commit at most and not worth a
  client-side filter pass; however, the producer SHOULD still apply a
  cheap client-side guard `entry.ts >= start_iso` after normalization so
  the emitted window is defined on the SAME timestamp the feed sorts by
  (author date, Z form). This guard is 5 lines and makes the window
  self-consistent.
- All bounds computed in UTC: `start_iso = (datetime.now(timezone.utc) -
  timedelta(days=7)).strftime('%Y-%m-%dT%H:%M:%SZ')`, passed to
  `git log --since=<start_iso>`. Git accepts the Z form. Producer's
  injectable `now` (test seam, same pattern as graph-data.py `build(now=)`
  per hist-reports-window section 3) makes the window hermetic in tests.

## 4. File scoping: whole tree, no path filter

- The gitlog source is deliberately UNFILTERED: no `-- <path>` argument,
  no `--no-merges`, no author filter. Rationale:
  - The spine renders "what happened in the repo"; kernel, automation,
    docs, and scripts commits are all legitimate history events.
  - A path filter would silently hide slices (e.g. `docs/` only would
    drop every ceremony and automation commit) and duplicate information
    the records/journal sources already carry.
  - Per-repo history is what the commit-hash dedup key assumes
    (`gitlog:<40-hex>`, sibling spec); path scoping does not affect key
    uniqueness but would affect the summary selection per key.
- Commit BODY is out of scope (flat entries, validator rule
  viz_schema.py:309-322); only `%H %h %an %aI %s` are extracted, per the
  sibling shape spec. Files-touched metadata is a future schema/2
  question, not this window.

## 5. Producer command (final form, verified flags)

```
git log --since=<start_iso_UTC_Z> \
        --pretty=format:'%H%x09%h%x09%an%x09%aI%x09%s'
```

Then: parse rows -> normalize `%aI` offset to Z -> client-side guard
`ts >= start` -> sort `ts` desc, `key` asc -> truncate to newest 400 ->
emit per sibling shape (`key` = `gitlog:<full sha>`, `ts`, `summary`,
`author`, `short`). Empty result emits the valid empty feed
`{"schema": "history/1", "entries": []}`.

Output format for downstream merge (per-source intermediate): the producer
hands the merge layer a list of already-shaped, already-deduped,
already-truncated history/1 entry objects (NOT raw git rows). The merge
layer (hist-windows-schema section 5) interleaves by `ts` with the other
sources and never re-truncates. This keeps window ownership fully inside
the gitlog producer and makes the merge layer source-agnostic.

## 6. What I did not check

- Whether git's `--since` commit-date vs author-date drift ever exceeds
  the one known rebase artifact under synthetic test fixtures.
- Payload size with the full 400-entry cap over a real run (estimate
  only; no feed writer exists yet).
- Whether a future window should widen when the merged feed is paginated
  (schema/2 concern, out of scope).
