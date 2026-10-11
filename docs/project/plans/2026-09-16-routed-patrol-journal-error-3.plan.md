<!-- plan: status=executed risk=normal accepted=2026-09-18T01:41:57Z routed-from=patrol:journal-error -->
# 2026-09-16 — routed candidate

Routed by scripts/router-tick.py from alert identity `patrol:journal-error`
at 2026-09-16T15:00:40Z. Alert text: patrol journal-error: unclaimed-err on unknown-journal-error -- 9 err+ line(s) no signature claims; latest: Bluetooth: hci0: ACL packet for unknown connection handle 3837 ×5

## Steps

- [x] Delve: open research subject fail-20260916-patrol-journal-error for patrol:journal-error; record disposition; then fix or park
      Verification: research subject fail-20260916-patrol-journal-error present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Execution note (2026-10-11)

- The routed subject name `fail-20260916-patrol-journal-error` is a
  router-text mangling: no such subject was ever filed. The alert's
  actual subject `patrol-20260916-journal-error-unclaimed-err` carries
  disposition `killed` (reorientation 2026-09-25, dupe of the kept
  `patrol-20260925-journal-error-unclaimed-err`;
  research-dispositions.tsv row 315;
  docs/records/2026-09-25-research-reorientation.md). Disposition
  recorded; nothing re-opened.
- Fix landed (fix, not park): `bluetooth-acl-stale` signature row in
  automation/config/journal-patrol.tsv -- transient, alert>=10. The
  class (kernel bluetooth driver dropping ACL data for a
  connection handle the controller already tore down) is observed
  recurring on this host since the 2026-09-16 filings (19 lines in
  the 2026-10-10 boot), has no corrective action (the stale handle
  lives kernel-side; bluetooth is not a --user unit), and claimed
  counting is the kwin-xcb-error precedent. unclaimed-err stops
  firing for it; a >=10-per-30m-window storm still escalates.
- Verification: tests/test-patrol.py
  Patrol.test_journal_seeds_fire_mapped_actions red first (the ACL
  line fell into unknown-journal-error), green after the row (the
  fixture runs against the landed table); real-data proof ran
  check_journal_errors over the live kernel journal with a backdated
  watermark: 18 real ACL lines claimed by bluetooth-acl-stale.
  automation make test green. The 7 other unclaimed err+ lines in
  that window are sporadic one-offs (6x pipewire profile glitch,
  1x sudo pacman auth failure) -- left unclaimed by design; the
  bestiary grows by usage, not by guess.

## Occurrences

- 2026-09-16T16:00:13Z re-occurred (dedup window expired)
- 2026-09-16T17:00:21Z re-occurred (dedup window expired)
