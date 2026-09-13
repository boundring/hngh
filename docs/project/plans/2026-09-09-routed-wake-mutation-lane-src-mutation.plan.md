<!-- plan: status=accepted risk=normal accepted=2026-09-09T20:01:16Z routed-from=wake-mutation-lane:src-mutation -->
# 2026-09-09 — routed candidate

Routed by scripts/router-tick.py from alert identity `wake-mutation-lane:src-mutation`
at 2026-09-09T17:00:16Z. Alert text: wake-mutation-lane rotation beat parked at the machine boundary: the :wake-mutation kernel src mutation is operator-only (2026-09-03 staging plan boundary); the boundary proposal itself is certified on the docs candidate (record docs/records/2026-09-09-wake-mutation-lane-rotation.md, landed through the certificate ceremony in this beat).

## Steps

- [x] Delve: open research subject fail-20260909-wake-mutation-lane-src-mutation for wake-mutation-lane:src-mutation; record disposition; then fix or park
      Verification: research subject fail-20260909-wake-mutation-lane-src-mutation present in research-subjects.txt with a recorded disposition; alert fixed or parked
      EXECUTED 2026-09-13T13:02Z: subject appended to automation/research-subjects.txt (line 80); disposition=parked in automation/research-dispositions.tsv (line 84, machine session cannot touch kernel src/ per 2026-09-03 staging boundary); crystallized doc docs/research/2026-09-13-fail-20260909-wake-mutation-lane-src-mutation.md; park occurrence row 6851ecc4 (2026-09-13T13:02:00Z) in docs/project/reports.md with body file. Landing path unchanged: operator lands the :wake-mutation src change through the ceremony (src/adapter/mutation.lisp:8-9, src/packages.lisp:247, src/main.lisp dispatch checks now :1469/:1588, tests/adapter/test-mutation.lisp).
      Verification: research subject fail-20260909-wake-mutation-lane-src-mutation present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-09T18:00:13Z re-occurred (dedup window expired)
