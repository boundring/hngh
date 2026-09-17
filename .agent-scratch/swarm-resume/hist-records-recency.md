# hist-records-recency: docs/records/ recency window verification

Verified 2026-09-15, repo ~/Projects/etc/hngh. READ-ONLY.

## Ordering

- Directory holds 139 markdown records plus README.md.
- Filename convention `YYYY-MM-DD-<slug>.md` is ISO date-prefixed, so plain
  lexicographic sort is chronological: `ls docs/records/ | sort -C` exits 0
  (already sorted oldest-first); `sort -r` yields newest-first directly.
- Newest records (2026-09-15): viz-schema-version-gate,
  viz-schema-validation-seam, swarm-coordination-lessons,
  rehearsal-lane-step-2-landing, loop-history-526cd3f-exemption-cure-completed,
  graph-60s-refresh-wiring-plan. Oldest: 2026-08-11-crystallized-cutover.
- Only non-record entry is README.md, which sorts at the very end of
  reverse order (capital R > lowercase) and at the very end of forward
  order too; it must be excluded explicitly when slicing records.

## Recent-slice selection

- Tail/last-N by date works with `ls docs/records/*.md | sort -r | head -N`
  (or `tail -N` on forward sort, skipping the README). No date parsing
  needed because of the ISO prefixes.

## Thin-harvest-since-09-01 policy

- Stated in docs/records/README.md (~line 175): "The harvest from
  2026-09-01 onward is thin here on purpose: recent work-slice facts live
  closer to their surfaces (plan files, reports.md, the changelog)."
- The README names four 2026-09-09 anchor records the documentation spine
  ties itself to: 1password-service-account-interface,
  budget-governance-directive, operator-flexibility-doctrine,
  wake-mutation-lane-rotation.
- Empirically the window is NOT empty: there are ~30 records dated
  2026-09-13 through 2026-09-15 (e.g. userspace-home,
  wake-mutation-lane-landing, the 2026-09-14 graph/jcode wave, the
  2026-09-15 viz-schema and rehearsal records). "Thin" is relative to the
  dense 2026-08 harvest, not a freeze.

## Where recent facts live instead

- docs/project/reports.md: append-only timestamped progress/alert table,
  entries up to 2026-09-15T13:12Z (research-beat lines, archive digests).
- CHANGELOG.md: dated entries; note its last explicit dated section here
  reads 2026-09-07 with records links, so CHANGELOG lags reports.md.
- Plan files and per-slice artifacts (per README policy text).
- The four 2026-09-09 anchor records for governance/doctrine facts.

## Conclusion

Newest-first recency slicing of docs/records/ is safe: ISO-prefix sortability
verified (`sort -C` clean), thin-harvest policy confirmed at
docs/records/README.md:175, and recent facts are expected in reports.md /
changelog / plan files rather than dense daily records.
